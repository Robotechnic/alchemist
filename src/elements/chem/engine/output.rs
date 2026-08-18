//! Serde structs for the JSON contract returned to Typst.
//! Coordinates are in bond-length units (1.0 = one bond).

use serde::Serialize;

#[derive(Debug, Clone, Copy, Default, Serialize)]
pub struct Vec2 {
    pub x: f64,
    pub y: f64,
}

impl Vec2 {
    pub fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct AtomOut {
    pub id: usize,
    /// Representative heavy atom (layout / valence decisions).
    pub element: String,
    /// Condensed label to render (e.g. "CH3", "(CH2)14"); null = skeletal vertex.
    pub text: Option<String>,
    pub pos: Vec2,
    pub charge: i8,
    pub isotope: Option<u16>,
    pub lone_pairs: u8,
    /// Implicit hydrogens on a skeletal carbon, shown only under `show-all-h`.
    pub implicit_h: u8,
    /// Unit directions from the atom toward each rendered lone-pair group.
    pub lone_pair_dirs: Vec<Vec2>,
    /// Unpaired electrons (GR-5.3) — drawn as single dots, always shown.
    pub radical: u8,
    /// Directions toward each radical dot.
    pub radical_dirs: Vec<Vec2>,
    /// Cross-link / mechanism anchor name from the DSL `:name`.
    pub label: Option<String>,
    /// Label growth direction "left" | "right" | "up" | "down" (GR-2.x).
    pub label_dir: String,
    /// True for a bare skeletal carbon vertex (no glyph drawn).
    pub skeletal: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct BondOut {
    pub from: usize,
    pub to: usize,
    /// 1 single, 2 double, 3 triple, 4 aromatic — for geometry (offset/label).
    pub order: u8,
    /// alchemist link function name: "single" | "double" | "triple" |
    /// "cram-filled-right" | "cram-dashed-left" | ...  (drives rendering).
    pub kind: String,
    /// Unit vector toward ring centroid for ring double bonds; (0,0) otherwise.
    pub inner: Vec2,
    /// True if this bond belongs to an aromatic ring (GR-6 circle mode).
    pub aromatic: bool,
}

/// An aromatic ring, for the optional GR-6 inner-circle depiction.
#[derive(Debug, Clone, Serialize)]
pub struct RingOut {
    pub center: Vec2,
    pub radius: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct LayoutOut {
    pub atoms: Vec<AtomOut>,
    pub bonds: Vec<BondOut>,
    pub aromatic_rings: Vec<RingOut>,
    /// Bounding box (width, height) in bond-length units, for auto-scaling.
    pub bbox: Vec2,
    /// Hill-system molecular formula counts: [(symbol, count), ...] (GR-2.4).
    pub formula: Vec<(String, u32)>,
    pub warnings: Vec<String>,
}

use crate::graph::{valence_electrons, Graph};
use crate::layout::rings::{largest_gap, ring_has_edge};

/// Build the JSON output from a laid-out graph.
pub fn build(g: &Graph) -> LayoutOut {
    let inner = crate::layout::ring_inner_dirs(g);
    // which rings read as aromatic (all-aromatic atoms, or alternating Kekulé)
    let arom: Vec<bool> = g.rings.iter().map(|r| ring_is_aromatic(g, r)).collect();
    let (lo, hi) = bounds(g);
    LayoutOut {
        atoms: build_atoms(g),
        bonds: build_bonds(g, &inner, &arom),
        aromatic_rings: build_aromatic_rings(g, &arom),
        bbox: Vec2::new(hi.x - lo.x, hi.y - lo.y),
        formula: molecular_formula(g),
        warnings: vec![],
    }
}

fn build_atoms(g: &Graph) -> Vec<AtomOut> {
    g.nodes
        .iter()
        .enumerate()
        .map(|(i, node)| {
            let (x, y) = g.pos(i);
            let lp = lone_pairs(g, i);
            let rad = radical(g, i);
            // place lone pairs first, then radicals, into the free angular gaps
            let dirs = lone_pair_dirs(g, i, lp as usize + rad as usize);
            // GR-2.1.2: a carbon with no explicit bonds must always be labelled
            // (e.g. methane / a methyl radical), lest it be overlooked.
            let (text, skeletal) = if node.is_skeletal() && g.adj[i].is_empty() {
                let h = implicit_h(g, i);
                let t = match h {
                    0 => node.element.clone(),
                    1 => format!("{}H", node.element),
                    n => format!("{}H{}", node.element, n),
                };
                (Some(t), false)
            } else {
                (node.text.clone(), node.is_skeletal())
            };
            AtomOut {
                id: i,
                element: node.element.clone(),
                text,
                pos: Vec2::new(x, y),
                charge: node.charge,
                isotope: node.isotope,
                lone_pairs: lp,
                implicit_h: implicit_h(g, i),
                lone_pair_dirs: dirs[..lp as usize].to_vec(),
                radical: rad,
                radical_dirs: dirs[lp as usize..].to_vec(),
                label: node.label.clone(),
                label_dir: label_dir(g, i),
                skeletal,
            }
        })
        .collect()
}

fn build_bonds(g: &Graph, inner: &[(f64, f64)], arom: &[bool]) -> Vec<BondOut> {
    let bond_arom = |bi: usize| {
        g.rings
            .iter()
            .enumerate()
            .any(|(ri, r)| arom[ri] && ring_has_edge(r, g.bonds[bi].a, g.bonds[bi].b))
    };
    g.bonds
        .iter()
        .enumerate()
        .map(|(bi, b)| BondOut {
            from: b.a,
            to: b.b,
            order: b.kind.order(),
            kind: b.kind.link_name().to_string(),
            inner: Vec2::new(inner[bi].0, inner[bi].1),
            aromatic: bond_arom(bi),
        })
        .collect()
}

fn build_aromatic_rings(g: &Graph, arom: &[bool]) -> Vec<RingOut> {
    g.rings
        .iter()
        .enumerate()
        .filter(|(ri, _)| arom[*ri])
        .map(|(_, r)| {
            let n = r.len();
            let nf = n as f64;
            let cx = r.iter().map(|&a| g.pos(a).0).sum::<f64>() / nf;
            let cy = r.iter().map(|&a| g.pos(a).1).sum::<f64>() / nf;
            // apothem (inscribed-circle radius): mean distance from the centroid to
            // the bond midpoints, so the GR-6 circle sits on the edges regardless of
            // ring size or slight irregularity.
            let rad = (0..n)
                .map(|k| {
                    let p = g.pos(r[k]);
                    let q = g.pos(r[(k + 1) % n]);
                    let (mx, my) = ((p.0 + q.0) / 2.0, (p.1 + q.1) / 2.0);
                    ((mx - cx).powi(2) + (my - cy).powi(2)).sqrt()
                })
                .sum::<f64>()
                / nf;
            RingOut {
                center: Vec2::new(cx, cy),
                radius: rad,
            }
        })
        .collect()
}

/// Hill-system molecular formula (GR-2.4): carbon first, hydrogen second, then
/// other elements alphabetically. Accurate for SMILES (one atom per node) and
/// for DSL fragments whose label is a simple element+count string.
fn molecular_formula(g: &Graph) -> Vec<(String, u32)> {
    use std::collections::BTreeMap;
    let mut counts: BTreeMap<String, u32> = BTreeMap::new();
    let mut add = |sym: &str, n: u32| {
        if n > 0 {
            *counts.entry(sym.to_string()).or_insert(0) += n;
        }
    };
    for i in 0..g.n() {
        let node = &g.nodes[i];
        match &node.text {
            // a multi-atom label (e.g. "CH3", "OH") already spells out its own
            // hydrogens, so parse them straight out of the text.
            Some(t) if t.chars().any(|c| c.is_ascii_uppercase()) && !t.contains(['(', '[']) => {
                for (sym, n) in parse_formula_atoms(t) {
                    add(&sym, n);
                }
            }
            // a bare vertex (skeletal carbon, or an unlabelled atom): its heavy
            // atom plus its hydrogen count (explicit or valence-derived).
            _ => {
                add(&node.element, 1);
                add("H", hydrogen_count(g, i) as u32);
            }
        }
    }
    // Hill order: C, H, then alphabetical
    let mut out = Vec::new();
    if let Some(&c) = counts.get("C") {
        out.push(("C".to_string(), c));
    }
    if let Some(&h) = counts.get("H") {
        out.push(("H".to_string(), h));
    }
    for (k, v) in &counts {
        if k != "C" && k != "H" {
            out.push((k.clone(), *v));
        }
    }
    out
}

/// Parse element symbols + subscripts from a simple condensed label like "CH3".
fn parse_formula_atoms(text: &str) -> Vec<(String, u32)> {
    let chars: Vec<char> = text.chars().collect();
    let mut out = Vec::new();
    let mut i = 0;
    while i < chars.len() {
        if chars[i].is_ascii_uppercase() {
            let mut sym = chars[i].to_string();
            i += 1;
            while i < chars.len() && chars[i].is_ascii_lowercase() {
                sym.push(chars[i]);
                i += 1;
            }
            let mut d = String::new();
            while i < chars.len() && chars[i].is_ascii_digit() {
                d.push(chars[i]);
                i += 1;
            }
            let n: u32 = d.parse().unwrap_or(1);
            out.push((sym, n));
        } else {
            i += 1;
        }
    }
    out
}

/// A ring is aromatic if every atom carries the aromatic flag (SMILES), or it is
/// an even ring with a perfect alternation of single/double bonds (Kekulé).
fn ring_is_aromatic(g: &Graph, ring: &[usize]) -> bool {
    if ring.len() >= 5 && ring.iter().all(|&a| g.nodes[a].aromatic) {
        return true;
    }
    let n = ring.len();
    if !n.is_multiple_of(2) {
        return false;
    }
    let orders: Vec<u8> = (0..n)
        .map(|i| {
            g.bond_between(ring[i], ring[(i + 1) % n])
                .map(|bi| g.bonds[bi].kind.order())
                .unwrap_or(1)
        })
        .collect();
    // perfectly alternating 1,2,1,2,... (either phase)
    let alt0 = (0..n).all(|i| orders[i] == if i % 2 == 0 { 1 } else { 2 });
    let alt1 = (0..n).all(|i| orders[i] == if i % 2 == 0 { 2 } else { 1 });
    alt0 || alt1
}

/// Unit directions toward each lone-pair group, placed into free angular gaps.
fn lone_pair_dirs(g: &Graph, i: usize, count: usize) -> Vec<Vec2> {
    use std::f64::consts::PI;
    if count == 0 {
        return Vec::new();
    }
    let p = g.pos(i);
    let mut occ: Vec<f64> = g.adj[i]
        .iter()
        .filter_map(|&(v, _)| {
            let q = g.nodes[v].pos.unwrap_or(p);
            let (dx, dy) = (q.0 - p.0, q.1 - p.1);
            (dx.abs() > 1e-8 || dy.abs() > 1e-8).then_some(dy.atan2(dx))
        })
        .collect();
    let angles: Vec<f64> = if occ.is_empty() {
        (0..count)
            .map(|k| PI / 2.0 + 2.0 * PI * k as f64 / count as f64)
            .collect()
    } else if occ.len() == 1 {
        let base = occ[0] + PI;
        if count == 1 {
            vec![base]
        } else {
            let span = 2.0 * PI / 3.0;
            (0..count)
                .map(|k| base - span / 2.0 + span * k as f64 / (count - 1).max(1) as f64)
                .collect()
        }
    } else {
        occ.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let (best_start, best_gap) = largest_gap(&occ);
        if count == 1 {
            vec![best_start + best_gap / 2.0]
        } else {
            let margin = (PI / 8.0).min(best_gap / 4.0);
            let usable = (best_gap - 2.0 * margin).max(best_gap * 0.5);
            (0..count)
                .map(|k| best_start + margin + usable * (k + 1) as f64 / (count + 1) as f64)
                .collect()
        }
    };
    angles
        .into_iter()
        .map(|a| Vec2::new(a.cos(), a.sin()))
        .collect()
}

/// Hydrogen count on atom `i`: an explicit count (from a label or SMILES) is
/// authoritative, otherwise it is derived from the valence.
fn hydrogen_count(g: &Graph, i: usize) -> u8 {
    if g.nodes[i].h_explicit {
        g.nodes[i].hcount
    } else {
        g.implicit_h(i)
    }
}

/// Hydrogens on a bare skeletal carbon (for the show-all-h option). Labeled
/// atoms already show their H, so they report 0.
fn implicit_h(g: &Graph, i: usize) -> u8 {
    if g.nodes[i].is_skeletal() {
        hydrogen_count(g, i)
    } else {
        0
    }
}

fn nonbonding_electrons(g: &Graph, i: usize) -> i16 {
    let node = &g.nodes[i];
    let Some(ve) = valence_electrons(&node.element) else {
        return 0;
    };
    (ve - node.charge as i16 - g.bond_order_sum(i) - hydrogen_count(g, i) as i16).max(0)
}

fn lone_pairs(g: &Graph, i: usize) -> u8 {
    (nonbonding_electrons(g, i) / 2) as u8
}

/// Unpaired electrons (GR-5.3): the odd remainder of the non-bonding pool.
/// Suppressed on aromatic atoms, where the Kekulé bond-order approximation
/// makes the parity unreliable (aromatic systems are closed-shell).
fn radical(g: &Graph, i: usize) -> u8 {
    if g.nodes[i].aromatic {
        return 0;
    }
    (nonbonding_electrons(g, i) % 2) as u8
}

/// Label orientation (GR-2.1.6). A label with bonds only on its right is
/// reversed ("H3C-", grows left, bonded atom anchored east); bonds only on the
/// left grow right (bonded atom anchored west); bonds on both sides (or none)
/// are centered.
fn label_dir(g: &Graph, i: usize) -> String {
    let p = g.pos(i);
    let mut left = false;
    let mut right = false;
    for &(v, _) in &g.adj[i] {
        let q = g.pos(v);
        if q.0 > p.0 + 0.1 {
            right = true;
        } else if q.0 < p.0 - 0.1 {
            left = true;
        }
    }
    if right && !left {
        "left".into() // reversed: H3C-
    } else if left && !right {
        "right".into() // normal: -OH
    } else {
        "center".into()
    }
}

fn bounds(g: &Graph) -> (Vec2, Vec2) {
    let mut lo = Vec2::new(f64::INFINITY, f64::INFINITY);
    let mut hi = Vec2::new(f64::NEG_INFINITY, f64::NEG_INFINITY);
    for i in 0..g.n() {
        let (x, y) = g.pos(i);
        lo.x = lo.x.min(x);
        lo.y = lo.y.min(y);
        hi.x = hi.x.max(x);
        hi.y = hi.y.max(y);
    }
    if !lo.x.is_finite() {
        lo = Vec2::default();
        hi = Vec2::default();
    }
    (lo, hi)
}
