extends RefCounted

# Display-only classification for boss skill-card activation timing. Runtime
# owners remain authoritative for when and how a skill actually activates.
const TRIGGER_INSTANT := "instant"
const TRIGGER_ON_BOSS_HIT := "on_boss_hit"
const VALID_TRIGGER_CLASSES := [
	TRIGGER_INSTANT,
	TRIGGER_ON_BOSS_HIT,
]


static func is_valid(value: String) -> bool:
	return value in VALID_TRIGGER_CLASSES


static func get_label(value: String) -> String:
	return "타격" if value == TRIGGER_ON_BOSS_HIT else "즉시"
