# severe-LOD 손상 후보 트리아지 (Slice 0 산출물)

> **결정 2026-07-06 (사용자): LOD 복구 PARKED(보류).** 트리아지로 큰 후보(A1 DEAD,
> A2 등 SEALED)가 빠지고 남은 class 3/4는 사용자가 목격 신고한 표면이 아니라,
> 프레임드랍 방지 원칙 대비 시각 이득이 작음. **이 문서는 기록으로 보존**하고, 실제
> 플레이 중 특정 요소가 눈에 밟힐 때만 §7 목록에서 그 항목만 꺼내 배선한다.
> 부수 결정: (1) 그리드 입자 = **봉인 유지**(`<=1`을 `>=1` 하한으로 뒤집는 건 디자인
> 변경, 명확한 시각 요구 전엔 보류). (2) 단일 대쉬토큰 부스트 이중드로우 = **별건 버그로
> 분리**(`docs/dash_token_single_boost_double_draw_bug.md`), LOD 복구 흐름과 미섞음.
> (3) 멘헤라 오라 링 = **승인된 파일럿 후보로만 보관**(미착수).

작성 2026-07-06 (Claude, 6영역 병렬 트리아지 컴파일). SSOT=
`docs/severe_lod_visual_restore_slice_plan.md`. 이 표가 복구 착수 전 **확정 작업 목록**.
class 3(FACET)/4(MISSING) + 라이브 + 비봉인만 배선 대상.

## 판정 기준
- **DEAD** — imagegen-PNG-우선/flag 분기에 스킵되어 출고 화면 미도달.
- **SEALED** — 기존 budget/threshold smoke가 감소값을 의도적으로 봉인(`<=N` 또는
  "severe active @0.58" 또는 anti-collapse 하한). 복구=봉인 파기 → 사인오프 필요.
- **FACET** — 라이브지만 감소가 좁은 스코프/부분봉인. 감사가 함의한 "전 플레이어
  손상"이 아님.
- **MISSING** — 라이브 + 감소값에 봉인 없음 → 진짜 복구 후보(+ 새 씰 필요).

## 총계 (~61 후보행)
**DEAD 3 · SEALED 43 · FACET 7 · MISSING 8 · CLEAN 1.**
→ 감사가 HIGH 16으로 부풀린 것 중 대다수가 **봉인된 의도적 최적화 또는 죽은 경로**였음.
사용자가 실제 신고·수정한 3건(스코어보드/스테3/스테2 playfield)은 이 표 밖(라이브 확정).

---

## 1. stage1 — DEAD 2 / SEALED 9 / FACET 0 / MISSING 0 (작업 대상 0)

| candidate | live_path_evidence | dead/skip_evidence | seal_evidence | class | allowed_action | required_smoke | notes |
|---|---|---|---|---|---|---|---|
| 중앙 코트 원 `STADIUM_GUIDE_ARC_SEGMENTS` | `_draw_stadium_guide_marks:389` | `stage1_playfield_renderer.gd:136-140` else-branch, center PNG(`battle_resources.gd:841`, 실존 136KB) | `stage1_actor_render_budget_smoke.gd:199-201` | **1 DEAD** | drop | (option: center PNG file_exists assert) | PNG 있으면 procedural 원 미도달 |
| 바닥 speck/moss/crack | `_draw_actual_*:183-213` | 동 center PNG 뒤 | speck `:181-186`, crack none | **1 DEAD** | drop | — | 죽은 경로 |
| 그리드 입자 severe=0 | 메인 `draw():146` (라이브) | none | `stage1_actor_render_budget_smoke.gd:180` (`<=1` 이 0 허용) | **2 SEALED** | hold-for-signoff | 되살리려면 severe≥1 + `>=1` 하한 씰 | ★에스컬레이션: 파란 상승입자 전멸, 디자인 의도 확인 |
| 스타디움 전기흐름 `STADIUM_SPARK_*` | 메인 `draw():145` | none | `:205-211` | **2 SEALED** | hold-for-signoff | — | 12~25s 간헐 버스트, 봉인 |
| 벽 접촉 플래시 | 메인 `draw():149` | none | `:188-193` | **2 SEALED** | hold-for-signoff | — | transient, 봉인 |
| 황금 테두리 샤인 `GAME_BORDER_SHINE_LAYERS_LOD` | `stage1_pillar_chrome_renderer.gd:35` | none | `:268-269` | **2 SEALED** | hold-for-signoff | — | 2→1 레이어, 봉인 |
| dalji 팽이 body/whip/glow | `stage1_dalji_spinning_top_renderer.gd:75` | none | `stage1_spinning_top_render_budget_smoke.gd:22-25` | **2 SEALED** | hold-for-signoff | — | **바이퍼 전용 LOD** — 4캐릭 풀밀도 |
| 낙엽 꽃잎 `LOD_PETAL_SEGMENTS`/stride | `stage1_pillar_petal_renderer.gd:14/37` | none | `:287` (`<=4`); stride none | **2 SEALED** | hold-for-signoff | stride 손대면 stride 씰 | 형상 봉인, stride 비봉인 |
| 풍선 door/machine/starpoint | `stage1_balloon_event.gd` | none (LOD 변형 자체 없음) | `stage1_balloon_event_render_budget_smoke.gd:31-33` | **2 SEALED** | drop(되돌릴 것 없음) | — | fps 무관 고정밀도 |
| 나비 흡수 링 | `stage1_pillar_background.gd:262` | none | `stage1_butterfly_render_budget_smoke.gd:28-30` | **2 SEALED** | hold-for-signoff | — | 18→10세그, 봉인 |
| 센서 쿨다운 오브 | `stage1_pillar_ui_renderer.gd:433` | none | `stage1_dalji_commando_hud_layout_smoke.gd:520-526` | **2 SEALED** | hold-for-signoff | — | HUD, 봉인 |

## 2. stage2/3 (playfield 제외) — DEAD 0 / SEALED 9 / FACET 3 / MISSING 1 (작업 4)

| candidate | live_path_evidence | dead | seal_evidence | class | allowed_action | required_smoke | notes |
|---|---|---|---|---|---|---|---|
| 멘헤라 ready/오버드라이브 오라 링 | `stage3_menhera_boss_actor_renderer.gd:345/347` | none | **none** | **3 FACET** | **direct-restore**(아크 저렴) | 신규 boss_actor 오라 세그 씰 | ★바깥40→18 + 안쪽 아크 severe OFF(`:346`). 라이브 |
| 멘헤라 지면 그림자 `GROUND_SHADOW_SEGMENTS` | `:329-331` | none | **none**(ball/stage1 그림자는 봉인, 멘헤라 카피는 아님) | **3 FACET** | **direct-restore**(18세그 저렴) | boss_actor 그림자 씰 | ★18→10 타원 각짐 |
| 스테3 하위 앰비언트 폴리지 | `stage3_pillar_background.gd:198/206/210` | none(PNG 363KB 실존→라이브) | **none** | **4 MISSING** | **direct-restore**(2 blit 저렴) | 앰비언트 폴리지 LOD 씰 | ★sprite idx4/7이 `if not _is_lod_active` → 0.58서 OFF |
| 멘헤라 오버드라이브 잔상 | `:310`, severe cap `:315` | none | **none** | **3 FACET** | **hold-for-signoff** | trail-count 씰 + perf | 잔상=풀 sprite blit, 실비용. severe 1개 |
| 스테3 하트/엣지/팝 (3후보) | `stage3_pillar_background.gd` | none | `stage3_map_port_smoke.gd:238-243` | **2 SEALED** | hold | — | 전부 `<=N` 봉인 |
| 스테2 지진파편/충격파/잎/스플래시/낙엽/스타포인트/트레일 (6후보) | `stage2_pillar_background.gd` | none | `stage2_pillar_render_budget_smoke.gd:34-63` | **2 SEALED** | hold | — | 낙엽 severe=0은 "should disable" 명시봉인; 충격파 count는 visual-only-vs-physical 구분(LOD무관) |

## 3. stage4 — DEAD 0 / SEALED 5 / FACET 2 / MISSING 2 (작업 2 + 저우선 2)

| candidate | live_path_evidence | dead | seal_evidence | class | allowed_action | required_smoke | notes |
|---|---|---|---|---|---|---|---|
| 파괴웨이브 코어 동심원 링 `CORE_RING_STEP` | `stage4_playfield_renderer.gd:1021` (이벤트 flag) | none | **none** | **4 MISSING** | **restore** | `CORE_RING_STEP(_LOD) <=` + 행동 leg | ★5→10=6→3링. 유일 비봉인 코어값 |
| 배경 대기 스파크 `BACK_ATMOSPHERE_SPARK_COUNT` | `:307-311` 무조건 | none | **none** | **4 MISSING** | **restore** | spark `<=` + 행동 leg | ★10→5 |
| 골드더스트 halo/반짝임 게이트 | `stage4_bird_event.gd:519/522` | none | count는 `:24-25` 봉인; halo/sparkle 불린게이트 **none** | **3 FACET** | 저우선(α0.16/0.32 sub-perceptual) | (option) 불린게이트 씰 | 코어 원은 여전히 그려짐 |
| 에너지링 레이어수 `RING_LAYER_COUNT` | `:980` | none | arc-points는 `:40-41` 봉인; layer_count **none** | **3 FACET** | 저우선 | `RING_LAYER_COUNT <=` | 4→2, 링 자체는 그려짐 |
| 코어버스트/코어아크/달조각트레일/신규배열캡/낙엽 (5후보) | stage4_playfield/bird | none | `stage4_playfield_render_budget_smoke.gd` + `stage4_bird_event_render_budget_smoke.gd` | **2 SEALED** | none | — | 신규 파티클캡=원래 무캡을 넉넉히 보호 |

## 4. HUD 오브 — DEAD 1 / SEALED 6 / FACET 1 / MISSING 0 (작업 1 + 별건버그 1)

| candidate | live_path_evidence | dead/superseded | seal_evidence | class | allowed_action | required_smoke | notes |
|---|---|---|---|---|---|---|---|
| 게이지 오브 글로우 스위트 | `pillar_gauge_orb_renderer.gd:61/90/102/130` | none(글로우는 라이브) | `stage1_dalji_commando_hud_layout_smoke.gd:476-483` + `pillar_gauge_orb_stability_smoke.gd:50-63` | **2 SEALED** | contract-change-needed | 픽셀QA 선행 | ★원래 HIGH였으나 봉인 계약. static-LOD 장식 트림 문서화됨 |
| 5구슬 쿨다운 파이/링 | `smasher_skill_orb_cooldown_renderer.gd:51-60` | none | `stage1_dalji_commando_hud_layout_smoke.gd:517-518` 상한 + **`:519` 하한(≥14 "not octagonal")** | **2 SEALED** | keep(상한+하한 고정) | — | ★원래 HIGH였으나 anti-collapse 하한까지 봉인 = 더 못깎음 |
| 오브 프레임 크롬(보스 대쉬 오브) | `pillar_orb_chrome_drawer.gd:69` via `pillar_dash_orb_body_renderer.gd:76` (`boss_dash_frame_texture=null`) | 게이지/플레이어는 PNG로 대체(`battle_resources.gd:836-837`) | `stage1_dalji_commando_hud_layout_smoke.gd:487-488` | **3 FACET** | contract-change(보스대쉬만 baked static) | 보스대쉬 procedural-frame 픽셀QA | 한 파일 두 얼굴: PNG-dead vs 보스 라이브 |
| 듀스 불꽃/리퀴드섹터/노멀크롬/대쉬바디 (4후보) | 각 HUD 렌더러 | none | `stage1_dalji_commando_hud_layout_smoke.gd:388-494` | **2 SEALED** | contract-change로만 | — | 전부 봉인 계약 |
| 단일 대쉬토큰 부스트 이중드로우 | `pillar_dash_token_fill_renderer.gd:267` | 멀티토큰은 `:149` host-guard | `:528-535` | **1 DEAD-ish(shader)** | **별건 버그**(LOD무관) | max_tokens==1 + active-host 씰 | CPU 무지개링이 셰이더호스트와 co-draw 가능 |

## 5. ball/items/characters — DEAD 0 / SEALED 6 / FACET 1 / MISSING 3 (작업 3)

| candidate | live_path_evidence + scope | dead | seal_evidence | class | allowed_action | required_smoke | notes |
|---|---|---|---|---|---|---|---|
| 홀리배리어 룬/광선/그라디언트 | `active_item_effect_renderer.gd:446` 무조건 [active-item, all-players] | none | **none**(입자범위 테스트만) | **4 MISSING** | **restore**(단, 베이크 리터럴→named const 추출 선행) | 새 rune/ray/step 예산 씰 | ★룬9→6·광선6→4·grad step2→4 |
| 마그넷 필드 링/라인/아크 | `active_item_effect_renderer.gd:301` 무조건 [active-item] | none | **none**(팔레트 테스트만) | **4 MISSING** | **restore**(named const 추출 선행) | 새 ring/line/arc 씰 | 현재 `range(3)`—감사 "5→4" 재확인 필요 |
| 픽업/오라 폴리시 `PICKUP_GLOW_RING_COUNT` | `active_item_effect_renderer.gd:22` 무조건 [active-item] | none | **none**(grep 0) | **4 MISSING** | **restore**(2→4) 또는 `<=N` 씰 | 새 픽업글로우 씰 | named const, 봉인 쉬움 |
| 에너지볼 크로마/새턴/아크 | `energy_ball_renderer.gd:245/422` [**viper-only**] | none | 입자경로만 `energy_ball_air_strike_lod_budget_smoke.gd:37`; 0.68/0.82 인라인 **비봉인** | **3 FACET** | 저우선(바이퍼+72fps만) | 임계값 씰 확장 | 비바이퍼는 풀 |
| 화염공 후광 / 차원문 / 라그나로크 / 월계수 / 스폰스파크 / 포세이돈 (6후보) | 각 오버레이 | none | `ball_status_overlay_renderer_budget_smoke.gd` / `active_item_field_renderer_portal_smoke.gd` / `laurel_leaf_shield_render_budget_smoke.gd` | **2 SEALED** | none | — | ★화염공후광=anti-oversized-comet 의도 redesign 봉인(원래 최상위 HIGH였음). 월계수=실루엣 품질하한 봉인 |

## 6. weather/core — DEAD 0 / SEALED 8 / FACET 0 / MISSING 2 / CLEAN 1 (작업 2)

| candidate | live_path_evidence | dead | seal_evidence | class | allowed_action | required_smoke | notes |
|---|---|---|---|---|---|---|---|
| 얼음 서리 오버레이 `ICE_OVERLAY_LINE_COUNT` | `weather_event_renderer.gd:134-143` | none | **none**(grep 0) | **4 MISSING** | **restore** + 벤치 + 씰 | 새 ice-overlay severe 씰 | ★10→2 |
| 불 열밴드 오버레이 `FIRE_OVERLAY_HEAT_LINE_COUNT` | `:117-130` | none | **none**(grep 0) | **4 MISSING** | **restore** + 벤치 + 씰 | 새 fire heat-band severe 씰 | ★base=4(6아님)→1 |
| 비/불/얼음/generic 필드 + 바람 + fire-hit + 상세 + 모래 (8후보) | `weather_event_renderer.gd:335`+ | none | `weather_event_render_budget_smoke.gd` + `weather_event_state_smoke.gd` | **2 SEALED** | hold/**forbid GPUParticles(바람)** | — | ★바람 near-full+stride금지 anti-flicker 봉인; "snow" 타입 없음 |
| core effects drawer / intros | passthrough | n/a | n/a | **CLEAN** | none | — | 감소 없음 |

---

## 7. 확정 작업 목록 (class 3/4 · 라이브 · 비봉인)

**즉시 복구 가능 (저렴·비봉인·라이브·명확)** — 각 direct-restore 또는 소규모 bake +
새 씰 + 반증검증:
1. stage3 멘헤라 오라 링 (바깥40→18 + 안쪽 아크 복원) — direct
2. stage3 멘헤라 지면 그림자 (18→10 복원) — direct
3. stage3 하위 앰비언트 폴리지 (2 blit, 0.58서 OFF) — direct
4. stage4 파괴웨이브 코어 동심원 링 (6→3) — restore + 씰
5. stage4 배경 대기 스파크 (10→5) — restore + 씰
6. weather 얼음 서리 오버레이 (10→2) — restore + 벤치 + 씰
7. weather 불 열밴드 오버레이 (4→1) — restore + 벤치 + 씰
8. items 홀리배리어 (룬/광선/grad; const 추출 선행) — restore + 씰
9. items 마그넷 필드 (const 추출 선행; 감사 수치 재확인) — restore + 씰
10. items 픽업/오라 글로우 (2→4) — restore + 씰
11. HUD 보스 대쉬 오브 procedural 프레임 (보스대쉬만; 픽셀QA) — bake/contract

**사인오프/보류:**
- stage1 그리드 입자(severe=0, `<=1` 봉인 — 디자인이 되살리길 원하는가?)
- stage3 멘헤라 오버드라이브 잔상(풀 sprite blit 실비용)
- HUD 게이지오브/쿨다운/듀스/리퀴드/대쉬바디(봉인 계약 — 계약변경 원하면 별도 디자인)

**저우선(sub-perceptual/좁은스코프):** stage4 골드더스트 halo·에너지링 레이어수,
energy_ball 크로마(바이퍼전용), lucky-coin 스파크.

**별건 버그(LOD무관):** 단일 대쉬토큰 부스트 이중드로우.

## 8. 파일럿 재선정
A1(중앙원)=DEAD, A2(게이지오브)=SEALED → 둘 다 파일럿 불가(rev1 오판 교정 완료).
**새 파일럿 후보 = #1 stage3 멘헤라 오라 링** (라이브·비봉인·저렴·시각 명확·boss_actor
렌더러엔 밀도 씰 없음). direct-restore + 신규 씰 + 반증검증으로 워크플로 확립.

## 9. 핵심 결론
- 감사 HIGH 16 → 트리아지 후 **즉시 복구 가치 있는 라이브·비봉인 = ~11건, 대부분
  주변부/저강도**(앰비언트 폴리지, 스파크, 오버레이 라인, 액티브아이템 룬).
- **원래 최상위 HIGH들이 대거 무효**: 중앙원=DEAD, 게이지오브·쿨다운=SEALED(쿨다운은
  하한까지), 화염공후광=의도 redesign 봉인, 날씨필드=SEALED, 차원문=SEALED.
- 사용자가 **실제로 신고한** 형상 손상은 이미 수정된 3건이 전부였고, 이 신규 목록엔
  사용자가 목격 신고한 항목이 없다 → 복구 여부/범위는 "이게 실제로 거슬리는가"
  기준으로 사용자가 정하는 게 맞다.
