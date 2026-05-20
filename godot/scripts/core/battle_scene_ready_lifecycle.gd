extends RefCounted


func ready(startup: Object, owner: Node, _registry: Object, module_getter: Callable, _callbacks: Dictionary) -> void:
	if startup == null:
		return
	startup._apply_selection_state(owner)
	startup._configure_battle_window(owner, module_getter)
	if not startup._consume_skip_battle_logo_once(owner):
		var logo_intro: Object = startup._get_module(module_getter, "penguin_logo_intro")
		if logo_intro != null and logo_intro.has_method("begin") and bool(logo_intro.begin(owner)):
			startup._queue_redraw(owner)
			return
	startup._queue_redraw(owner)
