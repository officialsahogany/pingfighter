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
const EXPECTED_LEG_COUNT := 8

var _failures: Array[String] = []
var _leg_count := 0
var _catalog: Object = PhysiqueTrainingCatalog.new()
var _character_runtime: Object = PlayerCharacterRuntime.new()


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_source_mapping_and_exclusions()
	_verify_tuned_card_and_stat_ledger_values()
	_verify_taeheo_production_hover_projection()
	_verify_shared_fuel_pouch_sync_contract()
	_verify_prediction_matches_actual_apply()
	_verify_maximum_has_no_preview()
	_verify_hover_release_blink_and_idle_cost()
	_verify_surface_scope_and_render_contracts()
	_expect(_leg_count == EXPECTED_LEG_COUNT, "all training preview smoke legs must execute")
	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("training_card_stat_preview_smoke: PASS=%d" % _leg_count)
		print("training_card_stat_preview_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_source_mapping_and_exclusions() -> void:
	_leg_count += 1
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


func _verify_tuned_card_and_stat_ledger_values() -> void:
	_leg_count += 1
	var expected_cards := {
		"physique_paddle_size": ["철산공 수련", "paddle_size_bonus_pct", 2.0, "몸집 크기 2% 증가"],
		"physique_dash_recovery": ["수세결 수련", "dash_recovery_reduction_pct", 6.0, "활주 후딜 6% 감소"],
		"physique_chosik_cooldown": ["조식심법 수련", "chosik_cooldown_reduction_pct", 3.0, "초식 쿨타임 3% 감소"],
		"physique_dash_recharge": ["회기보 수련", "dash_recharge_reduction_pct", 4.0, "활주 재충전 시간 4% 감소"],
	}
	for training_id: String in expected_cards:
		var expected: Array = expected_cards[training_id] as Array
		var card: Dictionary = _catalog.build_card(training_id, 0)
		_expect(str(card.get("name", "")) == str(expected[0]), "%s name-to-stat mapping must stay canonical" % training_id)
		_expect(str(card.get("training_stat_key", "")) == str(expected[1]), "%s stat mapping must stay canonical" % training_id)
		_expect(is_equal_approx(float(card.get("training_amount", 0.0)), float(expected[2])), "%s card must carry the tuned amount" % training_id)
		_expect(str(card.get("description", "")) == str(expected[3]), "%s card must display the tuned amount" % training_id)

	var expected_rows := {
		"physique_paddle_size": ["몸집 크기", "158px"],
		"physique_dash_recovery": ["활주 후딜 시간", "0.66초"],
		"physique_dash_recharge": ["활주 재충전", "4.80초"],
	}
	for training_id: String in expected_rows:
		var fixture: Dictionary = _build_fixture()
		var state: Object = fixture["state"]
		var owner: Object = fixture["owner"]
		var registry: Object = fixture["registry"]
		_expect(state.apply_choice(_catalog.build_card(training_id, 0), owner, registry), "%s tuned ledger fixture must apply" % training_id)
		var expected: Array = expected_rows[training_id] as Array
		var row := _row_by_label(_build_rows(state, owner, registry), str(expected[0]))
		_expect(not row.is_empty(), "%s must retain its production stats-panel row" % training_id)
		_expect(str(row.get("value", "")) == str(expected[1]), "%s stats-panel value should be %s, got %s" % [training_id, expected[1], row.get("value", "")])

	var chosik_fixture: Dictionary = _build_fixture()
	var chosik_state: Object = chosik_fixture["state"]
	_expect(chosik_state.apply_choice(_catalog.build_card("physique_chosik_cooldown", 0), chosik_fixture["owner"], chosik_fixture["registry"]), "Chosik tuned consumer fixture must apply")
	_expect(is_equal_approx(chosik_state.get_player_skill_cooldown_seconds(20.0), 19.4), "Chosik tuned card must reach the shared cooldown consumer")
	print("training_card_stat_preview_smoke: tuned=철산공2/수세결6/조식심법3/회기보4 ledger=158px/0.66초/4.80초 chosik20s=19.4s")


func _verify_taeheo_production_hover_projection() -> void:
	_leg_count += 1
	var fixture: Dictionary = _build_fixture()
	var state: Object = fixture["state"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var mythic: Object = registry.get_instance("mythic_item_runtime")
	# The stats context already supplies the authoritative runtime state, while
	# the shared mythic runtime's compatibility cache can still be unset on the
	# card-opening frame. Taeheo must project from the supplied context.
	mythic.runtime_perk_state_ref = null
	state.runtime_skill_levels["training_mastery"] = 3
	state.item_perk_level_bonus = 2
	var card: Dictionary = _catalog.build_card(
		"physique_max_gauge",
		state.get_physique_training_count("physique_max_gauge"),
		state.get_physique_training_multiplier()
	)
	var card_rect := Rect2(100.0, 80.0, 240.0, 320.0)
	var renderer := RuntimePerkOverlayRenderer.new()
	var preview: Dictionary = renderer._resolve_training_stat_preview(
		state,
		state.get_snapshot(),
		owner,
		registry,
		[card],
		[card_rect],
		card_rect.get_center()
	)
	print(
		"[TrainingCardStatPreview] taeheo_hover row_index=%d current_fill_ratio=%.6f projected_fill_ratio=%.6f reason=%s"
		% [
			int(preview.get("row_index", -1)),
			float(preview.get("current_fill_ratio", -1.0)),
			float(preview.get("projected_fill_ratio", -1.0)),
			str(preview.get("reason", "missing")),
		]
	)
	_expect(int(preview.get("row_index", -1)) == 3, "Taeheo production hover must resolve the max-gauge row")
	_expect(bool(preview.get("visible", false)), "Taeheo production hover must expose a visible projection: %s" % preview)
	_expect(
		float(preview.get("projected_fill_ratio", -1.0)) > float(preview.get("current_fill_ratio", -1.0)),
		"Taeheo production hover must increase the max-gauge fill ratio: %s" % preview
	)
	if not bool(preview.get("visible", false)):
		return
	_expect(state.apply_choice(card, owner, registry), "Taeheo production-hover fixture must apply one real step")
	var actual_rows: Array = _build_rows(state, owner, registry)
	var actual_row: Dictionary = actual_rows[int(preview.get("row_index", -1))] as Dictionary
	_expect(
		str(actual_row.get("value", "")) == str(preview.get("projected_value", "")),
		"Taeheo hover projected value must equal the actual one-step value"
	)
	_expect(
		is_equal_approx(
			CharacterInfoOverlayStatsPresenter.player_stat_row_fill_ratio(actual_row),
			float(preview.get("projected_fill_ratio", -1.0))
		),
		"Taeheo hover projected fill must equal the actual one-step fill"
	)


func _verify_shared_fuel_pouch_sync_contract() -> void:
	_leg_count += 1
	var fixture: Dictionary = _build_fixture()
	var state: Object = fixture["state"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var mythic: Object = registry.get_instance("mythic_item_runtime")
	state.runtime_skill_levels["fuel_pouch"] = 2
	mythic.runtime_perk_state_ref = state
	owner.special_gauge = 250.0
	var constants := {"base_special_gauge_max": CharacterInfoOverlayState.SPECIAL_GAUGE_MAX}
	var syncer := MythicItemOwnerSyncer.new()
	var expected: Dictionary = syncer.build_fuel_pouch_gauge_projection(
		mythic,
		constants,
		owner.special_gauge
	)
	syncer.sync_fuel_pouch_gauge_max(mythic, owner, constants)
	_expect(not expected.is_empty(), "the shared fuel-pouch sync projection must stay available")
	_expect(
		is_equal_approx(owner.special_gauge, float(expected.get("next_gauge", -1.0)))
		and is_equal_approx(owner.special_gauge_max, float(expected.get("next_max", -1.0)))
		and is_equal_approx(
			mythic.synced_special_gauge_unblessed_max,
			float(expected.get("next_unblessed_max", -1.0))
		)
		and is_equal_approx(
			mythic.synced_angel_gauge_multiplier,
			float(expected.get("next_angel_multiplier", -1.0))
		),
		"sync_fuel_pouch_gauge_max must retain the existing owner/cache mutation contract"
	)


func _verify_prediction_matches_actual_apply() -> void:
	_leg_count += 1
	var other_training_count := 0
	for training_id: String in PREVIEWABLE_TRAINING_IDS:
		if training_id != "physique_max_gauge":
			other_training_count += 1
		var fixture: Dictionary = _build_fixture()
		var state: Object = fixture["state"]
		var owner: Object = fixture["owner"]
		var registry: Object = fixture["registry"]
		# Effective star 5 is deliberately above the authored 3-star ceiling. The
		# preview must inherit the same 2.4x Training Mastery multiplier as apply.
		state.runtime_skill_levels["training_mastery"] = 3
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
		var stat_key := str(card.get("training_stat_key", ""))
		_expect(
			is_equal_approx(
				float(card.get("training_value_after", -1.0)),
				float(state.get_physique_training_bonus(stat_key))
			),
			"%s card accumulated value must equal the applied training bonus" % training_id
		)
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
	_expect(other_training_count == 8, "all eight non-Taeheo preview routes must execute unchanged")


func _verify_maximum_has_no_preview() -> void:
	_leg_count += 1
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
	_leg_count += 1
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
	_leg_count += 1
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


func _row_by_label(rows: Array, label: String) -> Dictionary:
	for row_value: Variant in rows:
		if row_value is Dictionary and str((row_value as Dictionary).get("label", "")) == label:
			return row_value as Dictionary
	return {}


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
