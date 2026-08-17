extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const DEFAULT_LEAGUE_MODE := "junior"
# Player-facing Stage 1 roulette pool. Dalji-only by explicit decision
# (2026-07-04): Gaksital / Pododaejang stay debug-picker-only (explicit
# selection) until they are release-ready. Re-add "gaksi" / "podo" here to
# re-open the original random roulette.
const STAGE1_RANDOM_BOSS_VARIANTS: Array[String] = ["dalji"]

var character_runtime: Object = PlayerCharacterRuntime.new()
var stage1_boss_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var stage1_boss_rng_ready := false


func apply_selection_state(owner: Object) -> void:
	if owner == null or not owner.has_method("get_node_or_null"):
		return
	var selection_state: Object = owner.get_node_or_null("/root/GameSelectionState")
	if selection_state == null or not selection_state.has_method("get_selection"):
		return
	var selection: Dictionary = selection_state.get_selection()
	var runtime_character_id: String = normalize_runtime_character_id(
		selection.get("runtime_character_id", selection.get("character_id", "smasher"))
	)
	var entry_stage: int = max(1, int(selection.get("stage_id", 1)))
	var stage1_boss_variant: String = resolve_stage1_boss_variant(selection, entry_stage)
	var stage_boss_variant: String = StageBossVariantCatalog.normalize_variant(
		entry_stage,
		selection.get("stage_boss_variant", "")
	)
	var stage_boss_entry: Dictionary = StageBossVariantCatalog.get_entry(entry_stage, stage_boss_variant)
	var boss_paddle_scale := maxf(0.1, float(stage_boss_entry.get("boss_paddle_scale", 1.0)))
	owner.set("current_stage", entry_stage)
	owner.set("stage1_boss_variant", stage1_boss_variant if entry_stage == 1 else "dalji")
	owner.set("stage_boss_variant", stage_boss_variant)
	owner.set("boss_paddle_width", 100.0 * boss_paddle_scale)
	owner.set("boss_hitbox_height", 40.0 * boss_paddle_scale)
	owner.set("selected_character_id", str(selection.get("character_id", "ufo_player")))
	owner.set("selected_runtime_character_id", runtime_character_id)
	owner.set("selected_character_type", runtime_character_id)
	owner.set("selected_character_name", str(selection.get("character_name", "\uc2a4\ub9e4\uc154")))
	owner.set("ai_mode", normalize_league_mode(str(selection.get("league_mode", DEFAULT_LEAGUE_MODE))))
	var plaza_save_path := _default_plaza_save_path(owner)
	reset_plaza_progress_if_new_game(entry_stage, plaza_save_path)
	sync_chance_gems_from_plaza_store(owner, plaza_save_path)


func reset_plaza_progress_if_new_game(entry_stage: int, save_path: String) -> void:
	# Parity with original PingFighter: a brand-new playthrough always enters at
	# stage 1 from character select. Stage transitions reuse this scene (they
	# never re-run apply_selection_state, and keep GameSelectionState.stage_id
	# synced to the live stage), so a stage > 1 here is never a fresh start and
	# must not wipe accumulated gold. An empty save_path => no-op, so the real
	# plaza save is only touched for live scenes (RefCounted unit-test owners
	# resolve to "" via _default_plaza_save_path and are skipped).
	if entry_stage != 1 or save_path.strip_edges() == "":
		return
	var store: Object = PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.reset_gold_and_ap_for_new_playthrough()


func sync_chance_gems_from_plaza_store(owner: Object, save_path: String) -> void:
	if owner == null or save_path.strip_edges() == "":
		return
	var store: Object = PlazaSaveStore.new()
	store.set_save_path(save_path)
	var count := PlazaSaveStore.MAX_CHANCE_GEMS
	if store.has_method("get_chance_gems"):
		count = maxi(0, int(store.get_chance_gems()))
	var max_count := PlazaSaveStore.MAX_CHANCE_GEMS
	if store.has_method("get_max_chance_gems"):
		max_count = maxi(1, int(store.get_max_chance_gems()))
	_sync_owner_chance_gems(owner, count, max_count)


func _sync_owner_chance_gems(owner: Object, count: int, max_count: int = PlazaSaveStore.MAX_CHANCE_GEMS) -> void:
	if owner == null:
		return
	owner.set("chance_gems_count", clampi(count, 0, max_count))
	owner.set("chance_gems_max", max_count)


func _default_plaza_save_path(owner: Object) -> String:
	# Live battle scene (a Node) resolves to the canonical plaza save; RefCounted
	# unit-test owners get "" so apply_selection_state never writes the real save
	# during the selection-startup unit tests.
	if owner is Node:
		return PlazaSaveStore.SAVE_PATH
	return ""


func normalize_league_mode(mode: String) -> String:
	return BattleSceneConfig.normalize_league_mode(mode)


func normalize_runtime_character_id(value: Variant) -> String:
	if character_runtime != null and character_runtime.has_method("normalize"):
		return str(character_runtime.normalize(value))
	var normalized: String = str(value).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	return "smasher"


func normalize_stage1_boss_variant(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized == "gaksi" or normalized == "gaksital" or normalized == "talkwangdae":
		return "gaksi"
	if normalized == "podo" or normalized == "pododaejang" or normalized == "podo_daejang":
		return "podo"
	return "dalji"


func resolve_stage1_boss_variant(selection: Dictionary, entry_stage: int) -> String:
	if entry_stage != 1:
		return "dalji"
	if bool(selection.get("stage1_boss_variant_explicit", false)):
		return normalize_stage1_boss_variant(str(selection.get("stage1_boss_variant", "dalji")))
	return select_random_stage1_boss_variant()


func select_random_stage1_boss_variant() -> String:
	if STAGE1_RANDOM_BOSS_VARIANTS.is_empty():
		return "dalji"
	_ensure_stage1_boss_rng_ready()
	var index: int = stage1_boss_rng.randi_range(0, STAGE1_RANDOM_BOSS_VARIANTS.size() - 1)
	return str(STAGE1_RANDOM_BOSS_VARIANTS[index])


func get_stage1_random_boss_variants() -> Array[String]:
	return STAGE1_RANDOM_BOSS_VARIANTS.duplicate()


func set_stage1_boss_rng_seed_for_test(seed_value: int) -> void:
	stage1_boss_rng.seed = seed_value
	stage1_boss_rng_ready = true


func _ensure_stage1_boss_rng_ready() -> void:
	if stage1_boss_rng_ready:
		return
	stage1_boss_rng.randomize()
	stage1_boss_rng_ready = true
