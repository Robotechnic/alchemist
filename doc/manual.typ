#import "@preview/mantys:1.0.2": *
#import "../lib.typ" as alchemist
#import "@preview/cetz:0.5.2"

#let infos = toml("../typst.toml")
#show: mantys(
  ..infos,
  abstract: [
    Alchemist is a package used to draw chemical structures with skeletal formulas using Cetz. It is heavily inspired by the Chemfig package for LaTeX. This package is meant to be easy to use and customizable. It can also be used alongside the cetz package to draw more complex structures.
  ],
  examples-scope: (
    scope: (
      alchemist: alchemist,
    ),
    imports: (
      alchemist: "*",
    ),
  ),
)

#let example = example.with(side-by-side: true)

#import alchemist: *

// Some fancy logos
// credits go to discord user @adriandelgado
#let TeX = context {
  set text(font: "New Computer Modern")
  let e = measure("E", styles)
  let T = "T"
  let E = text(1em, baseline: e.height * 0.31, "E")
  let X = "X"
  box(T + h(-0.15em) + E + h(-0.125em) + X)
}

#let LaTeX = context {
  set text(font: "New Computer Modern")
  let a-size = 0.66em
  let l = measure("L", styles)
  let a = measure(text(a-size, "A"), styles)
  let L = "L"
  let A = box(scale(x: 110%, text(a-size, baseline: a.height - l.height, "A")))
  box(L + h(-a.width * 0.67) + A + h(-a.width * 0.25) + TeX)
}

#show "LaTeX": LaTeX
#show "@version": infos.package.version

#let info(body) = alert(
  "info",
  body,
)

#custom-type("drawable", color: lime)

= Usage

To start using Alchemist, just import the package in your document:

```typ
#import "@preview/alchemist:@version": *
```

== Initializing drawing environment

To start drawing molecules, you first need to initialize the drawing environment. This is done by calling the #cmd[skeletize] function.

```typ
#skeletize({
	...
})
```

The main argument is a block of code that contains the drawing instructions. The block can also contain any cetz code to draw more complex structures, see @integration-with-cetz.

#command("skeletize", arg(debug: false), arg(background: none), arg(config: (:)), arg("body"), ret: content)[
  #argument("debug", types: true)[
    Display bounding boxes of the objects in the drawing environment.
  ]
  #argument("background", types: (red, none))[
    Background color of the drawing environment
  ]
  #argument("config", types: (:))[
    Configuration of the drawing environment. See @config.
  ]
  #argument("body", types: "drawable")[
    The module to draw or any cetz drawable object.
  ]
]

#command("skeletize-config", arg(config: (:)), ret: function)[
  Create a #cmd[skeletize] function with the given configuration. The returned function uses this configuration as default.
  #argument("config", types: (:))[
    Configuration of the drawing environment. See @config.
  ]
]

== Drawing a molecule directly in Cetz

Sometimes, you may want to draw a molecule directly in cetz. To do so, you can use the #cmd[draw-skeleton] function. This function is what is used internally by the #cmd[skeletize] function.

#command("draw-skeleton", arg(config: (:)), arg("body"), ret: "drawable")[
  #argument("config", types: (:))[
    Configuration of the drawing environment. See @config.
  ]
  #argument("body", types: "drawable")[
    The module to draw or any cetz drawable object.
  ]
  #argument("name", types: "", default: none)[
    If a name is provided, the molecule will be placed in a cetz group with this name.
  ]
  #argument("mol-anchor", types: "", default: none)[
    Anchor of the group. It is working the same way as the `anchor` argument of the cetz `group` function. The `default` anchor
    of the molecule is the east anchor of the first atom or the starting point of the first link.
  ]
]

#command("draw-skeleton-config", arg(config: (:)), ret: function)[
  Create a #cmd[draw-skeleton] function with the given configuration. The returned function uses this configuration as default.
  #argument("config", types: (:))[
    Configuration of the drawing environment. See @config.
  ]
]

The usefulness of this function comes when you want to draw multiple molecules in the same cetz environment. See @integration-with-cetz.

== Configuration <config>

The configuration dictionary that you can pass to skeletize defines a set of default values for a lot of parameters in alchemist.

#import "../src/default.typ": default

#argument("atom-sep", default: default.atom-sep, types: default.atom-sep)[
  It defines the distance between each atom center. It is overridden by the `atom-sep` argument of link
]

#argument("angle-increment", default: default.angle-increment, types: default.angle-increment)[
  It defines the angle added by each increment of the `angle` argument of link
]

#argument("base-angle", default: default.base-angle, types: default.base-angle)[
  Default angle at which a link with no angle defined will be.
]

#argument("fragment-margin", default: default.fragment-margin, types: default.fragment-margin)[
  Default space between a molecule and all its attachments (links and lewis formulae elements).
]

#argument("fragment-color", default: default.fragment-color, types: red)[
  Default color of the fragments. It is used to color the atoms in the molecule.
]

#argument("fragment-font", default: default.fragment-font, types: str)[
  Default font of the fragments. It is used to display the atoms in the molecule.
]

#argument("link-over-radius", default: default.link-over-radius, types: (default.link-over-radius, 1em))[
  Default radius around the links used to hide overlapped links.
]

=== Link default style
The default values also contain styling arguments for the links. You can specify default `stroke`, `fill`, `dash`, etc, depending on the link type. The default values for each link are in a dictionary named after the link name.


#grid(
  columns: (1fr, 1fr),
  align: center,
  row-gutter: 2em,
  column-gutter: 1em,
  ..for (key, value) in default {
    if type(value) != dictionary {
      continue
    }
    (
      block(breakable: false)[
        #key
        #table(
          columns: 2,
          "Argument", "Default value",
          ..for (k, v) in value {
            (k, repr(v))
          },
        )
      ],
    )
  },
)

== Available commands

#tidy-module(
  "alchemist",
  read("../lib.typ"),
  show-outline: false,
  first-heading-level: 3,
  sort-functions: none,
  legacy-parser: true,
)

=== Link functions <links>
==== Common arguments
Link functions are used to draw links between fragments. They all have the same base arguments but can be customized with additional arguments.

#argument("angle", types: 1, default: 0)[
  Multiplier of the `angle-increment` argument of the drawing environment. The final angle is relative to the abscissa axis.
]

#argument("relative", types: 0deg, default: none)[
  Relative angle to the previous link. This argument override all other angle arguments.
]

#argument("absolute", types: 0deg, default: none)[
  Absolute angle of the link. This argument override `angle` argument.
]

#argument("atom-sep", types: 1em, default: default.atom-sep)[
  Distance between the two connected atoms of the link. Default to the `atom-sep` entry of the configuration dictionary.
]

#argument("from", types: 0)[
  Index of the fragment in the group to start the link from. By default, it is computed depending on the angle of the link.
]

#argument("to", types: 0)[
  Index of the fragment in the group to end the link to. By default, it is computed depending on the angle of the link.
]

#argument("links", types: (:))[
  Dictionary of links to other fragments or hooks. The key is the name of the fragment or the hook and the value is the link function.
]

#argument("over", types: ((:), (), str))[
  If the link overlaps other links and is drawn over them, this argument can be used to specify that you want to hide the overlapped links.
  There are three possible values:
  - #dtype("string"): The name of the link to overlap
  - #dtype("dict"): A dictionary containing the keys:
    - `name`: The name of the link to overlap
    - `length`: The length of the overlap mask
    - `radius`: The distance from the link center to the edge of the mask
  - #dtype("array"): An array of the two above.
]

==== Links
#tidy-module(
  "alchemist-links",
  read("../src/elements/links.typ"),
  show-outline: false,
  first-heading-level: 3,
  legacy-parser: true,
)

=== Lewis structures <lewis>
All the lewis elements have two common arguments to control their position:
#argument("angle", types: 0deg, default: default.lewis.angle)[
  Angle of the lewis element relative to the abscissa axis.
]

#argument("fragment-margin", types: (default.lewis.radius), default: default.lewis.radius)[
  Space between the lewis element and the fragment.
]

#tidy-module(
  "alchemist-lewis",
  read("../src/elements/lewis.typ"),
  show-outline: false,
  first-heading-level: 3,
  legacy-parser: true,
)

=== Molecule engine <molecule-engine-cmds>
High-level declarative API. See @molecule-engine for a usage walkthrough.

#tidy-module(
  "alchemist-chem",
  read("../src/elements/chem/chem.typ"),
  show-outline: false,
  first-heading-level: 3,
  legacy-parser: true,
)

= Drawing molecules
== Atoms

In alchemist, the name of the function #cmd("fragment") is used to create a group of atom in a molecule. A fragment is in our case something of the form: optional number + capital letter + optional lowercase letter optionally followed by a charge, an exponent or a subscript.

#info[
  For instance, $H_2O$ is a molecule of the atoms $H_2$ and $O$.
  If we look at the bounding boxes of the molecules, we can see that separation.
  #align(
    center,
    grid(
      columns: 2,
      column-gutter: 1em,
      row-gutter: .65em,
      $H_2O$, skeletize(debug: true, fragment($H_2O$)),
      $C H_4$, skeletize(debug: true, fragment($C H_4$)),
      $C_2 H_6$, skeletize(debug: true, fragment($C_2H_6$)),
      $R'^2$, skeletize(debug: true, fragment($R'^2$)),
    ),
  )
]

This separation does not have any impact on the drawing of the molecules but it will be useful when we will draw more complex structures.

== Links
There are already some links available with the package (see @links) and you can create your own links with the #cmd[build-link] function but they all share the same base arguments used to control their behavior.

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

If the angle is in $]-90deg;90deg]$, the starting point is the last atom of the previous fragment and the ending point is the first atom of the next fragment. If the angle is in $]90deg;270deg]$, the starting point is the first atom of the previous fragment and the ending point is the last atom of the next fragment.

#grid(
  columns: (1fr, 1fr, 1fr, 1fr),
  align: center + horizon,
  row-gutter: 1em,
  ..for i in range(0, 8) {
    (
      skeletize({
        fragment("ABCD")
        single(angle: i)
        fragment("EFGH")
      }),
    )
  }
)

If you choose to override the starting and ending points, you can use the `from` and `to` arguments. The only constraint is that the index must be in the range $[0, n-1]$ where $n$ is the number of atoms in the fragment.

#grid(
  columns: (1fr, 1fr, 1fr, 1fr),
  align: center,
  row-gutter: 1em,
  ..for i in range(0, 4) {
    (
      skeletize({
        fragment("ABCD")
        single(from: i, to: 3 - i, absolute: 70deg)
        fragment("EFGH")
      }),
    )
  }
)

#info[
  The fact that you can choose any index for the `from` and `to` arguments can lead to some weird results. Alchemist can't check if the result is beautiful or not.
]

== Branches
Drawing linear molecules is nice but being able to draw molecules with branches is even better. To do so, you can use the #cmd[branch] function.

The principle is simple. When you draw normal molecules, each time an element is added, the attachment point is moved accordingly to the added object. Drawing a branch is a way to tell alchemist that you want the attachment point to say the same for the others elements outside the branch. The only constraint is that the branch must start with a link.

#example(```
#skeletize({
	fragment("A")
	single()
	fragment("B")
	branch({
		single(angle:1)
		fragment("W")
		single()
		fragment("X")
	})
	single()
	fragment("C")
})
```)

It is of course possible to have nested branches or branches with the same starting point.

#example(```
#skeletize({
	fragment("A")
	branch({
		single(angle:1)
		fragment("B")
		branch({
			single(angle:1)
			fragment("W")
			single()
			fragment("X")
		})
		single()
		fragment("C")
	})
	branch({
		single(angle:-2)
		fragment("Y")
		single(angle:-1)
		fragment("Z")
	})
	single()
	fragment("D")
})
```)

You can also specify an angle argument like for links. This angle will be then used as the `base-angle` for the branch. It means that all the links with no angle defined will be drawn with this angle.

#example(```
#skeletize({
	fragment("A")
	single()
	fragment("B")
	branch(relative:60deg,{
		single()
		fragment("D")
		single()
		fragment("E")
  })
	branch(relative:-30deg,{
		single()
		fragment("F")
		single()
		fragment("G")
	})
	single()
	fragment("C")
})
```)

== Link distant atoms

=== Basic usage
From then on, the only way to link atoms is to use link functions and put them one after the other. This doesn't allow doing cycles or linking atoms that are not next to each other in the code. The way alchemist handles this is with the `links` and `name` arguments of the #cmd[fragment] function.

#example(```
	#skeletize({
  fragment(name: "A", "A")
  single()
  fragment("B")
  branch({
    single(angle: 1)
    fragment(
      "W",
      links: (
        "A": single(),
      ),
    )
    single()
    fragment(name: "X", "X")
  })
  branch({
    single(angle: -1)
    fragment("Y")
    single()
    fragment(
      name: "Z",
      "Z",
      links: (
        "X": single(),
      ),
    )
  })
  single()
  fragment(
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
  fragment(name: "A", "A")
  single()
  fragment("B")
  branch({
    single(angle: 1)
    fragment(
      "W",
      links: (
        "A": double(stroke: red),
      ),
    )
    single()
    fragment(name: "X", "X")
  })
  branch({
    single(angle: -1)
    fragment("Y")
    single()
    fragment(
      name: "Z",
      "Z",
      links: (
        "X": single(stroke: black + 3pt),
      ),
    )
  })
  single()
  fragment(
    "C",
    links: (
      "X": cram-filled-left(fill: blue),
      "Z": single(),
    ),
  )
})
```)

== Cycles

=== Basic usage

Using branches and `links` arguments, you can draw cycles. However, depending on the number of faces, the angle calculation is fastidious. To help you with that, you can use the #cmd[cycle] function.

The default behavior if the angle is $0deg$ is to be placed in a way that the last link is vertical.
#example(```
	#skeletize({
		fragment("A")
		cycle(5, {
			single()
			fragment("B")
			double()
			fragment("C")
			single()
			fragment("D")
			single()
			fragment("E")
			double()
		})
	})
```)

If the angle is not $0deg$ or if the `align` argument is set, the cycle will be drawn in relation with the relative angle of the last link.

#example(```
	#skeletize({
		single()
		fragment("A")
		cycle(5, align: true, {
			single()
			fragment("B")
			double()
			fragment("C")
			single()
			fragment("D")
			single()
			fragment("E")
			double()
		})
	})
```)

A cycle must start by a link and if there is more links than the number of faces, the excess links will be ignored. Nevertheless, it is possible to have less links than the number of faces.

#example(```
	#skeletize({
		cycle(4,{
			single()
			fragment("A")
			single()
			fragment("B")
			single()
			fragment("C")
			single()
			fragment("D")
		})
	})
```)

=== Branches in cycles

It is possible to add branches in cycles. You can add a branch at any point of the cycle. The default angle of the branch will be set in a way that it is the bisector of the two links that are next to the branch.

#example(```
	#skeletize({
		cycle(5,{
			branch({
				single()
				fragment("A")
				double()
				fragment("B")
				single()
				fragment("C")
			})
			single()
			branch({
				single()
				fragment("D")
				single()
				fragment("E")
			})
			single()
			branch({
				double()
			})
			single()
			branch({
				single()
				fragment("F")
			})
			single()
			branch({
				single()
				fragment("G")
				double()
			})
			single()
			single()
			single()
			single()
		})
	})
```)


=== Cycles imbrication

Like branches, you can add cycles in cycles. By default the cycle will be placed in a way that the two cycles share a common link.

#example(```
	#skeletize({
		fragment("A")
		cycle(7,{
			single()
			fragment("B")
			cycle(5,{
				single()
				single()
				single()
				single()
			})
			double()
			single()
			double()
			cycle(4,{
				single()
				single()
				single()
			})
			single()
			double()
			single()
		})
	})
```)

=== Issues with atom groups

Cycles by default have an issue with atom groups with multiples atoms. The links are not well placed for the cycle to be drawn correctly.

#example(```
	#skeletize({
		fragment("AB")
		cycle(5,{
			single()
			fragment("CDE")
			single()
			fragment("F")
			single()
			fragment("GH")
			single()
			fragment("I")
			single()
		})
	})
```)

To fix that, you have to use the `from` and `to` arguments of the links to specify the starting and ending points of the links.

#example(```
	#skeletize({
		fragment("AB")
		cycle(5,{
			single(from: 1, to: 0)
			fragment("CDE")
			single(from: 0)
			fragment("F")
			single(to: 0)
			fragment("GH")
			single(from: 0)
			fragment("I")
			single(to: 1)
		})
	})
```)

=== Arcs

It is possible to draw arcs in cycles. The `arc` argument is a dictionary with the following entries:
#argument("start", types: 0deg, default: 0deg)[
  Angle at which the arc starts.
]
#argument("end", types: 0deg, default: 360deg)[
  Angle at which the arc ends.
]
#argument("delta", types: 0deg, default: none)[
  Angle of the arc in degrees.
]
#argument("radius", types: 0.1, default: none)[
  Radius of the arc in percentage of the smallest distance between two opposite atoms in the cycle. By default, it is set to $0.7$ for cycle with more than $4$ faces and $0.5$ for cycle with $4$ or $3$ faces.
]
Any styling argument of the cetz `arc` function can be used.

#example(```
	#skeletize({
		cycle(6, arc:(:), {
			single()
			single()
			single()
			single()
			single()
			single()
		})
	})
```)

#example(```
	#skeletize({
		cycle(5, arc:(start: 30deg, end: 330deg), {
			single()
			single()
			single()
			single()
			single()
		})
	})
```)

#example(```
	#skeletize({
		cycle(4, arc:(start: 0deg, delta: 270deg, stroke: (paint: black, dash: "dashed")), {
			single()
			single()
			single()
			single()
		})
	})
```)

== Resonance structures <resonance>

Chemfig allows you to draw resonance formulae. To use this feature, the package provides the #cmd[operator] function and the `resonance` argument of the #cmd[parenthesis] function. With these two things, you can draw formulae with molecules.

For instance, with the #cmd[operator] function, you can draw the resonance formulae of ozone:
#example(```
#skeletize({
	fragment("O", lewis: (
		lewis-double(angle: 135deg),
		lewis-double(angle: -45deg),
	))
	double(angle: 1)
	fragment("O", lewis: (
		lewis-double(angle: 90deg),
	))
	single(angle: -1)
	fragment("O", lewis: (
		lewis-double(angle: 45deg),
		lewis-double(angle: -45deg),
		lewis-double(angle: -135deg),
	))

	operator(math.stretch(sym.arrow.r.l, size: 2em))

		fragment("O", lewis: (
			lewis-double(angle: 135deg),
			lewis-double(angle: -135deg),
			lewis-double(angle: -45deg),
		))
		single(angle: 1)
		fragment("O", lewis: (
			lewis-double(angle: 90deg),
		))
		double(angle: -1)
		fragment("O", lewis: (
			lewis-double(angle: 45deg),
			lewis-double(angle: -135deg),
		))

})
```)

For parenthesis, you can use them like usual parenthesis but with the `resonance` argument set to `true`. If the resonance argument is not set, the parenthesis will be drawn as usual. Furthermore, operators are not allowed in normal parenthesis while they are allowed in resonance parenthesis.

#align(horizon + center, scale(75%,
skeletize(
  config: (angle-increment: 15deg),
  {
    import cetz.draw: *
    fragment("C")
    branch({
      single(angle: 14)
      fragment("E")
    })
    branch({
      double(angle: 6)
      fragment(
        "O",
        lewis: (
          lewis-double(),
          lewis-double(angle: 180deg),
        ),
      )
    })
    single(angle: -2)
    fragment(
      "O",
      lewis: (
        lewis-double(angle: -45deg),
        lewis-double(angle: -135deg),
      ),
      name: "to",
    )
    single(angle: 2, name: "from")
    fragment("H", name: "H")
    hobby(
      stroke: (red),
      (to: "from", rel: (0, 3pt)),
      ("from.50%", 0.5, -50deg, "to.north"),
      "to.north",
      mark: (end: ">", fill: red),
    )
    plus-link(atom-sep: 5em)
    fragment(
      "B",
      lewis: (
        lewis-double(angle: 180deg),
      ),
      name: "base",
    )
    hobby(
      stroke: (red),
      (to: "base", rel: (-5pt, 0)),
      ("base.west", 0.5, -30deg, "H.east"),
      "H.east",
      mark: (end: ">", fill: red),
    )

    operator(math.stretch(sym.harpoons.rtlb, size: 2em))

    parenthesis(
      resonance: true,
      r: "]",
      l: "[",
      {
        fragment("C")
        branch({
          single(angle: 14)
          fragment("R")
        })
        branch({
          double(angle: 6, name: "double")
          fragment(
            "O",
            lewis: (
              lewis-double(),
              lewis-double(angle: 180deg),
            ),
            name: "ketone",
          )
        })
        branch({
          single(angle: -2)
          fragment(
            "O",
            lewis: (
              lewis-double(angle: 0),
              lewis-double(angle: -90deg),
              lewis-double(angle: 90deg),
            ),
          )
        })
        hobby(
          stroke: (red),
          (to: "double", rel: (0, 3pt)),
          (to: "ketone.east", rel: (0.4, 0)),
          ("ketone.east", 0.5, -40deg, "ketone.north"),
          "ketone.north",
          mark: (end: ">", fill: red),
        )

        operator(math.stretch(sym.arrow.r.l, size: 2em))

        fragment("C")
        branch({
          single(angle: 14)
          fragment("R")
        })
        branch({
          single(angle: 6)
          fragment(
            "O",
            lewis: (
              lewis-double(),
              lewis-double(angle: 180deg),
              lewis-double(angle: 90deg),
            ),
          )
        })
        branch({
          single(angle: -2, name: "single")
          fragment(
            "O",
            lewis: (
              lewis-double(angle: 0),
              lewis-double(angle: -90deg),
              lewis-double(angle: 90deg),
            ),
            name: "O2",
          )
        })
        hobby(
          stroke: (red),
          (to: "O2.south", rel: (0, -5pt)),
          ("single.end", 0.7, 70deg, "single.start"),
          "single.50%",
          mark: (end: ">", fill: red),
        )

        operator(math.stretch(sym.arrow.r.l, size: 2em))

        fragment("C")
        branch({
          single(angle: 14)
          fragment("R")
        })
        branch({
          single(angle: 6)
          fragment(
            "O",
            lewis: (
              lewis-double(angle: 0),
              lewis-double(angle: -180deg),
              lewis-double(angle: 90deg),
            ),
          )
        })
        branch({
          double(angle: -2)
          fragment(
            "O",
            lewis: (
              lewis-double(angle: -135deg),
              lewis-double(angle: 45deg),
            ),
          )
        })
      },
    )
    operator($+$)
    fragment("BH")
  },
)))

This example is from the test suite of alchemist. It is too long to be displayed in the manual but you can find it in the git repository in the folder `tests/resonance/test.typ` or directly in the manual source file. It was made by #github-user("Kusaanko").


== Custom links

Using the #cmd[build-link] function, you can create your own links. The function passed as argument to #cmd[build-link] must takes four arguments:
- The length of the link
- The alchemist context
- The cetz context of the drawing environment
- A dictionary of named arguments that can be used to configure the links
You can then draw anything you want using the cetz functions. For instance, here is the code for the `single` link:
```typ
#let single = build-link((length, ctx, _, args) => {
  import cetz.draw: *
  line((0, 0), (length, 0), stroke: args.at("stroke", default: ctx.config.single.stroke))
})
```

== Integration with Cetz <integration-with-cetz>

=== Molecules

If you name your molecules with the `name` argument, you can use them in cetz code. The name of the molecule is the name of the cetz object. Accessing to atoms is done by using the anchors numbered by the index of the atom in the molecule.

#example(
  side-by-side: false,
  ```
  #skeletize({
    import cetz.draw: *
    fragment("ABCD", name: "A")
    single()
    fragment("EFGH", name: "B")
    line(
      "A.0.south",
      (rel: (0, -0.5)),
      (to: "B.0.south", rel: (0, -0.5)),
      "B.0.south",
      stroke: red,
      mark: (end: ">"),
    )
    for i in range(0, 4) {
      content((-2 + i, 2), $#i$, name: "label-" + str(i))
      line(
        (name: "label-" + str(i), anchor: "south"),
        (name: "A", anchor: (str(i), "north")),
        mark: (end: "<>"),
      )
    }
  })
  ```,
)

=== Links

If you name your links with the `name` argument, you can use them in cetz code. The name of the link is the name of the cetz object. It exposes the same anchors as the `line` function of cetz.

#example(
  side-by-side: false,
  ```
  #skeletize({
    import cetz.draw: *
    double(absolute: 30deg, name: "l1")
    single(absolute: -30deg, name: "l2")
    fragment("X", name: "X")
    hobby(
      "l1.50%",
      ("l1.start", 0.5, 90deg, "l1.end"),
      "l1.start",
  		stroke: (paint: red, dash: "dashed"),
      mark: (end: ">"),
    )
  	hobby(
  		(to: "X.north", rel: (0, 1pt)),
  		("l2.end", 0.4, -90deg, "l2.start"),
  		"l2.50%",
  		mark: (end: ">"),
  	)
  })
  ```,
)

Here, all the used coordinates for the arrows are computed using relative coordinates. It means that if you change the position of the links, the arrows will be placed accordingly without any modification.

#grid(
  columns: (1fr, 1fr, 1fr),
  align: horizon + center,
  skeletize({
    import cetz.draw: *
    double(absolute: 45deg, name: "l1")
    single(absolute: -80deg, name: "l2")
    fragment("X", name: "X")
    hobby(
      "l1.50%",
      ("l1.start", 0.5, 90deg, "l1.end"),
      "l1.start",
      stroke: (paint: red, dash: "dashed"),
      mark: (end: ">"),
    )
    hobby(
      (to: "X.north", rel: (0, 1pt)),
      ("l2.end", 0.4, -90deg, "l2.start"),
      "l2.50%",
      mark: (end: ">"),
    )
  }),
  skeletize({
    import cetz.draw: *
    double(absolute: 30deg, name: "l1")
    single(absolute: 30deg, name: "l2")
    fragment("X", name: "X")
    hobby(
      "l1.50%",
      ("l1.start", 0.5, 90deg, "l1.end"),
      "l1.start",
      stroke: (paint: red, dash: "dashed"),
      mark: (end: ">"),
    )
    hobby(
      (to: "X.north", rel: (0, 1pt)),
      ("l2.end", 0.4, -90deg, "l2.start"),
      "l2.50%",
      mark: (end: ">"),
    )
  }),
  skeletize({
    import cetz.draw: *
    double(absolute: 90deg, name: "l1")
    single(absolute: 0deg, name: "l2")
    fragment("X", name: "X")
    hobby(
      "l1.50%",
      ("l1.start", 0.5, 90deg, "l1.end"),
      "l1.start",
      stroke: (paint: red, dash: "dashed"),
      mark: (end: ">"),
    )
    hobby(
      (to: "X.north", rel: (0, 1pt)),
      ("l2.end", 0.4, -90deg, "l2.start"),
      "l2.50%",
      mark: (end: ">"),
    )
  }),
)

=== Cycles centers

The cycles centers can be accessed using the name of the cycle. If you name a cycle, an anchor will be placed at the center of the cycle. If the cycle is incomplete, the missing vertex will be approximated based on the last link and the `atom-sep` value. This will in most cases place the center correctly.

#example(
  side-by-side: false,
  ```
  #skeletize({
    import cetz.draw: *
    fragment("A")
    cycle(
      5,
      name: "cycle",
      {
        single()
        fragment("B")
        single()
        fragment("C")
        single()
        fragment("D")
        single()
        fragment("E")
        single()
      },
    )
    content(
      (to: "cycle", rel: (angle: 30deg, radius: 2)),
      "Center",
      name: "label",
    )
    line(
      "cycle",
      (to: "label.west", rel: (-1pt, -.5em)),
      (to: "label.east", rel: (1pt, -.5em)),
      stroke: red,
    )
    circle(
      "cycle",
      radius: .1em,
      fill: red,
      stroke: red,
    )
  })
  ```,
)

#example(```
#skeletize({
	import cetz.draw: *
	cycle(5, name: "c1", {
		single()
		single()
		single()
		branch({
			single()
			cycle(3, name: "c2", {
				single()
				single()
				single()
			})
		})
		single()
		single()
	})
	hobby(
		"c1",
		("c1", 0.5, -60deg, "c2"),
		"c2",
		stroke: red,
		mark: (end: ">"),
	)
})
```)


=== Multiple molecules

Alchemist allows you to draw multiple molecules in the same cetz environment. This is useful when you want to draw things like reactions.

#example(
  side-by-side: false,
  ```
  #cetz.canvas({
  	import cetz.draw: *
  	draw-skeleton(name: "mol1", {
  		cycle(6, {
  			single()
  			double()
  			single()
  			double()
  			single()
  			double()
  		})
  	})
  	line((to: "mol1.east", rel: (1em, 0)), (rel: (1, 0)), mark: (end: ">"))
  	set-origin((rel: (1em, 0)))
  	draw-skeleton(name: "mol2", mol-anchor: "west", {
  			fragment("X")
  			double(angle: 1)
  			fragment("Y")
  		})
  	line((to: "mol2.east", rel: (1em, 0)), (rel: (1, 0)), mark: (end: ">"))
    set-origin((rel: (1em, 0)))
  	draw-skeleton(name: "mol3", {
  		fragment("S")
  		cram-filled-right()
  		fragment("T")
  	})
  })
  ```,
)

== Integration with Touying

=== Simple animation

Using `touying-reducer` Alchemist can be used with Touying presentations. This provides compatibility with the `pause` animation.

#codesnippet(```typ
  #import "@preview/touying:0.6.3": *
  #import "@preview/alchemist:0.1.10": *

  #import themes.metropolis: *

  #let skeletize = touying-reducer.with(reduce: skeletize, cover: hide)


  #show: metropolis-theme.with(aspect-ratio: "16-9")

  #slide[
    #skeletize({
      fragment("A")
      (pause,)
      single()
      fragment("B")
    })
  ]
```)

=== only and uncover

We can also use `only` and `uncover` but this require a bit of technique:

#codesnippet(```typ
  #import "@preview/touying:0.6.3": *
  #import "@preview/alchemist:0.1.10": *

  #import themes.metropolis: *

  #let skeletize = touying-reducer.with(reduce: skeletize, cover: hide)

  #show: metropolis-theme.with(aspect-ratio: "16-9")

  #slide(repeat: 3, self => {
    skeletize({
      let self = utils.merge-dicts(self, config-methods(cover: utils.method-wrapper(hide)))
      let (uncover, only, alternatives) = utils.methods(self)
      fragment("A")
      (only(1, {
        double()
        fragment("B")
      }),)
      (only(2, {
         single()
         fragment("C")
      }),)
    })
  ]
```)


== Examples <examples>

The following examples are the same ones as in the Chemfig documentation. They are here for two purposes: To show you how to draw the same structures with Alchemist and to show you how to use the package.

=== Ethanol

#example(```
#skeletize({
    fragment("H")
    single()
    fragment("C")
    branch({
        single(angle:2)
        fragment("H")
    })
    branch({
        single(angle:-2)
        fragment("H")
    })
    single()
    fragment("C")
    branch({
        single(angle:-2)
        fragment("H")
    })
    branch({
        single(angle:2)
        fragment("H")
    })
    branch({
        single()
        fragment("O")
        single(angle: 1)
        fragment("H")
    })
})
```)


=== 2-Amino-4-oxohexanoic acid

#example(```
#skeletize(
	config: (angle-increment: 30deg),
	{
	single(angle:1)
	single(angle:-1)
	branch({
		double(angle:-3)
		fragment("O")
	})
	single(angle:1)
	single(angle:-1)
	branch({
		single(angle:-3)
		fragment("NH_2")
	})
	single(angle:1)
	branch({
		double(angle:3)
		fragment("O")
	})
	single(angle:-1)
	fragment("OH")
})
```)




=== #smallcaps[d]-Glucose

#example(
  side-by-side: false,
  ```
  #skeletize(
  	config: (angle-increment: 30deg),
  	{
  	fragment("HO")
  	single(angle:-1)
  	single(angle:1)
  	branch({
  		cram-filled-left(angle: 3)
  		fragment("OH")
  	})
  	single(angle:-1)
  	branch({
  		cram-dashed-left(angle: -3)
  		fragment("OH")
  	})
  	single(angle:1)
  	branch({
  		cram-dashed-left(angle: 3)
  		fragment("OH")
  	})
  	single(angle:-1)
  	branch({
  		cram-dashed-left(angle: -3)
  		fragment("OH")
  	})
  	single(angle:1)
  	branch({
  		double(angle: -1)
  		fragment("O")
  	})
  })
  ```,
)



=== Fisher projection

#example(```
#let fish-left = {
	single()
	branch({
		single(angle:4)
		fragment("H")
	})
	branch({
		single(angle:0)
		fragment("OH")
	})
}
#let fish-right = {
	single()
	branch({
		single(angle:4)
		fragment("OH")
	})
	branch({
		single(angle:0)
		fragment("H")
	})
}
#skeletize(
	config: (base-angle: 90deg),
	{
	fragment("OH")
	single(angle:3)
	fish-right
	fish-right
	fish-left
	fish-right
	single()
	double(angle: 1)
	fragment("O")
})
```)



=== $alpha$-D-glucose

#example(```
#skeletize({
	hook("start")
	branch({
		single(absolute: 190deg)
		fragment("OH")
	})
	single(absolute: -50deg)
	branch({
		single(absolute: 170deg)
		fragment("OH")
	})
	single(absolute: 10deg)
	branch({
		single(
			absolute: -55deg,
			atom-sep: 0.7
		)
		fragment("OH")
	})
	single(absolute: -10deg)
	branch({
		single(angle: -2, atom-sep: 0.7)
		fragment("OH")
	})
	single(absolute: 130deg)
	fragment("O")
	single(absolute: 190deg, links: ("start": single()))
	branch({
		single(
			absolute: 150deg,
			atom-sep: 0.7
		)
		single(angle: 2, atom-sep: 0.7)
		fragment("OH")
	})
})
```)


=== Adrenaline

#example(```
#skeletize({
	cycle(6, {
		branch({
			single()
			fragment("HO")
		})
		single()
		double()
		cycle(6,{
			single(stroke:transparent)
			single(
				stroke:transparent,
				to: 1
			)
			fragment("HN")
			branch({
				single(angle:-1)
				fragment("CH_3")
			})
			single(from:1)
			single()
			branch({
				cram-filled-left(angle: 2)
				fragment("OH")
			})
			single()
		})
		single()
		double()
		single()
		branch({
			single()
			fragment("HO")
		})
		double()
	})
})
```)



=== Guanine

#example(```
#skeletize({
	cycle(6, {
		branch({
			single()
			fragment("H_2N")
		})
		double()
		fragment("N")
		single()
		cycle(6, {
			single()
			fragment("NH", vertical: true)
			single()
			double()
			fragment("N", links: (
				"N-horizon": single()
			))
		})
		single()
		hook("N-horizon")
		single()
		single()
		fragment("NH")
		single(from: 1)
	})
})
```)



=== Sulfuric Acid

#example(```
#skeletize({
	fragment("H")
	single()
	fragment("O", lewis: (
		lewis-line(angle: 90deg),
		lewis-line(angle: -90deg)
	))
	single()
	fragment("S")
	let do(sign) = {
		double()
		fragment("O", lewis: (
			lewis-line(angle: sign * 45deg),
			lewis-line(angle: sign * 135deg)
		))
	}
	branch(angle: 2, do(1))
	branch(angle: -2, do(-1))
	single()
	fragment("O", lewis: (
		lewis-line(angle: 90deg),
		lewis-line(angle: -90deg)
	))
	single()
	fragment("H")
})
```)


=== $B H_3$
#example(```
#skeletize({
	fragment("H")
	single()
	fragment("B", lewis: (
		lewis-rectangle(fragment-margin: 5pt),
	))
	branch(angle:1, {
		single()
		fragment("H")
	})
	branch(angle:-1, {
		single()
		fragment("H")
	})
})
```)

=== Carbonate ion
#example(```
#skeletize(
  config: (
    atom-sep: 2em,
  ),
  {
    parenthesis(
      l: "[",
      r: "]",
      tr: $2-$,
      xoffset: .05,
      {
        fragment(
          "O",
          lewis: (
            lewis-double(angle: 135),
            lewis-double(angle: -45),
            lewis-double(angle: -135),
          ),
        )

        single(relative: 30deg)
        fragment("C")
        branch(
          angle: 2,
          {
            double()
            fragment(
              "O",
              lewis: (
                lewis-double(angle: 45),
                lewis-double(angle: 135),
              ),
            )
          },
        )
        single(absolute: -30deg)
        fragment(
          "O",
          lewis: (
            lewis-double(angle: 45),
            lewis-double(angle: -45),
            lewis-double(angle: -135),
          ),
        )
      },
    )
  },
)
```)


=== Polphenyl sulfide<polySulfide>

#example(```
#skeletize({
  single()
  parenthesis(
    br: $n$,
    right: "end",
    {
      fragment("S")
      single()
      cycle(
        6,
        align: true,
        arc: (:),
        {
          for i in range(3) {
            single()
          }
          branch(single(name: "end"))
          for i in range(3) {
            single()
          }
        },
      )
    },
  )
})
```)

=== Nylon 6
#example(```
#skeletize({
	parenthesis(xoffset: (.4, -.15), {
		single()
		fragment("N")
		branch(angle: 2, {
			single()
			fragment("H")
		})
		single()
		fragment("C")
		branch(angle: 2, {
			double()
			fragment("O")
		})
		single()
		fragment($(C H_2)_5$)
		single()
	})
})
```)

= Molecule engine <molecule-engine>

Everything above builds a molecule by hand, one fragment and link at a time. The
molecule engine is the high-level alternative: you give #cmd[chem] a structure as
a short string — either the readable #link(<dsl>)[DSL] or #link("https://en.wikipedia.org/wiki/Simplified_molecular-input_line-entry_system")[SMILES] — and a Rust/WASM
engine (backed by Schrödinger's CoordgenLibs) computes clean 2D coordinates,
which alchemist draws with IUPAC-style orientation. You never place an atom
yourself, and there is just one function to learn: #cmd[chem] returns
ready-to-place content, so you call it directly in your document.

```typ
#chem("CC(=O)Oc1ccccc1C(=O)O", format: "smiles") // aspirin
```
#align(center, chem("CC(=O)Oc1ccccc1C(=O)O", format: "smiles"))

The engine is a layout layer, not a second renderer: its coordinates are turned
into ordinary alchemist elements — each atom is a fragment placed at an absolute
position, each bond a link between two of them — and #cmd[draw-skeleton] draws
them. A generated molecule therefore uses the same configuration, the same link
styles and the same cetz anchors as a hand-drawn one, and both can live in the
same drawing.

== The DSL <dsl>

The default `format` is the alchemist DSL, a compact line notation:

#table(
  columns: (auto, 1fr),
  [*Syntax*], [*Meaning*],
  [`C`, `O`, `Cl`, …], [atoms (condensed groups like `CH3`, `NH2`, `COOH` too)],
  [`-` `=` `#`], [single / double / triple bond],
  [`>` `<` `:>` `<:`], [stereo wedges (solid / hashed)],
  [`(-OH)` `(=O)`], [a branch (starts with a bond)],
  [`@6` `@6(N)`], [a ring; the body lists vertices, bonds are inferred],
  [`:name`], [label an atom for cross-linking / anchors],
  [`^+` `^2-`], [a charge],
)

In a ring body each vertex is a single atom — a plain `C` is a skeletal corner, a
heteroatom is labelled, and substituents hang off as branches. You don't draw the
ring bonds: a 6-membered carbon/nitrogen ring is aromatised automatically, so
`@6` is benzene, `@6(N)` pyridine and `@6(C(-CH3)CCCCC)` toluene. Write the bonds
explicitly to override — `@6(------)` is cyclohexane.

#example(```
#chem("@6")        // benzene
#chem("@6(N)")     // pyridine
#chem("@6(C(-CH3)C(-CH3)CCCC)") // o-xylene
```)

#example(```
#chem("CH3-C(=O)-OH") // acetic acid
```)

== SMILES input

Pass `format: "smiles"` to read SMILES instead. The organic subset, lowercase
aromatic atoms (Kekulised automatically), ring-closure digits and stereo
(`@`/`@@`, `/`\/`\`) are supported.

#example(```
#chem("c1ccncc1", format: "smiles") // pyridine
```)

#example(```
#chem("N[C@@H](C)C(=O)O", format: "smiles") // L-alanine
```)

== Stereochemistry

Tetrahedral configuration comes from SMILES `@`/`@@` and double-bond geometry from
`/` and `\`; in the DSL, draw wedges directly with `>` `<` (solid) and `:>` `<:`
(hashed).

#example(```
#chem("F/C=C/F", format: "smiles")        // (E) trans
#chem("CH3-C(>OH)(-NH2)-H")               // DSL solid wedge
#chem("CH3-C(:>OH)(-NH2)-H")              // DSL hashed wedge
```)

== Orientation and rendering options

Extra named arguments are forwarded to the layout and the renderer:

/ #arg(orientation: "iupac"): `"iupac"` (default) applies the GR-3 canonical
  orientation; `"as-written"` keeps coordgen's raw pose.
/ #arg(rotation: 0deg): rotate the whole molecule.
/ #arg(color: false): colour atoms with the Jmol CPK palette.
/ #arg(lone-pairs: none): draw lone pairs as `"dots"` or `"lines"`.
/ #arg(aromatic: none): `"circle"` draws the aromatic delocalisation circle.
/ #arg(scale: 1): scale the drawing.

#example(```
#chem("c1ccccc1", format: "smiles", aromatic: "circle")
```)

#example(```
#chem("CCO", format: "smiles", color: true, lone-pairs: "dots")
```)

== Electron-pushing arrows

Curly arrows are addressed by atom id through the `arrows` option: each entry is
`(from, to)` (or `(from, to, side)` to flip the bow). The arrow is drawn clear of
the bonds and curves in to point at the target atom — no Cetz anchors involved.
Atom ids are the 0-based index of each atom in the source string.

#example(
  side-by-side: false,
  ```
  #chem("CH3-C(=O)-CH3", scale: 1.4, arrows: ((1, 2),)) // C=O π → O
  ```,
)

== Reactions

#cmd[reaction] arranges molecules, `[+]` separators and #cmd[rxn-arrow] arrows
into a horizontal scheme. Because #cmd[chem] is content, it drops straight in.

#example(```
#reaction(
  chem("CH3-C(=O)-OH"), [+], chem("CH3-CH2-OH"),
  rxn-arrow(above: [H#super[+]]),
  chem("CH3-C(=O)-O-CH2-CH3"), [+], chem("OH2"),
)
```)

== Molecular formula

#cmd[formula] returns the molecular formula in Hill order as formatted content.

#example(```
#formula("CC(=O)O", format: "smiles")
```)
