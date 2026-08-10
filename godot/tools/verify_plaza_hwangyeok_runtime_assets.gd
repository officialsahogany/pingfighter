extends SceneTree

const MANIFEST_ROOT := "res://assets/ui/plaza/buildings/hwangyeok"
const BUILDING_TYPES := [
	"bank",
	"shop",
	"gacha",
	"lingpet_store",
	"blacksmith",
	"tavern",
	"academy",
]
const LAYER_NAMES := ["base", "sign_emissive", "window_glow_mask"]
const EXPECTED_TEXTURE_SIZE := Vector2i(512, 512)


func _init() -> void:
	var failures: Array[String] = []
	var loaded_paths: Array[String] = []
	for building_type: String in BUILDING_TYPES:
		var asset_id := "plaza_hwangyeok_%s_3q_v1" % building_type
		var manifest_path := "%s/%s_manifest.json" % [MANIFEST_ROOT, asset_id]
		var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
		if manifest_file == null:
			failures.append("missing manifest: %s" % manifest_path)
			continue
		var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
		if not parsed is Dictionary:
			failures.append("invalid manifest json: %s" % manifest_path)
			continue
		var manifest: Dictionary = parsed
		var runtime_size: Array = manifest.get("runtime_texture_size", [])
		if (
			runtime_size.size() != 2
			or int(runtime_size[0]) != EXPECTED_TEXTURE_SIZE.x
			or int(runtime_size[1]) != EXPECTED_TEXTURE_SIZE.y
		):
			failures.append("runtime texture contract drift: %s" % manifest_path)
		var layers: Dictionary = manifest.get("layers", {})
		for layer_name: String in LAYER_NAMES:
			var layer: Dictionary = layers.get(layer_name, {})
			var texture_path := str(layer.get("res_path", ""))
			if texture_path.is_empty():
				failures.append("missing res_path: %s/%s" % [building_type, layer_name])
				continue
			var resource: Resource = ResourceLoader.load(texture_path)
			if resource == null or not resource is Texture2D:
				failures.append("texture load failed: %s" % texture_path)
				continue
			var texture := resource as Texture2D
			if Vector2i(texture.get_width(), texture.get_height()) != EXPECTED_TEXTURE_SIZE:
				failures.append(
					"texture size drift: %s (%dx%d)" % [
						texture_path,
						texture.get_width(),
						texture.get_height(),
					]
				)
			loaded_paths.append(texture_path)

	var report := {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"loaded_texture_count": loaded_paths.size(),
		"expected_texture_count": BUILDING_TYPES.size() * LAYER_NAMES.size(),
		"failures": failures,
	}
	print(JSON.stringify(report))
	if failures.is_empty():
		print("verify_plaza_hwangyeok_runtime_assets: ok")
	quit(0 if failures.is_empty() else 1)
