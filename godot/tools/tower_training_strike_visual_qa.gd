extends SceneTree

const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const RuntimePerkIconRenderer := preload(
	"res://scripts/hud/runtime_perk_icon_renderer.gd"
)
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const PlayerCharacterRuntime := preload(
	"res://scripts/characters/player_character_runtime.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_training_strike_s3"
const CHARACTER_SPECS: Array[Dictionary] = [
	{
		"label": "smasher",
		"character_type": PlayerCharacterRuntime.SMASHER,
		"expected_motion": "directional_attack",
		"textures": {
			"player_idle_back_sheet": BattleResources.SMASHER_IDLE_SHEET_PATH,
			"player_attack_right_sheet": BattleResources.SMASHER_ATTACK_RIGHT_SHEET_PATH,
		},
	},
	{
		"label": "viper",
		"character_type": PlayerCharacterRuntime.VIPER,
		"expected_motion": "directional_attack",
		"textures": {
			"viper_player_idle_sheet": BattleResources.VIPER_PLAYER_IDLE_SHEET_PATH,
			"viper_player_attack_right_sheet": BattleResources.VIPER_PLAYER_ATTACK_RIGHT_SHEET_PATH,
		},
	},
	{
		"label": "commando",
		"character_type": PlayerCharacterRuntime.COMMANDO,
		"expected_motion": "commando_pistol_fire",
		"textures": {
			"commando_player_idle_sheet": BattleResources.COMMANDO_PLAYER_BASE_GRIP_IDLE_BACK_SHEET_PATH,
			"commando_player_pistol_fire_sheet": BattleResources.COMMANDO_PLAYER_PISTOL_FIRE_SHEET_PATH,
		},
	},
	{
		"label": "optimus",
		"character_type": PlayerCharacterRuntime.OPTIMUS,
		"expected_motion": "optimus_idle_tween",
		"textures": {
			"optimus_player_idle_sheet": BattleResources.OPTIMUS_PLAYER_IDLE_SHEET_PATH,
		},
	},
	{
		"label": "blacksmith",
		"character_type": PlayerCharacterRuntime.BLACKSMITH,
		"expected_motion": "directional_attack",
		"textures": {
			"blacksmith_player_idle_sheet": BattleResources.BLACKSMITH_PLAYER_IDLE_SHEET_PATH,
			"blacksmith_player_attack_right_sheet": BattleResources.BLACKSMITH_PLAYER_ATTACK_RIGHT_SHEET_PATH,
		},
	},
]


class CaptureAudio:
	extends RefCounted
	var play_count := 0
	var stop_count := 0
	var active := false

	func play_training_strike_hit(_source_x: float = 0.0) -> void:
		play_count += 1
		active = true

	func stop_training_strike_audio() -> void:
		stop_count += 1
		active = false


class CaptureFlow:
	extends RefCounted
	var modal_state: Object
	var card_renderer: Object
	var icon_renderer: Object

	func _init(state_value: Object, card_value: Object, icon_value: Object) -> void:
		modal_state = state_value
		card_renderer = card_value
		icon_renderer = icon_value

	func get_phase_name() -> String:
		return "NODE_MODAL"

	func get_node_modal_view_model(view_size: Vector2) -> Dictionary:
		return modal_state.build_view_model(view_size)

	func get_node_modal_kind() -> String:
		return "training"

	func get_node_modal_render_context() -> Dictionary:
		return {
			"card_renderer": card_renderer,
			"icon_renderer": icon_renderer,
			"training_stage_presentation": modal_state.get_training_stage_presentation(),
		}


class CaptureCanvas:
	extends Node2D
	var flow: Object
	var renderer := TowerAscentFlowRenderer.new()

	func _init(flow_value: Object) -> void:
		flow = flow_value

	func _draw() -> void:
		renderer.draw_fullscreen_node_modal(
			self,
			flow,
			Rect2(Vector2.ZERO, Vector2(VIEW_SIZE))
		)


var _modal := TowerAscentNodeModalState.new()
var _card_renderer := RuntimePerkOverlayRenderer.new()
var _icon_renderer := RuntimePerkIconRenderer.new()
var _failed := false
var _capture_count := 0
var _full_frame_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_training_strike_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_training_strike_visual_qa requires Vulkan")
		quit(1)
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("training strike capture directory creation failed")
		quit(1)
		return
	var flow := CaptureFlow.new(_modal, _card_renderer, _icon_renderer)
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := CaptureCanvas.new(flow)
	viewport.add_child(canvas)
	for spec in CHARACTER_SPECS:
		if not await _capture_character_sequence(viewport, canvas, output_dir, spec):
			_failed = true
			break
	if not _failed and not await _verify_modal_close_cleanup(viewport, canvas):
		_failed = true
	if _failed:
		quit(1)
		return
	print("tower_training_strike_visual_qa: evidence=%s" % output_dir)
	print("tower_training_strike_visual_qa: captures=%d" % _capture_count)
	print("tower_training_strike_visual_qa: full_frames=%d" % _full_frame_count)
	print("tower_training_strike_visual_qa: strips=%d" % CHARACTER_SPECS.size())
	print("tower_training_strike_visual_qa: modal_close_cleanup=ok")
	print("tower_training_strike_visual_qa: ok")
	quit(0)


func _capture_character_sequence(
	viewport: SubViewport,
	canvas: CanvasItem,
	output_dir: String,
	spec: Dictionary
) -> bool:
	var label := str(spec.get("label", "unknown"))
	var clock_base := 10000 + CHARACTER_SPECS.find(spec) * 2000
	_modal.open("s3-vulkan-%s" % label, "training", {"gold": 30, "muhon": 8}, _actions())
	_modal.set_clock_msec_for_tests(clock_base)
	var texture_cache := _load_texture_cache(spec.get("textures", {}), label)
	if texture_cache.is_empty():
		return false
	var audio := CaptureAudio.new()
	if not _expect(
		_modal.configure_training_stage_presentation(
			spec.get("character_type", PlayerCharacterRuntime.SMASHER),
			texture_cache,
			audio
		),
		"%s presentation configuration" % label
	):
		return false
	var debug_state := _modal.get_training_stage_debug_state()
	if not _expect(bool(debug_state.get("asset_present", false)), "%s production asset present" % label):
		return false
	if not _expect(
		str(debug_state.get("motion_kind", "")) == str(spec.get("expected_motion", "")),
		"%s production motion selection" % label
	):
		return false
	if not _expect(
		int(debug_state.get("host_node_count", -1)) == 0
		and int(debug_state.get("dynamic_layer_count", -1)) == 0,
		"%s uses no detached host or dynamic layer" % label
	):
		return false
	var frames: Dictionary = {}
	var models: Dictionary = {}
	var frame_order: Array[String] = ["idle"]
	var idle_image := await _capture_image(viewport, canvas, label, "idle")
	if idle_image == null:
		return false
	frames["idle"] = idle_image
	if label in ["smasher", "optimus"]:
		if not _save_full_frame(output_dir, label, "idle", idle_image):
			return false
	_modal.set_training_stage_clock_msec_for_tests(clock_base)
	if not _expect(_modal.begin_training_strike(), "%s click starts strike" % label):
		return false
	var plan := _frame_plan(label)
	var contact_msec := 90 if label == "optimus" else 360
	for frame_spec in plan:
		var frame_name := str(frame_spec.get("name", "frame"))
		var elapsed_msec := int(frame_spec.get("elapsed", 0))
		_modal.set_clock_msec_for_tests(clock_base + elapsed_msec)
		_modal.set_training_stage_clock_msec_for_tests(clock_base + elapsed_msec)
		_modal.update_training_strike_wall_clock()
		if elapsed_msec == contact_msec:
			_modal.record_action_feedback(_modal.get_selected_action(), {
				"accepted": true,
				"applied": true,
				"message": "수련 성공",
			})
		var image := await _capture_image(viewport, canvas, label, frame_name)
		if image == null:
			return false
		frames[frame_name] = image
		models[frame_name] = _modal.get_training_stage_visual_model_for_tests().duplicate(true)
		frame_order.append(frame_name)
		if frame_name == "contact" or (
			label in ["smasher", "optimus"] and frame_name == "dummy_away"
		) or (label == "smasher" and frame_name == "returned"):
			if not _save_full_frame(output_dir, label, frame_name, image):
				return false
	if not _verify_character_sequence(label, frames, models, audio):
		return false
	if not _save_strip(output_dir, label, frames, frame_order):
		return false
	_modal.close()
	return true


func _frame_plan(label: String) -> Array[Dictionary]:
	if label == "optimus":
		return [
			{"name": "click", "elapsed": 0},
			{"name": "windup", "elapsed": 45},
			{"name": "contact", "elapsed": 90},
			{"name": "hitstop_end", "elapsed": 134},
			{"name": "dummy_away", "elapsed": 190},
			{"name": "dummy_rebound", "elapsed": 255},
			{"name": "recovery", "elapsed": 374},
			{"name": "returned", "elapsed": 375},
		]
	return [
		{"name": "click", "elapsed": 0},
		{"name": "windup", "elapsed": 180},
		{"name": "contact", "elapsed": 360},
		{"name": "hitstop_end", "elapsed": 404},
		{"name": "dummy_away", "elapsed": 460},
		{"name": "dummy_rebound", "elapsed": 525},
		{"name": "recovery", "elapsed": 720},
		{"name": "returned", "elapsed": 765},
	]


func _verify_character_sequence(
	label: String,
	frames: Dictionary,
	models: Dictionary,
	audio: CaptureAudio
) -> bool:
	var contact: Dictionary = models.get("contact", {})
	var hitstop_end: Dictionary = models.get("hitstop_end", {})
	if not _expect(
		int(contact.get("local_timeline_msec", -1))
		== int(hitstop_end.get("local_timeline_msec", -2)),
		"%s lower timeline freezes for all 45ms" % label
	):
		return false
	if not _expect(
		int(contact.get("frame_index", -1)) == int(hitstop_end.get("frame_index", -2))
		and is_equal_approx(
			float(contact.get("dummy_rotation_radians", 99.0)),
			float(hitstop_end.get("dummy_rotation_radians", -99.0))
		),
		"%s character and dummy pose freeze together" % label
	):
		return false
	var card_rects := _modal.get_action_rects(Vector2(VIEW_SIZE))
	if not _expect(not card_rects.is_empty(), "%s card layout available" % label):
		return false
	if not _expect(
		_sampled_difference_count_region(
			frames.get("contact", null),
			frames.get("hitstop_end", null),
			card_rects[0]
		) >= 12,
		"%s card receipt clock continues through lower hitstop" % label
	):
		return false
	var away_rotation := rad_to_deg(float(
		(models.get("dummy_away", {}) as Dictionary).get("dummy_rotation_radians", 0.0)
	))
	var rebound_rotation := rad_to_deg(float(
		(models.get("dummy_rebound", {}) as Dictionary).get("dummy_rotation_radians", 0.0)
	))
	if not _expect(absf(away_rotation - 7.0) < 0.08, "%s dummy reaches +7 degrees" % label):
		return false
	if not _expect(absf(rebound_rotation + 2.0) < 0.08, "%s dummy reaches -2 degrees" % label):
		return false
	if not _expect(
		_sampled_difference_count_region(
			frames.get("contact", null),
			frames.get("dummy_away", null),
			Rect2(1070.0, 610.0, 520.0, 420.0)
		) >= 30,
		"%s dummy rotation is visibly rendered" % label
	):
		return false
	if not _expect(
		audio.play_count == 1 and not audio.active,
		"%s contact audio fires once and ends with the strike" % label
	):
		return false
	var returned: Dictionary = models.get("returned", {})
	if not _expect(
		not bool(returned.get("active", true))
		and absf(float(returned.get("dummy_rotation_radians", 99.0))) < 0.001,
		"%s sequence returns to idle" % label
	):
		return false
	if label == "optimus":
		if not _expect(
			absf(float(contact.get("character_offset_x", 0.0)) - 14.0) < 0.01,
			"optimus renders the approved 14px idle lunge"
		):
			return false
		if not _expect(
			str(contact.get("motion_kind", "")) == "optimus_idle_tween"
			and bool(contact.get("asset_present", false)),
			"optimus renders its production idle sheet instead of disappearing"
		):
			return false
	return true


func _verify_modal_close_cleanup(viewport: SubViewport, canvas: CanvasItem) -> bool:
	var spec: Dictionary = CHARACTER_SPECS[0]
	var texture_cache := _load_texture_cache(spec.get("textures", {}), "cleanup")
	if texture_cache.is_empty():
		return false
	var audio := CaptureAudio.new()
	var clock_base := 30000
	_modal.open("s3-close-cleanup", "training", {"gold": 30, "muhon": 8}, _actions())
	_modal.set_clock_msec_for_tests(clock_base)
	if not _modal.configure_training_stage_presentation(
		PlayerCharacterRuntime.SMASHER,
		texture_cache,
		audio
	):
		return _expect(false, "modal-close presentation configuration")
	_modal.set_training_stage_clock_msec_for_tests(clock_base)
	_modal.begin_training_strike()
	_modal.set_training_stage_clock_msec_for_tests(clock_base + 360)
	_modal.update_training_strike_wall_clock()
	var before_close := _modal.get_training_stage_debug_state()
	if not _expect(
		audio.active
		and int(before_close.get("host_node_count", -1)) == 0
		and int(before_close.get("dynamic_layer_count", -1)) == 0,
		"modal-close leg reaches live contact without a host"
	):
		return false
	var root_child_count := get_root().get_child_count()
	_modal.close()
	canvas.queue_redraw()
	await process_frame
	return _expect(
		_modal.get_training_stage_presentation() == null
		and not audio.active
		and audio.stop_count >= 1
		and get_root().get_child_count() == root_child_count,
		"modal close explicitly clears presentation audio and leaves no host"
	)


func _load_texture_cache(texture_paths_value: Variant, label: String) -> Dictionary:
	var texture_paths: Dictionary = (
		texture_paths_value as Dictionary
		if texture_paths_value is Dictionary
		else {}
	)
	var result: Dictionary = {}
	for key_value in texture_paths.keys():
		var key := str(key_value)
		var path := str(texture_paths.get(key_value, ""))
		var texture := load(path)
		if not (texture is Texture2D):
			_expect(false, "%s texture failed to load: %s" % [label, path])
			return {}
		result[key] = texture
	return result


func _capture_image(
	viewport: SubViewport,
	canvas: CanvasItem,
	label: String,
	frame_name: String
) -> Image:
	canvas.queue_redraw()
	for _frame_index in range(3):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != VIEW_SIZE:
		_expect(false, "%s/%s Vulkan frame is empty" % [label, frame_name])
		return null
	_capture_count += 1
	return image


func _save_full_frame(output_dir: String, label: String, frame_name: String, image: Image) -> bool:
	var output_path := output_dir.path_join("training_%s_%s_2020x1246.png" % [label, frame_name])
	if image.save_png(output_path) != OK:
		return _expect(false, "failed to save full frame: %s" % output_path)
	_full_frame_count += 1
	print("[TowerTrainingStrikeVisualQA] %s" % output_path)
	return true


func _save_strip(
	output_dir: String,
	label: String,
	frames: Dictionary,
	frame_order: Array[String]
) -> bool:
	var cell_size := Vector2i(VIEW_SIZE.x / 2, VIEW_SIZE.y / 2)
	var strip := Image.create(
		cell_size.x * frame_order.size(),
		cell_size.y,
		false,
		Image.FORMAT_RGBA8
	)
	for index in range(frame_order.size()):
		var frame_value: Variant = frames.get(frame_order[index], null)
		if not (frame_value is Image):
			return _expect(false, "%s strip frame missing: %s" % [label, frame_order[index]])
		var frame := (frame_value as Image).duplicate()
		frame.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(
			frame,
			Rect2i(Vector2i.ZERO, cell_size),
			Vector2i(index * cell_size.x, 0)
		)
	var output_path := output_dir.path_join("training_%s_motion_strip.png" % label)
	if strip.save_png(output_path) != OK:
		return _expect(false, "failed to save motion strip: %s" % output_path)
	print("[TowerTrainingStrikeVisualQA] %s" % output_path)
	return true


func _sampled_difference_count_region(
	first: Image,
	second: Image,
	region: Rect2
) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return 0
	var bounds := Rect2i(Vector2i.ZERO, first.get_size())
	var sample_rect := Rect2i(region).intersection(bounds)
	var changed := 0
	for y in range(sample_rect.position.y, sample_rect.end.y, 3):
		for x in range(sample_rect.position.x, sample_rect.end.x, 3):
			var first_color := first.get_pixel(x, y)
			var second_color := second.get_pixel(x, y)
			var difference := (
				absf(first_color.r - second_color.r)
				+ absf(first_color.g - second_color.g)
				+ absf(first_color.b - second_color.b)
				+ absf(first_color.a - second_color.a)
			)
			if difference > 0.035:
				changed += 1
	return changed


func _actions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var names := ["철산공", "유운보", "태허심법", "격기심법", "순환결", "수납술"]
	for index in range(names.size()):
		result.append({
			"id": "training_visual_%d" % index,
			"label": names[index],
			"cost_text": "2 무혼",
			"enabled": true,
			"payload": {
				"choice": {
					"id": "training_visual_%d" % index,
					"name": names[index],
					"description": "몸을 단련해 전투 능력을 높입니다.",
					"current_level": 2,
					"next_level": 3,
					"level_text": "Lv.2 → Lv.3",
					"icon_color": Color(0.72, 0.39 + float(index) * 0.035, 0.18),
				},
				"presentation": {
					"current": "Lv.2",
					"result": "Lv.3",
					"target": names[index],
				},
			},
		})
	return result


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("tower_training_strike_visual_qa: %s" % message)
	return false
