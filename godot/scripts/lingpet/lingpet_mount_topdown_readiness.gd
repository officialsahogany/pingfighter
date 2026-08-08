extends RefCounted

# 탑다운 탑승 준비도 게이트 — S3-a 슬라이스 A.
# 정본 계약: docs/lingpet_topdown_mount_render_contract.md §A-4 / §A-4a.
#
# 왜 런타임 게이트가 따로 필요한가:
#   validate_catalog() 는 프로덕션에서 **한 번도 호출되지 않는다**(스모크 전용).
#   따라서 카탈로그 검증만 믿으면, 실제 플레이에서 M 텍스처나 현재 캐릭터의 N 이
#   없을 때 N 은 기존 걷기 포즈로 폴백해 그려지고 M 만 빠져 캐릭터가 허공에 앉는다.
#   그래서 "양쪽 준비 안 되면 탑다운 진입 차단 / 탑승 중이면 같은 프레임 철회"를
#   런타임에서 한 번 더 본다.
#
# 두 가지 계약이 이 파일의 존재 이유다:
#
#  (1) cache-only — 이 판정은 매 프레임 탑승 게이트에서 돈다. 여기서 로드를
#      트리거하면 첫 탑승 동기 로드 히치를 게이트가 매 프레임 후보로 되살린다.
#      허용: profile.get_cached_visual_texture(:398) / 이미 만들어진
#      battle_resources 의 resource cache dict 조회.
#      금지: profile.get_visual_texture(:394) / load_texture / load_imported_* /
#            prewarm_* 호출 — 전부 캐시 미스 시 로드를 친다.
#      준비는 프리웜(DEFAULT_PREWARM_KEYS)이 책임지고, 게이트는 "이미 준비됐나"만 본다.
#
#  (2) 키마다 정본 캐시가 다르다 — 리포에 텍스처 캐시가 둘 있고 서로 별개다:
#        · ProjectResourceLoader._texture_cache        : static 전역
#        · BattleTextureSpecStore._resource_cache      : 인스턴스 dict
#      actor context 의 `textures` 는 **후자**를 소비한다
#      (battle_resources.get_resource_cache() → battle_draw_actor_context).
#      그러므로 M(링펫 visual 캐시 소비)과 N(actor context 소비)의 판정 캐시가
#      달라야 한다. 전역 캐시로 N 을 판정하면 "게이트 GREEN인데 화면은 기존
#      걷기 포즈"가 성립한다.
#
# ⚠️ battle_resources 를 여기서 **새로 만들지 않는다**. registry.get_cached_instance
#    (비-인스턴스화 peek)만 쓰고 미존재면 미준비로 fail-closed 한다.
#    get_instance() 는 hot-path lazy-init 트랩이다.
#
# ⚠️ 호출자는 character_id 에 **PlayerCharacterRuntime.normalize() 를 먼저 태우지
#    말 것.** 그 함수는 미지 값을 smasher 로 폴백하므로(:11-22) strict
#    canonical_character_id() 가 거부할 기회를 잃고 게이트가 "스매셔 N"으로 잘못
#    열린다. 원시 id 를 그대로 넘기면 여기서 별칭만 풀고 미지 값은 버린다.
#    canonical id 와 캐시 키는 여기서 **1회만** 계산해 결과 dict 에 실어 보낸다 —
#    슬라이스 B 는 재정규화·재조회 없이 그 값과 rider_texture 객체를 그대로 써야
#    P16② 동일 객체 계약이 성립한다.
#
# ⚠️ egg 배선 시 원시 id 의 **폴백도 빈 문자열이어야 한다**:
#      BattleSceneOwnerReader.get_value(owner, "selected_character_type", "")
#    폴백을 "smasher" 로 두면 필드 자체가 누락됐을 때 다시 fail-open 되어
#    "스매셔 N"으로 게이트가 열린다(normalize() 폴백과 같은 구멍).

const PlayerMountRiderSpriteCatalog := preload("res://scripts/resources/player_mount_rider_sprite_catalog.gd")

const MOUNT_BASE_VISUAL_KEY := "companion_mount_base"
const BATTLE_RESOURCES_REGISTRY_KEY := "battle_resources"

# 미준비 사유 (씰 라벨 / 디버그용).
const REASON_READY := "ready"
const REASON_NOT_TOPDOWN := "not_topdown_model"
const REASON_NO_MOUNT_TEXTURE := "mount_base_texture_not_cached"
const REASON_NO_RIDER_SHEET := "rider_sheet_unauthored"
const REASON_NO_RIDER_TEXTURE := "rider_texture_not_published"
const REASON_NO_RESOURCES := "battle_resources_not_instantiated"
const REASON_UNKNOWN_CHARACTER := "unknown_character_id"

# 라이더 규격 공급자 seam. 비워두면 운영 카탈로그를 쓴다.
# S3-a 시점에는 N 시트가 0장이라 카탈로그가 항상 빈 dict 를 돌려주므로(8-10),
# 골격 씰이 "저작된 라이더가 있는" 경로를 검증하려면 이 seam 으로 1×1 인메모리
# 픽스처를 주입한다. 운영 경로는 seam 을 건드리지 않는다.
var rider_spec_provider: Callable = Callable()


# 키 정본은 라이더 카탈로그가 소유한다(path·규격과 같은 자리). 여기서는 위임만 —
# 문자열을 재작성하면 battle_resources 저장 측과 드리프트한다.
static func rider_texture_key(character_id: String) -> String:
	return PlayerMountRiderSpriteCatalog.get_texture_cache_key(character_id)


# 판정 본체. profile 은 egg runtime 의 _current_profile(정식 소유자, 또는
# get_cached_visual_texture 를 가진 스파이), registry 는 battle_resources 를 peek 할
# 레지스트리다. pet_id 는 받지 않는다 — profile 이 자기 pet_id 를 이미 소유하므로
# 따로 넘기면 두 값이 어긋날 수 있다.
#
# 반환: {
#   "ready": bool,
#   "reason": String,
#   "mount_texture": Texture2D | null,
#   "rider_texture": Texture2D | null,   # ← 이 객체가 그대로 actor context 로 간다
#   "rider_spec": Dictionary,
#   "rider_character_id": String,        # strict 정본화 결과 (미지 값이면 "")
#   "rider_texture_key": String,         # actor context 발행/조회 공용 키
# }
func resolve(
	character_id: String,
	topdown_model: bool,
	profile: Object,
	registry: Object
) -> Dictionary:
	var result := {
		"ready": false,
		"reason": REASON_NOT_TOPDOWN,
		"mount_texture": null,
		"rider_texture": null,
		"rider_spec": {},
		"rider_character_id": "",
		"rider_texture_key": "",
	}
	if not topdown_model:
		return result

	# ── M: 링펫 visual 캐시의 cache-only peek (로드 금지) ──────────────────
	var mount_texture: Texture2D = _peek_mount_texture(profile)
	result["mount_texture"] = mount_texture
	if mount_texture == null:
		result["reason"] = REASON_NO_MOUNT_TEXTURE
		return result

	# ── N: strict 정본화(1회) → 저작 여부 → 실제 발행 객체 ────────────────
	# 원시 id 를 그대로 받는다. 여기서 별칭만 풀고 미지 값은 버린다.
	var canonical_id := PlayerMountRiderSpriteCatalog.canonical_character_id(character_id)
	result["rider_character_id"] = canonical_id
	if canonical_id == "":
		result["reason"] = REASON_UNKNOWN_CHARACTER
		return result
	var texture_key := PlayerMountRiderSpriteCatalog.texture_cache_key_from_canonical(canonical_id)
	result["rider_texture_key"] = texture_key

	var rider_spec: Dictionary = _resolve_rider_spec_from_canonical(canonical_id)
	result["rider_spec"] = rider_spec
	if rider_spec.is_empty():
		result["reason"] = REASON_NO_RIDER_SHEET
		return result

	var resources: Object = _peek_battle_resources(registry)
	if resources == null:
		result["reason"] = REASON_NO_RESOURCES
		return result

	var rider_texture: Texture2D = _peek_rider_texture(resources, texture_key)
	result["rider_texture"] = rider_texture
	if rider_texture == null:
		result["reason"] = REASON_NO_RIDER_TEXTURE
		return result

	result["ready"] = true
	result["reason"] = REASON_READY
	return result


func is_ready(
	character_id: String,
	topdown_model: bool,
	profile: Object,
	registry: Object
) -> bool:
	return bool(resolve(character_id, topdown_model, profile, registry).get("ready", false))


# ── peek 헬퍼 (전부 cache-only) ────────────────────────────────────────────

func _resolve_rider_spec_from_canonical(canonical_id: String) -> Dictionary:
	# 이미 정본화된 id 만 받는다 — 카탈로그에서 재정규화하지 않는 경로를 쓴다.
	if rider_spec_provider.is_valid():
		var provided: Variant = rider_spec_provider.call(canonical_id)
		return provided as Dictionary if provided is Dictionary else {}
	return PlayerMountRiderSpriteCatalog.get_rider_from_canonical(canonical_id)


func _peek_mount_texture(profile: Object) -> Texture2D:
	# 정식 소유자는 egg runtime 의 _current_profile 이고, 그 공개 cache-only API 가
	# get_cached_visual_texture 다(lingpet_current_profile.gd:398). private
	# _visual_texture_cache 를 꺼내 쓰지 않는다.
	# ⚠️ get_visual_texture(:394)는 캐시 미스 시 **동기 로드**한다 — 매 프레임 게이트에서
	#    부르면 안 되는 API다.
	if profile == null or not profile.has_method("get_cached_visual_texture"):
		return null
	var value: Variant = profile.get_cached_visual_texture(MOUNT_BASE_VISUAL_KEY, null)
	return value as Texture2D if value is Texture2D else null


func _peek_battle_resources(registry: Object) -> Object:
	if registry == null:
		return null
	# ⚠️ get_instance() 금지 — 없으면 만들어 버린다(hot-path lazy-init 트랩).
	if not registry.has_method("get_cached_instance"):
		return null
	var cached: Variant = registry.get_cached_instance(BATTLE_RESOURCES_REGISTRY_KEY)
	return cached as Object if cached is Object else null


func _peek_rider_texture(resources: Object, key: String) -> Texture2D:
	# 키는 resolve() 가 1회 계산해 넘긴다 — 여기서 재정규화하지 않는다.
	if key == "" or resources == null or not resources.has_method("get_resource_cache"):
		return null
	var cache: Variant = resources.get_resource_cache()
	if not (cache is Dictionary):
		return null
	var value: Variant = (cache as Dictionary).get(key, null)
	return value as Texture2D if value is Texture2D else null
