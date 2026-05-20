extends SceneTree

const Stage4PonkMeditationFxHost := preload("res://scripts/stages/stage4/stage4_ponk_meditation_fx_host.gd")
const Stage4PonkSkillState := preload("res://scripts/stages/stage4/stage4_ponk_skill_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Stage4PonkMeditationFxHost.prewarm_assets()
	var skill_state := Stage4PonkSkillState.new()
	skill_state.prewarm_assets()
	var skill_asset_status: Dictionary = skill_state.get_asset_status()
	_expect(bool(skill_asset_status.get("meditation_fx_mandala_png_slot", false)), "Stage 4 Ponk skill state should expose Claude's mandala PNG slot")
	_expect(bool(skill_asset_status.get("meditation_fx_lotus_petal_png_slot", false)), "Stage 4 Ponk skill state should expose Claude's lotus-petal PNG slot")
	_expect(bool(skill_asset_status.get("meditation_fx_sutra_shard_png_slot", false)), "Stage 4 Ponk skill state should expose Claude's sutra-shard PNG slot")
	_expect(bool(skill_asset_status.get("meditation_fx_lock_burst_png_slot", false)), "Stage 4 Ponk skill state should expose Claude's lock-burst PNG slot")
	_expect(bool(skill_asset_status.get("meditation_fx_release_burst_png_slot", false)), "Stage 4 Ponk skill state should expose Claude's release-burst PNG slot")
	_expect(bool(skill_asset_status.get("meditation_fx_release_trail_png_slot", false)), "Stage 4 Ponk skill state should expose Claude's release-trail PNG slot")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 760)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var host := Stage4PonkMeditationFxHost.new()
	viewport.add_child(host)
	host.sync_state(_build_active_state(), true)

	for _idx in range(6):
		await process_frame

	var active_status: Dictionary = host.get_debug_status()
	_expect(bool(active_status.get("active", false)), "Stage 4 meditation FX should activate in a viewport host")
	_expect(bool(active_status.get("mandala_png_slot", false)), "Stage 4 meditation FX should use Claude's mandala PNG slot")
	_expect(bool(active_status.get("lotus_petal_png_slot", false)), "Stage 4 meditation FX should use Claude's lotus-petal PNG slot")
	_expect(bool(active_status.get("sutra_shard_png_slot", false)), "Stage 4 meditation FX should use Claude's sutra-shard PNG slot")
	_expect(bool(active_status.get("lock_burst_png_slot", false)), "Stage 4 meditation FX should use Claude's lock-burst PNG slot")
	_expect(bool(active_status.get("release_burst_png_slot", false)), "Stage 4 meditation FX should use Claude's release-burst PNG slot")
	_expect(bool(active_status.get("release_trail_png_slot", false)), "Stage 4 meditation FX should use Claude's release-trail PNG slot")
	_expect(bool(active_status.get("mandala_writhe_shader", false)), "Stage 4 meditation mandala should use the shared writhe ember shader")
	_expect(int(active_status.get("trail_point_count", 0)) >= 20, "Stage 4 meditation FX should preserve the figure-eight trail points")
	_expect(host.position == Vector2(96.0, 34.0), "Stage 4 meditation FX should apply the viewport game_offset")
	_expect(host.scale.distance_to(Vector2(0.78, 0.78)) <= 0.001, "Stage 4 meditation FX should apply the viewport render_scale")

	host.sync_state(_build_release_state(), true)
	for _idx in range(4):
		await process_frame

	var release_status: Dictionary = host.get_debug_status()
	_expect(int(release_status.get("shader_layers", 0)) >= 3, "Stage 4 meditation release should keep shader layers live")
	_expect(int(release_status.get("gpu_particle_layers", 0)) >= 3, "Stage 4 meditation release should keep particle layers live")
	_expect(bool(release_status.get("texture_pieces_ready", false)), "Stage 4 meditation release should keep texture pieces ready")
	_expect(bool(release_status.get("release_burst_visible", false)), "Stage 4 meditation release should render the release burst texture")
	_expect(bool(release_status.get("release_trail_visible", false)), "Stage 4 meditation release should render the release trail texture")

	host.tear_down(true)
	viewport.queue_free()

	if _failures.is_empty():
		print("stage4_ponk_meditation_fx_host_visual_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_active_state() -> Dictionary:
	var boss_center := Vector2(380.0, 88.0)
	var trails: Array = []
	for idx in range(22):
		var angle: float = float(idx) / 21.0 * TAU
		var denom: float = 1.0 + pow(sin(angle), 2.0)
		trails.append({
			"pos": boss_center + Vector2(
				120.0 * cos(angle) / denom,
				120.0 * sin(angle) * cos(angle) / denom
			),
			"life": 34.0,
			"radius": 11.0,
		})
	return {
		"active": true,
		"release_active": false,
		"progress": 0.46,
		"boss_center": boss_center,
		"ball_pos": trails[trails.size() - 1]["pos"],
		"trails": trails,
		"shake_offset": Vector2.ZERO,
		"game_offset": Vector2(96.0, 34.0),
		"render_scale": 0.78,
		"release_id": 0,
	}


func _build_release_state() -> Dictionary:
	var active_state: Dictionary = _build_active_state()
	active_state["active"] = false
	active_state["release_active"] = true
	active_state["release_progress"] = 0.32
	active_state["release_origin"] = Vector2(415.0, 116.0)
	active_state["release_pos"] = Vector2(455.0, 226.0)
	active_state["release_velocity"] = Vector2(2.4, 8.8)
	active_state["release_id"] = 1
	return active_state
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
