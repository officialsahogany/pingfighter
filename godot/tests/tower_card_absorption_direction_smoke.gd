extends SceneTree

const TowerCardAbsorptionTargetResolver := preload(
	"res://scripts/tower_ascent/tower_card_absorption_target_resolver.gd"
)
const TowerStartCardState := preload(
	"res://scripts/tower_ascent/tower_start_card_state.gd"
)
const TowerRewardPickState := preload(
	"res://scripts/tower_ascent/tower_reward_pick_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const VIEW_SIZE := Vector2(2020.0, 1246.0)
const CHOSIK_SLOT_TARGET := Vector2(91.0, 834.0)

var _failures: Array[String] = []


class FakeChosikTargetResolver:
	extends RefCounted

	var calls := 0

	func resolve_target(_choice: Dictionary, _owner: Object, _registry: Object, _view_size: Vector2) -> Dictionary:
		calls += 1
		return {
			"target_pos": CHOSIK_SLOT_TARGET,
			"slot_index": 2,
			"character_type": "smasher",
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_kind_specific_target_resolution()
	_verify_start_and_reward_view_models_share_targets()
	_verify_renderer_path_and_duration()
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("tower_card_absorption_direction_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _resolver_with_fake_chosik_target() -> Object:
	var resolver := TowerCardAbsorptionTargetResolver.new()
	resolver.set("_chosik_target_resolver", FakeChosikTargetResolver.new())
	return resolver


func _verify_kind_specific_target_resolution() -> void:
	var resolver: Object = _resolver_with_fake_chosik_target()
	var gameplay_rng := RandomNumberGenerator.new()
	gameplay_rng.seed = 917231
	var gameplay_rng_state := gameplay_rng.state
	var mugong_target: Dictionary = resolver.resolve_target(
		{"id": "mugong_probe", "start_card_kind": "mugong"},
		null,
		null,
		VIEW_SIZE
	)
	var expected_bottom := Vector2(
		VIEW_SIZE.x * 0.5,
		VIEW_SIZE.y * TowerCardAbsorptionTargetResolver.BOTTOM_CENTER_HEIGHT_RATIO
	)
	_expect(str(mugong_target.get("destination_kind", "")) == TowerCardAbsorptionTargetResolver.DESTINATION_BOTTOM_CENTER, "Mugong must route to the bottom-centre destination")
	_expect((mugong_target.get("target_pos", Vector2.ZERO) as Vector2).is_equal_approx(expected_bottom), "Mugong target must be viewport bottom-centre")
	_expect(not is_equal_approx((mugong_target.get("target_pos", Vector2.ZERO) as Vector2).x, 380.0), "bottom-centre reverse leg must reject the old 760-wide left-pillar x=380 target")

	var start_chosik_target: Dictionary = resolver.resolve_target(
		{"id": "start_chosik", "start_card_kind": "chosik", "unlocks_skill": "ghost_shot"},
		null,
		null,
		VIEW_SIZE
	)
	_expect(str(start_chosik_target.get("destination_kind", "")) == TowerCardAbsorptionTargetResolver.DESTINATION_CHOSIK_SLOT, "start Chosik must retain the Chosik-slot destination")
	_expect((start_chosik_target.get("target_pos", Vector2.ZERO) as Vector2).is_equal_approx(CHOSIK_SLOT_TARGET), "start Chosik must use the existing slot resolver target")
	var reward_chosik_target: Dictionary = resolver.resolve_target(
		{"id": "reward_vision", "reward_pick_kind": "vision", "unlocks_skill": "vision_chosik"},
		null,
		null,
		VIEW_SIZE
	)
	_expect((reward_chosik_target.get("target_pos", Vector2.ZERO) as Vector2).is_equal_approx(CHOSIK_SLOT_TARGET), "reward Vision Chosik must retain the Chosik-slot destination")
	_expect(not (reward_chosik_target.get("target_pos", Vector2.ZERO) as Vector2).is_equal_approx(expected_bottom), "Chosik reverse leg must reject the Mugong bottom-centre target")
	var reward_manual_target: Dictionary = resolver.resolve_target(
		{"id": "unlock_ghost_shot", "reward_pick_kind": "chosik", "unlocks_skill": "ghost_shot"},
		null,
		null,
		VIEW_SIZE
	)
	_expect(
		str(reward_manual_target.get("destination_kind", ""))
			== TowerCardAbsorptionTargetResolver.DESTINATION_CHOSIK_SLOT,
		"ordinary reward Chosik must use the same five-orb destination as Vision"
	)
	_expect(
		(reward_manual_target.get("target_pos", Vector2.ZERO) as Vector2).is_equal_approx(
			CHOSIK_SLOT_TARGET
		),
		"ordinary reward Chosik must land on the existing Chosik slot resolver target"
	)
	_expect(gameplay_rng.state == gameplay_rng_state, "absorption target resolution must not advance gameplay RNG state")


func _verify_start_and_reward_view_models_share_targets() -> void:
	var start_resolver: Object = _resolver_with_fake_chosik_target()
	var start_state := TowerStartCardState.new()
	var start_cards: Array[Dictionary] = [{
		"id": "start_mugong",
		"start_card_kind": "mugong",
		"start_card_selected": true,
		"enabled": false,
	}]
	start_state.set("_card_choices", start_cards)
	start_state.set("_selected_index", 0)
	start_state.set("_absorb_elapsed_sec", TowerAscentTuning.TEMP_START_CARD_ABSORB_DURATION_SEC * 0.5)
	start_state.set("_absorption_target_resolver", start_resolver)
	var start_model: Dictionary = start_state.build_view_model(VIEW_SIZE)
	var start_effect: Dictionary = start_model.get("absorption_effect", {}) if start_model.get("absorption_effect", {}) is Dictionary else {}
	_expect(str(start_effect.get("destination_kind", "")) == TowerCardAbsorptionTargetResolver.DESTINATION_BOTTOM_CENTER, "start-card view model must expose the Mugong bottom-centre flight")
	_expect(is_equal_approx(float(start_effect.get("progress", -1.0)), 0.5), "start-card absorption progress must use the existing duration clock")
	_expect(bool(((start_model.get("choices", []) as Array)[0] as Dictionary).get("start_card_absorbing", false)), "start-card description/card slot must expose the absorbing state")

	var reward_resolver: Object = _resolver_with_fake_chosik_target()
	var reward_state := TowerRewardPickState.new()
	reward_state.choices.assign([{
		"id": "unlock_ghost_shot",
		"reward_pick_kind": "chosik",
		"reward_pick_cost": 3,
		"unlocks_skill": "ghost_shot",
	}])
	reward_state.spent_flags.assign([true])
	reward_state.purchase_absorption_effects.assign([{
		"slot_index": 0,
		"elapsed": TowerRewardPickState.TEMP_REWARD_PICK_ABSORB_DURATION_SEC * 0.5,
		"duration": TowerRewardPickState.TEMP_REWARD_PICK_ABSORB_DURATION_SEC,
	}])
	reward_state.set("_absorption_target_resolver", reward_resolver)
	var reward_model: Dictionary = reward_state.build_view_model(VIEW_SIZE)
	var reward_effects: Array = reward_model.get("purchase_absorption_effects", []) if reward_model.get("purchase_absorption_effects", []) is Array else []
	_expect(reward_effects.size() == 1, "reward view model must retain one active absorption effect")
	if reward_effects.size() == 1:
		var reward_effect := reward_effects[0] as Dictionary
		_expect(str(reward_effect.get("destination_kind", "")) == TowerCardAbsorptionTargetResolver.DESTINATION_CHOSIK_SLOT, "reward Chosik view model must expose the slot destination")
		_expect((reward_effect.get("target_pos", Vector2.ZERO) as Vector2).is_equal_approx(CHOSIK_SLOT_TARGET), "reward Chosik effect must land on the existing slot position")


func _verify_renderer_path_and_duration() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var source_rect := Rect2(Vector2(700.0, 310.0), Vector2(320.0, 410.0))
	var target := Vector2(VIEW_SIZE.x * 0.5, VIEW_SIZE.y * 0.91)
	var lift_progress := RuntimePerkOverlayRenderer.TEMP_TOWER_REWARD_ABSORB_LIFT_RATIO * 0.5
	var lifted_mid: Vector2 = renderer._tower_reward_absorption_position(source_rect, {"target_pos": target}, lift_progress)
	_expect(is_equal_approx(lifted_mid.x, source_rect.get_center().x), "30px lift phase must preserve x")
	_expect(lifted_mid.y < source_rect.get_center().y, "existing 30px lift phase must remain before the destination flight")
	var arrived: Vector2 = renderer._tower_reward_absorption_position(source_rect, {"target_pos": target}, 1.0)
	_expect(arrived.is_equal_approx(target), "shared absorption curve must finish exactly at its kind-specific target")
	_expect(is_equal_approx(TowerAscentTuning.TEMP_START_CARD_ABSORB_DURATION_SEC, 0.78), "start-card 0.78s duration remains suitable for the bottom-centre path")
	_expect(is_equal_approx(TowerRewardPickState.TEMP_REWARD_PICK_ABSORB_DURATION_SEC, TowerAscentTuning.TEMP_START_CARD_ABSORB_DURATION_SEC), "start and reward absorption durations must remain lockstep")

	var renderer_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	var start_begin := renderer_source.find("func draw_tower_start_card(")
	var start_end := renderer_source.find("func draw_tower_reward_pick(", start_begin)
	var absorption_begin := renderer_source.find("func _build_tower_reward_absorbing_rect(")
	var absorption_end := renderer_source.find("func _runtime_state_has_visible_effects(", absorption_begin)
	_expect(start_begin >= 0 and start_end > start_begin, "start-card renderer source boundary must remain discoverable")
	if start_begin >= 0 and start_end > start_begin:
		var start_source := renderer_source.substr(start_begin, start_end - start_begin)
		_expect(start_source.find("_build_tower_reward_absorbing_rect(") >= 0, "start cards must reuse the reward absorption curve")
		_expect(start_source.find("_draw_tower_reward_absorption(") >= 0, "start cards must reuse the reward absorption particles")
	_expect(absorption_begin >= 0 and absorption_end > absorption_begin, "shared absorption renderer source boundary must remain discoverable")
	if absorption_begin >= 0 and absorption_end > absorption_begin:
		var absorption_source := renderer_source.substr(absorption_begin, absorption_end - absorption_begin)
		for forbidden_rng_call in ["randf(", "randi(", "randomize(", "seed("]:
			_expect(absorption_source.find(forbidden_rng_call) < 0, "presentation absorption must not consume gameplay/global RNG via %s" % forbidden_rng_call)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
