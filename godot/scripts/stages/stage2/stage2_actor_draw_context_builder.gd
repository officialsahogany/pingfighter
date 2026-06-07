extends RefCounted


func build_context(rage_snapshot: Dictionary, expression_snapshot: Dictionary, quake_snapshot: Dictionary = {}) -> Dictionary:
	return {
		"stage2_boss_rage_active": bool(rage_snapshot.get("active", false)),
		"stage2_boss_rage_offset_y": float(rage_snapshot.get("offset_y", 0.0)),
		"stage2_boss_rage_tint": float(rage_snapshot.get("tint", 0.0)),
		"stage2_boss_expression": str(expression_snapshot.get("expression", "neutral")),
		"stage2_boss_expression_timer": float(expression_snapshot.get("timer", 0.0)),
		"stage2_quake_active": bool(quake_snapshot.get("active", false)),
		"stage2_quake_timer": float(quake_snapshot.get("timer", 0.0)),
		"stage2_quake_duration": float(quake_snapshot.get("duration", 0.0)),
	}
