#let convert-length(ctx, num) = {
	// This function come from the cetz module
	if type(num) == length {
		if repr(num).ends-with("em") {
      float(repr(num).slice(0, -2)) * ctx.em-size.width / ctx.length
    } else {
      float(num / ctx.length)
    }
	} else {
		float(num)
	}
}