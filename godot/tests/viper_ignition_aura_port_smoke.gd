extends SceneTree

const HorizontalTimerGaugeStack := preload("res://scripts/hud/horizontal_timer_gauge_stack.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const TooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")

const BASE_PADDLE_WIDTH := 155.0
const BASE_PADDLE_HEIGHT := 50.0
const FIELD_HEIGHT := 750.0
const BULK_UP_LV1_SCALE := 1.06
const BULK_UP_IGNITION_SCALE := 1.18


class FakeInput:
	var snapshot := {
		"left_pressed": false,
		"right_pressed": false,
		"up_pressed": false,
		"down_pressed": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeSkillConfig:
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name == "ignition_aura"

	func get_skill_cost(skill_name: String) -> float:
		return 230.0 if skill_name == "ignition_aura" else 0.0

	func get_cooldown_seconds(skill_name: String) -> float:
		return 80.0 if skill_name == "ignition_aura" else 0.0


class FakeSkillState:
	var triggered: Array[String] = []

	func trigger_configured_cooldown(skill_name: String, _now_msec: int, _skill_config: Object) -> void:
		triggered.append(skill_name)

	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


class FakeOrbHud:
	var spins := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		spins += 1


class FakeAudio:
	var ignition := 0

	func play_viper_ignition_aura() -> void:
		ignition += 1


class FakeFeedback:
	var shakes := 0

	func set_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1


class RecordingPlayerFactory:
	var created := {}

	func create(parent: Node, name: String, path: String, volume_db: float) -> AudioStreamPlayer:
		var player := AudioStreamPlayer.new()
		player.name = name
		player.volume_db = volume_db
		player.stream = AudioStreamWAV.new()
		created[name] = {
			"path": path,
			"volume_db": volume_db,
			"player": player,
		}
		if parent != null:
			parent.add_child(player)
		return player


class FakeOwner:
	var selected_character_type := "viper"
	var player_pos := Vector2(302.5, FIELD_HEIGHT - BASE_PADDLE_HEIGHT)
	var player_paddle_width := BASE_PADDLE_WIDTH
	var player_paddle_height := BASE_PADDLE_HEIGHT
	var player_paddle_scale := 1.0
	var runtime_accessory_slot_bonus := 0
	var runtime_paddle_scale := 1.0
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var runtime_perk_effective_levels: Dictionary = {}
	var viper_ignition_aura_active := false


class RealViperRegistry:
	var perk_state: Object
	var skill_config: Object

	func _init(new_perk_state: Object, new_skill_config: Object) -> void:
		perk_state = new_perk_state
		skill_config = new_skill_config

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return perk_state
			"viper_skill_config":
				return skill_config
		return null


func _init() -> void:
	_test_catalog_unlock_wiring()
	_test_audio_asset_parity()
	_test_activation_bonus_gold_and_expiry()
	_test_owner_synced_ignition_level_bonus()
	_test_grounded_hold_blockers_and_reset()
	_test_tooltip_and_timer_stack_contract()
	_test_runtime_asset_prewarm_contract()
	_test_visibility_query_bridge_cleanup()
	print("viper_ignition_aura_port_smoke: ok")
	quit(0)


func _test_catalog_unlock_wiring() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var perk_state: Object = RuntimePerkState.new()
	var skill_config: Object = ViperSkillConfig.new()
	var owner := FakeOwner.new()
	var registry := RealViperRegistry.new(perk_state, skill_config)
	var unlock_data: Dictionary = catalog.get_perk_data("unlock_ignition_aura")
	_expect(not unlock_data.is_empty(), "unlock_ignition_aura should exist in the Viper perk catalog")
	_expect(str(unlock_data.get("unlocks_skill", "")) == "ignition_aura", "unlock_ignition_aura should equip the ignition_aura orb")
	_expect(not skill_config.is_skill_equipped("ignition_aura"), "Ignition Aura should not be equipped before the unlock")
	var icon_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/skills/viper_ignition_aura_skill_orb.png")
	var effect_sheet: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/effects/viper_ignition_aura_effect_sheet.png")
	_expect(icon_texture != null, "Ignition Aura orb PNG should load from Godot skill assets")
	_expect(effect_sheet != null, "Ignition Aura effect sheet should load from Godot effect assets")
	unlock_data["id"] = "unlock_ignition_aura"
	_expect(perk_state.apply_choice(unlock_data, owner, registry), "selecting unlock_ignition_aura should apply cleanly")
	_expect(perk_state.get_runtime_skill_level("unlock_ignition_aura") == 1, "unlock perk level should be recorded as a boolean gate")
	_expect(skill_config.is_skill_equipped("ignition_aura"), "Ignition Aura unlock should equip the runtime skill")


func _test_audio_asset_parity() -> void:
	_expect(GameAudio.VIPER_IGNITION_AURA_SOUND_PATH == "res://assets/sounds/beforedivestrike.wav", "Ignition Aura should use the Python reference beforedivestrike.wav")
	_expect(GameAudio.VIPER_IGNITION_AURA_FALLBACK_SOUND_PATH == "res://assets/sounds/backstep.wav", "Ignition Aura should keep Python's backstep fallback cue")
	_expect(FileAccess.file_exists(GameAudio.VIPER_IGNITION_AURA_SOUND_PATH), "Ignition Aura primary wav should exist in the Godot asset tree")
	_expect(FileAccess.file_exists(GameAudio.VIPER_IGNITION_AURA_FALLBACK_SOUND_PATH), "Ignition Aura fallback wav should exist in the Godot asset tree")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.VIPER_IGNITION_AURA_SOUND_PATH) != null, "Ignition Aura primary wav should load as a Godot audio stream")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.VIPER_IGNITION_AURA_FALLBACK_SOUND_PATH) != null, "Ignition Aura fallback wav should load as a Godot audio stream")
	_expect(abs(GameAudio.VIPER_IGNITION_AURA_GAIN_DB + 3.0980) <= 0.001, "Ignition Aura should match Python's 0.7 relative volume")

	var host := Node.new()
	var factory := RecordingPlayerFactory.new()
	var audio: Object = GameAudio.new()
	audio.player_factory = factory
	audio.owner_node = host
	audio._setup_smasher_skill_sfx()

	var primary: Dictionary = _as_dict(factory.created.get("ViperIgnitionAuraSfx", {}))
	var fallback: Dictionary = _as_dict(factory.created.get("ViperIgnitionAuraFallbackSfx", {}))
	_expect(str(primary.get("path", "")) == GameAudio.VIPER_IGNITION_AURA_SOUND_PATH, "Ignition Aura should create a dedicated primary audio player")
	_expect(str(fallback.get("path", "")) == GameAudio.VIPER_IGNITION_AURA_FALLBACK_SOUND_PATH, "Ignition Aura should create a dedicated fallback audio player")
	_expect(abs(float(primary.get("volume_db", 0.0)) - GameAudio.VIPER_IGNITION_AURA_GAIN_DB) <= 0.001, "Ignition Aura primary player should use the 0.7-volume gain")
	_expect(abs(float(fallback.get("volume_db", 0.0)) - GameAudio.VIPER_IGNITION_AURA_GAIN_DB) <= 0.001, "Ignition Aura fallback player should use the 0.7-volume gain")

	var primary_player: AudioStreamPlayer = primary.get("player", null)
	var fallback_player: AudioStreamPlayer = fallback.get("player", null)
	_expect(primary_player != null and fallback_player != null, "Ignition Aura audio players should be available for playback")
	var source := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd").replace("\r\n", "\n")
	var marker := "func play_viper_ignition_aura() -> void:"
	var start := source.find(marker)
	var end := source.find("\n\nfunc ", start + marker.length())
	_expect(start >= 0, "Ignition Aura playback function should exist in GameAudio")
	if end < 0:
		end = source.length()
	var body := source.substr(start, end - start) if start >= 0 else ""
	_expect(body.find("viper_ignition_aura_sfx") >= 0, "Ignition Aura should play the original dedicated cue")
	_expect(body.find("viper_ignition_aura_fallback_sfx") >= 0, "Ignition Aura should keep the Python fallback cue")
	_expect(body.find("firebomb_sfx") < 0, "Ignition Aura should no longer use firebomb.wav")
	_expect(body.find("randf_range") < 0, "Ignition Aura should play without pitch randomization like the Python reference")
	host.free()


func _test_visibility_query_bridge_cleanup() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_runtime.gd")
	for bridge_name in [
		"_get_ignition_aura_ratio",
		"_get_dual_glitch_remaining_frames",
		"_get_venom_edge_strike_frame",
		"_get_nerve_strike_freeze_frames",
	]:
		_expect(runtime_source.find(bridge_name) < 0, "Viper runtime should not keep private visibility bridge %s" % bridge_name)
	for owner_path in [
		"res://scripts/characters/viper_skill_context_builder.gd",
		"res://scripts/characters/viper_skill_snapshot_builder.gd",
		"res://scripts/characters/viper_skill_timer_gauge_renderer.gd",
	]:
		var owner_source := FileAccess.get_file_as_string(owner_path)
		_expect(owner_source.find("ViperSkillVisibilityQuery") >= 0, "%s should read visibility values from the owner query helper" % owner_path)


func _test_activation_bonus_gold_and_expiry() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state: Object = RuntimePerkState.new()
	perk_state.runtime_skill_levels["four_poisons"] = 3
	perk_state.runtime_skill_levels["unlock_ignition_aura"] = 1
	var owner := FakeOwner.new()
	var orb := FakeOrbHud.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var deps := _deps(input, skill_config, skill_state, perk_state, orb, audio, feedback, owner)
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	input.snapshot["up_pressed"] = true

	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	_expect(not bool(result.get("activated", false)), "Ignition Aura should require a 0.5s W/up hold before activation")
	runtime.ignition_hold_start_msec = Time.get_ticks_msec() - 501
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "Ignition Aura should activate after the hold requirement")
	_expect(str(result.get("skill_name", "")) == "ignition_aura", "Ignition activation should report its skill id")
	_expect(abs(float(result.get("special_gauge", 0.0)) - 270.0) < 0.01, "Ignition Aura should spend 230 gauge")
	_expect(skill_state.triggered.back() == "ignition_aura", "Ignition Aura should trigger its own cooldown")
	_expect(orb.spins == 1 and audio.ignition == 1 and feedback.shakes > 0, "Ignition startup should spin the orb, play audio, and shake feedback")
	_expect(bool(perk_state.is_viper_ignition_aura_active()), "Ignition activation should enable the runtime perk bonus")
	_expect(perk_state.get_runtime_skill_level("four_poisons") == 5, "active Ignition Aura should add +2 to invested scaling perks")
	_expect(perk_state.get_runtime_skill_level("unlock_ignition_aura") == 1, "Ignition Aura should not inflate boolean unlock gates")
	var effective_levels: Dictionary = _as_dict(perk_state.get_snapshot().get("effective_runtime_skill_levels", {}))
	_expect(int(effective_levels.get("four_poisons", 0)) == 5, "runtime snapshot should expose Ignition-boosted effective perk levels")
	var owner_effective_levels: Dictionary = _as_dict(owner.runtime_perk_effective_levels)
	_expect(int(owner_effective_levels.get("four_poisons", 0)) == 5, "Ignition activation should immediately sync owner effective perk levels")
	var acquired: Array = CharacterInfoOverlay.new()._build_acquired_perks(
		perk_state.runtime_skill_levels,
		RuntimePerkCatalog.new(),
		perk_state
	)
	var four_poisons_display: Dictionary = _find_perk(acquired, "four_poisons")
	_expect(int(four_poisons_display.get("base_level", 0)) == 3, "TAB perk grid should retain the invested base level separately")
	_expect(int(four_poisons_display.get("level", 0)) == 5, "TAB perk grid should display Ignition's effective perk level")
	_expect(perk_state.award_gold(20) == 70, "active Ignition Aura should add +50 to skill gold before storage")
	_expect(perk_state.apply_choice({"id": "convert_to_gold", "gold_amount": 500}, FakeOwner.new(), RealViperRegistry.new(perk_state, ViperSkillConfig.new())), "gold conversion should apply while Ignition is active")
	_expect(perk_state.gold_from_perks == 620, "active Ignition Aura should add +50 to perk gold conversion too")
	_expect(bool(runtime.get_snapshot().get("ignition_active", false)), "Ignition runtime snapshot should expose the active state")

	var context := config.duplicate(true)
	context["player_pos"] = player_pos
	context["player_paddle_size"] = Vector2(155.0, 50.0)
	runtime.update_effects(1490.0, Time.get_ticks_msec(), context, deps)
	_expect(bool(runtime.get_snapshot().get("ignition_active", false)), "Ignition Aura should remain active before its 25s duration is exhausted")
	runtime.update_effects(20.0, Time.get_ticks_msec(), context, deps)
	_expect(not bool(runtime.get_snapshot().get("ignition_active", true)), "Ignition Aura should expire after 25s")
	_expect(not bool(perk_state.is_viper_ignition_aura_active()), "Ignition expiry should clear the runtime perk bonus")


func _test_owner_synced_ignition_level_bonus() -> void:
	var perk_state: Object = RuntimePerkState.new()
	var skill_config: Object = ViperSkillConfig.new()
	var owner := FakeOwner.new()
	var registry := RealViperRegistry.new(perk_state, skill_config)
	perk_state.runtime_skill_levels["common_bulk_up"] = 1
	perk_state.runtime_skill_levels["common_expansion"] = 1

	perk_state.set_viper_ignition_aura_active(true)
	perk_state.refresh_viper_ignition_aura_dynamic_effects(registry)
	perk_state.update_resume_safety(owner, registry, 1.0 / 60.0)
	_expect_close(float(owner.runtime_paddle_scale), BULK_UP_IGNITION_SCALE, "active Ignition should resync cached Bulk Up paddle scale to effective Lv.3")
	_expect_close(float(owner.player_paddle_width), BASE_PADDLE_WIDTH * BULK_UP_IGNITION_SCALE, "active Ignition should resize the live paddle width")
	_expect_close(float(owner.player_paddle_height), BASE_PADDLE_HEIGHT * BULK_UP_IGNITION_SCALE, "active Ignition should resize the live paddle height")
	_expect_close(owner.player_pos.y + owner.player_paddle_height, FIELD_HEIGHT, "active Ignition paddle resize should keep the grounded bottom aligned")
	_expect(owner.runtime_accessory_slot_bonus == 3, "active Ignition should resync common_expansion to effective Lv.3")

	perk_state.set_viper_ignition_aura_active(false)
	perk_state.refresh_viper_ignition_aura_dynamic_effects(registry)
	perk_state.update_resume_safety(owner, registry, 1.0 / 60.0)
	_expect_close(float(owner.runtime_paddle_scale), BULK_UP_LV1_SCALE, "Ignition expiry should resync cached Bulk Up paddle scale back to invested Lv.1")
	_expect_close(float(owner.player_paddle_width), BASE_PADDLE_WIDTH * BULK_UP_LV1_SCALE, "Ignition expiry should restore live paddle width to invested Lv.1")
	_expect_close(float(owner.player_paddle_height), BASE_PADDLE_HEIGHT * BULK_UP_LV1_SCALE, "Ignition expiry should restore live paddle height to invested Lv.1")
	_expect_close(owner.player_pos.y + owner.player_paddle_height, FIELD_HEIGHT, "Ignition expiry paddle resize should keep the grounded bottom aligned")
	_expect(owner.runtime_accessory_slot_bonus == 1, "Ignition expiry should resync common_expansion back to invested Lv.1")


func _test_grounded_hold_blockers_and_reset() -> void:
	var bundle: Dictionary = _runtime_bundle()
	var runtime: Object = bundle["runtime"]
	var input: Object = bundle["input"]
	var deps: Dictionary = bundle["deps"]
	var config := _base_config()
	input.snapshot["up_pressed"] = true
	runtime.ignition_hold_start_msec = Time.get_ticks_msec() - 501
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, Vector2(302.5, 620.0), 500.0, config, deps)
	_expect(not bool(result.get("activated", false)), "Ignition Aura should not activate while Viper is airborne")

	runtime.dual_glitch_state = "active"
	runtime.ignition_hold_start_msec = Time.get_ticks_msec() - 501
	result = runtime.try_activate_before_movement(1.0 / 60.0, Vector2(302.5, 680.0), 500.0, config, deps)
	_expect(not bool(result.get("activated", false)), "Ignition Aura should not activate during another Viper skill")

	runtime.dual_glitch_state = "idle"
	runtime.ignition_hold_start_msec = Time.get_ticks_msec() - 501
	result = runtime.try_activate_before_movement(1.0 / 60.0, Vector2(302.5, 680.0), 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "Ignition Aura should activate again once blockers are gone")
	_expect(bool(bundle["perk_state"].is_viper_ignition_aura_active()), "Ignition bonus should be active before reset")
	var remaining_before_reset: float = float(runtime.get_snapshot().get("ignition_remaining_frames", 0.0))
	runtime.reset_round(deps)
	_expect(bool(runtime.get_snapshot().get("ignition_active", false)), "round reset should preserve active Ignition Aura for the next round")
	_expect(bool(bundle["perk_state"].is_viper_ignition_aura_active()), "round reset should preserve Ignition's temporary perk bonus")
	_expect(abs(float(runtime.get_snapshot().get("ignition_remaining_frames", 0.0)) - remaining_before_reset) < 0.01, "round reset should preserve Ignition's remaining duration")

	var waiting_context := _base_config()
	waiting_context["ball_active"] = false
	waiting_context["waiting_for_serve"] = true
	waiting_context["player_pos"] = Vector2(302.5, 680.0)
	waiting_context["player_paddle_size"] = Vector2(155.0, 50.0)
	runtime.update_effects(120.0, Time.get_ticks_msec(), waiting_context, deps)
	_expect(bool(runtime.get_snapshot().get("ignition_active", false)), "serve-wait frames should pause, not cancel, cross-round Ignition Aura")
	_expect(abs(float(runtime.get_snapshot().get("ignition_remaining_frames", 0.0)) - remaining_before_reset) < 0.01, "serve-wait frames should not consume Ignition's remaining duration")

	runtime.update_effects(10.0, Time.get_ticks_msec(), config, deps)
	_expect(float(runtime.get_snapshot().get("ignition_remaining_frames", 0.0)) < remaining_before_reset, "next live round should resume Ignition's countdown")
	var hard_reset_deps := deps.duplicate()
	hard_reset_deps["preserve_ignition_aura"] = false
	runtime.reset_round(hard_reset_deps)
	_expect(not bool(runtime.get_snapshot().get("ignition_active", true)), "explicit hard reset should still clear Ignition Aura")
	_expect(not bool(bundle["perk_state"].is_viper_ignition_aura_active()), "explicit hard reset should clear Ignition's temporary perk bonus")


func _test_tooltip_and_timer_stack_contract() -> void:
	var perk_state: Object = RuntimePerkState.new()
	perk_state.runtime_skill_levels["four_poisons"] = 1
	perk_state.set_viper_ignition_aura_active(true)
	var tooltip: Object = TooltipRenderer.new()
	var description: String = tooltip._build_description_with_runtime_bonus(
		{"name": "ignition_aura", "description": "base"},
		{"runtime_perk_state": perk_state}
	)
	_expect(description.find("Lv.+2") >= 0 and description.find("+50") >= 0, "Ignition tooltip should expose its live +level and gold bonuses")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	var spanish_description: String = tooltip._build_description_with_runtime_bonus(
		{"name": "ignition_aura", "description": "base"},
		{"runtime_perk_state": perk_state}
	)
	_expect(spanish_description.find("Ignici") >= 0 and spanish_description.find("oro +50") >= 0, "Ignition tooltip bonus line should localize to Spanish")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL)
	var portuguese_description: String = tooltip._build_description_with_runtime_bonus(
		{"name": "ignition_aura", "description": "base"},
		{"runtime_perk_state": perk_state}
	)
	_expect(portuguese_description.find("Igni") >= 0 and portuguese_description.find("ouro +50") >= 0, "Ignition tooltip bonus line should localize to Brazilian Portuguese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_RUSSIAN)
	var russian_description: String = tooltip._build_description_with_runtime_bonus(
		{"name": "ignition_aura", "description": "base"},
		{"runtime_perk_state": perk_state}
	)
	_expect(russian_description.find("Воспламенение") >= 0 and russian_description.find("золото +50") >= 0, "Ignition tooltip bonus line should localize to Russian")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)

	var stack: Object = HorizontalTimerGaugeStack.new()
	_expect(int(stack.claim("ignition_aura", true)) == 0, "Ignition timer should be able to own the bottom timer-stack row when alone")
	stack.begin_frame()
	_expect(int(stack.claim("dual_glitch", true)) == 1, "a second timer should stack above an already-active Ignition timer")
	_expect(int(stack.claim("ignition_aura", true)) == 0, "Ignition timer should keep its stack index within the same frame")
	stack.end_frame()


func _test_runtime_asset_prewarm_contract() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	runtime.ignition_aura_effect_texture = null
	runtime.ignition_aura_effect_load_attempted = false
	_expect(runtime.has_method("prewarm_assets_step"), "Viper runtime should expose staged runtime asset prewarm")
	var asset_prewarm_done := false
	for _i in range(64):
		asset_prewarm_done = bool(runtime.prewarm_assets_step())
		if asset_prewarm_done:
			break
	_expect(asset_prewarm_done, "Viper runtime staged asset prewarm should complete within the expected step budget")
	_expect(bool(runtime.ignition_aura_effect_load_attempted), "Ignition Aura sheet load gate should be satisfied by prewarm")
	_expect(runtime.ignition_aura_effect_texture != null, "Ignition Aura effect sheet should be loaded before first draw")
	_expect(runtime.has_method("prewarm_runtime_nodes_step"), "Viper runtime should expose staged FX host node prewarm")
	var prewarm_parent := Node2D.new()
	_expect(bool(runtime.prewarm_runtime_nodes_step(prewarm_parent)), "Viper runtime FX host prewarm should complete in one staged chunk")
	_expect(prewarm_parent.get_node_or_null("ViperChaosSpearFxHost") != null, "Viper runtime prewarm should attach the Chaos Spear FX host")
	_expect(prewarm_parent.get_node_or_null("ViperEmpStrikeFxHost") != null, "Viper runtime prewarm should attach the EMP Strike FX host")
	prewarm_parent.free()

	var source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_particle_drawer.gd")
	_expect(
		source.find("func prewarm_ignition_aura_assets") >= 0,
		"Ignition Aura should keep sheet loading out of the draw-only path"
	)


func _runtime_bundle() -> Dictionary:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state: Object = RuntimePerkState.new()
	perk_state.runtime_skill_levels["four_poisons"] = 1
	var deps := _deps(input, skill_config, skill_state, perk_state, FakeOrbHud.new(), FakeAudio.new(), FakeFeedback.new())
	return {
		"runtime": runtime,
		"input": input,
		"perk_state": perk_state,
		"deps": deps,
	}


func _deps(
	input: Object,
	skill_config: Object,
	skill_state: Object,
	perk_state: Object,
	orb: Object,
	audio: Object,
	feedback: Object,
	owner: Object = null
) -> Dictionary:
	return {
		"owner": owner,
		"input_reader": input,
		"viper_skill_config": skill_config,
		"viper_skill_state": skill_state,
		"runtime_perk_state": perk_state,
		"orb_hud_state": orb,
		"audio": audio,
		"feedback": feedback,
	}


func _find_perk(perks: Array, perk_id: String) -> Dictionary:
	for value in perks:
		if value is Dictionary:
			var perk: Dictionary = value
			if str(perk.get("id", "")) == perk_id:
				return perk
	return {}


func _as_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _base_config() -> Dictionary:
	return {
		"selected_character_type": "viper",
		"ball_active": true,
		"waiting_for_serve": false,
		"player_floor_y": 680.0,
		"height": 730.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"ball_pos": Vector2(380.0, 400.0),
		"ball_vel": Vector2(0.0, -8.0),
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) <= 0.03:
		return
	push_error("%s (actual %.3f, expected %.3f)" % [message, actual, expected])
	quit(1)
