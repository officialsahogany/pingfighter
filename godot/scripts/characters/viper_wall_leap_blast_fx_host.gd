extends Node2D

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ViperWallLeapBodyCoreFx := preload("res://scripts/characters/viper_wall_leap_body_core_fx.gd")

const SMOKE_BLOOM_TEXTURE_PATH := "res://assets/sprites/characters/viper/wall_leap_raid/serin_blast_smoke_bloom_imagegen_v1.png"
const BLADE_SHARDS_TEXTURE_PATH := "res://assets/sprites/characters/viper/wall_leap_raid/serin_blast_blade_shards_imagegen_v1.png"
const SHOCK_RING_TEXTURE_PATH := "res://assets/sprites/characters/viper/wall_leap_raid/serin_blast_shock_ring_imagegen_v1.png"

const SMOKE_DIAMETER := 334.0
const SHARDS_DIAMETER := 286.0
const SHOCK_RING_DIAMETER := 390.0
const SMOKE_BLEND_MODE := CanvasItemMaterial.BLEND_MODE_MIX
const LIGHT_BLEND_MODE := CanvasItemMaterial.BLEND_MODE_ADD

static var _smoke_bloom_texture: Texture2D = null
static var _blade_shards_texture: Texture2D = null
static var _shock_ring_texture: Texture2D = null
static var _prewarm_step_index := 0
static var _prewarmed := false

var _state: Dictionary = {}
var _playfield_clip: Control = null
var _smoke_sprite: Sprite2D = null
var _blade_shards_sprite: Sprite2D = null
var _shock_ring_sprite: Sprite2D = null
var _body_core_fx = null
var _mix_material: CanvasItemMaterial = null
var _additive_material: CanvasItemMaterial = null


static func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


static func prewarm_assets_step() -> bool:
	if _prewarmed:
		return true
	match _prewarm_step_index:
		0:
			_smoke_bloom_texture = ProjectResourceLoader.load_texture(SMOKE_BLOOM_TEXTURE_PATH)
		1:
			_blade_shards_texture = ProjectResourceLoader.load_texture(BLADE_SHARDS_TEXTURE_PATH)
		2:
			_shock_ring_texture = ProjectResourceLoader.load_texture(SHOCK_RING_TEXTURE_PATH)
		_:
			_prewarmed = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"wall_leap_blast_texture_layer_count": 3,
		"wall_leap_fx_texture_layer_count": 3,
		"wall_leap_blast_smoke_blend_mode": "mix" if SMOKE_BLEND_MODE == CanvasItemMaterial.BLEND_MODE_MIX else "not_mix",
		"wall_leap_blast_blade_shards_blend_mode": "add" if LIGHT_BLEND_MODE == CanvasItemMaterial.BLEND_MODE_ADD else "not_add",
		"wall_leap_blast_shock_ring_blend_mode": "add" if LIGHT_BLEND_MODE == CanvasItemMaterial.BLEND_MODE_ADD else "not_add",
		"wall_leap_blast_smoke_texture_path": SMOKE_BLOOM_TEXTURE_PATH,
		"wall_leap_blast_blade_shards_texture_path": BLADE_SHARDS_TEXTURE_PATH,
		"wall_leap_blast_shock_ring_texture_path": SHOCK_RING_TEXTURE_PATH,
		"wall_leap_blast_texture_pieces_ready": (
			_is_png_texture_ready(SMOKE_BLOOM_TEXTURE_PATH, _smoke_bloom_texture)
			and _is_png_texture_ready(BLADE_SHARDS_TEXTURE_PATH, _blade_shards_texture)
			and _is_png_texture_ready(SHOCK_RING_TEXTURE_PATH, _shock_ring_texture)
		),
		"wall_leap_fx_texture_pieces_ready": (
			_is_png_texture_ready(SMOKE_BLOOM_TEXTURE_PATH, _smoke_bloom_texture)
			and _is_png_texture_ready(BLADE_SHARDS_TEXTURE_PATH, _blade_shards_texture)
			and _is_png_texture_ready(SHOCK_RING_TEXTURE_PATH, _shock_ring_texture)
		),
	}


func _ready() -> void:
	var should_remain_active := visible and not _state.is_empty()
	z_as_relative = false
	z_index = 18
	_build_children()
	set_process(false)
	set_active(should_remain_active and can_handle_state(_state))
	if visible:
		_apply_state()


func prewarm_runtime_nodes() -> void:
	prewarm_assets()
	_build_children()
	set_active(false)


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _smoke_sprite == null:
		_build_children()
	_state = next_state.duplicate(false)
	set_active(active and can_handle_state(_state))
	if visible:
		_apply_state()


func set_active(active: bool) -> void:
	visible = active
	set_process(false)
	if active:
		if _playfield_clip != null:
			_playfield_clip.visible = true
		return
	_hide_layers()


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	_state.clear()
	if free_self and is_inside_tree():
		queue_free()


func can_handle_state(next_state: Dictionary) -> bool:
	return (
		bool(next_state.get("active", false))
		and next_state.get("origin_screen", Vector2.ZERO) is Vector2
		and float(next_state.get("render_scale", 0.0)) > 0.0
	)


func get_layer_status() -> Dictionary:
	return {
		"layer_count": 3,
		"blast_layer_count": 3,
		"playfield_clip_active": _playfield_clip != null and _playfield_clip.clip_contents,
		"smoke_visible": _smoke_sprite != null and _smoke_sprite.visible,
		"blade_shards_visible": _blade_shards_sprite != null and _blade_shards_sprite.visible,
		"shock_ring_visible": _shock_ring_sprite != null and _shock_ring_sprite.visible,
		"body_core_visible": _body_core_fx != null and _body_core_fx.visible,
		"smoke_blend_mode": _material_blend_mode(_smoke_sprite),
		"blade_shards_blend_mode": _material_blend_mode(_blade_shards_sprite),
		"shock_ring_blend_mode": _material_blend_mode(_shock_ring_sprite),
	}


func _build_children() -> void:
	prewarm_assets()
	if _playfield_clip == null:
		_playfield_clip = Control.new()
		_playfield_clip.name = "SerinBlastPlayfieldClip"
		_playfield_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_playfield_clip.clip_contents = true
		_playfield_clip.visible = false
		add_child(_playfield_clip)
	if _mix_material == null:
		_mix_material = _make_canvas_material(SMOKE_BLEND_MODE)
	if _additive_material == null:
		_additive_material = _make_canvas_material(LIGHT_BLEND_MODE)
	if _smoke_sprite == null:
		_smoke_sprite = _make_sprite("SerinBlastSmokeBloom", _smoke_bloom_texture, _mix_material, 0)
	if _shock_ring_sprite == null:
		_shock_ring_sprite = _make_sprite("SerinBlastShockRing", _shock_ring_texture, _additive_material, 1)
	if _blade_shards_sprite == null:
		_blade_shards_sprite = _make_sprite("SerinBlastBladeShards", _blade_shards_texture, _additive_material, 2)
	if _body_core_fx == null:
		_body_core_fx = ViperWallLeapBodyCoreFx.new()
		_body_core_fx.name = "SerinBodyDetonationCore"
		_body_core_fx.z_index = 3
		_body_core_fx.visible = false
		_playfield_clip.add_child(_body_core_fx)


func _make_sprite(sprite_name: String, texture: Texture2D, material: Material, layer_z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.centered = true
	sprite.texture = texture
	sprite.material = material
	sprite.z_index = layer_z
	sprite.visible = false
	_playfield_clip.add_child(sprite)
	return sprite


func _apply_state() -> void:
	var ratio := clampf(float(_state.get("progress", 0.0)), 0.0, 1.0)
	var render_scale := maxf(0.01, float(_state.get("render_scale", 1.0)))
	var origin: Vector2 = _state.get("origin_screen", Vector2.ZERO)
	var hit_origin: Vector2 = _state.get("hit_screen", origin)
	var playfield_origin: Vector2 = _state.get("playfield_origin_screen", Vector2.ZERO)
	var playfield_size: Vector2 = _state.get("playfield_size_screen", Vector2(760.0, 750.0) * render_scale)
	var hit := bool(_state.get("hit", false))
	_playfield_clip.position = playfield_origin
	_playfield_clip.size = playfield_size
	_playfield_clip.visible = true
	var origin_local := origin - playfield_origin
	var hit_origin_local := hit_origin - playfield_origin
	_body_core_fx.position = origin_local
	_body_core_fx.sync_progress(float(_state.get("body_core_progress", 1.0)))
	var expansion := 1.0 - pow(1.0 - ratio, 3.0)
	var smoke_fade := pow(1.0 - ratio, 0.62)
	_smoke_sprite.visible = _smoke_sprite.texture != null and smoke_fade > 0.01
	_smoke_sprite.position = origin_local + Vector2(lerpf(-7.0, 12.0, ratio), lerpf(8.0, -25.0, ratio)) * render_scale
	_smoke_sprite.rotation = lerpf(-0.055, 0.035, ratio)
	_set_sprite_diameter(_smoke_sprite, lerpf(92.0, SMOKE_DIAMETER, expansion) * render_scale)
	_smoke_sprite.modulate = Color(0.94, 0.97, 1.0, 0.96 * smoke_fade)

	var ring_ratio := clampf(ratio / 0.62, 0.0, 1.0)
	var ring_origin := origin_local.lerp(hit_origin_local, 0.28 if hit else 0.0)
	_shock_ring_sprite.visible = _shock_ring_sprite.texture != null and ring_ratio < 1.0
	_shock_ring_sprite.position = ring_origin
	_shock_ring_sprite.rotation = lerpf(-0.10, 0.09, ring_ratio)
	_set_sprite_diameter(_shock_ring_sprite, lerpf(46.0, SHOCK_RING_DIAMETER, 1.0 - pow(1.0 - ring_ratio, 2.6)) * render_scale)
	_shock_ring_sprite.modulate = Color(1.0, 0.94, 0.86, pow(1.0 - ring_ratio, 1.22))

	var shards_ratio := clampf(ratio / 0.78, 0.0, 1.0)
	var shards_tail_ratio := clampf(float(_state.get("shards_tail_progress", ratio)), 0.0, 1.0)
	var shards_fade := pow(1.0 - shards_tail_ratio, 1.08)
	_blade_shards_sprite.visible = _blade_shards_sprite.texture != null and shards_fade > 0.01
	_blade_shards_sprite.position = origin_local + Vector2(lerpf(-5.0, 18.0, shards_ratio), lerpf(3.0, -16.0, shards_ratio)) * render_scale
	_blade_shards_sprite.rotation = lerpf(-0.075, 0.085, shards_ratio)
	_set_sprite_diameter(_blade_shards_sprite, lerpf(64.0, SHARDS_DIAMETER, 1.0 - pow(1.0 - shards_ratio, 2.2)) * render_scale)
	_blade_shards_sprite.modulate = Color(1.0, 0.90, 0.97, shards_fade)


func _hide_layers() -> void:
	if _playfield_clip != null:
		_playfield_clip.visible = false
	for sprite in [_smoke_sprite, _blade_shards_sprite, _shock_ring_sprite]:
		if sprite != null:
			sprite.visible = false
	if _body_core_fx != null:
		_body_core_fx.set_active(false)


func _set_sprite_diameter(sprite: Sprite2D, diameter: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	var texture_size := sprite.texture.get_size()
	var source_diameter := maxf(texture_size.x, texture_size.y)
	if source_diameter <= 0.0:
		return
	sprite.scale = Vector2.ONE * (diameter / source_diameter)


static func _make_canvas_material(blend_mode: int) -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = blend_mode
	return material


static func _is_png_texture_ready(path: String, texture: Texture2D) -> bool:
	return path.ends_with(".png") and texture != null and texture.get_width() > 0 and texture.get_height() > 0


func _material_blend_mode(sprite: Sprite2D) -> int:
	if sprite == null or not (sprite.material is CanvasItemMaterial):
		return -1
	return int((sprite.material as CanvasItemMaterial).blend_mode)
