/// [ppi:100]
#import "../../lib.typ": *

// Rendering features on top of the geometry: labels, Jmol CPK colours, lone
// pairs, charges, aromatic delocalization, and the extended IUPAC GR feature set
// (isotopes, radicals, dative bonds, brackets, partial charges, Markush, ...).
#set page(width: auto, height: auto, margin: 1.5em)
#set text(size: 8pt)
#let sm(s, ..a) = chem(s, format: "smiles", ..a)
#let cell(t, b) = [#t\ #b]

= CPK colours
#grid(columns: 5, gutter: 16pt, align: center + horizon,
  cell("ethanol", sm("CCO", color: true)),
  cell("acetic acid", sm("CC(=O)O", color: true)),
  cell("pyridine", sm("c1ccncc1", color: true)),
  cell("amine", sm("CCN", color: true)),
  cell("chloroethane", sm("CCCl", color: true)),
  cell("bromoform", sm("BrC(Br)Br", color: true)),
  cell("thiol", sm("CCS", color: true)),
  cell("phosphine", sm("CP(C)C", color: true)),
  cell("fluoromethane", sm("CF", color: true)),
  cell("nitrobenzene", sm("O=[N+]([O-])c1ccccc1", color: true)),
)

= Lone pairs
#grid(columns: 5, gutter: 16pt, align: center + horizon,
  cell("water (dots)", chem("OH2", lone-pairs: "dots", color: true)),
  cell("water (lines)", chem("OH2", lone-pairs: "lines", color: true)),
  cell("ethanol", sm("CCO", lone-pairs: "dots")),
  cell("amine", sm("CCN", lone-pairs: "lines", color: true)),
  cell("ether", sm("COC", lone-pairs: "dots", color: true)),
  cell("acetate", sm("CC(=O)[O-]", lone-pairs: "dots", color: true)),
  cell("pyridine", sm("c1ccncc1", lone-pairs: "dots", color: true)),
  cell("trimethylamine", sm("CN(C)C", lone-pairs: "dots", color: true)),
)

= Charges & aromatic delocalization
#grid(columns: 5, gutter: 16pt, align: center + horizon,
  cell("ammonium", sm("[NH4+]")),
  cell("hydroxide", sm("[OH-]", lone-pairs: "dots")),
  cell("benzene circle", sm("c1ccccc1", aromatic: "circle")),
  cell("naphthalene", sm("c1ccc2ccccc2c1", aromatic: "circle")),
  cell("pyridine circle", sm("c1ccncc1", aromatic: "circle")),
  cell("indole circle", sm("c1ccc2[nH]ccc2c1", aromatic: "circle")),
  cell("acetate localized", sm("CC(=O)[O-]", color: true)),
  cell("acetate delocalized", sm("CC(=O)[O-]", color: true, delocalize: ((1, 2), (1, 3)))),
)

= Isotopes & radicals (GR-2.1.3 / GR-5.3)
#grid(columns: 4, gutter: 16pt, align: center + horizon,
  cell("¹³C", chem("^13C(-H3)-OH")),
  cell("deuterated water", sm("[2H]O[2H]")),
  cell("¹⁴C-methane", sm("[14CH4]")),
  cell("nitric oxide radical", sm("[N]=O", color: true)),
)

= Heteroatom groups (GR-8) — nitro, sulfone, sulfoxide, phosphate, dative
#grid(columns: 4, gutter: 16pt, align: center + horizon,
  cell("nitro", sm("C[N+](=O)[O-]", color: true)),
  cell("sulfone", sm("CS(=O)(=O)C", color: true)),
  cell("sulfoxide (DMSO)", chem("CH3-S(~O)-CH3")),
  cell("phosphate", sm("OP(=O)(O)O", color: true)),
  cell("ammonia-borane", chem("H3N~BH3")),
  cell("amine N-oxide", chem("CH3-N(-CH3)(-CH3)~O")),
)

= Polyatomic ions in brackets (GR-5.7)
#grid(columns: 4, gutter: 16pt, align: center + horizon,
  cell("sulfate", sm("[O-]S(=O)(=O)[O-]", brackets: -2, color: true)),
  cell("carbonate", sm("[O-]C(=O)[O-]", brackets: -2, color: true)),
  cell("nitrate", sm("[O-][N+](=O)[O-]", brackets: -1, color: true)),
  cell("ammonium", sm("[NH4+]", brackets: 1)),
)

= Partial charges, pseudobonds, multi-centre, Markush
#grid(columns: 3, gutter: 18pt, align: center + horizon,
  cell("δ+/δ- (GR-5.6)", chem("H-Cl", partial-charge: ("0": "+", "1": "-"), color: true)),
  cell("pseudobonds (GR-12)", chem("CH3-CH2-CH2-CH3", pseudo: ((0, 1), (2, 3)))),
  cell("ferrocene hapto (GR-1.9)", sm("[Fe].c1ccccc1", aromatic: "circle", multi-centre: ((0, (1, 2, 3, 4, 5, 6)),), color: true)),
)
#v(6pt)
#grid(columns: 4, gutter: 18pt, align: center + horizon,
  cell("R-group", chem("R-CH2-OH")),
  cell("R1/R2", chem("R1-CH(-R2)-CH3")),
  cell("X variable", chem("X-CH2-CH3")),
  cell("Markush attach (GR-9.4)", sm("Clc1ccccc1", aromatic: "circle", variable-attach: ((0, (1, 2, 3, 4, 5, 6)),))),
)

= Label layout (GR-2.1.7 vertical, GR-1.5 bent)
#grid(columns: 4, gutter: 18pt, align: center + horizon,
  cell("horizontal", chem("CH3-CH2OH-CH3")),
  cell("vertical", chem("CH3-CH2OH-CH3", vertical: (1,))),
  cell("straight", chem("CH3-CH2-CH2-OH")),
  cell("bent", chem("CH3-CH2-CH2-OH", bent: ((1, 2),))),
)
