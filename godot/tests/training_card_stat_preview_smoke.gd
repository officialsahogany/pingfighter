extends SceneTree

const CharacterInfoOverlayState := preload("res://scripts/hud/character_info_overlay_state.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const MythicItemOwnerSyncer := preload("res://scripts/items/mythic_item_owner_syncer.gd")
const MythicItemResourceBonusRuntime := preload("res://scripts/items/mythic_item_resource_bonus_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PhysiqueTrainingCatalog := preload("res://scripts/characters/physique_training_catalog.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkTrainingStatPreview := preload("res://scripts/characters/runtime_perk_training_stat_preview.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")

const PREVIEWABLE_TRAINING_IDS: Array[String] = [
	"physique_dash_recharge",
	"physique_dash_recovery",
	"physique_dash_distance",
	"physique_move_speed",
	"physique_posture",
	"physique_paddle_size",
	"physique_max_gauge",
	"physique_hit_gauge",
	"physique_active_item_cooldown",
]

var _failures: Array[String] = []
var _catalog: Object = PhysiqueTrainingCatalog.new()
var _character_runtime: Object = PlayerCharacterRuntime.new()


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_source_mapping_and_exclusions()
	_verify_prediction_matches_actual_apply()
	_verify_maximum_has_no_preview()
	_verify_hover_release_blink_and_idle_cost()
	_verify_surface_scope_and_render_contracts()
	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("training_card_stat_preview_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_source_mapping_and_exclusions() -> void:
	var resolver := RuntimePerkTrainingStatPreview.new()
	for training_id: String in PREVIEWABLE_TRAINING_IDS:
		var card: Dictionary = _catalog.build_card(training_id, 0)
		var source_perk_id := str(card.get("source_perk_id", ""))
		_expect(source_perk_id != "", "%s must retain a source_perk_id" % training_id)
		_expect(
			resolver.is_source_previewable(source_perk_id),
			"%s source %s must resolve to a continuous stats row" % [training_id, source_perk_id]
		)
	_expect(
		not resolver.is_source_previewable(str(_catalog.build_card("physique_chosik_cooldown", 0).get("source_perk_id", ""))),
		"Chosik cooldown must stay excluded while the ten-row ledger has no Chosik cooldown row"
	)
	var storage_card: Dictionary = _catalog.build_card("physique_storage", 0)
	_expect(str(storage_card.get("source_perk_id", "")) == "", "storage must retain its empty source_perk_id contract")
	_expect(
		not resolver.is_source_previewable(str(storage_card.get("source_perk_id", ""))),
		"storage must stay excluded because its slot row has no continuous gauge"
	)


func _verify_prediction_matches_actual_apply() -> void:
	for training_id: String in PREVIEWABLE_TRAINING_IDS:
		var fixture: Dictionary = _build_fixture()
		var state: Object = fixture["state"]
		var owner: Object = fixture["owner"]
		var registry: Object = fixture["registry"]
		# Effective Lv.7 is deliberately above the authored Lv.5 ceiling. The
		# preview must inherit the same 2.4x Training Mastery multiplier as apply.
		state.runtime_skill_levels["training_mastery"] = 5
		state.item_perk_level_bonus = 2
		var card: Dictionary = _catalog.build_card(
			training_id,
			0,
			state.get_physique_training_multiplier()
		)
		var before_snapshot: Dictionary = state.get_physique_training_snapshot()
		var before_owner_gauge_max: float = owner.special_gauge_max
		var before_owner_width: float = owner.player_paddle_width
		var resolver := RuntimePerkTrainingStatPreview.new()
		var preview: Dictionary = resolver.build_preview(
			state,
			card,
			owner,
			registry,
			_character_runtime
		)
		_expect(bool(preview.get("visible", false)), "%s must produce a visible one-step preview: %s" % [training_id, preview])
		_expect(
			state.get_physique_training_snapshot() == before_snapshot,
			"%s preview must not mutate the live training state" % training_id
		)
		_expect(
			is_equal_approx(owner.special_gauge_max, before_owner_gauge_max)
			and is_equal_approx(owner.player_paddle_width, before_owner_width),
			"%s preview must not mutate the battle owner" % training_id
		)
		if not bool(preview.get("visible", false)):
			continue
		_expect(state.apply_choice(card, owner, registry), "%s actual one-step choice must apply" % training_id)
		var actual_rows: Array = _build_rows(state, owner, registry)
		var row_index := int(preview.get("row_index", -1))
		_expect(row_index >= 0 and row_index < actual_rows.size(), "%s preview row must exist after apply" % training_id)
		if row_index < 0 or row_index >= actual_rows.size():
			continue
		var actual_row: Dictionary = actual_rows[row_index] as Dictionary
		var actual_fill := CharacterInfoOverlayStatsPresenter.player_stat_row_fill_ratio(actual_row)
		_expect(
			str(actual_row.get("value", "")) == str(preview.get("projected_value", "")),
			"%s projected value %s must equal actual value %s" % [training_id, preview.get("projected_value", ""), actual_row.get("value", "")]
		)
		_expect(
			is_equal_approx(actual_fill, float(preview.get("projected_fill_ratio", -1.0))),
			"%s projected fill %.6f must equal actual fill %.6f" % [training_id, float(preview.get("projected_fill_ratio", -1.0)), actual_fill]
		)


func _verify_maximum_has_no_preview() -> void:
	var fixture: Dictionary = _build_fixture()
	var state: Object = fixture["state"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var count := 0
	while not state.is_physique_training_saturated("physique_posture", registry) and count < 30:
		_expect(
			state.apply_choice(_catalog.build_card("physique_posture", count), owner, registry),
			"posture saturation fixture acquisition %d must apply" % count
		)
		count += 1
	_expect(state.is_physique_training_saturated("physique_posture", registry), "posture fixture must reach the production 100 percent clamp")
	var preview: Dictionary = RuntimePerkTrainingStatPreview.new().build_preview(
		state,
		_catalog.build_card("physique_posture", count),
		owner,
		registry,
		_character_runtime
	)
	_expect(not bool(preview.get("visible", true)), "a saturated training must not expose a blinking segment")
	_expect(str(preview.get("reason", "")) == "saturated", "the maximum negative leg must be rejected by the production saturation probe")


func _verify_hover_release_blink_and_idle_cost() -> void:
	var fixture: Dictionary = _build_fixture()
	var state: Object = fixture["state"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var renderer := RuntimePerkOverlayRenderer.new()
	var card: Dictionary = _catalog.build_card("physique_move_speed", 0)
	var card_rect := Rect2(100.0, 80.0, 240.0, 320.0)
	var snapshot: Dictionary = state.get_snapshot()
	var idle_count := renderer.get_training_stat_preview_build_count_for_tests()
	var no_hover: Dictionary = renderer._resolve_training_stat_preview(
		state,
		snapshot,
		owner,
		registry,
		[card],
		[card_rect],
		Vector2(20.0, 20.0)
	)
	_expect(no_hover.is_empty(), "no card hover must return the untouched baseline")
	_expect(
		renderer.get_training_stat_preview_build_count_for_tests() == idle_count,
		"GRT-043: no hover must not execute the production-row projection"
	)
	var hovered: Dictionary = renderer._resolve_training_stat_preview(
		state,
		snapshot,
		owner,
		registry,
		[card],
		[card_rect],
		card_rect.get_center()
	)
	_expect(bool(hovered.get("visible", false)), "a hovered mapped training must resolve its preview")
	_expect(
		renderer.get_training_stat_preview_build_count_for_tests() == idle_count + 1,
		"the first eligible hover must build exactly one projection"
	)
	var cached_hover: Dictionary = renderer._resolve_training_stat_preview(
		state,
		snapshot,
		owner,
		registry,
		[card],
		[card_rect],
		card_rect.get_center()
	)
	_expect(cached_hover == hovered, "an unchanged hover must reuse the projected model")
	_expect(
		renderer.get_training_stat_preview_build_count_for_tests() == idle_count + 1,
		"blink redraws must not rebuild the projection"
	)
	var released: Dictionary = renderer._resolve_training_stat_preview(
		state,
		snapshot,
		owner,
		registry,
		[card],
		[card_rect],
		Vector2(20.0, 20.0)
	)
	_expect(released.is_empty(), "hover release must remove the preview immediately")
	_expect(
		renderer.get_training_stat_preview_build_count_for_tests() == idle_count + 1,
		"hover release must not run another projection"
	)
	_expect(RuntimePerkOverlayRenderer.is_training_stat_preview_visible_at(100), "the deterministic wall-clock visible phase must show the segment")
	_expect(not RuntimePerkOverlayRenderer.is_training_stat_preview_visible_at(500), "the deterministic wall-clock hidden phase must remove the segment")
	_expect(RuntimePerkOverlayRenderer.is_training_stat_preview_visible_at(900), "the visible phase must repeat without gameplay RNG")
	# The blink is a raised-cosine fade, not a square wave. Assert the shape:
	# it rests at full and at zero, ramps monotonically between them, and repeats
	# on the same deterministic wall clock.
	var cycle: int = RuntimePerkOverlayRenderer.TRAINING_STAT_PREVIEW_BLINK_CYCLE_MSEC
	_expect(
		is_equal_approx(RuntimePerkOverlayRenderer.training_stat_preview_alpha_at(0), 1.0),
		"the fade must rest at full opacity on the cycle boundary"
	)
	_expect(
		is_zero_approx(RuntimePerkOverlayRenderer.training_stat_preview_alpha_at(cycle / 2)),
		"the fade must rest at zero opacity at the trough"
	)
	var previous_alpha: float = RuntimePerkOverlayRenderer.training_stat_preview_alpha_at(0)
	var monotone_down := true
	var intermediate_seen := false
	for step in range(1, cycle / 2 + 1):
		var current_alpha: float = RuntimePerkOverlayRenderer.training_stat_preview_alpha_at(step)
		if current_alpha > previous_alpha + 0.000001:
			monotone_down = false
		if current_alpha > 0.02 and current_alpha < 0.98:
			intermediate_seen = true
		previous_alpha = current_alpha
	_expect(monotone_down, "the fade-out half must never brighten")
	_expect(intermediate_seen, "a square wave would skip every partial opacity step")
	_expect(
		is_equal_approx(
			RuntimePerkOverlayRenderer.training_stat_preview_alpha_at(120),
			RuntimePerkOverlayRenderer.training_stat_preview_alpha_at(120 + cycle)
		),
		"the fade must repeat exactly one cycle later"
	)
	_expect(
		not CharacterInfoOverlayStatsPresenter.draw_player_stat_preview_segment(
			null, Rect2(50.0, 500.0, 900.0, 260.0), CharacterInfoOverlayState.STAT_ROW_COUNT, 0, 0.2, 0.6, 1.0, 0.0
		),
		"a fully faded frame must not draw"
	)
	var gauge_rect := CharacterInfoOverlayStatsPresenter.player_stat_gauge_rect(
		Rect2(50.0, 500.0, 900.0, 260.0),
		CharacterInfoOverlayState.STAT_ROW_COUNT,
		int(hovered.get("row_index", -1)),
		CharacterInfoOverlayState.UI_TEXT_SCALE
	)
	_expect(gauge_rect.size.x >= 70.0, "the preview segment must reuse a realizable production gauge row")


func _verify_surface_scope_and_render_contracts() -> void:
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/hud/runtime_perk_overlay_renderer.gd"
	)
	var presenter_source := FileAccess.get_file_as_string(
		"res://scripts/hud/character_info_overlay_stats_presenter.gd"
	)
	var tower_renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	var ordinary_draw := _function_body(renderer_source, "func draw(")
	var reward_draw := _function_body(renderer_source, "func draw_tower_reward_pick(")
	var start_draw := _function_body(renderer_source, "func draw_tower_start_card(")
	var node_modal_draw := _function_body(tower_renderer_source, "func _draw_node_modal(")
	var gauge_draw := _function_body(presenter_source, "static func _draw_stat_gauge_bar(")
	var segment_draw := _function_body(
		presenter_source,
		"static func draw_player_stat_preview_segment("
	)
	_expect(
		ordinary_draw.contains("_draw_stats_band(")
		and ordinary_draw.contains("runtime_state.get_card_rects(view_size)"),
		"ordinary perk choices must pass their cards and production hit rects to the shared preview drawer"
	)
	_expect(
		reward_draw.contains("_draw_stats_band(")
		and reward_draw.contains("choices,")
		and reward_draw.contains("rects"),
		"tower reward choices must pass their cards and reward-owned rects to the same preview drawer"
	)
	_expect(
		not start_draw.contains("_draw_stats_band("),
		"the user-removed start-card bottom stats panel must not be restored"
	)
	_expect(
		not node_modal_draw.contains("_draw_stats_band("),
		"training and fallen-monk node modals must not grow a new stats band"
	)
	_expect(
		gauge_draw.contains("lerpf(left_x, right_x"),
		"the shipped stats band must remain a continuous gauge instead of being discretized"
	)
	_expect(
		segment_draw.contains("current_x")
		and segment_draw.contains("projected_x")
		and not segment_draw.contains("rand"),
		"the overlay must draw only the deterministic current-to-projected interval"
	)


func _build_fixture() -> Dictionary:
	var state := RuntimePerkState.new()
	var owner := PreviewOwner.new()
	var mythic := PreviewMythicRuntime.new()
	var registry := PreviewRegistry.new()
	mythic.runtime_perk_state_ref = state
	registry.instances = {
		"runtime_perk_state": state,
		"mythic_item_runtime": mythic,
	}
	return {"state": state, "owner": owner, "registry": registry}


func _build_rows(state: Object, owner: Object, registry: Object) -> Array:
	return CharacterInfoOverlayStatsPresenter.build_player_stat_rows(
		owner,
		registry,
		_character_runtime,
		state,
		null,
		null,
		"",
		[],
		-1,
		null,
		CharacterInfoOverlayState.SPECIAL_GAUGE_MAX,
		CharacterInfoOverlayState.PLAYER_BASE_PADDLE_WIDTH,
		CharacterInfoOverlayState.BASE_ACTIVE_ITEM_SLOT_COUNT,
		CharacterInfoOverlayState.STAT_BUFF_COLOR,
		CharacterInfoOverlayState.STAT_DEBUFF_COLOR,
		false
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	var next_static := source.find("\n\nstatic func ", start + signature.length())
	if next < 0 or (next_static >= 0 and next_static < next):
		next = next_static
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


class PreviewOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var player_pos := Vector2(302.5, 700.0)
	var special_gauge := 250.0
	var special_gauge_max := 500.0
	var active_item_slots: Array = []


class PreviewRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class PreviewMythicRuntime:
	extends RefCounted

	var runtime_perk_state_ref: Object = null
	var synced_special_gauge_max := 500.0
	var synced_special_gauge_unblessed_max := 500.0
	var synced_angel_gauge_multiplier := 1.0
	var _resource_bonus := MythicItemResourceBonusRuntime.new()
	var _owner_syncer := MythicItemOwnerSyncer.new()

	func refresh_runtime_perk_scaling(owner: Object, registry: Object) -> void:
		runtime_perk_state_ref = registry.get_instance("runtime_perk_state") if registry != null else null
		_owner_syncer.sync_fuel_pouch_gauge_max(
			self,
			owner,
			{"base_special_gauge_max": CharacterInfoOverlayState.SPECIAL_GAUGE_MAX}
		)

	func get_effective_special_gauge_max(base_max: float) -> float:
		return _resource_bonus.get_effective_special_gauge_max(self, base_max)

	func calculate_bluetooth_ring_gauge_charge(base_charge: float) -> float:
		return _resource_bonus.calculate_bluetooth_ring_gauge_charge(self, base_charge)

	func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
		var value: Variant = owner.get(key) if owner != null else null
		return fallback if value == null else value
