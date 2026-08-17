extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const COLLECTION_MANIFEST_PATH := "res://assets/sprites/perks/remaining_mugong_collection_manifest.json"
const ICON_SIZE := Vector2i(256, 256)
const EXPECTED := {
	"star_detector": ["낙성결", "res://assets/sprites/perks/star_detector_mugong_icon.png"],
	"adversity_armor": ["역천호신", "res://assets/sprites/perks/adversity_armor_mugong_icon.png"],
	"reinforced_boomerang_gauntlet": ["회선철수", "res://assets/sprites/perks/reinforced_boomerang_gauntlet_mugong_icon.png"],
	"sensor": ["감응보", "res://assets/sprites/perks/sensor_mugong_icon.png"],
	"dowsing_pendulum": ["섭물공", "res://assets/sprites/perks/dowsing_pendulum_mugong_icon.png"],
	"dowsing_goggles": ["천안결", "res://assets/sprites/perks/dowsing_goggles_mugong_icon.png"],
	"chargebag": ["반탄심법", "res://assets/sprites/perks/chargebag_mugong_icon.png"],
	"battery": ["장기심법", "res://assets/sprites/perks/battery_mugong_icon.png"],
	"master": ["축성공", "res://assets/sprites/perks/master_mugong_icon.png"],
	"gold_digger": ["취금결", "res://assets/sprites/perks/gold_digger_mugong_icon.png"],
	"lucky_coin": ["쌍복결", "res://assets/sprites/perks/lucky_coin_mugong_icon.png"],
	"shrapnel_armor": ["산화수", "res://assets/sprites/perks/shrapnel_armor_mugong_icon.png"],
	"fuel_pouch": ["태허심법", "res://assets/sprites/perks/fuel_pouch_mugong_icon.png"],
	"bluetooth_ring": ["격기심법", "res://assets/sprites/perks/bluetooth_ring_mugong_icon.png"],
	"foul_whistle": ["반전결", "res://assets/sprites/perks/foul_whistle_mugong_icon.png"],
	"neural_helmet": ["강신결", "res://assets/sprites/perks/neural_helmet_mugong_icon.png"],
	"commando_arm": ["비병결", "res://assets/sprites/perks/commando_arm_mugong_icon.png"],
	"rainbow_fur_glove": ["칠채순환", "res://assets/sprites/perks/rainbow_fur_glove_mugong_icon.png"],
	"knee_pads": ["비각축기", "res://assets/sprites/perks/knee_pads_mugong_icon.png"],
	"soul_burst": ["폭혼보", "res://assets/sprites/perks/soul_burst_mugong_icon.png"],
	"bulletproof_hat": ["철심공", "res://assets/sprites/perks/bulletproof_hat_mugong_icon.png"],
	"venom_mist_gauntlet": ["독운공", "res://assets/sprites/perks/venom_mist_gauntlet_mugong_icon.png"],
	"sage_ring": ["현문차력", "res://assets/sprites/perks/sage_ring_mugong_icon.png"],
	"dash_spirit": ["잔영호법", "res://assets/sprites/perks/dash_spirit_mugong_icon.png"],
	"extension_gear": ["불식심법", "res://assets/sprites/perks/extension_gear_mugong_icon.png"],
	"combo_amplifier_chip": ["축뢰심법", "res://assets/sprites/perks/combo_amplifier_chip_mugong_icon.png"],
	"jetpack_enhance": ["승운신법", "res://assets/sprites/perks/jetpack_enhance_mugong_icon.png"],
	"kick_enhance": ["천각심법", "res://assets/sprites/perks/kick_enhance_mugong_icon.png"],
	"blade_amp": ["검강심법", "res://assets/sprites/perks/blade_amp_mugong_icon.png"],
	"four_poisons": ["사독귀일", "res://assets/sprites/perks/four_poisons_mugong_icon.png"],
	"pistol_enhance": ["철포결", "res://assets/sprites/perks/pistol_enhance_mugong_icon.png"],
}

var _failed := false


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_test_catalog_and_runtime_paths()
	_test_seven_language_coverage()
	_test_collection_manifest()
	_test_live_synergy_copy()
	LanguageSettings.set_test_locale_override("")
	PerkConversionFlags.debug_set_enabled(false)
	if _failed:
		quit(1)
		return
	print("remaining_mugong_collection_rebrand_smoke: ok")
	quit(0)


func _test_catalog_and_runtime_paths() -> void:
	var catalog := RuntimePerkCatalog.new()
	var renderer := RuntimePerkIconRenderer.new()
	LanguageSettings.set_test_locale_override("ko")
	for perk_id: String in EXPECTED.keys():
		var spec: Array = EXPECTED[perk_id]
		var expected_name := str(spec[0])
		var icon_path := str(spec[1])
		var data: Dictionary = catalog.get_perk_data(perk_id)
		_expect(not data.is_empty(), "%s should remain available through the runtime catalog" % perk_id)
		_expect(str(data.get("name", "")) == expected_name, "%s should expose the adopted Korean name" % perk_id)
		_expect(str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(perk_id, "")) == icon_path, "%s should keep its new runtime icon path" % perk_id)
		_expect(str(renderer._get_static_path(perk_id)) == icon_path and renderer.has_icon(perk_id), "%s should resolve through the production icon renderer" % perk_id)
		_expect(not renderer.has_animated_icon(perk_id), "%s should remain static so animation distinguishes Peerless Mugong" % perk_id)
		var image := Image.new()
		_expect(image.load(ProjectSettings.globalize_path(icon_path)) == OK, "%s PNG should load" % perk_id)
		if image.is_empty():
			continue
		_expect(Vector2i(image.get_width(), image.get_height()) == ICON_SIZE, "%s should remain 256x256" % perk_id)
		var used_rect := _get_visible_alpha_rect(image, 0.08)
		_expect(used_rect.has_area(), "%s should keep a visible seal silhouette" % perk_id)
		for corner in [Vector2i(0, 0), Vector2i(255, 0), Vector2i(0, 255), Vector2i(255, 255)]:
			_expect(is_zero_approx(image.get_pixelv(corner).a), "%s corners should remain transparent" % perk_id)


func _test_seven_language_coverage() -> void:
	var catalog := RuntimePerkCatalog.new()
	for locale: String in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		for perk_id: String in EXPECTED.keys():
			var data: Dictionary = catalog.get_perk_data(perk_id)
			_expect(str(data.get("name", "")).strip_edges() != "", "%s name should exist for %s" % [perk_id, locale])
			_expect(str(data.get("detail", "")).strip_edges() != "", "%s detail should exist for %s" % [perk_id, locale])


func _test_collection_manifest() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COLLECTION_MANIFEST_PATH))
	_expect(parsed is Dictionary, "the remaining Mugong collection manifest should parse")
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed
	_expect(str(manifest.get("collection_id", "")) == "remaining_mugong_hanji_seals_v1", "the collection id should stay stable")
	var assets: Array = manifest.get("assets", []) as Array
	_expect(assets.size() == EXPECTED.size(), "the collection manifest should list all 31 remaining ordinary Mugong")
	var seen: Dictionary = {}
	for asset_value: Variant in assets:
		if not asset_value is Dictionary:
			continue
		var asset: Dictionary = asset_value
		var perk_id := str(asset.get("perk_id", ""))
		seen[perk_id] = true
		if not EXPECTED.has(perk_id):
			continue
		var spec: Array = EXPECTED[perk_id]
		var icon_path := str(spec[1])
		_expect(str(asset.get("display_name_ko", "")) == str(spec[0]), "%s collection name should match the catalog" % perk_id)
		_expect(str(asset.get("static_path", "")) == icon_path, "%s collection path should match runtime" % perk_id)
		_expect(str(asset.get("sha256", "")) == FileAccess.get_sha256(icon_path), "%s manifest hash should match the accepted PNG" % perk_id)
	for perk_id: String in EXPECTED.keys():
		_expect(seen.has(perk_id), "%s should appear in the collection manifest" % perk_id)


func _test_live_synergy_copy() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
	for adopted_name in ["축뢰심법", "검강심법", "천각심법", "사독귀일"]:
		_expect(source.find(adopted_name) >= 0, "%s should appear in live active-skill synergy copy" % adopted_name)
	for retired_name in ["콤보증폭칩:", "검기증폭:", "킥 강화:", "사독:"]:
		_expect(source.find(retired_name) < 0, "retired tooltip label should not remain: %s" % retired_name)
	_expect(source.find('[["mouse_left", ""], ["text", "참격"]') >= 0, "wall-leap slash control row should use the localized slash label")
	_expect(source.find('[["mouse_left", ""], ["text", "검기"]') < 0, "wall-leap slash control row must not retain the untranslated sword-aura label")
	var overflow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_overflow_descriptions.gd")
	_expect(overflow_source.find("검기 사거리") < 0, "blade overflow copy must not retain the stale sword-aura label")
	_expect(overflow_source.find("참격 사거리") >= 0, "blade overflow copy should use the slash label")


func _get_visible_alpha_rect(image: Image, alpha_threshold: float) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < alpha_threshold:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
