//! Front-ends: source notation -> Graph IR. Nothing here makes layout choices.

pub mod dsl;
pub mod smiles;

use crate::graph::Graph;

pub fn parse(format: &str, source: &str) -> Result<Graph, String> {
    match format {
        "dsl" => dsl::parse(source),
        "smiles" => smiles::parse(source),
        other => Err(format!("unknown format {other:?}")),
    }
}
