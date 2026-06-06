extends RefCounted

# Fullscreen acquisition cut-in for the newly hatched lingpet. Drawn on top of the HUD
# (mirrors skill_cutin_overlay_host) and registered as a PHYSICS-PAUSING modal:
# the modal gate blocks battle physics while it is active, and the reveal is
# advanced by the frame controller's ungated idle pump (advance_acquire_cutin),
# not by the gated gameplay update. Driven by lingpet_egg_runtime's
# is_acquire_cutin_active() / get_acquire_cutin_progress(); triggered once when
# the egg hatches into the companion, and holds until a click/confirm dismisses
# it (no auto fade-out).
#
# Art uses each pet's catalog cut-in, not the SD walk sheet. The primary cut-in
# visual is the upscaled AutoSprite Live2D-style sheet; the crisp outsourced PNG
# remains as fallback/reference if the sheet is disabled.
# Maribo provenance: v003 magenta -> magenta-key nukki -> maribo_cutin_art.png (static)
#   -> AutoSprite character pose + custom cut-in loop (legendary, 1024px/16)
#   -> deterministic 84% safe-margin repack -> Real-ESRGAN x2 per cell
#   -> maribo_cutin_anim.png (2048px/frame, 4x4, 16 frames, 8192px sheet).

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const DEFAULT_PET_ID := "maribo"
const FALLBACK_CUTIN_ART_PATH := "res://assets/sprites/lingpet/maribo_cutin_art.png"
const FALLBACK_CUTIN_ANIM_SHEET_PATH := "res://assets/sprites/lingpet/maribo_cutin_anim.png"
const FALLBACK_CUTIN_ANIM_MANIFEST := "res://assets/sprites/lingpet/maribo_cutin_anim_manifest.json"
const CUTIN_ANIM_COLS := 4
const CUTIN_ANIM_ROWS := 4
const CUTIN_ANIM_FRAMES := 16
const CUTIN_ANIM_FPS := 16.0
const CUTIN_ANIM_COLS_OVERRIDES := {
	"red_dragon": 8,
	"rabi": 6,
}
const CUTIN_ANIM_ROWS_OVERRIDES := {
	"red_dragon": 4,
	"rabi": 6,
}
const CUTIN_ANIM_FRAMES_OVERRIDES := {
	"red_dragon": 32,
	"rabi": 32,
}
const CUTIN_ANIM_FPS_OVERRIDES := {
	"red_dragon": 16.0,
	"rabi": 32.0,
}
const USE_ANIMATED_CUTIN := true
# Click-triggered EXIT ACTION sheet: the current pet plays its catalog dismiss
# animation, then the overlay fades out and resumes gameplay. Driven by
# the runtime's is_acquire_cutin_dismissing() / get_acquire_cutin_dismiss_progress().
const FALLBACK_CUTIN_DISMISS_SHEET_PATH := "res://assets/sprites/lingpet/maribo_cutin_dismiss_anim.png"
const CUTIN_DISMISS_COLS := 5
const CUTIN_DISMISS_ROWS := 5
const CUTIN_DISMISS_FRAMES := 25
# Frames play over the first DISMISS_ACTION_PORTION of the dismiss window, then the
# final frame holds while the overlay fades out (DISMISS_FADE_START -> 1.0). The
# extra water-spray burst peaks near the spear-raise apex.
const DISMISS_ACTION_PORTION := 0.74
const DISMISS_FADE_START := 0.64
const DISMISS_SPRAY_PEAK := 0.56
# Raised from 0.70 to 0.85: the v4 steady cut-in and the spear-flourish dismiss
# are both repacked at 0.90 cell-centered (so they read at the SAME body size),
# which fills ~60% of the cell vs the old ~78%. The higher view ratio restores
# the on-screen hero scale. Cut-in and dismiss share this constant, so they
# stay size-locked to each other.
const ANIM_CELL_VIEW_H_RATIO := 0.85
const STATIC_ART_VIEW_H_RATIO := 0.74
const STATIC_ART_MAX_W_RATIO := 0.92
const STATIC_ART_BREATH_HZ := 0.72
const STATIC_ART_SCALE_PULSE := 0.018
const TITLE_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

const SUBTITLE_TEXT := "공명으로 깨어난 링펫 · 동행 시작"

# Painted "resonance awakening" portal backplate (imagegen, alpha-baked from a
# pure-black additive source so the black margins composite transparently — no
# square box residue, alpha bbox does not touch the canvas edge). Replaces the
# old thin procedural rings + Tron-grid background with a premium painted portal,
# uniform across all pets (resonance / 공명 theme). The motion envelope (entrance
# pop, breath, scale pulse, expanding pulse rings) is applied procedurally at
# draw time so the static texture reads alive WITHOUT a per-draw shader pass or
# draw_set_transform (both unsafe in this immediate-mode overlay host).
const RESONANCE_PORTAL_PATH := "res://assets/sprites/lingpet/effects/lingpet_acquire_resonance_backplate_imagegen_v1.png"

const DIM_ALPHA_MAX := 0.66
const OCEAN_DEEP := Color(0.04, 0.09, 0.18)
const OCEAN_GLOW := Color(0.24, 0.78, 1.0)
const RESONANCE := Color(0.55, 1.0, 0.95)
const TITLE_COLOR := Color(0.62, 1.0, 0.96)
const SPEED_LINE_COUNT := 22
const RESTORE_DATA_BIT_COUNT := 56
const RESTORE_SOLID_START := 0.94
const RESTORE_FRAGMENT_COLOR := Color(0.44, 1.0, 0.96)
# Digital reconstruction tuning (all in normalized restore_progress space, 0..1).
# Pacing handles for the "code-data shards assemble -> hologram densifies ->
# scan-printer solidifies -> lock-in" sequence; tweak here to retune feel.
const RESTORE_VOXEL_COLS := 10
const RESTORE_VOXEL_ROWS := 10
const RESTORE_VOXEL_LAND := 0.72
const RESTORE_PRINT_START := 0.44
const RESTORE_PRINT_END := 0.93
const RESTORE_CODE_GLYPH_COUNT := 16
const RESTORE_GLYPH_TOKENS := ["01", "10", "11", "00", "0x7F", "0xA3", "101", "010", "0xFF", "110", "0x1C", "001", "0xE0", "100", "0x3D", "011"]
# Futuristic data palette: near-white core, hot cyan, magenta chromatic partner.
const DATA_CORE := Color(0.80, 1.0, 1.0)
const DATA_HOT := Color(0.34, 0.96, 1.0)
const DATA_MAGENTA := Color(1.0, 0.36, 0.82)
const GRID_COLOR := Color(0.24, 0.78, 1.0)
const CUTIN_PREWARM_VISUAL_KEYS := ["cutin_art", "cutin_anim", "cutin_dismiss_anim"]

# Phase breakpoints over normalized reveal progress (0..1). Progress is clamped
# at 1.0 by the runtime, so progress >= HOLD_PROGRESS means the reveal finished
# and the cut-in is holding for a click/confirm to dismiss.
const INTRO_END := 0.12
const TEXT_START := 0.62
const HOLD_PROGRESS := 0.999

# Baked frame-0 alpha occupancy (loaded once from the manifest in prewarm). The
# reconstruction iterates the voxel grid; cells outside Maribo's silhouette must
# skip the shard/bevel/snap-flash draws or the transparent cell padding lights up
# as a "restoring box" instead of "restoring Maribo". Empty until loaded; the
# draw path falls back to a centered-ellipse cull so it is never a full rectangle.
var _recon_ready := false
var _recon_cols := 0
var _recon_rows := 0
var _recon_filled: PackedByteArray = PackedByteArray()
var _recon_bbox := Rect2(0.0, 0.0, 1.0, 1.0)
var _recon_mask_cache: Dictionary = {}
var _prewarm_pet_ids: Array[String] = []
var _prewarm_pet_index := 0
var _prewarm_finished := false
var _pet_texture_prewarm_pet_id := ""
var _pet_texture_prewarm_index := 0
var _pet_texture_prewarm_finished_for := ""
var _asset_pet_id := ""
var _title_text := "마리보"
var _cutin_art: Texture2D = null
var _cutin_anim_sheet: Texture2D = null
var _cutin_anim_manifest := FALLBACK_CUTIN_ANIM_MANIFEST
var _cutin_dismiss_sheet: Texture2D = null
var _portal_texture: Texture2D = null
var _portal_prewarm_attempted := false


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_finished:
		return true
	# Warm the shared resonance portal backplate first so the first (physics-paused)
	# reveal frame never sync-loads a 1MB+ PNG on the draw hot path. One staged step;
	# the attempt flag guards against an infinite prewarm loop if the asset is missing.
	if not _portal_prewarm_attempted:
		_portal_prewarm_attempted = true
		_get_portal_texture()
		return false
	if _prewarm_pet_ids.is_empty():
		_prewarm_pet_ids = LingpetCatalog.get_pet_ids()
		if _prewarm_pet_ids.is_empty():
			_prewarm_pet_ids = [DEFAULT_PET_ID]
	if _prewarm_pet_index >= _prewarm_pet_ids.size():
		_prewarm_pet_index = 0
		_prewarm_finished = true
		return true
	var pet_id: String = str(_prewarm_pet_ids[_prewarm_pet_index]).strip_edges().to_lower()
	if pet_id == "":
		pet_id = DEFAULT_PET_ID
	# Boot warmup must stay lightweight: do not decode every pet's 8192px cut-in
	# sheets at Stage 1 loading 81%. Cache only small JSON reconstruction masks;
	# hatch-time callers can opt into `prewarm_pet_assets_step(pet_id)`.
	_prewarm_reconstruction_mask_for_pet(pet_id)
	_prewarm_pet_index += 1
	return false


func prewarm_pet_assets_step(pet_id: String = DEFAULT_PET_ID) -> bool:
	var normalized := pet_id.strip_edges().to_lower()
	if normalized == "" or not LingpetCatalog.has_pet(normalized):
		normalized = DEFAULT_PET_ID
	if _pet_texture_prewarm_finished_for == normalized:
		return true
	if _pet_texture_prewarm_pet_id != normalized:
		_pet_texture_prewarm_pet_id = normalized
		_pet_texture_prewarm_index = 0
		_pet_texture_prewarm_finished_for = ""
	if _pet_texture_prewarm_index < CUTIN_PREWARM_VISUAL_KEYS.size():
		var visual_key: String = str(CUTIN_PREWARM_VISUAL_KEYS[_pet_texture_prewarm_index])
		var path: String = LingpetCatalog.get_visual_path(normalized, visual_key)
		if path != "":
			# prefer_imported_fallback=true: if the threaded slot times out, resolve
			# via the size_limit'd import (load_imported_texture), never the raw 8192px
			# source PNG. Keeps the streamed sheet small even on the fallback path.
			var texture_result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
				path,
				"",
				"",
				ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_MSEC,
				ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_POLLS,
				false,
				true
			)
			if not bool(texture_result.get("done", true)):
				return false
		_pet_texture_prewarm_index += 1
		return false
	_prewarm_reconstruction_mask_for_pet(normalized)
	_pet_texture_prewarm_finished_for = normalized
	_pet_texture_prewarm_pet_id = ""
	_pet_texture_prewarm_index = 0
	return true


func _prewarm_reconstruction_mask_for_pet(pet_id: String) -> void:
	var anim_path: String = LingpetCatalog.get_visual_path(pet_id, "cutin_anim")
	var manifest_path: String = _manifest_path_from_anim_path(anim_path)
	if manifest_path == "" or not FileAccess.file_exists(manifest_path):
		manifest_path = FALLBACK_CUTIN_ANIM_MANIFEST
	_get_reconstruction_mask_data(manifest_path)


func _load_reconstruction_mask() -> void:
	if _recon_ready:
		return
	var mask_data: Dictionary = _get_reconstruction_mask_data(_cutin_anim_manifest)
	if mask_data.is_empty():
		return
	_apply_reconstruction_mask(mask_data)


func _get_reconstruction_mask_data(manifest_path: String) -> Dictionary:
	if manifest_path == "" or not FileAccess.file_exists(manifest_path):
		return {}
	var cached: Variant = _recon_mask_cache.get(manifest_path, null)
	if cached is Dictionary:
		return cached as Dictionary
	var txt: String = FileAccess.get_file_as_string(manifest_path)
	if txt.is_empty():
		return {}
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var entry: Variant = (data as Dictionary).get("reconstruction_frame0", null)
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var cols: int = int((entry as Dictionary).get("grid_cols", 0))
	var rows: int = int((entry as Dictionary).get("grid_rows", 0))
	var occ: Variant = (entry as Dictionary).get("occupancy", [])
	if cols <= 0 or rows <= 0 or typeof(occ) != TYPE_ARRAY or (occ as Array).size() != cols * rows:
		return {}
	var occ_arr: Array = occ
	var filled := PackedByteArray()
	filled.resize(occ_arr.size())
	for i in occ_arr.size():
		filled[i] = 1 if int(occ_arr[i]) != 0 else 0
	var bbox := Rect2(0.0, 0.0, 1.0, 1.0)
	var bb: Variant = (entry as Dictionary).get("alpha_bbox", [0.0, 0.0, 1.0, 1.0])
	if typeof(bb) == TYPE_ARRAY and (bb as Array).size() == 4:
		var bb_arr: Array = bb
		bbox = Rect2(float(bb_arr[0]), float(bb_arr[1]), float(bb_arr[2]), float(bb_arr[3]))
	var result := {
		"cols": cols,
		"rows": rows,
		"filled": filled,
		"bbox": bbox,
	}
	_recon_mask_cache[manifest_path] = result
	return result


func _apply_reconstruction_mask(mask_data: Dictionary) -> void:
	_recon_cols = int(mask_data.get("cols", 0))
	_recon_rows = int(mask_data.get("rows", 0))
	var filled_value: Variant = mask_data.get("filled", PackedByteArray())
	if filled_value is PackedByteArray:
		_recon_filled = filled_value as PackedByteArray
	else:
		_recon_filled = PackedByteArray()
	var bbox_value: Variant = mask_data.get("bbox", Rect2(0.0, 0.0, 1.0, 1.0))
	if bbox_value is Rect2:
		_recon_bbox = bbox_value as Rect2
	else:
		_recon_bbox = Rect2(0.0, 0.0, 1.0, 1.0)
	_recon_ready = (
		_recon_cols > 0
		and _recon_rows > 0
		and _recon_filled.size() == _recon_cols * _recon_rows
	)


func prewarm_runtime_nodes(_owner: Object = null) -> void:
	prewarm_assets()
	# Warm the shared resonance portal texture so the first reveal frame does not
	# load a 1MB+ PNG on the (physics-paused) hot path.
	_get_portal_texture()


func _get_portal_texture() -> Texture2D:
	if _portal_texture != null:
		return _portal_texture
	_portal_texture = ProjectResourceLoader.load_texture(RESONANCE_PORTAL_PATH, "", "")
	return _portal_texture


func draw(canvas: CanvasItem, runtime: Object, view_size: Vector2) -> void:
	if canvas == null or runtime == null:
		return
	if not runtime.has_method("is_acquire_cutin_active") or not bool(runtime.is_acquire_cutin_active()):
		return
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	var pet_id: String = _get_runtime_pet_id(runtime)
	# Stream the heavy 8192/5120 anim + dismiss sheets on a background thread across
	# the cut-in's intro frames (dim + portal + static art) instead of sync-loading
	# them on the first reveal draw (the ~1141ms freeze). _sync pulls them from cache
	# once ready; until then _draw_art falls back to the small static art.
	prewarm_pet_assets_step(pet_id)
	_sync_assets_for_pet(pet_id)

	# Click-triggered exit action takes over the whole overlay: spear-raise +
	# water-spray, then fade out (gameplay resumes when the runtime clears active).
	if runtime.has_method("is_acquire_cutin_dismissing") and bool(runtime.is_acquire_cutin_dismissing()):
		var dismiss_progress: float = 0.0
		if runtime.has_method("get_acquire_cutin_dismiss_progress"):
			dismiss_progress = clampf(float(runtime.get_acquire_cutin_dismiss_progress()), 0.0, 1.0)
		_draw_dismiss_action(canvas, view_size, dismiss_progress)
		return

	var progress: float = 0.0
	if runtime.has_method("get_acquire_cutin_progress"):
		progress = clampf(float(runtime.get_acquire_cutin_progress()), 0.0, 1.0)

	_draw_dim(canvas, view_size, progress)
	_draw_resonance_bg(canvas, view_size, progress)
	_draw_speed_lines(canvas, view_size, progress)
	_draw_art(canvas, view_size, progress)
	_draw_title(canvas, view_size, progress)
	_draw_flash(canvas, view_size, progress)
	_draw_dismiss_hint(canvas, view_size, progress)


func _sync_assets_for_pet(pet_id: String) -> void:
	var normalized := pet_id.strip_edges().to_lower()
	if normalized == "" or not LingpetCatalog.has_pet(normalized):
		normalized = DEFAULT_PET_ID
	if normalized == _asset_pet_id:
		_refresh_deferred_cutin_sheets(normalized)
		return
	_asset_pet_id = normalized
	_title_text = LingpetCatalog.get_display_name(normalized)
	# Static, anim, and dismiss textures are all pulled from the threaded prewarm
	# cache. If a texture is not ready yet, the early portal/data restore frames
	# keep animating instead of forcing a synchronous PNG decode on the draw path.
	_cutin_art = _get_cached_cutin_texture(normalized, "cutin_art")
	_cutin_anim_sheet = _get_cached_cutin_texture(normalized, "cutin_anim")
	_cutin_dismiss_sheet = _get_cached_cutin_texture(normalized, "cutin_dismiss_anim")
	var anim_path := LingpetCatalog.get_visual_path(normalized, "cutin_anim")
	_cutin_anim_manifest = _manifest_path_from_anim_path(anim_path)
	if _cutin_anim_manifest == "" or not FileAccess.file_exists(_cutin_anim_manifest):
		_cutin_anim_manifest = FALLBACK_CUTIN_ANIM_MANIFEST
	_reset_reconstruction_mask()
	_load_reconstruction_mask()


func _refresh_deferred_cutin_sheets(pet_id: String) -> void:
	# Pull the streamed anim/dismiss sheets from cache once prewarm_pet_assets_step
	# has them; before that they stay null so _draw_art uses the static art.
	if _cutin_art == null:
		_cutin_art = _get_cached_cutin_texture(pet_id, "cutin_art")
	if _cutin_anim_sheet == null:
		_cutin_anim_sheet = _get_cached_cutin_texture(pet_id, "cutin_anim")
	if _cutin_dismiss_sheet == null:
		_cutin_dismiss_sheet = _get_cached_cutin_texture(pet_id, "cutin_dismiss_anim")


func _get_cached_cutin_texture(pet_id: String, visual_key: String) -> Texture2D:
	# Cache key matches prewarm_pet_assets_step's (the catalog visual path); returns
	# null until the threaded prewarm has stored the imported (size_limit'd) sheet.
	var path := LingpetCatalog.get_visual_path(pet_id, visual_key)
	if path == "":
		return null
	return ProjectResourceLoader.get_cached_texture(path)


func _get_runtime_pet_id(runtime: Object) -> String:
	if runtime != null and runtime.has_method("get_snapshot"):
		var snapshot: Variant = runtime.get_snapshot()
		if snapshot is Dictionary:
			var data := snapshot as Dictionary
			var pet_id := str(data.get("active_pet_id", ""))
			if pet_id == "":
				pet_id = str(data.get("pet_id", ""))
			return pet_id
	return DEFAULT_PET_ID


func _load_catalog_texture(pet_id: String, visual_key: String, fallback: Texture2D = null) -> Texture2D:
	var path := LingpetCatalog.get_visual_path(pet_id, visual_key)
	if path == "":
		path = _get_fallback_visual_path(visual_key)
	if path == "":
		return fallback
	# Use the IMPORTED (size_limit'd) texture, not load_texture() which decodes the
	# raw source PNG first and bypasses process/size_limit -- that raw 8192px decode
	# + VRAM upload was the ~1141ms first-draw freeze.
	var texture := ProjectResourceLoader.load_imported_texture(path, "", "")
	if texture != null:
		return texture
	var fallback_path := _get_fallback_visual_path(visual_key)
	if fallback_path != "" and fallback_path != path:
		texture = ProjectResourceLoader.load_imported_texture(fallback_path, "", "")
		if texture != null:
			return texture
	return fallback


func _get_fallback_visual_path(visual_key: String) -> String:
	match visual_key:
		"cutin_art":
			return FALLBACK_CUTIN_ART_PATH
		"cutin_anim":
			return FALLBACK_CUTIN_ANIM_SHEET_PATH
		"cutin_dismiss_anim":
			return FALLBACK_CUTIN_DISMISS_SHEET_PATH
	return ""


func _manifest_path_from_anim_path(anim_path: String) -> String:
	var path := anim_path.strip_edges()
	if path == "" or not path.ends_with(".png"):
		return ""
	return path.substr(0, path.length() - 4) + "_manifest.json"


func _reset_reconstruction_mask() -> void:
	_recon_ready = false
	_recon_cols = 0
	_recon_rows = 0
	_recon_filled = PackedByteArray()
	_recon_bbox = Rect2(0.0, 0.0, 1.0, 1.0)


func _overlay_fade(progress: float) -> float:
	# Eases the overlay ON during the intro, then stays fully on (the cut-in
	# holds until the player clicks to dismiss — there is no auto fade-out).
	if progress <= INTRO_END:
		return clampf(progress / INTRO_END, 0.0, 1.0)
	return 1.0


func _ease_out_cubic(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)


func _draw_dim(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	var alpha: float = DIM_ALPHA_MAX * _overlay_fade(progress)
	if alpha <= 0.0:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, alpha))


func _draw_resonance_bg(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	var fade: float = _overlay_fade(progress)
	if fade <= 0.0:
		return
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.46)
	var base_radius: float = view_size.length() * 0.5
	# Soft deep wash for depth behind the painted portal.
	canvas.draw_circle(center, base_radius, Color(OCEAN_DEEP.r, OCEAN_DEEP.g, OCEAN_DEEP.b, 0.42 * fade))

	# Painted "resonance awakening" portal. Two counter-rotating parallax layers
	# (a slow dim outer halo + a brighter inner ring) give it a living, spinning
	# summon-circle feel, plus a chromatic-aberration shimmer, an entrance pop, a
	# breath, and a pulsing core. Rotation uses rotated textured quads
	# (draw_colored_polygon) -- NOT draw_set_transform (the documented overlay trap)
	# and NOT a per-draw shader pass (Godot 4 has no per-command material, and a
	# node-based shader material cannot sit behind the immediate character draw on
	# this single-canvas overlay), so the spin stays local to the portal draws.
	var portal: Texture2D = _get_portal_texture()
	if portal != null and portal.get_width() > 1:
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		var breath: float = sin(t * TAU * 0.16)
		var entrance: float = lerpf(0.70, 1.0, _ease_out_cubic(clampf(progress / maxf(0.01, INTRO_END * 1.8), 0.0, 1.0)))
		var min_dim: float = minf(view_size.x, view_size.y)
		# Far halo layer: larger, dim, cool, slow counter-clockwise spin.
		var far_diam: float = min_dim * (1.58 + breath * 0.014) * entrance
		_draw_portal_quad(canvas, portal, center, far_diam, -t * 0.16, Color(0.80, 0.95, 1.0, 0.28 * fade))
		# Near hero layer: brighter, clockwise spin, with a chromatic-aberration
		# shimmer (cyan + magenta ghosts offset along an oscillating axis).
		var near_diam: float = min_dim * (1.28 + breath * 0.024) * entrance
		var near_angle: float = t * 0.30
		var chroma: float = view_size.x * 0.004 * (0.6 + 0.4 * sin(t * 2.3))
		_draw_portal_quad(canvas, portal, center + Vector2(chroma, 0.0), near_diam, near_angle, Color(0.42, 1.0, 1.0, 0.22 * fade))
		_draw_portal_quad(canvas, portal, center - Vector2(chroma, 0.0), near_diam, near_angle, Color(1.0, 0.50, 0.95, 0.18 * fade))
		_draw_portal_quad(canvas, portal, center, near_diam, near_angle, Color(1.0, 1.0, 1.0, (0.60 + 0.10 * breath) * fade))
		# Bright pulsing core glow at the very center.
		canvas.draw_circle(center, near_diam * 0.09, Color(0.86, 1.0, 1.0, (0.30 + 0.12 * breath) * fade))
	else:
		# Fallback soft glow if the portal texture is unavailable.
		canvas.draw_circle(center, base_radius * 0.62, Color(OCEAN_GLOW.r, OCEAN_GLOW.g, OCEAN_GLOW.b, 0.18 * fade))

	# Expanding resonance rings (the "공명" pulse) layered over the portal.
	var ring_phase: float = clampf((progress - INTRO_END) / 0.5, 0.0, 1.0)
	for i in 3:
		var ring_t: float = float(i) / 3.0
		var pulse: float = fposmod(ring_phase + ring_t, 1.0)
		var radius: float = base_radius * (0.20 + pulse * 0.70)
		var ring_alpha: float = (1.0 - pulse) * 0.34 * fade
		if ring_alpha <= 0.01:
			continue
		canvas.draw_arc(center, radius, 0.0, TAU, 48, Color(RESONANCE.r, RESONANCE.g, RESONANCE.b, ring_alpha), maxf(2.0, view_size.y * 0.004), true)


func _draw_portal_quad(canvas: CanvasItem, portal: Texture2D, center: Vector2, diameter: float, angle: float, modulate: Color) -> void:
	# Draws the portal texture as a square quad rotated by `angle`. Rotating the
	# four corner points while pinning the UVs to the texture corners spins the
	# texture WITHOUT draw_set_transform, so the spin never leaks into the dim /
	# character / title drawn on the same immediate canvas.
	if portal == null or modulate.a <= 0.0 or diameter <= 1.0:
		return
	var h: float = diameter * 0.5
	var ca: float = cos(angle)
	var sa: float = sin(angle)
	var corners := [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
	var pts := PackedVector2Array()
	for c in corners:
		pts.push_back(center + Vector2(c.x * ca - c.y * sa, c.x * sa + c.y * ca))
	var uvs := PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	canvas.draw_colored_polygon(pts, modulate, uvs, portal)


func _blit_portal(canvas: CanvasItem, portal: Texture2D, center: Vector2, diameter: float, modulate: Color) -> void:
	if portal == null or modulate.a <= 0.0 or diameter <= 1.0:
		return
	var tex_size: Vector2 = portal.get_size()
	var aspect: float = tex_size.y / maxf(1.0, tex_size.x)
	var draw_size := Vector2(diameter, diameter * aspect)
	canvas.draw_texture_rect(portal, Rect2(center - draw_size * 0.5, draw_size), false, modulate)


func _draw_speed_lines(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	if progress < INTRO_END or progress >= HOLD_PROGRESS:
		return
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.46)
	var max_radius: float = view_size.length() * 0.58
	var alpha: float = 0.16 * _overlay_fade(progress)
	if alpha <= 0.0:
		return
	for i in SPEED_LINE_COUNT:
		var angle: float = (float(i) / float(SPEED_LINE_COUNT)) * TAU
		var dir := Vector2(cos(angle), sin(angle))
		var inner_r: float = max_radius * 0.34
		var outer_r: float = max_radius * (0.70 + 0.30 * sin(angle * 3.0 + progress * 16.0))
		canvas.draw_line(center + dir * inner_r, center + dir * outer_r, Color(RESONANCE.r, RESONANCE.g, RESONANCE.b, alpha), maxf(1.0, view_size.y * 0.0022), true)


func _draw_art(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	var rise_raw: float = clampf((progress - INTRO_END) / 0.20, 0.0, 1.0)
	var alpha: float = clampf(rise_raw * 1.5, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var entrance: float = _ease_out_back(rise_raw)
	var restore_progress: float = clampf((progress - INTRO_END) / maxf(0.01, TEXT_START - INTRO_END), 0.0, 1.0)
	if USE_ANIMATED_CUTIN and _cutin_anim_sheet != null and _cutin_anim_sheet.get_width() > 1:
		_draw_art_animated(canvas, view_size, t, entrance, rise_raw, alpha, restore_progress)
	else:
		_draw_art_static(canvas, view_size, t, entrance, rise_raw, alpha, restore_progress)


func _draw_art_animated(
	canvas: CanvasItem,
	view_size: Vector2,
	t: float,
	entrance: float,
	rise_raw: float,
	alpha: float,
	restore_progress: float
) -> void:
	# Live2D-style: the AutoSprite asset animation carries the breathing / sway /
	# spear-bob, so we only frame-step the loop and apply the entrance punch +
	# aura chrome. No squash/stretch here (the frames already deform the art).
	var sheet: Texture2D = _cutin_anim_sheet
	var cols: int = _get_cutin_anim_cols()
	var rows: int = _get_cutin_anim_rows()
	var cw: float = float(sheet.get_width()) / float(cols)
	var ch: float = float(sheet.get_height()) / float(rows)
	if cw <= 1.0 or ch <= 1.0:
		return
	# Freeze the source frame during reconstruction so the assembling shards /
	# scanline reference a STABLE silhouette. A changing source frame mid-build
	# makes the textured shards jitter and the body shimmer; the Live2D breathing
	# loop only starts once the art has locked solid (>= RESTORE_SOLID_START).
	var frame: int = 0
	if restore_progress >= RESTORE_SOLID_START:
		frame = int(t * _get_cutin_anim_fps()) % maxi(1, _get_cutin_anim_frame_count())
	var col: int = frame % cols
	var row: int = int(floor(float(frame) / float(cols)))
	var src := Rect2(float(col) * cw, float(row) * ch, cw, ch)

	# The cell carries transparent padding (~1.4x) around the character, so size
	# the whole cell generously; the character then reads at roughly hero scale.
	var target_h: float = view_size.y * _get_cutin_anim_view_h_ratio() * entrance
	var scale: float = target_h / ch
	var max_w: float = view_size.x * 0.98
	if cw * scale > max_w:
		scale = max_w / cw
	var dw: float = cw * scale
	var dh: float = ch * scale
	var enter_offset: float = lerpf(view_size.y * 0.12, 0.0, _ease_out_cubic(rise_raw))
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.46 + enter_offset)
	var pos := Vector2(center.x - dw * 0.5, center.y - dh * 0.5)

	# Character fills ~62% of the padded cell -> hug aura/glow to that radius.
	var char_radius: float = dh * 0.31
	_draw_art_aura(canvas, center, char_radius * 1.18, t, alpha, rise_raw)
	canvas.draw_circle(center, char_radius, Color(OCEAN_GLOW.r, OCEAN_GLOW.g, OCEAN_GLOW.b, 0.20 * alpha))
	_draw_restoring_texture(canvas, sheet, src, Rect2(pos, Vector2(dw, dh)), t, alpha, restore_progress)


func _get_cutin_anim_fps() -> float:
	return maxf(1.0, float(CUTIN_ANIM_FPS_OVERRIDES.get(_asset_pet_id, CUTIN_ANIM_FPS)))


func _get_cutin_anim_cols() -> int:
	return maxi(1, int(CUTIN_ANIM_COLS_OVERRIDES.get(_asset_pet_id, CUTIN_ANIM_COLS)))


func _get_cutin_anim_rows() -> int:
	return maxi(1, int(CUTIN_ANIM_ROWS_OVERRIDES.get(_asset_pet_id, CUTIN_ANIM_ROWS)))


func _get_cutin_anim_frame_count() -> int:
	return maxi(1, int(CUTIN_ANIM_FRAMES_OVERRIDES.get(_asset_pet_id, CUTIN_ANIM_FRAMES)))


func _get_cutin_anim_view_h_ratio() -> float:
	return maxf(0.01, LingpetCatalog.get_visual_layout_value(_asset_pet_id, "cutin_anim_view_h_ratio", ANIM_CELL_VIEW_H_RATIO))


func _get_cutin_dismiss_view_h_ratio() -> float:
	var anim_ratio: float = _get_cutin_anim_view_h_ratio()
	return maxf(0.01, LingpetCatalog.get_visual_layout_value(_asset_pet_id, "cutin_dismiss_view_h_ratio", anim_ratio))


func _draw_dismiss_action(canvas: CanvasItem, view_size: Vector2, dismiss_progress: float) -> void:
	# Overlay fades out over [DISMISS_FADE_START, 1.0] so the screen closes naturally.
	var out_fade: float = 1.0 - _smoothstep_range(DISMISS_FADE_START, 1.0, dismiss_progress)
	if out_fade <= 0.0:
		return
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.46)

	# Background dim + painted portal + soft wash, all fading with the overlay so
	# the reveal -> dismiss transition does not pop the background.
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, DIM_ALPHA_MAX * out_fade))
	var portal: Texture2D = _get_portal_texture()
	if portal != null and portal.get_width() > 1:
		var breath: float = sin(t * TAU * 0.16)
		var min_dim: float = minf(view_size.x, view_size.y)
		_blit_portal(canvas, portal, center, min_dim * (1.58 + breath * 0.014), Color(0.80, 0.95, 1.0, 0.24 * out_fade))
		_blit_portal(canvas, portal, center, min_dim * (1.28 + breath * 0.024), Color(1.0, 1.0, 1.0, 0.54 * out_fade))
	canvas.draw_circle(center, view_size.length() * 0.30, Color(OCEAN_GLOW.r, OCEAN_GLOW.g, OCEAN_GLOW.b, 0.14 * out_fade))

	# Exit action frame: play 0..N over the action portion, then hold the last frame.
	var action_t: float = clampf(dismiss_progress / maxf(0.01, DISMISS_ACTION_PORTION), 0.0, 1.0)
	var sheet: Texture2D = _cutin_dismiss_sheet
	if sheet != null and sheet.get_width() > 1:
		var cols: int = maxi(1, CUTIN_DISMISS_COLS)
		var rows: int = maxi(1, CUTIN_DISMISS_ROWS)
		var cw: float = float(sheet.get_width()) / float(cols)
		var ch: float = float(sheet.get_height()) / float(rows)
		if cw > 1.0 and ch > 1.0:
			var frame: int = clampi(int(action_t * float(CUTIN_DISMISS_FRAMES)), 0, CUTIN_DISMISS_FRAMES - 1)
			var col: int = frame % cols
			var row: int = int(floor(float(frame) / float(cols)))
			var src := Rect2(float(col) * cw, float(row) * ch, cw, ch)
			var target_h: float = view_size.y * _get_cutin_dismiss_view_h_ratio()
			var scale: float = target_h / ch
			var max_w: float = view_size.x * 0.98
			if cw * scale > max_w:
				scale = max_w / cw
			var dw: float = cw * scale
			var dh: float = ch * scale
			var pos := Vector2(center.x - dw * 0.5, center.y - dh * 0.5)
			var char_radius: float = dh * 0.31
			_draw_art_aura(canvas, center, char_radius * 1.18, t, out_fade, 1.0)
			canvas.draw_circle(center, char_radius, Color(OCEAN_GLOW.r, OCEAN_GLOW.g, OCEAN_GLOW.b, 0.18 * out_fade))
			canvas.draw_texture_rect_region(sheet, Rect2(pos, Vector2(dw, dh)), src, Color(1.0, 1.0, 1.0, out_fade))
			# (Removed) The old turquoise mouth/spear-tip water spray read as an
			# awkward "water cannon from the mouth". The dismiss is now a spear
			# swing flourish (sheet motion only), so no procedural spray overlay.

	# Keep the title under the action, fading out with the overlay.
	_draw_dismiss_title(canvas, view_size, out_fade)


func _draw_dismiss_spray(canvas: CanvasItem, origin: Vector2, view_size: Vector2, action_t: float, out_fade: float, t: float) -> void:
	# A turquoise water-spray burst that swells as the spear reaches its apex and
	# disperses after, sitting on top of the sheet's own spray for extra punch.
	var sp: float = clampf((action_t - (DISMISS_SPRAY_PEAK - 0.16)) / 0.40, 0.0, 1.0)
	var intensity: float = sin(sp * PI) * out_fade
	if intensity <= 0.02:
		return
	var max_r: float = view_size.y * 0.20
	var r: float = lerpf(view_size.y * 0.03, max_r, sp)
	# Expanding ring shockwave.
	canvas.draw_arc(origin, r, 0.0, TAU, 40, Color(RESONANCE.r, RESONANCE.g, RESONANCE.b, intensity * 0.55), maxf(2.0, view_size.y * 0.005), true)
	canvas.draw_arc(origin, r * 0.78, 0.0, TAU, 36, Color(0.92, 1.0, 1.0, intensity * 0.32), maxf(1.5, view_size.y * 0.003), true)
	# Upward / outward droplet streaks.
	for i in 14:
		var ang: float = -PI * 0.5 + (float(i) / 14.0 - 0.5) * PI * 1.15 + sin(t * 3.0 + float(i)) * 0.05
		var dir := Vector2(cos(ang), sin(ang))
		var streak_r: float = r * (0.72 + 0.28 * _hash01(i, 3, 41))
		var tip: Vector2 = origin + dir * streak_r
		var tail: Vector2 = origin + dir * streak_r * 0.66
		var a: float = intensity * (0.45 + 0.4 * _hash01(i, 7, 53))
		canvas.draw_line(tail, tip, Color(OCEAN_GLOW.r, OCEAN_GLOW.g, OCEAN_GLOW.b, a), maxf(1.5, view_size.y * 0.0035), true)
		canvas.draw_circle(tip, maxf(1.5, view_size.y * 0.005 * (0.6 + 0.6 * sp)), Color(0.86, 1.0, 1.0, a))
	# Bright core flash at the spear tip.
	canvas.draw_circle(origin, maxf(2.0, view_size.y * 0.018 * (1.0 - sp)), Color(0.95, 1.0, 1.0, intensity * 0.7))


func _draw_dismiss_title(canvas: CanvasItem, view_size: Vector2, out_fade: float) -> void:
	var title_size_px: int = int(view_size.y * 0.072)
	var title_dim: Vector2 = TITLE_FONT.get_string_size(_title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size_px)
	var title_pos := Vector2((view_size.x - title_dim.x) * 0.5, view_size.y * 0.80)
	canvas.draw_string(TITLE_FONT, title_pos + Vector2(2, 2), _title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size_px, Color(0.0, 0.05, 0.10, 0.55 * out_fade))
	canvas.draw_string(TITLE_FONT, title_pos, _title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size_px, Color(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b, out_fade))


func _draw_art_static(
	canvas: CanvasItem,
	view_size: Vector2,
	t: float,
	entrance: float,
	rise_raw: float,
	alpha: float,
	restore_progress: float
) -> void:
	# Main crisp-art path: animate the original illustration with continuous
	# runtime motion (no frame stepping and no draw_set_transform).
	if _cutin_art == null:
		return
	var art_size: Vector2 = _cutin_art.get_size()
	if art_size.x <= 1.0 or art_size.y <= 1.0:
		return
	var target_h: float = view_size.y * STATIC_ART_VIEW_H_RATIO
	var scale_factor: float = target_h / art_size.y
	var max_w: float = view_size.x * STATIC_ART_MAX_W_RATIO
	if art_size.x * scale_factor > max_w:
		scale_factor = max_w / art_size.x
	var base_size: Vector2 = art_size * scale_factor
	var breathe: float = sin(t * TAU * STATIC_ART_BREATH_HZ)
	var pulse_scale: float = 1.0 + breathe * STATIC_ART_SCALE_PULSE
	var draw_size: Vector2 = base_size * entrance * pulse_scale
	var settle_center_y: float = view_size.y * 0.42
	var enter_offset: float = lerpf(view_size.y * 0.14, 0.0, _ease_out_cubic(rise_raw))
	var bob_y: float = sin(t * TAU * 0.36) * view_size.y * 0.004
	var feet_y: float = settle_center_y + base_size.y * 0.5 + enter_offset + bob_y
	var sway_x: float = sin(t * TAU * 0.31) * view_size.x * 0.010
	var pos := Vector2(view_size.x * 0.5 - draw_size.x * 0.5 + sway_x, feet_y - draw_size.y)
	var center := Vector2(pos.x + draw_size.x * 0.5, pos.y + draw_size.y * 0.5)
	var glow_alpha: float = (0.22 + 0.08 * breathe) * alpha
	_draw_art_aura(canvas, center, maxf(draw_size.x, draw_size.y) * 0.5, t, alpha, rise_raw)
	canvas.draw_circle(center, draw_size.y * 0.46, Color(OCEAN_GLOW.r, OCEAN_GLOW.g, OCEAN_GLOW.b, glow_alpha))
	var art_rect := Rect2(pos, draw_size)
	_draw_restoring_texture(canvas, _cutin_art, Rect2(Vector2.ZERO, art_size), art_rect, t, alpha, restore_progress)
	if restore_progress >= 0.72:
		_draw_art_shimmer(canvas, art_rect, alpha, t)


func _draw_restoring_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	src_rect: Rect2,
	art_rect: Rect2,
	t: float,
	alpha: float,
	restore_progress: float
) -> void:
	if texture == null or art_rect.size.x <= 1.0 or art_rect.size.y <= 1.0:
		return
	if restore_progress < RESTORE_SOLID_START:
		# Digital reconstruction: scattered code-data shards converge, a chromatic
		# hologram densifies, then a scan-printer solidifies the art bottom-to-top.
		_draw_data_restore_stream(canvas, art_rect, t, alpha, restore_progress)
		_draw_code_glyph_stream(canvas, art_rect, t, alpha, restore_progress)
		_draw_holo_ghost(canvas, texture, src_rect, art_rect, t, alpha, restore_progress)
		_draw_voxel_assembly(canvas, texture, src_rect, art_rect, t, alpha, restore_progress)
		_draw_scanline_print(canvas, texture, src_rect, art_rect, t, alpha, restore_progress)
		return
	# Locked solid: full art + a quick chromatic settle + completion shockwave.
	canvas.draw_texture_rect_region(texture, art_rect, src_rect, Color(1.0, 1.0, 1.0, alpha))
	var settle: float = 1.0 - _smoothstep_range(RESTORE_SOLID_START, 1.0, restore_progress)
	if settle > 0.01:
		var jx: float = art_rect.size.x * 0.012 * settle
		canvas.draw_texture_rect_region(texture, Rect2(art_rect.position + Vector2(-jx, 0.0), art_rect.size), src_rect, Color(1.0, 0.22, 0.30, alpha * 0.32 * settle))
		canvas.draw_texture_rect_region(texture, Rect2(art_rect.position + Vector2(jx, 0.0), art_rect.size), src_rect, Color(0.24, 0.92, 1.0, alpha * 0.32 * settle))
	_draw_completion_burst(canvas, art_rect, t, alpha, restore_progress)


func _draw_holo_ghost(
	canvas: CanvasItem,
	texture: Texture2D,
	src_rect: Rect2,
	art_rect: Rect2,
	t: float,
	alpha: float,
	restore_progress: float
) -> void:
	# Cyan/magenta chromatic hologram of the full art that densifies as the data
	# shards assemble. Texture-modulated, so the transparent cell padding stays
	# empty (no rectangular box residue in the margins).
	var holo: float = _smoothstep_range(0.12, RESTORE_VOXEL_LAND, restore_progress)
	if holo <= 0.01:
		return
	var flicker: float = 0.82 + 0.18 * sin(t * 26.0 + restore_progress * 12.0)
	var base_a: float = alpha * holo * 0.5 * flicker
	if base_a <= 0.01:
		return
	var split: float = art_rect.size.x * 0.010 * (1.0 - holo)
	canvas.draw_texture_rect_region(texture, Rect2(art_rect.position + Vector2(-split, 0.0), art_rect.size), src_rect, Color(DATA_HOT.r, DATA_HOT.g, DATA_HOT.b, base_a))
	canvas.draw_texture_rect_region(texture, Rect2(art_rect.position + Vector2(split, 0.0), art_rect.size), src_rect, Color(DATA_MAGENTA.r, DATA_MAGENTA.g, DATA_MAGENTA.b, base_a * 0.5))
	canvas.draw_texture_rect_region(texture, art_rect, src_rect, Color(DATA_CORE.r, DATA_CORE.g, DATA_CORE.b, base_a * 0.7))


func _draw_voxel_assembly(
	canvas: CanvasItem,
	texture: Texture2D,
	src_rect: Rect2,
	art_rect: Rect2,
	t: float,
	alpha: float,
	restore_progress: float
) -> void:
	# Texture-carrying data shards fly in from scattered VR-space positions and
	# snap into their grid slots, leaving glowing cube edges + motion trails.
	# Shards below the rising scan-printer line are already solid, so skip them.
	var cols: int = maxi(1, RESTORE_VOXEL_COLS)
	var rows: int = maxi(1, RESTORE_VOXEL_ROWS)
	var cell_src := Vector2(src_rect.size.x / float(cols), src_rect.size.y / float(rows))
	var cell_dst := Vector2(art_rect.size.x / float(cols), art_rect.size.y / float(rows))
	var print_phase: float = _smoothstep_range(RESTORE_PRINT_START, RESTORE_PRINT_END, restore_progress)
	var scan_frac: float = 2.0
	if print_phase > 0.0:
		scan_frac = _recon_scan_frac(print_phase)
	for gy in rows:
		var cell_yfrac: float = (float(gy) + 0.5) / float(rows)
		if cell_yfrac > scan_frac:
			continue
		for gx in cols:
			# Build only over Maribo's silhouette. Cells outside the baked alpha
			# mask are transparent padding; drawing shards/bevels/flashes there
			# would read as a "restoring box" instead of "restoring Maribo".
			if not _cell_visible(gx, gy):
				continue
			var order: float = _hash01(gx, gy, 13)
			var start: float = order * 0.42
			var local: float = clampf((restore_progress - start) / maxf(0.01, RESTORE_VOXEL_LAND - start), 0.0, 1.0)
			if local >= 1.0:
				continue
			var eased: float = _ease_out_cubic(local)
			var src := Rect2(src_rect.position + Vector2(cell_src.x * float(gx), cell_src.y * float(gy)), cell_src)
			var slot_center := art_rect.position + Vector2(cell_dst.x * (float(gx) + 0.5), cell_dst.y * (float(gy) + 0.5))
			var scatter: Vector2 = _restore_fragment_scatter(gx, gy, art_rect)
			var jitter := Vector2(sin(t * 8.0 + order * 17.0), cos(t * 7.1 + order * 23.0)) * art_rect.size.y * 0.006 * (1.0 - eased)
			var cur := slot_center + scatter * (1.0 - eased) + jitter
			var sscale: float = lerpf(0.16, 1.0, eased)
			var dst := Rect2(cur - cell_dst * sscale * 0.5, cell_dst * sscale)
			var a: float = alpha * clampf(local * 2.2, 0.0, 1.0)
			if a <= 0.02:
				continue
			# Motion trail behind the shard (toward where it came from).
			var to_slot := slot_center - cur
			if to_slot.length() > 1.0 and eased < 0.92:
				var tail_dir := -to_slot.normalized()
				var tail_len: float = minf(cell_dst.x, cell_dst.y) * lerpf(2.6, 0.2, eased)
				canvas.draw_line(cur, cur + tail_dir * tail_len, Color(DATA_HOT.r, DATA_HOT.g, DATA_HOT.b, a * 0.45), maxf(1.0, dst.size.y * 0.16), true)
			# Textured shard, tinted cyan in flight and resolving to true color.
			var tint: Color = DATA_HOT.lerp(Color(1.0, 1.0, 1.0, 1.0), eased)
			canvas.draw_texture_rect_region(texture, dst, src, Color(tint.r, tint.g, tint.b, a))
			# Cube bevel: bright top/left, dim bottom/right.
			var ew: float = maxf(1.0, dst.size.y * 0.07)
			canvas.draw_line(dst.position, dst.position + Vector2(dst.size.x, 0.0), Color(DATA_CORE.r, DATA_CORE.g, DATA_CORE.b, a * 0.9), ew, true)
			canvas.draw_line(dst.position, dst.position + Vector2(0.0, dst.size.y), Color(DATA_CORE.r, DATA_CORE.g, DATA_CORE.b, a * 0.7), ew, true)
			canvas.draw_line(dst.position + Vector2(0.0, dst.size.y), dst.end, Color(GRID_COLOR.r, GRID_COLOR.g, GRID_COLOR.b, a * 0.5), ew, true)
			canvas.draw_line(dst.position + Vector2(dst.size.x, 0.0), dst.end, Color(GRID_COLOR.r, GRID_COLOR.g, GRID_COLOR.b, a * 0.5), ew, true)
			# Snap flash at the instant the shard locks into its slot.
			if local > 0.82:
				var snap: float = (local - 0.82) / 0.18
				var snap_a: float = alpha * (1.0 - snap) * 0.8
				var slot_rect := Rect2(slot_center - cell_dst * 0.5, cell_dst)
				canvas.draw_rect(slot_rect, Color(DATA_CORE.r, DATA_CORE.g, DATA_CORE.b, snap_a), false, maxf(1.0, cell_dst.y * 0.12))


func _draw_scanline_print(
	canvas: CanvasItem,
	texture: Texture2D,
	src_rect: Rect2,
	art_rect: Rect2,
	t: float,
	alpha: float,
	restore_progress: float
) -> void:
	# A bright scanner sweeps feet->head, "printing" the solid art below it with a
	# chromatic-split fresh edge, while the hologram remains above the line.
	var print_phase: float = _smoothstep_range(RESTORE_PRINT_START, RESTORE_PRINT_END, restore_progress)
	if print_phase <= 0.0:
		return
	var scan_frac: float = _recon_scan_frac(print_phase)
	var solid_top: float = clampf(scan_frac, 0.0, 1.0)
	# Solid (printed) region below the scan line. Texture-modulated, so the
	# transparent padding outside Maribo stays empty (no box edge).
	if solid_top < 1.0:
		_draw_texture_band(canvas, texture, src_rect, art_rect, solid_top, 1.0, Color(1.0, 1.0, 1.0, alpha))
	# Chromatic-split fresh edge just below the line.
	var eb_top: float = clampf(scan_frac, 0.0, 1.0)
	var eb_bot: float = clampf(scan_frac + 0.05, 0.0, 1.0)
	if eb_bot > eb_top:
		var split: float = art_rect.size.x * 0.012 * (1.0 - print_phase * 0.4)
		_draw_texture_band(canvas, texture, src_rect, Rect2(art_rect.position + Vector2(-split, 0.0), art_rect.size), eb_top, eb_bot, Color(1.0, 0.22, 0.30, alpha * 0.5))
		_draw_texture_band(canvas, texture, src_rect, Rect2(art_rect.position + Vector2(split, 0.0), art_rect.size), eb_top, eb_bot, Color(0.24, 0.92, 1.0, alpha * 0.5))
	# Bright scan line + glow + travelling sparks, clamped to the character bbox so
	# the geometric beam reads as scanning Maribo, not a full-frame rectangle bar.
	var bx0: float = (art_rect.position.x + art_rect.size.x * _recon_bbox.position.x) if _recon_ready else art_rect.position.x
	var bx1: float = (art_rect.position.x + art_rect.size.x * (_recon_bbox.position.x + _recon_bbox.size.x)) if _recon_ready else (art_rect.position.x + art_rect.size.x)
	var by0: float = _recon_bbox.position.y if _recon_ready else 0.0
	var by1: float = (_recon_bbox.position.y + _recon_bbox.size.y) if _recon_ready else 1.0
	if scan_frac >= by0 - 0.06 and scan_frac <= by1 + 0.06:
		var ly: float = art_rect.position.y + art_rect.size.y * clampf(scan_frac, 0.0, 1.0)
		var span: float = maxf(1.0, bx1 - bx0)
		var pulse: float = 0.6 + 0.4 * sin(t * 30.0)
		canvas.draw_line(Vector2(bx0, ly), Vector2(bx1, ly), Color(DATA_HOT.r, DATA_HOT.g, DATA_HOT.b, alpha * 0.30 * pulse), maxf(3.0, art_rect.size.y * 0.018), true)
		canvas.draw_line(Vector2(bx0, ly), Vector2(bx1, ly), Color(DATA_CORE.r, DATA_CORE.g, DATA_CORE.b, alpha * 0.92), maxf(1.5, art_rect.size.y * 0.005), true)
		for s in 5:
			var sx: float = bx0 + span * fposmod(_hash01(s, 4, 53) + t * 0.6, 1.0)
			var sa: float = alpha * (0.4 + 0.5 * sin(t * 18.0 + float(s)))
			if sa > 0.05:
				canvas.draw_circle(Vector2(sx, ly), maxf(1.5, art_rect.size.y * 0.006), Color(DATA_CORE.r, DATA_CORE.g, DATA_CORE.b, sa))


func _draw_texture_band(
	canvas: CanvasItem,
	texture: Texture2D,
	src_rect: Rect2,
	art_rect: Rect2,
	y_top: float,
	y_bottom: float,
	modulate: Color
) -> void:
	# Draws the [y_top, y_bottom] vertical slice (height fractions measured from
	# the top) of the texture into the matching slice of art_rect.
	if y_bottom <= y_top or modulate.a <= 0.0:
		return
	var src := Rect2(
		src_rect.position.x,
		src_rect.position.y + src_rect.size.y * y_top,
		src_rect.size.x,
		src_rect.size.y * (y_bottom - y_top)
	)
	var dst := Rect2(
		art_rect.position.x,
		art_rect.position.y + art_rect.size.y * y_top,
		art_rect.size.x,
		art_rect.size.y * (y_bottom - y_top)
	)
	canvas.draw_texture_rect_region(texture, dst, src, modulate)


func _recon_scan_frac(print_phase: float) -> float:
	# The scan-printer sweeps the character's vertical extent (feet -> head),
	# not the full transparent-padded cell, so the beam reads as scanning Maribo.
	# Voxel assembly and the scanline share this so their boundaries stay in sync.
	var by0: float = 0.0
	var by1: float = 1.0
	if _recon_ready:
		by0 = _recon_bbox.position.y
		by1 = _recon_bbox.position.y + _recon_bbox.size.y
	return lerpf(by1 + 0.05, by0 - 0.05, clampf(print_phase, 0.0, 1.0))


func _cell_visible(gx: int, gy: int) -> bool:
	# True when the reconstruction voxel cell overlaps Maribo's baked silhouette.
	if _recon_ready and _recon_cols == RESTORE_VOXEL_COLS and _recon_rows == RESTORE_VOXEL_ROWS:
		return _recon_filled[gy * _recon_cols + gx] != 0
	# Fallback (no baked mask): cull corners/edges with a centered ellipse so the
	# assembly never reads as a full rectangle even without the manifest.
	var nx: float = (float(gx) + 0.5) / float(RESTORE_VOXEL_COLS) * 2.0 - 1.0
	var ny: float = (float(gy) + 0.5) / float(RESTORE_VOXEL_ROWS) * 2.0 - 1.0
	return (nx * nx) / (0.90 * 0.90) + (ny * ny) / (0.98 * 0.98) <= 1.0


func _draw_data_restore_stream(canvas: CanvasItem, art_rect: Rect2, t: float, alpha: float, restore_progress: float) -> void:
	var gather: float = _ease_out_cubic(restore_progress)
	var center: Vector2 = art_rect.get_center()
	for i in RESTORE_DATA_BIT_COUNT:
		var seed_value: float = _hash01(i, 7, 41)
		var target := Vector2(
			art_rect.position.x + art_rect.size.x * _hash01(i, 2, 59),
			art_rect.position.y + art_rect.size.y * _hash01(i, 3, 67)
		)
		var angle: float = seed_value * TAU + t * (0.14 + 0.10 * _hash01(i, 5, 71))
		var distance: float = art_rect.size.length() * lerpf(0.42, 0.96, _hash01(i, 11, 83))
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * distance
		var drift := Vector2(sin(t * 4.0 + seed_value * 11.0), cos(t * 3.5 + seed_value * 13.0)) * art_rect.size.y * 0.012
		var pos: Vector2 = start.lerp(target, gather) + drift * (1.0 - gather)
		var bit_alpha: float = alpha * (1.0 - _smoothstep_range(0.74, 1.0, restore_progress)) * (0.35 + 0.45 * _hash01(i, 17, 97))
		if bit_alpha <= 0.02:
			continue
		var bit_len: float = maxf(3.0, art_rect.size.y * lerpf(0.010, 0.022, _hash01(i, 23, 101)))
		var bit_h: float = maxf(1.5, art_rect.size.y * 0.004)
		canvas.draw_rect(Rect2(pos, Vector2(bit_len, bit_h)), Color(RESTORE_FRAGMENT_COLOR.r, RESTORE_FRAGMENT_COLOR.g, RESTORE_FRAGMENT_COLOR.b, bit_alpha))
		if i % 4 == 0:
			var tail_dir: Vector2 = (target - pos).normalized()
			canvas.draw_line(pos - tail_dir * bit_len * 1.6, pos, Color(0.82, 1.0, 1.0, bit_alpha * 0.55), maxf(1.0, bit_h), true)


func _draw_code_glyph_stream(canvas: CanvasItem, art_rect: Rect2, t: float, alpha: float, restore_progress: float) -> void:
	# A handful of hex / binary glyphs spiral inward toward the forming body,
	# selling the "made of code-data" concept. Fades out before the lock-in.
	var fade: float = 1.0 - _smoothstep_range(0.70, RESTORE_SOLID_START, restore_progress)
	if fade <= 0.02:
		return
	var gather: float = _ease_out_cubic(restore_progress)
	var center: Vector2 = art_rect.get_center()
	var glyph_px: int = maxi(8, int(art_rect.size.y * 0.026))
	var token_n: int = RESTORE_GLYPH_TOKENS.size()
	for i in RESTORE_CODE_GLYPH_COUNT:
		var seed_value: float = _hash01(i, 9, 61)
		var target := Vector2(
			art_rect.position.x + art_rect.size.x * _hash01(i, 2, 73),
			art_rect.position.y + art_rect.size.y * _hash01(i, 3, 79)
		)
		var angle: float = seed_value * TAU + t * (0.4 + 0.5 * _hash01(i, 5, 83))
		var distance: float = art_rect.size.length() * lerpf(0.30, 0.78, _hash01(i, 7, 89))
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * distance
		var pos: Vector2 = start.lerp(target, gather)
		var ga: float = alpha * fade * (0.30 + 0.40 * _hash01(i, 13, 91))
		if ga <= 0.03:
			continue
		var token: String = RESTORE_GLYPH_TOKENS[i % token_n]
		canvas.draw_string(TITLE_FONT, pos, token, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_px, Color(DATA_HOT.r, DATA_HOT.g, DATA_HOT.b, ga))


func _draw_completion_burst(canvas: CanvasItem, art_rect: Rect2, t: float, alpha: float, restore_progress: float) -> void:
	var burst: float = _smoothstep_range(RESTORE_SOLID_START, 1.0, restore_progress)
	var center: Vector2 = art_rect.get_center()
	# Expanding chromatic shockwave ring at the lock-in moment.
	var fade: float = 1.0 - burst
	if fade > 0.01:
		var max_r: float = art_rect.size.length() * 0.5
		var r: float = lerpf(art_rect.size.y * 0.14, max_r, burst)
		var ring_a: float = fade * alpha * 0.8
		var rw: float = maxf(2.0, art_rect.size.y * 0.01)
		canvas.draw_arc(center, r, 0.0, TAU, 56, Color(DATA_CORE.r, DATA_CORE.g, DATA_CORE.b, ring_a), rw, true)
		canvas.draw_arc(center, r * 1.04, 0.0, TAU, 56, Color(DATA_HOT.r, DATA_HOT.g, DATA_HOT.b, ring_a * 0.45), rw * 0.6, true)
		for i in 14:
			var ang: float = (float(i) / 14.0) * TAU + t * 0.5
			var sp: Vector2 = center + Vector2(cos(ang), sin(ang)) * r * (0.86 + 0.1 * sin(t * 6.0 + float(i)))
			canvas.draw_circle(sp, maxf(1.5, art_rect.size.y * 0.006), Color(DATA_CORE.r, DATA_CORE.g, DATA_CORE.b, ring_a))
	# Lingering idle data-motes over the locked art (kept to the central band).
	var idle_a: float = alpha * (0.18 + 0.12 * sin(t * 3.0)) * (1.0 - burst * 0.5)
	if idle_a > 0.02:
		for i in 8:
			var seed_value: float = _hash01(i, 19, 127)
			var p := Vector2(
				art_rect.position.x + art_rect.size.x * (0.22 + 0.56 * _hash01(i, 29, 131)),
				art_rect.position.y + art_rect.size.y * (0.18 + 0.62 * _hash01(i, 31, 137))
			)
			var tw: float = 0.5 + 0.5 * sin(t * 7.0 + seed_value * TAU)
			canvas.draw_circle(p, maxf(1.2, art_rect.size.y * 0.005 * tw), Color(DATA_CORE.r, DATA_CORE.g, DATA_CORE.b, idle_a * tw))


func _restore_fragment_scatter(gx: int, gy: int, art_rect: Rect2) -> Vector2:
	var angle: float = _hash01(gx, gy, 151) * TAU
	var radius: float = art_rect.size.length() * lerpf(0.30, 0.78, _hash01(gx, gy, 157))
	var side_bias := Vector2(
		(_hash01(gx, gy, 163) - 0.5) * art_rect.size.x * 0.75,
		(_hash01(gx, gy, 167) - 0.5) * art_rect.size.y * 0.58
	)
	return Vector2(cos(angle), sin(angle)) * radius + side_bias


func _smoothstep_range(edge0: float, edge1: float, value: float) -> float:
	var span: float = maxf(0.0001, edge1 - edge0)
	var x: float = clampf((value - edge0) / span, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _hash01(a: int, b: int, salt: int) -> float:
	var n: float = sin(float(a * 127 + b * 311 + salt * 743)) * 43758.5453123
	return fposmod(n, 1.0)


func _ease_out_back(t: float) -> float:
	# Overshoot ease: rises past 1.0 then settles back, giving the entrance a
	# punchy "pop" instead of a flat zoom.
	var c: float = clampf(t, 0.0, 1.0)
	var s := 1.70158
	var u: float = c - 1.0
	return 1.0 + (s + 1.0) * pow(u, 3.0) + s * pow(u, 2.0)


func _draw_art_aura(canvas: CanvasItem, center: Vector2, radius: float, t: float, alpha: float, entrance: float) -> void:
	if radius <= 1.0 or alpha <= 0.0:
		return
	# Strong on entrance, then a calmer steady idle aura.
	var intensity: float = (0.45 + 0.55 * (1.0 - clampf(entrance, 0.0, 1.0))) * alpha
	var base_r: float = radius * 0.92
	for ring_index in 3:
		var ring_t: float = float(ring_index) / 2.0
		var spin: float = t * (0.8 + ring_t * 0.6) + ring_t * 1.7
		var r: float = base_r * (0.78 + ring_t * 0.26 + 0.03 * sin(t * 3.0 + ring_t))
		var ring_alpha: float = intensity * (0.42 - ring_t * 0.10)
		var col: Color = OCEAN_GLOW.lerp(RESONANCE, ring_t)
		canvas.draw_arc(center, r, spin, spin + TAU * 0.66, 44, Color(col.r, col.g, col.b, ring_alpha), maxf(2.0, radius * 0.02), true)
		canvas.draw_arc(center, r * 0.7, -spin * 0.9, -spin * 0.9 + TAU * 0.5, 36, Color(0.92, 1.0, 1.0, ring_alpha * 0.6), maxf(1.5, radius * 0.012), true)
	# Orbiting energy motes.
	for mote_index in 10:
		var mote_t: float = float(mote_index) / 10.0
		var angle: float = mote_t * TAU + t * (1.4 + float(mote_index % 3) * 0.25)
		var orbit: float = base_r * (0.92 + 0.10 * sin(t * 2.0 + mote_index))
		var mote_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * orbit
		var mote_alpha: float = intensity * (0.35 + 0.35 * sin(mote_t * PI + t * 2.0))
		if mote_alpha <= 0.02:
			continue
		canvas.draw_circle(mote_pos, maxf(1.5, radius * 0.012), Color(0.85, 1.0, 0.98, mote_alpha))


func _draw_art_shimmer(canvas: CanvasItem, art_rect: Rect2, alpha: float, t: float) -> void:
	# Cheap "living artwork" sparkle: a few cyan glints drifting up over the
	# illustration (concentrated around the spear / upper body) plus a slow
	# diagonal light sweep. Pure additive-feel dots, no per-frame allocation.
	var sparkle_count := 6
	for i in sparkle_count:
		var seed_f: float = float(i) * 1.37
		var phase: float = fposmod(t * 0.35 + seed_f, 1.0)
		var col_x: float = art_rect.position.x + art_rect.size.x * (0.20 + 0.62 * fposmod(seed_f * 0.61, 1.0))
		var sy: float = art_rect.position.y + art_rect.size.y * (0.92 - 0.74 * phase)
		var twinkle: float = sin((t * 6.0 + seed_f) * TAU)
		var sa: float = clampf((0.5 - absf(phase - 0.5)) * 2.0, 0.0, 1.0) * (0.35 + 0.35 * twinkle) * alpha
		if sa <= 0.02:
			continue
		var radius: float = art_rect.size.y * (0.006 + 0.004 * maxf(0.0, twinkle))
		canvas.draw_circle(Vector2(col_x, sy), radius, Color(0.80, 1.0, 0.98, sa))
	# Slow diagonal light sweep across the upper body.
	var sweep: float = fposmod(t * 0.18, 1.0)
	var sweep_x: float = art_rect.position.x + art_rect.size.x * lerpf(-0.1, 1.1, sweep)
	var band_alpha: float = (0.10 * (0.5 - absf(sweep - 0.5)) * 2.0) * alpha
	if band_alpha > 0.01:
		var w: float = art_rect.size.x * 0.10
		var top := Vector2(sweep_x, art_rect.position.y + art_rect.size.y * 0.10)
		var bottom := Vector2(sweep_x - art_rect.size.x * 0.12, art_rect.position.y + art_rect.size.y * 0.62)
		canvas.draw_line(top, bottom, Color(0.85, 1.0, 1.0, band_alpha), maxf(2.0, w * 0.25), true)


func _draw_title(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	if progress < TEXT_START:
		return
	var appear: float = _ease_out_cubic(clampf((progress - TEXT_START) / 0.12, 0.0, 1.0))
	var alpha: float = appear
	if alpha <= 0.0:
		return

	var title_size_px: int = int(view_size.y * 0.072)
	var title_dim: Vector2 = TITLE_FONT.get_string_size(_title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size_px)
	var slide: float = lerpf(view_size.y * 0.04, 0.0, appear)
	var title_pos := Vector2(
		(view_size.x - title_dim.x) * 0.5,
		view_size.y * 0.80 + slide
	)
	canvas.draw_string(TITLE_FONT, title_pos + Vector2(2, 2), _title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size_px, Color(0.0, 0.05, 0.10, 0.55 * alpha))
	canvas.draw_string(TITLE_FONT, title_pos, _title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size_px, Color(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b, alpha))

	var sub_size_px: int = int(view_size.y * 0.032)
	var sub_dim: Vector2 = TITLE_FONT.get_string_size(SUBTITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size_px)
	var sub_pos := Vector2(
		(view_size.x - sub_dim.x) * 0.5,
		title_pos.y + title_dim.y * 0.78
	)
	canvas.draw_string(TITLE_FONT, sub_pos + Vector2(1, 1), SUBTITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size_px, Color(0.0, 0.05, 0.10, 0.5 * alpha))
	canvas.draw_string(TITLE_FONT, sub_pos, SUBTITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size_px, Color(0.86, 0.97, 1.0, 0.92 * alpha))


func _draw_flash(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	# One brief bright resonance flash as the title locks in (a short window after
	# TEXT_START). No auto fade-out afterwards -- the cut-in holds until dismissed.
	var flash_window: float = 0.26
	if progress < TEXT_START or progress >= TEXT_START + flash_window:
		return
	var local: float = (progress - TEXT_START) / flash_window
	var flash_alpha: float = (1.0 - local) * 0.30
	if flash_alpha <= 0.0:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(RESONANCE.r, RESONANCE.g, RESONANCE.b, flash_alpha))


func _draw_dismiss_hint(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	# Once the reveal has finished playing, prompt the player to click to resume.
	if progress < HOLD_PROGRESS:
		return
	var pulse: float = 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) * 0.006)
	var hint_text := "클릭하여 계속"
	var hint_size_px: int = int(view_size.y * 0.028)
	var hint_dim: Vector2 = TITLE_FONT.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size_px)
	var hint_pos := Vector2(
		(view_size.x - hint_dim.x) * 0.5,
		view_size.y * 0.93
	)
	canvas.draw_string(TITLE_FONT, hint_pos + Vector2(1, 1), hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size_px, Color(0.0, 0.05, 0.10, 0.45 * pulse))
	canvas.draw_string(TITLE_FONT, hint_pos, hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size_px, Color(0.92, 1.0, 1.0, 0.5 + 0.45 * pulse))
