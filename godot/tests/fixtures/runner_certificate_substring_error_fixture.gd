extends SceneTree


func _init() -> void:
	printerr("ERROR: runner real failure includes Failed to read the root certificate store")
	print("runner_certificate_substring_error_fixture: ok")
	quit(0)
