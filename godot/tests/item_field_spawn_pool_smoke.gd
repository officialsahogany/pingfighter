extends SceneTree

const ActiveItemBoomerangReturnHandler := preload("res://scripts/items/active_item_boomerang_return_handler.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var lingpet_owned_pet_ids: Array = []
	var ai_mode := "champion"
	var megingjord_equipped := false
	var dowsing_pendulum_equipped := false
	var dowsing_pendulum_range := 0.0
	var dowsing_pendulum_context: Dictionary = {}

	func queue_redraw() -> void:
		pass


class FakeRuntimePerkState:
	var runtime_skill_levels: Dictionary = {}

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(runtime_skill_levels.get(skill_id, 0))


class FakeRegistry:
	var mythic_runtime: Object
	var runtime_perk_state: Object

	func _init(runtime: Object, perk_state: Object = null) -> void:
		mythic_runtime = runtime
		runtime_perk_state = perk_state

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_runtime
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null

	# guardian_egg_access_policy reads runtime_perk_state via the non-instantiating
	# cached peek only — expose the same lookup through that surface.
	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FakeCachedPassiveCatalog:
	var field_spawn_call_count := 0

	func get_field_spawn_items() -> Array:
		field_spawn_call_count += 1
		return [{
			"name": "fake_passive",
			"display_name": "Fake Passive",
			"type": "passive",
			"chance": 1.0,
		}]


class FakeEggRuntime:
	var offer := true

	func can_offer_egg_item(_owner: Object, _registry: Object = null) -> bool:
		return offer


class FakeEggRegistry:
	var runtime: Object
	var egg_gate_used_get_instance := false

	func _init(r: Object) -> void:
		runtime = r

	func get_cached_instance(key: String) -> Object:
		if key == "lingpet_egg_runtime":
			return runtime
		return null

	# The lingpet_egg spawn gate must use the cache-only peek; reaching the lingpet
	# runtime through get_instance would be a lazy-instantiation contract violation.
	# Record it so the test fails. (Other keys like mythic_item_runtime may legitimately
	# use get_instance and return null here.)
	func get_instance(key: String) -> Object:
		if key == "lingpet_egg_runtime":
			egg_gate_used_get_instance = true
		return null


func _init() -> void:
	var active_catalog: Object = ActiveItemCatalog.new()
	var mythic_catalog: Object = MythicItemCatalog.new()
	var active_runtime: Object = ActiveItemRuntime.new()
	var mythic_runtime: Object = MythicItemRuntime.new()
	var runtime_perk_state := FakeRuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(mythic_runtime, runtime_perk_state)

	var active_slots: Array = []
	var banana_item: Dictionary = active_catalog.build_item_by_name("banana")
	_expect(not banana_item.is_empty(), "banana should be present in the active item catalog")
	_expect(
		active_runtime._store_active_item({"item_data": banana_item}, active_slots, registry, owner),
		"active field items should route into active slots"
	)
	_expect(active_slots.size() == 1, "active pickup should add one active slot item")

	# lingpet_egg is a one-shot deploy item: a second egg must NOT be stored (it would
	# strand as a dead duplicate, since deploy_egg_from_item returns false once a
	# lingpet exists). The first stores; the second is rejected and stays on the field.
	var egg_slots: Array = []
	var egg_owner := FakeOwner.new()
	# Egg pickup is gated on owning 영혼소환술 since the guardian duration redesign
	# (guardian_egg_access_policy) — grant it so this leg exercises the storage rule.
	runtime_perk_state.runtime_skill_levels["soul_summon_art"] = 1
	var egg_item_a: Dictionary = active_catalog.build_item_by_name("lingpet_egg")
	_expect(not egg_item_a.is_empty(), "lingpet_egg should build in the active item catalog")
	_expect(
		active_runtime._store_active_item({"item_data": egg_item_a}, egg_slots, registry, egg_owner),
		"first lingpet_egg pickup should store into an active slot"
	)
	var egg_item_b: Dictionary = active_catalog.build_item_by_name("lingpet_egg")
	_expect(
		not active_runtime._store_active_item({"item_data": egg_item_b}, egg_slots, registry, egg_owner),
		"a second lingpet_egg pickup must be rejected while one is already held"
	)
	_expect(egg_slots.size() == 1, "rejected duplicate lingpet_egg must not occupy a second active slot")

	var field_spawn_items: Array = mythic_catalog.get_field_spawn_items()
	_expect(_array_has_item(field_spawn_items, "dowsing_pendulum"), "dowsing pendulum should be in the passive field-spawn list")
	_expect(_array_has_item(field_spawn_items, "gravitybelt"), "Gravity Belt should be in the passive field-spawn list")
	_expect(_array_has_item(field_spawn_items, "sensor"), "Danger Sensor Belt should be in the passive field-spawn list")
	_expect(_array_has_item(field_spawn_items, "revival"), "Revival should be in the passive field-spawn list")
	_expect(_array_has_item(field_spawn_items, "smartphone"), "smartphone should be in the passive field-spawn list")
	_expect(_array_has_item(field_spawn_items, "neural_helmet"), "Neural Helmet should be in the passive field-spawn list")
	_expect(_array_has_item(field_spawn_items, "venom_mist_gauntlet"), "Venom Mist Gauntlet should be in the passive field-spawn list")
	_expect(_array_has_item(field_spawn_items, "reinforced_boomerang_gauntlet"), "Reinforced Boomerang Gauntlet should be in the passive field-spawn list")
	_expect(_array_has_item(field_spawn_items, "commando_arm"), "Commando Arm should be in the passive field-spawn list")
	_expect(_array_has_item(field_spawn_items, "gold_bar"), "Gold Bar should be in the passive field-spawn list")
	_expect(_array_has_item(field_spawn_items, "sage_ring"), "Sage Ring should be in the passive field-spawn list")
	_expect(_array_has_item(field_spawn_items, "megingjord"), "megingjord should be in the mythic field-spawn list")
	_expect(_array_has_item(field_spawn_items, "poseidon_trident"), "Poseidon Trident should be in the mythic field-spawn list")
	_expect(_array_has_item(field_spawn_items, "heavenly_cape"), "Heavenly Cape should be in the mythic field-spawn list")
	_expect(_array_has_item(field_spawn_items, "pandora_legacy"), "Pandora Legacy should be in the mythic field-spawn list")
	_expect(_catalog_item_has_chance(field_spawn_items, "dowsing_pendulum"), "dowsing pendulum should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "gravitybelt"), "Gravity Belt should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "sensor"), "Danger Sensor Belt should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "revival"), "Revival should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "smartphone"), "smartphone should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "neural_helmet"), "Neural Helmet should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "venom_mist_gauntlet"), "Venom Mist Gauntlet should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "reinforced_boomerang_gauntlet"), "Reinforced Boomerang Gauntlet should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "commando_arm"), "Commando Arm should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "gold_bar"), "Gold Bar should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "sage_ring"), "Sage Ring should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "megingjord"), "megingjord should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "poseidon_trident"), "Poseidon Trident should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "heavenly_cape"), "Heavenly Cape should have non-zero field chance")
	_expect(_catalog_item_has_chance(field_spawn_items, "pandora_legacy"), "Pandora Legacy should have non-zero field chance")
	_expect_megingjord_smooth_icon(mythic_catalog)

	var dowsing_item: Dictionary = _find_item(field_spawn_items, "dowsing_pendulum")
	_expect(
		active_runtime._store_active_item({"item_data": dowsing_item}, active_slots, registry, owner),
		"passive field items should route into passive inventory"
	)
	_expect(active_slots.size() == 1, "passive pickup should not consume an active slot")
	_expect(_inventory_has_item(mythic_runtime, "dowsing_pendulum"), "dowsing pendulum should be owned after pickup")

	var field_spawn_pool: Object = ActiveItemFieldSpawnPool.new()
	var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
	_expect(not field_spawn_pool.build_catalog_item("dowsing_pendulum").is_empty(), "debug catalog lookup should build passive field-spawn items")
	var candidate_names: Dictionary = field_spawn_pool.get_field_spawn_candidate_names()
	_expect(candidate_names.has("banana"), "field spawn candidates should include active items")
	_expect(candidate_names.has("dowsing_pendulum"), "field spawn candidates should include passive items")
	_expect(candidate_names.has("gravitybelt"), "field spawn candidates should include Gravity Belt")
	_expect(candidate_names.has("sensor"), "field spawn candidates should include Danger Sensor Belt")
	_expect(candidate_names.has("revival"), "field spawn candidates should include Revival")
	_expect(candidate_names.has("smartphone"), "field spawn candidates should include Smartphone")
	_expect(candidate_names.has("neural_helmet"), "field spawn candidates should include Neural Helmet")
	_expect(candidate_names.has("venom_mist_gauntlet"), "field spawn candidates should include Venom Mist Gauntlet when no owner filter is provided")
	_expect(candidate_names.has("reinforced_boomerang_gauntlet"), "field spawn candidates should include Reinforced Boomerang Gauntlet")
	_expect(candidate_names.has("commando_arm"), "field spawn candidates should include Commando Arm")
	_expect(candidate_names.has("gold_bar"), "field spawn candidates should include Gold Bar")
	_expect(candidate_names.has("sage_ring"), "field spawn candidates should include Sage Ring")
	_expect(candidate_names.has("megingjord"), "field spawn candidates should include mythic items")
	_expect(candidate_names.has("poseidon_trident"), "field spawn candidates should include Poseidon Trident")
	_expect(candidate_names.has("heavenly_cape"), "field spawn candidates should include Heavenly Cape")
	_expect(
		field_spawn_controller.get_field_spawn_candidate_names().has("banana"),
		"field spawn controller should delegate candidate names to the spawn pool"
	)
	_verify_lingpet_egg_active_gate()
	var controller_prewarm := ActiveItemFieldSpawnController.new()
	controller_prewarm.prewarm_spawn_candidate_templates()
	var controller_cache_status: Dictionary = controller_prewarm.get_spawn_candidate_cache_status()
	_expect(bool(controller_cache_status.get("active_ready", false)), "field spawn controller prewarm should prepare active item templates")
	_expect(bool(controller_cache_status.get("passive_mythic_ready", false)), "field spawn controller prewarm should prepare passive/mythic templates")
	_expect(int(controller_cache_status.get("active_count", 0)) > 0, "field spawn controller prewarm should cache active item templates")
	_expect(int(controller_cache_status.get("passive_mythic_count", 0)) > 0, "field spawn controller prewarm should cache passive/mythic item templates")
	var staged_controller_prewarm := ActiveItemFieldSpawnController.new()
	_expect(
		not bool(staged_controller_prewarm.prewarm_spawn_candidate_templates_step()),
		"first staged field-spawn prewarm call should not build every item template"
	)
	var staged_guard := 0
	while not bool(staged_controller_prewarm.prewarm_spawn_candidate_templates_step()) and staged_guard < 160:
		staged_guard += 1
	_expect(staged_guard < 160, "staged field-spawn prewarm should complete within a bounded number of steps")
	var staged_controller_cache_status: Dictionary = staged_controller_prewarm.get_spawn_candidate_cache_status()
	_expect(bool(staged_controller_cache_status.get("active_ready", false)), "staged field-spawn prewarm should prepare active item templates")
	_expect(bool(staged_controller_cache_status.get("passive_mythic_ready", false)), "staged field-spawn prewarm should prepare passive/mythic templates")
	_expect(
		field_spawn_controller.debug_spawn_item("dowsing_pendulum"),
		"field spawn controller should debug-spawn passive items by name"
	)
	var debug_spawned_field_item: Dictionary = field_spawn_controller.get_spawned_items()[0]
	var debug_spawned_item_data_value: Variant = debug_spawned_field_item.get("item_data", {})
	var debug_spawned_item_data: Dictionary = {}
	if debug_spawned_item_data_value is Dictionary:
		debug_spawned_item_data = debug_spawned_item_data_value
	_expect(
		str(debug_spawned_item_data.get("name", "")) == "dowsing_pendulum",
		"debug-spawned passive field item should preserve the requested name"
	)

	var base_shares: Dictionary = field_spawn_pool.get_spawn_group_target_shares(
		{"active": 1.0, "passive": 1.0, "mythic": 1.0},
		registry
	)
	_expect_share_close(base_shares, "active", 0.79, "base active field-spawn share should match Python")
	_expect_share_close(base_shares, "passive", 0.20, "base passive field-spawn share should match Python")
	_expect_share_close(base_shares, "mythic", 0.01, "base mythic field-spawn share should match Python")

	runtime_perk_state.runtime_skill_levels["downtown_treasure_map"] = 5
	var level5_shares: Dictionary = field_spawn_pool.get_spawn_group_target_shares(
		{"active": 1.0, "passive": 1.0, "mythic": 1.0},
		registry
	)
	_expect_share_close(level5_shares, "active", 0.565, "Lv.5 treasure map active share should match Python")
	_expect_share_close(level5_shares, "passive", 0.35, "Lv.5 treasure map passive share should match Python")
	_expect_share_close(level5_shares, "mythic", 0.085, "Lv.5 treasure map mythic share should match Python")
	runtime_perk_state.runtime_skill_levels.clear()

	var scaled_weights: Array[Dictionary] = field_spawn_pool.build_group_scaled_spawn_weights(
		field_spawn_pool.build_spawn_candidates(registry),
		{},
		registry
	)
	var scaled_shares: Dictionary = _sum_scaled_group_weights(scaled_weights)
	_expect_share_close(scaled_shares, "active", 0.79, "real candidate active share should be group-scaled")
	_expect_share_close(scaled_shares, "passive", 0.20, "real candidate passive share should be group-scaled")
	_expect_share_close(scaled_shares, "mythic", 0.01, "real candidate mythic share should be group-scaled")

	var passive_candidate: Dictionary = _find_item(field_spawn_pool.build_spawn_candidates(registry), "dowsing_pendulum")
	_expect(not passive_candidate.is_empty(), "field-spawn candidates should include Dowsing Pendulum before selection")
	_expect(_get_dict(passive_candidate.get("rolls", {})).is_empty(), "passive field-spawn candidates should defer random rolls until selection")
	var selected_candidates: Array[Dictionary] = [passive_candidate]
	var selected_passive: Dictionary = field_spawn_pool.build_weighted_spawn_item(selected_candidates, {}, registry)
	_expect(not _get_dict(selected_passive.get("rolls", {})).is_empty(), "selected passive field item should receive random rolls")
	_expect(_get_array(selected_passive.get("rolled_options", [])).size() > 0, "selected passive field item should sync rolled options")
	_expect(not selected_passive.has("_field_spawn_randomize_rolls"), "selected passive field item should not leak internal template markers")

	var cached_pool: Object = ActiveItemFieldSpawnPool.new()
	var fake_catalog := FakeCachedPassiveCatalog.new()
	cached_pool.passive_mythic_catalog = fake_catalog
	_expect(_array_has_item(cached_pool.build_spawn_candidates(), "fake_passive"), "fallback passive catalog should provide cached field candidates")
	_expect(_array_has_item(cached_pool.build_spawn_candidates(), "fake_passive"), "cached fallback passive candidates should remain available")
	_expect(fake_catalog.field_spawn_call_count == 1, "fallback passive catalog field-spawn list should be cached between builds")

	var prewarmed_cached_pool: Object = ActiveItemFieldSpawnPool.new()
	var prewarm_fake_catalog := FakeCachedPassiveCatalog.new()
	prewarmed_cached_pool.passive_mythic_catalog = prewarm_fake_catalog
	prewarmed_cached_pool.prewarm_spawn_candidate_templates()
	_expect(prewarm_fake_catalog.field_spawn_call_count == 1, "field-spawn prewarm should build fallback passive templates once")
	_expect(_array_has_item(prewarmed_cached_pool.build_spawn_candidates(), "fake_passive"), "prewarmed fallback passive candidates should remain available")
	_expect(prewarm_fake_catalog.field_spawn_call_count == 1, "prewarmed fallback passive templates should not rebuild on first spawn candidate build")

	var runtime_prewarm: Object = ActiveItemRuntime.new()
	runtime_prewarm.prewarm_assets()
	var runtime_cache_status: Dictionary = runtime_prewarm.field_spawn_controller.get_spawn_candidate_cache_status()
	_expect(bool(runtime_cache_status.get("active_ready", false)), "active item runtime prewarm should prepare field active templates")
	_expect(bool(runtime_cache_status.get("passive_mythic_ready", false)), "active item runtime prewarm should prepare field passive/mythic templates")

	var return_handler: Object = ActiveItemBoomerangReturnHandler.new()
	var megingjord_item: Dictionary = _find_item(field_spawn_items, "megingjord")
	return_handler.handle_return(
		owner,
		{"picked_items": [{"item_data": megingjord_item}]},
		registry,
		active_runtime.slot_controller,
		active_runtime.effect_controller,
		Callable()
	)
	_expect(_inventory_has_item(mythic_runtime, "megingjord"), "boomerang pickup should also route mythics into passive inventory")

	print("item_field_spawn_pool_smoke: ok")
	quit(0)


func _verify_lingpet_egg_active_gate() -> void:
	# Junior: the egg item is never offered (its lingpet is auto-present). With no
	# runtime cached, the league-only fallback gate must still hide it.
	var junior_owner := FakeOwner.new()
	junior_owner.ai_mode = "junior"
	var junior_pool := ActiveItemFieldSpawnPool.new()
	junior_pool.passive_mythic_catalog = null
	_expect(
		not _array_has_item(junior_pool.build_spawn_candidates(null, junior_owner), "lingpet_egg"),
		"lingpet_egg should never spawn in Junior league"
	)

	var champion_owner := FakeOwner.new()
	champion_owner.ai_mode = "champion"

	# Pro/Mythic + runtime can_offer (no lingpet deployed yet) → present.
	var offering_pool := ActiveItemFieldSpawnPool.new()
	offering_pool.passive_mythic_catalog = null
	var offering_runtime := FakeEggRuntime.new()
	offering_runtime.offer = true
	var offering_registry := FakeEggRegistry.new(offering_runtime)
	_expect(
		_array_has_item(
			offering_pool.build_spawn_candidates(offering_registry, champion_owner),
			"lingpet_egg"
		),
		"lingpet_egg should spawn in non-junior leagues while no lingpet is deployed"
	)
	_expect(
		not offering_registry.egg_gate_used_get_instance,
		"lingpet_egg spawn gate must use the cache-only peek, never lazy-instantiate via get_instance"
	)

	# Pro/Mythic + runtime cannot offer (already deployed) → hidden.
	var deployed_pool := ActiveItemFieldSpawnPool.new()
	deployed_pool.passive_mythic_catalog = null
	var deployed_runtime := FakeEggRuntime.new()
	deployed_runtime.offer = false
	_expect(
		not _array_has_item(
			deployed_pool.build_spawn_candidates(FakeEggRegistry.new(deployed_runtime), champion_owner),
			"lingpet_egg"
		),
		"lingpet_egg should stop spawning once a lingpet is deployed this battle"
	)

	# Already holding an egg in an active slot → no second egg spawns (would be an
	# uncatchable field duplicate; the slot controller also rejects the pickup).
	var held_owner := FakeOwner.new()
	held_owner.ai_mode = "champion"
	held_owner.active_item_slots = [{"name": "lingpet_egg"}]
	var held_pool := ActiveItemFieldSpawnPool.new()
	held_pool.passive_mythic_catalog = null
	var held_runtime := FakeEggRuntime.new()
	held_runtime.offer = true
	_expect(
		not _array_has_item(
			held_pool.build_spawn_candidates(FakeEggRegistry.new(held_runtime), held_owner),
			"lingpet_egg"
		),
		"lingpet_egg should not spawn a second egg while one is already held in an active slot"
	)


func _find_item(items: Array, item_name: String) -> Dictionary:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return item_value
	return {}


func _array_has_item(items: Array, item_name: String) -> bool:
	return not _find_item(items, item_name).is_empty()


func _catalog_item_has_chance(items: Array, item_name: String) -> bool:
	var item_data: Dictionary = _find_item(items, item_name)
	return float(item_data.get("chance", 0.0)) > 0.0


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _expect_megingjord_smooth_icon(catalog: Object) -> void:
	var item_data: Dictionary = catalog.build_item_by_name("megingjord")
	_expect(int(item_data.get("icon_frame_count", 0)) == 32, "megingjord should expose 32 smooth icon frames")
	var icon: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_path", "")))
	_expect(icon != null and icon.get_size() == Vector2(32.0, 32.0), "megingjord static icon should load as a 32px render")
	var sheet: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_sheet_path", "")))
	_expect(sheet != null and sheet.get_size() == Vector2(1024.0, 32.0), "megingjord icon sheet should load as 32 smooth 32px frames")


func _inventory_has_item(runtime: Object, item_name: String) -> bool:
	var snapshot: Dictionary = runtime.get_snapshot()
	var inventory: Array = snapshot.get("inventory_items", [])
	for item_value in inventory:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _sum_scaled_group_weights(entries: Array[Dictionary]) -> Dictionary:
	var sums := {
		"active": 0.0,
		"passive": 0.0,
		"mythic": 0.0,
	}
	for entry in entries:
		var group: String = str(entry.get("group", ""))
		if sums.has(group):
			sums[group] = float(sums.get(group, 0.0)) + float(entry.get("weight", 0.0))
	return sums


func _expect_share_close(shares: Dictionary, key: String, expected: float, message: String) -> void:
	var actual: float = float(shares.get(key, -1.0))
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
