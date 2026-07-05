extends RefCounted

# Shared lingpet skill rail card. The hatched companion casts on
# EVERY stage, so its skill card rides EVERY stage's boss skill-card rail rather
# than a separate pillar card. Each stage's boss-skill HUD composition calls
# append_entry() (which also force-enables the rail's active flag so a stage with
# no live boss skill still shows the lingpet card), and each per-stage renderer
# delegates the lingpet entry to draw_card()/tooltip_info() via is_lingpet_skill().
#
# draw_card() is fully SELF-CONTAINED (it owns its own texture) on purpose: the
# per-stage renderers resolve their own card art differently (per-id paths vs the
# Stage 3 atlas), and "maribo_hydro_sphere" is in none of those maps -- so the
# lingpet card must NOT route through any renderer's texture system.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")

const SKILL_ID := "maribo_hydro_sphere"
const SKILL_NAME := "하이드로 스피어"
const TEXTURE_PATH := "res://assets/sprites/lingpet/maribo_hydro_sphere_skillcard_imagegen_v2.png"
const ACCENT := Color(0.333, 0.855, 1.0)
const COOLDOWN_SECONDS := 40.0
const SIDE_STRIP_BASE := 2.0
const PREWARM_TEXTURE_FALLBACK_MSEC := 8
const PREWARM_TEXTURE_FALLBACK_POLLS := 4

# Decoded card art, shared (loaded once) across all five stage renderers.
static var _texture: Texture2D = null
static var _texture_loaded := false
static var _texture_cache: Dictionary = {}
static var _prewarm_paths: Array[String] = []
static var _prewarm_paths_ready := false
static var _prewarm_path_index := 0
static var _prewarm_complete := false


static func prewarm() -> void:
	while not prewarm_step():
		pass


static func clear_caches() -> void:
	_texture = null
	_texture_loaded = false
	_texture_cache.clear()
	_prewarm_paths.clear()
	_prewarm_paths_ready = false
	_prewarm_path_index = 0
	_prewarm_complete = false


static func prewarm_step() -> bool:
	if _prewarm_complete:
		return true
	if not _prewarm_paths_ready:
		_build_prewarm_paths()
		_prewarm_paths_ready = true
		return false
	if _prewarm_path_index >= _prewarm_paths.size():
		_prewarm_complete = true
		_prewarm_path_index = 0
		return true
	var card_path := str(_prewarm_paths[_prewarm_path_index])
	if not _prewarm_texture_path_step(card_path):
		return false
	_prewarm_path_index += 1
	if _prewarm_path_index >= _prewarm_paths.size():
		_prewarm_complete = true
		_prewarm_path_index = 0
		return true
	return false


static func _build_prewarm_paths() -> void:
	_prewarm_paths.clear()
	var seen := {}
	_append_prewarm_path(TEXTURE_PATH, seen)
	for pet_id in LingpetCatalog.get_pet_ids(true):
		for active_skill in LingpetCatalog.get_active_skill_pool(str(pet_id)):
			if not bool(active_skill.get("enabled", true)):
				continue
			var card_path := str(active_skill.get("card_texture_path", "")).strip_edges()
			_append_prewarm_path(card_path, seen)


static func _append_prewarm_path(path: String, seen: Dictionary) -> void:
	var resolved_path := path.strip_edges()
	if resolved_path == "":
		return
	if seen.has(resolved_path):
		return
	seen[resolved_path] = true
	_prewarm_paths.append(resolved_path)


static func _prewarm_texture_path_step(path: String) -> bool:
	var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		"[LingpetRailCard] missing skillcard texture: %s",
		"[LingpetRailCard] failed to load skillcard texture: %s",
		PREWARM_TEXTURE_FALLBACK_MSEC,
		PREWARM_TEXTURE_FALLBACK_POLLS,
		false,
		true
	)
	if not bool(result.get("done", false)):
		return false
	var texture_value: Variant = result.get("texture", null)
	if texture_value is Texture2D:
		var loaded_texture: Texture2D = texture_value
		_texture_cache[path] = loaded_texture
		if path == TEXTURE_PATH:
			_texture = loaded_texture
			_texture_loaded = true
	return true


static func texture(path: String = TEXTURE_PATH) -> Texture2D:
	var resolved_path := path.strip_edges()
	if resolved_path == "":
		resolved_path = TEXTURE_PATH
	if resolved_path == TEXTURE_PATH and not _texture_loaded:
		prewarm()
	return _load_texture(resolved_path)


static func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		var cached: Variant = _texture_cache[path]
		if cached is Texture2D:
			return cached as Texture2D
		_texture_cache.erase(path)
	var loaded := ProjectResourceLoader.load_texture(
		path,
		"[LingpetRailCard] missing skillcard texture: %s",
		"[LingpetRailCard] failed to load skillcard texture: %s"
	)
	if loaded != null:
		_texture_cache[path] = loaded
	return loaded


static func is_lingpet_skill(skill: Dictionary) -> bool:
	if bool(skill.get("is_lingpet", false)):
		return true
	var skill_id := str(skill.get("id", "")).strip_edges().to_lower()
	return skill_id == SKILL_ID or LingpetCatalog.has_active_skill_entry(skill_id)


static func _resolve_lingpet_runtime(registry: Object) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Object = registry.get_cached_instance("lingpet_egg_runtime")
		if cached != null:
			return cached
	if registry.has_method("get_instance"):
		return registry.get_instance("lingpet_egg_runtime")
	return null


# Returns ONLY the primary (slot 0) active-skill card. Kept for backward
# compatibility with the per-skill smokes; runtime rails go through
# build_entries() so a lingpet with a second unlocked active slot shows BOTH
# cards. Empty when the companion is not active.
static func build_entry(registry: Object) -> Dictionary:
	var entries := build_entries(registry)
	if entries.is_empty():
		return {}
	return entries[0]


# Returns one rail entry per LIVE active slot (slot 0 always, slot 1 when a
# second active is unlocked). The character-info panel already reads the
# companion_skill_*_1 snapshot keys for its second card; the runtime rail must
# do the same or a second unlocked active never gets its own skill card.
static func build_entries(registry: Object) -> Array[Dictionary]:
	var runtime: Object = _resolve_lingpet_runtime(registry)
	if runtime == null:
		return []
	if runtime.has_method("is_companion_active"):
		if not bool(runtime.is_companion_active()):
			return []
	elif not runtime.has_method("is_maribo_companion_active") or not bool(runtime.is_maribo_companion_active()):
		return []
	if not runtime.has_method("get_rail_card_surface") and not runtime.has_method("get_snapshot"):
		return []
	var snapshot: Dictionary = {}
	if runtime.has_method("get_rail_card_surface"):
		var rail_surface: Variant = runtime.get_rail_card_surface()
		if rail_surface is Dictionary:
			snapshot = rail_surface as Dictionary
	if snapshot.is_empty() and runtime.has_method("get_snapshot"):
		snapshot = runtime.get_snapshot()
	var entries: Array[Dictionary] = []
	var primary := _build_entry_from_snapshot(snapshot, "")
	if primary.is_empty():
		return []
	entries.append(primary)
	var second := _build_entry_from_snapshot(snapshot, "_1")
	if not second.is_empty():
		entries.append(second)
	return entries


# Builds one rail entry from a runtime snapshot slot. `suffix` is "" for the
# primary slot and "_1" for the second active slot; every companion_skill_*
# key exists in both suffixed and un-suffixed form (see
# lingpet_runtime_snapshot_builder / lingpet_companion_skill_state).
static func _build_entry_from_snapshot(snapshot: Dictionary, suffix: String) -> Dictionary:
	var skill_id: String = str(snapshot.get("companion_skill_id%s" % suffix, ""))
	if skill_id == "":
		return {}
	var duration: float = maxf(1.0, float(snapshot.get("companion_skill_cooldown_duration%s" % suffix, COOLDOWN_SECONDS)))
	var cooldown_remaining: float = maxf(0.0, float(snapshot.get("companion_skill_cooldown%s" % suffix, 0.0)))
	var progress: float = clampf(1.0 - cooldown_remaining / duration, 0.0, 1.0)
	var ready: bool = bool(snapshot.get("companion_skill_ready%s" % suffix, false))
	var casting: bool = _is_skill_casting(snapshot, skill_id, suffix)
	var status: String = "casting" if casting else ("ready" if ready else "charging")
	return {
		"id": skill_id,
		"label": str(snapshot.get("companion_skill_name%s" % suffix, SKILL_NAME)),
		"trigger_type": "auto",
		"trigger_label": "자동",
		"progress": progress,
		"ready": ready,
		"used": false,
		"status": status,
		"cooldown_remaining": cooldown_remaining,
		"cooldown_total": duration,
		"sort_remaining": cooldown_remaining,
		"flash": clampf(float(snapshot.get("companion_skill_flash_ratio%s" % suffix, 0.0)), 0.0, 1.0),
		"color": ACCENT,
		"is_lingpet": true,
		"accent_color": ACCENT,
		"card_texture_path": str(snapshot.get("companion_skill_card_path%s" % suffix, TEXTURE_PATH)),
		"description": str(snapshot.get("companion_skill_description%s" % suffix, "")),
	}


# Per-slot casting resolution. `draw_card` full-fills the gauge whenever status
# is "casting", so casting MUST be attributed to the slot's OWN skill kind, not
# a shared global OR -- otherwise slot 0's charging card would jump to full the
# moment slot 1 casts (and vice versa). Each slot's wind-up flag is suffixed,
# while the per-effect "active" flags come from the skill module snapshot keyed
# by kind (both slots run distinct kinds; would_share_module collapses to one
# slot when they'd share a module).
static func _is_skill_casting(snapshot: Dictionary, skill_id: String, suffix: String) -> bool:
	if bool(snapshot.get("companion_skill_winding_up%s" % suffix, false)):
		return true
	for flag_key in _casting_flag_keys_for_skill(skill_id):
		if bool(snapshot.get(flag_key, false)):
			return true
	return false


static func _casting_flag_keys_for_skill(skill_id: String) -> Array:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			return ["hydro_sphere_projectile_active", "hydro_sphere_puddle_active"]
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return ["headbutt_active", "headbutt_impact_active", "headbutt_miss_active", "headbutt_repeat_wait_active"]
		LingpetSkillDispatcher.SKILL_KIND_MOON_ORBIT:
			return ["moon_orbit_projectile_active", "moon_orbit_field_active"]
		LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			return ["bubble_trap_projectile_active", "bubble_trap_capture_active"]
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			return ["thunder_orb_projectile_active", "thunder_orb_explosion_active", "thunder_orb_electric_stun_active"]
		LingpetSkillDispatcher.SKILL_KIND_SOLAR_BOLT:
			return ["solar_bolt_active", "solar_bolt_refire_pending", "solar_bolt_vfx_active"]
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			return ["soul_clone_active"]
		LingpetSkillDispatcher.SKILL_KIND_GHOST_SUMMON:
			return ["ghost_summon_active"]
		LingpetSkillDispatcher.SKILL_KIND_STAR_COIL:
			return ["star_coil_active", "star_coil_visible"]
		LingpetSkillDispatcher.SKILL_KIND_GRAVITY_ACCEL:
			return ["gravity_accel_active", "gravity_accel_field_active"]
		LingpetSkillDispatcher.SKILL_KIND_SAND_PRISON:
			return ["sand_prison_active"]
		_:
			return []


# Merge the lingpet card(s) into a stage's boss skill-card rail. MUST also force
# the rail's active flag on, because every per-stage renderer early-returns when
# that flag is false -- otherwise a stage with no live boss skill would drop the
# card. Appends every live active slot (1 or 2 cards).
static func append_entry(hud_context: Dictionary, registry: Object, skills_key: String, active_flag_key: String) -> void:
	var entries := build_entries(registry)
	if entries.is_empty():
		return
	var rail_skills: Array = []
	var existing: Variant = hud_context.get(skills_key, [])
	if existing is Array:
		rail_skills = existing.duplicate()
	for entry in entries:
		rail_skills.append(entry)
	hud_context[skills_key] = rail_skills
	hud_context[active_flag_key] = true


static func tooltip_info(skill: Dictionary = {}) -> Dictionary:
	# Provides BOTH cooldown keys so every stage's tooltip path resolves it:
	# stage1/4 read cooldown_seconds; the shared spec (stage2/3) derives the
	# string from cooldown_seconds; stage5's own tooltip reads the cooldown string.
	var skill_name := str(skill.get("label", skill.get("name", SKILL_NAME))).strip_edges()
	if skill_name == "":
		skill_name = SKILL_NAME
	var trigger_label := str(skill.get("trigger_label", skill.get("trigger", ""))).strip_edges()
	if trigger_label == "":
		trigger_label = "자동발동"
	var cooldown_seconds := float(skill.get("cooldown_total", skill.get("cooldown_seconds", COOLDOWN_SECONDS)))
	if cooldown_seconds <= 0.0:
		cooldown_seconds = COOLDOWN_SECONDS
	var description := str(skill.get("description", "")).strip_edges()
	if description == "":
		description = SKILL_NAME
	var info := {
		"name": skill_name,
		"trigger": "자동발동",
		"cooldown_seconds": cooldown_seconds,
		"cooldown": _localized_cooldown_text(cooldown_seconds),
		"description": "마리보가 물의 창을 던집니다. 상대 진영 벽에 닿으면 5초 동안 가로로 넓은 물장판을 만듭니다.",
	}
	info["trigger"] = trigger_label
	info["description"] = description
	return info


static func _localized_cooldown_text(cooldown_seconds: float = COOLDOWN_SECONDS) -> String:
	var language: String = LanguageSettings.get_language()
	if language == LanguageSettings.LANGUAGE_ENGLISH:
		return "Cooldown %.0fs" % cooldown_seconds
	if language == LanguageSettings.LANGUAGE_SPANISH:
		return "Recarga %.0fs" % cooldown_seconds
	if language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Recarga %.0fs" % cooldown_seconds
	if language == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Перезарядка %.0fс" % cooldown_seconds
	if language == LanguageSettings.LANGUAGE_CHINESE:
		return "冷却%.0f秒" % cooldown_seconds
	if language == LanguageSettings.LANGUAGE_JAPANESE:
		return "クールタイム%.0f秒" % cooldown_seconds
	return "쿨타임 %.0f초" % cooldown_seconds


# Full, self-contained lingpet card render (background + v2 texture gauge fill +
# status overlays + flash border + status border + cyan side-strip + corner badge).
# Mirrors the proven Stage 1 boss-card visual but uses the shared static texture.
static func draw_card(canvas: CanvasItem, rect: Rect2, skill: Dictionary, scale_factor: float, time_seconds: float) -> void:
	if canvas == null:
		return
	var status: String = str(skill.get("status", "charging"))
	var ready: bool = bool(skill.get("ready", false)) or status == "ready"
	var active: bool = status == "casting"
	var used: bool = status == "used" or bool(skill.get("used", false))
	var progress: float = clampf(float(skill.get("progress", 0.0)), 0.0, 1.0)
	var flash: float = clampf(float(skill.get("flash", 0.0)), 0.0, 1.0)
	var accent: Color = _as_color(skill.get("accent_color", ACCENT), ACCENT)

	var fill_ratio: float = 1.0 if active or ready else progress
	if used:
		fill_ratio = 0.0
	_draw_gauge(canvas, rect, fill_ratio, accent, str(skill.get("card_texture_path", TEXTURE_PATH)))

	if active:
		var active_pulse: float = 0.5 + 0.5 * sin(time_seconds * 6.7)
		canvas.draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.16 + 0.12 * active_pulse))
	elif used:
		canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.58))
	elif not ready and fill_ratio > 0.0 and fill_ratio < 1.0:
		var edge_x: float = rect.position.x + rect.size.x * fill_ratio
		canvas.draw_line(
			Vector2(edge_x, rect.position.y + 1.0),
			Vector2(edge_x, rect.end.y - 1.0),
			Color(accent.r, accent.g, accent.b, 0.52),
			maxf(1.0, round(1.0 * scale_factor))
		)

	if flash > 0.0:
		canvas.draw_rect(
			rect.grow(2.0 * scale_factor),
			Color(accent.r, accent.g, accent.b, 0.22 * flash),
			false,
			maxf(1.0, round(2.0 * scale_factor))
		)

	var border_color := Color(0.24, 0.24, 0.32, 0.56)
	var border_width: float = maxf(1.0, round(1.0 * scale_factor))
	if active:
		var cast_pulse: float = 0.7 + 0.3 * sin(time_seconds * 5.0)
		border_color = Color(accent.r, accent.g, accent.b, 0.92 * cast_pulse)
		border_width = maxf(1.0, round(2.0 * scale_factor))
	elif ready:
		var ready_pulse: float = 0.6 + 0.4 * sin(time_seconds * 2.9)
		border_color = Color(accent.r, accent.g, accent.b, 0.78 * ready_pulse)
	elif used:
		border_color = Color(0.28, 0.25, 0.25, 0.54)
	canvas.draw_rect(rect, border_color, false, border_width)

	# Ally marker: cyan left side-strip + top-right corner badge (boss cards use red).
	var side_w: float = maxf(1.0, round(SIDE_STRIP_BASE * scale_factor))
	canvas.draw_rect(
		Rect2(rect.position + Vector2(0.0, border_width), Vector2(side_w, maxf(1.0, rect.size.y - border_width * 2.0))),
		Color(accent.r, accent.g, accent.b, 0.82)
	)
	var badge_size: float = maxf(3.0, round(4.0 * scale_factor))
	var top_right: Vector2 = rect.position + Vector2(rect.size.x - border_width, border_width)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			top_right + Vector2(-badge_size, 0.0),
			top_right,
			top_right + Vector2(0.0, badge_size),
		]),
		Color(accent.r, accent.g, accent.b, 0.94)
	)


static func _draw_gauge(canvas: CanvasItem, rect: Rect2, fill_ratio: float, accent: Color, texture_path: String) -> void:
	var clamped_fill: float = clampf(fill_ratio, 0.0, 1.0)
	canvas.draw_rect(rect, Color(0.06, 0.045, 0.075, 1.0))
	var card_texture: Texture2D = texture(texture_path)
	if card_texture == null:
		canvas.draw_rect(rect, Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 1.0))
		if clamped_fill > 0.0:
			canvas.draw_rect(
				Rect2(rect.position, Vector2(rect.size.x * clamped_fill, rect.size.y)),
				Color(accent.r * 0.55, accent.g * 0.55, accent.b * 0.55, 1.0)
			)
		return
	canvas.draw_texture_rect(card_texture, rect, false, Color(0.18, 0.18, 0.20, 1.0))
	if clamped_fill <= 0.0:
		return
	var texture_size: Vector2 = card_texture.get_size()
	var source_width: float = texture_size.x * clamped_fill
	canvas.draw_texture_rect_region(
		card_texture,
		Rect2(rect.position, Vector2(rect.size.x * clamped_fill, rect.size.y)),
		Rect2(Vector2.ZERO, Vector2(source_width, texture_size.y))
	)


static func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
