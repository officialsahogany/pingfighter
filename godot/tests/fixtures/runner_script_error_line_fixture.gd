extends SceneTree


func _init() -> void:
	print("runner_script_error_line_fixture: ok")
	call_deferred("_emit_script_error")
	call_deferred("_quit_ok")


func _emit_script_error() -> void:
	assert(false, "runner script-error severity fixture")


func _quit_ok() -> void:
	quit(0)
