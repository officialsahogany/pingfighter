extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")

const ICON_SIZE := Vector2i(256, 256)
const MANIFEST_PATH := "res://assets/sprites/perks/viper_manual_collection_manifest.json"
const CAPTURE_PATH := "res://../.tmp/perk_icon_redraw/viper_manual_small_cell_probe.png"
const MANUAL_IDS := [
	"unlock_nerve_strike",
	"unlock_dive_strike",
	"unlock_chaos_spear",
	"unlock_dual_glitch",
	"unlock_ignition_aura",
	"double_marshal_kick",
	"core_flip",
	"dark_blade",
]
const MANUAL_SPECS := {
	"unlock_nerve_strike": {"skill_id": "nerve_strike", "path": "res://assets/sprites/perks/viper_dokyeong_jeolmaek_manual_icon.png", "ko_name": "독영절맥 비급"},
	"unlock_dive_strike": {"skill_id": "dive_strike", "path": "res://assets/sprites/perks/viper_cheonroe_jingak_manual_icon.png", "ko_name": "천뢰진각 비급"},
	"unlock_chaos_spear": {"skill_id": "chaos_spear", "path": "res://assets/sprites/perks/viper_honcheon_heukchang_manual_icon.png", "ko_name": "혼천흑창 비급"},
	"unlock_dual_glitch": {"skill_id": "dual_glitch", "path": "res://assets/sprites/perks/viper_ssangyeong_bunsin_manual_icon.png", "ko_name": "쌍영분신 비급"},
	"unlock_ignition_aura": {"skill_id": "ignition_aura", "path": "res://assets/sprites/perks/viper_yeomhwa_gaemaek_manual_icon.png", "ko_name": "염화개맥 비급"},
	"double_marshal_kick": {"skill_id": "phantom_kick", "path": "res://assets/sprites/perks/viper_hwanyeong_yeongak_manual_icon.png", "ko_name": "환영연각 비급"},
	"core_flip": {"skill_id": "core_flip", "path": "res://assets/sprites/perks/viper_hwarang_bicheongak_manual_icon.png", "ko_name": "화랑비천각 비급"},
	"dark_blade": {"skill_id": "dark_blade", "path": "res://assets/sprites/perks/viper_hyeolyeong_cham_manual_icon.png", "ko_name": "혈영참 비급"},
}
const EXPECTED_LOCALIZED_NAMES := {
	"ko": ["독영절맥 비급", "천뢰진각 비급", "혼천흑창 비급", "쌍영분신 비급", "염화개맥 비급", "환영연각 비급", "화랑비천각 비급", "혈영참 비급"],
	"en": ["Poison-Shadow Meridian Sever Manual", "Heavenly Thunder Quaking Kick Manual", "Chaos-Heaven Black Spear Manual", "Twin-Shadow Doppelganger Manual", "Flame Meridian Opening Manual", "Phantom Chain Kick Manual", "Hwarang Sky-Flying Kick Manual", "Blood-Shadow Slash Manual"],
	"zh": ["毒影截脉秘笈", "天雷震脚秘笈", "混天黑枪秘笈", "双影分身秘笈", "炎火开脉秘笈", "幻影连脚秘笈", "花郎飞天脚秘笈", "血影斩秘笈"],
	"ja": ["毒影截脈秘伝書", "天雷震脚秘伝書", "混天黒槍秘伝書", "双影分身秘伝書", "炎火開脈秘伝書", "幻影連脚秘伝書", "花郎飛天脚秘伝書", "血影斬秘伝書"],
	"es": ["Manual de Corte del meridiano de sombra venenosa", "Manual de Patada sísmica del trueno celestial", "Manual de Lanza negra del cielo caótico", "Manual de Doble de sombras gemelas", "Manual de Apertura de meridianos de fuego", "Manual de Patada encadenada fantasma", "Manual de Patada celeste Hwarang", "Manual de Tajo de sombra sangrienta"],
	"pt-BR": ["Manual de Corte do meridiano da sombra venenosa", "Manual de Chute sísmico do trovão celestial", "Manual de Lança negra do céu caótico", "Manual de Duplo das sombras gêmeas", "Manual de Abertura dos meridianos de fogo", "Manual de Chute encadeado fantasma", "Manual de Chute celeste Hwarang", "Manual de Corte da sombra sangrenta"],
	"ru": ["Тайный свиток Рассечения ядовитой тени", "Тайный свиток Громовой сотрясающей стопы", "Тайный свиток Черного копья хаоса", "Тайный свиток Двойника парных теней", "Тайный свиток Открытия огненных меридианов", "Тайный свиток Цепного призрачного удара", "Тайный свиток Небесного удара Hwarang", "Тайный свиток Кроваво-теневого разреза"],
}
const EXPECTED_LOCALIZED_SKILL_NAMES := {
	"ko": ["독영절맥", "천뢰진각", "혼천흑창", "쌍영분신", "염화개맥", "환영연각", "화랑비천각", "혈영참"],
	"en": ["Poison-Shadow Meridian Sever", "Heavenly Thunder Quaking Kick", "Chaos-Heaven Black Spear", "Twin-Shadow Doppelganger", "Flame Meridian Opening", "Phantom Chain Kick", "Hwarang Sky-Flying Kick", "Blood-Shadow Slash"],
	"zh": ["毒影截脉", "天雷震脚", "混天黑枪", "双影分身", "炎火开脉", "幻影连脚", "花郎飞天脚", "血影斩"],
	"ja": ["毒影截脈", "天雷震脚", "混天黒槍", "双影分身", "炎火開脈", "幻影連脚", "花郎飛天脚", "血影斬"],
	"es": ["Corte del meridiano de sombra venenosa", "Patada sísmica del trueno celestial", "Lanza negra del cielo caótico", "Doble de sombras gemelas", "Apertura de meridianos de fuego", "Patada encadenada fantasma", "Patada celeste Hwarang", "Tajo de sombra sangrienta"],
	"pt-BR": ["Corte do meridiano da sombra venenosa", "Chute sísmico do trovão celestial", "Lança negra do céu caótico", "Duplo das sombras gêmeas", "Abertura dos meridianos de fogo", "Chute encadeado fantasma", "Chute celeste Hwarang", "Corte da sombra sangrenta"],
	"ru": ["Рассечение меридианов ядовитой тенью", "Громовая сотрясающая стопа", "Черное копье хаоса", "Двойник парных теней", "Открытие огненных меридианов", "Цепной призрачный удар", "Небесный удар Hwarang", "Кроваво-теневой разрез"],
}
const RUNTIME_CONSUMER_TERMS := [
	{"path": "res://scripts/characters/viper_emp_strike_fx_host.gd", "required": "천뢰진각", "forbidden": "EMP 스트라이크"},
	{"path": "res://scripts/characters/viper_skill_floating_text_renderer.gd", "required": "천뢰진각", "forbidden": "EMP 스트라이크"},
	{"path": "res://scripts/characters/viper_skill_kick_effect_renderer.gd", "required": "환영연각", "forbidden": "팬텀 킥"},
	{"path": "res://scripts/characters/viper_skill_particle_drawer.gd", "required": "독영절맥!", "forbidden": "베놈 엣지!"},
	{"path": "res://scripts/characters/viper_skill_timer_gauge_renderer.gd", "required": "염화개맥", "forbidden": "이그니션"},
	{"path": "res://scripts/characters/viper_skill_timer_gauge_renderer.gd", "required": "쌍영분신", "forbidden": "translate_text(\"듀얼\")"},
	{"path": "res://scripts/hud/skill_cutin_overlay_host.gd", "required": "\"title\": \"환영연각\"", "forbidden": "\"title\": \"팬텀 킥\""},
]


class ManualRenderProbe:
	extends Node2D

	var renderer := RuntimePerkIconRenderer.new()
	var ids: Array = []
	var draw_results: Dictionary = {}
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		draw_results.clear()
		draw_rect(Rect2(Vector2.ZERO, Vector2(420.0, 184.0)), Color(6.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0))
		for i in range(ids.size()):
			var perk_id := str(ids[i])
			var col := i % 4
			var row := int(floor(float(i) / 4.0))
			var cell_rect := Rect2(Vector2(14.0 + float(col) * 100.0, 14.0 + float(row) * 84.0), Vector2(92.0, 72.0))
			draw_rect(cell_rect, Color(10.0 / 255.0, 28.0 / 255.0, 48.0 / 255.0))
			draw_rect(cell_rect, Color(55.0 / 255.0, 125.0 / 255.0, 158.0 / 255.0), false, 1.0)
			var icon_rect := Rect2(cell_rect.position + Vector2(30.0, 5.0), Vector2(32.0, 32.0))
			draw_results[perk_id] = bool(renderer.draw_icon(self, perk_id, icon_rect, 1.0, true))
			var font := ThemeDB.fallback_font
			if font != null:
				draw_string(font, cell_rect.position + Vector2(32.0, 54.0), "Lv.1", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1.0, 0.88, 0.25))


var _failures: Array[String] = []
var _probe: ManualRenderProbe = null
var _frame_count := 0


func _init() -> void:
	_test_manual_paths_alpha_and_prewarm()
	_test_seven_language_names()
	_test_runtime_consumer_terms()
	_test_manifest_contract()
	LanguageSettings.set_test_locale_override("")
	get_root().size = Vector2i(420, 184)
	_probe = ManualRenderProbe.new()
	_probe.ids = MANUAL_IDS.duplicate()
	_probe.name = "ViperManualRenderProbe"
	get_root().add_child(_probe)
	_probe.queue_redraw()


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < 3:
		return false
	_test_small_cell_draw()
	_capture_probe_if_available()
	if _failures.is_empty():
		print("viper_manual_collection_rebrand_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	return true


func _test_manual_paths_alpha_and_prewarm() -> void:
	var renderer := RuntimePerkIconRenderer.new()
	var covered_ids := renderer.covered_ids()
	for perk_id: String in MANUAL_IDS:
		var spec: Dictionary = MANUAL_SPECS[perk_id]
		var expected_path := str(spec.get("path", ""))
		var expected_skill_id := str(spec.get("skill_id", ""))
		_expect(str(RuntimePerkIconRenderer.MANUAL_ICON_PATHS.get(perk_id, "")) == expected_path, "%s should use its dedicated secret-manual cover" % perk_id)
		_expect(str(renderer._resolve_skill_icon_id(perk_id)) == expected_skill_id, "%s should preserve its compatibility skill id" % perk_id)
		_expect(str(renderer._get_static_path(perk_id)) == expected_path, "%s manual path should resolve before the equipped skill icon" % perk_id)
		_expect(renderer._needs_unlock_badge(perk_id), "%s manual acquisition art should keep the unlock badge" % perk_id)
		_expect(covered_ids.has(perk_id), "%s should stay covered by the runtime icon registry" % perk_id)
		var source: Dictionary = renderer._get_icon_source(perk_id)
		var source_texture: Texture2D = source.get("texture", null) as Texture2D
		_expect(source_texture != null, "%s manual should load through the runtime source cache" % perk_id)
		if source_texture != null:
			_expect(source_texture.resource_path == expected_path, "%s manual must skip circular skill-orb normalization" % perk_id)
			_expect(Vector2i(source_texture.get_width(), source_texture.get_height()) == ICON_SIZE, "%s manual should stay 256x256" % perk_id)
			var draw_rect := renderer._get_draw_rect(Rect2(Vector2.ZERO, Vector2(32.0, 32.0)), perk_id, source_texture)
			_expect(draw_rect.position.x >= 0.0 and draw_rect.position.y >= 0.0 and draw_rect.end.x <= 32.0 and draw_rect.end.y <= 32.0, "%s should stay inside the smallest 32px icon box" % perk_id)
		_test_source_png_alpha(expected_path, perk_id)

	renderer.prewarm_assets()
	for perk_id: String in MANUAL_IDS:
		var path := str(MANUAL_SPECS[perk_id].get("path", ""))
		_expect(renderer._texture_cache.has(path), "%s manual texture should be cached by prewarm" % perk_id)
		_expect(renderer.has_icon(perk_id), "%s should remain drawable after prewarm" % perk_id)


func _test_source_png_alpha(path: String, perk_id: String) -> void:
	var image := Image.new()
	_expect(image.load(ProjectSettings.globalize_path(path)) == OK, "%s source PNG should load for alpha QA" % perk_id)
	if image.is_empty():
		return
	_expect(Vector2i(image.get_width(), image.get_height()) == ICON_SIZE, "%s source PNG should stay 256x256" % perk_id)
	var used_rect := image.get_used_rect()
	_expect(used_rect.position.x >= 12 and used_rect.position.y >= 12, "%s manual should keep transparent top-left padding" % perk_id)
	_expect(used_rect.end.x <= 244 and used_rect.end.y <= 244, "%s manual alpha bounds should stay clear of the canvas edge" % perk_id)
	for corner in [Vector2i(0, 0), Vector2i(255, 0), Vector2i(0, 255), Vector2i(255, 255)]:
		_expect(is_zero_approx(image.get_pixelv(corner).a), "%s manual corners should remain fully transparent" % perk_id)


func _test_seven_language_names() -> void:
	var catalog := RuntimePerkCatalog.new()
	for locale: String in EXPECTED_LOCALIZED_NAMES.keys():
		LanguageSettings.set_test_locale_override(locale)
		var expected_names: Array = EXPECTED_LOCALIZED_NAMES[locale]
		var expected_skill_names: Array = EXPECTED_LOCALIZED_SKILL_NAMES[locale]
		var config := ViperSkillConfig.new()
		for index in range(MANUAL_IDS.size()):
			var perk_id := str(MANUAL_IDS[index])
			var skill_id := str(MANUAL_SPECS[perk_id].get("skill_id", ""))
			var actual_name := str(catalog.get_perk_data(perk_id).get("name", ""))
			_expect(actual_name == str(expected_names[index]), "%s %s manual name should be fully localized" % [locale, perk_id])
			var actual_skill_name := str(config.get_skill_data(skill_id).get("korean", ""))
			_expect(actual_skill_name == str(expected_skill_names[index]), "%s %s equipped skill name should match its manual rebrand" % [locale, skill_id])


func _test_runtime_consumer_terms() -> void:
	for raw_spec: Variant in RUNTIME_CONSUMER_TERMS:
		var spec: Dictionary = raw_spec as Dictionary
		var path := str(spec.get("path", ""))
		var source := FileAccess.get_file_as_string(path)
		var required := str(spec.get("required", ""))
		var forbidden := str(spec.get("forbidden", ""))
		_expect(source.contains(required), "%s should materialize the rebranded runtime label %s" % [path, required])
		_expect(not source.contains(forbidden), "%s should not restore the retired player-facing label %s" % [path, forbidden])


func _test_manifest_contract() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(parsed is Dictionary, "Viper manual collection manifest should parse")
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed
	_expect(str(manifest.get("source_provenance", "")) == "not recorded in workspace", "unknown source provenance should stay explicit instead of being invented")
	var entries: Array = manifest.get("entries", []) as Array
	_expect(entries.size() == MANUAL_SPECS.size(), "Viper manual manifest should record every acquisition volume")
	var seen_ids: Dictionary = {}
	for raw_entry: Variant in entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var perk_id := str(entry.get("perk_id", ""))
		seen_ids[perk_id] = true
		if not MANUAL_SPECS.has(perk_id):
			continue
		var spec: Dictionary = MANUAL_SPECS[perk_id]
		var runtime_path := str(entry.get("runtime_path", ""))
		_expect(runtime_path == str(spec.get("path", "")), "%s manifest path should match runtime wiring" % perk_id)
		_expect(str(entry.get("skill_id", "")) == str(spec.get("skill_id", "")), "%s manifest should preserve the compatibility skill id" % perk_id)
		_expect(str(entry.get("display_name_ko", "")) == str(spec.get("ko_name", "")), "%s manifest should record the Korean card name" % perk_id)
		_expect(str(entry.get("sha256", "")) == FileAccess.get_sha256(runtime_path), "%s manifest hash should match the accepted runtime PNG" % perk_id)
	for perk_id: String in MANUAL_IDS:
		_expect(seen_ids.has(perk_id), "%s should be recorded in the Viper manual manifest" % perk_id)


func _test_small_cell_draw() -> void:
	_expect(_probe != null and _probe.draw_count > 0, "Viper manual render probe should receive a live draw callback")
	if _probe == null:
		return
	for perk_id: String in MANUAL_IDS:
		_expect(bool(_probe.draw_results.get(perk_id, false)), "%s should draw through RuntimePerkIconRenderer.draw_icon at 32px" % perk_id)


func _capture_probe_if_available() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var viewport_texture: Texture2D = get_root().get_texture()
	if viewport_texture == null:
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		return
	var capture_dir := ProjectSettings.globalize_path("res://../.tmp/perk_icon_redraw")
	_expect(DirAccess.make_dir_recursive_absolute(capture_dir) == OK, "small-cell capture directory should be creatable")
	_expect(image.save_png(ProjectSettings.globalize_path(CAPTURE_PATH)) == OK, "small-cell render capture should save")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
