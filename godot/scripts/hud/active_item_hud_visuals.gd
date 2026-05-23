extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")

const DEFAULT_ITEM_COLOR := Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)
const EXTRA_ICON_PREWARM_ITEMS := [
	"ammo_box",
	"doping_potion",
	"elixir_of_mastery",
]
const CATALOG_ICON_PREWARM_BATCH_SIZE := 3

var texture_cache: Dictionary = {}
var _catalog_icon_prewarm_items: Array = []
var _catalog_icon_prewarm_index: int = 0
var _active_catalog_prewarm: Object = null
var _mythic_catalog_prewarm: Object = null


func clear_cache() -> void:
	texture_cache.clear()


func prewarm_catalog_icons() -> void:
	while not prewarm_catalog_icons_step():
		pass


func prewarm_catalog_icons_step() -> bool:
	if _catalog_icon_prewarm_items.is_empty():
		_begin_catalog_icon_prewarm()
	var processed := 0
	while _catalog_icon_prewarm_index < _catalog_icon_prewarm_items.size() and processed < CATALOG_ICON_PREWARM_BATCH_SIZE:
		var entry: Variant = _catalog_icon_prewarm_items[_catalog_icon_prewarm_index]
		if entry is Dictionary:
			_prewarm_catalog_icon_entry(entry as Dictionary)
		_catalog_icon_prewarm_index += 1
		processed += 1
	if _catalog_icon_prewarm_index >= _catalog_icon_prewarm_items.size():
		_finish_catalog_icon_prewarm()
		return true
	return false


func get_icon_texture(item_data: Dictionary) -> Texture2D:
	var direct_texture = item_data.get("icon_texture", null)
	if direct_texture is Texture2D:
		return direct_texture as Texture2D

	var path: String = str(item_data.get("icon_path", ""))
	if path == "":
		return null
	if not texture_cache.has(path):
		texture_cache[path] = _load_texture_resource(path)
	var cached_texture = texture_cache[path]
	if cached_texture is Texture2D:
		return cached_texture as Texture2D
	return null


func get_item_color(item_data: Dictionary) -> Color:
	var raw_color = item_data.get("color", DEFAULT_ITEM_COLOR)
	if raw_color is Color:
		return raw_color as Color
	if raw_color is Array and raw_color.size() >= 3:
		return Color(
			float(raw_color[0]) / 255.0,
			float(raw_color[1]) / 255.0,
			float(raw_color[2]) / 255.0,
			1.0
		)
	return DEFAULT_ITEM_COLOR


func _prewarm_catalog_icon(catalog: Object, item_name: String) -> void:
	if catalog == null or not catalog.has_method("build_item_by_name"):
		return
	var item_data: Dictionary = catalog.build_item_by_name(item_name)
	var path: String = str(item_data.get("icon_path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	_touch_texture(get_icon_texture(item_data))


func _prewarm_catalog_icons(catalog: Object, item_names: Array) -> void:
	for item_name in item_names:
		_prewarm_catalog_icon(catalog, str(item_name))


func _begin_catalog_icon_prewarm() -> void:
	_active_catalog_prewarm = ActiveItemCatalog.new()
	_mythic_catalog_prewarm = MythicItemCatalog.new()
	_catalog_icon_prewarm_items.clear()
	for item_name in ActiveItemCatalog.FIELD_SPAWN_ORDER:
		_catalog_icon_prewarm_items.append({"catalog": "active", "name": str(item_name)})
	for item_name in EXTRA_ICON_PREWARM_ITEMS:
		_catalog_icon_prewarm_items.append({"catalog": "active", "name": str(item_name)})
	for item_name in MythicItemCatalog.FIELD_SPAWN_ORDER:
		_catalog_icon_prewarm_items.append({"catalog": "mythic", "name": str(item_name)})
	_catalog_icon_prewarm_index = 0


func _prewarm_catalog_icon_entry(entry: Dictionary) -> void:
	var catalog_key := str(entry.get("catalog", "active"))
	var catalog: Object = _active_catalog_prewarm
	if catalog_key == "mythic":
		catalog = _mythic_catalog_prewarm
	_prewarm_catalog_icon(catalog, str(entry.get("name", "")))


func _finish_catalog_icon_prewarm() -> void:
	_catalog_icon_prewarm_items.clear()
	_catalog_icon_prewarm_index = 0
	_active_catalog_prewarm = null
	_mythic_catalog_prewarm = null


func _load_texture_resource(path: String) -> Texture2D:
	return ProjectResourceLoader.load_texture(
		path,
		"Missing active item icon at %s",
		"Failed to load active item icon at %s"
	)


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()
