#import "@preview/cetz:0.5.2"

#let convert-length(ctx, num) = {
  // This function come from the cetz module
  return if type(num) == length {
    float(num.to-absolute() / ctx.length)
  } else if type(num) == ratio {
    num
  } else {
    float(num)
  }
}

/// Resolve an anchor to its (x, y) position. Coordinates that are already plain
/// numbers — every anchor computed by `anchors.typ`, and every link end — skip
/// cetz's resolver, which is the hot path when a drawing has many links.
///
/// - ctx (cetz-ctx): the cetz context
/// - point (anchor): the anchor to resolve
/// -> the (x, y) position
#let resolve-point(ctx, point) = {
  if type(point) == array and point.len() >= 2 {
    let (x, y, ..) = point
    if type(x) in (int, float) and type(y) in (int, float) {
      return (float(x), float(y))
    }
  }
  let (_, (x, y, ..)) = cetz.coordinate.resolve(ctx, point)
  (x, y)
}

/// get the distance between two anchors
#let distance-between(ctx, from, to) = {
  let (from-x, from-y) = resolve-point(ctx, from)
  let (to-x, to-y) = resolve-point(ctx, to)
  calc.sqrt(calc.pow(to-x - from-x, 2) + calc.pow(to-y - from-y, 2))
}

/// merge two imbricated dictionaries together
/// The second dictionary is the default value if the key is not present in the first dictionary
#let merge-dictionaries(dict1, default) = {
  let result = default
  for (key, value) in dict1 {
    if type(value) == dictionary {
      result.insert(key, merge-dictionaries(value, default.at(key)))
    } else {
      result.insert(key, value)
    }
  }
  result
}


///	get the type of an element by its name
///
/// - body (drawable): the chemfig body of a molecule
/// - name (string): the name of the element to get the type
/// -> string
#let get-element-type(body, name) = {
  for element in body {
    if type(element) != dictionary {
      continue
    }
    if "name" in element and element.name == name {
      return element.type
    }
    if element.type == "branch" or element.type == "cycle" or element.type == "parenthesis" {
      let type = get-element-type(element.body, name)
      if type != none {
        return type
      }
    }
  }
  none
}

/// Calculate the height of a bounding box
/// - bounds (dictionary): the bounding box
/// -> float
#let bounding-box-height(bounds) = {
  calc.abs(bounds.high.at(1) - bounds.low.at(1))
}

/// Calculate the width of a bounding box
/// - bounds (dictionary): the bounding box
/// -> float
#let bounding-box-width(bounds) = {
  calc.abs(bounds.high.at(0) - bounds.low.at(0))
}