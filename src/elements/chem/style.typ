// Central style for the chem renderer.
//
// One documented home for every tunable weight and geometric ratio, so the
// drawing code (skeleton.typ, decorations.typ) contains no bare magic numbers.
// Any key here can be overridden per molecule through `chem(..)`'s options.
//
// Units:
//   * lengths are font-relative (em);
//   * ratios tagged "(× bond)" are fractions of one bond length;
//   * ratios tagged "(× ring)" are fractions of a ring's circumradius.
//
// Values that can be *derived* from geometry or from alchemist's own config are
// not duplicated here — the delocalized-bond offset reuses alchemist's
// `double.gap`, and the aromatic circle is sized from the ring's apothem — so
// this table holds only genuinely free design parameters.

#let chem-style = (
  // ── line weight ────────────────────────────────────────────────────────────
  // GR (Brecher 2008): a bond is drawn about as thick as the atom-label stroke.
  stroke: 0.06em + black,

  // ── label clearance ─────────────────────────────────────────────────────────
  // gap left between a bond end and the label it meets; it becomes alchemist's
  // `fragment-margin`, so generated and hand-drawn molecules space bonds alike.
  label-clearance: 0.18em,

  // ── special bond styles ───────────────────────────────────────────────────
  bent-kink: 0.3, // (× bond) perpendicular offset of a bent bond's midpoint
  wave-amplitude: 0.09, // (× bond) height of a pseudobond wave
  wave-period: 0.18, // (× bond) length of one pseudobond wave

  // ── overlays ────────────────────────────────────────────────────────────────
  aromatic-inset: 0.82, // (× ring apothem) radius of the GR-6 delocalization circle
  charge-rise: 0.42, // (× bond) height a δ / formal-charge script sits above its atom
  bracket-pad: 0.45, // (× bond) padding between a bracket and the ion it encloses
  bracket-tick: 0.22, // (× bond) length of a bracket's corner ticks
  attach-fraction: 0.7, // (× bond) how far a variable-attachment bond reaches into a ring
  script-size: 0.85em, // size of sub/superscripts (charges, isotopes, δ)

  // curly (electron-pushing) arrow arc, all (× bond)
  arrow: (
    paint: rgb("#c00"),
    offset: 0.3, // perpendicular offset of the endpoints from the bond axis
    bend: 0.55, // how far the arc bows out
    pad: 0.16, // gap kept between the tail and its source atom
  ),
)

#import "../../default.typ": default

// The single default configuration for the whole renderer: the style above plus
// every feature option, so skeleton.typ and decorations.typ resolve one and the
// same config (`chem-defaults + user-config`) rather than each keeping its own
// defaults. Callers override any key through `chem(..)`.
#let chem-defaults = (
  ..chem-style,
  // one engine bond-length unit maps to alchemist's `atom-sep`, so generated
  // molecules sit at the same scale as hand-drawn ones.
  scale: default.atom-sep,
  // shared
  color: false,
  atom-colors: (:),
  aromatic: none, // "circle": aromatic ring bonds single + a delocalization circle
  oxidation: (:),
  // skeleton (bonds + labels)
  lone-pairs: none,
  show-all-h: false,
  vertical: (),
  delocalize: (),
  bent: (),
  pseudo: (),
  // decorations (overlays)
  ionic-bonds: false,
  brackets: none,
  variable-attach: (),
  multi-centre: (),
  partial-charge: (:),
  arrows: (),
)
