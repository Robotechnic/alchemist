/// [ppi:100]
#import "../../lib.typ": *

// 2D geometry from the coordgen engine: regular polygons, fused / bridged / spiro
// ring systems, macrocycles, cumulene sp centres, stereochemistry, and IUPAC
// GR-3 canonical orientation.
#set page(width: auto, height: auto, margin: 1.5em)
#set text(size: 8pt)
#let sm(s, ..a) = chem(s, format: "smiles", scale: 0.85, ..a)
#let cell(t, b) = [#t\ #b]

= Regular polygons (GR-3.3.1, flat bottom edge)
#grid(columns: 6, gutter: 12pt, align: center + horizon,
  cell("cyclopropane", chem("@3(---)")),
  cell("cyclobutane", chem("@4(----)")),
  cell("cyclopentane", chem("@5(-----)")),
  cell("cyclohexane", chem("@6(------)")),
  cell("cycloheptane", chem("@7(-------)")),
  cell("cyclooctane", chem("@8(--------)")),
)

= Fused ring systems
#grid(columns: 4, gutter: 14pt, align: center + horizon,
  cell("naphthalene", sm("c1ccc2ccccc2c1")),
  cell("anthracene", sm("c1ccc2cc3ccccc3cc2c1")),
  cell("phenanthrene", sm("c1ccc2ccc3ccccc3c2c1")),
  cell("azulene", sm("c1ccc2cccc2cc1")),
  cell("decalin", sm("C1CCC2CCCCC2C1")),
  cell("indane", sm("C1Cc2ccccc2C1")),
  cell("indene", sm("C1C=Cc2ccccc21")),
  cell("tetralin", sm("C1CCc2ccccc2C1")),
  cell("fluorene", sm("C1c2ccccc2-c2ccccc21")),
  cell("acenaphthylene", sm("C1=Cc2cccc3cccc1c23")),
  cell("indole", sm("c1ccc2[nH]ccc2c1")),
  cell("quinoline", sm("c1ccc2ncccc2c1")),
)

= Bridged / cage templates
#grid(columns: 4, gutter: 14pt, align: center + horizon,
  cell("norbornane", sm("C1CC2CCC1C2")),
  cell("bicyclo[2.2.2]", sm("C1CC2CCC1CC2")),
  cell("adamantane", sm("C1C2CC3CC1CC(C2)C3")),
  cell("camphor", sm("CC1(C)C2CCC1(C)C(=O)C2")),
  cell("cubane", sm("C12C3C4C1C5C4C3C25")),
  cell("housane", sm("C1CC2CC1C2")),
)

= Spiro junctions
#grid(columns: 3, gutter: 16pt, align: center + horizon,
  cell("spiro[2.2]", sm("C1CC12CC2")),
  cell("spiro[4.4]", sm("C1CCC12CCC2")),
  cell("spiro[5.5]", sm("C1CCCCC12CCCCC2")),
)

= Macrocycles
#grid(columns: 4, gutter: 14pt, align: center + horizon,
  cell("cyclooctane", sm("C1CCCCCCC1")),
  cell("cyclodecane", sm("C1CCCCCCCCC1")),
  cell("cyclododecane", sm("C1CCCCCCCCCCC1")),
  cell("18-crown-6", sm("C1COCCOCCOCCOCCOCCO1")),
)

= Cumulenes (sp centres) & strained
#grid(columns: 4, gutter: 16pt, align: center + horizon,
  cell("allene", sm("C=C=C")),
  cell("ketene", sm("C=C=O")),
  cell("CO2", sm("O=C=O")),
  cell("butatriene", sm("C=C=C=C")),
)

= Stereochemistry (wedges, cis/trans)
#grid(columns: 4, gutter: 16pt, align: center + horizon,
  cell("(S)-alanine", sm("N[C@@H](C)C(=O)O")),
  cell("(R)-alanine", sm("N[C@H](C)C(=O)O")),
  cell("CHFClBr", sm("[C@H](F)(Cl)Br")),
  cell("lactic acid", sm("C[C@@H](O)C(=O)O")),
  cell("(E) F/C=C/F", sm("F/C=C/F")),
  cell("(Z) F/C=C\\F", sm("F/C=C\\F")),
  cell("fumaric (E)", sm("OC(=O)/C=C/C(=O)O")),
  cell("maleic (Z)", sm("OC(=O)/C=C\\C(=O)O")),
  cell("DSL solid wedge", chem("CH3-C(>OH)(-NH2)-H")),
  cell("DSL hashed wedge", chem("CH3-C(:>OH)(-NH2)-H")),
)

= IUPAC GR-3 canonical orientation
#grid(columns: 4, gutter: 14pt, align: center + horizon,
  cell("GR-3.1.1 axis horizontal", sm("CCCCc1ccccc1")),
  cell("GR-3.1.2 group right", chem("HO-C(=O)-CH2-CH2-CH3")),
  cell("GR-3.1.2 acid > OH", sm("CC(O)C(=O)O")),
  cell("GR-3.1.2 ester parent R", sm("CC(=O)OCCCC")),
  cell("GR-3.2.2 carbonyl up", sm("CCCCCC(=O)C")),
  cell("GR-3.1.3 ring bottom-left", sm("OC(=O)Cc1ccccc1")),
  cell("GR-1.10 ring double inner", sm("C1=CCCCC1")),
  cell("GR-1.10 carbonyl centred", sm("CC(=O)C")),
)
