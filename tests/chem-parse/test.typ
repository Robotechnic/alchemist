/// [ppi:100]
#import "../../lib.typ": *

// Front-end coverage: the readable DSL and SMILES parsers should accept a broad
// range of syntax and lower it to the correct structure. Parsing + layout run in
// Rust, so deep nesting / long chains no longer hit Typst's recursion ceiling.
#set page(width: auto, height: auto, margin: 1.5em)
#set text(size: 9pt)
#let sm(s, ..a) = chem(s, format: "smiles", ..a)
#let cell(t, b) = [#raw(t)\ #b]

= DSL front-end

== Chains, branches, multiple bonds
#grid(columns: 4, gutter: 16pt, align: center + horizon,
  cell("CH3-CH2-OH", chem("CH3-CH2-OH")),
  cell("CH3-CH(-OH)-CH3", chem("CH3-CH(-OH)-CH3")),
  cell("CH3-C(=O)-CH3", chem("CH3-C(=O)-CH3")),
  cell("CH3-C(=O)-OH", chem("CH3-C(=O)-OH")),
  cell("CH2=CH2", chem("CH2=CH2")),
  cell("HC#CH", chem("HC#CH")),
  cell("CH2=CH-CH=CH2", chem("CH2=CH-CH=CH2")),
  cell("CH2=CH-C(=O)-OH", chem("CH2=CH-C(=O)-OH")),
  cell("NH2-CH2-C(=O)-OH", chem("NH2-CH2-C(=O)-OH")),
  cell("NH2-CH(-CH3)-C(=O)-OH", chem("NH2-CH(-CH3)-C(=O)-OH")),
  cell("CH3-CH2-CH2-NH2", chem("CH3-CH2-CH2-NH2")),
  cell("CH3-O-CH3", chem("CH3-O-CH3")),
)

== Rings: vertices listed, bonds inferred (`@6`=benzene)
#grid(columns: 4, gutter: 16pt, align: center + horizon,
  cell("@6", chem("@6")),
  cell("@6(N)", chem("@6(N)")),
  cell("@6(C(-CH3)CCCCC)", chem("@6(C(-CH3)CCCCC)")),
  cell("@6(C(-CH3)C(-CH3)CCCC)", chem("@6(C(-CH3)C(-CH3)CCCC)")),
  cell("@6(NCNCCC)", chem("@6(NCNCCC)")),
  cell("@5 (cyclopentane)", chem("@5")),
  cell("CH3-@6", chem("CH3-@6")),
)

== Rings: explicit bonds (override the auto-aromatic default)
#grid(columns: 4, gutter: 16pt, align: center + horizon,
  cell("@6(------)", chem("@6(------)")),
  cell("@6(-=-=-=)", chem("@6(-=-=-=)")),
  cell("@6(-(-CH3)-----)", chem("@6(-(-CH3)-----)")),
  cell("@6(-----@6(-----))", chem("@6(-----@6(-----))")),
  cell("@6(=-=-=@6(=-=-=))", chem("@6(=-=-=@6(=-=-=))")),
  cell("@6(-----@5(----))", chem("@6(-----@5(----))")),
  cell("@6(-----@6(----@6(-----)))", chem("@6(-----@6(----@6(-----)))")),
)

== Labels (`:name`) and charges (`^`)
#grid(columns: 3, gutter: 16pt, align: center + horizon,
  cell("CH3:start-CH2-CH2-OH:end", chem("CH3:start-CH2-CH2-OH:end")),
  cell("CH3-CH:c(-OH:o)-CH3", chem("CH3-CH:c(-OH:o)-CH3")),
  cell("^13C(-H3)-OH", chem("^13C(-H3)-OH")),
)

== Stress: deep nesting, long chain, large rings
#chem("CH3-CH(-CH(-CH(-CH(-CH(-CH(-CH(-CH(-CH(-CH(-CH3)-OH)-OH)-OH)-OH)-OH)-OH)-OH)-OH)-OH)-OH")
#v(6pt)
#chem("CH3-CH2-CH2-CH2-CH2-CH2-CH2-CH2-CH2-CH2-CH2-CH2-CH2-OH")
#v(6pt)
#chem("C(-CH3)(-CH3)(-CH3)-C(-CH3)(-CH3)(-CH3)")
#v(6pt)
#grid(columns: 6, gutter: 12pt, align: center + horizon,
  cell("@3(---)", chem("@3(---)")),
  cell("@4(----)", chem("@4(----)")),
  cell("@5(-----)", chem("@5(-----)")),
  cell("@6(------)", chem("@6(------)")),
  cell("@7(-------)", chem("@7(-------)")),
  cell("@8(--------)", chem("@8(--------)")),
)

= SMILES front-end

== Organic subset, branches, ring closures
#grid(columns: 4, gutter: 16pt, align: center + horizon,
  cell("CCO", sm("CCO")),
  cell("CC(=O)O", sm("CC(=O)O")),
  cell("CC(=O)C", sm("CC(=O)C")),
  cell("CCN", sm("CCN")),
  cell("CCCl", sm("CCCl")),
  cell("CC(C)C", sm("CC(C)C")),
  cell("CCOCC", sm("CCOCC")),
  cell("O=Cc1ccccc1", sm("O=Cc1ccccc1")),
  cell("C1CCCCC1", sm("C1CCCCC1")),
  cell("C1CCNCC1", sm("C1CCNCC1")),
  cell("O=C1CCCCC1", sm("O=C1CCCCC1")),
  cell("OCC1OC(O)C(O)C(O)C1O", sm("OCC1OC(O)C(O)C(O)C1O")),
)

== Aromatic (lowercase) + Kekulization, heteroaromatics
#grid(columns: 4, gutter: 16pt, align: center + horizon,
  cell("c1ccccc1", sm("c1ccccc1")),
  cell("Cc1ccccc1", sm("Cc1ccccc1")),
  cell("Nc1ccccc1", sm("Nc1ccccc1")),
  cell("Oc1ccccc1", sm("Oc1ccccc1")),
  cell("c1ccncc1", sm("c1ccncc1")),
  cell("c1ccco1", sm("c1ccco1")),
  cell("c1ccsc1", sm("c1ccsc1")),
  cell("c1cc[nH]c1", sm("c1cc[nH]c1")),
  cell("c1cnc[nH]1", sm("c1cnc[nH]1")),
  cell("c1ccc2ccccc2c1", sm("c1ccc2ccccc2c1")),
  cell("c1ccc2[nH]ccc2c1", sm("c1ccc2[nH]ccc2c1")),
  cell("c1ccc2ncccc2c1", sm("c1ccc2ncccc2c1")),
)

== Charges, isotopes, brackets
#grid(columns: 4, gutter: 16pt, align: center + horizon,
  cell("[NH4+]", sm("[NH4+]")),
  cell("[OH-]", sm("[OH-]")),
  cell("CC(=O)[O-]", sm("CC(=O)[O-]")),
  cell("C[N+](=O)[O-]", sm("C[N+](=O)[O-]")),
  cell("[Na+].[Cl-]", sm("[Na+].[Cl-]")),
  cell("[13CH4]", sm("[13CH4]")),
  cell("[2H]O[2H]", sm("[2H]O[2H]")),
  cell("[O-]C(=O)[O-]", sm("[O-]C(=O)[O-]")),
)
