#import "default.typ": default
#import "@preview/cetz:0.2.2"
#import "utils.typ"
#import cetz.draw

#let angle-to-anchor(angle) = {
	if angle < 45deg and angle > -45deg {
		"east"
	} else if utils.angle-in-range(angle, 45deg, 135deg) {
		"north"
	} else if utils.angle-in-range(angle, 135deg, 225deg) {
		"west"
	} else if utils.angle-in-range(angle, 225deg, 315deg) {
		"south"
	} else {
		panic("Unknown angle " + str(angle.deg()))
	}
}

#let link-molecule-index(angle, end, count) = {
	if utils.angle-in-range(angle, 85deg, 95deg) or utils.angle-in-range(angle, 265deg, 275deg) {
		"center"
	} else if angle > -90deg and angle < 90deg {
		if end {
			0
		} else {
			count
		}
	} else if end {
		count
	} else {
		0
	}
}

#let molecule-link-anchor(name, id, count, link-angle) = {
	if id == "center" {
		(name: name, anchor: angle-to-anchor(link-angle))
	} else {
		if count <= id {
			panic("The last molecule only has " + str(count) + " connections")
		}
		if id == -1{
			id = count - 1
		}
		(name: name, anchor: ("radius" + str(id), link-angle))
	}
}

#let link-molecule-anchor(id, angle, count) = {
	if id == "center" {
		angle-to-anchor(angle)
	} else {
		if id >= count {
			panic("This molecule only has " + str(count) + " anchors")
		}
		let to = if id == -1 {
			count - 1
		} else {
			id
		}
		(name: "radius" + str(to), anchor: angle)
	}
}

/// Draw a triangle between two molecules
#let cram(from, to, args) = {
	import cetz.draw : *

	get-ctx(ctx => {
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
	})
}


#let draw-molecule(last_anchor, mol, group-id) = {
	let name = if mol.name == none {
		"molecule" + str(group-id)
	} else {
		mol.name
	}
	let (anchor, side, coord) = if last_anchor.type == "coord" {
		("east", true, last_anchor.anchor)
	} else if last_anchor.type == "link" {
		last_anchor.angle = utils.angle-correction(last_anchor.angle + 180deg)
		let side = last_anchor.to == "center"
		let anchor = link-molecule-anchor(last_anchor.to, last_anchor.angle, mol.count)
		(
			anchor,
			side,
			last_anchor.name + ".end"
		)
	} else {
		panic("A molecule must be linked to a coord or a link")
	}
	(
		name,
		(
				type: "molecule",
				name: name,
				count: mol.at("count")
		),
		{
			draw.group(
				anchor: if side {anchor} else {"from" + str(group-id)},
				name: name, 
				{
					draw.set-origin(coord)
					draw.anchor("default", (0,0))
					mol.draw
					if not side {
						draw.anchor("from" + str(group-id), anchor)
					}
				}
			)
		}
	)
}

#let draw-link(config, link, link-id, last_anchor) = {
	let link-angle = if link.at("relative", default: none) != none {
		link.at("relative")
	} else if link.at("absolute", default: none) != none {
		link.at("absolute")
	} else {
		link.at("angle", default: 0) * config.angle-increment
	}
	link-angle = utils.angle-correction(link-angle)
	
	let to_connection = link-molecule-index(link-angle, true, -1)
	let to_connection = link.at("to", default: to_connection)

	let start_pos = if last_anchor.type == "coord" {
		last_anchor.anchor
	} else if last_anchor.type == "molecule" {
		let from_connection = link-molecule-index(link-angle, false, last_anchor.count - 1)
		let from_connection = link.at("from", default: from_connection)
		molecule-link-anchor(last_anchor.name, from_connection, last_anchor.count, link-angle)
	} else if last_anchor.type == "link" {
		(name: last_anchor.name, anchor: "end")
	} else {
		panick("Unknown anchor type " + last_anchor.type)
	}
	let length = link.at("length", default: config.atom-sep)
	(
		(
			type: "link",
			name: "link" + str(link-id),
			to: to_connection,
			angle: link-angle
		),
		draw.group(
			name: "link" + str(link-id), {
				draw.set-origin(start_pos)
				draw.rotate(link-angle)
				draw.anchor("end", (length,0))
				(link.draw)(
				  length
				)
			}
		)
	)
}

#let draw-molecule-links(config, mol, molecule-name, link-id, named-molecules) = {
	import cetz.draw : *
	(link-id + named-molecules.len(), get-ctx(ctx => {
		let (ctx, (x1, y1, _)) = cetz.coordinate.resolve(ctx, (name:molecule-name, anchor:"center"))
		for (id, (name, link)) in mol.links.pairs().enumerate(start: link-id) {
			let to_molecule = named-molecules.at(name, default: none)
			if to_molecule == none {
				panic("Molecule " + name + " does not exist")
			}
			if link.len() != 1 {
				panic("A link must be exactly one element")
			}
			if link.at(0).type != "link" {
				panic("Molecule link must be a link")
			}
			let link = link.at(0).draw
			let (ctx, (x2, y2,_)) = cetz.coordinate.resolve(
				ctx, (name: name, anchor: "center"))
			let angle = calc.atan2(x2 - x1, y2 - y1)
			let to-angle = utils.angle-correction(angle + 180deg)
			let from_index = link-molecule-index(angle, false, mol.count - 1)
			let to_index = link-molecule-index(to-angle, true, to_molecule.count - 1)
			let from_anchor = molecule-link-anchor(molecule-name, from_index, mol.count, angle)
			let to_anchor = molecule-link-anchor(name, to_index, to_molecule.count, to-angle)
			let (ctx, (x1, y1, _), (x2, y2, _)) = cetz.coordinate.resolve(
				ctx, from_anchor, to_anchor)
			let distance = calc.sqrt(calc.pow((x2 - x1),2) + calc.pow((y2 - y1),2))
			draw.group(name: "link" + str(id),
			{
				draw.set-origin(from_anchor)
				draw.rotate(angle)
				link(distance, override:(angle: none, relative: none, absolute: angle))
			})
		}
	}))
}

#let default-anchor = (
	type: "coord",
	anchor: (0,0)
)

#let draw-skeleton(
	config: default, 
	last-anchor: 
	default-anchor, 
	group-id: 0,
	link-id: 0,
	named-molecules: (:),
	body
) = {
	let molecule-name = ""
	let drawing = ()
	(for element in body {
		if type(element) == function {
			(element,)
		} else if element.at("type", default: none) == none {
			panic("Element " + str(element) + " has no type")
		} else if element.type == "molecule" {
			if element.name != none {
				if named-molecules.at(element.name, default: none) != none {
					panic("Molecule with name " + element.name + " already exists")
				}
				named-molecules.insert(element.name, element)
			}
			(molecule-name, last-anchor, drawing) = draw-molecule(last-anchor, element, group-id)
			drawing
			if element.at("links").len() != 0 {
				(link-id, drawing) = draw-molecule-links(config, element, molecule-name, link-id, named-molecules)
				drawing
			}
			group-id += 1
		} else if element.type == "link" {
			(last-anchor, drawing) = draw-link(config, element, link-id, last-anchor)
			link-id += 1
			drawing
		} else if element.type == "branch" {
			(drawing, group-id, link-id, named-molecules) = draw-skeleton(
				config: config, 
				last-anchor: last-anchor,	
				element.draw,
				group-id: group-id,
				link-id: link-id,
				named-molecules: named-molecules
			)
			drawing
		} else {
			panic("Unknown element type " + element.type)
		}
	}, group-id, link-id, named-molecules)
}