extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const DynamiteRenderer := preload("res://scripts/items/active_item_throw_dynamite_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_pokryeol_hwatong_asset_contract()
	_verify_pokryeol_hwatong_render_contract()
	if _failures.is_empty():
		print("active_item_throw_dynamite_renderer_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_pokryeol_hwatong_asset_contract() -> void:
	_expect(
		ActiveItemCatalog.DYNAMITE_ICON_PATH == "res://assets/sprites/items/dynamite_icon_hq_v1.png",
		"Pokryeol Hwatong HUD icon should use the dedicated generated asset"
	)
	_expect(
		DynamiteRenderer.POKRYEOL_HWATONG_PROJECTILE_SHEET_PATH == ActiveItemCatalog.DYNAMITE_ICON_PATH,
		"Pokryeol Hwatong projectile compatibility path should resolve to its catalog icon"
	)
	_expect(DynamiteRenderer.POKRYEOL_HWATONG_STAMP_EXPAND_PROGRESS <= 0.14, "Pokryeol Hwatong blast stamp should reach full spread within about five frames")
	_expect(DynamiteRenderer.POKRYEOL_HWATONG_FLASH_EXPAND_PROGRESS <= 0.12, "Pokryeol Hwatong flash should expand outward instead of visibly collapsing")
	var blast_texture: Texture2D = load(DynamiteRenderer.POKRYEOL_HWATONG_BLAST_STAMP_PATH) as Texture2D
	_expect(blast_texture != null, "Pokryeol Hwatong explosion should load its dedicated blast stamp")
	if blast_texture != null:
		_expect(blast_texture.get_size() == Vector2(512.0, 512.0), "Pokryeol Hwatong blast stamp should use the prepared 512px texture")
	var renderer: Object = DynamiteRenderer.new()
	var icon_texture: Texture2D = renderer.get_dynamite_icon_texture()
	var projectile_texture: Texture2D = renderer.get_dynamite_projectile_sheet_texture()
	_expect(icon_texture != null, "Pokryeol Hwatong catalog icon should load")
	_expect(projectile_texture == icon_texture, "Pokryeol Hwatong live projectile should reuse the exact catalog icon texture")
	if projectile_texture != null:
		_expect(projectile_texture.get_size() == Vector2(256.0, 256.0), "Pokryeol Hwatong live projectile should keep the 256px high-quality source")


func _verify_pokryeol_hwatong_render_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_dynamite_renderer.gd")
	var flight_body := _function_body(source, "func draw_dynamites")
	var placed_body := _function_body(source, "func draw_placed_dynamites")
	var trail_body := _function_body(source, "func _draw_projectile_trail")
	var fallback_body := _function_body(source, "func draw_dynamite_fallback")
	var explosion_body := _function_body(source, "func draw_dynamite_explosions")
	_expect(flight_body.find("get_dynamite_icon_texture") >= 0, "flying Pokryeol Hwatong should use the catalog icon")
	_expect(placed_body.find("get_dynamite_icon_texture") >= 0, "placed Pokryeol Hwatong should use the same catalog icon")
	_expect(source.find("pokryeol_hwatong_projectile_sheet_imagegen_v1.png") < 0, "Pokryeol Hwatong runtime should not reference its former low-resolution sheet")
	_expect(trail_body.find("POKRYEOL_HWATONG_TRAIL_POINT_LIMIT") >= 0, "Pokryeol Hwatong trail should keep a continuous newest-point window")
	_expect(trail_body.find("stride") < 0, "Pokryeol Hwatong trail must not flicker from index-stride culling")
	_expect(fallback_body.find("inner_body") >= 0, "Pokryeol Hwatong fallback should draw a powder vessel body")
	_expect(fallback_body.find("stick_offsets") < 0, "Pokryeol Hwatong fallback should not restore a modern dynamite bundle")
	_expect(explosion_body.find("_draw_pokryeol_hwatong_backplate") >= 0, "Pokryeol Hwatong explosion should compose its dedicated blast stamp")
	_expect(explosion_body.find("ImpactShockwaveTextureCache.draw_full_ring") >= 0, "Pokryeol Hwatong explosion should use textured pressure rings")
	var renderer: Object = DynamiteRenderer.new()
	renderer.prewarm_assets()
	_expect(renderer.are_explosion_texture_assets_ready(), "Pokryeol Hwatong explosion texture stack should prewarm")
	_expect(
		renderer.get_explosion_texture_layer_count({"explosion_style": DynamiteRenderer.POKRYEOL_HWATONG_EXPLOSION_STYLE}) == DynamiteRenderer.POKRYEOL_HWATONG_EXPLOSION_TEXTURE_LAYER_COUNT,
		"Pokryeol Hwatong explosion should expose its four-layer texture budget"
	)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + signature.length())
	if next_function < 0:
		return source.substr(start)
	return source.substr(start, next_function - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
