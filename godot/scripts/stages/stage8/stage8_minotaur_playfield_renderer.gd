extends RefCounted

# Stage 8 미노타우로스 code-native playfield VFX placeholder (Slice 1 shell).
#
# Ported from stage7_akamu_playfield_renderer. Slice 1 preserves the public
# draw / prewarm / reset contract that the actor renderer + core framework call
# by name, but THINS every boss-skill VFX channel (clones, shuriken, cloud,
# aura, superspeed dash wake, afterimage, awakening cinematic) down to a no-op.
# The earthquake combat VFX return in Slice 5.
#
# RESERVED-ASSET SAFETY: no not-yet-generated stage8 res:// path is wired into
# any draw here — the underlay / overlay passes render nothing until Slice 5
# lands the real channels + baked textures. The VfxTextureCache preload keeps
# the const preload chain intact; it bakes only code-native procedural textures
# (no reserved art), so prewarm stays safe even before stage8 art exists.

const VfxTextureCache := preload("res://scripts/stages/stage8/stage8_minotaur_vfx_texture_cache.gd")

const FIELD_SIZE := Vector2(760.0, 750.0)

# 그림자분신 스프라이트 프레임 소스(보스 액터 렌더러). 부모 액터 렌더러가 생성
# 시점에 물려준다. Slice 1 draw는 비어 있어 아직 소비되지 않지만, 액터 렌더러가
# _init에서 배선하는 세터 계약은 유지한다 (Slice 5 클론 스프라이트 소스로 재사용).
var _clone_sprite_source: Object = null


func set_clone_sprite_source(source: Object) -> void:
	_clone_sprite_source = source


func prewarm_assets() -> void:
	VfxTextureCache.prewarm()


func prewarm_assets_step() -> bool:
	return VfxTextureCache.prewarm_step()


func reset() -> void:
	pass


func clear_transient_canvas_items() -> void:
	pass


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, _perf_logger: Object = null) -> void:
	draw_underlay(canvas, context, shake_offset, _perf_logger)
	draw_overlay(canvas, context, shake_offset, _perf_logger)


func draw_underlay(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2,
	_perf_logger: Object = null
) -> void:
	if canvas == null:
		return
	# Slice 1 stub: clone / shuriken / superspeed / afterimage / aura VFX are
	# intentionally no-op. Slice 5 restores the earthquake channels here.


func draw_overlay(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2,
	_perf_logger: Object = null
) -> void:
	if canvas == null:
		return
	# Slice 1 stub: cloud / wind-aura / awakening cinematic overlay no-op.


func get_asset_status() -> Dictionary:
	return {
		"uses_code_native_placeholder": true,
		"generated_art_loaded": false,
		"runtime_nodes_required": false,
	}


func get_imagegen_asset_status() -> Dictionary:
	return get_asset_status()
