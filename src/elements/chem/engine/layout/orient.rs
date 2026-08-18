//! IUPAC canonical orientation (Brecher 2008, GR-3.1).
//!
//! GR-3.1.1 structures horizontal; GR-3.1.2 principal characteristic group to
//! the right. We approximate the principal axis by the farthest-apart pair of
//! vertices and rotate it onto the x-axis, then mirror so the highest-priority
//! functional group sits on the right.

use super::{center, centroid, rotate, Pt};
use crate::graph::Graph;

pub fn orient(g: &Graph, coords: &mut [Pt]) {
    if coords.len() < 2 {
        center(coords);
        return;
    }
    center(coords);
    let pg = principal_group(g);
    let pring = principal_ring_atoms(g);

    // GR-3.1.2/3.1.3: rotate so the principal group points to the right (and,
    // for ring systems, the ring ends up on the opposite/left side). With no
    // characteristic group to steer by, rest the principal ring system flat on a
    // horizontal edge (GR-3.3.1 — works for single *and* fused rings, so
    // naphthalene et al. sit horizontally); acyclic molecules fall back to the
    // longest-axis heuristic.
    if !rotate_principal_group_right(g, coords, pg) {
        if !pring.is_empty() {
            orient_ring_system_flat(g, &pring, coords);
        } else {
            rotate_principal_axis(coords);
        }
    }

    // Choose the best of the four axis-preserving reflections by a weighted
    // score that encodes the IUPAC priority:
    //   GR-3.1.2 principal group to the right   (highest)
    //   GR-3.2.2 branching double bonds upward
    //   GR-3.1.3 principal ring system bottom-left  ("absent an overriding concern")
    let mut best = (f64::NEG_INFINITY, 1.0, 1.0);
    for &fx in &[1.0, -1.0] {
        for &fy in &[1.0, -1.0] {
            let s = score(g, coords, pg, &pring, fx, fy);
            if s > best.0 {
                best = (s, fx, fy);
            }
        }
    }
    for p in coords.iter_mut() {
        p.0 *= best.1;
        p.1 *= best.2;
    }
    center(coords);
}

/// Atoms of the principal (largest fused) ring system: connected components of
/// ring atoms joined only by ring bonds, so biaryls (e.g. phenyl–naphthalene)
/// count as separate systems and the larger one wins.
fn principal_ring_atoms(g: &Graph) -> Vec<usize> {
    let is_ring = |i: usize| !g.nodes[i].ring_ids.is_empty();
    let n = g.n();
    let mut seen = vec![false; n];
    let mut best: Vec<usize> = Vec::new();
    for start in 0..n {
        if seen[start] || !is_ring(start) {
            continue;
        }
        let mut comp = Vec::new();
        let mut stack = vec![start];
        seen[start] = true;
        while let Some(u) = stack.pop() {
            comp.push(u);
            for &(v, bi) in &g.adj[u] {
                if is_ring(v) && !seen[v] && !g.bonds[bi].ring_ids.is_empty() {
                    seen[v] = true;
                    stack.push(v);
                }
            }
        }
        if comp.len() > best.len() {
            best = comp;
        }
    }
    best
}

fn score(g: &Graph, coords: &[Pt], pg: Option<usize>, pring: &[usize], fx: f64, fy: f64) -> f64 {
    let at = |i: usize| (coords[i].0 * fx, coords[i].1 * fy);
    let mut s = 0.0;

    // GR-3.1.2: principal group toward the right (weight 1000)
    if let Some(p) = pg {
        s += 1000.0 * at(p).0;
    }

    // GR-3.2.2: branching double bonds (terminal =O/=N/=CH2) upward (weight 100)
    let mut cu = 0.0;
    for b in &g.bonds {
        if b.kind.order() != 2 {
            continue;
        }
        let (term, anchor) = if g.adj[b.a].len() == 1 {
            (b.a, b.b)
        } else if g.adj[b.b].len() == 1 {
            (b.b, b.a)
        } else {
            continue;
        };
        cu += at(term).1 - at(anchor).1;
    }
    s += 100.0 * cu;

    // GR-3.1.3: principal ring system toward the bottom-left (weight 10)
    if !pring.is_empty() {
        let n = pring.len() as f64;
        let rx = pring.iter().map(|&i| at(i).0).sum::<f64>() / n;
        let ry = pring.iter().map(|&i| at(i).1).sum::<f64>() / n;
        s += 10.0 * (-rx - ry); // smaller x and y (bottom-left) scores higher
    }

    s
}

/// For ring systems, rotate so the bond carrying the principal group out of the
/// ring lies along +x — putting the principal group on the right (GR-3.1.2) and
/// the ring on the left (GR-3.1.3). Acyclic molecules return false so the caller
/// keeps the longest-axis heuristic (+ reflection scoring) that already works.
fn rotate_principal_group_right(g: &Graph, coords: &mut [Pt], pg: Option<usize>) -> bool {
    let Some(p) = pg else { return false };
    let is_ring = |i: usize| !g.nodes[i].ring_ids.is_empty();
    if !(0..g.n()).any(is_ring) {
        return false;
    }
    // axis = the ring→substituent bond on the path to the principal group; if the
    // group atom is itself in the ring, use ring-centroid → that atom.
    let axis = if is_ring(p) {
        let ring: Vec<usize> = (0..g.n()).filter(|&i| is_ring(i)).collect();
        let (cx, cy) = centroid(coords, &ring);
        Some((coords[p].0 - cx, coords[p].1 - cy))
    } else {
        // BFS from pg until a ring atom; the bond (ring atom → its predecessor)
        // is the substituent stem.
        let mut prev = vec![usize::MAX; g.n()];
        let mut seen = vec![false; g.n()];
        let mut q = std::collections::VecDeque::new();
        seen[p] = true;
        q.push_back(p);
        let mut stem = None;
        while let Some(u) = q.pop_front() {
            if is_ring(u) {
                let s = prev[u];
                stem = Some((coords[s].0 - coords[u].0, coords[s].1 - coords[u].1));
                break;
            }
            for &(v, _) in &g.adj[u] {
                if !seen[v] {
                    seen[v] = true;
                    prev[v] = u;
                    q.push_back(v);
                }
            }
        }
        stem
    };
    let Some((vx, vy)) = axis else { return false };
    if vx * vx + vy * vy < 0.04 {
        return false;
    }
    rotate(coords, -vy.atan2(vx));
    true
}

/// GR-3.3.1: rest a ring system flat on a horizontal edge. Over every ring bond
/// of the principal ring system, find the one whose midpoint points most nearly
/// straight down from the system centroid and rotate it to exactly straight down,
/// so the shared long axis of a fused system (naphthalene, indole, …) ends up
/// horizontal and each hexagon has a flat top and bottom.
fn orient_ring_system_flat(g: &Graph, ring_atoms: &[usize], coords: &mut [Pt]) {
    use std::f64::consts::PI;
    if ring_atoms.is_empty() {
        return;
    }
    let inset: std::collections::HashSet<usize> = ring_atoms.iter().copied().collect();
    let (cx, cy) = centroid(coords, ring_atoms);
    let mut best_ang = 0.0;
    let mut best_cos = f64::NEG_INFINITY;
    for b in &g.bonds {
        if b.ring_ids.is_empty() || !inset.contains(&b.a) || !inset.contains(&b.b) {
            continue;
        }
        let mx = (coords[b.a].0 + coords[b.b].0) / 2.0 - cx;
        let my = (coords[b.a].1 + coords[b.b].1) / 2.0 - cy;
        // closeness to straight-down (-π/2): maximise cos(ang - (-π/2))
        let ang = my.atan2(mx);
        let c = (ang + PI / 2.0).cos();
        if c > best_cos {
            best_cos = c;
            best_ang = ang;
        }
    }
    rotate(coords, -PI / 2.0 - best_ang);
}

fn rotate_principal_axis(coords: &mut [Pt]) {
    // farthest-apart pair = principal axis
    let mut best = (0usize, 0usize, 0.0f64);
    for i in 0..coords.len() {
        for j in (i + 1)..coords.len() {
            let d = (coords[i].0 - coords[j].0).powi(2) + (coords[i].1 - coords[j].1).powi(2);
            if d > best.2 {
                best = (i, j, d);
            }
        }
    }
    let (i, j, _) = best;
    rotate(
        coords,
        -(coords[j].1 - coords[i].1).atan2(coords[j].0 - coords[i].0),
    );
}

/// The vertex of the most senior characteristic group (GR-3.1.2). Seniority is
/// inferred from the local environment so carboxyl/ester rank above carbonyl,
/// which ranks above hydroxyl/amide/amine/halide.
fn principal_group(g: &Graph) -> Option<usize> {
    let mut best: Option<(i32, usize)> = None;
    for i in 0..g.n() {
        let s = seniority(g, i);
        if s > 0 && best.map(|(b, _)| s > b).unwrap_or(true) {
            best = Some((s, i));
        }
    }
    best.map(|(_, i)| i)
}

/// Characteristic-group seniority of the heteroatom at `i` (0 if not one).
fn seniority(g: &Graph, i: usize) -> i32 {
    let elem = g.nodes[i].element.as_str();
    let carbon_with = |c: usize, want_order: u8| -> bool {
        g.adj[c]
            .iter()
            .any(|&(o, bo)| g.nodes[o].element == "O" && g.bonds[bo].kind.order() == want_order)
    };
    match elem {
        "O" => {
            let mut s = 55; // ether/hydroxyl baseline
            for &(c, bi) in &g.adj[i] {
                if g.nodes[c].element != "C" {
                    continue;
                }
                let dbl = carbon_with(c, 2);
                let sgl = g.adj[c].iter().any(|&(o, bo)| {
                    o != i && g.nodes[o].element == "O" && g.bonds[bo].kind.order() == 1
                }) || (g.bonds[bi].kind.order() == 1 && dbl);
                if dbl && sgl {
                    // carboxylic acid (–C(=O)OH) outranks ester (–C(=O)O–C):
                    // an ester's single-bonded O bridges to a second carbon.
                    let ester = g.adj[c].iter().any(|&(o, bo)| {
                        g.nodes[o].element == "O"
                            && g.bonds[bo].kind.order() == 1
                            && g.adj[o]
                                .iter()
                                .any(|&(o2, _)| o2 != c && g.nodes[o2].element == "C")
                    });
                    s = s.max(if ester { 90 } else { 100 });
                } else if g.bonds[bi].kind.order() == 2 {
                    s = s.max(70); // ketone / aldehyde carbonyl
                } else {
                    s = s.max(60); // hydroxyl
                }
            }
            s
        }
        "N" => {
            // amide N sits next to a carbonyl carbon
            let amide = g.adj[i]
                .iter()
                .any(|&(c, _)| g.nodes[c].element == "C" && carbon_with(c, 2));
            if amide {
                50
            } else {
                40
            }
        }
        "S" | "P" => 35,
        "F" | "Cl" | "Br" | "I" => 20,
        _ => 0,
    }
}
