extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const BallUpdateStaticConfig := preload("res://scripts/ball/ball_update_static_config.gd")
const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayTextLineCache := preload("res://scripts/hud/character_info_overlay_text_line_cache.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")
const RuntimePerkAngelBlessingProjection := preload("res://scripts/characters/runtime_perk_angel_blessing_projection.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const SmasherDashActiveMotionResolver := preload("res://scripts/characters/smasher_dash_active_motion_resolver.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")

# 능력치 툴팁 소스별 증감 내역(breakdown) 상수.
# 0.5% 미만 기여는 표시하지 않는다 (반올림 시 0%가 되는 줄 방지).
const BREAKDOWN_MIN_RATIO_DELTA := 0.005
# stat_sources 기본 배열([무공, 액티브, 신화, 수호령]) 순서와 짝을 이루는 폴백 라벨.
# override 소스 배열이 다른 구성이면 측정값은 유지되고 인덱스 라벨로 떨어진다.
const CHAIN_SOURCE_FALLBACK_LABELS: Array[String] = ["무공 효과", "액티브 아이템", "신화 아이템", "수호령 버프"]
# 체인 스탯별 runtime_perk_state 스텝의 실제 합성 성분
# (runtime_perk_effective_stat_query_surface 참조):
# 구동 퍽(1±bonus) × 신비의 주사위(stat_key) × 천사의 축복(buff) 순.
const CHAIN_PERK_ID_BY_METHOD := {
	"get_dash_duration_frames": "dash_jump",
	"get_dash_recovery_frames": "dash_module_control",
	"get_dash_recharge_frames": "dash_lightweight",
	"get_active_item_cooldown_msec": "item_cooldown_mastery",
}
const CHAIN_PERK_BONUS_IS_REDUCTION := {
	"get_dash_duration_frames": false,
	"get_dash_recovery_frames": true,
	"get_dash_recharge_frames": true,
	"get_active_item_cooldown_msec": true,
}
const CHAIN_TRAINING_ID_BY_METHOD := {
	"get_dash_duration_frames": "physique_dash_distance",
	"get_dash_recovery_frames": "physique_dash_recovery",
	"get_dash_recharge_frames": "physique_dash_recharge",
	"get_active_item_cooldown_msec": "physique_active_item_cooldown",
}
const CHAIN_TRAINING_STAT_BY_METHOD := {
	"get_dash_duration_frames": "dash_distance_bonus_pct",
	"get_dash_recovery_frames": "dash_recovery_reduction_pct",
	"get_dash_recharge_frames": "dash_recharge_reduction_pct",
	"get_active_item_cooldown_msec": "active_item_cooldown_reduction_pct",
}
const CHAIN_DICE_KEY_BY_METHOD := {
	"get_dash_recovery_frames": "dash_recovery",
	"get_dash_recharge_frames": "dash_cooldown",
	"get_active_item_cooldown_msec": "item_cooldown",
}
const CHAIN_ANGEL_KIND_BY_METHOD := {
	"get_dash_recharge_frames": "dash_recharge",
	"get_active_item_cooldown_msec": "item_cooldown",
}
# 실전 게이지 산식(compute_gauge_gain_per_hit) collector 소스 키 → 표시 라벨.
# 아이템 소스(블루투스링·골드디거)는 아이템 표시명 로컬라이즈 경로를 쓴다.
const GAUGE_SOURCE_LABELS := {
	"combo": "콤보 보너스",
	"lingpet": "수호령 버프",
	"horn_strawberry": "뿔딸기 변신",
}


static func build_player_stat_rows(
	owner: Object,
	registry: Object,
	character_runtime: Object,
	runtime_state_override: Object = null,
	active_item_runtime_override: Object = null,
	mythic_item_runtime_override: Object = null,
	character_type_override: String = "",
	stat_sources_override: Array = [],
	active_item_slot_capacity_override: int = -1,
	active_item_slots_override: Variant = null,
	special_gauge_max: float = 500.0,
	player_base_paddle_width: float = 155.0,
	base_active_item_slot_count: int = 3,
	stat_buff_color: Color = Color.WHITE,
	stat_debuff_color: Color = Color.WHITE,
	include_breakdown: bool = true,
	owner_special_gauge_max_override: float = -1.0
) -> Array:
	var character_type: String = character_type_override if character_type_override != "" else CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime)
	var runtime_state: Object = runtime_state_override if runtime_state_override != null else CharacterInfoOverlayOwnerState.get_instance(registry, "runtime_perk_state")
	var active_item_runtime: Object = active_item_runtime_override if active_item_runtime_override != null else CharacterInfoOverlayOwnerState.get_instance(registry, "active_item_runtime")
	var mythic_item_runtime: Object = mythic_item_runtime_override if mythic_item_runtime_override != null else CharacterInfoOverlayOwnerState.get_instance(registry, "mythic_item_runtime")
	var lingpet_runtime: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "lingpet_egg_runtime")
	var weather_event_state: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "weather_event_state")
	var status_effect_state: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "status_effect_state")
	var stat_sources: Array = stat_sources_override if not stat_sources_override.is_empty() else [runtime_state, active_item_runtime, mythic_item_runtime, lingpet_runtime]
	var smasher_recovery_state: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "smasher_recovery_state") if character_type == "smasher" else null
	var combo_key: String = character_runtime.get_combo_state_key(character_type) if character_runtime != null else ""
	var combo_state: Object = CharacterInfoOverlayOwnerState.get_instance(registry, combo_key) if combo_key != "" else null
	var base_max_gauge_value: float = special_gauge_max
	var base_move_speed_value: float = base_move_speed(character_type, character_runtime)
	var base_paddle_width_value: float = player_base_paddle_width
	var base_gauge_gain_value: float = BallUpdateStaticConfig.GAUGE_CHARGE_PER_HIT
	var base_dash_distance_value: float = SmasherDashActiveMotionResolver.compute_total_dash_distance(SmasherDashState.DASH_BASE_DURATION_FRAMES)
	var base_dash_recovery_seconds_value: float = frames_to_seconds(SmasherDashState.DASH_BASE_RECOVERY_FRAMES)
	var base_dash_cooldown_seconds_value: float = frames_to_seconds(SmasherDashState.DASH_BASE_RECHARGE_FRAMES)
	var base_item_cooldown_seconds_value: float = float(ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC) / 1000.0
	var owner_special_gauge_max: float = max(
		1.0,
		float(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "special_gauge_max", special_gauge_max))
	)
	if owner_special_gauge_max_override >= 1.0:
		owner_special_gauge_max = owner_special_gauge_max_override
	var max_gauge: float = effective_max_gauge(owner_special_gauge_max, stat_sources, Callable(CharacterInfoOverlayOwnerState, "apply_stat_chain"))
	var move_speed: float = effective_move_speed(
		character_type,
		character_runtime,
		runtime_state,
		smasher_recovery_state,
		active_item_runtime,
		mythic_item_runtime,
		lingpet_runtime,
		Callable(CharacterInfoOverlayOwnerState, "call_numeric_multiplier"),
		[weather_event_state, status_effect_state]
	)
	var owner_width: float = float(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "player_paddle_width", 0.0))
	var runtime_scale_fallback: float = float(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "runtime_paddle_scale", 1.0))
	var paddle_width: float = effective_player_paddle_width(owner_width, runtime_scale_fallback, runtime_state, active_item_runtime, mythic_item_runtime, Callable(CharacterInfoOverlayOwnerState, "call_numeric_multiplier"), player_base_paddle_width)
	# 게이지/대시 스탯은 실전 산식의 공유 계산기(히트 라우터·대시 상태·감속
	# 적분)를 그대로 호출한다 — HUD 재구축 산식 금지 (2026-07-11 리뷰 반영).
	var horn_transformed: bool = _is_horn_strawberry_transformed(mythic_item_runtime)
	var gauge_steps: Array = []
	var gauge_gain: float = effective_gauge_gain_per_hit(
		combo_state,
		mythic_item_runtime,
		lingpet_runtime,
		horn_transformed,
		gauge_steps if include_breakdown else null
	)
	var dash_duration_steps: Array = []
	var dash_duration_frames: float = SmasherDashState.compute_dash_duration_frames(
		runtime_state,
		registry,
		dash_duration_steps if include_breakdown else null,
		mythic_item_runtime
	)
	var dash_distance_multiplier: float = _mystic_dice_ratio(runtime_state, "dash_distance")
	var dash_distance: float = max(1.0, SmasherDashActiveMotionResolver.compute_total_dash_distance(dash_duration_frames, dash_distance_multiplier))
	var dash_recovery_steps: Array = []
	var dash_recovery_seconds: float = frames_to_seconds(SmasherDashState.compute_dash_recovery_frames(
		runtime_state,
		registry,
		dash_recovery_steps if include_breakdown else null,
		mythic_item_runtime
	))
	var dash_recharge_steps: Array = []
	var dash_cooldown_seconds: float = frames_to_seconds(SmasherDashState.compute_dash_recharge_frames(
		runtime_state,
		registry,
		dash_recharge_steps if include_breakdown else null,
		mythic_item_runtime,
		active_item_runtime
	))
	var item_cooldown_seconds: float = float(CharacterInfoOverlayOwnerState.active_item_cooldown_from_base(ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC, stat_sources, Callable(CharacterInfoOverlayOwnerState, "apply_stat_chain"))) / 1000.0
	var posture_correction_pct: float = effective_posture_correction_pct(runtime_state, mythic_item_runtime)
	var active_item_slot_capacity: int = active_item_slot_capacity_override if active_item_slot_capacity_override >= 1 else CharacterInfoOverlayOwnerState.active_item_slot_capacity(runtime_state, mythic_item_runtime, base_active_item_slot_count)
	var active_item_slot_count: int = CharacterInfoOverlayOwnerState.active_item_slot_count_from_owner(owner, active_item_slots_override)
	var active_item_slot_color: Color = stat_delta_color(float(base_active_item_slot_count), float(active_item_slot_capacity), true, stat_buff_color, stat_debuff_color)

	var numeric_multiplier_callable := Callable(CharacterInfoOverlayOwnerState, "call_numeric_multiplier")
	return [
		with_breakdown(
			delta_stat_row("이동 속도", "%.2f" % move_speed, base_move_speed_value, move_speed, true, stat_buff_color, stat_debuff_color).merged({"icon": "speed", "tooltip_body": "몸집이 좌우로 움직이는 속도입니다. 무공·아이템·수호령 버프가 모두 반영된 최종 값이며, 높을수록 공을 따라잡기 쉽습니다."}),
			move_speed_breakdown(character_type, character_runtime, runtime_state, smasher_recovery_state, active_item_runtime, mythic_item_runtime, lingpet_runtime, weather_event_state, status_effect_state, numeric_multiplier_callable) if include_breakdown else [],
			include_breakdown
		),
		with_breakdown(
			delta_stat_row("몸집 크기", "%.0fpx" % paddle_width, base_paddle_width_value, paddle_width, true, stat_buff_color, stat_debuff_color).merged({"icon": "size", "tooltip_body": "몸집의 가로 길이입니다. 넓을수록 공을 받아내기 쉽습니다. 일부 아이템·보스 기술이 일시적으로 크기를 바꿉니다."}),
			paddle_width_breakdown(runtime_scale_fallback, runtime_state, active_item_runtime, mythic_item_runtime, numeric_multiplier_callable, player_base_paddle_width) if include_breakdown else [],
			include_breakdown
		),
		with_breakdown(
			delta_stat_row("기력 획득량", "%dpt" % int(round(gauge_gain)), base_gauge_gain_value, gauge_gain, true, stat_buff_color, stat_debuff_color).merged({"icon": "gauge_gain", "tooltip_body": "공을 쳐낼 때마다 차오르는 기력의 1회 획득량입니다. 높을수록 기력이 빨리 모입니다."}),
			gauge_breakdown_from_steps(gauge_steps, runtime_state, mythic_item_runtime, lingpet_runtime),
			include_breakdown
		),
		with_breakdown(
			delta_stat_row("최대 기력", "%dpt" % int(round(max_gauge)), base_max_gauge_value, max_gauge, true, stat_buff_color, stat_debuff_color).merged({"icon": "gauge_max", "tooltip_body": "보유할 수 있는 기력의 최대치입니다. 기력이 충분하면 강력한 초식을 펼칠 수 있습니다."}),
			max_gauge_breakdown(runtime_state, mythic_item_runtime, base_max_gauge_value) if include_breakdown else [],
			include_breakdown
		),
		with_breakdown(
			delta_stat_row("활주 거리", "%dpx" % int(round(dash_distance)), base_dash_distance_value, dash_distance, true, stat_buff_color, stat_debuff_color).merged({"icon": "dash_range", "tooltip_body": "활주 한 번으로 이동하는 거리입니다. 길수록 먼 공도 한 번에 따라갈 수 있습니다."}),
			dash_distance_breakdown(dash_duration_steps, runtime_state, mythic_item_runtime, dash_distance_multiplier) if include_breakdown else [],
			include_breakdown
		),
		with_breakdown(
			delta_stat_row("활주 후딜 시간", "%.2f초" % dash_recovery_seconds, base_dash_recovery_seconds_value, dash_recovery_seconds, false, stat_buff_color, stat_debuff_color).merged({"icon": "delay", "tooltip_body": "활주가 끝난 뒤 다음 행동까지 굳는 시간입니다. 짧을수록 연속 대응이 빨라집니다."}),
			dash_frames_breakdown_from_steps(dash_recovery_steps, runtime_state, mythic_item_runtime, "get_dash_recovery_frames"),
			include_breakdown
		),
		with_breakdown(
			delta_stat_row("활주 재충전", "%.2f초" % dash_cooldown_seconds, base_dash_cooldown_seconds_value, dash_cooldown_seconds, false, stat_buff_color, stat_debuff_color).merged({"icon": "recharge", "tooltip_body": "소모한 활주 횟수 1회가 다시 차오르는 데 걸리는 시간입니다. 짧을수록 활주를 자주 쓸 수 있습니다."}),
			dash_frames_breakdown_from_steps(dash_recharge_steps, runtime_state, mythic_item_runtime, "get_dash_recharge_frames"),
			include_breakdown
		),
		with_breakdown(
			delta_stat_row("아이템 재충전", "%.2f초" % item_cooldown_seconds, base_item_cooldown_seconds_value, item_cooldown_seconds, false, stat_buff_color, stat_debuff_color).merged({"icon": "recharge", "tooltip_body": "액티브 아이템을 사용한 뒤 다시 쓸 수 있을 때까지의 대기 시간입니다. 짧을수록 좋습니다."}),
			stat_chain_breakdown(float(ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC), stat_sources, "get_active_item_cooldown_msec", runtime_state, active_item_runtime, mythic_item_runtime, lingpet_runtime) if include_breakdown else [],
			include_breakdown
		),
		with_breakdown(
			bounded_percentage_stat_row("자세 보정", posture_correction_pct, 100.0, stat_buff_color).merged({"icon": "posture", "tooltip_body": "받는 스턴 지속시간과 넉백 이동거리·지속시간을 함께 줄이는 최종 보정치입니다. 높을수록 자세를 더 빨리 회복합니다."}),
			posture_correction_breakdown(runtime_state, posture_correction_pct) if include_breakdown else [],
			include_breakdown
		),
		with_breakdown(
			simple_stat_row("액티브 아이템 슬롯", CharacterInfoOverlayFormatter.format_int_pair(active_item_slot_count, active_item_slot_capacity), active_item_slot_color).merged({"icon": "slots", "tooltip_body": "장착 중인 액티브 아이템 수와 최대 슬롯 수입니다. 수납술 수련·연환병장과 배낭 효과가 슬롯을 늘려 줍니다."}),
			active_item_slot_breakdown(runtime_state, mythic_item_runtime, base_active_item_slot_count) if include_breakdown else [],
			include_breakdown
		),
	]


static func simple_stat_row(label: String, value_text: String, color: Color) -> Dictionary:
	return {
		"label": LanguageSettings.translate_text(label),
		"value": LanguageSettings.translate_text(value_text),
		"color": color,
	}


static func bounded_percentage_stat_row(label: String, current_value: float, maximum_value: float, buff_color: Color) -> Dictionary:
	var safe_maximum := maxf(0.0001, maximum_value)
	var bounded_value := clampf(current_value, 0.0, safe_maximum)
	var row := simple_stat_row(label, "%s%%" % _format_stat_number(bounded_value), buff_color if bounded_value > 0.001 else Color.WHITE)
	row["bar_fill_ratio"] = bounded_value / safe_maximum
	row["tooltip_stat_summary"] = "현재 %s%% · 최대 %s%%" % [_format_stat_number(bounded_value), _format_stat_number(safe_maximum)]
	return row


static func delta_stat_row(label: String, value_text: String, base_value: float, current_value: float, higher_is_better: bool, buff_color: Color, debuff_color: Color) -> Dictionary:
	var row: Dictionary = simple_stat_row(label, value_text, stat_delta_color(base_value, current_value, higher_is_better, buff_color, debuff_color))
	row["base"] = base_value
	row["current"] = current_value
	row["higher_is_better"] = higher_is_better
	return row


static func stat_delta_color(base_value: float, current_value: float, higher_is_better: bool, buff_color: Color, debuff_color: Color) -> Color:
	var delta: float = current_value - base_value
	if abs(delta) <= 0.001:
		return Color.WHITE
	var improved: bool = delta > 0.0 if higher_is_better else delta < 0.0
	return buff_color if improved else debuff_color


# 소스별 증감 내역을 행에 부착한다. 열거한 소스로 설명되지 않는 잔여 배율
# (몸집 크기의 owner_width 폴백 경로 등 외부 직접 기록자)은 "기타 효과"로
# 정직하게 노출해 툴팁 합계가 항상 기본→현재 비율과 일치하게 유지한다.
# include=false(비호버 프레임)면 내역·잔여 계산을 통째로 건너뛴다.
static func with_breakdown(row: Dictionary, entries: Array, include: bool = true) -> Dictionary:
	if not include:
		return row
	var base_value: float = float(row.get("base", 0.0))
	var current_value: float = float(row.get("current", 0.0))
	if base_value > 0.0001 and current_value > 0.0:
		var attributed: float = 1.0
		for entry_value in entries:
			if entry_value is Dictionary:
				attributed *= maxf(0.0001, float((entry_value as Dictionary).get("ratio", 1.0)))
		var residual: float = (current_value / base_value) / attributed
		if absf(residual - 1.0) >= 0.01:
			entries.append({"label": "기타 효과", "ratio": residual})
	if not entries.is_empty():
		row["breakdown"] = entries
	return row


static func _append_ratio_entry(entries: Array, label: String, ratio: float, icon_id: String = "") -> void:
	if absf(ratio - 1.0) < BREAKDOWN_MIN_RATIO_DELTA:
		return
	entries.append({"label": label, "ratio": ratio, "icon_id": icon_id})


static func posture_correction_breakdown(runtime_state: Object, current_value: float) -> Array:
	var entries: Array = []
	var training_value := 0.0
	if runtime_state != null and runtime_state.has_method("get_physique_training_bonus"):
		training_value = maxf(0.0, float(runtime_state.get_physique_training_bonus("posture_correction_pct")))
	var applied_training := minf(training_value, current_value)
	var perk_value := maxf(0.0, current_value - applied_training)
	if perk_value > 0.001:
		entries.append({
			"label": _catalog_perk_label("bulletproof_hat", "철심공"),
			"text": "+%s%%p" % _format_stat_number(perk_value),
			"icon_id": "bulletproof_hat",
		})
	if applied_training > 0.001:
		entries.append({
			"label": _catalog_perk_label("physique_posture", "철심공 수련"),
			"text": "+%s%%p" % _format_stat_number(applied_training),
			"icon_id": "physique_posture",
		})
	return entries


# 증감 내역 줄에 붙일 아이콘 id (툴팁이 runtime_perk_icon_renderer / 아이템
# 텍스처로 그린다). 구동 퍽이 실제로 살아 있을 때만 그 퍽 아이콘을 붙인다
# (레벨 0 범주 폴백엔 특정 아이콘을 붙이면 오해를 부른다).
static func _perk_icon_id(runtime_state: Object, perk_id: String) -> String:
	if (
		perk_id != ""
		and runtime_state != null
		and runtime_state.has_method("get_runtime_skill_level")
		and int(runtime_state.get_runtime_skill_level(perk_id)) > 0
	):
		return perk_id
	return ""


# 퍽 소스 라벨: 구동 퍽 레벨이 살아 있으면 카탈로그 표시명으로 특정하고,
# 아니면(레벨 0인데 배율이 남는 특수 경로) 범주 라벨로 떨어진다.
static func _perk_source_label(runtime_state: Object, perk_id: String) -> String:
	if (
		perk_id != ""
		and runtime_state != null
		and runtime_state.has_method("get_runtime_skill_level")
		and int(runtime_state.get_runtime_skill_level(perk_id)) > 0
	):
		var perk_name: String = RuntimePerkCatalog.get_perk_display_name(perk_id)
		if perk_name != "":
			# 퍽 아이콘이 소스가 퍽임을 이미 보여주므로 "(퍽)" 접미사는 중복 —
			# 아이템 줄(접미사 없음)과 맞춰 퍽 이름만 표기한다.
			return perk_name
	return "무공 효과"


static func _catalog_perk_label(perk_id: String, fallback: String) -> String:
	var perk_name := RuntimePerkCatalog.get_perk_display_name(perk_id)
	if perk_name != "":
		return perk_name
	return LanguageSettings.localize_item_display_name(perk_id, fallback)


# 구동 퍽 하나가 만드는 배율 (query surface의 1±bonus 항과 동일 산식).
static func _perk_bonus_ratio(runtime_state: Object, perk_id: String, is_reduction: bool) -> float:
	if perk_id == "" or runtime_state == null or not runtime_state.has_method("get_runtime_skill_bonus"):
		return 1.0
	var bonus: float = float(runtime_state.get_runtime_skill_bonus(perk_id))
	return maxf(0.0, 1.0 - bonus) if is_reduction else maxf(0.0, 1.0 + bonus)


static func _physique_training_ratio(runtime_state: Object, stat_key: String, is_reduction: bool) -> float:
	if stat_key == "" or runtime_state == null or not runtime_state.has_method("get_physique_training_bonus"):
		return 1.0
	var bonus := maxf(0.0, float(runtime_state.get_physique_training_bonus(stat_key))) / 100.0
	return maxf(0.0, 1.0 - bonus) if is_reduction else 1.0 + bonus


static func _mystic_dice_ratio(runtime_state: Object, stat_key: String) -> float:
	if runtime_state == null or not runtime_state.has_method("get_mystic_dice_multiplier"):
		return 1.0
	return maxf(0.0, float(runtime_state.get_mystic_dice_multiplier(stat_key)))


# 천사의 축복 배율: 실전 프로젝션에 기준값을 통과시켜 측정한다 (내부 버프
# 테이블 재구축 금지). 기준값이 커서 최소치 클램프가 개입하지 않는다.
static func _angel_ratio(runtime_state: Object, kind: String) -> float:
	if runtime_state == null or not runtime_state.has_method("get_angel_blessing_state"):
		return 1.0
	var blessing_state: Object = runtime_state.get_angel_blessing_state()
	if blessing_state == null:
		return 1.0
	match kind:
		"move_speed":
			return RuntimePerkAngelBlessingProjection.apply_player_speed_multiplier(blessing_state, 1.0)
		"paddle_size":
			return RuntimePerkAngelBlessingProjection.apply_player_paddle_size_multiplier(blessing_state, 1.0)
		"dash_recharge":
			return RuntimePerkAngelBlessingProjection.apply_dash_recharge_frames(blessing_state, 100000.0) / 100000.0
		"item_cooldown":
			return float(RuntimePerkAngelBlessingProjection.apply_active_item_cooldown_msec(blessing_state, 1000000)) / 1000000.0
		"gauge_max":
			return RuntimePerkAngelBlessingProjection.apply_special_gauge_max(blessing_state, 100000.0) / 100000.0
	return 1.0


# runtime_perk_state 스텝을 실제 합성 성분(구동 퍽 × 주사위 × 천사의 축복)
# 으로 나눠 기록한다 — 전체 스텝을 퍽 이름 하나로 오귀속하지 않는다.
# 성분 곱이 실제 스텝과 다르면(클램프 등) with_breakdown 잔여 줄로 드러난다.
static func _append_runtime_perk_chain_entries(entries: Array, runtime_state: Object, method_name: String) -> void:
	var perk_id: String = str(CHAIN_PERK_ID_BY_METHOD.get(method_name, ""))
	_append_ratio_entry(
		entries,
		_perk_source_label(runtime_state, perk_id),
		_perk_bonus_ratio(runtime_state, perk_id, bool(CHAIN_PERK_BONUS_IS_REDUCTION.get(method_name, false))),
		_perk_icon_id(runtime_state, perk_id)
	)
	var training_id: String = str(CHAIN_TRAINING_ID_BY_METHOD.get(method_name, ""))
	var training_stat: String = str(CHAIN_TRAINING_STAT_BY_METHOD.get(method_name, ""))
	_append_ratio_entry(
		entries,
		_catalog_perk_label(training_id, "수련"),
		_physique_training_ratio(
			runtime_state,
			training_stat,
			bool(CHAIN_PERK_BONUS_IS_REDUCTION.get(method_name, false))
		),
		training_id
	)
	var dice_key: String = str(CHAIN_DICE_KEY_BY_METHOD.get(method_name, ""))
	if dice_key != "":
		_append_ratio_entry(entries, "팔자윷",_mystic_dice_ratio(runtime_state, dice_key), "mystic_dice")
	var angel_kind: String = str(CHAIN_ANGEL_KIND_BY_METHOD.get(method_name, ""))
	if angel_kind != "":
		_append_ratio_entry(entries, "천운삼괘", _angel_ratio(runtime_state, angel_kind), "angel_blessing")


static func _chain_source_label(source: Object, index: int, active_item_runtime: Object, mythic_item_runtime: Object, lingpet_runtime: Object) -> String:
	if source == active_item_runtime:
		return "액티브 아이템"
	if source == mythic_item_runtime:
		return "신화 아이템"
	if source == lingpet_runtime:
		return "수호령 버프"
	if index >= 0 and index < CHAIN_SOURCE_FALLBACK_LABELS.size():
		return CHAIN_SOURCE_FALLBACK_LABELS[index]
	return "기타 효과"


# apply_stat_chain과 같은 순서·같은 변환으로 체인을 재실행하며 소스별
# before→after 비율을 기록한다. runtime_perk_state 스텝은 성분 분해 경로로,
# 나머지 소스는 측정 비율로 기록한다.
static func stat_chain_breakdown(base_value: float, sources: Array, method_name: String, runtime_state: Object, active_item_runtime: Object, mythic_item_runtime: Object, lingpet_runtime: Object) -> Array:
	var entries: Array = []
	var current: float = base_value
	for i in range(sources.size()):
		var source_value: Variant = sources[i]
		if not (source_value is Object):
			continue
		var source: Object = source_value
		if source == null or not source.has_method(method_name):
			continue
		var result: Variant = source.call(method_name, current)
		if not (result is int or result is float):
			continue
		var next_value: float = float(result)
		if source == runtime_state:
			_append_runtime_perk_chain_entries(entries, runtime_state, method_name)
		elif source == mythic_item_runtime and source.has_method("get_player_stat_breakdown"):
			var detailed: Variant = source.get_player_stat_breakdown("item_cooldown", current)
			if not _append_detailed_breakdown_entries(entries, detailed, "신화 아이템") and absf(current) > 0.0001:
				_append_ratio_entry(entries, "신화 아이템", next_value / current)
		elif absf(current) > 0.0001:
			_append_ratio_entry(entries, _chain_source_label(source, i, active_item_runtime, mythic_item_runtime, lingpet_runtime), next_value / current)
		current = next_value
	return entries


# 소스가 아이템별 내역(soft-contract: get_player_stat_breakdown)을 제공하면
# 그 줄들을, 아니면 측정된 범주 배율 한 줄을 기록한다.
static func _append_source_multiplier_entries(entries: Array, source: Object, stat_key: String, category_label: String, measured_ratio: float) -> void:
	if source != null and source.has_method("get_player_stat_breakdown"):
		var detailed: Variant = source.get_player_stat_breakdown(stat_key)
		if _append_detailed_breakdown_entries(entries, detailed, category_label):
			return
	_append_ratio_entry(entries, category_label, measured_ratio)


static func _append_detailed_breakdown_entries(entries: Array, detailed: Variant, category_label: String) -> bool:
	if not (detailed is Array) or (detailed as Array).is_empty():
		return false
	var found_entry := false
	for entry_value in (detailed as Array):
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var ratio := maxf(0.0, float(entry.get("ratio", 1.0)))
		var before := float(entry.get("before", 0.0))
		if entry.has("after") and absf(before) > 0.0001:
			ratio = maxf(0.0, float(entry.get("after", before)) / before)
		_append_ratio_entry(entries, str(entry.get("label", category_label)), ratio, str(entry.get("icon_id", "")))
		found_entry = true
	return found_entry


# effective_move_speed와 동일한 소스 집합을 실제 합성 성분으로 분해한다
# (곱은 교환 가능하므로 표시 순서만 다르고 합계는 현재값/기본값과 일치;
# 성분으로 설명되지 않는 잔여는 with_breakdown이 "기타 효과"로 노출).
static func move_speed_breakdown(
	character_type: String,
	character_runtime: Object,
	runtime_state: Object,
	smasher_recovery_state: Object,
	active_item_runtime: Object,
	mythic_item_runtime: Object,
	lingpet_runtime: Object,
	weather_event_state: Object,
	status_effect_state: Object,
	call_numeric_multiplier: Callable
) -> Array:
	var entries: Array = []
	var transformed: bool = _is_horn_strawberry_transformed(mythic_item_runtime)
	if transformed:
		var base_speed: float = base_move_speed(character_type, character_runtime)
		var horn_speed: Variant = mythic_item_runtime.get_horn_strawberry_move_speed()
		if horn_speed != null and base_speed > 0.0001:
			_append_ratio_entry(entries, _catalog_perk_label("horn_strawberry_mask", "뿔딸기 변신가면"), maxf(0.0, float(horn_speed)) / base_speed, "horn_strawberry_mask")
	_append_ratio_entry(entries, _perk_source_label(runtime_state, "common_swiftness"), _perk_bonus_ratio(runtime_state, "common_swiftness", false), _perk_icon_id(runtime_state, "common_swiftness"))
	_append_ratio_entry(entries, _catalog_perk_label("physique_move_speed", "유운보 수련"), _physique_training_ratio(runtime_state, "move_speed_bonus_pct", false), "physique_move_speed")
	_append_ratio_entry(entries, "팔자윷",_mystic_dice_ratio(runtime_state, "player_speed"), "mystic_dice")
	_append_ratio_entry(entries, "천운삼괘", _angel_ratio(runtime_state, "move_speed"), "angel_blessing")
	if runtime_state != null and runtime_state.has_method("get_perk_fusion_move_speed_multiplier"):
		_append_ratio_entry(entries, PerkFusionLocalization.byproduct_name("reverb"), maxf(0.0, float(runtime_state.get_perk_fusion_move_speed_multiplier())))
	if character_type == "smasher" and not transformed:
		_append_ratio_entry(entries, LanguageSettings.translate_text("리커버리 스킬"), float(call_numeric_multiplier.call(smasher_recovery_state, "get_player_speed_multiplier")))
	_append_source_multiplier_entries(entries, weather_event_state, "player_speed", "날씨 이벤트", float(call_numeric_multiplier.call(weather_event_state, "get_player_speed_multiplier")))
	_append_source_multiplier_entries(entries, status_effect_state, "player_speed", "상태이상", float(call_numeric_multiplier.call(status_effect_state, "get_player_speed_multiplier")))
	_append_source_multiplier_entries(entries, active_item_runtime, "player_speed", "액티브 아이템", float(call_numeric_multiplier.call(active_item_runtime, "get_player_speed_multiplier")))
	_append_source_multiplier_entries(entries, mythic_item_runtime, "player_speed", "신화 아이템", float(call_numeric_multiplier.call(mythic_item_runtime, "get_player_speed_multiplier")))
	_append_source_multiplier_entries(entries, lingpet_runtime, "player_speed", "수호령 버프", float(call_numeric_multiplier.call(lingpet_runtime, "get_player_speed_multiplier")))
	return entries


static func paddle_width_breakdown(
	runtime_scale_fallback: float,
	runtime_state: Object,
	active_item_runtime: Object,
	mythic_item_runtime: Object,
	call_numeric_multiplier: Callable,
	base_paddle_width: float
) -> Array:
	var entries: Array = []
	_append_ratio_entry(entries, _perk_source_label(runtime_state, "common_bulk_up"), _perk_bonus_ratio(runtime_state, "common_bulk_up", false), _perk_icon_id(runtime_state, "common_bulk_up"))
	_append_ratio_entry(entries, _catalog_perk_label("physique_paddle_size", "철산공 수련"), _physique_training_ratio(runtime_state, "paddle_size_bonus_pct", false), "physique_paddle_size")
	_append_ratio_entry(entries, "팔자윷",_mystic_dice_ratio(runtime_state, "paddle_size"), "mystic_dice")
	_append_ratio_entry(entries, "천운삼괘", _angel_ratio(runtime_state, "paddle_size"), "angel_blessing")
	var runtime_scale: float = runtime_paddle_scale(runtime_scale_fallback, runtime_state)
	var mythic_scale: float = float(call_numeric_multiplier.call(mythic_item_runtime, "get_player_paddle_scale"))
	_append_source_multiplier_entries(entries, mythic_item_runtime, "paddle_size", "신화 아이템", mythic_scale)
	var scaled_base_width: float = base_paddle_width * runtime_scale * mythic_scale
	if active_item_runtime != null and active_item_runtime.has_method("get_player_paddle_width") and scaled_base_width > 0.0001:
		_append_source_multiplier_entries(
			entries,
			active_item_runtime,
			"paddle_scale",
			"액티브 아이템",
			max(1.0, float(active_item_runtime.get_player_paddle_width(scaled_base_width))) / scaled_base_width
		)
	return entries


# 실전 게이지 산식 collector 스텝 → 내역 줄 (라벨은 소스 키 매핑;
# 아이템 소스는 표시명 로컬라이즈).
static func gauge_breakdown_from_steps(steps: Array, runtime_state: Object, mythic_item_runtime: Object, lingpet_runtime: Object) -> Array:
	var entries: Array = []
	for step_value in steps:
		if not (step_value is Dictionary):
			continue
		var step: Dictionary = step_value
		var before: float = float(step.get("before", 0.0))
		if absf(before) <= 0.0001:
			continue
		var gauge_source: String = str(step.get("source", ""))
		if gauge_source == "bluetooth_ring" and runtime_state != null:
			var training_pct := maxf(0.0, float(runtime_state.get_physique_training_bonus("hit_gauge_bonus_pct"))) if runtime_state.has_method("get_physique_training_bonus") else 0.0
			if training_pct > 0.0:
				# Split the measured production step, not only runtime_state's option
				# query: legacy Bluetooth owners can provide their portion from the
				# mythic compatibility layer while training still enters the same step.
				var total_pct := maxf(0.0, (float(step.get("after", before)) / before - 1.0) * 100.0)
				var perk_pct := maxf(0.0, total_pct - training_pct)
				_append_ratio_entry(entries, _gauge_step_label(gauge_source), 1.0 + perk_pct / 100.0, _gauge_step_icon_id(gauge_source))
				_append_ratio_entry(entries, _catalog_perk_label("physique_hit_gauge", "격기심법 수련"), (100.0 + perk_pct + training_pct) / maxf(0.0001, 100.0 + perk_pct), "physique_hit_gauge")
				continue
		if gauge_source == "lingpet" and lingpet_runtime != null and lingpet_runtime.has_method("get_player_stat_breakdown"):
			var detailed: Variant = lingpet_runtime.get_player_stat_breakdown("gauge_gain", before)
			if _append_detailed_breakdown_entries(entries, detailed, "수호령 버프"):
				continue
		_append_ratio_entry(entries, _gauge_step_label(gauge_source), float(step.get("after", 0.0)) / before, _gauge_step_icon_id(gauge_source))
	return entries


static func _gauge_step_label(source: String) -> String:
	match source:
		"bluetooth_ring":
			return _catalog_perk_label("bluetooth_ring", "블루투스링")
		"horn_strawberry":
			return _catalog_perk_label("horn_strawberry_mask", "뿔딸기 변신가면")
	return str(GAUGE_SOURCE_LABELS.get(source, "기타 효과"))


# 블루투스링은 퍽 아이콘 렌더러가 커버(신화→퍽 아이콘 공유); 콤보·수호령·뿔딸기
# 등 범주 스텝은 특정 아이콘이 없다.
static func _gauge_step_icon_id(source: String) -> String:
	if source == "bluetooth_ring":
		return source
	if source == "horn_strawberry":
		return "horn_strawberry_mask"
	return ""


# 대시 거리: 지속시간 스텝을 실거리 적분(compute_total_dash_distance)으로
# 환산해 비율화한다 (감속 커브 탓에 지속시간 비율 ≠ 거리 비율).
static func dash_distance_breakdown(duration_steps: Array, runtime_state: Object, mythic_item_runtime: Object, dice_multiplier: float) -> Array:
	var entries: Array = []
	for step_value in duration_steps:
		if not (step_value is Dictionary):
			continue
		var step: Dictionary = step_value
		var before_distance: float = SmasherDashActiveMotionResolver.compute_total_dash_distance(float(step.get("before", 0.0)))
		if before_distance <= 0.0001:
			continue
		var after_distance: float = SmasherDashActiveMotionResolver.compute_total_dash_distance(float(step.get("after", 0.0)))
		var dist_source: String = str(step.get("source", ""))
		if dist_source == "mythic_item" and mythic_item_runtime != null and mythic_item_runtime.has_method("get_player_stat_breakdown"):
			var detailed: Variant = mythic_item_runtime.get_player_stat_breakdown("dash_duration", float(step.get("before", 0.0)))
			if detailed is Array and not (detailed as Array).is_empty():
				for entry_value in (detailed as Array):
					if not (entry_value is Dictionary):
						continue
					var entry: Dictionary = entry_value
					var detail_before_distance := SmasherDashActiveMotionResolver.compute_total_dash_distance(float(entry.get("before", 0.0)))
					if detail_before_distance <= 0.0001:
						continue
					var detail_after_distance := SmasherDashActiveMotionResolver.compute_total_dash_distance(float(entry.get("after", 0.0)))
					_append_ratio_entry(entries, str(entry.get("label", "신화 아이템")), detail_after_distance / detail_before_distance, str(entry.get("icon_id", "")))
				continue
		var is_perk_step: bool = dist_source == "perk"
		if is_perk_step:
			_append_ratio_entry(entries, _perk_source_label(runtime_state, "dash_jump"), _perk_bonus_ratio(runtime_state, "dash_jump", false), _perk_icon_id(runtime_state, "dash_jump"))
			_append_ratio_entry(entries, _catalog_perk_label("physique_dash_distance", "비천보 수련"), _physique_training_ratio(runtime_state, "dash_distance_bonus_pct", false), "physique_dash_distance")
			continue
		var label: String = _perk_source_label(runtime_state, "dash_jump") if is_perk_step else _dash_step_label(dist_source)
		var icon_id: String = _perk_icon_id(runtime_state, "dash_jump") if is_perk_step else _dash_step_icon_id(dist_source)
		_append_ratio_entry(entries, label, after_distance / before_distance, icon_id)
	_append_ratio_entry(entries, "팔자윷",dice_multiplier, "mystic_dice")
	return entries


# 대시 후딜/재충전: 실전 체인 collector 스텝을 내역 줄로 바꾼다.
# 퍽 스텝은 성분 분해(구동 퍽 × 주사위 × 천사의 축복), 액티브 스텝은
# 축지부 아이템 표시명으로 특정한다.
static func dash_frames_breakdown_from_steps(steps: Array, runtime_state: Object, mythic_item_runtime: Object, method_name: String) -> Array:
	var entries: Array = []
	for step_value in steps:
		if not (step_value is Dictionary):
			continue
		var step: Dictionary = step_value
		var source: String = str(step.get("source", ""))
		if source == "perk":
			_append_runtime_perk_chain_entries(entries, runtime_state, method_name)
			continue
		var before: float = float(step.get("before", 0.0))
		if absf(before) <= 0.0001:
			continue
		if source == "mythic_item" and mythic_item_runtime != null and mythic_item_runtime.has_method("get_player_stat_breakdown"):
			var stat_key := "dash_recovery" if method_name == "get_dash_recovery_frames" else "dash_recharge"
			var detailed: Variant = mythic_item_runtime.get_player_stat_breakdown(stat_key, before)
			if _append_detailed_breakdown_entries(entries, detailed, "신화 아이템"):
				continue
		_append_ratio_entry(entries, _dash_step_label(source), float(step.get("after", 0.0)) / before, _dash_step_icon_id(source))
	return entries


# 축지부는 액티브 아이템(퍽 렌더러 미커버) → 아이템 텍스처 폴백 id;
# 신화 아이템 스텝은 특정 아이콘 없음.
static func _dash_step_icon_id(source: String) -> String:
	if source == "active_item":
		return "dash_boost"
	return ""


static func _dash_step_label(source: String) -> String:
	match source:
		"mythic_item":
			return "신화 아이템"
		"active_item":
			return LanguageSettings.localize_item_display_name("dash_boost", "축지부")
	return "기타 효과"


# 최대 게이지: 소유자 필드를 여러 주체가 직접 기록하므로 완전 분해는 불가.
# 직접 측정 가능한 천사의 축복만 특정하고 나머지는 잔여("기타 효과")로 남긴다.
static func max_gauge_breakdown(runtime_state: Object, mythic_item_runtime: Object, base_max_gauge: float) -> Array:
	var entries: Array = []
	var training_bonus := maxf(0.0, float(runtime_state.get_physique_training_bonus("max_gauge_flat"))) if runtime_state != null and runtime_state.has_method("get_physique_training_bonus") else 0.0
	if training_bonus > 0.0 and runtime_state.has_method("get_converted_perk_option_value"):
		var total_bonus := maxf(0.0, float(runtime_state.get_converted_perk_option_value("fuel_pouch", "fuel_bonus_flat")))
		var perk_bonus := maxf(0.0, total_bonus - training_bonus)
		var after_perk := base_max_gauge + perk_bonus
		_append_ratio_entry(entries, _catalog_perk_label("fuel_pouch", "태허심법"), after_perk / maxf(0.0001, base_max_gauge), "fuel_pouch")
		_append_ratio_entry(entries, _catalog_perk_label("physique_max_gauge", "태허심법 수련"), (after_perk + training_bonus) / maxf(0.0001, after_perk), "physique_max_gauge")
	elif mythic_item_runtime != null and mythic_item_runtime.has_method("get_player_stat_breakdown"):
		_append_detailed_breakdown_entries(entries, mythic_item_runtime.get_player_stat_breakdown("max_gauge", base_max_gauge), "신화 아이템")
	_append_ratio_entry(entries, "팔자윷",_mystic_dice_ratio(runtime_state, "skill_gauge"), "mystic_dice")
	_append_ratio_entry(entries, "천운삼괘", _angel_ratio(runtime_state, "gauge_max"), "angel_blessing")
	return entries


# 액티브 슬롯: 가산 스탯이라 비율 대신 "+N" 텍스트 항목으로 기록한다.
static func active_item_slot_breakdown(runtime_state: Object, mythic_item_runtime: Object, base_count: int) -> Array:
	var entries: Array = []
	var perk_capacity: int = base_count
	if runtime_state != null:
		if runtime_state.has_method("get_perk_fusion_active_item_slot_bonus_breakdown"):
			var fusion_breakdown: Dictionary = runtime_state.get_perk_fusion_active_item_slot_bonus_breakdown()
			for byproduct_id: String in ["linked_arsenal"]:
				var byproduct_bonus := maxi(0, int(fusion_breakdown.get(byproduct_id, 0)))
				if byproduct_bonus <= 0:
					continue
				perk_capacity += byproduct_bonus
				entries.append({"label": PerkFusionLocalization.byproduct_name(byproduct_id), "text": _signed_int_text(byproduct_bonus), "icon_id": byproduct_id})
		if runtime_state.has_method("get_active_item_slot_capacity"):
			var actual_perk_capacity := int(runtime_state.get_active_item_slot_capacity(base_count))
			var training_slot_bonus := maxi(0, int(roundf(runtime_state.get_physique_training_bonus("active_item_slot_bonus")))) if runtime_state.has_method("get_physique_training_bonus") else 0
			if training_slot_bonus > 0:
				entries.append({"label": _catalog_perk_label("physique_storage", "수납술 수련"), "text": _signed_int_text(training_slot_bonus), "icon_id": "physique_storage"})
				perk_capacity += training_slot_bonus
			var unlisted_bonus := actual_perk_capacity - perk_capacity
			if unlisted_bonus != 0:
				entries.append({"label": "기타 무공 효과", "text": _signed_int_text(unlisted_bonus)})
			perk_capacity = actual_perk_capacity
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_active_item_slot_capacity"):
		var mythic_capacity: int = int(mythic_item_runtime.get_active_item_slot_capacity(perk_capacity))
		if mythic_capacity != perk_capacity:
			entries.append({"label": LanguageSettings.localize_item_display_name("slot_add", "배낭"), "text": _signed_int_text(mythic_capacity - perk_capacity), "icon_id": "slot_add"})
	return entries


static func _signed_int_text(delta: int) -> String:
	return ("+%d" % delta) if delta > 0 else str(delta)


static func draw_cached_player_stat_rows(
	canvas: CanvasItem,
	font: Font,
	title: String,
	rect: Rect2,
	row_count: int,
	label_cache: Array,
	value_cache: Array,
	color_cache: Array,
	value_width_cache: Array,
	value_width_text_cache: Array,
	value_width_size_cache: Array,
	value_width_font_id_cache: Array,
	accent_blue: Color,
	text_dim: Color,
	empty_text_color: Color,
	ui_text_scale: float,
	mouse_pos: Vector2 = Vector2.INF,
	hover_data: Dictionary = {},
	hover_row_rects: Array = []
) -> Dictionary:
	canvas.draw_rect(rect, Color(0.34, 0.27, 0.18, 0.045))
	_draw_text_xy(canvas, font, title, rect.position.x + 4.0, rect.position.y + 23.0, 16, accent_blue, ui_text_scale)
	if row_count <= 0:
		_draw_text_centered_xy(canvas, font, "표시할 능력치 없음", rect.get_center().x, rect.get_center().y + 4.0, 12, empty_text_color, ui_text_scale)
		return hover_data
	var start_y: float = rect.position.y + 49.0
	var available_h: float = max(1.0, rect.end.y - start_y - 8.0)
	var line_gap: float = min(28.0, available_h / float(max(1, row_count)))
	var row_size: int = 14 if line_gap < 19.0 else 15 if line_gap < 23.0 else 16
	line_gap = max(19.0, line_gap)
	var label_x: float = rect.position.x + 4.0
	var value_right_x: float = rect.end.x - 10.0
	var value_column_width := clampf(rect.size.x * 0.11, 76.0, 104.0)
	for i in range(row_count):
		var baseline_y: float = start_y + float(i) * line_gap
		if baseline_y > rect.end.y - 8.0:
			break
		var row_rect := Rect2(rect.position.x, baseline_y - float(row_size) - 5.0, rect.size.x, line_gap)
		hover_row_rects.append(row_rect)
		var label_draw_x: float = label_x
		if i < _player_stat_icon_cache.size() and _player_stat_icon_cache[i] != "":
			CharacterInfoOverlayTextureDrawer.draw_ui_glyph(canvas, Vector2(label_x + 6.0, baseline_y - float(row_size) * 0.38), 11.0, _player_stat_icon_cache[i], Color(text_dim.r, text_dim.g, text_dim.b, 0.85))
			label_draw_x += 19.0
		_draw_text_xy(canvas, font, str(label_cache[i]), label_draw_x, baseline_y, row_size, text_dim, ui_text_scale)
		var value_text: String = str(value_cache[i])
		var value_color: Color = color_cache[i] if color_cache[i] is Color else text_dim
		if value_color.is_equal_approx(Color.WHITE):
			value_color = Color(0.12, 0.095, 0.065)
		var value_width: float = _get_cached_value_width(font, i, value_text, row_size, value_width_cache, value_width_text_cache, value_width_size_cache, value_width_font_id_cache, ui_text_scale)
		# Segmented gauge bar between the label column and the value column
		# (2026-07-09 stats redesign; fill/color precomputed at cache refresh).
		var bar_fill: float = _player_stat_bar_fill_cache[i] if i < _player_stat_bar_fill_cache.size() else -1.0
		if bar_fill >= 0.0:
			var gauge_rect := player_stat_gauge_rect(rect, row_count, i, ui_text_scale)
			if gauge_rect.size.x >= 70.0:
				_draw_stat_gauge_bar(canvas, gauge_rect, bar_fill, _player_stat_bar_color_cache[i])
		_draw_text_xy(canvas, font, value_text, value_right_x - value_width, baseline_y, row_size, value_color, ui_text_scale)
		if i < _player_stat_tooltip_cache.size() and _player_stat_tooltip_cache[i] != "" and row_rect.has_point(mouse_pos):
			_fill_hover_data(hover_data, str(label_cache[i]), value_text, _player_stat_tooltip_cache[i], value_color, row_rect)
			var breakdown_rows: Variant = _player_stat_breakdown_rows_cache[i] if i < _player_stat_breakdown_rows_cache.size() else []
			if breakdown_rows is Array and not (breakdown_rows as Array).is_empty():
				hover_data["breakdown_rows"] = breakdown_rows
	return hover_data


# Ink-line gauge with diamond end caps, matching the hanji reference ledger.
static func _draw_stat_gauge_bar(canvas: CanvasItem, bar_rect: Rect2, fill_ratio: float, fill_color: Color) -> void:
	if bar_rect.size.x < 24.0:
		return
	var center_y := bar_rect.get_center().y
	var left_x := bar_rect.position.x + 5.0
	var right_x := bar_rect.end.x - 5.0
	var line_color := Color(0.37, 0.29, 0.18, 0.42)
	canvas.draw_line(Vector2(left_x, center_y), Vector2(right_x, center_y), line_color, 1.0, true)
	CharacterInfoOverlayTextureDrawer.draw_empty_state_diamond(canvas, Vector2(left_x, center_y), 4.2, Color(0.52, 0.36, 0.15, 0.76))
	CharacterInfoOverlayTextureDrawer.draw_empty_state_diamond(canvas, Vector2(right_x, center_y), 4.2, Color(0.52, 0.36, 0.15, 0.76))
	var fill_end_x := lerpf(left_x, right_x, clampf(fill_ratio, 0.0, 1.0))
	if fill_end_x <= left_x + 0.5:
		return
	canvas.draw_line(Vector2(left_x, center_y), Vector2(fill_end_x, center_y), fill_color, 4.0, true)
	canvas.draw_line(Vector2(left_x, center_y - 1.0), Vector2(fill_end_x, center_y - 1.0), Color(0.92, 0.82, 0.60, 0.18), 1.0, true)
	CharacterInfoOverlayTextureDrawer.draw_empty_state_diamond(canvas, Vector2(fill_end_x, center_y), 5.2, Color(0.62, 0.43, 0.18, 0.94))


static func player_stat_gauge_rect(
	rect: Rect2,
	row_count: int,
	row_index: int,
	ui_text_scale: float
) -> Rect2:
	if row_count <= 0 or row_index < 0 or row_index >= row_count:
		return Rect2()
	var start_y: float = rect.position.y + 49.0
	var available_h: float = max(1.0, rect.end.y - start_y - 8.0)
	var line_gap: float = min(28.0, available_h / float(max(1, row_count)))
	var row_size: int = 14 if line_gap < 19.0 else 15 if line_gap < 23.0 else 16
	line_gap = max(19.0, line_gap)
	var baseline_y: float = start_y + float(row_index) * line_gap
	if baseline_y > rect.end.y - 8.0:
		return Rect2()
	var value_column_width := clampf(rect.size.x * 0.11, 76.0, 104.0)
	var bar_left: float = rect.position.x + 186.0 * ui_text_scale
	var bar_right: float = rect.end.x - value_column_width - 12.0
	return Rect2(
		bar_left,
		baseline_y - float(row_size) - 2.0,
		maxf(0.0, bar_right - bar_left),
		float(row_size) + 4.0
	)


# Draw only the predicted interval over the already-rendered current gauge.
# Geometry comes from the same helper used by draw_cached_player_stat_rows, so
# the overlay cannot drift to a separate row or scale contract.
static func draw_player_stat_preview_segment(
	canvas: CanvasItem,
	rect: Rect2,
	row_count: int,
	row_index: int,
	current_fill_ratio: float,
	projected_fill_ratio: float,
	ui_text_scale: float,
	blink_alpha: float = 1.0
) -> bool:
	if canvas == null:
		return false
	# The hover preview fades in and out instead of hard-toggling. A fully faded
	# frame must cost nothing, so bail before any geometry work.
	var fade: float = clampf(blink_alpha, 0.0, 1.0)
	if fade <= 0.004:
		return false
	var gauge_rect := player_stat_gauge_rect(rect, row_count, row_index, ui_text_scale)
	if gauge_rect.size.x < 70.0:
		return false
	var center_y := gauge_rect.get_center().y
	var left_x := gauge_rect.position.x + 5.0
	var right_x := gauge_rect.end.x - 5.0
	var current_x := lerpf(left_x, right_x, clampf(current_fill_ratio, 0.0, 1.0))
	var projected_x := lerpf(left_x, right_x, clampf(projected_fill_ratio, 0.0, 1.0))
	if projected_x <= current_x + 0.5:
		return false
	var glow_color := Color(0.23, 0.78, 0.82, 0.28 * fade)
	var segment_color := Color(0.12, 0.68, 0.76, 0.98 * fade)
	canvas.draw_line(Vector2(current_x, center_y), Vector2(projected_x, center_y), glow_color, 8.0, true)
	canvas.draw_line(Vector2(current_x, center_y), Vector2(projected_x, center_y), segment_color, 4.0, true)
	canvas.draw_line(Vector2(current_x, center_y - 1.0), Vector2(projected_x, center_y - 1.0), Color(0.80, 1.0, 0.96, 0.72 * fade), 1.0, true)
	CharacterInfoOverlayTextureDrawer.draw_empty_state_diamond(
		canvas,
		Vector2(projected_x, center_y),
		5.8,
		Color(0.22, 0.83, 0.84, 0.98 * fade)
	)
	return true


static func draw_lingpet_stat_rows(
	canvas: CanvasItem,
	font: Font,
	title: String,
	rows: Array,
	rect: Rect2,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	row_rects: Array,
	accent_blue: Color,
	text_dim: Color,
	empty_text_color: Color,
	ui_text_scale: float
) -> Dictionary:
	canvas.draw_rect(rect, Color(0.34, 0.27, 0.18, 0.045))
	var title_band := Rect2(rect.position, Vector2(rect.size.x, 30.0))
	canvas.draw_rect(title_band, Color(0.40, 0.31, 0.18, 0.075))
	canvas.draw_line(Vector2(rect.position.x + 2.0, title_band.end.y), Vector2(rect.end.x - 2.0, title_band.end.y), Color(0.43, 0.32, 0.17, 0.34), 1.0, true)
	CharacterInfoOverlayTextureDrawer.draw_empty_state_diamond(canvas, Vector2(rect.position.x + 8.0, rect.position.y + 15.0), 3.0, Color(0.55, 0.39, 0.18, 0.78))
	_draw_text_xy(canvas, font, title, rect.position.x + 17.0, rect.position.y + 23.0, 16, accent_blue, ui_text_scale)
	row_rects.clear()
	var row_count: int = rows.size()
	if row_count <= 0:
		_draw_text_centered_xy(canvas, font, "표시할 능력치 없음", rect.get_center().x, rect.get_center().y + 4.0, 12, empty_text_color, ui_text_scale)
		return hover_data
	var start_y: float = rect.position.y + 49.0
	var available_h: float = max(1.0, rect.end.y - start_y - 8.0)
	var line_gap: float = min(28.0, available_h / float(max(1, row_count)))
	var row_size: int = 14 if line_gap < 19.0 else 15 if line_gap < 23.0 else 16
	line_gap = max(19.0, line_gap)
	var label_x: float = rect.position.x + 2.0
	var value_right_x: float = rect.end.x - 2.0
	for i in range(row_count):
		var row_value: Variant = rows[i]
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var baseline_y: float = start_y + float(i) * line_gap
		if baseline_y > rect.end.y - 8.0:
			break
		var row_rect := Rect2(rect.position.x, baseline_y - float(row_size) - 5.0, rect.size.x, line_gap)
		row_rects.append(row_rect)
		canvas.draw_rect(row_rect, Color(0.46, 0.36, 0.22, 0.055 if i % 2 == 0 else 0.028))
		canvas.draw_line(Vector2(row_rect.position.x + 5.0, row_rect.end.y - 1.0), Vector2(row_rect.end.x - 5.0, row_rect.end.y - 1.0), Color(0.37, 0.28, 0.17, 0.19), 1.0, true)
		var label: String = str(row.get("label", ""))
		var value_text: String = str(row.get("value", ""))
		var value_color: Color = _get_color(row.get("color", Color.WHITE), Color.WHITE)
		if value_color.is_equal_approx(Color.WHITE):
			value_color = Color(0.12, 0.095, 0.065)
		var icon_kind: String = str(row.get("icon", ""))
		var label_draw_x: float = label_x
		if icon_kind != "":
			CharacterInfoOverlayTextureDrawer.draw_ui_glyph(canvas, Vector2(label_x + 6.0, baseline_y - float(row_size) * 0.38), 11.0, icon_kind, Color(text_dim.r, text_dim.g, text_dim.b, 0.85))
			label_draw_x += 19.0
		else:
			CharacterInfoOverlayTextureDrawer.draw_empty_state_diamond(canvas, Vector2(label_x + 6.0, baseline_y - float(row_size) * 0.38), 2.6, Color(0.53, 0.38, 0.18, 0.62))
			label_draw_x += 15.0
		_draw_text_xy(canvas, font, label, label_draw_x, baseline_y, row_size, text_dim, ui_text_scale)
		var value_width: float = _text_size(font, value_text, row_size, ui_text_scale).x
		var value_plate := Rect2(value_right_x - value_width - 8.0, baseline_y - float(row_size) - 3.0, value_width + 10.0, float(row_size) + 7.0)
		canvas.draw_rect(value_plate, Color(0.76, 0.68, 0.51, 0.22))
		canvas.draw_rect(value_plate, Color(0.43, 0.31, 0.16, 0.24), false, 1.0)
		_draw_text_xy(canvas, font, value_text, value_right_x - value_width, baseline_y, row_size, value_color, ui_text_scale)
		var tooltip_body: String = str(row.get("tooltip_body", ""))
		if tooltip_body != "" and row_rect.has_point(mouse_pos):
			_fill_hover_data(hover_data, str(row.get("tooltip_title", label)), str(row.get("tooltip_subtitle", value_text)), tooltip_body, value_color, row_rect)
	if row_count <= 2:
		var filler_top := start_y + float(row_count) * line_gap + 5.0
		var filler_rect := Rect2(rect.position.x + 12.0, filler_top, rect.size.x - 24.0, maxf(0.0, rect.end.y - filler_top - 8.0))
		_draw_lingpet_ledger_filler(canvas, filler_rect)
	return hover_data


static func player_stat_rows_visible_capacity(rect: Rect2, row_count: int) -> int:
	if row_count <= 0:
		return 0
	var start_y: float = rect.position.y + 49.0
	var available_h: float = maxf(1.0, rect.end.y - start_y - 8.0)
	var line_gap: float = minf(28.0, available_h / float(maxi(1, row_count)))
	line_gap = maxf(19.0, line_gap)
	var visible_count := 0
	for i in range(row_count):
		var baseline_y: float = start_y + float(i) * line_gap
		if baseline_y > rect.end.y - 8.0:
			break
		visible_count += 1
	return visible_count


static func _draw_lingpet_ledger_filler(canvas: CanvasItem, rect: Rect2) -> void:
	if rect.size.y < 28.0:
		return
	var center := rect.get_center()
	var radius := minf(27.0, minf(rect.size.x * 0.12, rect.size.y * 0.32))
	canvas.draw_arc(center, radius, 0.0, TAU, 40, Color(0.37, 0.29, 0.18, 0.12), 1.2, true)
	canvas.draw_arc(center, radius * 0.66, 0.0, TAU, 32, Color(0.19, 0.37, 0.33, 0.10), 1.0, true)
	CharacterInfoOverlayTextureDrawer.draw_ui_glyph(canvas, center, radius * 0.86, "seal", Color(0.42, 0.31, 0.17, 0.13))
	for rule_index in range(3):
		var rule_y := rect.position.y + 7.0 + float(rule_index) * 8.0
		canvas.draw_line(Vector2(rect.position.x + 4.0, rule_y), Vector2(center.x - radius - 12.0, rule_y), Color(0.40, 0.31, 0.20, 0.09), 1.0, true)
		canvas.draw_line(Vector2(center.x + radius + 12.0, rule_y), Vector2(rect.end.x - 4.0, rule_y), Color(0.40, 0.31, 0.20, 0.09), 1.0, true)


static func lingpet_stat_rows_visible_capacity(rect: Rect2, row_count: int) -> int:
	if row_count <= 0:
		return 0
	var start_y: float = rect.position.y + 49.0
	var available_h: float = max(1.0, rect.end.y - start_y - 8.0)
	var line_gap: float = min(28.0, available_h / float(max(1, row_count)))
	line_gap = max(19.0, line_gap)
	var visible_count := 0
	for i in range(row_count):
		var baseline_y: float = start_y + float(i) * line_gap
		if baseline_y > rect.end.y - 8.0:
			break
		visible_count += 1
	return visible_count


static func lingpet_stat_rect_for_sections(rect: Rect2) -> Rect2:
	var inner_rect := Rect2(rect.position.x + 12.0, rect.position.y + 38.0, rect.size.x - 24.0, rect.size.y - 50.0)
	var column_gap := 18.0
	if inner_rect.size.x >= 620.0:
		var column_w: float = (inner_rect.size.x - column_gap) * 0.5
		var player_rect := Rect2(inner_rect.position, Vector2(column_w, inner_rect.size.y))
		return Rect2(player_rect.end.x + column_gap, inner_rect.position.y, column_w, inner_rect.size.y)
	var row_gap := 10.0
	var row_h: float = (inner_rect.size.y - row_gap) * 0.5
	var stacked_player_rect := Rect2(inner_rect.position, Vector2(inner_rect.size.x, row_h))
	return Rect2(inner_rect.position.x, stacked_player_rect.end.y + row_gap, inner_rect.size.x, row_h)


static func draw_stat_sections(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	player_row_count: int,
	label_cache: Array,
	value_cache: Array,
	color_cache: Array,
	value_width_cache: Array,
	value_width_text_cache: Array,
	value_width_size_cache: Array,
	value_width_font_id_cache: Array,
	lingpet_rows: Array,
	mouse_pos: Vector2,
	hover_data: Dictionary,
	lingpet_row_rects: Array,
	accent_blue: Color,
	text_dim: Color,
	empty_text_color: Color,
	ui_text_scale: float
) -> Dictionary:
	var inner_rect := Rect2(rect.position.x + 12.0, rect.position.y + 38.0, rect.size.x - 24.0, rect.size.y - 50.0)
	var column_gap := 18.0
	var player_rect: Rect2
	var lingpet_rect: Rect2
	if inner_rect.size.x >= 620.0:
		var column_w: float = (inner_rect.size.x - column_gap) * 0.5
		player_rect = Rect2(inner_rect.position, Vector2(column_w, inner_rect.size.y))
		lingpet_rect = Rect2(player_rect.end.x + column_gap, inner_rect.position.y, column_w, inner_rect.size.y)
		var divider_x: float = player_rect.end.x + column_gap * 0.5
		canvas.draw_line(Vector2(divider_x, inner_rect.position.y + 2.0), Vector2(divider_x, inner_rect.end.y - 2.0), Color(78.0 / 255.0, 112.0 / 255.0, 165.0 / 255.0, 0.34), 1.0)
	else:
		var row_gap := 10.0
		var row_h: float = (inner_rect.size.y - row_gap) * 0.5
		player_rect = Rect2(inner_rect.position, Vector2(inner_rect.size.x, row_h))
		lingpet_rect = Rect2(inner_rect.position.x, player_rect.end.y + row_gap, inner_rect.size.x, row_h)
	# Lingpet rows draw first: their drawer clears the shared hover-rect list,
	# then the player rows append into it so mouse-motion redraw gating covers
	# both stat columns.
	hover_data = draw_lingpet_stat_rows(canvas, font, "수호령 능력치", lingpet_rows, lingpet_rect, mouse_pos, hover_data, lingpet_row_rects, accent_blue, text_dim, empty_text_color, ui_text_scale)
	return draw_cached_player_stat_rows(canvas, font, "플레이어 능력치", player_rect, player_row_count, label_cache, value_cache, color_cache, value_width_cache, value_width_text_cache, value_width_size_cache, value_width_font_id_cache, accent_blue, text_dim, empty_text_color, ui_text_scale, mouse_pos, hover_data, lingpet_row_rects)


static func build_overlay_player_stat_rows(
	target: Object,
	owner: Object,
	registry: Object,
	character_runtime: Object,
	runtime_state_override: Object,
	active_item_runtime_override: Object,
	mythic_item_runtime_override: Object,
	character_type_override: String,
	stat_sources_override: Array,
	write_row_cache: bool,
	active_item_slot_capacity_override: int,
	active_item_slots_override: Variant,
	row_count: int,
	row_cache: Array,
	label_cache: Array[String],
	value_cache: Array[String],
	color_cache: Array[Color],
	value_width_cache: Array[float],
	value_width_text_cache: Array[String],
	value_width_size_cache: Array[int],
	value_width_font_id_cache: Array[int],
	special_gauge_max: float,
	player_base_paddle_width: float,
	base_active_item_slot_count: int,
	stat_buff_color: Color,
	stat_debuff_color: Color,
	include_breakdown: bool = true
) -> Array:
	var rows: Array = build_player_stat_rows(owner, registry, character_runtime, runtime_state_override, active_item_runtime_override, mythic_item_runtime_override, character_type_override, stat_sources_override, active_item_slot_capacity_override, active_item_slots_override, special_gauge_max, player_base_paddle_width, base_active_item_slot_count, stat_buff_color, stat_debuff_color, include_breakdown)
	refresh_player_stat_cache(rows, row_count, write_row_cache, row_cache, label_cache, value_cache, color_cache, value_width_cache, value_width_text_cache, value_width_size_cache, value_width_font_id_cache)
	target.set("_stats_row_count", row_count)
	return row_cache


# Row icon kinds, refreshed alongside the label/value caches (single-instance
# overlay, so a presenter-level static avoids threading a new cache array
# through four call signatures).
static var _player_stat_icon_cache: Array[String] = []
static var _player_stat_tooltip_cache: Array[String] = []
# 소스별 증감 내역 행 (2026-07-12): 각 행은 {text, icon_id}. 툴팁 드로어가
# 아이콘 + "라벨: ±N%" 텍스트로 그린다 (본문 텍스트에는 더 이상 넣지 않는다).
static var _player_stat_breakdown_rows_cache: Array = []
# Gauge bar per row (2026-07-09 stats redesign): fill ratio (-1 = no bar) and fill
# color, computed at cache-refresh time so the draw loop stays allocation-free.
static var _player_stat_bar_fill_cache: Array[float] = []
static var _player_stat_bar_color_cache: Array[Color] = []

const STAT_BAR_NEUTRAL_COLOR := Color(0.055, 0.20, 0.28, 0.94)


# Base-anchored enhancement meter: the base value sits at 50% (5/10 cells), buffs
# fill right, debuffs drain left; lower-is-better stats invert so improvement always
# reads as MORE fill. Self-normalizing -- no per-stat range table needed.
static func stat_bar_fill_ratio(base_value: float, current_value: float, higher_is_better: bool) -> float:
	var safe_base: float = max(0.0001, base_value)
	var rel: float = current_value / safe_base
	var ratio: float = rel * 0.5 if higher_is_better else (2.0 - rel) * 0.5
	return clampf(ratio, 0.04, 1.0)


static func player_stat_row_fill_ratio(row: Dictionary) -> float:
	if row.has("bar_fill_ratio"):
		return clampf(float(row.get("bar_fill_ratio", 0.0)), 0.0, 1.0)
	if row.has("base") and row.has("current"):
		return stat_bar_fill_ratio(
			float(row.get("base", 0.0)),
			float(row.get("current", 0.0)),
			bool(row.get("higher_is_better", true))
		)
	return -1.0


# Tooltip breakdown line: current value vs base, signed delta, and whether the
# change is an improvement (covers lower-is-better stats honestly).
static func stat_bar_breakdown_text(base_value: float, current_value: float, higher_is_better: bool) -> String:
	var delta: float = current_value - base_value
	if absf(delta) <= 0.001:
		return "기본값 %s 그대로입니다." % _format_stat_number(base_value)
	var pct: int = int(round((current_value / max(0.0001, base_value) - 1.0) * 100.0))
	var pct_text: String = ("+%d" % pct) if pct >= 0 else str(pct)
	var improved: bool = delta > 0.0 if higher_is_better else delta < 0.0
	return "기본 %s → 현재 %s (%s%% · %s)" % [_format_stat_number(base_value), _format_stat_number(current_value), pct_text, "개선" if improved else "저하"]


# Compact number text for the breakdown line (no %g support in GDScript's format
# strings): integers stay bare, fractions keep up to two trimmed decimals.
static func _format_stat_number(value: float) -> String:
	if absf(value - roundf(value)) < 0.005:
		return str(int(roundf(value)))
	return ("%.2f" % value).rstrip("0").rstrip(".")


# 소스별 증감 내역을 구조화 행 배열 [{text, icon_id}]로 만든다. 툴팁 드로어가
# 각 행 앞에 원인 아이콘(퍽/아이템)을 그리고 "라벨: ±N%" 텍스트를 잇는다.
# 숫자가 붙은 합성 줄은 exact-map 번역을 통과하지 못하므로 정적 라벨 부분만
# 번역을 태운다 (이미 로컬라이즈된 아이템/퍽 라벨은 passthrough).
static func breakdown_rows_from_entries(entries_value: Variant) -> Array:
	var rows: Array = []
	if not (entries_value is Array):
		return rows
	for entry_value in (entries_value as Array):
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var label: String = LanguageSettings.translate_text(str(entry.get("label", "")))
		var icon_id: String = str(entry.get("icon_id", ""))
		var entry_text: String = str(entry.get("text", ""))
		if entry_text != "":
			rows.append({"text": "%s: %s" % [label, entry_text], "icon_id": icon_id})
			continue
		var pct: int = int(round((float(entry.get("ratio", 1.0)) - 1.0) * 100.0))
		if pct == 0:
			continue
		var pct_text: String = ("+%d" % pct) if pct > 0 else str(pct)
		rows.append({"text": "%s: %s%%" % [label, pct_text], "icon_id": icon_id})
	return rows


static func refresh_player_stat_cache(
	rows: Array,
	row_count: int,
	write_row_cache: bool,
	row_cache: Array,
	label_cache: Array[String],
	value_cache: Array[String],
	color_cache: Array[Color],
	value_width_cache: Array[float],
	value_width_text_cache: Array[String],
	value_width_size_cache: Array[int],
	value_width_font_id_cache: Array[int]
) -> void:
	while row_cache.size() < row_count:
		CharacterInfoOverlayValueUtils.append_empty_stats_row(row_cache, label_cache, value_cache, color_cache, value_width_cache, value_width_text_cache, value_width_size_cache, value_width_font_id_cache)
	if row_cache.size() > row_count:
		CharacterInfoOverlayValueUtils.resize_arrays([row_cache, label_cache, value_cache, color_cache, value_width_cache, value_width_text_cache, value_width_size_cache, value_width_font_id_cache], row_count)
	if _player_stat_icon_cache.size() != row_count:
		_player_stat_icon_cache.resize(row_count)
	if _player_stat_tooltip_cache.size() != row_count:
		_player_stat_tooltip_cache.resize(row_count)
	if _player_stat_breakdown_rows_cache.size() != row_count:
		_player_stat_breakdown_rows_cache.resize(row_count)
	if _player_stat_bar_fill_cache.size() != row_count:
		_player_stat_bar_fill_cache.resize(row_count)
	if _player_stat_bar_color_cache.size() != row_count:
		_player_stat_bar_color_cache.resize(row_count)
	for i in range(min(row_count, rows.size())):
		var row_data: Dictionary = CharacterInfoOverlayValueUtils.get_dict(rows[i])
		_player_stat_icon_cache[i] = str(row_data.get("icon", ""))
		var tooltip_text: String = LanguageSettings.translate_text(str(row_data.get("tooltip_body", "")))
		if row_data.has("bar_fill_ratio"):
			_player_stat_bar_fill_cache[i] = clampf(float(row_data.get("bar_fill_ratio", 0.0)), 0.0, 1.0)
			var bounded_row_color: Color = CharacterInfoOverlayValueUtils.get_color(row_data.get("color", Color.WHITE))
			_player_stat_bar_color_cache[i] = STAT_BAR_NEUTRAL_COLOR if bounded_row_color.is_equal_approx(Color.WHITE) else Color(bounded_row_color.r, bounded_row_color.g, bounded_row_color.b, 0.95)
			var bounded_summary := LanguageSettings.translate_text(str(row_data.get("tooltip_stat_summary", "")))
			if bounded_summary != "":
				if tooltip_text != "":
					tooltip_text += "\n"
				tooltip_text += bounded_summary
		elif row_data.has("base") and row_data.has("current"):
			var base_value: float = float(row_data.get("base", 0.0))
			var current_value: float = float(row_data.get("current", 0.0))
			var higher_is_better: bool = bool(row_data.get("higher_is_better", true))
			_player_stat_bar_fill_cache[i] = stat_bar_fill_ratio(base_value, current_value, higher_is_better)
			var row_color: Color = CharacterInfoOverlayValueUtils.get_color(row_data.get("color", Color.WHITE))
			_player_stat_bar_color_cache[i] = STAT_BAR_NEUTRAL_COLOR if row_color.is_equal_approx(Color.WHITE) else Color(row_color.r, row_color.g, row_color.b, 0.95)
			if tooltip_text != "":
				tooltip_text += "\n"
			tooltip_text += stat_bar_breakdown_text(base_value, current_value, higher_is_better)
		else:
			_player_stat_bar_fill_cache[i] = -1.0
			_player_stat_bar_color_cache[i] = STAT_BAR_NEUTRAL_COLOR
		_player_stat_tooltip_cache[i] = tooltip_text
		_player_stat_breakdown_rows_cache[i] = breakdown_rows_from_entries(row_data.get("breakdown"))
		var label: String = str(row_data.get("label", ""))
		var value_text: String = str(row_data.get("value", ""))
		var color: Color = CharacterInfoOverlayValueUtils.get_color(row_data.get("color", Color.WHITE))
		if write_row_cache:
			var row: Dictionary = row_cache[i]
			row["label"] = label
			row["value"] = value_text
			row["color"] = color
			if row_data.has("base"):
				row["base"] = float(row_data.get("base", 0.0))
				row["current"] = float(row_data.get("current", 0.0))
				row["higher_is_better"] = bool(row_data.get("higher_is_better", true))
			else:
				row.erase("base")
				row.erase("current")
				row.erase("higher_is_better")
			if row_data.has("breakdown"):
				row["breakdown"] = row_data.get("breakdown")
			else:
				row.erase("breakdown")
		label_cache[i] = label
		value_cache[i] = value_text
		color_cache[i] = color


static func effective_posture_correction_pct(runtime_state: Object, mythic_item_runtime: Object) -> float:
	if runtime_state != null and runtime_state.has_method("get_converted_perk_option_value"):
		return clampf(float(runtime_state.get_converted_perk_option_value("bulletproof_hat", "posture_correction_pct")), 0.0, 100.0)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_player_posture_correction_pct"):
		return clampf(float(mythic_item_runtime.get_player_posture_correction_pct()), 0.0, 100.0)
	return 0.0


static func _get_cached_value_width(font: Font, index: int, value_text: String, size: int, value_width_cache: Array, value_width_text_cache: Array, value_width_size_cache: Array, value_width_font_id_cache: Array, ui_text_scale: float) -> float:
	if font == null or value_text == "":
		return 0.0
	var font_id: int = font.get_instance_id()
	if index < value_width_cache.size() and value_width_text_cache[index] == value_text and int(value_width_size_cache[index]) == size and int(value_width_font_id_cache[index]) == font_id:
		return float(value_width_cache[index])
	var width := _text_size(font, value_text, size, ui_text_scale).x
	if index < value_width_cache.size():
		value_width_cache[index] = width
		value_width_text_cache[index] = value_text
		value_width_size_cache[index] = size
		value_width_font_id_cache[index] = font_id
	return width


static func _fill_hover_data(data: Dictionary, title: String, subtitle: String, body: String, color: Color, anchor_rect: Rect2) -> void:
	data.clear()
	data["title"] = title
	data["subtitle"] = subtitle
	data["body"] = body
	data["color"] = color
	data["anchor_rect"] = anchor_rect


static func _get_color(value: Variant, fallback: Color) -> Color:
	return value if value is Color else fallback


static func _draw_text_xy(canvas: CanvasItem, font: Font, text: String, baseline_x: float, baseline_y: float, size: int, color: Color, ui_text_scale: float) -> void:
	if text == "":
		return
	# draw_string과 픽셀 동일한 셰이핑 캐시 경로 (Font 내부 64-LRU 순환 축출 회피).
	CharacterInfoOverlayTextLineCache.draw_string_cached(canvas, font, Vector2(baseline_x, baseline_y), LanguageSettings.translate_text(text), _ui_font_size(size, ui_text_scale), color)


static func _draw_text_centered_xy(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int, color: Color, ui_text_scale: float) -> void:
	if text == "" or font == null:
		return
	var visible_text := LanguageSettings.translate_text(text)
	var text_size: Vector2 = _text_size(font, visible_text, size, ui_text_scale)
	CharacterInfoOverlayTextLineCache.draw_string_cached(canvas, font, Vector2(center_x - text_size.x * 0.5, center_y + text_size.y * 0.34), visible_text, _ui_font_size(size, ui_text_scale), color)


static func _text_size(font: Font, text: String, size: int, ui_text_scale: float) -> Vector2:
	if font == null or text == "":
		return Vector2.ZERO
	# get_string_size와 동일 값. 매 프레임 그려지는 행 텍스트라 셰이핑 캐시를 공유한다.
	return CharacterInfoOverlayTextLineCache.get_string_size_cached(font, text, _ui_font_size(size, ui_text_scale))


static func _ui_font_size(size: int, ui_text_scale: float) -> int:
	return max(1, int(round(float(size) * ui_text_scale)))


static func effective_max_gauge(owner_gauge_max: float, _stat_sources: Array, _apply_stat_chain: Callable) -> float:
	return maxf(1.0, owner_gauge_max)


static func effective_move_speed(
	character_type: String,
	character_runtime: Object,
	runtime_state: Object,
	smasher_recovery_state: Object,
	active_item_runtime: Object,
	mythic_item_runtime: Object,
	lingpet_runtime: Object,
	call_numeric_multiplier: Callable,
	additional_speed_sources: Array = []
) -> float:
	var movement_base: float = base_move_speed(character_type, character_runtime)
	if _is_horn_strawberry_transformed(mythic_item_runtime):
		var horn_move_speed: Variant = mythic_item_runtime.get_horn_strawberry_move_speed()
		if horn_move_speed != null:
			movement_base = maxf(0.0, float(horn_move_speed))
	return movement_base * effective_move_speed_multiplier(
		character_type,
		runtime_state,
		smasher_recovery_state,
		active_item_runtime,
		mythic_item_runtime,
		lingpet_runtime,
		call_numeric_multiplier,
		additional_speed_sources
	)


static func base_move_speed(character_type: String, character_runtime: Object) -> float:
	var config: Dictionary = character_runtime.get_base_movement_config(character_type) if character_runtime != null else {}
	return max(
		float(config.get("paddle_speed", 0.0)),
		float(config.get("paddle_max_speed", 0.0))
	)


static func effective_move_speed_multiplier(
	character_type: String,
	runtime_state: Object,
	smasher_recovery_state: Object,
	active_item_runtime: Object,
	mythic_item_runtime: Object,
	lingpet_runtime: Object,
	call_numeric_multiplier: Callable,
	additional_speed_sources: Array = []
) -> float:
	var multiplier: float = 1.0
	multiplier *= float(call_numeric_multiplier.call(runtime_state, "get_player_speed_multiplier"))
	if character_type == "smasher" and not _is_horn_strawberry_transformed(mythic_item_runtime):
		multiplier *= float(call_numeric_multiplier.call(smasher_recovery_state, "get_player_speed_multiplier"))
	for source: Object in additional_speed_sources:
		multiplier *= float(call_numeric_multiplier.call(source, "get_player_speed_multiplier"))
	multiplier *= float(call_numeric_multiplier.call(active_item_runtime, "get_player_speed_multiplier"))
	multiplier *= float(call_numeric_multiplier.call(mythic_item_runtime, "get_player_speed_multiplier"))
	multiplier *= float(call_numeric_multiplier.call(lingpet_runtime, "get_player_speed_multiplier"))
	return max(0.0, multiplier)


static func _is_horn_strawberry_transformed(mythic_item_runtime: Object) -> bool:
	return (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_horn_strawberry_transformed")
		and mythic_item_runtime.has_method("get_horn_strawberry_move_speed")
		and bool(mythic_item_runtime.is_horn_strawberry_transformed())
	)


static func effective_player_paddle_width(
	owner_width: float,
	runtime_scale_fallback: float,
	runtime_state: Object,
	active_item_runtime: Object,
	mythic_item_runtime: Object,
	call_numeric_multiplier: Callable,
	base_paddle_width: float
) -> float:
	var runtime_scale: float = runtime_paddle_scale(runtime_scale_fallback, runtime_state)
	var mythic_item_scale: float = float(call_numeric_multiplier.call(mythic_item_runtime, "get_player_paddle_scale"))
	var base_width: float = base_paddle_width * runtime_scale * mythic_item_scale
	var active_item_scale: float = float(call_numeric_multiplier.call(active_item_runtime, "get_player_paddle_scale"))
	var calculated_width: float = base_width
	if active_item_runtime != null and active_item_runtime.has_method("get_player_paddle_width"):
		calculated_width = max(1.0, float(active_item_runtime.get_player_paddle_width(base_width)))
	if abs(runtime_scale - 1.0) > 0.001 or abs(mythic_item_scale - 1.0) > 0.001 or abs(active_item_scale - 1.0) > 0.001:
		return calculated_width
	return max(1.0, owner_width if owner_width > 0.0 else calculated_width)


static func runtime_paddle_scale(runtime_scale_fallback: float, runtime_state: Object) -> float:
	if runtime_state != null and runtime_state.has_method("get_player_paddle_size_multiplier"):
		return max(0.1, float(runtime_state.get_player_paddle_size_multiplier()))
	return max(0.1, runtime_scale_fallback)


# 실전 히트 게이지 산식(paddle_bounce_event_router)의 그대로-호출 경로.
# collector에 Array를 주면 소스별 스텝이 기록된다.
static func effective_gauge_gain_per_hit(
	combo_state: Object,
	mythic_item_runtime: Object,
	lingpet_runtime: Object,
	horn_strawberry_transformed: bool = false,
	collector: Variant = null
) -> float:
	return max(0.0, PaddleBounceEventRouter.compute_gauge_gain_per_hit(
		BallUpdateStaticConfig.GAUGE_CHARGE_PER_HIT,
		combo_state,
		mythic_item_runtime,
		lingpet_runtime,
		horn_strawberry_transformed,
		collector
	))


# 실전 대시 지속 체인 + 감속 커브 적분으로 계산한 실제 이동 거리.
static func effective_dash_distance(
	runtime_perk_state: Object,
	registry: Object,
	mythic_item_runtime_override: Object = null
) -> float:
	var duration_frames: float = SmasherDashState.compute_dash_duration_frames(
		runtime_perk_state,
		registry,
		null,
		mythic_item_runtime_override
	)
	return max(1.0, SmasherDashActiveMotionResolver.compute_total_dash_distance(
		duration_frames,
		_mystic_dice_ratio(runtime_perk_state, "dash_distance")
	))


static func frames_to_seconds(frames: float) -> float:
	return CharacterInfoOverlayFormatter.frames_to_seconds(frames)
