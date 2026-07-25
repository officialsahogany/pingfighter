extends SceneTree

const Stage7AkamuActorRenderer := preload("res://scripts/stages/stage7/stage7_akamu_actor_renderer.gd")
const Stage7AkamuBossActorRenderer := preload("res://scripts/stages/stage7/stage7_akamu_boss_actor_renderer.gd")
const Stage7AkamuVfxTextureCache := preload("res://scripts/stages/stage7/stage7_akamu_vfx_texture_cache.gd")

const EXPECTED_PATHS := {
	"idle": "res://assets/sprites/bosses/stage7_akamu/stage7_akamu_boss_idle.png",
	"walk_left": "res://assets/sprites/bosses/stage7_akamu/stage7_akamu_boss_walk_left.png",
	"walk_right": "res://assets/sprites/bosses/stage7_akamu/stage7_akamu_boss_walk_right.png",
	"attack": "res://assets/sprites/bosses/stage7_akamu/stage7_akamu_boss_attack.png",
	"dash_left": "res://assets/sprites/bosses/stage7_akamu/stage7_akamu_boss_dash_left.png",
	"dash_right": "res://assets/sprites/bosses/stage7_akamu/stage7_akamu_boss_dash_right.png",
	"victory": "res://assets/sprites/bosses/stage7_akamu/stage7_akamu_boss_victory.png",
	"defeat": "res://assets/sprites/bosses/stage7_akamu/stage7_akamu_boss_defeat.png",
	"stun": "res://assets/sprites/bosses/stage7_akamu/stage7_akamu_boss_stun.png",
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_paths_and_grid()
	_verify_staged_child_prewarm()
	_verify_priority_and_native_walk_sheets()
	_verify_attack_plays_full_swing()
	_verify_shadow_clone_sprite_parity()
	_verify_source_contracts()
	if _failures.is_empty():
		print("stage7_akamu_sprite_runtime_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_paths_and_grid() -> void:
	var renderer: Object = Stage7AkamuBossActorRenderer.new()
	var paths: Dictionary = renderer.get_debug_sheet_paths()
	_expect(paths.size() == EXPECTED_PATHS.size(), "Akamu should expose exactly nine runtime sheet paths")
	for key_value in EXPECTED_PATHS:
		var key := str(key_value)
		var expected_path := str(EXPECTED_PATHS[key])
		_expect(str(paths.get(key, "")) == expected_path, "%s should use its Stage 7 dedicated path" % key)
		_expect(FileAccess.file_exists(expected_path), "%s runtime sheet should exist" % key)
	var grid: Dictionary = renderer.get_debug_grid_contract()
	_expect(int(grid.get("cols", 0)) == 4, "Akamu sheets should use four columns")
	_expect(int(grid.get("rows", 0)) == 2, "Akamu sheets should use two rows")
	_expect(int(grid.get("frame_count", 0)) == 8, "Akamu sheets should expose eight frames")
	_expect(grid.get("draw_size", Vector2.ZERO) == Vector2(128.0, 128.0), "Akamu gameplay draw size should be 128x128")


func _verify_staged_child_prewarm() -> void:
	var renderer: Object = Stage7AkamuBossActorRenderer.new()
	var initial_status: Dictionary = renderer.get_asset_status()
	_expect(not bool(initial_status.get("prewarm_complete", true)), "fresh Akamu renderer should not report prewarm complete")
	_expect(bool(initial_status.get("uses_code_native_placeholder", false)), "code fallback should be limited to the prewarm window")
	for step in range(EXPECTED_PATHS.size()):
		var done: bool = bool(renderer.prewarm_assets_step())
		var textures_value: Variant = renderer.get("_textures")
		var texture_count := (textures_value as Dictionary).size() if textures_value is Dictionary else -1
		_expect(texture_count == step + 1, "boss prewarm step %d should load exactly one texture" % step)
		_expect(done == (step == EXPECTED_PATHS.size() - 1), "boss prewarm completion should follow the ninth texture")
	var status: Dictionary = renderer.get_asset_status()
	_expect(bool(status.get("prewarm_complete", false)), "Akamu prewarm should complete after nine texture steps")
	_expect(bool(status.get("generated_art_loaded", false)), "all nine promoted Akamu sheets should load")
	_expect(not bool(status.get("uses_code_native_placeholder", true)), "code fallback should switch off after prewarm")
	for key_value in EXPECTED_PATHS:
		var key := str(key_value)
		_expect(bool(status.get("stage7_akamu_" + key, false)), "%s asset status should be truthful after prewarm" % key)
		var textures: Dictionary = renderer.get("_textures")
		var texture_value: Variant = textures.get(key, null)
		_expect(texture_value is Texture2D, "%s should load as Texture2D" % key)
		if texture_value is Texture2D:
			_expect((texture_value as Texture2D).get_size() == Vector2(1024.0, 512.0), "%s should keep the runtime-ready 1024x512 size" % key)
	_expect(renderer.get_debug_source_rect("idle", 0) == Rect2(0.0, 0.0, 256.0, 256.0), "frame 0 should use the first 256x256 cell")
	_expect(renderer.get_debug_source_rect("idle", 7) == Rect2(768.0, 256.0, 256.0, 256.0), "frame 7 should use the final 4x2 cell")

	var actor: Object = Stage7AkamuActorRenderer.new()
	# 2026-07-11 프레임드랍 수정: 부모 스텝 체인 = 보스 시트(스텝당 1장) 뒤에
	# 플레이필드 VFX bake-once 텍스처(스텝당 1장)가 이어진다. 핫패스 lazy
	# bake 금지 계약이라 완료 보고는 마지막 bake 스텝에서만 나와야 한다.
	Stage7AkamuVfxTextureCache.debug_clear()
	var vfx_steps: int = Stage7AkamuVfxTextureCache.BAKE_KEYS.size()
	var total_steps: int = EXPECTED_PATHS.size() + vfx_steps
	for step in range(total_steps):
		var done: bool = bool(actor.prewarm_assets_step())
		var child: Object = actor.get("boss_renderer")
		var child_textures_value: Variant = child.get("_textures")
		var child_texture_count := (child_textures_value as Dictionary).size() if child_textures_value is Dictionary else -1
		_expect(
			child_texture_count == mini(step + 1, EXPECTED_PATHS.size()),
			"actor prewarm should delegate one texture at a time to its boss child"
		)
		_expect(
			done == (step == total_steps - 1),
			"actor prewarm should finish only after boss sheets plus playfield VFX bake steps"
		)
	_expect(
		Stage7AkamuVfxTextureCache.is_ready(),
		"actor prewarm chain should leave the playfield VFX blit textures baked"
	)
	var actor_status: Dictionary = actor.get_imagegen_asset_status()
	_expect(bool(actor_status.get("generated_art_loaded", false)), "actor facade should publish its boss child's loaded status")


func _verify_attack_plays_full_swing() -> void:
	# 회귀 방지: 공격은 0.20초 원샷 스윙(핑퐁 8프레임 windup→peak→recovery). 프레임이
	# 공격 창 진행도(1 - remaining/total)에 매핑돼 0→7 전체가 한 번 재생되어야 한다.
	# 고정 루프(0.06s)로 돌리면 0.20초 창이 정점(≈3)에서 끝나 스윙이 잘린다
	# (사용자 리포트: "공격 모션이 잘려보임"). end_frame==7 단언이 이 회귀를 잡는다.
	var renderer: Object = Stage7AkamuBossActorRenderer.new()
	var total := 0.20
	var base := {
		"stage7_akamu_boss_attack_active": true,
		"stage7_akamu_boss_attack_total": total,
	}
	base["stage7_akamu_boss_attack_remaining"] = total
	var start_pose: Dictionary = renderer.get_debug_selected_pose(base)
	_expect(str(start_pose.get("key", "")) == "attack", "attack window should select the attack sheet")
	_expect(int(start_pose.get("frame", -1)) == 0, "attack should begin at frame 0 (windup)")
	base["stage7_akamu_boss_attack_remaining"] = total * 0.5
	_expect(int(renderer.get_debug_selected_pose(base).get("frame", -1)) == 4, "attack mid-window should reach the peak/turnaround frame")
	base["stage7_akamu_boss_attack_remaining"] = 0.001
	_expect(int(renderer.get_debug_selected_pose(base).get("frame", -1)) == 7, "attack must play through the recovery half to frame 7 (not cut at the peak)")
	var prev := -1
	for i in range(9):
		base["stage7_akamu_boss_attack_remaining"] = total * (1.0 - float(i) / 8.0)
		var f := int(renderer.get_debug_selected_pose(base).get("frame", -1))
		_expect(f >= prev, "attack frame should advance monotonically across the window (step %d)" % i)
		prev = f


func _verify_priority_and_native_walk_sheets() -> void:
	var renderer: Object = Stage7AkamuBossActorRenderer.new()
	var context := {
		"boss_defeat_active": true,
		"boss_victory_active": true,
		"active_item_boss_stun_active": true,
		"boss_dash_active": true,
		"stage7_akamu_boss_attack_active": true,
		"boss_is_walking": true,
		"boss_facing": -1,
	}
	_expect(_pose_key(renderer, context) == "defeat", "defeat should outrank every Akamu pose")
	context["boss_defeat_active"] = false
	_expect(_pose_key(renderer, context) == "victory", "victory should outrank stun, dash, attack, and walk")
	context["boss_victory_active"] = false
	_expect(_pose_key(renderer, context) == "stun", "stun should outrank dash, attack, and walk")
	context["active_item_boss_stun_active"] = false
	_expect(_pose_key(renderer, context) == "dash_left", "left-facing dash should outrank attack and walk with the native left dash sheet")
	context["boss_dash_active"] = false
	_expect(_pose_key(renderer, context) == "attack", "attack should outrank walk")
	context["stage7_akamu_boss_attack_active"] = false
	var left_pose: Dictionary = renderer.get_debug_selected_pose(context)
	_expect(str(left_pose.get("key", "")) == "walk_left", "left-facing movement should use the native left sheet")
	_expect(not left_pose.has("flip_h"), "native left movement must not request runtime mirroring")
	context["boss_facing"] = 1
	var right_pose: Dictionary = renderer.get_debug_selected_pose(context)
	_expect(str(right_pose.get("key", "")) == "walk_right", "right-facing movement should use the native right sheet")
	_expect(not right_pose.has("flip_h"), "native right movement must not request runtime mirroring")
	context["boss_is_walking"] = false
	_expect(_pose_key(renderer, context) == "idle", "idle should remain the final priority fallback")
	var paths: Dictionary = renderer.get_debug_sheet_paths()
	_expect(paths.get("walk_left", "") != paths.get("walk_right", ""), "native left and right movement should own distinct files")

	var cloud_pre_context := {
		"stage7_akamu_cloud_dash_active": true,
		"stage7_akamu_cloud_dash_phase": "pre",
	}
	_expect(_pose_key(renderer, cloud_pre_context) == "attack", "cloud pre-cast should use the attack sheet, not dash")
	_expect(_pose_key(renderer, {"stage7_akamu_cloud_dash_phase": "down"}) == "dash_right", "cloud descent should use the facing-side dash sheet")
	_expect(_pose_key(renderer, {"stage7_akamu_cloud_dash_phase": "up"}) == "dash_right", "cloud ascent should use the facing-side dash sheet")
	_expect(_pose_key(renderer, {"stage7_akamu_escape_active": true}) == "dash_right", "escape travel should use the facing-side dash sheet")
	_expect(
		_pose_key(renderer, {
			"boss_dash_active": true,
			"stage7_akamu_superspeed_dash_direction": -1,
		}) == "dash_left",
		"superspeed dash direction should pick the matching native dash sheet"
	)
	_expect(
		_pose_key(renderer, {
			"status_boss_stun_active": true,
			"stage7_akamu_cloud_dash_phase": "down",
			"stage7_akamu_boss_attack_active": true,
		}) == "stun",
		"shared status stun should outrank Stage 7 dash and attack poses"
	)


func _verify_shadow_clone_sprite_parity() -> void:
	var actor: Object = Stage7AkamuActorRenderer.new()
	var playfield: Object = actor.get("playfield_renderer")
	var boss: Object = actor.get("boss_renderer")
	var context := {"boss_pos": Vector2(330.0, 25.0)}
	_expect(
		str(playfield.get_debug_clone_render_mode(context)) == "placeholder",
		"clone rendering should stay on the code fallback until the boss sheets prewarm"
	)
	actor.prewarm_assets()
	_expect(
		str(playfield.get_debug_clone_render_mode(context)) == "sprite",
		"prewarmed Stage 7 clones must render the live boss sprite frame, not the placeholder box"
	)
	var spec: Dictionary = boss.get_shadow_clone_frame_spec(context)
	_expect(spec.get("texture", null) is Texture2D, "clone frame spec should carry the live sheet texture")
	var pose: Dictionary = boss.get_debug_selected_pose(context)
	var expected_rect: Rect2 = boss.get_debug_source_rect(str(pose.get("key", "idle")), int(pose.get("frame", 0)))
	_expect(
		spec.get("source_rect", Rect2()) == expected_rect and expected_rect.size.x > 0.0,
		"clone frame spec should mirror the boss's live pose frame"
	)
	var tint_value: Variant = spec.get("tint", null)
	_expect(
		tint_value is Color
			and (tint_value as Color).is_equal_approx(Color(150.0 / 255.0, 150.0 / 255.0, 180.0 / 255.0)),
		"clone tint should keep the legacy BLEND_RGBA_MULT(150,150,180) parity"
	)
	var orphan_script := load("res://scripts/stages/stage7/stage7_akamu_playfield_renderer.gd") as GDScript
	var orphan: Object = orphan_script.new()
	_expect(
		str(orphan.get_debug_clone_render_mode(context)) == "placeholder",
		"an unwired playfield renderer must not claim the sprite path"
	)


func _verify_source_contracts() -> void:
	var boss_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_boss_actor_renderer.gd")
	var sprite_draw_source := _source_section(boss_source, "func _draw_sprite_pose(", "func _get_source_rect(")
	var draw_source := _source_section(boss_source, "func draw(", "func get_asset_status(")
	_expect(sprite_draw_source.find("_draw_flipped") < 0, "Akamu runtime sprite draw should not mirror native directional art")
	_expect(sprite_draw_source.find("SUPERSPEED_SPRITE_MODULATE") >= 0, "Akamu sprite draw should preserve the Superspeed tint")
	_expect(sprite_draw_source.find("stage7_akamu_boss_ball_intangible") >= 0, "Akamu sprite draw should preserve intangibility alpha feedback")
	# 2026-07-11 라이브 QA: 코드-네이티브 팔/검격 오버레이가 승격된 공격
	# 시트 위에 겹치면 원본에 없는 V자 잔상이 붙는다. 오버레이는 프리웜 전
	# 플레이스홀더 액터 전용으로만 남아야 한다.
	_expect(
		sprite_draw_source.find("_draw_attack_pose") < 0,
		"promoted attack sheet must not stack the placeholder arm/slash overlay"
	)
	var placeholder_source := _source_section(boss_source, "func _draw_placeholder_actor(", "func _draw_attack_pose(")
	_expect(
		placeholder_source.find("_draw_attack_pose") >= 0,
		"pre-prewarm placeholder actor should keep the code-native attack overlay fallback"
	)
	# 2026-07-11 파리티: 무형(intangible) 피드백은 반투명 알파 전용 — 128셀
	# 크기의 펄스 사각 아웃라인("사각 그리드" 리포트)은 재도입 금지.
	_expect(
		boss_source.find("grow(3.0 + phase") < 0,
		"intangible feedback must stay alpha-only (no pulsing cell-sized outline box)"
	)
	_expect(draw_source.find("boss_paddle_shrink_scale") >= 0, "Akamu actor should preserve dwarf-centered shrink")
	_expect(draw_source.find("if not _assets_prewarmed") >= 0, "code fallback should be gated to unfinished prewarm")
	# 2026-07-11 원본 파리티: 내구 점 카운터 오버레이는 원본에 없어 제거됨 —
	# 오라 strength 약화(playfield)가 유일한 내구 피드백이다.
	_expect(draw_source.find("_draw_wind_aura_durability") < 0, "legacy-absent durability pip overlay must stay removed")

	var actor_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_actor_renderer.gd")
	var actor_prewarm_source := _source_section(actor_source, "func prewarm_assets_step(", "func reset(")
	_expect(actor_prewarm_source.find("boss_renderer.prewarm_assets_step") >= 0, "Stage 7 actor prewarm should delegate to the boss child")
	_expect(actor_prewarm_source.find("boss_renderer.prewarm_assets()") < 0 or actor_prewarm_source.find("has_method(\"prewarm_assets_step\")") >= 0, "child staged prewarm should be preferred over a synchronous fallback")


func _pose_key(renderer: Object, context: Dictionary) -> String:
	return str(renderer.get_debug_selected_pose(context).get("key", ""))


func _source_section(source: String, start_marker: String, end_marker: String) -> String:
	var start_index := source.find(start_marker)
	if start_index < 0:
		return ""
	var end_index := source.find(end_marker, start_index + start_marker.length())
	if end_index < 0:
		return source.substr(start_index)
	return source.substr(start_index, end_index - start_index)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
