extends RefCounted


static func build_fire_failed_result(
	weapon_id: String,
	special_gauge: float,
	reason: String,
	extra_fields: Dictionary = {}
) -> Dictionary:
	var result := {
		"handled": true,
		"weapon_id": weapon_id,
		"fire_failed": true,
		"failure_reason": reason,
		"special_gauge": special_gauge,
	}
	result.merge(extra_fields, true)
	return result
