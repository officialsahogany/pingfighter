extends RefCounted

const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const ICON_ROOT := "res://assets/sprites/tower/map_icons"
const COMBAT_NODE_KINDS := ["boss", "combat", "enraged"]
const NODE_ICON_PATH_BY_KIND := {
	"shop": ICON_ROOT + "/node_shop_imagegen_v1.png",
	"training": ICON_ROOT + "/node_training_imagegen_v1.png",
	"fallen_monk": ICON_ROOT + "/node_fallen_monk_imagegen_v1.png",
	"guardian_spring": ICON_ROOT + "/node_guardian_spring_imagegen_v1.png",
	"rest": ICON_ROOT + "/node_rest_imagegen_v1.png",
	"map_hint": ICON_ROOT + "/map_hint_imagegen_v1.png",
}
const BOSS_ICON_PATH_FORMAT := ICON_ROOT + "/boss_%s_imagegen_v1.png"
var _boss_registry: Object = TowerAscentBossRegistry.new()
var _boss_id_by_node_id: Dictionary = {}
var _boss_registry_resolve_count := 0
var _texture_by_path: Dictionary = {}
var _load_attempt_by_path: Dictionary = {}


func resolve_icon_path(kind: String, boss_id: String = "") -> String:
	var normalized_kind := kind.strip_edges()
	if normalized_kind in COMBAT_NODE_KINDS:
		var normalized_boss_id := _safe_identifier(boss_id)
		return BOSS_ICON_PATH_FORMAT % normalized_boss_id if not normalized_boss_id.is_empty() else ""
	return str(NODE_ICON_PATH_BY_KIND.get(normalized_kind, ""))


func resolve_presentation(
	kind: String,
	boss_id: String,
	fallback_label: String
) -> Dictionary:
	var path := resolve_icon_path(kind, boss_id)
	var texture := _load_texture_once(path)
	return {
		"kind": kind,
		"boss_id": boss_id,
		"icon_path": path,
		"icon_texture": texture,
		"fallback_label": fallback_label if texture == null else "",
	}


func resolve_boss_id_for_node(node: Dictionary) -> String:
	if str(node.get("kind", "")) not in COMBAT_NODE_KINDS:
		return ""
	if str(node.get("boss_slot_id", "")).is_empty():
		return ""
	var node_id := str(node.get("id", ""))
	if not node_id.is_empty() and _boss_id_by_node_id.has(node_id):
		return str(_boss_id_by_node_id[node_id])
	_boss_registry_resolve_count += 1
	var boss_id := str(_boss_registry.resolve_boss_icon_id_for_node(node))
	if not node_id.is_empty():
		_boss_id_by_node_id[node_id] = boss_id
	return boss_id


func invalidate_boss_node_cache(node_id: String = "") -> void:
	var normalized_node_id := node_id.strip_edges()
	if normalized_node_id.is_empty():
		_boss_id_by_node_id.clear()
		return
	_boss_id_by_node_id.erase(normalized_node_id)


func get_debug_state() -> Dictionary:
	var hit_count := 0
	var miss_count := 0
	for texture_value in _texture_by_path.values():
		if texture_value is Texture2D:
			hit_count += 1
		else:
			miss_count += 1
	return {
		"entry_count": _texture_by_path.size(),
		"hit_count": hit_count,
		"miss_count": miss_count,
		"boss_node_cache_count": _boss_id_by_node_id.size(),
		"boss_registry_resolve_count": _boss_registry_resolve_count,
		"load_attempt_by_path": _load_attempt_by_path.duplicate(true),
	}


func clear_cache() -> void:
	_boss_id_by_node_id.clear()
	_boss_registry_resolve_count = 0
	_texture_by_path.clear()
	_load_attempt_by_path.clear()


func _load_texture_once(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_by_path.has(path):
		var cached_texture: Variant = _texture_by_path[path]
		return cached_texture as Texture2D if cached_texture is Texture2D else null
	_load_attempt_by_path[path] = int(_load_attempt_by_path.get(path, 0)) + 1
	var texture: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		var loaded_resource: Resource = ResourceLoader.load(path, "Texture2D")
		if loaded_resource is Texture2D:
			texture = loaded_resource as Texture2D
	_texture_by_path[path] = texture
	return texture


func _safe_identifier(value: String) -> String:
	var candidate := value.strip_edges()
	if candidate.is_empty():
		return ""
	for index in range(candidate.length()):
		var codepoint := candidate.unicode_at(index)
		var lowercase_ascii := codepoint >= 97 and codepoint <= 122
		var digit_ascii := codepoint >= 48 and codepoint <= 57
		if not lowercase_ascii and not digit_ascii and codepoint != 95:
			return ""
	return candidate
