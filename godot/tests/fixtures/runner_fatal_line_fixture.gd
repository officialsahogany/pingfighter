extends SceneTree


func _init() -> void:
	# Godot exposes no recoverable public fatal API. Emit the exact stderr
	# severity line so this lexical classifier branch remains sealed.
	printerr("FATAL: runner fatal severity fixture")
	print("runner_fatal_line_fixture: ok")
	quit(0)
