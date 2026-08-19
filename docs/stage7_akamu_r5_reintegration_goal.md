# 아카무 R5 재이식 /goal 지시문 (2026-08-19)

- **목적**: 격리 브랜치 `codex/stage7-akamu-r5-7eb6`(HEAD `ce1c956ad`)의 R5
  기능 4종을, 본 트리에 새로 착지한 **소유자 모듈 구조 위로 수동 이식**한다.
- **기준 HEAD**: `035cf72e0` 이후 최신. 이 커밋이 아카무 상태를 소유자 모듈로
  분리한 지점이며 이식의 기준점이다.
- **정본 계약**: `docs/stage7_akamu_r5_goal.md`(L0~L5 계약, 씰 계약, TEMP 상수)와
  `docs/stage7_akamu_r5_preflight_audit.md`. 두 문서의 **설계 계약은 그대로
  유효**하며 이 지시문은 **착지 위치만** 바꾼다.
- **판단 근거**: `C:\w\a7r5\docs\stage7_akamu_merge_block_response.md`
  (R5 세션 회신, SHA-256 `0FDC6D06...FC4B`). 소유자별 대상 모듈 표가 그 문서
  Q3에 있고 Fable이 현재 코드와 대조해 타당함을 확인했다.
- **완료 보고**: `docs/stage7_akamu_r5_reintegration_report.md`. 푸시 금지.

## 0. 왜 직접 병합이 아닌가

R5 브랜치는 `stage7_akamu_state.gd`가 **단일 파일이던 시절** 위에서 만들어졌다.
본 트리는 그 파일을 소유자 모듈로 쪼갠 상태이며, 두 blob은 서로 다른 계보다.

- 본 트리 `035cf72e0` 이전 HEAD의 해당 파일 blob = R5 브랜치 기준점의 blob
  (`a7f551ae…`)으로 **동일**했다. 즉 본 트리 WIP은 R5의 복제가 아니라 같은
  베이스에서 갈라진 **별개 작업**이다.
- 따라서 브랜치를 통째로 얹으면 R5의 편집이 이미 사라진 코드 영역을 참조하게
  된다. **직접 merge와 전체 cherry-pick을 금지한다.**

**R5를 버려서도 안 된다.** 아래 4종이 본 트리에 하나도 들어와 있지 않음을
Fable이 코드로 확인했다.

| 항목 | 본 트리 현재 상태 (확인) |
|---|---|
| L1 각성 프리즈 컨텍스트 | 프레임 흐름이 여전히 인자 없이 호출 |
| L2 오오라 충돌 배선 | 볼 스테퍼에 오오라 이벤트 0건 |
| L4 황금 분신·무혼 | 분신에 `golden` 필드 없음, starpoint 파일 없음 |
| L5 궁극기 해금·50초 | `COOLDOWN_SEC := 25.0` 그대로 |

## 1. 착지 순서

R5 지시문의 L0~L5 순서를 유지하되, 각 단계의 **착지 위치를 새 소유자로 옮긴다.**

| 순서 | 내용 | 비고 |
|---|---|---|
| P0 | 실패 문구별 RED 기준선 재고정 | 아래 §4 |
| P1 | L1 각성 프리즈 컨텍스트 | 프레임 흐름 2파일 |
| P2 | L2 오오라 충돌 배선 | 볼 모션 3파일 + 파사드 |
| P3 | L4 황금 분신 + 무혼 캐리어 | 분신 상태 + 신규 starpoint |
| P4 | L5 궁극기 해금 + 50초 | 궁극기 상태 + 파사드 + HUD |
| P5 | 라이브 QA + 캡처 | R5 지시문 §5 그대로 |

## 2. 소유자별 착지 위치

R5 세션 회신 Q3의 지명을 Fable이 현재 코드와 대조해 확정했다.

### P2 오오라 충돌 배선

| 책임 | 착지 위치 |
|---|---|
| 오오라 반경·내구·디바운스·반사 수식 | `stage7_akamu_awakening_state.gd` — **이미 존재. 재복사 금지** |
| 게이지·음향·무료 구름/분신 조정 | `stage7_akamu_state.gd` 파사드 |
| swept substep 충돌 순서, 분신 우선권 | `ball_motion_stepper.gd` |
| step context와 반사 결과 왕복 | `ball_motion_event_processor.gd` |
| 별똬리 pause 스냅샷 | `ball_update_owner_snapshot.gd` |

**핵심**: 수식은 이미 모듈에 보존되어 있다. R5 L2가 복원해야 하는 것은
**볼 모션 호출 경로와 컨텍스트·스냅샷 계약**이다.

### P3 황금 분신과 무혼

| 책임 | 착지 위치 |
|---|---|
| 생성 시 1회 golden 굴림, 엔티티 필드 | `stage7_akamu_clone_state.gd:210 spawn_entities()` |
| 충돌 결과에서 golden·rect 중심 확보 | `stage7_akamu_clone_state.gd:337 query_ball_collision()` |
| 볼 처치와 무혼 생성 조정 | `stage7_akamu_state.gd:841 resolve_ball_collision()` |
| 드랍 생명주기 | 신규 `stage7_akamu_starpoint_state.gd` |
| 황금 분신·무혼 렌더 | `stage7_akamu_playfield_renderer.gd` |

golden 여부와 rect 중심은 `begin_dying()`(`:372`) **호출 전에 확보**한다.
배열을 다시 인덱싱해 판정하는 구조는 금지한다(GRT-030).

### P4 궁극기 해금과 쿨다운

| 책임 | 착지 위치 |
|---|---|
| 50초 단일 상수·tick·종료 후 재사용 | `stage7_akamu_superspeed_state.gd:7 COOLDOWN_SEC` |
| 각성 완료 시 최초 50초 설정, 즉시 체인 제거 | `stage7_akamu_state.gd:618 _complete_awakening()` |
| 각성 전 3장·각성 후 4장 카드 순서 | `stage7_akamu_hud_state_builder.gd` |
| 카드 한국어 카피 | `stage7_akamu_boss_skill_hud_renderer.gd` |
| 7언어 | `language_settings_data.gd` |

**쿨다운 소유자는 각성 상태가 아니라 궁극기 상태다.** 이미
`set_cooldown_remaining()`(`:108`)과 `try_start()`(`:116`)가 그 파일에 있다.
각성 상태는 완료 여부만 반환하고, 파사드가 두 소유자 사이의 전환을 조정한다.

## 3. exact-HEAD 복구 커밋 3종 취급

아래 셋은 **요청 기준 HEAD의 부분 통합 상태를 되살리려고 만든 실행 전제
커밋**이다. 새 구조 위에 통째로 적용하지 마라.

- `46b711127` restore exact-head load contracts
- `218fce0ac` complete exact-head draw contracts
- `16b0674d4` finish exact-head ball draw arities

현재 소비자 계약을 **재감사한 뒤 필요한 hunk만 선택**한다. 어떤 hunk를 왜
채택했고 왜 버렸는지 보고서에 적는다.

## 4. RED 기준선 재고정 (P0, 선행)

⚠ **기존 숫자를 그대로 비교하지 마라.** 세 값이 전부 다르다.

| 출처 | slice5 RED |
|---|---|
| R5 exact-HEAD 실행 기준 | 34건 |
| R5 통합 브랜치 최종 | 24건 |
| 사전 감사 예상치 | 30건 |
| 현재 본 트리(모듈 분리 후) | 약 31건 |

게다가 `stage7_akamu_slice5_smoke.gd` 자체가 본 트리에서 수정된 상태다.
따라서 **실패 건수가 아니라 실패 문구별로** 기준선을 다시 고정하고, 이후
단계마다 어느 문구가 해소됐는지로 보고한다.

## 5. 씰 개정 범위

R5 회신이 지명한 개정 대상이다. 각 항목의 구체 계약은
`docs/stage7_akamu_r5_goal.md` §4를 따른다.

- `stage7_akamu_clone_state_refactor_smoke.gd` — golden 굴림이 생성 시 1회이고
  기존 이동 RNG 소비 **뒤에** 오는지 추가
- `stage7_akamu_awakening_state_refactor_smoke.gd` — 오오라 수식·디바운스 소유 유지
- `stage7_akamu_superspeed_state_refactor_smoke.gd` — 50초 단일 정본, 종료 후
  50초, 라운드 경계 보존
- `stage7_akamu_hud_state_builder_refactor_smoke.gd:67-68` — 현재 4장 고정 기대를
  각성 전 3장 / 각성 후 4장으로 변경
- `stage7_akamu_slice5_smoke.gd:15, :233-264, :664-771` — 25초를 50초로,
  각성 직후 즉시 발동 기대를 최초 50초 잠금으로
- 신규 golden·unlock 씰 — monolith source guard를 분신·궁극기·HUD 빌더 소유자
  경로로 이동
- 신규·개정 씰은 `.github/workflows/godot-ci.yml`과
  `godot/tools/run_pre_push_checks.ps1` **두 리터럴 목록에 동시 등재**

## 6. 규율

- ⚠ **본 트리에 대량 미커밋 WIP이 남아 있다**(수정 1,135건, 미추적 2,486건).
  오버드라이브 계열, 볼 렌더러, 모듈 원장 문서 등이다.
  **격리 워크트리에서 작업하고 `stash`·`checkout`·`reset`·통짜 `git add`
  없이 통합하라.** 통합 직전 본 트리 HEAD와 dirty 범위를 재스냅샷하라.
- 로그 백업 선행. 표준 래퍼 `-AllowDuringPlay`. 커밋 분리·푸시 금지.
- 통과 판정은 배치 종단선 `All Godot smoke tests passed.` + `SCRIPT ERROR` 0건.
- 판정 불가 지점이 나오면 중단·보고.

## 7. 검증

- 단계별 씰 + 타워/스테이지7 회귀 + `-Paths` 경고 + 헤드리스 +
  `git diff --check`.
- **Vulkan 캡처 3장 이상**: 오오라에 공이 튕기는 순간, 황금 분신과 무혼 드랍,
  각성 직후 궁극기가 잠긴 상태의 스킬 카드. 실 해상도(2020x1246).
- 오오라 배선 후 전용 사운드가 실제로 재생되는지 확인.
- 각성 시점 게이지 잔량 라이브 3판 계측표(R5 지시문 L3).

**완료 선언 조건**: P0~P5 구현·검증 + 게이트 blocked/unverified 0건 +
RED 문구별 기준선 대조표 + 보고서 완성. 단계별 중간 보고 허용.
