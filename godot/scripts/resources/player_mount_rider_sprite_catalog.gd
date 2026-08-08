extends RefCounted

# 탑다운 탑승 라이더(N) 시트 카탈로그 — S3-a 슬라이스 A.
# 정본 계약: docs/lingpet_topdown_mount_render_contract.md §A-2.
#
# 왜 펫 카탈로그가 아니라 여기인가:
#   라이더 착석 포즈는 **캐릭터 자산**이지 수호령 자산이 아니다. 펫 visuals(평면
#   dict)에 캐릭터 5키를 넣으면 마운트 가능 펫이 늘 때마다 5줄씩 복제되어 데이터가
#   M×N으로 불어난다 — docs/sprite_socket_composition_contract.md 레인 C의 M+N
#   표준("조합 0벌")이 금지한 회귀다.
#
# 왜 경로만 담는 paths 파일이 아닌가:
#   캐릭터마다 셀·그리드·draw_size가 다르다(발토르 128 vs 나머지 160,
#   battle_draw_actor_context.gd:18/:330-331). 경로와 규격이 서로 다른 파일에 살면
#   어긋났을 때 조용히 오슬라이스된다. 한 엔트리가 둘을 함께 소유한다.
#
# 키는 PlayerCharacterRuntime.normalize() 결과 문자열과 **동일**해야 한다
# (soldier / blacksmith / optimus — 별칭 commando / baltor / io 를 키로 쓰지 않는다).
#
# ⚠️ S3-a 시점에는 N 시트가 한 장도 없다(계약 8-10: N 5종 완비 전까지 백린 shipped
# 카탈로그에 topdown 모델을 넣지 않는다). 그래서 모든 path 가 빈 문자열이고
# get_rider() 는 빈 dict 를 돌려준다 = fail-closed. 준비도 게이트(§A-4)가 이걸 보고
# 탑다운 진입을 막는다. 시트가 랜딩되면 path 만 채우면 된다.

# actor context 의 `textures` dict 에서 라이더 시트를 찾는 키의 **단일 정본**.
# battle_resources(저장) · 준비도 게이트(조회) · actor context(발행) 가 전부 이 함수
# 하나만 호출한다 — 문자열을 각자 재작성하면 드리프트하고, 링펫 모듈이 소유하면
# 리소스 계층이 링펫을 역참조하는 소유권 역전이 된다.
const TEXTURE_CACHE_KEY_PREFIX := "player_mount_rider_seated_"

# 별칭 → 정본 id. PlayerCharacterRuntime.normalize() 를 그대로 쓰지 않는 이유:
# 그 함수는 **미지의 값을 smasher 로 폴백**한다(player_character_runtime.gd:11-22).
# 오타 하나가 "스매셔 라이더"로 둔갑해 fail-closed 가 깨진다.
# 여기서는 아는 별칭만 풀고 모르는 값은 버린다.
#
# ⚠️ 탑승 준비도 경로에서는 **normalize() 선행 호출을 금지한다.** 먼저 통과시키면
#    미지 값이 이미 smasher 로 바뀐 뒤라 아래 strict 판정이 거부할 기회를 잃고,
#    준비도 게이트가 "스매셔 N"으로 잘못 열린다. 원시 character id 를 그대로
#    canonical_character_id() 에 넘길 것.
const CHARACTER_ID_ALIASES := {
	"commando": "soldier",
	"baltor": "blacksmith",
	"kohaku": "blacksmith",
	"io": "optimus",
}

const RIDERS := {
	"smasher": {
		"path": "",
		"cols": 1,
		"rows": 1,
		"frame_count": 1,
		"draw_size": Vector2(160.0, 160.0),
	},
	"viper": {
		"path": "",
		"cols": 1,
		"rows": 1,
		"frame_count": 1,
		"draw_size": Vector2(160.0, 160.0),
	},
	"soldier": {
		"path": "",
		"cols": 1,
		"rows": 1,
		"frame_count": 1,
		"draw_size": Vector2(160.0, 160.0),
	},
	"blacksmith": {
		# 발토르만 본체 draw_size 가 128 계열이다
		# (battle_draw_actor_context.gd:18 BLACKSMITH_PLAYER_DRAW_SIZE).
		"path": "",
		"cols": 1,
		"rows": 1,
		"frame_count": 1,
		"draw_size": Vector2(128.0, 128.0),
	},
	"optimus": {
		"path": "",
		"cols": 1,
		"rows": 1,
		"frame_count": 1,
		"draw_size": Vector2(160.0, 160.0),
	},
}


# 별칭을 풀어 정본 id 로. 모르는 값은 빈 문자열(fail-closed) — normalize() 와 달리
# smasher 로 폴백하지 않는다.
static func canonical_character_id(character_id: String) -> String:
	var value := character_id.strip_edges().to_lower()
	if value == "":
		return ""
	if RIDERS.has(value):
		return value
	if CHARACTER_ID_ALIASES.has(value):
		return str(CHARACTER_ID_ALIASES[value])
	return ""


# actor context textures dict 의 라이더 키. 저장·조회·발행이 공유하는 유일 정본.
static func get_texture_cache_key(character_id: String) -> String:
	return texture_cache_key_from_canonical(canonical_character_id(character_id))


# 이미 정본화된 id 로 키만 만든다(재정규화 회피 — resolver 가 1회 계산해 보존한다).
static func texture_cache_key_from_canonical(canonical_id: String) -> String:
	if canonical_id == "" or not RIDERS.has(canonical_id):
		return ""
	return "%s%s" % [TEXTURE_CACHE_KEY_PREFIX, canonical_id]


# 미등재 캐릭터 / 경로 미저작이면 빈 dict (fail-closed).
# 준비도 게이트는 이 빈 dict 를 "N 미준비"로 읽는다.
static func get_rider(character_id: String) -> Dictionary:
	return get_rider_from_canonical(canonical_character_id(character_id))


# 이미 정본화된 id 전용. resolver 가 canonical 을 1회 계산해 보존하므로 재정규화를
# 하지 않는다 — "canonical 1회" 계약을 코드로 고정하는 지점이다.
static func get_rider_from_canonical(canonical_id: String) -> Dictionary:
	if canonical_id == "" or not RIDERS.has(canonical_id):
		return {}
	var entry: Dictionary = RIDERS[canonical_id] as Dictionary
	if str(entry.get("path", "")).strip_edges() == "":
		return {}
	return entry.duplicate(true)


# 경로 유무와 무관하게 선언된 규격만 필요할 때(씰 / 문서화용). 미등재면 빈 dict.
static func get_rider_spec(character_id: String) -> Dictionary:
	var canonical := canonical_character_id(character_id)
	if canonical == "":
		return {}
	return (RIDERS[canonical] as Dictionary).duplicate(true)


static func get_rider_path(character_id: String) -> String:
	var canonical := canonical_character_id(character_id)
	if canonical == "":
		return ""
	return str((RIDERS[canonical] as Dictionary).get("path", "")).strip_edges()


static func has_rider_sheet(character_id: String) -> bool:
	return get_rider_path(character_id) != ""


static func get_character_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in RIDERS.keys():
		ids.append(str(raw_id))
	return ids
