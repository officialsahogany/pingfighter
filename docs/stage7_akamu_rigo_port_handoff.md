# Stage 7 아카무 리고 포팅 — 세션 핸드오프

다른 머신(데스크탑)에서 이어서 작업하기 위한 세션 브리프.
작성일: 2026-07-10 · 작성 시점 브랜치: `fix/plaza-lingpet-egg-full-roster-test`

---

## 1. 한 줄 요약

원본 PingFighter **Python Stage 8 (아카무 리고, 그림자 닌자)** 를 Godot **Stage 7**
로 포팅하기 위한 **조사 + 기획이 완료**된 상태. 산출물은 기획서 1개이며 **코드는
아직 한 줄도 수정하지 않았다** (구현 미착수).

## 2. 산출물 / 파일 상태

| 파일 | 상태 |
|---|---|
| `docs/stage7_akamu_rigo_port_plan.md` | ✅ 작성 완료 + 코덱스 리뷰 4건 교정 반영 완료. **untracked (미커밋)** — 이 세션은 커밋하지 않았음 |
| `docs/stage7_akamu_rigo_port_handoff.md` | 본 문서 |
| `godot/` 코드 | 변경 없음. stage7/akamu 스캐폴딩은 여전히 0개 |

> 이 레포는 커밋되지 않은 WIP가 많은 dirty worktree가 정상 상태다. 기획서 2개
> 파일만 이번 세션 산출물이므로, 커밋한다면 `docs(stage7): 아카무 리고 포팅 기획`
> 류로 이 2개만 스코프해서 커밋할 것.

## 3. 스코프 결정 (사용자 확정)

- **Godot Stage 7 = Python Stage 8** (테트리서 Godot6=Python7 선례와 동일 패턴).
- 코드/자산 prefix: `stage7_akamu_*`.
- **필러 배경 아트 + 인게임 필드(내부) 그림은 신규 작화 예정 → 원본 아트 포팅
  제외.** 단 런타임 슬롯/훅(필러 득점 반응 `trigger_excitement` 인터페이스,
  배경 placeholder 모듈 골격)은 포팅 범위.

## 4. 기획서를 신뢰해도 되는 근거 (검증 상태)

기획서의 핵심 수치는 에이전트 조사 후 **원본 코드를 직접 재확인**했다:
- 스킬 상수 블록 `pingfighter.py:63402-63521` (STAGE8_* 전부)
- 게이지 수급 +80/+90/+20 및 그림자 25% / 구름 35% 트리거 (`handle_ball` @173771-173823)
- 초각성 3점 트리거 + 극정호신 발동 조건 (`handle_boss` @178119-178153)
- 분신 게이지 -100은 **시전 완료 시점 1회** 차감 (`update_stage8_shadow_clones`)
- intangible 3창 (`handle_ball` @173655-173680)
- 표창 피격: 클렌즈 면역 시 슬로우+게이지드레인 **동시** 차단 (`update_stage8_shurikens`)
- 리셋 트랩: `reset_round()` @165755-165786 은 `current_stage != 8` 일 때만 정리
- 🔴 게이지 라운드 이월: `go_to_next_round()` @76315-76322 에서 **×0.7 (30% 감소)**
- `BOSS_CONFIGS[8]` AI 스탯 (`config/stage_configs.py:130`)

## 5. 코덱스 리뷰 교정 반영 이력 (기획서에 이미 반영됨)

1. **게이지 라운드 이월** — "전량 유지"가 아니라 ×0.7 이월. §2.0/§4/§9/§10-1 교정.
2. **`battle_effects_update_controller.gd` per-frame tick 누락** — 체크리스트 #5로
   추가 (stage6은 :93-102에서 `state.update(delta, context, effect_deps)` +
   `_merge_score_context`). 누락 시 표창/구름/오오라/극정호신 타이머 전부 정지.
3. **볼 경로 round deps 누락** — 체크리스트 #9로 추가:
   `ball_dependency_context.gd` `get_stage_round_dep_keys()` case 7 +
   `ball_round_actor_cleanup.gd` 의 `reset_round()` 호출. state는
   `reset_round()`(awakened 유지·게이지 ×0.7·transient 정리) / `reset()`(전체
   초기화) 분리 노출.
4. **하드코딩 리스트 스모크 갱신 대상 추가** — `refactor_status_brief_smoke.gd`
   `STAGE_ROUTE_EXPECTATIONS`(:58), `lingpet_rail_card_shared_smoke.gd`
   `_verify_all_stage_rails_wire_shared_helper`(:430). 후자는 stage7 HUD 렌더러의
   lingpet 카드 공유 헬퍼 위임 **계약**이기도 함 (§8에 명시).

## 6. 다음 단계 (기획서 §11 슬라이스 순서)

착수 전에 **§12 결정 필요 항목**을 사용자와 확정할 것. 특히:
1. 보스 스프라이트 소스 — 원본 시트 재사용 vs **AutoSprite 7종 신규 생성(권장)**.
   원본 세트는 hit이 `stage9hit2.png` 차용 + idle/stun 부재.
2. 극정호신 밸런스 — 원본 충실(10초 사실상 완봉)이 기본값, 조정 시 명시 기록.
3. 라운드 간 transient 정리 — 원본 잔존은 버그로 판정, 무조건 정리가 기본 방침.
4. 인트로 비디오 / JRPG 대화(멘헤라걸 스토리 연결 대사) 취급.

결정 후 슬라이스 1(스캐폴딩: 피커 8→7, `DEMO_STAGE_SEQUENCE_END=7`, 라우터/
카탈로그/deps/prewarm 배선 + 빈 모듈 7종 + wiring 스모크)부터 진행.

## 7. 이어받는 에이전트 주의사항

- 구현 전 반드시 `docs/stage7_akamu_rigo_port_plan.md` 전문을 읽을 것 — 통합
  체크리스트 22항목(§5), 크로스컷 계약 9종(§6), 리셋 규칙(§9), 스모크 계획(§10)
  이 전부 그 문서에 있다.
- 이 레포 규칙: 반증검증은 in-place Edit 토글로만, **`git reset`/`checkout`/`stash`
  금지** (`docs/agent_operating_posture.md`).
- CLAUDE.md "Legacy Stage Order Reference" 섹션의 Stage 7 매핑 행 추가는
  **구현 착수 시점**에 갱신 (테트리서 §13 선례 — 기획 단계에서는 미변경).
- 원본 조사에서 나온 정리 항목: 서브타이틀 "심해 : 어둠의 끝"은 잔재 — 신규 아트
  브리프에 섞지 말 것 (테마 = 닌자 저택/그림자, 기획서 §0).
