extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemEffectRenderer := preload("res://scripts/items/active_item_effect_renderer.gd")
const ActiveItemGeumgangBarrierRenderer := preload("res://scripts/items/active_item_geumgang_barrier_renderer.gd")
const ActiveItemHolyBarrierParticlePayloadFactory := preload("res://scripts/items/active_item_holy_barrier_particle_payload_factory.gd")
const GameplayItemModuleCatalog := preload("res://scripts/resources/gameplay_item_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_generated_assets()
	_verify_modular_renderer_contract()
	_verify_particle_identity()
	_verify_module_catalog()
	if _failures.is_empty():
		print("active_item_geumgang_barrier_renderer_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_generated_assets() -> void:
	const EXPECTED_ICON_PATH := "res://assets/sprites/items/holy_barrier_icon_hq_v1.png"
	const EXPECTED_SEAL_PATH := "res://assets/sprites/effects/geumgang_barrier_seal_imagegen_v1.png"
	_expect(ActiveItemCatalog.HOLY_BARRIER_ICON_PATH == EXPECTED_ICON_PATH, "Geumgang Barrier catalog should use the generated ritual-tool icon")
	_expect(ActiveItemGeumgangBarrierRenderer.GEUMGANG_BARRIER_SEAL_PATH == EXPECTED_SEAL_PATH, "Geumgang Barrier renderer should use the generated Vajra Lotus seal")
	var icon: Texture2D = load(EXPECTED_ICON_PATH) as Texture2D
	var seal: Texture2D = load(EXPECTED_SEAL_PATH) as Texture2D
	_expect(icon != null and icon.get_size() == Vector2(256.0, 256.0), "Geumgang Barrier icon should load with the 256px HQ contract")
	_expect(seal != null and seal.get_size() == Vector2(64.0, 64.0), "Geumgang Barrier seal should load at 64px")


func _verify_modular_renderer_contract() -> void:
	var renderer: Object = ActiveItemGeumgangBarrierRenderer.new()
	renderer.prewarm_assets()
	_expect(renderer.get_seal_texture() != null, "Geumgang Barrier seal should prewarm before battle draw")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/items/active_item_geumgang_barrier_renderer.gd")
	_expect(renderer_source.find("canvas.draw_texture_rect") >= 0, "Geumgang Barrier should compose the generated seal texture at runtime")
	_expect(renderer_source.find("_draw_layered_band") >= 0, "Geumgang Barrier should retain a layered gold and oxblood collision band")
	_expect(renderer_source.find("_draw_braided_knots") >= 0, "Geumgang Barrier should render ritual-cord knot geometry")
	_expect(renderer_source.find("_draw_hit_particle") >= 0, "Geumgang Barrier should own a Vajra-spoke hit response")
	var facade_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_renderer.gd")
	_expect(facade_source.find("_geumgang_barrier_renderer.prewarm_assets()") >= 0, "active item renderer should prewarm Geumgang Barrier assets")
	_expect(facade_source.find("_geumgang_barrier_renderer.draw(canvas, barrier_context, holy_barrier_particles, shake_offset)") >= 0, "active item renderer should delegate the field effect to Geumgang Barrier renderer")
	var debug_menu_source := FileAccess.get_file_as_string("res://scripts/items/active_item_debug_spawn_menu.gd")
	_expect(debug_menu_source.find("return \"하단 금강결계\"") >= 0, "F2 active-item menu should describe the rebranded barrier")


func _verify_particle_identity() -> void:
	seed(20260721)
	var hit: Dictionary = ActiveItemHolyBarrierParticlePayloadFactory.build_hit_particle(Vector2(380.0, 735.0))
	var idle: Dictionary = ActiveItemHolyBarrierParticlePayloadFactory.build_idle_particle(760.0, 735.0)
	_expect(str(hit.get("kind", "")) == "hit", "Geumgang Barrier impact particles should identify the Vajra-spoke lane")
	_expect(str(idle.get("kind", "")) == "idle", "Geumgang Barrier ambient particles should identify the lotus-petal lane")
	_expect(hit.has("rotation") and hit.has("angular_velocity"), "Geumgang Barrier impact particles should rotate during expansion")
	_expect(idle.has("rotation") and idle.has("angular_velocity"), "Geumgang Barrier ambient petals should drift with rotation")
	var hit_color: Color = hit.get("color", Color.TRANSPARENT)
	_expect(hit_color.r > hit_color.b, "Geumgang Barrier impact palette should be warm gold instead of the old cool holy blue")


func _verify_module_catalog() -> void:
	_expect(GameplayItemModuleCatalog.MODULES.has("active_item_geumgang_barrier_renderer"), "item module catalog should list Geumgang Barrier renderer")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("active_item_geumgang_barrier_renderer")
	_expect(str(spec.get("path", "")) == "res://scripts/items/active_item_geumgang_barrier_renderer.gd", "top-level module catalog should resolve Geumgang Barrier renderer")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
