extends RefCounted

const REINFORCED_BOOMERANG_GAUNTLET_ICON_PATH := "res://assets/sprites/items/reinforced_boomerang_gauntlet.png"
const COMMANDO_ARM_ICON_PATH := "res://assets/sprites/items/commando_arm.png"

const MYTHIC_ICON_FRAME_COUNT := 32
const MYTHIC_ICON_FRAME_MSEC := 33

const ITEM_ICON_PATHS := {
	"megingjord": "res://assets/sprites/items/megingjord.png",
	"ragnarok_hammer": "res://assets/sprites/items/ragnarok_hammer.png",
	"hermes_shoes": "res://assets/sprites/items/hermes_shoes.png",
	"poseidon_trident": "res://assets/sprites/items/poseidon_trident.png",
	"sacred_laurel": "res://assets/sprites/items/sacred_laurel.png",
	"transcendent_crown": "res://assets/sprites/items/transcendent_crown.png",
	"heavenly_cape": "res://assets/sprites/items/heavenly_cape.png",
	"horn_strawberry_mask": "res://assets/sprites/items/horn_strawberry_mask.png",
	"odins_eye": "res://assets/sprites/items/odins_eye.png",
	"celestial_armor": "res://assets/sprites/items/celestial_armor.png",
	"baal_boots": "res://assets/sprites/items/baal_boots.png",
	"pandora_legacy": "res://assets/sprites/items/pandora_legacy.png",
	"elixir_of_mastery": "res://assets/sprites/items/elixir_of_mastery.png",
	"dowsing_pendulum": "res://assets/sprites/items/dowsing_pendulum.png",
	"dowsing_goggles": "res://assets/sprites/items/dowsing_goggles.png",
	"speedboots": "res://assets/sprites/items/speedboots.png",
	"speedgear": "res://assets/sprites/items/speedgear.png",
	"gravitybelt": "res://assets/sprites/items/gravitybelt.png",
	"sensor": "res://assets/sprites/items/sensor.png",
	"slot_add": "res://assets/sprites/items/slot_add_icon.png",
	"chargebag": "res://assets/sprites/items/chargebag.png",
	"battery": "res://assets/sprites/items/battery.png",
	"revival": "res://assets/sprites/items/revival.png",
	"master": "res://assets/sprites/items/master.png",
	"gold_digger": "res://assets/sprites/items/gold_digger.png",
	"gold_bar": "res://assets/sprites/items/gold_bar.png",
	"lucky_coin": "res://assets/sprites/items/lucky_coin.png",
	"adversity_armor": "res://assets/sprites/items/adversity_armor.png",
	"shrapnel_armor": "res://assets/sprites/items/shrapnel_armor.png",
	"sage_ring": "res://assets/sprites/items/sage_ring.png",
	"cooltime": "res://assets/sprites/items/coolingball.png",
	"timer_belt": "res://assets/sprites/items/timer_belt.png",
	"fuel_pouch": "res://assets/sprites/items/fuel_pouch.png",
	"bluetooth_ring": "res://assets/sprites/items/bluetooth_ring.png",
	"star_detector": "res://assets/sprites/items/star_detector.png",
	"foul_whistle": "res://assets/sprites/items/foul_whistle.png",
	"smartphone": "res://assets/sprites/items/smartphone.png",
	"neural_helmet": "res://assets/sprites/items/neural_helmet.png",
	"venom_mist_gauntlet": "res://assets/sprites/items/venom_mist_gauntlet.png",
	"reinforced_boomerang_gauntlet": REINFORCED_BOOMERANG_GAUNTLET_ICON_PATH,
	"commando_arm": COMMANDO_ARM_ICON_PATH,
	"rainbow_fur_glove": "res://assets/sprites/items/rainbow_fur_glove.png",
	"knee_pads": "res://assets/sprites/items/knee_pads.png",
	"dashgear": "res://assets/sprites/items/dashgear.png",
	"soul_burst": "res://assets/sprites/items/soul_burst.png",
	"bulkup": "res://assets/sprites/items/bulkup.png",
	"spikeboots": "res://assets/sprites/items/spikeboots.png",
	"bulletproof_hat": "res://assets/sprites/items/bulletproof_hat.png",
	"spiked_helmet": "res://assets/sprites/items/spiked_helmet.png",
	"dashholder": "res://assets/sprites/items/dashholder.png",
}

const MYTHIC_ICON_SHEET_PATHS := {
	"megingjord": "res://assets/sprites/items/megingjord_icon_sheet.png",
	"ragnarok_hammer": "res://assets/sprites/items/ragnarok_hammer_icon_sheet.png",
	"hermes_shoes": "res://assets/sprites/items/hermes_shoes_icon_sheet.png",
	"poseidon_trident": "res://assets/sprites/items/poseidon_trident_icon_sheet.png",
	"sacred_laurel": "res://assets/sprites/items/sacred_laurel_icon_sheet.png",
	"transcendent_crown": "res://assets/sprites/items/transcendent_crown_icon_sheet.png",
	"heavenly_cape": "res://assets/sprites/items/heavenly_cape_icon_sheet.png",
	"horn_strawberry_mask": "res://assets/sprites/items/horn_strawberry_mask_icon_sheet.png",
	"odins_eye": "res://assets/sprites/items/odins_eye_icon_sheet.png",
	"celestial_armor": "res://assets/sprites/items/celestial_armor_icon_sheet.png",
	"baal_boots": "res://assets/sprites/items/baal_boots_icon_sheet.png",
	"pandora_legacy": "res://assets/sprites/items/pandora_legacy_icon_sheet.png",
}


func get_icon_path(item_name: String) -> String:
	return str(ITEM_ICON_PATHS.get(item_name, ""))


func get_icon_sheet_path(item_name: String) -> String:
	return str(MYTHIC_ICON_SHEET_PATHS.get(item_name, ""))


func with_mythic_icon_sheet(item_data: Dictionary, icon_sheet_path: String) -> Dictionary:
	item_data["icon_sheet_path"] = icon_sheet_path
	item_data["icon_frame_count"] = MYTHIC_ICON_FRAME_COUNT
	item_data["icon_frame_msec"] = MYTHIC_ICON_FRAME_MSEC
	item_data["icon_source_inset"] = 0.0
	item_data["icon_fill_slot"] = true
	item_data["icon_target_pad"] = 5.0
	return item_data
