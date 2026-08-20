extends RefCounted

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
	var explicit_id := _safe_identifier(str(node.get("map_icon_boss_id", "")))
	if not explicit_id.is_empty():
		return explicit_id
	var slot_id := str(node.get("boss_slot_id", "")).strip_edges()
	var parts := slot_id.split("_", false)
	if parts.size() >= 3 and parts[0] == "floor" and str(parts[1]).is_valid_int():
		return _safe_identifier("_".join(parts.slice(2)))
	var standin_variant: Variant = node.get("standin", {})
	if standin_variant is Dictionary:
		var standin := standin_variant as Dictionary
		var variant_id := _safe_identifier(str(standin.get("variant", "")))
		if not variant_id.is_empty():
			return variant_id
		return _safe_identifier(str(standin.get("boss_id", "")))
	return ""


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
		"load_attempt_by_path": _load_attempt_by_path.duplicate(true),
	}


func clear_cache() -> void:
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
