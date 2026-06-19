extends SceneTree

const MythicItemFieldEffectRenderer := preload("res://scripts/items/mythic_item_field_effect_renderer.gd")

var _failures: Array[String] = []


class FakePerfLogger:
	extends RefCounted

	var enabled := true
	var counters: Dictionary = {}
	var labels: Array[String] = []

	func is_enabled() -> bool:
		return enabled

	func begin_sample() -> int:
		return 1

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)

	func record_counter_sample(label: String, value: float) -> void:
		counters[label] = value


class FakeVisibleState:
	extends RefCounted

	var visible := false

	func has_visible_effects() -> bool:
		return visible


func _init() -> void:
	_verify_render_budgets()
	_verify_recent_start_helper()
	_verify_perf_visibility_helpers()
	_verify_draw_paths_use_render_caps()
	_verify_idle_draw_gate_avoids_mythic_reflection()

	if _failures.is_empty():
		print("mythic_item_field_render_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_render_budgets() -> void:
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_VENOM_MIST_PARTICLES <= 48, "Venom Mist should cap decorative fog particles")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_RAINBOW_FUR_GLOVE_PARTICLES <= 28, "Rainbow Fur Glove should cap decorative aura particles")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_SHRAPNEL_ARMOR_SHARDS <= 12, "Shrapnel Armor should cap rendered shard polygons")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_SHRAPNEL_ARMOR_TRAIL_POINTS <= 3, "Shrapnel Armor should cap rendered trail points per shard")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_SHRAPNEL_ARMOR_DUST_PARTICLES <= 48, "Shrapnel Armor dust should cap decorative particles")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_KNEE_PADS_PARTICLES <= 16, "Knee Pads flash should cap decorative particles")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_SOUL_BURST_WIND_TRAILS <= 4, "Soul Burst should cap wind trail strokes")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_SOUL_BURST_SHOCKWAVES <= 3, "Soul Burst should cap shockwave rings")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_SOUL_BURST_PARTICLES <= 24, "Soul Burst should cap decorative dash particles")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_POSEIDON_WATER_TRAIL <= 12, "Poseidon water trail should keep a tight droplet budget")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_POSEIDON_PARTICLES <= 24, "Poseidon vortex should keep a tight particle budget")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_POSEIDON_EXPLOSION_PARTICLES <= 6, "Poseidon charge flash should cap rendered explosion particles")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_HORN_STRAWBERRY_PROJECTILES <= 6, "Horn Strawberry stems should cap rendered projectiles")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_HORN_STRAWBERRY_BARRIERS <= 3, "Horn Strawberry field should cap rendered barriers")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_HORN_STRAWBERRY_BOMBS <= 18, "Horn Strawberry bombs should cap rendered bomb sprites")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_HORN_STRAWBERRY_PAINT <= 16, "Horn Strawberry paint should cap rendered splatters")
	_expect(MythicItemFieldEffectRenderer.MAX_RENDERED_RAGNAROK_SPARKS <= 12, "Ragnarok sparks should cap decorative electric particles tightly")
	_expect(MythicItemFieldEffectRenderer.MAX_POSEIDON_TRAIL_ARCS <= 4, "Poseidon water trail should draw arcs only on newest large droplets")

	var renderer := MythicItemFieldEffectRenderer.new()
	var status: Dictionary = renderer.get_render_budget_status()
	_expect(int(status.get("poseidon_particle_render_limit", 0)) == MythicItemFieldEffectRenderer.MAX_RENDERED_POSEIDON_PARTICLES, "budget status should expose the Poseidon particle render cap")
	_expect(int(status.get("poseidon_explosion_particle_render_limit", 0)) == MythicItemFieldEffectRenderer.MAX_RENDERED_POSEIDON_EXPLOSION_PARTICLES, "budget status should expose the Poseidon explosion render cap")
	_expect(int(status.get("venom_mist_particle_render_limit", 0)) == MythicItemFieldEffectRenderer.MAX_RENDERED_VENOM_MIST_PARTICLES, "budget status should expose the Venom Mist particle render cap")
	_expect(int(status.get("shrapnel_armor_shard_render_limit", 0)) == MythicItemFieldEffectRenderer.MAX_RENDERED_SHRAPNEL_ARMOR_SHARDS, "budget status should expose the Shrapnel Armor shard render cap")
	_expect(int(status.get("shrapnel_armor_trail_render_limit", 0)) == MythicItemFieldEffectRenderer.MAX_RENDERED_SHRAPNEL_ARMOR_TRAIL_POINTS, "budget status should expose the Shrapnel Armor trail render cap")
	_expect(int(status.get("knee_pads_particle_render_limit", 0)) == MythicItemFieldEffectRenderer.MAX_RENDERED_KNEE_PADS_PARTICLES, "budget status should expose the Knee Pads particle render cap")
	_expect(int(status.get("soul_burst_wind_trail_render_limit", 0)) == MythicItemFieldEffectRenderer.MAX_RENDERED_SOUL_BURST_WIND_TRAILS, "budget status should expose the Soul Burst wind-trail render cap")
	_expect(int(status.get("ragnarok_spark_render_limit", 0)) == MythicItemFieldEffectRenderer.MAX_RENDERED_RAGNAROK_SPARKS, "budget status should expose the Ragnarok spark render cap")


func _verify_recent_start_helper() -> void:
	var renderer := MythicItemFieldEffectRenderer.new()
	var values: Array = []
	for index in range(100):
		values.append(index)
	_expect(renderer._recent_start(values, 32) == 68, "recent-start helper should draw only the newest capped entries")
	_expect(renderer._recent_start(values, 120) == 0, "recent-start helper should draw from zero when under budget")
	_expect(renderer._recent_start(values, 0) == values.size(), "zero render budget should draw nothing")


func _verify_perf_visibility_helpers() -> void:
	var renderer := MythicItemFieldEffectRenderer.new()
	var logger := FakePerfLogger.new()
	renderer._record_visible_counters(logger, {"poseidon": true, "idle": false})
	_expect(float(logger.counters.get("mythic.visible.poseidon", 0.0)) == 1.0, "mythic visibility counters should record visible field families")
	_expect(not logger.counters.has("mythic.visible.idle"), "mythic visibility counters should skip hidden field families")
	_expect(renderer._should_record_field_detail(logger), "mythic field detail sampling should accept enabled perf loggers with begin / finish methods")
	logger.enabled = false
	renderer._record_visible_counters(logger, {"venom_mist": true})
	_expect(not logger.counters.has("mythic.visible.venom_mist"), "mythic visibility counters should skip disabled perf loggers")
	_expect(not renderer._should_record_field_detail(logger), "mythic field detail sampling should skip disabled perf loggers")
	var visible_state := FakeVisibleState.new()
	visible_state.visible = true
	_expect(renderer._state_has_visible_effects(visible_state), "mythic visible-state helper should read active state objects")
	visible_state.visible = false
	_expect(not renderer._state_has_visible_effects(visible_state), "mythic visible-state helper should read inactive state objects")
	_expect(not renderer._state_has_visible_effects(null), "mythic visible-state helper should tolerate null state objects")


func _verify_draw_paths_use_render_caps() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_field_effect_renderer.gd")
	var aura_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_aura_field_renderer.gd")
	var armor_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_armor_field_renderer.gd")
	var hermes_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_hermes_field_renderer.gd")
	var horn_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_horn_strawberry_field_renderer.gd")
	var horn_timer_source := FileAccess.get_file_as_string("res://scripts/items/horn_strawberry_timer_gauge_renderer.gd")
	var momentum_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_momentum_field_renderer.gd")
	var poseidon_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_poseidon_field_renderer.gd")
	var ragnarok_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_ragnarok_field_renderer.gd")
	_expect(source != "", "mythic item field renderer source should be readable")
	_expect(aura_source != "", "mythic item aura field renderer source should be readable")
	_expect(armor_source != "", "mythic item armor field renderer source should be readable")
	_expect(hermes_source != "", "mythic item Hermes field renderer source should be readable")
	_expect(horn_source != "", "mythic item Horn Strawberry field renderer source should be readable")
	_expect(horn_timer_source != "", "mythic item Horn Strawberry timer renderer source should be readable")
	_expect(momentum_source != "", "mythic item momentum field renderer source should be readable")
	_expect(poseidon_source != "", "mythic item Poseidon field renderer source should be readable")
	_expect(ragnarok_source != "", "mythic item Ragnarok field renderer source should be readable")
	_expect(
		_function_body(aura_source, "func draw_venom_mist_effect").find("_recent_start(particles, particle_render_limit)") >= 0,
		"Venom Mist draw should cap decorative fog particles"
	)
	_expect(
		_function_body(aura_source, "func draw_rainbow_fur_glove_effect").find("_recent_start(particles, particle_render_limit)") >= 0,
		"Rainbow Fur Glove draw should cap decorative aura particles"
	)
	_expect(
		_function_body(aura_source, "func draw_rainbow_fur_glove_effect").find("ring_segments") >= 0,
		"Rainbow Fur Glove draw should receive a capped ring segment budget"
	)
	_expect(
		_function_body(armor_source, "func draw_adversity_armor_effect").find("_recent_start(aura_particles, particle_render_limit)") >= 0,
		"Adversity Armor draw should cap aura particles"
	)
	_expect(
		_function_body(armor_source, "func draw_shrapnel_armor_effect").find("_recent_start(dust_particles, dust_particle_render_limit)") >= 0,
		"Shrapnel Armor draw should cap decorative dust particles"
	)
	_expect(
		_function_body(armor_source, "func draw_shrapnel_armor_effect").find("_recent_start(shards, shard_render_limit)") >= 0,
		"Shrapnel Armor draw should cap shard polygons"
	)
	_expect(
		_function_body(armor_source, "func draw_shrapnel_armor_effect").find("_recent_start(trail, trail_render_limit)") >= 0,
		"Shrapnel Armor draw should cap trail points"
	)
	_expect(
		_function_body(armor_source, "func draw_shrapnel_armor_effect").find("boss_impact_arc_segments") >= 0,
		"Shrapnel Armor boss impact should use a capped arc segment budget"
	)
	_expect(
		_function_body(source, "func draw_field_effects").find("mythic.shrapnel_armor") >= 0,
		"Mythic field draw should expose a focused Shrapnel Armor perf label"
	)
	_expect(
		_function_body(source, "func draw_field_effects").find("mythic.poseidon") >= 0,
		"Mythic field draw should expose a focused Poseidon perf label"
	)
	_expect(
		_function_body(source, "func draw_field_effects").find("_hermes_field_renderer.draw_hermes_shoes_effect") >= 0,
		"Mythic field draw should delegate Hermes Shoes host sync to the focused renderer"
	)
	_expect(
		_function_body(hermes_source, "func draw_hermes_shoes_effect").find("sync_state") >= 0,
		"Hermes Shoes field renderer should sync the attached FX host"
	)
	_expect(
		_function_body(source, "func draw_field_effects").find("mythic.ragnarok_sparks") >= 0,
		"Mythic field draw should expose a focused Ragnarok spark perf label"
	)
	_expect(
		_function_body(momentum_source, "func draw_knee_pads_effects").find("_recent_start(particles, particle_render_limit)") >= 0,
		"Knee Pads draw should cap decorative flash particles"
	)
	_expect(
		_function_body(momentum_source, "func draw_soul_burst_effects").find("_recent_start(wind_trails, wind_trail_render_limit)") >= 0,
		"Soul Burst draw should cap wind trails"
	)
	_expect(
		_function_body(momentum_source, "func draw_soul_burst_effects").find("_recent_start(shockwaves, shockwave_render_limit)") >= 0,
		"Soul Burst draw should cap shockwaves"
	)
	_expect(
		_function_body(momentum_source, "func draw_soul_burst_effects").find("_recent_start(particles, particle_render_limit)") >= 0,
		"Soul Burst draw should cap decorative dash particles"
	)
	_expect(
		_function_body(horn_source, "func draw_horn_strawberry_effects").find("render_limits.get(\"projectiles\"") >= 0,
		"Horn Strawberry draw should receive a capped projectile budget"
	)
	_expect(
		_function_body(horn_source, "func draw_horn_strawberry_effects").find("draw_context") >= 0,
		"Horn Strawberry draw should receive the player draw context for transformed actor placement"
	)
	_expect(
		_function_body(source, "func draw_field_effects").find("_horn_strawberry_timer_renderer.draw_transform_timer_gauge") >= 0,
		"Mythic field draw should delegate Horn Strawberry duration gauge rendering"
	)
	_expect(
		_function_body(horn_timer_source, "func draw_transform_timer_gauge").find("timer_stack") >= 0,
		"Horn Strawberry timer gauge should claim the shared horizontal timer stack"
	)
	_expect(
		_function_body(horn_source, "func _draw_bomb_paint").find("paint_render_limit") >= 0,
		"Horn Strawberry paint draw should use the render budget"
	)
	_expect(
		_function_body(horn_source, "func _draw_bombs").find("explosion_render_limit") >= 0,
		"Horn Strawberry bomb draw should cap explosion rings"
	)
	var horn_barrier_body := _function_body(horn_source, "func _draw_barrier")
	_expect(
		horn_barrier_body.find("built_stem_lines") >= 0
			and horn_barrier_body.find("draw_multiline(built_stem_lines") >= 0,
		"Horn Strawberry built barriers should batch repeated berry stem strokes"
	)
	var tiny_strawberry_body := _function_body(horn_source, "func _draw_tiny_strawberry")
	_expect(
		tiny_strawberry_body.find("draw_colored_polygon") >= 0,
		"Horn Strawberry tiny berries should use the solid-color polygon draw path"
	)
	_expect(
		tiny_strawberry_body.find("draw_multiline(leaf_lines") >= 0,
		"Horn Strawberry tiny berries should batch leaf strokes"
	)
	_expect(
		_function_body(poseidon_source, "func draw_poseidon_water_trail").find("_recent_start(water_trail, water_trail_render_limit)") >= 0,
		"Poseidon water trail draw should cap decorative droplets"
	)
	_expect(
		_function_body(poseidon_source, "func draw_poseidon_particles").find("particle_render_limit") >= 0,
		"Poseidon particle draw should cap vortex particles by the provided budget (recent-N or uniform stride)"
	)
	_expect(
		_function_body(poseidon_source, "func draw_poseidon_water_trail").find("trail_arc_render_limit") >= 0,
		"Poseidon water trail draw should limit decorative arcs"
	)
	_expect(
		_function_body(poseidon_source, "func draw_poseidon_water_explosion").find("_recent_start(explosion_particles, explosion_particle_render_limit)") >= 0,
		"Poseidon explosion draw should cap charge particles"
	)
	_expect(
		_function_body(ragnarok_source, "func draw_ragnarok_sparks").find("_recent_start(sparks, spark_render_limit)") >= 0,
		"Ragnarok spark draw should cap decorative sparks"
	)
	var ragnarok_stun_body := _function_body(ragnarok_source, "func draw_ragnarok_electric_stun_overlay")
	_expect(ragnarok_stun_body.find("randf") < 0, "Ragnarok electric stun draw should not call random float helpers during draw")
	_expect(ragnarok_stun_body.find("randi") < 0, "Ragnarok electric stun draw should not call random integer helpers during draw")
	var runtime_constants_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime_constants.gd")
	_expect(runtime_constants_source != "", "mythic item runtime constants source should be readable")
	_expect(runtime_constants_source.find("const RAGNAROK_SPARK_COUNT := 12") >= 0, "Ragnarok runtime spark count should stay capped")
	_expect(runtime_constants_source.find("\"spark_count\": RAGNAROK_SPARK_COUNT") >= 0, "Ragnarok runtime constants should feed the spark-count budget")
	_expect(source.find("const RAGNAROK_ELECTRIC_ELLIPSE_SEGMENTS := 16") >= 0, "Ragnarok electric ellipse should use the reduced segment budget")


func _verify_idle_draw_gate_avoids_mythic_reflection() -> void:
	var drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var visibility_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_field_effect_visibility.gd")
	_expect(drawer_source != "", "playfield drawer source should be readable")
	_expect(runtime_source != "", "mythic runtime source should be readable")
	_expect(visibility_source != "", "mythic field-effect visibility source should be readable")
	_expect(
		_function_body(drawer_source, "func _draw_mythic_item_field_effects").find("has_visible_field_effects") >= 0,
		"Playfield mythic draw should skip the idle field path before method-list reflection"
	)
	_expect(
		drawer_source.find("_mythic_draw_field_effects_accepts_perf_logger") >= 0,
		"Playfield mythic draw should cache the perf-logger signature check"
	)
	_expect(
		drawer_source.find("_mythic_draw_field_effects_uses_draw_context") >= 0,
		"Playfield mythic draw should cache the draw-context signature check"
	)
	_expect(
		_function_body(drawer_source, "func _draw_mythic_item_field_effects").find("draw_context") >= 0,
		"Playfield mythic draw should forward player draw context to mythic field effects"
	)
	_expect(
		_function_body(runtime_source, "func has_visible_field_effects").find("field_effect_visibility") >= 0,
		"Mythic runtime should route field-effect visibility through the focused helper"
	)
	_expect(
		_function_body(visibility_source, "func has_visible_field_effects").find("acquisition_cinematic") >= 0,
		"Mythic field-effect visibility helper should include acquisition cinematic state"
	)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
