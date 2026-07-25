extends SceneTree

const Factory := preload("res://scripts/items/mythic_item_acquisition_presentation_factory.gd")
const Cinematic := preload("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const BACKPLATE_PATH := "res://assets/sprites/effects/mythic_acquisition/mythic_backplate.png"
const SHARD_PATH := "res://assets/sprites/effects/mythic_acquisition/mythic_shard.png"
const ARC_PATH := "res://assets/sprites/effects/mythic_acquisition/mythic_arc_ribbon.png"
const ICON_BACKDROP_PATH := "res://assets/sprites/effects/mythic_acquisition/mythic_icon_backdrop.png"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_factory_manifest()
	await _verify_cinematic_uses_factory_manifest()
	_verify_source_ownership()
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("mythic_item_acquisition_presentation_factory_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_factory_manifest() -> void:
	var parent := Node2D.new()
	root.add_child(parent)
	var result := Factory.build(
		parent,
		_load_texture(BACKPLATE_PATH),
		_load_texture(ARC_PATH),
		_load_texture(SHARD_PATH),
		_load_texture(ICON_BACKDROP_PATH)
	)
	_expect(parent.get_child_count() == 13, "presentation factory should build the fixed 13-node manifest")
	var backplate := result.get("backplate") as Sprite2D
	var backplate_material := result.get("backplate_material") as ShaderMaterial
	_expect(backplate != null and backplate.position == Vector2(380.0, 375.0), "backplate should remain centered in the 760x750 field")
	_expect(backplate_material != null, "backplate should keep its writhe shader material")
	if backplate_material != null:
		_expect(is_equal_approx(float(backplate_material.get_shader_parameter("distort_strength")), 0.012), "backplate distortion preset should remain stable")
		_expect(is_equal_approx(float(backplate_material.get_shader_parameter("pulse_speed")), 1.6), "backplate pulse preset should remain stable")
		_expect(is_equal_approx(float(backplate_material.get_shader_parameter("core_dim_radius")), 0.28), "backplate core dim radius should remain stable")

	var arcs_value: Variant = result.get("arcs", [])
	var arcs: Array = arcs_value if arcs_value is Array else []
	_expect(arcs.size() == Factory.ARC_COUNT, "presentation factory should build four arc sprites")
	for index in range(arcs.size()):
		var arc := arcs[index] as Sprite2D
		_expect(arc != null, "arc manifest entries should remain Sprite2D nodes")
		if arc == null:
			continue
		_expect(is_equal_approx(arc.rotation, float(index) * PI * 0.5 + PI * 0.25), "arc rotations should preserve quarter-turn spacing")
		var arc_material := arc.material as ShaderMaterial
		_expect(arc_material != null and is_equal_approx(float(arc_material.get_shader_parameter("scroll_speed")), 1.5), "arc flow preset should remain stable")

	_verify_particle(result.get("ambient_particles") as GPUParticles2D, 24, 1.35, false, "ambient")
	_verify_particle(result.get("burst_particles") as GPUParticles2D, 200, 0.7, true, "burst")
	_verify_particle(result.get("absorb_particles") as GPUParticles2D, 90, 1.3, false, "absorb")

	var icon_backdrop := result.get("icon_backdrop") as Sprite2D
	var icon_sprite := result.get("icon_sprite") as Sprite2D
	_expect(icon_backdrop != null and icon_backdrop.z_index == 4 and icon_backdrop.scale.length() <= 0.001, "icon backdrop should preserve z-order and hidden scale (found %s)" % [icon_backdrop.scale if icon_backdrop != null else Vector2.INF])
	_expect(icon_sprite != null and icon_sprite.z_index == 5 and icon_sprite.scale.length() <= 0.001, "icon sprite should preserve z-order and hidden scale (found %s)" % [icon_sprite.scale if icon_sprite != null else Vector2.INF])
	var text_band := result.get("text_band") as ColorRect
	var name_label := result.get("name_label") as Label
	var description_label := result.get("description_label") as Label
	_expect(text_band != null and text_band.z_index == 6 and not text_band.visible, "text band should start hidden above the icon")
	_expect(name_label != null and name_label.get_theme_font_size("font_size") == 26 and name_label.z_index == 7, "name label typography should remain stable")
	_expect(description_label != null and description_label.get_theme_font_size("font_size") == 16 and description_label.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY, "description label typography should remain stable")
	parent.queue_free()


func _verify_cinematic_uses_factory_manifest() -> void:
	var cinematic := Cinematic.new()
	root.add_child(cinematic)
	await process_frame
	_expect(cinematic.get_child_count() == 13, "cinematic host should consume the factory's complete node manifest")
	_expect(cinematic._backplate is Sprite2D, "cinematic host should bind the factory backplate")
	_expect(cinematic._arcs.size() == Factory.ARC_COUNT, "cinematic host should bind all factory arcs")
	_expect(cinematic._ambient_particles is GPUParticles2D, "cinematic host should bind factory ambient particles")
	_expect(cinematic._burst_particles is GPUParticles2D, "cinematic host should bind factory burst particles")
	_expect(cinematic._absorb_particles is GPUParticles2D, "cinematic host should bind factory absorb particles")
	cinematic.tear_down(true)
	await process_frame


func _verify_source_ownership() -> void:
	var host_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
	var factory_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_presentation_factory.gd")
	_expect(host_source.find("PresentationFactory.build(") >= 0, "cinematic host should delegate fixed node construction")
	for constructor in ["GPUParticles2D.new()", "ParticleProcessMaterial.new()", "ShaderMaterial.new()", "Sprite2D.new()", "ColorRect.new()", "Label.new()"]:
		_expect(host_source.find(str(constructor)) < 0, "cinematic host should not retain fixed constructor %s" % str(constructor))
		_expect(factory_source.find(str(constructor)) >= 0, "presentation factory should own fixed constructor %s" % str(constructor))
	_expect(host_source.find("func _clear_particle_resources(") >= 0, "cinematic host should retain direct particle cleanup ownership")
	_expect(host_source.find("func _apply_visual_state(") >= 0, "cinematic host should retain phase-driven visual state ownership")


func _verify_particle(particles: GPUParticles2D, expected_amount: int, expected_lifetime: float, expected_one_shot: bool, label: String) -> void:
	_expect(particles != null, "%s particles should exist" % label)
	if particles == null:
		return
	_expect(particles.amount == expected_amount, "%s particle amount should remain stable" % label)
	_expect(is_equal_approx(particles.lifetime, expected_lifetime), "%s particle lifetime should remain stable" % label)
	_expect(particles.one_shot == expected_one_shot, "%s one-shot policy should remain stable" % label)
	_expect(not particles.emitting, "%s particles should start inactive" % label)
	var canvas_material := particles.material as CanvasItemMaterial
	_expect(canvas_material != null and canvas_material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "%s particles should preserve additive blend" % label)
	_expect(particles.process_material is ParticleProcessMaterial, "%s particles should keep a process material" % label)


func _load_texture(path: String) -> Texture2D:
	var texture := ProjectResourceLoader.load_texture(path)
	_expect(texture != null, "factory fixture texture should load: %s" % path)
	return texture


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
