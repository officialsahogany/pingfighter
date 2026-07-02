# 링펫알 — 미래지향 받침 + 제각각 알 N종 (레이어 분리) 슬라이스 설계

> **2026-07-03 후속**: 필드 알은 받침 제거 + 맨 타원형 알 + 물리 구르기로 재조정한다.
> 받침은 상점 진열/아이콘 전용 크롬으로 보존. 후속 단일 소스 =
> `docs/lingpet_egg_bare_roll_slice_plan.md` (변종 시스템·RNG·save/load는 본 문서 그대로 유지).

단일 소스. **2026-06-27 피벗**: 균일 modulate(중립 베이스 × 색조곱)를 폐기하고, **그릇(받침)은
1장 고정 + 알은 제각각 imagegen N종**을 런타임 레이어 합성한다. 디자인 평가의 3갭(① 픽업 글로우
색충돌 ② 전 펫 maribo 핑크 알 공유 ③ 슬롯 크롭)은 그대로 닫힌다.

분담: Claude = 아트(받침·알 생성/누끼/수용) + 이 스펙 + 적대 리뷰. **Codex = 배선(이 조정 적용)**.
이미 배선된 modulate 슬라이스(미커밋)를 **이 문서대로 조정**한다.

---

## 0. 핵심 결정
- **레이어 분리**: 받침 1장(고정) + 알 N장(제각각). 같은 512 캔버스에 받침=하단·알=상단으로 정렬,
  런타임에서 **같은 rect에 2회 draw**(받침 먼저 → 알 위). 알 하단 1/3이 받침 볼에 안착, 에너지 링이
  알 허리를 감쌈.
- 알 색/모양/무늬는 **펫과 무관한 RNG 변종 인덱스**(스포 차단 불변식 유지).
- 알 종류 = **4~5종**(`EGG_VARIANT_COUNT`). 크랙 = **절차적 크랙-라이트 오버레이만**(알별 크랙
  텍스처 제작 안 함; 알 변종은 종류당 1장).
- 받침 = **미래지향 디자인**(부유 크래들 + 시안 에너지 링 + 골드 인레이 받침). v1 채택.

---

## 1. ✅ 재사용 (이미 배선됨 — 그대로 유지, 조정 최소)
modulate 슬라이스가 만든 인프라는 **인덱스 의미만 "색조"→"변종"으로 바뀔 뿐 구조는 동일**:
- `lingpet_egg_field_state.gd`: `egg_color_index` (스폰 1회 롤 `randi()%COUNT`, `advance()` 무관여,
  `reset_all` -1, 스냅샷, setter, **펫/profile 디커플**). → **이름만 `egg_variant_index`로 바꿔도
  되고(미커밋이라 save 호환 부담 없음) 유지해도 됨.** 롤 상한 상수는 `EGG_VARIANT_COUNT`로.
- save/load: `lingpet_runtime_snapshot_builder` / `lingpet_save_store`(기본 -1) / `lingpet_save_restore_applier`.
- 두 알 경로: 메인 `_egg_state` + 코이그지스트 `_item_egg_state` (공유 `LingpetEggFieldState`).
- `active_item_catalog._build_lingpet_egg` `color: Color(0.30,0.80,1.0)` 시안(#1 픽업 글로우). 유지.

---

## 2. 변종 텍스처 + 받침 (렌더러 소유)
**핵심 구조 변경**: 알 텍스처를 **펫 profile에서 읽지 않는다**. 렌더러가 고정 받침 + 변종 알 세트를
직접 소유하고 인덱스로 고른다(= 펫과 완전 분리, 스포 차단의 구조적 강화).

`lingpet_egg_field_renderer.gd` 상단 (✅ 에셋 배치·import 완료, 경로 LIVE):
```
const HOLDER_PATH := "res://assets/sprites/lingpet/resonance_egg_holder.png"
const EGG_VARIANT_PATHS := [
    "res://assets/sprites/lingpet/resonance_egg_variant_0.png",  # 0 crystal (cyan)
    "res://assets/sprites/lingpet/resonance_egg_variant_1.png",  # 1 mech (gold/amber)
    "res://assets/sprites/lingpet/resonance_egg_variant_2.png",  # 2 nebula (violet)
    "res://assets/sprites/lingpet/resonance_egg_variant_3.png",  # 3 rose (pink scale)
    "res://assets/sprites/lingpet/resonance_egg_variant_4.png",  # 4 rune (jade)
]
const EGG_VARIANT_GLOW := [
    Color(0.36, 0.82, 1.00),  # 0 cyan
    Color(1.00, 0.74, 0.32),  # 1 amber
    Color(0.66, 0.50, 1.00),  # 2 violet
    Color(1.00, 0.46, 0.64),  # 3 rose
    Color(0.42, 0.92, 0.64),  # 4 jade
]
const EGG_VARIANT_COUNT := EGG_VARIANT_PATHS.size()   # = 5
```
- **합성 규약**: 받침/알/아이콘 모두 512×512, 같은 rect에 그리면 정렬됨. 알 풋프린트 통일
  (x 163–347, 하단 y 267, 폭 184). 받침을 먼저 그리고 알을 위에 → 알이 크래들 볼에 안착.
- 슬롯 아이콘 `resonance_egg_item_icon.png` = 받침+crystal(variant_0) 사전합성 1장.
- `EGG_VARIANT_COUNT`는 한 곳(렌더러)만 권위. `field_state`는 렌더러의 count를 주입받거나 스모크가
  동일성 봉인(기존 `EGG_TINT_COUNT==get_tint_count()` 패턴 계승).
- 텍스처는 **렌더러가 1회 로드·캐시**(핫패스 lazy-load 금지 — Godot Hot-Path Lazy Init Trap). `prewarm()`
  추가해서 로드아웃-적용/보스 부팅 시 미리 적재(기존 `_prewarm_current_skill_runtime` 패턴 참조).

---

## 3. 색 롤 1회 + 저장 (변경 없음 — §1 그대로)
스폰서 1회 롤, 펫 디커플, 크랙 3상태 색/변종 공유(인덱스 1개), save/load 보존. (modulate판에서 검증·
반증검증 완료된 부분.)

---

## 4. 렌더러 = 2-레이어 합성 (modulate 제거)
`lingpet_egg_field_renderer.draw_egg` / `draw_profile_egg`:
- **modulate(`tint` 곱) 제거.** `EGG_TINTS` 삭제.
- 인자에 `variant_index: int` 받기. 그리기 순서:
  1. `draw_circle(...)` 글로우 — 색 = `EGG_VARIANT_GLOW[variant_index]`(범위 밖이면 시안 폴백).
  2. **받침** `draw_texture_rect(HOLDER_TEX, texture_rect, false)` (Color.WHITE, 알 뒤).
  3. **알** `draw_texture_rect(EGG_VARIANT_TEX[variant_index], texture_rect, false)` (Color.WHITE, 받침 위).
  4. `_draw_egg_crack_light(...)` (절차 크랙, `hatch_hits`로 강도; 기존 그대로).
- `draw_profile_egg`: 더 이상 `profile.get_visual_texture(egg_key)` 안 씀. `profile`/`required_hits`는
  **부화 상태(크랙 강도)** 용으로만. 텍스처는 `variant_index` → 렌더러 소유 세트에서.
- 호출부(`lingpet_egg_runtime` 메인 ~591 / 코이그지스트 ~607): `get_tint_for_index(...)` 대신
  해당 알 상태의 `egg_color_index`(변종 인덱스)를 그대로 전달.

---

## 5. 카탈로그 정리 (펫 egg 경로 → 폐기/플레이스홀더)
- `lingpet_catalog.gd`의 전 펫 `visuals.egg / egg_crack_1 / egg_crack_2`(현재 `resonance_egg_base*`)는
  **필드 알 렌더에 더 이상 쓰이지 않음**(렌더러가 변종 세트 소유). 깔끔히 하려면 키 제거, 또는 잔여
  참조 안전을 위해 placeholder 유지. **prewarm 키 셋(`DEFAULT_PREWARM_KEYS`)에서 egg/egg_crack 제거**
  하고 렌더러 `prewarm()`으로 대체.
- 슬롯 아이콘 `active_item_catalog.LINGPET_EGG_ICON_PATH` → **사전 합성 아이콘**
  `resonance_egg_item_icon.png`(받침 + 대표 알 1종 합성). (슬롯 렌더러는 modulate 안 하므로 합성본을
  그대로 표시.)
- ⚠️ 기존 `maribo_egg_v002*` / `resonance_egg_base*` 파일은 **삭제 금지**(롤백·비교용). 참조만 끊는다.

---

## 6. 아트 에셋 — ✅ 납품 완료 (배치 + import 끝)
`godot/assets/sprites/lingpet/`에 7장 PNG + 7장 `.import` 배치·import 완료(전부 untracked).
모두 512×512, 투명 코너, edge-touch 없음, 알 풋프린트 통일(x163–347/하단y267):
| res:// 경로 | 내용 | 글로우색 |
|---|---|---|
| `resonance_egg_holder.png` | 미래지향 받침(부유 크래들+시안 에너지링+골드 인레이 페디스털) | — |
| `resonance_egg_variant_0.png` | crystal (시안 크리스탈) | `(0.36,0.82,1.00)` |
| `resonance_egg_variant_1.png` | mech (골드/앰버 기어) | `(1.00,0.74,0.32)` |
| `resonance_egg_variant_2.png` | nebula (바이올렛 성운) | `(0.66,0.50,1.00)` |
| `resonance_egg_variant_3.png` | rose (로즈 펄스케일) | `(1.00,0.46,0.64)` |
| `resonance_egg_variant_4.png` | rune (제이드 룬) | `(0.42,0.92,0.64)` |
| `resonance_egg_item_icon.png` | 슬롯 합성 아이콘(받침+crystal) | — |

- 누끼 QA: 코너 전부 0(투명), 모트/스파클 제거(최대연결성분), 로즈 하단 알파 solidify, 받침은
  볼+받침대 두 성분 보존. 풋프린트/하단y 통일.
- ⚠️ 기존 `maribo_egg_v002*` / `resonance_egg_base*`는 보존(삭제 금지, 롤백/비교용). 참조만 끊는다.
- ⚠️ 커밋 선별: 이 슬라이스 = 위 7 PNG + 7 `.import`만. 전체 import가 트리의 다른 untracked WIP
  자산 `.import`도 생성했을 수 있으니 egg-set 14파일만 담을 것.

---

## 7. 봉인 (스모크 — 조정)
기존 `_verify_egg_color_rolls_once_and_restores` 유지 + 조정:
- ✅ 유지: 스폰 1회 롤·`advance` 재롤 금지·펫 디커플(field_state 소스에 pet_id/profile 없음)·save/load
  라운드트립·두 경로·`EGG_VARIANT_COUNT==렌더러 count`.
- 🔁 조정: 렌더러 modulate 단언(`draw_texture_rect(egg_texture, rect, false, Color(tint.r...`)을
  **2-레이어 단언**으로 — 받침 draw + 변종 draw가 같은 rect, modulate 없음(Color.WHITE), 텍스처가
  `EGG_VARIANT_PATHS[index]`에서 옴(소스 가드).
- 반증검증: `advance()`에 재롤 주입 → 5단언 FAIL(modulate판에서 확인된 동일 패턴).

---

## 8. felt-QA (남음)
인게임에서 받침 볼에 알 N종이 깨끗이 안착(앞 rim 가림 자연스러운지), 에너지 링이 알 허리 감싸는 합성,
변종별 글로우색, 슬롯 합성 아이콘 가독성, 10초+ (받침 회전요소 없으면 정적).

---

## 9. 터치 파일 (Codex 배선 체크리스트)
- `lingpet_egg_field_renderer.gd` — 받침/변종 const + 로드캐시 + `prewarm()`, 2-레이어 draw,
  modulate 제거, `variant_index` 인자, 변종 글로우.
- `lingpet_egg_runtime.gd` — 두 호출부 인덱스 전달(기존 유지), `prewarm()` 연결.
- `lingpet_catalog.gd` — 펫 egg/crack 경로 정리, `DEFAULT_PREWARM_KEYS`에서 egg 키 제거.
- `active_item_catalog.gd` — 아이콘 경로 합성본으로(시안 color 유지).
- `lingpet_egg_field_state.gd` — (선택) `egg_color_index`→`egg_variant_index` 리네임, 상한
  `EGG_VARIANT_COUNT`.
- save/load 3파일 — 키 유지(또는 리네임 동기).
- 신규 에셋: 받침 1 + 알 N + 아이콘 1 (+ .import).
- `lingpet_egg_runtime_smoke.gd` — §7 조정.
