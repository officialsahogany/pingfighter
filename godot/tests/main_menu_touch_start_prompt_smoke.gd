extends SceneTree

const MainMenuTouchStartPrompt := preload("res://scripts/ui/main_menu_touch_start_prompt.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var failure_count: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_localized_copy()
	var host := Control.new()
	host.size = Vector2(900.0, 100.0)
	get_root().add_child(host)
	var button := Button.new()
	button.size = host.size
	host.add_child(button)
	var prompt := MainMenuTouchStartPrompt.new()
	button.add_child(prompt)
	prompt.configure(button)
	await process_frame

	_expect(prompt.name == "PromptRibbon", "prompt should preserve the main-menu node path")
	_expect(prompt.mouse_filter == Control.MOUSE_FILTER_IGNORE, "prompt should not intercept start input")
	_expect(prompt.get_node_or_null("PromptTextCenter/PromptText") is Label, "prompt should own its centered label")
	_expect(prompt.prompt_label.text == MainMenuTouchStartPrompt.PROMPT_TEXT, "prompt label should preserve the shipped copy")
	_expect(is_zero_approx(MainMenuTouchStartPrompt.RIBBON_BACKGROUND_ALPHA), "R6 prompt ribbon must remove its translucent band fill")
	_expect(is_equal_approx(MainMenuTouchStartPrompt.HAIRLINE_WIDTH, 1.0), "R6 prompt ribbon should use 1px bronze hairlines")
	var prompt_source := FileAccess.get_file_as_string("res://scripts/ui/main_menu_touch_start_prompt.gd")
	_expect(prompt_source.find("_draw_faded_band") < 0, "R6 prompt must remove the cyber faded-band renderer")
	_expect(prompt_source.find("_draw_side_dash_ornaments") >= 0, "R7 prompt should draw left/right dash ornaments with primitives")
	_expect(prompt_source.find("_draw_lower_diamond_ornament") >= 0, "R7 prompt should draw the lower diamond ornament with primitives")
	_expect(prompt_source.find("✦") < 0 and prompt_source.find("U+2726") < 0, "R7 prompt must not use Unicode ornament glyphs that can tofu")

	# Left-shifted start-copy regression seal. The live VBox stretches the
	# host button WIDER than its 845px custom_minimum_size AFTER configure() runs.
	# A ribbon filled with set_anchors_preset (keep_offsets=false) bakes offsets
	# against the pre-stretch width and collapses to a sliver on the next resize,
	# pinning the centered label to the button's left edge. Filling via anchors +
	# offsets must keep both the ribbon and the label centered on the button after
	# the resize. Prove the ribbon truly fills before trusting the label center.
	button.size = Vector2(1200.0, 120.0)
	await process_frame
	await process_frame
	var ribbon_center_x := prompt.global_position.x + prompt.size.x * 0.5
	var button_center_x := button.global_position.x + button.size.x * 0.5
	_expect(
		is_equal_approx(prompt.size.x, button.size.x),
		"ribbon must fill the host button width after a post-configure resize (not collapse to a sliver)"
	)
	_expect(
		is_equal_approx(ribbon_center_x, button_center_x),
		"ribbon must stay horizontally centered on the host button after resize"
	)
	var label := prompt.prompt_label
	var label_center_x := label.global_position.x + label.size.x * 0.5
	# Allow a 1px band for the CenterContainer's integer pixel snapping of an
	# odd-width label; the buggy left-pinned state is off by hundreds of px.
	_expect(
		absf(label_center_x - button_center_x) <= 1.0,
		"start-copy label must stay centered on the host button after a post-configure resize"
	)
	prompt.set_prompt_text("Knock to open the spirit gate")
	_expect(prompt.prompt_label.text == "Knock to open the spirit gate", "runtime locale refresh should update the centered prompt label")
	_expect(button.text == "Knock to open the spirit gate", "runtime locale refresh should update the host button accessibility text")
	_expect(is_equal_approx(prompt.get_pulse(), 0.5), "prompt pulse should start at its midpoint")
	_expect(is_equal_approx(button.modulate.a, 0.95), "midpoint pulse should preserve the initial button alpha")

	prompt.advance(MainMenuTouchStartPrompt.PULSE_PERIOD_SEC * 0.25, false)
	_expect(is_equal_approx(prompt.get_pulse(), 1.0), "quarter-period advance should reach the pulse peak")
	_expect(is_equal_approx(button.modulate.a, 1.0), "pulse peak should reach full button alpha")
	var peak_alpha := button.modulate.a
	prompt.advance(MainMenuTouchStartPrompt.PULSE_PERIOD_SEC * 0.25, true)
	_expect(is_equal_approx(button.modulate.a, peak_alpha), "active transition should freeze the visible prompt state")

	prompt.queue_redraw()
	await process_frame
	host.queue_free()
	await process_frame

	if failure_count > 0:
		quit(1)
		return
	print("main_menu_touch_start_prompt_smoke: ok")
	quit(0)


func _verify_localized_copy() -> void:
	var expected := {
		"ko": "문을 두드려 귀문을 연다",
		"en": "Knock to open the spirit gate",
		"zh": "叩门开启鬼门",
		"ja": "門を叩いて鬼門を開く",
		"es": "Llama para abrir el portal",
		"pt-BR": "Bata para abrir o portal",
		"ru": "Постучите, чтобы открыть врата",
	}
	for locale in expected:
		LanguageSettings.set_test_locale_override(locale)
		_expect(LanguageSettings.translate("main_menu.start_prompt") == expected[locale], "start prompt should ship the approved %s locale copy" % locale)
	LanguageSettings.set_test_locale_override("")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
