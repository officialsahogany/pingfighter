extends SceneTree

# S3-a 슬라이스 A 씰 — 탑다운 준비도 게이트(§A-4 / §A-4a).
#
# 봉인 범위:
#  - P14(준비도): M/N 결손 조합별로 ready=false + 사유가 정확히 갈린다 · 정상 대조군
#  - P16①(부분): 판정 경로에서 **로더 호출 0회**(get_texture / load_texture /
#    load_imported_* / prewarm_*) + registry.get_instance() 0회(인스턴스화 금지)
#
# ⚠️ P16②(N 객체 동일성)는 **여기서 완결되지 않는다.** 이 씰은 resolver 가 peek 한
#    객체를 그대로 돌려준다는 것까지만 본다. "같은 객체가 actor context 와 renderer
#    까지 도달한다"는 계약은 **슬라이스 B**에서 봉인한다(계약 §9-b 경계 2).
#
# 에셋 0장. 라이더 규격은 rider_spec_provider seam 으로 인메모리 1×1 픽스처를 넣는다.

const LingpetMountTopdownReadiness := preload("res://scripts/lingpet/lingpet_mount_topdown_readiness.gd")
const PlayerMountRiderSpriteCatalog := preload("res://scripts/resources/player_mount_rider_sprite_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failed := false


# 실제 생산 소유자와 같은 표면: egg runtime 의 _current_profile.
# cache-only API = get_cached_visual_texture(:398) / 로드형 = get_visual_texture(:394).
class SpyProfile:
	extends RefCounted

	var cached: Dictionary = {}          # visual_key -> Texture2D
	var cached_peek_calls := 0
	var loader_calls := 0                # 이게 0이어야 cache-only 계약이 산다

	func get_cached_visual_texture(visual_key: String, fallback: Texture2D) -> Texture2D:
		cached_peek_calls += 1
		return cached.get(visual_key, fallback) as Texture2D if cached.has(visual_key) else fallback

	# 아래 셋은 "부르면 안 되는" API 다. 호출되면 loader_calls 가 오른다.
	func get_visual_texture(_visual_key: String, fallback: Texture2D) -> Texture2D:
		loader_calls += 1
		return fallback

	func prewarm_visual_keys(_keys: Array = []) -> void:
		loader_calls += 1

	func prewarm_visual_key_threaded_step(_visual_key: String, _max_msec: int, _max_polls: int) -> bool:
		loader_calls += 1
		return true


class SpyBattleResources:
	extends RefCounted

	var resource_cache: Dictionary = {}
	var resource_cache_calls := 0
	var loader_calls := 0

	func get_resource_cache() -> Dictionary:
		resource_cache_calls += 1
		return resource_cache

	func load_texture_resource(_path: String) -> Texture2D:
		loader_calls += 1
		return null

	func load_imported_texture_resource(_path: String, _optional: bool = false) -> Texture2D:
		loader_calls += 1
		return null


class SpyRegistry:
	extends RefCounted

	var cached: Dictionary = {}
	var cached_instance_calls := 0
	var instantiating_calls := 0         # get_instance() = 인스턴스화 트랩. 0이어야 한다

	func get_cached_instance(key: String) -> Variant:
		cached_instance_calls += 1
		return cached.get(key, null)

	func get_instance(key: String) -> Variant:
		instantiating_calls += 1
		return cached.get(key, null)


func _init() -> void:
	call_deferred("_run")


func _expect(label: String, ok: bool) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		_failed = true
		printerr("FAIL: %s" % label)


func _run() -> void:
	_test_non_topdown_is_inert()
	_test_missing_mount_texture()
	_test_unauthored_rider_sheet()
	_test_missing_battle_resources()
	_test_rider_texture_not_published()
	_test_ready_and_object_passthrough()
	_test_shipped_catalog_has_no_authored_rider()
	_test_rider_texture_key_contract()
	_test_character_alias_control()
	_test_unknown_character_is_rejected()
	_test_result_carries_canonical_id_and_key()
	_test_operational_gate_blocks_when_not_ready()
	_test_operational_gate_positive_and_revoke()
	_test_operational_onimaru_untouched()
	_test_mount_validation_value_checks()

	if _failed:
		printerr("lingpet_mount_topdown_readiness_smoke: FAILED")
		quit(1)
		return
	print("lingpet_mount_topdown_readiness_smoke: ok")
	quit(0)


func _make_texture() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(image)


func _make_rider_spec() -> Dictionary:
	return {
		"path": "res://__fixture__/mount_rider_seated.png",
		"cols": 1,
		"rows": 1,
		"frame_count": 1,
		"draw_size": Vector2(160.0, 160.0),
	}


# 픽스처: M 캐시 / N 발행 여부를 레그마다 다르게 조립한다.
func _build(
	mount_cached: bool,
	rider_authored: bool,
	resources_instantiated: bool,
	rider_published: bool
) -> Dictionary:
	var readiness := LingpetMountTopdownReadiness.new()
	var profile := SpyProfile.new()
	var registry := SpyRegistry.new()
	var mount_texture: Texture2D = _make_texture()
	var rider_texture: Texture2D = _make_texture()
	if mount_cached:
		profile.cached[LingpetMountTopdownReadiness.MOUNT_BASE_VISUAL_KEY] = mount_texture
	if rider_authored:
		readiness.rider_spec_provider = func(_character_id: String) -> Dictionary:
			return _make_rider_spec()
	else:
		readiness.rider_spec_provider = func(_character_id: String) -> Dictionary:
			return {}
	var resources: SpyBattleResources = null
	if resources_instantiated:
		resources = SpyBattleResources.new()
		if rider_published:
			# 저장 측도 카탈로그 정본 키를 쓴다(문자열 재작성 금지).
			resources.resource_cache[PlayerMountRiderSpriteCatalog.get_texture_cache_key("smasher")] = rider_texture
		registry.cached["battle_resources"] = resources
	return {
		"readiness": readiness,
		"profile": profile,
		"registry": registry,
		"resources": resources,
		"mount_texture": mount_texture,
		"rider_texture": rider_texture,
	}


func _resolve(fixture: Dictionary, topdown: bool = true) -> Dictionary:
	var readiness: Object = fixture["readiness"]
	return readiness.resolve(
		"smasher",
		topdown,
		fixture["profile"] as Object,
		fixture["registry"] as Object
	)


# 판정 경로가 cache-only 였는지 (모든 레그에서 공통으로 확인).
func _assert_cache_only(label: String, fixture: Dictionary) -> void:
	var profile: SpyProfile = fixture["profile"]
	var registry: SpyRegistry = fixture["registry"]
	var resources: SpyBattleResources = fixture["resources"]
	_expect("%s — profile 로더 API(get_visual_texture 등) 호출 0회 (cache-only)" % label, profile.loader_calls == 0)
	_expect("%s — registry.get_instance() 0회 (인스턴스화 금지)" % label, registry.instantiating_calls == 0)
	if resources != null:
		_expect("%s — battle_resources 로더 호출 0회" % label, resources.loader_calls == 0)


func _test_non_topdown_is_inert() -> void:
	# 모델이 탑다운이 아니면 아무것도 조회하지 않고 즉시 미준비다(온이마루 무접촉).
	var fixture := _build(true, true, true, true)
	var result := _resolve(fixture, false)
	_expect("비탑다운: ready=false", not bool(result.get("ready", true)))
	_expect(
		"비탑다운: 사유 not_topdown_model",
		str(result.get("reason", "")) == LingpetMountTopdownReadiness.REASON_NOT_TOPDOWN
	)
	var profile: SpyProfile = fixture["profile"]
	_expect("비탑다운: 캐시 peek 조차 하지 않음", profile.cached_peek_calls == 0)
	_assert_cache_only("비탑다운", fixture)


func _test_missing_mount_texture() -> void:
	var fixture := _build(false, true, true, true)
	var result := _resolve(fixture)
	_expect("M 미캐시: ready=false", not bool(result.get("ready", true)))
	_expect(
		"M 미캐시: 사유 mount_base_texture_not_cached",
		str(result.get("reason", "")) == LingpetMountTopdownReadiness.REASON_NO_MOUNT_TEXTURE
	)
	_assert_cache_only("M 미캐시", fixture)


func _test_unauthored_rider_sheet() -> void:
	var fixture := _build(true, false, true, true)
	var result := _resolve(fixture)
	_expect("N 미저작: ready=false", not bool(result.get("ready", true)))
	_expect(
		"N 미저작: 사유 rider_sheet_unauthored",
		str(result.get("reason", "")) == LingpetMountTopdownReadiness.REASON_NO_RIDER_SHEET
	)
	_assert_cache_only("N 미저작", fixture)


func _test_missing_battle_resources() -> void:
	# battle_resources 가 아직 인스턴스화되지 않았으면 만들지 않고 미준비로 닫는다.
	var fixture := _build(true, true, false, false)
	var result := _resolve(fixture)
	_expect("리소스 미인스턴스: ready=false", not bool(result.get("ready", true)))
	_expect(
		"리소스 미인스턴스: 사유 battle_resources_not_instantiated",
		str(result.get("reason", "")) == LingpetMountTopdownReadiness.REASON_NO_RESOURCES
	)
	_assert_cache_only("리소스 미인스턴스", fixture)


func _test_rider_texture_not_published() -> void:
	# 카탈로그엔 저작돼 있는데 actor context 로 발행되지 않은 상태 — 이게 정확히
	# "게이트 GREEN인데 화면은 기존 포즈"를 만드는 구멍이라 미준비로 닫아야 한다.
	var fixture := _build(true, true, true, false)
	var result := _resolve(fixture)
	_expect("N 미발행: ready=false", not bool(result.get("ready", true)))
	_expect(
		"N 미발행: 사유 rider_texture_not_published",
		str(result.get("reason", "")) == LingpetMountTopdownReadiness.REASON_NO_RIDER_TEXTURE
	)
	_assert_cache_only("N 미발행", fixture)


func _test_unknown_character_is_rejected() -> void:
	# 미지 캐릭터 id 는 준비도에서 즉시 거부돼야 한다. upstream normalize() 를 태웠다면
	# 이 시점엔 이미 "smasher" 가 되어 있어 이 레그가 통과할 수 없다 = 혼입 검출기.
	var fixture := _build(true, true, true, true)
	var readiness: Object = fixture["readiness"]
	var result: Dictionary = readiness.resolve(
		"__typo__",
		true,
		fixture["profile"] as Object,
		fixture["registry"] as Object
	)
	_expect("미지 캐릭터: ready=false", not bool(result.get("ready", true)))
	_expect(
		"미지 캐릭터: 사유 unknown_character_id (스매셔 폴백 아님)",
		str(result.get("reason", "")) == LingpetMountTopdownReadiness.REASON_UNKNOWN_CHARACTER
	)
	_expect("미지 캐릭터: canonical id 빈 문자열", str(result.get("rider_character_id", "x")) == "")
	_expect("미지 캐릭터: 캐시 키 빈 문자열", str(result.get("rider_texture_key", "x")) == "")
	_expect("미지 캐릭터: 라이더 텍스처 미사용", result.get("rider_texture", null) == null)
	# ⭐ 픽스처에는 **스매셔 라이더 텍스처가 실제로 발행돼 있다**(_build 의 마지막 인자).
	#    upstream normalize 가 섞여 "smasher" 로 둔갑했다면 이 텍스처를 집어 ready 가
	#    되어야 하므로, 발행 캐시를 **한 번도 열어보지 않았다**는 것이 가장 직접적인
	#    봉인이다(키별 호출 계수보다 강하다 — get_resource_cache() 는 dict 를 통째로
	#    돌려주므로 키 단위 계수가 불가능하다).
	var resources: SpyBattleResources = fixture["resources"]
	_expect(
		"미지 캐릭터: 발행 캐시(get_resource_cache) 접근 0회 — 스매셔 N 으로 새지 않음",
		resources != null and resources.resource_cache_calls == 0
	)
	_expect(
		"미지 캐릭터 사전: 픽스처에 스매셔 라이더가 실제로 발행돼 있다 (구멍이 열려 있었다면 잡혔을 조건)",
		resources != null and resources.resource_cache.has(PlayerMountRiderSpriteCatalog.get_texture_cache_key("smasher"))
	)
	_assert_cache_only("미지 캐릭터", fixture)


func _test_result_carries_canonical_id_and_key() -> void:
	# 슬라이스 B 가 재정규화·재조회 없이 쓰도록 결과 dict 가 정본화 id 와 키를 싣는다.
	var fixture := _build(true, true, true, true)
	var readiness: Object = fixture["readiness"]
	# 별칭으로 호출해도 결과는 정본 id / 정본 키여야 한다.
	var result: Dictionary = readiness.resolve(
		"commando",
		true,
		fixture["profile"] as Object,
		fixture["registry"] as Object
	)
	_expect("별칭 호출: canonical id = soldier", str(result.get("rider_character_id", "")) == "soldier")
	_expect(
		"별칭 호출: 캐시 키 = 정본 키",
		str(result.get("rider_texture_key", "")) == PlayerMountRiderSpriteCatalog.get_texture_cache_key("soldier")
	)
	_assert_cache_only("별칭 호출", fixture)


func _test_ready_and_object_passthrough() -> void:
	var fixture := _build(true, true, true, true)
	var result := _resolve(fixture)
	_expect("정상 대조군: ready=true", bool(result.get("ready", false)))
	_expect(
		"정상 대조군: 사유 ready",
		str(result.get("reason", "")) == LingpetMountTopdownReadiness.REASON_READY
	)
	_expect(
		"정상 대조군: M 텍스처가 캐시에서 peek 한 그 객체",
		result.get("mount_texture", null) == fixture["mount_texture"]
	)
	# ⚠️ P16② 부분 — resolver 가 발행 캐시의 객체를 그대로 돌려준다는 것까지만이다.
	#    actor context / renderer 도달은 슬라이스 B 에서 봉인한다.
	_expect(
		"정상 대조군: N 텍스처가 발행 캐시의 그 객체 (P16② 부분 — actor context 도달은 슬라이스 B)",
		result.get("rider_texture", null) == fixture["rider_texture"]
	)
	_expect("정상 대조군: canonical id 보존", str(result.get("rider_character_id", "")) == "smasher")
	_expect(
		"정상 대조군: 캐시 키 보존 (B 가 재조회하지 않도록)",
		str(result.get("rider_texture_key", "")) == PlayerMountRiderSpriteCatalog.get_texture_cache_key("smasher")
	)
	_assert_cache_only("정상 대조군", fixture)


func _test_shipped_catalog_has_no_authored_rider() -> void:
	# 계약 8-10: N 5종 완비 전까지 shipped 라이더 경로는 비어 있어야 한다.
	# 하나라도 채워지면 백린 topdown 활성화 판단을 다시 해야 하므로 여기서 잡는다.
	var ids := PlayerMountRiderSpriteCatalog.get_character_ids()
	_expect("라이더 카탈로그: 캐릭터 5종 등재", ids.size() == 5)
	for expected_id in ["smasher", "viper", "soldier", "blacksmith", "optimus"]:
		_expect("라이더 카탈로그: %s 등재" % expected_id, ids.has(expected_id))
		var spec: Dictionary = PlayerMountRiderSpriteCatalog.get_rider_spec(expected_id)
		_expect("라이더 카탈로그: %s 규격 선언" % expected_id, not spec.is_empty())
		_expect(
			"라이더 카탈로그: %s 는 아직 미저작(8-10) — get_rider() 빈 dict" % expected_id,
			PlayerMountRiderSpriteCatalog.get_rider(expected_id).is_empty()
		)
	# 발토르만 128 계열 — 캐릭터별 규격 차이가 카탈로그에 살아 있어야 한다.
	var blacksmith_size: Vector2 = PlayerMountRiderSpriteCatalog.get_rider_spec("blacksmith").get("draw_size", Vector2.ZERO)
	var smasher_size: Vector2 = PlayerMountRiderSpriteCatalog.get_rider_spec("smasher").get("draw_size", Vector2.ZERO)
	_expect("라이더 카탈로그: 발토르 draw_size 128 계열", is_equal_approx(blacksmith_size.x, 128.0))
	_expect("라이더 카탈로그: 스매셔 draw_size 160 계열", is_equal_approx(smasher_size.x, 160.0))
	_expect("라이더 카탈로그: 미등재 캐릭터는 빈 dict (fail-closed)", PlayerMountRiderSpriteCatalog.get_rider_spec("__none__").is_empty())


func _test_rider_texture_key_contract() -> void:
	# 게이트와 draw context 가 같은 키를 쓰게 하는 단일 정본 — 소유자는 카탈로그다.
	_expect(
		"라이더 텍스처 키: 캐릭터 id 정규화 + 접두사",
		PlayerMountRiderSpriteCatalog.get_texture_cache_key("  SMASHER ") == "player_mount_rider_seated_smasher"
	)
	_expect("라이더 텍스처 키: 빈 id 는 빈 문자열", PlayerMountRiderSpriteCatalog.get_texture_cache_key("") == "")
	_expect(
		"라이더 텍스처 키: readiness 는 카탈로그에 위임(문자열 재작성 금지)",
		LingpetMountTopdownReadiness.rider_texture_key("commando") == PlayerMountRiderSpriteCatalog.get_texture_cache_key("commando")
	)


func _test_character_alias_control() -> void:
	# PlayerCharacterRuntime.normalize() 의 별칭을 카탈로그도 풀어야 한다.
	# 단 normalize() 를 그대로 쓰면 미지의 값이 smasher 로 폴백해 fail-closed 가
	# 깨지므로, 카탈로그는 아는 별칭만 풀고 모르는 값은 버린다.
	var cases := {
		"commando": "soldier",
		"COMMANDO": "soldier",
		"  baltor ": "blacksmith",
		"kohaku": "blacksmith",
		"io": "optimus",
		"soldier": "soldier",
		"blacksmith": "blacksmith",
		"optimus": "optimus",
		"viper": "viper",
		"smasher": "smasher",
	}
	for raw_id in cases.keys():
		var expected := str(cases[raw_id])
		_expect(
			"별칭 대조군: %s -> %s" % [str(raw_id), expected],
			PlayerMountRiderSpriteCatalog.canonical_character_id(str(raw_id)) == expected
		)
		_expect(
			"별칭 대조군: %s 키가 정본 키와 동일" % str(raw_id),
			PlayerMountRiderSpriteCatalog.get_texture_cache_key(str(raw_id)) == "player_mount_rider_seated_%s" % expected
		)
	# 미지의 값은 smasher 로 폴백하지 않는다 (normalize() 와의 결정적 차이).
	for unknown_id in ["__none__", "mika", "serin", "hanmiryang", ""]:
		_expect(
			"별칭 대조군: 미지의 %s 는 빈 문자열 (smasher 폴백 금지)" % str(unknown_id),
			PlayerMountRiderSpriteCatalog.canonical_character_id(str(unknown_id)) == ""
		)
		_expect(
			"별칭 대조군: 미지의 %s 는 규격도 빈 dict" % str(unknown_id),
			PlayerMountRiderSpriteCatalog.get_rider_spec(str(unknown_id)).is_empty()
		)


# ══════════ 운영 관통 (P14 게이트 연결) ══════════
# resolver 단위가 아니라 **실 egg 갱신 → readiness 완전 교체 → coordinator →
# mount_state 게이트**를 관통한다. 탑다운 모델은 shipped 카탈로그에 없으므로
# (8-10) 백린 엔트리에 런타임으로 주입하고 레그 끝에 제거한다(인메모리 픽스처).
const MOUNT_FIXTURE_PATH := "res://__fixture__/baekrin_mount_base_1x1.png"

# store_texture 는 resource_path 를 경로에 고정하므로 같은 경로로 두 번 만들면
# 엔진이 cyclic-inclusion 오류를 낸다 — 픽스처 텍스처는 전 레그가 1개를 공유한다.
var _mount_fixture_texture: Texture2D = null


func _ensure_mount_fixture_texture() -> void:
	if _mount_fixture_texture == null:
		_mount_fixture_texture = _make_texture()
		ProjectResourceLoader.store_texture(MOUNT_FIXTURE_PATH, _mount_fixture_texture)


class FakeInputProbe:
	extends RefCounted

	var rmb := false
	var down := false

	func is_rmb_pressed() -> bool:
		return rmb

	func is_down_pressed() -> bool:
		return down


class OperationalOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 675.0)
	var player_paddle_width := 155.0
	var player_speed := 0.0
	var selected_character_type := "smasher"
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_size := 28.6


class OperationalRegistry:
	extends RefCounted

	var cached: Dictionary = {}
	var instantiating_calls := 0

	func get_cached_instance(key: String) -> Variant:
		return cached.get(key, null)

	func get_instance(key: String) -> Variant:
		instantiating_calls += 1
		return cached.get(key, null)


func _install_topdown_model(with_base_path: bool) -> void:
	# const PETS 는 read-only — 8-10 이 승인한 테스트 오버라이드가 유일 수단이다.
	# M 축은 base_path 유무로 제어한다: 빈 경로 = 프리웜·peek 모두 자연 스킵
	# (실로드 경고 없이 REASON_NO_MOUNT_TEXTURE 로 귀결).
	LingpetCatalog.set_mount_presentation_override_for_tests(
		"baekrin",
		LingpetCatalog.MOUNT_PRESENTATION_TOPDOWN,
		MOUNT_FIXTURE_PATH if with_base_path else ""
	)


func _remove_topdown_model() -> void:
	LingpetCatalog.clear_mount_presentation_test_overrides()


# mount_ready=true 면 M 을 프리웜(셋업 시점 로드 — 게이트는 cache-only peek 만 한다),
# rider_published=true 면 발행 캐시에 N 을 싣는다.
func _make_operational_runtime(owner: Object, registry: OperationalRegistry, mount_ready: bool, rider_authored: bool, rider_published: bool) -> Object:
	_install_topdown_model(mount_ready)
	if mount_ready:
		_ensure_mount_fixture_texture()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.debug_grant_and_activate_pet("baekrin", owner, false, "baekrin_saddle")
	runtime._state = "companion"
	runtime._guardian_stowed = false
	var center_x: float = owner.player_pos.x + owner.player_paddle_width * 0.5
	runtime._companion_motion_coordinator.set_position(Vector2(center_x, 655.0))
	if mount_ready:
		runtime._current_profile.get_visual_texture(LingpetCatalog.MOUNT_BASE_VISUAL_KEY, null)
	if rider_authored:
		runtime._mount_topdown_readiness.rider_spec_provider = func(_character_id: String) -> Dictionary:
			return _make_rider_spec()
	var resources := SpyBattleResources.new()
	if rider_published:
		resources.resource_cache[PlayerMountRiderSpriteCatalog.get_texture_cache_key("smasher")] = _make_texture()
	registry.cached["battle_resources"] = resources
	return runtime


func _try_mount_via_runtime(runtime: Object, owner: Object, registry: Object) -> bool:
	var probe := FakeInputProbe.new()
	runtime._mount_state.set_input_probe(probe)
	probe.rmb = false
	runtime._update_companion_motion(0.016, owner, registry)
	probe.rmb = true
	runtime._update_companion_motion(0.016, owner, registry)
	probe.rmb = false
	return bool(runtime._mount_state.is_mounted())


func _test_operational_gate_blocks_when_not_ready() -> void:
	var combos := [
		{"label": "M 없음", "mount": false, "authored": true, "published": true},
		{"label": "N 미발행", "mount": true, "authored": true, "published": false},
		{"label": "N 미저작", "mount": true, "authored": false, "published": true},
		{"label": "둘 다 없음", "mount": false, "authored": true, "published": false},
	]
	for combo in combos:
		var owner := OperationalOwner.new()
		var registry := OperationalRegistry.new()
		var runtime := _make_operational_runtime(
			owner, registry,
			bool(combo["mount"]), bool(combo["authored"]), bool(combo["published"])
		)
		_expect(
			"운영 게이트 %s: 탑다운 진입 차단" % str(combo["label"]),
			not _try_mount_via_runtime(runtime, owner, registry)
		)
		_expect(
			"운영 게이트 %s: readiness 결과가 미준비" % str(combo["label"]),
			not bool(runtime.get_topdown_mount_readiness().get("ready", true))
		)
		_expect(
			"운영 게이트 %s: get_instance 0회" % str(combo["label"]),
			registry.instantiating_calls == 0
		)
	_remove_topdown_model()


func _test_operational_gate_positive_and_revoke() -> void:
	# 양성 대조군: M+N 준비 → 진입 성립
	var owner := OperationalOwner.new()
	var registry := OperationalRegistry.new()
	var runtime := _make_operational_runtime(owner, registry, true, true, true)
	_expect("운영 양성: M+N 준비 시 탑다운 진입 성립", _try_mount_via_runtime(runtime, owner, registry))
	_expect(
		"운영 양성: readiness 결과 ready + rider_texture 객체 보존 (B 재조회 금지 소스)",
		bool(runtime.get_topdown_mount_readiness().get("ready", false))
		and runtime.get_topdown_mount_readiness().get("rider_texture", null) != null
	)
	# 탑승 중 미준비 전이: 발행 캐시에서 N 이 사라지면 같은 프레임 철회
	var resources: SpyBattleResources = registry.cached["battle_resources"]
	resources.resource_cache.erase(PlayerMountRiderSpriteCatalog.get_texture_cache_key("smasher"))
	runtime._update_companion_motion(0.016, owner, registry)
	_expect("운영 철회: 탑승 중 N 소실 → 같은 프레임 강제 하차", not bool(runtime._mount_state.is_mounted()))
	_remove_topdown_model()


func _test_operational_onimaru_untouched() -> void:
	# 온이마루(비탑다운): M/N 이 전혀 없어도 유예 탑승이 현행 그대로 성립한다.
	var owner := OperationalOwner.new()
	var registry := OperationalRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.debug_grant_and_activate_pet("onimaru", owner, false)
	runtime._state = "companion"
	runtime._guardian_stowed = false
	var center_x: float = owner.player_pos.x + owner.player_paddle_width * 0.5
	runtime._companion_motion_coordinator.set_position(Vector2(center_x, 655.0))
	_expect("운영 온이마루 무접촉: M/N 없어도 탑승 성립", _try_mount_via_runtime(runtime, owner, registry))


# ══════════ 카탈로그 값 검증 (P2) ══════════
func _make_validation_entry(layout: Dictionary) -> Dictionary:
	return {
		"id": "fixture_pet",
		"display_name": "픽스처",
		"hatch_weight": 1,
		"required_hits": 3,
		"enabled": true,
		LingpetCatalog.MOUNT_PRESENTATION_MODEL_KEY: LingpetCatalog.MOUNT_PRESENTATION_TOPDOWN,
		"visuals": {LingpetCatalog.MOUNT_BASE_VISUAL_KEY: "res://__fixture__/x.png"},
		"visual_layout": layout,
	}


func _has_issue(issues: Array, needle: String) -> bool:
	for issue in issues:
		if str(issue).find(needle) >= 0:
			return true
	return false


func _validate_layout(layout: Dictionary) -> Array:
	# 실 validate_entry 통합 관통 — 존재 검사와 값 검사가 같은 경로에서 나온다.
	return LingpetCatalog.validate_entry("fixture_pet", _make_validation_entry(layout), false)


func _good_layout() -> Dictionary:
	return {
		"companion_mount_base_cols": 1.0,
		"companion_mount_base_rows": 1.0,
		"companion_mount_base_frame_count": 1.0,
		"companion_mount_base_draw_size": 92.0,
		"companion_mount_base_saddle_x": 128.0,
		"companion_mount_base_saddle_y": 64.0,
	}


func _test_mount_validation_value_checks() -> void:
	# 정상 레이아웃: mount 관련 이슈 0건
	var clean := _validate_layout(_good_layout())
	_expect("값검증 대조군: 정상 레이아웃에 mount 이슈 없음", not _has_issue(clean, "companion_mount_base"))

	var zero_cols := _good_layout()
	zero_cols["companion_mount_base_cols"] = 0.0
	_expect("값검증: cols=0 거부", _has_issue(_validate_layout(zero_cols), "companion_mount_base_cols must be a positive integer"))

	var negative_frames := _good_layout()
	negative_frames["companion_mount_base_frame_count"] = -3.0
	_expect("값검증: 음수 frame_count 거부", _has_issue(_validate_layout(negative_frames), "companion_mount_base_frame_count must be a positive integer"))

	var over_capacity := _good_layout()
	over_capacity["companion_mount_base_cols"] = 5.0
	over_capacity["companion_mount_base_rows"] = 5.0
	over_capacity["companion_mount_base_frame_count"] = 30.0
	_expect("값검증: frame_count > cols*rows 거부", _has_issue(_validate_layout(over_capacity), "exceeds grid capacity"))

	var zero_draw := _good_layout()
	zero_draw["companion_mount_base_draw_size"] = 0.0
	_expect("값검증: draw_size=0 거부", _has_issue(_validate_layout(zero_draw), "companion_mount_base_draw_size must be > 0"))

	var string_draw := _good_layout()
	string_draw["companion_mount_base_draw_size"] = "92"
	_expect("값검증: 문자열 draw_size 거부 (float 전용)", _has_issue(_validate_layout(string_draw), "companion_mount_base_draw_size must be a number"))

	var infinite_saddle := _good_layout()
	infinite_saddle["companion_mount_base_saddle_x"] = INF
	_expect("값검증: 무한 saddle 좌표 거부", _has_issue(_validate_layout(infinite_saddle), "companion_mount_base_saddle_x must be finite"))

	var fractional_cols := _good_layout()
	fractional_cols["companion_mount_base_cols"] = 2.5
	_expect("값검증: 비정수 cols 거부", _has_issue(_validate_layout(fractional_cols), "companion_mount_base_cols must be a positive integer"))
