extends RefCounted

# Stage 8 미노타우로스 boss skill-card HUD (Slice 1 THIN STUB).
# The minotaur has NO skill card yet — the earthquake card lands in Slice 5.
# This owner preserves the public surface the stage8 pillar_scene_drawer calls
# (prewarm hooks + draw) but the body is a safe no-op: it draws nothing and
# wires NO not-yet-generated skillcard PNG paths into any per-frame path.

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const Stage8MinotaurBossSkillHudAssets := preload("res://scripts/stages/stage8/stage8_minotaur_boss_skill_hud_assets.gd")

# Slice 1: no skill cards yet, so nothing to prewarm.
const PREWARM_SKILL_IDS: Array = []

var _queue_positions: Dictionary = {}
var _prewarm_step_index := 0
var _prewarmed := false


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	# No stage8 skillcard textures exist yet — complete immediately (no-op).
	if _prewarmed:
		return true
	if _prewarm_step_index >= PREWARM_SKILL_IDS.size():
		_prewarmed = true
		_prewarm_step_index = 0
		return true
	_prewarm_step_index += 1
	if _prewarm_step_index >= PREWARM_SKILL_IDS.size():
		_prewarmed = true
		_prewarm_step_index = 0
		return true
	return false


func reset() -> void:
	_queue_positions.clear()


func get_debug_card_metrics(pillar_width: float) -> Dictionary:
	return BossSkillCardHudSpec.get_card_metrics(pillar_width)


func build_card_layout(_context: Dictionary) -> Dictionary:
	# Slice 1 stub: the minotaur owns no skill card, so there is never a layout.
	return {}


func draw(canvas: CanvasItem, context: Dictionary) -> void:
	# Safe no-op for the placeholder shell. Stage guard + empty layout means
	# nothing is drawn and no reserved asset path is touched.
	if canvas == null or int(context.get("current_stage", 1)) != 8:
		return
	var layout := build_card_layout(context)
	if layout.is_empty():
		return


func get_asset_status() -> Dictionary:
	# No skillcard textures wired in Slice 1 — always code-native placeholder.
	return {
		"earthquake_card_texture": false,
		"uses_code_native_placeholder": true,
	}
