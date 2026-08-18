//! Tetrahedral stereochemistry: @/@@ -> wedge/hash bond on one substituent.
//!
//! Picks wedge vs. hash from the signed volume of the four neighbor directions
//! (OpenSMILES order) so the depicted 3D structure reproduces the requested
//! chirality. `@` wants a negative signed volume, `@@` a positive one.

use super::Pt;
use crate::graph::{BondKind, Graph};

// ── cis/trans (E/Z) geometry from SMILES / \ markers ─────────────────────────

/// Reflect double-bond substituent subtrees so `/` and `\` markers place each
/// substituent on the requested side of the double bond (port of typed-smiles).
pub fn apply_cis_trans(g: &Graph, coords: &mut [Pt]) {
    for db in &g.bonds {
        if db.kind != BondKind::Double {
            continue;
        }
        let left = directional_neighbor(g, db.a, db.b);
        let right = directional_neighbor(g, db.b, db.a);
        if let (Some(l), Some(r)) = (left, right) {
            let af = coords[db.a];
            let at = coords[db.b];
            orient_subtree(g, coords, l.0, db.a, db.b, af, at, l.1);
            orient_subtree(g, coords, r.0, db.b, db.a, af, at, r.1);
        }
    }
}

/// (neighbor, side) of a directional single bond at `center`, excluding `partner`.
fn directional_neighbor(g: &Graph, center: usize, partner: usize) -> Option<(usize, i8)> {
    let mut found = None;
    for &(nb, bi) in &g.adj[center] {
        if nb == partner {
            continue;
        }
        let b = &g.bonds[bi];
        if b.direction == 0 {
            continue;
        }
        let side = if b.a == center {
            b.direction
        } else {
            -b.direction
        };
        if found.is_some() {
            return None; // ambiguous
        }
        found = Some((nb, side));
    }
    found
}

fn orient_subtree(
    g: &Graph,
    coords: &mut [Pt],
    root: usize,
    parent: usize,
    blocked: usize,
    af: Pt,
    at: Pt,
    desired: i8,
) {
    let cur = side_of_point(af, at, coords[root]);
    if cur == 0 || cur == desired {
        return;
    }
    for atom in collect_subtree(g, root, parent, blocked) {
        coords[atom] = reflect_across_line(coords[atom], af, at);
    }
}

fn side_of_point(a: Pt, b: Pt, p: Pt) -> i8 {
    let cross = (b.0 - a.0) * (p.1 - a.1) - (b.1 - a.1) * (p.0 - a.0);
    if cross > 1e-8 {
        1
    } else if cross < -1e-8 {
        -1
    } else {
        0
    }
}

fn reflect_across_line(p: Pt, a: Pt, b: Pt) -> Pt {
    let (dx, dy) = (b.0 - a.0, b.1 - a.1);
    let len2 = dx * dx + dy * dy;
    if len2 < 1e-10 {
        return p;
    }
    let t = ((p.0 - a.0) * dx + (p.1 - a.1) * dy) / len2;
    let proj = (a.0 + t * dx, a.1 + t * dy);
    (2.0 * proj.0 - p.0, 2.0 * proj.1 - p.1)
}

fn collect_subtree(g: &Graph, root: usize, parent: usize, blocked: usize) -> Vec<usize> {
    let mut seen = vec![false; g.n()];
    seen[parent] = true;
    seen[blocked] = true;
    seen[root] = true;
    let mut stack = vec![root];
    let mut out = Vec::new();
    while let Some(a) = stack.pop() {
        out.push(a);
        for &(nb, _) in &g.adj[a] {
            if !seen[nb] {
                seen[nb] = true;
                stack.push(nb);
            }
        }
    }
    out
}

// ── tetrahedral wedge/hash ───────────────────────────────────────────────────

pub fn apply(g: &mut Graph) {
    let n = g.n();
    for c in 0..n {
        let parity = match g.nodes[c].chirality {
            -1 => -1.0, // @
            1 => 1.0,   // @@
            _ => continue,
        };
        if let Some((bond_idx, swap, stereo)) = wedge_for_center(g, c, parity) {
            if swap {
                let b = &mut g.bonds[bond_idx];
                std::mem::swap(&mut b.a, &mut b.b);
            }
            g.bonds[bond_idx].kind = stereo;
        }
    }
}

fn wedge_for_center(g: &Graph, c: usize, parity: f64) -> Option<(usize, bool, BondKind)> {
    // neighbor bonds in SMILES writing order
    let nbonds: Vec<usize> = g
        .bonds
        .iter()
        .enumerate()
        .filter(|(_, b)| b.a == c || b.b == c)
        .map(|(i, _)| i)
        .collect();
    let n_h = g.nodes[c].hcount as usize;
    if nbonds.len() + n_h != 4 || n_h > 1 {
        return None; // only clean 4-coordinate centers with <=1 H
    }

    // build the ordered neighbor slots (Some(other_atom) or None=implicit H)
    let mut slots: Vec<Option<usize>> = nbonds
        .iter()
        .map(|&bi| {
            let b = &g.bonds[bi];
            Some(if b.a == c { b.b } else { b.a })
        })
        .collect();
    if n_h == 1 {
        let pos = if g.nodes[c].preceding { 1 } else { 0 };
        slots.insert(pos.min(slots.len()), None);
    }

    let cpos = g.nodes[c].pos?;
    let h_dir = implicit_h_dir(g, c, cpos);

    // choose the out-of-plane neighbor: prefer an exocyclic visible substituent
    let chosen_bond = pick_substituent(g, c, &nbonds);
    let out_idx = match chosen_bond {
        Some(bi) => {
            let other = {
                let b = &g.bonds[bi];
                if b.a == c {
                    b.b
                } else {
                    b.a
                }
            };
            slots.iter().position(|s| *s == Some(other))?
        }
        None => slots.iter().position(|s| s.is_none())?,
    };

    // trial geometry: out-of-plane neighbor toward viewer (z=+1), an undrawn
    // implicit H on the far side (z=-1), the rest in plane (z=0).
    let mut d = [[0.0f64; 3]; 4];
    for (i, slot) in slots.iter().enumerate() {
        d[i] = if i == out_idx {
            let dir = match slot {
                Some(o) => super::unit(g.nodes[*o].pos.unwrap(), cpos),
                None => h_dir,
            };
            [dir.0, dir.1, 1.0]
        } else {
            match slot {
                Some(o) => {
                    let dir = super::unit(g.nodes[*o].pos.unwrap(), cpos);
                    [dir.0, dir.1, 0.0]
                }
                None => [h_dir.0, h_dir.1, -1.0],
            }
        };
    }

    let vol = signed_volume(&d);
    if vol.abs() < 1e-9 {
        return None;
    }
    let stereo = if vol.signum() == parity {
        BondKind::CramFilledRight // wedge up
    } else {
        BondKind::CramDashedRight // hash down
    };
    match chosen_bond {
        Some(bi) => {
            let swap = g.bonds[bi].a != c; // ensure narrow tip at the stereocenter
            Some((bi, swap, stereo))
        }
        None => None, // implicit-H-only wedge: skip (no bond to decorate) for M5
    }
}

/// Prefer an exocyclic, visible, terminal single-bond neighbor to draw wedged.
fn pick_substituent(g: &Graph, c: usize, nbonds: &[usize]) -> Option<usize> {
    let mut best: Option<(usize, i32)> = None;
    for &bi in nbonds {
        let b = &g.bonds[bi];
        if b.kind.order() != 1 {
            continue;
        }
        let other = if b.a == c { b.b } else { b.a };
        let mut score = 0;
        if b.ring_ids.is_empty() {
            score += 100;
        } else {
            score -= 100;
        }
        if g.nodes[other].text.is_some() {
            score += 50; // visible (heteroatom-bearing) label
        }
        if g.adj[other].len() == 1 {
            score += 10; // terminal
        }
        if best.map(|(_, s)| score > s).unwrap_or(true) {
            best = Some((bi, score));
        }
    }
    best.and_then(|(bi, s)| if s > 0 { Some(bi) } else { None })
}

fn implicit_h_dir(g: &Graph, c: usize, cpos: (f64, f64)) -> (f64, f64) {
    let mut occ: Vec<f64> = g.adj[c]
        .iter()
        .map(|&(v, _)| super::angle(g.nodes[v].pos.unwrap_or(cpos), cpos))
        .collect();
    if occ.is_empty() {
        return (0.0, -1.0);
    }
    occ.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let (start, gap) = super::rings::largest_gap(&occ);
    let a = start + gap / 2.0;
    (a.cos(), a.sin())
}

fn signed_volume(d: &[[f64; 3]; 4]) -> f64 {
    let a = [d[1][0] - d[0][0], d[1][1] - d[0][1], d[1][2] - d[0][2]];
    let b = [d[2][0] - d[0][0], d[2][1] - d[0][1], d[2][2] - d[0][2]];
    let c = [d[3][0] - d[0][0], d[3][1] - d[0][1], d[3][2] - d[0][2]];
    a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0])
        + a[2] * (b[0] * c[1] - b[1] * c[0])
}
