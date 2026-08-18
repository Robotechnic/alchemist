/// [ppi:100]
#import "../../lib.typ": *

// Real-world regression set: drugs, natural products, vitamins, neurotransmitters
// and nucleobases via the SMILES front-end. Exercises the full pipeline on the
// kind of fused / bridged / stereo-rich structures coordgen is built for.
#set page(width: auto, height: auto, margin: 1.5em)
#set text(size: 8pt)
#let sm(s) = chem(s, format: "smiles", scale: 0.8)
#let cell(t, b) = [#t\ #b]

= Common drugs
#grid(columns: 4, column-gutter: 26pt, row-gutter: 22pt, align: center + horizon,
  cell("caffeine", sm("Cn1cnc2c1c(=O)n(C)c(=O)n2C")),
  cell("aspirin", sm("CC(=O)Oc1ccccc1C(=O)O")),
  cell("paracetamol", sm("CC(=O)Nc1ccc(O)cc1")),
  cell("ibuprofen", sm("CC(C)Cc1ccc(C(C)C(=O)O)cc1")),
  cell("naproxen", sm("COc1ccc2cc(C(C)C(=O)O)ccc2c1")),
  cell("salicylic acid", sm("OC(=O)c1ccccc1O")),
  cell("penicillin core", sm("CC1(C)SC2C(NC2=O)N1")),
  cell("nicotine", sm("CN1CCCC1c1cccnc1")),
)

= Natural products & steroids
#grid(columns: 4, column-gutter: 26pt, row-gutter: 22pt, align: center + horizon,
  cell("cholesterol", sm("CC(C)CCCC(C)C1CCC2C1(CCC3C2CC=C4C3(CCC(C4)O)C)C")),
  cell("testosterone", sm("CC12CCC3C(C1CCC2O)CCC4=CC(=O)CCC34C")),
  cell("camphor", sm("CC1(C)C2CCC1(C)C(=O)C2")),
  cell("menthol", sm("CC(C)C1CCC(C)CC1O")),
  cell("glucose", sm("OCC1OC(O)C(O)C(O)C1O")),
  cell("ascorbic acid", sm("OCC(O)C1OC(=O)C(O)=C1O")),
  cell("citric acid", sm("OC(=O)CC(O)(C(=O)O)CC(=O)O")),
  cell("vanillin", sm("O=Cc1ccc(O)c(OC)c1")),
)

= Neurotransmitters & amino acids
#grid(columns: 4, column-gutter: 26pt, row-gutter: 22pt, align: center + horizon,
  cell("dopamine", sm("NCCc1ccc(O)c(O)c1")),
  cell("serotonin", sm("NCCc1c[nH]c2ccc(O)cc12")),
  cell("adrenaline", sm("CNCC(O)c1ccc(O)c(O)c1")),
  cell("histamine", sm("NCCc1c[nH]cn1")),
  cell("phenylalanine", sm("c1ccc(cc1)CC(C(=O)O)N")),
  cell("tryptophan", sm("c1ccc2c(c1)c(c[nH]2)CC(C(=O)O)N")),
  cell("glycine", sm("C(C(=O)O)N")),
  cell("lactic acid", sm("CC(O)C(=O)O")),
)

= Heteroaromatics & nucleobases
#grid(columns: 5, column-gutter: 22pt, row-gutter: 22pt, align: center + horizon,
  cell("furan", sm("c1ccco1")),
  cell("thiophene", sm("c1ccsc1")),
  cell("pyrrole", sm("c1cc[nH]c1")),
  cell("imidazole", sm("c1cnc[nH]1")),
  cell("pyrimidine", sm("c1cncnc1")),
  cell("quinoline", sm("c1ccc2ncccc2c1")),
  cell("indole", sm("c1ccc2[nH]ccc2c1")),
  cell("coumarin", sm("O=c1ccc2ccccc2o1")),
  cell("uracil", sm("O=c1cc[nH]c(=O)[nH]1")),
  cell("thymine", sm("Cc1c[nH]c(=O)[nH]c1=O")),
)

= Aromatics & simple building blocks
#grid(columns: 5, column-gutter: 22pt, row-gutter: 22pt, align: center + horizon,
  cell("benzene", sm("c1ccccc1")),
  cell("toluene", sm("Cc1ccccc1")),
  cell("phenol", sm("Oc1ccccc1")),
  cell("aniline", sm("Nc1ccccc1")),
  cell("styrene", sm("C=Cc1ccccc1")),
  cell("biphenyl", sm("c1ccc(cc1)c1ccccc1")),
  cell("naphthalene", sm("c1ccc2ccccc2c1")),
  cell("anthracene", sm("c1ccc2cc3ccccc3cc2c1")),
  cell("nitrobenzene", sm("O=[N+]([O-])c1ccccc1")),
  cell("benzaldehyde", sm("O=Cc1ccccc1")),
  cell("urea", sm("NC(=O)N")),
  cell("acetonitrile", sm("CC#N")),
  cell("niacin", sm("OC(=O)c1cccnc1")),
  cell("pyridoxine", sm("Cc1ncc(CO)c(CO)c1O")),
  cell("acetamide", sm("CC(=O)N")),
)
