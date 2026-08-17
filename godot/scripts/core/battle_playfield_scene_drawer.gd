extends RefCounted

const BattlePlayfieldBallDrawer := preload("res://scripts/core/battle_playfield_ball_drawer.gd")
const BattlePlayfieldEffectsDrawer := preload("res://scripts/core/battle_playfield_effects_drawer.gd")
const BattlePlayfieldOverlayDrawer := preload("res://scripts/core/battle_playfield_overlay_drawer.gd")
const SmasherVoidPhantomRenderer := preload("res://scripts/characters/smasher_void_phantom_renderer.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const BLOCKING_OVERLAY_LOD_METHODS := [
	"is_runtime_perk_choice_active",
	"is_runtime_perk_feedback_active",
	"is_character_debug_picker_open",
	"is_perk_debug_picker_open",
	"is_stage_debug_picker_open",
	"is_weather_debug_picker_open",
	"is_lingpet_debug_picker_open",
	"is_mythic_management_menu_open",
	"is_pandora_legacy_selection_active",
	"is_character_info_active",
	"is_pause_menu_active",
	"is_active_item_debug_spawn_menu_open",
]

var ball_drawer: Object = BattlePlayfieldBallDrawer.new()
var effects_drawer: Object = BattlePlayfieldEffectsDrawer.new()
var overlay_drawer: Object = BattlePlayfieldOverlayDrawer.new()
var _void_phantom_renderer: Object = SmasherVoidPhantomRenderer.new()
var _mythic_draw_field_effects_accepts_perf_logger: int = -1
var _mythic_draw_field_effects_accepts_timer_stack: int = -1
var _mythic_draw_field_effects_accepts_draw_context: int = -1
var _method_argument_count_cache: Dictionary = {}
var _method_accepts_argument_count_cache: Dictionary = {}
var _character_runtime: Object = PlayerCharacterRuntime.new()


func draw(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	width: float,
	height: float,
	_pillar_width: float
) -> void:
	if canvas == null or registry == null:
		return
	# The transformed playfield pass uses full 760x750 game coordinates.
	# Do not subtract the legacy pillar width here; outer pillar chrome belongs
	# to the separate pillar scene pass.
	var draw_context_builder: Object = _get_instance(registry, "battle_draw_context")
	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var draw_context: Dictionary = {}
	var draw_deps: Dictionary = {}
	var actor_context: Dictionary = {}
	var power_state: Object = null
	var frame_start: int = _perf_begin(perf_logger)
	if draw_context_builder != null:
		var context_start: int = _perf_begin(perf_logger)
		var context_step_start: int = _perf_begin(perf_logger)
		draw_context = draw_context_builder.build_scene_context(canvas, shake_offset, registry)
		_perf_end(perf_logger, "context.scene", context_step_start)
		context_step_start = _perf_begin(perf_logger)
		power_state = _get_smasher_power_state_for_draw(registry, draw_context)
		draw_deps = draw_context_builder.build_scene_deps(registry, feedback, power_state, draw_context)
		_perf_end(perf_logger, "context.deps", context_step_start)
		context_step_start = _perf_begin(perf_logger)
		if _method_accepts_argument_count(draw_context_builder, "build_actor_context", 3):
			actor_context = draw_context_builder.build_actor_context(draw_context, draw_deps, perf_logger)
		else:
			actor_context = draw_context_builder.build_actor_context(draw_context, draw_deps)
		_perf_end(perf_logger, "context.actor", context_step_start)
		_perf_end(perf_logger, "context.build_all", context_start)
	var highlight_recorder: Object = _get_instance(registry, "victory_highlight_recorder")
	if highlight_recorder != null and highlight_recorder.has_method("capture_visual"):
		highlight_recorder.capture_visual(actor_context, draw_context)
	var highlight_playback: Object = _get_instance(registry, "victory_highlight_playback_state")
	if highlight_playback != null and highlight_playback.has_method("sync_host_layout"):
		highlight_playback.sync_host_layout(draw_context)

	# Decorative LOD gating was hiding the entire Stage 2 pillar HUD (skill / gauge /
	# dash orbs) and field background elements during the 0.25s scoreboard fade-in
	# window after a score, because the overlay reports `is_active()=true` before
	# its alpha covers the scene. The score overlay itself fills the screen, so the
	# perf savings were tiny compared with the visible "everything vanishes" flash
	# during shield kiting hits or Viper airborne hits. Keep all decorative draws
	# running so the HUD never collapses mid-rally. The `_uses_stage2_score_overlay_lod`
	# / `_uses_blocking_overlay_lod` helpers remain on the type for the existing
	# render-budget smoke tests that exercise them directly.
	var decorative_lod := false
	var stage_background: Object = _get_stage_background(registry, draw_context)
	# Draw the lingpet BODY (egg / companion) behind the player: inject a hook the shared
	# player actor renderer invokes just before it draws the player sprite. That is the
	# only Z-slot between the opaque stage background (drawn first inside draw_actors) and
	# the player, so an overlapping lingpet renders behind the player. The companion's
	# skill VFX / feedback stay in the post-actor pass (_draw_lingpet_runtime below).
	if not actor_context.is_empty():
		var lingpet_body_runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
		install_lingpet_draw_hooks(actor_context, lingpet_body_runtime, shake_offset)
	var sample_start: int = _perf_begin(perf_logger)
	effects_drawer.draw_actors(canvas, registry, draw_context, actor_context, perf_logger)
	_perf_end(perf_logger, "01.actors.total", sample_start)
	sample_start = _perf_begin(perf_logger)
	# 신비의 주사위 패들 오라: 플레이어 렌더 직후 분리형 호스트 동기화.
	effects_drawer.draw_mystic_dice_paddle_effect(registry, draw_context, shake_offset)
	_perf_end(perf_logger, "01b.mystic_dice_paddle", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_perk_fusion_byproduct_effects(canvas, registry, shake_offset)
	_perf_end(perf_logger, "01c.perk_fusion_byproduct", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_smasher_overdrive_meteor_effect(canvas, registry, draw_context, shake_offset)
	_perf_end(perf_logger, "01d.smasher_overdrive_meteor", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_stage1_butterfly_event(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "02.stage1_butterfly", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_stage1_balloon_background(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "03.stage1_balloon_bg", sample_start)
	if not decorative_lod and _has_visible_stage_playfield_obstacles(stage_background):
		sample_start = _perf_begin(perf_logger)
		_draw_stage_playfield_obstacles(canvas, stage_background, shake_offset, draw_context, perf_logger)
		_perf_end(perf_logger, "04.stage_obstacles", sample_start)
	sample_start = _perf_begin(perf_logger)
	if not decorative_lod:
		_draw_stage2_monkey_banana_event(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "05.stage2_monkey_banana", sample_start)
	sample_start = _perf_begin(perf_logger)
	_begin_horizontal_timer_gauge_frame(registry)
	_perf_end(perf_logger, "06.timer_stack_begin", sample_start)
	sample_start = _perf_begin(perf_logger)
	ball_drawer.draw_ball_effects(canvas, registry, draw_context_builder, draw_context, draw_deps, shake_offset, perf_logger)
	_perf_end(perf_logger, "07.ball_effects", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_power_smash_effects(canvas, registry, power_state, shake_offset, draw_context)
	_perf_end(perf_logger, "08.power_smash", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_lingpet_runtime(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "08b.lingpet", sample_start)
	sample_start = _perf_begin(perf_logger)
	var live_ball_renderer_context: Dictionary = ball_drawer.draw_ball(
		canvas,
		registry,
		draw_context_builder,
		draw_context,
		draw_deps,
		shake_offset,
		width,
		height,
		perf_logger
	)
	_perf_end(perf_logger, "09.ball", sample_start)
	sample_start = _perf_begin(perf_logger)
	# 환영공은 실제 공과 같은 z-계층이다. 둘 사이에 전면 날씨/스킬/필드 레이어가
	# 끼면 "나중에 선명하게 뜨는 쪽이 가짜"라는 판별 텔이 생긴다.
	_draw_void_phantom_decoys(
		canvas, registry, shake_offset, draw_context, live_ball_renderer_context
	)
	_perf_end(perf_logger, "09a.void_phantom", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_stage1_balloon_foreground(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "10.stage1_balloon_fg", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_stage1_spinning_top(canvas, registry, draw_context, actor_context)
	_perf_end(perf_logger, "11.stage1_spinning_top", sample_start)
	if not decorative_lod and _has_visible_stage_playfield_overlay(stage_background):
		sample_start = _perf_begin(perf_logger)
		_draw_stage_playfield_overlay(canvas, stage_background, shake_offset, draw_context, perf_logger)
		_perf_end(perf_logger, "12.stage_overlay", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_dash_spirit_effects(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "13.dash_spirit", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_recovery_effects(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "14.recovery", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_cleanse_effects(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "15.cleanse", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_warp_gate_effects(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "16.warp_gate", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_smasher_wheel_effects(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "17.smasher_wheel", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_dalji_vision_chosik_effects(canvas, registry, shake_offset)
	_perf_end(perf_logger, "17b.dalji_vision_chosik", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_cheongringwi_vision_chosik_effects(canvas, registry, shake_offset)
	effects_drawer.draw_yeonmyo_vision_chosik_effects(canvas, registry, shake_offset)
	_perf_end(perf_logger, "17c.cheongringwi_vision_chosik", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_plasma_effects(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "18.plasma", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_shield_kiting_effects(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "19.shield_kiting", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_blacksmith_thor_shield_effects(canvas, registry, shake_offset, actor_context)
	_perf_end(perf_logger, "19b.blacksmith_thor_shield", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_laurel_leaf_shield(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "20.laurel_leaf_shield", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_magnum_grip_effects(canvas, registry, draw_context, shake_offset)
	_perf_end(perf_logger, "21.magnum_grip", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_dash_acceleration_effect(canvas, registry, draw_context, shake_offset)
	_perf_end(perf_logger, "22.dash_acceleration", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_boost_charging_effect(canvas, registry, draw_context, shake_offset)
	_perf_end(perf_logger, "23.boost_charging", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_runtime_perk_timer_effects(canvas, registry)
	_perf_end(perf_logger, "23b.runtime_perk_timers", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_viper_skill_effects(canvas, registry, shake_offset, draw_context, perf_logger)
	_perf_end(perf_logger, "24.viper_skill", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_commando_supply_drop_effects(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "25.commando_supply", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_monkey_blessing_delivery(canvas, registry, shake_offset)
	_perf_end(perf_logger, "26.monkey_blessing", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_commando_reload_delivery(canvas, registry, shake_offset)
	_perf_end(perf_logger, "26b.commando_reload", sample_start)
	sample_start = _perf_begin(perf_logger)
	effects_drawer.draw_impact_and_combo_effects(canvas, registry, shake_offset, draw_context)
	_perf_end(perf_logger, "27.impact_combo", sample_start)
	if _should_draw_weather_effects(registry, draw_context):
		sample_start = _perf_begin(perf_logger)
		_draw_weather_effects(canvas, registry, shake_offset, draw_context)
		_perf_end(perf_logger, "28.weather", sample_start)
	sample_start = _perf_begin(perf_logger)
	if not decorative_lod:
		_draw_active_item_field(canvas, registry, shake_offset, perf_logger)
	_perf_end(perf_logger, "29.active_item_field", sample_start)
	sample_start = _perf_begin(perf_logger)
	# 승리 전리품 상자는 픽업 대상(게임플레이 크리티컬)이라 LOD 게이트를 타지 않는다.
	_draw_victory_loot_boxes(canvas, registry, shake_offset)
	_perf_end(perf_logger, "29b.victory_loot_boxes", sample_start)
	sample_start = _perf_begin(perf_logger)
	if not decorative_lod:
		_draw_mythic_item_field_effects(canvas, registry, shake_offset, perf_logger, draw_context)
	_perf_end(perf_logger, "30.mythic_item_field", sample_start)
	sample_start = _perf_begin(perf_logger)
	_end_horizontal_timer_gauge_frame(registry)
	_perf_end(perf_logger, "31.timer_stack_end", sample_start)
	sample_start = _perf_begin(perf_logger)
	overlay_drawer.draw_skill_banners(canvas, registry, draw_context_builder, draw_context, draw_deps, width, height)
	_perf_end(perf_logger, "32.skill_banners", sample_start)
	sample_start = _perf_begin(perf_logger)
	if not decorative_lod:
		_draw_active_item_pickup_effect(canvas, registry, perf_logger)
	_perf_end(perf_logger, "33.active_item_pickup", sample_start)
	sample_start = _perf_begin(perf_logger)
	overlay_drawer.draw_scoreboard_overlay(canvas, registry, width, height, draw_context, perf_logger)
	_perf_end(perf_logger, "34.scoreboard_overlay", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_tower_ascent_flow(canvas, registry)
	_perf_end(perf_logger, "35.tower_ascent_flow", sample_start)
	_perf_end(perf_logger, "00.playfield_frame_total", frame_start)
	_perf_remember_context(perf_logger, draw_context)


func _draw_perk_fusion_byproduct_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2
) -> void:
	var runtime_perk_state: Object = _get_cached_instance(registry, "runtime_perk_state")
	if (
		runtime_perk_state != null
		and runtime_perk_state.has_method("has_perk_fusion_byproduct_visible_effects")
		and bool(runtime_perk_state.has_perk_fusion_byproduct_visible_effects())
		and runtime_perk_state.has_method("draw_perk_fusion_byproduct_effects")
	):
		runtime_perk_state.draw_perk_fusion_byproduct_effects(canvas, shake_offset)


# S3-b §B-3. 본체·M 두 훅 주입 — 생산 경로와 씰이 공유하는 정본 헬퍼다.
# 인라인으로 풀어 쓰면 씰이 주입 배선을 증명하지 못한다(2026-08-15 회귀 복구).
static func install_lingpet_draw_hooks(actor_context: Dictionary, lingpet_body_runtime: Object, shake_offset: Vector2) -> void:
	if lingpet_body_runtime == null:
		return
	if lingpet_body_runtime.has_method("draw_lingpet_body_behind_actors"):
		actor_context["lingpet_body_draw"] = func(body_canvas: CanvasItem) -> void:
			lingpet_body_runtime.draw_lingpet_body_behind_actors(body_canvas, shake_offset)
	# M 베이스는 라이더 최종 rect 를 인자로 받는다 — 여기서 좌표를 재계산하면
	# shake·visual offset 이 플레이어 렌더러와 갈라진다(§B-3b).
	if lingpet_body_runtime.has_method("draw_topdown_mount_base"):
		actor_context["lingpet_mount_base_draw"] = func(mount_canvas: CanvasItem, final_rider_rect: Rect2) -> void:
			lingpet_body_runtime.draw_topdown_mount_base(mount_canvas, final_rider_rect)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	var value: Variant = registry.get_cached_instance(key)
	return _as_object(value)


func _get_smasher_power_state_for_draw(registry: Object, draw_context: Dictionary) -> Object:
	if _get_draw_character_type(draw_context) != PlayerCharacterRuntime.SMASHER:
		return null
	return _get_cached_instance(registry, "smasher_power_smash_state")


func _get_draw_character_type(draw_context: Dictionary) -> String:
	# Live draw contexts are already normalized; keep aliases here for direct tests
	# or older callers while preserving a conservative Smasher fallback.
	return _character_runtime.normalize(draw_context.get("selected_character_type", PlayerCharacterRuntime.SMASHER))


func _get_registry_module(key: String, registry: Object) -> Object:
	var cached: Object = _get_cached_instance(registry, key)
	if cached != null:
		return cached
	if registry != null and not registry.has_method("get_cached_instance") and registry.has_method("get_instance"):
		return _as_object(registry.get_instance(key))
	return null


func _uses_stage2_score_overlay_lod(registry: Object, draw_context: Dictionary) -> bool:
	if int(draw_context.get("current_stage", 1)) != 2:
		return false
	return _is_scoreboard_overlay_active(registry)


func _uses_blocking_overlay_lod(registry: Object, draw_context: Dictionary) -> bool:
	if int(draw_context.get("current_stage", 1)) != 2:
		return false
	var modal_gate: Object = _get_instance(registry, "battle_scene_modal_gate_controller")
	if modal_gate == null:
		return false
	var module_getter := Callable(self, "_get_registry_module").bind(registry)
	for method_name in BLOCKING_OVERLAY_LOD_METHODS:
		if modal_gate.has_method(method_name) and bool(modal_gate.call(method_name, module_getter)):
			return true
	return false


func _is_scoreboard_overlay_active(registry: Object) -> bool:
	var result_screen: Object = _get_instance(registry, "stage_clear_result_screen")
	if result_screen != null and result_screen.has_method("is_active") and bool(result_screen.is_active()):
		return false
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	return scoreboard_state != null and scoreboard_state.has_method("is_active") and bool(scoreboard_state.is_active())


func _get_stage_background(registry: Object, draw_context: Dictionary) -> Object:
	var current_stage: int = int(draw_context.get("current_stage", 1))
	var router: Object = _get_instance(registry, "stage_runtime_router")
	if router == null or not router.has_method("get_instance"):
		return null
	return _as_object(router.get_instance(registry, current_stage, "stage_background"))


func _has_visible_stage_playfield_overlay(stage_background: Object) -> bool:
	if stage_background == null or not stage_background.has_method("draw_playfield_overlay"):
		return false
	if stage_background.has_method("has_visible_playfield_overlay"):
		return bool(stage_background.has_visible_playfield_overlay())
	return true


func _has_visible_stage_playfield_obstacles(stage_background: Object) -> bool:
	if stage_background == null or not stage_background.has_method("draw_playfield_obstacles"):
		return false
	if stage_background.has_method("has_visible_playfield_obstacles"):
		return bool(stage_background.has_visible_playfield_obstacles())
	return true


func _as_object(value: Variant) -> Object:
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _perf_remember_context(perf_logger: Object, context: Dictionary) -> void:
	if perf_logger != null and perf_logger.has_method("remember_context"):
		perf_logger.remember_context(context)


func _draw_victory_loot_boxes(canvas: CanvasItem, registry: Object, shake_offset: Vector2) -> void:
	var loot_state: Object = _get_instance(registry, "victory_loot_phase_state")
	if loot_state == null or not loot_state.has_method("is_active") or not bool(loot_state.is_active()):
		return
	if loot_state.has_method("draw"):
		loot_state.draw(canvas, shake_offset)


func _draw_tower_ascent_flow(canvas: CanvasItem, registry: Object) -> void:
	# Draw-path lookup must remain cached-only. The victory-flow transition owns
	# creation, so the default-off lane cannot cold-instantiate this module.
	var flow_owner: Object = _get_cached_instance(registry, "tower_ascent_flow_owner")
	if (
		flow_owner != null
		and flow_owner.has_method("is_active")
		and bool(flow_owner.is_active())
		and flow_owner.has_method("draw")
	):
		flow_owner.draw(canvas)


func _draw_void_phantom_decoys(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	scene_draw_context: Dictionary = {},
	live_ball_renderer_context: Dictionary = {}
) -> void:
	# ⚠️peek 전용: 매 프레임 도는 드로우 경로다. get_instance 는 미생성 모듈을
	# 콜드 인스턴스화해 첫 호출을 히치로 만든다(Hot-Path Lazy Init Trap).
	# 미캐시 = 초식이 한 번도 돌아본 적 없음이므로 그릴 환영도 없다.
	var state: Object = _get_cached_instance(registry, "smasher_void_phantom_state")
	if state == null or not state.has_method("has_visible_effects"):
		if _void_phantom_renderer.has_method("set_active"):
			_void_phantom_renderer.set_active(false)
		return
	if not bool(state.has_visible_effects()):
		if _void_phantom_renderer.has_method("set_active"):
			_void_phantom_renderer.set_active(false)
		return
	var draw_context: Dictionary = state.build_draw_context()
	if draw_context.is_empty():
		if _void_phantom_renderer.has_method("set_active"):
			_void_phantom_renderer.set_active(false)
		return
	var textures_value: Variant = scene_draw_context.get("textures", {})
	if textures_value is Dictionary:
		var seal_ring_texture: Variant = textures_value.get("smasher_void_phantom_seal_ring", null)
		if seal_ring_texture is Texture2D:
			draw_context["seal_ring_texture"] = seal_ring_texture
	# 실제 공이 방금 사용한 완성 컨텍스트를 재사용한다. 스킬 색, 그림자,
	# 상태 오버레이, 공 전용 잔상과 LOD가 환영 쪽에서 따로 갈라지지 않는다.
	var effect_lod_scale: float = clampf(
		float(live_ball_renderer_context.get("effect_lod_scale", 1.0)), 0.25, 1.0
	)
	_void_phantom_renderer.draw(
		canvas,
		draw_context,
		shake_offset,
		effect_lod_scale,
		live_ball_renderer_context
	)


func _draw_active_item_field(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	perf_logger: Object = null
) -> void:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("draw_field_items"):
		if _get_method_argument_count(active_item_runtime, "draw_field_items") >= 4:
			active_item_runtime.draw_field_items(canvas, registry, shake_offset, perf_logger)
		else:
			active_item_runtime.draw_field_items(canvas, registry, shake_offset)


func _draw_lingpet_runtime(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary
) -> void:
	var runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("draw"):
		return
	if runtime.has_method("has_visible_effects") and not bool(runtime.has_visible_effects()):
		return
	runtime.draw(canvas, shake_offset, draw_context)


func _get_method_argument_count(target: Object, method_name: String) -> int:
	if target == null:
		return 0
	var cache_key := _get_method_cache_key(target, method_name)
	if _method_argument_count_cache.has(cache_key):
		return int(_method_argument_count_cache[cache_key])
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_value: Variant = method_info.get("args", [])
		if args_value is Array:
			var args_count: int = args_value.size()
			_method_argument_count_cache[cache_key] = args_count
			return args_count
	_method_argument_count_cache[cache_key] = 0
	return 0


func _method_accepts_argument_count(target: Object, method_name: String, arg_count: int) -> bool:
	if target == null:
		return false
	var cache_key := "%s:%d" % [_get_method_cache_key(target, method_name), arg_count]
	if _method_accepts_argument_count_cache.has(cache_key):
		return bool(_method_accepts_argument_count_cache[cache_key])
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_count: int = 0
		var args_value: Variant = method_info.get("args", [])
		if args_value is Array:
			args_count = args_value.size()
		var default_count: int = 0
		var default_value: Variant = method_info.get("default_args", [])
		if default_value is Array:
			default_count = default_value.size()
		# declared-defaults <= requested <= declared (battle_scene_drawer와
		# 동일 계약) — 구판 requested <= declared+defaults 는 디폴트를 이중
		# 계산해 3선언/1디폴트 메서드를 4-인자 호출 가능으로 오판한다.
		var min_args_count: int = max(0, args_count - default_count)
		var accepts := arg_count >= min_args_count and arg_count <= args_count
		_method_accepts_argument_count_cache[cache_key] = accepts
		return accepts
	_method_accepts_argument_count_cache[cache_key] = false
	return false


func _get_method_cache_key(target: Object, method_name: String) -> String:
	return "%d:%s" % [target.get_instance_id(), method_name]


func _draw_weather_effects(canvas: CanvasItem, registry: Object, shake_offset: Vector2, draw_context: Dictionary) -> void:
	var weather_driver: Object = _get_instance(registry, "battle_scene_weather_update_driver")
	if weather_driver != null and weather_driver.has_method("draw_weather"):
		weather_driver.draw_weather(canvas, registry, shake_offset, draw_context)


func _should_draw_weather_effects(registry: Object, draw_context: Dictionary) -> bool:
	var weather_driver: Object = _get_instance(registry, "battle_scene_weather_update_driver")
	if weather_driver == null:
		return false
	if weather_driver.has_method("should_draw_weather"):
		return bool(weather_driver.should_draw_weather(registry, draw_context))
	return weather_driver.has_method("draw_weather")


func _draw_active_item_pickup_effect(canvas: CanvasItem, registry: Object, perf_logger: Object = null) -> void:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("draw_pickup_effect"):
		if _get_method_argument_count(active_item_runtime, "draw_pickup_effect") >= 3:
			active_item_runtime.draw_pickup_effect(canvas, registry, perf_logger)
		else:
			active_item_runtime.draw_pickup_effect(canvas, registry)


func _draw_mythic_item_field_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	perf_logger: Object = null,
	draw_context: Dictionary = {}
) -> void:
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("draw_field_effects"):
		if mythic_item_runtime.has_method("has_visible_field_effects") and not bool(mythic_item_runtime.has_visible_field_effects()):
			return
		if _mythic_draw_field_effects_uses_draw_context(mythic_item_runtime):
			mythic_item_runtime.draw_field_effects(
				canvas,
				registry,
				shake_offset,
				perf_logger,
				_get_instance(registry, "horizontal_timer_gauge_stack"),
				draw_context
			)
		elif _mythic_draw_field_effects_uses_timer_stack(mythic_item_runtime):
			mythic_item_runtime.draw_field_effects(
				canvas,
				registry,
				shake_offset,
				perf_logger,
				_get_instance(registry, "horizontal_timer_gauge_stack")
			)
		elif _mythic_draw_field_effects_uses_perf_logger(mythic_item_runtime):
			mythic_item_runtime.draw_field_effects(canvas, registry, shake_offset, perf_logger)
		else:
			mythic_item_runtime.draw_field_effects(canvas, registry, shake_offset)


func _mythic_draw_field_effects_uses_timer_stack(mythic_item_runtime: Object) -> bool:
	if _mythic_draw_field_effects_accepts_timer_stack < 0:
		_mythic_draw_field_effects_accepts_timer_stack = 1 if _method_accepts_argument_count(mythic_item_runtime, "draw_field_effects", 5) else 0
	return _mythic_draw_field_effects_accepts_timer_stack == 1


func _mythic_draw_field_effects_uses_draw_context(mythic_item_runtime: Object) -> bool:
	if _mythic_draw_field_effects_accepts_draw_context < 0:
		_mythic_draw_field_effects_accepts_draw_context = 1 if _method_accepts_argument_count(mythic_item_runtime, "draw_field_effects", 6) else 0
	return _mythic_draw_field_effects_accepts_draw_context == 1


func _mythic_draw_field_effects_uses_perf_logger(mythic_item_runtime: Object) -> bool:
	if _mythic_draw_field_effects_accepts_perf_logger < 0:
		_mythic_draw_field_effects_accepts_perf_logger = 1 if _method_accepts_argument_count(mythic_item_runtime, "draw_field_effects", 4) else 0
	return _mythic_draw_field_effects_accepts_perf_logger == 1


func _begin_horizontal_timer_gauge_frame(registry: Object) -> void:
	var timer_stack: Object = _get_instance(registry, "horizontal_timer_gauge_stack")
	if timer_stack != null and timer_stack.has_method("begin_frame"):
		timer_stack.begin_frame()


func _end_horizontal_timer_gauge_frame(registry: Object) -> void:
	var timer_stack: Object = _get_instance(registry, "horizontal_timer_gauge_stack")
	if timer_stack != null and timer_stack.has_method("end_frame"):
		timer_stack.end_frame()


func _draw_stage1_balloon_background(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary
) -> void:
	if int(draw_context.get("current_stage", 1)) != 1:
		return
	var balloon_event: Object = _get_instance(registry, "stage1_balloon_event")
	if balloon_event != null and balloon_event.has_method("draw_background"):
		var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
		if _method_accepts_argument_count(balloon_event, "draw_background", 3):
			balloon_event.draw_background(canvas, shake_offset, perf_logger)
		else:
			balloon_event.draw_background(canvas, shake_offset)


func _draw_stage1_butterfly_event(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary
) -> void:
	if int(draw_context.get("current_stage", 1)) != 1:
		return
	var stage_background: Object = _get_instance(registry, "stage1_pillar_background")
	if stage_background != null and stage_background.has_method("draw_butterfly_ingame"):
		var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
		var quality_scale: float = BattleRenderQuality.effect_scale(draw_context)
		if _get_method_argument_count(stage_background, "draw_butterfly_ingame") >= 4:
			stage_background.draw_butterfly_ingame(canvas, shake_offset, perf_logger, quality_scale)
		elif _get_method_argument_count(stage_background, "draw_butterfly_ingame") >= 3:
			stage_background.draw_butterfly_ingame(canvas, shake_offset, perf_logger)
		else:
			stage_background.draw_butterfly_ingame(canvas, shake_offset)


func _draw_stage1_balloon_foreground(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary
) -> void:
	if int(draw_context.get("current_stage", 1)) != 1:
		return
	var balloon_event: Object = _get_instance(registry, "stage1_balloon_event")
	if balloon_event != null and balloon_event.has_method("draw_foreground"):
		var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
		# game_offset is forwarded so the GPU starpoint host (child of the outer
		# canvas, outside the playfield's draw_set_transform) can shift and scale
		# each drop's slot into rendered-playfield screen coordinates.
		var game_offset_value: Variant = draw_context.get("game_offset", Vector2.ZERO)
		var game_offset: Vector2 = game_offset_value if game_offset_value is Vector2 else Vector2.ZERO
		var render_scale: float = maxf(0.001, float(draw_context.get("render_scale", 1.0)))
		if _method_accepts_argument_count(balloon_event, "draw_foreground", 5):
			balloon_event.draw_foreground(canvas, shake_offset, perf_logger, game_offset, render_scale)
		elif _method_accepts_argument_count(balloon_event, "draw_foreground", 4):
			balloon_event.draw_foreground(canvas, shake_offset, perf_logger, game_offset)
		elif _method_accepts_argument_count(balloon_event, "draw_foreground", 3):
			balloon_event.draw_foreground(canvas, shake_offset, perf_logger)
		else:
			balloon_event.draw_foreground(canvas, shake_offset)


func _draw_stage1_spinning_top(
	canvas: CanvasItem,
	registry: Object,
	draw_context: Dictionary,
	actor_context: Dictionary
) -> void:
	if int(draw_context.get("current_stage", 1)) != 1:
		return
	var actor_renderer: Object = _get_instance(registry, "stage1_actor_renderer")
	if actor_renderer == null or actor_context.is_empty() or not actor_renderer.has_method("draw_spinning_top"):
		return
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	if _get_method_argument_count(actor_renderer, "draw_spinning_top") >= 3:
		actor_renderer.draw_spinning_top(canvas, actor_context, perf_logger)
	else:
		actor_renderer.draw_spinning_top(canvas, actor_context)


func _draw_stage_playfield_overlay(
	canvas: CanvasItem,
	stage_background: Object,
	shake_offset: Vector2,
	draw_context: Dictionary,
	perf_logger: Object
) -> void:
	if stage_background != null and stage_background.has_method("draw_playfield_overlay"):
		if _get_method_argument_count(stage_background, "draw_playfield_overlay") >= 4:
			stage_background.draw_playfield_overlay(canvas, draw_context, shake_offset, perf_logger)
		else:
			stage_background.draw_playfield_overlay(canvas, draw_context, shake_offset)


func _draw_stage_playfield_obstacles(
	canvas: CanvasItem,
	stage_background: Object,
	shake_offset: Vector2,
	draw_context: Dictionary,
	perf_logger: Object
) -> void:
	if stage_background != null and stage_background.has_method("draw_playfield_obstacles"):
		if _get_method_argument_count(stage_background, "draw_playfield_obstacles") >= 4:
			stage_background.draw_playfield_obstacles(canvas, draw_context, shake_offset, perf_logger)
		else:
			stage_background.draw_playfield_obstacles(canvas, draw_context, shake_offset)


func _draw_stage2_monkey_banana_event(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary
) -> void:
	if int(draw_context.get("current_stage", 1)) != 2:
		return
	var monkey_event: Object = _get_instance(registry, "stage2_monkey_banana_event")
	if monkey_event != null and monkey_event.has_method("draw_playfield"):
		monkey_event.draw_playfield(canvas, draw_context, shake_offset)
