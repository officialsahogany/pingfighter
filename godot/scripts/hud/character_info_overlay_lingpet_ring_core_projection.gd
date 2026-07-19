extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")

const CHIP_PIP_WIDTH := 8.0
const CHIP_PIP_HEIGHT := 7.0
const CHIP_PIP_GAP := 2.0


static func build_row(snapshot: Dictionary, rect: Rect2) -> Dictionary:
	var tier := clampi(int(snapshot.get("ring_core_tier", 0)), 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	var chip_count := clampi(int(snapshot.get("affinity_chip_count", 0)), 0, LingpetAffinityState.MAX_ENHANCEMENT_CHIPS)
	var slot_size := clampf(rect.size.y - 6.0, 42.0, 58.0)
	var ring_core_rect := Rect2(rect.position + Vector2(0.0, (rect.size.y - slot_size) * 0.5), Vector2(slot_size, slot_size))
	var chip_pips_x := ring_core_rect.end.x + 7.0
	var pips_width := chip_pips_width()
	return {
		"tier": tier,
		"chip_count": chip_count,
		"ring_core_rect": ring_core_rect,
		"chip_pips_rect": Rect2(chip_pips_x, rect.position.y, pips_width, rect.size.y),
		"chip_pips_hover_rect": Rect2(chip_pips_x - 3.0, rect.position.y, pips_width + 6.0, rect.size.y),
		"text_x": chip_pips_x + pips_width + 11.0,
		"title_text": LanguageSettings.translate_text("링코어"),
		"tier_text": "T%d" % tier if tier > 0 else LanguageSettings.translate_text("미장착"),
		"chip_text": LanguageSettings.translate_text("강화칩 %d / %d") % [chip_count, LingpetAffinityState.MAX_ENHANCEMENT_CHIPS],
	}


static func hover_target(row_rect: Rect2, pips_rect: Rect2, mouse_pos: Vector2) -> StringName:
	if pips_rect.has_point(mouse_pos):
		return &"chip"
	if row_rect.has_point(mouse_pos):
		return &"ring_core"
	return &""


static func tooltip_spec(tier: int, chip_count: int, target: StringName) -> Dictionary:
	if target == &"chip":
		return {
			"title": LanguageSettings.translate_text("강화칩 %d / %d") % [chip_count, LingpetAffinityState.MAX_ENHANCEMENT_CHIPS],
			"subtitle": "",
			"body": LanguageSettings.translate_text("친밀도 획득량 +%d%%") % (chip_count * 20),
			"color_key": "chip",
		}
	if target == &"ring_core":
		return {
			"title": LanguageSettings.translate_text("링코어"),
			"subtitle": "T%d" % tier if tier > 0 else LanguageSettings.translate_text("미장착"),
			"body": LanguageSettings.translate_text("친밀도 상한 Lv.%d") % LingpetRingCoreRules.get_ring_core_cap_for_tier(tier),
			"color_key": "ring_core",
		}
	return {}


static func icon_rect(slot_rect: Rect2) -> Rect2:
	return slot_rect.grow(-4.0)


static func chip_pips_width() -> float:
	return CHIP_PIP_WIDTH if LingpetAffinityState.MAX_ENHANCEMENT_CHIPS > 0 else 0.0


static func build_vertical_pips(rect: Rect2, chip_count: int) -> Array[Dictionary]:
	var max_chips := LingpetAffinityState.MAX_ENHANCEMENT_CHIPS
	var pips: Array[Dictionary] = []
	if max_chips <= 0:
		return pips
	var normalized_count := clampi(chip_count, 0, max_chips)
	var total_h := float(max_chips) * CHIP_PIP_HEIGHT + float(maxi(0, max_chips - 1)) * CHIP_PIP_GAP
	var pip_x := rect.position.x + (rect.size.x - CHIP_PIP_WIDTH) * 0.5
	var pip_y := rect.position.y + (rect.size.y - total_h) * 0.5
	for index in range(max_chips):
		pips.append({
			"rect": Rect2(pip_x, pip_y + float(index) * (CHIP_PIP_HEIGHT + CHIP_PIP_GAP), CHIP_PIP_WIDTH, CHIP_PIP_HEIGHT),
			"filled": index < normalized_count,
		})
	return pips
