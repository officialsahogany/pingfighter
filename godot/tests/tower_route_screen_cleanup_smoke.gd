extends SceneTree

const BattlePlayfieldEffectsDrawer := preload(
	"res://scripts/core/battle_playfield_effects_drawer.gd"
)
const BattleSceneDrawer := preload("res://scripts/core/battle_scene_drawer.gd")
const TowerAscentModalLifecycle := preload(
	"res://scripts/tower_ascent/tower_ascent_modal_lifecycle.gd"
)

const PILLAR_SCENE_FILES := [
	"res://scripts/stages/stage2/stage2_pillar_scene_drawer.gd",
	"res://scripts/stages/stage3/stage3_pillar_scene_drawer.gd",
	"res://scripts/stages/stage4/stage4_pillar_scene_drawer.gd",
	"res://scripts/stages/stage5/stage5_pillar_scene_drawer.gd",
	"res://scripts/stages/stage5/stage5_hongryun_pillar_scene_drawer.gd",
	"res://scripts/stages/stage6/stage6_tetriser_pillar_scene_drawer.gd",
	"res://scripts/stages/stage7/stage7_akamu_pillar_scene_drawer.gd",
	"res://scripts/stages/stage8/stage8_minotaur_pillar_scene_drawer.gd",
]

var _failures: Array[String] = []


class FakePlayerRenderer:
	extends RefCounted

	var draw_calls := 0
	var last_shake_offset := Vector2.ZERO

	func draw(
		_canvas: CanvasItem,
		_context: Dictionary,
		shake_offset: Vector2,
		_perf_logger: Object
	) -> void:
		draw_calls += 1
		last_shake_offset = shake_offset


class FakeActorRenderer:
	extends RefCounted

	var player_renderer: Object = FakePlayerRenderer.new()
	var clear_calls := 0
	var full_draw_calls := 0

	func clear_transient_canvas_items() -> void:
		clear_calls += 1

	func draw(_canvas: CanvasItem, _context: Dictionary) -> void:
		full_draw_calls += 1


class FakeStageRuntimeRouter:
	extends RefCounted

	var actor_renderer: Object

	func _init(value: Object) -> void:
		actor_renderer = value

	func get_instance(
		_registry: Object,
		_stage: int,
		role: String
	) -> Object:
		return actor_renderer if role == "actor_renderer" else null


class FakeEffectsRegistry:
	extends RefCounted

	var router: Object

	func _init(actor_renderer: Object) -> void:
		router = FakeStageRuntimeRouter.new(actor_renderer)

	func get_instance(key: String) -> Object:
		return router if key == "stage_runtime_router" else null


class FakeRouteFlow:
	extends RefCounted

	var active := true
	var phase := "ROUTE_AIM"

	func is_active() -> bool:
		return active

	func get_phase_name() -> String:
		return phase

	func has_renderable_retained_noncombat_node_background() -> bool:
		return false


class FakeFlowRegistry:
	extends RefCounted

	var flow: Object

	func _init(value: Object) -> void:
		flow = value

	func get_cached_instance(key: String) -> Object:
		return flow if key == "tower_ascent_flow_owner" else null


class FakeRuntimePerkState:
	extends RefCounted

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass

	func _resume_skill_cooldowns_for_choice() -> void:
		pass

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass


class FakeAudio:
	extends RefCounted

	var stop_stage2_calls := 0
	var stop_stage5_calls := 0

	func stop_stage2_quake_loop() -> void:
		stop_stage2_calls += 1

	func stop_stage5_hongryun_fireball() -> void:
		stop_stage5_calls += 1


class FakeLifecycleRegistry:
	extends RefCounted

	var runtime_state := FakeRuntimePerkState.new()
	var audio := FakeAudio.new()

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime_state
		if key == "game_audio":
			return audio
		return null


func _init() -> void:
	_verify_route_composition_and_reverse_gate()
	_verify_player_only_actor_slice_and_transient_cleanup()
	_verify_balloon_and_boss_rail_owners()
	_verify_tower_entry_stops_detached_loop_audio()
	if _failures.is_empty():
		print("tower_route_screen_cleanup_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_route_composition_and_reverse_gate() -> void:
	var drawer := BattleSceneDrawer.new()
	var flow := FakeRouteFlow.new()
	var registry := FakeFlowRegistry.new(flow)
	_expect(
		not bool(drawer.call("_should_draw_tower_battle_playfield", registry)),
		"active initial ROUTE_AIM must suppress the full battle playfield",
	)
	_expect(
		bool(drawer.call("_should_suppress_tower_boss_skill_hud", registry)),
		"active Tower route aim must suppress boss-skill rails",
	)
	flow.phase = "COMBAT"
	_expect(
		not bool(drawer.call("_should_suppress_tower_boss_skill_hud", registry)),
		"active Tower combat must preserve boss-skill rails",
	)
	flow.phase = "MAP_OVERLAY"
	_expect(
		bool(drawer.call("_should_suppress_tower_boss_skill_hud", registry)),
		"active Tower map overlay must suppress boss-skill rails",
	)
	flow.active = false
	_expect(
		bool(drawer.call("_should_draw_tower_battle_playfield", registry)),
		"inactive/non-Tower flow must restore the normal full playfield",
	)
	_expect(
		not bool(drawer.call("_should_suppress_tower_boss_skill_hud", registry)),
		"inactive/non-Tower flow must restore boss-skill rails",
	)
	var source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_drawer.gd"
	)
	var route_body := _function_body(
		source,
		"func _draw_tower_ascent_playfield_flow_only("
	)
	var border_index := route_body.find("draw_tower_route_playfield_border")
	var player_index := route_body.find("draw_tower_route_player")
	var ball_index := route_body.find("draw_tower_route_selector_ball")
	_expect(
		border_index >= 0 and player_index > border_index and ball_index > player_index,
		"route aim must compose border, player, then selector ball as explicit slices",
	)
	_expect(
		route_body.find("_draw_playfield_scene") < 0,
		"route-only composition must never call the full playfield scene",
	)


func _verify_player_only_actor_slice_and_transient_cleanup() -> void:
	var actor := FakeActorRenderer.new()
	var effects := BattlePlayfieldEffectsDrawer.new()
	effects.draw_tower_route_player(
		null,
		FakeEffectsRegistry.new(actor),
		{"current_stage": 1},
		{"shake_offset": Vector2(3.0, -2.0)},
		null
	)
	var player := actor.player_renderer as FakePlayerRenderer
	_expect(actor.clear_calls == 1, "route player slice must clear detached actor hosts first")
	_expect(actor.full_draw_calls == 0, "route player slice must not invoke the stage actor draw")
	_expect(player.draw_calls == 1, "route player slice must invoke only the existing player renderer")
	_expect(player.last_shake_offset == Vector2(3.0, -2.0), "route player slice must preserve the actor shake sample")


func _verify_balloon_and_boss_rail_owners() -> void:
	var playfield_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_playfield_scene_drawer.gd"
	)
	var full_draw_body := _function_body(playfield_source, "func draw(")
	_expect(
		full_draw_body.find("_draw_stage1_balloon_background") >= 0
		and full_draw_body.find("_draw_stage1_balloon_foreground") >= 0,
		"the stale Stage 1 balloon owner must remain confined to the full playfield draw",
	)
	var shared_hud_source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd"
	)
	_expect(
		shared_hud_source.find("include_stage1_boss_skill_hud and not bool(context.get(\"suppress_boss_skill_hud\", false))") >= 0,
		"the shared Dalji/Gaksi rail owner must honor the Tower suppression context",
	)
	for path in PILLAR_SCENE_FILES:
		var source := FileAccess.get_file_as_string(path)
		_expect(
			source.find("bool(context.get(\"suppress_boss_skill_hud\", false))") >= 0,
			"%s must honor the Tower boss-skill rail suppression context" % path,
		)


func _verify_tower_entry_stops_detached_loop_audio() -> void:
	var lifecycle := TowerAscentModalLifecycle.new()
	var registry := FakeLifecycleRegistry.new()
	var result: Dictionary = lifecycle.enter(RefCounted.new(), registry)
	_expect(bool(result.get("accepted", false)), "Tower modal lifecycle must accept the production-shaped entry")
	_expect(registry.audio.stop_stage2_calls == 1, "Tower entry must stop detached Stage 2 loop audio")
	_expect(registry.audio.stop_stage5_calls == 1, "Tower entry must stop detached Stage 5 loop audio")
	lifecycle.leave()


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if next_func < 0 else source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
