extends RefCounted

# Stage 8 Minotaur actor-pass orchestrator.
# Shared player and Commando renderers remain common owners; Stage 8 owns only
# its playfield effects and boss sprite runtime.

const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")
const Stage8MinotaurPlayfieldRenderer := preload("res://scripts/stages/stage8/stage8_minotaur_playfield_renderer.gd")
const Stage8MinotaurBossActorRenderer := preload("res://scripts/stages/stage8/stage8_minotaur_boss_actor_renderer.gd")

var playfield_renderer: Object = Stage8MinotaurPlayfieldRenderer.new()
var player_renderer: Object = Stage1PlayerActorRenderer.new()
var boss_renderer: Object = Stage8MinotaurBossActorRenderer.new()
var commando_firearm_renderer: Object = Stage1CommandoFirearmRenderer.new()
# 보스 시트 위임이 끝난 뒤에만 플레이필드 VFX bake로 넘어가는 스텝 래치 —
# 한 프리웜 호출은 정확히 한 작업(시트 1장 로드 OR 텍스처 1장 bake)만 한다.
var _boss_prewarm_done := false


func _init() -> void:
	# 보스 시트의 현재 프레임을 프레임 소스로 넘겨 두는 클론-스프라이트 계약.
	# 시트 소유자는 boss child 하나뿐이므로 플레이필드 렌더러에 물려준다.
	# Slice 1 미노타우로스는 아직 분신 스킬이 없어 has_method 가드로 no-op이 되지만
	# 계약(set_clone_sprite_source)은 그대로 보존한다.
	if playfield_renderer.has_method("set_clone_sprite_source"):
		playfield_renderer.set_clone_sprite_source(boss_renderer)


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	# The boot controller owns this parent as one Stage 8 step. Delegate the
	# repeated calls to the boss child so each call loads at most one of its
	# per-pose sheets instead of synchronously decoding the full set, then bake
	# the playfield VFX blit textures one per call. Hot-path lazy bake is
	# forbidden — draw() falls back to vector primitives until then.
	if not _boss_prewarm_done:
		if boss_renderer != null and boss_renderer.has_method("prewarm_assets_step"):
			if not bool(boss_renderer.prewarm_assets_step()):
				return false
		elif boss_renderer != null and boss_renderer.has_method("prewarm_assets"):
			boss_renderer.prewarm_assets()
		_boss_prewarm_done = true
		return false
	if playfield_renderer != null and playfield_renderer.has_method("prewarm_assets_step"):
		return bool(playfield_renderer.prewarm_assets_step())
	return true


func reset() -> void:
	reset_round_fx()
	if boss_renderer != null and boss_renderer.has_method("reset"):
		boss_renderer.reset()


func reset_round_fx() -> void:
	if playfield_renderer != null and playfield_renderer.has_method("reset"):
		playfield_renderer.reset()


func draw(canvas: CanvasItem, context: Dictionary, perf_logger: Object = null) -> void:
	if canvas == null:
		return
	var shake_offset: Vector2 = _as_vector2(context.get("shake_offset", Vector2.ZERO), Vector2.ZERO)
	var uses_split_playfield_passes: bool = playfield_renderer != null \
		and playfield_renderer.has_method("draw_underlay") \
		and playfield_renderer.has_method("draw_overlay")
	if uses_split_playfield_passes:
		playfield_renderer.draw_underlay(canvas, context, shake_offset, perf_logger)
	elif playfield_renderer != null and playfield_renderer.has_method("draw"):
		playfield_renderer.draw(canvas, context, shake_offset, perf_logger)
	player_renderer.draw(canvas, context, shake_offset, perf_logger)
	boss_renderer.draw(canvas, context, shake_offset)
	commando_firearm_renderer.draw(canvas, context, shake_offset)
	if uses_split_playfield_passes:
		playfield_renderer.draw_overlay(canvas, context, shake_offset, perf_logger)


func clear_transient_canvas_items() -> void:
	_clear_renderer_transients(playfield_renderer)
	_clear_renderer_transients(player_renderer)
	_clear_renderer_transients(boss_renderer)
	_clear_renderer_transients(commando_firearm_renderer)


func get_imagegen_asset_status() -> Dictionary:
	if boss_renderer != null and boss_renderer.has_method("get_imagegen_asset_status"):
		return boss_renderer.get_imagegen_asset_status()
	return {
		"uses_code_native_placeholder": true,
		"generated_art_loaded": false,
	}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _clear_renderer_transients(renderer: Object) -> void:
	if renderer != null and renderer.has_method("clear_transient_canvas_items"):
		renderer.clear_transient_canvas_items()
