// High-level declarative molecule API.
//
// A DSL / SMILES string is laid out by the Rust+CoordgenLibs WASM engine and
// drawn by reusing alchemist's own primitives (`skeleton.typ`) plus a thin GR
// overlay (`decorations.typ`). `chem()` is the one entry point (stand-alone);
// `reaction()` / `rxn-arrow()` arrange a scheme; `formula()` gives the Hill
// formula. Electron-pushing arrows are addressed by atom id via chem's `arrows`
// option, so the user never touches Cetz anchors.

#import "@preview/cetz:0.5.2"
#import "skeleton.typ": draw-skeleton-core
#import "decorations.typ": draw-decorations
#import "geometry.typ": curly-arc

// ── WASM engine ──────────────────────────────────────────────────────────────
// Pipeline: the Rust engine parses the source and emits the integer connectivity
// table (`cg_input`); CoordgenLibs lays out clean 2D coordinates (`layout`); the
// Rust engine applies IUPAC orientation + stereo and builds the LayoutOut
// (`finish`). CoordGen owns the hard geometry; alchemist owns orientation/render.

#let engine-plugin = plugin("chem.wasm")
#let coordgen-plugin = plugin("coordgen.wasm")

/// Run the engine: source string -> LayoutOut dict (or panic with the error).
/// - orientation ("iupac" | "as-written"): IUPAC canonical orientation, or keep
///   the structure as written
/// - rotation (angle): extra rotation applied after orientation
#let layout-of(source, format: "dsl", orientation: "iupac", rotation: 0deg) = {
  // JSON-escape the source (backslashes and quotes occur in SMILES like F/C=C\F)
  let esc = source.replace("\\", "\\\\").replace("\"", "\\\"")
  let opts = "{\"orientation\":\"" + orientation + "\",\"rotation\":" + str(rotation / 1deg) + "}"
  let req = "{\"format\":\"" + format + "\",\"source\":\"" + esc + "\",\"options\":" + opts + "}"
  let ints = engine-plugin.cg_input(bytes(req))
  let coords = coordgen-plugin.layout(ints)
  json(engine-plugin.finish(bytes(req), coords))
}

// ── public API ───────────────────────────────────────────────────────────────

// Split layout options (handled by the engine) from render options (Typst-side).
#let _split-config(config) = {
  let c = config.named()
  let orientation = c.at("orientation", default: "iupac")
  let rotation = c.at("rotation", default: 0deg)
  let _ = c.remove("orientation", default: none)
  let _ = c.remove("rotation", default: none)
  (orientation, rotation, c)
}

/// Draw a molecule from a string. Give it a structure in the readable DSL
/// (e.g. `"CH3-CH2-OH"`) or SMILES and the engine lays out clean 2D coordinates
/// and draws the skeletal formula — you never place an atom yourself. The result
/// is ready-to-place content, so call it directly in your document.
///
/// #example(```
/// #chem("CH3-C(=O)-OH")
/// #chem("c1ccncc1", format: "smiles")
/// ```)
///
/// - source (string): molecule in the readable DSL or SMILES
/// - format (string): `"dsl"` (default) or `"smiles"`
/// - name (string): base name for the per-atom Cetz anchors (`<name>-a<id>`)
/// - ..config (any): layout options (`orientation`, `rotation`) and render options
///   (`color`, `lone-pairs`, `aromatic`, `arrows`, `scale`, …)
/// -> content
/// Draw a molecule as CeTZ *drawables* (no canvas), so several molecules,
/// reaction arrows and cross-molecule electron-pushing arrows can be composed in
/// one shared `cetz.canvas` (every atom is a named anchor `<name>-a<id>`). This
/// is the coordinate-world counterpart of placing `draw-skeleton` in a scheme.
#let draw-chem(source, format: "dsl", name: "mol", ..config) = {
  let (orientation, rotation, render-cfg) = _split-config(config)
  let lay = layout-of(source, format: format, orientation: orientation, rotation: rotation)
  draw-skeleton-core(lay, name: name, config: render-cfg)
  draw-decorations(lay, name: name, config: render-cfg)
}

/// Draw a molecule as stand-alone content (wraps `draw-chem` in a canvas).
#let chem(source, format: "dsl", name: "mol", ..config) = cetz.canvas(
  draw-chem(source, format: format, name: name, ..config),
)

/// Molecular formula (GR-2.4) in Hill order, as formatted content (e.g.
/// "C₂H₆O"). Accurate for SMILES and simple DSL fragments.
///
/// - source (string): molecule in the readable DSL or SMILES
/// - format (string): `"dsl"` (default) or `"smiles"`
/// -> content
#let formula(source, format: "dsl") = {
  let lay = layout-of(source, format: format)
  lay.formula.map(((sym, n)) => sym + if n > 1 { sub(str(n)) }).join()
}

// ── reaction schemes ─────────────────────────────────────────────────────────

/// A labelled reaction arrow.
/// - above/below (content): reagent / condition labels
/// - dir (str): "right" | "left" | "equilibrium"
/// - length (float): arrow length in em-ish canvas units
#let rxn-arrow(above: none, below: none, dir: "right", length: 2.4) = cetz.canvas({
  import cetz.draw: *
  if dir == "equilibrium" {
    line((0, 0.06), (length, 0.06), mark: (end: ">", scale: 0.6))
    line((length, -0.06), (0, -0.06), mark: (end: ">", scale: 0.6))
  } else if dir == "left" {
    line((length, 0), (0, 0), mark: (end: ">"))
  } else {
    line((0, 0), (length, 0), mark: (end: ">"))
  }
  if above != none {
    content((length / 2, 0.42), text(size: 8pt, above))
  }
  if below != none {
    content((length / 2, -0.42), text(size: 8pt, below))
  }
})

/// Arrange items (molecules from `chem()`, `[+]`, `rxn-arrow(...)`) into a
/// horizontal scheme, vertically centred.
#let reaction(..items, gap: 0.7em) = {
  let cells = items.pos()
  grid(columns: cells.len(), column-gutter: gap, align: horizon, ..cells)
}

/// Electron-pushing (curly) arrow between two raw Cetz coordinates/anchors. For
/// molecules from `chem(...)`, prefer its `arrows` option (addressed by atom id);
/// this helper is the escape hatch when you draw in raw Cetz. The whole arc is
/// offset perpendicular to the from→to line so it stays clear of the bond, and
/// the head curves back in to point at the target atom.
/// - bend (float): how far the arc bows out from the bond
/// - off (float): perpendicular offset of the endpoints from the bond axis
/// - side (1 | -1): which side of the bond the arc bows to
/// - pad (float): gap kept between the tail and its source atom label
#let curly-arrow(from, to, bend: 0.55, off: 0.3, side: 1, pad: 0.16, paint: rgb("#c00")) = {
  cetz.draw.get-ctx(ctx => {
    let (ctx, a) = cetz.coordinate.resolve(ctx, from)
    let (ctx, b) = cetz.coordinate.resolve(ctx, to)
    let (p0, p3, c1, c2) = curly-arc(a, b, side, off, bend, pad)
    cetz.draw.bezier(p0, p3, c1, c2, stroke: 0.7pt + paint, mark: (end: ">", scale: 0.85))
  })
}
