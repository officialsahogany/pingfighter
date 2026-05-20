extends RefCounted


func trigger(
	target: Object,
	field_item: Dictionary,
	display_name: String,
	item_color: Color,
	registry: Object,
	particles: Array[Dictionary],
	pickup_state: Object,
	effect_feedback: Object
) -> void:
	var pickup_effect: Dictionary = pickup_state.trigger_pickup_effect(
		field_item,
		display_name,
		item_color,
		particles
	)
	var icon_texture: Texture2D = _resolve_pickup_icon_texture(field_item, registry)
	if icon_texture != null:
		pickup_effect["icon_texture"] = icon_texture
		var item_data: Dictionary = _get_dictionary(pickup_effect, "item_data")
		if not item_data.is_empty():
			item_data["icon_texture"] = icon_texture
	target.set("pickup_effect", pickup_effect)
	effect_feedback.play_first_audio(registry, ["play_item_get"])


func _resolve_pickup_icon_texture(field_item: Dictionary, registry: Object) -> Texture2D:
	var item_data: Dictionary = _get_dictionary(field_item, "item_data")
	var direct_texture = item_data.get("icon_texture", null)
	if direct_texture is Texture2D:
		return direct_texture as Texture2D
	var visuals: Object = _get_instance(registry, "active_item_hud_visuals")
	if visuals != null and visuals.has_method("get_icon_texture"):
		var texture: Variant = visuals.get_icon_texture(item_data)
		if texture is Texture2D:
			return texture as Texture2D
	return null


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
