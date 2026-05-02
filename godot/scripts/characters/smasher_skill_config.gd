extends RefCounted

const MAX_SKILL_SLOTS := 5
const EQUIPPED_SKILLS := ["drive", "power_smashing"]
const SKILL_COSTS := {
	"drive": 150.0,
	"power_smashing": 300.0,
	"plasma": 40.0,
	"recovery": 120.0,
	"cleanse": 100.0,
	"shield_kiting": 130.0,
	"magnum_grip": 120.0,
	"ghost_shot": 420.0,
	"warp_gate": 100.0,
	"smasher_wheel": 200.0,
}
const SKILL_COLORS := {
	"drive": Color(255.0 / 255.0, 220.0 / 255.0, 50.0 / 255.0),
	"power_smashing": Color(255.0 / 255.0, 100.0 / 255.0, 50.0 / 255.0),
	"plasma": Color(0.0, 200.0 / 255.0, 1.0),
	"recovery": Color(50.0 / 255.0, 1.0, 150.0 / 255.0),
	"cleanse": Color(1.0, 220.0 / 255.0, 115.0 / 255.0),
	"shield_kiting": Color(110.0 / 255.0, 210.0 / 255.0, 1.0),
	"magnum_grip": Color(120.0 / 255.0, 200.0 / 255.0, 1.0),
	"ghost_shot": Color(120.0 / 255.0, 50.0 / 255.0, 180.0 / 255.0),
	"warp_gate": Color(200.0 / 255.0, 110.0 / 255.0, 1.0),
	"smasher_wheel": Color(1.0, 165.0 / 255.0, 60.0 / 255.0),
}
const COOLDOWN_SECONDS := {
	"drive": 15.0,
	"power_smashing": 35.0,
	"plasma": 8.0,
	"recovery": 12.0,
	"cleanse": 20.0,
	"shield_kiting": 12.0,
	"magnum_grip": 15.0,
	"ghost_shot": 85.0,
	"warp_gate": 80.0,
	"smasher_wheel": 25.0,
}


func get_snapshot() -> Dictionary:
	return {
		"max_slots": MAX_SKILL_SLOTS,
		"equipped_skills": EQUIPPED_SKILLS,
		"skill_costs": SKILL_COSTS,
		"skill_colors": SKILL_COLORS,
		"cooldown_seconds": COOLDOWN_SECONDS,
	}


func get_cooldown_seconds(skill_name: String) -> float:
	return float(COOLDOWN_SECONDS.get(skill_name, 0.0))
