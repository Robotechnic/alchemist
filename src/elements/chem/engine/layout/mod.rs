//! 2D coordinate layout on top of externally-supplied (CoordgenLibs) coordinates
//! and rings. CoordGen owns the hard geometry *and* ring perception (SSSR); this
//! module owns the ring-derived render hints (GR double-bond sides), the IUPAC
//! GR-3 orientation pass, and stereo.

mod orient;
pub(crate) mod rings;
mod stereo;

use crate::graph::Graph;

pub type Pt = (f64, f64);

/// Layout from externally-supplied coordinates (e.g. CoordgenLibs): perceive
/// rings (needed by the renderer for double-bond sides / aromatic / labels),
/// normalise the scale to unit bond length, then apply alchemist's IUPAC
/// canonical orientation and stereo decoration. The coordinate engine owns the
/// hard geometry; alchemist owns ring perception, orientation and rendering.
pub fn from_coords(g: &mut Graph, raw: &[Pt], rings: Vec<Vec<usize>>, iupac: bool, rotation: f64) {
    let n = g.n();
    if n == 0 || raw.len() != n {
        return;
    }
    // rings are perceived by coordgen and passed in, so we don't re-run SSSR.
    g.rings = rings;
    rings::tag_ring_membership(g);

    // normalise to unit mean bond length (coordgen draws at ~50 units/bond)
    let mut coords: Vec<Pt> = raw.to_vec();
    let (mut sum, mut cnt) = (0.0, 0u32);
    for b in &g.bonds {
        let d = dist(coords[b.a], coords[b.b]);
        if d > 1e-9 {
            sum += d;
            cnt += 1;
        }
    }
    if cnt > 0 {
        let s = sum / cnt as f64;
        if s > 1e-9 {
            for p in coords.iter_mut() {
                p.0 /= s;
                p.1 /= s;
            }
        }
    }

    // Disconnected fragments (salts, `.` in SMILES) come out of coordgen spaced
    // far apart — and with no bond to normalise against, isolated ions keep raw
    // engine units. Pack the connected components side by side at a fixed gap.
    pack_components(g, &mut coords);

    // cis/trans (E/Z): coordgen lays out ignorant of our SMILES / \ markers, so
    // reflect double-bond subtrees to the configured side (angle-preserving).
    stereo::apply_cis_trans(g, &mut coords);

    if iupac {
        orient::orient(g, &mut coords);
    } else {
        center(&mut coords);
    }
    if rotation != 0.0 {
        rotate(&mut coords, rotation);
    }
    for i in 0..n {
        g.nodes[i].pos = Some(coords[i]);
    }
    stereo::apply(g);
}

// ── small geometry helpers shared across submodules ──────────────────────────

/// Per-bond unit vector toward the ring centroid (double-bond side, GR-1.10).
pub fn ring_inner_dirs(g: &Graph) -> Vec<(f64, f64)> {
    let coords: Vec<Pt> = g
        .nodes
        .iter()
        .map(|n| n.pos.unwrap_or((0.0, 0.0)))
        .collect();
    rings::ring_inner_dirs(g, &coords)
}

/// Re-pack disconnected connected-components left-to-right with a fixed gap, so
/// salts / ion pairs sit next to each other instead of at coordgen's wide
/// default separation. Each component keeps its own internal geometry.
fn pack_components(g: &Graph, coords: &mut [Pt]) {
    const GAP: f64 = 1.6;
    let n = coords.len();
    let mut comp = vec![usize::MAX; n];
    let mut ncomp = 0usize;
    for s in 0..n {
        if comp[s] != usize::MAX {
            continue;
        }
        let mut stack = vec![s];
        comp[s] = ncomp;
        while let Some(u) = stack.pop() {
            for &(v, _) in &g.adj[u] {
                if comp[v] == usize::MAX {
                    comp[v] = ncomp;
                    stack.push(v);
                }
            }
        }
        ncomp += 1;
    }
    if ncomp <= 1 {
        return;
    }
    let mut cursor = 0.0;
    for c in 0..ncomp {
        let idxs: Vec<usize> = (0..n).filter(|&i| comp[i] == c).collect();
        let minx = idxs
            .iter()
            .map(|&i| coords[i].0)
            .fold(f64::INFINITY, f64::min);
        let maxx = idxs
            .iter()
            .map(|&i| coords[i].0)
            .fold(f64::NEG_INFINITY, f64::max);
        let cy = idxs.iter().map(|&i| coords[i].1).sum::<f64>() / idxs.len() as f64;
        let dx = cursor - minx;
        for &i in &idxs {
            coords[i].0 += dx;
            coords[i].1 -= cy;
        }
        cursor += (maxx - minx) + GAP;
    }
}

pub fn dist(a: Pt, b: Pt) -> f64 {
    ((a.0 - b.0).powi(2) + (a.1 - b.1).powi(2)).sqrt()
}

/// Unit vector from `o` toward `p` (returns the raw delta if `p == o`).
pub(crate) fn unit(p: Pt, o: Pt) -> Pt {
    let (dx, dy) = (p.0 - o.0, p.1 - o.1);
    let l = (dx * dx + dy * dy).sqrt();
    if l > 1e-12 {
        (dx / l, dy / l)
    } else {
        (dx, dy)
    }
}

/// Angle (radians) of the vector from `o` toward `p`.
pub(crate) fn angle(p: Pt, o: Pt) -> f64 {
    (p.1 - o.1).atan2(p.0 - o.0)
}

/// Mean position of the given atom indices.
pub(crate) fn centroid(coords: &[Pt], atoms: &[usize]) -> Pt {
    let n = atoms.len().max(1) as f64;
    (
        atoms.iter().map(|&i| coords[i].0).sum::<f64>() / n,
        atoms.iter().map(|&i| coords[i].1).sum::<f64>() / n,
    )
}

pub(crate) fn center(coords: &mut [Pt]) {
    if coords.is_empty() {
        return;
    }
    let (cx, cy) = centroid(coords, &(0..coords.len()).collect::<Vec<_>>());
    for p in coords.iter_mut() {
        p.0 -= cx;
        p.1 -= cy;
    }
}

/// Rotate all coordinates about the origin by `angle` (radians, CCW).
pub(crate) fn rotate(coords: &mut [Pt], angle: f64) {
    let (s, c) = angle.sin_cos();
    for p in coords.iter_mut() {
        *p = (p.0 * c - p.1 * s, p.0 * s + p.1 * c);
    }
}
