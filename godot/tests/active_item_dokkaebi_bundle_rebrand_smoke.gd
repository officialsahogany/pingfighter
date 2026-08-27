extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkInstantRewards := preload("res://scripts/characters/runtime_perk_instant_rewards.gd")

const ACTIVE_ICON_PATH := "res://assets/sprites/items/pandora_box_icon_hq_v1.png"
const GATE_SEAL_PATH := "res://assets/sprites/effects/dokkaebi_bundle_gate_seal_imagegen_v1.png"
const FLAME_PATH := "res://assets/sprites/effects/dokkaebi_flame_particle_imagegen_v1.png"
const PERK_ICON_PATH := "res://assets/sprites/perks/instant_dimension_gate_dokkaebi_perk_icon_imagegen_v1.png"
const PERK_SHEET_PATH := "res://assets/sprites/perks/instant_dimension_gate_dokkaebi_perk_icon_sheet_imagegen_v1.png"

const EXPECTED_ACTIVE_NAMES := {
	"ko": "도깨비 보따리",
	"en": "Dokkaebi Bundle",
	"zh": "鬼怪包袱",
	"ja": "トッケビの包み",
	"es": "Fardo dokkaebi",
	"pt_BR": "Trouxa Dokkaebi",
	"ru": "Узелок токкэби",
}

const EXPECTED_PERK_NAMES := {
	"ko": "백보초래",
	"en": "Call of a Hundred Treasures",
	"zh": "百宝招来",
	"ja": "百宝招来",
	"es": "Llamada de los Cien Tesoros",
	"pt_BR": "Chamado dos Cem Tesouros",
	"ru": "Призыв сотни сокровищ",
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_compatibility_ids_and_copy()
	_verify_localized_names()
	_verify_visual_asset_contracts()
	_verify_player_facing_consumers()
	LanguageSettings.set_test_locale_override("")

	if _failures.is_empty():
		print("active_item_dokkaebi_bundle_rebrand_smoke: ok")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _verify_compatibility_ids_and_copy() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var item: Dictionary = ActiveItemCatalog.new().build_item_by_name("pandora_box")
	_expect(str(item.get("name", "")) == "pandora_box", "the save/runtime item id must remain pandora_box")
	_expect(str(item.get("effect", "")) == "pandora_box", "the use-routing effect id must remain pandora_box")
	_expect(str(item.get("display_name", "")) == "도깨비 보따리", "the Korean active-item name should be rebranded")
	var description: String = str(item.get("description", ""))
	_expect(description.contains("귀문") and description.contains("3초") and description.contains("0.5~1초"), "the Korean tooltip should describe the real 3-second spawn behavior")
	_expect(str(item.get("icon_path", "")) == ACTIVE_ICON_PATH, "the catalog should route to the dokkaebi bundle icon")

	var perk: Dictionary = RuntimePerkCatalog.new().get_perk_data("instant_dimension_gate")
	_expect(not perk.is_empty(), "the compatibility perk id instant_dimension_gate must remain registered")
	_expect(str(perk.get("name", "")) == "백보초래", "the shared instant card should use the Korean-fantasy rebrand")
	_expect(str(perk.get("detail", "")).contains("중앙 귀문"), "the instant card detail should describe the shared spirit-gate effect")
	_expect(RuntimePerkInstantRewards.DIMENSION_GATE_FEEDBACK_TEXT == "백보초래", "the activation feedback should not revive the retired dimension-gate label")


func _verify_localized_names() -> void:
	var active_catalog := ActiveItemCatalog.new()
	var perk_catalog := RuntimePerkCatalog.new()
	for locale_value: Variant in EXPECTED_ACTIVE_NAMES.keys():
		var locale: String = str(locale_value)
		LanguageSettings.set_test_locale_override(locale)
		var item: Dictionary = active_catalog.build_item_by_name("pandora_box")
		_expect(
			str(item.get("display_name", "")) == str(EXPECTED_ACTIVE_NAMES[locale]),
			"%s should localize the dokkaebi bundle name" % locale
		)
		var perk: Dictionary = perk_catalog.get_perk_data("instant_dimension_gate")
		_expect(
			str(perk.get("name", "")) == str(EXPECTED_PERK_NAMES[locale]),
			"%s should localize the Hundred Treasures card name" % locale
		)
		_expect(not str(perk.get("description", "")).strip_edges().is_empty(), "%s should keep a localized instant-card summary" % locale)


func _verify_visual_asset_contracts() -> void:
	_verify_alpha_asset(ACTIVE_ICON_PATH, Vector2i(256, 256), "active item icon", true)
	_verify_alpha_asset(GATE_SEAL_PATH, Vector2i(512, 512), "spirit-gate seal", false)
	_verify_alpha_asset(FLAME_PATH, Vector2i(64, 64), "dokkaebi flame", false)
	_verify_alpha_asset(PERK_ICON_PATH, Vector2i(512, 512), "instant-card icon", false)
	_verify_alpha_asset(PERK_SHEET_PATH, Vector2i(4096, 512), "instant-card eight-frame sheet", false)

	_expect(str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get("instant_dimension_gate", "")) == PERK_ICON_PATH, "the production icon renderer should use the new static identity anchor")
	_expect(str(RuntimePerkIconRenderer.PERK_SHEET_PATHS.get("instant_dimension_gate", "")) == PERK_SHEET_PATH, "the production icon renderer should use the new eight-frame sheet")
	var renderer := RuntimePerkIconRenderer.new()
	_expect(renderer.has_icon("instant_dimension_gate"), "the production icon renderer should resolve the rebranded card icon")
	_expect(renderer.has_animated_icon("instant_dimension_gate"), "the one-shot card should retain animated sheet-first presentation")


func _verify_alpha_asset(path: String, expected_size: Vector2i, label: String, audit_small_icon: bool) -> void:
	_expect(FileAccess.file_exists(path), "%s should exist" % label)
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(image != null and not image.is_empty(), "%s should decode" % label)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == expected_size, "%s should keep size %s" % [label, str(expected_size)])
	var size: Vector2i = image.get_size()
	var corner_alpha := [
		image.get_pixel(0, 0).a,
		image.get_pixel(size.x - 1, 0).a,
		image.get_pixel(0, size.y - 1).a,
		image.get_pixel(size.x - 1, size.y - 1).a,
	]
	for alpha_value: float in corner_alpha:
		_expect(alpha_value <= 0.01, "%s corners should stay transparent" % label)
	if not audit_small_icon:
		return
	var semi_transparent_count := 0
	for y: int in range(size.y):
		for x: int in range(size.x):
			var alpha: float = image.get_pixel(x, y).a
			if alpha > 8.0 / 255.0 and alpha <= 200.0 / 255.0:
				semi_transparent_count += 1
	_expect(semi_transparent_count < size.x * size.y / 4, "the HQ item icon should not carry a full-canvas chroma halo")


func _verify_player_facing_consumers() -> void:
	var sources := {
		"res://scripts/items/active_item_catalog.gd": "도깨비 보따리",
		"res://scripts/items/active_item_pickup_feedback.gd": "도깨비 보따리",
		"res://scripts/items/active_item_debug_spawn_menu.gd": "귀문 개방",
		"res://scripts/items/mythic_item_pandora_legacy_runtime.gd": "도깨비 보따리",
	}
	for path_value: Variant in sources.keys():
		var path: String = str(path_value)
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.contains(str(sources[path])), "%s should expose the rebranded player-facing copy" % path)
		_expect(not source.contains("판도라의 상자"), "%s should not leak the retired player-facing name" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
