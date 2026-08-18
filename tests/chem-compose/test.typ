/// [ppi:100]
#import "../../lib.typ": *

// Composition built on chem(): reaction schemes (chem() returns content, so it
// drops straight into reaction()) and electron-pushing arrows addressed by atom
// id via the `arrows` option — no Cetz anchors in user code.
#set page(width: auto, height: auto, margin: 1.5em)
#set text(size: 9pt)

= Reaction schemes
== Fischer esterification
#reaction(
  chem("CH3-C(=O)-OH"), [+], chem("CH3-CH2-OH"),
  rxn-arrow(above: [H#super[+]], below: [heat]),
  chem("CH3-C(=O)-O-CH2-CH3"), [+], chem("OH2"),
)

== Acid/base equilibrium
#reaction(
  chem("CH3-C(=O)-OH"),
  rxn-arrow(dir: "equilibrium", above: [base]),
  chem("CH3-C(=O)-O"),
)

== Keto–enol tautomerism
#reaction(
  chem("CH3-C(=O)-CH3"),
  rxn-arrow(dir: "equilibrium"),
  chem("CH2=C(-OH)-CH3"),
)

= Electron-pushing arrows (`arrows:` — atom ids, no Cetz anchors)
#grid(columns: 2, column-gutter: 36pt, align: center + horizon,
  [carbonyl π → O\ #chem("CH3-C(=O)-CH3", scale: 1.5, arrows: ((1, 2),))],
  [amide resonance\ #chem("CH3-C(=O)-NH2", scale: 1.5, arrows: ((3, 1, -1), (1, 2)))],
)
