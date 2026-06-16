extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const DEFAULT_COOLDOWN_MSEC := 7000
const GAUGE_MAX := 500.0
const GAUGE_CHARGE_AMOUNT := 220.0

const AIPILL_ICON_PATH := "res://assets/sprites/items/aipill.png"
const GAUGE_CHARGE_ICON_PATH := "res://assets/sprites/items/gauge_200.png"
const LIFE_ELIXIR_ICON_PATH := "res://assets/sprites/items/life_elixir.png"
const AMMO_BOX_ICON_PATH := "res://assets/sprites/items/ammo_box.png"
const DOPING_POTION_ICON_PATH := "res://assets/sprites/items/doping_potion.png"
const VITAMIN_PILL_ICON_PATH := "res://assets/sprites/items/vitamin_pill.png"
const STRANGE_VIAL_ICON_PATH := "res://assets/sprites/items/strange_vial.png"
const PANDORA_BOX_ICON_PATH := "res://assets/sprites/items/pandora_box.png"
const GRENADE_ICON_PATH := "res://assets/sprites/items/grenade.png"
const FLARE_ICON_PATH := "res://assets/sprites/items/flare.png"
const TEAR_GAS_ICON_PATH := "res://assets/sprites/items/smoke_grenade.png"
const DYNAMITE_ICON_PATH := "res://assets/sprites/items/dynamite.png"
const MOLOTOV_ICON_PATH := "res://assets/sprites/items/molotov.png"
const STOPWATCH_ICON_PATH := "res://assets/sprites/items/stopwatch_icon.png"
const MAGNET_FIELD_ICON_PATH := "res://assets/sprites/items/magnet_field.png"
const LONG_BOOST_ICON_PATH := "res://assets/sprites/items/long_boost_icon.png"
const REGENERATION_POTION_ICON_PATH := "res://assets/sprites/items/regeneration_potion.png"
const HOLY_BARRIER_ICON_PATH := "res://assets/sprites/items/holy_barrier.png"
const DASH_BOOST_ICON_PATH := "res://assets/sprites/items/dash_boost.png"
const WALL_ICON_PATH := "res://assets/sprites/items/wall.png"
const TRAMPOLINE_ICON_PATH := "res://assets/sprites/items/trampoline.png"
const BOOMERANG_ICON_PATH := "res://assets/sprites/items/boomerang.png"
const BOOMERANG_METAL_ICON_PATH := "res://assets/sprites/items/boomerang_metal.png"
const BANANA_ICON_PATH := "res://assets/sprites/items/banana.png"
const SOAP_ICON_PATH := "res://assets/sprites/items/soap.png"
const SPIDER_MINE_ICON_PATH := "res://assets/sprites/items/spider_mine.png"
const ELIXIR_OF_MASTERY_ICON_PATH := "res://assets/sprites/items/elixir_of_mastery.png"
const MILK_BOTTLE_ICON_PATH := "res://assets/sprites/items/milk_bottle_icon_imagegen_v1.png"
const MILK_BOTTLE_FIELD_ICON_PATH := "res://assets/sprites/items/milk_bottle_field_imagegen_v1.png"
const LINGPET_FEED_ICON_PATH := "res://assets/sprites/items/lingpet_feed_icon.png"

const FIELD_SPAWN_ORDER := [
	"gauge_charge",
	"lingpet_feed",
	"life_elixir",
	"vitamin_pill",
	"strange_vial",
	"aipill",
	"pandora_box",
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
	"boomerang",
	"banana",
	"soap",
	"spider_mine",
]


func build_item_by_name(item_name: String) -> Dictionary:
	var item_data: Dictionary = {}
	match item_name:
		"gauge_charge":
			item_data = _build_gauge_charge()
		"lingpet_feed":
			item_data = _build_lingpet_feed()
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
	if item_data.is_empty():
		return {}
	return LanguageSettings.localize_item_data(item_data)


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
		"display_name": "에너지드링크",
		"type": "active",
		"effect": "gauge_charge",
		"chance": 0.042,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"gauge_gain": GAUGE_CHARGE_AMOUNT,
		"gauge_max": GAUGE_MAX,
		"description": "게이지를 220 충전합니다.",
		"icon_path": GAUGE_CHARGE_ICON_PATH,
		"color": Color(1.0, 100.0 / 255.0, 1.0),
		"consumable": true,
	}


func _build_lingpet_feed() -> Dictionary:
	return {
		"name": "lingpet_feed",
		"display_name": "링펫 먹이",
		"type": "active",
		"effect": "lingpet_feed",
		"chance": 0.010,
		"duration": 0,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"feed_amount": 35.0,
		"description": "활성 링펫에게 먹이를 줘 친밀도를 35 올립니다. 한 런에 3번, 친밀도 Lv.15까지만 효과가 있습니다.",
		"icon_path": LINGPET_FEED_ICON_PATH,
		"color": Color(0.45, 0.95, 0.88),
		"consumable": true,
	}


func _build_life_elixir() -> Dictionary:
	return {
		"name": "life_elixir",
		"display_name": "생명수",
		"type": "active",
		"effect": "life_elixir",
		"chance": 0.008,
		"duration": 0,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"gauge_gain": GAUGE_MAX,
		"gauge_max": GAUGE_MAX,
		"description": "게이지를 최대치까지 충전합니다.",
		"icon_path": LIFE_ELIXIR_ICON_PATH,
		"color": Color(200.0 / 255.0, 100.0 / 255.0, 1.0),
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
		"description": "일정 시간 코만도 화기의 연사와 위력을 강화합니다.",
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
		"display_name": "비타민드링크",
		"type": "active",
		"effect": "vitamin_pill",
		"chance": 0.012,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "일정 시간 이동 속도가 증가합니다.",
		"icon_path": VITAMIN_PILL_ICON_PATH,
		"color": Color(80.0 / 255.0, 170.0 / 255.0, 1.0),
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
		"description": "무작위로 패들 크기와 이동 속도가 크게 변합니다.",
		"icon_path": STRANGE_VIAL_ICON_PATH,
		"color": Color(160.0 / 255.0, 90.0 / 255.0, 220.0 / 255.0),
		"consumable": true,
	}


func _build_aipill() -> Dictionary:
	return {
		"name": "aipill",
		"display_name": "AI 알약",
		"type": "active",
		"effect": "aipill",
		"chance": 0.006,
		"duration": 300,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "자동 가드가 활성화되며, 가드할 때마다 게이지가 줄어듭니다.",
		"icon_path": AIPILL_ICON_PATH,
		"color": Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
		"consumable": true,
	}


func _build_pandora_box() -> Dictionary:
	return {
		"name": "pandora_box",
		"display_name": "판도라의 상자",
		"type": "active",
		"effect": "pandora_box",
		"chance": 0.003,
		"duration": 180,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "차원문을 열어 필드에 액티브 아이템을 소환합니다.",
		"icon_path": PANDORA_BOX_ICON_PATH,
		"color": Color(1.0, 0.0, 1.0),
		"consumable": true,
	}


func _build_grenade() -> Dictionary:
	return {
		"name": "grenade",
		"display_name": "수류탄",
		"type": "active",
		"effect": "grenade",
		"chance": 0.018,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "수류탄을 던져 폭발 범위 안의 보스를 기절시킵니다.",
		"icon_path": GRENADE_ICON_PATH,
		"color": Color(80.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0),
		"consumable": true,
		"count": 1,
	}


func _build_flare() -> Dictionary:
	return {
		"name": "flare",
		"display_name": "조명탄",
		"type": "active",
		"effect": "flare",
		"chance": 0.020,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "조명탄을 던져 범위 안의 보스를 혼란 상태로 만듭니다.",
		"icon_path": FLARE_ICON_PATH,
		"color": Color(1.0, 1.0, 200.0 / 255.0),
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
		"display_name": "다이너마이트",
		"type": "active",
		"effect": "dynamite",
		"chance": 0.006,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "다이너마이트를 설치해 카운트다운 후 강한 폭발을 일으킵니다.",
		"icon_path": DYNAMITE_ICON_PATH,
		"color": Color(200.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0),
		"consumable": true,
		"count": 1,
	}


func _build_molotov() -> Dictionary:
	return {
		"name": "molotov",
		"display_name": "화염병",
		"type": "active",
		"effect": "molotov",
		"chance": 0.015,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "화염병을 던져 지속 피해를 주는 화염 지대를 만듭니다.",
		"icon_path": MOLOTOV_ICON_PATH,
		"color": Color(1.0, 100.0 / 255.0, 0.0),
		"consumable": true,
		"count": 1,
	}


func _build_stopwatch() -> Dictionary:
	return {
		"name": "stopwatch",
		"display_name": "스탑워치",
		"type": "active",
		"effect": "stopwatch",
		"chance": 0.006,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "잠시 시간을 멈춰 공과 전투 흐름을 정지시킵니다.",
		"icon_path": STOPWATCH_ICON_PATH,
		"color": Color(180.0 / 255.0, 140.0 / 255.0, 90.0 / 255.0),
		"consumable": true,
	}


func _build_magnet_field() -> Dictionary:
	return {
		"name": "magnet_field",
		"display_name": "자기장",
		"type": "active",
		"effect": "magnet_field",
		"chance": 0.007,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "일정 시간 공을 플레이어 패들 쪽으로 끌어당깁니다.",
		"icon_path": MAGNET_FIELD_ICON_PATH,
		"color": Color(100.0 / 255.0, 120.0 / 255.0, 1.0),
		"consumable": true,
	}


func _build_long_boost() -> Dictionary:
	return {
		"name": "long_boost",
		"display_name": "거대화포션",
		"type": "active",
		"effect": "long_boost",
		"chance": 0.028,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "일정 시간 플레이어 패들이 크게 커집니다.",
		"icon_path": LONG_BOOST_ICON_PATH,
		"color": Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
		"consumable": true,
	}


func _build_regeneration_potion() -> Dictionary:
	return {
		"name": "regeneration_potion",
		"display_name": "재생물약",
		"type": "active",
		"effect": "regeneration_potion",
		"chance": 0.008,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "스킬 쿨타임과 대쉬 토큰을 즉시 회복합니다.",
		"icon_path": REGENERATION_POTION_ICON_PATH,
		"color": Color(1.0, 230.0 / 255.0, 80.0 / 255.0),
		"consumable": true,
	}


func _build_holy_barrier() -> Dictionary:
	return {
		"name": "holy_barrier",
		"display_name": "홀리베리어",
		"type": "active",
		"effect": "holy_barrier",
		"chance": 0.006,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "플레이어 뒤쪽에 공을 튕겨내는 방벽을 펼칩니다.",
		"icon_path": HOLY_BARRIER_ICON_PATH,
		"color": Color(1.0, 245.0 / 255.0, 170.0 / 255.0),
		"consumable": true,
	}


func _build_dash_boost() -> Dictionary:
	return {
		"name": "dash_boost",
		"display_name": "대쉬부스트",
		"type": "active",
		"effect": "dash_boost",
		"chance": 0.005,
		"duration": 480,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "일정 시간 대쉬 비용과 쿨타임을 크게 줄입니다.",
		"icon_path": DASH_BOOST_ICON_PATH,
		"color": Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
		"consumable": true,
	}


func _build_wall() -> Dictionary:
	return {
		"name": "wall",
		"display_name": "벽돌",
		"type": "active",
		"effect": "wall",
		"chance": 0.035,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "공을 막는 방어용 벽돌을 설치합니다.",
		"icon_path": WALL_ICON_PATH,
		"color": Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0),
		"consumable": true,
	}


func _build_trampoline() -> Dictionary:
	return {
		"name": "trampoline",
		"display_name": "트램펄린",
		"type": "active",
		"effect": "trampoline",
		"chance": 0.012,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "공을 띠용 튕겨 올리는 트램펄린을 설치합니다. 3회 튕기면 사라집니다.",
		"icon_path": TRAMPOLINE_ICON_PATH,
		"color": Color(80.0 / 255.0, 210.0 / 255.0, 1.0),
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
		"display_name": "스파이더지뢰",
		"type": "active",
		"effect": "spider_mine",
		"chance": 0.007,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"description": "벽을 타고 이동하는 지뢰를 전개해 보스를 느리게 합니다.",
		"icon_path": SPIDER_MINE_ICON_PATH,
		"color": Color(120.0 / 255.0, 90.0 / 255.0, 160.0 / 255.0),
		"consumable": true,
		"count": 1,
	}


func _build_elixir_of_mastery() -> Dictionary:
	return {
		"name": "elixir_of_mastery",
		"display_name": "엘릭서 오브 마스터리",
		"korean_name": "엘릭서 오브 마스터리",
		"type": "active",
		"rarity": "mythic",
		"effect": "elixir_of_mastery",
		"chance": 0.0,
		"duration": 0,
		"cooldown_msec": 0,
		"icon_path": ELIXIR_OF_MASTERY_ICON_PATH,
		"color": Color(0.47, 0.2, 0.78),
		"consumable": true,
		"mythic_active": true,
		"description": "보유 중인 퍽 하나를 무작위로 골라 즉시 Lv.5로 만듭니다.",
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
		"description": "사용 시 스테이지 종료까지 플레이어 패들과 이미지 크기가 20% 증가합니다.",
	}
