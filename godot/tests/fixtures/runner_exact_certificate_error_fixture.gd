extends SceneTree


func _init() -> void:
	printerr("ERROR: Failed to read the root certificate store.")
	print("runner_exact_certificate_error_fixture: ok")
	quit(0)
