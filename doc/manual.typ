#import "@preview/mantys:0.1.4": *
#import "@preview/alchemist:0.1.0"

#let infos = toml("../typst.toml")

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

#show: mantys.with(
  ..infos,
  abstract: [
    Alchemist is a package used to draw chemical structures with skeletal formulas using Cetz. It is heavily inspired by the Chemfig package for LaTeX. This package is meant to be easy to use and customizable. It can also be used alongside the cetz package to draw more complex structures.
  ],
  examples-scope: (dictionary(alchemist)),
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



== Available commands

#tidy-module(
  read("../lib.typ"),
  name: infos.package.name,
  show-outline: false,
  include-examples-scope: true,
  extract-headings: 3,
)

= Drawing molecules

== Basic drawing

== Integration with cetz <exemple-cez>