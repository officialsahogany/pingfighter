extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")
const DriveCutinFxHost := preload("res://scripts/hud/drive_cutin_fx_host.gd")
const SkillCutinDriveRenderer := preload("res://scripts/hud/skill_cutin_drive_renderer.gd")
const SkillCutinStandardRenderer := preload("res://scripts/hud/skill_cutin_standard_renderer.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")

const POWER_SMASHING_CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/smasher_power_smashing_cutin_sheet.png"
const GHOST_SMASHING_CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/smasher_ghost_smashing_cutin_sheet.png"
const VIPER_PHANTOM_KICK_CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/viper_phantom_kick_cutin_sheet.png"
const CUTIN_FRAME_COUNT := 16
const CUTIN_AUTOSPRITE_COLUMNS := 3
const CUTIN_STANDARD_COLUMNS := 4
const SKILL_DRIVE := "drive"
const SKILL_POWER_SMASHING := "power_smashing"
const SKILL_GHOST_SHOT := "ghost_shot"
const SKILL_SHIELD_KITING := "shield_kiting"
const SKILL_PHANTOM_KICK := "phantom_kick"

const POWER_SMASHING_COLOR := Color(1.0, 100.0 / 255.0, 50.0 / 255.0)
const GHOST_SMASHING_COLOR := Color(170.0 / 255.0, 80.0 / 255.0, 1.0)
const PHANTOM_KICK_COLOR := Color(0.84, 0.22, 1.0)
const WIPE_COLOR := Color(1.0, 100.0 / 255.0, 50.0 / 255.0, 0.85)
const GHOST_WIPE_COLOR := Color(82.0 / 255.0, 22.0 / 255.0, 128.0 / 255.0, 0.88)
const PHANTOM_WIPE_COLOR := Color(0.17, 0.0, 0.28, 0.90)
const FLASH_COLOR := Color(1.0, 0.88, 0.7, 1.0)
const GHOST_FLASH_COLOR := Color(0.74, 0.58, 1.0, 1.0)
const PHANTOM_FLASH_COLOR := Color(0.82, 0.48, 1.0, 1.0)
const CHARGE_CORE_COLOR := Color(1.0, 0.12, 0.05, 1.0)
const CHARGE_HOT_COLOR := Color(1.0, 0.55, 0.16, 1.0)
const GHOST_CHARGE_CORE_COLOR := Color(0.44, 0.10, 1.0, 1.0)
const GHOST_CHARGE_HOT_COLOR := Color(0.95, 0.48, 1.0, 1.0)
const PHANTOM_CHARGE_CORE_COLOR := Color(0.45, 0.03, 0.84, 1.0)
const PHANTOM_CHARGE_HOT_COLOR := Color(0.96, 0.38, 1.0, 1.0)

# --- Drive partial-screen still cut-in -------------------------------------
# Reuses the prewarmed Mika power-smash sheet (one fixed frame as a still) and
# slides it in from the LEFT as a non-freezing, non-dimming hero portrait while
# the rally keeps playing. Tunables are grouped so the pose/size/placement can be
# retuned from one spot after an in-game look.
const DRIVE_TITLE_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const DRIVE_TITLE_TEXT := "드라이브"
const DRIVE_COLOR := Color(0.22, 0.95, 1.0)
const DRIVE_ACCENT_HOT := Color(1.0, 0.78, 0.24)
# Dedicated AutoSprite "Drive Strike" pose (Mika, cyan curve-energy), nukki'd to
# transparent. Replaces the reused power-smash sheet frame as the portrait.
const DRIVE_CHARACTER_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_character.png"
const DRIVE_CUTIN_FX_HOST_NAME := "SmasherDriveCutinFxHost"
const DRIVE_PORTRAIT_HEIGHT_RATIO := 0.30    # upper-body pose draw height vs view height
const DRIVE_PORTRAIT_CENTER_X_RATIO := 0.075 # face anchor screen x (0..1) — keep the whole cut-in in the left corner
const DRIVE_PORTRAIT_CENTER_Y_RATIO := 0.135 # face anchor screen y (0..1)
const DRIVE_PORTRAIT_CHAR_CENTER := Vector2(0.30, 0.26)  # face anchor point within the upper-body texture
const DRIVE_VFX_CENTER_X_RATIO := 0.17       # backplate/arc center x (behind the character mass, NOT the far-left face)

# 3-piece modular VFX (light=ADD via writhe-ember shader). Backplate + arc are
# immediate-mode textured draws BEHIND the portrait (correct layering needs them
# in the same _draw pass before the portrait, so they cannot be child nodes); the
# writhe-ember shader is applied via the documented canvas.material set/restore
# pass (NOT draw_set_transform). The particle layer is a GPUParticles2D node
# (drive_cutin_fx_host.gd) rendered in front. Cyan/teal drive energy with warm
# gold accents so the VFX reads as one unit with Mika's racket trail.
const DRIVE_BACKPLATE_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_backplate.png"
const DRIVE_ARC_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_arc.png"
const DRIVE_TRIANGLE_TOP_LEFT := Vector2(0.000, -0.045)
const DRIVE_TRIANGLE_TOP_RIGHT := Vector2(0.360, -0.030)
const DRIVE_TRIANGLE_BOTTOM_LEFT := Vector2(0.000, 0.485)
const DRIVE_BACKPLATE_SIZE_RATIO := 0.34      # backplate square size vs view height
const DRIVE_BACKPLATE_CENTER_Y_RATIO := 0.15  # backplate center-y on screen
const DRIVE_ARC_SIZE_RATIO := 0.30            # arc square size vs view height
const DRIVE_ARC_CENTER_Y_RATIO := 0.14        # arc center-y on screen
const DRIVE_ARC_SPIN_SPEED := 0.55            # radians/sec slow spin
const DRIVE_WRITHE_PRESET := "drive_cutin"
const DRIVE_WRITHE_PRESET_ENRAGED := "drive_cutin_enraged"
const DRIVE_SLIDE_DISTANCE_RATIO := 0.55      # horizontal slide travel vs view width

var _prewarmed: bool = false
var _cutin_sheet_textures: Dictionary = {}
var _cutin_sheet_grids: Dictionary = {}
var _drive_textures: Dictionary = {}
var _drive_writhe_material: ShaderMaterial = null
var _drive_writhe_material_enraged: ShaderMaterial = null
var _smasher_title_skill_config: Object = null
var _viper_title_skill_config: Object = null


func prewarm_assets() -> void:
	prewarm_assets_for_character("")


func prewarm_assets_for_character(character_type: String = "") -> void:
	var normalized_character: String = character_type.strip_edges().to_lower()
	_prewarmed = true
	if normalized_character.is_empty() or normalized_character == "smasher":
		_prewarm_cutin_sheet_texture(POWER_SMASHING_CUTIN_SHEET_PATH, "Smasher power-smashing")
		_prewarm_cutin_sheet_texture(GHOST_SMASHING_CUTIN_SHEET_PATH, "Smasher ghost-smashing")
	if normalized_character.is_empty() or normalized_character == "viper":
		_prewarm_cutin_sheet_texture(VIPER_PHANTOM_KICK_CUTIN_SHEET_PATH, "Viper phantom-kick")
	# Drive cut-in 3-piece VFX: warm the 2 immediate-mode textures + the writhe-ember
	# materials so the first drive never sync-loads art / compiles a shader on the
	# draw hot path. The particle layer node prewarms itself (DriveCutinFxHost).
	if normalized_character.is_empty() or normalized_character == "smasher":
		_get_drive_texture(DRIVE_BACKPLATE_PATH)
		_get_drive_texture(DRIVE_ARC_PATH)
		_get_drive_texture(DRIVE_CHARACTER_PATH)
		_get_drive_texture(SkillCutinDriveRenderer.SHIELD_KITING_CHARACTER_PATH)
		_get_drive_writhe_material(false)
		_get_drive_writhe_material(true)
		DriveCutinFxHost.prewarm_assets()


func prewarm_runtime_nodes(_owner: Object = null) -> void:
	var normalized_character: String = _get_owner_character_type(_owner)
	prewarm_assets_for_character(normalized_character)
	if not normalized_character.is_empty() and normalized_character != "smasher":
		return
	if not (_owner is Node):
		return
	var parent: Node = _owner as Node
	var existing: Node = parent.get_node_or_null(DRIVE_CUTIN_FX_HOST_NAME)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		if existing.has_method("set_active"):
			existing.set_active(false)
		return
	var fx_host := DriveCutinFxHost.new()
	fx_host.name = DRIVE_CUTIN_FX_HOST_NAME
	fx_host.visible = false
	parent.add_child(fx_host)
	fx_host.set_active(false)


func _get_owner_character_type(owner: Object) -> String:
	if owner == null:
		return ""
	var selected: Variant = owner.get("selected_character_type")
	if selected == null:
		return ""
	return str(selected).strip_edges().to_lower()


func draw(canvas: CanvasItem, cutin_state: Object, view_size: Vector2) -> void:
	if canvas == null:
		return
	if cutin_state == null or not cutin_state.is_active():
		return

	var progress: float = cutin_state.get_progress()
	var phase: String = cutin_state.get_phase()
	var profile: Dictionary = _get_cutin_profile(_get_cutin_skill_name(cutin_state))
	SkillCutinStandardRenderer.draw(
		canvas,
		view_size,
		progress,
		phase,
		profile,
		Callable(self, "_get_cutin_sheet_texture"),
		Callable(self, "_get_sheet_grid"),
		Callable(self, "_get_profile_title"),
		Callable(self, "_fit_title_font_size")
	)


func _prewarm_cutin_sheet_texture(path: String, label: String) -> void:
	var texture: Texture2D = _load_cutin_sheet_texture(path, label)
	_cutin_sheet_textures[path] = texture
	_refresh_sheet_grid(path, texture)


func _load_cutin_sheet_texture(path: String, label: String) -> Texture2D:
	if (
		not FileAccess.file_exists(path)
		and not FileAccess.file_exists("%s.import" % path)
		and not ResourceLoader.exists(path)
	):
		return null
	return ProjectResourceLoader.load_imported_texture(
		path,
		"",
		"Failed to load %s cut-in sheet: %%s" % label
	)


func _refresh_sheet_grid(path: String, texture: Texture2D) -> void:
	var columns := CUTIN_AUTOSPRITE_COLUMNS
	var rows := 3
	if texture == null:
		_cutin_sheet_grids[path] = Vector2i(columns, rows)
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		_cutin_sheet_grids[path] = Vector2i(columns, rows)
		return
	if texture_size.x >= texture_size.y * 1.7:
		columns = CUTIN_STANDARD_COLUMNS
		rows = int(ceil(float(CUTIN_FRAME_COUNT) / float(columns)))
	elif absf(texture_size.x - texture_size.y) <= maxf(texture_size.x, texture_size.y) * 0.05:
		columns = CUTIN_STANDARD_COLUMNS
		rows = CUTIN_STANDARD_COLUMNS
	else:
		columns = CUTIN_AUTOSPRITE_COLUMNS
		rows = int(ceil(float(CUTIN_FRAME_COUNT) / float(columns)))
	_cutin_sheet_grids[path] = Vector2i(columns, rows)


func _get_cutin_skill_name(cutin_state: Object) -> String:
	if cutin_state != null and cutin_state.has_method("get_skill_name"):
		return str(cutin_state.get_skill_name())
	return SKILL_POWER_SMASHING


func _get_cutin_profile(skill_name: String) -> Dictionary:
	if skill_name == SKILL_GHOST_SHOT:
		return {
			"skill_name": SKILL_GHOST_SHOT,
			"title": "고스트스매싱",
			"sheet_path": GHOST_SMASHING_CUTIN_SHEET_PATH,
			"title_color": GHOST_SMASHING_COLOR,
			"wipe_color": GHOST_WIPE_COLOR,
			"flash_color": GHOST_FLASH_COLOR,
			"charge_core_color": GHOST_CHARGE_CORE_COLOR,
			"charge_hot_color": GHOST_CHARGE_HOT_COLOR,
			"sheet_modulate": Color.WHITE,
			"speed_line_color": Color(0.80, 0.64, 1.0, 1.0),
			"ghost_wisps": true,
		}
	if skill_name == SKILL_PHANTOM_KICK:
		return {
			"skill_name": SKILL_PHANTOM_KICK,
			"title": "팬텀 킥",
			"sheet_path": VIPER_PHANTOM_KICK_CUTIN_SHEET_PATH,
			"title_color": PHANTOM_KICK_COLOR,
			"wipe_color": PHANTOM_WIPE_COLOR,
			"flash_color": PHANTOM_FLASH_COLOR,
			"charge_core_color": PHANTOM_CHARGE_CORE_COLOR,
			"charge_hot_color": PHANTOM_CHARGE_HOT_COLOR,
			"sheet_modulate": Color.WHITE,
			"speed_line_color": Color(0.86, 0.44, 1.0, 1.0),
			"ghost_wisps": true,
			"charge_points": [
				Vector2(0.31, 0.55),
				Vector2(0.34, 0.54),
				Vector2(0.37, 0.53),
				Vector2(0.40, 0.52),
				Vector2(0.43, 0.51),
				Vector2(0.46, 0.50),
				Vector2(0.49, 0.49),
				Vector2(0.52, 0.48),
				Vector2(0.57, 0.49),
				Vector2(0.62, 0.50),
				Vector2(0.67, 0.51),
				Vector2(0.71, 0.52),
				Vector2(0.74, 0.53),
				Vector2(0.76, 0.54),
				Vector2(0.78, 0.55),
				Vector2(0.80, 0.56),
			],
		}
	return {
		"skill_name": SKILL_POWER_SMASHING,
		"title": "파워스매싱",
		"sheet_path": POWER_SMASHING_CUTIN_SHEET_PATH,
		"title_color": POWER_SMASHING_COLOR,
		"wipe_color": WIPE_COLOR,
		"flash_color": FLASH_COLOR,
		"charge_core_color": CHARGE_CORE_COLOR,
		"charge_hot_color": CHARGE_HOT_COLOR,
		"sheet_modulate": Color.WHITE,
		"speed_line_color": Color.WHITE,
		"ghost_wisps": false,
	}


func _get_profile_title(profile: Dictionary) -> String:
	var fallback_title: String = str(profile.get("title", "파워스매싱"))
	return _get_localized_skill_title(str(profile.get("skill_name", "")), fallback_title)


func _get_localized_skill_title(skill_name: String, fallback_title: String) -> String:
	if skill_name.is_empty():
		return fallback_title
	var skill_config: Object = _get_title_skill_config(skill_name)
	if skill_config != null and skill_config.has_method("get_skill_data"):
		var skill_data: Dictionary = skill_config.get_skill_data(skill_name)
		var title: String = str(skill_data.get("korean", ""))
		if not title.is_empty():
			return title
	return fallback_title


func _get_title_skill_config(skill_name: String) -> Object:
	if skill_name == SKILL_PHANTOM_KICK:
		if _viper_title_skill_config == null:
			_viper_title_skill_config = ViperSkillConfig.new()
		return _viper_title_skill_config
	if _smasher_title_skill_config == null:
		_smasher_title_skill_config = SmasherSkillConfig.new()
	return _smasher_title_skill_config


func _fit_title_font_size(font: Font, text: String, target_size: int, max_width: float) -> int:
	var size_px: int = max(12, target_size)
	if font == null or max_width <= 1.0:
		return size_px
	while size_px > 12 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > max_width:
		size_px -= 1
	return size_px


func _get_cutin_sheet_texture(path: String) -> Texture2D:
	if not _cutin_sheet_textures.has(path):
		_prewarm_cutin_sheet_texture(path, "Smasher skill")
	var texture: Variant = _cutin_sheet_textures.get(path, null)
	if texture is Texture2D:
		return texture
	return null


func _get_sheet_grid(path: String) -> Vector2i:
	var grid: Variant = _cutin_sheet_grids.get(path, Vector2i(CUTIN_AUTOSPRITE_COLUMNS, 3))
	if grid is Vector2i:
		return grid
	return Vector2i(CUTIN_AUTOSPRITE_COLUMNS, 3)


# --- Drive partial-screen still cut-in --------------------------------------

func draw_drive_cutin(canvas: CanvasItem, drive_cutin_state: Object, view_size: Vector2) -> void:
	SkillCutinDriveRenderer.draw_drive_cutin(
		canvas,
		drive_cutin_state,
		view_size,
		Callable(self, "_get_drive_texture"),
		Callable(self, "_get_drive_writhe_material"),
		Callable(self, "_get_localized_skill_title"),
		Callable(self, "_fit_title_font_size")
	)


func draw_shield_kiting_cutin(
	canvas: CanvasItem,
	cutin_state: Object,
	shield_kiting_state: Object,
	view_size: Vector2
) -> void:
	var shield_symbol_drawer := Callable()
	if shield_kiting_state != null and shield_kiting_state.has_method("draw_cutin_symbol"):
		shield_symbol_drawer = Callable(shield_kiting_state, "draw_cutin_symbol")
	SkillCutinDriveRenderer.draw_shield_kiting_cutin(
		canvas,
		cutin_state,
		view_size,
		Callable(self, "_get_drive_texture"),
		Callable(self, "_get_drive_writhe_material"),
		Callable(self, "_get_localized_skill_title"),
		Callable(self, "_fit_title_font_size"),
		shield_symbol_drawer
	)


func compute_drive_slide_px(progress: float, view_width: float) -> float:
	# Single source of the horizontal slide so the immediate-mode pieces and the
	# particle node move together: enter from the left, hold at rest, exit left.
	return SkillCutinDriveRenderer.compute_drive_slide_px(progress, view_width)


func compute_shield_kiting_slide_px(progress: float, view_width: float) -> float:
	return SkillCutinDriveRenderer.compute_shield_kiting_slide_px(progress, view_width)


func _drive_slide_ratio(progress: float) -> float:
	return SkillCutinDriveRenderer.drive_slide_ratio(progress)


func _drive_alpha(progress: float) -> float:
	return SkillCutinDriveRenderer.drive_alpha(progress)


func _drive_impact_punch(progress: float) -> float:
	return SkillCutinDriveRenderer.drive_impact_punch(progress)


func _drive_triangle_points(view_size: Vector2, slide_px: float) -> PackedVector2Array:
	return SkillCutinDriveRenderer.drive_triangle_points(view_size, slide_px)


func _expanded_drive_polygon(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	return SkillCutinDriveRenderer.expanded_drive_polygon(points, amount)


func _should_draw_drive_edge_flames(from_point: Vector2, to_point: Vector2) -> bool:
	# The left screen wall is the triangle's solid hinge. Keep its seam, but do not
	# push flame offsets outward into the letterbox / outside-screen area.
	return SkillCutinDriveRenderer.should_draw_drive_edge_flames(from_point, to_point)


func _get_drive_texture(path: String) -> Texture2D:
	if _drive_textures.has(path):
		var cached: Variant = _drive_textures[path]
		if cached is Texture2D:
			return cached
	var texture: Texture2D = ProjectResourceLoader.load_texture(path, "", "Failed to load drive cut-in VFX texture: %s")
	_drive_textures[path] = texture
	return texture


func _get_drive_writhe_material(enraged: bool) -> ShaderMaterial:
	if enraged:
		if _drive_writhe_material_enraged == null:
			_drive_writhe_material_enraged = WritheEmber.build_material(DRIVE_WRITHE_PRESET_ENRAGED)
		return _drive_writhe_material_enraged
	if _drive_writhe_material == null:
		_drive_writhe_material = WritheEmber.build_material(DRIVE_WRITHE_PRESET)
	return _drive_writhe_material
