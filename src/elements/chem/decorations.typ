// Non-bond GR decorations drawn as an overlay on top of the shared skeleton
// (skeleton.typ). Everything here is a pure coordinate overlay that has no
// counterpart in alchemist's link/fragment drawing: ionic dotted bonds, brackets,
// aromatic circles, electron-pushing arrows, partial/oxidation charges, and
// hapto / variable-attachment lines. Bonds themselves — including the special
// styles (delocalized, bent, wavy) — are all drawn by skeleton.typ, at the shared
// `bond-stroke` weight, so nothing here re-draws or re-weights a bond.

#import "@preview/cetz:0.5.2"
#import cetz.draw: *
#import "../../utils/utils.typ": convert-length
#import "style.typ": chem-defaults
#import "geometry.typ": atom-anchor, atom-pos, box-trim, curly-arc, label-box, resolve-scale

#let draw-decorations(layout, name: "mol", config: (:)) = {
  let cfg = chem-defaults + config
  get-ctx(ctx => {
  let s = resolve-scale(ctx, cfg.scale)
  let stroke = cfg.stroke
  let margin = convert-length(ctx, cfg.label-clearance)
  let P(i) = atom-pos(layout.atoms.at(i), s)
  // start point of a line leaving atom `from` toward (tx, ty), pulled back to
  // clear `from`'s label — same rule the bonds use, so overlay lines never run
  // into a glyph.
  let from-edge(from, tx, ty) = {
    let a = P(from)
    let (dx, dy) = (tx - a.at(0), ty - a.at(1))
    let len = calc.max(calc.sqrt(dx * dx + dy * dy), 1e-9)
    let t = box-trim(label-box(ctx, atom-anchor(name, from), a.at(0), a.at(1)), dx / len, dy / len, margin)
    (a.at(0) + dx / len * t, a.at(1) + dy / len * t)
  }

  // ── GR-7.1 ionic dotted bonds between disconnected components ──────────────
  if cfg.ionic-bonds {
    let n = layout.atoms.len()
    let parent = range(n)
    let find(x) = {
      let r = x
      while parent.at(r) != r { r = parent.at(r) }
      r
    }
    for b in layout.bonds {
      let ra = find(b.from)
      let rb = find(b.to)
      if ra != rb { parent.at(ra) = rb }
    }
    let comp = range(n).map(find)
    let roots = comp.dedup()
    for i in range(roots.len()) {
      for j in range(i + 1, roots.len()) {
        let (ra, rb) = (roots.at(i), roots.at(j))
        let best = none
        for x in range(n) {
          if comp.at(x) != ra { continue }
          for y in range(n) {
            if comp.at(y) != rb { continue }
            let px = P(x)
            let py = P(y)
            let d = (px.at(0) - py.at(0)) * (px.at(0) - py.at(0)) + (px.at(1) - py.at(1)) * (px.at(1) - py.at(1))
            if best == none or d < best.at(0) { best = (d, x, y) }
          }
        }
        if best != none {
          line(P(best.at(1)), P(best.at(2)), stroke: (paint: gray, thickness: stroke.thickness, dash: "dotted"))
        }
      }
    }
  }

  // ── GR-9.4 variable attachment (bond into a ring centre) ───────────────────
  for (from, ring-ids) in cfg.variable-attach {
    let nn = ring-ids.len()
    let cx = ring-ids.map(i => P(i).at(0)).sum() / nn
    let cy = ring-ids.map(i => P(i).at(1)).sum() / nn
    let a = P(from)
    let f = cfg.attach-fraction
    let end = (a.at(0) + (cx - a.at(0)) * f, a.at(1) + (cy - a.at(1)) * f)
    line(from-edge(from, cx, cy), end, stroke: stroke)
  }

  // ── GR-1.9 multi-centre (hapto / η) bond to a centroid ─────────────────────
  for (from, ids) in cfg.multi-centre {
    let nn = ids.len()
    let cx = ids.map(i => P(i).at(0)).sum() / nn
    let cy = ids.map(i => P(i).at(1)).sum() / nn
    line(from-edge(from, cx, cy), (cx, cy), stroke: stroke)
  }

  // ── GR-6 aromatic delocalization circles ──────────────────────────────────
  if cfg.aromatic == "circle" {
    for ring in layout.at("aromatic_rings", default: ()) {
      circle((ring.center.x * s, ring.center.y * s), radius: ring.radius * s * cfg.aromatic-inset, stroke: stroke)
    }
  }

  // ── GR-5.6 partial charges (δ+/δ-) ─────────────────────────────────────────
  for (id, sign) in cfg.partial-charge {
    let a = P(int(id))
    let sg = if sign == "+" { "+" } else { "−" }
    content((a.at(0), a.at(1) + cfg.charge-rise * s), text(size: cfg.script-size * 1.1, [δ] + super(size: cfg.script-size, sg)))
  }

  // ── electron-pushing curly arrows (addressed by atom id) ───────────────────
  for arr in cfg.arrows {
    let side = if arr.len() > 2 { arr.at(2) } else { 1 }
    let (p0, p3, c1, c2) = curly-arc(P(arr.at(0)), P(arr.at(1)), side, cfg.arrow.offset * s, cfg.arrow.bend * s, cfg.arrow.pad * s)
    bezier(p0, p3, c1, c2, stroke: (paint: cfg.arrow.paint, thickness: stroke.thickness), mark: (end: ">", scale: 0.85))
  }

  // ── GR-5.7 enclose a polyatomic ion in brackets ───────────────────────────
  if cfg.brackets != none {
    let xs = layout.atoms.map(a => a.pos.x * s)
    let ys = layout.atoms.map(a => a.pos.y * s)
    let pad = cfg.bracket-pad * s
    let (x0, x1) = (calc.min(..xs) - pad, calc.max(..xs) + pad)
    let (y0, y1) = (calc.min(..ys) - pad, calc.max(..ys) + pad)
    let tick = cfg.bracket-tick * s
    line((x0 + tick, y1), (x0, y1), (x0, y0), (x0 + tick, y0), stroke: stroke)
    line((x1 - tick, y1), (x1, y1), (x1, y0), (x1 - tick, y0), stroke: stroke)
    let q = cfg.brackets
    if q != 0 {
      let m = calc.abs(q)
      let sg = if q > 0 { "+" } else { "−" }
      content((x1 + tick / 2, y1), text(super(size: cfg.script-size, (if m > 1 { str(m) } else { "" }) + sg)), anchor: "south-west")
    }
  }
  })
}
