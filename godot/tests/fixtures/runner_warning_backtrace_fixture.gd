extends SceneTree


func _init() -> void:
	push_warning("runner warning-backtrace fixture")
	print("runner_warning_backtrace_fixture: ok")
	quit(0)
