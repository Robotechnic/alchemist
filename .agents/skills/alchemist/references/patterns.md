# Alchemist Drawing Patterns

This file lists common molecular drawing patterns you will frequently need.
Adapt coordinates and angles to match your specific molecule.

## 1. Basic alkane chain

```typ
#skeletize({
  fragment("C_6H_14")
})
```

## 2. Multi-atom chain with bonds

```typ
#skeletize({
  fragment("C")
  single()
  fragment("C")
  double()
  fragment("O")
  single()
  fragment("H")
})
```

## 3. Branched molecule (isopropyl example)

```typ
#skeletize({
  fragment("C", name: "main")
  branch({
    single(angle: 1)
    fragment("C_2H_5")
  })
  branch({
    single(angle: -1)
    fragment("C_2H_5")
  })
  single()
  fragment("OH")
})
```

## 4. Benzene ring

```typ
#skeletize({
  cycle(6, {
    single()
    fragment("")
    double()
    fragment("")
    single()
    fragment("")
  })
})
```

## 5. Cyclohexane with substituent

```typ
#skeletize({
  cycle(6, {
    single()
    fragment("")
    single()
    fragment("")
    single()
    fragment("")
  })
  single(angle: 1)
  fragment("OH")
})
```

## 6. Lewis structure (water)

```typ
#skeletize({
  fragment("O", lewis: (
    lewis-single(offset: "top"),
    lewis-single(offset: "bottom"),
    lewis-double(angle: 90deg),
    lewis-double(angle: -90deg),
  ))
  single()
  fragment("H")
  single()
  fragment("H")
})
```

## 7. Cross-linked fragments

```typ
#skeletize({
  fragment("A", name: "A")
  single()
  fragment("B")
  branch({
    single()
    fragment("X", name: "X")
  })
  single()
  fragment("C", links: (
    "A": single(),
    "X": double(stroke: red),
  ))
})
```

## 8. Reaction scheme

```typ
#skeletize({
  fragment("A")
  operator($->$, margin: 1em)
  fragment("B")
  operator($<=>$, margin: 1em)
  fragment("C")
})
```

## 9. Polymer with brackets

```typ
#skeletize(config: (angle-increment: 30deg), {
  parenthesis({
      single(angle: 1)
      single(angle: -1)
      single(angle: 1)
    },
    l: "[", r: "]",
    br: $n$,
  )
})
```

## 10. Using hooks for complex connections

```typ
#skeletize({
  fragment("A", name: "A")
  single()
  hook(name: "h1")
  single()
  fragment("B")
  single()
  fragment("C", name: "C", links: (
    "h1": single(stroke: blue),
  ))
})
```

## 11. Resonance structures

```typ
#skeletize({
  fragment("A")
  parenthesis(resonance: true, {
    single(angle: 1)
    fragment("B")
    single(angle: -1)
    fragment("C")
  })
  operator($<->$, margin: 1.5em)
  fragment("A")
  parenthesis(resonance: true, {
    single(angle: 1)
    fragment("C")
    single(angle: -1)
    fragment("B")
  })
})
```

## 12. Vertical fragment layout

```typ
#skeletize({
  fragment("ABCD", vertical: true)
})
```

## 13. Fragment with custom colors

```typ
#skeletize({
  fragment("ABCD", colors: (red, green, blue))
  single()
  fragment("EFGH", colors: (orange))
})
```

## 14. CeTZ combined drawing

```typ
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
})
```

## 15. Using plus link between fragments

```typ
#skeletize({
  fragment("Na")
  plus()
  fragment("Cl")
})
```
