extends RefCounted

const MythicItemCatalogLists := preload("res://scripts/items/mythic_item_catalog_lists.gd")
const MythicItemCatalogBuildRouter := preload("res://scripts/items/mythic_item_catalog_build_router.gd")
const MythicItemCatalogIconMetadata := preload("res://scripts/items/mythic_item_catalog_icon_metadata.gd")
const MythicItemCatalogPresentation := preload("res://scripts/items/mythic_item_catalog_presentation.gd")
const MythicItemCatalogFixedOptions := preload("res://scripts/items/mythic_item_catalog_fixed_options.gd")
const MythicItemCatalogRolls := preload("res://scripts/items/mythic_item_catalog_rolls.gd")
const MythicItemCatalogSpawnMetadata := preload("res://scripts/items/mythic_item_catalog_spawn_metadata.gd")

var list_helper: Object = MythicItemCatalogLists.new()
var build_router: Object = MythicItemCatalogBuildRouter.new()
var icon_metadata_helper: Object = MythicItemCatalogIconMetadata.new()
var presentation_helper: Object = MythicItemCatalogPresentation.new()
var fixed_options_helper: Object = MythicItemCatalogFixedOptions.new()
var roll_helper: Object = MythicItemCatalogRolls.new()
var spawn_metadata_helper: Object = MythicItemCatalogSpawnMetadata.new()

const MEGINGJORD := "megingjord"
const RAGNAROK_HAMMER := "ragnarok_hammer"
const HERMES_SHOES := "hermes_shoes"
const POSEIDON_TRIDENT := "poseidon_trident"
const SACRED_LAUREL := "sacred_laurel"
const TRANSCENDENT_CROWN := "transcendent_crown"
const HEAVENLY_CAPE := "heavenly_cape"
const HORN_STRAWBERRY_MASK := "horn_strawberry_mask"
const ODINS_EYE := "odins_eye"
const CELESTIAL_ARMOR := "celestial_armor"
const BAAL_BOOTS := "baal_boots"
const PANDORA_LEGACY := "pandora_legacy"
const ELIXIR_OF_MASTERY := "elixir_of_mastery"
const DOWSING_PENDULUM := "dowsing_pendulum"
const DOWSING_GOGGLES := "dowsing_goggles"
const SPEEDBOOTS := "speedboots"
const SPEEDGEAR := "speedgear"
const GRAVITYBELT := "gravitybelt"
const SENSOR := "sensor"
const SLOT_ADD := "slot_add"
const CHARGEBAG := "chargebag"
const BATTERY := "battery"
const REVIVAL := "revival"
const MASTER := "master"
const GOLD_DIGGER := "gold_digger"
const GOLD_BAR := "gold_bar"
const GOLD_BAR_SELL_PRICE := 2000
const LUCKY_COIN := "lucky_coin"
const ADVERSITY_ARMOR := "adversity_armor"
const SHRAPNEL_ARMOR := "shrapnel_armor"
const SAGE_RING := "sage_ring"
const COOLTIME := "cooltime"
const TIMER_BELT := "timer_belt"
const FUEL_POUCH := "fuel_pouch"
const BLUETOOTH_RING := "bluetooth_ring"
const STAR_DETECTOR := "star_detector"
const FOUL_WHISTLE := "foul_whistle"
const SMARTPHONE := "smartphone"
const NEURAL_HELMET := "neural_helmet"
const VENOM_MIST_GAUNTLET := "venom_mist_gauntlet"
const REINFORCED_BOOMERANG_GAUNTLET := "reinforced_boomerang_gauntlet"
const REINFORCED_BOOMERANG_GAUNTLET_ICON_PATH := MythicItemCatalogIconMetadata.REINFORCED_BOOMERANG_GAUNTLET_ICON_PATH
const COMMANDO_ARM := "commando_arm"
const COMMANDO_ARM_ICON_PATH := MythicItemCatalogIconMetadata.COMMANDO_ARM_ICON_PATH
const RAINBOW_FUR_GLOVE := "rainbow_fur_glove"
const KNEE_PADS := "knee_pads"
const DASHGEAR := "dashgear"
const SOUL_BURST := "soul_burst"
const BULKUP := "bulkup"
const SPIKEBOOTS := "spikeboots"
const BULLETPROOF_HAT := "bulletproof_hat"
const SPIKED_HELMET := "spiked_helmet"
const DASHHOLDER := "dashholder"
const FIELD_SPAWN_ORDER := MythicItemCatalogLists.FIELD_SPAWN_ORDER

func build_item_by_name(item_name: String) -> Dictionary:
	return build_router.build_item_by_name(self, item_name)


func get_display_name(item_name: String) -> String:
	return presentation_helper.get_display_name(self, item_name)


func format_item_display_name(item_data: Dictionary) -> String:
	return presentation_helper.format_item_display_name(item_data)


func get_item_quality_color(item_data: Dictionary, fallback: Color = Color.WHITE) -> Color:
	return presentation_helper.get_item_quality_color(item_data, fallback)


func get_debug_items() -> Array:
	return list_helper.get_debug_items(self, FIELD_SPAWN_ORDER)


func get_field_spawn_items() -> Array:
	return list_helper.get_field_spawn_items(self, FIELD_SPAWN_ORDER)


func get_fixed_options(item_name: String) -> Array:
	return fixed_options_helper.get_fixed_options(item_name)


func get_icon_path(item_name: String) -> String:
	return icon_metadata_helper.get_icon_path(item_name)


func get_icon_sheet_path(item_name: String) -> String:
	return icon_metadata_helper.get_icon_sheet_path(item_name)


func get_field_chance(item_name: String) -> float:
	return spawn_metadata_helper.get_field_chance(item_name)


func get_roll_options(item_name: String) -> Array:
	return roll_helper.get_roll_options(item_name)


func build_default_rolls(item_name: String) -> Dictionary:
	return roll_helper.build_default_rolls(self, item_name)


func build_random_rolls(item_name: String) -> Dictionary:
	return roll_helper.build_random_rolls(self, item_name)


func build_rolled_options(item_name: String, rolls: Dictionary) -> Array:
	return roll_helper.build_rolled_options(self, item_name, rolls)


func sync_roll_fields(item_data: Dictionary, randomize_missing: bool = false, force_quality: bool = false) -> Dictionary:
	return roll_helper.sync_roll_fields(self, item_data, randomize_missing, force_quality)


func get_default_roll_value(item_name: String, option_key: String) -> float:
	return roll_helper.get_default_roll_value(self, item_name, option_key)


func get_slot_key(item_name: String) -> String:
	var item_data: Dictionary = build_item_by_name(item_name)
	return str(item_data.get("slot", ""))
