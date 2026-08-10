# severe-LOD 비주얼 손상 복구 — 슬라이스 플랜 (SSOT, rev2)

> **상태 2026-07-06: PARKED(보류).** Slice 0 트리아지(`docs/severe_lod_triage.md`) 결과
> 되돌릴 가치 큰 명백한 손상이 사실상 없음(감사 HIGH 16 대다수 DEAD/SEALED). 사용자
> 결정=복구 파킹. 이 SSOT는 **재개 시 절차 참조용**으로 보존. 재개 조건=플레이 중 특정
> 요소가 실제로 거슬려 사용자가 그 항목을 지목할 때. 파일럿 후보=stage3 멘헤라 오라 링
> (미착수). 대쉬토큰 이중드로우는 별건(`docs/dash_token_single_boost_double_draw_bug.md`).

작성 2026-07-06 (Claude). rev2 = Codex 리뷰(라이브 경로/봉인 충돌/op-list 패리티/
타깃값/캐시 API/바람 예외) 반영. 이 문서가 단일 진실이며 **repo-self-contained**
(감사 근거·백업값은 §9 부록에 인라인). 분업: Claude=이 SSOT + 씰 백본 + 적대리뷰,
Codex=GDScript 배선. 런타임 통합 세부 최종권위=`AGENTS.md`.

---

## 0. 배경 / 근본 원인

- 출고 기본 72fps 캡 → `BattleRenderQuality.effect_scale`=0.58 → `_is_lod_active`
  (<0.85)·`_is_severe_lod_active`(<0.66) **둘 다 상시 발동**. 최적화가 severe를
  "희귀 폴백"으로 가정하고 깎은 값이 실제 일상 화면이 됨.
- **이미 raw-restore로 수정한 3건(미커밋, 범위 밖)**: `scoreboard_overlay_renderer`
  (승리 조명), `stage3_playfield_renderer`(쿠로미+혀), `stage2_playfield_renderer`
  (악어) + `stage2_center_playfield_draw_smoke` 봉인 갱신. **이 3건은 사용자가
  인게임에서 직접 목격·신고한 실손상 = 라이브 확정.**
- **감사(HIGH 16 + MED 20)는 코드 대조만 했고 라이브 경로/봉인 의도를 검증하지
  않았다.** Codex 리뷰가 실증한 두 반례:
  - **죽은 경로**: stage1 중앙 원 procedural(`_draw_stadium_guide_marks`)은
    `stage1_center_background_texture` PNG(실존, `_get_core_texture_specs`)가 로드되면
    `draw()`(:137)에서 통째로 스킵됨 → 출고 화면에 안 나옴. "테스트 GREEN·화면 불변".
  - **봉인된 의도적 캡**: `stage1_actor_render_budget_smoke:199`가
    `STADIUM_GUIDE_ARC_SEGMENTS<=28`을 "coarse 유지"로, `weather_event_render_budget_smoke`
    (:119)가 바람 near-full·rain stride3을 의도적으로 봉인. 이건 실수 과절단이 아니라
    설계된 72fps 예산.

**결론**: 감사 목록은 **후보**일 뿐. 복구 착수 전 각 항목을 아래 트리아지 게이트로
분류해 **class 3/4(진짜 라이브 손상)만** 작업한다.

---

## 0.5 트리아지 게이트 (Slice 0, 필수 선행 — 이걸 통과 못 하면 배선 금지)

각 감사 후보에 대해 순서대로:

1. **라이브 경로 검증**: 문제의 procedural 드로우가 실제로 화면에 도달하는가?
   - imagegen-PNG-우선 분기에 스킵되지 않는가? (`context.get("*_texture")` /
     `has_imagegen_base` 게이트 → PNG가 디스크에 실존하면 procedural은 죽은 경로.
     stage1_playfield의 `draw()`는 background PNG 있으면 `_draw_actual_*` 스킵;
     단 같은 파일이라도 `_draw_stadium_electric_flow`/`_draw_grid_particles`/
     `_draw_stage1_wall_contact_flash`는 메인 `draw()`라 **살아있음** — 함수별로 갈림.)
   - 비활성 플래그/디버그 게이트 뒤가 아닌가?
   - **판정법**: 그 렌더러의 상위 `draw()` 호출 트리를 따라가 PNG-skip/flag-skip을
     확인. 애매하면 라이브 인스턴스에서 해당 요소가 실제로 보이는지 픽셀 확인.
2. **봉인 의도 검증**: 그 (감소된) 값을 **명시적으로 봉인**하는 기존 budget smoke가
   있는가? (`grep -rl <CONST> godot/tests`) 있으면 그 감소는 **설계된 최적화**이지
   실수 손상이 아님 → 자동 복구 대상 아님. 복구하려면 "이게 실제로 시각 문제인가"를
   먼저 확인(사용자/디자인 사인오프). 봉인 문구가 회귀방지 근거를 달고 있으면
   (예: "stride flickers the sparse wind flow") 특히 존중.
3. **분류 결과 기록** (repo 파일 `docs/severe_lod_triage.md`에 표로):
   - **class 1 DEAD** — PNG/flag에 스킵. 드롭(또는 PNG 자체 교체는 별건).
   - **class 2 SEALED** — 봉인된 의도적 캡. 사인오프 전 보류.
   - **class 3 FACET** — 라이브 procedural 형상이 각짐, 보호 봉인 없음 → **복구 대상**.
   - **class 4 MISSING** — 라이브인데 요소가 72fps서 통째 스킵/0 → **복구 대상**.

**이미 알려진 재분류 (Codex 실증):**
- A1 stage1 중앙 원 → **class 1 DEAD** (center PNG에 스킵). 파일럿에서 제외.
- A12 stage1 바닥 디테일(`FLOOR_*`) → **class 1 DEAD** (같은 `_draw_actual_*` 안).
- B1 날씨 rain/fire 필드 캡 → **class 2 SEALED** (weather budget smoke가 의도 봉인).
  바람은 이미 near-full. → 사인오프 전 보류. "전 필드 GPUParticles 이관"은 이 봉인을
  덮으므로 **금지**; 정말 시각 문제면 개별 재봉인 후 진행.
- stage1 grid 입자(`GRID_PARTICLE_COUNT_SEVERE_LOD 0`) → 메인 `draw()`라 **라이브**,
  class 4 후보(봉인 여부 확인).

**class 3/4 확정 목록이 이 게이트의 산출물이고, 그게 나오기 전엔 어떤 A~D 배선도
시작하지 않는다.**

---

## 1. 목표 (수용 기준, class 3/4 확정분에 한해)

원본 화질 복귀 + 72fps 프레임 예산 악화 없음. 부류별:
- **A**(정적 형상/링/크롬): bake-once로 풀 화질 + 비용 출고본 이하(순이익, 위험0).
- **B**(이동 파티클 필드): 봉인 아닌 것만. GPUParticles2D 또는 프로파일 CPU. felt-gate.
- **C**(전체화면 오라/글로우): 형상 bake+modulate 또는 셰이더. felt-gate.
- **D**(진짜 애니 형상): 직접 카운트 복구(저렴). 위험0.

---

## 2. 안전 근거 (실측, 2026-07-06 헤드리스 벤치, µs/frame CPU 드로우커맨드)

| 시나리오 | 나이브 풀벡터 | 출고 삭감 | bake-once blit |
|---|---|---|---|
| 중앙 원 3중아크@64 | 37.3 | 6.8 | **0.47** |
| 게이지오브 글로우 스택 | 13.8 | — | **0.40** |
| 날씨 필드 120 입자 | 84.0 | 6.8 | (베이크 불가→GPU) |

- A 부류: bake-once가 풀 화질이면서 출고 삭감본보다 빠름 → 순이익·위험0.
- 한계: 헤드리스는 CPU만. GPU 오버드로우는 못 잼 → B·C는 전시 노트북 felt-gate.

---

## 3. 절대 금지 (트랩)

- **전역 LOD 레버 상향 금지** (`effect_scale`/`FPS_CAP_EFFECT_SCALE`0.58/
  `SEVERE_LOD_ACTIVE_THRESHOLD`0.66). 72fps 예산 압박이 도입 근거라 광범위 드랍
  재유발. 복구는 개별 렌더러에서만.
- **핫패스 lazy-init 금지** — 베이크/파티클/셰이더는 로딩 프리웜 스텝에서만 생성.
- **봉인된 캡 무단 상향 금지** — §0.5 게이트 class 2는 사인오프 전 보류.
- **draw_polygon 픽셀 rect UV 금지** — bake blit은 `draw_texture_rect` 사용.
- **미생성 예약 에셋 per-frame re-stat 금지**.

---

## 4. A 부류 배선 규칙 — op-list 이원 지오메트리 (Codex #3 반영)

즉시 드로우 본문은 **LOD-aware**(severe서 8세그)라, "op-list가 즉시 본문과 1:1이면서
풀 세그"는 자기모순. **두 지오메트리를 분리**한다:

- **RESTORE 지오메트리 (캐시 베이크용)**: 풀 세그먼트(§9 부록의 목표값). 이걸
  `_build_restore_ops()`가 산출 → 캐시에 굽는다. **화면의 진실.**
- **FALLBACK 지오메트리 (텍스처 미준비 시 즉시 경로)**: 기존 LOD-aware 본문 그대로.
  베이크 완료 전 몇 프레임만 보임. 여기선 severe 캡 유지(비용 낮게).

레퍼런스 소비 패턴 = `pillar_orb_chrome_drawer.draw_pillar_orb_glass`(:109) +
`_build_glass_ops`(:160) + `prewarm_static_layers_step`(:142). 단 그 파일은 즉시본문과
op가 동일(비-LOD)했으므로, 새 A 항목은 위 이원 분리를 적용하고 **RESTORE op만 풀 세그**.

**budget smoke 재정의 (Codex #2)**: 기존 `*_render_budget_smoke`가 `CONST <= N`으로
봉인한 상수는 **FALLBACK 경로 상수**로 남겨 그대로 통과시키고, **RESTORE 경로는 별도
상수/함수**(`*_RESTORE_SEGMENTS` 등)로 두어 "bake는 full, fallback은 cap"을 각각 씰한다.
기존 smoke의 `<= N`을 깨지 말 것 — RESTORE는 새 assert로 추가.

### 캐시 API 확장 요구 (Codex #5)

`PillarOrbStaticLayerCache`는 `MAX_CACHE_ENTRIES=24` 초과 시 전체 clear이고
`draw_centered`에 modulate/rotation/scale 인자가 없다. 알파 맥동·회전·스케일 blit이
필요한 항목(게이지오브 글로우 맥동, dalji 회전, 차원문 회전, 나비 스케일)은 먼저:
- `draw_centered_modulated(canvas, tex, center, modulate, rotation_rad, scale)` 헬퍼 추가
  (내부 `draw_set_transform` + `draw_texture_rect`, 회전 후 IDENTITY 복원 —
  `feedback_godot_draw_set_transform_trap`).
- 동시 상주 키가 24 초과할 수 있으면 `MAX_CACHE_ENTRIES` 상향 또는 LRU로 바꾸고
  **캐시-키 예산 smoke**로 "한 프레임 상주 키 <= capacity" 씰.
- 이 확장은 A 확산의 선행 슬라이스(Slice A0-infra).

---

## 5. 백본 후보 표 (트리아지 통과 시에만 배선; class는 게이트 산출물)

접근만 지시. 파일:라인은 §9 부록·감사 기준, 편집 전 재확인.

### A — bake-once (class 3 확정분)
| # | 후보 | 접근 | 트리아지 주의 |
|---|---|---|---|
| A2 | `hud/pillar_gauge_orb_renderer.gd` 글로우 스택+아이들 링 (`static_hud_lod` 게이트) | bake 글로우+링, 맥동=modulate blit | 라이브 유력(글로우 procedural), 보호봉인 확인. **파일럿 1순위 후보.** |
| A3 | `hud/smasher_skill_orb_cooldown_renderer.gd` backing 링/글로우 | 정적 backing=bake, 진행 파이=풀세그 벡터 | 라이브(항상 procedural). |
| A4 | `hud/scoreboard_top_mini_normal_chrome_renderer.gd` 크롬 글로우/밴드 | bake 크롬 | 봉인 확인. |
| A5 | `stages/stage1/stage1_pillar_chrome_renderer.gd:5` 테두리 샤인 | bake(해상도별) | 라이브 확인(border PNG 별도). |
| A6 | `stages/stage1/stage1_dalji_spinning_top_renderer.gd` 몸체/글로우 | bake+회전 blit; 채찍은 **D1** | dalji 라이브 확인. |
| A7 | `hud/stage1_pillar_ui_renderer.gd:20-25` 센서 오브 프레임 | 정적 프레임 bake, 진행 아크 풀세그 | 라이브(HUD). |
| A8 | `items/active_item_field_renderer.gd:350` 차원문 7링 | bake 링스택+회전 blit | 액티브 사용시만. |
| A11 | `characters/laurel_leaf_shield_state.gd:249` 잎+글로우 | bake 잎 텍스처(타입4) | 라이브(스킬). |

### B — GPUParticles/CPU (class 4 & 非봉인만)
| # | 후보 | 접근 | 트리아지 주의 |
|---|---|---|---|
| B4 | `stages/stage3/stage3_pillar_background.gd:13` 떠다니는 하트(28→6) | CPU 캡 복구 또는 GPUParticles | 봉인 확인. |
| B6a | `stages/stage1/stage1_playfield_renderer.gd:33` grid 입자(severe 0) | severe 캡 복구 | **라이브(메인 draw)**, 봉인 확인. |
| B6b | `stage1_pillar_petal_renderer.gd:9` 꽃잎 세그3+stride | 스프라이트 bake blit로 승격 권장 | 봉인 확인. |
| ~~B1~~ | ~~날씨 rain/fire 필드~~ | **class 2 SEALED — 보류** (§0.5) | 바람 near-full 봉인 존중. |

### C — bake+modulate/셰이더 (felt-gate)
| # | 후보 | 접근 |
|---|---|---|
| C1 | `ball/ball_status_overlay_renderer.gd:102` 화염공 후광 | 방사 그라디언트 bake → 공 위치 blit+맥동 |
| C3 | `stages/stage3/stage3_menhera_boss_actor_renderer.gd:333-335/304-306` 오라/잔상 | 오라 링=bake+modulate, 잔상=스프라이트 blit 카운트 |

### D — 직접 복구 (저렴, 위험0)
| # | 후보 |
|---|---|
| D1 | `stage1_dalji_spinning_top_renderer.gd:9` 채찍 `WHIP_SEGMENTS 10` (감사 3→10) |
| D2 | `stage1_playfield_renderer.gd` `_draw_stadium_electric_flow` (메인 draw=라이브; 단 봉인 `STADIUM_SPARK_*` 확인) |
| D3 | `hud/pillar_liquid_drawer.gd:19-20` 대쉬 섹터 세그 |
| D4 | `items/active_item_effect_renderer.gd` 홀리배리어 룬/마그넷 링 |
| D5 | `ball/ball_status_overlay_renderer.gd:148` 라그나로크 볼트/orbit |

---

## 6. 스모크 씰 (Claude 백본)

- **RESTORE op-list 패리티**: `_build_restore_ops()`가 풀 세그(부록값)를 쓰는지 상수/구조
  검증. FALLBACK 상수의 기존 `<= N` 봉인은 유지.
- **프리웜-스텝 존재**: bake 소유 렌더러가 `prewarm_*_step()` 노출 + 프리웜 체인 연결
  (핫패스 lazy-init 방지). `_draw` 내 최초 `request_build`가 즉시-폴백 갖는지 grep.
- **캐시 용량 예산**(A0-infra 후): 한 프레임 상주 키 <= capacity.
- **B/C felt-gate**: 헤드리스 불가 → BattlePerf 라벨(`stage*.playfield.*`,`weather.*`)
  로 전시 노트북 실측. 스모크는 GPUParticles amount·좌표 bake식·ADD 배선만 정적 검증.
- **반증검증 필수 (SAFE, in-place Edit 토글만)**: 각 복구 스모크가 깎인/미배선 코드에서
  FAIL함을 in-place로 증명. **git reset/checkout/stash 금지**(WIP 파괴,
  [Agent Operating Posture §1](agent_operating_posture.md#1-기본-적용할-작업자세-12)).

---

## 7. 트랩 레지스터

- Hot-Path Lazy Init / draw_polygon UV 정규화 / FX host 좌표 bake
  (`game_offset+pos*render_scale`, 자식 미상속) / negative-z 조상 fill / draw_set_transform
  연속회전 텀블 / 미생성 예약에셋 re-stat. 상세=CLAUDE.md 트랩 인덱스 +
  `docs/godot_runtime_traps.md`.

---

## 8. 시퀀싱

1. **Slice 0 (트리아지)** — §0.5 게이트로 36 후보 분류 → `docs/severe_lod_triage.md`
   class 3/4 확정 목록. **모든 배선의 선행.**
2. **Slice A0-infra** — 캐시 modulate/rotation/scale 헬퍼 + 용량 정책 + 예산 smoke.
3. **파일럿 = class 3/4 확정 & 非봉인 & 라이브 중 최소위험** (현 유력: A2 게이지오브
   글로우 — 항상 procedural, 순수 정적 형상, bake+modulate). A1(중앙원)은 DEAD라 파일럿 불가.
4. A 확산 → D(병행 가능) → C1(화염공, felt) → B(비봉인분만, felt).

각 슬라이스: 백본(씰) → Codex 배선 → 반증검증 → Claude 적대리뷰 → 픽셀/felt QA →
커밋. A·D 위험0 빠르게, B·C felt 통과 전 커밋 보류.

---

## 9. 부록 — repo-local 증거 (Codex #4: Claude memory 밖 참조 제거)

**메커니즘**: `battle_render_quality.gd` `effect_scale`가 72fps 캡에서
`ViperAirborneLod.FPS_CAP_EFFECT_SCALE=0.58` 반환. `_is_lod_active`(<0.85)·
`_is_severe_lod_active`(<0.66) 모두 참 → 각 렌더러의 `*_SEVERE_LOD` 상수 및
severe 분기가 라이브 기본값.

**백업 원본값 (참조: `d:\고도백업본\260512\godot`, LOD 시스템 없음=전부 풀카운트)** —
목표값이 아니라 **상한 참고**. 현재 소스의 "full" 상수가 이미 백업보다 낮은 경우
(예: stage1 `STADIUM_GUIDE_ARC_SEGMENTS` 현재 28 vs 백업 64; `FLOOR_SPECK_COUNT`
현재 160 vs 백업 220) RESTORE 목표는 **디자인이 정한 풀값**(백업값 또는 그 사이)으로
명시하고, 기존 FALLBACK 봉인은 건드리지 않는다.

주요 후보의 (감사 관측: 현재 라이브값 → 백업값):
- stage1 중앙원 arc: severe 8 → 백업 64 ×3. **[DEAD]**
- stage1 floor speck/moss/crack: severe 12/4/2 → 백업 220/48/6. **[DEAD]**
- stage1 grid 입자: severe 0 → 백업 14. [라이브, class4 후보]
- gauge orb 글로우: static_hud_lod서 레이어 0/게이트 → 원본 3레이어+코어+아이들링.
- cooldown ring/sector: 14/14 → 원본 28/24.
- 차원문 링: 3/arc14 → 원본 7/arc72.
- dalji 몸체/글로우: 3/4 → 원본 10/14. 채찍 severe 3 → 10.
- 화염공 후광: 반경 곱셈(~0.46~1.30) → 원본 가산(+5~+21).
- 멘헤라 오라: 바깥 40→18, 안쪽 스킵 → 원본 40+36. 잔상 severe1 → 원본 full.
- 날씨: rain/fire severe limit 24/18 + stride3 → 백업 무캡. **[SEALED — weather budget
  smoke가 의도 봉인, 바람 near-full]**

전체 36 후보 파일:라인은 감사 세션 산출물(6개 영역 에이전트)에서 이관; Slice 0
트리아지 표(`docs/severe_lod_triage.md`)가 최종 작업 목록이 된다.
