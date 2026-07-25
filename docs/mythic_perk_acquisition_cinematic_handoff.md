# 코덱스 핸드오프 — 신화퍽 확정상자 획득 시 신화 획득 시네마틱 재생

발주: 2026-07-08. 요구: 결과화면 신화퍽 확정상자에서 신화퍽 획득 시, 기존 신화
**아이템** 획득 연출(백플레이트+아크+슬램 시네마틱, `mythic_item_acquisition_cinematic_v2`)
이 똑같이 등장. 표시 결정: **퍽 아이콘(애니 시트) + 퍽 이름 + 퍽 설명**.
Claude 기획 → Codex 배선 → Claude 적대 리뷰 → 통과 시 자동커밋.

## 현행 (조사 확정)

- 신화 **아이템**(flag OFF): 리졸버 `_try_start_acquisition_cinematic`(line ~349) →
  `mythic_item_runtime.start_acquisition_cinematic(item_data, pos, owner, registry)` →
  v2 시네마틱 재생. 결과화면은 `stage_clear_result_mythic_acquisition_handler`가
  `is_acquisition_cinematic_active` 폴링으로 update/input/z-raise(1305) 처리 — **퍽도
  같은 폴링에 자동 편승**(핸들러 수정 불필요).
- 신화 **퍽**(flag ON, S5a): `_grant_mythic_perk_reward`(line ~375)가
  `MythicPerkGrantHelper.grant_reward`만 호출 — **시네마틱 미발동**. 현재 리빌은
  보라 서클+이름(스크린샷)뿐.
- 결과화면 상자 오픈 두 경로(`stage_clear_result_reward_grant_state` line 37,
  `stage_clear_result_immediate_reward_grant_data._grant_immediate_mythic_perk_box_reward`)
  모두 `reward_resolver.grant_rewards` → REWARD_MYTHIC_PERK →
  `_grant_mythic_perk_reward`로 **수렴 = 단일 초크포인트**.
- v2 시네마틱 게이트 `should_use_item_data`: `rarity=="mythic"`이면 통과 — 퍽 보상
  dict에 이미 `"rarity": "mythic"` 존재.
- v2 시네마틱 아이콘 로드 필드(`_load_item_texture`, line ~1379): `icon_sheet_path`
  (우선) / `icon_path`, `icon_frame_count`, `icon_frame_msec`, `icon_source_inset`.
- **v2는 텍스트를 전혀 안 그림**(Sprite2D+셰이더+파티클만, draw_string 0개) —
  이름/설명 레인은 이번에 신설해야 함.

## 배선

### ① 트리거 (`stage_clear_reward_resolver._grant_mythic_perk_reward`)
그랜트 성공 시에만 시네마틱 시작:
```
func _grant_mythic_perk_reward(reward, owner, registry) -> Dictionary:
    var result := MythicPerkGrantHelper.grant_reward(reward, owner, registry)
    if bool(result.get("granted", false)) \
            and str(result.get("reward_type", "")) == REWARD_MYTHIC_PERK \
            and not bool(result.get("fallback_starpoint", false)):
        _try_start_mythic_perk_acquisition_cinematic(
            str(result.get("perk_id", "")), reward, owner, registry)
    return result
```
- **SP 폴백(슬롯가득/전부보유)은 시네마틱 없음**(스타포인트 연출 그대로).
- mythic_item_runtime은 registry `get_instance("mythic_item_runtime")`, 널가드.

### ② 퍽용 item_data 구성 (신설 `_try_start_mythic_perk_acquisition_cinematic`)
```
var perk_data: Dictionary = <runtime_perk_catalog>.get_perk_data(perk_id)   # localize 경유
var descriptions: Dictionary = perk_data.get("descriptions", {})
var cinematic_data := {
    "name": str(perk_data.get("name", perk_id)),
    "rarity": "mythic",                                   # should_use_item_data 게이트
    "icon_sheet_path": <RuntimePerkIconRenderer.PERK_SHEET_PATHS.get(perk_id, "")>,
    "icon_frame_count": 8,
    "icon_frame_msec": 110,
    "reveal_description": str(descriptions.get(1, perk_data.get("detail", ""))),
}
mythic_item_runtime.start_acquisition_cinematic(cinematic_data, pickup_position, owner, registry)
```
- 아이콘 = **퍽 애니 시트**(R2: 신화 12종 전부 `<id>_perk_icon_sheet.png` 존재,
  1024x128 8프레임 ~110ms). PERK_SHEET_PATHS는 `runtime_perk_icon_renderer.gd`
  const — preload 참조 또는 경로 규약 복제 중 전자 권장(단일 소스).
- 시트 경로가 빈 문자열이면(방어) `icon_path`=정적 퍽 PNG로 폴백, 둘 다 없으면
  시네마틱 스킵(그랜트는 이미 완료 — 연출만 생략).
- `pickup_position`: reward dict의 `pickup_position` 있으면 사용, 없으면 기존
  기본값(Vector2(380,375)) — 아이템 경로 `_try_start_acquisition_cinematic`와 동일.
- 이름/설명 로컬라이즈: `get_perk_data`가 비-한국어에서 localize 경유인지 확인
  (`localize_perk_data` 경로) — 한국어 외 언어에서 name/descriptions가 PERK_NAME/
  PERK_SUMMARY 로컬로 나오는지. 아니면 LanguageSettings에서 직접 조회.

### ③ v2 시네마틱 텍스트 레인 신설 (additive-only)
`mythic_item_acquisition_cinematic_v2.gd`에 **이름 + 설명** 렌더 추가:
- 발동 조건: `item_data`에 비어있지 않은 `reveal_description`(또는 `name`+해당 키)
  존재할 때만. **키가 없으면(기존 아이템 경로) 렌더 0 = 바이트 동일 비주얼** —
  아이템 회귀 불가 구조.
- 표시: 리빌/홀드 페이즈(아이콘 슬램 후)에 아이콘 아래 이름(크게) + 설명(작게,
  1~2줄 wrap). 등장은 아이콘 리빌과 같은 페이즈에 페이드인, 종료 시 함께 페이드.
- 렌더 방식: `_draw()`에 `draw_string`(테마 기본 폰트) 또는 Label 자식 노드 —
  구현 단순한 쪽. **CJK 트랩**: 명시 NanumSquareB 지정 금지(日/中 글리프 드롭 —
  메모리 규칙), 테마 기본 폰트+fallback 경로 사용. 장식 유니코드 심볼 금지(tofu).
- 가독성: 어두운 반투명 밴드 또는 기존 백플레이트 위 — 픽셀QA로 확정.

## 조사 노트 (구현 시 참고)
- 결과화면 핸들러(`stage_clear_result_mythic_acquisition_handler`)는 폴링식이라
  **수정 불필요** — 시네마틱 active면 update/input/z(1305) 자동.
- 프리웜: 퍽 시트는 결과화면 퍽 리빌(보라 서클)이 이미 로드해 캐시 히트 예상.
  방어적으로 `prewarm_item_textures`에 신화 퍽 시트 12종 추가 가능(각 7~40KB).
- 기존 보라 서클 리빌과 시네마틱이 **겹쳐 재생**됨(시네마틱이 z 1305로 위) —
  시네마틱 종료 후 서클 리빌이 남는 흐름이 자연스러운지 픽셀QA로 판단. 어색하면
  시네마틱 active 동안 서클 리빌 suppress(선택 폴리시, 보고만).

## 범위 제외
- 보물탐색 신화퍽(전투 중) 시네마틱 — 사용자 요구는 **결과화면 상자**. 형제 경로
  감사만 노트(원하면 후속).
- flag OFF 신화 아이템 경로(무변경 — additive 키 게이트로 구조 보장).
- 시네마틱 비주얼 자체 리디자인(기존 연출 재사용).

## 스모크 (신설: `mythic_perk_acquisition_cinematic_smoke.gd`)
- [ ] flag ON + 신화퍽 그랜트 성공 → `mythic_item_runtime.is_acquisition_cinematic_active()`
      true + 시네마틱 item_data(스냅샷)의 name=퍽 이름
- [ ] SP 폴백 그랜트(슬롯가득 강제) → 시네마틱 **미발동**
- [ ] 시트 경로 유효(12종 전부 PERK_SHEET_PATHS 존재 + file exists)
- [ ] 아이템 경로 회귀: `reveal_description` 없는 기존 item_data로 trigger → 기존과
      동일(텍스트 레인 미발동 — 상태/스냅샷 레벨로 확인)
- [ ] flag OFF: 리졸버 신화 아이템 경로 무변경(기존 씰 유지)

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)
1. 트리거 호출 임시 제거 → "그랜트 성공 시 cinematic active" 레그 RED → 복원
2. SP 폴백 가드(`fallback_starpoint` 체크) 임시 제거 → "SP 폴백 미발동" 레그 RED → 복원

## 트랩 노트
- **미존재 에셋 per-frame re-stat 트랩**: icon_sheet_path가 빈/오타 경로로 매프레임
  로드 시도하지 않게 — 시작 시 1회 로드 실패면 시네마틱 스킵(기존 v2 로드 흐름 확인).
- **modal pause**: 시네마틱 active는 `should_pause_game` 계열 — 결과화면은 이미 모달이라
  무해하나, owned-ball 트랩 문서의 pause 분기 목록에 새 분기를 **추가하지 말 것**(기존
  분기 재사용).
- 텍스트는 additive-only 키 게이트(아이템 경로 바이트 동일). 픽셀QA 필수(negative-z/
  가독성). owner set() 스키마 무관. UTF-8 BOM 금지, `.agents/skills/` 미러 금지.
- **커밋 엉킴**: `stage_clear_reward_resolver`·시네마틱 v2에 타 트랙 WIP 있는지 커밋
  전 헝크 확인 — perk 체크포인트 INCLUDE 밖 파일들이라 별도 커밋 가능 예상이나,
  불가 시 검증완료·미커밋 보고.

## 완료 보고 형식
(1) 변경 지점(리졸버 트리거 + item_data 빌더 + v2 텍스트 레인), (2) 신설 스모크 결과
원문, (3) 반증검증 2건 RED→GREEN, (4) 아이템 경로/flag OFF 회귀 무변화 + SP 폴백
미발동 자가 확인, (5) 결과화면 실재생 스크린샷(이름+설명 가독), (6) 이탈/가정.
