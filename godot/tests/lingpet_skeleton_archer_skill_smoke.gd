extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkeletonArcherSkill := preload("res://scripts/lingpet/lingpet_skeleton_archer_skill.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")

const SKILL_ID := "nekuring_skeleton_archer"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_active := true
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2(0.0, -8.0)
	var ball_size := 28.6
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class FakeAudio:
	extends RefCounted

	# Dedicated original-cue counters (the path that must win).
	var archer_summon_count := 0
	var archer_death_count := 0
	var archer_fire_count := 0
	var archer_hit_count := 0
	# Legacy borrowed-cue counters. These methods stay implemented so the test proves the
	# dedicated original cues are PREFERRED over them (the borrowed counters must stay 0).
	var summon_count := 0
	var fire_count := 0
	var hit_count := 0
	var break_count := 0
	var active_item_count := 0

	func play_lingpet_skeleton_archer_summon() -> void:
		archer_summon_count += 1

	func play_lingpet_skeleton_archer_death() -> void:
		archer_death_count += 1

	func play_lingpet_skeleton_archer_arrow_fire() -> void:
		archer_fire_count += 1

	func play_lingpet_skeleton_archer_arrow_hit() -> void:
		archer_hit_count += 1

	func play_lingpet_ghost_summon() -> void:
		summon_count += 1

	func play_shrapnel_armor_fire() -> void:
		fire_count += 1

	func play_shrapnel_armor_hit() -> void:
		hit_count += 1

	func play_boomerang_break() -> void:
		break_count += 1

	func play_active_item() -> void:
		active_item_count += 1


class FakeStatusEffectState:
	extends RefCounted

	var applied: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		applied.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		})
		return {}


class FakeBossAiState:
	extends RefCounted

	var knockback_calls := 0
	var last_velocity := 0.0
	var last_frames := 0.0
	var last_decay := 0.0
	var last_replace := false

	func start_paddle_hit_knockback(velocity: float, frames: float = 0.0, decay: float = 1.0, replace_current: bool = false) -> bool:
		knockback_calls += 1
		last_velocity = velocity
		last_frames = frames
		last_decay = decay
		last_replace = replace_current
		return true


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null


func _init() -> void:
	seed(20260614)
	_verify_catalog_dispatcher_and_host_wiring()
	_verify_clean_lingpia_visual_layers()
	_verify_level_scaling_tables_and_runtime_snapshot()
	_verify_normal_arrow_hit_applies_original_stun_shape()
	_verify_golden_archer_multishot()
	_verify_level5_bonus_summon()
	_verify_returned_ball_breaks_archer()
	_verify_archer_count_cap_bounds_accumulation()
	_verify_original_event_audio_is_ported()

	if _failures.is_empty():
		print("lingpet_skeleton_archer_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_dispatcher_and_host_wiring() -> void:
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_skeleton_archer_skill.gd"), "Skeleton Archer skill module should exist")
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_skeleton_archer_payload_factory.gd"), "Skeleton Archer payload factory should exist")
	_expect(LingpetSkillDispatcher.is_supported_kind("skeleton_archer"), "dispatcher should support the skeleton_archer runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime(SKILL_ID), "Nekuring Skeleton Archer should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_skeleton_archer(SKILL_ID), "dispatcher should expose a Skeleton Archer helper")
	_expect(not LingpetSkillDispatcher.skills_share_exclusive_resource(SKILL_ID, "rabi_ghost_summon"), "Skeleton Archer should not claim ball ownership while Ghost Summon does")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry(SKILL_ID)
	_expect(not skill.is_empty(), "Nekuring catalog should expose Skeleton Archer metadata")
	_expect(str(skill.get("runtime_kind", "")) == "skeleton_archer", "Skeleton Archer metadata should use the skeleton_archer runtime kind")
	_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), 11.7), "Skeleton Archer skill cooldown should be the +30% nerf value (9.0 -> 11.7)")
	_expect(is_equal_approx(float(skill.get("windup_seconds", 0.0)), 0.45), "Skeleton Archer should use a short lingpet cast windup")
	var nekuring_skill_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("nekuring"))
	_expect(not nekuring_skill_ids.has("nekuring_ghost_summon"), "Nekuring active pool should remove Skeleton Summon")
	_expect(nekuring_skill_ids.has(SKILL_ID), "Nekuring active pool should add Skeleton Archer")

	var spec := GameplayModuleCatalog.new().get_spec("lingpet_skeleton_archer_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_skeleton_archer_payload_factory.gd", "module catalog should list the Skeleton Archer payload factory")

	var host := LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({"game_audio": audio})
	_expect(host.launch(SKILL_ID, Vector2(380.0, 680.0), owner, {"registry": registry, "spawn_x": 380.0, "spawn_y": 650.0, "arrow_cooldown": 0.0}), "runtime host should launch Nekuring Skeleton Archer")
	host.trigger_launch_feedback(SKILL_ID, registry)
	_expect(audio.archer_summon_count == 1, "Skeleton Archer launch should play the original bonemake2 summon cue")
	_expect(audio.summon_count == 0 and audio.active_item_count == 0, "Skeleton Archer summon should prefer the dedicated cue over the borrowed ghost-summon cue")
	_expect(not host.is_launch_blocked(SKILL_ID), "Skeleton Archer should allow later casts while existing archers remain alive")
	host.update(1.21, owner, registry, SKILL_ID)
	_expect(host.get_skeleton_archer_archer_count_for_tests() == 1, "runtime host should update the live archer module")
	var host_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(host_source.find("draw.lingpet.skeleton_archer") >= 0, "Skeleton Archer draw should expose a focused BattlePerf sample label")
	_expect(host_source.find("lingpet.skeleton_archer.archers") >= 0, "Skeleton Archer draw should expose archer-count perf counters")
	_expect(host_source.find("lingpet.skeleton_archer.arrows") >= 0, "Skeleton Archer draw should expose arrow-count perf counters")
	_expect(host_source.find("record_counter_sample") >= 0, "Skeleton Archer draw counters should use the BattlePerf counter path")
	_expect(runtime_source.find("_skill_runtime_host.draw(canvas, shake_offset, _get_draw_perf_logger(_draw_context))") >= 0, "lingpet draw should pass the playfield BattlePerf logger into the skill runtime host")
	host.reset(owner, registry)
	_expect(not host.has_visible_effects(), "runtime host reset should clear live Skeleton Archer visuals at round boundaries")


func _verify_clean_lingpia_visual_layers() -> void:
	# The Skeleton Archer was redesigned from the cluttered "Ultra Premium" skeleton into a clean
	# Lumion Spirit-Revenant: ONE convex cloak-bell silhouette + a skull-lantern + 링파츠 hardware
	# (twin shoulder pods, forehead + chest-core gems), hovering (no legs). This guards the clean
	# design AND that the old anatomical clutter the user rejected stays removed.
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skeleton_archer_skill.gd")
	# --- new clean layers present ---
	_expect(source.find("func _draw_archer_cloak_bell") >= 0, "redesign should draw the single convex cloak-bell silhouette")
	_expect(source.find("func _draw_archer_hem_underglow") >= 0, "redesign should draw the hovering-spirit hem underglow (replaces legs/feet)")
	_expect(source.find("func _draw_archer_shoulder_pods") >= 0, "redesign should draw the twin 링파츠 shoulder pods")
	_expect(source.find("func _draw_archer_skull_lantern") >= 0, "redesign should draw the clean skull-lantern (dome + jaw + forehead gem + eyes)")
	_expect(source.find("func _draw_archer_chest_core") >= 0, "redesign should draw the 링파츠 chest-core gem")
	_expect(source.find("func _build_recurve_bow_points") >= 0, "redesign should keep the recurve bow construction")
	_expect(source.find("func _draw_aiming_arrow") >= 0, "redesign should keep the charged aiming arrow")
	_expect(source.find("draw_polygon") >= 0, "cloak bell + jaw + chest hex should use filled draw_polygon shapes, not stroke-noise")
	# --- bow geometry locks (kept from the bow-direction fix) ---
	_expect(source.find("var aim := Vector2(bow_side * 0.34, aim_dir).normalized()") >= 0, "draw pose should use the 3/4 upward aim vector")
	_expect(source.find("var grip := pos + Vector2(bow_side * 19.0, -19.0)") >= 0, "bow grip should stay pushed away from the skull")
	_expect(source.find("_draw_aiming_arrow(canvas, nock, grip + aim * 22.0, aim") >= 0, "nocked arrow should run through the grip along the aim vector")
	_expect(source.find("points.append(grip + axis * along + aim * (belly - recurve))") >= 0, "bow belly must bow TOWARD the target (held the correct way round, not reversed)")
	_expect(source.find("for point_index in range(13)") >= 0, "bow should keep the 13-point recurve construction")
	_expect(source.find("pos.y += 14.0") >= 0, "draw anchor should keep the +14 body offset (visual must overlap the collision center)")
	_expect(source.find("draw_colored_polygon") < 0, "visual should avoid animated draw_colored_polygon triangulation risk")
	# --- old cluttered anatomy must stay REMOVED (the messy look the user rejected) ---
	_expect(source.find("func _draw_archer_pelvis") < 0, "redesign must NOT keep the pelvis anatomy")
	_expect(source.find("func _draw_archer_legs") < 0, "redesign must NOT keep jointed legs/feet (the spirit hovers)")
	_expect(source.find("func _draw_archer_spine_and_ribs") < 0, "redesign must NOT keep the ribcage/spine anatomy")
	_expect(source.find("func _draw_premium_skull") < 0, "redesign must NOT keep the over-detailed skull (sutures/teeth/nose)")
	_expect(source.find("for rib_index in range(4)") < 0, "the four-rib stack must be gone")
	_expect(source.find("for tooth_index in range(7)") < 0, "the seven-tooth jaw must be gone")
	_expect(source.find("for vertebra_index in range(6)") < 0, "the six vertebrae must be gone")
	_expect(source.find("for tear_index in range(7)") < 0, "the seven torn-hem strokes must be gone")
	_expect(source.find("var hand := pos + Vector2(bow_side * 8.0, -28.0 + aim_dir * -14.0)") < 0, "should not regress to the old flat hand/bow draw pose")


func _verify_level_scaling_tables_and_runtime_snapshot() -> void:
	var lv1: Dictionary = LingpetCatalog.get_active_skill("nekuring", SKILL_ID, 1)
	var lv3: Dictionary = LingpetCatalog.get_active_skill("nekuring", SKILL_ID, 3)
	var lv4: Dictionary = LingpetCatalog.get_active_skill("nekuring", SKILL_ID, 4)
	var lv5: Dictionary = LingpetCatalog.get_active_skill("nekuring", SKILL_ID, 5)
	_expect(is_equal_approx(float(lv1.get("golden_chance_pct", -1.0)), 0.0), "Skeleton Archer Lv.1 should not roll golden archers")
	_expect(is_equal_approx(float(lv3.get("golden_chance_pct", -1.0)), 20.0), "Skeleton Archer Lv.3 should roll golden archers at 20 percent")
	_expect(is_equal_approx(float(lv4.get("golden_chance_pct", -1.0)), 30.0), "Skeleton Archer Lv.4 should roll golden archers at 30 percent")
	_expect(is_equal_approx(float(lv5.get("golden_chance_pct", -1.0)), 30.0), "Skeleton Archer Lv.5 should keep the 30 percent golden archer roll")
	_expect(is_equal_approx(float(lv5.get("bonus_summon_chance_pct", -1.0)), 30.0), "Skeleton Archer Lv.5 should add a 30 percent second-archer roll")
	_expect(float(lv5.get("arrow_draw_time", 9.0)) < float(lv1.get("arrow_draw_time", 0.0)), "Skeleton Archer arrow draw time should shrink by Lv.5")
	_expect(float(lv5.get("arrow_cooldown_max", 9.0)) < float(lv1.get("arrow_cooldown_max", 0.0)), "Skeleton Archer max arrow cooldown should shrink by Lv.5")

	var owner := FakeOwner.new()
	var lv1_skill := LingpetSkeletonArcherSkill.new()
	lv1_skill.set_golden_rolls_for_tests([0.0])
	lv1_skill.set_bonus_summon_rolls_for_tests([0.0])
	_expect(lv1_skill.launch(Vector2(380.0, 680.0), owner, {"active_skill_level": 1, "spawn_x": 380.0, "spawn_y": 650.0}), "Lv.1 Skeleton Archer snapshot fixture should launch")
	var lv1_snapshot := lv1_skill.get_snapshot()
	_expect(not bool(lv1_snapshot.get("skeleton_archer_has_golden", true)), "Lv.1 should stay non-golden even on a zero golden roll")
	_expect(is_equal_approx(float(lv1_snapshot.get("skeleton_archer_golden_chance_pct", -1.0)), 0.0), "Lv.1 snapshot should expose 0 percent golden chance")

	var lv5_skill := LingpetSkeletonArcherSkill.new()
	lv5_skill.set_bonus_summon_rolls_for_tests([1.0])
	lv5_skill.set_golden_rolls_for_tests([1.0])
	_expect(lv5_skill.launch(Vector2(380.0, 680.0), owner, {"active_skill_level": 5, "spawn_x": 380.0, "spawn_y": 650.0}), "Lv.5 Skeleton Archer snapshot fixture should launch")
	var lv5_snapshot := lv5_skill.get_snapshot()
	_expect(is_equal_approx(float(lv5_snapshot.get("skeleton_archer_golden_chance_pct", -1.0)), 30.0), "Lv.5 snapshot should expose 30 percent golden chance")
	_expect(is_equal_approx(float(lv5_snapshot.get("skeleton_archer_bonus_summon_chance_pct", -1.0)), 30.0), "Lv.5 snapshot should expose 30 percent bonus summon chance")
	_expect(float(lv5_snapshot.get("skeleton_archer_arrow_draw_time", 9.0)) < float(lv1_snapshot.get("skeleton_archer_arrow_draw_time", 0.0)), "runtime snapshot should show faster Lv.5 arrow draw time")
	_expect(float(lv5_snapshot.get("skeleton_archer_arrow_cooldown_max", 9.0)) < float(lv1_snapshot.get("skeleton_archer_arrow_cooldown_max", 0.0)), "runtime snapshot should show faster Lv.5 arrow cooldown")


func _verify_normal_arrow_hit_applies_original_stun_shape() -> void:
	var skill := LingpetSkeletonArcherSkill.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var status_state := FakeStatusEffectState.new()
	var boss_ai := FakeBossAiState.new()
	var registry := FakeRegistry.new({
		"game_audio": audio,
		"status_effect_state": status_state,
		"boss_ai_state": boss_ai,
	})
	skill.set_golden_rolls_for_tests([1.0])
	skill.set_normal_spread_degrees_for_tests([0.0])
	_expect(skill.launch(Vector2(380.0, 680.0), owner, {"registry": registry, "spawn_x": 380.0, "spawn_y": 650.0, "arrow_cooldown": 0.0}), "normal Skeleton Archer fixture should launch")
	skill.update(1.21, owner, registry)
	skill.update(1.01, owner, registry)
	_expect(int(skill.get_snapshot().get("skeleton_archer_arrow_fire_count", 0)) == 1, "normal Skeleton Archer should fire one arrow")
	_expect(audio.archer_fire_count == 1 and audio.fire_count == 0, "Skeleton Archer should play the dedicated original arrow.wav fire cue")
	for _i in range(90):
		skill.update(1.0 / 60.0, owner, registry)
		if int(skill.get_snapshot().get("skeleton_archer_arrow_hit_count", 0)) > 0:
			break
	var snapshot := skill.get_snapshot()
	_expect(int(snapshot.get("skeleton_archer_arrow_hit_count", 0)) == 1, "Skeleton Archer arrow should hit the boss hit radius")
	_expect(audio.archer_hit_count == 1 and audio.hit_count == 0, "Skeleton Archer should play the dedicated original bullethit cue on boss hit")
	_expect(boss_ai.knockback_calls == 0, "Skeleton Archer should let shared status own knockback when status_effect_state is available")
	_expect(status_state.applied.size() == 1, "Skeleton Archer should apply one boss stun status on hit")
	if status_state.applied.size() == 1:
		var status_call: Dictionary = status_state.applied[0]
		var status_data: Dictionary = status_call.get("data", {}) as Dictionary
		_expect(str(status_call.get("target", "")) == "boss", "Skeleton Archer stun should target the boss")
		_expect(str(status_call.get("status_id", "")) == "stun", "Skeleton Archer should use the shared boss stun status")
		_expect(is_equal_approx(float(status_call.get("duration_frames", 0.0)), 36.0), "Skeleton Archer stun should keep the original 36-frame hit stun")
		_expect(is_equal_approx(absf(float(status_data.get("knockback_vel", 0.0))), 14.0), "Skeleton Archer should map the original 150 reference knockback into Godot's 14 px/frame boss nudge")
		_expect(is_equal_approx(float(status_data.get("knockback_frames", 0.0)), 36.0), "Skeleton Archer knockback should last 36 frames")
		_expect(is_equal_approx(float(status_data.get("knockback_decay_per_frame", 0.0)), 0.85), "Skeleton Archer knockback should use the shipped 0.85 decay")
	_expect(is_equal_approx(float(snapshot.get("skeleton_archer_original_knockback_vel", 0.0)), 150.0), "snapshot should preserve the original PingFighter knockback constant as a parity anchor")


func _verify_golden_archer_multishot() -> void:
	var skill := LingpetSkeletonArcherSkill.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({"game_audio": audio})
	skill.set_golden_rolls_for_tests([0.0])
	_expect(skill.launch(Vector2(380.0, 680.0), owner, {"registry": registry, "active_skill_level": 3, "spawn_x": 380.0, "spawn_y": 650.0, "arrow_cooldown": 0.0}), "golden Skeleton Archer fixture should launch")
	skill.update(1.21, owner, registry)
	skill.update(1.01, owner, registry)
	var snapshot := skill.get_snapshot()
	_expect(bool(snapshot.get("skeleton_archer_has_golden", false)), "golden roll below 20 percent should create a golden archer")
	_expect(int(snapshot.get("skeleton_archer_arrow_fire_count", 0)) == 3, "golden Skeleton Archer should fire the original three-arrow volley")
	_expect(int(snapshot.get("skeleton_archer_arrow_count", 0)) == 3, "golden Skeleton Archer volley should keep three live arrows before the next motion step")
	_expect(audio.archer_fire_count == 1 and audio.fire_count == 0, "golden volley should play one dedicated fire cue for the volley")


func _verify_level5_bonus_summon() -> void:
	var owner := FakeOwner.new()
	var single_skill := LingpetSkeletonArcherSkill.new()
	single_skill.set_bonus_summon_rolls_for_tests([0.31])
	single_skill.set_golden_rolls_for_tests([1.0])
	_expect(single_skill.launch(Vector2(380.0, 680.0), owner, {"active_skill_level": 5, "spawn_x": 380.0, "spawn_y": 650.0}), "Lv.5 single-roll Skeleton Archer fixture should launch")
	_expect(int(single_skill.get_snapshot().get("skeleton_archer_archer_count", 0)) == 1, "Lv.5 bonus roll above 30 percent should summon one archer")

	var double_skill := LingpetSkeletonArcherSkill.new()
	double_skill.set_bonus_summon_rolls_for_tests([0.29])
	double_skill.set_golden_rolls_for_tests([1.0, 1.0])
	_expect(double_skill.launch(Vector2(380.0, 680.0), owner, {"active_skill_level": 5, "spawn_x": 380.0, "spawn_y": 650.0}), "Lv.5 double-roll Skeleton Archer fixture should launch")
	var snapshot := double_skill.get_snapshot()
	_expect(int(snapshot.get("skeleton_archer_archer_count", 0)) == 2, "Lv.5 bonus roll below 30 percent should summon two archers")
	_expect(int(snapshot.get("skeleton_archer_summon_count", 0)) == 2, "Lv.5 double summon should record both spawned archers")


func _verify_returned_ball_breaks_archer() -> void:
	var skill := LingpetSkeletonArcherSkill.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({"game_audio": audio})
	skill.set_golden_rolls_for_tests([1.0])
	_expect(skill.launch(Vector2(380.0, 680.0), owner, {"registry": registry, "spawn_x": 380.0, "spawn_y": 650.0}), "ball-break Skeleton Archer fixture should launch")
	skill.update(1.21, owner, registry)
	var positions: Array = skill.get_snapshot().get("skeleton_archer_archer_positions", []) as Array
	_expect(positions.size() == 1, "ball-break fixture should expose one live archer position")
	if positions.size() == 1 and positions[0] is Vector2:
		owner.ball_pos = positions[0]
		owner.ball_vel = Vector2(0.0, 12.0)
		skill.update(1.0 / 60.0, owner, registry)
	var snapshot := skill.get_snapshot()
	_expect(int(snapshot.get("skeleton_archer_archer_death_count", 0)) == 1, "boss-returned downward ball should shatter the player-side archer")
	_expect(int(snapshot.get("skeleton_archer_archer_count", 0)) == 0, "shattered archer should leave the live archer list")
	_expect(int(snapshot.get("skeleton_archer_dying_count", 0)) == 1, "shattered archer should leave a short bone-fragment death visual")
	_expect(audio.archer_death_count == 1, "shattered archer should play the original skulldead death cue")
	_expect(audio.break_count == 0, "shattered archer should prefer the dedicated death cue over the borrowed bonebreak cue")


func _verify_archer_count_cap_bounds_accumulation() -> void:
	# Archers never expire on their own and launch() is re-cast every cooldown with no
	# occupancy check, so a long rally with no archer deaths would let the (now ~5-8x
	# heavier) full-detail archers pile up unbounded. The soft cap must bound the live
	# count, and an over-cap retire must dissolve gracefully WITHOUT counting as a death.
	var cap := int(LingpetSkeletonArcherSkill.MAX_CONCURRENT_ARCHERS)
	_expect(cap > 0, "Skeleton Archer should expose a positive concurrent-archer cap")
	var skill := LingpetSkeletonArcherSkill.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({"game_audio": audio})
	var casts := cap + 3
	for index in range(casts):
		_expect(
			skill.launch(Vector2(380.0, 680.0), owner, {"registry": registry, "active_skill_level": 1, "spawn_x": 380.0, "spawn_y": 650.0, "arrow_cooldown": 99.0}),
			"repeated Skeleton Archer cast %d should launch" % index
		)
	var snapshot := skill.get_snapshot()
	_expect(int(snapshot.get("skeleton_archer_archer_count", 0)) == cap, "live archer count should be clamped to the concurrent cap after over-casting")
	_expect(int(snapshot.get("skeleton_archer_summon_count", 0)) == casts, "every cast should still record a spawn even when the oldest archer retires")
	_expect(int(snapshot.get("skeleton_archer_archer_death_count", 0)) == 0, "a cap retire is a graceful dissolve, not a kill, so it must not increment the death count")
	_expect(int(snapshot.get("skeleton_archer_dying_count", 0)) >= casts - cap, "over-cap archers should leave bone-fragment dissolve visuals")
	_expect(audio.archer_death_count == 0 and audio.break_count == 0, "a cap retire must not play any death cue")


func _verify_original_event_audio_is_ported() -> void:
	# The original PingFighter SkeletonArcher plays four dedicated SFX (bonemake2 summon,
	# skulldead death, arrow fire, bullethit hit). This guard keeps the dedicated cues
	# from silently regressing back to the borrowed shrapnel/ghost/boomerang cues.
	_expect(FileAccess.file_exists("res://assets/sounds/bonemake2.wav"), "original bonemake2 summon sound should be imported into the Godot asset tree")
	_expect(FileAccess.file_exists("res://assets/sounds/skulldead.wav"), "original skulldead death sound should be imported into the Godot asset tree")
	_expect(FileAccess.file_exists("res://assets/sounds/arrow.wav"), "original arrow fire sound should exist in the Godot asset tree")
	_expect(FileAccess.file_exists("res://assets/sounds/bullethit.wav"), "original bullethit hit sound should exist in the Godot asset tree")

	var audio_source := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	_expect(audio_source.find("LINGPET_SKELETON_ARCHER_SUMMON_SOUND_PATH := \"res://assets/sounds/bonemake2.wav\"") >= 0, "game audio should map the summon cue to the original bonemake2.wav")
	_expect(audio_source.find("LINGPET_SKELETON_ARCHER_DEATH_SOUND_PATH := \"res://assets/sounds/skulldead.wav\"") >= 0, "game audio should map the death cue to the original skulldead.wav")
	_expect(audio_source.find("LINGPET_SKELETON_ARCHER_ARROW_FIRE_SOUND_PATH := \"res://assets/sounds/arrow.wav\"") >= 0, "game audio should map the fire cue to the original arrow.wav")
	_expect(audio_source.find("LINGPET_SKELETON_ARCHER_ARROW_HIT_SOUND_PATH := \"res://assets/sounds/bullethit.wav\"") >= 0, "game audio should map the hit cue to the original bullethit.wav")
	_expect(audio_source.find("func play_lingpet_skeleton_archer_summon") >= 0, "game audio should expose the dedicated summon play method")
	_expect(audio_source.find("func play_lingpet_skeleton_archer_death") >= 0, "game audio should expose the dedicated death play method")
	_expect(audio_source.find("func play_lingpet_skeleton_archer_arrow_fire") >= 0, "game audio should expose the dedicated fire play method")
	_expect(audio_source.find("func play_lingpet_skeleton_archer_arrow_hit") >= 0, "game audio should expose the dedicated hit play method")

	var host_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
	_expect(host_source.find("play_lingpet_skeleton_archer_summon") >= 0, "host launch feedback should prefer the dedicated summon cue")

	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skeleton_archer_skill.gd")
	_expect(skill_source.find("play_lingpet_skeleton_archer_arrow_fire") >= 0, "skill should prefer the dedicated arrow-fire cue")
	_expect(skill_source.find("play_lingpet_skeleton_archer_arrow_hit") >= 0, "skill should prefer the dedicated arrow-hit cue")
	_expect(skill_source.find("play_lingpet_skeleton_archer_death") >= 0, "skill should prefer the dedicated death cue")


func _skill_ids(pool: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for skill in pool:
		ids.append(str(skill.get("id", "")))
	return ids


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
