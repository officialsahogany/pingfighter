# 스매셔 신규 액티브 스킬 "오버드라이브" — 코덱스 배선 핸드오프

작성: Opus (기획·설계·트랩 브리프). 배선: Codex. 비주얼: Opus.
분담 원칙: **기능+기술+코딩(런타임 배선) = Codex / 비주얼적 구현(VFX·컷인·아이콘 렌더) = Opus.**
루트 문서: `docs/character_skill_perk_checklist.md` (전 경로 배선 소스오브트루스).

---

## 0. ⚠️ 착수 전 반드시 해결할 OPEN 아이템 2개

1. **이름 충돌 — 스킬 id는 `smasher_overdrive` 로 고정.**
   `overdrive` 는 이미 **링펫 링코어 퍽**이 점유 중이다
   (`godot/assets/sprites/perks/lingpet_ring_core_overdrive_perk_icon.png`,
   `godot/scripts/characters/runtime_perk_catalog.gd`,
   `godot/scripts/hud/runtime_perk_icon_renderer.gd`). 런타임 스킬 id =
   `smasher_overdrive`, 언락 퍽 id = `unlock_smasher_overdrive`. 짧은 `overdrive`
   문자열을 어떤 레지스트리/딕셔너리 키로도 재사용하지 말 것. 한글 표시명
   "오버드라이브"는 시스템이 달라 공존 가능하나, 배선 중 문자열 매칭이 링펫 퍽과
   섞이지 않는지 확인.

2. **입력 조합 충돌 감사 — 락 전 필수.**
   스매셔 입력 공간이 이미 포화(더블클릭·더블탭·S홀드·A-W-D/D-W-A 휠·←+→ 점유).
   후보: **S 더블탭** 또는 **↓ + 우클릭**. 공유 입력 리더
   `get_snapshot()` 엣지 소비 트랩(CLAUDE.md "Shared Stateful Input-Reader
   Edge-Eating Trap") 때문에, 신규 엣지 게이트가 기존 스매셔 스킬 입력의 엣지를
   먹지 않는지 실제 입력 리더에서 감사한 뒤 확정. 감사 결과를 이 문서에 회신.

   **Codex 감사 결과 (2026-07-13): `↓/S + 우클릭`으로 확정.** `S` 더블탭은
   워프게이트의 `S/↓` 홀드와 코어 대시의 아래 방향 입력에 시간창 충돌을 만든다.
   우클릭은 스매셔 런타임에서 비어 있으며, `secondary_action_just_pressed`를 기존
   물리 프레임 스냅샷 캐시에 넣어 다중 소비자 호출에도 같은 에지를 반환한다.
   스킬 잠금·Stage 3 스턴 입력 프록시도 이 필드를 명시적으로 차단한다.

수치(코스트/쿨/공속/지그재그 파라미터)는 사용자의 "첨부 요청을 읽고 실행" 지시에
따라 §1 제안값을 구현 기준으로 채택했다. 후속 플레이테스트 조정은 데이터 상수만
바꾸면 되며 런타임 소유권·id 계약은 유지한다.

---

## 1. 스킬 정체성 + 수치 (제안, 조정 가능)

**정체성:** 5초간 패들이 과부하 상태가 되어, 이 창 동안 되받아친 공이 **각지게
꺾이는 폭주 궤도**로 날아가고 공속이 상승한다. 게이지를 직접 태우는 스매셔 유일의
자원-연소 스킬. 드라이브(매끈한 스핀 커브)·AI 알약(접촉마다 무한누적 공속)과
정체성 축이 겹치지 않음.

| 항목 | 제안값 | 비고 |
|---|---|---|
| 런타임 스킬 id | `smasher_overdrive` | §0-1 충돌 회피 |
| 언락 퍽 id | `unlock_smasher_overdrive` | 언락 카드용 |
| 한글 표시명 | 오버드라이브 | |
| 코스트 | 280 게이지 | 휠(200)~고스트 사이 |
| 쿨다운 | 28초 | 강버프 창 |
| 지속 | **5초 = 360f @ 72 Hz (프레임 기반)** | ⚠️월클럭 아님 — 모달 자연 일시정지 |
| 공속 | 창 유지 중 **+30% 플랫**, 상한 26→30 **한시** 상향, 종료 시 자기치유 회수 | ⚠️**캡 있음** — 알약의 무한누적 금지 |
| 지그재그 | 12프레임마다 base_heading 기준 ±28° 교대, 최소 vy 가드 | 튜닝 대상 |
| slot_occupancy | `active_orb` | 5-orb 예산 점유 |
| cooldown_reduction_eligible | `true` | transcendent_crown/sage_ring 적용 |
| cleanup_policy | `perk_id_lookup` | `_CHARACTER_UNLOCK_PERKS["smasher"]` 역매핑 |

**알약과의 결정적 분리선:** 공속을 "접촉마다 무한누적"으로 만들면 그 순간 알약과
동일 기능이 된다. 반드시 **창 동안 캡 있는 플랫 버프**로 배선.

---

## 2. 지그재그 = 공 미소유 속도 필드 (물리 스펙)

**절대 규칙: 공을 소유하지 않는다.** `skip_ball_motion_step` 미사용, `ball_vel`
제로화 없음. 정상 `step_motion`(패들·벽·바닥·보스·배리어 충돌)이 계속 돌게 두고
**속도 벡터의 방향만 주기적으로 꺾는다.** 이로써 CLAUDE.md의 소유-공 트랩군
(skip_motion_step 스턱, 홀리베리어 통과, update_effects-only 일시정지 릴리스 소실
등)을 통째로 회피한다.

메커니즘:
- 활성 시 `overdrive_active=true`, 창 프레임 카운터 세팅, 현재 공 진행 방향을
  `base_heading`(정규화 방향벡터)로 캡처.
- **base_heading 갱신:** 패들/벽/바닥/보스에 바운스할 때마다 반사된 새 방향으로
  갱신. (핵심 배선 과제 — 바운스 이벤트 훅. `paddle_bounce_event_router.gd` +
  `ball_frame_motion_controller.gd`의 벽/바닥 반사 지점.) 이래야 지그재그가 반사를
  거스르지 않고 새 진행선 주위로 재정렬됨.
- **꺾임:** `kink_interval`(12f)마다 `zig_sign` 토글, `ball_vel =
  base_heading.rotated(zig_sign * kink_angle) * speed`. 회전은 크기를 안 바꾸므로
  공속 보존. 꺾임 사이 직선 구간 → 날카로운 코너.
- **정체 방지 가드:** 회전 후 `|vy|`가 임계 미만이면(공 수평화 → 옆벽 무한
  핑퐁으로 랠리 정지) 최소 수직성분으로 클램프.
- **공속:** `speed = base_speed * 1.30`, 표준 공속 시스템을 통해 적용하되 창 동안만
  캡 30. 무한누적 채널(알약의 `active_item_aipill_ball_boost_active` 류) 사용 금지.

물리 훅 위치(참고): `ball_frame_motion_controller.gd`(프레임 속도),
`paddle_bounce_event_router.gd`(바운스 이벤트), `ball_round_state.gd`(라운드 스냅샷
정규화). 드라이브가 per-hit 바운스만 건드리는 것과 달리 이 스킬은 창 내내 매
프레임 방향을 관리 → 상태를 스킬 update 경로에서 틱.

---

## 3. 런타임 배선 위치 (character_skill_perk_checklist.md 전 경로)

`docs/character_skill_perk_checklist.md`를 열고 아래를 전부 감사:

- **스킬 카탈로그:** `godot/scripts/characters/smasher_skill_config.gd`
  - `SKILL_DATA["smasher_overdrive"]` (name/korean/cost/color/cooldown/description/
    how_to_use/motion_hint/effect_type) — §5 툴팁 계약 준수
  - `SKILL_COSTS` / `COOLDOWN_SECONDS` / `SKILL_COLORS` 추가
  - 영어 로컬라이제이션 블록(파일 하단 match)에도 추가 — [[한글=다국어 동기화]]
  - `EQUIPPED_SKILLS` 기본값에는 **넣지 않음**(언락 스킬). 언락 시 5-orb 슬롯 편입.
- **언락/장착 플로우:** 드라이브 활성 컨트롤러(`smasher_drive_activation_controller.gd`)
  형제 패턴으로 오버드라이브 활성 상태머신 추가. 언락 퍽 처리(`unlock_smasher_overdrive`)
  → 슬롯 풀이면 스왑 다이얼로그, 취소 시 **완전 no-op**(runtime_skill_levels/unlock
  플래그/ownership 어느 것도 성공 전 기록 금지).
- **5-orb 슬롯:** slot_occupancy=`active_orb` 예산 카운트. 슬롯 풀 판정은 공유 슬롯
  점유 총합 기준.
- **쿨다운 감소 스코프:** transcendent_crown/sage_ring 등 오브 쿨감이
  `smasher_overdrive`에도 적용 → 오브 웨지 채움/남은시간 텍스트/툴팁 쿨다운 모두
  **최종 유효 쿨다운** 읽기(raw 상수 금지).
- **스킬 골드 정책:** 오버드라이브가 소유 이벤트(꺾임 히트/보스 히트)를 만드는지
  판단해 명시적 골드 정책 결정. 제로골드는 의도적 선택일 때만. 랠리골드 이중지급
  가드 확인.
- **지속 HUD:** 우하단 공용 가로 타이머 게이지 스택에 5초 창 등록(기존 지속바와
  동일 사이즈/스택/정리 시맨틱).
- **정리(teardown):** 단일 owner `reset()` 하나를 만들고 **라운드리셋 + 결과/게임종료
  + 스테이지이탈** 전 경로에서 호출. `ball_round_state` 공용 스냅샷이
  `overdrive_active=false` 정규화(라운드 경계 넘김 방지). CLAUDE.md 보스스킬 정리
  이중경로 트랩 — go_to_next_round만이 아니라 show_result류 게임종료 경로도 포함.
- **저장/로드/리셋:** 창 활성 플래그가 세션 간 누수 안 되게.

---

## 4. 신호 계약 (Codex ↔ Opus 이음새)

비주얼은 Opus가 담당하므로, Codex는 아래 신호/상태만 **방출**하면 됨:

- `smasher_overdrive_active: bool` — 창 유지 중 true
- `smasher_overdrive_remaining_frames: int` — HUD/페이드용
- **꺾임 이벤트** — 매 kink마다 `{pos: Vector2, heading: Vector2, zig_sign: int}`
  방출(또는 조회 가능한 마지막 꺾임 상태). Opus가 이 이벤트에 잔상/스파크/각진
  트레일을 얹음.
- `smasher_overdrive_ball_boost_active: bool` — 공속 상한 한시 상향 채널(활성시에만
  키 존재 → merge 클로버 방지, 자기치유). 알약의 boost 채널 배선 패턴 참고하되
  **캡 있는** 버전.

Opus 비주얼 산출물(별도 진행): 폭주 공 지그재그 잔상·트레일 렌더, 스킬 컷인
(`skill_cutin_drive_renderer.gd` 형제로 overdrive 컷인), 오브/미니 아이콘 렌더,
타이머 바 외형. **아이콘 PNG 자산 생성 경로는 별도 확정**(imagegen 라우팅) —
배선 측은 렌더러 분기와 로더-우선 경로만 준비.

---

## 5. 툴팁 계약 (5-orb 표준 포맷)

`_draw_smasher_skill_tooltip()` 계열 계약 준수:
- `description`(3줄 max): 효과 + 짧은 플레이버 + 제약. 입력키/쿨다운 recap 금지.
- `how_to_use`: 완결 문장, **`\n` 금지**(non-orb 경로가 단일 render).
- `motion_hint`: 시각/모션 동사 한 줄. 퍽으로 바뀌는 숫자 baking 금지.
- 공속 수치처럼 고정이면 서술 동사로. 지속(5초)은 extension_gear류로 스케일되면
  "일정 기간"으로 추상화.
- 아이콘: draw_skill_icon_mini 상당(Godot `runtime_perk_icon_renderer.gd`)과 오브
  심볼 렌더 **둘 다** 커버. `smasher_overdrive`와 `unlock_smasher_overdrive` 양쪽
  id가 의도 분기에 도달하는지 alias 감사. (Opus가 렌더 채우되, 분기/precedence
  배선은 Codex.)

---

## 6. 씰(스모크) + 반증검증 계획

신규 focused 스모크 `smasher_overdrive_*_smoke.gd`. 반증검증은 in-place Edit/temp
patch/fixture로만(**git reset/checkout/stash 금지** — 이 repo는 미커밋 WIP 보존).
각 불변식이 버그 코드에서 정확히 해당 레그만 RED 나는지 증명:

1. 공 미소유 — skip_ball_motion_step 미사용, ball_vel 제로화 없음
2. 공속 크기 매 프레임 보존 + **캡 준수**, 창 종료 후 표준 캡(26) 자기치유
3. 바운스마다 base_heading 갱신(창 중 바운스 → 새 방향 채택 → 지그재그 재정렬)
4. 정체 방지 최소 vy 가드(꺾은 뒤 |vy| ≥ 임계)
5. 클린 티어다운(라운드리셋/결과/게임종료 각 경로에서 창 클리어, 라운드 경계 넘김
   없음)
6. 지속 프레임 기반(모달 일시정지 창에서 프레임 안 흐름)
7. 쿨다운 감소 유효값이 HUD 3곳(웨지/남은시간/툴팁)에 일치

검증 보고: 스모크 + `run_headless_load_check` + `run_warning_scan`. 그 diff를 Opus가
이 문서 기준 적대적 리뷰.

---

## 7. 진행 순서

1. Codex: §0 OPEN 2건 해결(id 고정 확인 + 입력 충돌 감사 회신)
2. 사용자: §1 수치 사인오프
3. Codex: §3 전 경로 배선 + §4 신호 방출 + §6 씰/반증 → 검증 보고
4. Opus: §4 비주얼(지그재그 트레일·컷인·아이콘) + 배선 diff 적대적 리뷰

---

## 8. 2026-07-14 Opus 적대적 리뷰 회신 / 런타임 결정

- **Finding 1 수정:** `ball_motion_event_processor.gd::step_motion()`의 이벤트
  디스패치가 끝난 뒤 최종 `scene.ball_vel`을 한 번 읽는 중앙 반사 훅으로 통합했다.
  대상은 wall, player/boss paddle, sand terrain, brick wall, trampoline,
  horn-strawberry field, Lingpet bone barrier, holy barrier, adversity armor다.
  Stage 2 득점 백스톱이 실제로 세이브한 경우도 반사로 취급한다. 핸들러별 wall/paddle
  훅은 제거해 이중 갱신을 막았다.
- **Finding 1 씰:** 아래 방향 `base_heading`으로 활성화한 뒤 홀리베리어가 위로
  반사하고, 12 게임 프레임 뒤 첫 kink도 `ball_vel.y < 0`을 유지하는 통합 스모크를
  추가한다. 중앙 집합에서 `holy_barrier`를 임시 제거하는 RED 반증으로 민감도를
  확인한다.
- **Finding 2 결정:** 출하 `project.godot`의 물리 틱은 72 Hz다. 플레이어 계약인
  5초를 유지하기 위해 지속을 300f에서 **360f**로 보정한다. 모달/스턴/임시 변신
  락에서는 프레임 카운터를 소비하지 않는다.
- **스킬골드:** 별도 소유 hit 이벤트가 없는 공 버프이므로 0이 의도다. 기존
  player-paddle 랠리 골드만 지급하며 이중 지급하지 않는다.
- **임시 lock:** 짧은 공용 스턴은 기존에도 컨트롤러 조기 반환으로 창을 멈췄다.
  변신형 `player_skill_input_locked`도 같은 일시정지로 통일한다. 라운드/경기/캐릭터
  교체 및 장착 해제만 창을 종료한다.
- **동시 스킬 우선순위:** 지속적으로 공을 조향하는 Magnum Grip과 60-cap 재발사인
  Smasher Wheel은 Overdrive와 상호 배타다. 어느 한쪽이 활성 중이면 다른 쪽의 신규
  발동을 막는다. Drive spin은 공통 spin 단계가 먼저 현재 벡터를 갱신하고 Overdrive가
  kink 프레임 외에는 그 벡터를 보존하므로 병행을 허용한다.
- **쿨감 HUD:** 발동 시 최종 유효 쿨다운을 `smasher_skill_state`에 저장하고, 오브
  웨지·남은시간·툴팁은 같은 config/state 값을 읽는다. 50% fixture에서 세 경로가
  모두 14초 및 7초 경과 ratio 0.5를 가리키는 스모크로 봉인한다.

이 결정 후 §4 신호의 이름과 payload는 바뀌지 않으므로 Opus 비주얼 작업은 병행 가능하다.
