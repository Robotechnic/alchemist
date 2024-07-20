#import "@preview/cetz:0.2.2"
#import "src/default.typ": default
#import "src/utils.typ"
#import "src/drawer.typ"
#import "src/drawer.typ" : skeletize
#import "src/links.typ" : *

/// === Molecule function
/// Build a molecule group based on mol
/// Each molecule is represented as an optional count followed by a molecule name
/// starting by a capital letter followed by an optional indice
/// #example(```
/// #skeletize({
///   molecule("H_2O")
/// })
///```)
/// #example(```
/// #skeletize({
///   molecule("2Aa_7 3Bb")
/// })
///```)
/// - name (string): The name of the molecule. It is used as the cetz name of the molecule and to link other molecules to it.
/// - links (dictionary): The links between this molecule and the previous ones. The key is the name of the molecule and the value is the link you want to draw between the two molecules.
///
/// Note that the antom-sep and angle arguments are ignored
/// - mol (string): The string representing the molecule
/// -> drawable
#let molecule(name: none, links: (:), mol) = {
  let aux(str) = {
    let match = str.match(regex("^ *([0-9]*[A-Z][a-z]*)(_[0-9]+)?"))
    if match == none {
      panic(str + " is not a valid atom")
    }
    let eq = "\"" + match.captures.at(0) + "\""
    if match.captures.len() >= 2 {
      eq += match.captures.at(1)
    }
    let eq = math.equation(eval(eq, mode: "math"))
    (eq, match.end)
  }

  let molecules = ()
  while not mol.len() == 0 {
    let (eq, end) = aux(mol)
    mol = mol.slice(end)
    molecules.push(eq)
  }
  (
    (
      type: "molecule",
      name: name,
      molecules: molecules,
      links: links,
      count: molecules.len(),
    ),
  )
}

/// === Branch and cycles
/// Create a branch from the current molecule, the first element
/// of the branch has to be a link.
/// 
/// You can specify an angle argument like for links. This angle will be then
/// used as the `base-angle` for the branch.
///
/// #example(```
/// #skeletize({
///   molecule("A")
///   branch({
///     single(angle:1)
///     molecule("B")
///   })
///   branch({
///     double(angle: -1)
///     molecule("D")
///   })
///   single()
///   double()
///   single()
///   molecule("C")
/// })
///```)
#let branch(..args) = {
	if args.pos().len() != 1 {
		panic("Branch takes one positional argument: the body of the branch")
	}
  ((type: "branch", draw: args.pos().at(0), args: args.named()),)
}

/// Create a regular cycle of molecules
/// #example(```
/// #skeletize({
///   cycle(5, {
///     single()
///     double()
///     single()
///     double()
///     single()
///   })
/// })
///```)
#let cycle(..args) = {
  if args.pos().len() != 2 {
    panic("Cycle takes two positional arguments: number of faces and body")
  }
  (
    (
      type: "cycle",
      faces: args.pos().at(0),
      draw: args.pos().at(1),
      args: args.named(),
    ),
  )
}
