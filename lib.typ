#import "@preview/cetz:0.2.2"
#import "src/default.typ": default
#import "src/utils.typ"
#import "src/drawer.typ"
#import "src/drawer.typ" : skeletize

/// === Molecule function
/// Build a molecule group based on mol
/// Each molecule is represented as an optional count followed by a molecule name
/// starting by a capital letter followed by an optional indice
/// #example(```
/// #skeletize({
///   molecule("H_2O")
/// })
///```)
/// #example(```
/// #skeletize({
///   molecule("2Aa_7 3Bb")
/// })
///```)
/// - name (string): The name of the molecule. It is used as the cetz name of the molecule and to link other molecules to it.
/// - links (dictionary): The links between this molecule and the previous ones. The key is the name of the molecule and the value is the link you want to draw between the two molecules.
///
/// Note that the length and angle arguments are ignored
/// - mol (string): The string representing the molecule
/// -> drawable
#let molecule(name: none, links: (:), mol) = {
  let aux(str) = {
    let match = str.match(regex("^ *([0-9]*[A-Z][a-z]*)(_[0-9]+)?"))
    if match == none {
      panic(str + " is not a valid atom")
    }
    let eq = "\"" + match.captures.at(0) + "\""
    if match.captures.len() >= 2 {
      eq += match.captures.at(1)
    }
    let eq = math.equation(eval(eq, mode: "math"))
    (eq, match.end)
  }

  let molecules = ()
  while not mol.len() == 0 {
    let (eq, end) = aux(mol)
    mol = mol.slice(end)
    molecules.push(eq)
  }
  (
    (
      type: "molecule",
      name: name,
      molecules: molecules,
      links: links,
      count: molecules.len(),
    ),
  )
}

/// === Link functions
/// Create a link function that is then used to draw a link between two points
///
///
/// - draw-function (function): The function that will be used to draw the link. It should takes three arguments: the length of the link, the context, and a dictionary of named arguments that can be used to configure the links
/// -> function
#let build-link(draw-function) = {
  (..args) => {
    if args.pos().len() != 0 {
      panic("Links takes no positional arguments")
    }
    (
      (
        type: "link",
        draw: (length, ctx, override: (:)) => {
          let args = args.named()
          for (key, val) in override {
            args.insert(key, val)
          }
          draw-function(length, ctx, args)
        },
        ..args.named(),
      ),
    )
  }
}

/// Draw a single line between two molecules
/// #example(```
/// #skeletize({
///   molecule("A")
///   single()
///   molecule("B")
/// })
///```)
/// It is possible to change the color and width of the line
/// with the `stroke` argument
/// #example(```
/// #skeletize({
///   molecule("A")
///   single(stroke: red + 5pt)
///   molecule("B")
/// })
///```)
#let single = build-link((length, _, args) => {
  import cetz.draw: *
  line((0, 0), (length, 0), stroke: args.at("stroke", default: black))
})

/// Draw a double line between two molecules
/// #example(```
/// #skeletize({
///   molecule("A")
///   double()
///   molecule("B")
/// })
///```)
/// It is possible to change the color and width of the line
/// with the `stroke` argument and the gap between the two lines
/// with the `gap` argument
/// #example(```
/// #skeletize({
///   molecule("A")
///   double(
///     stroke: orange + 2pt,
///     gap: .8em
///   )
///   molecule("B")
/// })
///```)
#let double = build-link((length, ctx, args) => {
  import cetz.draw: *
  let gap = utils.convert-length(ctx, args.at("gap", default: .25em)) / 2
  let offset = args.at("offset", default: "center")
  let coeff = args.at("offset-coeff", default: 0.85)
  if coeff < 0 or coeff > 1 {
    panic("Invalid offset-coeff value: must be between 0 and 1")
  }
  if offset == "left" {
    translate((0, -gap))
  } else if offset == "right" {
    translate((0, gap))
  } else if offset == "center" { } else {
    panic("Invalid offset value: must be \"left\", \"right\" or \"center\"")
  }

  translate((0, -gap))
  line(
    ..if offset == "left" {
      let x = length * (1 - coeff) / 2
      ((x, 0), (x + length * coeff, 0))
    } else {
      ((0, 0), (length, 0))
    },
    stroke: args.at("stroke", default: black),
  )
  translate((0, 2 * gap))
  line(
    ..if offset == "right" {
      let x = length * (1 - coeff) / 2
      ((x, 0), (x + length * coeff, 0))
    } else {
      ((0, 0), (length, 0))
    },
    stroke: args.at("stroke", default: black),
  )
})

/// Draw a triple line between two molecules
/// #example(```
/// #skeletize({
///   molecule("A")
///   triple()
///   molecule("B")
/// })
///```)
/// It is possible to change the color and width of the line
/// with the `stroke` argument and the gap between the three lines
/// with the `gap` argument
/// #example(```
/// #skeletize({
///   molecule("A")
///   triple(
///     stroke: blue + .5pt,
///     gap: .15em
///   )
///   molecule("B")
/// })
///```)
#let triple = build-link((length, ctx, args) => {
  import cetz.draw: *
  let gap = utils.convert-length(ctx, args.at("gap", default: .25em))
  line((0, 0), (length, 0), stroke: args.at("stroke", default: black))
  translate((0, -gap))
  line((0, 0), (length, 0), stroke: args.at("stroke", default: black))
  translate((0, 2 * gap))
  line((0, 0), (length, 0), stroke: args.at("stroke", default: black))
})

/// Draw a filled cram between two molecules with the arrow pointing to the right
/// #example(```
/// #skeletize({
///   molecule("A")
///   cram-filled-right()
///   molecule("B")
/// })
///```)
/// It is possible to change the stroke and fill color of the arrow
/// with the `stroke` and `fill` arguments. You can also change the base length of the arrow with the `base-length` argument
/// #example(```
/// #skeletize({
///   molecule("A")
///   cram-filled-right(
///     stroke: red + 2pt,
///     fill: green,
///     base-length: 2em
///   )
///   molecule("B")
/// })
///```)
#let cram-filled-right = build-link((length, ctx, args) => drawer.cram(
  (0, 0),
  (length, 0),
  ctx,
  args,
))

/// Draw a filled cram between two molecules with the arrow pointing to the left
/// #example(```
/// #skeletize({
///   molecule("A")
///   cram-filled-left()
///   molecule("B")
/// })
///```)
/// It is possible to change the stroke and fill color of the arrow
/// with the `stroke` and `fill` arguments. You can also change the base length of the arrow with the `base-length` argument
/// #example(```
/// #skeletize({
///   molecule("A")
///   cram-filled-left(
///     stroke: red + 2pt,
///     fill: green,
///     base-length: 2em
///   )
///   molecule("B")
/// })
///```)
#let cram-filled-left = build-link((length, ctx, args) => drawer.cram(
  (length, 0),
  (0, 0),
  ctx,
  args,
))

/// Draw a hollow cram between two molecules with the arrow pointing to the right
/// It is a shorthand for `cram-filled-right(fill: none)`
#let cram-hollow-right = build-link((length, ctx, args) => {
  args.fill = none
  args.stroke = args.at("stroke", default: black)
  drawer.cram((0, 0), (length, 0), ctx, args)
})

/// Draw a hollow cram between two molecules with the arrow pointing to the left
/// It is a shorthand for `cram-filled-left(fill: none)`
#let cram-hollow-left = build-link((length, ctx, args) => {
  args.fill = none
  args.stroke = args.at("stroke", default: black)
  drawer.cram((length, 0), (0, 0), ctx, args)
})

/// Draw a dashed cram between two molecules with the arrow pointing to the right
/// #example(```
/// #skeletize({
///   molecule("A")
///   cram-dashed-right()
///   molecule("B")
/// })
///```)
/// It is possible to change the stroke of the lines in the arrow
/// with the `stroke` argument. You can also change the base length of the arrow with the `base-length` argument and distance between the dashes with the `dash-gap` argument
/// #example(```
/// #skeletize({
///   molecule("A")
///   cram-dashed-right(
///     stroke: red + 2pt,
///     base-length: 2em,
///     dash-gap: .5em
///   )
///   molecule("B")
/// })
///```)
#let cram-dashed-right = build-link((length, ctx, args) => drawer.dashed-cram(
  (0, 0),
  (length, 0),
  length,
  ctx,
  args,
))

/// Draw a dashed cram between two molecules with the arrow pointing to the left
/// #example(```
/// #skeletize({
///   molecule("A")
///   cram-dashed-left()
///   molecule("B")
/// })
///```)
/// It is possible to change the stroke of the lines in the arrow
/// with the `stroke` argument. You can also change the base length of the arrow with the `base-length` argument and distance between the dashes with the `dash-gap` argument
/// #example(```
/// #skeletize({
///   molecule("A")
///   cram-dashed-left(
///     stroke: red + 2pt,
///     base-length: 2em,
///     dash-gap: .5em
///   )
///   molecule("B")
/// })
///```)
#let cram-dashed-left = build-link((length, ctx, args) => drawer.dashed-cram(
  (length, 0),
  (0, 0),
  length,
  ctx,
  args,
))

/// === Branch and cycles
/// Create a branch from the current molecule, the first element
/// of the branch has to be a link
/// #example(```
/// #skeletize({
///   molecule("A")
///   branch({
///     single(angle:1)
///     molecule("B")
///   })
///   branch({
///     double(angle: -1)
///     molecule("D")
///   })
///   single()
///   double()
///   single()
///   molecule("C")
/// })
///```)
#let branch(body) = {
  ((type: "branch", draw: body),)
}

/// Create a regular cycle of molecules
/// #example(```
/// #skeletize({
///   cycle(5, {
///     single()
///     double()
///     single()
///     double()
///     single()
///   })
/// })
///```)
#let cycle(..args) = {
  if args.pos().len() != 2 {
    panic("Cycle takes two positional arguments: number of faces and body")
  }
  (
    (
      type: "cycle",
      faces: args.pos().at(0),
      draw: args.pos().at(1),
      ..args.named(),
    ),
  )
}
