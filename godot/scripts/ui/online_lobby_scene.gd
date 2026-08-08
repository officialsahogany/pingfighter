extends Control

const BATTLE_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const DEFAULT_PORT := 24777

@onready var address_input: LineEdit = $CenterPanel/Margin/VBox/AddressInput
@onready var port_input: SpinBox = $CenterPanel/Margin/VBox/PortRow/PortInput
@onready var host_button: Button = $CenterPanel/Margin/VBox/ActionRow/HostButton
@onready var join_button: Button = $CenterPanel/Margin/VBox/ActionRow/JoinButton
@onready var back_button: Button = $CenterPanel/Margin/VBox/BackButton
@onready var status_label: Label = $CenterPanel/Margin/VBox/StatusLabel

var _transitioning := false


func _ready() -> void:
	if port_input != null:
		port_input.value = DEFAULT_PORT
	if host_button != null:
		host_button.pressed.connect(_on_host_pressed)
	if join_button != null:
		join_button.pressed.connect(_on_join_pressed)
	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
	if address_input != null:
		address_input.text_submitted.connect(_on_address_submitted)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not _transitioning:
			_on_back_pressed()
		get_viewport().set_input_as_handled()


func _on_host_pressed() -> void:
	if _transitioning:
		return
	_start_online_battle({
		"role": "host",
		"bind_ip": "*",
		"port": _get_port(),
		"snapshot_hz": 30,
	})


func _on_join_pressed() -> void:
	if _transitioning:
		return
	var address := address_input.text.strip_edges() if address_input != null else ""
	if address == "" or not address.is_valid_ip_address():
		_set_status("접속할 LAN 또는 Tailscale IP를 입력하세요.", true)
		if address_input != null:
			address_input.grab_focus()
		return
	_start_online_battle({
		"role": "client",
		"address": address,
		"port": _get_port(),
		"snapshot_hz": 30,
	})


func _on_address_submitted(_value: String) -> void:
	_on_join_pressed()


func _on_back_pressed() -> void:
	if _transitioning:
		return
	var selection_state := _get_selection_state()
	if selection_state != null and selection_state.has_method("cancel_online_match_request"):
		selection_state.cancel_online_match_request()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _start_online_battle(request: Dictionary) -> void:
	if _transitioning:
		return
	var selection_state := _get_selection_state()
	if selection_state == null:
		_set_status("게임 선택 상태를 찾을 수 없습니다.", true)
		return
	selection_state.set_character({
		"id": "ufo_player",
		"runtime_id": "smasher",
		"name": "한미량",
	})
	selection_state.set_league_mode("champion")
	selection_state.set_stage(1)
	selection_state.request_online_match(request)
	_transitioning = true
	_set_controls_disabled(true)
	_set_status("온라인 전투를 준비합니다…", false)
	var error := get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
	if error != OK:
		selection_state.cancel_online_match_request()
		_transitioning = false
		_set_controls_disabled(false)
		_set_status("전투 씬을 열지 못했습니다. 오류 %d" % error, true)


func _get_port() -> int:
	return clampi(int(port_input.value) if port_input != null else DEFAULT_PORT, 1, 65535)


func _set_controls_disabled(disabled: bool) -> void:
	for button in [host_button, join_button, back_button]:
		if button != null:
			button.disabled = disabled
	if address_input != null:
		address_input.editable = not disabled
	if port_input != null:
		port_input.editable = not disabled


func _set_status(message: String, is_error: bool) -> void:
	if status_label == null:
		return
	status_label.text = message
	status_label.modulate = Color(1.0, 0.55, 0.62) if is_error else Color(0.72, 0.92, 1.0)


func _get_selection_state() -> Node:
	return get_node_or_null("/root/GameSelectionState")
