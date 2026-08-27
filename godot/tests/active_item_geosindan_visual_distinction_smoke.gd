extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemTimerGaugeRenderer := preload("res://scripts/items/active_item_timer_gauge_renderer.gd")

const GEOSINDAN_ICON_PATH := "res://assets/sprites/items/long_boost_icon_hq_v1.png"
const YEOLHWABYEONG_ICON_PATH := "res://assets/sprites/items/molotov_icon_hq_v1.png"

var _failures: Array[String] = []


func _init() -> void:
	_verify_runtime_identity_and_paths()
	_verify_icon_distinction()

	if _failures.is_empty():
		print("active_item_geosindan_visual_distinction_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_identity_and_paths() -> void:
	var item_data: Dictionary = ActiveItemCatalog.new().build_item_by_name("long_boost")
	_expect(str(item_data.get("name", "")) == "long_boost", "Geosindan must preserve the long_boost compatibility ID")
	_expect(str(item_data.get("effect", "")) == "long_boost", "Geosindan must preserve the long_boost effect route")
	_expect(ActiveItemCatalog.LONG_BOOST_ICON_PATH == GEOSINDAN_ICON_PATH, "Geosindan catalog should use the cool-jade v2 icon")
	_expect(ActiveItemTimerGaugeRenderer.LONG_BOOST_ICON_PATH == GEOSINDAN_ICON_PATH, "Geosindan timer gauge should share the catalog v2 icon")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_support.gd")
	_expect(overlay_source.contains("\"long_boost\": \"%s\"" % GEOSINDAN_ICON_PATH), "character-info breakdown should use the Geosindan v2 icon")
	_expect(not overlay_source.contains("\"long_boost\": \"res://assets/sprites/items/geosindan_icon_imagegen_v1.png\""), "character-info breakdown should not retain the warm Geosindan v1 icon")


func _verify_icon_distinction() -> void:
	var geosindan_texture := load(GEOSINDAN_ICON_PATH) as Texture2D
	var yeolhwabyeong_texture := load(YEOLHWABYEONG_ICON_PATH) as Texture2D
	_expect(geosindan_texture != null, "Geosindan v2 icon should load")
	_expect(yeolhwabyeong_texture != null, "Yeolhwabyeong comparison icon should load")
	if geosindan_texture == null or yeolhwabyeong_texture == null:
		return
	_expect(geosindan_texture.get_size() == Vector2(256.0, 256.0), "Geosindan icon should use the 256px HQ contract")
	_expect(yeolhwabyeong_texture.get_size() == Vector2(256.0, 256.0), "Yeolhwabyeong comparison icon should use the 256px HQ contract")
	var geosindan_metrics := _measure_icon(geosindan_texture.get_image())
	var yeolhwabyeong_metrics := _measure_icon(yeolhwabyeong_texture.get_image())
	_expect(int(geosindan_metrics.get("semi", 99999)) < 5000, "Geosindan should not carry a full-canvas chroma-key halo")
	_expect(float(geosindan_metrics.get("aspect", 0.0)) >= 0.75, "Geosindan should keep a broad medicine-case silhouette")
	_expect(
		float(geosindan_metrics.get("aspect", 0.0)) >= float(yeolhwabyeong_metrics.get("aspect", 99.0)) * 1.75,
		"Geosindan should remain substantially broader than the tall Yeolhwabyeong flask"
	)
	_expect(float(geosindan_metrics.get("cool_ratio", 0.0)) >= 0.40, "Geosindan should retain a strong cool jade and navy identity")
	_expect(float(geosindan_metrics.get("warm_ratio", 1.0)) <= 0.35, "Geosindan should keep warm brass subordinate to its cool medicine identity")
	_expect(float(yeolhwabyeong_metrics.get("warm_ratio", 0.0)) >= 0.70, "Yeolhwabyeong should remain warm enough to separate from Geosindan")
	_expect(geosindan_texture.get_image().get_pixel(0, 0).a <= 8.0 / 255.0, "Geosindan v2 corner should be transparent")


func _measure_icon(image: Image) -> Dictionary:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	var visible := 0
	var semi := 0
	var cool := 0
	var warm := 0
	for y_value in range(image.get_height()):
		for x_value in range(image.get_width()):
			var color: Color = image.get_pixel(x_value, y_value)
			if color.a > 8.0 / 255.0 and color.a <= 200.0 / 255.0:
				semi += 1
			if color.a <= 200.0 / 255.0:
				continue
			visible += 1
			min_x = mini(min_x, x_value)
			min_y = mini(min_y, y_value)
			max_x = maxi(max_x, x_value)
			max_y = maxi(max_y, y_value)
			if color.b > color.r * 1.08 and color.g > color.r * 1.05:
				cool += 1
			if color.r > color.b * 1.18 and color.r > color.g * 1.08:
				warm += 1
	var width: float = float(max_x - min_x + 1) if visible > 0 else 0.0
	var height: float = float(max_y - min_y + 1) if visible > 0 else 1.0
	return {
		"visible": visible,
		"semi": semi,
		"aspect": width / maxf(1.0, height),
		"cool_ratio": float(cool) / maxf(1.0, float(visible)),
		"warm_ratio": float(warm) / maxf(1.0, float(visible)),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
