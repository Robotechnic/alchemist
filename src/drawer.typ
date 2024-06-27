#import "default.typ": default
#import "@preview/cetz:0.2.2"
#import cetz.draw

#let draw-molecule(last_anchor, mol, group-id) = {
	let name = if mol.name == none {
		"molecule" + str(group-id)
		group-id += 1
	} else {
		element.name
	}
	let (anchor, coord) = if last_anchor.type == "coord" {
		("east", last_anchor.anchor)
	} else if last_anchor.type == "link" {
		if last_anchor.to >= mol.count {
			panic("This molecule only has " + str(mol.count) + " anchors")
		}
		(
			(name: "radius" + str(last_anchor.to), anchor: 180deg + last_anchor.angle),
			last_anchor.name + ".end"
		)
	} else {
		panic("A molecule must be linked to a coord or a link")
	}
	(
		name,
		group-id + 1,
		{
			draw.group(
				anchor: "from" + str(group-id),
				name: name, 
				{
					draw.set-origin(coord)
					draw.anchor("default", (0,0))
					mol.draw
					draw.anchor("from" + str(group-id), anchor)
				}
			)
		}
	)
}

#let draw-link(config, link, link-id, last_anchor) = {
	let angle = if link.at("relative", default: none) != none {
		link.at("relative")
	} else if link.at("absolute", default: none) != none {
		link.at("absolute")
	} else {
		link.at("angle", default: 0) * config.angle-increment
	}
	let from_connection = link.at("from", default: -1)
	let to_connection = link.at("to", default: 0)
	let start_pos = if last_anchor.type == "coord" {
		last_anchor.anchor
	} else if last_anchor.type == "molecule" {
		if last_anchor.count <= from_connection {
			panic("The last molecule only has " + str(last_anchor.count) + " connections")
		}
		if from_connection == -1{
			from_connection = last_anchor.count - 1
		}
		(name: last_anchor.name, anchor: ("radius" + str(from_connection), angle))
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
			angle: angle
		),
		draw.group(
			name: "link" + str(link-id), {
				draw.set-origin(start_pos)
				draw.rotate(angle)
				draw.anchor("end", (length,0))
				(link.draw)(
				  length
				)
			}
		)
	)
}

#let draw-skeleton(config: default, body) = {
	let group-id = 0
	let group-name = ""
	let link-id = 0

	let last_anchor = (
		type: "coord",
		anchor: (0,0)
	)

	let drawing = ()
	for element in body {
		if type(element) == function {
			(element,)
		} else if element.at("type", default: none) == none {
			panic("Element " + str(element) + " has no type")
		} else if element.type == "molecule" {
			(group-name, group-id, drawing) = draw-molecule(last_anchor, element, group-id)
			last_anchor = (
				type: "molecule",
				name: group-name,
				count: element.at("count")
			)
			drawing
		} else if element.type == "link" {
			(last_anchor, drawing) = draw-link(config, element, link-id, last_anchor)
			link-id += 1
			drawing
		} else {
			panic("Unknown element type " + element.type)
		}
	}
}