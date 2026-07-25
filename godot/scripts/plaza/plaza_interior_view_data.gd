extends RefCounted

var building_type := ""
var title := ""
var subtitle := ""
var actions: Array[String] = []
var last_message := ""
var npc_name := ""
var npc_texture: Texture2D = null
var room_backdrop_texture: Texture2D = null
var object_textures: Dictionary = {}
var accent := Color(0.0, 0.86, 1.0, 1.0)
var save_snapshot: Dictionary = {}
var player_inventory: Array = []
var shop_inventory: Array = []


func apply(data: Dictionary) -> void:
	building_type = str(data.get("building_type", building_type))
	title = str(data.get("title", title))
	subtitle = str(data.get("subtitle", subtitle))
	actions = _get_string_array(data.get("actions", actions))
	last_message = str(data.get("last_message", last_message))
	npc_name = str(data.get("npc_name", npc_name))
	var texture_value: Variant = data.get("npc_texture", npc_texture)
	npc_texture = texture_value if texture_value is Texture2D else null
	var room_texture_value: Variant = data.get("room_texture", room_backdrop_texture)
	room_backdrop_texture = room_texture_value if room_texture_value is Texture2D else null
	var object_textures_value: Variant = data.get("object_textures", object_textures)
	if object_textures_value is Dictionary:
		object_textures = (object_textures_value as Dictionary).duplicate(false)
	var accent_value: Variant = data.get("accent_color", accent)
	accent = accent_value if accent_value is Color else accent
	var snapshot_value: Variant = data.get("save_snapshot", save_snapshot)
	if snapshot_value is Dictionary:
		save_snapshot = (snapshot_value as Dictionary).duplicate(true)
	player_inventory = _duplicate_dictionary_array(data.get("player_inventory", player_inventory))
	shop_inventory = _duplicate_dictionary_array(data.get("shop_inventory", shop_inventory))


func get_object_texture(kind: String) -> Texture2D:
	var texture: Variant = object_textures.get(kind, null)
	return texture as Texture2D if texture is Texture2D else null


func get_loaded_object_texture_count() -> int:
	var count := 0
	for texture in object_textures.values():
		if texture is Texture2D:
			count += 1
	return count


func is_topview_shop_backdrop() -> bool:
	return building_type == "shop" and room_backdrop_texture != null


static func _get_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value as Array:
			result.append(str(item))
	return result


static func _duplicate_dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result
