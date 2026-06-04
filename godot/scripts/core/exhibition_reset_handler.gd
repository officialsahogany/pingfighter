extends Node

# Exhibition / showcase reset hotkey. Pressing F10 anywhere in the running game
# returns to the title (main menu) scene and clears volatile match state so the
# next visitor at the booth starts from a clean slate.

const RESET_KEY := KEY_F10
const TITLE_SCENE_PATH := "res://scenes/main_menu.tscn"
const DEFAULT_LEAGUE_MODE := "junior"
const DEFAULT_STAGE_ID := 1

var _resetting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if _resetting:
		return
	if not is_exhibition_reset_event(event):
		return
	if request_reset():
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func is_exhibition_reset_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.physical_keycode == RESET_KEY or key_event.keycode == RESET_KEY


func request_reset() -> bool:
	if _resetting:
		return false
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	_resetting = true
	_reset_game_selection_state()
	var error: int = tree.change_scene_to_file(TITLE_SCENE_PATH)
	if error != OK:
		push_warning("ExhibitionResetHandler: failed to return to title (error %d)" % error)
		_resetting = false
		return false
	if not tree.process_frame.is_connected(_clear_resetting_lock):
		tree.process_frame.connect(_clear_resetting_lock, CONNECT_ONE_SHOT)
	return true


func is_resetting() -> bool:
	return _resetting


func _begin_reset_lock_for_test() -> void:
	_resetting = true


func _clear_resetting_lock() -> void:
	_resetting = false


func _reset_game_selection_state_for_test(selection_state: Object) -> void:
	_reset_game_selection_state(selection_state)


func _reset_game_selection_state(selection_state_override: Object = null) -> void:
	var selection_state: Object = selection_state_override
	if selection_state == null:
		selection_state = _resolve_game_selection_state()
	if selection_state == null:
		return
	if selection_state.has_method("set_stage"):
		selection_state.set_stage(DEFAULT_STAGE_ID)
	if selection_state.has_method("set_league_mode"):
		selection_state.set_league_mode(DEFAULT_LEAGUE_MODE)
	if "skip_battle_logo_once" in selection_state:
		selection_state.set("skip_battle_logo_once", false)


func _resolve_game_selection_state() -> Object:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Node = tree.root
	if root == null:
		return null
	return root.get_node_or_null("GameSelectionState")
