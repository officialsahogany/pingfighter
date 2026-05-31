extends SceneTree

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const BattleSceneLifecycle := preload("res://scripts/core/battle_scene_lifecycle.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetSaveStore := preload("res://scripts/lingpet/lingpet_save_store.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior league"
	var selected_character_type := "smasher"
	var player_pos := Vector2(263.75, 675.0)
	var player_paddle_width := 232.5
	var player_paddle_height := 75.0
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_serve_origin := ""
	var ball_size := 28.6
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var lingpet_id := ""
	var active_lingpet_id := ""
	var current_lingpet_id := ""
	var lingpet_state := "none"
	var ringpet_state := "none"
	var lingpet_hatch_hits := 0
	var ringpet_hatch_hits := 0
	var lingpet_hatch_required_hits := 3
	var ringpet_hatch_required_hits := 3
	var lingpet_egg_pos := Vector2.ZERO
	var lingpet_companion_pos := Vector2.ZERO
	var ringpet_companion_pos := Vector2.ZERO
	var lingpet_companion_contact_count := 0
	var ringpet_companion_contact_count := 0
	var lingpet_companion_last_contact_pos := Vector2.ZERO
	var ringpet_companion_last_contact_pos := Vector2.ZERO
	var lingpet_companion_hit_cooldown := 0.0
	var ringpet_companion_hit_cooldown := 0.0
	var lingpet_skill_id := ""
	var ringpet_skill_id := ""
	var lingpet_skill_name := ""
	var ringpet_skill_name := ""
	var lingpet_skill_cooldown := 0.0
	var ringpet_skill_cooldown := 0.0
	var lingpet_skill_cooldown_duration := 6.0
	var ringpet_skill_cooldown_duration := 6.0
	var lingpet_skill_ready := false
	var ringpet_skill_ready := false
	var lingpet_skill_last_gain := 0.0
	var ringpet_skill_last_gain := 0.0
	var lingpet_skill_trigger_count := 0
	var ringpet_skill_trigger_count := 0
	var lingpet_effect_text := ""
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}


class FakeBattleOwner:
	extends Node2D

	var current_stage := 1
	var ai_mode := "champion"
	var arena_mode_enabled := false
	var weather_type := ""
	var lingpet_id := ""
	var active_lingpet_id := ""
	var current_lingpet_id := ""
	var lingpet_state := "none"
	var ringpet_state := "none"
	var lingpet_hatch_hits := 0
	var ringpet_hatch_hits := 0
	var lingpet_hatch_required_hits := 3
	var ringpet_hatch_required_hits := 3
	var lingpet_egg_pos := Vector2.ZERO
	var lingpet_companion_pos := Vector2.ZERO
	var ringpet_companion_pos := Vector2.ZERO
	var lingpet_companion_contact_count := 0
	var ringpet_companion_contact_count := 0
	var lingpet_companion_last_contact_pos := Vector2.ZERO
	var ringpet_companion_last_contact_pos := Vector2.ZERO
	var lingpet_companion_hit_cooldown := 0.0
	var ringpet_companion_hit_cooldown := 0.0
	var lingpet_skill_id := ""
	var ringpet_skill_id := ""
	var lingpet_skill_name := ""
	var ringpet_skill_name := ""
	var lingpet_skill_cooldown := 0.0
	var ringpet_skill_cooldown := 0.0
	var lingpet_skill_cooldown_duration := 6.0
	var ringpet_skill_cooldown_duration := 6.0
	var lingpet_skill_ready := false
	var ringpet_skill_ready := false
	var lingpet_skill_last_gain := 0.0
	var ringpet_skill_last_gain := 0.0
	var lingpet_skill_trigger_count := 0
	var ringpet_skill_trigger_count := 0
	var lingpet_effect_text := ""
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}


class FakeBootstrap:
	extends RefCounted

	func initialize(_owner: Node, _context: Dictionary, _registry: Object) -> Dictionary:
		return {}


class FakeFeedback:
	extends RefCounted

	var gauge_flashes := 0

	func trigger_gauge_flash() -> void:
		gauge_flashes += 1


class FakeOrbHudState:
	extends RefCounted

	var gauge_spins := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		gauge_spins += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		if value is Object:
			return value
		return null


func _init() -> void:
	_verify_registry_and_frame_wiring()
	_verify_junior_mika_spawn_syncs_character_info_keys()
	_verify_egg_player_contact_nudges_and_wobbles()
	_verify_player_serve_ball_does_not_hatch_egg()
	_verify_egg_hit_uses_player_paddle_reflection()
	_verify_two_ball_hits_hatch_maribo()
	_verify_acquire_cutin_triggers_on_hatch()
	_verify_owned_maribo_is_kept_as_companion()
	_verify_companion_visual_and_pillar_card()
	_verify_companion_patrol_edge_pause_and_speed_change()
	_verify_companion_ball_collision_soft_bounce()
	_verify_companion_skill_card_gauge_charge()
	_verify_save_snapshot_roundtrip()
	_verify_save_store_persists_and_restores_maribo()
	_verify_battle_lifecycle_restores_lingpet_save()
	_verify_maribo_companion_gauge_bonus()
	_verify_ineligible_conditions_do_not_spawn()

	if _failures.is_empty():
		print("lingpet_egg_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_registry_and_frame_wiring() -> void:
	var registry := GameplayModuleRegistry.new()
	var runtime: Object = registry.get_instance("lingpet_egg_runtime")
	_expect(runtime != null and runtime.has_method("update"), "lingpet egg runtime should be registered")
	var save_store: Object = registry.get_instance("lingpet_save_store")
	_expect(save_store != null and save_store.has_method("restore_runtime"), "lingpet save store should be registered")
	var callback_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_update_callbacks.gd")
	var flow_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_frame_flow_controller.gd")
	var drawer_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	var lifecycle_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_lifecycle.gd")
	var deps_source: String = FileAccess.get_file_as_string("res://scripts/ball/ball_dependency_context.gd")
	var hit_router_source: String = FileAccess.get_file_as_string("res://scripts/ball/paddle_bounce_event_router.gd")
	var character_info_source: String = FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay.gd")
	var pillar_hud_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
	var pillar_ui_source: String = FileAccess.get_file_as_string("res://scripts/hud/stage1_pillar_ui_renderer.gd")
	_expect(callback_source.find("update_lingpet") >= 0, "battle callbacks should expose lingpet update")
	_expect(callback_source.find("save_runtime(owner, registry)") >= 0, "battle callbacks should persist lingpet runtime changes")
	_expect(flow_source.find("update_lingpet") >= 0, "battle flow should update lingpet after ball/serve flow")
	_expect(drawer_source.find("lingpet_egg_runtime") >= 0, "playfield drawer should render visible lingpet runtime")
	_expect(lifecycle_source.find("_restore_lingpet_save(owner, registry)") >= 0, "battle lifecycle should restore saved lingpet data after bootstrap")
	_expect(deps_source.find("\"lingpet_egg_runtime\"") >= 0, "ball dependencies should expose the lingpet runtime")
	_expect(hit_router_source.find("get_gauge_gain_per_hit") >= 0, "player hit gauge routing should read lingpet gauge bonuses")
	_expect(character_info_source.find("_frame_stat_sources.append(lingpet_runtime)") >= 0, "character info stats should include lingpet stat sources")
	_expect(pillar_hud_source.find("\"lingpet_runtime\"") >= 0, "shared pillar HUD should pass lingpet runtime to the pillar UI")
	_expect(pillar_ui_source.find("draw_pillar_card") >= 0, "shared pillar UI should draw the ringpet card beside the skill cluster")
	_expect(drawer_source.find("lingpet_egg_runtime") >= 0, "playfield drawer should keep drawing the ringpet companion after hatching")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_egg_v002.png"), "Maribo egg should use a PNG-backed runtime asset")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_egg_v002_crack1.png"), "Maribo egg should have a first-hit cracked PNG variant")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_egg_v002_crack2.png"), "Maribo egg should have a second-hit cracked PNG variant")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(runtime_source.find("MARIBO_EGG_TEXTURE_CRACK_1") >= 0, "field egg rendering should switch to the first cracked asset after one hit")
	_expect(runtime_source.find("MARIBO_EGG_TEXTURE_CRACK_2") >= 0, "field egg rendering should switch to the second cracked asset after two hits")
	_expect(runtime_source.find("_draw_egg_crack_light") >= 0, "field egg rendering should leak light from cracked shell paths after a hatch hit")
	_expect(runtime_source.find("HATCH_BREAK_SHARD_COUNT") >= 0, "field hatch should keep a shell-fragment burst spec")
	_expect(runtime_source.find("_draw_hatch_shell_burst") >= 0, "field hatch should draw breaking egg fragments during the hatch flash")
	_verify_companion_walk_sheet_wiring(runtime_source)
	_verify_acquire_cutin_wiring(runtime_source)


func _verify_acquire_cutin_wiring(runtime_source: String) -> void:
	# The fullscreen acquisition cut-in reveals the ORIGINAL outsourced artwork
	# (not the SD walk sheet) once on hatch, as an overlay drawn above the HUD.
	# Seal the asset + host registration + frame-controller hook + prewarm so the
	# reveal cannot silently stop firing.
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_cutin_art.png"), "Maribo acquisition cut-in should keep the nukki'd original-art PNG as fallback")
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_cutin_anim.png"), "Maribo acquisition cut-in should use the AutoSprite Live2D-style animation sheet")
	_expect(FileAccess.file_exists("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd"), "lingpet acquisition cut-in overlay host should exist")
	var cutin_host_source: String = FileAccess.get_file_as_string("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
	_expect(cutin_host_source.find("CUTIN_ANIM_SHEET") >= 0, "cut-in host should reference the Live2D-style animation sheet")
	_expect(cutin_host_source.find("draw_texture_rect_region") >= 0, "cut-in host should frame-step the animation sheet")
	_expect(runtime_source.find("is_acquire_cutin_active") >= 0, "lingpet runtime should expose the acquisition cut-in active flag")
	_expect(runtime_source.find("get_acquire_cutin_progress") >= 0, "lingpet runtime should expose the acquisition cut-in progress")
	_expect(runtime_source.find("advance_acquire_cutin") >= 0, "lingpet runtime should advance the cut-in from the ungated idle pump")
	_expect(runtime_source.find("is_acquire_cutin_awaiting_dismiss") >= 0, "lingpet runtime should expose the post-reveal dismissable state")
	_expect(runtime_source.find("dismiss_acquire_cutin") >= 0, "lingpet runtime should support click dismissal of the cut-in")
	var hud_catalog_source: String = FileAccess.get_file_as_string("res://scripts/resources/gameplay_hud_module_catalog.gd")
	_expect(hud_catalog_source.find("lingpet_acquire_cutin_overlay_host") >= 0, "HUD module catalog should register the lingpet acquisition cut-in host")
	var frame_controller_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(frame_controller_source.find("_draw_lingpet_acquire_cutin_if_active") >= 0, "battle frame controller should draw the lingpet acquisition cut-in above the HUD")
	_expect(frame_controller_source.find("lingpet_acquire_cutin_overlay_host") >= 0, "battle frame controller should resolve the lingpet acquisition cut-in host")
	_expect(frame_controller_source.find("advance_acquire_cutin") >= 0, "battle frame controller idle pump should advance the cut-in while physics is paused")
	var prewarm_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
	_expect(prewarm_source.find("lingpet_acquire_cutin_overlay_host") >= 0, "Smasher prewarm should warm the lingpet acquisition cut-in host before the hatch frame")
	# Pause + dismiss wiring: the cut-in must gate battle physics and be reachable
	# by the overlay input controller for click dismissal.
	var modal_gate_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_modal_gate_controller.gd")
	_expect(modal_gate_source.find("is_lingpet_acquire_cutin_active") >= 0, "modal gate should expose the lingpet acquisition cut-in as a physics-blocking modal")
	_expect(modal_gate_source.find("physics.modal_gate.lingpet_acquire_cutin") >= 0, "modal gate should block battle physics while the acquisition cut-in is active")
	var input_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_input_controller.gd")
	_expect(input_source.find("is_acquire_cutin_awaiting_dismiss") >= 0, "overlay input controller should only dismiss the cut-in after the reveal finishes")
	_expect(input_source.find("dismiss_acquire_cutin") >= 0, "overlay input controller should dismiss the cut-in on click/confirm")
	var modal_gate: Object = GameplayModuleRegistry.new().get_instance("battle_scene_modal_gate_controller")
	_expect(modal_gate != null and modal_gate.has_method("is_lingpet_acquire_cutin_active"), "modal gate controller should implement the cut-in gate method")
	var host: Object = GameplayModuleRegistry.new().get_instance("lingpet_acquire_cutin_overlay_host")
	_expect(host != null and host.has_method("draw"), "lingpet acquisition cut-in host should be registered and drawable")


func _verify_companion_walk_sheet_wiring(runtime_source: String) -> void:
	# The hatched companion now renders from the AutoSprite back-view walk sheet
	# (idle is derived from the same sheet). Seal the asset + grid spec so a
	# future PNG swap or grid change cannot silently desync the frame math.
	_expect(FileAccess.file_exists("res://assets/sprites/lingpet/maribo_companion_walk.png"), "Maribo companion should use a PNG-backed back-view walk sheet")
	_expect(runtime_source.find("MARIBO_COMPANION_WALK_SHEET") >= 0, "companion rendering should reference the walk-sheet texture")
	_expect(runtime_source.find("draw_texture_rect_region") >= 0, "companion rendering should blit walk-sheet cells, not draw a procedural body")
	_expect(runtime_source.find("_get_companion_sprite_frame") >= 0, "companion rendering should resolve a sheet frame per draw")
	var sheet: Texture2D = load("res://assets/sprites/lingpet/maribo_companion_walk.png") as Texture2D
	_expect(sheet != null, "companion walk sheet should load as a Texture2D")
	if sheet != null:
		# Grid metadata is hardcoded in the runtime; the asset must divide evenly
		# by it, and the frame count must fit cols*rows.
		var cols := 5
		var rows := 5
		var frames := 25
		_expect(sheet.get_width() % cols == 0, "walk sheet width must divide evenly into the column count")
		_expect(sheet.get_height() % rows == 0, "walk sheet height must divide evenly into the row count")
		_expect(frames <= cols * rows, "declared frame count must fit the walk-sheet grid")
	var player_serve_snapshot: Dictionary = BallRoundState.new().build_serve_snapshot(
		true,
		Vector2(300.0, 675.0),
		Vector2(300.0, 25.0),
		700.0,
		25.0,
		155.0,
		100.0,
		40.0,
		28.6,
		14.3,
		null
	)
	var boss_serve_snapshot: Dictionary = BallRoundState.new().build_serve_snapshot(
		false,
		Vector2(300.0, 675.0),
		Vector2(300.0, 25.0),
		700.0,
		25.0,
		155.0,
		100.0,
		40.0,
		28.6,
		14.3,
		null
	)
	_expect(str(player_serve_snapshot.get("ball_serve_origin", "")) == "player", "player serve snapshots should mark the serve origin")
	_expect(str(boss_serve_snapshot.get("ball_serve_origin", "")) == "boss", "boss serve snapshots should mark the serve origin")


func _verify_junior_mika_spawn_syncs_character_info_keys() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.update(0.0, owner), "Junior Mika should spawn the first Maribo egg immediately")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(str(snapshot.get("state", "")) == "egg", "first Maribo state should become egg")
	_expect(str(owner.lingpet_id) == "maribo", "owner should publish the Maribo id for the character-info panel")
	_expect(str(owner.lingpet_state) == "egg", "owner should publish egg state")
	_expect(int(owner.lingpet_hatch_hits) == 0, "egg should start at 0 hatch hits")
	_expect(int(owner.lingpet_hatch_required_hits) == 2, "egg should require two hits to hatch")
	_expect(owner.lingpet_egg_pos is Vector2, "egg should publish a playfield position")
	var expected_floor_y := 750.0 - 28.0 - 18.0
	_expect(absf(owner.lingpet_egg_pos.y - expected_floor_y) <= 1.0, "egg should start as a floor-placed brick-like object")

	var panel: Dictionary = CharacterInfoOverlay.new()._get_lingpet_panel_snapshot(owner)
	_expect(str(panel.get("state", "")) == "egg", "character-info ringpet panel should read the shared egg state")
	_expect(str(panel.get("subtitle", "")).find("0 / 2") >= 0, "character-info panel should show hatch progress")


func _verify_egg_player_contact_nudges_and_wobbles() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var start_pos: Vector2 = owner.lingpet_egg_pos
	owner.player_pos = Vector2(
		start_pos.x - owner.player_paddle_width * 0.5 - 16.0,
		start_pos.y - owner.player_paddle_height * 0.5
	)
	runtime.update(0.016, owner)
	var snapshot: Dictionary = runtime.get_snapshot()
	var first_nudge: float = owner.lingpet_egg_pos.x - start_pos.x
	_expect(first_nudge > 0.0 and first_nudge < 0.6, "player contact should gently nudge the Ringpet egg away from the player")
	_expect(absf(float(snapshot.get("egg_wobble_angle", 0.0))) > 0.01, "player contact should wobble the Ringpet egg")
	_expect(int(owner.lingpet_hatch_hits) == 0, "player contact should not count as a hatch hit")
	for _idx in range(30):
		runtime.update(0.016, owner)
	var sustained_nudge: float = owner.lingpet_egg_pos.x - start_pos.x
	_expect(sustained_nudge < 14.0, "sustained player contact should not shove the Ringpet egg too far")


func _verify_player_serve_ball_does_not_hatch_egg() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	owner.ball_serve_origin = "player"
	_register_hit(runtime, owner, egg_pos, 1)
	_expect(int(owner.lingpet_hatch_hits) == 0, "player serve ball should bounce off the egg without cracking it")
	_expect(str(owner.lingpet_state) == "egg", "player serve ball should not hatch the Ringpet egg")
	_expect(owner.ball_vel.y < 0.0, "ignored player serve hit should still reflect toward the opponent side")

	owner.ball_serve_origin = "boss"
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	runtime.update(0.21, owner)
	_register_hit(runtime, owner, egg_pos, 2)
	_expect(int(owner.lingpet_hatch_hits) == 1, "non-player-serve ball hits should still crack the egg")


func _verify_egg_hit_uses_player_paddle_reflection() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	owner.ball_pos = egg_pos + Vector2(30.0, -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner)
	_expect(int(owner.lingpet_hatch_hits) == 1, "egg paddle-reflection hit should still crack the egg")
	_expect(owner.ball_vel.y < 0.0, "egg hit should reflect the ball toward the opponent side")
	_expect(owner.ball_vel.x > 0.0, "right-side egg contact should angle the reflected ball to the right like a paddle hit")
	_expect(owner.ball_pos.y < egg_pos.y, "egg hit should separate the ball above the egg after reflection")


func _verify_two_ball_hits_hatch_maribo() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true

	_register_hit(runtime, owner, egg_pos, 1)
	_expect(int(owner.lingpet_hatch_hits) == 1, "first hit should crack the egg but not yet hatch")
	_expect(str(owner.lingpet_state) == "egg", "egg should still be unhatched after one hit")
	_expect(owner.ball_vel.y < 0.0, "egg hit should reflect a downward ball toward the opponent side")

	_register_hit(runtime, owner, egg_pos, 2)
	_expect(str(owner.lingpet_state) == "companion", "second hit should hatch Maribo into companion state")
	_expect(str(owner.active_lingpet_id) == "maribo", "hatched Maribo should become the active lingpet")
	_expect(owner.lingpet_owned_pet_ids.has("maribo"), "hatched Maribo should be added to the owned pet id list")
	_expect(bool(owner.lingpet_collection.get("maribo", false)), "hatched Maribo should be marked in the lingpet collection")
	_expect(is_equal_approx(float(runtime.get_gauge_gain_per_hit(50.0)), 55.0), "hatched Maribo should expose a 10% gauge-gain bonus")
	_expect(runtime.has_visible_effects(), "hatched Maribo should keep visible companion effects after hatching")
	_expect(owner.lingpet_companion_pos is Vector2 and owner.lingpet_companion_pos != Vector2.ZERO, "hatched Maribo should publish companion position")
	_expect(float(runtime.get_snapshot().get("hatch_flash_timer", 0.0)) > 0.0, "hatched Maribo should keep the egg-break animation active briefly")
	var panel: Dictionary = CharacterInfoOverlay.new()._get_lingpet_panel_snapshot(owner)
	_expect(str(panel.get("title", "")) == "마리보", "character-info panel should show Maribo after hatching")
	_expect(str(panel.get("subtitle", "")) == "동행 중", "character-info panel should show companion status after hatching")


func _register_hit(runtime: Object, owner: FakeOwner, egg_pos: Vector2, index: int) -> void:
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.21, owner)
	owner.ball_pos = egg_pos + Vector2(float(index), -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner)


func _verify_acquire_cutin_triggers_on_hatch() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	_register_hit(runtime, owner, egg_pos, 1)
	_expect(not bool(runtime.is_acquire_cutin_active()), "acquisition cut-in should not start before the egg fully hatches")
	_register_hit(runtime, owner, egg_pos, 2)
	_expect(str(owner.lingpet_state) == "companion", "second hit should hatch Maribo before the cut-in check")
	_expect(bool(runtime.is_acquire_cutin_active()), "hatching should trigger the fullscreen acquisition cut-in")
	_expect(is_equal_approx(float(runtime.get_acquire_cutin_progress()), 0.0), "acquisition cut-in should start at zero progress")
	_expect(not bool(runtime.is_acquire_cutin_awaiting_dismiss()), "acquisition cut-in should not be dismissable before the reveal finishes")
	# The gated update driver must NOT advance the reveal -- only the ungated idle
	# pump does, via advance_acquire_cutin(). update() here is a no-op for it.
	runtime.update(5.0, owner)
	_expect(bool(runtime.is_acquire_cutin_active()) and is_equal_approx(float(runtime.get_acquire_cutin_progress()), 0.0), "gated update() must not advance the acquisition cut-in reveal")
	# Idle-pump advance drives the reveal; once the reveal duration elapses it
	# holds and becomes dismissable instead of auto-closing.
	runtime.advance_acquire_cutin(0.5)
	_expect(float(runtime.get_acquire_cutin_progress()) > 0.0, "advance_acquire_cutin should progress the reveal")
	_expect(not bool(runtime.is_acquire_cutin_awaiting_dismiss()), "reveal still playing should not be dismissable yet")
	runtime.advance_acquire_cutin(2.0)
	_expect(bool(runtime.is_acquire_cutin_active()), "acquisition cut-in should HOLD after the reveal (no auto-close)")
	_expect(bool(runtime.is_acquire_cutin_awaiting_dismiss()), "finished reveal should be dismissable")
	_expect(is_equal_approx(float(runtime.get_acquire_cutin_progress()), 1.0), "held reveal progress should clamp at 1.0")
	# Click/confirm dismissal resumes the battle.
	_expect(bool(runtime.dismiss_acquire_cutin()), "dismiss should consume the active cut-in")
	_expect(not bool(runtime.is_acquire_cutin_active()), "dismissed cut-in should be inactive so battle physics resumes")
	_expect(not bool(runtime.dismiss_acquire_cutin()), "dismissing an inactive cut-in should be a no-op")

	# Re-adopting an already-owned Maribo (no hatch event) must NOT replay the
	# acquisition cut-in.
	var owned_owner := FakeOwner.new()
	owned_owner.lingpet_owned_pet_ids = ["maribo"]
	var owned_runtime: Object = LingpetEggRuntime.new()
	owned_runtime.update(0.0, owned_owner)
	_expect(str(owned_owner.lingpet_state) == "companion", "owned Maribo should adopt directly as companion")
	_expect(not bool(owned_runtime.is_acquire_cutin_active()), "adopting an already-owned Maribo should not replay the acquisition cut-in")


func _verify_owned_maribo_is_kept_as_companion() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.update(0.0, owner), "owned Maribo should sync as a companion instead of spawning an egg")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(str(snapshot.get("state", "")) == "companion", "owned Maribo should restore companion runtime state")
	_expect(str(owner.lingpet_state) == "companion", "owned Maribo should publish companion state to the owner")
	_expect(str(owner.active_lingpet_id) == "maribo", "owned Maribo should become the active lingpet")


func _verify_companion_visual_and_pillar_card() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var first_pos: Vector2 = owner.lingpet_companion_pos
	var expected_lane_y: float = owner.player_pos.y + owner.player_paddle_height * 0.5
	_expect(runtime.has_visible_effects(), "owned Maribo companion should remain visible on the playfield")
	_expect(runtime.has_pillar_card(), "owned Maribo companion should expose a left-pillar card")
	_expect(absf(first_pos.y - expected_lane_y) <= 1.0, "owned Maribo companion should start on the player-height patrol lane")
	_expect(first_pos.x >= 42.0 and first_pos.x <= 718.0, "owned Maribo companion should start inside the patrol bounds")
	owner.player_pos.x += 120.0
	runtime.update(0.5, owner)
	var moved_pos: Vector2 = owner.lingpet_companion_pos
	_expect(absf(moved_pos.y - expected_lane_y) <= 1.0, "Maribo companion should stay on the player-height patrol lane")
	_expect(absf(moved_pos.x - first_pos.x) > 1.0, "Maribo companion should patrol independently instead of attaching to the player side")
	_expect(absf(moved_pos.x - (owner.player_pos.x + owner.player_paddle_width * 0.5)) > 20.0, "Maribo companion should not snap to the paddle center after player movement")
	var snapshot: Dictionary = runtime.get_save_snapshot()
	_expect(snapshot.get("companion_pos", Vector2.ZERO) is Vector2, "save snapshot should keep companion visual position")
	_expect(float(snapshot.get("companion_patrol_dir", 0.0)) != 0.0, "save snapshot should keep Maribo patrol direction")
	_expect(float(snapshot.get("companion_patrol_speed", 0.0)) >= 70.0 and float(snapshot.get("companion_patrol_speed", 0.0)) <= 135.0, "save snapshot should keep Maribo's current patrol speed")


func _verify_companion_patrol_edge_pause_and_speed_change() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.apply_save_snapshot({
		"pet_id": "maribo",
		"state": "companion",
		"owned_pet_ids": ["maribo"],
		"companion_pos": Vector2(43.0, 704.0),
		"companion_patrol_dir": -1.0,
		"companion_patrol_seed": 12345,
		"companion_patrol_speed": 120.0,
	}, owner)
	runtime.update(0.2, owner)
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(is_equal_approx(owner.lingpet_companion_pos.x, 42.0), "Maribo patrol should clamp at the left edge")
	_expect(float(snapshot.get("companion_patrol_pause", 0.0)) > 0.0, "Maribo patrol should pause after hitting a patrol edge")
	_expect(float(snapshot.get("companion_patrol_speed", 0.0)) >= 70.0 and float(snapshot.get("companion_patrol_speed", 0.0)) <= 135.0, "Maribo patrol should keep a randomized speed band")


func _verify_companion_ball_collision_soft_bounce() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var companion_pos: Vector2 = owner.lingpet_companion_pos
	owner.ball_active = true
	owner.ball_pos = companion_pos + Vector2(0.0, -6.0)
	owner.ball_vel = Vector2(0.0, 14.0)
	runtime.update(0.01, owner)
	_expect(owner.ball_vel.y < 0.0, "Maribo body collision should softly bounce a downward ball upward")
	_expect(int(owner.lingpet_companion_contact_count) == 1, "Maribo body collision should publish a contact count")
	_expect(owner.lingpet_companion_hit_cooldown > 0.0, "Maribo body collision should arm an internal cooldown")
	_expect(owner.lingpet_companion_last_contact_pos is Vector2 and owner.lingpet_companion_last_contact_pos != Vector2.ZERO, "Maribo body collision should publish the last contact position")
	var count_after_first_hit: int = int(owner.lingpet_companion_contact_count)
	owner.ball_pos = owner.lingpet_companion_pos + Vector2(0.0, -5.0)
	owner.ball_vel = Vector2(0.0, 14.0)
	runtime.update(0.0, owner)
	_expect(int(owner.lingpet_companion_contact_count) == count_after_first_hit, "Maribo body collision cooldown should prevent same-overlap repeat hits")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(int(snapshot.get("companion_contact_count", 0)) == count_after_first_hit, "runtime snapshot should expose Maribo contact count")


func _verify_companion_skill_card_gauge_charge() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.special_gauge = 100.0
	var runtime: Object = LingpetEggRuntime.new()
	var feedback := FakeFeedback.new()
	var orb_hud_state := FakeOrbHudState.new()
	var registry := FakeRegistry.new({
		"battle_feedback_state": feedback,
		"orb_hud_state": orb_hud_state,
	})
	runtime.update(0.0, owner, registry)
	owner.ball_active = true
	_expect(str(owner.lingpet_skill_id) == "maribo_resonance", "owned Maribo should publish its skill-card id")
	_expect(str(owner.lingpet_skill_name) == "공명 충전", "owned Maribo should publish its Korean skill-card name")
	_expect(bool(owner.lingpet_skill_ready), "owned Maribo skill should start ready")

	_hit_companion(runtime, owner, registry, owner.lingpet_companion_pos)
	_expect(is_equal_approx(owner.special_gauge, 140.0), "Maribo skill should grant 40 gauge on ready body contact")
	_expect(int(owner.lingpet_skill_trigger_count) == 1, "Maribo skill should count its first trigger")
	_expect(is_equal_approx(owner.lingpet_skill_last_gain, 40.0), "Maribo skill should publish the applied gauge gain")
	_expect(owner.lingpet_skill_cooldown > 5.0, "Maribo skill should enter a six-second cooldown")
	_expect(not bool(owner.lingpet_skill_ready), "Maribo skill should not be ready during cooldown")
	_expect(feedback.gauge_flashes == 1, "Maribo skill gauge gain should trigger gauge flash feedback")
	_expect(orb_hud_state.gauge_spins == 1, "Maribo skill gauge gain should trigger gauge orb spin")
	var skill_snapshot: Dictionary = runtime.get_snapshot()
	_expect(float(skill_snapshot.get("companion_skill_flash_timer", 0.0)) > 0.0, "Maribo skill should expose an activation flash timer for playfield/card VFX")
	_expect(skill_snapshot.get("companion_skill_origin", Vector2.ZERO) is Vector2 and skill_snapshot.get("companion_skill_origin", Vector2.ZERO) != Vector2.ZERO, "Maribo skill should remember its activation origin for VFX")
	var first_trigger_count: int = int(owner.lingpet_skill_trigger_count)

	owner.ball_pos = owner.lingpet_companion_pos + Vector2(0.0, -90.0)
	runtime.update(0.43, owner, registry)
	_hit_companion(runtime, owner, registry, owner.lingpet_companion_pos)
	_expect(int(owner.lingpet_companion_contact_count) >= 2, "Maribo body should keep colliding while the skill is on cooldown")
	_expect(int(owner.lingpet_skill_trigger_count) == first_trigger_count, "Maribo skill cooldown should block repeated gauge grants")
	_expect(is_equal_approx(owner.special_gauge, 140.0), "Maribo skill cooldown should preserve gauge after the blocked trigger")

	owner.ball_pos = owner.lingpet_companion_pos + Vector2(0.0, -90.0)
	runtime.update(6.1, owner, registry)
	_expect(bool(owner.lingpet_skill_ready), "Maribo skill should become ready after cooldown expires")
	_hit_companion(runtime, owner, registry, owner.lingpet_companion_pos)
	_expect(is_equal_approx(owner.special_gauge, 180.0), "Maribo skill should grant gauge again after cooldown")
	_expect(int(owner.lingpet_skill_trigger_count) == first_trigger_count + 1, "Maribo skill should count the second ready trigger")


func _verify_save_snapshot_roundtrip() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	_register_hit(runtime, owner, egg_pos, 1)
	_register_hit(runtime, owner, egg_pos, 2)

	var snapshot: Dictionary = runtime.get_save_snapshot()
	_expect(int(snapshot.get("version", 0)) == 1, "lingpet save snapshot should carry a schema version")
	_expect((snapshot.get("owned_pet_ids", []) as Array).has("maribo"), "lingpet save snapshot should preserve owned Maribo")

	var restored_owner := FakeOwner.new()
	restored_owner.ai_mode = "champion"
	var restored: Object = LingpetEggRuntime.new()
	var restore_result: Dictionary = restored.apply_save_snapshot(snapshot, restored_owner)
	_expect(bool(restore_result.get("restored", false)), "lingpet save snapshot should restore successfully")
	_expect(str(restored_owner.lingpet_state) == "companion", "restored owned Maribo should sync companion state")
	_expect(restored_owner.owned_lingpet_ids.has("maribo"), "restore should republish owned pet ids to the owner")
	_expect(bool(restored_owner.owned_lingpets.get("maribo", false)), "restore should republish owned collection to the owner")


func _verify_save_store_persists_and_restores_maribo() -> void:
	var companion_path := "user://lingpet_save_store_companion_smoke.cfg"
	_remove_user_file(companion_path)
	var owner := FakeOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	_register_hit(runtime, owner, egg_pos, 1)
	_register_hit(runtime, owner, egg_pos, 2)

	var save_store: Object = LingpetSaveStore.new()
	save_store.set_save_path(companion_path)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	_expect(bool(save_store.save_runtime(owner, registry)), "lingpet save store should clear companion run state on restart")
	_expect(not FileAccess.file_exists(companion_path), "lingpet save store should not keep a companion run-state save file")

	_write_lingpet_snapshot(companion_path, {
		"version": 1,
		"pet_id": "maribo",
		"state": "companion",
		"hatch_hits": 3,
		"required_hits": 3,
		"owned_pet_ids": ["maribo"],
		"active_pet_id": "maribo",
	})
	var restored_owner := FakeOwner.new()
	restored_owner.ai_mode = "champion"
	var restored_runtime: Object = LingpetEggRuntime.new()
	var restored_store: Object = LingpetSaveStore.new()
	restored_store.set_save_path(companion_path)
	var restored_registry := FakeRegistry.new({"lingpet_egg_runtime": restored_runtime})
	var restore_result: Dictionary = restored_store.restore_runtime(restored_owner, restored_registry)
	_expect(str(restore_result.get("reason", "")) == "run_state_reset_on_entry", "legacy saved companion should be treated as volatile on re-entry")
	_expect(str(restored_owner.lingpet_state) == "none", "saved Maribo should not restore as companion after game restart")
	_expect(is_equal_approx(float(restored_runtime.get_gauge_gain_per_hit(50.0)), 50.0), "reset saved Maribo should not keep the companion gauge bonus")
	_remove_user_file(companion_path)

	var egg_path := "user://lingpet_save_store_egg_smoke.cfg"
	_remove_user_file(egg_path)
	var egg_owner := FakeOwner.new()
	var egg_runtime: Object = LingpetEggRuntime.new()
	egg_runtime.update(0.0, egg_owner)
	egg_owner.ball_active = true
	_register_hit(egg_runtime, egg_owner, egg_owner.lingpet_egg_pos, 1)
	var egg_store: Object = LingpetSaveStore.new()
	egg_store.set_save_path(egg_path)
	_expect(bool(egg_store.save_runtime(egg_owner, FakeRegistry.new({"lingpet_egg_runtime": egg_runtime}))), "lingpet save store should clear volatile egg progress")
	_expect(not FileAccess.file_exists(egg_path), "lingpet save store should not keep a pre-hatch egg save file")

	_write_lingpet_snapshot(egg_path, {
		"version": 1,
		"pet_id": "maribo",
		"state": "egg",
		"hatch_hits": 1,
		"required_hits": 3,
		"egg_pos": Vector2(120.0, 704.0),
		"owned_pet_ids": [],
	})
	var deferred_owner := FakeOwner.new()
	deferred_owner.ai_mode = "champion"
	var deferred_runtime: Object = LingpetEggRuntime.new()
	var deferred_store: Object = LingpetSaveStore.new()
	deferred_store.set_save_path(egg_path)
	var deferred_result: Dictionary = deferred_store.restore_runtime(deferred_owner, FakeRegistry.new({"lingpet_egg_runtime": deferred_runtime}))
	_expect(str(deferred_result.get("reason", "")) == "run_state_reset_on_entry", "legacy saved egg progress should be treated as volatile on re-entry")
	_expect(str(deferred_result.get("state", "")) == "none", "legacy saved egg progress should not restore when the current run is ineligible")
	_expect(str(deferred_owner.lingpet_state) == "none", "ineligible restore should not show an egg")

	_write_lingpet_snapshot(egg_path, {
		"version": 1,
		"pet_id": "maribo",
		"state": "egg",
		"hatch_hits": 1,
		"required_hits": 3,
		"egg_pos": Vector2(120.0, 704.0),
		"owned_pet_ids": [],
	})
	var eligible_owner := FakeOwner.new()
	var eligible_runtime: Object = LingpetEggRuntime.new()
	var eligible_store: Object = LingpetSaveStore.new()
	eligible_store.set_save_path(egg_path)
	eligible_store.restore_runtime(eligible_owner, FakeRegistry.new({"lingpet_egg_runtime": eligible_runtime}))
	_expect(str(eligible_owner.lingpet_state) == "egg", "legacy saved egg progress should restart as a fresh Junior Mika egg")
	_expect(int(eligible_owner.lingpet_hatch_hits) == 0, "legacy saved egg progress should reset hatch-hit count on re-entry")
	_remove_user_file(egg_path)


func _verify_battle_lifecycle_restores_lingpet_save() -> void:
	var save_path := "user://lingpet_lifecycle_restore_smoke.cfg"
	_remove_user_file(save_path)
	var save_store: Object = LingpetSaveStore.new()
	save_store.set_save_path(save_path)
	_write_lingpet_snapshot(save_path, {
		"version": 1,
		"pet_id": "maribo",
		"state": "companion",
		"hatch_hits": 3,
		"required_hits": 3,
		"owned_pet_ids": ["maribo"],
		"active_pet_id": "maribo",
	})

	var owner := FakeBattleOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	var registry := FakeRegistry.new({
		"battle_scene_bootstrap": FakeBootstrap.new(),
		"lingpet_egg_runtime": runtime,
		"lingpet_save_store": save_store,
	})
	BattleSceneLifecycle.new().initialize(owner, registry)
	_expect(str(owner.lingpet_state) == "none", "battle lifecycle should reset stale saved Maribo run state")
	_expect(str(owner.active_lingpet_id) == "", "battle lifecycle reset should not publish active Maribo")
	_expect(not FileAccess.file_exists(save_path), "battle lifecycle should clear stale lingpet run-state save files")
	owner.free()
	_remove_user_file(save_path)


func _verify_maribo_companion_gauge_bonus() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner)
	_expect(bool(runtime.is_maribo_companion_active()), "owned Maribo should activate the companion effect")
	_expect(str(owner.lingpet_effect_text).find("+10%") >= 0, "owner effect text should describe Maribo's gauge bonus")
	_expect(is_equal_approx(float(runtime.get_gauge_gain_per_hit(50.0)), 55.0), "Maribo should turn 50 gauge gain into 55")

	var overlay_gain: float = CharacterInfoOverlay.new()._get_effective_gauge_gain_per_hit("smasher", null, [runtime])
	_expect(is_equal_approx(overlay_gain, 55.0), "character-info gauge-gain stat should read the Maribo bonus")

	var router := PaddleBounceEventRouter.new()
	var context := {
		"gauge_charge_per_hit": 50.0,
		"gauge_max": 500.0,
		"selected_character_type": "smasher",
	}
	var deps := {
		"lingpet_egg_runtime": runtime,
	}
	var gauge_after_hit: float = router.register_player_hit(Vector2(320.0, 690.0), 0.0, false, false, 100.0, context, deps)
	_expect(is_equal_approx(gauge_after_hit, 155.0), "player paddle hit should apply Maribo's gauge bonus")
	var gauge_after_drive: float = router.register_player_hit(Vector2(320.0, 690.0), 0.0, true, false, 100.0, context, deps)
	_expect(is_equal_approx(gauge_after_drive, 100.0), "Maribo should not bypass drive-hit gauge gain blocking")


func _verify_ineligible_conditions_do_not_spawn() -> void:
	var champion_owner := FakeOwner.new()
	champion_owner.ai_mode = "champion"
	_expect(not LingpetEggRuntime.new().update(0.0, champion_owner), "Champion League should not spawn the first Maribo egg")

	var viper_owner := FakeOwner.new()
	viper_owner.selected_character_type = "viper"
	_expect(not LingpetEggRuntime.new().update(0.0, viper_owner), "Junior non-Mika character should not spawn the first Maribo egg")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _hit_companion(runtime: Object, owner: FakeOwner, registry: Object, companion_pos: Vector2) -> void:
	owner.ball_pos = companion_pos + Vector2(0.0, -6.0)
	owner.ball_vel = Vector2(0.0, 14.0)
	runtime.update(0.0, owner, registry)


func _write_lingpet_snapshot(path: String, snapshot: Dictionary) -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", 1)
	config.set_value("lingpet", "snapshot", snapshot.duplicate(true))
	var result: int = config.save(path)
	_expect(result == OK, "test helper should write a legacy lingpet snapshot")


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
