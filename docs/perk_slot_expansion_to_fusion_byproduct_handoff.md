# 코덱스 핸드오프 — 광맥결 삭제 + 슬롯 확장의 융합 부산물 이전

발주: 2026-08-01. 결정(사용자 확정): **`common_expansion`(광맥결)을 삭제**하고,
그 옵션(무공 최대 슬롯 +1)을 **무공 합일(퍽 융합) 부산물**로 이전한다.
⚠️ **이 결정은 `docs/perk_slot_expansion_handoff.md`(2026-07-08, 광맥결 신설)를
대체**한다. 그 문서의 "확장 퍽으로 최대 10" 설계는 폐기.
Claude 기획 → Codex 배선 → Claude 적대 리뷰 → 통과 시 자동커밋.

---

## 0. 사전 고지 (기획 시 사용자에게 보고된 트레이드오프)

착수 전 아래 3개는 **의도된 결과**임을 확인하고 진행한다. 리뷰에서
"버그 아니냐"로 재점화되지 않도록 여기 박아둔다.

1. **슬롯 상한 10 → 7.** 부산물은 전역 중복 제외(`get_contextual_pool`)라
   런당 1회만 획득 가능하다. 기본 6 + 부산물 1 = **7이 새 상한**.
2. **슬롯 성장이 확정 투자에서 확률 보상으로 바뀐다.** 획득 확률은 융합
   확정 1회당 **약 5.6%**(§3에 산출). 대부분의 런은 6슬롯으로 끝난다.
3. **"가득 막힘 탈출 밸브"가 사라진다.** 광맥결은 슬롯 비소모라 가득
   상태에서도 오퍼에 등장하는 유일한 탈출구였다. 삭제 후 슬롯 가득 =
   신규 퍽 차단(보유 업그레이드 예약은 그대로 작동, 소프트락 아님).
   융합의 2→1 환급이 유일한 슬롯 해방 수단이 된다.

---

## 1. 설계 (확정)

### D1. 슬롯 한도
- `BASE_PERK_SLOT_LIMIT := 6` 유지, `MAX_PERK_SLOT_LIMIT := 10 → **7**`.
- `get_perk_slot_limit()`는 더 이상 `common_expansion` 레벨을 읽지 않고,
  **보유 부산물**을 읽는다.

### D2. 신규 부산물
| 항목 | 값 |
|---|---|
| id | `meridian_expand` |
| 한국어명 | **기맥 확장** |
| detail(ko) | `이번 런의 무공 최대 슬롯이 1칸 늘어납니다.` |
| 풀 | **general** (rare 아님 — 근거 §3) |
| runtime_enabled | `true` |
| 캡 | 전역 중복 제외로 자연 캡(런당 1회) |

⚠️ **rare 풀 금지.** `_select_byproducts_with_rare_slot`는 rare 슬롯을
`requested_count >= 3`일 때만 배정한다([perk_fusion_result_builder.gd:317](../godot/scripts/characters/perk_fusion_result_builder.gd#L317)).
rare에 넣으면 실획득률이 1.7%까지 떨어져 사실상 미획득 콘텐츠가 된다.

### D3. `common_expansion` 삭제 범위 — **flag ON 경로만**
`common_expansion`은 이중 의미 id다. flag ON = 퍽 슬롯 확장(광맥결),
**flag OFF = 레거시 장신구 슬롯 확장("확장", max_level 2)**
([runtime_perk_catalog.gd:1534-1542](../godot/scripts/characters/runtime_perk_catalog.gd#L1534-L1542)).
프로덕션은 부트에서 항상 flag ON이므로(`PerkConversionFlags.set_enabled`),
**플레이어가 보는 모든 경로에서 제거하는 것 = flag ON 경로 제거**로 충분하다.

- ✅ flag ON: 오퍼 풀·카탈로그 노출·슬롯 한도 기여·유효레벨 분기에서 완전 제거.
- ❌ **flag OFF 레거시 정의(`_resolve_expansion_definition`)는 건드리지 말 것.**
  삭제하면 레거시 장비/장신구 경로와 그 스모크가 같이 깨진다. OFF 레거시
  완전 제거는 **후속 정리 항목**으로 분리한다.

### D4. flag OFF에서 부산물 무효
flag OFF는 한도가 6 고정이라 `meridian_expand`가 아무 일도 못 한다.
→ **OFF에서는 부산물 풀에서 제외**한다(`limit_break`가 대상 없을 때
풀에서 빠지는 선례와 동일 패턴, [perk_fusion_result_builder.gd:352](../godot/scripts/characters/perk_fusion_result_builder.gd#L352)).

### D5. 세이브 마이그레이션
진행 중인 런의 `runtime_skill_levels["common_expansion"]`이 남아 있으면
TAB/ESC 그리드에 **삭제된 퍽이 유령으로 뜬다**(카탈로그 조회는 flag OFF
레거시 정의를 반환하므로 빈 dict가 아니다 — 조용히 "확장 Lv3"으로 렌더됨).
→ 로드 시 flag ON이면 해당 키를 **제거**하는 자가 치유 경로를 둔다.
초과 점유(기존 9칸 보유 → 한도 7)는 허용한다: 신규 퍽만 막히고 보유
퍽·업그레이드는 유지된다.

---

## 2. 배선

### ① 부산물 카탈로그 ([perk_fusion_byproduct_catalog.gd](../godot/scripts/characters/perk_fusion_byproduct_catalog.gd))
- `GENERAL_IDS`에 `"meridian_expand"` 추가(6종).
- `DATA`에 엔트리 추가(§D2 표).
- `get_contextual_pool()` 시그니처에 flag/한도 컨텍스트를 넘겨 **flag OFF일
  때 `meridian_expand` 제외**(D4). `limit_break` 제외 분기 바로 옆에 둔다.

### ② 슬롯 한도 ([runtime_perk_catalog.gd:1618-1625](../godot/scripts/characters/runtime_perk_catalog.gd#L1618-L1625))
```gdscript
func get_perk_slot_limit(runtime_levels: Dictionary, slot_context: Object = null) -> int:
    if not PerkConversionFlags.is_enabled():
        return BASE_PERK_SLOT_LIMIT
    var bonus: int = _resolve_perk_fusion_slot_limit_bonus(slot_context)
    return clampi(BASE_PERK_SLOT_LIMIT + bonus, BASE_PERK_SLOT_LIMIT, MAX_PERK_SLOT_LIMIT)
```
- 보너스 해석은 `_resolve_perk_fusion_slot_reduction`와 **같은 slot_context
  해석 패턴**을 재사용한다(registry면 `get_instance("runtime_perk_state")`,
  state면 직접). [runtime_perk_catalog.gd:1603-1611](../godot/scripts/characters/runtime_perk_catalog.gd#L1603-L1611)
- 소스는 `runtime_perk_state.get_perk_fusion_owned_byproduct_ids()`
  ([runtime_perk_state.gd:265](../godot/scripts/characters/runtime_perk_state.gd#L265)).
- `MAX_PERK_SLOT_LIMIT := 7`.

⚠️ **최대 트랩 — slot_context 전파 누락.** 현재 `get_perk_slot_limit`은
**인자가 `runtime_levels` 하나뿐**이라 호출부가 slot_context를 안 넘긴다.
파라미터만 추가하고 호출부를 안 고치면 **부산물이 조용히 무시되고 항상 6**이
된다(기본값 `null` = 보너스 0). 전 호출부 전수 갱신 필수:
- [runtime_perk_catalog.gd:1615](../godot/scripts/characters/runtime_perk_catalog.gd#L1615) `has_open_perk_slot` → slot_context 전달
- [runtime_perk_catalog.gd:1630](../godot/scripts/characters/runtime_perk_catalog.gd#L1630) `get_perk_slot_status` → slot_context 전달
- [runtime_perk_catalog.gd:1953](../godot/scripts/characters/runtime_perk_catalog.gd#L1953) `_filter_perk_slot_budget` → `_registry` 전달
- 외부: [character_info_overlay_core.gd:649](../godot/scripts/hud/character_info_overlay_core.gd#L649),
  [runtime_perk_overlay_renderer.gd:1299](../godot/scripts/hud/runtime_perk_overlay_renderer.gd#L1299),
  [runtime_perk_choice_offer_modifiers.gd:47](../godot/scripts/characters/runtime_perk_choice_offer_modifiers.gd#L47),
  [mythic_perk_grant_helper.gd:390](../godot/scripts/characters/mythic_perk_grant_helper.gd#L390)
  — 이들은 이미 registry/runtime_state를 넘기고 있으므로 status/open 경유면 자동.
- grep 0건 확인: `get_perk_slot_limit(` 호출 중 slot_context 없는 것(스모크 제외).

### ③ 광맥결 제거 (flag ON 경로)
- [runtime_perk_catalog.gd:218-230](../godot/scripts/characters/runtime_perk_catalog.gd#L218-L230)
  `COMMON_PERKS["common_expansion"]` 엔트리: **flag ON 오퍼에 나오지 않게**
  한다. 엔트리 자체를 지우면 `_resolve_expansion_definition`(OFF 레거시)이
  기반 dict를 잃으므로, **엔트리는 남기고 flag ON 후보 생성에서 제외**하는
  방식을 택한다(`_append_pool_choices` 단계에서 flag ON일 때 스킵).
  → 조회(`get_perk_data`)는 OFF 정의를 계속 반환, ON에서는 획득 불가.
- [runtime_perk_catalog.gd:1562](../godot/scripts/characters/runtime_perk_catalog.gd#L1562)
  `is_slot_consuming_perk`의 flag ON 비소모 예외 **제거**(밸브 폐지).
- [runtime_perk_catalog.gd:16](../godot/scripts/characters/runtime_perk_catalog.gd#L16)
  `SLOT_EXPANSION_PERK_ID` 상수는 OFF 레거시 분기가 계속 쓰므로 유지.
- [runtime_perk_effective_levels.gd:160](../godot/scripts/characters/runtime_perk_effective_levels.gd#L160)
  (유효레벨 보너스 제외), [:271](../godot/scripts/characters/runtime_perk_effective_levels.gd#L271)
  (`base_bonus = 0.0 if flag ON`), [:581](../godot/scripts/characters/runtime_perk_effective_levels.gd#L581)
  (`get_accessory_slot_bonus`) — **전부 현행 유지**. flag ON에서 이미 0/제외라
  광맥결이 사라져도 동작이 같다. 건드리면 OFF 레거시가 깨진다.

### ④ 부산물 효과 소비
`meridian_expand`는 **런타임 틱이 없다**(순수 한도 보너스).
[perk_fusion_byproduct_runtime.gd](../godot/scripts/characters/perk_fusion_byproduct_runtime.gd)에
상태 추가 금지 — ②의 한도 조회가 유일한 소비자다.

### ⑤ 다국어 (7개 언어 — 문구수정=다국어 동기화 규칙)
- 한국어/영어: [perk_fusion_localization.gd](../godot/scripts/characters/perk_fusion_localization.gd)의
  `BYPRODUCT_KO` / `BYPRODUCT_EN` + `BYPRODUCT_DETAIL_KO` / `BYPRODUCT_DETAIL_EN`.
- zh / ja / es / pt-BR / ru: [perk_fusion_localization_data.gd:346-367](../godot/scripts/characters/perk_fusion_localization_data.gd#L346-L367)
  `BYPRODUCT_NAMES` + [:369~](../godot/scripts/characters/perk_fusion_localization_data.gd#L369) `BYPRODUCT_DETAILS`.
- ⚠️ **5개 맵 + 2개 맵 = 총 7곳.** 한국어만 grep해서 "미현지화" 판정 금지
  (기존 오판 사례 있음).

### ⑥ 세이브 자가 치유 (D5)
런타임 퍽 로드 경로에서 flag ON이면 `runtime_skill_levels`의
`common_expansion` 키 제거. 융합 레코드 로드 자가 치유(없는 id면 레코드
해체)와 같은 계층에 둔다.

### ⑦ 에셋
`common_expansion_perk_icon*.png` / manifest / `common_mugong_collection_manifest.json`
엔트리는 **OFF 레거시가 아직 참조**하므로 삭제하지 않는다. 부산물은 전용
아이콘 체계가 없으므로(텍스트 로그·툴팁 레인) **신규 이미지 작업 없음**.

---

## 3. 확률 산출 (밸런스 근거 — 다이얼 남김)

`requested_count = mini(3, 1 + floor(count_roll * 3))` → 1/2/3이 각 1/3.
general 풀 6종(신규 포함) 기준, 슬롯이 뽑힐 확률:

| count | general 슬롯 수 | 포함 확률 |
|---|---|---|
| 1 | 1 | 1/6 ≈ 16.7% |
| 2 | 2 | 1 − (5/6)(4/5) = 33.3% |
| 3 | 2 (+rare 1) | 33.3% |

평균 ≈ 27.8%. **부산물 분기 20% × 27.8% ≈ 5.6% / 융합 확정 1회.**
(다른 부산물을 이미 보유하면 dedup로 풀이 줄어 후반부일수록 상승.)

너무 낮다고 판단되면 다이얼 2개: (a) `BASE_BYPRODUCT_PERCENT` 20 상향,
(b) `meridian_expand`에 별도 가중치 부여. **(b)는 현재 균등 추첨 구조를
깨므로 (a) 우선.** 이번 슬라이스에서는 둘 다 건드리지 않는다.

---

## 4. 스모크 (개정 대상 + 신규 레그)

기존 [perk_slot_limit_smoke.gd](../godot/tests/perk_slot_limit_smoke.gd)가
`common_expansion` 픽스처로 한도 7/8/10을 단언하고 있으므로 **전면 개정**이다
(:293-296, :305-306, :362-363, :508).

- [ ] 부산물 미보유 → 한도 6, 6개 보유 시 가득(신규 차단·보유 업글 예약 작동)
- [ ] `meridian_expand` 보유 → 한도 **7**, 6개 보유가 가득 아님, 7개째 획득 가능
- [ ] 한도 클램프: 보너스가 어떤 이유로 2 이상이어도 7 초과 불가
- [ ] **slot_context 전파 씰**: `get_perk_slot_status(levels, registry)`와
      `(levels, state)` 두 컨텍스트 모두 한도 7을 반환(하나만 되면 반쪽 랜딩)
- [ ] flag ON에서 `common_expansion`이 **오퍼 후보에 등장하지 않음**
- [ ] flag ON에서 광맥결 레벨이 있어도 **한도가 오르지 않음**(구 경로 사망 확인)
- [ ] flag OFF: 한도 6 고정 + `meridian_expand`가 부산물 풀에서 제외됨
- [ ] 부산물 중복 제외: 보유 후 재융합 시 풀에서 빠짐(기존 dedup 회귀 없음)
- [ ] 세이브 로드 자가 치유: `common_expansion` 키가 flag ON 로드에서 제거됨
- [ ] 다국어: 7개 로케일 전부 `meridian_expand` 이름·detail이 id 폴백이 아님
- [ ] 결과 리빌/툴팁 렌더: 부산물 3개 최악 픽스처에 신규 항목 포함해도 클립 없음

기존 씰 중 `common_expansion`을 픽스처로 쓰는 것들 동반 점검:
`perk_offer_owned_upgrade_priority_smoke`, `perk_status_panel_render_capture_smoke`,
`perk_status_owned_tooltip_smoke`, `runtime_perk_effective_stat_queries_smoke`,
`runtime_perk_owner_effect_sync_smoke`, `perk_polish_amplify_smoke`,
`sage_ring_port_smoke`, `transcendent_crown_port_smoke`,
`common_mugong_*_rebrand_smoke`, `character_info_mugong_round_slot_visual_qa`.

---

## 5. 반증검증 (필수 — `git reset`/`checkout`/`stash` 금지, in-place 토글 + 즉시 복원)

1. `_resolve_perk_fusion_slot_limit_bonus`를 `return 0` 고정 → "부산물 보유 시
   한도 7" 레그 RED → 복원.
2. `get_perk_slot_status`의 slot_context 전달을 한 곳만 제거 → **slot_context
   전파 씰** RED → 복원. (이걸 안 하면 반쪽 랜딩이 GREEN으로 통과한다.)
3. flag OFF 제외 분기 임시 해제 → "OFF에서 풀 제외" 레그 RED → 복원.

---

## 6. 트랩 노트

- **slot_context 전파(②)가 이 슬라이스의 유일한 고위험 지점**이다. 기본값
  `null` 때문에 미전달이 **에러 없이 "보너스 0"**으로 흡수된다 — Godot
  반쪽-랜딩 슬라이스 트랩 + owner-field 스키마 트랩과 같은 실패 계열.
- **유령 퍽(D5)**: 카탈로그가 OFF 레거시 정의를 반환하므로 삭제된 퍽이 빈
  dict가 아니라 "확장 Lv3"으로 **정상 렌더된다**. 마이그레이션 없으면
  세이브 로드 QA에서만 잡힌다.
- **다국어 7곳**(⑤) — 한국어 grep 0건으로 단정 금지.
- 하드코딩 "/10", "최대 10", "슬롯 10" UI·문구 grep(7개 언어 포함).
- `docs/perk_slot_expansion_handoff.md` 상단에 대체 결정 1줄 주석(문서 정합).
- 핫패스 아님(오퍼/그랜트/HUD 조회 시점). UTF-8 BOM 금지, `.agents/skills/`
  미러 금지.

---

## 7. 완료 보고 형식

(1) 부산물 신설 + 풀/OFF 제외, (2) 한도 함수 재배선 + **slot_context 전파
grep 0건 증빙**, (3) 광맥결 flag ON 제거(오퍼 미등장 증빙), (4) 세이브 자가
치유, (5) 다국어 7곳, (6) 개정 스모크 결과 원문, (7) 반증검증 3건 RED→GREEN,
(8) 이탈/가정.
