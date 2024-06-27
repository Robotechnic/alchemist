#import "@preview/cetz:0.2.2"
#import "src/default.typ": default
#import "src/utils.typ"
#import "src/drawer.typ"


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
	import cetz.draw
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

/// Create a link function that is hen used to draw a link between two points
/// The draw-function is a function that takes two points, the start and the end of the link
/// and a dictionary of named arguments that can be used to configure the links
#let build-link(draw-function) = {
	(..args) => {
		if args.pos().len() != 0 {
			panic("Links takes no positional arguments")
		}
		((
		type: "link",
		draw: (length) => draw-function(length, args.named()),
		..args.named()
	),)}
}

/// Draw a single line between two molecules
#let single = build-link((length, args) => {
	import cetz.draw : *
	line((0,0), (length,0), stroke: args.at("stroke", default: black))
})

/// Draw a double line between two molecules
#let double = build-link((length, args) => {
	import cetz.draw : *
	translate((0,-.1em))
	line((0,0), (length,0), stroke: args.at("stroke", default: black))
	translate((0,.2em))
	line((0,0), (length,0), stroke: args.at("stroke", default: black))
})

/// Draw a triple line between two molecules
#let triple = build-link((length, args) => {
	import cetz.draw : *
	line((0,0), (length,0), stroke: args.at("stroke", default: black))
	translate((0, -.2em))
	line((0,0), (length,0), stroke: args.at("stroke", default: black))
	translate((0, .4em))
	line((0,0), (length,0), stroke: args.at("stroke", default: black))
})

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

/// Draw a filled cram between two molecules with the arrow pointing to the right
#let cram-filled-right = build-link((length, args) => cram((0,0), (length,0), args))

/// Draw a filled cram between two molecules with the arrow pointing to the left
#let cram-filled-left = build-link((length, args) => cram((length,0), (0,0), args))

/// Draw a holow cram between two molecules with the arrow pointing to the right
#let cram-holow-right = build-link((length, args) => {
	args.fill = none
	args.stroke = args.at("stroke", default: black)
	cram((0,0), (length,0), args)
})

/// Draw a holow cram between two molecules with the arrow pointing to the left
#let cram-holow-left = build-link((length, args) => {
	args.fill = none
	args.stroke = args.at("stroke", default: black)
	cram((length,0), (0,0), args)
})

#let dashed-cram(from, to, length, args) = {
	import cetz.draw : *
	get-ctx(ctx => {
		let (ctx, (from-x,from-y,_)) = cetz.coordinate.resolve(ctx, from)
		let (ctx, (to-x, to-y,_)) = cetz.coordinate.resolve(ctx, to)
		let base-length = utils.convert-length(ctx,args.at("base-length", default: .8em))
		hide({
			line(
				name: "top",
				(from-x, from-y - base-length / 2),
				(to-x, to-y)
			)
			line(
				name: "bottom",
				(from-x, from-y + base-length / 2),
				(to-x, to-y)
			)
		})
		let dash-sep = utils.convert-length(ctx,args.at("dash-sep", default: .3em))
		let dash-width = args.at("dash-width", default: .05em)
		let converted-dash-width = utils.convert-length(ctx,dash-width)
		let length = utils.convert-length(ctx,length)

		let dash-count = int(calc.ceil(length / (dash-sep + converted-dash-width)))

		let i = 0
		let percentage = 0
		while percentage <= 1 {
			percentage = i / dash-count
			i += 1
			line(
				(name: "top", anchor: percentage),
				(name: "bottom", anchor: percentage),
				stroke: args.at("stroke", default: black) + dash-width
			)
		}
	})
}

/// Draw a dashed cram between two molecules with the arrow pointing to the right
#let dashed-cram-right = build-link((length, args) => dashed-cram((0,0), (length,0), length, args))

/// Draw a dashed cram between two molecules with the arrow pointing to the left
#let dashed-cram-left = build-link((length, args) => dashed-cram((length,0), (0,0), length, args))

/// setup a molecule skeleton drawer
#let skeletize(
	debug: false,
	background: none,
	config: default,
	body
) = {		
	cetz.canvas(
		debug: debug,
		background: background,
		drawer.draw-skeleton(config: config, body)
	)
}

#skeletize({
	single(angle:1, to: 0)
	molecule("H_2O")
	double(angle:-0)
	molecule("H")
	cram-filled-right()
	molecule("C")
	cram-filled-left()
	cram-holow-left()
	cram-holow-right()
	dashed-cram-right()
	molecule("H")
	dashed-cram-left()
})

