extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage1CommandoFirearmFxHost := preload("res://scripts/stages/stage1/stage1_commando_firearm_fx_host.gd")
const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")

const SLINGSHOT_STONE_SHEET_PATH := "res://assets/sprites/effects/commando_slingshot_stone_projectile_sheet_imagegen_v1.png"
const SLINGSHOT_STONE_SHEET_COLS := 4
const SLINGSHOT_STONE_SHEET_ROWS := 3
const SLINGSHOT_STONE_VARIANTS_PER_LEVEL := 4
const SLINGSHOT_STONE_MIN_DRAW_DIAMETERS := {1: 22.0, 2: 27.0, 3: 32.0}
const BOWLING_TRAP_INSTALLED_TEXTURE_PATH := "res://assets/sprites/effects/commando_bowling_trap_installed_imagegen_v1.png"
const BOWLING_TRAP_CAPTURE_SHEET_PATH := "res://assets/sprites/effects/commando_bowling_trap_capture_sheet_autosprite_v1.png"
const BOWLING_TRAP_LAUNCH_SHEET_PATH := "res://assets/sprites/effects/commando_bowling_trap_launch_sheet_autosprite_v1.png"
const BOWLING_TRAP_SHEET_COLS := 4
const BOWLING_TRAP_SHEET_ROWS := 4
const BOWLING_TRAP_SHEET_FRAME_COUNT := 16
const SUPPORT_AIRCRAFT_TEXTURE_PATH := "res://assets/sprites/effects/commando_fire_support_aircraft_stealth_imagegen_v1.png"
const SUPPORT_BOMB_TEXTURE_PATH := "res://assets/sprites/effects/commando_fire_support_bomb_projectile_imagegen_v1.png"
const SUPPORT_AIRCRAFT_SOURCE_RECT := Rect2(Vector2(270.0, 41.0), Vector2(483.0, 430.0))
const SUPPORT_AIRCRAFT_DRAW_SIZE := Vector2(90.0, 80.4)
const SUPPORT_AIRCRAFT_TRAIL_COUNT := 4
const SUPPORT_AIRCRAFT_SHADOW_OFFSET := Vector2(0.0, 42.0)
const SUPPORT_BOMB_DRAW_LENGTH_SCALE := 6.5
const SUPPORT_BOMB_DRAW_WIDTH_SCALE := 4.3
const SUPPORT_MISSILE_LAUNCH_FLASH_FRAMES := 12.0
const SUPPORT_MISSILE_SMOKE_PUFFS := 5

const REMASTER_TEXTURE_FAMILIES := [
	"muzzle_glow",
	"impact_burst",
	"impact_ring",
	"lingering_field_glow",
	"projectile_silhouette",
	"bowling_trap_claw",
	"drone_rotor",
	"support_aircraft",
	"support_bomb_projectile",
	"support_airstrike_explosion",
]

const REQUIRED_VISUAL_FAMILIES := [
	"pistol",
	"commando_pistol",
	"ak47",
	"bazooka",
	"net_gun",
	"fire_support",
	"bowling_trap",
	"suicide_drone",
]

var fx_host: Node = null
var fx_host_add_pending := false
static var slingshot_stone_texture: Texture2D = null
static var bowling_trap_installed_texture: Texture2D = null
static var bowling_trap_capture_sheet_texture: Texture2D = null
static var bowling_trap_launch_sheet_texture: Texture2D = null
static var support_aircraft_texture: Texture2D = null
static var support_bomb_texture: Texture2D = null
static var _prewarmed: bool = false
static var _prewarm_step_index: int = 0


# Idempotent. All underlying caches (ImpactFlareTextureCache, ImpactShockwaveTextureCache,
# the bowling/slingshot texture getters, Stage1CommandoFirearmFxHost.prewarm_assets) are
# themselves cached, but skipping the dispatch entirely once `_prewarmed` is true avoids
# the per-frame method-call overhead on every actor render pass.
static func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_runtime_assets() -> void:
	prewarm_assets()


func clear_transient_canvas_items() -> void:
	if _is_valid_fx_host():
		if fx_host.has_method("set_active"):
			fx_host.set_active(false)
		else:
			fx_host.visible = false


static func prewarm_assets_step() -> bool:
	if _prewarmed:
		return true
	match _prewarm_step_index:
		0:
			ImpactFlareTextureCache.get_glow_texture()
		1:
			ImpactFlareTextureCache.get_burst_texture()
		2:
			ImpactFlareTextureCache.get_sparkle_texture()
		3:
			ImpactShockwaveTextureCache.get_full_ring_texture()
		4:
			ImpactShockwaveTextureCache.get_wall_ring_texture("left")
		5:
			ImpactShockwaveTextureCache.get_wall_ring_texture("right")
		6:
			Stage1CommandoFirearmFxHost.prewarm_assets()
		7:
			var fx_probe: Node = Stage1CommandoFirearmFxHost.new()
			if fx_probe != null and fx_probe.has_method("prewarm_node_pipeline"):
				fx_probe.prewarm_node_pipeline()
				fx_probe.free()
		8:
			_get_slingshot_stone_texture()
		9:
			_get_bowling_trap_installed_texture()
		10:
			_get_bowling_trap_capture_sheet_texture()
		11:
			_get_bowling_trap_launch_sheet_texture()
		12:
			_get_support_aircraft_texture()
		13:
			_get_support_bomb_texture()
		_:
			_prewarmed = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 13:
		_prewarmed = true
		_prewarm_step_index = 0
		return true
	return false


static func reset_prewarm_cache_for_test() -> void:
	_prewarmed = false
	_prewarm_step_index = 0


# True iff any commando firearm runtime arrays in `context` carry at least one
# entry. Used to skip the entire commando draw pass on frames where no commando
# state is active — relevant for viper/smasher/optimus/blacksmith plays on a
# stage whose actor renderer still calls this draw() unconditionally.
static func has_anything_to_draw(context: Dictionary) -> bool:
	const KEYS := [
		"commando_firearm_projectiles",
		"commando_firearm_muzzle_flashes",
		"commando_firearm_impact_flashes",
		"commando_firearm_lingering_effects",
		"commando_firearm_shell_casings",
		"commando_firearm_pistol_feedbacks",
		"commando_firearm_support_calls",
		"commando_firearm_bowling_traps",
	]
	for key in KEYS:
		var value: Variant = context.get(key, null)
		if value is Array and not (value as Array).is_empty():
			return true
	return false


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	# Skip the entire draw pass on frames where no commando firearm state is active
	# AND no fx_host exists yet (so there is nothing to deactivate). This is the
	# common case for viper/smasher/optimus/blacksmith plays — the actor renderer
	# calls this draw() unconditionally per stage, so the early return saves the
	# per-frame `_sync_fx_host` call, the `build_draw_items` dictionary creation,
	# and all the no-op array iterations downstream.
	if not has_anything_to_draw(context) and not _is_valid_fx_host():
		return
	prewarm_assets()
	var draw_items: Dictionary = build_draw_items(context)
	_sync_fx_host(canvas, draw_items, shake_offset, context)
	_draw_lingering_texture_layers(canvas, _get_array(draw_items.get("lingering_effects", [])), shake_offset)
	_draw_lingering_effects(canvas, _get_array(draw_items.get("lingering_effects", [])), shake_offset)
	_draw_bowling_traps(canvas, _get_array(draw_items.get("bowling_traps", [])), shake_offset)
	_draw_support_calls(canvas, _get_array(draw_items.get("support_calls", [])), shake_offset)
	_draw_muzzle_texture_layers(canvas, _get_array(draw_items.get("muzzle_flashes", [])), shake_offset)
	_draw_muzzle_flashes(canvas, _get_array(draw_items.get("muzzle_flashes", [])), shake_offset)
	_draw_projectiles(canvas, _get_array(draw_items.get("projectiles", [])), shake_offset)
	_draw_shell_casings(canvas, _get_array(draw_items.get("shell_casings", [])), shake_offset)
	_draw_impact_texture_layers(canvas, _get_array(draw_items.get("impact_flashes", [])), shake_offset)
	_draw_impact_flashes(canvas, _get_array(draw_items.get("impact_flashes", [])), shake_offset)
	_draw_pistol_feedbacks(canvas, _get_array(draw_items.get("pistol_feedbacks", [])), shake_offset)


func build_draw_items(context: Dictionary) -> Dictionary:
	return {
		"projectiles": _get_array(context.get("commando_firearm_projectiles", [])),
		"muzzle_flashes": _get_array(context.get("commando_firearm_muzzle_flashes", [])),
		"impact_flashes": _get_array(context.get("commando_firearm_impact_flashes", [])),
		"lingering_effects": _get_array(context.get("commando_firearm_lingering_effects", [])),
		"shell_casings": _get_array(context.get("commando_firearm_shell_casings", [])),
		"pistol_feedbacks": _get_array(context.get("commando_firearm_pistol_feedbacks", [])),
		"pistol_state": _get_dict(context.get("commando_firearm_pistol_state", {})),
		"support_calls": _get_array(context.get("commando_firearm_support_calls", [])),
		"bowling_traps": _get_array(context.get("commando_firearm_bowling_traps", [])),
	}


func build_texture_remaster_plan(context: Dictionary) -> Dictionary:
	prewarm_assets()
	var draw_items: Dictionary = build_draw_items(context)
	var muzzle_flashes: Array = _get_array(draw_items.get("muzzle_flashes", []))
	var impact_flashes: Array = _get_array(draw_items.get("impact_flashes", []))
	var lingering_effects: Array = _get_array(draw_items.get("lingering_effects", []))
	var pistol_feedbacks: Array = _get_array(draw_items.get("pistol_feedbacks", []))
	var host_status: Dictionary = Stage1CommandoFirearmFxHost.build_pipeline_status()
	var identity_report: Dictionary = build_visual_identity_report(context)
	var plan := {
		"texture_piece_pipeline": true,
		"pistol_feedback_text_pipeline": true,
		"families": REMASTER_TEXTURE_FAMILIES.duplicate(),
		"muzzle_texture_layers": muzzle_flashes.size() * 2,
		"impact_texture_layers": _get_impact_texture_layer_count(impact_flashes),
		"lingering_texture_layers": _get_lingering_texture_layer_count(lingering_effects),
		"pistol_feedback_entries": pistol_feedbacks.size(),
		"glow_texture_ready": ImpactFlareTextureCache.get_glow_texture() != null,
		"burst_texture_ready": ImpactFlareTextureCache.get_burst_texture() != null,
		"sparkle_texture_ready": ImpactFlareTextureCache.get_sparkle_texture() != null,
		"ring_texture_ready": ImpactShockwaveTextureCache.get_full_ring_texture() != null,
		"slingshot_stone_sheet_ready": _get_slingshot_stone_texture() != null,
		"slingshot_stone_sheet_frame_count": SLINGSHOT_STONE_SHEET_COLS * SLINGSHOT_STONE_SHEET_ROWS,
		"slingshot_stone_sheet_cols": SLINGSHOT_STONE_SHEET_COLS,
		"slingshot_stone_sheet_rows": SLINGSHOT_STONE_SHEET_ROWS,
		"bowling_trap_installed_texture_ready": _get_bowling_trap_installed_texture() != null,
		"bowling_trap_capture_sheet_ready": _get_bowling_trap_capture_sheet_texture() != null,
		"bowling_trap_launch_sheet_ready": _get_bowling_trap_launch_sheet_texture() != null,
		"support_aircraft_texture_ready": _get_support_aircraft_texture() != null,
		"support_aircraft_draw_size": SUPPORT_AIRCRAFT_DRAW_SIZE,
		"support_bomb_texture_ready": _get_support_bomb_texture() != null,
		"grenade_explosion_texture_pieces_ready": GrenadeExplosionDrawer.are_texture_assets_ready(),
		"support_airstrike_explosion_texture_layers": _get_support_airstrike_explosion_layer_count(impact_flashes),
		"bowling_trap_sheet_frame_count": BOWLING_TRAP_SHEET_FRAME_COUNT,
		"bowling_trap_sheet_cols": BOWLING_TRAP_SHEET_COLS,
		"bowling_trap_sheet_rows": BOWLING_TRAP_SHEET_ROWS,
		"weapon_visual_identity_count": int(identity_report.get("family_count", 0)),
		"visual_identity_families": _get_array(identity_report.get("weapon_families", [])),
		"visual_identity_layers": _get_array(identity_report.get("layers", [])),
	}
	for key in host_status.keys():
		plan[key] = host_status[key]
	return plan


func build_visual_identity_report(context: Dictionary) -> Dictionary:
	var draw_items: Dictionary = build_draw_items(context)
	var counts := {}
	var layers: Array = []
	for value in _get_array(draw_items.get("projectiles", [])):
		var projectile: Dictionary = _get_dict(value)
		var family: String = _projectile_visual_family(projectile)
		_add_visual_identity(counts, layers, family, _projectile_visual_layer(projectile, family))
	for value in _get_array(draw_items.get("impact_flashes", [])):
		var flash: Dictionary = _get_dict(value)
		if str(flash.get("weapon_id", "")) == "fire_support" and str(flash.get("kind", "")) == "grenade_explosion":
			_add_visual_identity(counts, layers, "fire_support", "airstrike_grenade_explosion")
	for value in _get_array(draw_items.get("shell_casings", [])):
		var shell: Dictionary = _get_dict(value)
		if str(shell.get("weapon_id", "")) == "ak47":
			_add_visual_identity(counts, layers, "ak47", "brass_casing_ejection")
	for value in _get_array(draw_items.get("pistol_feedbacks", [])):
		var feedback: Dictionary = _get_dict(value)
		if str(feedback.get("kind", "")) == "headshot" or str(feedback.get("kind", "")) == "legshot":
			_add_visual_identity(counts, layers, "commando_pistol", "headshot_legshot_text")
	for value in _get_array(draw_items.get("support_calls", [])):
		@warning_ignore("shadowed_variable_base_class")
		var call: Dictionary = _get_dict(value)
		_add_visual_identity(counts, layers, "fire_support", "radio_target_marker")
		if bool(call.get("aircraft_active", false)):
			_add_visual_identity(counts, layers, "fire_support", "aircraft_silhouette")
			_add_visual_identity(counts, layers, "fire_support", "aircraft_motion_trails")
	for value in _get_array(draw_items.get("bowling_traps", [])):
		var trap: Dictionary = _get_dict(value)
		var state: String = str(trap.get("state", "waiting"))
		_add_visual_identity(counts, layers, "bowling_trap", "ground_clamp_%s" % state)
	for value in _get_array(draw_items.get("lingering_effects", [])):
		var effect: Dictionary = _get_dict(value)
		match str(effect.get("kind", "")):
			"net_field":
				_add_visual_identity(counts, layers, "net_gun", "deployed_net_field")
			"fire_zone":
				_add_visual_identity(counts, layers, "suicide_drone", "fire_zone")
			"trap_clamp":
				_add_visual_identity(counts, layers, "bowling_trap", "launch_clamp_burst")
			"blast_field":
				_add_visual_identity(counts, layers, "fire_support", "blast_residue")
	var families: Array = counts.keys()
	families.sort()
	var missing: Array = []
	for family in REQUIRED_VISUAL_FAMILIES:
		if not families.has(family):
			missing.append(family)
	return {
		"weapon_families": families,
		"family_count": families.size(),
		"layers": layers,
		"counts": counts,
		"required_families": REQUIRED_VISUAL_FAMILIES.duplicate(),
		"missing_required_families": missing,
		"all_required_families_present": missing.is_empty(),
	}


func get_remaster_status() -> Dictionary:
	var status: Dictionary = build_texture_remaster_plan({})
	status["fx_host_attached"] = _is_valid_fx_host()
	return status


func _sync_fx_host(
	canvas: CanvasItem,
	draw_items: Dictionary,
	shake_offset: Vector2,
	layout_context: Dictionary = {}
) -> void:
	var fx_impact_flashes: Array = _get_fx_host_impact_flashes(_get_array(draw_items.get("impact_flashes", [])))
	var active := (
		not _get_array(draw_items.get("muzzle_flashes", [])).is_empty()
		or not fx_impact_flashes.is_empty()
		or not _get_array(draw_items.get("lingering_effects", [])).is_empty()
	)
	if not active and not _is_valid_fx_host():
		return
	var host: Node = _get_or_create_fx_host(canvas)
	if host == null or not host.has_method("sync_state"):
		return
	# Shallow copy, not deep: the only mutation is swapping the impact_flashes
	# key to the grenade-filtered set, so we just need a fresh top-level dict so
	# draw() can keep using the original unfiltered impact_flashes afterward. The
	# fx host treats draw_items as read-only (sync_state re-copies it shallow and
	# copies each anchor entry before mutating), so the 8 shared array refs are
	# safe. The old duplicate(true) deep-copied every projectile/casing/effect
	# array every firing frame purely to replace one key.
	var fx_draw_items: Dictionary = draw_items.duplicate(false)
	fx_draw_items["impact_flashes"] = fx_impact_flashes
	host.sync_state(fx_draw_items, shake_offset, active, _build_fx_host_layout(layout_context))


func _build_fx_host_layout(context: Dictionary) -> Dictionary:
	return {
		"game_offset": Stage1ContextReader.as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO),
		"render_scale": max(0.01, float(context.get("render_scale", 1.0))),
	}


func _get_fx_host_impact_flashes(flashes: Array) -> Array:
	var filtered: Array = []
	for value in flashes:
		var flash: Dictionary = _get_dict(value)
		if str(flash.get("kind", "bullet")) == "grenade_explosion":
			continue
		filtered.append(value)
	return filtered


func _get_or_create_fx_host(canvas: CanvasItem) -> Node:
	if _is_valid_fx_host():
		return fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null("CommandoFirearmFxHost")
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		fx_host = existing
		fx_host_add_pending = false
		return fx_host
	fx_host = Stage1CommandoFirearmFxHost.new()
	fx_host.name = "CommandoFirearmFxHost"
	fx_host.visible = false
	if not fx_host_add_pending:
		fx_host_add_pending = true
		parent.call_deferred("add_child", fx_host)
	return fx_host


func _is_valid_fx_host() -> bool:
	return fx_host != null and is_instance_valid(fx_host) and not fx_host.is_queued_for_deletion()


func _draw_muzzle_texture_layers(canvas: CanvasItem, flashes: Array, shake_offset: Vector2) -> void:
	for value in flashes:
		var flash: Dictionary = _get_dict(value)
		var pos: Vector2 = Stage1ContextReader.as_vector2(flash.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var direction: Vector2 = Stage1ContextReader.as_vector2(flash.get("direction", Vector2.UP), Vector2.UP)
		var ratio: float = _timer_ratio(flash)
		var radius: float = float(flash.get("radius", 12.0)) * (0.80 + 0.35 * ratio)
		var color: Color = Stage1ContextReader.as_color(flash.get("color", Color(1.0, 0.75, 0.25)), Color(1.0, 0.75, 0.25))
		var tip: Vector2 = pos + direction.normalized() * radius * 0.34 if direction.length() > 0.001 else pos
		ImpactFlareTextureCache.draw_glow(canvas, pos, radius * 1.65, color, 0.20 * ratio)
		ImpactFlareTextureCache.draw_burst(canvas, tip, radius * 1.10, Color(1.0, 0.94, 0.55), 0.34 * ratio)


func _draw_impact_texture_layers(canvas: CanvasItem, flashes: Array, shake_offset: Vector2) -> void:
	for value in flashes:
		var flash: Dictionary = _get_dict(value)
		var pos: Vector2 = Stage1ContextReader.as_vector2(flash.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var kind: String = str(flash.get("kind", "bullet"))
		var ratio: float = _timer_ratio(flash)
		var radius: float = float(flash.get("radius", 18.0)) * (1.0 - ratio * 0.12)
		var color: Color = Stage1ContextReader.as_color(flash.get("color", Color.WHITE), Color.WHITE)
		var secondary: Color = Stage1ContextReader.as_color(flash.get("secondary", Color(1.0, 0.5, 0.2)), Color(1.0, 0.5, 0.2))
		if kind == "grenade_explosion":
			continue
		if kind == "support_marker":
			ImpactShockwaveTextureCache.draw_full_ring(canvas, pos, radius * (0.92 + (1.0 - ratio) * 0.18), secondary, 0.40 * ratio)
			ImpactFlareTextureCache.draw_sparkle(canvas, pos, radius * 0.52, color, 0.42 * ratio)
			continue
		ImpactFlareTextureCache.draw_glow(canvas, pos, radius * 1.28, color, 0.16 * ratio)
		ImpactFlareTextureCache.draw_burst(canvas, pos, radius * 1.08, secondary, 0.40 * ratio)
		ImpactShockwaveTextureCache.draw_full_ring(canvas, pos, radius * 1.02, secondary, 0.38 * ratio)
		if kind == "net":
			ImpactFlareTextureCache.draw_sparkle(canvas, pos, radius * 0.74, color, 0.36 * ratio)


func _draw_lingering_texture_layers(canvas: CanvasItem, effects: Array, shake_offset: Vector2) -> void:
	for value in effects:
		var effect: Dictionary = _get_dict(value)
		var kind: String = str(effect.get("kind", ""))
		var pos: Vector2 = Stage1ContextReader.as_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var width: float = float(effect.get("width", 120.0))
		var height: float = float(effect.get("height", 60.0))
		var ratio: float = _timer_ratio(effect)
		var color: Color = Stage1ContextReader.as_color(effect.get("color", Color.WHITE), Color.WHITE)
		var secondary: Color = Stage1ContextReader.as_color(effect.get("secondary", color), color)
		match kind:
			"net_field":
				ImpactFlareTextureCache.draw_glow(canvas, pos, max(width, height) * 0.42, color, 0.10 * ratio)
				ImpactShockwaveTextureCache.draw_full_ring(canvas, pos, min(width, height) * 0.46, secondary, 0.18 * ratio)
			"fire_zone":
				ImpactFlareTextureCache.draw_glow(canvas, pos, max(width, height) * 0.55, color, 0.12 * ratio)
				ImpactFlareTextureCache.draw_burst(canvas, pos + Vector2(0.0, -height * 0.10), max(width, height) * 0.36, secondary, 0.18 * ratio)
			"trap_clamp":
				ImpactFlareTextureCache.draw_sparkle(canvas, pos, max(width, height) * 0.44, color, 0.30 * ratio)
			"blast_field":
				for ring_idx in range(3):
					var ring_ratio: float = 0.36 + float(ring_idx) * 0.22 + (1.0 - ratio) * 0.10
					ImpactShockwaveTextureCache.draw_full_ring(canvas, pos, max(width, height) * ring_ratio, secondary, (0.22 - float(ring_idx) * 0.04) * ratio)


func _get_impact_texture_layer_count(flashes: Array) -> int:
	var count := 0
	for value in flashes:
		var kind: String = str(_get_dict(value).get("kind", "bullet"))
		if kind == "support_marker":
			count += 2
		elif kind == "grenade_explosion":
			count += GrenadeExplosionDrawer.get_texture_layer_count(_get_dict(value))
		elif kind == "net":
			count += 4
		else:
			count += 3
	return count


func _get_support_airstrike_explosion_layer_count(flashes: Array) -> int:
	var count := 0
	for value in flashes:
		var flash: Dictionary = _get_dict(value)
		if str(flash.get("weapon_id", "")) == "fire_support" and str(flash.get("kind", "")) == "grenade_explosion":
			count += GrenadeExplosionDrawer.get_texture_layer_count(flash)
	return count


func _get_lingering_texture_layer_count(effects: Array) -> int:
	var count := 0
	for value in effects:
		match str(_get_dict(value).get("kind", "")):
			"net_field":
				count += 2
			"fire_zone":
				count += 2
			"trap_clamp":
				count += 1
			"blast_field":
				count += 3
	return count


func _add_visual_identity(counts: Dictionary, layers: Array, family: String, layer: String) -> void:
	if family == "":
		return
	counts[family] = int(counts.get(family, 0)) + 1
	var layer_key := "%s:%s" % [family, layer]
	if not layers.has(layer_key):
		layers.append(layer_key)


func _projectile_visual_family(projectile: Dictionary) -> String:
	var weapon_id: String = str(projectile.get("weapon_id", ""))
	if bool(projectile.get("slingshot", false)):
		return "slingshot"
	var kind: String = str(projectile.get("kind", "bullet"))
	match kind:
		"rocket":
			return "bazooka"
		"net":
			return "net_gun"
		"support":
			return "fire_support"
		"trap":
			return "bowling_trap"
		"drone":
			return "suicide_drone"
	match weapon_id:
		"bazooka":
			return "bazooka"
		"net_gun":
			return "net_gun"
		"fire_support":
			return "fire_support"
		"bowling_trap":
			return "bowling_trap"
		"suicide_drone":
			return "suicide_drone"
		"commando_pistol":
			return "commando_pistol"
		"ak47":
			return "ak47"
		"pistol":
			return "pistol"
	return weapon_id


func _projectile_visual_layer(projectile: Dictionary, family: String) -> String:
	match family:
		"slingshot":
			return "charged_pellet"
		"pistol":
			return "base_bullet"
		"commando_pistol":
			return "aimed_bullet"
		"ak47":
			return "rapid_bullet"
		"bazooka":
			return "accelerating_rocket_smoke"
		"net_gun":
			return "harpoon_rope"
		"fire_support":
			return "imagegen_bomb_projectile"
		"bowling_trap":
			return "captured_ball_or_clamp"
		"suicide_drone":
			return "manual_drone_rotor"
	return str(projectile.get("kind", "projectile"))


func _draw_muzzle_flashes(canvas: CanvasItem, flashes: Array, shake_offset: Vector2) -> void:
	for value in flashes:
		var flash: Dictionary = _get_dict(value)
		var pos: Vector2 = Stage1ContextReader.as_vector2(flash.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var direction: Vector2 = Stage1ContextReader.as_vector2(flash.get("direction", Vector2.UP), Vector2.UP)
		var ratio: float = _timer_ratio(flash)
		var radius: float = float(flash.get("radius", 12.0)) * (0.72 + 0.40 * ratio)
		var color: Color = Stage1ContextReader.as_color(flash.get("color", Color(1.0, 0.75, 0.25)), Color(1.0, 0.75, 0.25))
		canvas.draw_circle(pos, radius, _with_alpha(color, 0.24 * ratio))
		canvas.draw_circle(pos, radius * 0.44, _with_alpha(Color(1.0, 0.96, 0.64), 0.70 * ratio))
		var side: Vector2 = direction.rotated(PI * 0.5)
		canvas.draw_line(pos - side * radius * 0.46, pos + direction * radius * 1.35, _with_alpha(color, 0.85 * ratio), 2.0, true)
		canvas.draw_line(pos + side * radius * 0.46, pos + direction * radius * 1.35, _with_alpha(Color(1.0, 0.95, 0.62), 0.70 * ratio), 2.0, true)


func _draw_projectiles(canvas: CanvasItem, projectiles: Array, shake_offset: Vector2) -> void:
	for value in projectiles:
		var projectile: Dictionary = _get_dict(value)
		var kind: String = str(projectile.get("kind", "bullet"))
		match kind:
			"rocket":
				_draw_rocket(canvas, projectile, shake_offset)
			"net":
				_draw_net(canvas, projectile, shake_offset)
			"support":
				_draw_support_shell(canvas, projectile, shake_offset)
			"trap":
				_draw_trap_ball(canvas, projectile, shake_offset)
			"drone":
				_draw_drone(canvas, projectile, shake_offset)
			_:
				_draw_bullet(canvas, projectile, shake_offset)


func _draw_shell_casings(canvas: CanvasItem, casings: Array, shake_offset: Vector2) -> void:
	for value in casings:
		var shell: Dictionary = _get_dict(value)
		var lifetime: float = float(shell.get("lifetime_frames", 0.0))
		if lifetime < 30.0 and int(lifetime) % 6 < 3:
			continue
		var pos: Vector2 = Stage1ContextReader.as_vector2(shell.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var velocity: Vector2 = Stage1ContextReader.as_vector2(shell.get("velocity", Vector2.ZERO), Vector2.ZERO)
		var rotation: float = deg_to_rad(float(shell.get("rotation", 0.0)))
		var alpha: float = clamp(lifetime / 60.0, 0.0, 1.0)
		var shell_length: float = float(shell.get("length", 8.0))
		var shell_width: float = float(shell.get("width", 3.0))
		var dir := Vector2(cos(rotation), sin(rotation))
		var normal := Vector2(-dir.y, dir.x)
		var start: Vector2 = pos - dir * shell_length * 0.5
		var end: Vector2 = pos + dir * shell_length * 0.5
		var bounce_count: int = int(shell.get("bounce_count", 0))
		var airborne: bool = bounce_count < 3 and abs(velocity.y) > 0.5
		var brass_dark := Color(0.63, 0.46, 0.18, 0.78 * alpha)
		var brass_base := Color(0.78, 0.61, 0.30, 0.92 * alpha)
		var brass_light := Color(0.98, 0.82, 0.48, 0.86 * alpha)
		if airborne:
			brass_base = Color(0.90, 0.70, 0.36, 0.96 * alpha)
			brass_light = Color(1.0, 0.88, 0.56, 0.92 * alpha)
		canvas.draw_line(start, end, brass_dark, shell_width + 1.0, true)
		canvas.draw_line(start, end, brass_base, shell_width, true)
		canvas.draw_circle(start - dir, 2.0, Color(0.70, 0.54, 0.23, 0.86 * alpha))
		canvas.draw_circle(start - dir, 1.0, Color(0.92, 0.72, 0.34, 0.90 * alpha))
		canvas.draw_line(start + normal, end + normal, brass_light, 1.0, true)


func _draw_impact_flashes(canvas: CanvasItem, flashes: Array, shake_offset: Vector2) -> void:
	for value in flashes:
		var flash: Dictionary = _get_dict(value)
		var pos: Vector2 = Stage1ContextReader.as_vector2(flash.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var kind: String = str(flash.get("kind", "bullet"))
		var ratio: float = _timer_ratio(flash)
		var radius: float = float(flash.get("radius", 18.0)) * (1.0 - ratio * 0.18)
		var color: Color = Stage1ContextReader.as_color(flash.get("color", Color.WHITE), Color.WHITE)
		var secondary: Color = Stage1ContextReader.as_color(flash.get("secondary", Color(1.0, 0.5, 0.2)), Color(1.0, 0.5, 0.2))
		if kind == "grenade_explosion":
			GrenadeExplosionDrawer.draw_zone(canvas, flash, shake_offset)
			continue
		if kind == "support_marker":
			_draw_target_marker(canvas, pos, radius, ratio, color, secondary)
			continue
		canvas.draw_circle(pos, radius, _with_alpha(color, 0.15 * ratio))
		canvas.draw_circle(pos, max(2.0, radius * 0.18), _with_alpha(Color(1.0, 0.96, 0.68), 0.72 * ratio))
		for i in range(8):
			var angle: float = TAU * float(i) / 8.0
			var dir := Vector2(cos(angle), sin(angle))
			canvas.draw_line(pos + dir * radius * 0.18, pos + dir * radius, _with_alpha(secondary, 0.62 * ratio), 2.0, true)
		if kind == "net":
			_draw_net_web(canvas, pos, radius, ratio, color)


func _draw_pistol_feedbacks(canvas: CanvasItem, feedbacks: Array, shake_offset: Vector2) -> void:
	for value in feedbacks:
		var feedback: Dictionary = _get_dict(value)
		var kind: String = str(feedback.get("kind", ""))
		if kind != "headshot" and kind != "legshot":
			continue
		var ratio: float = _timer_ratio(feedback)
		if ratio <= 0.0:
			continue
		var progress: float = 1.0 - ratio
		var alpha: float = _pistol_feedback_alpha(progress)
		var scale: float = _pistol_feedback_scale(progress)
		var text_pos: Vector2 = Stage1ContextReader.as_vector2(feedback.get("text_pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var text: String = str(feedback.get("text", "헤드샷!" if kind == "headshot" else "레그샷!"))
		text = LanguageSettings.translate_text(text)
		var accent: Color = Color(1.0, 0.24, 0.18) if kind == "headshot" else Color(0.35, 1.0, 0.38)
		var rim: Color = Color(1.0, 0.82, 0.12) if kind == "headshot" else Color(0.72, 0.52, 1.0)
		if kind == "legshot":
			var wave_pos: Vector2 = Stage1ContextReader.as_vector2(feedback.get("wave_pos", text_pos), text_pos) + shake_offset
			_draw_pistol_legshot_wave(canvas, wave_pos, ratio)
		_draw_pistol_feedback_burst(canvas, text_pos, progress, alpha, rim)
		_draw_pistol_feedback_text(canvas, text_pos, text, scale, alpha, accent, rim)


func _draw_pistol_feedback_text(canvas: CanvasItem, center: Vector2, text: String, scale: float, alpha: float, accent: Color, rim: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_width: float = 150.0 * scale
	var font_size: int = int(round(20.0 * scale))
	var baseline: Vector2 = Vector2(center.x - text_width * 0.5, center.y + 8.0 * scale)
	canvas.draw_string(font, baseline + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(0.03, 0.02, 0.02, 0.78 * alpha))
	canvas.draw_string(font, baseline + Vector2(-1.0, -1.0), text, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, _with_alpha(rim, 0.38 * alpha))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(1.0, 1.0, 1.0, alpha))
	canvas.draw_string(font, baseline + Vector2(0.0, -1.0), text, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, _with_alpha(accent, 0.28 * alpha))


func _draw_pistol_feedback_burst(canvas: CanvasItem, center: Vector2, progress: float, alpha: float, color: Color) -> void:
	var pulse_radius: float = 22.0 + sin(progress * PI) * 10.0
	_draw_ellipse(canvas, center, pulse_radius * 1.25, pulse_radius * 0.58, _with_alpha(color, 0.10 * alpha))
	if progress >= 0.20:
		return
	var line_alpha: float = alpha * (1.0 - progress / 0.20)
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var length: float = 26.0 + 55.0 * progress
		canvas.draw_line(center + dir * 12.0, center + dir * length, _with_alpha(color, 0.72 * line_alpha), 2.0, true)


func _draw_pistol_legshot_wave(canvas: CanvasItem, center: Vector2, ratio: float) -> void:
	var intensity: float = 0.5 + 0.5 * clamp(ratio, 0.0, 1.0)
	var color: Color = Color(0.64, 0.42, 1.0)
	_draw_ellipse(canvas, center + Vector2(0.0, -2.0), 60.0, 22.0, _with_alpha(color, 0.08 * intensity))
	for i in range(3):
		var t: float = float(i) / 3.0
		var rx: float = 34.0 + t * 23.0 + sin((1.0 - ratio) * TAU + t * PI) * 3.0
		var ry: float = 10.0 + t * 6.0
		_draw_ellipse_outline(canvas, center + Vector2(0.0, -2.0 - t * 8.0), rx, ry, _with_alpha(color, (0.28 - t * 0.06) * intensity), 1.4)


func _pistol_feedback_scale(progress: float) -> float:
	if progress < 0.10:
		return 0.50 + progress * 15.0
	if progress < 0.30:
		return 2.0 - ((progress - 0.10) * 5.0)
	if progress < 0.70:
		return 1.0
	return max(0.0, 1.0 - ((progress - 0.70) / 0.30))


func _pistol_feedback_alpha(progress: float) -> float:
	if progress < 0.70:
		return 1.0
	return clamp((1.0 - progress) / 0.30, 0.0, 1.0)


func _draw_lingering_effects(canvas: CanvasItem, effects: Array, shake_offset: Vector2) -> void:
	for value in effects:
		var effect: Dictionary = _get_dict(value)
		var kind: String = str(effect.get("kind", ""))
		match kind:
			"net_field":
				_draw_net_field(canvas, effect, shake_offset)
			"fire_zone":
				_draw_fire_zone(canvas, effect, shake_offset)
			"trap_clamp":
				_draw_trap_clamp(canvas, effect, shake_offset)
			"blast_field":
				_draw_blast_field(canvas, effect, shake_offset)


func _draw_support_calls(canvas: CanvasItem, calls: Array, shake_offset: Vector2) -> void:
	for value in calls:
		@warning_ignore("shadowed_variable_base_class")
		var call: Dictionary = _get_dict(value)
		_draw_support_call_marker(canvas, call, shake_offset)
		if bool(call.get("aircraft_active", false)):
			_draw_support_aircraft(canvas, call, shake_offset)


func _draw_bowling_traps(canvas: CanvasItem, traps: Array, shake_offset: Vector2) -> void:
	for value in traps:
		var trap: Dictionary = _get_dict(value)
		_draw_bowling_trap(canvas, trap, shake_offset)


func should_draw_projectile_trail(projectile: Dictionary) -> bool:
	if bool(projectile.get("slingshot", false)):
		return false
	var weapon_id: String = str(projectile.get("weapon_id", ""))
	return not (weapon_id in ["pistol", "commando_pistol", "ak47"])


func _draw_bullet(canvas: CanvasItem, projectile: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = Stage1ContextReader.as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var prev_pos: Vector2 = Stage1ContextReader.as_vector2(projectile.get("prev_pos", pos), pos) + shake_offset
	var color: Color = Stage1ContextReader.as_color(projectile.get("color", Color.WHITE), Color.WHITE)
	var secondary: Color = Stage1ContextReader.as_color(projectile.get("secondary", Color(1.0, 0.55, 0.24)), Color(1.0, 0.55, 0.24))
	var radius: float = float(projectile.get("radius", 4.0))
	if bool(projectile.get("slingshot", false)):
		var charge_level: int = clampi(int(projectile.get("charge_level", 1)), 1, 3)
		_draw_slingshot_stone(canvas, projectile, pos, radius, color)
		if charge_level >= 3:
			canvas.draw_circle(pos, radius * 2.1, Color(1.0, 0.76, 0.20, 0.14))
		return
	if should_draw_projectile_trail(projectile):
		canvas.draw_line(prev_pos, pos, _with_alpha(secondary, 0.56), max(2.0, radius * 0.55), true)
	canvas.draw_circle(pos, radius, _with_alpha(color, 0.96))
	canvas.draw_circle(pos, radius * 0.45, Color(1.0, 0.98, 0.78, 0.96))


func _draw_slingshot_stone(canvas: CanvasItem, projectile: Dictionary, pos: Vector2, radius: float, fallback_color: Color) -> void:
	var charge_level: int = clampi(int(projectile.get("charge_level", 1)), 1, 3)
	var texture: Texture2D = _get_slingshot_stone_texture()
	if texture == null:
		var fallback_radius: float = _get_slingshot_stone_draw_size(radius, charge_level).x * 0.5
		canvas.draw_circle(pos, fallback_radius, _with_alpha(fallback_color, 0.98))
		canvas.draw_circle(pos + Vector2(-fallback_radius * 0.22, -fallback_radius * 0.22), max(1.0, fallback_radius * 0.42), Color(1.0, 1.0, 0.94, 0.96))
		return
	var draw_size: Vector2 = _get_slingshot_stone_draw_size(radius, charge_level)
	var source_rect: Rect2 = _get_slingshot_stone_source_rect(texture, projectile, charge_level)
	canvas.draw_texture_rect_region(
		texture,
		Rect2(pos - draw_size * 0.5, draw_size),
		source_rect,
		Color(1.0, 1.0, 1.0, 0.98),
		false,
		true
	)


func _get_slingshot_stone_draw_size(radius: float, charge_level: int) -> Vector2:
	var level: int = clampi(charge_level, 1, 3)
	var diameter: float = max(1.0, radius * (3.05 + 0.38 * float(level - 1)))
	diameter = max(diameter, float(SLINGSHOT_STONE_MIN_DRAW_DIAMETERS.get(level, 22.0)))
	return Vector2(diameter, diameter)


func _get_slingshot_stone_source_rect(texture: Texture2D, projectile: Dictionary, charge_level: int) -> Rect2:
	var variant: int = clampi(int(projectile.get("slingshot_stone_variant", _get_slingshot_stone_variant(projectile))), 0, SLINGSHOT_STONE_VARIANTS_PER_LEVEL - 1)
	var frame_index: int = int(projectile.get("slingshot_stone_frame", (charge_level - 1) * SLINGSHOT_STONE_VARIANTS_PER_LEVEL + variant))
	frame_index = clampi(frame_index, 0, SLINGSHOT_STONE_SHEET_COLS * SLINGSHOT_STONE_SHEET_ROWS - 1)
	var col: int = frame_index % SLINGSHOT_STONE_SHEET_COLS
	var row: int = int(floor(float(frame_index) / float(SLINGSHOT_STONE_SHEET_COLS)))
	var cell_size := Vector2(
		float(texture.get_width()) / float(SLINGSHOT_STONE_SHEET_COLS),
		float(texture.get_height()) / float(SLINGSHOT_STONE_SHEET_ROWS)
	)
	return Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)


func _get_slingshot_stone_variant(projectile: Dictionary) -> int:
	if projectile.has("id"):
		return abs(int(projectile.get("id", 1)) - 1) % SLINGSHOT_STONE_VARIANTS_PER_LEVEL
	var pos: Vector2 = Stage1ContextReader.as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	return abs(int(round(pos.x * 13.0 + pos.y * 7.0))) % SLINGSHOT_STONE_VARIANTS_PER_LEVEL


static func _get_slingshot_stone_texture() -> Texture2D:
	if slingshot_stone_texture != null:
		return slingshot_stone_texture
	slingshot_stone_texture = ProjectResourceLoader.load_texture(
		SLINGSHOT_STONE_SHEET_PATH,
		"Missing Commando slingshot stone sheet at %s",
		"Failed to load Commando slingshot stone sheet at %s"
	)
	return slingshot_stone_texture


static func _get_bowling_trap_installed_texture() -> Texture2D:
	if bowling_trap_installed_texture != null:
		return bowling_trap_installed_texture
	bowling_trap_installed_texture = ProjectResourceLoader.load_texture(
		BOWLING_TRAP_INSTALLED_TEXTURE_PATH,
		"Missing Commando bowling trap installed texture at %s",
		"Failed to load Commando bowling trap installed texture at %s"
	)
	return bowling_trap_installed_texture


static func _get_bowling_trap_capture_sheet_texture() -> Texture2D:
	if bowling_trap_capture_sheet_texture != null:
		return bowling_trap_capture_sheet_texture
	bowling_trap_capture_sheet_texture = ProjectResourceLoader.load_texture(
		BOWLING_TRAP_CAPTURE_SHEET_PATH,
		"Missing Commando bowling trap capture sheet at %s",
		"Failed to load Commando bowling trap capture sheet at %s"
	)
	return bowling_trap_capture_sheet_texture


static func _get_bowling_trap_launch_sheet_texture() -> Texture2D:
	if bowling_trap_launch_sheet_texture != null:
		return bowling_trap_launch_sheet_texture
	bowling_trap_launch_sheet_texture = ProjectResourceLoader.load_texture(
		BOWLING_TRAP_LAUNCH_SHEET_PATH,
		"Missing Commando bowling trap launch sheet at %s",
		"Failed to load Commando bowling trap launch sheet at %s"
	)
	return bowling_trap_launch_sheet_texture


static func _get_support_aircraft_texture() -> Texture2D:
	if support_aircraft_texture != null:
		return support_aircraft_texture
	support_aircraft_texture = ProjectResourceLoader.load_texture(
		SUPPORT_AIRCRAFT_TEXTURE_PATH,
		"Missing Commando fire-support stealth aircraft texture at %s",
		"Failed to load Commando fire-support stealth aircraft texture at %s"
	)
	return support_aircraft_texture


static func _get_support_bomb_texture() -> Texture2D:
	if support_bomb_texture != null:
		return support_bomb_texture
	support_bomb_texture = ProjectResourceLoader.load_texture(
		SUPPORT_BOMB_TEXTURE_PATH,
		"Missing Commando fire-support bomb projectile texture at %s",
		"Failed to load Commando fire-support bomb projectile texture at %s"
	)
	return support_bomb_texture


func _draw_rocket(canvas: CanvasItem, projectile: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = Stage1ContextReader.as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var velocity: Vector2 = Stage1ContextReader.as_vector2(projectile.get("velocity", Vector2.UP), Vector2.UP)
	var dir: Vector2 = velocity.normalized() if velocity.length() > 0.001 else Vector2.UP
	var side: Vector2 = dir.rotated(PI * 0.5)
	var color: Color = Stage1ContextReader.as_color(projectile.get("color", Color(1.0, 0.46, 0.18)), Color(1.0, 0.46, 0.18))
	var secondary: Color = Stage1ContextReader.as_color(projectile.get("secondary", Color(1.0, 0.88, 0.38)), Color(1.0, 0.88, 0.38))
	var radius: float = float(projectile.get("radius", 9.0))
	var smoke_trail: Array = _get_array(projectile.get("smoke_trail", []))
	for index in range(smoke_trail.size()):
		var smoke_pos: Vector2 = Stage1ContextReader.as_vector2(smoke_trail[index], pos) + shake_offset
		var ratio: float = float(index + 1) / float(max(1, smoke_trail.size()))
		var smoke_radius: float = radius * lerp(0.42, 0.95, ratio)
		canvas.draw_circle(smoke_pos, smoke_radius, Color(0.36, 0.35, 0.31, 0.08 + ratio * 0.16))
	canvas.draw_line(pos - dir * radius * 3.6, pos - dir * radius * 1.1, _with_alpha(secondary, 0.28), radius * 1.5, true)
	canvas.draw_line(pos - dir * radius * 2.5, pos - dir * radius * 0.8, _with_alpha(Color(1.0, 0.25, 0.08), 0.52), radius * 0.85, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + dir * radius * 1.25,
		pos - dir * radius * 1.05 + side * radius * 0.72,
		pos - dir * radius * 1.05 - side * radius * 0.72,
	]), _with_alpha(color, 0.95))
	canvas.draw_circle(pos + dir * radius * 0.20, radius * 0.42, _with_alpha(secondary, 0.86))


func _draw_net(canvas: CanvasItem, projectile: Dictionary, shake_offset: Vector2) -> void:
	# Harpoon (작살) projectile matching item_effects/net_gun.py draw_projectiles:
	# rope trail from player origin -> harpoon path, then a triangular spearhead
	# with a short rectangular shaft oriented along the velocity vector.
	var pos: Vector2 = Stage1ContextReader.as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var origin: Vector2 = Stage1ContextReader.as_vector2(projectile.get("origin", pos), pos) + shake_offset
	var velocity: Vector2 = Stage1ContextReader.as_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var rope_color := Color(0.823529, 0.705882, 0.549020, 1.0) # rgb(210,180,140)
	var rope_points: Array = _get_array(projectile.get("rope_points", []))
	var rope_path: Array[Vector2] = [origin]
	for value in rope_points:
		rope_path.append(Stage1ContextReader.as_vector2(value, pos) + shake_offset)
	if rope_path.size() <= 1:
		rope_path.append(pos)
	for index in range(rope_path.size() - 1):
		var thickness: float = max(1.0, 4.0 - floor(float(index) / 4.0))
		canvas.draw_line(rope_path[index], rope_path[index + 1], rope_color, thickness, true)
	var heading: float = velocity.angle() if velocity.length_squared() > 0.0 else -PI * 0.5
	var head_color := Color(0.784314, 0.862745, 0.901961, 1.0) # rgb(200,220,230)
	var shaft_color := Color(0.509804, 0.549020, 0.588235, 1.0) # rgb(130,140,150)
	var tip := pos + Vector2(cos(heading), sin(heading)) * 16.0
	var left_wing := pos + Vector2(cos(heading + PI * 0.75), sin(heading + PI * 0.75)) * 8.0
	var right_wing := pos + Vector2(cos(heading - PI * 0.75), sin(heading - PI * 0.75)) * 8.0
	canvas.draw_colored_polygon(PackedVector2Array([tip, left_wing, right_wing]), head_color)
	var shaft_center: Vector2 = pos - Vector2(cos(heading), sin(heading)) * 6.0
	var shaft_dir := Vector2(cos(heading), sin(heading))
	var shaft_perp := Vector2(-shaft_dir.y, shaft_dir.x)
	var shaft_half_len: float = 9.0
	var shaft_half_width: float = 3.0
	var shaft_corners := PackedVector2Array([
		shaft_center + shaft_dir * shaft_half_len + shaft_perp * shaft_half_width,
		shaft_center + shaft_dir * shaft_half_len - shaft_perp * shaft_half_width,
		shaft_center - shaft_dir * shaft_half_len - shaft_perp * shaft_half_width,
		shaft_center - shaft_dir * shaft_half_len + shaft_perp * shaft_half_width,
	])
	canvas.draw_colored_polygon(shaft_corners, shaft_color)


func _draw_support_shell(canvas: CanvasItem, projectile: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = Stage1ContextReader.as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var prev_pos: Vector2 = Stage1ContextReader.as_vector2(projectile.get("prev_pos", pos), pos) + shake_offset
	var color: Color = Stage1ContextReader.as_color(projectile.get("color", Color(1.0, 0.34, 0.16)), Color(1.0, 0.34, 0.16))
	var secondary: Color = Stage1ContextReader.as_color(projectile.get("secondary", Color(1.0, 0.82, 0.25)), Color(1.0, 0.82, 0.25))
	var radius: float = float(projectile.get("radius", 7.0))
	var velocity: Vector2 = Stage1ContextReader.as_vector2(projectile.get("velocity", Vector2.DOWN), Vector2.DOWN)
	var dir: Vector2 = velocity.normalized() if velocity.length_squared() > 0.0001 else Vector2.DOWN
	var side: Vector2 = dir.rotated(PI * 0.5)
	var shell_length: float = max(19.0, radius * 3.2)
	var shell_width: float = max(6.0, radius * 0.95)
	var nose: Vector2 = pos + dir * shell_length * 0.54
	var tail: Vector2 = pos - dir * shell_length * 0.48
	var max_life_frames: float = max(1.0, float(projectile.get("max_life_frames", projectile.get("life_frames", 1.0))))
	var life_frames: float = clamp(float(projectile.get("life_frames", max_life_frames)), 0.0, max_life_frames)
	var age_frames: float = max_life_frames - life_frames
	var is_wall_missile: bool = str(projectile.get("support_impact_mode", "")) == "opponent_wall"
	canvas.draw_line(prev_pos, pos, _with_alpha(secondary, 0.46), max(2.0, radius * 0.55), true)
	_draw_support_missile_smoke_tail(canvas, tail, dir, side, shell_length, shell_width, secondary, age_frames, is_wall_missile)
	if is_wall_missile and age_frames <= SUPPORT_MISSILE_LAUNCH_FLASH_FRAMES:
		_draw_support_missile_launch_flash(canvas, tail, dir, side, shell_length, shell_width, color, secondary, age_frames)
	if _draw_support_bomb_texture(canvas, pos, dir, side, radius):
		return
	canvas.draw_line(tail - dir * shell_length * 0.72, tail, _with_alpha(Color(1.0, 0.36, 0.08), 0.54), shell_width * 0.72, true)
	canvas.draw_line(tail - dir * shell_length * 0.50, tail, _with_alpha(secondary, 0.74), shell_width * 0.38, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		nose,
		pos + side * shell_width * 0.55,
		tail + side * shell_width * 0.66,
		tail - side * shell_width * 0.66,
		pos - side * shell_width * 0.55,
	]), _with_alpha(color, 0.96))
	canvas.draw_line(nose - dir * shell_length * 0.22, tail + dir * shell_length * 0.12, _with_alpha(Color(1.0, 0.92, 0.62), 0.78), max(1.0, shell_width * 0.24), true)
	canvas.draw_line(tail + side * shell_width * 0.72, tail + side * shell_width * 1.35 - dir * shell_length * 0.16, _with_alpha(secondary, 0.82), 1.6, true)
	canvas.draw_line(tail - side * shell_width * 0.72, tail - side * shell_width * 1.35 - dir * shell_length * 0.16, _with_alpha(secondary, 0.82), 1.6, true)


func _draw_support_bomb_texture(canvas: CanvasItem, pos: Vector2, dir: Vector2, side: Vector2, radius: float) -> bool:
	var texture: Texture2D = _get_support_bomb_texture()
	if texture == null:
		return false
	var draw_length: float = max(58.0, radius * SUPPORT_BOMB_DRAW_LENGTH_SCALE)
	var draw_width: float = max(38.0, radius * SUPPORT_BOMB_DRAW_WIDTH_SCALE)
	var half_length := draw_length * 0.5
	var half_width := draw_width * 0.5
	var points := PackedVector2Array([
		pos - dir * half_length - side * half_width,
		pos + dir * half_length - side * half_width,
		pos + dir * half_length + side * half_width,
		pos - dir * half_length + side * half_width,
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	canvas.draw_colored_polygon(points, Color(1.0, 1.0, 1.0, 0.98), uvs, texture)
	return true


func _draw_support_missile_smoke_tail(
	canvas: CanvasItem,
	tail: Vector2,
	dir: Vector2,
	side: Vector2,
	shell_length: float,
	shell_width: float,
	secondary: Color,
	age_frames: float,
	is_wall_missile: bool
) -> void:
	var puff_count: int = SUPPORT_MISSILE_SMOKE_PUFFS if is_wall_missile else 3
	var alpha_scale: float = 1.0 if is_wall_missile else 0.62
	for i in range(puff_count):
		var ratio: float = float(i + 1) / float(puff_count)
		var drift: float = sin(age_frames * 0.23 + float(i) * 1.71) * shell_width * (0.18 + ratio * 0.18)
		var puff_pos: Vector2 = tail - dir * shell_length * (0.62 + ratio * 1.18) + side * drift
		var puff_radius: float = shell_width * (0.42 + ratio * 0.54)
		var alpha: float = alpha_scale * (0.22 - ratio * 0.11)
		canvas.draw_circle(puff_pos, puff_radius, _with_alpha(Color(0.58, 0.62, 0.68), alpha))
		canvas.draw_circle(puff_pos - dir * puff_radius * 0.45, puff_radius * 0.48, _with_alpha(secondary, alpha * 0.32))


func _draw_support_missile_launch_flash(
	canvas: CanvasItem,
	tail: Vector2,
	dir: Vector2,
	side: Vector2,
	shell_length: float,
	shell_width: float,
	color: Color,
	secondary: Color,
	age_frames: float
) -> void:
	var ratio: float = clamp(1.0 - age_frames / SUPPORT_MISSILE_LAUNCH_FLASH_FRAMES, 0.0, 1.0)
	var flash_center: Vector2 = tail - dir * shell_length * 0.25
	canvas.draw_circle(flash_center, shell_width * (2.2 + ratio * 1.3), _with_alpha(color, 0.20 * ratio))
	canvas.draw_circle(flash_center, shell_width * (0.85 + ratio * 0.75), _with_alpha(Color(1.0, 0.96, 0.66), 0.68 * ratio))
	for i in range(5):
		var lane: float = float(i) - 2.0
		var start: Vector2 = flash_center + side * lane * shell_width * 0.43
		var end: Vector2 = start - dir * shell_length * (0.80 + abs(lane) * 0.18 + ratio * 0.35)
		var width: float = max(1.2, shell_width * (0.14 + ratio * 0.05))
		canvas.draw_line(start, end, _with_alpha(secondary, (0.28 - abs(lane) * 0.03) * ratio), width, true)


func _draw_trap_ball(canvas: CanvasItem, projectile: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = Stage1ContextReader.as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var color: Color = Stage1ContextReader.as_color(projectile.get("color", Color(0.95, 0.18, 0.24)), Color(0.95, 0.18, 0.24))
	var secondary: Color = Stage1ContextReader.as_color(projectile.get("secondary", Color(0.22, 0.10, 0.12)), Color(0.22, 0.10, 0.12))
	var radius: float = float(projectile.get("radius", 12.0))
	canvas.draw_circle(pos, radius, _with_alpha(color, 0.92))
	canvas.draw_circle(pos + Vector2(-radius * 0.28, -radius * 0.22), radius * 0.16, _with_alpha(secondary, 0.92))
	canvas.draw_circle(pos + Vector2(radius * 0.18, -radius * 0.34), radius * 0.12, _with_alpha(secondary, 0.92))
	canvas.draw_line(pos + Vector2(-radius * 0.78, radius * 0.38), pos + Vector2(radius * 0.78, -radius * 0.28), _with_alpha(Color(1.0, 0.70, 0.70), 0.50), 2.0, true)


func _draw_bowling_trap(canvas: CanvasItem, trap: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = Stage1ContextReader.as_vector2(trap.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var width: float = float(trap.get("width", 60.0))
	var height: float = float(trap.get("height", 20.0))
	var state: String = str(trap.get("state", "waiting"))
	var color: Color = Stage1ContextReader.as_color(trap.get("color", Color(0.95, 0.18, 0.24)), Color(0.95, 0.18, 0.24))
	var secondary: Color = Stage1ContextReader.as_color(trap.get("secondary", Color(0.22, 0.10, 0.12)), Color(0.22, 0.10, 0.12))
	var install_progress: float = clamp(float(trap.get("install_progress", 1.0)), 0.0, 1.0)
	var capture_progress: float = clamp(float(trap.get("capture_progress", 0.0)), 0.0, 1.0)
	var body_y_offset: float = (1.0 - install_progress) * 12.0 if state == "installing" else 0.0
	var body_pos: Vector2 = pos + Vector2(0.0, body_y_offset)
	if _draw_bowling_trap_runtime_sprite(canvas, body_pos, width, height, state, install_progress, capture_progress):
		if state == "installing":
			_draw_bowling_trap_install_gauge(canvas, pos, width, height, install_progress)
		return
	var rect := Rect2(body_pos - Vector2(width, height) * 0.5, Vector2(width, height))
	var alpha: float = 0.42 + 0.42 * install_progress
	canvas.draw_rect(rect.grow(4.0), _with_alpha(secondary, 0.22 * alpha), true)
	canvas.draw_rect(rect, _with_alpha(secondary, 0.72 * alpha), true)
	canvas.draw_rect(rect, _with_alpha(color, 0.82 * alpha), false, 2.0)
	canvas.draw_line(rect.position + Vector2(6.0, height * 0.5), rect.position + Vector2(width - 6.0, height * 0.5), _with_alpha(Color(1.0, 0.72, 0.72), 0.38 * alpha), 1.4, true)

	if state == "installing":
		_draw_bowling_trap_install_gauge(canvas, pos, width, height, install_progress)

	var claw_angle: float = float(trap.get("claw_angle", 0.0))
	var open_amount: float = clamp(0.28 + claw_angle * 0.34, -0.10, 0.72)
	if state == "capturing":
		var captured_pos: Vector2 = Stage1ContextReader.as_vector2(trap.get("captured_ball_pos", pos - Vector2(0.0, 15.0)), pos - Vector2(0.0, 15.0)) + shake_offset
		canvas.draw_circle(captured_pos, 15.5, _with_alpha(color, 0.12 + 0.18 * sin(capture_progress * TAU)))
		canvas.draw_circle(captured_pos, 10.5, _with_alpha(Color(1.0, 0.92, 0.72), 0.52))
		canvas.draw_circle(captured_pos + Vector2(-3.0, -3.0), 3.2, _with_alpha(secondary, 0.68))
	for side_sign in [-1.0, 1.0]:
		var hinge := body_pos + Vector2(side_sign * width * 0.30, -height * 0.22)
		var tip := body_pos + Vector2(side_sign * width * open_amount, -height * 1.08)
		canvas.draw_line(hinge, tip, _with_alpha(color, 0.84 * alpha), 3.0, true)
		canvas.draw_circle(hinge, 4.0, _with_alpha(secondary, 0.86 * alpha))


func _draw_bowling_trap_runtime_sprite(canvas: CanvasItem, body_pos: Vector2, width: float, height: float, state: String, install_progress: float, capture_progress: float) -> bool:
	var texture: Texture2D = null
	var frame_index := 0
	if state == "capturing":
		texture = _get_bowling_trap_capture_sheet_texture()
		frame_index = _get_bowling_trap_sheet_frame(capture_progress)
	else:
		texture = _get_bowling_trap_installed_texture()
	if texture == null:
		return false
	var draw_side: float = max(width * 1.45, height * 3.65)
	if state == "capturing":
		draw_side *= 1.08
	var draw_center := body_pos + Vector2(0.0, -draw_side * 0.16)
	var source_rect := Rect2(Vector2.ZERO, Vector2(texture.get_width(), texture.get_height()))
	if state == "capturing":
		source_rect = _get_bowling_trap_sheet_source_rect(texture, frame_index)
	var alpha: float = 1.0
	if state == "installing":
		alpha = clamp(0.45 + 0.55 * install_progress, 0.0, 1.0)
	canvas.draw_texture_rect_region(
		texture,
		Rect2(draw_center - Vector2(draw_side, draw_side) * 0.5, Vector2(draw_side, draw_side)),
		source_rect,
		Color(1.0, 1.0, 1.0, alpha),
		false,
		true
	)
	return true


func _draw_bowling_trap_install_gauge(canvas: CanvasItem, pos: Vector2, width: float, height: float, install_progress: float) -> void:
	var gauge_width: float = width
	var gauge_rect := Rect2(pos + Vector2(-gauge_width * 0.5, -height * 1.6), Vector2(gauge_width, 5.0))
	canvas.draw_rect(gauge_rect, _with_alpha(Color(0.05, 0.06, 0.06), 0.72), true)
	canvas.draw_rect(Rect2(gauge_rect.position, Vector2(gauge_rect.size.x * install_progress, gauge_rect.size.y)), _with_alpha(Color(0.45, 1.0, 0.42), 0.86), true)
	canvas.draw_rect(gauge_rect, _with_alpha(Color(0.74, 0.84, 0.72), 0.56), false, 1.0)


func _draw_drone(canvas: CanvasItem, projectile: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = Stage1ContextReader.as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var velocity: Vector2 = Stage1ContextReader.as_vector2(projectile.get("velocity", Vector2.UP), Vector2.UP)
	var dir: Vector2 = velocity.normalized() if velocity.length() > 0.001 else Vector2.UP
	var side: Vector2 = dir.rotated(PI * 0.5)
	var color: Color = Stage1ContextReader.as_color(projectile.get("color", Color(1.0, 0.42, 0.18)), Color(1.0, 0.42, 0.18))
	var secondary: Color = Stage1ContextReader.as_color(projectile.get("secondary", Color(0.45, 0.86, 1.0)), Color(0.45, 0.86, 1.0))
	var radius: float = float(projectile.get("radius", 8.0))
	var size: Vector2 = Stage1ContextReader.as_vector2(projectile.get("size", Vector2(radius * 2.0, radius * 2.0)), Vector2(radius * 2.0, radius * 2.0))
	var body_radius: float = min(radius * 0.76, max(8.0, min(size.x, size.y) * 0.30))
	var rotor_span: float = max(radius * 1.15, max(size.x, size.y) * 0.36)
	var rotor_angle: float = deg_to_rad(float(projectile.get("rotor_angle", 0.0)))
	ImpactFlareTextureCache.draw_glow(canvas, pos, max(radius * 1.65, 34.0), secondary, 0.08)
	for offset in [side * rotor_span, -side * rotor_span]:
		_draw_drone_rotor(canvas, pos + offset, rotor_angle, secondary, radius)
	canvas.draw_line(pos - side * rotor_span, pos + side * rotor_span, _with_alpha(secondary, 0.32), 2.0, true)
	canvas.draw_line(pos - dir * rotor_span * 0.72, pos + dir * rotor_span * 0.72, _with_alpha(secondary, 0.22), 1.4, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + dir * body_radius * 1.18,
		pos + side * body_radius * 0.94,
		pos - dir * body_radius * 1.04,
		pos - side * body_radius * 0.94,
	]), _with_alpha(color, 0.94))
	canvas.draw_circle(pos, body_radius * 0.36, _with_alpha(Color(1.0, 0.95, 0.60), 0.94))
	canvas.draw_circle(pos - dir * body_radius * 0.50, body_radius * 0.18, _with_alpha(secondary, 0.72))


func _draw_drone_rotor(canvas: CanvasItem, center: Vector2, rotation: float, color: Color, radius: float) -> void:
	var rotor_radius: float = max(7.0, radius * 0.38)
	canvas.draw_circle(center, rotor_radius * 1.25, _with_alpha(color, 0.08))
	for i in range(2):
		var angle: float = rotation + float(i) * PI
		var dir := Vector2(cos(angle), sin(angle))
		canvas.draw_line(center - dir * rotor_radius, center + dir * rotor_radius, _with_alpha(color, 0.56), 1.8, true)
	canvas.draw_circle(center, rotor_radius * 0.26, _with_alpha(Color(1.0, 0.95, 0.78), 0.82))


func _draw_target_marker(canvas: CanvasItem, pos: Vector2, radius: float, ratio: float, color: Color, secondary: Color) -> void:
	canvas.draw_circle(pos, radius, _with_alpha(color, 0.08 * ratio))
	canvas.draw_line(pos + Vector2(-radius, 0.0), pos + Vector2(radius, 0.0), _with_alpha(secondary, 0.56 * ratio), 2.0, true)
	canvas.draw_line(pos + Vector2(0.0, -radius), pos + Vector2(0.0, radius), _with_alpha(secondary, 0.56 * ratio), 2.0, true)
	canvas.draw_circle(pos, radius * 0.34, _with_alpha(secondary, 0.16 * ratio))


@warning_ignore("shadowed_variable_base_class")
func _draw_support_call_marker(canvas: CanvasItem, call: Dictionary, shake_offset: Vector2) -> void:
	var origin: Vector2 = Stage1ContextReader.as_vector2(call.get("origin", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var target: Vector2 = Stage1ContextReader.as_vector2(call.get("target", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var color: Color = Stage1ContextReader.as_color(call.get("color", Color(1.0, 0.34, 0.16)), Color(1.0, 0.34, 0.16))
	var secondary: Color = Stage1ContextReader.as_color(call.get("secondary", Color(1.0, 0.82, 0.25)), Color(1.0, 0.82, 0.25))
	var call_timer: float = max(0.0, float(call.get("call_timer_frames", 0.0)))
	var delay: float = max(0.0, float(call.get("delay_frames", 0.0)))
	var pulse: float = 0.35 + 0.65 * abs(sin((call_timer + delay) * 0.12))
	if call_timer > 0.0:
		canvas.draw_circle(origin, 14.0 + pulse * 4.0, _with_alpha(secondary, 0.12))
		canvas.draw_circle(origin, 5.0, _with_alpha(secondary, 0.68))
		canvas.draw_line(origin, target, _with_alpha(color, 0.18), 1.4, true)
	if delay > 0.0:
		var radius: float = 30.0 + pulse * 8.0
		canvas.draw_line(target + Vector2(-radius, 0.0), target + Vector2(radius, 0.0), _with_alpha(secondary, 0.34), 1.5, true)
		canvas.draw_line(target + Vector2(0.0, -radius), target + Vector2(0.0, radius), _with_alpha(secondary, 0.34), 1.5, true)
		canvas.draw_circle(target, radius * 0.32, _with_alpha(color, 0.08))


@warning_ignore("shadowed_variable_base_class")
func _draw_support_aircraft(canvas: CanvasItem, call: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = Stage1ContextReader.as_vector2(call.get("aircraft_pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var velocity: Vector2 = Stage1ContextReader.as_vector2(call.get("aircraft_velocity", Vector2.RIGHT), Vector2.RIGHT)
	var dir: Vector2 = velocity.normalized() if velocity.length_squared() > 0.0001 else Vector2.RIGHT
	var side: Vector2 = dir.rotated(PI * 0.5)
	_draw_support_aircraft_motion_fx(canvas, call, pos, dir, side)
	var texture: Texture2D = _get_support_aircraft_texture()
	if texture != null:
		canvas.draw_texture_rect_region(
			texture,
			Rect2(pos - SUPPORT_AIRCRAFT_DRAW_SIZE * 0.5, SUPPORT_AIRCRAFT_DRAW_SIZE),
			SUPPORT_AIRCRAFT_SOURCE_RECT,
			Color(1.0, 1.0, 1.0, 0.96),
			false,
			true
		)
		return
	var color: Color = Color(0.08, 0.09, 0.11, 0.92)
	var edge: Color = Color(0.34, 0.36, 0.42, 0.70)
	var glow: Color = Stage1ContextReader.as_color(call.get("secondary", Color(1.0, 0.82, 0.25)), Color(1.0, 0.82, 0.25))
	var w: float = 92.0
	var h: float = 28.0
	var points := PackedVector2Array([
		pos + Vector2(w * 0.50, 0.0),
		pos + Vector2(w * 0.18, -h * 0.46),
		pos + Vector2(-w * 0.45, -h * 0.60),
		pos + Vector2(-w * 0.20, 0.0),
		pos + Vector2(-w * 0.45, h * 0.60),
		pos + Vector2(w * 0.18, h * 0.46),
	])
	canvas.draw_colored_polygon(points, color)
	for i in range(points.size()):
		canvas.draw_line(points[i], points[(i + 1) % points.size()], edge, 1.2, true)
	canvas.draw_circle(pos + Vector2(w * 0.22, 0.0), 4.0, _with_alpha(Color(0.12, 0.16, 0.22), 0.90))
	canvas.draw_line(pos + Vector2(-w * 0.46, -h * 0.25), pos + Vector2(-w * 0.68, -h * 0.25), _with_alpha(glow, 0.34), 4.0, true)
	canvas.draw_line(pos + Vector2(-w * 0.46, h * 0.25), pos + Vector2(-w * 0.68, h * 0.25), _with_alpha(glow, 0.34), 4.0, true)


func _draw_support_aircraft_motion_fx(canvas: CanvasItem, support_call: Dictionary, pos: Vector2, dir: Vector2, side: Vector2) -> void:
	var secondary: Color = Stage1ContextReader.as_color(support_call.get("secondary", Color(1.0, 0.82, 0.25)), Color(1.0, 0.82, 0.25))
	var timer: float = float(support_call.get("aircraft_spawn_timer", support_call.get("timer_frames", 0.0)))
	var wave: float = sin(timer * 0.18)
	var shadow_pos: Vector2 = pos + SUPPORT_AIRCRAFT_SHADOW_OFFSET + side * wave * 2.0
	_draw_ellipse(canvas, shadow_pos, SUPPORT_AIRCRAFT_DRAW_SIZE.x * 0.46, SUPPORT_AIRCRAFT_DRAW_SIZE.y * 0.14, Color(0.0, 0.0, 0.0, 0.16))
	_draw_ellipse(canvas, shadow_pos, SUPPORT_AIRCRAFT_DRAW_SIZE.x * 0.28, SUPPORT_AIRCRAFT_DRAW_SIZE.y * 0.08, Color(0.0, 0.0, 0.0, 0.09))
	for i in range(SUPPORT_AIRCRAFT_TRAIL_COUNT):
		var ratio: float = float(i + 1) / float(SUPPORT_AIRCRAFT_TRAIL_COUNT)
		var lane: float = float(i) - (float(SUPPORT_AIRCRAFT_TRAIL_COUNT) - 1.0) * 0.5
		var start: Vector2 = pos - dir * SUPPORT_AIRCRAFT_DRAW_SIZE.x * (0.34 + ratio * 0.16) + side * lane * 14.0
		var end: Vector2 = start - dir * SUPPORT_AIRCRAFT_DRAW_SIZE.x * (0.28 + ratio * 0.36)
		var alpha: float = (0.18 - ratio * 0.025) * (0.92 + 0.08 * wave)
		canvas.draw_line(start, end, _with_alpha(Color(0.58, 0.74, 0.92), alpha), 1.2 + ratio * 1.5, true)
		canvas.draw_line(start + side * 2.0, end + side * 2.0, _with_alpha(secondary, alpha * 0.35), 0.8 + ratio * 0.6, true)
	for i in range(2):
		var ratio: float = float(i + 1) / 2.0
		var ghost_pos: Vector2 = pos - dir * SUPPORT_AIRCRAFT_DRAW_SIZE.x * (0.20 + ratio * 0.14)
		var ghost_width: float = SUPPORT_AIRCRAFT_DRAW_SIZE.x * (0.36 + ratio * 0.05)
		var ghost_height: float = SUPPORT_AIRCRAFT_DRAW_SIZE.y * (0.14 + ratio * 0.03)
		canvas.draw_colored_polygon(PackedVector2Array([
			ghost_pos + dir * ghost_width * 0.45,
			ghost_pos + side * ghost_height,
			ghost_pos - dir * ghost_width * 0.52,
			ghost_pos - side * ghost_height,
		]), _with_alpha(Color(0.24, 0.30, 0.40), 0.10 - ratio * 0.025))


func _draw_net_field(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	# Organic mesh net matching item_effects/net_gun.py draw_nets:
	# stored polygon shape jittered by phase, scaled by remaining_ratio and
	# constrict_factor (left/right mash narrows the net), with mesh lattice + chords + spokes.
	var pos: Vector2 = Stage1ContextReader.as_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var width: float = float(effect.get("width", 280.0))
	var height: float = float(effect.get("height", 140.0))
	var phase: float = float(effect.get("phase", 0.0))
	var dissolve: bool = bool(effect.get("dissolve", false))
	var hooked: bool = bool(effect.get("hooked_player", false)) and not dissolve
	var max_timer: float = max(1.0, float(effect.get("max_timer_frames", 1.0)))
	var remaining_ratio: float = clamp(float(effect.get("timer_frames", 0.0)) / max_timer, 0.0, 1.0)
	var alpha_base: float = (200.0 if not dissolve else 150.0) * remaining_ratio + 30.0
	var alpha_unit: float = clamp(alpha_base / 255.0, 0.0, 1.0)

	var fill_color := Color(95.0 / 255.0, 140.0 / 255.0, 180.0 / 255.0, 1.0)
	var outline_color := Color(210.0 / 255.0, 240.0 / 255.0, 1.0, 1.0)
	var lattice_color := Color(175.0 / 255.0, 215.0 / 255.0, 245.0 / 255.0, 1.0)

	_draw_net_anchor_rope(canvas, effect, pos, shake_offset, remaining_ratio if not dissolve else remaining_ratio * 0.66)

	var shape_points: Array = _get_array(effect.get("shape", []))
	if shape_points.is_empty():
		# Asset-side safety: build a fallback shape from current width/height so
		# pre-existing nets without stored shape still draw something organic.
		shape_points = _fallback_net_shape(width, height)
	var constrict_x: float = float(effect.get("constrict_factor", 1.0)) if hooked else 1.0
	var shrink: float
	var jitter_amp: float
	var vertical_scale: float
	if dissolve:
		shrink = pow(remaining_ratio, 1.4)
		jitter_amp = 4.0 + (1.0 - remaining_ratio) * 8.0
		vertical_scale = 0.45 + 0.25 * remaining_ratio
	else:
		shrink = 0.9 + 0.1 * remaining_ratio
		jitter_amp = 3.0
		vertical_scale = 0.6 + 0.3 * remaining_ratio

	var jittered := PackedVector2Array()
	jittered.resize(shape_points.size())
	for i in range(shape_points.size()):
		var p: Vector2 = Stage1ContextReader.as_vector2(shape_points[i], Vector2.ZERO)
		var sine_seed: float = phase + (p.x + p.y) * 0.03
		var jitter_x: float = sin(sine_seed) * jitter_amp
		var jitter_y: float = cos(sine_seed * 0.8) * (jitter_amp * 0.5)
		var final_x: float = p.x * shrink * constrict_x + jitter_x
		var final_y: float = p.y * vertical_scale + jitter_y
		if dissolve:
			final_y += pow(1.0 - remaining_ratio, 1.2) * height * 0.6
			final_x += sin(phase * 1.7 + p.x * 0.05) * (1.0 - remaining_ratio) * 10.0
		jittered[i] = pos + Vector2(final_x, final_y)

	var fill_alpha: float = max(20.0, alpha_base * (0.4 if dissolve else 0.55)) / 255.0
	var outline_alpha: float = max(60.0 / 255.0, alpha_unit)
	canvas.draw_colored_polygon(jittered, _with_alpha(fill_color, fill_alpha))
	for index in range(jittered.size()):
		var a: Vector2 = jittered[index]
		var b: Vector2 = jittered[(index + 1) % jittered.size()]
		canvas.draw_line(a, b, _with_alpha(outline_color, outline_alpha), 2.0, true)

	_draw_net_mesh_overlay(canvas, jittered, _with_alpha(lattice_color, alpha_unit * 0.7), dissolve, remaining_ratio)


func _fallback_net_shape(width: float, height: float) -> Array:
	var points: Array = []
	var radius_x: float = width * 0.5
	var radius_y: float = height * 0.5
	var steps: int = 36
	for i in range(steps):
		var angle: float = TAU * float(i) / float(steps)
		var noise: float = sin(angle * 3.0) * 0.18 + sin(angle * 7.0) * 0.08
		var scale: float = 0.82 + noise
		points.append(Vector2(cos(angle) * radius_x * scale, sin(angle) * radius_y * scale))
	return points


func _draw_net_mesh_overlay(canvas: CanvasItem, hull_points: PackedVector2Array, color: Color, dissolve: bool, life_ratio: float) -> void:
	if hull_points.is_empty():
		return
	var center := Vector2.ZERO
	for point in hull_points:
		center += point
	center /= float(hull_points.size())
	var radius_x: float = 0.0
	var radius_y: float = 0.0
	for point in hull_points:
		radius_x = max(radius_x, abs(point.x - center.x))
		radius_y = max(radius_y, abs(point.y - center.y))
	var subdivisions: int = 10 if dissolve else 14
	for i in range(subdivisions):
		var t: float = float(i) / float(subdivisions)
		var angle: float = t * TAU
		var base: float = 0.48 + 0.2 * sin(angle * 5.0)
		var radius: float = base * (0.6 + 0.3 * life_ratio) if dissolve else base * 0.9
		var inner_x: float = center.x + cos(angle) * radius_x * radius
		var inner_y: float = center.y + sin(angle) * radius_y * radius
		canvas.draw_circle(Vector2(inner_x, inner_y), 1.0, color)
	var chord_step: int = max(3, int(hull_points.size() / float(12 if dissolve else 14)))
	for i in range(0, hull_points.size(), chord_step):
		var start: Vector2 = hull_points[i]
		var end: Vector2 = hull_points[(i + chord_step * 3) % hull_points.size()]
		canvas.draw_line(start, end, color, 1.0, true)
	var spoke_step: int = max(2, int(hull_points.size() / float(10 if dissolve else 18)))
	for i in range(0, hull_points.size(), spoke_step):
		var dest: Vector2 = hull_points[(i + spoke_step * 2) % hull_points.size()]
		var mid: Vector2 = (hull_points[i] + dest) * 0.5
		canvas.draw_line(center, mid, color, 1.0, true)


func _draw_net_anchor_rope(canvas: CanvasItem, effect: Dictionary, net_pos: Vector2, shake_offset: Vector2, ratio: float) -> void:
	var hooked: bool = bool(effect.get("hooked_player", false)) and not bool(effect.get("dissolve", false))
	var breaking: bool = bool(effect.get("rope_broken", false)) and bool(effect.get("dissolve", false))
	if not hooked and not breaking:
		return
	var origin: Vector2 = Stage1ContextReader.as_vector2(effect.get("origin", net_pos), net_pos) + shake_offset
	var end: Vector2 = net_pos
	if breaking:
		var snap_duration: float = max(1.0, float(effect.get("rope_snap_duration", 1.0)))
		var snap_timer: float = clamp(float(effect.get("rope_snap_timer", 0.0)), 0.0, snap_duration)
		var progress: float = snap_timer / snap_duration
		if progress <= 0.0:
			return
		end = origin.lerp(net_pos, progress)
	var rope_color := Color(0.82, 0.72, 0.52, 0.48 * ratio) if hooked else Color(0.92, 0.44, 0.44, 0.42 * ratio)
	var highlight := Color(1.0, 0.93, 0.72, 0.44 * ratio) if hooked else Color(1.0, 0.72, 0.72, 0.36 * ratio)
	var control1 := origin.lerp(end, 0.34) + Vector2(0.0, 20.0)
	var control2 := origin.lerp(end, 0.66) + Vector2(0.0, 28.0)
	var path := [origin, control1, control2, end]
	for index in range(path.size() - 1):
		canvas.draw_line(path[index], path[index + 1], rope_color, 4.0, true)
		canvas.draw_line(path[index], path[index + 1], highlight, 1.2, true)


func _draw_fire_zone(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = Stage1ContextReader.as_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var width: float = float(effect.get("width", 150.0))
	var height: float = float(effect.get("height", 60.0))
	var ratio: float = _timer_ratio(effect)
	var color: Color = Stage1ContextReader.as_color(effect.get("color", Color(1.0, 0.28, 0.08)), Color(1.0, 0.28, 0.08))
	var secondary: Color = Stage1ContextReader.as_color(effect.get("secondary", Color(1.0, 0.78, 0.18)), Color(1.0, 0.78, 0.18))
	_draw_ellipse(canvas, pos, width * 0.5, height * 0.5, _with_alpha(color, 0.10 * ratio))
	_draw_ellipse_outline(canvas, pos, width * 0.5, height * 0.5, _with_alpha(secondary, 0.28 * ratio), 2.0)
	var flames: Array = _get_array(effect.get("flames", []))
	for value in flames:
		var flame: Dictionary = _get_dict(value)
		var offset: Vector2 = Stage1ContextReader.as_vector2(flame.get("offset", Vector2.ZERO), Vector2.ZERO)
		var lifetime_ratio: float = clamp(float(flame.get("lifetime", 1.0)) / max(1.0, float(flame.get("max_lifetime", 40.0))), 0.0, 1.0)
		var size: float = float(flame.get("size", 10.0)) * (0.66 + 0.42 * lifetime_ratio)
		canvas.draw_circle(pos + offset, size, _with_alpha(color, 0.18 * ratio * lifetime_ratio))
		canvas.draw_circle(pos + offset + Vector2(0.0, -size * 0.18), max(2.0, size * 0.42), _with_alpha(secondary, 0.42 * ratio * lifetime_ratio))


func _draw_trap_clamp(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = Stage1ContextReader.as_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var width: float = float(effect.get("width", 92.0))
	var height: float = float(effect.get("height", 42.0))
	var ratio: float = _timer_ratio(effect)
	if _draw_bowling_trap_launch_sprite(canvas, pos, width, height, 1.0 - ratio, ratio):
		return
	var phase: float = float(effect.get("phase", 0.0))
	var color: Color = Stage1ContextReader.as_color(effect.get("color", Color(0.95, 0.18, 0.24)), Color(0.95, 0.18, 0.24))
	var secondary: Color = Stage1ContextReader.as_color(effect.get("secondary", Color(0.22, 0.10, 0.12)), Color(0.22, 0.10, 0.12))
	var rect := Rect2(pos - Vector2(width, height) * 0.5, Vector2(width, height))
	canvas.draw_rect(rect, _with_alpha(secondary, 0.24 * ratio), true)
	canvas.draw_rect(rect, _with_alpha(color, 0.58 * ratio), false, 2.0)
	var claw_open: float = 0.35 + 0.18 * sin(phase * 2.0)
	for side_sign in [-1.0, 1.0]:
		var hinge := Vector2(pos.x + side_sign * width * 0.30, pos.y - height * 0.12)
		var tip := Vector2(pos.x + side_sign * width * (0.08 + claw_open), pos.y + height * 0.42)
		canvas.draw_line(hinge, tip, _with_alpha(color, 0.72 * ratio), 3.0, true)
		canvas.draw_circle(hinge, 4.0, _with_alpha(secondary, 0.72 * ratio))


func _draw_bowling_trap_launch_sprite(canvas: CanvasItem, pos: Vector2, width: float, height: float, progress: float, alpha: float) -> bool:
	var texture: Texture2D = _get_bowling_trap_launch_sheet_texture()
	if texture == null:
		return false
	var frame_index: int = _get_bowling_trap_sheet_frame(progress)
	var draw_side: float = max(width * 1.55, height * 3.20)
	var draw_center := pos + Vector2(0.0, -draw_side * 0.24)
	canvas.draw_texture_rect_region(
		texture,
		Rect2(draw_center - Vector2(draw_side, draw_side) * 0.5, Vector2(draw_side, draw_side)),
		_get_bowling_trap_sheet_source_rect(texture, frame_index),
		Color(1.0, 1.0, 1.0, clamp(alpha, 0.0, 1.0)),
		false,
		true
	)
	return true


func _get_bowling_trap_sheet_frame(progress: float) -> int:
	return clampi(int(floor(clamp(progress, 0.0, 0.9999) * float(BOWLING_TRAP_SHEET_FRAME_COUNT))), 0, BOWLING_TRAP_SHEET_FRAME_COUNT - 1)


func _get_bowling_trap_sheet_source_rect(texture: Texture2D, frame_index: int) -> Rect2:
	var safe_frame: int = clampi(frame_index, 0, BOWLING_TRAP_SHEET_FRAME_COUNT - 1)
	var cell_size := Vector2(
		float(texture.get_width()) / float(BOWLING_TRAP_SHEET_COLS),
		float(texture.get_height()) / float(BOWLING_TRAP_SHEET_ROWS)
	)
	var col: int = safe_frame % BOWLING_TRAP_SHEET_COLS
	var row: int = int(floor(float(safe_frame) / float(BOWLING_TRAP_SHEET_COLS)))
	return Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)


func _draw_blast_field(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = Stage1ContextReader.as_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var width: float = float(effect.get("width", 168.0))
	var height: float = float(effect.get("height", 110.0))
	var ratio: float = _timer_ratio(effect)
	var color: Color = Stage1ContextReader.as_color(effect.get("color", Color(1.0, 0.34, 0.16)), Color(1.0, 0.34, 0.16))
	var secondary: Color = Stage1ContextReader.as_color(effect.get("secondary", Color(1.0, 0.82, 0.25)), Color(1.0, 0.82, 0.25))
	_draw_ellipse(canvas, pos, width * 0.5, height * 0.5, _with_alpha(color, 0.08 * ratio))
	for i in range(3):
		var scale: float = 0.38 + float(i) * 0.24 + (1.0 - ratio) * 0.18
		_draw_ellipse_outline(canvas, pos, width * 0.5 * scale, height * 0.5 * scale, _with_alpha(secondary, 0.36 * ratio), 2.0)


func _draw_net_web(canvas: CanvasItem, pos: Vector2, radius: float, ratio: float, color: Color) -> void:
	for i in range(6):
		var angle: float = TAU * float(i) / 6.0
		var dir := Vector2(cos(angle), sin(angle))
		canvas.draw_line(pos - dir * radius, pos + dir * radius, _with_alpha(color, 0.62 * ratio), 1.4, true)
	for ring_scale in [0.45, 0.72, 1.0]:
		var ring_radius: float = radius * float(ring_scale)
		var last: Vector2 = pos + Vector2(ring_radius, 0.0)
		for step in range(1, 19):
			var angle: float = TAU * float(step) / 18.0
			var next: Vector2 = pos + Vector2(cos(angle), sin(angle)) * ring_radius
			canvas.draw_line(last, next, _with_alpha(color, 0.44 * ratio), 1.2, true)
			last = next


func _draw_ellipse(canvas: CanvasItem, pos: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var angle: float = TAU * float(i) / 32.0
		points.append(pos + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	canvas.draw_colored_polygon(points, color)


func _draw_ellipse_outline(canvas: CanvasItem, pos: Vector2, radius_x: float, radius_y: float, color: Color, width: float = 1.0) -> void:
	var last: Vector2 = pos + Vector2(radius_x, 0.0)
	for i in range(1, 33):
		var angle: float = TAU * float(i) / 32.0
		var next: Vector2 = pos + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		canvas.draw_line(last, next, color, width, true)
		last = next


func _timer_ratio(entry: Dictionary) -> float:
	var timer: float = max(0.0, float(entry.get("timer_frames", 0.0)))
	var total: float = max(1.0, float(entry.get("max_timer_frames", timer)))
	return clamp(timer / total, 0.0, 1.0)


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0))


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
