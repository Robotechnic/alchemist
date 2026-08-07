# Alchemist API Reference

## Import

```typ
#import "@preview/alchemist:0.1.10": *
```

## Core functions

### `skeletize(debug:, background:, config:, body)`
Wraps molecule drawing in a CeTZ canvas.
- `body` — drawing commands inside `{}` (positional argument)
- `debug:` (bool, default false) — shows bounding boxes and anchor points
- `background:` (none, color) — canvas background
- `config:` (dictionary) — overrides default configuration

### `skeletize-config(default-config) -> function`
Returns a pre-configured skeletize function.
```typ
#let draw = skeletize-config((angle-increment: 30deg))
#draw({ fragment("A") single() fragment("B") })
```

### `draw-skeleton(config:, name:, mol-anchor:, body)`
Low-level draw without canvas wrapper. Use inside an existing CeTZ canvas.

### `draw-skeleton-config(default-config) -> function`
Pre-configured draw-skeleton.

### `hide-drawables(elements)`
Passthrough function (placeholder for future use).

---

## Fragment

### `fragment(mol, name:, links:, lewis:, vertical:, ignore-charge:, colors:)`
- `mol` (string or equation) — chemical formula. String splits by capital letters (positional argument)
- `name:` (string, optional) — identifier for cross-linking
- `links:` (dict) — maps target fragment/hook names to link functions
- `lewis:` (array) — Lewis decoration elements
- `vertical:` (bool, default false) — stack atoms vertically
- `ignore-charge:` (bool, default false) — exclude charges from link connections
- `colors:` (color or array) — color(s) for atom groups

**String notation:**
- `"H_2O"`, `"C_6H_12O_6"` — subscripts with `_`
- `"Fe^{2+}"`, `"C^5"` — superscripts with `^`
- `"A'"`, `"A''"` — primes
- `"C^-"` — charges (superscript `-` or `+`)

**Equation notation:** Use math mode for complex groups.
```typ
fragment($C(C H_3)_3$)
```

---

## Links (bonds)

All links accept:
- `angle:` (int — multiplier of `angle-increment`, defaults to 0)
- `absolute:` (angle) — absolute angle in degrees
- `relative:` (angle) — relative angle from current direction
- `name:` (string) — identifier
- `over:` (string or dict) — creates an overpass for crossing bonds

### `single(stroke)`

### `double(gap, offset, offset-coeff, stroke)`
- `offset:` — `"left"`, `"right"`, or `"center"` (default `"center"`)
- `offset-coeff:` (0–1) — fraction of line length used for offset

### `triple(gap, stroke)`

### `cram-filled-right(stroke, fill, base-length)`
### `cram-filled-left(stroke, fill, base-length)`
### `cram-hollow-right(stroke, fill, base-length)`
### `cram-hollow-left(stroke, fill, base-length)`

### `cram-dashed-right(stroke, dash-gap, base-length, tip-length)`
### `cram-dashed-left(stroke, dash-gap, base-length, tip-length)`

### `plus(fill, size, stroke)`

---

## Branch

### `branch(body)`
Side chain off a fragment. Body must start with a link.

Angle argument on the first link sets the branch direction:
```typ
branch({
  single(angle: 1)    // 45deg (1x angle-increment)
  fragment("OH")
})
```

---

## Cycle

### `cycle(faces, body)`
Regular polygon ring with `faces` vertices (minimum 3).

The body alternates links and fragments. For a regular ring the fragments can be empty:
```typ
cycle(6, {
  single()
  fragment("")
  single()
  fragment("")
  single()
  fragment("")
})
```

Accepts `align:` argument to force alignment to the previous link angle.

---

## Parenthesis

### `parenthesis(body, l:, r:, align:, resonance:, height:, yoffset:, xoffset:, right:, tr:, br:)`
Enclose a group in brackets. Used for polymers and resonance structures.

- `body` — drawing commands inside `{}` (positional argument, should come first)
- `l:` (string) — left parenthesis character (default `"("`)
- `r:` (string) — right parenthesis character (default `")"`)
- `align:` (bool, default true) — auto-size and align
- `resonance:` (bool) — resonance mode (separated from neighbors)
- `height:` (length) — manual height
- `yoffset:` / `xoffset:` (length or pair) — fine position adjustment
- `right:` (string) — name of element where right bracket ends
- `tr:` / `br:` — top-right / bottom-right label content

---

## Operator

### `operator(op, name:, margin:)`
Separate molecules within the same skeletize block. Resets drawing position.
- `op` (content, string, or none) — the displayed operator (positional argument)
- `name:` (string, optional) — identifier for the operator
- `margin:` (length, default 1em) — spacing

```typ
operator($->$, margin: 1em)
```

---

## Hook

### `hook(name)`
Named anchor point for links. Place at a position to create a connection target.

---

## Hide

### `hide(bounds:, body)`
Visually suppress part of the drawing. Hidden elements still occupy bounding box space and remain linkable.
- `bounds:` (bool, default true) — preserve bounding box when true
- `body` — drawing commands inside `{}` (positional argument)

---

## Lewis structures

### `lewis-single(angle:, radius:, offset:, gap:, stroke:, fill:)`
Single electron dot. `offset:` is `"top"`, `"bottom"`, or `"center"`.

### `lewis-double(angle:, radius:, gap:, stroke:, fill:)`
Two electron dots (lone pair).

### `lewis-line(angle:, length:, stroke:)`
Line representing a shared electron pair.

### `lewis-rectangle(angle:, stroke:, fill:, height:, width:)`
Rectangular lone pair marker.

---

## Configuration defaults

```typ
#let default = (
  atom-sep: 3em,
  fragment-margin: 0.2em,
  fragment-font: none,
  fragment-color: none,
  link-over-radius: .2,
  angle-increment: 45deg,
  base-angle: 0deg,
  debug: false,
  single: (stroke: black),
  double: (
    gap: .25em,
    offset: "center",
    offset-coeff: 0.85,
    stroke: black,
  ),
  triple: (
    gap: .25em,
    stroke: black,
  ),
  filled-cram: (
    stroke: none,
    fill: black,
    base-length: .8em,
  ),
  dashed-cram: (
    stroke: black + .05em,
    dash-gap: .3em,
    base-length: .8em,
    tip-length: .1em,
  ),
  lewis: (
    angle: 0deg,
    radius: 0.2em,
  ),
  lewis-single: (
    stroke: black,
    fill: black,
    radius: .1em,
    gap: .25em,
    offset: "top",
  ),
  lewis-double: (
    stroke: black,
    fill: black,
    radius: .1em,
    gap: .25em,
  ),
  lewis-line: (
    stroke: black,
    length: .7em,
  ),
  lewis-rectangle: (
    stroke: .08em + black,
    fill: white,
    height: .7em,
    width: .3em,
  ),
)
```

To override, pass only the keys you want to change to `skeletize()` or `skeletize-config()`.

## Utility functions (exported from lib.typ)

- `name` — the string `"alchemist"`
- `transparent` — fully transparent color
- `molecule(name:, links:, lewis:, vertical:, mol)` — deprecated alias for `fragment`

## Touying bindings

```typ
#let touying-reducer-bindings = (
  "reduce": ("skeletize",),
  "cover": ("hide",)
)
```
