#import "@preview/mantys:0.1.4": *
#import "@preview/alchemist:0.1.0"

#let infos = toml("../typst.toml")
#show: mantys.with(
  ..infos,
  abstract: [
    Alchemist is a package used to draw chemical structures with skeletal formulas using Cetz. It is heavily inspired by the Chemfig package for LaTeX. This package is meant to be easy to use and customizable. It can also be used alongside the cetz package to draw more complex structures.
  ],
  examples-scope: (dictionary(alchemist)),
)

#let example =  example.with(side-by-side: true)

#import alchemist : *

// Some fancy logos
// credits go to discord user @adriandelgado
#let TeX = style(styles => {
  set text(font: "New Computer Modern")
  let e = measure("E", styles)
  let T = "T"
  let E = text(1em, baseline: e.height * 0.31, "E")
  let X = "X"
  box(T + h(-0.15em) + E + h(-0.125em) + X)
})

#let LaTeX = style(styles => {
  set text(font: "New Computer Modern")
  let a-size = 0.66em
  let l = measure("L", styles)
  let a = measure(text(a-size, "A"), styles)
  let L = "L"
  let A = box(scale(x: 110%, text(a-size, baseline: a.height - l.height, "A")))
  box(L + h(-a.width * 0.67) + A + h(-a.width * 0.25) + TeX)
})

#show "LaTeX": LaTeX
#show "@version": infos.package.version



#let info(body) = mty.alert(
	color:rgb("#0074d9"),
	body
)

#add-type("drawable", color: lime)

= Usage

To start using Alchemist, just import the package in your document:

```typ
#import "@preview/alchemist:@version": *
```

== Initializing drawing environment

To start drawing molecules, you first need to initialise the drawing environment. This is done by calling the #cmd[skeletize] function.

```typ
#skeletize({
	...
})
```

The main argument is a block of code that contains the drawing instructions. The block can also contain any cetz code to draw more complex structures, see @exemple-cez.

#command("skeletize", arg(debug: false), arg(background:none), arg(config:(:)), arg("body"))[
	#argument("debug", types:(true))[
		Display bounding boxes of the objects in the drawing environment.
	]
	#argument("background", types:(red, none))[
		Background color of the drawing environment
	]
	#argument("config", types:((:)))[
		Configuration of the drawing environment. See @config.
	]
	#argument("body", types:("drawable"))[
		The module to draw or any cetz drawable object.
	]
]

== Configuration <config>

Th configuration dictionary that you can pass to skeletize defines a set of default values for a lot of parameters in alchemist.

#import "../src/default.typ" : default

#argument("atom-sep", default: default.atom-sep, types: default.atom-sep)[
	It defines the distance between each atom center. It is overridden by the `atom-sep` argument of link
]

#argument("angle-increment", default: default.angle-increment, types: default.angle-increment)[
	It defines the angle added by each increment of the `angle` argument of link
]

#argument("base-angle", default: default.base-angle, types: default.base-angle)[
	Default angle at which the link with no angle defined will be. 
]

== Available commands

#tidy-module(
  read("../lib.typ"),
  name: infos.package.name,
  show-outline: false,
  include-examples-scope: true,
  extract-headings: 3,
)

=== Link functions <links>
==== Common arguments
Links functions are used to draw links between molecules. They all have the same base arguments but can be customized with additional arguments.

#argument("angle", types:(1), default: 0)[
	Multiplier of the `angle-increment` argument of the drawing environment. The final angle is relative to the abscissa axis.
]

#argument("relative", types:(0deg), default: none)[
	Relative angle to the previous link. This argument override all other angle arguments.
]

#argument("absolute", types:(0deg), default: none)[
	Absolute angle of the link. This argument override `angle` argument.
]

#argument("antom-sep", types:(1em), default: default.atom-sep)[
	Distance between the two connected atom of the link. Default to the `atom-sep` entry of the configuration dictionary.
]

#argument("from", types:(0))[
	Index of the molecule in the group to start the link from. By default, it is computed depending on the angle of the link.
]

#argument("to", types:(0))[
	Index of the molecule in the group to end the link to. By default, it is computed depending on the angle of the link.
]

==== Links
#tidy-module(
  read("../src/links.typ"),
  name: infos.package.name,
  show-outline: false,
  include-examples-scope: true,
  extract-headings: 3,
)

= Drawing molecules
== Atoms

In alchemist, the name of the function #cmd("molecule") is used to create a group of atom but here it is a little bit abusive as it do not necessarily represent real molecules. An atom is in our case something of the form: optional number + capital letter + optional lowercase letter + optional \_ number. For the ones interested here is the regex used: `^ *([0-9]*[A-Z][a-z]*)(_[0-9]+)?`.

#info[
	For instance, $H_2O$ is a molecule of the atoms $H_2$ and $O$.
	If we look at the bounding boxes of the molecules, we can see that separation.
	#align(center, grid(
		columns: 2,
		column-gutter: 1em,
		row-gutter: .65em,
		$H_2O$, skeletize(debug:true, molecule("H_2O")),
		$C H_4$, skeletize(debug:true, molecule("CH_4")),
		$C_2 H_6$, skeletize(debug:true, molecule("C_2H_6")),
	))
]

This separation does not have any impact on the drawing of the molecules but it will be useful when we will draw more complex structures.

== Links
There are already som links available with the package (see @links) and you can create your own links with the #cmd[build-link] function but they all share the same base arguments used to control their behaviors.

=== Atom separation
Each atom is separated by a distance defined by the `atom-sep` argument of the drawing environment. This distance can be overridden by the `atom-sep` argument of the link. It defines the distance between the center of the two connected atoms.

The behavior is not well defined yet.

=== Angle
There are three ways to define the angle of a link: using the `angle` argument, the `relative` argument, or the `absolute` argument.

The argument `angle` is a multiplier of the `angle-increment` argument.

#example(```
#skeletize({
	single()
	single(angle:1)
	single(angle:3)
	single()
	single(angle:7)
	single(angle:6)
})
```)

Changing the `angle-increment` argument of the drawing environment will change the angle of the links.

#example(```
#skeletize(config:(angle-increment:20deg),{
	single()
	single(angle:1)
	single(angle:3)
	single()
	single(angle:7)
	single(angle:6)
})
```)

The argument `relative` allows you to define the angle of the link relative to the previous link. 

#example(```
#skeletize({
	single()
	single(relative:20deg)
	single(relative:20deg)
	single(relative:20deg)
	single(relative:20deg)
})
```)

The argument `absolute` allows you to define the angle of the link relative to the abscissa axis.
#example(```
#skeletize({
	single()
	single(absolute:-20deg)
	single(absolute:10deg)
	single(absolute:40deg)
	single(absolute:-90deg)
})
```)

=== Starting and ending points
By default, the starting and ending points of the links are computed depending on the angle of the link. You can override this behavior by using the `from` and `to` arguments.

If the angle is in $]-90deg;90deg]$, the starting point is the last atom of the previous molecule and the ending point is the first atom of the next molecule. If the angle is in $]90deg;270deg]$, the starting point is the first atom of the previous molecule and the ending point is the last atom of the next molecule.

#grid(columns: (1fr,1fr,1fr,1fr),
align: center + horizon,
row-gutter: 1em,
..for i in range(0,8) {
	(skeletize({
		molecule("ABCD")
		single(angle:i)
		molecule("EFGH")
	}),)
})

If you choose to override the starting and ending points, you can use the `from` and `to` arguments. The only constraint is that the index must be in the range $[0, n-1]$ where $n$ is the number of atoms in the molecule.

#grid(columns: (1fr,1fr,1fr,1fr),
align: center,
row-gutter: 1em,
..for i in range(0,4) {
	(skeletize({
		molecule("ABCD")
		single(from:i, to: 3 - i, absolute: 70deg)
		molecule("EFGH")
	}),)
})

#info[
	The fact that you can chose any index for the `from` and `to` arguments can lead to some weird results. Alchemist can't check if he result is beautiful or not.
]

== Branches
Drawing linear molecules is nice but being able to draw molecule with branches is even better. To do so, you can use the #cmd[branch] function.

The principle is simple. When you draw normal molecules, each time an element is added, the attachement point is moved accordingly to the added object. Drawing a branch is a way to tell alchemist that you want the attachement point to say the same for the others elements outside the branch. The only constraint is that the branch must start with a link.

#example(```
#skeletize({
	molecule("A")
	single()
	molecule("B")
	branch({
		single(angle:1)
		molecule("W")
		single()
		molecule("X")
	})
	single()
	molecule("C")
})
```)

It is of course possible to have nested branches or branches with the same starting point.

#example(```
#skeletize({
	molecule("A")
	branch({
		single(angle:1)
		molecule("B")
		branch({
			single(angle:1)
			molecule("W")
			single()
			molecule("X")
		})
		single()
		molecule("C")
	})
	branch({
		single(angle:-2)
		molecule("Y")
		single(angle:-1)
		molecule("Z")
	})
	single()
	molecule("D")
})
```)

You can also specify an angle argument like for links. This angle will be then used as the `base-angle` for the branch. It means that all the links with no angle defined will be drawn with this angle.

#example(```
#skeletize({
	molecule("A")
	single()
	molecule("B")
	branch(relative:60deg,{
		single()
		molecule("D")
		single()
		molecule("E")
  })
	branch(relative:-30deg,{
		single()
		molecule("F")
		single()
		molecule("G")
	})
	single()
	molecule("C")
})
```)

== Link distant atoms

=== Basic usage
From then, the only way to link atoms is to use links functions and putting them one after the other. This doesn't allow to do cycles or to link atoms that are not next to each other in the code. The way alchemist handle this is with the `links` and `name` arguments of the #cmd[molecule] function.

#example(```
	#skeletize({
  molecule(name: "A", "A")
  single()
  molecule("B")
  branch({
    single(angle: 1)
    molecule(
      "W",
      links: (
        "A": single(),
      ),
    )
    single()
    molecule(name: "X", "X")
  })
  branch({
    single(angle: -1)
    molecule("Y")
    single()
    molecule(
      name: "Z",
      "Z",
      links: (
        "X": single(),
      ),
    )
  })
  single()
  molecule(
    "C",
    links: (
      "X": single(),
      "Z": single(),
    ),
  )
})
```)

In this example, we can see that the molecules are linked to the molecules defined before with the `name` argument. Note that you can't link to a molecule that is defined after the current one because the name is not defined yet. It's a limitation of the current implementation.

=== Customizing links
If you look at the previous example, you can see that the links used in the `links` argument are functions. This is because you can still customize the links as you want. The only thing that is not taken into account are the `length` and `angle` arguments. It means that you can change color, `from` and `to` arguments, etc.

#example(```
#skeletize({
  molecule(name: "A", "A")
  single()
  molecule("B")
  branch({
    single(angle: 1)
    molecule(
      "W",
      links: (
        "A": double(stroke: red),
      ),
    )
    single()
    molecule(name: "X", "X")
  })
  branch({
    single(angle: -1)
    molecule("Y")
    single()
    molecule(
      name: "Z",
      "Z",
      links: (
        "X": single(stroke: black + 3pt),
      ),
    )
  })
  single()
  molecule(
    "C",
    links: (
      "X": cram-filled-left(fill: blue),
      "Z": single(),
    ),
  )
})```)


== Integration with cetz <exemple-cez>