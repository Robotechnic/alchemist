#import "default.typ": default
#import "@preview/cetz:0.2.2"
#import "utils.typ"
#import cetz.draw

#let default-anchor = (type: "coord", anchor: (0, 0))

#let default-ctx = (
	// general
  last-anchor: default-anchor,
  group-id: 0,
  link-id: 0,
	links: (),
  named-molecules: (:),
  relative-angle: 0deg,
  angle: 0deg,

	// branch and cycle
	first-branch: false,

	// cycle
	first-molecule: none,
  in-cycle: false,
  cycle-faces: 0,
  faces-count: 0,
  cycle-step-angle: 0deg,
	record-edges: false,
	vertex-anchors: (),
)

#let set-last-anchor(ctx, anchor) = {
  if ctx.last-anchor.type == "link" {
    ctx.links.push(ctx.last-anchor)
  }
  (..ctx, last-anchor: anchor)
}

#let link-molecule-index(angle, end, count) = {
  if not end {
    if utils.angle-in-range(angle, 90deg, 270deg) {
      0
    } else {
      count
    }
  } else {
    if utils.angle-in-range(angle, 90deg, 270deg) {
      count
    } else {
      0
    }
  }
}

#let molecule-link-anchor(name, id, count) = {
  if count <= id {
    panic("The last molecule only has " + str(count) + " connections")
  }
  if id == -1 {
    id = count - 1
  }
  (name: name, anchor: (str(id), "center"))
}

#let link-molecule-anchor(name: none, id, count) = {
  if id >= count {
    panic("This molecule only has " + str(count) + " anchors")
  }
  if id == -1 {
    panic("The index of the molecule to link to must be defined")
  }
  if name == none {
    (name: str(id), anchor: "center")
  } else {
    (name: name, anchor: (str(id), "center"))
  }
}

#let angle-from-ctx(ctx, object, default) = {
  if "relative" in object {
    object.at("relative") + ctx.relative-angle
  } else if "absolute" in object {
    object.at("absolute")
  } else if "angle" in object {
    object.at("angle") * ctx.config.angle-increment
  } else {
    default
  }
}

#let cycle-angle(ctx) = {
  if ctx.in-cycle {
    if ctx.faces-count == 0 {
      ctx.relative-angle - ctx.cycle-step-angle - (180deg - ctx.cycle-step-angle) / 2
    } else {
      ctx.relative-angle - (180deg - ctx.cycle-step-angle) / 2
    }
  } else {
    ctx.angle
  }
}

/// Draw a triangle between two molecules
#let cram(from, to, ctx, args) = {
  import cetz.draw: *

  let (ctx, (from-x, from-y, _)) = cetz.coordinate.resolve(ctx, from)
  let (ctx, (to-x, to-y, _)) = cetz.coordinate.resolve(ctx, to)
  let base-length = utils.convert-length(
    ctx,
    args.at("base-length", default: .8em),
  )
  line(
    (from-x, from-y - base-length / 2),
    (from-x, from-y + base-length / 2),
    (to-x, to-y),
    close: true,
    stroke: args.at("stroke", default: none),
    fill: args.at("fill", default: black),
  )
}

/// Draw a dashed triangle between two molecules
#let dashed-cram(from, to, length, ctx, args) = {
  import cetz.draw: *
  let (ctx, (from-x, from-y, _)) = cetz.coordinate.resolve(ctx, from)
  let (ctx, (to-x, to-y, _)) = cetz.coordinate.resolve(ctx, to)
  let base-length = utils.convert-length(
    ctx,
    args.at("base-length", default: .8em),
  )
  hide({
    line(name: "top", (from-x, from-y - base-length / 2), (to-x, to-y - 0.05))
    line(
      name: "bottom",
      (from-x, from-y + base-length / 2),
      (to-x, to-y + 0.05),
    )
  })
  let stroke = args.at("stroke", default: black + .05em)
  let dash-gap = utils.convert-length(ctx, args.at("dash-gap", default: .3em))
  let dash-width = stroke.thickness
  let converted-dash-width = utils.convert-length(ctx, dash-width)
  let length = utils.convert-length(ctx, length)

  let dash-count = int(calc.ceil(length / (dash-gap + converted-dash-width)))
  let incr = 100% / dash-count

  let percentage = 0%
  while percentage <= 100% {
    line(
      (name: "top", anchor: percentage),
      (name: "bottom", anchor: percentage),
      stroke: stroke,
    )
    percentage += incr
  }
}

#let draw-molecule-text(mol) = {
  for (id, eq) in mol.molecules.enumerate() {
    let name = str(id)
    // draw the molecules of the group one after the other from left to right
    draw.content(
      name: name,
      anchor: "west",
      (
        if id == 0 {
          (0, 0)
        } else {
          str(id - 1) + ".east"
        }
      ),
      eq,
    )
    id += 1
  }
}

#let draw-molecule(mol, ctx) = {
  let name = mol.name
  if name != none {
    if name in ctx.named-molecules {
      panic("Molecule with name " + name + " already exists")
    }
    ctx.named-molecules.insert(name, mol)
  } else {
    name = "molecule" + str(ctx.group-id)
  }
  let (anchor, side, coord) = if ctx.last-anchor.type == "coord" {
    ("east", true, ctx.last-anchor.anchor)
  } else if ctx.last-anchor.type == "link" {
    if ctx.last-anchor.to == -1 {
      ctx.last-anchor.to = link-molecule-index(
        ctx.last-anchor.angle,
        true,
        mol.count - 1,
      )
    }
    let anchor = link-molecule-anchor(ctx.last-anchor.to, mol.count)
    ctx.last-anchor.to-name = name
    (anchor, false, ctx.last-anchor.name + "-end-anchor")
  } else {
    panic("A molecule must be linked to a coord or a link")
  }
  ctx = set-last-anchor(
    ctx,
    (type: "molecule", name: name, count: mol.at("count")),
  )
  ctx.group-id += 1
  (
    name,
    ctx,
    {
      draw.group(
        anchor: if side {
          anchor
        } else {
          "from" + str(ctx.group-id)
        },
        name: name,
        {
          draw.set-origin(coord)
          draw.anchor("default", (0, 0))
          draw-molecule-text(mol)
          if not side {
            draw.anchor("from" + str(ctx.group-id), anchor)
          }
        },
      )
    },
  )
}

#let angle-override(angle, ctx) = {
  if ctx.in-cycle {
    ("offset": "left")
  } else {
    (:)
  }
}

#let draw-last-cycle-link(link, ctx) = {
  let from-name = none
  let from-pos = none
  if ctx.last-anchor.type == "molecule" {
    from-name = ctx.last-anchor.name
    from-pos = (name: from-name, anchor: "center")
    if from-name not in ctx.named-molecules {
      ctx.named-molecules.insert(from-name, ctx.last-anchor)
    }
  } else if ctx.last-anchor.type == "link" {
    from-pos = ctx.last-anchor.name + "-end-anchor"
  } else {
    panic("A cycle link must be linked to a molecule or a link")
  }
  ctx.links.push((
    type: "link",
    name: link.at("name", default: "link" + str(ctx.link-id)),
    from-pos: from-pos,
    from-name: from-name,
    to-name: ctx.first-molecule,
    from: link.at("from", default: none),
    to: link.at("to", default: none),
    override: (offset: "left"),
    draw: link.draw,
  ))
  ctx.link-id += 1
  (ctx, ())
}

#let draw-link(link, ctx) = {
  let link-angle = 0deg
  if ctx.in-cycle {
    if ctx.faces-count == ctx.cycle-faces - 1 and ctx.first-molecule != none {
      return draw-last-cycle-link(link, ctx)
    }
    if ctx.faces-count == 0 {
      link-angle = ctx.relative-angle
    } else {
      link-angle = ctx.relative-angle + ctx.cycle-step-angle
    }
  } else {
    link-angle = angle-from-ctx(ctx, link, ctx.angle)
  }
  link-angle = utils.angle-correction(link-angle)
  ctx.relative-angle = link-angle
  let override = angle-override(link-angle, ctx)

  let to-connection = link-molecule-index(link-angle, true, -1)
  to-connection = link.at("to", default: to-connection)
  let from-connection = none
  let from-name = none

  let from-pos = if ctx.last-anchor.type == "coord" {
    ctx.last-anchor.anchor
  } else if ctx.last-anchor.type == "molecule" {
    from-connection = link-molecule-index(
      link-angle,
      false,
      ctx.last-anchor.count - 1,
    )
    from-connection = link.at("from", default: from-connection)
    from-name = ctx.last-anchor.name
    molecule-link-anchor(
      ctx.last-anchor.name,
      from-connection,
      ctx.last-anchor.count,
    )
  } else if ctx.last-anchor.type == "link" {
    ctx.last-anchor.name + "-end-anchor"
  } else {
    panic("Unknown anchor type " + ctx.last-anchor.type)
  }
  let length = link.at("atom-sep", default: ctx.config.atom-sep)
  let link-name = link.at("name", default: "link" + str(ctx.link-id))
  if ctx.record-edges {
		if ctx.faces-count == 0 {
			ctx.vertex-anchors.push(from-pos)
		}
		if ctx.faces-count < ctx.cycle-faces - 1 {
    	ctx.vertex-anchors.push(link-name + "-end-anchor")
		}
  }
  ctx = set-last-anchor(
    ctx,
    (
      type: "link",
      name: link-name,
      override: override,
      from-pos: from-pos,
      from-name: from-name,
      from: from-connection,
      to-name: none,
      to: to-connection,
      angle: link-angle,
      draw: link.draw,
    ),
  )
  ctx.link-id += 1
  (
    ctx,
    draw.get-ctx(ctx => {
      let (ctx, (x1, y1, _)) = cetz.coordinate.resolve(ctx, from-pos)
      let length = utils.convert-length(ctx, length)
      let x = x1 + length * calc.cos(link-angle)
      let y = y1 + length * calc.sin(link-angle)
      draw.group(
        name: link-name + "-end-anchor",
        {
          draw.anchor("default", (x, y))
        },
      )
    }),
  )
}

#let draw-cycle-center-arc(ctx, name, arc) = {
	let faces = ctx.cycle-faces
	let vertex = ctx.vertex-anchors
	draw.get-ctx(cetz-ctx => {
		let odd = calc.rem(faces,  2) == 1
		let (cetz-ctx, ..vertex) = cetz.coordinate.resolve(cetz-ctx, ..vertex)
		if vertex.len() < faces {
			let atom-sep = utils.convert-length(cetz-ctx, ctx.config.atom-sep)
			for i in range(faces - vertex.len()) {
				let (x, y, _) = vertex.last()
				vertex.push(
					(
						x + atom-sep * calc.cos(ctx.relative-angle + ctx.cycle-step-angle * (i + 1)),
						y + atom-sep * calc.sin(ctx.relative-angle + ctx.cycle-step-angle * (i + 1)),
						0
					)
				)	
			}
		}
		let center = (0, 0)
		let min-radius = 9223372036854775807 // max int
		for (i,v) in vertex.enumerate() {
			if (ctx.config.debug) {
				draw.circle(v, radius: .1em, fill: blue, stroke: blue)
			}
			let (x, y, _) = v
			center = (center.at(0) + x, center.at(1) + y)
			if odd {
				let opposite1 = calc.rem(i + calc.div-euclid(faces, 2), faces)
				let opposite2 = calc.rem(i + calc.div-euclid(faces, 2) + 1, faces)
				let (ox1, oy1, _) = vertex.at(opposite1)
				let (ox2, oy2, _) = vertex.at(opposite2)
				let radius = utils.distance-between(cetz-ctx, (x, y), ((ox1 + ox2) / 2, (oy1 + oy2) / 2)) / 2
				if radius < min-radius {
					min-radius = radius
				}
			} else {
				let opposite = calc.rem-euclid(i + calc.div-euclid(faces, 2), faces)
				let (ox, oy, _) = vertex.at(opposite)
				let radius = utils.distance-between(cetz-ctx, (x, y), (ox, oy)) / 2
				if radius < min-radius {
					min-radius = radius
				}
			}
		}
		center = (center.at(0) / vertex.len(), center.at(1) / vertex.len())
		if name != none {
			draw.group(
				name: name,
				{
					draw.anchor("default", center)
				})
		}
		if arc != none {
			if min-radius == 9223372036854775807 {
				panic("The cycle has no opposite vertices")
			}
			if ctx.cycle-faces > 4 {
				min-radius *= arc.at("radius", default: 0.7)
			} else {
				min-radius *= arc.at("radius", default: 0.5)
			}
			let start = arc.at("start", default: 0deg)
			let end = arc.at("end", default: 360deg)
			let delta = arc.at("delta", default: end - start)
			center = (
				center.at(0) + min-radius * calc.cos(start),
				center.at(1) + min-radius * calc.sin(start)
			)
			draw.arc(
				center,
				..arc,
				radius: min-radius,
				start: start,
				delta: delta,
			)
		}
	})

}

#let draw-molecule-links(mol, mol-name, ctx) = {
  ctx.named-molecules.insert(mol-name, mol)
  let last-anchor = ctx.last-anchor
  for (to-name, (link,)) in mol.links {
    ctx.last-anchor = last-anchor
    if to-name not in ctx.named-molecules {
      panic("Molecule " + to-name + " does not exist")
    }
    ctx.links.push((
      type: "link",
      name: link.at("name", default: "link" + str(ctx.link-id)),
      from-pos: (name: mol-name, anchor: "center"),
      from-name: mol-name,
      to-name: to-name,
      override: angle-override(ctx.angle, ctx),
      from: none,
      to: none,
      draw: link.draw,
    ))
    ctx.link-id += 1
  }
  ctx
}

#let draw-molecules-and-link(ctx, body) = {
  let molecule-name = ""
  let drawing = ()
  let cetz-drawing = ()
  (
    {
      for element in body {
        if ctx.in-cycle and ctx.faces-count >= ctx.cycle-faces {
          continue
        }
        if type(element) == function {
          cetz-drawing.push(element)
        } else if "type" not in element {
          panic("Element " + str(element) + " has no type")
        } else if element.type == "molecule" {
          if ctx.first-branch {
            panic("A molecule can not be the first element in a cycle")
          }
          (molecule-name, ctx, drawing) = draw-molecule(element, ctx)
          drawing
          if element.at("links").len() != 0 {
            ctx = draw-molecule-links(element, molecule-name, ctx)
          }
        } else if element.type == "link" {
          ctx.first-branch = false
          (ctx, drawing) = draw-link(element, ctx)
          ctx.faces-count += 1
          drawing
        } else if element.type == "branch" {
          let angle = angle-from-ctx(ctx, element.args, cycle-angle(ctx))
          let (drawing, branch-ctx, cetz-rec) = draw-molecules-and-link(
            (
              ..ctx,
              in-cycle: false,
              first-branch: true,
              cycle-step-angle: 0,
              angle: angle,
            ),
            element.draw,
          )
          ctx.named-molecules += branch-ctx.named-molecules
          ctx.links += branch-ctx.links
          ctx.group-id = branch-ctx.group-id
          ctx.link-id = branch-ctx.link-id
          cetz-drawing += cetz-rec
          drawing
        } else if element.type == "cycle" {
          let cycle-step-angle = 360deg / element.faces
          let angle = angle-from-ctx(ctx, element.args, none)
          if angle == none {
            if ctx.in-cycle {
              angle = ctx.relative-angle - (180deg - cycle-step-angle)
              if ctx.faces-count != 0 {
                angle += ctx.cycle-step-angle
              }
            } else if ctx.relative-angle == 0deg and ctx.angle == 0deg and not element.args.at(
              "align",
              default: false,
            ) {
              angle = cycle-step-angle - 90deg
            } else {
              angle = ctx.relative-angle - (180deg - cycle-step-angle) / 2
            }
          }
          let first-molecule = none
          if ctx.last-anchor.type == "molecule" {
            first-molecule = ctx.last-anchor.name
            if first-molecule not in ctx.named-molecules {
              ctx.named-molecules.insert(first-molecule, ctx.last-anchor)
            }
          }
          let name = none
          let record-edges = false
          if "name" in element.args {
            name = element.args.at("name")
            record-edges = true
          } else if "arc" in element.args {
						record-edges = true
					}
          let (drawing, cycle-ctx, cetz-rec) = draw-molecules-and-link(
            (
              ..ctx,
              in-cycle: true,
              cycle-faces: element.faces,
              faces-count: 0,
              first-branch: true,
              cycle-step-angle: cycle-step-angle,
              relative-angle: angle,
              first-molecule: first-molecule,
              angle: angle,
              record-edges: record-edges,
							vertex-anchors: (),
            ),
            element.draw,
          )
          ctx.named-molecules += cycle-ctx.named-molecules
          ctx.links += cycle-ctx.links
          ctx.group-id = cycle-ctx.group-id
          ctx.link-id = cycle-ctx.link-id
          cetz-drawing += cetz-rec
          drawing
					if record-edges {
						draw-cycle-center-arc(cycle-ctx, name, element.args.at("arc", default: none))
					}
        } else {
          panic("Unknown element type " + element.type)
        }
      }
      if ctx.last-anchor.type == "link" {
        ctx.links.push(ctx.last-anchor)
      }
    },
    ctx,
    cetz-drawing,
  )
}

#let molecule-anchor(cetz-ctx, angle, molecule, id) = {
  let (cetz-ctx, (x, y, _)) = cetz.coordinate.resolve(
    cetz-ctx,
    (name: molecule, anchor: (id, "center")),
  )
  let (cetz-ctx, (_, b, _)) = cetz.coordinate.resolve(
    cetz-ctx,
    (name: molecule, anchor: (id, "north")),
  )
  let (cetz-ctx, (a, _, _)) = cetz.coordinate.resolve(
    cetz-ctx,
    (name: molecule, anchor: (id, "east")),
  )
  let a = (a - x) * 1.8
  let b = (b - y) * 2.3
  if a == 0 or b == 0 {
    panic("Ellipse " + ellipse + " has no width or height")
  }
  (x + a * calc.cos(angle), y + b * calc.sin(angle))
}

#let calculate-link-anchors(ctx, cetz-ctx, link) = {
  if link.to-name != none and link.from-name != none {
    let to-pos = (name: link.to-name, anchor: "center")
    if link.to == none or link.from == none {
      let angle = utils.angle-between(cetz-ctx, link.from-pos, to-pos)
      link.angle = angle
      if link.from == none {
        link.from = link-molecule-index(
          angle,
          false,
          ctx.named-molecules.at(link.from-name).count - 1,
        )
      }
      if link.to == none {
        link.to = link-molecule-index(
          angle,
          true,
          ctx.named-molecules.at(link.to-name).count - 1,
        )
      }
    }
    let start = molecule-anchor(cetz-ctx, link.angle, link.from-name, str(link.from))
    let end = molecule-anchor(cetz-ctx, link.angle + 180deg, link.to-name, str(link.to))
    ((start, end), utils.angle-between(cetz-ctx, start, end))
  } else if link.to-name != none {
    if link.to == none {
      let angle = utils.angle-correction(
        utils.angle-between(
          cetz-ctx,
          link.from-pos,
          (name: link.to-name, anchor: "center"),
        ),
      )
      link.to = link-molecule-index(
        angle,
        true,
        ctx.named-molecules.at(link.to-name).count - 1,
      )
      link.angle = angle
    } else if "angle" not in link {
      link.angle = utils.angle-correction(
        utils.angle-between(
          cetz-ctx,
          link.from-pos,
          (name: link.to-name, anchor: (str(link.to), "center")),
        ),
      )
    }
    let end-anchor = molecule-anchor(
      cetz-ctx,
      link.angle + 180deg,
      link.to-name,
      str(link.to),
    )
    (
      (
        link.from-pos,
        end-anchor,
      ),
      utils.angle-between(cetz-ctx, link.from-pos, end-anchor),
    )
  } else if link.from-name != none {
    (
      (
        molecule-anchor(cetz-ctx, link.angle, link.from-name, str(link.from)),
        link.name + "-end-anchor",
      ),
      link.angle,
    )
  } else {
    ((link.from-pos, link.name + "-end-anchor"), link.angle)
  }
}

#let draw-link-decoration(ctx) = {
  import cetz.draw: *
  (
    get-ctx(cetz-ctx => {
      for link in ctx.links {
        let ((from, to), angle) = calculate-link-anchors(ctx, cetz-ctx, link)
        if ctx.config.debug {
          circle(from, radius: .1em, fill: red, stroke: red)
          circle(to, radius: .1em, fill: red, stroke: red)
        }
        let length = utils.distance-between(cetz-ctx, from, to)
        hide(line(from, to, name: link.name))
        group({
          set-origin(from)
          rotate(angle)
          (link.draw)(length, cetz-ctx, override: link.override)
        })
      }
    }),
    ctx,
  )
}

#let draw-skeleton(config: default, body) = {
  let ctx = default-ctx
  ctx.angle = config.base-angle
  ctx.config = config
  let (draw, ctx, cetz-drawing) = draw-molecules-and-link(ctx, body)
  let (links, _) = draw-link-decoration(ctx)
  {
    draw
    links
    cetz-drawing
  }
}

/// setup a molecule skeleton drawer
#let skeletize(debug: false, background: none, config: (:), body) = {
  for (key, value) in default {
    if key not in config {
      config.insert(key, value)
    }
  }
	if "debug" not in config {
		config.insert("debug", debug)
	}
  cetz.canvas(
    debug: debug,
    background: background,
    draw-skeleton(config: config, body),
  )
}
