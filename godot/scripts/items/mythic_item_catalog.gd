extends RefCounted

const MythicItemCatalogLists := preload("res://scripts/items/mythic_item_catalog_lists.gd")
const MythicItemCatalogBuildRouter := preload("res://scripts/items/mythic_item_catalog_build_router.gd")
const MythicItemCatalogPresentation := preload("res://scripts/items/mythic_item_catalog_presentation.gd")
const MythicItemCatalogFixedOptions := preload("res://scripts/items/mythic_item_catalog_fixed_options.gd")
const MythicItemCatalogRolls := preload("res://scripts/items/mythic_item_catalog_rolls.gd")

var list_helper: Object = MythicItemCatalogLists.new()
var build_router: Object = MythicItemCatalogBuildRouter.new()
var presentation_helper: Object = MythicItemCatalogPresentation.new()
var fixed_options_helper: Object = MythicItemCatalogFixedOptions.new()
var roll_helper: Object = MythicItemCatalogRolls.new()

const MYTHIC_ICON_FRAME_COUNT := 32
const MYTHIC_ICON_FRAME_MSEC := 33
const MEGINGJORD := "megingjord"
const MEGINGJORD_ICON_PATH := "res://assets/sprites/items/megingjord.png"
const MEGINGJORD_ICON_SHEET_PATH := "res://assets/sprites/items/megingjord_icon_sheet.png"
const MEGINGJORD_FIELD_CHANCE := 0.00008
const RAGNAROK_HAMMER := "ragnarok_hammer"
const RAGNAROK_HAMMER_ICON_PATH := "res://assets/sprites/items/ragnarok_hammer.png"
const RAGNAROK_HAMMER_ICON_SHEET_PATH := "res://assets/sprites/items/ragnarok_hammer_icon_sheet.png"
const RAGNAROK_HAMMER_FIELD_CHANCE := 0.00008
const HERMES_SHOES := "hermes_shoes"
const HERMES_SHOES_ICON_PATH := "res://assets/sprites/items/hermes_shoes.png"
const HERMES_SHOES_ICON_SHEET_PATH := "res://assets/sprites/items/hermes_shoes_icon_sheet.png"
const HERMES_SHOES_FIELD_CHANCE := 0.00008
const POSEIDON_TRIDENT := "poseidon_trident"
const POSEIDON_TRIDENT_ICON_PATH := "res://assets/sprites/items/poseidon_trident.png"
const POSEIDON_TRIDENT_ICON_SHEET_PATH := "res://assets/sprites/items/poseidon_trident_icon_sheet.png"
const POSEIDON_TRIDENT_FIELD_CHANCE := 0.00008
const SACRED_LAUREL := "sacred_laurel"
const SACRED_LAUREL_ICON_PATH := "res://assets/sprites/items/sacred_laurel.png"
const SACRED_LAUREL_ICON_SHEET_PATH := "res://assets/sprites/items/sacred_laurel_icon_sheet.png"
const SACRED_LAUREL_FIELD_CHANCE := 0.00008
const TRANSCENDENT_CROWN := "transcendent_crown"
const TRANSCENDENT_CROWN_ICON_PATH := "res://assets/sprites/items/transcendent_crown.png"
const TRANSCENDENT_CROWN_ICON_SHEET_PATH := "res://assets/sprites/items/transcendent_crown_icon_sheet.png"
const TRANSCENDENT_CROWN_FIELD_CHANCE := 0.00008
const HEAVENLY_CAPE := "heavenly_cape"
const HEAVENLY_CAPE_ICON_PATH := "res://assets/sprites/items/heavenly_cape.png"
const HEAVENLY_CAPE_ICON_SHEET_PATH := "res://assets/sprites/items/heavenly_cape_icon_sheet.png"
const HEAVENLY_CAPE_FIELD_CHANCE := 0.00008
const HORN_STRAWBERRY_MASK := "horn_strawberry_mask"
const HORN_STRAWBERRY_MASK_ICON_PATH := "res://assets/sprites/items/horn_strawberry_mask.png"
const HORN_STRAWBERRY_MASK_ICON_SHEET_PATH := "res://assets/sprites/items/horn_strawberry_mask_icon_sheet.png"
const HORN_STRAWBERRY_MASK_FIELD_CHANCE := 0.00008
const CELESTIAL_ARMOR := "celestial_armor"
const CELESTIAL_ARMOR_ICON_PATH := "res://assets/sprites/items/celestial_armor.png"
const CELESTIAL_ARMOR_ICON_SHEET_PATH := "res://assets/sprites/items/celestial_armor_icon_sheet.png"
const CELESTIAL_ARMOR_FIELD_CHANCE := 0.00008
const BAAL_BOOTS := "baal_boots"
const BAAL_BOOTS_ICON_PATH := "res://assets/sprites/items/baal_boots.png"
const BAAL_BOOTS_ICON_SHEET_PATH := "res://assets/sprites/items/baal_boots_icon_sheet.png"
const BAAL_BOOTS_FIELD_CHANCE := 0.00008
const PANDORA_LEGACY := "pandora_legacy"
const PANDORA_LEGACY_ICON_PATH := "res://assets/sprites/items/pandora_legacy.png"
const PANDORA_LEGACY_ICON_SHEET_PATH := "res://assets/sprites/items/pandora_legacy_icon_sheet.png"
const PANDORA_LEGACY_FIELD_CHANCE := 0.00008
const ELIXIR_OF_MASTERY := "elixir_of_mastery"
const ELIXIR_OF_MASTERY_ICON_PATH := "res://assets/sprites/items/elixir_of_mastery.png"
const DOWSING_PENDULUM := "dowsing_pendulum"
const DOWSING_PENDULUM_ICON_PATH := "res://assets/sprites/items/dowsing_pendulum.png"
const DOWSING_PENDULUM_FIELD_CHANCE := 0.005
const DOWSING_GOGGLES := "dowsing_goggles"
const DOWSING_GOGGLES_ICON_PATH := "res://assets/sprites/items/dowsing_goggles.png"
const DOWSING_GOGGLES_FIELD_CHANCE := 0.005
const SPEEDBOOTS := "speedboots"
const SPEEDBOOTS_ICON_PATH := "res://assets/sprites/items/speedboots.png"
const SPEEDBOOTS_FIELD_CHANCE := 0.005
const SPEEDGEAR := "speedgear"
const SPEEDGEAR_ICON_PATH := "res://assets/sprites/items/speedgear.png"
const SPEEDGEAR_FIELD_CHANCE := 0.005
const GRAVITYBELT := "gravitybelt"
const GRAVITYBELT_ICON_PATH := "res://assets/sprites/items/gravitybelt.png"
const GRAVITYBELT_FIELD_CHANCE := 0.002
const SENSOR := "sensor"
const SENSOR_ICON_PATH := "res://assets/sprites/items/sensor.png"
const SENSOR_FIELD_CHANCE := 0.005
const SLOT_ADD := "slot_add"
const SLOT_ADD_ICON_PATH := "res://assets/sprites/items/slot_add_icon.png"
const SLOT_ADD_FIELD_CHANCE := 0.006
const CHARGEBAG := "chargebag"
const CHARGEBAG_ICON_PATH := "res://assets/sprites/items/chargebag.png"
const CHARGEBAG_FIELD_CHANCE := 0.003
const BATTERY := "battery"
const BATTERY_ICON_PATH := "res://assets/sprites/items/battery.png"
const BATTERY_FIELD_CHANCE := 0.005
const REVIVAL := "revival"
const REVIVAL_ICON_PATH := "res://assets/sprites/items/revival.png"
const REVIVAL_FIELD_CHANCE := 0.005
const MASTER := "master"
const MASTER_ICON_PATH := "res://assets/sprites/items/master.png"
const MASTER_FIELD_CHANCE := 0.005
const GOLD_DIGGER := "gold_digger"
const GOLD_DIGGER_ICON_PATH := "res://assets/sprites/items/gold_digger.png"
const GOLD_DIGGER_FIELD_CHANCE := 0.005
const GOLD_BAR := "gold_bar"
const GOLD_BAR_ICON_PATH := "res://assets/sprites/items/gold_bar.png"
const GOLD_BAR_FIELD_CHANCE := 0.001
const GOLD_BAR_SELL_PRICE := 2000
const LUCKY_COIN := "lucky_coin"
const LUCKY_COIN_ICON_PATH := "res://assets/sprites/items/lucky_coin.png"
const LUCKY_COIN_FIELD_CHANCE := 0.004
const ADVERSITY_ARMOR := "adversity_armor"
const ADVERSITY_ARMOR_ICON_PATH := "res://assets/sprites/items/adversity_armor.png"
const ADVERSITY_ARMOR_FIELD_CHANCE := 0.004
const SHRAPNEL_ARMOR := "shrapnel_armor"
const SHRAPNEL_ARMOR_ICON_PATH := "res://assets/sprites/items/shrapnel_armor.png"
const SHRAPNEL_ARMOR_FIELD_CHANCE := 0.004
const SAGE_RING := "sage_ring"
const SAGE_RING_ICON_PATH := "res://assets/sprites/items/sage_ring.png"
const SAGE_RING_FIELD_CHANCE := 0.001
const COOLTIME := "cooltime"
const COOLTIME_ICON_PATH := "res://assets/sprites/items/coolingball.png"
const COOLTIME_FIELD_CHANCE := 0.005
const TIMER_BELT := "timer_belt"
const TIMER_BELT_ICON_PATH := "res://assets/sprites/items/timer_belt.png"
const TIMER_BELT_FIELD_CHANCE := 0.005
const FUEL_POUCH := "fuel_pouch"
const FUEL_POUCH_ICON_PATH := "res://assets/sprites/items/fuel_pouch.png"
const FUEL_POUCH_FIELD_CHANCE := 0.005
const BLUETOOTH_RING := "bluetooth_ring"
const BLUETOOTH_RING_ICON_PATH := "res://assets/sprites/items/bluetooth_ring.png"
const BLUETOOTH_RING_FIELD_CHANCE := 0.006
const STAR_DETECTOR := "star_detector"
const STAR_DETECTOR_ICON_PATH := "res://assets/sprites/items/star_detector.png"
const STAR_DETECTOR_FIELD_CHANCE := 0.004
const FOUL_WHISTLE := "foul_whistle"
const FOUL_WHISTLE_ICON_PATH := "res://assets/sprites/items/foul_whistle.png"
const FOUL_WHISTLE_FIELD_CHANCE := 0.005
const SMARTPHONE := "smartphone"
const SMARTPHONE_ICON_PATH := "res://assets/sprites/items/smartphone.png"
const SMARTPHONE_FIELD_CHANCE := 0.004
const NEURAL_HELMET := "neural_helmet"
const NEURAL_HELMET_ICON_PATH := "res://assets/sprites/items/neural_helmet.png"
const NEURAL_HELMET_FIELD_CHANCE := 0.005
const VENOM_MIST_GAUNTLET := "venom_mist_gauntlet"
const VENOM_MIST_GAUNTLET_ICON_PATH := "res://assets/sprites/items/venom_mist_gauntlet.png"
const VENOM_MIST_GAUNTLET_FIELD_CHANCE := 0.004
const REINFORCED_BOOMERANG_GAUNTLET := "reinforced_boomerang_gauntlet"
const REINFORCED_BOOMERANG_GAUNTLET_ICON_PATH := "res://assets/sprites/items/reinforced_boomerang_gauntlet.png"
const REINFORCED_BOOMERANG_GAUNTLET_FIELD_CHANCE := 0.005
const COMMANDO_ARM := "commando_arm"
const COMMANDO_ARM_ICON_PATH := "res://assets/sprites/items/commando_arm.png"
const COMMANDO_ARM_FIELD_CHANCE := 0.006
const RAINBOW_FUR_GLOVE := "rainbow_fur_glove"
const RAINBOW_FUR_GLOVE_ICON_PATH := "res://assets/sprites/items/rainbow_fur_glove.png"
const RAINBOW_FUR_GLOVE_FIELD_CHANCE := 0.004
const KNEE_PADS := "knee_pads"
const KNEE_PADS_ICON_PATH := "res://assets/sprites/items/knee_pads.png"
const KNEE_PADS_FIELD_CHANCE := 0.005
const DASHGEAR := "dashgear"
const DASHGEAR_ICON_PATH := "res://assets/sprites/items/dashgear.png"
const DASHGEAR_FIELD_CHANCE := 0.005
const SOUL_BURST := "soul_burst"
const SOUL_BURST_ICON_PATH := "res://assets/sprites/items/soul_burst.png"
const SOUL_BURST_FIELD_CHANCE := 0.005
const BULKUP := "bulkup"
const BULKUP_ICON_PATH := "res://assets/sprites/items/bulkup.png"
const BULKUP_FIELD_CHANCE := 0.005
const SPIKEBOOTS := "spikeboots"
const SPIKEBOOTS_ICON_PATH := "res://assets/sprites/items/spikeboots.png"
const SPIKEBOOTS_FIELD_CHANCE := 0.005
const BULLETPROOF_HAT := "bulletproof_hat"
const BULLETPROOF_HAT_ICON_PATH := "res://assets/sprites/items/bulletproof_hat.png"
const BULLETPROOF_HAT_FIELD_CHANCE := 0.006
const SPIKED_HELMET := "spiked_helmet"
const SPIKED_HELMET_ICON_PATH := "res://assets/sprites/items/spiked_helmet.png"
const SPIKED_HELMET_FIELD_CHANCE := 0.006
const DASHHOLDER := "dashholder"
const DASHHOLDER_ICON_PATH := "res://assets/sprites/items/dashholder.png"
const DASHHOLDER_FIELD_CHANCE := 0.008
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


func _build_speedboots() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(SPEEDBOOTS)
	return {
		"name": SPEEDBOOTS,
		"display_name": "스피드부츠",
		"korean_name": "스피드부츠",
		"type": "passive",
		"rarity": "passive",
		"effect": SPEEDBOOTS,
		"slot": "shoes",
		"icon_path": SPEEDBOOTS_ICON_PATH,
		"chance": SPEEDBOOTS_FIELD_CHANCE,
		"description": "장착 중 플레이어의 이동 속도를 롤옵션만큼 높입니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(SPEEDBOOTS),
		"rolled_options": build_rolled_options(SPEEDBOOTS, rolls),
		"color": Color(0.0, 1.0, 100.0 / 255.0),
	}


func _build_speedgear() -> Dictionary:
	return {
		"name": SPEEDGEAR,
		"display_name": "보정벨트",
		"korean_name": "보정벨트",
		"type": "passive",
		"rarity": "passive",
		"effect": SPEEDGEAR,
		"slot": "belt",
		"icon_path": SPEEDGEAR_ICON_PATH,
		"chance": SPEEDGEAR_FIELD_CHANCE,
		"description": "장착 중 좌우 방향 전환 감속이 2.5배 증가합니다.",
		"rolls": {},
		"roll_options": [],
		"rolled_options": [],
		"fixed_options": get_fixed_options(SPEEDGEAR),
		"color": Color(1.0, 150.0 / 255.0, 0.0),
	}


func _build_gravitybelt() -> Dictionary:
	return {
		"name": GRAVITYBELT,
		"display_name": "무중력벨트",
		"korean_name": "무중력벨트",
		"type": "passive",
		"rarity": "passive",
		"effect": GRAVITYBELT,
		"slot": "belt",
		"icon_path": GRAVITYBELT_ICON_PATH,
		"chance": GRAVITYBELT_FIELD_CHANCE,
		"description": "이동 입력 즉시 최대 속도로 전환하고, 입력을 떼면 바로 정지합니다.",
		"rolls": {},
		"roll_options": [],
		"rolled_options": [],
		"fixed_options": get_fixed_options(GRAVITYBELT),
		"color": Color(120.0 / 255.0, 90.0 / 255.0, 1.0),
	}


func _build_sensor() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(SENSOR)
	return {
		"name": SENSOR,
		"display_name": "위험감지벨트",
		"korean_name": "위험감지벨트",
		"type": "passive",
		"rarity": "passive",
		"effect": SENSOR,
		"slot": "belt",
		"icon_path": SENSOR_ICON_PATH,
		"chance": SENSOR_FIELD_CHANCE,
		"description": "위험 상황에서 자동으로 대쉬합니다. 자동대쉬는 게이지와 대쉬토큰을 소모하지 않습니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(SENSOR),
		"rolled_options": build_rolled_options(SENSOR, rolls),
		"color": Color(150.0 / 255.0, 150.0 / 255.0, 1.0),
	}


func _build_spikeboots() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(SPIKEBOOTS)
	return {
		"name": SPIKEBOOTS,
		"display_name": "스파이크부츠",
		"korean_name": "스파이크부츠",
		"type": "passive",
		"rarity": "passive",
		"effect": SPIKEBOOTS,
		"slot": "shoes",
		"icon_path": SPIKEBOOTS_ICON_PATH,
		"chance": SPIKEBOOTS_FIELD_CHANCE,
		"description": "대쉬 후딜 시간과 대쉬 토큰 재충전 시간을 롤옵션만큼 줄입니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(SPIKEBOOTS),
		"rolled_options": build_rolled_options(SPIKEBOOTS, rolls),
		"color": Color(1.0, 100.0 / 255.0, 1.0),
	}


func _build_dowsing_pendulum() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(DOWSING_PENDULUM)
	return {
		"name": DOWSING_PENDULUM,
		"display_name": "다우징팬들럼",
		"korean_name": "다우징팬들럼",
		"type": "passive",
		"rarity": "passive",
		"effect": DOWSING_PENDULUM,
		"slot": "belt2",
		"icon_path": DOWSING_PENDULUM_ICON_PATH,
		"chance": DOWSING_PENDULUM_FIELD_CHANCE,
		"description": "롤옵션 범위 안의 필드 아이템을 플레이어 패들 쪽으로 끌어당깁니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(DOWSING_PENDULUM),
		"rolled_options": build_rolled_options(DOWSING_PENDULUM, rolls),
		"color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0),
	}


func _build_dowsing_goggles() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(DOWSING_GOGGLES)
	return {
		"name": DOWSING_GOGGLES,
		"display_name": "다우징 고글",
		"korean_name": "다우징 고글",
		"type": "passive",
		"rarity": "passive",
		"effect": DOWSING_GOGGLES,
		"slot": "head",
		"icon_path": DOWSING_GOGGLES_ICON_PATH,
		"chance": DOWSING_GOGGLES_FIELD_CHANCE,
		"description": "퍽 선택 화면에서 일정 확률로 일반 퍽 선택지가 1장 추가됩니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(DOWSING_GOGGLES),
		"rolled_options": build_rolled_options(DOWSING_GOGGLES, rolls),
		"color": Color(60.0 / 255.0, 200.0 / 255.0, 180.0 / 255.0),
	}


func _build_slot_add() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(SLOT_ADD)
	return {
		"name": SLOT_ADD,
		"display_name": "배낭",
		"korean_name": "배낭",
		"type": "passive",
		"rarity": "passive",
		"effect": SLOT_ADD,
		"slot": "belt2",
		"icon_path": SLOT_ADD_ICON_PATH,
		"chance": SLOT_ADD_FIELD_CHANCE,
		"description": "장착 중 액티브 아이템 슬롯을 롤옵션만큼 늘립니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(SLOT_ADD),
		"rolled_options": build_rolled_options(SLOT_ADD, rolls),
		"color": Color(1.0, 180.0 / 255.0, 80.0 / 255.0),
	}


func _build_chargebag() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(CHARGEBAG)
	return {
		"name": CHARGEBAG,
		"display_name": "충전가방",
		"korean_name": "충전가방",
		"type": "passive",
		"rarity": "passive",
		"effect": CHARGEBAG,
		"slot": "belt2",
		"icon_path": CHARGEBAG_ICON_PATH,
		"chance": CHARGEBAG_FIELD_CHANCE,
		"description": "장착 중 공이 벽에 닿을 때마다 기본 게이지 충전량의 일부를 추가로 얻습니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(CHARGEBAG),
		"rolled_options": build_rolled_options(CHARGEBAG, rolls),
		"color": Color(100.0 / 255.0, 1.0, 100.0 / 255.0),
	}


func _build_battery() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(BATTERY)
	return {
		"name": BATTERY,
		"display_name": "배터리팩",
		"korean_name": "배터리팩",
		"type": "passive",
		"rarity": "passive",
		"effect": BATTERY,
		"slot": "belt2",
		"icon_path": BATTERY_ICON_PATH,
		"chance": BATTERY_FIELD_CHANCE,
		"description": "장착 중 다음 스테이지로 넘어갈 때 게이지를 롤옵션 비율만큼 보존합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(BATTERY),
		"rolled_options": build_rolled_options(BATTERY, rolls),
		"color": Color(1.0, 1.0, 0.0),
	}


func _build_revival() -> Dictionary:
	return {
		"name": REVIVAL,
		"display_name": "윤회의 부적",
		"korean_name": "윤회의 부적",
		"type": "passive",
		"rarity": "passive",
		"effect": REVIVAL,
		"slot": "accessory",
		"icon_path": REVIVAL_ICON_PATH,
		"chance": REVIVAL_FIELD_CHANCE,
		"description": "장착 중 패배 직전 한 번 발동해 게임 오버를 막고 스테이지를 처음부터 다시 시작합니다.",
		"rolls": {},
		"roll_options": [],
		"rolled_options": [],
		"fixed_options": get_fixed_options(REVIVAL),
		"color": Color(1.0, 0.0, 1.0),
	}


func _build_master() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(MASTER)
	return {
		"name": MASTER,
		"display_name": "수리공망치",
		"korean_name": "수리공망치",
		"type": "passive",
		"rarity": "passive",
		"effect": MASTER,
		"slot": "arm",
		"icon_path": MASTER_ICON_PATH,
		"chance": MASTER_FIELD_CHANCE,
		"description": "장착 중 벽돌 액티브의 길이를 늘리고, 액티브 아이템 쿨타임을 줄이며, 벽돌 아이템의 필드 스폰 가중치를 높입니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(MASTER),
		"rolled_options": build_rolled_options(MASTER, rolls),
		"color": Color(1.0, 215.0 / 255.0, 0.0),
	}


func _build_gold_digger() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(GOLD_DIGGER)
	return {
		"name": GOLD_DIGGER,
		"display_name": "골드디거",
		"korean_name": "골드디거",
		"type": "passive",
		"rarity": "passive",
		"effect": GOLD_DIGGER,
		"slot": "arm",
		"icon_path": GOLD_DIGGER_ICON_PATH,
		"chance": GOLD_DIGGER_FIELD_CHANCE,
		"description": "장착 중 골드 획득량과 일부 게이지 획득량을 롤옵션만큼 늘립니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(GOLD_DIGGER),
		"rolled_options": build_rolled_options(GOLD_DIGGER, rolls),
		"color": Color(1.0, 200.0 / 255.0, 50.0 / 255.0),
	}


func _build_gold_bar() -> Dictionary:
	return {
		"name": GOLD_BAR,
		"display_name": "금괴",
		"korean_name": "금괴",
		"type": "passive",
		"rarity": "passive",
		"effect": GOLD_BAR,
		"slot": "accessory",
		"icon_path": GOLD_BAR_ICON_PATH,
		"chance": GOLD_BAR_FIELD_CHANCE,
		"description": "판매 전용 귀금속입니다. 보유 중 이동속도가 30% 감소하지만 상점에서 2000골드에 판매할 수 있습니다.",
		"sell_price": GOLD_BAR_SELL_PRICE,
		"rolls": {},
		"roll_options": [],
		"rolled_options": [],
		"fixed_options": get_fixed_options(GOLD_BAR),
		"color": Color(1.0, 215.0 / 255.0, 0.0),
	}


func _build_lucky_coin() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(LUCKY_COIN)
	return {
		"name": LUCKY_COIN,
		"display_name": "럭키코인",
		"korean_name": "럭키코인",
		"type": "passive",
		"rarity": "passive",
		"effect": LUCKY_COIN,
		"slot": "accessory",
		"icon_path": LUCKY_COIN_ICON_PATH,
		"chance": LUCKY_COIN_FIELD_CHANCE,
		"description": "장착 중 필드 아이템이 스폰될 때 롤옵션 확률로 보너스 아이템을 1개 더 생성합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(LUCKY_COIN),
		"rolled_options": build_rolled_options(LUCKY_COIN, rolls),
		"color": Color(1.0, 223.0 / 255.0, 0.0),
	}


func _build_adversity_armor() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(ADVERSITY_ARMOR)
	return {
		"name": ADVERSITY_ARMOR,
		"display_name": "역경의 갑옷",
		"korean_name": "역경의 갑옷",
		"type": "passive",
		"rarity": "passive",
		"effect": ADVERSITY_ARMOR,
		"slot": "top",
		"icon_path": ADVERSITY_ARMOR_ICON_PATH,
		"chance": ADVERSITY_ARMOR_FIELD_CHANCE,
		"description": "실점 후 그다음 라운드에 일정 확률로 사용자를 보호하는 무적의 벽이 생성됩니다. 다음 서브 시 공 속도도 증가합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(ADVERSITY_ARMOR),
		"rolled_options": build_rolled_options(ADVERSITY_ARMOR, rolls),
		"color": Color(0.96, 0.58, 0.18),
	}


func _build_shrapnel_armor() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(SHRAPNEL_ARMOR)
	return {
		"name": SHRAPNEL_ARMOR,
		"display_name": "파편갑옷",
		"korean_name": "파편갑옷",
		"type": "passive",
		"rarity": "passive",
		"effect": SHRAPNEL_ARMOR,
		"slot": "top",
		"icon_path": SHRAPNEL_ARMOR_ICON_PATH,
		"chance": SHRAPNEL_ARMOR_FIELD_CHANCE,
		"description": "플레이어 패들이 공을 칠 때 일정 확률로 게이지를 소모해 위쪽으로 가시 파편을 발사하고, 보스에게 맞으면 짧은 스턴과 넉백을 줍니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(SHRAPNEL_ARMOR),
		"rolled_options": build_rolled_options(SHRAPNEL_ARMOR, rolls),
		"color": Color(1.0, 150.0 / 255.0, 80.0 / 255.0),
	}


func _build_sage_ring() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(SAGE_RING)
	return {
		"name": SAGE_RING,
		"display_name": "현자의 반지",
		"korean_name": "현자의 반지",
		"type": "passive",
		"rarity": "passive",
		"effect": SAGE_RING,
		"slot": "accessory",
		"icon_path": SAGE_RING_ICON_PATH,
		"chance": SAGE_RING_FIELD_CHANCE,
		"description": "장착 중 모든 투자된 퍽의 유효 레벨을 1 올립니다. 대신 이동속도와 몸집크기가 롤옵션만큼 감소합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(SAGE_RING),
		"rolled_options": build_rolled_options(SAGE_RING, rolls),
		"fixed_options": get_fixed_options(SAGE_RING),
		"color": Color(180.0 / 255.0, 140.0 / 255.0, 1.0),
	}


func _build_cooltime() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(COOLTIME)
	return {
		"name": COOLTIME,
		"display_name": "쿨링볼",
		"korean_name": "쿨링볼",
		"type": "passive",
		"rarity": "passive",
		"effect": COOLTIME,
		"slot": "accessory",
		"icon_path": COOLTIME_ICON_PATH,
		"chance": COOLTIME_FIELD_CHANCE,
		"description": "장착 중 액티브 아이템 재사용 쿨타임을 롤옵션만큼 줄입니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(COOLTIME),
		"rolled_options": build_rolled_options(COOLTIME, rolls),
		"color": Color(0.0, 230.0 / 255.0, 1.0),
	}


func _build_timer_belt() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(TIMER_BELT)
	return {
		"name": TIMER_BELT,
		"display_name": "타이머벨트",
		"korean_name": "타이머벨트",
		"type": "passive",
		"rarity": "passive",
		"effect": TIMER_BELT,
		"slot": "belt",
		"icon_path": TIMER_BELT_ICON_PATH,
		"chance": TIMER_BELT_FIELD_CHANCE,
		"description": "장착 중 모든 캐릭터 스킬의 쿨타임을 롤옵션만큼 줄입니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(TIMER_BELT),
		"rolled_options": build_rolled_options(TIMER_BELT, rolls),
		"color": Color(90.0 / 255.0, 220.0 / 255.0, 230.0 / 255.0),
	}


func _build_fuel_pouch() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(FUEL_POUCH)
	return {
		"name": FUEL_POUCH,
		"display_name": "연료파우치",
		"korean_name": "연료파우치",
		"type": "passive",
		"rarity": "passive",
		"effect": FUEL_POUCH,
		"slot": "accessory",
		"icon_path": FUEL_POUCH_ICON_PATH,
		"chance": FUEL_POUCH_FIELD_CHANCE,
		"description": "장착 중 플레이어의 최대 게이지를 롤옵션 수치만큼 늘립니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(FUEL_POUCH),
		"rolled_options": build_rolled_options(FUEL_POUCH, rolls),
		"color": Color(180.0 / 255.0, 100.0 / 255.0, 40.0 / 255.0),
	}


func _build_bluetooth_ring() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(BLUETOOTH_RING)
	return {
		"name": BLUETOOTH_RING,
		"display_name": "블루투스링",
		"korean_name": "블루투스링",
		"type": "passive",
		"rarity": "passive",
		"effect": BLUETOOTH_RING,
		"slot": "accessory",
		"icon_path": BLUETOOTH_RING_ICON_PATH,
		"chance": BLUETOOTH_RING_FIELD_CHANCE,
		"description": "장착 중 플레이어가 패들로 공을 칠 때 얻는 게이지를 롤옵션만큼 늘립니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(BLUETOOTH_RING),
		"rolled_options": build_rolled_options(BLUETOOTH_RING, rolls),
		"color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0),
	}


func _build_star_detector() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(STAR_DETECTOR)
	return {
		"name": STAR_DETECTOR,
		"display_name": "별탐지기",
		"korean_name": "별탐지기",
		"type": "passive",
		"rarity": "passive",
		"effect": STAR_DETECTOR,
		"slot": "accessory",
		"icon_path": STAR_DETECTOR_ICON_PATH,
		"chance": STAR_DETECTOR_FIELD_CHANCE,
		"description": "장착 중 스타포인트 드랍이 생길 때 롤옵션 확률로 보너스 스타포인트 드랍을 1개 더 생성합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(STAR_DETECTOR),
		"rolled_options": build_rolled_options(STAR_DETECTOR, rolls),
		"color": Color(80.0 / 255.0, 200.0 / 255.0, 220.0 / 255.0),
	}


func _build_foul_whistle() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(FOUL_WHISTLE)
	return {
		"name": FOUL_WHISTLE,
		"display_name": "반칙호루라기",
		"korean_name": "반칙호루라기",
		"type": "passive",
		"rarity": "passive",
		"effect": FOUL_WHISTLE,
		"slot": "accessory",
		"icon_path": FOUL_WHISTLE_ICON_PATH,
		"chance": FOUL_WHISTLE_FIELD_CHANCE,
		"description": "라운드 패배 시 일정 확률로 심판이 호루라기를 불어 실점을 무효화하고 라운드를 다시 시작합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(FOUL_WHISTLE),
		"rolled_options": build_rolled_options(FOUL_WHISTLE, rolls),
		"color": Color(1.0, 235.0 / 255.0, 120.0 / 255.0),
	}


func _build_smartphone() -> Dictionary:
	return {
		"name": SMARTPHONE,
		"display_name": "스마트폰",
		"korean_name": "스마트폰",
		"type": "passive",
		"rarity": "passive",
		"effect": SMARTPHONE,
		"slot": "arm",
		"icon_path": SMARTPHONE_ICON_PATH,
		"chance": SMARTPHONE_FIELD_CHANCE,
		"description": "게이지가 낮으면 회복 아이템을 자동으로 사용하고, 위급할 때 스톱워치 또는 홀리베리어를 자동 발동합니다.",
		"rolls": {},
		"roll_options": [],
		"rolled_options": [],
		"color": Color(100.0 / 255.0, 150.0 / 255.0, 200.0 / 255.0),
	}


func _build_neural_helmet() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(NEURAL_HELMET)
	return {
		"name": NEURAL_HELMET,
		"display_name": "뉴럴헬멧",
		"korean_name": "뉴럴헬멧",
		"type": "passive",
		"rarity": "passive",
		"effect": NEURAL_HELMET,
		"slot": "head",
		"icon_path": NEURAL_HELMET_ICON_PATH,
		"chance": NEURAL_HELMET_FIELD_CHANCE,
		"description": "AI알약의 게이지 소모를 줄이고 AI알약 스폰율을 높입니다. AI알약 발동 중 방향키 입력으로 즉시 해제할 수 있습니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(NEURAL_HELMET),
		"rolled_options": build_rolled_options(NEURAL_HELMET, rolls),
		"color": Color(140.0 / 255.0, 180.0 / 255.0, 1.0),
	}


func _build_venom_mist_gauntlet() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(VENOM_MIST_GAUNTLET)
	return {
		"name": VENOM_MIST_GAUNTLET,
		"display_name": "독안개 건틀릿",
		"korean_name": "독안개 건틀릿",
		"type": "passive",
		"rarity": "passive",
		"effect": VENOM_MIST_GAUNTLET,
		"slot": "arm",
		"icon_path": VENOM_MIST_GAUNTLET_ICON_PATH,
		"chance": VENOM_MIST_GAUNTLET_FIELD_CHANCE,
		"description": "바이퍼 전용. 화랑 킥으로 공에 독을 싣고, 보스가 감염된 공을 가드하면 보스 주변에 독안개를 생성합니다. 독안개 안의 보스는 이동속도와 특수 게이지가 감소합니다.",
		"character_restriction": "viper",
		"rolls": rolls,
		"roll_options": get_roll_options(VENOM_MIST_GAUNTLET),
		"rolled_options": build_rolled_options(VENOM_MIST_GAUNTLET, rolls),
		"color": Color(80.0 / 255.0, 200.0 / 255.0, 80.0 / 255.0),
	}


func _build_reinforced_boomerang_gauntlet() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(REINFORCED_BOOMERANG_GAUNTLET)
	return {
		"name": REINFORCED_BOOMERANG_GAUNTLET,
		"display_name": "강화부메랑 장갑",
		"korean_name": "강화부메랑 장갑",
		"type": "passive",
		"rarity": "passive",
		"effect": REINFORCED_BOOMERANG_GAUNTLET,
		"slot": "arm",
		"icon_path": REINFORCED_BOOMERANG_GAUNTLET_ICON_PATH,
		"chance": REINFORCED_BOOMERANG_GAUNTLET_FIELD_CHANCE,
		"description": "부메랑을 메탈 강화하고 발사속도, 유도성능, 스폰율, 넉백, 스턴 시간을 올립니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(REINFORCED_BOOMERANG_GAUNTLET),
		"rolled_options": build_rolled_options(REINFORCED_BOOMERANG_GAUNTLET, rolls),
		"fixed_options": get_fixed_options(REINFORCED_BOOMERANG_GAUNTLET),
		"color": Color(150.0 / 255.0, 200.0 / 255.0, 1.0),
	}


func _build_commando_arm() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(COMMANDO_ARM)
	return {
		"name": COMMANDO_ARM,
		"display_name": "코만도암",
		"korean_name": "코만도암",
		"type": "passive",
		"rarity": "passive",
		"effect": COMMANDO_ARM,
		"slot": "arm",
		"icon_path": COMMANDO_ARM_ICON_PATH,
		"chance": COMMANDO_ARM_FIELD_CHANCE,
		"description": "투척류 아이템을 전투용 팔 장비로 보조합니다. 수류탄, 조명탄, 화염병은 더 빠르게 날아가고 폭발 범위가 넓어지며, 다이너마이트, 바나나, 비누, 부메랑의 준비시간이 줄어듭니다. 연막탄 지속시간도 증가합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(COMMANDO_ARM),
		"rolled_options": build_rolled_options(COMMANDO_ARM, rolls),
		"color": Color(60.0 / 255.0, 60.0 / 255.0, 70.0 / 255.0),
	}


func _build_rainbow_fur_glove() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(RAINBOW_FUR_GLOVE)
	return {
		"name": RAINBOW_FUR_GLOVE,
		"display_name": "무지개털장갑",
		"korean_name": "무지개털장갑",
		"type": "passive",
		"rarity": "passive",
		"effect": RAINBOW_FUR_GLOVE,
		"slot": "arm",
		"icon_path": RAINBOW_FUR_GLOVE_ICON_PATH,
		"chance": RAINBOW_FUR_GLOVE_FIELD_CHANCE,
		"description": "공을 패들로 칠 때 일정 확률로 발동하여 장착한 캐릭터 스킬의 진행 중 쿨타임을 즉시 감소시킵니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(RAINBOW_FUR_GLOVE),
		"rolled_options": build_rolled_options(RAINBOW_FUR_GLOVE, rolls),
		"color": Color(1.0, 170.0 / 255.0, 220.0 / 255.0),
	}


func _build_knee_pads() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(KNEE_PADS)
	return {
		"name": KNEE_PADS,
		"display_name": "킥차져",
		"korean_name": "킥차져",
		"type": "passive",
		"rarity": "passive",
		"effect": KNEE_PADS,
		"slot": "knee",
		"icon_path": KNEE_PADS_ICON_PATH,
		"chance": KNEE_PADS_FIELD_CHANCE,
		"description": "장착 중 하프대쉬로 공을 맞추면 기본 게이지 획득량을 기준으로 롤옵션 비율만큼 충전합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(KNEE_PADS),
		"rolled_options": build_rolled_options(KNEE_PADS, rolls),
		"color": Color(80.0 / 255.0, 80.0 / 255.0, 100.0 / 255.0),
	}


func _build_dashgear() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(DASHGEAR)
	return {
		"name": DASHGEAR,
		"display_name": "대쉬기어",
		"korean_name": "대쉬기어",
		"type": "passive",
		"rarity": "passive",
		"effect": DASHGEAR,
		"slot": "knee",
		"icon_path": DASHGEAR_ICON_PATH,
		"chance": DASHGEAR_FIELD_CHANCE,
		"description": "대쉬 거리를 늘리고, 일정 확률로 다음 대쉬 토큰 소모를 무효화합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(DASHGEAR),
		"rolled_options": build_rolled_options(DASHGEAR, rolls),
		"color": Color(1.0, 150.0 / 255.0, 100.0 / 255.0),
	}


func _build_soul_burst() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(SOUL_BURST)
	return {
		"name": SOUL_BURST,
		"display_name": "소울버스트",
		"korean_name": "소울버스트",
		"type": "passive",
		"rarity": "passive",
		"effect": SOUL_BURST,
		"slot": "knee",
		"icon_path": SOUL_BURST_ICON_PATH,
		"chance": SOUL_BURST_FIELD_CHANCE,
		"description": "대쉬 토큰이 없을 때 스페셜 게이지를 소모해 하프대쉬 대신 풀대쉬를 발동합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(SOUL_BURST),
		"rolled_options": build_rolled_options(SOUL_BURST, rolls),
		"color": Color(150.0 / 255.0, 80.0 / 255.0, 1.0),
	}


func _build_bulkup() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(BULKUP)
	return {
		"name": BULKUP,
		"display_name": "벌크업슈트",
		"korean_name": "벌크업슈트",
		"type": "passive",
		"rarity": "passive",
		"effect": BULKUP,
		"slot": "top",
		"icon_path": BULKUP_ICON_PATH,
		"chance": BULKUP_FIELD_CHANCE,
		"description": "장착 중 플레이어 패들의 몸집크기를 롤옵션만큼 늘립니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(BULKUP),
		"rolled_options": build_rolled_options(BULKUP, rolls),
		"color": Color(1.0, 100.0 / 255.0, 100.0 / 255.0),
	}


func _build_dashholder() -> Dictionary:
	return {
		"name": DASHHOLDER,
		"display_name": "대쉬홀더",
		"korean_name": "대쉬홀더",
		"type": "passive",
		"rarity": "passive",
		"effect": DASHHOLDER,
		"slot": "accessory",
		"icon_path": DASHHOLDER_ICON_PATH,
		"chance": DASHHOLDER_FIELD_CHANCE,
		"description": "장착 중 대쉬 토큰 최대 개수를 1개 늘립니다.",
		"rolls": {},
		"roll_options": [],
		"rolled_options": [],
		"fixed_options": get_fixed_options(DASHHOLDER),
		"color": Color(1.0, 150.0 / 255.0, 100.0 / 255.0),
	}


func _build_bulletproof_hat() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(BULLETPROOF_HAT)
	return {
		"name": BULLETPROOF_HAT,
		"display_name": "방탄모자",
		"korean_name": "방탄모자",
		"type": "passive",
		"rarity": "passive",
		"effect": BULLETPROOF_HAT,
		"slot": "head",
		"icon_path": BULLETPROOF_HAT_ICON_PATH,
		"chance": BULLETPROOF_HAT_FIELD_CHANCE,
		"description": "장착 중 플레이어에게 걸리는 스턴 시간을 롤옵션만큼 줄입니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(BULLETPROOF_HAT),
		"rolled_options": build_rolled_options(BULLETPROOF_HAT, rolls),
		"color": Color(0.38, 0.72, 1.0),
	}


func _build_spiked_helmet() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(SPIKED_HELMET)
	return {
		"name": SPIKED_HELMET,
		"display_name": "가시투구",
		"korean_name": "가시투구",
		"type": "passive",
		"rarity": "passive",
		"effect": SPIKED_HELMET,
		"slot": "head",
		"icon_path": SPIKED_HELMET_ICON_PATH,
		"chance": SPIKED_HELMET_FIELD_CHANCE,
		"description": "장착 중 플레이어가 받는 넉백 속도를 롤옵션만큼 줄입니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(SPIKED_HELMET),
		"rolled_options": build_rolled_options(SPIKED_HELMET, rolls),
		"color": Color(1.0, 0.62, 0.32),
	}


func _build_pandora_legacy() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(PANDORA_LEGACY)
	return {
		"name": PANDORA_LEGACY,
		"display_name": "판도라의 유산",
		"korean_name": "판도라의 유산",
		"type": "mythic",
		"rarity": "mythic",
		"effect": PANDORA_LEGACY,
		"slot": "back",
		"icon_path": PANDORA_LEGACY_ICON_PATH,
		"icon_sheet_path": PANDORA_LEGACY_ICON_SHEET_PATH,
		"icon_frame_count": MYTHIC_ICON_FRAME_COUNT,
		"icon_frame_msec": MYTHIC_ICON_FRAME_MSEC,
		"icon_source_inset": 0.0,
		"icon_fill_slot": true,
		"icon_target_pad": 5.0,
		"chance": PANDORA_LEGACY_FIELD_CHANCE,
		"description": "라운드 승리 시 일정 확률로 발동해 3개의 아이템 중 하나를 선택합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(PANDORA_LEGACY),
		"rolled_options": build_rolled_options(PANDORA_LEGACY, rolls),
		"color": Color(150.0 / 255.0, 50.0 / 255.0, 200.0 / 255.0),
	}


func _build_megingjord() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(MEGINGJORD)
	return {
		"name": MEGINGJORD,
		"display_name": "메긴교르드",
		"korean_name": "메긴교르드",
		"type": "mythic",
		"rarity": "mythic",
		"effect": MEGINGJORD,
		"slot": "belt",
		"icon_path": MEGINGJORD_ICON_PATH,
		"icon_sheet_path": MEGINGJORD_ICON_SHEET_PATH,
		"icon_frame_count": MYTHIC_ICON_FRAME_COUNT,
		"icon_frame_msec": MYTHIC_ICON_FRAME_MSEC,
		"icon_source_inset": 0.0,
		"icon_fill_slot": true,
		"icon_target_pad": 5.0,
		"chance": MEGINGJORD_FIELD_CHANCE,
		"description": "퍽 선택 시 추가 선택 기회를 얻습니다. 한 선택 묶음에서 최대 2회까지 연속 발동합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(MEGINGJORD),
		"rolled_options": build_rolled_options(MEGINGJORD, rolls),
		"color": Color(1.0, 215.0 / 255.0, 75.0 / 255.0),
	}


func _build_ragnarok_hammer() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(RAGNAROK_HAMMER)
	return {
		"name": RAGNAROK_HAMMER,
		"display_name": "라그나로크 해머",
		"korean_name": "라그나로크 해머",
		"type": "mythic",
		"rarity": "mythic",
		"effect": RAGNAROK_HAMMER,
		"slot": "arm",
		"icon_path": RAGNAROK_HAMMER_ICON_PATH,
		"icon_sheet_path": RAGNAROK_HAMMER_ICON_SHEET_PATH,
		"icon_frame_count": MYTHIC_ICON_FRAME_COUNT,
		"icon_frame_msec": MYTHIC_ICON_FRAME_MSEC,
		"icon_source_inset": 0.0,
		"icon_fill_slot": true,
		"icon_target_pad": 5.0,
		"chance": RAGNAROK_HAMMER_FIELD_CHANCE,
		"description": "플레이어가 공을 받아칠 때 게이지를 소모해 스턴공을 만들고, 보스가 받아치면 넉백과 스턴을 겁니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(RAGNAROK_HAMMER),
		"rolled_options": build_rolled_options(RAGNAROK_HAMMER, rolls),
		"color": Color(120.0 / 255.0, 190.0 / 255.0, 1.0),
	}


func _build_hermes_shoes() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(HERMES_SHOES)
	return {
		"name": HERMES_SHOES,
		"display_name": "헤르메스의 신발",
		"korean_name": "헤르메스의 신발",
		"type": "mythic",
		"rarity": "mythic",
		"effect": HERMES_SHOES,
		"slot": "shoes",
		"icon_path": HERMES_SHOES_ICON_PATH,
		"icon_sheet_path": HERMES_SHOES_ICON_SHEET_PATH,
		"icon_frame_count": MYTHIC_ICON_FRAME_COUNT,
		"icon_frame_msec": MYTHIC_ICON_FRAME_MSEC,
		"icon_source_inset": 0.0,
		"icon_fill_slot": true,
		"icon_target_pad": 5.0,
		"chance": HERMES_SHOES_FIELD_CHANCE,
		"description": "신들의 전령이 신던 날개 신발입니다. 롤 옵션만큼 플레이어 이동속도를 증가시킵니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(HERMES_SHOES),
		"rolled_options": build_rolled_options(HERMES_SHOES, rolls),
		"color": Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
	}


func _build_poseidon_trident() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(POSEIDON_TRIDENT)
	return {
		"name": POSEIDON_TRIDENT,
		"display_name": "포세이돈의 삼지창",
		"korean_name": "포세이돈의 삼지창",
		"type": "mythic",
		"rarity": "mythic",
		"effect": POSEIDON_TRIDENT,
		"slot": "arm",
		"icon_path": POSEIDON_TRIDENT_ICON_PATH,
		"icon_sheet_path": POSEIDON_TRIDENT_ICON_SHEET_PATH,
		"icon_frame_count": MYTHIC_ICON_FRAME_COUNT,
		"icon_frame_msec": MYTHIC_ICON_FRAME_MSEC,
		"icon_source_inset": 0.0,
		"icon_fill_slot": true,
		"icon_target_pad": 5.0,
		"chance": POSEIDON_TRIDENT_FIELD_CHANCE,
		"description": "대시 회복 순간 좌우에 거대한 물회오리를 생성하여 보스가 내려친 공을 위쪽으로 강하게 튕겨냅니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(POSEIDON_TRIDENT),
		"rolled_options": build_rolled_options(POSEIDON_TRIDENT, rolls),
		"color": Color(70.0 / 255.0, 185.0 / 255.0, 1.0),
	}


func _build_sacred_laurel() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(SACRED_LAUREL)
	return {
		"name": SACRED_LAUREL,
		"display_name": "신성 월계수",
		"korean_name": "신성 월계수",
		"type": "mythic",
		"rarity": "mythic",
		"effect": SACRED_LAUREL,
		"slot": "accessory",
		"icon_path": SACRED_LAUREL_ICON_PATH,
		"icon_sheet_path": SACRED_LAUREL_ICON_SHEET_PATH,
		"icon_frame_count": MYTHIC_ICON_FRAME_COUNT,
		"icon_frame_msec": MYTHIC_ICON_FRAME_MSEC,
		"icon_source_inset": 0.0,
		"icon_fill_slot": true,
		"icon_target_pad": 5.0,
		"chance": SACRED_LAUREL_FIELD_CHANCE,
		"description": "월계수 잎이 플레이어 주변을 회전하며 보호합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(SACRED_LAUREL),
		"rolled_options": build_rolled_options(SACRED_LAUREL, rolls),
		"color": Color(105.0 / 255.0, 215.0 / 255.0, 120.0 / 255.0),
	}


func _build_transcendent_crown() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(TRANSCENDENT_CROWN)
	return {
		"name": TRANSCENDENT_CROWN,
		"display_name": "초월자의 관",
		"korean_name": "초월자의 관",
		"type": "mythic",
		"rarity": "mythic",
		"effect": TRANSCENDENT_CROWN,
		"slot": "head",
		"icon_path": TRANSCENDENT_CROWN_ICON_PATH,
		"icon_sheet_path": TRANSCENDENT_CROWN_ICON_SHEET_PATH,
		"icon_frame_count": MYTHIC_ICON_FRAME_COUNT,
		"icon_frame_msec": MYTHIC_ICON_FRAME_MSEC,
		"icon_source_inset": 0.0,
		"icon_fill_slot": true,
		"icon_target_pad": 5.0,
		"chance": TRANSCENDENT_CROWN_FIELD_CHANCE,
		"description": "이미 투자한 모든 퍽의 효과 레벨을 롤 옵션만큼 증가시킵니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(TRANSCENDENT_CROWN),
		"rolled_options": build_rolled_options(TRANSCENDENT_CROWN, rolls),
		"color": Color(1.0, 215.0 / 255.0, 100.0 / 255.0),
	}


func _build_heavenly_cape() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(HEAVENLY_CAPE)
	return {
		"name": HEAVENLY_CAPE,
		"display_name": "천상의 망토",
		"korean_name": "천상의 망토",
		"type": "mythic",
		"rarity": "mythic",
		"effect": HEAVENLY_CAPE,
		"slot": "back",
		"icon_path": HEAVENLY_CAPE_ICON_PATH,
		"icon_sheet_path": HEAVENLY_CAPE_ICON_SHEET_PATH,
		"icon_frame_count": MYTHIC_ICON_FRAME_COUNT,
		"icon_frame_msec": MYTHIC_ICON_FRAME_MSEC,
		"icon_source_inset": 0.0,
		"icon_fill_slot": true,
		"icon_target_pad": 5.0,
		"chance": HEAVENLY_CAPE_FIELD_CHANCE,
		"description": "스킬 구슬 슬롯을 1칸 늘리고 모든 플레이어 스킬 쿨타임을 줄입니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(HEAVENLY_CAPE),
		"rolled_options": build_rolled_options(HEAVENLY_CAPE, rolls),
		"fixed_options": [
			{"label": "스킬 구슬 슬롯", "value": "+1", "unit": "칸"},
		],
		"color": Color(190.0 / 255.0, 225.0 / 255.0, 1.0),
	}


func _build_horn_strawberry_mask() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(HORN_STRAWBERRY_MASK)
	return {
		"name": HORN_STRAWBERRY_MASK,
		"display_name": "뿔딸기 변신가면",
		"korean_name": "뿔딸기 변신가면",
		"type": "mythic",
		"rarity": "mythic",
		"effect": HORN_STRAWBERRY_MASK,
		"slot": "head",
		"icon_path": HORN_STRAWBERRY_MASK_ICON_PATH,
		"icon_sheet_path": HORN_STRAWBERRY_MASK_ICON_SHEET_PATH,
		"icon_frame_count": MYTHIC_ICON_FRAME_COUNT,
		"icon_frame_msec": MYTHIC_ICON_FRAME_MSEC,
		"icon_source_inset": 0.0,
		"icon_fill_slot": true,
		"icon_target_pad": 5.0,
		"chance": HORN_STRAWBERRY_MASK_FIELD_CHANCE,
		"description": "A→D→A→D→A→D 커맨드로 1스테이지 1회 뿔딸기로 변신합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(HORN_STRAWBERRY_MASK),
		"rolled_options": build_rolled_options(HORN_STRAWBERRY_MASK, rolls),
		"fixed_options": [
			{"label": "변신 비용", "value": "-500", "unit": "게이지"},
			{"label": "공 타격 게이지", "value": "+80", "unit": ""},
		],
		"color": Color(1.0, 72.0 / 255.0, 90.0 / 255.0),
	}


func _build_celestial_armor() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(CELESTIAL_ARMOR)
	return {
		"name": CELESTIAL_ARMOR,
		"display_name": "천구의 부동 갑주",
		"korean_name": "천구의 부동 갑주",
		"type": "mythic",
		"rarity": "mythic",
		"effect": CELESTIAL_ARMOR,
		"slot": "top",
		"icon_path": CELESTIAL_ARMOR_ICON_PATH,
		"icon_sheet_path": CELESTIAL_ARMOR_ICON_SHEET_PATH,
		"icon_frame_count": MYTHIC_ICON_FRAME_COUNT,
		"icon_frame_msec": MYTHIC_ICON_FRAME_MSEC,
		"icon_source_inset": 0.0,
		"icon_fill_slot": true,
		"icon_target_pad": 5.0,
		"chance": CELESTIAL_ARMOR_FIELD_CHANCE,
		"description": "스턴이 들어올 때 롤 확률로 무시하고, 발동 시 게이지를 소모합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(CELESTIAL_ARMOR),
		"rolled_options": build_rolled_options(CELESTIAL_ARMOR, rolls),
		"color": Color(180.0 / 255.0, 200.0 / 255.0, 1.0),
	}


func _build_baal_boots() -> Dictionary:
	var rolls: Dictionary = build_default_rolls(BAAL_BOOTS)
	return {
		"name": BAAL_BOOTS,
		"display_name": "바알의 부츠",
		"korean_name": "바알의 부츠",
		"type": "mythic",
		"rarity": "mythic",
		"effect": BAAL_BOOTS,
		"slot": "shoes",
		"icon_path": BAAL_BOOTS_ICON_PATH,
		"icon_sheet_path": BAAL_BOOTS_ICON_SHEET_PATH,
		"icon_frame_count": MYTHIC_ICON_FRAME_COUNT,
		"icon_frame_msec": MYTHIC_ICON_FRAME_MSEC,
		"icon_source_inset": 0.0,
		"icon_fill_slot": true,
		"icon_target_pad": 5.0,
		"chance": BAAL_BOOTS_FIELD_CHANCE,
		"description": "날씨 이벤트가 시작되면 바알의 힘으로 현재 날씨를 흡수하고 게이지를 회복합니다. 흡수한 날씨에 따라 이번 라운드 동안 추가 효과가 발동합니다.",
		"rolls": rolls,
		"roll_options": get_roll_options(BAAL_BOOTS),
		"rolled_options": build_rolled_options(BAAL_BOOTS, rolls),
		"color": Color(1.0, 90.0 / 255.0, 55.0 / 255.0),
	}


func _build_elixir_of_mastery() -> Dictionary:
	return {
		"name": ELIXIR_OF_MASTERY,
		"display_name": "엘릭서 오브 마스터리",
		"korean_name": "엘릭서 오브 마스터리",
		"type": "mythic",
		"rarity": "mythic",
		"effect": ELIXIR_OF_MASTERY,
		"slot": "",
		"icon_path": ELIXIR_OF_MASTERY_ICON_PATH,
		"chance": 0.0,
		"description": "사용 시 보유 중인 퍽 중 랜덤으로 1개를 선택해 Lv.5로 만듭니다. 신화급 액티브 아이템으로, 사용 후 소모됩니다.",
		"rolls": {},
		"roll_options": [],
		"rolled_options": [],
		"color": Color(0.47, 0.2, 0.78),
		"consumable": true,
		"mythic_active": true,
	}
