#import "@preview/cetz:0.2.2"
#let draw = cetz.draw

#let default = (
	atom-sep: 3em,
	angle-increment: 45deg
)

/// Build a molecule group based on mol
/// Each molecule is represented as an opinal count folowed by a molecule name
/// starting by a capital letter followed by an optional indice
/// Example: "H_2O", "2Aa_7 3Bb"
#let molecule(
	name: none,
	mol
) = {
	let aux(str) = {
		let match = str.match(regex("^ *([0-9]*[A-Z][a-z]*)(_[0-9]+)?"))
		if match == none {
			panic(str + " is not a valid atom")
		}
		let eq = "\"" + match.captures.at(0) + "\""
		if match.captures.len() >= 2 {
			eq +=  match.captures.at(1)
		}
		let eq = math.equation(eval(eq, mode: "math"))
		(eq, match.end)
	}

	let id = 0
	let cetz-content = (
		while not mol.len() == 0 {
			let (eq, end) = aux(mol)
			mol = mol.slice(end)
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
			draw.get-ctx(ctx => {
				let (ctx, (x1,_,_), (x2,_,_)) = cetz.coordinate.resolve(ctx, name + ".west", name + ".east")
				let radius = (x2 - x1) / 2
				radius += radius * 0.4
				// this circle is used to connect the links to molecules
				draw.hide(
					draw.circle(
						name: "radius" + name, 
						name,
						radius: (radius, .6em),
					)
				)
			})
			id += 1
	})
	((type: "molecule",
	  name: name,
	  draw: cetz-content, 
		count: id),)
}

#let build-link(draw-function) = {
	(..args) => {
		if args.pos().len() != 0 {
			panic("Links takes no positional arguments")
		}
		((
		type: "link",
		draw: draw-function,
		..args.named()
	),)}
}

#let single = build-link((from, to) => {
	draw.line(from, to)
})

#let double = build-link((from, to) => {
	draw.translate((0,-.1em))
	draw.line(from, to)
	draw.translate((0,.2em))
	draw.line(from, to)
})

#let triple = build-link((from, to) => {
	draw.line(from, to)
	draw.translate((0, -.2em))
	draw.line(from, to)
	draw.translate((0, .4em))
	draw.line(from, to)
})
			

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
					(0,0),
					(length, 0)
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

#let skeletize(
	debug: false,
	background: none,
	config: default,
	body
) = {		
	cetz.canvas(
		debug: debug,
		background: background,
		draw-skeleton(config: config, body)
	)
}

#skeletize({
	single(angle:1, to: 0)
	molecule("H_2O")
	double(angle:-0)
	molecule("H")
	double(angle: -1)
	molecule("C")
})

