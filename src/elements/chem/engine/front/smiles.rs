//! OpenSMILES parser -> Graph IR, built on the `winnow` combinator library.
//!
//! Covers the organic subset + bracket atoms (isotope, charge, H-count,
//! chirality), bonds (`- = # :` and directional `/ \`), branches, ring closures
//! (single digit and `%nn`), the disconnection dot, and lowercase aromatic atoms
//! with Kekulization. Each SMILES atom becomes one graph vertex; carbons render
//! as bare skeletal vertices, heteroatoms as element + hydrogen labels.
//!
//! Parsing is two stages: `winnow` tokenizes the string into `Tok`s, then
//! `build` walks the tokens into a graph (branch stack, ring-closure matching).

use crate::graph::{BondKind, Graph, Node};
use winnow::ascii::digit1;
use winnow::combinator::{alt, delimited, opt, preceded, repeat};
use winnow::token::one_of;
use winnow::{ModalResult, Parser};

#[derive(Clone, Copy, PartialEq)]
enum BondTok {
    Default,
    Single,
    Double,
    Triple,
    Aromatic,
    Up,
    Down,
}

impl BondTok {
    fn kind(self) -> BondKind {
        match self {
            BondTok::Double => BondKind::Double,
            BondTok::Triple => BondKind::Triple,
            _ => BondKind::Single,
        }
    }
}

// ── tokenizer (winnow) ───────────────────────────────────────────────────────

/// A parsed atom: element symbol + attributes (organic atoms default them).
struct AtomSpec {
    element: String,
    aromatic: bool,
    charge: i8,
    isotope: Option<u16>,
    hcount: Option<u8>,
    chirality: i8,
}

impl AtomSpec {
    fn plain(element: String, aromatic: bool) -> Self {
        AtomSpec {
            element,
            aromatic,
            charge: 0,
            isotope: None,
            hcount: None,
            chirality: 0,
        }
    }
}

enum Tok {
    Atom(AtomSpec),
    Bond(BondTok),
    Open,
    Close,
    Dot,
    Ring(u32),
}

fn uint(input: &mut &str) -> ModalResult<u32> {
    digit1.parse_to().parse_next(input)
}

fn digit(input: &mut &str) -> ModalResult<u32> {
    one_of(|c: char| c.is_ascii_digit())
        .map(|c: char| c.to_digit(10).unwrap())
        .parse_next(input)
}

/// Organic-subset atom: two-letter (Cl/Br), an upper-case organic element, a
/// lower-case aromatic element, or the `*` wildcard.
fn organic(input: &mut &str) -> ModalResult<AtomSpec> {
    alt((
        alt(("Cl", "Br")).map(|s: &str| AtomSpec::plain(s.to_string(), false)),
        one_of(['B', 'C', 'N', 'O', 'P', 'S', 'F', 'I'])
            .map(|c: char| AtomSpec::plain(c.to_string(), false)),
        one_of(['b', 'c', 'n', 'o', 'p', 's'])
            .map(|c: char| AtomSpec::plain(c.to_ascii_uppercase().to_string(), true)),
        '*'.map(|_| AtomSpec::plain("*".to_string(), false)),
    ))
    .parse_next(input)
}

/// The element part of a bracket atom -> (symbol, aromatic).
fn bracket_symbol(input: &mut &str) -> ModalResult<(String, bool)> {
    alt((
        '*'.map(|_| ("*".to_string(), false)),
        (
            one_of(|c: char| c.is_ascii_uppercase()),
            opt(one_of(|c: char| c.is_ascii_lowercase())),
        )
            .map(|(u, l): (char, Option<char>)| {
                let mut s = u.to_string();
                if let Some(l) = l {
                    s.push(l);
                }
                (s, false)
            }),
        one_of(|c: char| c.is_ascii_lowercase())
            .map(|c: char| (c.to_ascii_uppercase().to_string(), true)),
    ))
    .parse_next(input)
}

/// `@` (anticlockwise, -1) / `@@` (clockwise, +1); a stereo-class tail (e.g.
/// `@TH1`) is skipped, stopping before the H-count.
fn chirality(input: &mut &str) -> ModalResult<i8> {
    let Some(second_at) = opt(preceded('@', opt('@'))).parse_next(input)? else {
        return Ok(0);
    };
    let _: String =
        repeat(0.., one_of(|c: char| c.is_ascii_alphanumeric() && c != 'H')).parse_next(input)?;
    Ok(if second_at.is_some() { 1 } else { -1 })
}

/// Formal charge: `+`/`-`, `+n`/`-n`, or a run of `++`/`--`.
fn charge(input: &mut &str) -> ModalResult<i8> {
    for (sign, mag) in [('+', 1i8), ('-', -1)] {
        if opt(sign).parse_next(input)?.is_some() {
            if let Some(n) = opt(uint).parse_next(input)? {
                return Ok(mag * n as i8);
            }
            let extra: usize = repeat(0.., sign).parse_next(input)?;
            return Ok(mag * (1 + extra as i8));
        }
    }
    Ok(0)
}

fn bracket(input: &mut &str) -> ModalResult<AtomSpec> {
    delimited(
        '[',
        (
            opt(uint),
            bracket_symbol,
            chirality,
            opt(preceded('H', opt(uint))),
            charge,
        ),
        ']',
    )
    .map(
        |(isotope, (element, aromatic), chirality, h, charge)| AtomSpec {
            element,
            aromatic,
            charge,
            isotope: isotope.map(|n| n as u16),
            hcount: Some(h.map(|o| o.unwrap_or(1) as u8).unwrap_or(0)),
            chirality,
        },
    )
    .parse_next(input)
}

fn bond(input: &mut &str) -> ModalResult<BondTok> {
    one_of(['-', '=', '#', ':', '/', '\\'])
        .map(|c: char| match c {
            '=' => BondTok::Double,
            '#' => BondTok::Triple,
            ':' => BondTok::Aromatic,
            '/' => BondTok::Up,
            '\\' => BondTok::Down,
            _ => BondTok::Single,
        })
        .parse_next(input)
}

fn ring(input: &mut &str) -> ModalResult<u32> {
    alt((
        preceded('%', (digit, digit)).map(|(a, b)| a * 10 + b),
        digit,
    ))
    .parse_next(input)
}

fn token(input: &mut &str) -> ModalResult<Tok> {
    alt((
        bracket.map(Tok::Atom),
        organic.map(Tok::Atom),
        bond.map(Tok::Bond),
        '('.map(|_| Tok::Open),
        ')'.map(|_| Tok::Close),
        '.'.map(|_| Tok::Dot),
        ring.map(Tok::Ring),
    ))
    .parse_next(input)
}

// ── graph builder ────────────────────────────────────────────────────────────

struct Builder {
    g: Graph,
    explicit_h: Vec<Option<u8>>,
    // temp bonds: (a, b, tok)
    bonds: Vec<(usize, usize, BondTok)>,
}

impl Builder {
    fn new() -> Self {
        Builder {
            g: Graph::default(),
            explicit_h: Vec::new(),
            bonds: Vec::new(),
        }
    }

    fn add_atom(&mut self, spec: AtomSpec) -> usize {
        let id = self.g.add_node(Node {
            element: spec.element,
            charge: spec.charge,
            isotope: spec.isotope,
            aromatic: spec.aromatic,
            chirality: spec.chirality,
            h_explicit: true,
            ..Default::default()
        });
        self.explicit_h.push(spec.hcount);
        id
    }
}

pub fn parse(source: &str) -> Result<Graph, String> {
    let mut input = source.trim();
    let toks: Vec<Tok> = repeat(0.., token)
        .parse_next(&mut input)
        .map_err(|_| "invalid SMILES".to_string())?;
    if !input.is_empty() {
        return Err(format!("unexpected character in SMILES near {input:?}"));
    }
    build(toks)
}

fn build(toks: Vec<Tok>) -> Result<Graph, String> {
    let mut b = Builder::new();
    let mut prev: Option<usize> = None;
    let mut pending = BondTok::Default;
    let mut stack: Vec<Option<usize>> = Vec::new();
    // ring closure digit -> (atom, bond tok)
    let mut rings: std::collections::HashMap<u32, (usize, BondTok)> =
        std::collections::HashMap::new();

    for tok in toks {
        match tok {
            Tok::Open => stack.push(prev),
            Tok::Close => prev = stack.pop().ok_or("unbalanced ')' in SMILES")?,
            Tok::Dot => {
                prev = None;
                pending = BondTok::Default;
            }
            Tok::Bond(bt) => pending = bt,
            Tok::Ring(n) => {
                close_ring(&mut b, &mut rings, prev, pending, n)?;
                pending = BondTok::Default;
            }
            Tok::Atom(spec) => {
                let id = b.add_atom(spec);
                link(&mut b, &mut prev, pending, id);
                pending = BondTok::Default;
            }
        }
    }

    if !stack.is_empty() {
        return Err("unclosed '(' in SMILES".into());
    }
    if pending != BondTok::Default {
        return Err("SMILES ends with a dangling bond".into());
    }
    if !rings.is_empty() {
        return Err("unclosed ring bond in SMILES".into());
    }

    finalize(b)
}

fn link(b: &mut Builder, prev: &mut Option<usize>, pending: BondTok, id: usize) {
    if let Some(p) = *prev {
        b.g.nodes[id].preceding = true;
        let tok = if pending == BondTok::Default {
            if b.g.nodes[p].aromatic && b.g.nodes[id].aromatic {
                BondTok::Aromatic
            } else {
                BondTok::Single
            }
        } else {
            pending
        };
        b.bonds.push((p, id, tok));
    }
    *prev = Some(id);
}

fn close_ring(
    b: &mut Builder,
    rings: &mut std::collections::HashMap<u32, (usize, BondTok)>,
    prev: Option<usize>,
    pending: BondTok,
    n: u32,
) -> Result<(), String> {
    let cur = prev.ok_or("ring bond before any atom")?;
    if let Some((open, open_tok)) = rings.remove(&n) {
        let tok = if pending != BondTok::Default {
            pending
        } else if open_tok != BondTok::Default {
            open_tok
        } else if b.g.nodes[open].aromatic && b.g.nodes[cur].aromatic {
            BondTok::Aromatic
        } else {
            BondTok::Single
        };
        b.bonds.push((open, cur, tok));
    } else {
        rings.insert(n, (cur, pending));
    }
    Ok(())
}

fn finalize(mut b: Builder) -> Result<Graph, String> {
    let n = b.g.n();
    // Create real graph bonds (aromatic edges as single for now), keeping the
    // / \ direction markers for cis/trans.
    for &(a, c, tok) in &b.bonds {
        let dir = match tok {
            BondTok::Up => 1,
            BondTok::Down => -1,
            _ => 0,
        };
        let idx = b.g.add_bond(a, c, tok.kind());
        b.g.bonds[idx].direction = dir;
    }

    // Seed explicit (bracket) H first so kekulize can tell a pyridine-type N (two
    // ring bonds, takes a ring double) from a pyrrole-type N (extra H, stays
    // single), then assign the Kekulé double bonds across the aromatic system.
    for i in 0..n {
        if let Some(h) = b.explicit_h[i] {
            b.g.nodes[i].hcount = h;
        }
    }
    b.g.kekulize_aromatic();

    // With bond orders final, fill in the derived implicit H and the label text.
    for i in 0..n {
        if b.explicit_h[i].is_none() {
            b.g.nodes[i].hcount = b.g.implicit_h(i);
        }
        let node = &b.g.nodes[i];
        // carbons stay skeletal unless charged/isotopic; heteroatoms are labelled
        if !(node.element == "C" && node.charge == 0 && node.isotope.is_none()) {
            b.g.nodes[i].text = Some(make_label(&node.element.clone(), node.hcount));
        }
    }

    Ok(b.g)
}

fn make_label(elem: &str, h: u8) -> String {
    if h == 0 {
        elem.to_string()
    } else if h == 1 {
        format!("{elem}H")
    } else {
        format!("{elem}H{h}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn g(s: &str) -> Graph {
        parse(s).unwrap()
    }

    #[test]
    fn ethanol() {
        let m = g("CCO");
        assert_eq!(m.nodes.len(), 3);
        assert_eq!(m.bonds.len(), 2);
        assert_eq!(m.nodes[2].element, "O");
        assert_eq!(m.nodes[2].text.as_deref(), Some("OH")); // O + 1 implicit H
    }

    #[test]
    fn benzene_kekulized() {
        let m = g("c1ccccc1");
        assert_eq!(m.nodes.len(), 6);
        assert_eq!(m.bonds.len(), 6);
        assert_eq!(
            m.bonds
                .iter()
                .filter(|b| b.kind == BondKind::Double)
                .count(),
            3,
            "benzene kekulizes to 3 double bonds"
        );
    }

    #[test]
    fn bracket_charge() {
        let m = g("[NH4+]");
        assert_eq!(m.nodes[0].charge, 1);
        assert_eq!(m.nodes[0].text.as_deref(), Some("NH4"));
    }

    #[test]
    fn ring_closure() {
        let m = g("C1CCCCC1"); // cyclohexane
        assert_eq!(m.nodes.len(), 6);
        assert_eq!(m.bonds.len(), 6);
    }

    #[test]
    fn branches_and_double() {
        let m = g("CC(=O)O"); // acetic acid
        assert_eq!(m.nodes.len(), 4);
        assert!(m.bonds.iter().any(|b| b.kind == BondKind::Double));
    }
}
