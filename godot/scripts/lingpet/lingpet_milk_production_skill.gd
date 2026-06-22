extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const MILK_BOTTLE_ITEM_NAME := "milk_bottle"
const CHEDDAR_CHEESE_ITEM_NAME := "cheddar_cheese"
const CAMEMBERT_CHEESE_ITEM_NAME := "camembert_cheese"
const EMMENTAL_CHEESE_ITEM_NAME := "emmental_cheese"
const PRODUCTION_SECONDS := 3.0
const GAUGE_WIDTH := 74.0
const GAUGE_HEIGHT := 8.0
const GAUGE_OFFSET_Y := -67.0
const BOTTLE_FLOOR_Y := FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT * 0.5
const SPAWN_FLASH_SECONDS := 0.42
const PRODUCTION_SHEET_PATH := "res://assets/sprites/lingpet/milkring_milk_production_autosprite_25f.png"
const FIELD_ICON_PATH := "res://assets/sprites/items/milk_bottle_field_imagegen_v1.png"
const SLOT_ICON_PATH := "res://assets/sprites/items/milk_bottle_icon_imagegen_v1.png"
const CHEDDAR_CHEESE_ICON_PATH := "res://assets/sprites/items/cheddar_cheese_icon_imagegen_v1.png"
const CAMEMBERT_CHEESE_ICON_PATH := "res://assets/sprites/items/camembert_cheese_icon_imagegen_v1.png"
const EMMENTAL_CHEESE_ICON_PATH := "res://assets/sprites/items/emmental_cheese_icon_imagegen_v1.png"
const PADDLE_SCALE_MULTIPLIER_BY_LEVEL := [1.12, 1.14, 1.16, 1.18, 1.20]
const CHEESE_CHANCE_BY_LEVEL := [0.0, 0.0, 0.30, 0.30, 0.30]
const CHEESE_ITEM_BY_LEVEL := ["", "", CHEDDAR_CHEESE_ITEM_NAME, CAMEMBERT_CHEESE_ITEM_NAME, EMMENTAL_CHEESE_ITEM_NAME]

var _production_active := false
var _production_pos := Vector2.ZERO
var _production_progress := 0.0
var _spawn_flash_timer := 0.0
var _last_spawn_pos := Vector2.ZERO
var _last_spawn_item_name := ""
var _last_milk_bottle_scale := 1.0
var _spawn_count := 0
var _textures_prewarmed := false


func reset() -> void:
	_production_active = false
	_production_pos = Vector2.ZERO
	_production_progress = 0.0
	_spawn_flash_timer = 0.0
	_last_spawn_pos = Vector2.ZERO
	_last_spawn_item_name = ""
	_last_milk_bottle_scale = 1.0


func prewarm() -> void:
	if _textures_prewarmed:
		return
	_touch_texture(ProjectResourceLoader.load_texture(PRODUCTION_SHEET_PATH))
	_touch_texture(ProjectResourceLoader.load_texture(FIELD_ICON_PATH))
	_touch_texture(ProjectResourceLoader.load_texture(SLOT_ICON_PATH))
	_touch_texture(ProjectResourceLoader.load_texture(CHEDDAR_CHEESE_ICON_PATH))
	_touch_texture(ProjectResourceLoader.load_texture(CAMEMBERT_CHEESE_ICON_PATH))
	_touch_texture(ProjectResourceLoader.load_texture(EMMENTAL_CHEESE_ICON_PATH))
	_textures_prewarmed = true


func update(delta: float, _owner: Object, _registry: Object = null, launch_context: Dictionary = {}) -> void:
	_spawn_flash_timer = maxf(0.0, _spawn_flash_timer - maxf(0.0, delta))
	var skill_state: Object = launch_context.get("skill_state", null) as Object
	if skill_state == null or not bool(skill_state.get("windup_active")):
		_production_active = false
		return
	var windup_seconds: float = maxf(0.001, float(launch_context.get("windup_seconds", PRODUCTION_SECONDS)))
	var elapsed: float = clampf(float(skill_state.get("windup_elapsed")) + maxf(0.0, delta), 0.0, windup_seconds)
	_production_active = true
	_production_progress = clampf(elapsed / windup_seconds, 0.0, 1.0)
	_production_pos = _get_vector2(launch_context, "companion_pos", _production_pos)


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	prewarm()
	var registry: Object = launch_context.get("registry", null) as Object
	var active_item_runtime: Object = _get_registry_instance(registry, "active_item_runtime")
	if active_item_runtime == null:
		return false
	var spawn_pos: Vector2 = _build_spawn_position(origin, owner, launch_context)
	var active_skill_level := _get_active_skill_level(launch_context)
	var spawn_item_name := _pick_spawn_item_name(active_skill_level, launch_context)
	var spawned := _spawn_item(active_item_runtime, spawn_item_name, spawn_pos, active_skill_level, launch_context)
	if not spawned:
		return false
	_production_active = false
	_production_progress = 1.0
	_spawn_flash_timer = SPAWN_FLASH_SECONDS
	_last_spawn_pos = spawn_pos
	_last_spawn_item_name = spawn_item_name
	_spawn_count += 1
	return true


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _production_active:
		_draw_production_gauge(canvas, _production_pos + shake_offset, _production_progress)
	if _spawn_flash_timer > 0.0:
		_draw_spawn_flash(canvas, _last_spawn_pos + shake_offset)


func has_visible_effects() -> bool:
	return _production_active or _spawn_flash_timer > 0.0


func is_producing() -> bool:
	return _production_active


func get_spawn_count_for_tests() -> int:
	return _spawn_count


func get_snapshot() -> Dictionary:
	return {
		"milk_production_active": _production_active,
		"milk_production_progress": _production_progress,
		"milk_production_pos": _production_pos,
		"milk_production_spawn_flash_timer": _spawn_flash_timer,
		"milk_production_last_spawn_pos": _last_spawn_pos,
		"milk_production_last_spawn_item_name": _last_spawn_item_name,
		"milk_production_last_milk_bottle_scale": _last_milk_bottle_scale,
		"milk_production_spawn_count": _spawn_count,
	}


func _draw_production_gauge(canvas: CanvasItem, center: Vector2, progress: float) -> void:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	var top_left := center + Vector2(-GAUGE_WIDTH * 0.5, GAUGE_OFFSET_Y)
	var bg_rect := Rect2(top_left, Vector2(GAUGE_WIDTH, GAUGE_HEIGHT))
	var fill_rect := Rect2(top_left + Vector2(1.5, 1.5), Vector2(maxf(0.0, (GAUGE_WIDTH - 3.0) * clamped_progress), GAUGE_HEIGHT - 3.0))
	canvas.draw_rect(bg_rect.grow(2.0), Color(0.02, 0.08, 0.12, 0.74), true)
	canvas.draw_rect(bg_rect, Color(0.78, 0.96, 1.0, 0.92), false, 1.4)
	canvas.draw_rect(fill_rect, Color(0.54, 1.0, 0.96, 0.92), true)
	var sparkle_x: float = top_left.x + 4.0 + (GAUGE_WIDTH - 8.0) * clamped_progress
	canvas.draw_circle(Vector2(sparkle_x, top_left.y + GAUGE_HEIGHT * 0.5), 2.0, Color(1.0, 1.0, 1.0, 0.84))


func _draw_spawn_flash(canvas: CanvasItem, center: Vector2) -> void:
	var ratio: float = clampf(_spawn_flash_timer / SPAWN_FLASH_SECONDS, 0.0, 1.0)
	var expansion: float = 1.0 - ratio
	canvas.draw_circle(center, lerpf(12.0, 38.0, expansion), Color(0.70, 1.0, 0.96, 0.20 * ratio))
	canvas.draw_arc(center, lerpf(16.0, 44.0, expansion), 0.0, TAU, 34, Color(0.84, 1.0, 1.0, 0.78 * ratio), 2.0)


func _build_spawn_position(origin: Vector2, owner: Object, launch_context: Dictionary) -> Vector2:
	var companion_pos: Vector2 = _get_vector2(launch_context, "companion_pos", origin)
	var x: float = companion_pos.x
	if owner != null:
		var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2.ZERO)
		var player_width: float = maxf(1.0, float(_get_owner_value(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
		if player_pos != Vector2.ZERO and absf(companion_pos.x - (player_pos.x + player_width * 0.5)) < 18.0:
			x = clampf(companion_pos.x + 96.0, 30.0, FIELD_WIDTH - 30.0)
	return Vector2(clampf(x, 30.0, FIELD_WIDTH - 30.0), BOTTLE_FLOOR_Y)


func _spawn_item(active_item_runtime: Object, item_name: String, spawn_pos: Vector2, active_skill_level: int, launch_context: Dictionary) -> bool:
	if item_name == MILK_BOTTLE_ITEM_NAME:
		return _spawn_milk_bottle(active_item_runtime, spawn_pos, active_skill_level, launch_context)
	_last_milk_bottle_scale = 1.0
	if not active_item_runtime.has_method("spawn_field_item"):
		return false
	return bool(active_item_runtime.spawn_field_item(item_name, spawn_pos))


func _spawn_milk_bottle(active_item_runtime: Object, spawn_pos: Vector2, active_skill_level: int, launch_context: Dictionary) -> bool:
	var scale_multiplier := _get_paddle_scale_multiplier(active_skill_level, launch_context)
	_last_milk_bottle_scale = scale_multiplier
	if active_item_runtime.has_method("spawn_field_item_data"):
		var item_data := ActiveItemCatalog.new().build_item_by_name(MILK_BOTTLE_ITEM_NAME)
		if item_data.is_empty():
			return false
		item_data = item_data.duplicate(true)
		item_data["paddle_scale_multiplier"] = scale_multiplier
		item_data["paddle_scale_percent"] = int(round((scale_multiplier - 1.0) * 100.0))
		item_data["description"] = _build_milk_bottle_description(scale_multiplier)
		return bool(active_item_runtime.spawn_field_item_data(item_data, spawn_pos))
	if active_item_runtime.has_method("spawn_field_item"):
		return bool(active_item_runtime.spawn_field_item(MILK_BOTTLE_ITEM_NAME, spawn_pos))
	return false


func _pick_spawn_item_name(active_skill_level: int, launch_context: Dictionary) -> String:
	var cheese_chance := _get_cheese_chance(active_skill_level, launch_context)
	if cheese_chance <= 0.0:
		return MILK_BOTTLE_ITEM_NAME
	if _consume_cheese_roll(launch_context) < cheese_chance:
		return _get_cheese_item_name(active_skill_level)
	return MILK_BOTTLE_ITEM_NAME


func _get_active_skill_level(launch_context: Dictionary) -> int:
	return clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, 5)


func _get_paddle_scale_multiplier(active_skill_level: int, launch_context: Dictionary) -> float:
	if launch_context.has("paddle_scale_multiplier"):
		return maxf(0.1, float(launch_context.get("paddle_scale_multiplier", 1.20)))
	return _get_level_array_value(PADDLE_SCALE_MULTIPLIER_BY_LEVEL, active_skill_level, 1.20)


func _get_cheese_chance(active_skill_level: int, launch_context: Dictionary) -> float:
	if launch_context.has("cheese_chance"):
		return clampf(float(launch_context.get("cheese_chance", 0.0)), 0.0, 1.0)
	return clampf(_get_level_array_value(CHEESE_CHANCE_BY_LEVEL, active_skill_level, 0.0), 0.0, 1.0)


func _get_cheese_item_name(active_skill_level: int) -> String:
	var index := clampi(active_skill_level, 1, CHEESE_ITEM_BY_LEVEL.size()) - 1
	var item_name := str(CHEESE_ITEM_BY_LEVEL[index])
	return item_name if item_name != "" else MILK_BOTTLE_ITEM_NAME


func _consume_cheese_roll(launch_context: Dictionary) -> float:
	if launch_context.has("milk_production_cheese_roll"):
		return clampf(float(launch_context.get("milk_production_cheese_roll", 1.0)), 0.0, 1.0)
	if launch_context.has("cheese_roll"):
		return clampf(float(launch_context.get("cheese_roll", 1.0)), 0.0, 1.0)
	return randf()


func _get_level_array_value(values: Array, active_skill_level: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var index := clampi(active_skill_level, 1, values.size()) - 1
	return float(values[index])


func _build_milk_bottle_description(scale_multiplier: float) -> String:
	var percent := int(round(maxf(0.0, scale_multiplier - 1.0) * 100.0))
	match LanguageSettings.get_language():
		LanguageSettings.LANGUAGE_ENGLISH:
			return "On use, increases the player's paddle and character image size by %d%% until the stage ends." % percent
		LanguageSettings.LANGUAGE_CHINESE:
			return "使用后，玩家挡板和角色图像大小增加%d%%，持续到本关结束。" % percent
		LanguageSettings.LANGUAGE_JAPANESE:
			return "使用すると、ステージ終了までプレイヤーのパドルとキャラクター画像サイズが%d%%増加します。" % percent
		LanguageSettings.LANGUAGE_SPANISH:
			return "Al usarla, aumenta un %d%% el tamaño del paddle y de la imagen del jugador hasta el final de la etapa." % percent
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
			return "Ao usar, aumenta em %d%% o tamanho do paddle e da imagem do jogador até o fim da fase." % percent
		LanguageSettings.LANGUAGE_RUSSIAN:
			return "При использовании увеличивает размер ракетки и изображения игрока на %d%% до конца этапа." % percent
	return "사용 시 스테이지 종료까지 플레이어 패들과 이미지 크기가 %d%% 증가합니다." % percent


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null
