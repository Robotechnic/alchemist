---
name: alchemist
description: >
  Draw chemical skeletal formulas (structural formulas) in Typst using the alchemist package.
  Use when Codex needs to create molecular structure diagrams, organic chemistry drawings,
  Lewis structures, reaction schemes, resonance structures, or polymer representations in Typst
  documents. Integrates with CeTZ for additional canvas drawing. Supports: (1) molecules with
  fragments and bonds (single/double/triple/cram), (2) branches and cycles, (3) charges and
  Lewis structures, (4) reaction operators, (5) polymer/resonance parenthesis, (6) hiding parts
  of molecules for presentations. The package is based on chemfig conventions.
---

# Alchemist – Skeletal Formula Drawing for Typst

Alchemist draws chemical structures inside a `skeletize` block using CeTZ. Import once, then
compose molecules from fragments connected by links.

```typ
#import "@preview/alchemist:0.1.10": *

#skeletize({
  fragment("A")
  single()
  fragment("B")
})
```

## Core workflow

1. **`skeletize(body)`** — wraps everything in a CeTZ canvas.  
2. Inside the body, list elements in drawing order: fragments, links, branches, cycles, etc.  
3. Links connect the **previous** fragment (or anchor) to the **next** fragment.  
4. Branches and cycles group elements with sub-layout.

### Main elements

| Element | Purpose |
|---|---|
| `fragment(mol, name:, links:, lewis:, ...)` | A chemical symbol / group. String notation: `"C_6H_12O_6"`, `"Fe^{2+}"`, `$CH_4$` (equation) |
| `hook(name)` | Named anchor point for links |
| `single()` / `double()` / `triple()` / `cram-*()` / `plus()` | Bonds between fragments — see Links section |
| `branch(body)` | Side chain off a fragment (body starts with a link) |
| `cycle(faces, body)` | Regular polygon-shaped ring (faces >= 3) |
| `parenthesis(body, l:"(", r:")", ...)` | Polymer or resonance brackets |
| `operator(op, margin:)` | Separator between molecules (e.g. reaction arrow) |
| `hide(bounds:, body)` | Visually suppress part of the drawing for animations |

## Fragment notation

Fragments are the core atoms/groups. They can be strings or math equations.

**String notation rules** — consecutive capital letters split into separate atoms:
- `"H_2O"` renders as H2O
- `"C^5_4"` renders as C with superscript 5 and subscript 4
- `"A'"` / `"A''"` renders primed atoms
- `"C_6H_12O_6"` renders a multi-atom molecule (each token auto-spaced)

**Equation notation** — more flexible, supports arbitrary structure:
```typ
fragment($C(C H_3)_3$)  // tert-butyl group
```

**Parameters:**
- `name:` — identifier for linking (auto-generated if omitted)
- `links:` — dict mapping target names to link functions (see cross-linking)
- `lewis:` — list of lewis-dot decorations
- `vertical:` — stack atoms vertically instead of horizontally
- `ignore-charge:` — excludes charge atoms from link connection points
- `colors:` — single color or list of colors for each atom group

## Links (bonds)

Links connect the **current drawing position** to the **next fragment**. Each link function
accepts named arguments that override config defaults.

| Link | Appearance |
|---|---|
| `single()` | Single line |
| `double()` | Double line (configurable `gap`, `offset: "left"/"right"/"center"`) |
| `triple()` | Triple line |
| `cram-filled-right()` / `cram-filled-left()` | Solid wedge (stereochemistry) |
| `cram-hollow-right()` / `cram-hollow-left()` | Hollow wedge |
| `cram-dashed-right()` / `cram-dashed-left()` | Dashed wedge |
| `plus()` | Plus sign between fragments |

## Branches

A branch starts from the current fragment and draws a side chain. The first element must be a link.

```typ
branch({
  single(angle: 1)   // angle multiplier of angle-increment (default 45deg)
  fragment("OH")
})
```

## Cycles

Create regular polygon rings. The body alternates links and fragments.

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

## Lewis structures

Decorate a fragment with electron representations via the `lewis:` parameter.

```typ
fragment("O", lewis: (
  lewis-single(offset: "top"),
  lewis-double(angle: 90deg),
  lewis-line(angle: 45deg),
  lewis-rectangle(angle: 180deg),
))
```

| Lewis element | Description |
|---|---|
| `lewis-single(offset:, gap:)` | Single electron dot |
| `lewis-double(gap:)` | Two electron dots (lone pair) |
| `lewis-line(length:)` | Line through a dot pair |
| `lewis-rectangle(height:, width:)` | Rectangular lone pair marker |

## Cross-linking fragments

Use named fragments and the `links:` parameter to draw bonds between non-adjacent atoms.

```typ
fragment(name: "A", "A")
single()
fragment("B")
branch({
  single()
  fragment(name: "X", "X")
})
single()
fragment("C", links: (
  "A": double(stroke: red),
  "X": single(),
))
```

## Configuration

Use `skeletize-config(default-config)` to create a pre-configured drawer.

```typ
#let draw-molecule = skeletize-config((
  angle-increment: 30deg,
  base-angle: 90deg,
  single: (stroke: blue),
))

#draw-molecule({
  fragment("A")
  single()
  fragment("B")
})
```

Available config keys with defaults: see [references/api.md](references/api.md).

## CeTZ integration

Alchemist renders on a CeTZ canvas. Mix raw CeTZ drawing commands inside `skeletize`:

```typ
#skeletize({
  import cetz.draw: *
  single(absolute: 30deg, name: "l1")
  hobby("l1.start", ("l1.end", 0.5, 90deg, "l1.start"), mark: (end: ">"))
  fragment("X")
})
```

## Low-level drawing

Use `draw-skeleton(config:, name:, body)` to draw without the canvas wrapper — useful when
embedding inside an existing CeTZ canvas.

## Touying integration

Alchemist provides automatic touying bindings for slide reveal/hide effects.

See [references/api.md](references/api.md) for the full API reference and
[references/patterns.md](references/patterns.md) for common molecule templates.
