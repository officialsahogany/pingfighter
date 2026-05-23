extends RefCounted

const ITEM_BUILD_METHODS := {
	"speedboots": "_build_speedboots",
	"speedgear": "_build_speedgear",
	"gravitybelt": "_build_gravitybelt",
	"sensor": "_build_sensor",
	"spikeboots": "_build_spikeboots",
	"dowsing_pendulum": "_build_dowsing_pendulum",
	"dowsing_goggles": "_build_dowsing_goggles",
	"slot_add": "_build_slot_add",
	"chargebag": "_build_chargebag",
	"battery": "_build_battery",
	"revival": "_build_revival",
	"master": "_build_master",
	"gold_digger": "_build_gold_digger",
	"gold_bar": "_build_gold_bar",
	"lucky_coin": "_build_lucky_coin",
	"adversity_armor": "_build_adversity_armor",
	"shrapnel_armor": "_build_shrapnel_armor",
	"sage_ring": "_build_sage_ring",
	"cooltime": "_build_cooltime",
	"timer_belt": "_build_timer_belt",
	"fuel_pouch": "_build_fuel_pouch",
	"bluetooth_ring": "_build_bluetooth_ring",
	"star_detector": "_build_star_detector",
	"foul_whistle": "_build_foul_whistle",
	"smartphone": "_build_smartphone",
	"neural_helmet": "_build_neural_helmet",
	"venom_mist_gauntlet": "_build_venom_mist_gauntlet",
	"reinforced_boomerang_gauntlet": "_build_reinforced_boomerang_gauntlet",
	"commando_arm": "_build_commando_arm",
	"rainbow_fur_glove": "_build_rainbow_fur_glove",
	"knee_pads": "_build_knee_pads",
	"dashgear": "_build_dashgear",
	"soul_burst": "_build_soul_burst",
	"bulkup": "_build_bulkup",
	"dashholder": "_build_dashholder",
	"bulletproof_hat": "_build_bulletproof_hat",
	"spiked_helmet": "_build_spiked_helmet",
	"pandora_legacy": "_build_pandora_legacy",
	"megingjord": "_build_megingjord",
	"ragnarok_hammer": "_build_ragnarok_hammer",
	"hermes_shoes": "_build_hermes_shoes",
	"poseidon_trident": "_build_poseidon_trident",
	"sacred_laurel": "_build_sacred_laurel",
	"transcendent_crown": "_build_transcendent_crown",
	"heavenly_cape": "_build_heavenly_cape",
	"horn_strawberry_mask": "_build_horn_strawberry_mask",
	"celestial_armor": "_build_celestial_armor",
	"baal_boots": "_build_baal_boots",
	"elixir_of_mastery": "_build_elixir_of_mastery",
}


func build_item_by_name(catalog: Object, item_name: String) -> Dictionary:
	var method_name: String = str(ITEM_BUILD_METHODS.get(item_name, ""))
	if catalog == null or method_name == "" or not catalog.has_method(method_name):
		return {}
	var result: Variant = catalog.call(method_name)
	if result is Dictionary:
		return result
	return {}
