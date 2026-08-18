//! Ring-derived render hints on the rings CoordgenLibs perceived (double-bond
//! sides, aromatic-circle geometry). Ring perception itself lives in coordgen.

use std::f64::consts::PI;

use super::Pt;
use crate::graph::Graph;

pub fn tag_ring_membership(g: &mut Graph) {
    let rings = g.rings.clone();
    for (ri, ring) in rings.iter().enumerate() {
        for &a in ring {
            if !g.nodes[a].ring_ids.contains(&ri) {
                g.nodes[a].ring_ids.push(ri);
            }
        }
        for i in 0..ring.len() {
            let a = ring[i];
            let b = ring[(i + 1) % ring.len()];
            if let Some(bi) = g.bond_between(a, b) {
                if !g.bonds[bi].ring_ids.contains(&ri) {
                    g.bonds[bi].ring_ids.push(ri);
                }
            }
        }
    }
}

// ── ring geometry ────────────────────────────────────────────────────────────

pub(crate) fn ring_has_edge(ring: &[usize], a: usize, b: usize) -> bool {
    (0..ring.len()).any(|i| {
        let x = ring[i];
        let y = ring[(i + 1) % ring.len()];
        (x == a && y == b) || (x == b && y == a)
    })
}
pub fn largest_gap(sorted: &[f64]) -> (f64, f64) {
    let mut best_start = sorted[0];
    let mut best = 0.0;
    for i in 0..sorted.len() {
        let s = sorted[i];
        let e = if i + 1 < sorted.len() {
            sorted[i + 1]
        } else {
            sorted[0] + 2.0 * PI
        };
        if e - s > best {
            best = e - s;
            best_start = s;
        }
    }
    (best_start, best)
}

// ── ring-inner directions (double-bond side, GR-1.10) ────────────────────────

pub fn ring_inner_dirs(g: &Graph, coords: &[Pt]) -> Vec<(f64, f64)> {
    let mut dirs = vec![(0.0, 0.0); g.bonds.len()];
    for (bi, b) in g.bonds.iter().enumerate() {
        if b.kind.order() != 2 {
            continue;
        }
        // GR-1.10: ring double bonds offset toward the ring centroid (the inner
        // line sits inside the ring). Acyclic double bonds are drawn symmetric
        // (inner = 0), matching the ChemDraw default — both lines equidistant from
        // the bond axis, so the bond reads as centred rather than shifted.
        if let Some(ring) = best_ring_for_bond(g, b.a, b.b) {
            let mid = (
                (coords[b.a].0 + coords[b.b].0) / 2.0,
                (coords[b.a].1 + coords[b.b].1) / 2.0,
            );
            // unit vector from the bond midpoint toward the ring centroid
            dirs[bi] = super::unit(super::centroid(coords, ring), mid);
        }
    }
    dirs
}

fn best_ring_for_bond(g: &Graph, a: usize, b: usize) -> Option<&Vec<usize>> {
    g.rings
        .iter()
        .filter(|r| ring_has_edge(r, a, b))
        .max_by(|x, y| {
            unsat(g, x)
                .cmp(&unsat(g, y))
                .then_with(|| y.len().cmp(&x.len()))
        })
}

fn unsat(g: &Graph, ring: &[usize]) -> usize {
    (0..ring.len())
        .filter_map(|i| g.bond_between(ring[i], ring[(i + 1) % ring.len()]))
        .filter(|&bi| g.bonds[bi].kind.order() == 2)
        .count()
}
