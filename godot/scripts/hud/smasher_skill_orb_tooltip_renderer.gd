extends RefCounted

const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const SkillOrbTooltipEffectPreviewRenderer := preload("res://scripts/hud/skill_orb_tooltip_effect_preview_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")
const TowerCardAbsorptionTargetResolver := preload(
	"res://scripts/tower_ascent/tower_card_absorption_target_resolver.gd"
)

const TOOLTIP_WIDTH := 300.0
const HEADER_HEIGHT := 36.0
const EFFECT_PREVIEW_HEIGHT := 100.0
const PADDING := 12.0
const CONTROL_ROW_HEIGHT := 20.0
const COMMANDO_FIREARM_SELECTOR_OFFSET := Vector2(28.0, -64.0)
const COMMON_CONTROL_ROWS := {
	"soul_summon_art": [
		[["key", "Ctrl"], ["slash", "/"], ["key", "R3"], ["text", "소환·수납 전환"], ["accent", "발동"]],
	],
	"dalji_vision_chain_top": [
		[["key", "Shift"], ["plus", "+"], ["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "발동"]],
	],
	"cheongringwi_vision_dragon_torrent": [
		[["key", "Shift"], ["plus", "+"], ["key", "A"], ["arrow", "→"], ["key", "D"], ["arrow", "→"], ["key", "A"]],
		[["dim", "또는"], ["key", "←"], ["arrow", "→"], ["key", "→"], ["arrow", "→"], ["key", "←"], ["accent", "발동"]],
	],
	"yeonmyo_vision_bonghongwe": [
		[["key", "Shift"], ["plus", "+"], ["key", "S"], ["slash", "/"], ["key", "↓"], ["accent", "발동"]],
	],
}
const CONTROL_ROWS := {
	"plasma": [
		[["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "홀드 후 손 떼면 발동"]],
	],
	"recovery": [
		[["text", "활주 후딜 중"], ["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "발동"]],
	],
	"cleanse": [
		[["text", "상태이상 중"], ["key", "W"], ["accent", "발동"]],
	],
	"shield_kiting": [
		[["mouse_left", ""], ["accent", "더블클릭"], ["dim", "또는"], ["key", "SPACE"], ["accent", "더블탭"], ["text", "발동"]],
	],
	"drive": [
		[["key", "A"], ["slash", "/"], ["key", "D"], ["plus", "+"], ["mouse_left", ""], ["accent", "동시에 누르기"]],
	],
	"power_smashing": [
		[["key", "A"], ["slash", "/"], ["key", "D"], ["plus", "+"], ["mouse_left", ""], ["accent", "홀드 발동"]],
		[["text", "단독"], ["mouse_left", ""], ["text", "홀드 시 반대쪽 자동 발동"]],
	],
	"ghost_shot": [
		[["key", "A"], ["slash", "/"], ["key", "D"], ["plus", "+"], ["mouse_left", ""], ["accent", "홀드 발동"]],
	],
	"magnum_grip": [
		[["key", "←"], ["plus", "+"], ["key", "→"], ["dim", "또는"], ["key", "A"], ["plus", "+"], ["key", "D"], ["accent", "발동"]],
	],
	"warp_gate": [
		[["key", "S"], ["dim", "또는"], ["key", "↓"], ["accent", "0.5초 홀드 발동"]],
	],
	"smasher_wheel": [
		[["key", "A"], ["arrow", "→"], ["key", "W"], ["arrow", "→"], ["key", "D"], ["accent", "우회전 발동"]],
		[["key", "D"], ["arrow", "→"], ["key", "W"], ["arrow", "→"], ["key", "A"], ["accent", "좌회전 발동"]],
	],
	# 천뢰격(power_smashing)과 동일한 "방향키 + 버튼 홀드 → 타구 시점 발동" 계약이라
	# 행 구성/문구를 그대로 미러한다(좌클릭 → 우클릭만 교체). 재사용한 문구는 이미
	# EXACT_TEXT 전 언어에 등재돼 있어 신규 다국어 누락이 생기지 않는다.
	"smasher_overdrive": [
		[["key", "A"], ["slash", "/"], ["key", "D"], ["plus", "+"], ["mouse_right", ""], ["accent", "홀드 발동"]],
		[["text", "단독"], ["mouse_right", ""], ["text", "홀드 시 반대쪽 자동 발동"]],
	],
	# 접촉 발동은 입력만 보여 주면 즉시 시전으로 오해하기 쉽다. 기존 다국어
	# 토큰인 "받아치기"를 별도 맥락 행으로 두고, 실제 커맨드는 그 아래에 둔다.
	"void_phantom": [
		[["text", "받아치기"]],
		[["key", "S"], ["slash", "/"], ["key", "↓"], ["plus", "+"], ["mouse_left", ""], ["accent", "홀드 발동"]],
	],
}

const VIPER_CONTROL_ROWS := {
	"wall_leap_raid": [
		[["mouse_right", ""], ["text", "잠입"], ["dim", "기력 180 소모"]],
		[["mouse_left", ""], ["text", "참격"], ["dim", "추가 소모 없음 · 둔화 5초"]],
		[["mouse_right", ""], ["text", "폭발"], ["dim", "추가 소모 없음 · 기절 3초"]],
	],
	"shadow_step": [
		[["text", "활주 중/직후"], ["key", "S"], ["accent", "발동"]],
	],
	"blade_rush": [
		[["text", "체공 중"], ["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "발동"]],
	],
	"nerve_strike": [
		[["text", "블레이드 계열 사용 후"], ["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "발동"]],
	],
	"dive_strike": [
		[["text", "체공 중"], ["key", "S"], ["slash", "/"], ["key", "↓"], ["accent", "0.3초 홀드"]],
	],
	"marshal_kick": [
		[["text", "연계 후"], ["key", "S"], ["slash", "/"], ["key", "↓"], ["accent", "발동"]],
	],
	"phantom_kick": [
		[["text", "마샬 킥 적중 후"], ["key", "S"], ["slash", "/"], ["key", "↓"], ["accent", "발동"]],
	],
	"dark_blade": [
		[["text", "연계 타격 후 공중"], ["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "발동"]],
	],
	"chaos_spear": [
		[["key", "A"], ["arrow", "→"], ["key", "W"], ["arrow", "→"], ["key", "D"], ["accent", "발동"]],
	],
	"core_flip": [
		[["text", "활주 타격 후"], ["key", "A"], ["plus", "+"], ["key", "D"], ["accent", "발동"]],
	],
	"dual_glitch": [
		[["key", "A"], ["arrow", "→"], ["key", "D"], ["arrow", "→"], ["key", "A"], ["arrow", "→"], ["key", "D"]],
	],
	"ignition_aura": [
		[["text", "지상에서"], ["key", "W"], ["slash", "/"], ["key", "↑"], ["accent", "0.5초 홀드"]],
	],
}

const COMMANDO_CONTROL_ROWS := {
	"supply_drop": [
		[["key", "S"], ["slash", "/"], ["key", "↓"], ["dim", "또는"], ["mouse_right", ""], ["accent", "1초 홀드"]],
	],
	"emergency_supply": [
		[["text", "제자리에서"], ["key", "↓"], ["arrow", "→"], ["key", "↓"], ["accent", "발동"]],
	],
	"commando_pistol": [
		[["text", "무기 선택 후"], ["mouse_left", ""], ["dim", "또는"], ["key", "SPACE"]],
	],
	"bazooka": [
		[["text", "무기 선택 후"], ["mouse_left", ""], ["dim", "또는"], ["key", "SPACE"]],
	],
	"ak47": [
		[["text", "무기 선택 후"], ["mouse_left", ""], ["dim", "또는"], ["key", "SPACE"]],
	],
	"net_gun": [
		[["text", "무기 선택 후"], ["mouse_left", ""], ["dim", "또는"], ["key", "SPACE"]],
	],
	"fire_support": [
		[["text", "무기 선택 후"], ["mouse_left", ""], ["dim", "또는"], ["key", "SPACE"]],
	],
	"bowling_trap": [
		[["text", "무기 선택 후"], ["mouse_left", ""], ["dim", "또는"], ["key", "SPACE"]],
	],
	"suicide_drone": [
		[["text", "무기 선택 후"], ["mouse_left", ""], ["dim", "또는"], ["key", "SPACE"]],
	],
}

const ODINS_EYE_CONTROL_ROWS := {
	"odins_eye_dark_swamp": [
		[["text", "변신 중"], ["mouse_left", ""], ["accent", "좌클릭 발동"]],
	],
}

const HORN_STRAWBERRY_CONTROL_ROWS := {
	"horn_strawberry_horn_charge": [
		[["key", "W"], ["accent", "발동"]],
	],
	"horn_strawberry_field": [
		[["key", "S"], ["accent", "1초 유지"]],
	],
	"horn_strawberry_eat": [
		[["key", "SPACE"], ["dim", "또는"], ["mouse_left", ""], ["accent", "발동"]],
	],
	"horn_strawberry_bomb": [
		[["key", "A"], ["plus", "+"], ["key", "D"], ["accent", "0.5초 유지"]],
	],
}

var layout_helper: Object = Stage1PillarUiLayout.new()
var fallback_orb_renderer: Object = SmasherSkillOrbRenderer.new()
var character_runtime: Object = PlayerCharacterRuntime.new()
var effect_preview_renderer: Object = SkillOrbTooltipEffectPreviewRenderer.new()
var tooltip_hover_active := false
var tooltip_hover_skill_name := ""


func draw(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary, scene_context: Dictionary) -> void:
	if canvas == null or registry == null:
		return

	var hover_state: Dictionary = update_hover_state(canvas, registry, view_size, layout, scene_context)
	if hover_state.is_empty():
		return
	if str(hover_state.get("hover_type", "skill_orb")) == "commando_firearm":
		var firearm_tooltip_renderer: Object = _get_dictionary(hover_state.get("hover_context", {})).get("commando_firearm_tooltip_renderer", null)
		if firearm_tooltip_renderer != null and firearm_tooltip_renderer.has_method("draw"):
			firearm_tooltip_renderer.draw(canvas, _get_dictionary(hover_state.get("tooltip_state", {})))
		return

	_draw_tooltip(
		canvas,
		_get_dictionary(hover_state.get("hover_context", {})),
		_get_dictionary(hover_state.get("skill_data", {}))
	)


# Tower start/reward cards reuse this renderer rather than growing a second
# Chosik tooltip. The card can advertise a skill that is not equipped yet, so
# this path resolves the canonical skill_data map directly instead of using the
# equipped-orb-only hover lookup.
func draw_card_tooltip(
	canvas: CanvasItem,
	registry: Object,
	fallback_view_size: Vector2,
	scene_context: Dictionary,
	choice: Dictionary,
	card_rect: Rect2,
	avoid_rects: Array,
	mouse_pos: Vector2
) -> void:
	var state := build_card_tooltip_state(
		canvas,
		registry,
		fallback_view_size,
		scene_context,
		choice,
		card_rect,
		avoid_rects,
		mouse_pos
	)
	if state.is_empty():
		return
	_draw_tooltip(
		canvas,
		_get_dictionary(state.get("hover_context", {})),
		_get_dictionary(state.get("skill_data", {}))
	)


func build_card_tooltip_state(
	canvas: CanvasItem,
	registry: Object,
	fallback_view_size: Vector2,
	scene_context: Dictionary,
	choice: Dictionary,
	card_rect: Rect2,
	avoid_rects: Array,
	mouse_pos: Vector2
) -> Dictionary:
	if (
		canvas == null
		or registry == null
		or card_rect.size.x <= 0.0
		or card_rect.size.y <= 0.0
		or not card_rect.has_point(mouse_pos)
		or not TowerCardAbsorptionTargetResolver.is_chosik_choice(choice)
	):
		return {}
	var skill_name := str(choice.get("unlocks_skill", "")).strip_edges()
	if skill_name.is_empty():
		return {}

	var view_size := resolve_card_tooltip_view_size(canvas, fallback_view_size)
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return {}
	var fullscreen_layout := {
		"game_offset": Vector2.ZERO,
		"game_size": view_size,
	}
	var tooltip_scene_context := scene_context.duplicate(true)
	tooltip_scene_context["height"] = view_size.y
	var hover_context := _build_hover_context(
		canvas,
		registry,
		view_size,
		fullscreen_layout,
		tooltip_scene_context
	)
	if hover_context.is_empty():
		return {}
	var snapshot := _get_dictionary(hover_context.get("skill_config_snapshot", {}))
	var skill_data_map := _get_dictionary(snapshot.get("skill_data", {}))
	if not skill_data_map.has(skill_name):
		return {}
	var skill_data := _get_dictionary(skill_data_map.get(skill_name, {})).duplicate(true)
	if skill_data.is_empty():
		return {}
	skill_data["slot_rect"] = card_rect
	hover_context["mouse_pos"] = mouse_pos
	hover_context["view_size"] = view_size
	hover_context["card_tooltip_mode"] = true
	hover_context["card_tooltip_anchor_rect"] = card_rect
	hover_context["card_tooltip_avoid_rects"] = avoid_rects.duplicate()

	var metrics := _build_tooltip_metrics(hover_context, skill_data)
	if metrics.is_empty():
		return {}
	var tooltip_size := Vector2(
		float(metrics.get("tooltip_width", 0.0)),
		float(metrics.get("tooltip_height", 0.0))
	)
	var tooltip_position := _get_tooltip_position(
		hover_context,
		tooltip_size.x,
		tooltip_size.y,
		float(metrics.get("scale_factor", 1.0))
	)
	return {
		"hover_context": hover_context,
		"skill_data": skill_data,
		"tooltip_rect": Rect2(tooltip_position, tooltip_size),
	}


# GRT-044: fullscreen card overlays use the live viewport while their canvas is
# in the tree. The supplied size remains a deterministic fallback for isolated
# layout tests and pre-tree callers only.
func resolve_card_tooltip_view_size(canvas: CanvasItem, fallback_view_size: Vector2) -> Vector2:
	if canvas != null and canvas.is_inside_tree():
		var viewport_size := canvas.get_viewport_rect().size
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			return viewport_size
	return fallback_view_size


func update_hover_state(canvas: CanvasItem, registry: Object, view_size: Vector2, layout: Dictionary, scene_context: Dictionary) -> Dictionary:
	tooltip_hover_active = false
	tooltip_hover_skill_name = ""
	if canvas == null or registry == null:
		return {}

	var hover_context: Dictionary = _build_hover_context(canvas, registry, view_size, layout, scene_context)
	if hover_context.is_empty():
		return {}

	var gamepad_skill_name: String = _get_gamepad_selected_skill_name(registry)
	if gamepad_skill_name != "":
		var selected_skill_data: Dictionary = _find_skill_by_name(hover_context, gamepad_skill_name)
		if not selected_skill_data.is_empty():
			var selected_rect: Rect2 = _get_rect2(selected_skill_data.get("slot_rect", Rect2()), Rect2())
			if selected_rect.size != Vector2.ZERO:
				hover_context["mouse_pos"] = selected_rect.position + selected_rect.size * 0.5
			tooltip_hover_active = true
			tooltip_hover_skill_name = str(selected_skill_data.get("name", gamepad_skill_name))
			return {
				"hover_type": "skill_orb",
				"hover_context": hover_context,
				"skill_data": selected_skill_data,
			}

	var skill_data: Dictionary = _find_hovered_skill(hover_context)
	if skill_data.is_empty():
		var firearm_tooltip_state: Dictionary = _find_hovered_commando_firearm(hover_context)
		if firearm_tooltip_state.is_empty():
			return {}
		tooltip_hover_active = true
		tooltip_hover_skill_name = str(firearm_tooltip_state.get("tooltip_key", "commando_firearm"))
		return {
			"hover_type": "commando_firearm",
			"hover_context": hover_context,
			"tooltip_state": firearm_tooltip_state,
		}

	tooltip_hover_active = true
	tooltip_hover_skill_name = str(skill_data.get("name", ""))
	return {
		"hover_type": "skill_orb",
		"hover_context": hover_context,
		"skill_data": skill_data,
	}


func is_tooltip_active() -> bool:
	return tooltip_hover_active


func _build_hover_context(
	canvas: CanvasItem,
	registry: Object,
	view_size: Vector2,
	layout: Dictionary,
	scene_context: Dictionary
) -> Dictionary:
	var character_type: String = character_runtime.normalize(scene_context.get("selected_character_type", "smasher"))
	var skill_config: Object = _get_instance(registry, character_runtime.get_skill_config_key(character_type))
	if skill_config == null or not skill_config.has_method("get_snapshot"):
		return {}
	var is_commando: bool = character_runtime.is_commando(character_type)

	var game_offset: Vector2 = _get_vector2(layout, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout, "game_size", Vector2(760.0, 750.0))
	var ui_layout: Dictionary = layout_helper.build_layout(game_offset, game_size, {
		"height": float(scene_context.get("height", 750.0)),
	})
	var scale_factor: float = float(ui_layout.get("scale_factor", 1.0))
	var snapshot: Dictionary = skill_config.get_snapshot()
	var textures: Dictionary = _get_dictionary(scene_context.get("textures", {}))
	var max_skill_slots: int = int(snapshot.get("max_slots", 5))
	var skill_cluster_frame_key: String = character_runtime.get_skill_cluster_frame_texture_key(character_type, max_skill_slots)
	var skill_orb_context: Dictionary = layout_helper.build_skill_orb_context({
		"cluster_frame_texture": textures.get(skill_cluster_frame_key, null),
		"cluster_frame_slots": max_skill_slots,
		"skill_orb_frame_texture": textures.get("skill_orb_frame_texture", null),
		"skill_icons": scene_context.get("skill_icons", {}),
		"skill_state": _get_instance(registry, character_runtime.get_skill_state_key(character_type)),
		"special_gauge": scene_context.get("special_gauge", 0.0),
		"selected_character_type": character_type,
		"skill_config_snapshot": snapshot,
	}, _get_instance(registry, "pillar_orb_drawer"))
	var orb_renderer: Object = _get_instance(registry, "smasher_skill_orb_renderer")
	if orb_renderer == null or not orb_renderer.has_method("get_slot_positions"):
		orb_renderer = fallback_orb_renderer
	var horn_strawberry_context: Dictionary = _get_horn_strawberry_context(registry, scene_context)
	var horn_strawberry_skill_renderer: Object = _get_instance(registry, "horn_strawberry_skill_pillar_renderer")
	var horn_strawberry_active: bool = _is_horn_strawberry_skill_hud_active(
		horn_strawberry_skill_renderer,
		horn_strawberry_context
	)
	if horn_strawberry_active and horn_strawberry_skill_renderer.has_method("build_skill_orb_context"):
		orb_renderer = horn_strawberry_skill_renderer
		skill_orb_context = horn_strawberry_skill_renderer.build_skill_orb_context(
			horn_strawberry_context,
			float(scene_context.get("special_gauge", 0.0)),
			_get_instance(registry, "pillar_orb_drawer"),
			skill_orb_context
		)
	# 오딘의 눈 변신(혼딸기 형제 계약, 혼딸기 선순위): 변신 중 툴팁 hover는
	# 늪 오브 렌더러가 소유한다 — 이 분기가 없으면 그려지지 않는 일반
	# 클러스터 위치로 hover가 해석돼 "드라이브" 유령 툴팁이 뜬다(2026-07-21).
	var odins_eye_context: Dictionary = _get_odins_eye_context(registry, scene_context)
	var odins_eye_skill_renderer: Object = _get_instance(registry, "odins_eye_skill_pillar_renderer")
	var odins_eye_active: bool = (
		not horn_strawberry_active
		and _is_odins_eye_skill_hud_active(odins_eye_skill_renderer, odins_eye_context)
	)
	if odins_eye_active and odins_eye_skill_renderer.has_method("build_skill_orb_context"):
		orb_renderer = odins_eye_skill_renderer
		skill_orb_context = odins_eye_skill_renderer.build_skill_orb_context(
			odins_eye_context,
			float(scene_context.get("special_gauge", 0.0)),
			_get_instance(registry, "pillar_orb_drawer"),
			skill_orb_context
		)
	var baekrin_mount_context: Dictionary = _get_baekrin_mount_context(registry, scene_context)
	var baekrin_mount_skill_renderer: Object = _get_instance(registry, "baekrin_mount_skill_pillar_renderer")
	var baekrin_mount_active: bool = (
		not horn_strawberry_active
		and not odins_eye_active
		and _is_baekrin_mount_skill_hud_active(baekrin_mount_skill_renderer, baekrin_mount_context)
	)
	if baekrin_mount_active and baekrin_mount_skill_renderer.has_method("build_skill_orb_context"):
		orb_renderer = baekrin_mount_skill_renderer
		skill_orb_context = baekrin_mount_skill_renderer.build_skill_orb_context(
			baekrin_mount_context,
			float(scene_context.get("special_gauge", 0.0)),
			_get_instance(registry, "pillar_orb_drawer"),
			skill_orb_context
		)
	var commando_firearm_runtime: Object = _get_instance(registry, "commando_firearm_runtime") if is_commando else null
	var commando_firearm_context: Dictionary = {}
	if commando_firearm_runtime != null and commando_firearm_runtime.has_method("get_actor_draw_context"):
		commando_firearm_context = commando_firearm_runtime.get_actor_draw_context()

	return {
		"mouse_pos": canvas.get_viewport().get_mouse_position(),
		"view_size": view_size,
		"game_offset": game_offset,
		"game_size": game_size,
		"scale_factor": scale_factor,
		"selected_character_type": character_type,
		"left_center": _get_vector2(ui_layout, "left_center", Vector2.ZERO),
		"orb_radius": float(ui_layout.get("orb_radius", 55.0)),
		"skill_context": skill_orb_context,
		"skill_config_snapshot": snapshot,
		"skill_state": _get_instance(registry, character_runtime.get_skill_state_key(character_type)),
		"runtime_perk_state": _get_instance(registry, "runtime_perk_state"),
		"commando_weapon_controller": _get_instance(registry, "commando_weapon_controller") if is_commando else null,
		"commando_firearm_selector_renderer": _get_instance(registry, "commando_firearm_selector_renderer") if is_commando else null,
		"commando_firearm_tooltip_renderer": _get_instance(registry, "commando_firearm_tooltip_renderer") if is_commando else null,
		"commando_firearm_slingshot_state": _get_dictionary(commando_firearm_context.get("commando_firearm_slingshot_state", scene_context.get("commando_firearm_slingshot_state", {}))),
		"commando_firearm_pistol_state": _get_dictionary(commando_firearm_context.get("commando_firearm_pistol_state", scene_context.get("commando_firearm_pistol_state", {}))),
		"special_gauge": float(scene_context.get("special_gauge", 0.0)),
		"orb_renderer": orb_renderer,
		"horn_strawberry_active": horn_strawberry_active,
		"horn_strawberry_context": horn_strawberry_context,
		"horn_strawberry_skill_pillar_renderer": horn_strawberry_skill_renderer,
		"odins_eye_active": odins_eye_active,
		"odins_eye_context": odins_eye_context,
		"odins_eye_skill_pillar_renderer": odins_eye_skill_renderer,
		"baekrin_mount_active": baekrin_mount_active,
		"baekrin_mount_context": baekrin_mount_context,
		"baekrin_mount_skill_pillar_renderer": baekrin_mount_skill_renderer,
	}


func _find_hovered_skill(hover_context: Dictionary) -> Dictionary:
	var skill_context: Dictionary = _get_dictionary(hover_context.get("skill_context", {}))
	if bool(hover_context.get("horn_strawberry_active", false)):
		var horn_renderer: Object = hover_context.get("horn_strawberry_skill_pillar_renderer", null)
		if horn_renderer != null and horn_renderer.has_method("find_hovered_skill"):
			return horn_renderer.find_hovered_skill(
				_get_vector2(hover_context, "mouse_pos", Vector2.ZERO),
				_get_vector2(hover_context, "left_center", Vector2.ZERO),
				float(hover_context.get("orb_radius", 55.0)),
				float(hover_context.get("scale_factor", 1.0)),
				skill_context
			)
		return {}
	if bool(hover_context.get("odins_eye_active", false)):
		# 변신 중에는 늪 오브 렌더러가 hover를 소유하고, 미스 시 {}로 끝낸다
		# — 일반 클러스터 폴스루가 유령 툴팁을 만든다.
		var odins_renderer: Object = hover_context.get("odins_eye_skill_pillar_renderer", null)
		if odins_renderer != null and odins_renderer.has_method("find_hovered_skill"):
			return odins_renderer.find_hovered_skill(
				_get_vector2(hover_context, "mouse_pos", Vector2.ZERO),
				_get_vector2(hover_context, "left_center", Vector2.ZERO),
				float(hover_context.get("orb_radius", 55.0)),
				float(hover_context.get("scale_factor", 1.0)),
				skill_context
			)
		return {}
	if bool(hover_context.get("baekrin_mount_active", false)):
		var mount_renderer: Object = hover_context.get("baekrin_mount_skill_pillar_renderer", null)
		if mount_renderer != null and mount_renderer.has_method("find_hovered_skill"):
			return mount_renderer.find_hovered_skill(
				_get_vector2(hover_context, "mouse_pos", Vector2.ZERO),
				_get_vector2(hover_context, "left_center", Vector2.ZERO),
				float(hover_context.get("orb_radius", 55.0)),
				float(hover_context.get("scale_factor", 1.0)),
				skill_context
			)
		return {}
	var snapshot: Dictionary = _get_dictionary(hover_context.get("skill_config_snapshot", {}))
	var equipped_skills: Array = _get_array(snapshot.get("equipped_skills", []))
	var skill_data_map: Dictionary = _get_dictionary(snapshot.get("skill_data", {}))
	if equipped_skills.is_empty() or skill_data_map.is_empty():
		return {}

	var scale_factor: float = float(hover_context.get("scale_factor", 1.0))
	var icon_radius: float = float(skill_context.get("skill_orb_radius", 24.0)) * scale_factor
	var orb_renderer: Object = hover_context.get("orb_renderer", null)
	if orb_renderer == null or not orb_renderer.has_method("get_slot_positions"):
		return {}

	var positions: Array = orb_renderer.get_slot_positions(
		_get_vector2(hover_context, "left_center", Vector2.ZERO),
		float(hover_context.get("orb_radius", 55.0)),
		scale_factor,
		skill_context
	)
	var mouse_pos: Vector2 = _get_vector2(hover_context, "mouse_pos", Vector2.ZERO)
	var equipped_count: int = min(equipped_skills.size(), positions.size())
	for i in range(equipped_count):
		var skill_name: String = str(equipped_skills[i])
		if not skill_data_map.has(skill_name):
			continue
		var rect := Rect2(
			positions[i] - Vector2(icon_radius, icon_radius),
			Vector2(icon_radius * 2.0, icon_radius * 2.0)
		)
		if rect.has_point(mouse_pos):
			var data: Dictionary = _get_dictionary(skill_data_map.get(skill_name, {})).duplicate(true)
			data["slot_rect"] = rect
			return data
	return {}


func _find_skill_by_name(hover_context: Dictionary, target_skill_name: String) -> Dictionary:
	if target_skill_name == "":
		return {}
	if bool(hover_context.get("horn_strawberry_active", false)):
		return _find_horn_strawberry_skill_by_name(hover_context, target_skill_name)
	if bool(hover_context.get("odins_eye_active", false)):
		return _find_odins_eye_skill_by_name(hover_context, target_skill_name)
	if bool(hover_context.get("baekrin_mount_active", false)):
		return _find_replacement_skill_by_name(
			hover_context,
			target_skill_name,
			"baekrin_mount_skill_pillar_renderer"
		)
	var snapshot: Dictionary = _get_dictionary(hover_context.get("skill_config_snapshot", {}))
	var equipped_skills: Array = _get_array(snapshot.get("equipped_skills", []))
	var skill_data_map: Dictionary = _get_dictionary(snapshot.get("skill_data", {}))
	if equipped_skills.is_empty() or not skill_data_map.has(target_skill_name):
		return {}
	var skill_context: Dictionary = _get_dictionary(hover_context.get("skill_context", {}))
	var scale_factor: float = float(hover_context.get("scale_factor", 1.0))
	var orb_renderer: Object = hover_context.get("orb_renderer", null)
	if orb_renderer == null or not orb_renderer.has_method("get_slot_positions"):
		return {}
	var positions: Array = orb_renderer.get_slot_positions(
		_get_vector2(hover_context, "left_center", Vector2.ZERO),
		float(hover_context.get("orb_radius", 55.0)),
		scale_factor,
		skill_context
	)
	var icon_radius: float = float(skill_context.get("skill_orb_radius", 24.0)) * scale_factor
	var equipped_count: int = min(equipped_skills.size(), positions.size())
	for i in range(equipped_count):
		var skill_name: String = str(equipped_skills[i])
		if skill_name != target_skill_name:
			continue
		var slot_center: Vector2 = _get_vector2_from_variant(positions[i], Vector2.ZERO)
		var rect := Rect2(
			slot_center - Vector2(icon_radius, icon_radius),
			Vector2(icon_radius * 2.0, icon_radius * 2.0)
		)
		var data: Dictionary = _get_dictionary(skill_data_map.get(skill_name, {})).duplicate(true)
		data["slot_rect"] = rect
		return data
	return {}


func _find_horn_strawberry_skill_by_name(hover_context: Dictionary, target_skill_name: String) -> Dictionary:
	var horn_renderer: Object = hover_context.get("horn_strawberry_skill_pillar_renderer", null)
	if (
		horn_renderer == null
		or not horn_renderer.has_method("get_skill_order")
		or not horn_renderer.has_method("get_skill_data_map")
		or not horn_renderer.has_method("get_slot_positions")
	):
		return {}
	var data_map: Dictionary = _get_dictionary(horn_renderer.get_skill_data_map())
	if not data_map.has(target_skill_name):
		return {}
	var order: Array = _get_array(horn_renderer.get_skill_order())
	var target_index := -1
	for i in range(order.size()):
		if str(order[i]) == target_skill_name:
			target_index = i
			break
	if target_index < 0:
		return {}
	var skill_context: Dictionary = _get_dictionary(hover_context.get("skill_context", {}))
	var scale_factor: float = float(hover_context.get("scale_factor", 1.0))
	var positions: Array = horn_renderer.get_slot_positions(
		_get_vector2(hover_context, "left_center", Vector2.ZERO),
		float(hover_context.get("orb_radius", 55.0)),
		scale_factor,
		skill_context
	)
	if target_index >= positions.size():
		return {}
	var icon_radius: float = float(skill_context.get("skill_orb_radius", 24.0)) * scale_factor
	var slot_center: Vector2 = _get_vector2_from_variant(positions[target_index], Vector2.ZERO)
	var rect := Rect2(
		slot_center - Vector2(icon_radius, icon_radius),
		Vector2(icon_radius * 2.0, icon_radius * 2.0)
	)
	var data: Dictionary = _get_dictionary(data_map.get(target_skill_name, {})).duplicate(true)
	data["slot_rect"] = rect
	return data


func _find_odins_eye_skill_by_name(hover_context: Dictionary, target_skill_name: String) -> Dictionary:
	var odins_renderer: Object = hover_context.get("odins_eye_skill_pillar_renderer", null)
	if (
		odins_renderer == null
		or not odins_renderer.has_method("get_skill_order")
		or not odins_renderer.has_method("get_skill_data_map")
		or not odins_renderer.has_method("get_slot_positions")
	):
		return {}
	var data_map: Dictionary = _get_dictionary(odins_renderer.get_skill_data_map())
	if not data_map.has(target_skill_name):
		return {}
	var order: Array = _get_array(odins_renderer.get_skill_order())
	var target_index := -1
	for i in range(order.size()):
		if str(order[i]) == target_skill_name:
			target_index = i
			break
	if target_index < 0:
		return {}
	var skill_context: Dictionary = _get_dictionary(hover_context.get("skill_context", {}))
	var scale_factor: float = float(hover_context.get("scale_factor", 1.0))
	var positions: Array = odins_renderer.get_slot_positions(
		_get_vector2(hover_context, "left_center", Vector2.ZERO),
		float(hover_context.get("orb_radius", 55.0)),
		scale_factor,
		skill_context
	)
	if target_index >= positions.size():
		return {}
	var icon_radius: float = float(skill_context.get("skill_orb_radius", 24.0)) * scale_factor
	var slot_center: Vector2 = _get_vector2_from_variant(positions[target_index], Vector2.ZERO)
	var rect := Rect2(
		slot_center - Vector2(icon_radius, icon_radius),
		Vector2(icon_radius * 2.0, icon_radius * 2.0)
	)
	var data: Dictionary = _get_dictionary(data_map.get(target_skill_name, {})).duplicate(true)
	data["slot_rect"] = rect
	return data


func _find_replacement_skill_by_name(
	hover_context: Dictionary,
	target_skill_name: String,
	renderer_key: String
) -> Dictionary:
	var renderer: Object = hover_context.get(renderer_key, null)
	if (
		renderer == null
		or not renderer.has_method("get_skill_order")
		or not renderer.has_method("get_skill_data_map")
		or not renderer.has_method("get_slot_positions")
	):
		return {}
	var data_map: Dictionary = _get_dictionary(renderer.get_skill_data_map())
	if not data_map.has(target_skill_name):
		return {}
	var order: Array = _get_array(renderer.get_skill_order())
	var target_index := order.find(target_skill_name)
	if target_index < 0:
		return {}
	var skill_context: Dictionary = _get_dictionary(hover_context.get("skill_context", {}))
	var scale_factor := float(hover_context.get("scale_factor", 1.0))
	var positions: Array = renderer.get_slot_positions(
		_get_vector2(hover_context, "left_center", Vector2.ZERO),
		float(hover_context.get("orb_radius", 55.0)),
		scale_factor,
		skill_context
	)
	if target_index >= positions.size():
		return {}
	var icon_radius := float(skill_context.get("skill_orb_radius", 24.0)) * scale_factor
	var slot_center := _get_vector2_from_variant(positions[target_index], Vector2.ZERO)
	var data: Dictionary = _get_dictionary(data_map.get(target_skill_name, {})).duplicate(true)
	data["slot_rect"] = Rect2(
		slot_center - Vector2(icon_radius, icon_radius),
		Vector2(icon_radius * 2.0, icon_radius * 2.0)
	)
	return data


func _find_hovered_commando_firearm(hover_context: Dictionary) -> Dictionary:
	if bool(hover_context.get("horn_strawberry_active", false)) or bool(hover_context.get("baekrin_mount_active", false)):
		return {}
	if bool(hover_context.get("odins_eye_active", false)):
		return {}
	if str(hover_context.get("selected_character_type", "")) != "soldier":
		return {}
	var selector_renderer: Object = hover_context.get("commando_firearm_selector_renderer", null)
	var tooltip_renderer: Object = hover_context.get("commando_firearm_tooltip_renderer", null)
	var weapon_controller: Object = hover_context.get("commando_weapon_controller", null)
	if (
		selector_renderer == null
		or tooltip_renderer == null
		or weapon_controller == null
		or not selector_renderer.has_method("build_panel_state")
		or not tooltip_renderer.has_method("build_hover_state")
	):
		return {}
	var panel_state: Dictionary = _build_commando_firearm_panel_state(hover_context, selector_renderer, weapon_controller)
	if panel_state.is_empty():
		return {}
	return tooltip_renderer.build_hover_state(
		panel_state,
		_get_vector2(hover_context, "view_size", Vector2(1488.0, 918.0)),
		float(hover_context.get("scale_factor", 1.0)),
		{
			"mouse_pos": _get_vector2(hover_context, "mouse_pos", Vector2.ZERO),
			"commando_weapon_controller": weapon_controller,
			"skill_config_snapshot": _get_dictionary(hover_context.get("skill_config_snapshot", {})),
			"commando_firearm_slingshot_state": _get_dictionary(hover_context.get("commando_firearm_slingshot_state", {})),
			"commando_firearm_pistol_state": _get_dictionary(hover_context.get("commando_firearm_pistol_state", {})),
		}
	)


func _build_commando_firearm_panel_state(hover_context: Dictionary, selector_renderer: Object, weapon_controller: Object) -> Dictionary:
	var skill_context: Dictionary = _get_dictionary(hover_context.get("skill_context", {}))
	var orb_renderer: Object = hover_context.get("orb_renderer", null)
	var scale_factor: float = float(hover_context.get("scale_factor", 1.0))
	var left_center: Vector2 = _get_vector2(hover_context, "left_center", Vector2.ZERO)
	var orb_radius: float = float(hover_context.get("orb_radius", 55.0))
	var panel_center := left_center + Vector2(28.0, -180.0) * scale_factor
	if orb_renderer != null and orb_renderer.has_method("get_cluster_bounds"):
		var cluster_bounds: Rect2 = orb_renderer.get_cluster_bounds(left_center, orb_radius, scale_factor, skill_context)
		if cluster_bounds.size.x > 0.0 and cluster_bounds.size.y > 0.0:
			panel_center = Vector2(
				cluster_bounds.position.x + cluster_bounds.size.x * 0.5,
				cluster_bounds.position.y
			) + COMMANDO_FIREARM_SELECTOR_OFFSET * scale_factor
	return selector_renderer.build_panel_state(
		panel_center,
		scale_factor,
		{
			"commando_weapon_controller": weapon_controller,
			"commando_firearm_slingshot_state": _get_dictionary(hover_context.get("commando_firearm_slingshot_state", {})),
			"commando_firearm_pistol_state": _get_dictionary(hover_context.get("commando_firearm_pistol_state", {})),
		}
	)


func _draw_tooltip(canvas: CanvasItem, hover_context: Dictionary, skill_data: Dictionary) -> void:
	var metrics := _build_tooltip_metrics(hover_context, skill_data)
	if metrics.is_empty():
		return
	var font: Font = metrics.get("font", ThemeDB.fallback_font)
	var scale_factor := float(metrics.get("scale_factor", 1.0))
	var tooltip_width := float(metrics.get("tooltip_width", 0.0))
	var tooltip_height := float(metrics.get("tooltip_height", 0.0))
	var padding := float(metrics.get("padding", 0.0))
	var title_size := int(metrics.get("title_size", 14))
	var normal_size := int(metrics.get("normal_size", 11))
	var small_size := int(metrics.get("small_size", 9))
	var desc_lines: Array = _get_array(metrics.get("desc_lines", []))
	var control_rows: Array = _get_array(metrics.get("control_rows", []))
	var control_lines: Array = _get_array(metrics.get("control_lines", []))
	var control_box_height := float(metrics.get("control_box_height", 0.0))
	var preview_height := float(metrics.get("preview_height", 0.0))
	var tooltip_pos: Vector2 = _get_tooltip_position(hover_context, tooltip_width, tooltip_height, scale_factor)
	var tooltip_rect := Rect2(tooltip_pos, Vector2(tooltip_width, tooltip_height))
	var skill_color: Color = _get_color(skill_data.get("color", Color.WHITE), Color.WHITE)

	_draw_panel(canvas, tooltip_rect, Color(20.0 / 255.0, 25.0 / 255.0, 35.0 / 255.0, 0.92), skill_color, 2.0 * scale_factor, 8.0 * scale_factor)
	var header_rect := Rect2(
		tooltip_pos + Vector2(2.0 * scale_factor, 2.0 * scale_factor),
		Vector2(tooltip_width - 4.0 * scale_factor, HEADER_HEIGHT * scale_factor)
	)
	_draw_panel(canvas, header_rect, Color(skill_color.r, skill_color.g, skill_color.b, 0.24), Color(0.0, 0.0, 0.0, 0.0), 0.0, 6.0 * scale_factor)

	var cursor_y: float = tooltip_pos.y + padding
	_draw_text(canvas, font, Vector2(tooltip_pos.x + padding, cursor_y), str(skill_data.get("korean", "")), title_size, Color.WHITE)
	var active_text := LanguageSettings.translate_text("초식")
	var active_size: Vector2 = font.get_string_size(active_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size)
	_draw_text(
		canvas,
		font,
		Vector2(tooltip_pos.x + tooltip_width - padding - active_size.x, cursor_y),
		active_text,
		title_size,
		Color(1.0, 120.0 / 255.0, 80.0 / 255.0)
	)

	cursor_y += HEADER_HEIGHT * scale_factor + 6.0 * scale_factor
	_draw_cost_and_cooldown_line(canvas, font, hover_context, skill_data, tooltip_pos, tooltip_width, padding, cursor_y, normal_size, small_size)
	cursor_y += 22.0 * scale_factor

	for line in desc_lines:
		_draw_text(canvas, font, Vector2(tooltip_pos.x + padding, cursor_y), line, normal_size, Color(220.0 / 255.0, 220.0 / 255.0, 220.0 / 255.0))
		cursor_y += 18.0 * scale_factor

	cursor_y += 6.0 * scale_factor
	if control_box_height > 0.0:
		var control_rect := Rect2(
			Vector2(tooltip_pos.x + padding, cursor_y),
			Vector2(tooltip_width - padding * 2.0, control_box_height)
		)
		_draw_panel(canvas, control_rect, Color(40.0 / 255.0, 45.0 / 255.0, 60.0 / 255.0, 0.78), Color(skill_color.r, skill_color.g, skill_color.b, 0.32), 1.0 * scale_factor, 4.0 * scale_factor)
		if not control_rows.is_empty():
			_draw_control_rows(canvas, font, control_rows, control_rect.position + Vector2(8.0 * scale_factor, 7.0 * scale_factor), normal_size, small_size, scale_factor)
		else:
			var line_y: float = control_rect.position.y + 8.0 * scale_factor
			for line in control_lines:
				_draw_text(canvas, font, Vector2(control_rect.position.x + 8.0 * scale_factor, line_y), line, normal_size, Color(224.0 / 255.0, 229.0 / 255.0, 238.0 / 255.0))
				line_y += 18.0 * scale_factor
		cursor_y += control_box_height + 8.0 * scale_factor

	var effect_rect := Rect2(
		Vector2(tooltip_pos.x + padding, tooltip_pos.y + tooltip_height - preview_height - padding),
		Vector2(tooltip_width - padding * 2.0, preview_height)
	)
	_draw_panel(canvas, effect_rect, Color(10.0 / 255.0, 15.0 / 255.0, 25.0 / 255.0, 0.78), Color(skill_color.r, skill_color.g, skill_color.b, 0.40), 1.0 * scale_factor, 6.0 * scale_factor)
	_draw_effect_preview(canvas, effect_rect, str(skill_data.get("effect_type", "")), skill_color, float(Time.get_ticks_msec() % 2000) / 2000.0)
	_draw_text(canvas, font, effect_rect.position + Vector2(4.0 * scale_factor, 4.0 * scale_factor), LanguageSettings.translate_text("이펙트 미리보기"), small_size, Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0))


func _build_tooltip_metrics(hover_context: Dictionary, skill_data: Dictionary) -> Dictionary:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return {}
	var scale_factor := float(hover_context.get("scale_factor", 1.0))
	var tooltip_width := TOOLTIP_WIDTH * scale_factor
	var padding := PADDING * scale_factor
	var title_size := maxi(14, int(round(16.0 * scale_factor)))
	var normal_size := maxi(11, int(round(12.0 * scale_factor)))
	var small_size := maxi(9, int(round(10.0 * scale_factor)))
	var max_text_width := tooltip_width - padding * 2.0
	var description_text := _build_description_with_runtime_bonus(skill_data, hover_context)
	var desc_lines: Array[String] = _wrap_text(
		description_text,
		font,
		normal_size,
		max_text_width,
		_get_description_max_lines(skill_data, hover_context)
	)
	var control_rows: Array = _build_control_rows(
		str(skill_data.get("name", "")),
		str(hover_context.get("selected_character_type", "smasher")),
		str(skill_data.get("motion_hint", "")),
		font,
		normal_size,
		max_text_width - 16.0 * scale_factor
	)
	var control_lines: Array[String] = []
	if control_rows.is_empty():
		control_lines = _wrap_text(
			str(skill_data.get("how_to_use", "")),
			font,
			normal_size,
			max_text_width - 16.0 * scale_factor,
			2
		)
	var control_box_height := 0.0
	if not control_rows.is_empty():
		control_box_height = max(
			38.0 * scale_factor,
			float(control_rows.size()) * CONTROL_ROW_HEIGHT * scale_factor + 12.0 * scale_factor
		)
	elif not control_lines.is_empty():
		control_box_height = max(
			34.0 * scale_factor,
			float(control_lines.size()) * 18.0 * scale_factor + 16.0 * scale_factor
		)
	var content_bottom_y := padding + HEADER_HEIGHT * scale_factor + 6.0 * scale_factor + 22.0 * scale_factor
	content_bottom_y += float(desc_lines.size()) * 18.0 * scale_factor + 6.0 * scale_factor
	if control_box_height > 0.0:
		content_bottom_y += control_box_height + 8.0 * scale_factor
	var preview_height := EFFECT_PREVIEW_HEIGHT * scale_factor
	var min_height := 0.0
	var skill_name := str(skill_data.get("name", ""))
	if skill_name != "drive" and skill_name != "power_smashing":
		min_height = 300.0 * scale_factor
	return {
		"font": font,
		"scale_factor": scale_factor,
		"tooltip_width": tooltip_width,
		"tooltip_height": max(min_height, content_bottom_y + preview_height + padding),
		"padding": padding,
		"title_size": title_size,
		"normal_size": normal_size,
		"small_size": small_size,
		"desc_lines": desc_lines,
		"control_rows": control_rows,
		"control_lines": control_lines,
		"control_box_height": control_box_height,
		"preview_height": preview_height,
	}


func _draw_cost_and_cooldown_line(
	canvas: CanvasItem,
	font: Font,
	hover_context: Dictionary,
	skill_data: Dictionary,
	tooltip_pos: Vector2,
	tooltip_width: float,
	padding: float,
	y: float,
	normal_size: int,
	small_size: int
) -> void:
	var current_gauge: float = float(hover_context.get("special_gauge", 0.0))
	var cost: float = _get_effective_skill_cost(skill_data, hover_context)
	var can_use: bool = current_gauge >= cost
	var cost_color := Color(100.0 / 255.0, 1.0, 150.0 / 255.0) if can_use else Color(1.0, 100.0 / 255.0, 100.0 / 255.0)
	_draw_text(canvas, font, Vector2(tooltip_pos.x + padding, y), "%s: %s" % [LanguageSettings.translate_text("기력 비용"), _format_number(cost)], normal_size, cost_color)
	if not bool(skill_data.get("show_cooldown", true)):
		return

	var cooldown_seconds: float = _get_effective_skill_cooldown_seconds(skill_data, hover_context)
	var cooldown_ratio: float = _get_cooldown_remaining(
		hover_context.get("skill_state", null),
		str(skill_data.get("name", "")),
		Time.get_ticks_msec(),
		cooldown_seconds,
		hover_context
	)
	var cooldown_text: String = _compose_cooldown_text(skill_data, hover_context, cooldown_seconds, cooldown_ratio)
	var cooldown_color: Color = Color(1.0, 180.0 / 255.0, 80.0 / 255.0) if cooldown_ratio > 0.0 else Color(180.0 / 255.0, 180.0 / 255.0, 180.0 / 255.0)
	var cd_size: Vector2 = font.get_string_size(cooldown_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, small_size)
	_draw_text(canvas, font, Vector2(tooltip_pos.x + tooltip_width - padding - cd_size.x, y + 2.0), cooldown_text, small_size, cooldown_color)


# 쿨타임 표기 조립. 가변 쿨타임 스킬(플라즈마: skill_data["cooldown_range"] 보유)은
# 대기 중엔 "min~max초" 범위를, 발동 중엔 실제로 걸린 총쿨(skill_state가 저장한
# 이번 시전 cooldown_msec) × 잔여비율을 표시한다. 범위 데이터가 없는 다른 모든
# 스킬은 이전과 바이트-동일한 두 포맷 문자열로 폴백한다(플라즈마만 분기).
func _compose_cooldown_text(skill_data: Dictionary, hover_context: Dictionary, cooldown_seconds: float, cooldown_ratio: float) -> String:
	var cooldown_label := LanguageSettings.translate_text("쿨타임")
	var seconds_suffix := LanguageSettings.translate_text("초")
	var cooldown_range: Array = _get_cooldown_range(skill_data)
	var has_range: bool = cooldown_range.size() == 2
	if cooldown_ratio > 0.0:
		var active_total: float = cooldown_seconds
		if has_range:
			var state_total: float = _get_active_cooldown_total_seconds(hover_context.get("skill_state", null), str(skill_data.get("name", "")))
			if state_total > 0.0:
				active_total = state_total
		return "%s: %.1f%s" % [cooldown_label, active_total * cooldown_ratio, seconds_suffix]
	if has_range:
		return "%s: %s~%s%s" % [cooldown_label, _format_number(cooldown_range[0]), _format_number(cooldown_range[1]), seconds_suffix]
	return "%s: %s%s" % [cooldown_label, _format_number(cooldown_seconds), seconds_suffix]


func _get_cooldown_range(skill_data: Dictionary) -> Array:
	var value: Variant = skill_data.get("cooldown_range", null)
	if value is Array and (value as Array).size() == 2:
		return [float((value as Array)[0]), float((value as Array)[1])]
	return []


func _get_active_cooldown_total_seconds(skill_state: Object, skill_name: String) -> float:
	if skill_state != null and skill_state.has_method("get_cooldown_total_seconds"):
		return float(skill_state.get_cooldown_total_seconds(skill_name))
	return 0.0


func _build_description_with_runtime_bonus(skill_data: Dictionary, hover_context: Dictionary) -> String:
	var description: String = str(skill_data.get("description", ""))
	var skill_name: String = str(skill_data.get("name", ""))
	if skill_name in ["drive", "power_smashing"]:
		return _append_combo_amplifier_runtime_bonus(description, hover_context, skill_name)
	if skill_name == "dual_glitch":
		return _append_dual_glitch_runtime_bonus(description, hover_context)
	if skill_name == "ignition_aura":
		return _append_ignition_aura_runtime_bonus(description, hover_context)
	if skill_name == "dive_strike":
		return _append_dive_strike_runtime_bonus(description, hover_context)
	if skill_name == "nerve_strike":
		return _append_nerve_strike_runtime_bonus(description, hover_context)
	if skill_name in ["shadow_step", "marshal_kick", "phantom_kick", "core_flip"]:
		return _append_viper_kick_runtime_bonus(description, hover_context, skill_name)
	if not (skill_name in ["blade_rush", "dark_blade"]):
		return description
	var blade_level: int = _get_runtime_skill_level(hover_context, "blade_amp")
	if blade_level <= 0:
		return description
	var size_pct := int(round(RuntimePerkProgression.get_value("blade_amp", "range_width_bonus", blade_level) * 100.0))
	var projectile_speed_pct := int(round(RuntimePerkProgression.get_value("blade_amp", "projectile_speed_bonus", blade_level) * 100.0))
	var hit_speed_pct := int(round(RuntimePerkProgression.get_value("blade_amp", "hit_speed_bonus", blade_level) * 100.0))
	var cost_cut := RuntimePerkProgression.get_int_value("blade_amp", "gauge_cost_reduction", blade_level)
	var homing_pct: int = 0
	if RuntimePerkProgression.get_int_value("blade_amp", "homing_tier", blade_level) > 0:
		homing_pct = 30 if skill_name == "dark_blade" else 60
	var followup_pct := RuntimePerkProgression.get_int_value("blade_amp", "followup_chance_pct", blade_level)
	var lines: Array[String] = [_format_blade_amp_runtime_line(size_pct, projectile_speed_pct, hit_speed_pct, cost_cut)]
	if homing_pct > 0 or followup_pct > 0:
		lines.append(_format_blade_amp_lv3_line(homing_pct, followup_pct))
	return "%s\n%s" % [description, "\n".join(lines)]


# 콤보증폭칩(enhancer)이 드라이브/천뢰격 orb 스킬의 콤보 항을 증폭하므로, 대상 orb
# 툴팁에 현재 효과값 시너지 라인을 노출(CLAUDE.md: enhancer는 target orb tooltip에 live값 표시).
func _append_combo_amplifier_runtime_bonus(description: String, hover_context: Dictionary, skill_name: String) -> String:
	var level: int = _get_runtime_skill_level(hover_context, "combo_amplifier_chip")
	if level <= 0:
		return description
	var is_drive: bool = skill_name == "drive"
	var pct_a := int(round(RuntimePerkProgression.get_value(
		"combo_amplifier_chip",
		"drive_speed_bonus" if is_drive else "smash_speed_bonus",
		level
	) * 100.0))
	var pct_b := int(round(RuntimePerkProgression.get_value(
		"combo_amplifier_chip",
		"drive_curve_bonus" if is_drive else "initial_boost_decay_reduction",
		level
	) * 100.0))
	return "%s\n%s" % [description, _format_combo_amplifier_line(is_drive, pct_a, pct_b)]


func _format_combo_amplifier_line(is_drive: bool, pct_a: int, pct_b: int) -> String:
	var lang := LanguageSettings.get_language()
	if lang == LanguageSettings.LANGUAGE_ENGLISH:
		return ("Thunder-Gathering Inner Art: Thunderclap Strike speed +%d%%, curve +%d%%" if is_drive else "Thunder-Gathering Inner Art: Heavenly Thunder Strike speed +%d%%, boost retention +%d%%") % [pct_a, pct_b]
	if lang == LanguageSettings.LANGUAGE_CHINESE:
		return ("蓄雷心法：霹雳击球速 +%d%%，曲线 +%d%%" if is_drive else "蓄雷心法：天雷击球速 +%d%%，增幅维持 +%d%%") % [pct_a, pct_b]
	if lang == LanguageSettings.LANGUAGE_JAPANESE:
		return ("蓄雷心法：霹靂打の球速 +%d%%、カーブ +%d%%" if is_drive else "蓄雷心法：天雷撃の球速 +%d%%、ブースト維持 +%d%%") % [pct_a, pct_b]
	if lang == LanguageSettings.LANGUAGE_SPANISH:
		return ("Arte Interior de Trueno Acumulado: velocidad de Golpe Relámpago +%d%%, curva +%d%%" if is_drive else "Arte Interior de Trueno Acumulado: velocidad de Golpe del Trueno Celestial +%d%%, retención de impulso +%d%%") % [pct_a, pct_b]
	if lang == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return ("Arte Interior do Trovão Acumulado: velocidade do Golpe Relâmpago +%d%%, curva +%d%%" if is_drive else "Arte Interior do Trovão Acumulado: velocidade do Golpe do Trovão Celestial +%d%%, retenção de impulso +%d%%") % [pct_a, pct_b]
	if lang == LanguageSettings.LANGUAGE_RUSSIAN:
		return ("Внутреннее Искусство Накопленной Молнии: скорость Громового удара +%d%%, кривая +%d%%" if is_drive else "Внутреннее Искусство Накопленной Молнии: скорость Удара небесного грома +%d%%, удержание ускорения +%d%%") % [pct_a, pct_b]
	return ("축뢰심법: 벽력타 공속 +%d%%, 커브 +%d%%" if is_drive else "축뢰심법: 천뢰격 공속 +%d%%, 부스트 유지 +%d%%") % [pct_a, pct_b]


func _get_description_max_lines(skill_data: Dictionary, hover_context: Dictionary) -> int:
	if skill_data.has("description_max_lines"):
		return maxi(1, int(skill_data.get("description_max_lines", 5)))
	var skill_name: String = str(skill_data.get("name", ""))
	if skill_name in ["drive", "power_smashing"] and _get_runtime_skill_level(hover_context, "combo_amplifier_chip") > 0:
		return 6
	if skill_name in ["blade_rush", "dark_blade"] and _get_runtime_skill_level(hover_context, "blade_amp") > 0:
		return 7
	if skill_name in ["shadow_step", "marshal_kick", "phantom_kick", "core_flip"] and _get_runtime_skill_level(hover_context, "kick_enhance") > 0:
		return 7
	if skill_name in ["dive_strike", "chaos_spear", "dual_glitch", "nerve_strike"] and _get_runtime_skill_level(hover_context, "four_poisons") > 0:
		return 7
	if skill_name == "ignition_aura":
		return 6
	return 5


func _append_viper_kick_runtime_bonus(description: String, hover_context: Dictionary, skill_name: String) -> String:
	var kick_level: int = _get_runtime_skill_level(hover_context, "kick_enhance")
	if kick_level <= 0:
		return description
	# Keep the known authored 8%/12% lanes distinct from the live 0.09/0.04
	# geometry lanes. S2 records the mismatch without resolving it.
	var precision_pct := RuntimePerkProgression.get_int_value("kick_enhance", "authored_precision_pct", kick_level)
	var speed_pct := RuntimePerkProgression.get_int_value("kick_enhance", "authored_speed_pct", kick_level)
	var lines: Array[String] = [_format_kick_enhance_runtime_line(precision_pct, speed_pct)]
	if skill_name != "shadow_step":
		var prep_pct := int(round(RuntimePerkProgression.get_value("kick_enhance", "prep_reduction", kick_level) * 100.0))
		lines[0] = "%s, %s -%d%%" % [lines[0], LanguageSettings.translate_text("준비"), prep_pct]
	var knockback_chance_pct := int(round(RuntimePerkProgression.get_value("kick_enhance", "furnace_knockback_chance", kick_level) * 100.0))
	if knockback_chance_pct > 0:
		lines.append(_format_kick_knockback_runtime_line(knockback_chance_pct))
	return "%s\n%s" % [description, "\n".join(lines)]


func _append_dive_strike_runtime_bonus(description: String, hover_context: Dictionary) -> String:
	var four_poisons_level: int = _get_runtime_skill_level(hover_context, "four_poisons")
	if four_poisons_level <= 0:
		return description
	var prep_pct := RuntimePerkProgression.get_int_value("four_poisons", "prep_reduction_pct", four_poisons_level)
	var sleep_pct := RuntimePerkProgression.get_int_value("four_poisons", "sleep_pct", four_poisons_level)
	var cooldown_pct := RuntimePerkProgression.get_int_value("four_poisons", "cooldown_reduction_pct", four_poisons_level)
	var line: String = _format_four_poisons_dive_line(prep_pct, sleep_pct)
	var extras: Array[String] = []
	if cooldown_pct > 0:
		extras.append(_format_cooldown_reduction_runtime_line(cooldown_pct))
	if RuntimePerkProgression.get_int_value("four_poisons", "superarmor", four_poisons_level) > 0:
		extras.append(LanguageSettings.translate_text("슈퍼아머"))
	if not extras.is_empty():
		line = "%s / %s" % [line, "·".join(extras)]
	return "%s\n%s" % [description, line]


func _append_dual_glitch_runtime_bonus(description: String, hover_context: Dictionary) -> String:
	var four_poisons_level: int = _get_runtime_skill_level(hover_context, "four_poisons")
	if four_poisons_level <= 0:
		return description
	var duration_pct := RuntimePerkProgression.get_int_value("four_poisons", "dual_duration_pct", four_poisons_level)
	var cooldown_pct := RuntimePerkProgression.get_int_value("four_poisons", "cooldown_reduction_pct", four_poisons_level)
	var clone_hp := RuntimePerkProgression.get_int_value("four_poisons", "clone_hp", four_poisons_level)
	var line: String = _format_four_poisons_dual_line(duration_pct, clone_hp)
	var extras: Array[String] = []
	if cooldown_pct > 0:
		extras.append(_format_cooldown_reduction_runtime_line(cooldown_pct))
	if RuntimePerkProgression.get_int_value("four_poisons", "superarmor", four_poisons_level) > 0:
		extras.append(LanguageSettings.translate_text("슈퍼아머"))
	if not extras.is_empty():
		line = "%s / %s" % [line, " · ".join(extras)]
	var lines: Array[String] = [line]
	if RuntimePerkProgression.get_int_value("four_poisons", "clone_replication", four_poisons_level) > 0:
		lines.append(_format_four_poisons_dual_lv5_line())
	return "%s\n%s" % [description, "\n".join(lines)]


func _append_nerve_strike_runtime_bonus(description: String, hover_context: Dictionary) -> String:
	var four_poisons_level: int = _get_runtime_skill_level(hover_context, "four_poisons")
	if four_poisons_level <= 0:
		return description
	var confusion_pct := RuntimePerkProgression.get_int_value("four_poisons", "confusion_pct", four_poisons_level)
	var cooldown_pct := RuntimePerkProgression.get_int_value("four_poisons", "cooldown_reduction_pct", four_poisons_level)
	var line: String = _format_four_poisons_nerve_line(confusion_pct)
	var extras: Array[String] = []
	if cooldown_pct > 0:
		extras.append(_format_cooldown_reduction_runtime_line(cooldown_pct))
	if RuntimePerkProgression.get_int_value("four_poisons", "clone_replication", four_poisons_level) > 0:
		extras.append(LanguageSettings.translate_text("분신 독 슬래시"))
	if not extras.is_empty():
		line = "%s / %s" % [line, " · ".join(extras)]
	return "%s\n%s" % [description, line]


func _append_ignition_aura_runtime_bonus(description: String, hover_context: Dictionary) -> String:
	var runtime_perk_state: Object = hover_context.get("runtime_perk_state", null)
	var active_bonus: int = 0
	var gold_bonus: int = 0
	if runtime_perk_state != null:
		if runtime_perk_state.has_method("get_viper_ignition_aura_level_bonus"):
			active_bonus = int(runtime_perk_state.get_viper_ignition_aura_level_bonus())
		if runtime_perk_state.has_method("get_viper_ignition_aura_gold_bonus"):
			gold_bonus = int(runtime_perk_state.get_viper_ignition_aura_gold_bonus())
	if active_bonus <= 0:
		active_bonus = 2
	if gold_bonus <= 0:
		gold_bonus = 50
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "%s\nIgnition: invested perks Lv.+%d for 25s / gold +%d" % [description, active_bonus, gold_bonus]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "%s\nIgnición: perks invertidos Lv.+%d por 25s / oro +%d" % [description, active_bonus, gold_bonus]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "%s\nIgnição: perks investidos Lv.+%d por 25s / ouro +%d" % [description, active_bonus, gold_bonus]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "%s\nВоспламенение: вложенные перки Lv.+%d на 25с / золото +%d" % [description, active_bonus, gold_bonus]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "%s\n点火：25秒内已投资升级 Lv.+%d / 金币 +%d" % [description, active_bonus, gold_bonus]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "%s\nイグニッション：25秒間、投資パーク Lv.+%d / ゴールド +%d" % [description, active_bonus, gold_bonus]
	return "%s\n이그니션: 25초 동안 투자 무공 경지 +%d / 골드 +%d" % [description, active_bonus, gold_bonus]


func _format_blade_amp_runtime_line(size_pct: int, projectile_speed_pct: int, hit_speed_pct: int, cost_cut: int) -> String:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "Sword Aura Inner Art: width/range +%d%%, blade speed +%d%%, attack speed +%d%%, cost -%d" % [
			size_pct,
			projectile_speed_pct,
			hit_speed_pct,
			cost_cut,
		]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Arte Interior de Aura de Espada: ancho/alcance +%d%%, velocidad de hoja +%d%%, velocidad de ataque +%d%%, coste -%d" % [
			size_pct,
			projectile_speed_pct,
			hit_speed_pct,
			cost_cut,
		]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Arte Interior da Aura de Espada: largura/alcance +%d%%, velocidade da lâmina +%d%%, velocidade de ataque +%d%%, custo -%d" % [
			size_pct,
			projectile_speed_pct,
			hit_speed_pct,
			cost_cut,
		]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Внутреннее Искусство Мечевой Ци: ширина/дальность +%d%%, скорость лезвия +%d%%, скорость атаки +%d%%, стоимость -%d" % [
			size_pct,
			projectile_speed_pct,
			hit_speed_pct,
			cost_cut,
		]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "剑罡心法：宽度/距离 +%d%%，刀速 +%d%%，攻速 +%d%%，费用 -%d" % [
			size_pct,
			projectile_speed_pct,
			hit_speed_pct,
			cost_cut,
		]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "剣罡心法：幅/距離 +%d%%、刃速 +%d%%、攻速 +%d%%、費用 -%d" % [
			size_pct,
			projectile_speed_pct,
			hit_speed_pct,
			cost_cut,
		]
	return "검강심법: 폭/거리+%d%%, 검속+%d%%, 공속+%d%%, 비용-%d" % [
		size_pct,
		projectile_speed_pct,
		hit_speed_pct,
		cost_cut,
	]


func _format_blade_amp_lv3_line(homing_pct: int, followup_pct: int) -> String:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "Lv3+: homing %d%%, extra blade %d%%" % [homing_pct, followup_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Lv3+: guiado %d%%, hoja extra %d%%" % [homing_pct, followup_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Lv3+: guiagem %d%%, lâmina extra %d%%" % [homing_pct, followup_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Lv3+: наведение %d%%, доп. лезвие %d%%" % [homing_pct, followup_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "Lv3+：追踪 %d%%，追加刀波 %d%%" % [homing_pct, followup_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "Lv3+：誘導 %d%%、追加刃波 %d%%" % [homing_pct, followup_pct]
	return "3성부터: 유도 %d%%, 추가검기 %d%%" % [homing_pct, followup_pct]


func _format_kick_enhance_runtime_line(precision_pct: int, speed_pct: int) -> String:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "Heavenly Kick Inner Art: precision +%d%%, ball speed +%d%%" % [precision_pct, speed_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Arte Interior de Patada Celestial: precisión +%d%%, velocidad de bola +%d%%" % [precision_pct, speed_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Arte Interior do Chute Celestial: precisão +%d%%, velocidade da bola +%d%%" % [precision_pct, speed_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Внутреннее Искусство Небесного Удара: точность +%d%%, скорость мяча +%d%%" % [precision_pct, speed_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "天脚心法：精度 +%d%%，球速 +%d%%" % [precision_pct, speed_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "天脚心法：精度 +%d%%、球速 +%d%%" % [precision_pct, speed_pct]
	return "천각심법: 정밀도 +%d%%, 공속 +%d%%" % [precision_pct, speed_pct]


func _format_kick_knockback_runtime_line(knockback_chance_pct: int) -> String:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "Lv3+: furnace knockback ball %d%%, guard knockback 150%%" % knockback_chance_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Lv3+: bola de retroceso de horno %d%%, retroceso de guardia 150%%" % knockback_chance_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Lv3+: bola de empurrão da fornalha %d%%, empurrão de guarda 150%%" % knockback_chance_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Lv3+: мяч отталкивания печи %d%%, отталкивание блока 150%%" % knockback_chance_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "Lv3+：熔炉击退球 %d%%，防御击退 150%%" % knockback_chance_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "Lv3+：炉ノックバックボール %d%%、ガードノックバック 150%%" % knockback_chance_pct
	return "3성부터: 용광로 넉백볼 %d%%, 가드 넉백 150%%" % knockback_chance_pct


func _format_four_poisons_dive_line(prep_pct: int, sleep_pct: int) -> String:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "Four Poisons Unity: prep -%d%%, sleep +%d%%" % [prep_pct, sleep_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Unidad de los Cuatro Venenos: preparación -%d%%, sueño +%d%%" % [prep_pct, sleep_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Unidade dos Quatro Venenos: preparação -%d%%, sono +%d%%" % [prep_pct, sleep_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Единство Четырёх Ядов: подготовка -%d%%, сон +%d%%" % [prep_pct, sleep_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "四毒归一：准备 -%d%%，睡眠 +%d%%" % [prep_pct, sleep_pct]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "四毒帰一：準備 -%d%%、睡眠 +%d%%" % [prep_pct, sleep_pct]
	return "사독귀일: 준비 -%d%%, 수면 +%d%%" % [prep_pct, sleep_pct]


func _format_four_poisons_dual_line(duration_pct: int, clone_hp: int) -> String:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "Four Poisons Unity: duration +%d%%, clone HP %d" % [duration_pct, clone_hp]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Unidad de los Cuatro Venenos: duración +%d%%, PV del clon %d" % [duration_pct, clone_hp]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Unidade dos Quatro Venenos: duração +%d%%, PV do clone %d" % [duration_pct, clone_hp]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Единство Четырёх Ядов: длительность +%d%%, HP клона %d" % [duration_pct, clone_hp]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "四毒归一：持续 +%d%%，分身HP %d" % [duration_pct, clone_hp]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "四毒帰一：持続 +%d%%、分身HP %d" % [duration_pct, clone_hp]
	return "사독귀일: 지속 +%d%%, 분신 HP %d" % [duration_pct, clone_hp]


func _format_four_poisons_dual_lv5_line() -> String:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "Four Poisons Unity Lv5: clones copy skills while active"
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Unidad de los Cuatro Venenos Lv5: los clones copian habilidades durante la activa"
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Unidade dos Quatro Venenos Lv5: clones copiam habilidades durante a ativa"
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Единство Четырёх Ядов Lv5: клоны копируют навыки во время актива"
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "四毒归一Lv5：主动期间分身复制技能"
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "四毒帰一Lv5：アクティブ中、分身がスキルをコピー"
	return "사독귀일 극성: 발동 중 분신이 초식을 복제"


func _format_four_poisons_nerve_line(confusion_pct: int) -> String:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "Four Poisons Unity: confusion +%d%%" % confusion_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Unidad de los Cuatro Venenos: confusión +%d%%" % confusion_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Unidade dos Quatro Venenos: confusão +%d%%" % confusion_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Единство Четырёх Ядов: замешательство +%d%%" % confusion_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "四毒归一：混乱 +%d%%" % confusion_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "四毒帰一：混乱 +%d%%" % confusion_pct
	return "사독귀일: 혼란 +%d%%" % confusion_pct


func _format_cooldown_reduction_runtime_line(cooldown_pct: int) -> String:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "cooldown -%d%%" % cooldown_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "recarga -%d%%" % cooldown_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "recarga -%d%%" % cooldown_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "перезарядка -%d%%" % cooldown_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "冷却 -%d%%" % cooldown_pct
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "クールタイム -%d%%" % cooldown_pct
	return "쿨 -%d%%" % cooldown_pct


func _get_effective_skill_cost(skill_data: Dictionary, hover_context: Dictionary) -> float:
	var skill_name: String = str(skill_data.get("name", ""))
	var cost: float = float(skill_data.get("cost", 0.0))
	if skill_name in ["blade_rush", "dark_blade"]:
		var blade_level: int = _get_runtime_skill_level(hover_context, "blade_amp")
		return max(100.0, cost - RuntimePerkProgression.get_value("blade_amp", "gauge_cost_reduction", blade_level))
	return cost


func _get_effective_skill_cooldown_seconds(skill_data: Dictionary, hover_context: Dictionary) -> float:
	var skill_name: String = str(skill_data.get("name", ""))
	var cooldown: float = float(skill_data.get("cooldown", 0.0))
	if skill_name in ["dive_strike", "chaos_spear", "dual_glitch", "nerve_strike"]:
		var four_poisons_level: int = _get_runtime_skill_level(hover_context, "four_poisons")
		var cooldown_pct := RuntimePerkProgression.get_int_value("four_poisons", "cooldown_reduction_pct", four_poisons_level)
		var base_cooldown: float = _get_viper_base_cooldown_seconds(skill_name, cooldown)
		var configured_reduction: float = clamp(1.0 - cooldown / max(0.001, base_cooldown), 0.0, 0.95)
		var total_reduction: float = clamp(configured_reduction + float(cooldown_pct) / 100.0, 0.0, 0.95)
		cooldown = base_cooldown * (1.0 - total_reduction)
	return cooldown


func _get_viper_base_cooldown_seconds(skill_name: String, fallback: float) -> float:
	match skill_name:
		"dive_strike":
			return 70.0
		"chaos_spear":
			return 30.0
		"dual_glitch":
			return 40.0
		"nerve_strike":
			return 35.0
	return fallback


func _get_runtime_skill_level(hover_context: Dictionary, skill_id: String) -> int:
	var runtime_perk_state: Object = hover_context.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_perk_state.get_runtime_skill_level(skill_id)))
	return 0


func _get_tooltip_position(hover_context: Dictionary, tooltip_width: float, tooltip_height: float, scale_factor: float) -> Vector2:
	var view_size: Vector2 = _get_vector2(hover_context, "view_size", Vector2(1488.0, 918.0))
	if bool(hover_context.get("card_tooltip_mode", false)):
		return _get_card_tooltip_position(
			hover_context,
			view_size,
			tooltip_width,
			tooltip_height,
			scale_factor
		)
	var game_offset: Vector2 = _get_vector2(hover_context, "game_offset", Vector2.ZERO)
	var mouse_pos: Vector2 = _get_vector2(hover_context, "mouse_pos", Vector2.ZERO)
	var tooltip_x: float = game_offset.x + 10.0 * scale_factor
	var tooltip_y: float = mouse_pos.y - tooltip_height * 0.5
	tooltip_x = clamp(tooltip_x, 5.0, max(5.0, view_size.x - tooltip_width - 5.0))
	tooltip_y = clamp(tooltip_y, 10.0, max(10.0, view_size.y - tooltip_height - 10.0))
	return Vector2(tooltip_x, tooltip_y)


func _get_card_tooltip_position(
	hover_context: Dictionary,
	view_size: Vector2,
	tooltip_width: float,
	tooltip_height: float,
	scale_factor: float
) -> Vector2:
	var margin := 10.0
	var gap := 14.0 * maxf(0.5, scale_factor)
	var safe_rect := Rect2(
		Vector2(margin, margin),
		Vector2(
			maxf(0.0, view_size.x - margin * 2.0),
			maxf(0.0, view_size.y - margin * 2.0)
		)
	)
	var anchor := _get_rect2(
		hover_context.get("card_tooltip_anchor_rect", Rect2()),
		Rect2()
	)
	var avoid_rects: Array[Rect2] = []
	for value in _get_array(hover_context.get("card_tooltip_avoid_rects", [])):
		if value is Rect2 and (value as Rect2).size.x > 0.0 and (value as Rect2).size.y > 0.0:
			avoid_rects.append(value as Rect2)
	if avoid_rects.is_empty() and anchor.size.x > 0.0 and anchor.size.y > 0.0:
		avoid_rects.append(anchor)
	var avoid_bounds := anchor
	for rect in avoid_rects:
		avoid_bounds = rect if avoid_bounds.size == Vector2.ZERO else avoid_bounds.merge(rect)
	var tooltip_size := Vector2(tooltip_width, tooltip_height)
	var candidates: Array[Vector2] = [
		Vector2(
			avoid_bounds.position.x - tooltip_width - gap,
			anchor.get_center().y - tooltip_height * 0.5
		),
		Vector2(
			avoid_bounds.end.x + gap,
			anchor.get_center().y - tooltip_height * 0.5
		),
		Vector2(
			anchor.get_center().x - tooltip_width * 0.5,
			avoid_bounds.position.y - tooltip_height - gap
		),
		Vector2(
			anchor.get_center().x - tooltip_width * 0.5,
			avoid_bounds.end.y + gap
		),
	]
	for candidate in candidates:
		var candidate_rect := Rect2(candidate, tooltip_size)
		if _rect_is_inside(candidate_rect, safe_rect) and not _rect_overlaps_any(candidate_rect, avoid_rects):
			return candidate
	for candidate in candidates:
		var clamped := Vector2(
			clampf(candidate.x, safe_rect.position.x, maxf(safe_rect.position.x, safe_rect.end.x - tooltip_width)),
			clampf(candidate.y, safe_rect.position.y, maxf(safe_rect.position.y, safe_rect.end.y - tooltip_height))
		)
		if not _rect_overlaps_any(Rect2(clamped, tooltip_size), avoid_rects):
			return clamped
	# Extremely small windows may have no non-overlapping solution. Keep the
	# panel fully clipped to the viewport and choose the least-overlapping
	# candidate rather than hiding the canonical tooltip.
	var best_position := safe_rect.position
	var best_overlap := INF
	for candidate in candidates:
		var clamped := Vector2(
			clampf(candidate.x, safe_rect.position.x, maxf(safe_rect.position.x, safe_rect.end.x - tooltip_width)),
			clampf(candidate.y, safe_rect.position.y, maxf(safe_rect.position.y, safe_rect.end.y - tooltip_height))
		)
		var overlap := _rect_overlap_area(Rect2(clamped, tooltip_size), avoid_rects)
		if overlap < best_overlap:
			best_overlap = overlap
			best_position = clamped
	return best_position


func _rect_is_inside(inner: Rect2, outer: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x
		and inner.position.y >= outer.position.y
		and inner.end.x <= outer.end.x
		and inner.end.y <= outer.end.y
	)


func _rect_overlaps_any(rect: Rect2, avoid_rects: Array[Rect2]) -> bool:
	for avoid_rect in avoid_rects:
		if rect.intersects(avoid_rect):
			return true
	return false


func _rect_overlap_area(rect: Rect2, avoid_rects: Array[Rect2]) -> float:
	var total := 0.0
	for avoid_rect in avoid_rects:
		var overlap := rect.intersection(avoid_rect)
		total += maxf(0.0, overlap.size.x) * maxf(0.0, overlap.size.y)
	return total


func _build_control_rows(skill_name: String, character_type: String, motion_hint: String, font: Font, font_size: int, max_width: float) -> Array:
	var rows: Array = _get_control_rows(skill_name, character_type).duplicate(true)
	# 구조화 입력 행이 없으면 호출자가 how_to_use 문장 폴백을 그린다. 여기서
	# motion_hint를 먼저 붙이면 rows가 비지 않아 폴백이 조용히 사라진다.
	if rows.is_empty():
		return rows
	if not motion_hint.is_empty():
		for line in _wrap_text(motion_hint, font, font_size, max_width, 2):
			rows.append([["dim", line]])
	return rows


func _draw_control_rows(canvas: CanvasItem, font: Font, rows: Array, start: Vector2, normal_size: int, small_size: int, scale_factor: float) -> void:
	var row_height: float = CONTROL_ROW_HEIGHT * scale_factor
	for row_index in range(rows.size()):
		var row: Array = _get_array(rows[row_index])
		var cursor_x: float = start.x
		var row_y: float = start.y + float(row_index) * row_height
		for token_value in row:
			var token: Array = _get_array(token_value)
			if token.size() < 2:
				continue
			var token_type: String = str(token[0])
			var value: String = str(token[1])
			if token_type == "key":
				cursor_x += _draw_keycap(canvas, font, Vector2(cursor_x, row_y - scale_factor), value, small_size, scale_factor) + 4.0 * scale_factor
			elif token_type == "mouse_left":
				_draw_mouse_left_icon(canvas, Vector2(cursor_x, row_y - scale_factor), 18.0 * scale_factor)
				cursor_x += 22.0 * scale_factor
			elif token_type == "mouse_right":
				_draw_mouse_button_icon(canvas, Vector2(cursor_x, row_y - scale_factor), 18.0 * scale_factor, false)
				cursor_x += 22.0 * scale_factor
			else:
				var color: Color = _token_color(token_type)
				var text_size: Vector2 = _draw_text(canvas, font, Vector2(cursor_x, row_y + scale_factor), LanguageSettings.translate_text(value), normal_size, color)
				cursor_x += text_size.x + 6.0 * scale_factor


func _draw_keycap(canvas: CanvasItem, font: Font, pos: Vector2, text: String, font_size: int, scale_factor: float) -> float:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var width: float = max(20.0 * scale_factor, text_size.x + 14.0 * scale_factor)
	var height: float = 18.0 * scale_factor
	var rect := Rect2(pos, Vector2(width, height))
	_draw_panel(canvas, rect, Color(18.0 / 255.0, 22.0 / 255.0, 32.0 / 255.0, 0.92), Color(120.0 / 255.0, 130.0 / 255.0, 150.0 / 255.0, 0.85), 1.0 * scale_factor, 4.0 * scale_factor)
	_draw_text(canvas, font, Vector2(pos.x + (width - text_size.x) * 0.5, pos.y + (height - text_size.y) * 0.48), text, font_size, Color.WHITE)
	return width


func _draw_mouse_left_icon(canvas: CanvasItem, pos: Vector2, size: float) -> void:
	_draw_mouse_button_icon(canvas, pos, size, true)


func _draw_mouse_button_icon(canvas: CanvasItem, pos: Vector2, size: float, button_left: bool) -> void:
	var rect := Rect2(pos, Vector2(size * 0.72, size))
	var center_x: float = rect.position.x + rect.size.x * 0.5
	_draw_panel(canvas, rect, Color(18.0 / 255.0, 22.0 / 255.0, 32.0 / 255.0, 0.92), Color(120.0 / 255.0, 130.0 / 255.0, 150.0 / 255.0, 0.85), max(1.0, size * 0.06), size * 0.22)
	canvas.draw_line(Vector2(center_x, rect.position.y + size * 0.08), Vector2(center_x, rect.position.y + size * 0.44), Color(0.75, 0.8, 0.9), max(1.0, size * 0.06))
	var button_x: float = rect.position.x + rect.size.x * (0.31 if button_left else 0.69)
	canvas.draw_circle(Vector2(button_x, rect.position.y + size * 0.25), max(1.2, size * 0.08), Color(1.0, 214.0 / 255.0, 96.0 / 255.0))


func _draw_effect_preview(canvas: CanvasItem, rect: Rect2, effect_type: String, color: Color, _progress: float) -> void:
	effect_preview_renderer.draw(canvas, rect, effect_type, color, _progress)


func _get_effect_preview_family(effect_type: String) -> String:
	return effect_preview_renderer.get_effect_preview_family(effect_type)

func _wrap_text(text: String, font: Font, font_size: int, max_width: float, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	if text.is_empty() or max_lines <= 0:
		return lines
	for hard_line in text.split("\n", false):
		var line: String = ""
		var segment: String = str(hard_line)
		for index in range(segment.length()):
			var glyph: String = segment.substr(index, 1)
			var candidate: String = line + glyph
			if line.is_empty() or font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
				line = candidate
			else:
				lines.append(line)
				if lines.size() >= max_lines:
					return lines
				line = glyph
		if not line.is_empty():
			lines.append(line)
			if lines.size() >= max_lines:
				return lines
	return lines


func _draw_text(canvas: CanvasItem, font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> Vector2:
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(pos.x, pos.y + font.get_ascent(font_size))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
	return size


func _draw_panel(canvas: CanvasItem, rect: Rect2, fill_color: Color, border_color: Color, border_width: float, corner_radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	var width: int = max(0, int(round(border_width)))
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	var radius: int = max(0, int(round(corner_radius)))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	canvas.draw_style_box(style, rect)


func _get_control_rows(skill_name: String, character_type: String = "smasher") -> Array:
	if COMMON_CONTROL_ROWS.has(skill_name):
		var common_rows: Variant = COMMON_CONTROL_ROWS.get(skill_name, [])
		if common_rows is Array:
			return common_rows
	if ODINS_EYE_CONTROL_ROWS.has(skill_name):
		var odins_rows: Variant = ODINS_EYE_CONTROL_ROWS.get(skill_name, [])
		if odins_rows is Array:
			return odins_rows
	if HORN_STRAWBERRY_CONTROL_ROWS.has(skill_name):
		var horn_rows: Variant = HORN_STRAWBERRY_CONTROL_ROWS.get(skill_name, [])
		if horn_rows is Array:
			return horn_rows
	var rows: Variant = []
	if character_runtime.is_commando(character_type):
		rows = COMMANDO_CONTROL_ROWS.get(skill_name, [])
	elif character_runtime.is_viper(character_type):
		rows = VIPER_CONTROL_ROWS.get(skill_name, [])
	else:
		rows = CONTROL_ROWS.get(skill_name, [])
	if rows is Array:
		return rows
	return []


func _get_cooldown_remaining(
	skill_state: Object,
	skill_name: String,
	time_now: int,
	cooldown_seconds: float,
	hover_context: Dictionary = {}
) -> float:
	var skill_context: Dictionary = _get_dictionary(hover_context.get("skill_context", {}))
	var cooldown_ratios: Dictionary = _get_dictionary(skill_context.get("skill_cooldown_remaining_ratios", {}))
	if cooldown_ratios.has(skill_name):
		return clamp(float(cooldown_ratios.get(skill_name, 0.0)), 0.0, 1.0)
	if skill_state != null and skill_state.has_method("get_cooldown_remaining"):
		return float(skill_state.get_cooldown_remaining(skill_name, time_now, cooldown_seconds))
	return 0.0


func _get_horn_strawberry_context(registry: Object, scene_context: Dictionary) -> Dictionary:
	var context: Dictionary = _get_dictionary(scene_context.get("horn_strawberry_context", {}))
	if not context.is_empty():
		return context
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_horn_strawberry_context"):
		var value: Variant = mythic_item_runtime.get_horn_strawberry_context()
		if value is Dictionary:
			return value
	return {}


func _is_horn_strawberry_skill_hud_active(horn_renderer: Object, horn_context: Dictionary) -> bool:
	if horn_renderer == null:
		return false
	if horn_renderer.has_method("is_active"):
		return bool(horn_renderer.is_active(horn_context))
	return bool(horn_context.get("transformed", false))


func _get_odins_eye_context(registry: Object, scene_context: Dictionary) -> Dictionary:
	var context: Dictionary = _get_dictionary(scene_context.get("odins_eye_context", {}))
	if not context.is_empty():
		return context
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_odins_eye_context"):
		var value: Variant = mythic_item_runtime.get_odins_eye_context()
		if value is Dictionary:
			return value
	return {}


func _is_odins_eye_skill_hud_active(odins_renderer: Object, odins_context: Dictionary) -> bool:
	if odins_renderer == null:
		return false
	if odins_renderer.has_method("is_active"):
		return bool(odins_renderer.is_active(odins_context))
	return bool(odins_context.get("transformed", false))


func _get_baekrin_mount_context(registry: Object, scene_context: Dictionary) -> Dictionary:
	var context: Dictionary = _get_dictionary(scene_context.get("baekrin_mount_context", {}))
	if not context.is_empty():
		return context
	var lingpet_runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	if lingpet_runtime != null and lingpet_runtime.has_method("get_baekrin_mount_context"):
		var value: Variant = lingpet_runtime.get_baekrin_mount_context()
		if value is Dictionary:
			return value
	return {}


func _is_baekrin_mount_skill_hud_active(mount_renderer: Object, mount_context: Dictionary) -> bool:
	if mount_renderer == null:
		return false
	if mount_renderer.has_method("is_active"):
		return bool(mount_renderer.is_active(mount_context))
	return bool(mount_context.get("mounted", false))


func _token_color(token_type: String) -> Color:
	if token_type == "dim":
		return Color(184.0 / 255.0, 192.0 / 255.0, 208.0 / 255.0)
	if token_type == "accent":
		return Color(1.0, 214.0 / 255.0, 96.0 / 255.0)
	if token_type in ["arrow", "plus", "slash"]:
		return Color(190.0 / 255.0, 196.0 / 255.0, 210.0 / 255.0)
	return Color(224.0 / 255.0, 229.0 / 255.0, 238.0 / 255.0)


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_gamepad_selected_skill_name(registry: Object) -> String:
	var hover_state: Object = _get_instance(registry, "skill_orb_tooltip_hover_state")
	if hover_state == null or not hover_state.has_method("get_gamepad_selected_skill_name"):
		return ""
	return str(hover_state.get_gamepad_selected_skill_name())


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_vector2_from_variant(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _get_rect2(value: Variant, fallback: Rect2) -> Rect2:
	if value is Rect2:
		return value
	return fallback
