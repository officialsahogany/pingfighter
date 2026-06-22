extends RefCounted

const MAX_DECODER_LEVEL := 5
const DECODE_PCT_PER_LEVEL := 20


static func clamp_level(level: int) -> int:
	return clampi(level, 0, MAX_DECODER_LEVEL)


static func decode_pct_for_level(level: int) -> int:
	return clampi(clamp_level(level) * DECODE_PCT_PER_LEVEL, 0, 100)
