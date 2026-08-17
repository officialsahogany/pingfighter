extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ActiveItemRaritySchema := preload(
	"res://scripts/items/active_item_rarity_schema.gd"
)

const DEFAULT_COOLDOWN_MSEC := 7000
const LINGPET_SPIRIT_WATER_COOLDOWN_MSEC := 1500
const GAUGE_MAX := 500.0
const GAUGE_CHARGE_AMOUNT := 220.0
const DAESEONG_YEONGDAN_SPAWN_WEIGHT := 0.001

const AIPILL_ICON_PATH := "res://assets/sprites/items/aipill_icon_hq_v1.png"
const GAUGE_CHARGE_ICON_PATH := "res://assets/sprites/items/gauge_charge_icon_hq_v1.png"
const LIFE_ELIXIR_ICON_PATH := "res://assets/sprites/items/life_elixir_icon_hq_v1.png"
const AMMO_BOX_ICON_PATH := "res://assets/sprites/items/ammo_box_icon_hq_v1.png"
const DOPING_POTION_ICON_PATH := "res://assets/sprites/items/doping_potion_icon_hq_v1.png"
const VITAMIN_PILL_ICON_PATH := "res://assets/sprites/items/vitamin_pill_icon_hq_v1.png"
const STRANGE_VIAL_ICON_PATH := "res://assets/sprites/items/strange_vial.png"
const PANDORA_BOX_ICON_PATH := "res://assets/sprites/items/pandora_box_icon_hq_v1.png"
const MYSTIC_DICE_ICON_PATH := "res://assets/sprites/items/mystic_dice_icon_hq_v1.png"
const GRENADE_ICON_PATH := "res://assets/sprites/items/pokhwatan_icon_imagegen_v1.png"
const FLARE_ICON_PATH := "res://assets/sprites/items/flare_icon_hq_v1.png"
const TEAR_GAS_ICON_PATH := "res://assets/sprites/items/tear_gas_icon_hq_v1.png"
const DYNAMITE_ICON_PATH := "res://assets/sprites/items/dynamite_icon_hq_v1.png"
const MOLOTOV_ICON_PATH := "res://assets/sprites/items/molotov_icon_hq_v1.png"
const STOPWATCH_ICON_PATH := "res://assets/sprites/items/stopwatch_icon_hq_v1.png"
const MAGNET_FIELD_ICON_PATH := "res://assets/sprites/items/magnet_field_icon_hq_v1.png"
const LONG_BOOST_ICON_PATH := "res://assets/sprites/items/long_boost_icon_hq_v1.png"
const REGENERATION_POTION_ICON_PATH := "res://assets/sprites/items/regeneration_potion_icon_hq_v1.png"
const HOLY_BARRIER_ICON_PATH := "res://assets/sprites/items/holy_barrier_icon_hq_v1.png"
const DASH_BOOST_ICON_PATH := "res://assets/sprites/items/dash_boost_icon_hq_v1.png"
const WALL_ICON_PATH := "res://assets/sprites/items/wall_icon_hq_v1.png"
const TRAMPOLINE_ICON_PATH := "res://assets/sprites/items/trampoline_icon_hq_v1.png"
const CAMPFIRE_ICON_PATH := "res://assets/sprites/items/campfire_icon_hq_v1.png"
const BOOMERANG_ICON_PATH := "res://assets/sprites/items/boomerang_icon_hq_v1.png"
const BOOMERANG_METAL_ICON_PATH := "res://assets/sprites/items/boomerang_metal_icon_hq_v1.png"
const BANANA_ICON_PATH := "res://assets/sprites/items/banana_icon_hq_v1.png"
const SOAP_ICON_PATH := "res://assets/sprites/items/soap_icon_hq_v1.png"
const SPIDER_MINE_ICON_PATH := "res://assets/sprites/items/spider_mine_icon_hq_v1.png"
const ELIXIR_OF_MASTERY_ICON_PATH := "res://assets/sprites/items/elixir_of_mastery_icon_hq_v1.png"
const MILK_BOTTLE_ICON_PATH := "res://assets/sprites/items/milk_bottle_icon_hq_v1.png"
const MILK_BOTTLE_FIELD_ICON_PATH := "res://assets/sprites/items/milk_bottle_field_imagegen_v1.png"
const CHEDDAR_CHEESE_ICON_PATH := "res://assets/sprites/items/cheddar_cheese_icon_hq_v1.png"
const CAMEMBERT_CHEESE_ICON_PATH := "res://assets/sprites/items/camembert_cheese_icon_hq_v1.png"
const EMMENTAL_CHEESE_ICON_PATH := "res://assets/sprites/items/emmental_cheese_icon_hq_v1.png"
const LINGPET_SPIRIT_WATER_ICON_PATH := "res://assets/sprites/items/lingpet_spirit_water_icon_hq_v1.png"
const LINGPET_EGG_ICON_PATH := "res://assets/sprites/items/lingpet_egg_icon_hq_v1.png"

const LEGACY_DISABLED_ACQUISITION_NAMES := {
	"strange_vial": true,
}

const CATALOG_ORDER := [
	"gauge_charge", "lingpet_spirit_water", "lingpet_egg", "life_elixir",
	"ammo_box", "doping_potion", "vitamin_pill", "strange_vial", "aipill",
	"pandora_box", "mystic_dice", "grenade", "flare", "tear_gas",
	"dynamite", "molotov", "stopwatch", "magnet_field", "long_boost",
	"regeneration_potion", "holy_barrier", "dash_boost", "wall", "trampoline",
	"campfire", "boomerang", "banana", "soap", "spider_mine",
	"elixir_of_mastery", "milk_bottle", "cheddar_cheese",
	"camembert_cheese", "emmental_cheese",
]

const FIELD_SPAWN_ORDER := [
	"gauge_charge",
	"lingpet_spirit_water",
	"lingpet_egg",
	"life_elixir",
	"vitamin_pill",
	"aipill",
	"pandora_box",
	"mystic_dice",
	"grenade",
	"flare",
	"tear_gas",
	"dynamite",
	"molotov",
	"stopwatch",
	"magnet_field",
	"long_boost",
	"regeneration_potion",
	"holy_barrier",
	"dash_boost",
	"wall",
	"trampoline",
	"campfire",
	"boomerang",
	"banana",
	"soap",
	"spider_mine",
	"elixir_of_mastery",
]


func build_item_by_name(item_name: String) -> Dictionary:
	if is_acquisition_disabled(item_name):
		return {}
	var item_data: Dictionary = {}
	match item_name:
		"gauge_charge":
			item_data = _build_gauge_charge()
		"lingpet_spirit_water":
			item_data = _build_lingpet_spirit_water()
		"lingpet_egg":
			item_data = _build_lingpet_egg()
		"life_elixir":
			item_data = _build_life_elixir()
		"ammo_box":
			item_data = _build_ammo_box()
		"doping_potion":
			item_data = _build_doping_potion()
		"vitamin_pill":
			item_data = _build_vitamin_pill()
		"strange_vial":
			item_data = _build_strange_vial()
		"aipill":
			item_data = _build_aipill()
		"pandora_box":
			item_data = _build_pandora_box()
		"mystic_dice":
			item_data = _build_mystic_dice()
		"grenade":
			item_data = _build_grenade()
		"flare":
			item_data = _build_flare()
		"tear_gas":
			item_data = _build_tear_gas()
		"dynamite":
			item_data = _build_dynamite()
		"molotov":
			item_data = _build_molotov()
		"stopwatch":
			item_data = _build_stopwatch()
		"magnet_field":
			item_data = _build_magnet_field()
		"long_boost":
			item_data = _build_long_boost()
		"regeneration_potion":
			item_data = _build_regeneration_potion()
		"holy_barrier":
			item_data = _build_holy_barrier()
		"dash_boost":
			item_data = _build_dash_boost()
		"wall":
			item_data = _build_wall()
		"trampoline":
			item_data = _build_trampoline()
		"campfire":
			item_data = _build_campfire()
		"boomerang":
			item_data = _build_boomerang()
		"banana":
			item_data = _build_banana()
		"soap":
			item_data = _build_soap()
		"spider_mine":
			item_data = _build_spider_mine()
		"elixir_of_mastery":
			item_data = _build_elixir_of_mastery()
		"milk_bottle":
			item_data = _build_milk_bottle()
		"cheddar_cheese":
			item_data = _build_cheese(
				"cheddar_cheese",
				"체다치즈",
				300.0,
				1.16,
				CHEDDAR_CHEESE_ICON_PATH,
				Color(1.0, 0.64, 0.18)
			)
		"camembert_cheese":
			item_data = _build_cheese(
				"camembert_cheese",
				"까망베르치즈",
				400.0,
				1.18,
				CAMEMBERT_CHEESE_ICON_PATH,
				Color(0.96, 0.92, 0.80)
			)
		"emmental_cheese":
			item_data = _build_cheese(
				"emmental_cheese",
				"에멘탈치즈",
				500.0,
				1.20,
				EMMENTAL_CHEESE_ICON_PATH,
				Color(1.0, 0.82, 0.24)
			)
	if item_data.is_empty():
		return {}
	item_data = ActiveItemRaritySchema.normalize_item_data(item_data)
	return LanguageSettings.localize_item_data(item_data)


static func is_acquisition_disabled(item_name: String) -> bool:
	return LEGACY_DISABLED_ACQUISITION_NAMES.has(item_name)


func build_random_spawn_item() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for item_name in FIELD_SPAWN_ORDER:
		var candidate: Dictionary = build_item_by_name(str(item_name))
		if not candidate.is_empty():
			candidates.append(candidate)
	if candidates.is_empty():
		return {}

	var total_weight: float = 0.0
	for candidate in candidates:
		total_weight += max(0.0, float(candidate.get("chance", 0.0)))
	var roll: float = randf() * max(0.001, total_weight)
	for candidate in candidates:
		roll -= max(0.0, float(candidate.get("chance", 0.0)))
		if roll <= 0.0:
			return candidate.duplicate(true)
	return candidates.back().duplicate(true)


func get_display_name(item_name: String) -> String:
	var item_data: Dictionary = build_item_by_name(item_name)
	return str(item_data.get("display_name", item_name))


func _build_gauge_charge() -> Dictionary:
	return {
		"name": "gauge_charge",
		"display_name": "탕약",
		"type": "active",
		"effect": "gauge_charge",
		"chance": 0.042,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"gauge_gain": GAUGE_CHARGE_AMOUNT,
		"gauge_max": GAUGE_MAX,
		"description": "탕약을 마셔 기력을 220 충전합니다.",
		"icon_path": GAUGE_CHARGE_ICON_PATH,
		"color": Color(1.0, 100.0 / 255.0, 1.0),
		"consumable": true,
	}


func _build_lingpet_spirit_water() -> Dictionary:
	return {
		"name": "lingpet_spirit_water",
		"display_name": "심령수",
		"type": "active",
		"effect": "lingpet_spirit_water",
		# Transitional spawn weight inherited from the basic feed. Final tuning
		# remains an explicit §10 approval item.
		"chance": 0.010,
		"duration": 0,
		"cooldown_msec": LINGPET_SPIRIT_WATER_COOLDOWN_MSEC,
		"description": "수호령 지속시간을 전량 회복합니다. 남은 시간이 최대치를 넘었다면 그대로 보존합니다.",
		"icon_path": LINGPET_SPIRIT_WATER_ICON_PATH,
		"color": Color(0.30, 0.90, 0.84),
		"no_global_cooldown": true,
		"consumable": true,
		"tuning_pending": true,
	}


func _build_lingpet_egg() -> Dictionary:
	# Pro (champion) / Mythic only — gated in active_item_field_spawn_pool via
	# can_offer_egg_item. On use it places an egg (deploy_egg_from_item): with NO companion
	# the egg hatches into the companion; with a companion ALREADY on field a SEPARATE egg
	# incubates alongside it (the companion keeps accompanying the player), then opens the
	# shared Replace / Absorb decision. Absorb grants one Guardian Enhancement through the
	# same reward path as the perk. Only one egg incubates at a time
	# (can_offer_egg_item blocks while _state == STATE_EGG or an incubator is active). Junior
	# never sees this item (its lingpet is auto-present).
	return {
		"name": "lingpet_egg",
		"display_name": "수호령 알",
		"type": "active",
		"effect": "lingpet_egg",
		"chance": 0.030,
		"duration": 0,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "필드에 수호령 알을 설치합니다. 공으로 맞혀 부화시키면 수호령 하나를 무작위로 얻습니다.",
		"icon_path": LINGPET_EGG_ICON_PATH,
		"color": Color(0.30, 0.80, 1.0),
		"consumable": true,
		# One-shot deploy: the Alchemy recycle perk must NOT keep this in the slot. Only one
		# egg can incubate at a time, so a recycled egg would strand a dead slot until the
		# current incubation resolves (item_runtime_checklist §1.7).
		"no_recycle": true,
	}


func _build_life_elixir() -> Dictionary:
	return {
		"name": "life_elixir",
		"display_name": "오색약수",
		"type": "active",
		"effect": "life_elixir",
		"chance": 0.008,
		"duration": 0,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"gauge_gain": GAUGE_MAX,
		"gauge_max": GAUGE_MAX,
		"description": "오색약수를 마셔 기력을 최대치까지 충전합니다.",
		"icon_path": LIFE_ELIXIR_ICON_PATH,
		"color": Color(0.35, 0.82, 1.0),
		"consumable": true,
	}


func _build_ammo_box() -> Dictionary:
	return {
		"name": "ammo_box",
		"display_name": "탄약상자",
		"type": "active",
		"effect": "ammo_box",
		"chance": 0.0,
		"duration": 0,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "현재 선택한 대여 화기의 탄약을 보급합니다.",
		"icon_path": AMMO_BOX_ICON_PATH,
		"color": Color(0.72, 0.46, 0.24),
		"consumable": true,
		"supply_drop_only": true,
	}


func _build_doping_potion() -> Dictionary:
	return {
		"name": "doping_potion",
		"display_name": "도핑주사기",
		"type": "active",
		"effect": "doping_potion",
		"chance": 0.0,
		"duration": 480,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "일정 시간 호란의 화기의 연사와 위력을 강화합니다.",
		"icon_path": DOPING_POTION_ICON_PATH,
		"color": Color(1.0, 0.42, 0.22),
		"consumable": true,
		"head_leg_multiplier": 2.0,
		"fire_rate_multiplier": 0.5,
		"pistol_cooldown_frames": 30,
		"pistol_control_lock_frames": 9,
		"pistol_speed_multiplier": 1.2,
		"beretta_cooldown_frames": 15,
		"ak47_fire_interval_frames": 3,
		"bazooka_cooldown_frames": 60,
		"bazooka_control_lock_frames": 15,
		"supply_drop_only": true,
	}


func _build_vitamin_pill() -> Dictionary:
	return {
		"name": "vitamin_pill",
		"display_name": "경신단",
		"type": "active",
		"effect": "vitamin_pill",
		"chance": 0.012,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "경신단을 복용해 일정 시간 이동 속도를 증가시킵니다.",
		"icon_path": VITAMIN_PILL_ICON_PATH,
		"color": Color(0.24, 0.88, 0.78),
		"consumable": true,
	}


func _build_strange_vial() -> Dictionary:
	return {
		"name": "strange_vial",
		"display_name": "기묘한 약병",
		"type": "active",
		"effect": "strange_vial",
		"chance": 0.012,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "무작위로 몸집 크기와 이동 속도가 크게 변합니다.",
		"icon_path": STRANGE_VIAL_ICON_PATH,
		"color": Color(160.0 / 255.0, 90.0 / 255.0, 220.0 / 255.0),
		"consumable": true,
	}


func _build_aipill() -> Dictionary:
	return {
		"name": "aipill",
		"display_name": "신령환",
		"type": "active",
		"effect": "aipill",
		"chance": 0.006,
		"duration": 300,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "신령환을 복용해 호신령의 자동 가드를 활성화합니다. 가드할 때마다 기력이 줄고, 공을 쳐낼 때마다 공 속도가 8%씩 증가합니다(상한 없음).",
		"icon_path": AIPILL_ICON_PATH,
		# 호신령 빙의 연출이 금/주사 팔레트로 바뀌면서 HUD 슬롯·픽업 토스트
		# 강조색도 같이 옮긴다(구 시안은 사이버 글리치 시절의 잔재).
		"color": Color(0.900, 0.780, 0.440),
		"consumable": true,
	}


func _build_pandora_box() -> Dictionary:
	return {
		"name": "pandora_box",
		"display_name": "도깨비 보따리",
		"type": "active",
		"effect": "pandora_box",
		"chance": 0.003,
		"duration": 180,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "도깨비 보따리를 풀어 귀문을 엽니다. 3초 동안 중앙에서 액티브 아이템이 0.5~1초 간격으로 쏟아집니다.",
		"icon_path": PANDORA_BOX_ICON_PATH,
		"color": Color(0.66, 0.27, 0.76),
		"consumable": true,
	}


func _build_mystic_dice() -> Dictionary:
	return {
		"name": "mystic_dice",
		"display_name": "팔자윷",
		"type": "active",
		"effect": "mystic_dice",
		# Frozen PingFighter's Devil Dice used the same 0.005 field weight.
		"chance": 0.005,
		"duration": 0,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "윷가락을 던져 7가지 능력치가 각각 오르거나 내립니다. 결과는 이번 플레이 동안 누적되며, 최대 2회 다시 던질 수 있습니다.",
		"icon_path": MYSTIC_DICE_ICON_PATH,
		"color": Color(0.78, 0.56, 0.24),
		"consumable": true,
	}


func _build_grenade() -> Dictionary:
	return {
		"name": "grenade",
		"display_name": "폭화탄",
		"type": "active",
		"effect": "grenade",
		"chance": 0.018,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "화약을 채운 무쇠 폭화탄을 던져 폭발 범위 안의 보스를 기절시킵니다.",
		"icon_path": GRENADE_ICON_PATH,
		"color": Color(210.0 / 255.0, 76.0 / 255.0, 20.0 / 255.0),
		"consumable": true,
		"count": 1,
	}


func _build_flare() -> Dictionary:
	return {
		"name": "flare",
		"display_name": "환광탄",
		"type": "active",
		"effect": "flare",
		"chance": 0.020,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "환광탄을 던져 순간적인 환광으로 범위 안의 보스를 혼란 상태로 만듭니다.",
		"icon_path": FLARE_ICON_PATH,
		"color": Color(0.64, 0.86, 1.0),
		"consumable": true,
		"count": 1,
	}


func _build_tear_gas() -> Dictionary:
	return {
		"name": "tear_gas",
		"display_name": "최루탄",
		"type": "active",
		"effect": "tear_gas",
		"chance": 0.010,
		"duration": 960,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "최루탄을 던져 보스 스킬 쿨타임을 잠시 멈춥니다.",
		"icon_path": TEAR_GAS_ICON_PATH,
		"color": Color(150.0 / 255.0, 160.0 / 255.0, 145.0 / 255.0),
		"consumable": true,
		"count": 1,
	}


func _build_dynamite() -> Dictionary:
	return {
		"name": "dynamite",
		"display_name": "폭렬화통",
		"type": "active",
		"effect": "dynamite",
		"chance": 0.006,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "폭렬화통을 설치해 도화선이 다 타면 강력한 폭발을 일으킵니다.",
		"icon_path": DYNAMITE_ICON_PATH,
		"color": Color(0.92, 0.25, 0.10),
		"consumable": true,
		"count": 1,
	}


func _build_molotov() -> Dictionary:
	return {
		"name": "molotov",
		"display_name": "열화병",
		"type": "active",
		"effect": "molotov",
		"chance": 0.015,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "열화병을 던져 지속 피해를 주는 화염 지대를 만듭니다.",
		"icon_path": MOLOTOV_ICON_PATH,
		"color": Color(1.0, 100.0 / 255.0, 0.0),
		"consumable": true,
		"count": 1,
	}


func _build_stopwatch() -> Dictionary:
	return {
		"name": "stopwatch",
		"display_name": "요술 회중시계",
		"type": "active",
		"effect": "stopwatch",
		"chance": 0.006,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "요술 회중시계의 태엽을 멈춰 잠시 공과 전투의 흐름을 정지시킵니다.",
		"icon_path": STOPWATCH_ICON_PATH,
		"color": Color(0.15, 0.82, 0.93),
		"consumable": true,
	}


func _build_magnet_field() -> Dictionary:
	return {
		"name": "magnet_field",
		"display_name": "흡인진",
		"type": "active",
		"effect": "magnet_field",
		"chance": 0.007,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "흡인진을 펼쳐 일정 시간 공을 플레이어 쪽으로 끌어당깁니다.",
		"icon_path": MAGNET_FIELD_ICON_PATH,
		"color": Color(214.0 / 255.0, 158.0 / 255.0, 53.0 / 255.0),
		"consumable": true,
	}


func _build_long_boost() -> Dictionary:
	return {
		"name": "long_boost",
		"display_name": "거신단",
		"type": "active",
		"effect": "long_boost",
		"chance": 0.028,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "일정 시간 플레이어의 몸집이 크게 커집니다.",
		"icon_path": LONG_BOOST_ICON_PATH,
		"color": Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
		"consumable": true,
	}


func _build_regeneration_potion() -> Dictionary:
	return {
		"name": "regeneration_potion",
		"display_name": "원기탕",
		"type": "active",
		"effect": "regeneration_potion",
		"chance": 0.008,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "원기를 북돋아 초식 쿨타임과 활주 횟수를 즉시 회복합니다.",
		"icon_path": REGENERATION_POTION_ICON_PATH,
		"color": Color(1.0, 230.0 / 255.0, 80.0 / 255.0),
		"consumable": true,
	}


func _build_holy_barrier() -> Dictionary:
	return {
		"name": "holy_barrier",
		"display_name": "금강결계",
		"type": "active",
		"effect": "holy_barrier",
		"chance": 0.006,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "금강결계를 펼쳐 플레이어 뒤에서 공을 되받아칩니다.",
		"icon_path": HOLY_BARRIER_ICON_PATH,
		"color": Color(1.0, 245.0 / 255.0, 170.0 / 255.0),
		"consumable": true,
	}


func _build_dash_boost() -> Dictionary:
	return {
		"name": "dash_boost",
		"display_name": "축지부",
		"type": "active",
		"effect": "dash_boost",
		"chance": 0.005,
		"duration": 480,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "축지술로 일정 시간 활주 비용과 재충전 시간을 크게 줄입니다.",
		"icon_path": DASH_BOOST_ICON_PATH,
		"color": Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
		"consumable": true,
	}


func _build_wall() -> Dictionary:
	return {
		"name": "wall",
		"display_name": "토벽패",
		"type": "active",
		"effect": "wall",
		"chance": 0.035,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "부적의 힘으로 공을 막는 토벽을 세웁니다.",
		"icon_path": WALL_ICON_PATH,
		"color": Color(183.0 / 255.0, 126.0 / 255.0, 55.0 / 255.0),
		"consumable": true,
	}


func _build_trampoline() -> Dictionary:
	return {
		"name": "trampoline",
		"display_name": "널뛰기",
		"type": "active",
		"effect": "trampoline",
		"chance": 0.012,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "널뛰기를 설치해 떨어지는 공의 기세를 받아 더 강하게 되받아칩니다. 세 번 사용하면 부서집니다.",
		"icon_path": TRAMPOLINE_ICON_PATH,
		"color": Color(0.18, 0.78, 0.67),
		"consumable": true,
	}


func _build_campfire() -> Dictionary:
	return {
		"name": "campfire",
		"display_name": "모닥불",
		"type": "active",
		"effect": "campfire",
		"chance": 0.012,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "모닥불을 설치합니다. 반경 80px 안에 있으면 활주 재충전과 초식 쿨타임 회복 속도가 80% 증가하고, 기력을 초당 30 회복합니다. 공에 한 번 맞으면 공을 반사하며 부서지고, 플레이어가 대쉬로 통과해도 부서집니다.",
		"icon_path": CAMPFIRE_ICON_PATH,
		"color": Color(1.0, 0.46, 0.12),
		"consumable": true,
	}


func _build_boomerang() -> Dictionary:
	return {
		"name": "boomerang",
		"display_name": "부메랑",
		"type": "active",
		"effect": "boomerang",
		"chance": 0.015,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "보스를 향해 부메랑을 던지고, 돌아오면 다시 회수합니다.",
		"icon_path": BOOMERANG_ICON_PATH,
		"color": Color(200.0 / 255.0, 130.0 / 255.0, 60.0 / 255.0),
		"consumable": true,
		# Returning the projectile already restores this item. Keeping it in the
		# slot through 환보결 would stack two independent recovery paths.
		"no_recycle": true,
		"count": 1,
	}


func _build_banana() -> Dictionary:
	return {
		"name": "banana",
		"display_name": "바나나",
		"type": "active",
		"effect": "banana",
		"chance": 0.012,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "보스가 밟으면 미끄러지는 바나나 함정을 던집니다.",
		"icon_path": BANANA_ICON_PATH,
		"color": Color(1.0, 220.0 / 255.0, 50.0 / 255.0),
		"consumable": true,
		"count": 1,
	}


func _build_soap() -> Dictionary:
	return {
		"name": "soap",
		"display_name": "비누",
		"type": "active",
		"effect": "soap",
		"chance": 0.010,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "보스가 밟으면 미끄러지는 비누를 던집니다.",
		"icon_path": SOAP_ICON_PATH,
		"color": Color(140.0 / 255.0, 200.0 / 255.0, 240.0 / 255.0),
		"consumable": true,
		"count": 1,
	}


func _build_spider_mine() -> Dictionary:
	return {
		"name": "spider_mine",
		"display_name": "귀주뢰",
		"type": "active",
		"effect": "spider_mine",
		"chance": 0.007,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "귀문 부적을 새긴 귀주뢰가 벽을 타고 올라 보스 곁에 박힌 뒤 폭발해 이동을 늦춥니다.",
		"icon_path": SPIDER_MINE_ICON_PATH,
		"color": Color(210.0 / 255.0, 64.0 / 255.0, 38.0 / 255.0),
		"consumable": true,
		"count": 1,
	}


func _build_elixir_of_mastery() -> Dictionary:
	return {
		"name": "elixir_of_mastery",
		"display_name": "대성영단",
		"korean_name": "대성영단",
		"type": "active",
		"rarity": "mythic",
		"effect": "elixir_of_mastery",
		# Raw weight for active-derived pools. The production field picker classifies
		# this active mythic into its 1% base mythic lane, keeping ordinary drops rare.
		"chance": DAESEONG_YEONGDAN_SPAWN_WEIGHT,
		"duration": 0,
		"cooldown_msec": 0,
		"icon_path": ELIXIR_OF_MASTERY_ICON_PATH,
		"color": Color(0.93, 0.61, 0.12),
		"consumable": true,
		"mythic_active": true,
		"description": "대성영단을 복용하면 보유 중인 무공 하나를 무작위로 골라 즉시 극성에 도달시킵니다. 사용 후 소모됩니다.",
	}


func _build_milk_bottle() -> Dictionary:
	return {
		"name": "milk_bottle",
		"display_name": "우유병",
		"type": "active",
		"effect": "milk_bottle",
		"chance": 0.0,
		"duration": 0,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"icon_path": MILK_BOTTLE_ICON_PATH,
		"field_icon_path": MILK_BOTTLE_FIELD_ICON_PATH,
		"color": Color(0.58, 1.0, 0.95),
		"consumable": true,
		"stationary_field_item": true,
		"dash_destroy_on_player_contact": true,
		"paddle_scale_multiplier": 1.20,
		"stage_persistent": true,
		"lingpet_generated_only": true,
		"description": "사용 시 스테이지 종료까지 플레이어 몸집과 이미지 크기가 20% 증가합니다.",
	}


func _build_cheese(item_name: String, display_name: String, gauge_gain: float, paddle_scale_multiplier: float, icon_path: String, item_color: Color) -> Dictionary:
	# Cheese restores the gauge AND carries the milk-bottle paddle/character size buff.
	# Each cheese maps 1:1 to a milk-production level (cheddar=Lv.3, camembert=Lv.4,
	# emmental=Lv.5), so its size step matches that level's milk-bottle scale.
	var scale_percent := int(round(maxf(0.0, paddle_scale_multiplier - 1.0) * 100.0))
	return {
		"name": item_name,
		"display_name": display_name,
		"type": "active",
		"effect": "cheese",
		"chance": 0.0,
		"duration": 0,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"icon_path": icon_path,
		"field_icon_path": icon_path,
		"color": item_color,
		"consumable": true,
		"stationary_field_item": true,
		"dash_destroy_on_player_contact": true,
		"paddle_scale_multiplier": paddle_scale_multiplier,
		"paddle_scale_percent": scale_percent,
		"stage_persistent": true,
		"lingpet_generated_only": true,
		"gauge_gain": gauge_gain,
		"gauge_max": GAUGE_MAX,
		"description": "사용 시 왼쪽 파란 기력 구슬을 즉시 %d 회복하고, 스테이지 종료까지 플레이어 몸집과 이미지 크기가 %d%% 증가합니다." % [int(round(gauge_gain)), scale_percent],
	}
