#import "@preview/cetz:0.2.2"
#import "src/default.typ": default
#import "src/utils.typ"
#import "src/drawer.typ"

/// Build a molecule group based on mol
/// Each molecule is represented as an optional count followed by a molecule name
/// starting by a capital letter followed by an optional indice
/// Example: "H_2O", "2Aa_7 3Bb"
/// The name of the molecule is the cetz name of the molecule
/// and the name used to link other molecules to it
/// The links are a list of links between this molecule and the previous one
/// the key is the name of the molecule and the value is the link you want to draw between the two molecules
/// note that the length and angle arguments are ignored
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

/// Create a link function that is hen used to draw a link between two points
/// The draw-function is a function that takes two points, the start and the end of the link
/// and a dictionary of named arguments that can be used to configure the links
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
#let single = build-link((length, _, args) => {
  import cetz.draw: *
  line((0, 0), (length, 0), stroke: args.at("stroke", default: black))
})

/// Draw a double line between two molecules
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
#let cram-filled-right = build-link((length, ctx, args) => drawer.cram(
  (0, 0),
  (length, 0),
  ctx,
  args,
))

/// Draw a filled cram between two molecules with the arrow pointing to the left
#let cram-filled-left = build-link((length, ctx, args) => drawer.cram(
  (length, 0),
  (0, 0),
  ctx,
  args,
))

/// Draw a hollow cram between two molecules with the arrow pointing to the right
#let cram-hollow-right = build-link((length, ctx, args) => {
  args.fill = none
  args.stroke = args.at("stroke", default: black)
  drawer.cram((0, 0), (length, 0), ctx, args)
})

/// Draw a hollow cram between two molecules with the arrow pointing to the left
#let cram-hollow-left = build-link((length, ctx, args) => {
  args.fill = none
  args.stroke = args.at("stroke", default: black)
  drawer.cram((length, 0), (0, 0), ctx, args)
})

/// Draw a dashed cram between two molecules with the arrow pointing to the right
#let cram-dashed-right = build-link((length, ctx, args) => drawer.dashed-cram(
  (0, 0),
  (length, 0),
  length,
  ctx,
  args,
))

/// Draw a dashed cram between two molecules with the arrow pointing to the left
#let cram-dashed-left = build-link((length, ctx, args) => drawer.dashed-cram(
  (length, 0),
  (0, 0),
  length,
  ctx,
  args,
))

/// Create a branch from the current molecule
#let branch(body) = {
  ((type: "branch", draw: body),)
}

/// Create a regular cycle of molecules
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

/// setup a molecule skeleton drawer
#let skeletize(debug: false, background: none, config: (:), body) = {
  for (key, value) in default {
    if config.at(key, default: none) == none {
      config.insert(key, value)
    }
  }
  cetz.canvas(
    debug: debug,
    background: background,
    drawer.draw-skeleton(config: config, body),
  )
}

