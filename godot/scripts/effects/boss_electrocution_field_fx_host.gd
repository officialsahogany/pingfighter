extends Node2D

# Shared, source-agnostic boss electrocution FIELD (the "감전" symptom).
#
# Any electric stun — Ragnarok Hammer mythic, Lumion's thunder orb, or any
# future skill — drives this same field via the shared electric-stun context
# flags (`ragnarok_hammer_electric_stun_active` / `boss_electric_stun_active`).
# This is the "field" layer of electrocution; the body tremble + cyan tint in
# boss_electric_stun_visual.gd is the "body" layer. Each boss actor renderer
# drives both, so the symptom looks identical regardless of the source.
#
# Read goal: sparks SEARING all over the body + short bolts crackling ACROSS the
# body, NOT a smooth centred energy ring/halo (which read as "magic"). So the
# composition is body-conforming, not a big aura:
#   - spark shower (GPUParticles2D, BOX emission over the body box, ADD): hot
#     white->cyan sparks bursting across the whole body.
#   - crackle bolts (procedural _draw, ADD): short jagged white-core/cyan-glow
#     bolts jumping between random points across the body box, RE-SEEDED on a
#     discrete ~18 Hz tick with per-tick strobe so they snap/flicker like a live
#     arc instead of sliding smoothly.
#   - contact flashes + a faint charged underglow (procedural, no ring).
# Tween supplies the intro/outro envelope; _process advances time + queue_redraw
# so the fade-out keeps animating after the driver stops syncing.
#
# Coordinate space: the host parents to the boss renderer's canvas, whose
# playfield mapping is applied via draw_set_transform() in _draw() — which child
# NODES do NOT inherit. So sync_field BAKES game_offset + playfield_center *
# render_scale with scale = render_scale (read from context), exactly like
# InfernoChargeFxHost. The host's OWN _draw()/children then render in local
# space and ride that baked transform. (Do NOT feed raw playfield coords
# assuming inheritance — that detaches the FX to the top-left letterbox corner;
# regression pinned by boss_electrocution_field_fx_host_smoke.gd.)

const SELF_PATH := "res://scripts/effects/boss_electrocution_field_fx_host.gd"
const HOST_NAME := "BossElectrocutionFieldHost"
const SPARK_PATH := "res://assets/sprites/effects/boss_electrocution_field_spark_imagegen_v1.png"

# Above the immediate-drawn boss body, below the ball / HUD.
const HOST_Z_INDEX := 4
# Body coverage box (playfield px, centred on the boss). Sparks + bolts spread
# over this so the effect reads as "all over the body", not a halo. Tunable.
const BODY_BOX_W := 78.0
const BODY_BOX_H := 108.0
const BOLT_COUNT := 11
const BOLT_SEGMENTS := 7
const BOLT_TICK_MSEC := 46.0
const FLASH_COUNT := 4
const SPARK_PARTICLE_AMOUNT := 48
const PARTICLE_FIXED_FPS := 30
const FADE_IN_SEC := 0.12
const FADE_OUT_SEC := 0.20

# Lightning palette — electric blue, NOT near-white. Core is a pale electric
# blue (still bright but clearly blue), glow is a saturated electric blue.
const CORE_COLOR := Color(0.66, 0.82, 1.0, 1.0)
const GLOW_COLOR := Color(0.30, 0.52, 1.0, 1.0)
const SPARK_COLOR := Color(0.74, 0.88, 1.0, 1.0)

static var _prewarmed := false
static var _spark_tex: Texture2D = null
static var _pending_host: Node = null
static var _active_hosts: Array = []

var _sparks: GPUParticles2D = null
var _additive_material: CanvasItemMaterial = null

var _envelope := 0.0
var _envelope_tween: Tween = null
var _target_active := false
var _intensity := 1.0
var _elapsed := 0.0


# ---------------------------------------------------------------- static API

static func prewarm_assets() -> void:
	if _prewarmed:
		return
	_load_textures()
	_prewarmed = true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"boss_electrocution_field_spark_ready": _spark_tex != null,
		"boss_electrocution_field_bolt_count": BOLT_COUNT,
		"boss_electrocution_field_spark_amount": SPARK_PARTICLE_AMOUNT,
	}


static func _load_textures() -> void:
	if _spark_tex == null:
		_spark_tex = load(SPARK_PATH) as Texture2D


# Boss-renderer-facing one-call driver. Reads the shared electric-stun flags;
# activates / fades the field, or hides it when no electric stun is present.
static func drive_from_context(canvas: CanvasItem, center: Vector2, context: Dictionary) -> void:
	var active: bool = (
		bool(context.get("ragnarok_hammer_electric_stun_active", false))
		or bool(context.get("boss_electric_stun_active", false))
	)
	if not active:
		hide_on_canvas(canvas)
		return
	var host: Node = get_or_create_on_canvas(canvas)
	if host == null or not host.has_method("sync_field"):
		return
	# Bake playfield -> screen (children do NOT inherit the parent canvas's
	# draw_set_transform mapping). See header.
	var game_offset: Vector2 = _as_vector2(context.get("game_offset", Vector2.ZERO))
	var render_scale: float = max(0.01, float(context.get("render_scale", 1.0)))
	var game_size: Vector2 = _as_vector2(context.get("game_size", Vector2(760.0, 750.0)))
	# Keep the body box inside the playfield so sparks/bolts cannot bleed into the
	# side letterbox / pillars when the boss hugs an edge.
	var margin: float = BODY_BOX_W * 0.5
	var clamped_center := Vector2(
		clampf(center.x, margin, maxf(margin, game_size.x - margin)),
		center.y
	)
	var ratio: float = clampf(float(context.get("status_boss_stun_ratio", 1.0)), 0.0, 1.0)
	var intensity: float = 0.7 + 0.3 * ratio
	host.sync_field(clamped_center, game_offset, render_scale, intensity, false)


static func get_or_create_on_canvas(canvas: CanvasItem) -> Node:
	if canvas == null or not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(HOST_NAME)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		_pending_host = null
		_remember_host(existing)
		return existing
	if _pending_host != null and is_instance_valid(_pending_host) and not _pending_host.is_queued_for_deletion():
		_remember_host(_pending_host)
		return _pending_host
	var host: Node = load(SELF_PATH).new()
	host.name = HOST_NAME
	_pending_host = host
	_remember_host(host)
	parent.call_deferred("add_child", host)
	return host


static func hide_on_canvas(canvas: CanvasItem) -> void:
	if canvas == null or not (canvas is Node):
		return
	var parent: Node = canvas as Node
	var host: Node = parent.get_node_or_null(HOST_NAME)
	if host == null and _pending_host != null and is_instance_valid(_pending_host) and not _pending_host.is_queued_for_deletion():
		host = _pending_host
	if host != null and is_instance_valid(host) and not host.is_queued_for_deletion() and host.has_method("deactivate"):
		host.deactivate()


static func hide_all_existing_hosts() -> void:
	if _pending_host != null and is_instance_valid(_pending_host) and not _pending_host.is_queued_for_deletion():
		if _pending_host.has_method("deactivate"):
			_pending_host.deactivate()
	var next_hosts: Array = []
	for host_ref in _active_hosts:
		var host: Node = _resolve_host_ref(host_ref)
		if host == null or not is_instance_valid(host) or host.is_queued_for_deletion():
			continue
		if host.has_method("deactivate"):
			host.deactivate()
		next_hosts.append(host_ref)
	_active_hosts = next_hosts


static func _remember_host(host: Node) -> void:
	if host == null:
		return
	for host_ref in _active_hosts:
		if _resolve_host_ref(host_ref) == host:
			return
	_active_hosts.append(weakref(host))


static func _resolve_host_ref(host_ref: Variant) -> Node:
	if host_ref is WeakRef:
		var value: Variant = (host_ref as WeakRef).get_ref()
		return (value as Node) if value is Node else null
	return (host_ref as Node) if host_ref is Node else null


static func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return Vector2.ZERO


# ---------------------------------------------------------------- instance

func _ready() -> void:
	z_as_relative = false
	z_index = HOST_Z_INDEX
	_remember_host(self)
	_build_children()
	visible = _target_active
	set_process(_target_active)


func sync_field(playfield_center: Vector2, game_offset: Vector2, render_scale: float, intensity: float, _peak: bool) -> void:
	if _sparks == null:
		_build_children()
	# Parent canvas uses draw_set_transform (draw-local), not a node transform,
	# so the host must bake the same playfield->screen mapping itself.
	position = game_offset + playfield_center * render_scale
	scale = Vector2(render_scale, render_scale)
	_intensity = clampf(intensity, 0.0, 1.5)
	if not _target_active:
		_target_active = true
		visible = true
		set_process(true)
		if _sparks != null:
			_sparks.emitting = true
		_start_envelope_tween(1.0, FADE_IN_SEC)
	queue_redraw()


func deactivate() -> void:
	if not _target_active and not visible:
		return
	_target_active = false
	_start_envelope_tween(0.0, FADE_OUT_SEC)


func is_field_active_for_tests() -> bool:
	return _target_active


func get_envelope_for_tests() -> float:
	return _envelope


func tear_down(free_self: bool = false) -> void:
	_target_active = false
	_kill_envelope_tween()
	_hide()
	if free_self:
		queue_free()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _sparks != null:
		_sparks.emitting = _target_active and _envelope > 0.05
		var pm: ParticleProcessMaterial = _sparks.process_material as ParticleProcessMaterial
		if pm != null:
			var s: float = _intensity * clampf(_envelope, 0.0, 1.0)
			pm.color = Color(SPARK_COLOR.r, SPARK_COLOR.g, SPARK_COLOR.b, clampf(0.55 + 0.4 * s, 0.0, 1.0))
	queue_redraw()
	if not _target_active and _envelope <= 0.001:
		_hide()


# Body-conforming crackle: bolts searing ACROSS the body box + contact flashes +
# a faint charged underglow. All additive (host.material), all re-seeded on the
# discrete bolt tick with per-bolt strobe so it snaps/flickers like a live arc.
func _draw() -> void:
	var env: float = clampf(_envelope, 0.0, 1.0)
	if env <= 0.001:
		return
	var strength: float = _intensity * env
	var now: float = float(Time.get_ticks_msec())
	var tick: float = floor(now / BOLT_TICK_MSEC)
	var hw: float = BODY_BOX_W * 0.5
	var hh: float = BODY_BOX_H * 0.5

	# Faint "charged body" underglow — soft, dim, NOT a ring.
	draw_circle(Vector2.ZERO, maxf(hw, hh) * 1.02, Color(0.26, 0.66, 1.0, 0.05 * env))
	draw_circle(Vector2.ZERO, maxf(hw, hh) * 0.6, Color(0.50, 0.86, 1.0, 0.07 * env))

	# Crackling bolts jumping across the body — thin, jagged, electric blue.
	var glow_w: float = max(0.8, 1.1 * (0.7 + 0.5 * strength))
	var bend: float = 8.0 + 8.0 * strength
	for i in range(BOLT_COUNT):
		if _hash(float(i) * 3.13, tick) < 0.42:
			continue  # strobe: this bolt is "off" this tick
		var a := Vector2(_hash_range(float(i) * 1.7, tick, -hw, hw), _hash_range(float(i) * 2.3, tick, -hh, hh))
		var b := Vector2(_hash_range(float(i) * 1.7 + 9.0, tick, -hw, hw), _hash_range(float(i) * 2.3 + 9.0, tick, -hh, hh))
		var pts := _build_bolt_points(a, b, float(i) + tick * 17.0, bend, BOLT_SEGMENTS)
		draw_polyline(pts, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.46 * env), glow_w, true)
		draw_polyline(pts, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.9 * env), 0.8, true)
		# Rough forked branch off a midpoint for chaos.
		if _hash(float(i) * 4.7 + 2.0, tick) > 0.45 and pts.size() > 3:
			var bi: int = 1 + int(_hash(float(i) * 5.3, tick) * float(pts.size() - 2))
			var origin: Vector2 = pts[bi]
			var fork := origin + Vector2(
				_hash_range(float(i) * 6.1, tick, -hw * 0.55, hw * 0.55),
				_hash_range(float(i) * 6.7, tick, -hh * 0.55, hh * 0.55)
			)
			var bpts := _build_bolt_points(origin, fork, float(i) + tick * 31.0 + 71.0, bend * 0.7, 4)
			draw_polyline(bpts, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.32 * env), max(0.7, glow_w * 0.65), true)
			draw_polyline(bpts, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.78 * env), 0.8, true)

	# Contact flashes (the "지지는" searing points) — small, electric blue-white.
	for j in range(FLASH_COUNT):
		if _hash(float(j) * 5.0 + 1.0, tick) < 0.5:
			continue
		var p := Vector2(_hash_range(float(j) * 4.0, tick, -hw, hw), _hash_range(float(j) * 4.0 + 7.0, tick, -hh, hh))
		var r: float = 1.6 + _hash(float(j) * 6.0, tick) * 2.2
		draw_circle(p, r * 2.1, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.28 * env))
		draw_circle(p, r * (1.0 + 0.4 * strength), Color(0.82, 0.92, 1.0, 0.88 * env))


func _build_bolt_points(a: Vector2, b: Vector2, seed_value: float, bend: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var delta := b - a
	var normal := delta.orthogonal()
	if normal.length_squared() > 0.001:
		normal = normal.normalized()
	var seg: int = max(2, segments)
	for k in range(seg + 1):
		var t := float(k) / float(seg)
		# Light taper only — keep the endpoints jagged too for a rougher arc.
		var taper := 1.0 - absf(t * 2.0 - 1.0) * 0.18
		# Two jitter octaves (coarse + high-frequency) for a rougher, noisier bolt.
		var j1 := (_hash(seed_value + float(k) * 1.31, 0.0) - 0.5) * bend
		var j2 := (_hash(seed_value * 1.7 + float(k) * 4.73, 0.0) - 0.5) * bend * 0.5
		pts.append(a.lerp(b, t) + normal * (j1 + j2) * taper)
	return pts


func _build_children() -> void:
	_load_textures()
	if _additive_material == null:
		_additive_material = CanvasItemMaterial.new()
		_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Host's own _draw() (bolts + flashes + underglow) renders additively.
	material = _additive_material
	if _sparks == null:
		_sparks = GPUParticles2D.new()
		_sparks.name = "ElectroSparks"
		_sparks.amount = SPARK_PARTICLE_AMOUNT
		_sparks.lifetime = 0.34
		_sparks.one_shot = false
		_sparks.explosiveness = 0.0
		_sparks.randomness = 0.95
		_sparks.fixed_fps = PARTICLE_FIXED_FPS
		_sparks.local_coords = true
		_sparks.visibility_rect = Rect2(-220.0, -260.0, 440.0, 520.0)
		_sparks.texture = _spark_tex
		_sparks.material = _additive_material
		_sparks.process_material = _build_spark_process_material()
		_sparks.z_index = 1
		_sparks.emitting = false
		add_child(_sparks)


func _start_envelope_tween(target: float, duration: float) -> void:
	_kill_envelope_tween()
	if not is_inside_tree():
		_envelope = target
		return
	_envelope_tween = create_tween()
	_envelope_tween.tween_property(self, "_envelope", target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _kill_envelope_tween() -> void:
	if _envelope_tween != null and _envelope_tween.is_valid():
		_envelope_tween.kill()
	_envelope_tween = null


func _hide() -> void:
	visible = false
	set_process(false)
	_envelope = 0.0
	if _sparks != null:
		_sparks.emitting = false
	queue_redraw()


func _hash(a: float, b: float) -> float:
	var hashed := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return hashed - floor(hashed)


func _hash_range(a: float, b: float, lo: float, hi: float) -> float:
	return lerp(lo, hi, _hash(a, b))


# Spark shower over the whole body box: fast, short-lived, hot white sparks that
# burst outward all over the body (BOX emission, not a ring), then a touch of
# gravity so they "rain off" the body.
static func _build_spark_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3(0.0, 90.0, 0.0)
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 210.0
	mat.damping_min = 18.0
	mat.damping_max = 64.0
	mat.scale_min = 0.10
	mat.scale_max = 0.28
	mat.color = Color(SPARK_COLOR.r, SPARK_COLOR.g, SPARK_COLOR.b, 0.8)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(BODY_BOX_W * 0.5, BODY_BOX_H * 0.5, 0.0)
	return mat
