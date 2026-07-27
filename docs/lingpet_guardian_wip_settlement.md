# 수호령 삭제영역 WIP 정산표 (읽기 전용)

작성 2026-07-28. `docs/lingpet_guardian_duration_redesign_plan.md` §9-1(선 WIP 정산)의
입력 자료. **이 문서는 분류만 한다 — 커밋·폐기 실행은 사용자 승인 후 별도 작업.**

방법: `git status --porcelain -uall` 필터(lingpet|affinity|ring_core|satiety) 228건 +
공유 소비자 dirty 8건 = 236건을 분류 에이전트 8개가 전 파일 실측(?? = 본문 Read,
M = git diff 헝크 판독)으로 분류하고, 적대 감사 2개(폐기 오분류·정합성)가 재검증.
정정 6건 적용, 감사자 충돌 0건, 최종 전 항목 확신도 high.

## 요약

| 버킷 | 건수 | 의미 |
|---|---|---|
| A. 보존·커밋 | 227 (+누락 편입 4 = 231) | 범용 기반 — 재설계와 무관하게 커밋 |
| B. 추출 레일 | 7 | 커밋 보존(추출 원본) → 새 설계 이식 후 삭제 |
| C. 완전 폐기 | **0** | 폐기물 없음 (아래 핵심 발견 참조) |
| D. 혼합 — 사용자 결정 | 2 | 파일 1쌍 (입력 라우터 + .uid) |

## 핵심 발견

1. **C(폐기) = 0건.** 순수 구설계 코드(교감 포인트 수입 파이프라인, 링코어 상점
   행, 칩 기계 본체)는 이미 **커밋된 상태**라 WIP 델타가 아니다 — 구설계 삭제는
   §9-4 "후 삭제" 슬라이스의 일이지 WIP 정산의 일이 아니다. WIP 델타에서 유일한
   순수 폐기 코드는 D 라우터 안의 교감 인터랙트 섹션뿐.
2. **236건 중 235건이 "커밋" 방향으로 단일 결정된다.** 대부분이 렌더러 추출(~60),
   리브랜드/manifest 동기(~40), 알 전통 리스타일(~18), 오디오/라우터/프레임
   컨트롤러 분해, 링펫 스킬 포팅, 링크포트 이중수비 등 범용 기반이다.
   "어차피 삭제될 시스템"이라는 이유로 버릴 파일은 사실상 없다.
3. **`lingpet_egg_runtime.gd`의 WIP가 이미 §9-2(레일 추출)의 선행분이다.**
   diff 실측 결과 satiety 로직이 신규 `LingpetSatietyRuntimeState`로 위임 추출되어
   있다(폐기 대상 헝크 0건, 교감 인터랙트 코드는 delta가 아니라 HEAD에 존재).
   → **구현 착수 시 satiety 추출을 중복 재작업하지 말 것.** 이 커밋이 곧 지속시간
   엔진 추출의 출발점이다.
4. 링코어 퍽 레인 기계 본체(`runtime_perk_lingpet_rewards.gd`,
   `ring_core_projection.gd`)는 WIP가 아니라 커밋 상태 — 정산표에 없는 것이 정상.

## D 버킷 결정 — ✅ 종결 (2026-07-28, 사용자 확정: 선택지 1)

**`godot/scripts/core/battle_lingpet_interaction_input_router.gd` (+ `.uid`)** — 한 파일에:

- **보존부**: 우선 컷인 입력 처리(`handle_priority_cutin_input`), 클릭 리액션,
  멀티펫 L사이클 (새 설계에서도 로스터 3마리 유지라 필요)
- **폐기부**: 교감 인터랙트 입력 — `LINGPET_INTERACT_KEY=E`, RT 트리거 래치
  (상수 3 + 헬퍼 2 + `_handle_companion_interact`). 교감 삭제로 무용 + §4에서
  RT는 패드 매핑 불승인까지 받은 입력.

**결정: (1) 전체 커밋 후, §9-4 삭제 슬라이스에서 인터랙트 섹션 트림.**

결정 근거: E/RT 교감 동작은 신규 WIP가 아니라 이미 HEAD의 입력 컨트롤러에
존재했고, 이번 변경은 이를 전용 라우터로 옮기는 **동작보존 추출**이다. 지금
트림하면 정산 커밋에 의미 변경까지 섞이지만, 전체 커밋하면 "소유권 이동"과
"구기능 삭제" 이력이 깨끗하게 분리된다.

**첫 커밋의 원자 구성 (전부 dirty 실측 확인됨):**

| 파일 | 상태 |
|---|---|
| godot/scripts/core/battle_lingpet_interaction_input_router.gd | ?? |
| godot/scripts/core/battle_lingpet_interaction_input_router.gd.uid | ?? |
| godot/scripts/core/battle_scene_input_controller.gd — 위임·상수 재노출 헝크만 | M |
| godot/tests/battle_lingpet_interaction_input_router_owner_smoke.gd | ?? |
| godot/tests/battle_lingpet_interaction_input_router_owner_smoke.gd.uid | ?? |
| godot/tests/lingpet_battle_slot_hud_removed_smoke.gd — 재조준 헝크 | M |

**§9-4 트림 범위 (이 파일에 한정되지 않음):**
- 라우터의 E/RT 상수·래치·헬퍼·집계 호출
- 입력 컨트롤러의 `LINGPET_INTERACT_*` 재노출
- owner smoke의 RT 단언
- 대조군 봉인: 컷인 우선 입력, 클릭 리액션, L/Shift+L 순환은 트림 후에도
  동작함을 씰로 보증 (트림이 보존부를 건드리지 않았다는 증명).

## 정합 감사가 편입한 누락 4건 (A 버킷 추가)

영역 grep 재검색으로 236 스코프 밖에서 발견된 같은 번들 소속 WIP:

| 파일 | 상태 | 번들 | 근거 |
|---|---|---|---|
| godot/tests/guardian_spirit_rebrand_smoke.gd | ?? | 수호령 리브랜드 | 리브랜드 중앙 씰(7언어 표시명·호환 ID·로딩팁). preload 대상 3파일이 전부 A 엔트리 |
| godot/tests/guardian_spirit_rebrand_smoke.gd.uid | ?? | 〃 | UID 사이드카 동반 |
| godot/assets/ui/character_info/character_info_empty_guardian_spirit_egg_traditional_v1.png | ?? | 알 전통 리스타일 | manifest·`character_info_overlay_state.gd:58`이 소비. **이 PNG 없이 소비자만 커밋하면 예약-에셋 per-frame re-stat 트랩** |
| godot/assets/ui/character_info/character_info_empty_guardian_spirit_egg_traditional_v1.png.import | ?? | 〃 | import 메타 동반 |

## 스코프 밖 경계 의존 파일 (커밋 시 함께 검토 — dirty 실측 확인됨)

A 엔트리들이 의존하는 236 스코프 밖 dirty 파일. 해당 번들 커밋 시 관련 헝크를
같이 실어야 비자립 커밋(모듈만 살고 배선 죽는 고아쌍)을 피한다:

| 파일 | 상태 | 관련 번들 |
|---|---|---|
| godot/scripts/audio/game_audio.gd | M | 링펫 오디오 owner 분리 3종 배선 |
| godot/scripts/core/battle_scene_input_controller.gd | M | 입력 라우터 추출 콜사이트 |
| godot/scripts/hud/character_info_overlay_state.gd | M | 빈 알 히어로 경로 1줄 (위 PNG 소비자) |
| godot/scripts/plaza/plaza_shop_transactions.gd | ?? | 플라자 분해 (feed 씰 재조준 대상) |

⚠️ 이 4건은 수호령 외 외래 WIP 헝크를 포함할 수 있으므로 커밋 시 헝크 분리 필수.

## 다음 단계

1. ~~D 라우터 처리 방식 결정~~ ✅ 종결 — 선택지 1 (전체 커밋 → §9-4 트림).
2. A+B+D 총 240건(236 + 편입 4)을 **기능 묶음 단위로 헝크 분리 커밋** (아래 표의
   의존성 열 = 동반 커밋 대상). D 라우터는 위 원자 구성표대로. B는 커밋 메시지에
   "추출 원본 — 이식 후 삭제 예정" 명기.
3. 정산 완료 후 코덱스가 §9-2부터 착수 (satiety 추출 선행분 재작업 금지 노트 전달).

### 정산 커밋 실행 계약 (2026-07-28 사용자 확정)

**트리거: 사용자가 "정산 커밋 시작"이라고 명시할 때만 실행 개시.**
트리거는 **로컬 커밋까지만** 의미하며, 푸시·PR 생성은 별도 지시 필요.

실행 원칙:
1. 기능 묶음별 원자 커밋.
2. 경계 파일 4건(game_audio, battle_scene_input_controller,
   character_info_overlay_state, plaza_shop_transactions)은 필요한 헝크만 선별.
3. `git add -A` 등 광역 스테이징 금지.
4. 각 커밋마다 의존 파일·씰 포함 여부와 **실제 커밋 blob 검증**.
5. focused smoke + `git diff --check` + 잔여 dirty 목록 대조.
6. `reset`·`checkout`·`stash` 금지.
7. 전체 정산 완료 후에만 §9-2 착수.

### 실행 로그 — ✅ 2026-07-28 완료 (로컬 커밋 6건, 250파일)

| # | 커밋 | 내용 | 파일 |
|---|---|---|---|
| 1 | 0e4b54999 | docs — 기획 정본 + 정산표 + 링펫 문서 용어 동기 | 8 |
| 2 | 82a6a6f61 | 수호령알 전통 리스타일 에셋 (소비자 선행) | 19 |
| 3 | 430a3a539 | 스킬 서브시스템 분해 웨이브 (렌더러 20종·오디오 모듈·수비/포만도 상태·egg_runtime) | 140 |
| 4 | 2f89fc017 | 입력 컨트롤러 6-라우터 분해 + D 라우터 원자 랜딩 | 38 |
| 5 | e6885971d | 리브랜드 카피 동기 + 알 전통 필드 배선 + manifest 개명 | 42 |
| 6 | df6065868 | 액티브 슬롯 쿨다운 상태 모듈 추출 | 3 |

- 매 커밋 집합 대조(스테이징 == 계획 목록) + `git diff --check` 통과.
- **정산 스코프 240건 중 227 커밋, 보류 13건** (잔여 dirty 목록과 1:1 대조 일치):
  bomb_surprise(부동갑주 의존), game_audio owner 씰 3쌍(game_audio 3,860줄
  외래 동거 델타 대기), feed/plaza store 씰 2건(플라자 분해 캠페인 대기),
  runtime_perk_state(퍽 파이프라인 6파일 캠페인), battle_scene_frame_controller
  (14 코디네이터 캠페인), guardian_spirit_rebrand_smoke 쌍(로딩팁·플라자 델타 단언).
- 스코프 밖 동반 커밋 23건: 파스타임 preload 자기완결성 필수 편입(웨이브 4 라우터
  3쌍+owner 씰 5쌍, 쿨다운 상태 쌍) + 경계 파일 2건(battle_scene_input_controller
  는 6-라우터 재작성이라 헝크 분리 불가로 전체 커밋, character_info_overlay_state
  는 델타가 빈 알 경로 1줄뿐) + 정산표 문서.
- focused smoke 15종: **14 GREEN / 1 RED** — `character_info_lingpet_card_specs_smoke`
  퍼사드 위임 단언 4건 실패. 정산 델타는 표시명 리네임뿐(정합 감사가 presenter
  20헝크 전부 리네임 diff 실측)이라 **정산 커밋이 만든 회귀 아님** — WIP 소실
  사건의 "위임 배선만 죽은 고아쌍" 계열 기존 RED로 판정, 복구 백로그로 이관.

---

# 상세 분류표 (감사 정정 반영)

## A. 보존·커밋할 범용 기반 — 227건

### 링펫 스킬 렌더러 분리 (30건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_afterglow_leak_renderer_smoke.gd | ?? | 커밋 — afterglow leak 렌더러/상태 모듈과 페어 랜딩 | 신설 lingpet_afterglow_leak_renderer(패시브 잔광 VFX 렌더러 추출)의 씰. 펫 패시브 VFX는 신설계 생존 자산. | godot/scripts/lingpet/lingpet_afterglow_leak_renderer.gd; godot/scripts/lingpet/lingpet_afterglow_leak_state.gd; godot/tests/lingpet_afterglow_leak_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_afterglow_leak_renderer_smoke.gd.uid | ?? | 동반 커밋 (uid 사이드카) | 쌍이 되는 .gd 스모크의 uid 사이드카. | godot/tests/lingpet_afterglow_leak_renderer_smoke.gd | high |
| godot/tests/lingpet_banana_slice_renderer_smoke.gd | ?? | 커밋 — banana slice 렌더러 모듈과 페어 랜딩 | 신설 lingpet_banana_slice_renderer(빠나몽 바나나슬라이스 VFX 렌더러 추출)의 씰. 스킬 자산 생존, 렌더러 추출은 A 인프라. | godot/scripts/lingpet/lingpet_banana_slice_renderer.gd; godot/scripts/lingpet/lingpet_banana_slice_skill.gd; godot/tests/lingpet_banana_slice_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_banana_slice_renderer_smoke.gd.uid | ?? | 동반 커밋 (uid 사이드카) | 쌍이 되는 .gd 스모크의 uid 사이드카. | godot/tests/lingpet_banana_slice_renderer_smoke.gd | high |
| godot/tests/lingpet_bone_barrier_renderer_smoke.gd | ?? | 커밋 — bone barrier 렌더러 모듈과 페어 랜딩 | 신설 lingpet_bone_barrier_renderer의 씰(파사드 페이로드·빌드 진행 계약·소스 소유권). 렌더러 추출 A 인프라. | godot/scripts/lingpet/lingpet_bone_barrier_renderer.gd; godot/scripts/lingpet/lingpet_bone_barrier_skill.gd; godot/tests/lingpet_bone_barrier_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_bone_barrier_renderer_smoke.gd.uid | ?? | 동반 커밋 (uid 사이드카) | 쌍이 되는 .gd 스모크의 uid 사이드카. | godot/tests/lingpet_bone_barrier_renderer_smoke.gd | high |
| godot/tests/lingpet_bubble_trap_renderer_smoke.gd | ?? | 커밋 — bubble trap 렌더러 모듈과 페어 랜딩 | 신설 lingpet_bubble_trap_renderer의 씰. 렌더러 추출 A 인프라; 기존 스킬 스모크의 재조준 단언과 함께 이동. | godot/scripts/lingpet/lingpet_bubble_trap_renderer.gd; godot/tests/lingpet_bubble_trap_skill_smoke.gd; godot/tests/lingpet_bubble_trap_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_bubble_trap_renderer_smoke.gd.uid | ?? | 동반 커밋 (uid 사이드카) | 쌍이 되는 .gd 스모크의 uid 사이드카. | godot/tests/lingpet_bubble_trap_renderer_smoke.gd | high |
| godot/tests/lingpet_bubble_trap_skill_smoke.gd | M | 커밋 — lingpet_bubble_trap_renderer 추출과 동일 커밋 | 델타는 _draw_inner_bubbles 단언을 스킬 본체에서 신설 렌더러 소스로 재조준. 렌더러 추출(A)의 정합 씰. | godot/scripts/lingpet/lingpet_bubble_trap_renderer.gd; godot/tests/lingpet_bubble_trap_renderer_smoke.gd | high |
| godot/tests/lingpet_doll_curse_skill_smoke.gd | M | 커밋 — doll_curse 렌더러·런치 피드백 라우터 추출과 동일 커밋 | 델타는 마리오네트 드로/폴백 단언을 lingpet_doll_curse_renderer로, 발동 오디오 단언을 lingpet_skill_launch_feedback_router로 재조준. 렌더러/라우터 추출(A) 정합 씰. | godot/scripts/lingpet/lingpet_doll_curse_renderer.gd; godot/scripts/lingpet/lingpet_skill_launch_feedback_router.gd | high |
| godot/tests/lingpet_dragon_breath_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_dragon_breath_renderer/_skill 쌍 씰. 펫 스킬 VFX 렌더러 추출 계열로 신설계 무관 보존 인프라. | godot/scripts/lingpet/lingpet_dragon_breath_renderer.gd; godot/scripts/lingpet/lingpet_dragon_breath_skill.gd; godot/tests/lingpet_dragon_breath_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_dragon_breath_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_dragon_breath_renderer_smoke.gd | high |
| godot/tests/lingpet_dragon_wing_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_dragon_wing_renderer/_skill 쌍 씰. 펫 스킬 VFX 렌더러 추출 계열. | godot/scripts/lingpet/lingpet_dragon_wing_renderer.gd; godot/scripts/lingpet/lingpet_dragon_wing_skill.gd; godot/tests/lingpet_dragon_wing_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_dragon_wing_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_dragon_wing_renderer_smoke.gd | high |
| godot/tests/lingpet_gatling_burst_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_gatling_burst_renderer/_skill 쌍 씰. 펫 스킬 VFX 렌더러 추출 계열. | godot/scripts/lingpet/lingpet_gatling_burst_renderer.gd; godot/scripts/lingpet/lingpet_gatling_burst_skill.gd; godot/tests/lingpet_gatling_burst_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_gatling_burst_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_gatling_burst_renderer_smoke.gd | high |
| godot/tests/lingpet_ghost_summon_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_ghost_summon_renderer/_skill 쌍 씰. 펫 스킬 VFX 렌더러 추출 계열. | godot/scripts/lingpet/lingpet_ghost_summon_renderer.gd; godot/scripts/lingpet/lingpet_ghost_summon_skill.gd; godot/tests/lingpet_ghost_summon_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_ghost_summon_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_ghost_summon_renderer_smoke.gd | high |
| godot/tests/lingpet_headbutt_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_headbutt_renderer/_skill 쌍 씰. 펫 스킬 VFX 렌더러 추출 계열. | godot/scripts/lingpet/lingpet_headbutt_renderer.gd; godot/scripts/lingpet/lingpet_headbutt_skill.gd; godot/tests/lingpet_headbutt_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_headbutt_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_headbutt_renderer_smoke.gd | high |
| godot/tests/lingpet_hydro_sphere_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_hydro_sphere_renderer/_skill 쌍 씰. 펫 스킬 VFX 렌더러 추출 계열. | godot/scripts/lingpet/lingpet_hydro_sphere_renderer.gd; godot/scripts/lingpet/lingpet_hydro_sphere_skill.gd; godot/tests/lingpet_hydro_sphere_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_hydro_sphere_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_hydro_sphere_renderer_smoke.gd | high |
| godot/tests/lingpet_moon_orbit_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_moon_orbit_renderer/_skill 쌍 씰. 펫 스킬 VFX 렌더러 추출 계열. | godot/scripts/lingpet/lingpet_moon_orbit_renderer.gd; godot/scripts/lingpet/lingpet_moon_orbit_skill.gd; godot/tests/lingpet_moon_orbit_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_moon_orbit_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_moon_orbit_renderer_smoke.gd | high |
| godot/tests/lingpet_skeleton_archer_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_skeleton_archer_renderer/_skill 쌍 씰. 펫 스킬 VFX 렌더러 추출 계열. | godot/scripts/lingpet/lingpet_skeleton_archer_renderer.gd; godot/scripts/lingpet/lingpet_skeleton_archer_skill.gd; godot/tests/lingpet_skeleton_archer_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_skeleton_archer_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_skeleton_archer_renderer_smoke.gd | high |
| godot/tests/lingpet_soul_clone_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_soul_clone_renderer/_skill 쌍 씰. 펫 스킬 VFX 렌더러 추출 계열. | godot/scripts/lingpet/lingpet_soul_clone_renderer.gd; godot/scripts/lingpet/lingpet_soul_clone_skill.gd; godot/tests/lingpet_soul_clone_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_soul_clone_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_soul_clone_renderer_smoke.gd | high |
| godot/tests/lingpet_thunder_orb_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_thunder_orb_renderer/_skill 쌍 씰. 펫 스킬 VFX 렌더러 추출 계열. | godot/scripts/lingpet/lingpet_thunder_orb_renderer.gd; godot/scripts/lingpet/lingpet_thunder_orb_skill.gd; godot/tests/lingpet_thunder_orb_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_thunder_orb_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_thunder_orb_renderer_smoke.gd | high |

### 한국 신화 리브랜딩 펫 개명 (manifest 동기화) (18건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/assets/sprites/lingpet/koyora_click_live2d_pingpong_98f_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | diff는 display_name '코요라'→'살각시' 한 줄뿐. 신화무협 리브랜딩 트랙의 provenance 문서 동기화로, 진행 시스템 삭제와 무관. | godot/scripts/lingpet/lingpet_catalog.gd (런타임측 동일 개명) | high |
| godot/assets/sprites/lingpet/koyora_companion_click_reaction_98f_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '살각시' 개명 한 줄. 리브랜딩 문서 동기화. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/koyora_companion_idle_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name 'Koyora'→'살각시' 한 줄. 컴패니언 idle 시트는 신설계에서도 그대로 사용. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/koyora_companion_move_left_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '살각시' 개명 한 줄. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/koyora_companion_move_right_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '살각시' 개명 한 줄. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/koyora_companion_strike_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name 'Koyora'→'살각시' 한 줄. 스트라이크 모션은 신설계 유지 자산. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/koyora_companion_walk_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '살각시' 개명 한 줄. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/koyora_cutin_anim_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '코요라'→'살각시' 한 줄. 컷인 아트는 신설계 수호령강화 연출(§5)이 그대로 재사용하는 자산. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/koyora_puppet_control_cast_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name 'Koyora'→'살각시' 한 줄. 퍼핏그랩 스킬 시트는 신설계에서도 유지되는 펫 스킬 자산. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/lumion_click_live2d_pingpong_98f_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '루미온'→'벼락여우' 한 줄. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/lumion_companion_idle_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '루미온'→'벼락여우' + 말미 개행 정규화뿐. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/lumion_companion_strike_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '벼락여우' 개명 + 개행 정규화. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/lumion_companion_walk_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '벼락여우' 개명 + 개행 정규화. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/lumion_cutin_anim_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '루미온'→'벼락여우' 한 줄. 컷인 아트는 수호령강화 연출 재사용 자산. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/onimaru_companion_move_left_25f_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '오니마루'→'방망깨비' + 개행 정규화. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/onimaru_companion_move_right_25f_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '방망깨비' 개명 + 개행 정규화. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/onimaru_companion_standing_idle_25f_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '오니마루'→'방망깨비' + 개행 정규화. | godot/scripts/lingpet/lingpet_catalog.gd | high |
| godot/assets/sprites/lingpet/onimaru_companion_strike_25f_manifest.json | M | 리브랜딩 개명 묶음으로 커밋 | display_name '방망깨비' 개명 + 개행 정규화. | godot/scripts/lingpet/lingpet_catalog.gd | high |

### 수호령알 전통 리스타일 + 크랙 오버레이 (17건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_crack_stage_1_v1.png | ?? | 알 리스타일 자산 묶음으로 커밋 | 부화 진행 크랙 1단계 오버레이 PNG. 신설계 §2가 알 획득·2~4회 타격 부화를 그대로 유지하므로 필수 자산. lingpet_egg_field_renderer.gd가 소비. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_crack_stage_1_v1.png.import; godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_v1_manifest.json; godot/scripts/lingpet/lingpet_egg_field_renderer.gd | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_crack_stage_1_v1.png.import | ?? | 짝 PNG와 함께 커밋 | 크랙 1단계 PNG의 Godot import 메타. PNG↔import 쌍으로 이동. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_crack_stage_1_v1.png | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_crack_stage_2_v1.png | ?? | 알 리스타일 자산 묶음으로 커밋 | 크랙 2단계 오버레이 PNG. 부화 히트 피드백은 신설계에서도 유지 (2~4회 타격 부화 상향). | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_crack_stage_2_v1.png.import; godot/scripts/lingpet/lingpet_egg_field_renderer.gd | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_crack_stage_2_v1.png.import | ?? | 짝 PNG와 함께 커밋 | 크랙 2단계 PNG의 import 메타. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_crack_stage_2_v1.png | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_item_icon_v1.png | ?? | 알 리스타일 자산 묶음으로 커밋 | 액티브 아이템 스폰풀용 알 아이콘. active_item_catalog.gd 소비. 신설계 §2가 스폰풀 알 등장을 유지·확장하므로 필수. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_item_icon_v1.png.import; godot/scripts/items/active_item_catalog.gd | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_item_icon_v1.png.import | ?? | 짝 PNG와 함께 커밋 | 알 아이콘 PNG의 import 메타. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_item_icon_v1.png | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_v1_manifest.json | ?? | 알 리스타일 자산 묶음으로 커밋 | 알 패밀리 계약 정본 (variant 5종·크랙 2단·아이콘·character_info hero 매핑 + alpha_bounds/draw_size 런타임 계약). 자산군과 한 묶음. | guardian_spirit_egg_traditional_variant_0..4_v1.png; guardian_spirit_egg_traditional_crack_stage_1/2_v1.png; godot/assets/ui/character_info/character_info_empty_guardian_spirit_egg_traditional_v1.png (다른 청크) | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_0_v1.png | ?? | 알 리스타일 자산 묶음으로 커밋 | 청화백자 테마 알 variant. lingpet_egg_field_renderer.gd·lingpet_catalog.gd 소비, lingpet_egg_runtime_smoke.gd 봉인. 신설계 유지 자산. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_0_v1.png.import; godot/scripts/lingpet/lingpet_egg_field_renderer.gd; godot/tests/lingpet_egg_runtime_smoke.gd | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_0_v1.png.import | ?? | 짝 PNG와 함께 커밋 | variant 0 PNG의 import 메타. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_0_v1.png | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_1_v1.png | ?? | 알 리스타일 자산 묶음으로 커밋 | 황토단청 테마 알 variant. 동일 소비자 배선. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_1_v1.png.import; godot/scripts/lingpet/lingpet_egg_field_renderer.gd | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_1_v1.png.import | ?? | 짝 PNG와 함께 커밋 | variant 1 PNG의 import 메타. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_1_v1.png | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_2_v1.png | ?? | 알 리스타일 자산 묶음으로 커밋 | 칠성옻칠 테마 알 variant. 동일 소비자 배선. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_2_v1.png.import; godot/scripts/lingpet/lingpet_egg_field_renderer.gd | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_2_v1.png.import | ?? | 짝 PNG와 함께 커밋 | variant 2 PNG의 import 메타. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_2_v1.png | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_3_v1.png | ?? | 알 리스타일 자산 묶음으로 커밋 | 홍매자개 테마 알 variant. 동일 소비자 배선. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_3_v1.png.import; godot/scripts/lingpet/lingpet_egg_field_renderer.gd | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_3_v1.png.import | ?? | 짝 PNG와 함께 커밋 | variant 3 PNG의 import 메타. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_3_v1.png | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_4_v1.png | ?? | 알 리스타일 자산 묶음으로 커밋 | 비취청자 테마 알 variant. 동일 소비자 배선. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_4_v1.png.import; godot/scripts/lingpet/lingpet_egg_field_renderer.gd | high |
| godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_4_v1.png.import | ?? | 짝 PNG와 함께 커밋 | variant 4 PNG의 import 메타. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_4_v1.png | high |

### 링펫 스킬 렌더러 추출 (17건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_afterglow_leak_renderer.gd | ?? | M lingpet_afterglow_leak_state.gd(타 청크)와 함께 보존 커밋 | 순수 draw 추출 렌더러 (AfterglowFluidTextureCache prewarm 포함). 짝 상태 모듈이 M으로 위임 배선 중이라 이 파일 없이는 preload 깨짐 — 반드시 동반 커밋. | godot/scripts/lingpet/lingpet_afterglow_leak_state.gd; godot/scripts/lingpet/lingpet_afterglow_leak_renderer.gd.uid | high |
| godot/scripts/lingpet/lingpet_afterglow_leak_renderer.gd.uid | ?? | 짝 .gd와 동반 커밋 | Godot UID 사이드카 — 짝 .gd와 항상 같이 이동. | godot/scripts/lingpet/lingpet_afterglow_leak_renderer.gd | high |
| godot/scripts/lingpet/lingpet_banana_slice_renderer.gd | ?? | M lingpet_banana_slice_skill.gd(타 청크)와 함께 보존 커밋 | 바나나 텍스처/타원 메시 캐시 포함 순수 draw 추출 렌더러. 짝 스킬 모듈이 M 위임 파사드 — 동반 커밋 필수. 펫 스킬은 신설계에서도 보존. | godot/scripts/lingpet/lingpet_banana_slice_skill.gd; godot/scripts/lingpet/lingpet_banana_slice_renderer.gd.uid | high |
| godot/scripts/lingpet/lingpet_banana_slice_renderer.gd.uid | ?? | 짝 .gd와 동반 커밋 | UID 사이드카. | godot/scripts/lingpet/lingpet_banana_slice_renderer.gd | high |
| godot/scripts/lingpet/lingpet_bone_barrier_renderer.gd | ?? | M lingpet_bone_barrier_skill.gd(타 청크)와 함께 보존 커밋 | 네크로 본배리어 팔레트/draw 순수 추출 렌더러. 짝 스킬 모듈 M 위임 파사드와 동반 필수. | godot/scripts/lingpet/lingpet_bone_barrier_skill.gd; godot/scripts/lingpet/lingpet_bone_barrier_renderer.gd.uid | high |
| godot/scripts/lingpet/lingpet_bone_barrier_renderer.gd.uid | ?? | 짝 .gd와 동반 커밋 | UID 사이드카. | godot/scripts/lingpet/lingpet_bone_barrier_renderer.gd | high |
| godot/scripts/lingpet/lingpet_bubble_trap_renderer.gd | ?? | M lingpet_bubble_trap_skill.gd(타 청크)와 함께 보존 커밋 | 버블 트랩 draw 순수 추출 렌더러. 짝 스킬 모듈 M 위임 파사드와 동반 필수. | godot/scripts/lingpet/lingpet_bubble_trap_skill.gd; godot/scripts/lingpet/lingpet_bubble_trap_renderer.gd.uid | high |
| godot/scripts/lingpet/lingpet_bubble_trap_renderer.gd.uid | ?? | 짝 .gd와 동반 커밋 | UID 사이드카. | godot/scripts/lingpet/lingpet_bubble_trap_renderer.gd | high |
| godot/scripts/lingpet/lingpet_dragon_breath_renderer.gd | ?? | M lingpet_dragon_breath_skill.gd(타 청크)와 함께 보존 커밋 | 드래곤 브레스 draw 순수 추출 렌더러 (텍스처 캐시 위임 포함). 짝 스킬 모듈 M 위임 파사드와 동반 필수. | godot/scripts/lingpet/lingpet_dragon_breath_skill.gd; godot/scripts/lingpet/lingpet_dragon_breath_texture_cache.gd; godot/scripts/lingpet/lingpet_dragon_breath_renderer.gd.uid | high |
| godot/scripts/lingpet/lingpet_dragon_breath_renderer.gd.uid | ?? | 짝 .gd와 동반 커밋 | UID 사이드카. | godot/scripts/lingpet/lingpet_dragon_breath_renderer.gd | high |
| godot/scripts/lingpet/lingpet_dragon_wing_renderer.gd | ?? | M lingpet_dragon_wing_skill.gd(타 청크)와 함께 보존 커밋 | 레드드래곤 비행 시트(5x5) draw 순수 추출 렌더러. 짝 스킬 모듈 M 위임 파사드와 동반 필수. 시트 에셋 경로 소비자. | godot/scripts/lingpet/lingpet_dragon_wing_skill.gd; godot/assets/sprites/lingpet/red_dragon_companion_side_fly_flap.png; godot/scripts/lingpet/lingpet_dragon_wing_renderer.gd.uid | high |
| godot/scripts/lingpet/lingpet_dragon_wing_renderer.gd.uid | ?? | 짝 .gd와 동반 커밋 | UID 사이드카. | godot/scripts/lingpet/lingpet_dragon_wing_renderer.gd | high |
| godot/scripts/lingpet/lingpet_ghost_summon_renderer.gd | ?? | M lingpet_ghost_summon_skill.gd(타 청크)와 함께 보존 커밋 | 고스트 소환 draw 순수 추출 렌더러. 짝 스킬 모듈 M 위임 파사드와 동반 필수. | godot/scripts/lingpet/lingpet_ghost_summon_skill.gd; godot/scripts/lingpet/lingpet_ghost_summon_renderer.gd.uid | high |
| godot/scripts/lingpet/lingpet_ghost_summon_renderer.gd.uid | ?? | 짝 .gd와 동반 커밋 | UID 사이드카. | godot/scripts/lingpet/lingpet_ghost_summon_renderer.gd | high |
| godot/scripts/lingpet/lingpet_headbutt_renderer.gd | ?? | M lingpet_headbutt_skill.gd(타 청크)와 함께 보존 커밋 | 헤드벗 그라운드슬램 draw 순수 추출 렌더러. 짝 스킬 모듈 M 위임 파사드와 동반 필수. | godot/scripts/lingpet/lingpet_headbutt_skill.gd; godot/scripts/lingpet/lingpet_headbutt_renderer.gd.uid | high |
| godot/scripts/lingpet/lingpet_headbutt_renderer.gd.uid | ?? | 짝 .gd와 동반 커밋 | UID 사이드카. | godot/scripts/lingpet/lingpet_headbutt_renderer.gd | high |
| godot/scripts/lingpet/lingpet_hydro_sphere_renderer.gd | ?? | M lingpet_hydro_sphere_skill.gd(타 청크)와 함께 보존 커밋 | 하이드로 스피어 draw 순수 추출 렌더러 (HydroPuddleTextureCache prewarm 포함). 짝 스킬 모듈 M 위임 파사드와 동반 필수. .uid 사이드카는 타 청크 소속. | godot/scripts/lingpet/lingpet_hydro_sphere_skill.gd; godot/scripts/lingpet/lingpet_hydro_sphere_renderer.gd.uid | high |

### 링펫 렌더러 추출 (15건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_afterglow_leak_state.gd | M | 신규 렌더러와 페어로 커밋 | draw/텍스처 캐시 코드를 lingpet_afterglow_leak_renderer.gd로 위임하는 순수 렌더러 추출. 잔광유출 패시브 자체(기력 회수)는 새 설계에서도 생존. | godot/scripts/lingpet/lingpet_afterglow_leak_renderer.gd (??); lingpet_afterglow_leak_renderer.gd.uid | high |
| godot/scripts/lingpet/lingpet_banana_slice_skill.gd | M | 신규 렌더러와 페어로 커밋 | 바나나 draw 코드를 lingpet_banana_slice_renderer.gd로 위임하는 렌더러 추출. 펫 스킬 모듈은 새 설계에서 전량 보존 대상. | godot/scripts/lingpet/lingpet_banana_slice_renderer.gd (??); 바나나슬라이스 idle-게이트 생존맵 씰 스모크 | high |
| godot/scripts/lingpet/lingpet_bone_barrier_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_bone_barrier_renderer.gd로의 순수 렌더러 추출(빌드 진행도 헬퍼 포함). | godot/scripts/lingpet/lingpet_bone_barrier_renderer.gd (??) | high |
| godot/scripts/lingpet/lingpet_bubble_trap_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_bubble_trap_renderer.gd로의 순수 렌더러 추출. | godot/scripts/lingpet/lingpet_bubble_trap_renderer.gd (??) | high |
| godot/scripts/lingpet/lingpet_doll_curse_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_doll_curse_renderer.gd로의 순수 렌더러 추출(마리오네트/빔/인형 draw 위임). | godot/scripts/lingpet/lingpet_doll_curse_renderer.gd (??) | high |
| godot/scripts/lingpet/lingpet_dragon_breath_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_dragon_breath_renderer.gd + 화염지대 zone fx 렌더러로의 draw 위임. | godot/scripts/lingpet/lingpet_dragon_breath_renderer.gd (??); molotov zone fx 렌더러 | high |
| godot/scripts/lingpet/lingpet_dragon_wing_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_dragon_wing_renderer.gd로의 순수 렌더러 추출. | godot/scripts/lingpet/lingpet_dragon_wing_renderer.gd (??) | high |
| godot/scripts/lingpet/lingpet_gatling_burst_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_gatling_burst_renderer.gd로의 순수 렌더러 추출(상수도 렌더러 소유로 이동). | godot/scripts/lingpet/lingpet_gatling_burst_renderer.gd (??) | high |
| godot/scripts/lingpet/lingpet_ghost_summon_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_ghost_summon_renderer.gd로의 순수 렌더러 추출. | godot/scripts/lingpet/lingpet_ghost_summon_renderer.gd (??) | high |
| godot/scripts/lingpet/lingpet_headbutt_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_headbutt_renderer.gd로의 순수 렌더러 추출(차지/대쉬/임팩트 draw 위임). | godot/scripts/lingpet/lingpet_headbutt_renderer.gd (??) | high |
| godot/scripts/lingpet/lingpet_hydro_sphere_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_hydro_sphere_renderer.gd로의 순수 렌더러 추출. | godot/scripts/lingpet/lingpet_hydro_sphere_renderer.gd (??) | high |
| godot/scripts/lingpet/lingpet_moon_orbit_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_moon_orbit_renderer.gd로의 순수 렌더러 추출. | godot/scripts/lingpet/lingpet_moon_orbit_renderer.gd (??) | high |
| godot/scripts/lingpet/lingpet_puppet_grab_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_puppet_grab_renderer.gd로의 순수 렌더러 추출(스파이 치환 가능 구조 명시). | godot/scripts/lingpet/lingpet_puppet_grab_renderer.gd (??); 코요라 퍼핏그랩 씰 스모크 | high |
| godot/scripts/lingpet/lingpet_skeleton_archer_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_skeleton_archer_renderer.gd로의 순수 렌더러 추출(-587줄, 프레젠테이션 지오메트리 전부 이동). | godot/scripts/lingpet/lingpet_skeleton_archer_renderer.gd (??) | high |
| godot/scripts/lingpet/lingpet_soul_clone_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_soul_clone_renderer.gd로의 순수 렌더러 추출. | godot/scripts/lingpet/lingpet_soul_clone_renderer.gd (??) | high |

### 수호령 리브랜딩 용어 동기화 (13건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| docs/lingpet_koyora_doll_curse_beam_vfx_design.md | M | 리네임 번들과 함께 커밋 | diff는 코요라→살각시 개명 2줄뿐(한국 신화무협 리브랜딩 패스). 인형의 저주 VFX 설계 자체는 펫 스킬 자산으로 신설계에서 보존 대상. | docs/lingpet_koyora_doll_curse_plan.md; 리네임 패스 전체(13개 M 파일) 동반 커밋 | high |
| docs/lingpet_koyora_doll_curse_plan.md | M | 리네임 번들과 함께 커밋 | 코요라→살각시·링펫→수호령 개명만 8헝크. 스킬 포팅 기획 문서 본체는 신설계에서도 유효(스킬 자산 전부 보존 방침). | docs/lingpet_koyora_doll_curse_beam_vfx_design.md | high |
| docs/lingpet_lumion_solar_bolt_slice_plan.md | M | 리네임 번들과 함께 커밋 | 루미온→벼락여우 개명만. 문서 내용에 링코어 게이트(구 해금 프레임워크) 언급이 있으나 그건 커밋된 본문이고 이번 diff는 순수 개명 — 내용 진부화는 신설계 문서 갱신 단계에서 별도 처리. | docs/lingpet_unlock_loadout_v3_2c_slice_plan.md | high |
| docs/lingpet_missing_skill_card_art_handoff.md | M | 리네임 번들과 함께 커밋 | 오니마루→방망깨비 개명만 5헝크. 스킬 카드 아트 핸드오프는 신설계에서도 유효한 아트 작업. |  | high |
| docs/lingpet_orosha_star_coil_slice_plan.md | M | 리네임 번들과 함께 커밋 | 루미온→벼락여우 개명 1줄뿐. 오로샤 별똬리 스킬 포팅 문서는 보존 대상. |  | high |
| docs/lingpet_unlock_loadout_v3_2c_slice_plan.md | M | 리네임 번들과 함께 커밋 (내용 진부화는 별도) | diff는 루미온→벼락여우 개명만. 단 문서가 다루는 V3-2c 해금/로드아웃 설계는 신설계 §5(스킬레벨합≥5+30% 롤 폐지, 추가해금 버프 이관)로 일부 대체됨 — 개명 커밋과 무관하게 후속 문서 정리 필요. | docs/lingpet_lumion_solar_bolt_slice_plan.md | high |
| godot/scripts/core/lingpet_debug_picker.gd | M | 리네임 번들과 함께 커밋 | F7 디버그 피커의 표시명만 개명(코요라→살각시, 오니마루→방망깨비, 링펫→수호령). 피커 자체는 신설계 QA(D10 디버그 우회)에서도 계속 쓰는 인프라. |  | high |
| godot/scripts/hud/character_info_overlay_lingpet_card_specs.gd | M | 리네임 번들 + 다국어 테이블과 함께 커밋 | 링펫→수호령·게이지→기력 문자열 개명만 7헝크. 스킬 스펙 카드 UI는 신설계에서도 유지(펫 스킬 표시). | character_info_overlay_lingpet_presenter.gd; 다국어 테이블 동기화(타 청크 language 데이터 파일) | high |
| godot/scripts/hud/character_info_overlay_lingpet_presenter.gd | M | 리네임 번들과 함께 커밋 — 교감/포만도 문자열 헝크 2개는 후속 삭제가 흡수 | 20헝크 전부 문자열 개명(링펫→수호령·게이지→기력). 그중 draw_affinity_status 내 교감/포만도 툴팁 개명 2헝크는 §9 4단계에서 통째 삭제될 코드 위의 개명이라 커밋해도 무해(삭제가 대체). translate_text 원문 키가 바뀌므로 7언어 테이블 미동기 시 번역 룩업이 조용히 깨짐 — 다국어 파일과 동반 커밋 필수. | character_info_overlay_lingpet_card_specs.gd; character_info_overlay_lingpet_snapshot_builder.gd; 다국어 테이블 동기화(타 청크) | high |
| godot/scripts/hud/character_info_overlay_lingpet_snapshot_builder.gd | M | 리네임 번들과 함께 커밋 | 링펫→수호령 + '테스트 난이도/미카'→'수련 난이도/한미량' 개명만. 알/컴패니언 스냅샷 빌더는 신설계에서 알·로스터 흐름이 유지되므로 보존. | character_info_overlay_lingpet_presenter.gd; 다국어 테이블 동기화(타 청크) | high |
| godot/scripts/hud/character_info_overlay_lingpet_stats_projection.gd | M | 리네임 번들과 함께 커밋 | 링펫→수호령·게이지→기력 개명 2헝크. 스탯 projection은 신설계에서도 유지되는 표시 인프라(방어율/이속 행은 수호령강화 버프 표시로 이어짐). | character_info_overlay_lingpet_presenter.gd | high |
| godot/scripts/hud/lingpet_acquire_cutin_overlay_host.gd | M | 리네임 번들과 함께 커밋 | 서브타이틀 문자열 개명 1줄. 획득 컷인 호스트는 신설계 §8 이식 맵의 명시 재사용 대상(수호령강화 연출 포크 베이스). |  | high |
| godot/scripts/hud/lingpet_overflow_choice_overlay_host.gd | M | 리네임 번들과 함께 커밋 | 타이틀 문자열 개명 2줄. 오버플로 선택(로스터 만석 시 펫 선택)은 신설계에서도 3마리 로스터가 유지되므로 살아있는 흐름. | battle_lingpet_priority_input_router.gd(입력 위임) | high |

### 전투 링펫 입력·오버레이 라우터 추출 (6건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/core/battle_lingpet_overlay_presenter.gd | ?? | 호출자 배선과 함께 커밋 | 레지스트리 peek(get_cached_instance 우선) + perf 샘플링을 갖춘 범용 오버레이 draw 디스패처 — 순수 인프라 추출. 컷인/오버플로 호스트 모두 신설계에서 재사용. | godot/scripts/core/battle_scene_frame_controller.gd(호출자, 타 청크); battle_lingpet_overlay_presenter.gd.uid | high |
| godot/scripts/core/battle_lingpet_overlay_presenter.gd.uid | ?? | 부모 .gd와 함께 커밋 | uid 사이드카. | battle_lingpet_overlay_presenter.gd | high |
| godot/scripts/core/battle_lingpet_priority_input_router.gd | ?? | 호출자 배선과 함께 커밋 | 획득 컷인 dismiss + 오버플로 선택 모달 입력 라우팅. 두 흐름 모두 신설계 생존(컷인은 §8 재사용, 오버플로는 3마리 로스터 유지). 모달 게이트 컨트롤러 경유 구조도 §5 강화 연출이 그대로 상속할 패턴. | godot/scripts/core/battle_scene_overlay_input_controller.gd(호출자, 타 청크); battle_lingpet_priority_input_router.gd.uid; lingpet_overflow_choice_overlay_host.gd; godot/tests/lingpet_battle_slot_hud_removed_smoke.gd | high |
| godot/scripts/core/battle_lingpet_priority_input_router.gd.uid | ?? | 부모 .gd와 함께 커밋 | uid 사이드카. | battle_lingpet_priority_input_router.gd | high |
| godot/scripts/core/battle_lingpet_ungated_idle_coordinator.gd | ?? | 호출자 배선과 함께 커밋 — 신설계 §5가 명시 의존 | 부화 셸브레이크→컷인→오버플로의 물리게이트 밖 idle 펌프. 신설계 §5 강화 연출이 '물리 완전 정지 + ungated idle 펌프' 패턴으로 이 모듈을 그대로 상속한다고 명시 — 확실한 보존 인프라. | godot/scripts/core/battle_scene_frame_controller.gd(호출자, 타 청크); battle_lingpet_ungated_idle_coordinator.gd.uid; lingpet_egg_runtime(advance_hatch_break/advance_acquire_cutin callee) | high |
| godot/scripts/core/battle_lingpet_ungated_idle_coordinator.gd.uid | ?? | 부모 .gd와 함께 커밋 | uid 사이드카. | battle_lingpet_ungated_idle_coordinator.gd | high |

### 링펫 오디오 모듈 분리 (6건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/audio/lingpet_acquisition_audio.gd | ?? | game_audio 배선과 함께 커밋 | 획득 컷인 SFX 큐 카탈로그+프리웜 projection의 game_audio.gd 위임 추출(배선 확인 완료, 고아 아님). 컷인 호스트는 §8 재사용 대상이라 오디오도 그대로 산다. | godot/scripts/audio/game_audio.gd(호출자, 타 청크); lingpet_acquisition_audio.gd.uid; godot/tests/lingpet_egg_runtime_smoke.gd | high |
| godot/scripts/audio/lingpet_acquisition_audio.gd.uid | ?? | 부모 .gd와 함께 커밋 | Godot uid 사이드카 — 부모 스크립트와 원자적으로 이동. | lingpet_acquisition_audio.gd | high |
| godot/scripts/audio/lingpet_click_voice_audio.gd | ?? | game_audio 배선과 함께 커밋 | 11펫 클릭 리액션 보이스 카탈로그. 삭제되는 것은 클릭 '포인트 수입'이지 클릭 리액션(Live2D+보이스) 자체가 아님 — 아트/자산 전부 보존 방침에 부합하는 코스메틱 인프라. | godot/scripts/audio/game_audio.gd(호출자); lingpet_click_voice_audio.gd.uid; battle_lingpet_interaction_input_router.gd(클릭 핸들러) | high |
| godot/scripts/audio/lingpet_click_voice_audio.gd.uid | ?? | 부모 .gd와 함께 커밋 | uid 사이드카. | lingpet_click_voice_audio.gd | high |
| godot/scripts/audio/lingpet_combat_audio.gd | ?? | 커밋 — 단 affinity_level_up 큐 1건은 4단계 삭제 스윕 목록에 등재 | 펫 스킬 전투 SFX 카탈로그(퍼펫그랩·모래감옥·포효·별똬리·개틀링·난쟁이마술·네크로 소환·알 히트) — 전부 신설계 보존 스킬. 유일한 구시스템 항목은 `affinity_level_up` 큐 id 1건뿐이라 파일 단위 결정 가능(후 삭제가 흡수). | godot/scripts/audio/game_audio.gd(호출자); lingpet_combat_audio.gd.uid; godot/tests/lingpet_wild_roar_skill_smoke.gd; godot/tests/lingpet_bone_barrier_skill_smoke.gd | high |
| godot/scripts/audio/lingpet_combat_audio.gd.uid | ?? | 부모 .gd와 함께 커밋 | uid 사이드카. | lingpet_combat_audio.gd | high |

### 배틀 링펫 입력 라우터 분리 (5건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/battle_lingpet_interaction_input_router_owner_smoke.gd | ?? | 커밋 — 라우터 모듈과 module↔smoke 페어로 랜딩; 교감 interact 레그는 후 삭제 단계에서 정리 | 신설 battle_lingpet_interaction_input_router(클릭·사이클·부화 브레이크 입력)의 owner 씰. 입력 라우터 추출은 A 인프라이며 Ctrl 소환 토글 배선의 자연스러운 자리이기도 함. 내부 interact(교감 E키) 레그만 C-운명이나 커밋 결정을 바꾸지 않음. | godot/scripts/core/battle_lingpet_interaction_input_router.gd; godot/tests/lingpet_battle_slot_hud_removed_smoke.gd; godot/tests/battle_lingpet_interaction_input_router_owner_smoke.gd.uid | high |
| godot/tests/battle_lingpet_interaction_input_router_owner_smoke.gd.uid | ?? | 동반 커밋 (uid 사이드카) | 쌍이 되는 .gd 스모크의 Godot uid 사이드카 — 항상 함께 이동. | godot/tests/battle_lingpet_interaction_input_router_owner_smoke.gd | high |
| godot/tests/battle_lingpet_priority_input_router_owner_smoke.gd | ?? | 커밋 — 라우터 모듈과 페어 랜딩 | 신설 battle_lingpet_priority_input_router(획득 컷인 dismiss·오버플로 선택 우선 입력)의 owner 씰. 컷인 모달 게이트 패턴은 §5·§8에서 수호령강화 연출로 재사용되는 레일. | godot/scripts/core/battle_lingpet_priority_input_router.gd; godot/tests/lingpet_egg_runtime_smoke.gd(컷인 입력 재조준 단언); godot/tests/battle_lingpet_priority_input_router_owner_smoke.gd.uid | high |
| godot/tests/battle_lingpet_priority_input_router_owner_smoke.gd.uid | ?? | 동반 커밋 (uid 사이드카) | 쌍이 되는 .gd 스모크의 uid 사이드카. | godot/tests/battle_lingpet_priority_input_router_owner_smoke.gd | high |
| godot/tests/lingpet_battle_slot_hud_removed_smoke.gd | M | 커밋 — battle_lingpet_interaction_input_router 추출과 동일 커밋 | 델타는 링펫 사이클/입력 단언을 battle_scene_input_controller에서 신설 라우터로 재조준한 것 — 입력 라우터 추출(A 인프라)의 정합 씰. | godot/scripts/core/battle_lingpet_interaction_input_router.gd; godot/tests/battle_lingpet_interaction_input_router_owner_smoke.gd; godot/scripts/core/battle_scene_input_controller.gd | high |

### 스킬 런타임 호스트 라우터 분리 (4건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_skill_companion_surface_router.gd | ?? | 커밋 보존 | 펫 액티브 스킬의 컴패니언-대면 정책 라우터(발사 원점, 위치 오버라이드, 바디히트/바디드로우 억제 게이트 — 무력화 트랩 인덱스의 suppresses_companion_body_hit 단일 스위치 구현체). satiety/affinity 참조 0건. 새 설계 §4 수납 계약도 이 라우터 계층 위에서 동작한다. | godot/scripts/lingpet/lingpet_skill_companion_surface_router.gd.uid; godot/scripts/lingpet/lingpet_skill_runtime_host.gd; godot/scripts/lingpet/lingpet_skill_dispatcher.gd | high |
| godot/scripts/lingpet/lingpet_skill_companion_surface_router.gd.uid | ?? | 라우터 .gd와 함께 커밋 | surface router의 UID 페어 파일. | godot/scripts/lingpet/lingpet_skill_companion_surface_router.gd | high |
| godot/scripts/lingpet/lingpet_skill_launch_feedback_router.gd | ?? | 커밋 보존 | 펫 스킬 발사 사운드 큐 선택·폴백 우선순위 라우터(스킬 종류별 SFX 디스패치). 전 스킬 공용 인프라이며 구 진행 시스템 결합 없음. §4 수납 시 루프 오디오 정리 계약과도 인접한 오디오 배선 기반. | godot/scripts/lingpet/lingpet_skill_launch_feedback_router.gd.uid; godot/scripts/lingpet/lingpet_skill_runtime_host.gd; godot/scripts/lingpet/lingpet_skill_dispatcher.gd | high |
| godot/scripts/lingpet/lingpet_skill_launch_feedback_router.gd.uid | ?? | 라우터 .gd와 함께 커밋 | launch feedback router의 UID 페어 파일. | godot/scripts/lingpet/lingpet_skill_launch_feedback_router.gd | high |

### 링펫 오디오 owner 분리(전투) (3건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/game_audio_lingpet_combat_audio_owner_smoke.gd | ?? | 커밋 — lingpet_combat_audio 모듈과 페어 랜딩; 'affinity_level_up' 큐 엔트리 1건은 후 삭제 단계에서 스펙과 함께 제거 | 신설 lingpet_combat_audio(스킬/알히트/링대쉬 등 전투 SFX owner)의 씰. 모듈·씰 모두 A 인프라. 스펙 목록의 affinity_level_up 큐만 교감 레벨업(C-운명) 잔재로, 후 삭제 시 owner 스펙과 씰 목록에서 같이 지우면 됨. | godot/scripts/audio/lingpet_combat_audio.gd; godot/scripts/audio/game_audio.gd(파사드); godot/tests/game_audio_lingpet_combat_audio_owner_smoke.gd.uid | high |
| godot/tests/game_audio_lingpet_combat_audio_owner_smoke.gd.uid | ?? | 동반 커밋 (uid 사이드카) | 쌍이 되는 .gd 스모크의 uid 사이드카. | godot/tests/game_audio_lingpet_combat_audio_owner_smoke.gd | high |
| godot/tests/lingpet_bone_barrier_skill_smoke.gd | M | 커밋 — lingpet_combat_audio 추출과 동일 커밋 | 델타는 본 배리어 빌드 큐 단언을 game_audio에서 lingpet_combat_audio owner로 재조준. 오디오 owner 추출(A)의 정합 편집. 라호세트 계열 스킬 자체도 신설계에서 생존. | godot/scripts/audio/lingpet_combat_audio.gd; godot/tests/game_audio_lingpet_combat_audio_owner_smoke.gd | high |

### 수호령 용어 리브랜드 (3건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_audio_dispatcher.gd | M | 커밋 | 주석 1줄 링펫알→수호령 알 리네임뿐. 알 히트 SFX 경로는 새 설계에서도 그대로 쓰인다. |  | high |
| godot/scripts/lingpet/lingpet_collection_state.gd | M | 커밋 | 주석 1줄 리네임뿐(링코어 언급은 기존 주석의 잔존 문구로 코드 변경 아님). 컬렉션/슬롯 상태는 새 설계의 로스터 3마리 기반으로 생존. |  | high |
| godot/scripts/lingpet/lingpet_egg_field_state.gd | M | 커밋 | 주석 1줄 리네임뿐. 알 히트/부화 판정 로직은 새 설계 §2(공 2~4회 부화)의 직접 기반. |  | high |

### 수호령 리브랜딩(표시명) (3건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/character_info_lingpet_card_specs_smoke.gd | M | 커밋 — 프레젠터의 수호령 라벨 변경과 같은 커밋으로 랜딩 | 델타는 빈 pet id 기본 라벨 '링펫'→'수호령' 단언 1건. CLAUDE.md 표준 용어(수호령) 정착 작업으로 개편과 무관하게 보존. 씰 대상(스킬 레일/해금 프로젝션)은 신설계에서도 생존. | character_info_overlay_lingpet_card_specs(수호령 라벨 헝크); character_info_overlay_lingpet_presenter | high |
| godot/tests/lingpet_onimaru_debug_l2d_smoke.gd | M | 커밋 — 카탈로그 '방망깨비' 리네임과 동일 커밋 | 델타는 오니마루→방망깨비 표시명 단언 1건. 한국 신화무협 리브랜딩 작업으로 개편과 무관하게 보존. | godot/scripts/lingpet/lingpet_catalog.gd(방망깨비 리네임) | high |
| godot/tests/lingpet_thunder_orb_skill_smoke.gd | M | 커밋 — 카탈로그 '벼락여우' 리네임과 동일 커밋 | 델타는 루미온→벼락여우 표시명 단언 1줄 추가. 리브랜드 작업으로 보존. 루미온 낙뢰 스킬 자체는 SEALED 생존 자산. | godot/scripts/lingpet/lingpet_catalog.gd(벼락여우 리네임) | high |

### 링펫 오디오 owner 분리(획득) (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/game_audio_lingpet_acquisition_audio_owner_smoke.gd | ?? | 커밋 — lingpet_acquisition_audio 모듈과 페어 랜딩 | 신설 lingpet_acquisition_audio(컷인·클릭 리액션 백킹 SFX owner)의 씰. 획득 컷인 오디오는 강화 연출 레일(§8)로 신설계 재사용. | godot/scripts/audio/lingpet_acquisition_audio.gd; godot/scripts/audio/game_audio.gd(파사드); godot/tests/game_audio_lingpet_acquisition_audio_owner_smoke.gd.uid | high |
| godot/tests/game_audio_lingpet_acquisition_audio_owner_smoke.gd.uid | ?? | 동반 커밋 (uid 사이드카) | 쌍이 되는 .gd 스모크의 uid 사이드카. | godot/tests/game_audio_lingpet_acquisition_audio_owner_smoke.gd | high |

### 링펫 ungated idle 코디네이터 분리 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/battle_lingpet_ungated_idle_coordinator_owner_smoke.gd | ?? | 커밋 — 코디네이터 모듈과 페어 랜딩 | 신설 battle_lingpet_ungated_idle_coordinator(물리 정지 중 부화 브레이크/컷인/오버플로 idle 펌프)의 owner 씰. §5의 '물리 완전 정지 + ungated idle 펌프' 강화 연출이 이 인프라를 그대로 요구. | godot/scripts/core/battle_lingpet_ungated_idle_coordinator.gd; godot/tests/battle_lingpet_ungated_idle_coordinator_owner_smoke.gd.uid | high |
| godot/tests/battle_lingpet_ungated_idle_coordinator_owner_smoke.gd.uid | ?? | 동반 커밋 (uid 사이드카) | 쌍이 되는 .gd 스모크의 uid 사이드카. | godot/tests/battle_lingpet_ungated_idle_coordinator_owner_smoke.gd | high |

### 링펫 오버레이 프레젠터 분리 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/battle_lingpet_overlay_presenter_owner_smoke.gd | ?? | 커밋 — 프레젠터 모듈과 페어 랜딩 | 신설 battle_lingpet_overlay_presenter(획득 컷인/오버플로 오버레이 드로 위임)의 owner 씰. 획득 컷인 호스트는 §8에서 수호령강화 연출로 재사용되는 레일이라 신설계에도 필수. | godot/scripts/core/battle_lingpet_overlay_presenter.gd; godot/tests/battle_lingpet_overlay_presenter_owner_smoke.gd.uid | high |
| godot/tests/battle_lingpet_overlay_presenter_owner_smoke.gd.uid | ?? | 동반 커밋 (uid 사이드카) | 쌍이 되는 .gd 스모크의 uid 사이드카. | godot/tests/battle_lingpet_overlay_presenter_owner_smoke.gd | high |

### 빠나몽 포효 스킬 포팅 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_wild_roar_renderer.gd | ?? | 커밋 보존 | 빠나몽 포효(wild roar) 충격파/스크린 플래시/파티클 렌더러. 링펫 스킬 포팅 묶음, 구 진행 시스템 결합 없음. | godot/scripts/lingpet/lingpet_wild_roar_renderer.gd.uid; godot/scripts/lingpet/lingpet_wild_roar_skill.gd | high |
| godot/scripts/lingpet/lingpet_wild_roar_renderer.gd.uid | ?? | 렌더러 .gd와 함께 커밋 | wild_roar 렌더러의 UID 페어 파일. | godot/scripts/lingpet/lingpet_wild_roar_renderer.gd | high |

### 썬더오브 스킬 렌더러 분리 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_thunder_orb_renderer.gd | ?? | 커밋 보존 | 썬더오브 스킬의 파티클/아크 VFX 렌더러(색상 팔레트 상수 + 드로우). 구 진행 시스템 결합 없음. | godot/scripts/lingpet/lingpet_thunder_orb_renderer.gd.uid; godot/scripts/lingpet/lingpet_thunder_orb_skill.gd | high |
| godot/scripts/lingpet/lingpet_thunder_orb_renderer.gd.uid | ?? | 렌더러 .gd와 함께 커밋 | thunder_orb 렌더러의 UID 페어 파일. | godot/scripts/lingpet/lingpet_thunder_orb_renderer.gd | high |

### 컴패니언 스킬 컨트롤러 분리 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_companion_skill_update_context_builder_smoke.gd | M | 커밋 — lingpet_companion_skill_controller 슬롯틱 이관과 동일 커밋 | 델타는 업데이트 컨텍스트 조립 소유권을 egg 런타임에서 스킬 컨트롤러로 옮긴 추출의 정합 단언. 순수 리팩터 인프라. | godot/scripts/lingpet/lingpet_companion_skill_controller.gd; godot/scripts/lingpet/lingpet_egg_runtime.gd | high |
| godot/tests/lingpet_skill_runtime_surface_smoke.gd | M | 커밋 — 스킬 컨트롤러 슬롯틱 이관과 동일 커밋 | 델타는 strike request 소비 단언을 런타임에서 컨트롤러 소유 슬롯틱으로 재조준. 추출(A) 정합 씰. | godot/scripts/lingpet/lingpet_companion_skill_controller.gd; godot/scripts/lingpet/lingpet_skill_runtime_surface.gd | high |

### 링펫 발사 피드백 라우터 분리 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_skill_launch_feedback_router_smoke.gd | ?? | 커밋 — 라우터 모듈과 함께 보존 | lingpet_skill_launch_feedback_router.gd(스킬 발사 SFX 라우팅, get_cached_instance 비인스턴스화 peek 준수) 씰. 펫 스킬 오디오 인프라로 신설계 보존 대상. | godot/scripts/lingpet/lingpet_skill_launch_feedback_router.gd; godot/scripts/lingpet/lingpet_skill_runtime_host.gd; godot/tests/lingpet_skill_launch_feedback_router_smoke.gd.uid | high |
| godot/tests/lingpet_skill_launch_feedback_router_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_skill_launch_feedback_router_smoke.gd | high |

### 링펫 컴패니언 표면 라우터 분리 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_skill_companion_surface_router_smoke.gd | ?? | 커밋 — 라우터 모듈과 함께 보존 | lingpet_skill_companion_surface_router.gd(위치 오버라이드·바디히트/드로우 억제·스트라이크 요청·캐스트 포즈 라우팅) 씰. 신설계 §4 수납 상태 계약이 바디히트 억제/companion_active fold 인프라를 그대로 소비하므로 필수 보존 인프라. satiety 커플링 0건. | godot/scripts/lingpet/lingpet_skill_companion_surface_router.gd; godot/scripts/lingpet/lingpet_skill_runtime_host.gd; godot/tests/lingpet_skill_companion_surface_router_smoke.gd.uid | high |
| godot/tests/lingpet_skill_companion_surface_router_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_skill_companion_surface_router_smoke.gd | high |

### 루미온 낙뢰 포팅 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_solar_bolt_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_solar_bolt_renderer/_skill 쌍 씰(루미온 낙뢰 포팅 트랙, SEALED 상태). 펫 스킬은 신설계 보존 대상. | godot/scripts/lingpet/lingpet_solar_bolt_renderer.gd; godot/scripts/lingpet/lingpet_solar_bolt_skill.gd; godot/tests/lingpet_solar_bolt_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_solar_bolt_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_solar_bolt_renderer_smoke.gd | high |

### 빠나몽 포효 포팅 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_wild_roar_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_wild_roar_renderer/_skill 쌍 씰(빠나몽 포효 포팅 트랙). 펫 스킬은 신설계 보존 대상. | godot/scripts/lingpet/lingpet_wild_roar_renderer.gd; godot/scripts/lingpet/lingpet_wild_roar_skill.gd; godot/tests/lingpet_wild_roar_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_wild_roar_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_wild_roar_renderer_smoke.gd | high |

### 오로샤 별똬리 포팅 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_star_coil_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_star_coil_renderer/_skill 쌍 씰(오로샤 별똬리 포팅 트랙). 펫 스킬은 신설계 보존 대상. | godot/scripts/lingpet/lingpet_star_coil_renderer.gd; godot/scripts/lingpet/lingpet_star_coil_skill.gd; godot/tests/lingpet_star_coil_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_star_coil_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_star_coil_renderer_smoke.gd | high |

### 라호세트 모래감옥 포팅 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_sand_prison_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_sand_prison_renderer/_skill 쌍 씰(라호세트 모래감옥 포팅 트랙). 펫 스킬은 신설계 보존 대상. | godot/scripts/lingpet/lingpet_sand_prison_renderer.gd; godot/scripts/lingpet/lingpet_sand_prison_skill.gd; godot/tests/lingpet_sand_prison_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_sand_prison_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_sand_prison_renderer_smoke.gd | high |

### 컴패니언 수비 상태 owner 분리(링크포트 이중수비 기반) (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_companion_defense_state_owner_smoke.gd | ?? | 커밋 — defense state/motion state 모듈과 페어 랜딩 | 신설 lingpet_companion_defense_state(예측 가드 상태 owner)와 motion state 호환 표면의 씰. 방어 인터셉트는 신설계에서 소환 중 그대로 동작하는 생존 기능이고, 링크포트 이중수비 재구현의 기반 모듈. 수납 시 정지는 companion_active fold로 처리되므로 모듈 자체는 보존. | godot/scripts/lingpet/lingpet_companion_defense_state.gd; godot/scripts/lingpet/lingpet_companion_motion_state.gd; godot/tests/lingpet_egg_runtime_smoke.gd(링크포트 이중수비 레그); godot/tests/lingpet_companion_defense_state_owner_smoke.gd.uid | high |
| godot/tests/lingpet_companion_defense_state_owner_smoke.gd.uid | ?? | 동반 커밋 (uid 사이드카) | 쌍이 되는 .gd 스모크의 uid 사이드카. | godot/tests/lingpet_companion_defense_state_owner_smoke.gd | high |

### 링펫 오디오 owner 분리(클릭 보이스) (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/game_audio_lingpet_click_voice_owner_smoke.gd | ?? | 커밋 — lingpet_click_voice_audio 모듈과 페어 랜딩 | 신설 lingpet_click_voice_audio(11펫 클릭 리액션 보이스 owner)의 씰. 클릭 리액션 보이스는 플레이버 자산으로 신설계에서도 생존(삭제되는 것은 클릭 '교감 포인트' 지급이지 보이스가 아님). | godot/scripts/audio/lingpet_click_voice_audio.gd; godot/scripts/audio/game_audio.gd(파사드); godot/tests/game_audio_lingpet_click_voice_owner_smoke.gd.uid | high |
| godot/tests/game_audio_lingpet_click_voice_owner_smoke.gd.uid | ?? | 동반 커밋 (uid 사이드카) | 쌍이 되는 .gd 스모크의 uid 사이드카. | godot/tests/game_audio_lingpet_click_voice_owner_smoke.gd | high |

### 링펫 스킬 런타임 코디네이터 분리 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_companion_skill_runtime_coordinator_smoke.gd | ?? | 커밋 — 코디네이터 모듈과 함께 보존 | lingpet_companion_skill_controller.gd(스킬 윈드업/발사/prewarm/is_launch_blocked 생존맵 조율)를 봉인하는 씰. 신설계에서도 펫 스킬 런타임은 그대로 쓰이며 satiety/affinity 커플링 grep 0건. | godot/scripts/lingpet/lingpet_companion_skill_controller.gd; godot/tests/lingpet_companion_skill_runtime_coordinator_smoke.gd.uid | high |
| godot/tests/lingpet_companion_skill_runtime_coordinator_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | Godot UID 사이드카. 짝 .gd와 같은 커밋으로 이동. | godot/tests/lingpet_companion_skill_runtime_coordinator_smoke.gd | high |

### 코요라 퍼펫 그랩 스킬 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_puppet_grab_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_puppet_grab_renderer/_skill 쌍 씰. 보스-패들 스크립팅 스킬(퍼펫 그랩) VFX로 신설계에서도 보존. | godot/scripts/lingpet/lingpet_puppet_grab_renderer.gd; godot/scripts/lingpet/lingpet_puppet_grab_skill.gd; godot/tests/lingpet_puppet_grab_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_puppet_grab_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_puppet_grab_renderer_smoke.gd | high |

### 코요라 인형저주 스킬 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_doll_curse_renderer_smoke.gd | ?? | 커밋 — 렌더러/스킬 모듈 쌍과 함께 보존 | lingpet_doll_curse_renderer.gd + lingpet_doll_curse_skill.gd 드로우 페이로드 씰. 펫 스킬 VFX는 신설계에서 전량 보존 대상(14마리 로스터 유지). | godot/scripts/lingpet/lingpet_doll_curse_renderer.gd; godot/scripts/lingpet/lingpet_doll_curse_skill.gd; godot/tests/lingpet_doll_curse_renderer_smoke.gd.uid | high |
| godot/tests/lingpet_doll_curse_renderer_smoke.gd.uid | ?? | 커밋 — .gd와 동반 | UID 사이드카, 짝 .gd와 동반 커밋. | godot/tests/lingpet_doll_curse_renderer_smoke.gd | high |

### 컴패니언 방어 인터셉트 상태 분리 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_companion_defense_state.gd | ?? | 소비자 lingpet_companion_motion_state.gd + 전용 owner 스모크와 함께 보존 커밋 | 지상펫 방어 인터셉트 상태기계(결정 타이머·per-opportunity 롤 락 defense_last_roll·가드 오라)를 motion_state에서 분리한 신규 owner 모듈. 신설계도 방어 인터셉트와 방어율(수호령강화 버프)을 유지하고 §4가 롤 락 보존을 명시하므로 존치 인프라. 주의: 내부 _player_can_block은 정지 스팬 판정 — 링크포트 대쉬-투영 수정은 별도 모듈이므로 이 파일 커밋과 별개로 정산 필요. | godot/scripts/lingpet/lingpet_companion_motion_state.gd; godot/tests/lingpet_companion_defense_state_owner_smoke.gd; godot/tests/lingpet_egg_runtime_smoke.gd; godot/scripts/lingpet/lingpet_companion_defense_state.gd.uid | high |
| godot/scripts/lingpet/lingpet_companion_defense_state.gd.uid | ?? | 짝 .gd와 동반 커밋 | UID 사이드카. | godot/scripts/lingpet/lingpet_companion_defense_state.gd | high |

### 코요라 인형조종 스킬 렌더러 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_puppet_grab_renderer.gd | ?? | 커밋 보존 | 코요라 퍼핏그랩(보스 패들 스크립팅 스킬)의 VFX 렌더러 — 실/당김/CHU/끊김 연출 상수와 드로우만 담당. 구 진행 시스템 참조 없음. 새 설계에서 펫 스킬 유지. | godot/scripts/lingpet/lingpet_puppet_grab_renderer.gd.uid; godot/scripts/lingpet/lingpet_puppet_grab_skill.gd | high |
| godot/scripts/lingpet/lingpet_puppet_grab_renderer.gd.uid | ?? | 렌더러 .gd와 함께 커밋 | puppet_grab 렌더러의 UID 페어 파일. | godot/scripts/lingpet/lingpet_puppet_grab_renderer.gd | high |

### 링펫 스킬 렌더러 분리 (달궤도 스킬) (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_moon_orbit_renderer.gd | ?? | 커밋 보존 | 무상태(stateless) 스킬 VFX 렌더러 — 궤도 필드/투사체/버스트 드로우만 담당. 포만도·친밀도·링코어 참조 0건 확인. 새 설계에서도 펫 스킬은 전부 살아남는다. | godot/scripts/lingpet/lingpet_moon_orbit_renderer.gd.uid; godot/scripts/lingpet/lingpet_moon_orbit_skill.gd | high |
| godot/scripts/lingpet/lingpet_moon_orbit_renderer.gd.uid | ?? | 렌더러 .gd와 함께 커밋 | moon_orbit 렌더러의 UID 페어 파일. 소유 .gd와 동일 판정. | godot/scripts/lingpet/lingpet_moon_orbit_renderer.gd | high |

### 링펫 스킬 렌더러 추출 (코요라 인형저주) (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_doll_curse_renderer.gd | ?? | M lingpet_doll_curse_skill.gd(타 청크)와 함께 보존 커밋 | 인형저주 시트(4x4) draw 순수 추출 렌더러. 짝 스킬 모듈 M 위임 파사드와 동반 필수. | godot/scripts/lingpet/lingpet_doll_curse_skill.gd; godot/scripts/lingpet/lingpet_doll_curse_renderer.gd.uid | high |
| godot/scripts/lingpet/lingpet_doll_curse_renderer.gd.uid | ?? | 짝 .gd와 동반 커밋 | UID 사이드카. | godot/scripts/lingpet/lingpet_doll_curse_renderer.gd | high |

### 링펫 스킬 렌더러 추출 (볼티 개틀링) (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_gatling_burst_renderer.gd | ?? | M lingpet_gatling_burst_skill.gd(타 청크)와 함께 보존 커밋 | 탱크 변신 시트(25f) draw 순수 추출 렌더러. 짝 스킬 모듈 M 위임 파사드와 동반 필수. | godot/scripts/lingpet/lingpet_gatling_burst_skill.gd; godot/assets/sprites/lingpet/volty_gatling_tank_transform.png; godot/scripts/lingpet/lingpet_gatling_burst_renderer.gd.uid | high |
| godot/scripts/lingpet/lingpet_gatling_burst_renderer.gd.uid | ?? | 짝 .gd와 동반 커밋 | UID 사이드카. | godot/scripts/lingpet/lingpet_gatling_burst_renderer.gd | high |

### 해골궁수 스킬 렌더러 분리 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_skeleton_archer_renderer.gd | ?? | 커밋 보존 | 해골궁수 소환 스킬의 무상태 렌더러('Stateless renderer' 주석 명시, 런타임 컬렉션은 스킬 소유·차용만). 구 진행 시스템 결합 없음. | godot/scripts/lingpet/lingpet_skeleton_archer_renderer.gd.uid; godot/scripts/lingpet/lingpet_skeleton_archer_skill.gd | high |
| godot/scripts/lingpet/lingpet_skeleton_archer_renderer.gd.uid | ?? | 렌더러 .gd와 함께 커밋 | skeleton_archer 렌더러의 UID 페어 파일. | godot/scripts/lingpet/lingpet_skeleton_archer_renderer.gd | high |

### 소울클론 스킬 렌더러 분리 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_soul_clone_renderer.gd | ?? | 커밋 보존 | 라비 소울클론 스킬 렌더러(rabi_companion_walk.png 텍스처 프리웜 + 클론 드로우). 구 진행 시스템 결합 없음, 프리웜 패턴 준수. | godot/scripts/lingpet/lingpet_soul_clone_renderer.gd.uid; godot/scripts/lingpet/lingpet_soul_clone_skill.gd; godot/assets/sprites/lingpet/rabi_companion_walk.png | high |
| godot/scripts/lingpet/lingpet_soul_clone_renderer.gd.uid | ?? | 렌더러 .gd와 함께 커밋 | soul_clone 렌더러의 UID 페어 파일. | godot/scripts/lingpet/lingpet_soul_clone_renderer.gd | high |

### 루미온 낙뢰 스킬 포팅 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_solar_bolt_renderer.gd | ?? | 커밋 보존 | 루미온 낙뢰(솔라 볼트, SEALED 트랙)의 VFX 렌더러 — 원본 PingFighter 팔레트 이식 주석 포함. 구 진행 시스템 결합 없음. | godot/scripts/lingpet/lingpet_solar_bolt_renderer.gd.uid; godot/scripts/lingpet/lingpet_solar_bolt_skill.gd | high |
| godot/scripts/lingpet/lingpet_solar_bolt_renderer.gd.uid | ?? | 렌더러 .gd와 함께 커밋 | solar_bolt 렌더러의 UID 페어 파일. | godot/scripts/lingpet/lingpet_solar_bolt_renderer.gd | high |

### 라호세트 모래감옥 스킬 포팅 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_sand_prison_renderer.gd | ?? | 커밋 보존 | 라호세트 모래감옥(보스 케이지형 스킬)의 무상태 VFX 렌더러. 링펫 스킬 포팅 묶음의 일부이며 구 진행 시스템 결합 없음. | godot/scripts/lingpet/lingpet_sand_prison_renderer.gd.uid; godot/scripts/lingpet/lingpet_sand_prison_skill.gd | high |
| godot/scripts/lingpet/lingpet_sand_prison_renderer.gd.uid | ?? | 렌더러 .gd와 함께 커밋 | sand_prison 렌더러의 UID 페어 파일. | godot/scripts/lingpet/lingpet_sand_prison_renderer.gd | high |

### 오로샤 별똬리 스킬 포팅 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_star_coil_renderer.gd | ?? | 커밋 보존 | 오로샤 별똬리(star coil) 트레일/스파크 렌더러 + 테스트용 별 정점 헬퍼(get_star_vertices_for_tests). 링펫 스킬 포팅 묶음, 구 진행 시스템 결합 없음. | godot/scripts/lingpet/lingpet_star_coil_renderer.gd.uid; godot/scripts/lingpet/lingpet_star_coil_skill.gd | high |
| godot/scripts/lingpet/lingpet_star_coil_renderer.gd.uid | ?? | 렌더러 .gd와 함께 커밋 | star_coil 렌더러의 UID 페어 파일. | godot/scripts/lingpet/lingpet_star_coil_renderer.gd | high |

### egg_runtime god-module 분해 (스킬 컨트롤러) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_companion_skill_controller.gd | M | egg_runtime 위임 헝크와 반드시 함께 커밋 | egg_runtime의 액티브 슬롯 갱신 루프를 controller.update_active_slots로 추출(+173줄). idle-게이트/컨텍스트 빌더를 흡수한 일반 인프라. companion_exhausted 파라미터는 새 설계에서 수납 fold로 재사용될 접점. | godot/scripts/lingpet/lingpet_egg_runtime.gd (호출측 위임 + 콜백 API); lingpet_companion_skill_effect_update_gate.gd; lingpet_companion_skill_update_context_builder.gd | high |

### 부동갑주 넉백 커버 복원 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_bomb_surprise_skill.gd | M | 부동갑주 트랙과 함께 커밋 | 볼탄 자폭의 플레이어 스턴+넉백에 PlayerKnockbackImmunity(부동갑주) 게이트를 추가한 6사이트 배선의 일부 + 주석 리네임. 진행 시스템 삭제와 무관한 아이템 런타임 수정. | godot/scripts/stages/common/player_knockback_immunity.gd; 부동갑주 넉백 커버 씰 5종 | high |

### 수호령 용어 리브랜드 + 알 전통 디자인 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_catalog.gd | M | 알 아트 에셋·egg_field_renderer와 함께 커밋 | 카피 리네임(링펫→수호령, 게이지→기력, 코만도→호란)과 14펫 알 비주얼을 guardian_spirit_egg_traditional 공유 상수로 통일. 카탈로그·14로스터는 새 설계에서 전량 보존. 삭제 대상 데이터 변경 없음. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_*.png; godot/scripts/lingpet/lingpet_egg_field_renderer.gd; 다국어 카피 동기 | high |

### 알 전통 디자인 + 크랙 오버레이 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_egg_field_renderer.gd | M | guardian_spirit_egg 에셋·카탈로그와 함께 커밋 | 알 변형/크랙 PNG 경로를 resonance_egg→guardian_spirit_egg_traditional로 스왑. 알 부화 시스템은 새 설계의 획득 흐름 핵심(§2)이라 그대로 필요. | godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_variant_*_v1.png; guardian_spirit_egg_traditional_crack_stage_*_v1.png; godot/scripts/lingpet/lingpet_catalog.gd | high |

### egg_runtime 분해 + 포만도 추출 + 링크포트/벽력유성 배선 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_egg_runtime.gd | M | 파일 전체 단일 커밋 (헝크 분리 불가 — 링크포트 콜사이트가 탈진 fold 안) | A 헝크(스킬 컨트롤러 위임, 링크포트 대쉬투영 스냅샷 peek, 벽력유성 우클릭 소유권, 리네임)와 B 성격 헝크(satiety 로직의 LingpetSatietyRuntimeState 추출, 탈진 companion_active fold — §8 지속시간 엔진/수납 계약의 추출 원본)가 섞여 있으나 폐기 대상 헝크는 0건이라 결정은 전부 '커밋'으로 단일하다. satiety 추출 커밋은 오히려 새 설계의 레일 추출을 선행해 준다. ⚠️정정(폐기감사): A_keep_commit→A_keep_commit. diff 헝크 헤더 21개 전수 + 최대 satiety 헝크(@@ -3076,67) 실확인: _advance_satiety/_get_satiety_speed_scale/드레인 배율 로직이 신규 LingpetSatietyRuntimeState(_satiety_runtime_state.advance_active/latch_penalty_exempt)로 위임 추출됨 — 정확히 계획 §8 '지속시간 엔진 리네임 추출'의 선행 작업. 추가로 diff의 + 라인 grep에서 interact/교감 포인트 수입 배선 0건 확인. 폐기 대상 헝크가 없어 전 헝크 커밋 방향 일치 — A 유지, medium→high 승격. / 정정(정합감사): A_keep_commit→A_keep_commit. medium→high 상향. git diff 실측(148+/163-)으로 분류 근거를 전부 확인: (1) affinity/satiety를 건드리는 삭제 라인은 전부 _affinity_state 직접 호출을 LingpetSatietyRuntimeState 위임으로 바꾸는 추출 헝크(§8 '지속시간 소모/회복 엔진 리네임 추출'의 선행 작업과 정확히 일치), (2) 폐기 대상 헝크 0건 확인 — 교감 interact 코드(try_begin_companion_interact_reaction)는 delta가 아니라 HEAD에 이미 커밋되어 있음(git show HEAD 1건, diff 0건), (3) 스킬 컨트롤러 위임·리네임 헝크도 전부 커밋 방향 일치. '섞였지만 결정은 단일 커밋'이라는 원 판정이 실측으로 뒷받침되므로 사용자 리뷰 대상(low/medium)에서 빼도 안전하다. | godot/scripts/lingpet/lingpet_satiety_runtime_state.gd (??); godot/scripts/lingpet/lingpet_companion_skill_controller.gd; godot/scripts/lingpet/lingpet_ring_dash_state.gd; godot/scripts/lingpet/lingpet_mount_state.gd; smasher_dash_state/smasher_overdrive_state 레지스트리 캐시 | high |

### 소켓 합성 계약 (탑승 carry) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/assets/sprites/lingpet/onimaru_companion_carry_idle_25f.png.import | ?? | 이미 커밋된 짝 PNG의 import 메타로 커밋 | 짝 PNG onimaru_companion_carry_idle_25f.png는 이미 트래킹(커밋)됨 — import 메타만 untracked로 남은 상태. 소켓 합성/탑승 트랙 자산이며 신설계와 무관하게 필요. | godot/assets/sprites/lingpet/onimaru_companion_carry_idle_25f.png (committed); godot/scripts/lingpet/lingpet_catalog.gd | high |

### 수호령 지속시간 대개편 기획 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| docs/lingpet_guardian_duration_redesign_plan.md | ?? | 최우선 커밋 — 개편의 기획 정본 | 이번 개편의 authoritative 스펙 문서 자체(코덱스 리뷰 v1 + R3 충돌 검사 반영본). 정산의 기준 문서이므로 가장 먼저 커밋. |  | high |

### 컴패니언 수비 상태 추출 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_companion_motion_state.gd | M | 신규 defense_state와 페어로 커밋 | 방어 인터셉트 튜닝 상수·런타임을 lingpet_companion_defense_state.gd로 추출하고 프로퍼티 포워딩으로 호환 유지. 방어 인터셉트는 새 설계에서 소환 중 그대로 동작하는 핵심 기능. | godot/scripts/lingpet/lingpet_companion_defense_state.gd (??); 링크포트/수비 관련 스모크 | high |

### 액티브 아이템 쿨다운 상태 모듈 추출 + AIDBG 스캐폴드 제거 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/items/active_item_slot_controller.gd | M | 커밋 보존 — ActiveItemSlotCooldownState 신규 모듈과 한 묶음 | 글로벌/퍼아이템 쿨다운·모달 일시정지·스테이지 전환 리셋 로직을 ActiveItemSlotCooldownState로 위임하고, 진단용 _AIDBG print 스캐폴드를 제거하는 순수 리팩터. 수호령 헝크 0건. 새 설계의 심령수도 이 슬롯 경로를 그대로 쓰므로 보존 가치 명확. | godot/scripts/items/active_item_slot_cooldown_state.gd (신규 모듈); 액티브 아이템 슬롯 관련 focused 스모크 | high |

### 무협 리브랜딩 (아이템 개명 + 신규 아이콘 경로) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/items/active_item_catalog.gd | M | 커밋 보존 — 참조하는 신규 아이콘 PNG/.import와 반드시 동반 커밋 | 델타 전체가 리브랜딩: 표시명/설명 무협 교체(탕약·오색약수·경신단·진뢰탄·환광탄·폭렬화통·열화병·거신단·원기탕·금강결계·축지부·신령환), 아이콘 경로를 신규 리브랜드 에셋으로 스왑, 알 아이콘을 guardian_spirit_egg_traditional_item_icon_v1로 교체. 피딩 4종 빌더는 문구 리브랜드만(추후 심령수로 대체·삭제 대상이나 델타 자체는 무해). 알 아이템은 새 설계에서 핵심 존속이므로 알 아이콘 스왑은 명확히 보존 가치. | godot/assets/sprites/items/ 하위 신규 리브랜드 아이콘 PNG+.import (shinryeonghwan/tangyak/osaek_yaksu/gyeongsinhwan/jinroe_tan/hwangwangtan/pokryeol_hwatong/yeolhwabyeong/geosindan/wongitang/geumgang_barrier/chukjibu); godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_item_icon_v1.png(+.import); godot/scripts/core/language_settings_data.gd | high |

### 시스템 입력 라우터 추출 (F11/BGM/우스틱 억제) — 새 설계 R3 carve-out 앵커 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/core/battle_system_shortcut_input_router.gd | ?? | 커밋 보존 — 새 설계 착수 전 선커밋 필수 (R3 토글의 수정 대상 파일) | 신규 추출 모듈(F11 풀스크린, B BGM 토글, 우스틱→휠 억제). 범용 인프라이면서 동시에 새 설계의 직접 의존: 재설계 정본 §4가 이 파일 58행 should_suppress_right_stick_event를 앵커로 guardian_toggle(R3) 버튼 프레스 carve-out을 요구 — 실제 58행과 정확히 일치, 계획이 이 WIP 파일 기준으로 작성됨. 이 파일이 커밋되지 않으면 R3 슬라이스의 전제가 사라진다. | godot/scripts/core/battle_scene_input_controller.gd (호출자); godot/scripts/core/gamepad_input.gd (should_suppress_right_stick_event); godot/tests/battle_system_shortcut_input_router_owner_smoke.gd (페어 스모크) | high |

### 전투 입력 라우터 추출 (스킬 툴팁 사이클·코만도 무기 스왑) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/core/battle_combat_shortcut_input_router.gd | ?? | 커밋 보존 — 호출자·스모크와 3점 세트로 커밋 | 신규 추출 모듈: 스킬 오브 툴팁 게임패드 사이클(Shift/그립 스타일 분기)과 코만도 무기 전환 이벤트 라우팅만 담당. 수호령 코드 0건, 범용 입력 인프라. | godot/scripts/core/battle_scene_input_controller.gd (호출자); godot/tests/battle_combat_shortcut_input_router_owner_smoke.gd (페어 스모크) | high |

### 런타임퍽 모듈 분리 (파이프라인 스테이트 추출) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/characters/runtime_perk_state.gd | M | 커밋 보존 — 신규 pipeline-state 모듈들과 한 묶음으로 | 1186줄 델타 전부가 퍼사드 분해 리팩터: choice/unlock 파이프라인, 융합·주사위·엔젤블레싱 런타임을 RuntimePerkChoicePipelineState / RuntimePerkUnlockPipelineState / RuntimePerkFusionRuntimeState / RuntimePerkMysticDiceRuntimeState / RuntimePerkAngelBlessingRuntimeState / RuntimePerkDisplayProjectionState로 위임. 수호령 관련 헝크 0건 (diff grep 확인). | godot/scripts/characters/runtime_perk_choice_pipeline_state.gd; godot/scripts/characters/runtime_perk_unlock_pipeline_state.gd; godot/scripts/characters/runtime_perk_display_projection_state.gd; godot/scripts/characters/runtime_perk_fusion_runtime_state.gd; godot/scripts/characters/runtime_perk_mystic_dice_runtime_state.gd; godot/scripts/characters/runtime_perk_angel_blessing_runtime_state.gd; 관련 focused 퍽 스모크들 | high |

### 한국 신화무협 리브랜딩 (무공 용어집 카피 패스) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/characters/runtime_perk_catalog.gd | M | 커밋 보존 — 리브랜딩 카피 패스, 새 설계와 무관하게 유지 | 델타 전체가 퍽 이름/설명 무협 용어 교체(경량화→회기보, 대쉬→활주, 퍽→무공 등)와 확장 퍽 레거시 이름 보정 1줄. 유일한 수호령 영역 헝크는 LINGPET_AFFINITY_CHIP_PERK(강화칩) 설명의 링펫→수호령 용어 교체뿐인데, 이는 신기능이 아니라 리브랜드 문구이고 해당 블록은 어차피 4단계에서 통째로 삭제되므로 커밋해도 무해. | godot/scripts/core/language_settings_data.gd (퍽 이름 다국어 동기); 퍽 툴팁/카드 렌더러 (표시명 소비자) | high |

### 다국어 데이터 — 리브랜딩·신령환·오버드라이브·주사위 혼합 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/core/language_settings_data.gd | M | 커밋 보존 — 전 헝크가 보존 트랙, 단 커밋 메시지용 헝크 분리는 사실상 불가 | 3064줄 델타가 여러 트랙 혼합이나 전부 보존 대상: ① 환격전 무협 리브랜딩 7언어(활주/기력/무공, 아이템·보스·스킬 개명, 난이도 수련/격전/극한/초월, 링펫→수호령/Guardian Spirit) ② 신령환(AI알약 개명) ③ 스매셔 오버드라이브 신규 키 ④ mystic_dice 신규 키 ⑤ hud.active_item.* 신규 키. 순수호령 구시스템 문자열(피딩 4종, 강화칩, 교감 E키(RT) 툴팁, 포만도 툴팁)은 리브랜드 문구 교체만 받았고 net-new 키 감사로 구시스템 신규 문자열 0건 확인 — 4단계 일괄 삭제(~57줄×7언어) 전까지 표시 일관성을 위해 커밋이 맞다. ⚠️정정(폐기감사): A_keep_commit→A_keep_commit. 구시스템 키워드(lingpet_affinity_chip·피딩 4종·교감/포만도 툴팁)의 + 라인에 대응하는 - 라인 15건을 diff에서 실확인 — 추가분은 전부 리브랜드 키/문구 교체(치환)이며 구시스템 net-new 문자열 0건 주장이 사실로 검증됨. 4단계 일괄 삭제 전까지 7언어 표시 일관성을 위해 커밋이 맞다 — A 유지, medium→high 승격. | godot/scripts/characters/runtime_perk_catalog.gd (퍽 이름 정합); godot/scripts/items/active_item_catalog.gd (아이템 표시명 정합); language_settings 소비 UI 전반 | high |

### 프레임 컨트롤러 모듈 분리 (14 코디네이터/프레젠터 추출) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/core/battle_scene_frame_controller.gd | M | 커밋 보존 — 새 설계가 재사용하는 컷인 호스트 경로의 추출 리팩터 | 907줄 델타 전부가 퍼사드 분해: 드라이브 컷인, 물리 게이트, 스테이지 전환, 터미널 오버레이, 튜토리얼, 링펫 오버레이 처리를 14개 신규 Battle* 모듈로 이동. 링펫 헝크(획득 컷인/오버플로/ungated idle)는 기존 동작의 순수 이동이며, 획득 컷인 오버레이 호스트는 새 설계 §8이 강화 연출로 명시 재사용하는 인프라 — 오히려 새 설계에 필요. | godot/scripts/core/battle_lingpet_overlay_presenter.gd; godot/scripts/core/battle_lingpet_ungated_idle_coordinator.gd; godot/scripts/core/battle_drive_cutin_presenter.gd; godot/scripts/core/battle_physics_gate_coordinator.gd; godot/scripts/core/battle_modal_pause_runtime_state.gd; godot/scripts/core/battle_stage_transition_frame_coordinator.gd; godot/scripts/core/battle_terminal_overlay_idle_coordinator.gd 등 신규 코디네이터 14종; 계약 상수를 읽는 focused 스모크들 | high |

### 벽력유성 우클릭 소유권 × 수호령 탑승 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_mount_state.gd | M | 벽력유성 재설계·egg_runtime 헝크와 함께 커밋 | 탑승 토글의 맨 우클릭을 스매셔 벽력유성(우클릭 홀드 무장)과 공유하는 input_blocked 계약 문서화+주석 갱신. 탑승(소켓 합성 lane C)과 벽력유성 둘 다 새 설계와 무관하게 생존. | godot/scripts/lingpet/lingpet_egg_runtime.gd (_is_right_click_claimed_by_player_skill); 벽력유성(smasher overdrive) 상태 모듈 | high |

### 빠나몽 포효 포팅 + 오디오/컨트롤러 분리 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_wild_roar_skill_smoke.gd | M | 커밋 — lingpet_combat_audio·스킬 컨트롤러 추출과 동일 커밋 | 델타는 Wild Roar 사운드 단언을 combat_audio owner PLAYER_SPECS로, 컨텍스트 조립 단언을 스킬 컨트롤러로 재조준. 포효 스킬 포팅 번들(A)의 추출 정합 씰. | godot/scripts/audio/lingpet_combat_audio.gd; godot/scripts/lingpet/lingpet_companion_skill_controller.gd | high |

### 링펫 스킬 렌더러/오디오 owner 분리 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_skeleton_archer_skill_smoke.gd | M | 커밋 — skeleton_archer 렌더러·combat_audio·피드백 라우터 추출과 동일 커밋 | 델타는 비주얼 레이어 단언을 신설 렌더러로, 이벤트 오디오 단언을 lingpet_combat_audio owner와 런치 피드백 라우터로 재조준. 전부 추출(A) 정합 씰. | godot/scripts/lingpet/lingpet_skeleton_archer_renderer.gd; godot/scripts/audio/lingpet_combat_audio.gd; godot/scripts/lingpet/lingpet_skill_launch_feedback_router.gd | high |

### 링펫 스킬 렌더러 분리 (물방울 스킬) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_hydro_sphere_renderer.gd.uid | ?? | hydro_sphere 렌더러 .gd와 함께 커밋 | 펫 액티브 스킬 VFX 렌더러의 UID 파일. 새 설계는 14마리 로스터·스킬 자산 전부 보존이 전제라 스킬 렌더러는 무조건 유지. UID는 소유 .gd(타 청크)와 반드시 동행. | godot/scripts/lingpet/lingpet_hydro_sphere_renderer.gd; godot/scripts/lingpet/lingpet_hydro_sphere_skill.gd | high |

### 플라자 씬 분해(메시지 포매터) × 링코어 상점 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/plaza_lingpet_store_menu_smoke.gd | M | 커밋 (plaza_transaction_message_formatter 추출 정합에 필수) → 후 삭제 단계에서 링코어 상점 행과 함께 해당 씰 함수 정리 | 델타 헝크는 전부 링코어 UI 메시지 단언을 plaza_scene에서 신설 메시지 포매터로 재조준한 리팩터 정합 편집 — 폐기하면 A 버킷인 플라자 분해 커밋이 RED. 단 씰이 봉인하는 링코어 구매 행 자체는 §7에 따라 후 삭제 대상(추출 레일 아님)이므로 삭제 슬라이스에서 씰 재작성 필요. ⚠️정정(폐기감사): A_keep_commit→A_keep_commit. diff 전문(8줄) 실확인: 링코어 UI 메시지 단언 소스를 plaza_scene.gd→plaza_transaction_message_formatter.gd로 재조준한 정합 편집만 존재(신규 링코어 기능 헝크 0건). 폐기 시 A 버킷인 메시지 포매터 추출 커밋이 RED. 링코어 구매 행 자체의 삭제(§7)는 후 삭제 슬라이스의 씰 재작성으로 처리 — A 유지, medium→high 승격. | godot/scripts/plaza/plaza_transaction_message_formatter.gd; godot/scripts/plaza/plaza_lingpet_store_transactions.gd | high |

### 디버그 숏컷 라우터 분리 + 리브랜드 표시명 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_debug_picker_smoke.gd | M | 커밋 — battle_debug_menu_shortcut_router 추출 및 카탈로그 '살각시' 리네임과 동일 커밋 | 델타 2종 모두 보존 가치: F7 숏컷의 라우터 위임(입력 라우터 추출)과 코요라→살각시 리브랜드 표시명 단언. 둘 다 개편과 무관한 A 작업. | godot/scripts/core/battle_debug_menu_shortcut_router.gd; godot/scripts/lingpet/lingpet_catalog.gd(살각시 리네임) | high |

### 소켓 합성 계약 (탑승 상태) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_mount_state.gd.uid | ?? | lingpet_mount_state.gd(타 청크)와 함께 커밋 | 탑승(mount) 상태 모듈의 UID 파일. 소켓 합성 계약 트랙(S1~S3 완결)의 일부로 진행 시스템 삭제와 무관한 컴패니언 모션 인프라. egg_runtime이 직접 인스턴스화(line 157)하는 살아있는 소비자 확인. | godot/scripts/lingpet/lingpet_mount_state.gd; godot/scripts/lingpet/lingpet_egg_runtime.gd | high |

### 에그 런타임 분해 + 링크포트 이중수비 + 탈진 억제 씰 + 전통 알 아트 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_egg_runtime_smoke.gd | M | 커밋 — 링크포트 이중수비 레그와 탈진 억제 레그는 헝크 분리 불가이므로 동반 커밋(메모리 확인 사항), 탈진 레그는 §8 수납 계약의 추출 원본 씰로 보존 | 델타 구성: (1) 링크포트 대쉬-투영 4레그+대조군(신설계 필요 A), (2) 탈진 중 별빛추적/링크포트 억제 씰(companion_active fold — §8에서 수납 상태 계약으로 그대로 재사용되는 추출 원본, B가치지만 권장 동일=커밋), (3) 수많은 추출 정합 단언(스킬 컨트롤러·priority/interaction 입력 라우터·오디오 3-owner·스타포인트 스테이지 상태), (4) guardian_spirit_egg 전통 알 아트 스왑+크랙 오버레이 경로, (5) 수호령 리브랜드 카피. 전 헝크가 커밋 방향으로 일치. | godot/scripts/lingpet/lingpet_egg_runtime.gd; godot/scripts/lingpet/lingpet_companion_skill_controller.gd; godot/scripts/core/battle_lingpet_priority_input_router.gd; godot/scripts/core/battle_lingpet_interaction_input_router.gd; godot/scripts/audio/lingpet_acquisition_audio.gd; godot/scripts/audio/lingpet_click_voice_audio.gd; godot/scripts/audio/lingpet_combat_audio.gd; godot/scripts/lingpet/lingpet_egg_field_renderer.gd; godot/assets/sprites/lingpet/guardian_spirit_egg_traditional_* 에셋; stage1~4 starpoint state 모듈 | high |

### 알 부화 넉백+크랙 오버레이 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_egg_crack_capture_smoke.gd | M | 커밋 — 주석 리브랜드(수호령 알) 1줄, 리브랜드 웨이브에 동승 | 델타는 헤더 주석의 링펫알→수호령 알 용어 교체뿐. 씰 자체(크랙 PNG 픽셀 캡처)는 A 번들(알 부화 크랙 오버레이)의 봉인으로 신설계에서도 알 시스템이 유지되므로 보존. | godot/scripts/lingpet/lingpet_egg_field_renderer.gd | high |

### 스킬 런타임 호스트 라우터 분해 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_skill_runtime_host.gd | M | 신규 라우터 2종과 페어로 커밋 | launch_origin/포지션 오버라이드/바디히트 억제 등의 거대 match 체인을 companion_surface_router·launch_feedback_router로 추출(-421줄). 스킬 호스트는 새 설계의 idle-게이트 생존맵 소유자로 핵심 생존 모듈. | godot/scripts/lingpet/lingpet_skill_companion_surface_router.gd (??); godot/scripts/lingpet/lingpet_skill_launch_feedback_router.gd (??) | high |

### 링펫 렌더러 추출 (루미온 낙뢰) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_solar_bolt_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_solar_bolt_renderer.gd로의 순수 렌더러 추출. 낙뢰 포팅 트랙(SEALED)의 후속 정리. | godot/scripts/lingpet/lingpet_solar_bolt_renderer.gd (??) | high |

### 링크포트 이중수비 재구현 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_ring_dash_state.gd | M | egg_runtime 콜사이트·씰 4레그와 함께 커밋 (라이브QA 잔여) | 대쉬 커밋 중 플레이어의 접촉 시점 위치를 shipped 감속 커브(compute_total_dash_distance 차분)로 투영해 이중수비를 막는 재구현 — 새 설계에서도 방어 인터셉트가 생존하므로 필수 수정. 트랩 백필까지 완료된 트랙. | godot/scripts/characters/smasher_dash_active_motion_resolver.gd; godot/scripts/lingpet/lingpet_egg_runtime.gd (_resolve_player_dash_state + 탈진 fold 콜사이트); 링크포트 씰 스모크 4레그 | high |

### 링펫 렌더러 추출 (라호세트 모래감옥) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_sand_prison_skill.gd | M | 신규 렌더러와 페어로 커밋 | lingpet_sand_prison_renderer.gd로의 순수 렌더러 추출. 모래감옥 스킬 포팅 트랙의 일부로 새 설계에서 보존. | godot/scripts/lingpet/lingpet_sand_prison_renderer.gd (??) | high |

### 링펫 스킬 렌더러 추출 (루미온 낙뢰) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_thunder_orb_skill.gd | M | 렌더러 신규 파일과 한 커밋으로 보존 커밋 | 동일 렌더러 추출 패턴 (60삽입/414삭제 3파일 중 최대분). draw_orb/explosion/mini_spark를 lingpet_thunder_orb_renderer.gd로 위임, 잔여 헝크(@@-604,227 / @@-832,10)는 이동된 draw 코드+데드 폴백(_draw_boss_electric_stun) 순수 삭제 확인. 행동 변경 없음. | godot/scripts/lingpet/lingpet_thunder_orb_renderer.gd; godot/scripts/lingpet/lingpet_thunder_orb_renderer.gd.uid | high |

### 링펫 스킬 렌더러 추출 (빠나몽 포효) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_wild_roar_skill.gd | M | 렌더러 신규 파일과 한 커밋으로 보존 커밋 | 동일 렌더러 추출 패턴 — _draw_screen_flash/_draw_roar_zone/_draw_particles/_draw_ball_glow를 lingpet_wild_roar_renderer.gd로 이동, draw()는 위임 호출만. 개편과 무관한 범용 인프라 리팩터. | godot/scripts/lingpet/lingpet_wild_roar_renderer.gd; godot/scripts/lingpet/lingpet_wild_roar_renderer.gd.uid | high |

### 링펫 스킬 렌더러 추출 (오로샤 별똬리) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_star_coil_skill.gd | M | 렌더러 신규 파일과 한 커밋으로 보존 커밋 | diff 전체가 draw 코드의 전용 렌더러(lingpet_star_coil_renderer.gd) 위임 파사드 추출 — _draw_motion_trail/_draw_sparks/_draw_star 삭제 + prewarm/draw 위임만. 신설계는 14펫 스킬 자산 전부 보존(계획 §0)이므로 개편과 무관한 범용 리팩터. | godot/scripts/lingpet/lingpet_star_coil_renderer.gd; godot/scripts/lingpet/lingpet_star_coil_renderer.gd.uid | high |

### 소켓 합성 계약 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_mount_state_smoke.gd.uid | ?? | 커밋 — 이미 커밋된 mount_state 씰의 누락 사이드카 보충 | 짝 .gd(lingpet_mount_state_smoke.gd)는 ea5622cc6로 이미 커밋됨(소켓 합성/탑승 트랙). UID 사이드카만 누락된 고아 — 단독 커밋으로 보충. | godot/tests/lingpet_mount_state_smoke.gd | high |


## B. 신규 설계로 추출 후 삭제할 레일 (커밋 보존 = 추출 원본) — 7건

### 포만도 시스템+튜닝 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_satiety_runtime_state.gd | ?? | 커밋 보존 (추출 원본) → 지속시간 엔진 추출 후 삭제 | 포만도 런타임 상태기계 fold 모듈 — 드레인 배율(소식가 최대 -60%), advance_satiety/advance_satiety_exhaustion 구동, 리그 면제 래치(penalty_exempt). 정확히 새 설계 §8의 '지속시간 소모/회복 엔진(리네임 추출)' + §7 '리그 면제 래치 패턴 계승'의 추출 원본이다. affinity_state에 위임하는 얇은 fold라 추출 시 시그니처가 그대로 레일이 된다. | godot/scripts/lingpet/lingpet_satiety_runtime_state.gd.uid; godot/scripts/lingpet/lingpet_egg_runtime.gd; godot/scripts/lingpet/lingpet_affinity_state.gd | high |
| godot/scripts/lingpet/lingpet_satiety_runtime_state.gd.uid | ?? | satiety 상태 .gd와 함께 커밋 보존 → 추출 후 동반 삭제 | satiety 런타임 상태 모듈의 UID 페어 파일. 소유 .gd와 운명 공동. | godot/scripts/lingpet/lingpet_satiety_runtime_state.gd | high |

### 포만도 튜닝 (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_satiety_runtime_state_owner_smoke.gd | ?? | 커밋 보존 (추출 원본) → 지속시간 엔진 추출 시 씰 동반 이식 후 삭제 | lingpet_satiety_runtime_state.gd(드레인/휴식회복 배율·탈진 텔레그래프·오토프레젠트 리그 면제)를 봉인하는 씰 — 계획 §8의 지속시간 소모/회복 엔진 및 §7 리그 면제 래치의 추출 원본 바로 그것. 씰은 레일 리네임 이식과 함께 이동해야 함. | godot/scripts/lingpet/lingpet_satiety_runtime_state.gd; godot/scripts/lingpet/lingpet_affinity_state.gd; godot/tests/lingpet_satiety_runtime_state_owner_smoke.gd.uid | high |
| godot/tests/lingpet_satiety_runtime_state_owner_smoke.gd.uid | ?? | 커밋 보존 — .gd와 동반, 추출 후 함께 삭제 | UID 사이드카, 짝 .gd(포만도 상태 owner 씰)와 운명 공유. | godot/tests/lingpet_satiety_runtime_state_owner_smoke.gd | high |

### 교감 보상카드 덱 라벨 정비 (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/lingpet/lingpet_affinity_state.gd | M | 커밋 보존 (추출 원본) → 수호령강화 이식 후 삭제 | diff는 보상카드 라벨 '게이지 강화'→'기력 강화' 리네임뿐. 보상카드 덱(REWARD_TYPE_*, CANONICAL_REWARD_TRACK)은 새 설계 §8에서 수호령강화 버프 저장으로 트리거만 교체해 그대로 이식되므로 라벨 문구 튜닝이 추출 레일에 그대로 실린다. | 수호령강화 버프 저장 신규 owner(추출 대상); 보상카드 UI 소비자; 다국어 카피 동기 | high |

### 포만도 피딩 아이템(→심령수 추출 원본) (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/lingpet_feed_active_item_smoke.gd | M | 커밋 보존 (plaza_shop_transactions 분해 정합 + 심령수 추출 원본) → 심령수 이관 후 삭제/재작성 | 델타는 상점 구매 라우팅 단언을 plaza_scene에서 plaza_shop_transactions로 재조준한 리팩터 정합 편집. 씰 본문은 피딩 4종 스폰 게이트·상점 재고·가격(§8: 피딩 스폰 게이트+아이콘 배선 → 심령수 레일). 델타 폐기 시 plaza 분해 커밋과 어긋나 RED. ⚠️정정(폐기감사): B_extract_rail→B_extract_rail. diff 전문(4줄) 실확인: 상점 구매 라우팅 단언 소스를 plaza_scene.gd→plaza_shop_transactions.gd로 재조준한 플라자 분해 정합 편집뿐. 피딩 4종 스폰/재고/가격 씰 본문은 §8 '피딩 스폰 게이트+아이콘 배선→심령수' 추출 원본. 델타 폐기 시 plaza 분해 커밋 RED — B 유지, medium→high 승격. | godot/scripts/plaza/plaza_shop_transactions.gd; godot/scripts/plaza/plaza_shop_stock.gd; godot/scripts/plaza/plaza_shop_pricing.gd | high |

### 링펫 포만도·교감 캐릭터정보창 UI (1건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/tests/character_info_lingpet_satiety_bar_smoke.gd | M | 커밋 보존 (프레젠터 수호령 카피와 동기) → 지속시간 게이지 재라벨/교감 바 삭제 시 씰 재작성 | 델타는 교감/포만도 바 툴팁 문구의 링펫→수호령 동기화뿐이나, 씰 본문이 TAB 포만도/교감 바(구 시스템)를 봉인 — §8에서 포만도 HUD 스트립은 지속시간 게이지로 재라벨되는 추출 레일이고 교감 바는 삭제 대상. 델타를 버리면 프레젠터 카피 변경과 어긋나 RED. ⚠️정정(폐기감사): B_extract_rail→B_extract_rail. diff 전문(4줄) 실확인: '링펫과 쌓은 교감'→'수호령과 쌓은 교감', '링펫의 포만도'→'수호령의 포만도' 툴팁 원문 단언 동기화뿐. 프레젠터의 수호령 카피 변경과 페어라 폐기 시 프레젠터 커밋이 RED. 씰 본문은 포만도 스트립(§8 지속시간 게이지 재라벨 레일) 봉인 — B 유지, medium→high 승격. | character_info overlay lingpet presenter(draw_affinity_status 카피) | high |


## C. 완전 폐기 가능한 구설계 전용 WIP — 0건


## D. 혼합 헝크 — 사용자 판단 필요 — 2건

### 멀티펫 L사이클+교감 E/RT 키 (혼합) (2건)

| 파일 | 상태 | 권장 처리 | 근거 | 의존성 | 확신도 |
|---|---|---|---|---|---|
| godot/scripts/core/battle_lingpet_interaction_input_router.gd | ?? | 사용자 결정: 전체 커밋 후 4단계에서 interact 섹션 삭제 vs 커밋 전에 interact 섹션 트림 | 보존 헝크 = handle_priority_cutin_input(부화 셸브레이크/컷인 입력 스왈로우, §8 재사용 대상) + _handle_companion_click(클릭 리액션, 코스메틱 유지) + _handle_slot_switch·LINGPET_CYCLE_KEY(멀티펫 L사이클, 3마리 로스터 유지로 계속 필요). 폐기 헝크 = LINGPET_INTERACT_KEY(E)·LINGPET_INTERACT_TRIGGER_*(RT)·_lingpet_interact_trigger_latched·_handle_companion_interact·_is_lingpet_interact_key_event·_consume_lingpet_interact_trigger_edge = §1 삭제 대상인 교감 E+RT 본드 키(RT는 신설계에서 수호령 토글 불승인까지 받은 입력). 호출자(battle_scene_input_controller)는 집계 함수 handle_companion_input만 부르므로 interact 트림은 이 파일 내부 편집만으로 가능. | godot/scripts/core/battle_scene_input_controller.gd(호출자, 타 청크); battle_lingpet_interaction_input_router.gd.uid; lingpet_egg_runtime.try_begin_companion_interact_reaction(폐기측 callee); lingpet_egg_runtime.cycle_lingpet_slot(보존측 callee) | high |
| godot/scripts/core/battle_lingpet_interaction_input_router.gd.uid | ?? | 부모 .gd 결정을 따름 (파일 자체는 커밋 시 동반) | uid 사이드카 — 부모 라우터의 D 결정에 종속. 파일이 어떤 형태로든 커밋되면 uid도 함께 간다. | battle_lingpet_interaction_input_router.gd | high |
