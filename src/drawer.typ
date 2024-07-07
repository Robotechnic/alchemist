#import "default.typ": default
#import "@preview/cetz:0.2.2"
#import "utils.typ"
#import cetz.draw

#let default-anchor = (
	type: "coord",
	anchor: (0,0)
)

#let default-ctx = (
	last-anchor: default-anchor,
	links: (),
	group-id: 0,
	link-id: 0,
	named-molecules: (:),
	relative-angle: 0deg,
	in-cycle: false,
	cycle-step-angle: 0deg,
	angle: 0deg
)

#let set-last-anchor(ctx, anchor) = {
	if ctx.last-anchor.type == "link" {
		ctx.links.push(ctx.last-anchor)
	}
	(
		..ctx,
		last-anchor: anchor
	)
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
	if id == -1{
		id = count - 1
	}
	(name: name, anchor: (str(id), "center"))
}

#let link-molecule-anchor(name: none, id, count) = {
	if id >= count {
		panic("This molecule only has " + str(count) + " anchors")
	}
	let to = if id == -1 {
		count - 1
	} else {
		id
	}
	if name == none {
		(name: str(to), anchor: "center")
	} else {
		(name: name, anchor: (str(to), "center"))
	}
}


#let angle-from-ctx(ctx, object, default) = {
	if object.at("relative", default: none) != none {
		object.at("relative") + ctx.relative-angle
	} else if object.at("absolute", default: none) != none {
		object.at("absolute")
	} else if object.at("angle", default: none) != none {
		object.at("angle") * ctx.config.angle-increment
	} else {
		default
	}
}

#let cycle-angle(ctx) = {
	if ctx.in-cycle {
		ctx.relative-angle - (180deg - ctx.cycle-step-angle) / 2
	} else {
		ctx.angle
	}
}

/// Draw a triangle between two molecules
#let cram(from, to, ctx, args) = {
	import cetz.draw : *

	let (ctx, (from-x,from-y,_)) = cetz.coordinate.resolve(ctx, from)
	let (ctx, (to-x, to-y,_)) = cetz.coordinate.resolve(ctx, to)
	let base-length = utils.convert-length(ctx,args.at("base-length", default: .8em))
	line(
		(from-x, from-y - base-length / 2),
		(from-x, from-y + base-length / 2),
		(to-x, to-y),
		close: true,
		stroke: args.at("stroke", default: none),
		fill: args.at("fill", default: black)
	)
}

/// Draw a dashed triangle between two molecules
#let dashed-cram(from, to, length, ctx, args) = {
	import cetz.draw : *
	let (ctx, (from-x,from-y,_)) = cetz.coordinate.resolve(ctx, from)
	let (ctx, (to-x, to-y,_)) = cetz.coordinate.resolve(ctx, to)
	let base-length = utils.convert-length(ctx,args.at("base-length", default: .8em))
	hide({
		line(
			name: "top",
			(from-x, from-y - base-length / 2),
			(to-x, to-y - 0.05)
		)
		line(
			name: "bottom",
			(from-x, from-y + base-length / 2),
			(to-x, to-y + 0.05)
		)
	})
	let dash-sep = utils.convert-length(ctx,args.at("dash-sep", default: .3em))
	let dash-width = args.at("dash-width", default: .05em)
	let converted-dash-width = utils.convert-length(ctx,dash-width)
	let length = utils.convert-length(ctx,length)

	let dash-count = int(calc.ceil(length / (dash-sep + converted-dash-width)))
	let incr = 100% / dash-count

	let percentage = 0%
	while percentage <= 100% {
		line(
			(name: "top", anchor: percentage),
			(name: "bottom", anchor: percentage),
			stroke: args.at("stroke", default: black) + dash-width
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
			(if id == 0 {
					(0,0)
				} else {
					str(id - 1) + ".east"
				}
			),
			eq
		)
		id += 1
	}
}

#let draw-molecule(mol, ctx) = {
	let name = mol.name
	if name != none {
		if ctx.named-molecules.at(name, default: none) != none {
			panic("Molecule with name " + name + " already exists")
		}
		ctx.named-molecules.insert(name, mol)
	} else {
		name = "molecule" + str(ctx.group-id)
	}
	let (anchor, side, coord) = if ctx.last-anchor.type == "coord" {
		("east", true, ctx.last-anchor.anchor)
	} else if ctx.last-anchor.type == "link" {
		let anchor = link-molecule-anchor(ctx.last-anchor.to, mol.count)
		ctx.last-anchor.to-name = name
		ctx.last-anchor.to = link-molecule-index(ctx.last-anchor.angle, true, mol.count - 1)
		(
			anchor,
			false,
			ctx.last-anchor.name + ".end"
		)
	} else {
		panic("A molecule must be linked to a coord or a link")
	}
	ctx = set-last-anchor(ctx,(
		type: "molecule",
		name: name,
		count: mol.at("count")
	))
	ctx.group-id += 1
	(
		name,
		ctx,
		{
			draw.group(
				anchor: if side {anchor} else {"from" + str(ctx.group-id)},
				name: name, 
				{
					draw.set-origin(coord)
					draw.anchor("default", (0,0))
					draw-molecule-text(mol)
					if not side {
						draw.anchor("from" + str(ctx.group-id), anchor)
					}
				}
			)
		}
	)
}

#let angle-override(angle, ctx) = {
	if ctx.in-cycle {
		if angle > 0deg {
			("offset": "right")
		} else {
			("offset": "left")
		}
	} else {
		(:)
	}
}

#let draw-link(link, ctx) = {
	let link-angle = if ctx.in-cycle {
		let link-angle = ctx.cycle-step-angle + ctx.relative-angle
		link-angle
	} else {
		angle-from-ctx(ctx, link, ctx.angle)
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
		from-connection = link-molecule-index(link-angle, false, ctx.last-anchor.count - 1)
		from-connection = link.at("from", default: from-connection)
		from-name = ctx.last-anchor.name
		molecule-link-anchor(ctx.last-anchor.name, from-connection, ctx.last-anchor.count)
	} else if ctx.last-anchor.type == "link" {
		(name: ctx.last-anchor.name, anchor: "end")
	} else {
		panick("Unknown anchor type " + ctx.last-anchor.type)
	}
	let length = link.at("length", default: ctx.config.atom-sep)
	let link-name = "link" + str(ctx.link-id)
	ctx = set-last-anchor(ctx, (
		type: "link",
		name: link-name,
		override: override,
		from-pos: from-pos,
		from-name: from-name,
		from: from-connection,
		to-name: none,
		to: to-connection,
		angle: link-angle,
		draw: link.draw
	))
	ctx.link-id += 1
	(
		ctx,
		draw.get-ctx(ctx => {
			let (ctx, (x1,y1,_)) = cetz.coordinate.resolve(ctx, from-pos)
			let length = utils.convert-length(ctx, length)
			let x = x1 + length * calc.cos(link-angle)
			let y = y1 + length * calc.sin(link-angle)
			draw.hide(
				draw.line(
					name: link-name,
					(x1, y1),
					(x, y)
				)
			)
		})
	)
}

#let draw-molecule-links(mol, molname, ctx) = {
	ctx.named-molecules.insert(molname, mol)
	let last-anchor = ctx.last-anchor
	for (to-name, link) in mol.links {
		ctx.last-anchor = last-anchor
		if ctx.named-molecules.at(to-name, default: none) == none {
			panic("Molecule " + to-name + " does not exist")
		}
		ctx.links.push((
			type: "link",
			name: "link" + str(ctx.link-id),
			from-pos: (name: molname, anchor: "center"),
			from-name: molname,
			to-name: to-name,
			override: angle-override(ctx.angle, ctx),
			from: none,
			to: none,
			draw: link.at(0).draw
		))
		ctx.link-id += 1
	}
	ctx
}

#let draw-molecules-and-link(
	ctx,
	body
) = {
	let molecule-name = ""
	let drawing = ()
	({
		for element in body {
			if type(element) == function {
				(element,)
			} else if element.at("type", default: none) == none {
				panic("Element " + str(element) + " has no type")
			} else if element.type == "molecule" {
				(molecule-name, ctx, drawing) = draw-molecule(element, ctx)
				drawing
				if element.at("links").len() != 0 {
					ctx = draw-molecule-links(element, molecule-name, ctx)
				}
			} else if element.type == "link" {
				(ctx, drawing) = draw-link(element, ctx)
				drawing
			} else if element.type == "branch" {
				let (drawing, branch-ctx) = draw-molecules-and-link(
					(
						..ctx,
						in-cycle: false,
						cycle-step-angle: 0,
						angle: cycle-angle(ctx)
					),
					element.draw
				)
				ctx.named-molecules += branch-ctx.named-molecules
				ctx.links += branch-ctx.links
				ctx.group-id = branch-ctx.group-id
				ctx.link-id = branch-ctx.link-id
				drawing
			} else if element.type == "cycle" {
				let cycle-step-angle = 360deg / element.faces
				let angle = angle-from-ctx(ctx, element, none)
				if angle == none {
					if ctx.in-cycle {
						angle = ctx.relative-angle + ctx.cycle-step-angle + 2 * cycle-step-angle
					} else {
						angle = cycle-angle(ctx) - cycle-step-angle * 1.5
					}
				}
				let (drawing, cycle-ctx) = draw-molecules-and-link(
					(
						..ctx,
						in-cycle: true,
						cycle-step-angle: cycle-step-angle,
						relative-angle: angle,
						angle: angle
					),
					element.draw
				)
				ctx.named-molecules += cycle-ctx.named-molecules
				ctx.links += cycle-ctx.links
				ctx.group-id = cycle-ctx.group-id
				ctx.link-id = cycle-ctx.link-id
				drawing
			} else {
				panic("Unknown element type " + element.type)
			}
		}
		if ctx.last-anchor.type == "link" {
			ctx.links.push(ctx.last-anchor)
		}
	}, ctx)
}

#let molecule-anchor(cetz-ctx, angle, molecule, id) = {
	let (cetz-ctx, (x,y,_)) = cetz.coordinate.resolve(cetz-ctx, (name: molecule, anchor: id))
	let (cetz-ctx, (_,b,_)) = cetz.coordinate.resolve(cetz-ctx, (name: molecule, anchor: (id, "north")))
	let (cetz-ctx, (a,_,_)) = cetz.coordinate.resolve(cetz-ctx, (name: molecule, anchor: (id, "east")))
	let a = (a - x) * 1.2
	let b = (b - y) * 2
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
			link.from = link-molecule-index(angle, false, ctx.named-molecules.at(link.from-name).count - 1)
			link.to = link-molecule-index(angle, true, ctx.named-molecules.at(link.to-name).count - 1)
		}
		(
			(molecule-anchor(cetz-ctx, link.angle, link.from-name, str(link.from)), molecule-anchor(cetz-ctx, link.angle + 180deg, link.to-name, str(link.to))), link.angle
		)
	} else if link.to-name != none {
		let to-pos = (name: link.to-name, anchor: "center")
		if link.to == none {
			let angle = utils.angle-correction(utils.angle-between(cetz-ctx, link.from-pos, to-pos) + 180deg)
			link.angle = angle
			link.to = link-molecule-index(angle, true, ctx.named-molecules.at(link.to-name).count - 1)
		}
		(
			(link.from-pos, molecule-anchor(cetz-ctx, link.angle + 180deg, link.to-name, str(link.to))),
			link.angle
		)
	} else if link.from-name != none {
		(
			(molecule-anchor(cetz-ctx, link.angle, link.from-name, str(link.from)), (name: link.name, anchor: "end")),
			link.angle
		)
	} else {
		((link.from-pos, (name: link.name, anchor: "end")), link.angle)
	}		
}


#let draw-link-decoration(ctx) = {
	import cetz.draw : *
	(
			get-ctx(cetz-ctx => {
				for link in ctx.links {
					let ((from, to), angle) = calculate-link-anchors(ctx, cetz-ctx, link)
					let length = utils.distance-between(cetz-ctx, from, to)
					group(name: "decorations", {
						set-origin(from)
						rotate(angle)
						(link.draw)(length, cetz-ctx, override:link.override)
					})
				}
		}),
		ctx
	)
}

#let draw-skeleton(config:default, body) = {
	let ctx = default-ctx
	ctx.angle = config.base-angle
	ctx.config = config
	let (draw, ctx) = draw-molecules-and-link(ctx, body)
	let (links, _) = draw-link-decoration(ctx)
	{draw
	 links}
}