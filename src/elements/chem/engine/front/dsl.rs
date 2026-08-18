//! Alchemist DSL parser: condensed structural notation -> Graph IR.
//!
//! Grammar (ported from the Typst parser-combinator version):
//!   molecule  ::= unit (bond unit)*
//!   unit      ::= (fragment | label-ref)? branch* ring*
//!   fragment  ::= atoms label?
//!   bond      ::= ("-"|"="|"#"|">"|"<"|":>"|"<:"|"|>"|"<|") bondlabel?
//!   branch    ::= "(" bond molecule ")"
//!   ring      ::= "@" INT ("(" ring-body ")")? label?
//!   ring-body ::= ring-vertex (bond? ring-vertex)*   // bond defaults to single
//!   ring-vertex ::= atom? branch* ring*              // one atom per vertex
//!   label     ::= ":" IDENT
//!
//! A fragment is one drawn vertex (e.g. "CH3"); an empty unit is a skeletal C.
//! In a ring body, each vertex is a single atom (plain C = skeletal, heteroatom =
//! labelled) and the bond between vertices is optional, so a 6-membered carbo-/
//! aza-cycle written without explicit bonds is auto-aromatised: `@6` = benzene,
//! `@6(N)` = pyridine, `@6(C(-CH3)CCCCC)` = toluene. Writing explicit bonds keeps
//! the literal structure (`@6(------)` cyclohexane, `@6(-=-=-=)` Kekulé benzene).

use crate::graph::{BondKind, Graph, Node};

// ── AST ──────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
struct Frag {
    text: String,
    element: String,
    charge: i8,
    isotope: Option<u16>,
    hcount: u8,
    label: Option<String>,
}

#[derive(Debug, Clone)]
enum NodeAst {
    Fragment(Frag),
    LabelRef(String), // :name used as a node (remote ring closure)
    Implicit,         // skeletal carbon
}

#[derive(Debug, Clone)]
struct Unit {
    node: NodeAst,
    branches: Vec<(BondKind, Mol)>,
    rings: Vec<Ring>,
}

#[derive(Debug, Clone)]
struct Ring {
    faces: usize,
    body: Option<Mol>,
    /// True if the body wrote any explicit bond symbol. When false (e.g. `@6`,
    /// `@6(N)`, `@6(C(-CH3)CCCCC)`) the ring's bonds were all defaulted, so a
    /// 6-membered carbo-/aza-cycle is auto-aromatised (benzene / pyridine).
    explicit_bonds: bool,
}

#[derive(Debug, Clone)]
struct Mol {
    first: Unit,
    rest: Vec<(BondKind, Unit)>,
}

// ── Parser ─────────────────────────────────────────────────────────────────

struct P {
    c: Vec<char>,
    i: usize,
}

impl P {
    fn peek(&self) -> Option<char> {
        self.c.get(self.i).copied()
    }
    fn peek2(&self) -> Option<char> {
        self.c.get(self.i + 1).copied()
    }
    fn bump(&mut self) -> Option<char> {
        let c = self.peek();
        if c.is_some() {
            self.i += 1;
        }
        c
    }
    fn eat(&mut self, c: char) -> bool {
        if self.peek() == Some(c) {
            self.i += 1;
            true
        } else {
            false
        }
    }
    fn at_end(&self) -> bool {
        self.i >= self.c.len()
    }

    /// Advance past every leading character satisfying `pred`.
    fn skip_while(&mut self, pred: impl Fn(char) -> bool) {
        while matches!(self.peek(), Some(c) if pred(c)) {
            self.i += 1;
        }
    }

    fn parse_bond(&mut self) -> Option<BondKind> {
        let two: String = self.c[self.i..(self.i + 2).min(self.c.len())]
            .iter()
            .collect();
        let sym = match two.as_str() {
            ":>" | "<:" | "|>" | "<|" => {
                self.i += 2;
                two.as_str().to_string()
            }
            _ => match self.peek() {
                Some(c @ ('-' | '=' | '#' | '>' | '<' | '~')) => {
                    self.i += 1;
                    c.to_string()
                }
                _ => return None,
            },
        };
        // optional bond label "::name"
        if self.peek() == Some(':') && self.peek2() == Some(':') {
            self.i += 2;
            self.parse_ident();
        }
        Some(BondKind::from_symbol(&sym))
    }

    fn parse_ident(&mut self) -> String {
        let start = self.i;
        self.skip_while(|c| c.is_ascii_alphanumeric() || c == '_');
        self.c[start..self.i].iter().collect()
    }

    /// A `(` that starts a branch (next char is a bond symbol), vs. a
    /// parenthetical that is part of a fragment (next char is an atom).
    fn paren_is_branch(&self) -> bool {
        matches!(
            self.peek2(),
            Some('-' | '=' | '#' | '>' | '<' | ':' | '|' | '~')
        )
    }

    fn parse_fragment(&mut self) -> Option<Frag> {
        let start = self.i;
        // consume atom-parts until a stop char
        loop {
            match self.peek() {
                Some(c) if c.is_ascii_uppercase() => {
                    self.i += 1;
                    self.skip_while(|c| c.is_ascii_lowercase());
                    self.skip_while(|c| c.is_ascii_digit());
                }
                Some('(') if !self.paren_is_branch() => {
                    // parenthetical group: ( atoms ) digits*
                    self.i += 1;
                    let mut depth = 1;
                    while depth > 0 {
                        match self.bump() {
                            Some('(') => depth += 1,
                            Some(')') => depth -= 1,
                            None => break,
                            _ => {}
                        }
                    }
                    self.skip_while(|c| c.is_ascii_digit());
                }
                Some('[') => {
                    self.i += 1;
                    self.skip_while(|c| c != ']');
                    self.eat(']');
                }
                Some('^') => {
                    // isotope (^14) handled in extract; charge (^+/^2-) too
                    self.i += 1;
                    self.skip_while(|c| c.is_ascii_digit());
                    if matches!(self.peek(), Some('+' | '-')) {
                        self.i += 1;
                    }
                }
                _ => break,
            }
        }
        if self.i == start {
            return None;
        }
        let text: String = self.c[start..self.i].iter().collect();
        Some(extract_frag(&text))
    }

    /// A `:name` annotation (but not the `:>` dative bond); consumed if present.
    fn try_label(&mut self) -> Option<String> {
        if self.peek() == Some(':') && self.peek2() != Some('>') {
            self.i += 1;
            Some(self.parse_ident())
        } else {
            None
        }
    }

    /// One vertex: a leading `:name` remote-reference, else an atom (a condensed
    /// `fragment` in a chain, a single `ring` atom in a ring body) with an
    /// optional `:label`, else an implicit skeletal carbon; plus its decorations.
    /// In ring bodies a plain `C` is a skeletal vertex, not a labelled fragment.
    fn parse_unit(&mut self, ring: bool) -> Unit {
        let node = if let Some(name) = self.try_label() {
            NodeAst::LabelRef(name)
        } else if let Some(mut frag) = if ring {
            self.parse_ring_atom()
        } else {
            self.parse_fragment()
        } {
            frag.label = self.try_label();
            let plain_c = ring
                && frag.element == "C"
                && frag.text == "C"
                && frag.charge == 0
                && frag.isotope.is_none()
                && frag.hcount == 0
                && frag.label.is_none();
            if plain_c {
                NodeAst::Implicit
            } else {
                NodeAst::Fragment(frag)
            }
        } else {
            NodeAst::Implicit
        };
        let (branches, rings) = self.parse_decorations();
        Unit {
            node,
            branches,
            rings,
        }
    }

    /// Branches `(…)` and rings `@n` that decorate a vertex (shared by chain and
    /// ring-body vertices).
    fn parse_decorations(&mut self) -> (Vec<(BondKind, Mol)>, Vec<Ring>) {
        let mut branches = Vec::new();
        let mut rings = Vec::new();
        loop {
            if self.peek() == Some('(') && self.paren_is_branch() {
                self.i += 1; // (
                let bond = self.parse_bond().unwrap_or(BondKind::Single);
                let mol = self.parse_molecule();
                self.eat(')');
                branches.push((bond, mol));
            } else if self.peek() == Some('@') {
                self.i += 1;
                let faces = self.parse_int().unwrap_or(6) as usize;
                let (body, explicit_bonds) = if self.peek() == Some('(') {
                    self.i += 1;
                    let (m, explicit) = self.parse_ring_body();
                    self.eat(')');
                    (Some(m), explicit)
                } else {
                    (None, false)
                };
                self.try_label(); // optional :label on ring (ignored for now)
                rings.push(Ring {
                    faces,
                    body,
                    explicit_bonds,
                });
            } else {
                break;
            }
        }
        (branches, rings)
    }

    /// Parse a single ring-vertex atom: one element symbol + optional explicit H
    /// run (e.g. `NH` pyrrole) + optional `^charge`/`^isotope`. Returns None when
    /// the next token is not an atom (so the vertex is implicit/skeletal).
    fn parse_ring_atom(&mut self) -> Option<Frag> {
        let start = self.i;
        match self.peek() {
            Some(c) if c.is_ascii_uppercase() => {
                self.i += 1;
                if matches!(self.peek(), Some(c) if c.is_ascii_lowercase()) {
                    self.i += 1;
                }
            }
            _ => return None,
        }
        // explicit attached hydrogens, e.g. NH / NH1 (pyrrole-type)
        if self.peek() == Some('H') {
            self.i += 1;
            self.skip_while(|c| c.is_ascii_digit());
        }
        // ^isotope / ^charge marker
        if self.peek() == Some('^') {
            self.i += 1;
            self.skip_while(|c| c.is_ascii_digit());
            if matches!(self.peek(), Some('+' | '-')) {
                self.i += 1;
            }
        }
        let text: String = self.c[start..self.i].iter().collect();
        Some(extract_frag(&text))
    }

    fn parse_int(&mut self) -> Option<u32> {
        let start = self.i;
        self.skip_while(|c| c.is_ascii_digit());
        if self.i == start {
            None
        } else {
            self.c[start..self.i]
                .iter()
                .collect::<String>()
                .parse()
                .ok()
        }
    }

    fn parse_molecule(&mut self) -> Mol {
        let first = self.parse_unit(false);
        let mut rest = Vec::new();
        while let Some(save) = {
            let s = self.i;
            self.parse_bond().map(|b| (s, b))
        } {
            let (_, bond) = save;
            let unit = self.parse_unit(false);
            rest.push((bond, unit));
        }
        Mol { first, rest }
    }

    /// Parse a ring body where the bond between two vertices is optional and
    /// defaults to single — so vertices can be juxtaposed (`N`, `CCCCCC`,
    /// `C(-CH3)C(-CH3)CCCC`) as well as written with explicit bonds (`-=-=-=`).
    /// Returns whether any explicit bond symbol appeared.
    fn parse_ring_body(&mut self) -> (Mol, bool) {
        let mut explicit = false;
        let first = self.parse_unit(true);
        let mut rest = Vec::new();
        loop {
            if self.peek() == Some(')') || self.at_end() {
                break;
            }
            let before = self.i;
            let bond = match self.parse_bond() {
                Some(b) => {
                    explicit = true;
                    b
                }
                None => BondKind::Single,
            };
            let unit = self.parse_unit(true);
            if self.i == before {
                break; // no progress (unexpected char) — avoid looping forever
            }
            rest.push((bond, unit));
        }
        (Mol { first, rest }, explicit)
    }
}

/// Extract element / charge / isotope / hcount from a condensed fragment string.
fn extract_frag(text: &str) -> Frag {
    let chars: Vec<char> = text.chars().collect();
    let mut element = String::new();
    let mut hcount = 0u8;
    let mut charge = 0i8;
    let mut isotope = None;

    // first heavy (non-H) element symbol + attached hydrogens
    let mut i = 0;
    let mut h_before = 0u8;
    while i < chars.len() {
        let c = chars[i];
        if c.is_ascii_uppercase() {
            let mut sym = c.to_string();
            i += 1;
            if i < chars.len() && chars[i].is_ascii_lowercase() {
                sym.push(chars[i]);
                i += 1;
            }
            let mut digits = String::new();
            while i < chars.len() && chars[i].is_ascii_digit() {
                digits.push(chars[i]);
                i += 1;
            }
            let count: u8 = digits.parse().unwrap_or(1);
            if sym == "H" {
                if element.is_empty() {
                    h_before = h_before.saturating_add(count);
                } else {
                    hcount = hcount.saturating_add(count);
                }
            } else if element.is_empty() {
                element = sym;
                hcount = h_before; // hydrogens written before the heavy atom
            }
        } else if c == '^' {
            i += 1;
            let mut digits = String::new();
            while i < chars.len() && chars[i].is_ascii_digit() {
                digits.push(chars[i]);
                i += 1;
            }
            if i < chars.len() && (chars[i] == '+' || chars[i] == '-') {
                let n: i8 = digits.parse().unwrap_or(1);
                charge = if chars[i] == '+' { n } else { -n };
                i += 1;
            } else if !digits.is_empty() {
                isotope = digits.parse().ok();
            }
        } else {
            i += 1;
        }
    }
    if element.is_empty() {
        element = "C".into();
    }
    Frag {
        // Display text strips the `^isotope` / `^charge` markers — those are
        // rendered separately (GR-2.1.3 isotope superscript, GR-5.1 charge).
        text: strip_carets(text),
        element,
        charge,
        isotope,
        hcount,
        label: None,
    }
}

/// Remove `^<digits>` (isotope) and `^<digits>?[+-]` (charge) markers.
fn strip_carets(text: &str) -> String {
    let chars: Vec<char> = text.chars().collect();
    let mut out = String::new();
    let mut i = 0;
    while i < chars.len() {
        if chars[i] == '^' {
            i += 1;
            while i < chars.len() && chars[i].is_ascii_digit() {
                i += 1;
            }
            if i < chars.len() && (chars[i] == '+' || chars[i] == '-') {
                i += 1;
            }
        } else {
            out.push(chars[i]);
            i += 1;
        }
    }
    out
}

/// Build a graph node from a parsed fragment. DSL fragments are explicit: the
/// label the user wrote (CH3, CH2, OH …) is preserved as-is.
fn node_from_frag(f: &Frag) -> Node {
    Node {
        text: Some(f.text.clone()),
        element: f.element.clone(),
        charge: f.charge,
        isotope: f.isotope,
        hcount: f.hcount,
        label: f.label.clone(),
        h_explicit: true,
        ..Default::default()
    }
}

// ── AST -> Graph ─────────────────────────────────────────────────────────────

struct Builder {
    g: Graph,
}

impl Builder {
    /// Returns the id of the first node of `mol`, bonding it to `parent`.
    fn build_mol(&mut self, mol: &Mol, parent: Option<usize>, incoming: BondKind) -> Option<usize> {
        let first = self.build_unit(&mol.first, parent, incoming)?;
        let mut prev = first;
        for (bond, unit) in &mol.rest {
            if let Some(id) = self.build_unit(unit, Some(prev), *bond) {
                prev = id;
            }
        }
        Some(first)
    }

    fn build_unit(
        &mut self,
        unit: &Unit,
        parent: Option<usize>,
        incoming: BondKind,
    ) -> Option<usize> {
        let cur = match &unit.node {
            NodeAst::LabelRef(name) => {
                // remote closure: bond parent to the referenced node
                let target = *self.g.labels.get(name)?;
                if let Some(p) = parent {
                    self.g.add_bond(p, target, incoming);
                }
                target
            }
            NodeAst::Fragment(f) => {
                let id = self.g.add_node(node_from_frag(f));
                if let Some(p) = parent {
                    self.g.add_bond(p, id, incoming);
                }
                id
            }
            NodeAst::Implicit => {
                let id = self.g.add_node(Node::skeletal());
                if let Some(p) = parent {
                    self.g.add_bond(p, id, incoming);
                }
                id
            }
        };

        for (bond, mol) in &unit.branches {
            self.build_mol(mol, Some(cur), *bond);
        }
        for ring in &unit.rings {
            self.build_ring(cur, ring);
        }
        Some(cur)
    }

    /// Build an `n`-membered ring whose vertex 0 is `anchor`.
    /// Per-edge bond kinds and per-vertex body decorations, padded/truncated to
    /// exactly `edges` entries (defaulting to single bonds / no decoration).
    fn ring_edges(body: &Option<Mol>, edges: usize) -> (Vec<BondKind>, Vec<Option<Unit>>) {
        let mut kinds = Vec::new();
        let mut units = Vec::new();
        if let Some(body) = body {
            for (bond, unit) in &body.rest {
                kinds.push(*bond);
                units.push(Some(unit.clone()));
            }
        }
        kinds.resize(edges, BondKind::Single);
        units.resize(edges, None);
        (kinds, units)
    }

    /// Walk a ring path from `start`, adding one bond per `kinds` entry; the last
    /// bond closes onto the existing vertex `close`. Interior vertices are created
    /// (as body fragments or skeletal carbons). Returns start + interior vertices.
    fn lay_ring_path(
        &mut self,
        start: usize,
        close: usize,
        kinds: &[BondKind],
        units: &[Option<Unit>],
    ) -> Vec<usize> {
        let mut prev = start;
        let mut verts = vec![start];
        for (k, &kind) in kinds.iter().enumerate() {
            let target = if k == kinds.len() - 1 {
                close
            } else {
                let id = match units[k].as_ref() {
                    Some(u) => self.unit_vertex(u),
                    None => self.g.add_node(Node::skeletal()),
                };
                verts.push(id);
                id
            };
            self.g.add_bond(prev, target, kind);
            prev = target;
        }
        verts
    }

    /// Decorate interior vertices `verts[1..]` from their body units (`units[k]`
    /// decorates `verts[k+1]`, entered from `verts[k]`).
    fn decorate_ring(&mut self, verts: &[usize], units: &[Option<Unit>]) {
        for k in 0..verts.len() - 1 {
            if let Some(Some(u)) = units.get(k) {
                self.decorate_vertex(verts[k], verts[k + 1], u);
            }
        }
    }

    fn build_ring(&mut self, anchor: usize, ring: &Ring) {
        let n = ring.faces;
        if n < 3 {
            return;
        }
        let (kinds, units) = Self::ring_edges(&ring.body, n);
        let verts = self.lay_ring_path(anchor, anchor, &kinds, &units);
        // The body's first token decorates vertex 0 (the anchor); a heteroatom
        // written there (e.g. `@6(N)` pyridine) replaces the skeletal anchor carbon.
        if let Some(u) = ring.body.as_ref().map(|b| &b.first) {
            if let NodeAst::Fragment(f) = &u.node {
                let ring_ids = self.g.nodes[anchor].ring_ids.clone();
                let mut nn = node_from_frag(f);
                nn.ring_ids = ring_ids;
                self.g.nodes[anchor] = nn;
            }
            self.decorate_vertex(*verts.last().unwrap(), anchor, u);
        }
        self.decorate_ring(&verts, &units);
        self.maybe_aromatize(n, ring.explicit_bonds, &verts);
    }

    /// A 6-membered carbo-/aza-cycle whose bonds were all defaulted (no explicit
    /// bond symbol) is drawn aromatic — `@6` benzene, `@6(N)` pyridine — by
    /// flagging its atoms; `kekulize_aromatic` then assigns the double bonds.
    fn maybe_aromatize(&mut self, faces: usize, explicit: bool, atoms: &[usize]) {
        if faces != 6 || explicit {
            return;
        }
        if !atoms
            .iter()
            .all(|&v| matches!(self.g.nodes[v].element.as_str(), "C" | "N"))
        {
            return;
        }
        for &v in atoms {
            self.g.nodes[v].aromatic = true;
        }
    }

    /// Build an `n`-ring fused onto the existing edge (a, b): a and b are two of
    /// its vertices, sharing that bond; only the other n-2 vertices are new.
    /// Build an `n`-ring fused onto the existing edge (a, b): a and b are two of
    /// its vertices sharing that bond, so only the other n-2 vertices are new and
    /// the body provides the n-1 non-shared edges (b -> ... -> a).
    fn build_fused_ring(&mut self, a: usize, b: usize, ring: &Ring) {
        let n = ring.faces;
        if n < 3 {
            return;
        }
        let (kinds, units) = Self::ring_edges(&ring.body, n - 1);
        let verts = self.lay_ring_path(b, a, &kinds, &units);
        self.decorate_ring(&verts, &units);
        let mut atoms = verts.clone();
        atoms.push(a);
        self.maybe_aromatize(n, ring.explicit_bonds, &atoms);
    }

    /// Create a node for a ring-body vertex (fragment or skeletal carbon).
    fn unit_vertex(&mut self, u: &Unit) -> usize {
        match &u.node {
            NodeAst::Fragment(f) => self.g.add_node(node_from_frag(f)),
            _ => self.g.add_node(Node::skeletal()),
        }
    }

    /// Attach a vertex's branches and nested rings. `pred` is the preceding ring
    /// vertex, so a nested ring fuses on the shared edge (pred, vid).
    fn decorate_vertex(&mut self, pred: usize, vid: usize, u: &Unit) {
        for (bond, mol) in &u.branches {
            self.build_mol(mol, Some(vid), *bond);
        }
        for ring in &u.rings {
            self.build_fused_ring(pred, vid, ring);
        }
    }
}

pub fn parse(source: &str) -> Result<Graph, String> {
    let mut p = P {
        c: source.chars().collect(),
        i: 0,
    };
    // skip leading whitespace
    while matches!(p.peek(), Some(c) if c.is_whitespace()) {
        p.i += 1;
    }
    if p.at_end() {
        return Ok(Graph::default());
    }
    let mol = p.parse_molecule();
    // trailing whitespace ok; otherwise report
    while matches!(p.peek(), Some(c) if c.is_whitespace()) {
        p.i += 1;
    }
    if !p.at_end() {
        let rest: String = p.c[p.i..].iter().collect();
        return Err(format!("unexpected trailing input: {:?}", rest));
    }
    let mut b = Builder {
        g: Graph::default(),
    };
    b.build_mol(&mol, None, BondKind::Single);
    b.g.kekulize_aromatic();
    Ok(b.g)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn g(s: &str) -> Graph {
        parse(s).unwrap()
    }

    #[test]
    fn chain() {
        let m = g("CH3-CH2-OH");
        assert_eq!(m.nodes.len(), 3);
        assert_eq!(m.bonds.len(), 2);
        assert_eq!(m.nodes[0].text.as_deref(), Some("CH3"));
        assert_eq!(m.nodes[2].element, "O");
    }

    #[test]
    fn branch() {
        let m = g("CH3-CH(-OH)-CH3");
        assert_eq!(m.nodes.len(), 4);
        assert_eq!(m.bonds.len(), 3);
    }

    #[test]
    fn double_branch() {
        let m = g("CH3-C(=O)-CH3");
        assert_eq!(m.nodes.len(), 4);
        assert!(m.bonds.iter().any(|b| b.kind == BondKind::Double));
    }

    #[test]
    fn benzene_ring() {
        let m = g("@6(-=-=-=)");
        assert_eq!(m.nodes.len(), 6, "benzene has 6 vertices");
        assert_eq!(m.bonds.len(), 6, "benzene has 6 edges");
        assert_eq!(
            m.bonds
                .iter()
                .filter(|b| b.kind == BondKind::Double)
                .count(),
            3
        );
    }

    #[test]
    fn methylcyclohexane() {
        let m = g("@6(-(-CH3)-----)");
        // 6 ring carbons + 1 methyl
        assert_eq!(m.nodes.len(), 7);
        assert_eq!(m.bonds.len(), 7);
    }

    #[test]
    fn parenthetical_fragment() {
        let m = g("CH3-(CH2)14-C(=O)-OH");
        // CH3, (CH2)14, C, O(branch), OH  = 5 nodes
        assert_eq!(m.nodes.len(), 5);
        assert_eq!(m.nodes[1].text.as_deref(), Some("(CH2)14"));
    }

    fn doubles(m: &Graph) -> usize {
        m.bonds
            .iter()
            .filter(|b| b.kind == BondKind::Double)
            .count()
    }

    #[test]
    fn at6_is_benzene() {
        let m = g("@6");
        assert_eq!(m.nodes.len(), 6);
        assert!(
            m.nodes.iter().all(|n| n.aromatic),
            "all ring atoms aromatic"
        );
        assert_eq!(doubles(&m), 3, "benzene kekulizes to 3 double bonds");
    }

    #[test]
    fn at6_n_is_pyridine() {
        let m = g("@6(N)");
        assert_eq!(m.nodes.len(), 6);
        assert_eq!(m.nodes.iter().filter(|n| n.element == "N").count(), 1);
        assert_eq!(doubles(&m), 3, "pyridine kekulizes to 3 double bonds");
    }

    #[test]
    fn at6_vertices_toluene() {
        // 6-ring listing vertices, bonds auto: toluene
        let m = g("@6(C(-CH3)CCCCC)");
        // 6 ring carbons + 1 methyl
        assert_eq!(m.nodes.len(), 7);
        assert_eq!(doubles(&m), 3, "aromatic ring");
    }

    #[test]
    fn explicit_single_is_cyclohexane() {
        let m = g("@6(------)");
        assert_eq!(m.nodes.len(), 6);
        assert!(
            m.nodes.iter().all(|n| !n.aromatic),
            "explicit bonds: not aromatic"
        );
        assert_eq!(doubles(&m), 0, "cyclohexane is saturated");
    }

    #[test]
    fn explicit_kekule_benzene_unchanged() {
        let m = g("@6(-=-=-=)");
        assert_eq!(m.nodes.len(), 6);
        assert_eq!(doubles(&m), 3);
    }
}
