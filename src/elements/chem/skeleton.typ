// Coordinate renderer built on alchemist's own element pipeline.
//
// LayoutOut (from the WASM engine) is turned into *native alchemist elements* —
// one `place` per atom at its absolute coordinate, and one cross-link per bond —
// which `draw-skeleton` then draws. So the engine only supplies coordinates:
// fragment text, lone pairs, link geometry, label margins and Cetz anchors all
// come from alchemist itself, and a generated molecule is indistinguishable from
// a hand-drawn one as far as anchors and configuration are concerned.

#import "@preview/cetz:0.5.2"
#import "../../drawer.typ": draw-skeleton
#import "../../default.typ": default
#import "../../utils/utils.typ": convert-length
#import "../../elements/links.typ" as links
#import "../../elements/lewis.typ": lewis-double, lewis-line, lewis-single
#import "labels.typ": element-color, element-groups, format-label, group-math
#import "style.typ": chem-defaults
#import "geometry.typ": atom-anchor, atom-pos, resolve-scale

// membership test for a bond {from,to} in an unordered atom-pair list
#let pair-in(list, f, t) = list.any(p => (p.at(0) == f and p.at(1) == t) or (p.at(0) == t and p.at(1) == f))

// ── GR bond styles that have no alchemist counterpart ────────────────────────
// Each is a normal alchemist link (built with `build-link`), so it goes through
// the same anchor/margin machinery as `single` and friends. Everything they need
// beyond the drawn length is passed as link arguments in canvas units.

/// GR-6 partial (delocalized) bond: a solid line with a dashed inner line.
#let delocalized = links.build-link((length, ctx, cetz-ctx, args) => {
  import cetz.draw: *
  let stroke = args.at("stroke", default: ctx.config.single.stroke)
  let inner = args.at("inner-stroke", default: stroke)
  let gap = args.at("gap", default: convert-length(cetz-ctx, ctx.config.double.gap))
  let side = args.at("side", default: 1)
  line((0, 0), (length, 0), stroke: stroke)
  line((gap, side * gap), (length - gap, side * gap), stroke: inner)
})

/// GR-1.5 bent bond: a perpendicular kink at the midpoint.
#let bent = links.build-link((length, ctx, cetz-ctx, args) => {
  import cetz.draw: *
  let stroke = args.at("stroke", default: ctx.config.single.stroke)
  line((0, 0), (length / 2, args.at("kink", default: 0.3)), (length, 0), stroke: stroke)
})

/// GR-12 pseudobond: a wavy connector.
#let pseudo = links.build-link((length, ctx, cetz-ctx, args) => {
  import cetz.draw: *
  let stroke = args.at("stroke", default: ctx.config.single.stroke)
  let amp = args.at("amplitude", default: 0.09)
  let period = args.at("period", default: 0.18)
  let waves = int(calc.max(3, calc.round(length / period)))
  let steps = waves * 6
  line(
    ..range(steps + 1).map(k => {
      let t = k / steps
      (t * length, calc.sin(t * waves * calc.pi) * amp)
    }),
    stroke: stroke,
  )
})

// engine bond `kind` -> alchemist link function. Wedges are swapped right<->left:
// the engine names a wedge narrow-at-`from` (the stereocentre), while alchemist's
// `cram-*-right` draws wide-at-`from`, so the opposite-handed variant gives the
// chemically correct narrow-at-stereocentre triangle.
#let link-fn = (
  "single": links.single,
  "double": links.double,
  "triple": links.triple,
  "dative": links.dative,
  "cram-filled-right": links.cram-filled-left,
  "cram-filled-left": links.cram-filled-right,
  "cram-dashed-right": links.cram-dashed-left,
  "cram-dashed-left": links.cram-dashed-right,
  "cram-hollow-right": links.cram-hollow-left,
  "cram-hollow-left": links.cram-hollow-right,
)

// A double bond maps onto alchemist's own `double` link via its `offset` option:
// "center" for a symmetric (acyclic) bond, "left"/"right" to put the shortened
// inner line on the ring-centroid side. `z` is cross(bond, inner) — the side the
// inner line goes to — and `zero` marks a bond with no inner direction at all.
#let double-offset(z, zero) = if zero { "center" } else if z > 0 { "left" } else { "right" }

// The alchemist configuration a generated molecule is drawn with: one stroke
// weight for every link style, and the GR label clearance as the fragment margin
// so bonds stop short of a label exactly like alchemist's hand-drawn ones do.
#let alch-config(cfg) = {
  let alch = default
  alch.fragment-color = none
  alch.fragment-margin = cfg.label-clearance
  alch.single.stroke = cfg.stroke
  alch.double.stroke = cfg.stroke
  alch.triple.stroke = cfg.stroke
  alch.dative.stroke = cfg.stroke
  alch.dashed-cram.stroke = cfg.stroke
  alch
}

// is this atom rendered as a glyph (label) rather than a bare skeletal vertex?
#let is-labeled(atom, cfg) = {
  not atom.skeletal or (cfg.show-all-h and atom.at("implicit_h", default: 0) > 0)
}

// An alchemist fragment dict; `count`/`empty` follow from the sub-atom list. The
// bonds are filled into `links` later, once every atom's shape is known.
#let make-fragment(name, atoms, colors: none, lewis: (), vertical: false, empty: false) = (
  type: "fragment", name: name, atoms: atoms, colors: colors,
  links: (:), lewis: lewis, vertical: vertical, count: atoms.len(), empty: empty,
)

// Build a native alchemist fragment dict for one engine atom.
#let atom-fragment(atom, name, cfg) = {
  if not is-labeled(atom, cfg) {
    return make-fragment(name, ((none, true),), empty: true)
  }
  // lone pairs / radicals as alchemist lewis elements, from engine directions
  let lewis = ()
  if cfg.lone-pairs != none {
    let lp = if cfg.lone-pairs == "lines" { lewis-line } else { lewis-double }
    for d in atom.lone_pair_dirs { lewis.push(lp(angle: calc.atan2(d.x, d.y))) }
  }
  for d in atom.at("radical_dirs", default: ()) {
    lewis.push(lewis-single(angle: calc.atan2(d.x, d.y), offset: "center"))
  }
  let clr = element-color(atom.element, cfg.color, cfg.atom-colors)
  let colors = if clr != black { clr } else { none }
  let ox = cfg.oxidation.at(str(atom.id), default: none)
  let reversed = atom.at("label_dir", default: "center") == "left"
  let groups = element-groups(atom.text)
  let atoms(order) = order.map(gp => (group-math(gp.sym, gp.sub), true))
  let frag(atoms, ..args) = make-fragment(name, atoms, colors: colors, lewis: lewis, ..args)

  if groups != none {
    let heavy = groups.filter(x => x.sym == atom.element)
    let rest = groups.filter(x => x.sym != atom.element)
    // GR-2.1.7 vertical: element groups stacked, heavy atom first (the connector)
    if cfg.vertical.contains(atom.id) and not atom.skeletal {
      return frag(atoms(heavy + rest), vertical: true)
    }
    // GR-2.1.5 plain: groups left-to-right, heavy atom at the connecting end (first
    // for a right label "CH2", last for a reversed left label "H2C"), so the bond
    // meets the *element symbol* on the coordinate — not the whole-"CH2"-box centre.
    if atom.charge == 0 and atom.isotope == none and ox == none {
      return frag(atoms(if reversed { rest + heavy } else { heavy + rest }))
    }
  }
  // charged / isotopic / oxidation labels: one GR-formatted blob
  frag(((format-label(atom, reversed: reversed, oxidation: ox), true),))
}

// The sub-atom a bond must meet: the element symbol, never a trailing H — the
// last group for a reversed label ("H_2C-"), the first one otherwise ("-CH_2").
#let conn-idx(atom, frag) = if atom.at("label_dir", default: "center") == "left" {
  frag.count - 1
} else { 0 }

// One engine bond as an alchemist link element. `s` is the bond-length unit and
// `gap` the double-bond gap, both already in canvas units, so the GR ratios in
// `style.typ` become absolute link arguments. `from`/`to` pin the sub-atom each
// end connects to (the element symbol), instead of letting the angle decide.
#let bond-link(bond, cfg, s, gap, z, from, to) = {
  let ends = (from: from, to: to)
  let stroke = cfg.stroke
  if cfg.aromatic == "circle" and bond.at("aromatic", default: false) {
    // GR-6 circle mode: aromatic ring bonds are plain single lines
    links.single(stroke: stroke, ..ends)
  } else if pair-in(cfg.delocalize, bond.from, bond.to) {
    let dashed = (paint: black, thickness: stroke.thickness, dash: "dashed")
    delocalized(stroke: stroke, inner-stroke: dashed, gap: gap, side: if z > 0 { 1 } else { -1 }, ..ends)
  } else if pair-in(cfg.bent, bond.from, bond.to) {
    bent(stroke: stroke, kink: cfg.bent-kink * s, ..ends)
  } else if pair-in(cfg.pseudo, bond.from, bond.to) {
    pseudo(stroke: stroke, amplitude: cfg.wave-amplitude * s, period: cfg.wave-period * s, ..ends)
  } else if bond.kind == "double" {
    let zero = bond.inner.x == 0 and bond.inner.y == 0
    links.double(stroke: stroke, offset: double-offset(z, zero), ..ends)
  } else {
    link-fn.at(bond.kind, default: links.single)(stroke: stroke, ..ends)
  }
}

// The whole molecule as an alchemist element body: every atom placed at its
// absolute coordinate, every bond a cross-link between two placed fragments.
#let chem-body(layout, name, cfg, s, gap) = {
  let aname(i) = atom-anchor(name, i)
  let atom(i) = layout.atoms.at(i)
  // the fragments come first: a bond needs to know which sub-atom it meets on
  // both ends before it can be built.
  let frags = layout.atoms.map(a => atom-fragment(a, aname(a.id), cfg))
  let conn = layout.atoms.map(a => conn-idx(a, frags.at(a.id)))
  // bonds are declared on the fragment they start from, keyed by the fragment
  // they end on — the pipeline resolves them once every atom has been placed.
  let bonds-of = (:)
  for b in layout.bonds {
    let (a, c) = (atom-pos(atom(b.from), s), atom-pos(atom(b.to), s))
    let (dx, dy) = (c.at(0) - a.at(0), c.at(1) - a.at(1))
    // z = cross(bond, inner): the side the inner/offset line goes to
    let z = dx * b.inner.y - dy * b.inner.x
    let key = str(b.from)
    let from-links = bonds-of.at(key, default: (:))
    // a cross-link is keyed by the fragment it ends on, so a degenerate input
    // that bonds the same pair twice (`C12CC12`) keeps its first bond only —
    // the second would draw the very same line over it anyway.
    if aname(b.to) in from-links { continue }
    let link = bond-link(b, cfg, s, gap, z, conn.at(b.from), conn.at(b.to))
    bonds-of.insert(key, from-links + (aname(b.to): link))
  }
  layout.atoms.map(a => (
    type: "place",
    pos: atom-pos(a, s),
    anchor: "center",
    fragment: frags.at(a.id) + (links: bonds-of.at(str(a.id), default: (:))),
    centered-on: conn.at(a.id),
  ))
}

// Render a LayoutOut to CeTZ drawables (compose inside any canvas).
#let draw-skeleton-core(layout, name: "mol", config: (:)) = {
  let cfg = chem-defaults + config
  let alch = alch-config(cfg)
  cetz.draw.get-ctx(cetz-ctx => {
    let s = resolve-scale(cetz-ctx, cfg.scale)
    let gap = convert-length(cetz-ctx, alch.double.gap)
    draw-skeleton(config: alch, chem-body(layout, name, cfg, s, gap))
    // semantic anchor for DSL `:label` (mechanism arrows / cross-links)
    for a in layout.atoms {
      if a.at("label", default: none) != none {
        cetz.draw.anchor(name + "-" + a.label, atom-pos(a, s))
      }
    }
  })
}
