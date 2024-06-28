#import "@preview/alchemist:0.1.0":*
#context{
let render = [
#skeletize({
  import cetz.draw : *
  molecule(name: "A", "A")
  single()
  molecule("B")
  branch({
    single(angle:1)
    molecule("W", links:(
      "A": double(stroke: red)
    ))
    single()
    molecule(name: "X", "X")
  })
  branch({
    single(angle:-1)
    molecule("Y")
    single()
    molecule(name: "Z", "Z", links: (
      "X": single(stroke: black + 3pt)
    ))
  })
  single()
  molecule("C", links: (
    "X": cram-filled-left(fill: blue),
    "Z": single()
  ))
})
]
let dimensions = measure(render)
set page(width: dimensions.width + 1pt, height: dimensions.height + 10pt, margin: 0cm, fill: white)
render
}
