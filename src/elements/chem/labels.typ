// Label + colour helpers (GR-2.1) shared by skeleton.typ / decorations.typ.
// Pure formatting: condensed-formula subscripts, isotope/charge/oxidation
// superscripts, Jmol CPK element colours.

#import "@preview/cetz:0.5.2"

// ── Jmol CPK element colors ─────────────────────────────────────────────────
#let cpk-colors = (
  H: rgb("#000000"), C: rgb("#000000"), N: rgb("#3050F8"), O: rgb("#FF0D0D"),
  F: rgb("#90E050"), Cl: rgb("#1FF01F"), Br: rgb("#A62929"), I: rgb("#940094"),
  S: rgb("#FFD123"), P: rgb("#FF8000"), B: rgb("#FFB5B5"),
)
#let element-color(elem, color, overrides) = {
  if not color { return black }
  if elem in overrides { return overrides.at(elem) }
  cpk-colors.at(elem, default: black)
}

// ── label typesetting (math mode) ────────────────────────────────────────────
// Labels are built as math content so subscripts, isotope/charge superscripts and
// the ± signs get real math typography (the fragment drawer applies
// `math.upright`, so element symbols stay roman). Strings are spliced with `[#..]`
// so multi-letter symbols like "Cl" stay together and render upright.

// one element group (symbol + optional subscript count) as math content
#let group-frag(sym, sub) = if sub == "" { [#sym] } else { math.attach([#sym], br: [#sub]) }

// the same, wrapped as a standalone equation for one placed sub-atom
#let group-math(sym, sub) = math.equation(block: false, group-frag(sym, sub))

// a condensed formula as math content: each maximal non-digit run is a base and
// the digit run that follows it becomes its subscript ("CH2OH" -> C H_2 O H).
#let formula-frag(formula) = {
  let frags = ()
  let (t, d) = ("", "")
  for ch in formula.clusters() {
    if ch >= "0" and ch <= "9" {
      d += ch
    } else {
      if d != "" {
        frags.push((t, d))
        (t, d) = ("", "")
      }
      t += ch
    }
  }
  frags.push((t, d))
  frags.map(((t, d)) => group-frag(t, d)).join()
}

// Split a simple condensed formula into element groups (sym + subscript count).
// Returns none for labels with parens/brackets (not simply reversible).
#let element-groups(text) = {
  if "(" in text or "[" in text or "]" in text { return none }
  let groups = ()
  let chars = text.clusters()
  let i = 0
  while i < chars.len() {
    let c = chars.at(i)
    if upper(c) == c and lower(c) != c {
      // uppercase letter starts a group
      let sym = c
      i += 1
      while i < chars.len() and lower(chars.at(i)) == chars.at(i) and upper(chars.at(i)) != chars.at(i) {
        sym += chars.at(i)
        i += 1
      }
      let d = ""
      while i < chars.len() and chars.at(i) >= "0" and chars.at(i) <= "9" {
        d += chars.at(i)
        i += 1
      }
      groups.push((sym: sym, sub: d))
    } else {
      i += 1
    }
  }
  groups
}

// GR-2.1.4: oxidation number as a superscript Roman numeral.
#let roman(n) = {
  let neg = n < 0
  let n = calc.abs(n)
  if n == 0 { return "0" }
  let table = ((1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"),
    (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I"))
  let s = ""
  for (v, sym) in table {
    while n >= v { s += sym; n -= v }
  }
  if neg { "−" + s } else { s }
}

// GR-2.1.6: reversed labels read the element groups in reverse (CH3 -> H3C),
// keeping each subscript with its element. `reversed` only applies to simple
// element-only labels. Isotope is a left superscript (GR-2.1.3); oxidation
// number (GR-2.1.4) and formal charge are right superscripts.
#let format-label(atom, reversed: false, oxidation: none) = {
  let groups = element-groups(atom.text)
  let base = if reversed and groups != none {
    groups.rev().map(g => group-frag(g.sym, g.sub)).join()
  } else {
    formula-frag(atom.text)
  }
  let tl = if atom.isotope != none { [#str(atom.isotope)] } else { none }
  let tr = {
    let s = if oxidation != none { roman(oxidation) } else { "" }
    if atom.charge != 0 {
      let n = calc.abs(atom.charge)
      s += (if n > 1 { str(n) } else { "" }) + (if atom.charge > 0 { "+" } else { "−" })
    }
    if s != "" { [#s] } else { none }
  }
  math.equation(
    block: false,
    if tl == none and tr == none { base } else { math.attach(base, tl: tl, tr: tr) },
  )
}
