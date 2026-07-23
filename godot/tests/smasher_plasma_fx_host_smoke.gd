extends SceneTree

# 스매셔 플라즈마 3-피스 모듈러 VFX 호스트 봉인:
#  - 파이프라인 준비(셰이더 프리셋 + 3 텍스처) 상태
#  - 실제 씬에 붙여 렌더(셰이더 컴파일/텍스처 로드) 시 런타임 에러 0
#  - 좌표 규약: host.position == 렌더러 pos, host.scale == render_scale
#  - 블렌드 의도 분리: backplate/arc = writhe-ember(ADD), core = MIX(material null),
#    particles = additive CanvasItemMaterial
#  - enraged 프리셋 스왑, 단일 cleanup(set_active(false) -> 전 자식 off)

const PlasmaFxHost := preload("res://scripts/characters/smasher_plasma_fx_host.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")

const OUT_DIR := "res://../tmp"
const OUT_PATH := "res://../tmp/smasher_plasma_fx_host_probe.png"

var _failures: Array[String] = []
var _host: Node2D = null


func _init() -> void:
	get_root().size = Vector2i(760, 750)
	PlasmaFxHost.reset_textures_for_test()
	_verify_pipeline_status()

	_host = PlasmaFxHost.new()
	_host.name = "PlasmaFxHost"
	get_root().add_child(_host)

	# charge phase: 중간 세기, non-enraged, render_scale != 1로 좌표 규약 검증.
	_host.sync_state({
		"phase_active": true,
		"pos": Vector2(300.0, 620.0),
		"render_scale": 1.5,
		"radius": 90.0,
		"intensity": 0.6,
		"enraged": false,
		"quality_scale": 1.0,
		"phase": "charge",
	}, true)
	_verify_active_charge_state()

	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	await process_frame
	_verify_no_render_error_and_enraged_swap()
	await _verify_runtime_pixels_if_available()
	_verify_no_center_fallback()
	await _verify_live_drawer_wiring()
	_verify_cleanup()
	_finish()


func _verify_pipeline_status() -> void:
	var status: Dictionary = PlasmaFxHost.build_pipeline_status()
	for key in [
		"smasher_plasma_orb_shader_ready",
		"smasher_plasma_orb_enraged_shader_ready",
		"smasher_plasma_arc_shader_ready",
		"smasher_plasma_backplate_texture_ready",
		"smasher_plasma_arc_texture_ready",
		"smasher_plasma_particle_texture_ready",
	]:
		_expect(bool(status.get(key, false)), "pipeline status should report ready: " + key)


func _verify_active_charge_state() -> void:
	_expect(_host.visible, "host should be visible while phase_active")
	# 좌표 규약: 렌더러가 계산한 screen pos + render_scale를 그대로 적용.
	_expect(_host.position.is_equal_approx(Vector2(300.0, 620.0)), "host position should equal the renderer-provided screen pos")
	_expect(_host.scale.is_equal_approx(Vector2(1.5, 1.5)), "host scale should equal render_scale")
	var dbg: Dictionary = _host.get_debug_status()
	_expect(bool(dbg.get("active", false)), "debug active should be true")
	_expect(bool(dbg.get("backplate_shader_ready", false)), "backplate should use the writhe-ember shader (ADD light)")
	_expect(bool(dbg.get("arc_shader_ready", false)), "arc should use the writhe-ember shader (ADD light)")
	_expect(bool(dbg.get("core_blend_mix", false)), "core should be a plain MIX sprite (실체), not the additive shader")
	# 파티클은 additive CanvasItemMaterial이어야 한다.
	var particles: Node = _host.get_node_or_null("PlasmaPlayfieldClip/PlasmaParticles")
	_expect(particles != null, "particle node should exist")
	if particles != null:
		var mat = particles.material
		_expect(mat is CanvasItemMaterial and (mat as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "particles should use an additive CanvasItemMaterial (light)")


func _verify_no_render_error_and_enraged_swap() -> void:
	# enraged wave phase로 전환: 프리셋 스왑 확인 + 렌더 에러 없음(러너가 ERROR 라인 포착).
	_host.sync_state({
		"phase_active": true,
		"pos": Vector2(380.0, 300.0),
		"render_scale": 1.0,
		"radius": 130.0,
		"intensity": 1.0,
		"enraged": true,
		"quality_scale": 1.0,
		"phase": "wave",
	}, true)
	var dbg: Dictionary = _host.get_debug_status()
	_expect(bool(dbg.get("enraged", false)), "host should flip to the enraged tuning table")
	_expect(str(dbg.get("phase", "")) == "wave", "host should report the wave phase during the projectile")
	_expect(float(dbg.get("phase_envelope", 1.0)) > 1.0, "wave phase should start with a short pop envelope")
	_expect(_host.position.is_equal_approx(Vector2(380.0, 300.0)), "host should re-anchor to the new wave pos")


func _verify_runtime_pixels_if_available() -> void:
	var display_name := DisplayServer.get_name().to_lower()
	if display_name.find("headless") >= 0:
		print("smasher_plasma_fx_host_smoke: pixel QA skipped under headless display server")
		return
	for _idx in range(3):
		await process_frame
	var viewport_texture := get_root().get_texture()
	if viewport_texture == null:
		print("smasher_plasma_fx_host_smoke: pixel QA skipped under dummy renderer")
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		print("smasher_plasma_fx_host_smoke: pixel QA skipped under empty viewport texture")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var save_error := image.save_png(ProjectSettings.globalize_path(OUT_PATH))
	_expect(save_error == OK, "plasma host visual probe should save a runtime screenshot")
	var sample_rect := Rect2(Vector2(250.0, 170.0), Vector2(260.0, 260.0))
	_expect(_max_rgb_energy(image, sample_rect) > 0.20, "active plasma host should render nonblank cyan-white pixels")


# 유효한 위치(Vector2 pos)가 없는 활성 상태가 오면, 화면 중앙(380,375) 기본값으로
# 오브가 잠깐 뜨지 않고 숨겨야 한다(차징 시작 시 화면 중앙 플래시 회귀 방지).
func _verify_no_center_fallback() -> void:
	_host.sync_state({
		"phase_active": true,
		"radius": 90.0,
		"intensity": 0.6,
		"quality_scale": 1.0,
		"phase": "charge",
	}, true)
	_expect(not _host.visible, "host must NOT render at the screen-center fallback when pos is missing")


func _verify_cleanup() -> void:
	# 단일 cleanup query: set_active(false) 한 번에 전 자식 off.
	_host.sync_state({"phase_active": false}, false)
	_expect(not _host.visible, "host should hide when phase inactive")
	var dbg: Dictionary = _host.get_debug_status()
	_expect(not bool(dbg.get("particle_emitting", true)), "particles should stop emitting on cleanup")
	for child_name in ["PlasmaBackplate", "PlasmaArc", "PlasmaCore"]:
		var child: Node = _host.get_node_or_null("PlasmaPlayfieldClip/" + child_name)
		_expect(child != null and not (child as CanvasItem).visible, "child should hide on cleanup: " + child_name)


func _max_rgb_energy(image: Image, rect: Rect2) -> float:
	var max_energy := 0.0
	var min_x := clampi(floori(rect.position.x), 0, image.get_width() - 1)
	var min_y := clampi(floori(rect.position.y), 0, image.get_height() - 1)
	var max_x := clampi(ceili(rect.end.x), 0, image.get_width() - 1)
	var max_y := clampi(ceili(rect.end.y), 0, image.get_height() - 1)
	var step_x := maxi(1, int((max_x - min_x) / 16))
	var step_y := maxi(1, int((max_y - min_y) / 16))
	for y in range(min_y, max_y + 1, step_y):
		for x in range(min_x, max_x + 1, step_x):
			var color := image.get_pixel(x, y)
			max_energy = maxf(max_energy, color.r + color.g + color.b)
	return max_energy


func _finish() -> void:
	if _failures.is_empty():
		print("smasher_plasma_fx_host_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakePlasmaSpyState:
	extends RefCounted

	var draw_calls := 0
	var contact_calls := 0
	var fx_state := {
		"phase": "wave",
		"phase_active": true,
		"pos": Vector2(300.0, 400.0),
		"radius": 130.0,
		"intensity": 0.8,
		"enraged": true,
	}

	func get_plasma_fx_state(shake_offset: Vector2 = Vector2.ZERO) -> Dictionary:
		var state: Dictionary = fx_state.duplicate(true)
		state["pos"] = (state.get("pos", Vector2.ZERO) as Vector2) + shake_offset
		return state

	func has_visible_effects() -> bool:
		return true

	func draw(_canvas: CanvasItem, _shake: Vector2 = Vector2.ZERO) -> void:
		draw_calls += 1

	func draw_contact_overlay(_canvas: CanvasItem, _shake: Vector2 = Vector2.ZERO) -> void:
		contact_calls += 1


class FakeDrawerRegistry:
	extends RefCounted

	var plasma_state: Object

	func get_instance(key: String) -> Object:
		if key == "smasher_plasma_state":
			return plasma_state
		return null


# 라이브 배선 씰(WIP 파괴 후 재배선 + 재검수 P2): draw_plasma_effects가
# ①호스트를 즉시모드 draw 안에서 동기 생성하지 않고 call_deferred로 붙이며(구성=
# _draw 밖) ②트리에 들어온 뒤 FX 좌표식(screen = game_offset + (playfield_pos +
# shake) × render_scale)으로 sync하며 ③절차적 charge/wave draw()는 은퇴하되 접촉
# 오버레이는 호스트 준비와 무관하게 매 프레임 그리는지 스파이로 봉인한다.
func _verify_live_drawer_wiring() -> void:
	var effects_drawer: Object = load("res://scripts/core/battle_playfield_effects_drawer.gd").new()
	var canvas := Node2D.new()
	get_root().add_child(canvas)
	var spy := FakePlasmaSpyState.new()
	var registry := FakeDrawerRegistry.new()
	registry.plasma_state = spy
	var shake := Vector2(4.0, -2.0)
	var draw_context := {
		"selected_character_type": "smasher",
		"game_offset": Vector2(550.0, 60.0),
		"render_scale": 1.5,
	}
	# 첫 draw: 호스트는 즉시모드 draw에서 동기 생성되면 안 된다(deferred). 접촉
	# 오버레이는 호스트와 무관하게 이번 프레임에도 그려야 한다.
	effects_drawer.draw_plasma_effects(canvas, registry, shake, draw_context)
	_expect(canvas.get_node_or_null("SmasherPlasmaFxHost") == null, "live drawer must NOT create the host synchronously in the immediate draw path (deferred add_child)")
	_expect(spy.draw_calls == 0, "live path must retire the procedural charge/wave draw() (modular host owns the orb)")
	_expect(spy.contact_calls == 1, "boss-contact overlay must draw even while the host is deferred-creating")
	await process_frame
	var live_host: Node = canvas.get_node_or_null("SmasherPlasmaFxHost")
	_expect(live_host != null, "live drawer should attach the plasma FX host as a canvas child after one idle frame")
	# 두 번째 draw: 트리에 들어온 호스트를 조회해 sync(좌표 계약).
	effects_drawer.draw_plasma_effects(canvas, registry, shake, draw_context)
	if live_host != null:
		var expected_pos: Vector2 = Vector2(550.0, 60.0) + (Vector2(300.0, 400.0) + shake) * 1.5
		_expect(
			(live_host as Node2D).position.distance_to(expected_pos) < 0.5,
			"host position must follow the FX coordinate contract (got %s expected %s)" % [
				str((live_host as Node2D).position),
				str(expected_pos),
			]
		)
	_expect(spy.draw_calls == 0, "live path must retire the procedural charge/wave draw() across both frames")
	_expect(spy.contact_calls == 2, "boss-contact overlay must draw on the sync frame too")
	canvas.queue_free()
