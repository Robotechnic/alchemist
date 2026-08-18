// Shared drawing geometry for the chem renderer.
//
// Bonds get their label clearance from alchemist itself (the fragment margin of
// a placed fragment, see skeleton.typ), but the overlays in decorations.typ —
// hapto and variable-attachment lines — are raw cetz lines, so they trim
// themselves against the label box with the helpers below. The small coordinate
// helpers are shared by both files.

#import "@preview/cetz:0.5.2"
#import "../../utils/utils.typ": convert-length

// A `scale` option may be a length (e.g. `atom-sep`) or a plain canvas-unit
// number; resolve it to a float in canvas units.
#let resolve-scale(cetz-ctx, scale) = {
  if type(scale) == length { convert-length(cetz-ctx, scale) } else { scale }
}

// The CeTZ anchor name of engine atom `id` within molecule `name`.
#let atom-anchor(name, id) = name + "-a" + str(id)

// Scaled canvas position of a layout atom.
#let atom-pos(a, s) = (a.pos.x * s, a.pos.y * s)

// The label box of the atom drawn as group `name`, expressed relative to its
// coordinate (cx, cy) in canvas units. Works for any placed atom (a bare vertex
// resolves to a near-zero box, so it is simply not trimmed beyond the margin).
#let label-box(cetz-ctx, name, cx, cy) = {
  let (_, nw) = cetz.coordinate.resolve(cetz-ctx, (name: name, anchor: "north-west"))
  let (_, se) = cetz.coordinate.resolve(cetz-ctx, (name: name, anchor: "south-east"))
  (x0: nw.at(0) - cx, x1: se.at(0) - cx, y0: se.at(1) - cy, y1: nw.at(1) - cy)
}

// Distance from the coordinate to where the ray (ux, uy) leaves `box`, plus a
// uniform margin. `box == none` (an atom with no drawn label) means no trim.
#let box-trim(box, ux, uy, margin) = {
  if box == none { return 0 }
  let big = 1e6
  let tx = if ux > 1e-6 { box.x1 / ux } else if ux < -1e-6 { box.x0 / ux } else { big }
  let ty = if uy > 1e-6 { box.y1 / uy } else if uy < -1e-6 { box.y0 / uy } else { big }
  calc.min(tx, ty) + margin
}

// Control points of a curly (electron-pushing) arc from `a` toward `b`, bowed to
// one `side` (±1). The whole arc is offset perpendicular to the a→b line so it
// stays clear of the bond, and the head curves back in to point at the target.
// Returns (p0, p3, c1, c2) for a cubic bezier.
#let curly-arc(a, b, side, off, bend, pad) = {
  let dx = b.at(0) - a.at(0)
  let dy = b.at(1) - a.at(1)
  let len = calc.max(calc.sqrt(dx * dx + dy * dy), 1e-9)
  let (ux, uy) = (dx / len, dy / len)
  let (px, py) = (-uy * side, ux * side)
  let p0 = (a.at(0) + ux * pad + px * off, a.at(1) + uy * pad + py * off)
  let p3 = (b.at(0) - ux * pad * 0.2 + px * off * 0.55, b.at(1) - uy * pad * 0.2 + py * off * 0.55)
  let c1 = (p0.at(0) + ux * len * 0.2 + px * bend, p0.at(1) + uy * len * 0.2 + py * bend)
  let c2 = (p3.at(0) + px * bend, p3.at(1) + py * bend)
  (p0, p3, c1, c2)
}
