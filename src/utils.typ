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

/// Convert any angle to an angle between -360deg and 360deg
#let angle-correction(angle) = {
	calc.rem(angle.deg(), 360) * 1deg
}

/// Check if the angle is in the range [from, to[
#let angle-in-range(angle, from, to) = {
	if to < from {
		panic("angle-in-range: The 'to' angle must be greater than the 'from' angle")
	}
	angle = if angle < 0deg {
		angle + 360deg
	} else {
		angle
	}
	angle >= from and angle < to
}