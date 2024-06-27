#import "default.typ": default
#import "@preview/cetz:0.2.2"
#import cetz.draw

#let angle-correction(angle) = {
	calc.rem(angle.deg(), 360) * 1deg
}

#let angle-in-range(angle, from, to) = {
	angle = if angle < 0deg {
		angle + 360deg
	} else {
		angle
	}
	angle >= from and angle < to
}

#let angle-to-anchor(angle) = {
	if angle < 45deg and angle > -45deg {
		"east"
	} else if angle-in-range(angle, 45deg, 135deg) {
		"north"
	} else if angle-in-range(angle, 135deg, 225deg) {
		"west"
	} else if angle-in-range(angle, 225deg, 315deg) {
		"south"
	} else {
		panic("Unknown angle " + str(angle.deg()))
	}
}

#let link-anchor(angle, end) = {
	if angle-in-range(angle, 85deg, 95deg) or angle-in-range(angle, 265deg, 275deg) {
		"center"
	} else if angle > -90deg and angle < 90deg {
		if end {
			0
		} else {
			-1
		}
	} else if end {
		-1
	} else {
		0
	}
}

#let draw-molecule(last_anchor, mol, group-id) = {
	let name = if mol.name == none {
		"molecule" + str(group-id)
	} else {
		element.name
	}
	let (anchor, side, coord) = if last_anchor.type == "coord" {
		("east", true, last_anchor.anchor)
	} else if last_anchor.type == "link" {
		last_anchor.angle = angle-correction(last_anchor.angle + 180deg)
		let (text-anchor, side) = if last_anchor.to == "center" {
			(angle-to-anchor(last_anchor.angle), true)
		} else {
			if last_anchor.to >= mol.count {
				panic("This molecule only has " + str(mol.count) + " anchors")
			}
			let to = if last_anchor.to == -1 {
				mol.count - 1
			} else {
				last_anchor.to
			}
			((name: "radius" + str(to), anchor: last_anchor.angle), false)
		}
		(
			text-anchor,
			side,
			last_anchor.name + ".end"
		)
	} else {
		panic("A molecule must be linked to a coord or a link")
	}
	(
		name,
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
	link-angle = angle-correction(link-angle)
	let from_connection = link-anchor(link-angle, false)
	let to_connection = link-anchor(link-angle, true)
	let from_connection = link.at("from", default: from_connection)
	let to_connection = link.at("to", default: to_connection)

	let start_pos = if last_anchor.type == "coord" {
		last_anchor.anchor
	} else if last_anchor.type == "molecule" {
		if from_connection == "center" {
			(name: last_anchor.name, anchor: angle-to-anchor(link-angle))
		} else {
			if last_anchor.count <= from_connection {
				panic("The last molecule only has " + str(last_anchor.count) + " connections")
			}
			if from_connection == -1{
				from_connection = last_anchor.count - 1
			}
			(name: last_anchor.name, anchor: ("radius" + str(from_connection), link-angle))
		}
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
	body
) = {
	let group-id = 0
	let link-id = 0

	let group-name = ""
	let drawing = ()
	for element in body {
		if type(element) == function {
			(element,)
		} else if element.at("type", default: none) == none {
			panic("Element " + str(element) + " has no type")
		} else if element.type == "molecule" {
			(group-name, drawing) = draw-molecule(last-anchor, element, group-id)
			group-id += 1
			last-anchor = (
				type: "molecule",
				name: group-name,
				count: element.at("count")
			)
			drawing
		} else if element.type == "link" {
			(last-anchor, drawing) = draw-link(config, element, link-id, last-anchor)
			link-id += 1
			drawing
		} else if element.type == "branch" {
			draw-skeleton(
				config: config, 
				last-anchor: last-anchor,	
				element.draw,
				group-id: group-id,
				link-id: link-id
			)
		} else {
			panic("Unknown element type " + element.type)
		}
	}
}