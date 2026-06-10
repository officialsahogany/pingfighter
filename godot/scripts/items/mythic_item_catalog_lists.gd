extends RefCounted

const FIELD_SPAWN_ORDER := [
	"speedboots",
	"speedgear",
	"gravitybelt",
	"sensor",
	"spikeboots",
	"dowsing_pendulum",
	"dowsing_goggles",
	"slot_add",
	"chargebag",
	"battery",
	"revival",
	"master",
	"gold_digger",
	"gold_bar",
	"lucky_coin",
	"adversity_armor",
	"shrapnel_armor",
	"sage_ring",
	"cooltime",
	"timer_belt",
	"fuel_pouch",
	"bluetooth_ring",
	"star_detector",
	"foul_whistle",
	"smartphone",
	"neural_helmet",
	"venom_mist_gauntlet",
	"reinforced_boomerang_gauntlet",
	"commando_arm",
	"rainbow_fur_glove",
	"knee_pads",
	"dashgear",
	"soul_burst",
	"bulkup",
	"dashholder",
	"bulletproof_hat",
	"spiked_helmet",
	"pandora_legacy",
	"megingjord",
	"ragnarok_hammer",
	"hermes_shoes",
	"poseidon_trident",
	"sacred_laurel",
	"transcendent_crown",
	"heavenly_cape",
	"horn_strawberry_mask",
	"odins_eye",
	"celestial_armor",
	"baal_boots",
]


func get_debug_items(catalog: Object, item_order: Array) -> Array:
	var result: Array = []
	for item_name in item_order:
		var item_data: Dictionary = catalog.build_item_by_name(str(item_name))
		if not item_data.is_empty():
			result.append(item_data)
	return result


func get_field_spawn_items(catalog: Object, item_order: Array) -> Array:
	var result: Array = []
	for item_name in item_order:
		var normalized_name: String = str(item_name)
		var item_data: Dictionary = catalog.build_item_by_name(normalized_name)
		if item_data.is_empty():
			continue
		item_data["rolls"] = catalog.build_random_rolls(normalized_name)
		item_data = catalog.sync_roll_fields(item_data, false)
		result.append(item_data)
	return result
