extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SkillOrbTextureNormalizer := preload("res://scripts/resources/skill_orb_texture_normalizer.gd")

const PERK_ICON_PATHS := {
	"mystic_dice": "res://assets/sprites/perks/mystic_dice_perk_icon.png",
	"dash_lightweight": "res://assets/sprites/perks/dash_lightweight_perk_icon.png",
	"dash_module_control": "res://assets/sprites/perks/dash_module_control_perk_icon.png",
	"dash_jump": "res://assets/sprites/perks/dash_jump_perk_icon.png",
	"dash_amplification": "res://assets/sprites/perks/dash_amplification_perk_icon.png",
	"dash_acceleration": "res://assets/sprites/perks/dash_acceleration_perk_icon.png",
	"item_luck": "res://assets/sprites/perks/item_luck_perk_icon.png",
	"item_cooldown_mastery": "res://assets/sprites/perks/item_cooldown_mastery_perk_icon.png",
	"item_gauge_mastery": "res://assets/sprites/perks/item_gauge_mastery_perk_icon.png",
	"item_bag_expansion": "res://assets/sprites/perks/item_bag_expansion_perk_icon.png",
	"item_caffeine": "res://assets/sprites/perks/item_caffeine_perk_icon.png",
	"item_polish": "res://assets/sprites/perks/item_polish_perk_icon.png",
	"item_recycle": "res://assets/sprites/perks/item_recycle_perk_icon.png",
	"common_swiftness": "res://assets/sprites/perks/common_swiftness_perk_icon.png",
	"common_expansion": "res://assets/sprites/perks/common_expansion_perk_icon.png",
	"common_bulk_up": "res://assets/sprites/perks/common_bulk_up_perk_icon.png",
	"common_training": "res://assets/sprites/perks/common_training_perk_icon.png",
	"common_refresh": "res://assets/sprites/perks/common_refresh_perk_icon.png",
	"perk_boost_charge": "res://assets/sprites/perks/perk_boost_charge_perk_icon_v2.png",
	"perk_laurel_shield": "res://assets/sprites/perks/perk_laurel_shield_perk_icon.png",
	"downtown_treasure_map": "res://assets/sprites/perks/downtown_treasure_map_perk_icon.png",
	"downtown_gamble": "res://assets/sprites/perks/downtown_gamble_perk_icon.png",
	"downtown_bargain": "res://assets/sprites/perks/downtown_bargain_perk_icon.png",
	"convert_to_gold": "res://assets/sprites/perks/convert_to_gold_perk_icon.png",
	"instant_gauge_full": "res://assets/sprites/perks/instant_gauge_full_perk_icon.png",
	"instant_dimension_gate": "res://assets/sprites/perks/instant_dimension_gate_perk_icon.png",
	"instant_treasure_hunt": "res://assets/sprites/perks/instant_treasure_hunt_perk_icon.png",
	"instant_monkey_blessing": "res://assets/sprites/perks/instant_monkey_blessing_perk_icon.png",
	"lingpet_affinity_chip": "res://assets/sprites/perks/lingpet_affinity_chip_perk_icon.png",
	"lingpet_ring_core_upgrade": "res://assets/sprites/perks/lingpet_ring_core_standard_perk_icon.png",
	"lingpet_ring_core_upgrade_tier_1": "res://assets/sprites/perks/lingpet_ring_core_standard_perk_icon.png",
	"lingpet_ring_core_upgrade_tier_2": "res://assets/sprites/perks/lingpet_ring_core_boost_perk_icon.png",
	"lingpet_ring_core_upgrade_tier_3": "res://assets/sprites/perks/lingpet_ring_core_hyper_perk_icon.png",
	"lingpet_ring_core_upgrade_tier_4": "res://assets/sprites/perks/lingpet_ring_core_overdrive_perk_icon.png",
	"lingpet_ring_core_upgrade_tier_5": "res://assets/sprites/perks/lingpet_ring_core_ultimate_perk_icon.png",
	"lingpet_ring_core_upgrade_tier_6": "res://assets/sprites/perks/lingpet_ring_core_zenith_perk_icon.png",
	"dash_spirit": "res://assets/sprites/perks/smasher_dash_spirit_perk_icon.png",
	"extension_gear": "res://assets/sprites/perks/smasher_extension_gear_perk_icon.png",
	"combo_amplifier_chip": "res://assets/sprites/perks/smasher_combo_amplifier_chip_perk_icon.png",
	"jetpack_enhance": "res://assets/sprites/perks/viper_jetpack_enhance_perk_icon.png",
	"kick_enhance": "res://assets/sprites/perks/viper_kick_enhance_perk_icon.png",
	"blade_amp": "res://assets/sprites/perks/viper_blade_amp_perk_icon.png",
	"four_poisons": "res://assets/sprites/perks/viper_four_poisons_perk_icon.png",
	"pistol_enhance": "res://assets/sprites/perks/soldier_pistol_enhance_perk_icon.png",
	"star_detector": "res://assets/sprites/perks/star_detector_perk_icon.png",
	"adversity_armor": "res://assets/sprites/perks/adversity_armor_perk_icon.png",
	"reinforced_boomerang_gauntlet": "res://assets/sprites/perks/reinforced_boomerang_gauntlet_perk_icon.png",
	"sensor": "res://assets/sprites/perks/sensor_perk_icon.png",
	"gravitybelt": "res://assets/sprites/perks/gravitybelt_perk_icon.png",
	"dowsing_pendulum": "res://assets/sprites/perks/dowsing_pendulum_perk_icon.png",
	"dowsing_goggles": "res://assets/sprites/perks/dowsing_goggles_perk_icon.png",
	"chargebag": "res://assets/sprites/perks/chargebag_perk_icon.png",
	"battery": "res://assets/sprites/perks/battery_perk_icon.png",
	"revival": "res://assets/sprites/perks/revival_perk_icon.png",
	"master": "res://assets/sprites/perks/master_perk_icon.png",
	"gold_digger": "res://assets/sprites/perks/gold_digger_perk_icon.png",
	"lucky_coin": "res://assets/sprites/perks/lucky_coin_perk_icon.png",
	"shrapnel_armor": "res://assets/sprites/perks/shrapnel_armor_perk_icon.png",
	"fuel_pouch": "res://assets/sprites/perks/fuel_pouch_perk_icon.png",
	"bluetooth_ring": "res://assets/sprites/perks/bluetooth_ring_perk_icon.png",
	"foul_whistle": "res://assets/sprites/perks/foul_whistle_perk_icon.png",
	"smartphone": "res://assets/sprites/perks/smartphone_perk_icon.png",
	"neural_helmet": "res://assets/sprites/perks/neural_helmet_perk_icon.png",
	"commando_arm": "res://assets/sprites/perks/commando_arm_perk_icon.png",
	"rainbow_fur_glove": "res://assets/sprites/perks/rainbow_fur_glove_perk_icon.png",
	"knee_pads": "res://assets/sprites/perks/knee_pads_perk_icon.png",
	"soul_burst": "res://assets/sprites/perks/soul_burst_perk_icon.png",
	"bulletproof_hat": "res://assets/sprites/perks/bulletproof_hat_perk_icon.png",
	"spiked_helmet": "res://assets/sprites/perks/spiked_helmet_perk_icon.png",
	"venom_mist_gauntlet": "res://assets/sprites/perks/venom_mist_gauntlet_perk_icon.png",
	"speedgear": "res://assets/sprites/perks/speedgear_perk_icon.png",
	"sage_ring": "res://assets/sprites/perks/sage_ring_perk_icon.png",
	"pandora_legacy": "res://assets/sprites/perks/pandora_legacy_perk_icon.png",
	"ragnarok_hammer": "res://assets/sprites/perks/ragnarok_hammer_perk_icon.png",
	"transcendent_crown": "res://assets/sprites/perks/transcendent_crown_perk_icon.png",
	"odins_eye": "res://assets/sprites/perks/odins_eye_perk_icon.png",
	"heavenly_cape": "res://assets/sprites/perks/heavenly_cape_perk_icon.png",
	"baal_boots": "res://assets/sprites/perks/baal_boots_perk_icon.png",
	"megingjord": "res://assets/sprites/perks/megingjord_perk_icon.png",
	"hermes_shoes": "res://assets/sprites/perks/hermes_shoes_perk_icon.png",
	"horn_strawberry_mask": "res://assets/sprites/perks/horn_strawberry_mask_perk_icon.png",
	"poseidon_trident": "res://assets/sprites/perks/poseidon_trident_perk_icon.png",
	"sacred_laurel": "res://assets/sprites/perks/sacred_laurel_perk_icon.png",
	"celestial_armor": "res://assets/sprites/perks/celestial_armor_perk_icon.png",
	"angel_blessing": "res://assets/sprites/perks/angel_blessing_perk_icon.png",
}

# 융합 제안 카드 아트: 명시 PNG 경로 테이블(공유 텍스처 캐시 진입).
const FUSION_OFFER_ICON_PATHS := {
	"perk_fusion": "res://assets/sprites/perks/perk_fusion_offer_0.png",
	"perk_fusion_0": "res://assets/sprites/perks/perk_fusion_offer_0.png",
	"perk_fusion_1": "res://assets/sprites/perks/perk_fusion_offer_1.png",
	"perk_fusion_2": "res://assets/sprites/perks/perk_fusion_offer_2.png",
	"perk_fusion_3": "res://assets/sprites/perks/perk_fusion_offer_3.png",
	"perk_fusion_4": "res://assets/sprites/perks/perk_fusion_offer_4.png",
}
const FUSION_PAIR_KEY_PREFIX := "perk_fusion_pair:"
const FUSION_PAIR_DEFAULT_SIZE := Vector2(64.0, 64.0)
const PerkFusionIconKey := preload("res://scripts/characters/perk_fusion_icon_key.gd")

const PERK_SHEET_PATHS := {
	"common_refresh": "res://assets/sprites/perks/common_refresh_perk_icon_sheet.png",
	"instant_gauge_full": "res://assets/sprites/perks/instant_gauge_full_perk_icon_sheet.png",
	"instant_dimension_gate": "res://assets/sprites/perks/instant_dimension_gate_perk_icon_sheet.png",
	"instant_treasure_hunt": "res://assets/sprites/perks/instant_treasure_hunt_perk_icon_sheet.png",
	"instant_monkey_blessing": "res://assets/sprites/perks/instant_monkey_blessing_perk_icon_sheet.png",
	"pandora_legacy": "res://assets/sprites/perks/pandora_legacy_perk_icon_sheet.png",
	"ragnarok_hammer": "res://assets/sprites/perks/ragnarok_hammer_perk_icon_sheet.png",
	"transcendent_crown": "res://assets/sprites/perks/transcendent_crown_perk_icon_sheet.png",
	"odins_eye": "res://assets/sprites/perks/odins_eye_perk_icon_sheet.png",
	"heavenly_cape": "res://assets/sprites/perks/heavenly_cape_perk_icon_sheet.png",
	"baal_boots": "res://assets/sprites/perks/baal_boots_perk_icon_sheet.png",
	"megingjord": "res://assets/sprites/perks/megingjord_perk_icon_sheet.png",
	"hermes_shoes": "res://assets/sprites/perks/hermes_shoes_perk_icon_sheet.png",
	"horn_strawberry_mask": "res://assets/sprites/perks/horn_strawberry_mask_perk_icon_sheet.png",
	"poseidon_trident": "res://assets/sprites/perks/poseidon_trident_perk_icon_sheet.png",
	"sacred_laurel": "res://assets/sprites/perks/sacred_laurel_perk_icon_sheet.png",
	"celestial_armor": "res://assets/sprites/perks/celestial_armor_perk_icon_sheet.png",
	"angel_blessing": "res://assets/sprites/perks/angel_blessing_perk_icon_sheet.png",
}

const SKILL_ICON_PATHS := {
	"drive": "res://assets/sprites/skills/smasher_drive_skill_orb.png",
	"power_smashing": "res://assets/sprites/skills/smasher_power_smashing_skill_orb.png",
	"plasma": "res://assets/sprites/skills/smasher_plasma_skill_orb.png",
	"recovery": "res://assets/sprites/skills/smasher_recovery_skill_orb.png",
	"cleanse": "res://assets/sprites/skills/smasher_cleanse_skill_orb.png",
	"shield_kiting": "res://assets/sprites/skills/smasher_shield_kiting_skill_orb.png",
	"magnum_grip": "res://assets/sprites/skills/smasher_magnum_grip_skill_orb.png",
	"ghost_shot": "res://assets/sprites/skills/smasher_ghost_shot_skill_orb.png",
	"warp_gate": "res://assets/sprites/skills/smasher_warp_gate_skill_orb.png",
	"smasher_wheel": "res://assets/sprites/skills/smasher_wheel_skill_orb.png",
	"shadow_step": "res://assets/sprites/skills/viper_shadow_step_skill_orb.png",
	"blade_rush": "res://assets/sprites/skills/viper_blade_rush_skill_orb.png",
	"nerve_strike": "res://assets/sprites/skills/viper_nerve_strike_skill_orb.png",
	"dive_strike": "res://assets/sprites/skills/viper_emp_strike_skill_orb.png",
	"marshal_kick": "res://assets/sprites/skills/viper_marshal_kick_skill_orb.png",
	"phantom_kick": "res://assets/sprites/skills/viper_phantom_kick_skill_orb.png",
	"dark_blade": "res://assets/sprites/skills/viper_dark_blade_skill_orb.png",
	"chaos_spear": "res://assets/sprites/skills/viper_chaos_spear_skill_orb.png",
	"core_flip": "res://assets/sprites/skills/viper_core_flip_skill_orb.png",
	"dual_glitch": "res://assets/sprites/skills/viper_dual_glitch_skill_orb.png",
	"ignition_aura": "res://assets/sprites/skills/viper_ignition_aura_skill_orb.png",
	"supply_drop": "res://assets/sprites/skills/commando_supply_drop_skill_orb.png",
	"emergency_supply": "res://assets/sprites/skills/commando_emergency_supply_skill_orb.png",
	"commando_pistol": "res://assets/sprites/skills/commando_pistol_skill_orb.png",
	"net_gun": "res://assets/sprites/skills/commando_net_gun_skill_orb.png",
	"fire_support": "res://assets/sprites/skills/commando_fire_support_skill_orb.png",
	"bowling_trap": "res://assets/sprites/skills/commando_bowling_trap_skill_orb.png",
	"suicide_drone": "res://assets/sprites/skills/commando_suicide_drone_skill_orb.png",
	"bazooka": "res://assets/sprites/skills/commando_bazooka_skill_orb.png",
	"ak47": "res://assets/sprites/skills/commando_ak47_skill_orb.png",
}

# 비급 획득 카드 전용 표지. 전투 중 장착 초식은 SKILL_ICON_PATHS의
# 즉시 판독 가능한 술법 인장을 유지하고, 아래에 명시한 획득 카드 ID만
# 책 표지를 쓴다. 전용 표지가 없으면 UNLOCK_ALIASES의 초식 인장으로 폴백한다.
const MANUAL_ICON_PATHS := {
	"unlock_nerve_strike": "res://assets/sprites/perks/viper_dokyeong_jeolmaek_manual_icon.png",
	"unlock_dive_strike": "res://assets/sprites/perks/viper_cheonroe_jingak_manual_icon.png",
	"unlock_chaos_spear": "res://assets/sprites/perks/viper_honcheon_heukchang_manual_icon.png",
	"unlock_dual_glitch": "res://assets/sprites/perks/viper_ssangyeong_bunsin_manual_icon.png",
	"unlock_ignition_aura": "res://assets/sprites/perks/viper_yeomhwa_gaemaek_manual_icon.png",
	"double_marshal_kick": "res://assets/sprites/perks/viper_hwanyeong_yeongak_manual_icon.png",
	"core_flip": "res://assets/sprites/perks/viper_hwarang_bicheongak_manual_icon.png",
	"dark_blade": "res://assets/sprites/perks/viper_hyeolyeong_cham_manual_icon.png",
}

const UNLOCK_ALIASES := {
	"unlock_plasma": "plasma",
	"unlock_recovery_skill": "recovery",
	"unlock_cleanse": "cleanse",
	"unlock_shield_kiting": "shield_kiting",
	"unlock_magnum_grip": "magnum_grip",
	"unlock_ghost_shot": "ghost_shot",
	"unlock_warp_gate": "warp_gate",
	"unlock_smasher_wheel": "smasher_wheel",
	"unlock_smasher_overdrive": "smasher_overdrive",
	"unlock_nerve_strike": "nerve_strike",
	"unlock_dive_strike": "dive_strike",
	"unlock_chaos_spear": "chaos_spear",
	"unlock_dual_glitch": "dual_glitch",
	"unlock_ignition_aura": "ignition_aura",
	"double_marshal_kick": "phantom_kick",
	"soldier_unlock_net_gun": "net_gun",
	"soldier_unlock_fire_support": "fire_support",
	"soldier_unlock_bowling_trap": "bowling_trap",
	"soldier_unlock_suicide_drone": "suicide_drone",
	"soldier_unlock_bazooka": "bazooka",
	"soldier_unlock_ak47": "ak47",
	"soldier_pistol_perk": "commando_pistol",
}

const COMMANDO_UNLOCK_BADGE_IDS := {
	"soldier_unlock_net_gun": true,
	"soldier_unlock_fire_support": true,
	"soldier_unlock_bowling_trap": true,
	"soldier_unlock_suicide_drone": true,
	"soldier_unlock_bazooka": true,
	"soldier_unlock_ak47": true,
	"soldier_pistol_perk": true,
}

const DRAW_SCALE := {
	"dash_module_control": 1.08,
	"dash_lightweight": 1.07,
	"dash_acceleration": 1.08,
	"perk_boost_charge": 1.07,
	"perk_laurel_shield": 1.06,
	"dash_spirit": 1.06,
	"jetpack_enhance": 1.06,
	"kick_enhance": 1.06,
	"blade_amp": 1.06,
	"four_poisons": 1.06,
	"pistol_enhance": 1.06,
	"angel_blessing": 0.96,
}

const PREWARM_ASSET_BATCH_SIZE := 1

var _texture_cache: Dictionary = {}
var _sheet_cache: Dictionary = {}
var _static_source_cache: Dictionary = {}
var _sheet_region_cache: Dictionary = {}
var _prewarm_asset_jobs: Array = []
var _prewarm_asset_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step(256):
		pass


func prewarm_assets_step(batch_size: int = PREWARM_ASSET_BATCH_SIZE) -> bool:
	if _prewarm_asset_jobs.is_empty():
		_prewarm_asset_jobs = _build_prewarm_asset_jobs()
		_prewarm_asset_index = 0
	var remaining: int = max(1, batch_size)
	while _prewarm_asset_index < _prewarm_asset_jobs.size() and remaining > 0:
		_run_prewarm_asset_job(_prewarm_asset_jobs[_prewarm_asset_index])
		_prewarm_asset_index += 1
		remaining -= 1
	if _prewarm_asset_index >= _prewarm_asset_jobs.size():
		_prewarm_asset_jobs.clear()
		_prewarm_asset_index = 0
		return true
	return false


func draw_icon(canvas: CanvasItem, skill_id: String, rect: Rect2, alpha: float = 1.0, active: bool = true) -> bool:
	if canvas == null or skill_id == "":
		return false
	# 융합 재료쌍: 조회 전용 캐시 소비+소유 절차 폴백 — 캐시 미스 프레임도
	# 융합 아이콘으로 렌더되고, 합성은 프리웜(엔트리 빌드/씬 구성) 소유라
	# 드로우 핫패스 재합성이 없다.
	if skill_id.begins_with(FUSION_PAIR_KEY_PREFIX):
		_draw_perk_fusion_pair_icon(canvas, skill_id, rect, active, alpha)
		return true
	var source: Dictionary = _get_icon_source(skill_id)
	var texture: Texture2D = source.get("texture", null)
	if texture == null:
		return false

	var draw_rect: Rect2 = _get_draw_rect(rect, skill_id, texture)
	var modulate := Color(1.0, 1.0, 1.0, alpha) if active else Color(0.48, 0.48, 0.48, 0.78 * alpha)
	var region: Rect2 = source.get("region", Rect2())
	if region.size.x > 0.0 and region.size.y > 0.0:
		canvas.draw_texture_rect_region(texture, draw_rect, region, modulate)
	else:
		canvas.draw_texture_rect(texture, draw_rect, false, modulate)

	if _needs_unlock_badge(skill_id):
		_draw_unlock_badge(canvas, rect, alpha)
	return true


func has_icon(skill_id: String) -> bool:
	# 융합 재료쌍 키는 파싱만 유효하면 항상 렌더 가능하다(합성 텍스처 미스
	# 프레임도 소유 절차 폴백이 담당) — 캐시 상태에 따라 has/hasn't가
	# 흔들리면 소비자 폴백 분기가 프레임마다 튄다.
	if skill_id.begins_with(FUSION_PAIR_KEY_PREFIX):
		return not PerkFusionIconKey.parse(skill_id).is_empty()
	return _get_icon_source(skill_id).get("texture", null) != null


# 애니메이션(시트) 아이콘 여부. 융합 재료쌍 합성은 항상 정적 경로 — 시트
# 재료도 임의 프레임을 얼리는 대신 결정적 정적 companion으로 합성한다.
func has_animated_icon(skill_id: String) -> bool:
	if skill_id.begins_with(FUSION_PAIR_KEY_PREFIX):
		return false
	return PERK_SHEET_PATHS.has(skill_id)


# 재료쌍 합성 텍스처 준비(드로우 핫패스 밖). 슬롯 키=fusion_id — 복수
# 융합(A/B)이 동시에 표시돼도 서로의 텍스처를 몰아내지 않는다. 슬롯 안의
# cache_key=pair_id(리비전·소스 포함)/size/active — 같은 fusion_id의 키
# 변경(리비전·소스·크기)만 그 슬롯을 교체 재합성한다.
var _fusion_pair_texture_cache: Dictionary = {}
var _fusion_pair_compositions := 0
var _fusion_pair_cache_hits := 0


func prepare_fusion_pair_icon(pair_id: String, icon_size: Vector2, active: bool) -> bool:
	var cache_key := "%s|%dx%d|%d" % [pair_id, int(icon_size.x), int(icon_size.y), int(active)]
	# 히트 경로는 parse/합성 없이 슬롯 키 대조만 — 프레임 안 반복 호출 무비용.
	for slot_value: Variant in _fusion_pair_texture_cache.values():
		if slot_value is Dictionary and str((slot_value as Dictionary).get("key", "")) == cache_key:
			_fusion_pair_cache_hits += 1
			return true
	var parsed: Dictionary = PerkFusionIconKey.parse(pair_id)
	if parsed.is_empty():
		return false
	var texture: Texture2D = _compose_fusion_pair_texture(parsed, icon_size, active)
	if texture == null:
		return false
	_fusion_pair_texture_cache[str(parsed.get("fusion_id", pair_id))] = {
		"key": cache_key,
		"texture": texture,
	}
	_fusion_pair_compositions += 1
	return true


func get_fusion_pair_cache_stats() -> Dictionary:
	return {
		"textures": _fusion_pair_texture_cache.size(),
		"compositions": _fusion_pair_compositions,
		"hits": _fusion_pair_cache_hits,
	}


# 스테이지드 프리웜(업데이트/오픈 경로 소유 — CanvasItem draw 밖): 상태의
# 융합 projection을 읽어 재료쌍 텍스처를 미리 합성한다. 마커=리비전×캐시
# 서명×크기 — 무변경 재호출은 O(1) 문자열 비교로 끝나고, 드로우 소비자는
# 조회 전용(미스=절차 폴백)을 유지하므로 draw 프레임에서 합성이 없다.
var _fusion_pair_prewarm_marker := ""


func prewarm_fusion_pair_icons_for_state(runtime_state: Object, icon_size: Vector2 = FUSION_PAIR_DEFAULT_SIZE) -> int:
	if runtime_state == null or not runtime_state.has_method("get_perk_fusion_display_projection"):
		return 0
	var projection: Dictionary = runtime_state.get_perk_fusion_display_projection()
	var marker := "%s|%s|%dx%d" % [
		str(projection.get("fusion_revision", 0)),
		str(projection.get("cache_signature", 0)),
		int(icon_size.x),
		int(icon_size.y),
	]
	if marker == _fusion_pair_prewarm_marker:
		return 0
	var prepared := 0
	var complete := true
	for entry_value: Variant in projection.get("entries", []) as Array:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("type", "")) != "fusion":
			continue
		var pair_id: String = PerkFusionIconKey.build(
			str(entry.get("fusion_id", "")),
			int(entry.get("fusion_revision", 0)),
			entry.get("sources", []) as Array
		)
		if prepare_fusion_pair_icon(pair_id, icon_size, true):
			prepared += 1
		else:
			complete = false
	if complete:
		_fusion_pair_prewarm_marker = marker
	return prepared


# 드로우 경로 소비자: 조회 전용(합성·parse 없음). 저장된 cache_key가 요청
# pair_id(리비전·소스 포함)와 맞아야만 히트 — stale 리비전 텍스처를 그리지
# 않는다.
func _get_fusion_pair_cached_texture(pair_id: String) -> Texture2D:
	var wanted_prefix := pair_id + "|"
	for slot_value: Variant in _fusion_pair_texture_cache.values():
		if not (slot_value is Dictionary):
			continue
		var slot: Dictionary = slot_value
		if str(slot.get("key", "")).begins_with(wanted_prefix):
			return slot.get("texture", null) as Texture2D
	return null


# 두 재료 아이콘을 대각 분할 합성(§5 계약: 반대각 경계 — 좌상 삼각=첫
# 재료, 우하 삼각=둘째 재료, 경계 1.5px AA + 잉크 위 골드 씸 틴트).
# 각 재료는 풀사이즈로 스케일 후 마스크(반폭 압착 금지 — 모티프 보존).
# Image 합성 — 드로우 경로의 폴리곤 삼각분할·뷰포트 캡처 비용을 피한다.
# 프리웜 소유 경로 전용이라 per-pixel 루프 비용(<80x80)은 핫패스 무관.
func _compose_fusion_pair_texture(parsed: Dictionary, icon_size: Vector2, active: bool) -> Texture2D:
	var sources: Array = parsed.get("sources", []) as Array
	if sources.size() != 2:
		return null
	var width: int = maxi(8, int(round(icon_size.x)))
	var height: int = maxi(8, int(round(icon_size.y)))
	var left_image: Image = _get_fusion_source_icon(str(sources[0]), Vector2(width, height))
	var right_image: Image = _get_fusion_source_icon(str(sources[1]), Vector2(width, height))
	if left_image == null and right_image == null:
		return null
	if not active:
		if left_image != null:
			left_image.adjust_bcs(0.72, 1.0, 0.55)
		if right_image != null:
			right_image.adjust_bcs(0.72, 1.0, 0.55)
	var composed := Image.create(width, height, false, Image.FORMAT_RGBA8)
	composed.fill(Color(0.0, 0.0, 0.0, 0.0))
	var transparent := Color(0.0, 0.0, 0.0, 0.0)
	var seam_tint := Color(1.0, 0.92, 0.62)
	for y in range(height):
		for x in range(width):
			# 반대각 부호거리(px 단위): <0 = 좌상 삼각(첫 재료), >0 = 우하
			# 삼각(둘째 재료). 정사각이 아니면 y를 폭 비율로 정규화.
			var diagonal_px: float = float(x) + 0.5 + (float(y) + 0.5) * float(width) / float(height) - float(width)
			var blend: float = smoothstep(-0.75, 0.75, diagonal_px)
			var left_px: Color = left_image.get_pixel(x, y) if left_image != null else transparent
			var right_px: Color = right_image.get_pixel(x, y) if right_image != null else transparent
			var px: Color = left_px.lerp(right_px, blend)
			if absf(diagonal_px) < 0.9 and px.a > 0.05:
				# 씸은 잉크 위 RGB 틴트만 — 알파를 새로 만들지 않는다
				# (코너 투명 계약, perk_fusion_icon_runtime_smoke).
				px = Color(
					lerpf(px.r, seam_tint.r, 0.35),
					lerpf(px.g, seam_tint.g, 0.35),
					lerpf(px.b, seam_tint.b, 0.35),
					px.a
				)
			composed.set_pixel(x, y, px)
	return ImageTexture.create_from_image(composed)


# 재료 소스 아이콘의 결정적 정적 이미지. 정적 PNG가 있으면 그 텍스처를,
# 시트만 있으면(임의 프레임 얼림 금지) 아이콘 id 해시 기반의 결정적
# 그라디언트 플레이스홀더를 쓴다.
func _get_fusion_source_icon(perk_id: String, target_size: Vector2) -> Image:
	var width: int = maxi(1, int(round(target_size.x)))
	var height: int = maxi(1, int(round(target_size.y)))
	var static_path: String = _get_static_path(perk_id)
	if static_path != "":
		var texture: Texture2D = _get_texture(static_path)
		if texture != null:
			var image: Image = texture.get_image()
			if image != null and not image.is_empty():
				image = image.duplicate()
				if image.is_compressed():
					image.decompress()
				image.convert(Image.FORMAT_RGBA8)
				image.resize(width, height, Image.INTERPOLATE_LANCZOS)
				return image
	var seed_hash: int = hash(perk_id)
	var base_color := Color.from_hsv(float(seed_hash % 360) / 360.0, 0.55, 0.85, 1.0)
	var placeholder := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var row_shade: float = 0.75 + 0.25 * (1.0 - float(y) / maxf(1.0, float(height - 1)))
		var row_color := Color(base_color.r * row_shade, base_color.g * row_shade, base_color.b * row_shade, 1.0)
		for x in range(width):
			placeholder.set_pixel(x, y, row_color)
	return placeholder


# 소유 폴백 아트: PNG가 전부 실패해도 융합 아이콘은 렌더 가능해야 한다.
# 원/링 기반 절차 드로우 — draw_colored_polygon 삼각분할 위험 회피.
func _draw_perk_fusion_icon(canvas: CanvasItem, rect: Rect2, active: bool) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.42
	var body_color := Color(0.72, 0.46, 0.98, 1.0 if active else 0.6)
	canvas.draw_circle(center, radius, Color(0.16, 0.10, 0.24, 0.9))
	canvas.draw_arc(center, radius * 0.92, 0.0, TAU, 24, body_color, 2.0, true)
	canvas.draw_circle(center + Vector2(-radius * 0.3, 0.0), radius * 0.34, Color(0.5, 0.75, 1.0, 0.85))
	canvas.draw_circle(center + Vector2(radius * 0.3, 0.0), radius * 0.34, Color(1.0, 0.62, 0.42, 0.85))
	canvas.draw_arc(center, radius * 0.45, 0.0, TAU, 16, Color(1.0, 0.9, 0.6, 0.9), 1.5, true)


# 재료쌍 표시 아이콘의 소유 드로우 진입점(합성 텍스처 캐시 소비). 미스는
# 저비용 절차 폴백 — 드로우 핫패스에서 합성하지 않는다(프리웜은 엔트리
# 빌드/씬 구성 시점 소유).
func _draw_perk_fusion_pair_icon(canvas: CanvasItem, pair_id: String, rect: Rect2, active: bool, alpha: float = 1.0) -> void:
	var cached: Texture2D = _get_fusion_pair_cached_texture(pair_id)
	if cached != null:
		var modulate := Color(1.0, 1.0, 1.0, alpha) if active else Color(0.48, 0.48, 0.48, 0.78 * alpha)
		canvas.draw_texture_rect(cached, rect, false, modulate)
		return
	_draw_perk_fusion_icon(canvas, rect, active)


func covered_ids() -> Array:
	var ids: Array = []
	for key in FUSION_OFFER_ICON_PATHS.keys():
		ids.append(str(key))
	for key in PERK_ICON_PATHS.keys():
		ids.append(str(key))
	for key in SKILL_ICON_PATHS.keys():
		ids.append(str(key))
	for key in UNLOCK_ALIASES.keys():
		ids.append(str(key))
	return ids


func _build_prewarm_asset_jobs() -> Array:
	var jobs: Array = []
	for key in PERK_ICON_PATHS.keys():
		jobs.append({"type": "texture", "path": str(PERK_ICON_PATHS[key])})
	for key in SKILL_ICON_PATHS.keys():
		jobs.append({"type": "texture", "path": str(SKILL_ICON_PATHS[key])})
	for key in MANUAL_ICON_PATHS.keys():
		jobs.append({"type": "texture", "path": str(MANUAL_ICON_PATHS[key])})
	for key in PERK_SHEET_PATHS.keys():
		jobs.append({"type": "sheet", "path": str(PERK_SHEET_PATHS[key])})
	for skill_id in covered_ids():
		jobs.append({"type": "source", "id": str(skill_id)})
	return jobs


func _run_prewarm_asset_job(job_value: Variant) -> void:
	if not (job_value is Dictionary):
		return
	var job: Dictionary = job_value
	match str(job.get("type", "")):
		"texture":
			_touch_texture(_get_texture(str(job.get("path", ""))))
		"sheet":
			_touch_texture(_get_sheet_texture(str(job.get("path", ""))))
		"source":
			var source: Dictionary = _get_icon_source(str(job.get("id", "")))
			_touch_texture(source.get("texture", null))


func _get_icon_source(skill_id: String) -> Dictionary:
	# 융합 재료쌍 키: 조회 전용(드로우 핫패스 — 합성 금지). 미스={} →
	# 소비자 폴백 심볼이 그 프레임을 담당하고, 프리웜(엔트리 빌드/씬 구성
	# 시점)이 다음 표시 전에 채운다.
	if skill_id.begins_with(FUSION_PAIR_KEY_PREFIX):
		var pair_texture: Texture2D = _get_fusion_pair_cached_texture(skill_id)
		if pair_texture != null:
			return {"texture": pair_texture, "region": Rect2(Vector2.ZERO, pair_texture.get_size())}
		return {}
	var sheet_path: String = str(PERK_SHEET_PATHS.get(skill_id, ""))
	if sheet_path != "":
		var sheet_texture: Texture2D = _get_sheet_texture(sheet_path)
		if sheet_texture != null:
			return {
				"texture": sheet_texture,
				"region": _get_sheet_region(sheet_texture),
			}

	if _static_source_cache.has(skill_id):
		var cached_source: Variant = _static_source_cache[skill_id]
		if cached_source is Dictionary:
			return cached_source
		_static_source_cache.erase(skill_id)

	var path: String = _get_static_path(skill_id)
	if path == "":
		return {}
	var texture: Texture2D = _get_texture(path)
	if texture == null:
		return {}
	# 비급책은 완성된 투명 실루엣이므로 원형 초식 구슬의 crop/zoom 정규화를
	# 적용하지 않는다. 같은 호환 id를 쓰더라도 책 외곽을 보존해야 한다.
	if not MANUAL_ICON_PATHS.has(skill_id):
		texture = SkillOrbTextureNormalizer.normalize(_resolve_skill_icon_id(skill_id), texture)
	var source := {"texture": texture, "region": Rect2()}
	_static_source_cache[skill_id] = source
	return source


func _get_static_path(skill_id: String) -> String:
	if FUSION_OFFER_ICON_PATHS.has(skill_id):
		return str(FUSION_OFFER_ICON_PATHS[skill_id])
	if PERK_ICON_PATHS.has(skill_id):
		return str(PERK_ICON_PATHS[skill_id])
	if MANUAL_ICON_PATHS.has(skill_id):
		return str(MANUAL_ICON_PATHS[skill_id])
	var resolved_id: String = _resolve_skill_icon_id(skill_id)
	if SKILL_ICON_PATHS.has(resolved_id):
		return str(SKILL_ICON_PATHS[resolved_id])
	return ""


func _resolve_skill_icon_id(skill_id: String) -> String:
	return str(UNLOCK_ALIASES.get(skill_id, skill_id))


func _get_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture: Texture2D = ProjectResourceLoader.load_texture(
		path,
		"Missing runtime perk icon at %s",
		"Failed to load runtime perk icon at %s"
	)
	_texture_cache[path] = texture
	return texture


func _get_sheet_texture(path: String) -> Texture2D:
	if _sheet_cache.has(path):
		return _sheet_cache[path]
	var texture: Texture2D = ProjectResourceLoader.load_texture(
		path,
		"Missing runtime perk icon sheet at %s",
		"Failed to load runtime perk icon sheet at %s"
	)
	_sheet_cache[path] = texture
	return texture


func _get_sheet_region(texture: Texture2D) -> Rect2:
	var cache_key: String = str(texture.get_rid().get_id())
	var region_data: Dictionary = {}
	if _sheet_region_cache.has(cache_key):
		var cached_region_data: Variant = _sheet_region_cache[cache_key]
		if cached_region_data is Dictionary:
			region_data = cached_region_data
	if region_data.is_empty():
		var frame_size_new: int = max(1, texture.get_height())
		var frame_count_new: int = max(1, int(floor(float(texture.get_width()) / float(frame_size_new))))
		region_data = {
			"frame_size": frame_size_new,
			"frame_count": frame_count_new,
		}
		_sheet_region_cache[cache_key] = region_data
	var frame_size: int = int(region_data.get("frame_size", max(1, texture.get_height())))
	var frame_count: int = int(region_data.get("frame_count", 1))
	var frame_index: int = int(floor(float(Time.get_ticks_msec()) / 110.0)) % frame_count
	return Rect2(Vector2(float(frame_index * frame_size), 0.0), Vector2(float(frame_size), float(frame_size)))


func _get_draw_rect(rect: Rect2, skill_id: String, texture: Texture2D) -> Rect2:
	var scale: float = float(DRAW_SCALE.get(skill_id, 1.0))
	if UNLOCK_ALIASES.has(skill_id):
		scale = min(scale, 0.98)
	var size: Vector2 = rect.size * scale
	var source_w: float = max(1.0, float(texture.get_width()))
	var source_h: float = max(1.0, float(texture.get_height()))
	if source_w > source_h * 1.5:
		source_w = source_h
	var aspect: float = source_w / source_h
	if aspect > 1.0:
		size.y = size.x / aspect
	else:
		size.x = size.y * aspect
	return Rect2(rect.get_center() - size * 0.5, size)


func _needs_unlock_badge(skill_id: String) -> bool:
	return MANUAL_ICON_PATHS.has(skill_id) or skill_id.begins_with("unlock_") or bool(COMMANDO_UNLOCK_BADGE_IDS.get(skill_id, false))


func _draw_unlock_badge(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	var radius: float = max(6.0, min(rect.size.x, rect.size.y) * 0.17)
	var center: Vector2 = rect.end - Vector2(radius * 0.9, radius * 0.9)
	canvas.draw_circle(center, radius + 1.5, Color(4.0 / 255.0, 12.0 / 255.0, 18.0 / 255.0, 0.92 * alpha))
	canvas.draw_circle(center, radius, Color(0.0, 215.0 / 255.0, 1.0, 0.95 * alpha))
	canvas.draw_line(center + Vector2(-radius * 0.45, 0.0), center + Vector2(radius * 0.45, 0.0), Color.WHITE, 2.0)
	canvas.draw_line(center + Vector2(0.0, -radius * 0.45), center + Vector2(0.0, radius * 0.45), Color.WHITE, 2.0)


func _touch_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	texture.get_width()
	texture.get_height()
