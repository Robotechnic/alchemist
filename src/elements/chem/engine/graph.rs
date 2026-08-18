//! Molecular graph IR shared by both front-ends (DSL and SMILES).
//!
//! A node is a *drawn vertex*. For the DSL a vertex is a condensed fragment
//! (e.g. "CH3", "OH", "(CH2)14") with `text` set; a bare ring/implicit carbon
//! has `text == None` (skeletal). For SMILES a vertex is a single atom and the
//! label is generated from element + hydrogens + charge.

use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BondKind {
    Single,
    Double,
    Triple,
    CramFilledRight,
    CramFilledLeft,
    CramDashedRight,
    CramDashedLeft,
    CramHollowRight,
    CramHollowLeft,
    /// Coordination / dative bond (GR-1.7), drawn as an arrow.
    Dative,
}

impl BondKind {
    pub fn from_symbol(sym: &str) -> Self {
        match sym {
            "=" => BondKind::Double,
            "#" => BondKind::Triple,
            ">" => BondKind::CramFilledRight,
            "<" => BondKind::CramFilledLeft,
            ":>" => BondKind::CramDashedRight,
            "<:" => BondKind::CramDashedLeft,
            "|>" => BondKind::CramHollowRight,
            "<|" => BondKind::CramHollowLeft,
            "~" => BondKind::Dative,
            _ => BondKind::Single,
        }
    }
    /// alchemist link function name used by the Typst renderer.
    pub fn link_name(self) -> &'static str {
        match self {
            BondKind::Single => "single",
            BondKind::Double => "double",
            BondKind::Triple => "triple",
            BondKind::CramFilledRight => "cram-filled-right",
            BondKind::CramFilledLeft => "cram-filled-left",
            BondKind::CramDashedRight => "cram-dashed-right",
            BondKind::CramDashedLeft => "cram-dashed-left",
            BondKind::CramHollowRight => "cram-hollow-right",
            BondKind::CramHollowLeft => "cram-hollow-left",
            BondKind::Dative => "dative",
        }
    }
    /// Bond order for geometry (double-bond offset, labels). Wedges are single.
    pub fn order(self) -> u8 {
        match self {
            BondKind::Double => 2,
            BondKind::Triple => 3,
            _ => 1,
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct Node {
    /// Condensed label to render; None = skeletal carbon vertex.
    pub text: Option<String>,
    /// Representative heavy atom symbol, e.g. "C", "N", "O".
    pub element: String,
    pub charge: i8,
    pub isotope: Option<u16>,
    /// Hydrogens attached (explicit in the DSL label; implicit for SMILES).
    pub hcount: u8,
    /// True when `hcount` is the definitive H count (DSL fragment / SMILES atom);
    /// false for bare skeletal carbons whose H is implicit and uncounted.
    pub h_explicit: bool,
    /// Cross-link / mechanism anchor name (`:name`).
    pub label: Option<String>,
    pub aromatic: bool,
    /// Tetrahedral chirality: 0 none, -1 = @ (anti), +1 = @@ (clockwise).
    pub chirality: i8,
    /// SMILES: this atom had a preceding "from" atom (implicit-H ordering).
    pub preceding: bool,
    // computed
    pub pos: Option<(f64, f64)>,
    pub ring_ids: Vec<usize>,
}

impl Node {
    pub fn skeletal() -> Self {
        Node {
            element: "C".into(),
            ..Default::default()
        }
    }
    pub fn is_skeletal(&self) -> bool {
        self.text.is_none()
    }
}

#[derive(Debug, Clone)]
pub struct Bond {
    pub a: usize,
    pub b: usize,
    pub kind: BondKind,
    /// SMILES directional marker for cis/trans: 0 none, +1 `/`, -1 `\`
    /// (sign is relative to the written order a→b).
    pub direction: i8,
    pub ring_ids: Vec<usize>,
}

#[derive(Debug, Default)]
pub struct Graph {
    pub nodes: Vec<Node>,
    pub bonds: Vec<Bond>,
    pub adj: Vec<Vec<(usize, usize)>>, // (neighbor, bond_idx)
    pub rings: Vec<Vec<usize>>,        // SSSR, filled by ring perception
    pub labels: HashMap<String, usize>,
}

impl Graph {
    pub fn add_node(&mut self, node: Node) -> usize {
        let id = self.nodes.len();
        if let Some(name) = &node.label {
            self.labels.insert(name.clone(), id);
        }
        self.nodes.push(node);
        self.adj.push(Vec::new());
        id
    }

    pub fn add_bond(&mut self, a: usize, b: usize, kind: BondKind) -> usize {
        let idx = self.bonds.len();
        self.bonds.push(Bond {
            a,
            b,
            kind,
            direction: 0,
            ring_ids: Vec::new(),
        });
        self.adj[a].push((b, idx));
        self.adj[b].push((a, idx));
        idx
    }

    pub fn n(&self) -> usize {
        self.nodes.len()
    }

    pub fn bond_between(&self, a: usize, b: usize) -> Option<usize> {
        self.adj[a]
            .iter()
            .find_map(|&(nb, bi)| if nb == b { Some(bi) } else { None })
    }

    /// Laid-out position of atom `i` (origin if it has not been placed yet).
    pub fn pos(&self, i: usize) -> (f64, f64) {
        self.nodes[i].pos.unwrap_or((0.0, 0.0))
    }

    /// Sum of bond orders incident on atom `i` (single = 1, double = 2, …).
    pub fn bond_order_sum(&self, i: usize) -> i16 {
        self.adj[i]
            .iter()
            .map(|&(_, bi)| self.bonds[bi].kind.order() as i16)
            .sum()
    }

    /// Hydrogens needed to fill atom `i`'s (charge-adjusted) standard valence,
    /// given the heavy bonds already placed; 0 for elements with no set valence.
    pub fn implicit_h(&self, i: usize) -> u8 {
        let node = &self.nodes[i];
        standard_valence(&node.element)
            .map(|v| {
                (v + charge_valence_adjust(&node.element, node.charge) - self.bond_order_sum(i))
                    .max(0) as u8
            })
            .unwrap_or(0)
    }

    /// Assign Kekulé double bonds to atoms flagged `aromatic` (used by the DSL
    /// auto-aromatic rings). Greedy maximum matching over the currently-single
    /// bonds between aromatic atoms — the same scheme the SMILES front-end uses.
    pub fn kekulize_aromatic(&mut self) {
        let n = self.n();
        let mut needs = vec![false; n];
        for i in 0..n {
            if !self.nodes[i].aromatic {
                continue;
            }
            // an atom already carrying a double/triple (e.g. exocyclic C=O) is set
            let has_multiple = self.adj[i]
                .iter()
                .any(|&(_, bi)| self.bonds[bi].kind.order() >= 2);
            if has_multiple {
                continue;
            }
            let charge = self.nodes[i].charge;
            // total connectivity distinguishes pyridine-type (needs a ring double)
            // from pyrrole-type (donates its lone pair, stays single).
            let total_deg = self.adj[i].len() + self.nodes[i].hcount as usize;
            needs[i] = match self.nodes[i].element.as_str() {
                "C" => charge == 0,
                "N" | "P" => charge > 0 || total_deg <= 2,
                "B" => true,
                _ => false,
            };
        }
        let arom_edges: Vec<usize> = (0..self.bonds.len())
            .filter(|&e| {
                let b = &self.bonds[e];
                self.nodes[b.a].aromatic && self.nodes[b.b].aromatic && b.kind == BondKind::Single
            })
            .collect();
        // greedy maximum matching, most-constrained atom first: order by how many
        // aromatic edges reach *another* atom that also needs a double, so a atom
        // with only one possible partner (e.g. a pyrrole β-carbon) is matched
        // before its partner gets taken by someone else.
        let free_deg = |i: usize| {
            arom_edges
                .iter()
                .filter(|&&e| {
                    let (a, c) = (self.bonds[e].a, self.bonds[e].b);
                    let j = if a == i {
                        c
                    } else if c == i {
                        a
                    } else {
                        return false;
                    };
                    needs[j]
                })
                .count()
        };
        let mut matched = vec![false; n];
        let mut atoms: Vec<usize> = (0..n).filter(|&i| needs[i]).collect();
        atoms.sort_by_key(|&i| free_deg(i));
        for &i in &atoms {
            if matched[i] {
                continue;
            }
            for &e in &arom_edges {
                let (a, c) = (self.bonds[e].a, self.bonds[e].b);
                let j = if a == i {
                    c
                } else if c == i {
                    a
                } else {
                    continue;
                };
                if needs[j] && !matched[j] {
                    self.bonds[e].kind = BondKind::Double;
                    matched[i] = true;
                    matched[j] = true;
                    break;
                }
            }
        }
    }
}

/// Atomic number for a heavy-atom element symbol (defaults to carbon).
pub fn atomic_number(sym: &str) -> i32 {
    match sym {
        "H" => 1,
        "He" => 2,
        "Li" => 3,
        "Be" => 4,
        "B" => 5,
        "C" => 6,
        "N" => 7,
        "O" => 8,
        "F" => 9,
        "Ne" => 10,
        "Na" => 11,
        "Mg" => 12,
        "Al" => 13,
        "Si" => 14,
        "P" => 15,
        "S" => 16,
        "Cl" => 17,
        "Ar" => 18,
        "K" => 19,
        "Ca" => 20,
        "Fe" => 26,
        "Cu" => 29,
        "Zn" => 30,
        "Br" => 35,
        "I" => 53,
        _ => 6,
    }
}

/// Standard neutral valence for implicit-H (SMILES front-end).
/// Valence adjustment for charged heteroatoms (N⁺ takes 4 bonds, O⁻ takes 1, a
/// charged carbon loses one per unit charge, …).
pub fn charge_valence_adjust(elem: &str, charge: i8) -> i16 {
    match elem {
        "N" | "P" | "O" | "S" => charge as i16,
        "C" => -(charge.abs() as i16),
        _ => 0,
    }
}

pub fn standard_valence(sym: &str) -> Option<i16> {
    Some(match sym {
        "C" | "Si" | "Sn" => 4,
        "N" | "P" | "As" => 3,
        "O" | "S" | "Se" | "Te" => 2,
        "B" => 3,
        "F" | "Cl" | "Br" | "I" => 1,
        _ => return None,
    })
}

/// Valence electrons for lone-pair counting.
pub fn valence_electrons(sym: &str) -> Option<i16> {
    Some(match sym {
        "B" => 3,
        "C" | "Si" | "Sn" => 4,
        "N" | "P" | "As" => 5,
        "O" | "S" | "Se" | "Te" => 6,
        "F" | "Cl" | "Br" | "I" => 7,
        _ => return None,
    })
}
