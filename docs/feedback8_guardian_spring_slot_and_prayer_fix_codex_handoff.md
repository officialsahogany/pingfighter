# 지시문 X1-수정 — [P0] 방문당 1행동 게이트가 첫 수호령 선택까지 닫아 수호령 0마리 런을 만든다

- **발행**: 관제탑 2026-08-26. 대상: 브랜치
  `codex/feedback8-guardian-spring-slot-prayer-20260826`(워크트리
  `D:\codex_tmp\bosspong_feedback8_guardian_x1_0bd1`)의 `8ce16ec88` 위
  **추가 커밋**. amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: **REJECT.** A안(초식 만석 2단 교체) 핵심 수리는 **견고하다**
  (아래 무결 목록 — 재작업 금지). B안 구현이 게이트를 너무 넓게 걸었다.

---

## [P0] F1 — 팜 커밋이 그 방문의 첫 수호령 선택까지 닫는다

### ★관제탑 지시문의 문구도 한몫했다

지시문 B-2가 **"손바닥·기도 중 하나가 커밋되면 나머지 카드도 그 방문에서
닫아라"** 라고 썼다. "나머지 카드"를 **첫 수호령 선택 카드까지** 포함하는 것으로
읽을 여지가 있었다. **의도는 그것이 아니다.** 아래로 확정한다.

> **닫히는 것은 "손바닥"과 "기도" 두 액션 카드뿐이다.**
> **첫 수호령 선택(first_pick)은 손바닥 액션의 연속이지 두 번째 행동이 아니다.**
> 사용자 문서 5항이 명시한다 — "손바닥 → 영혼소환술 → 예 → 수용 연출 3초 →
> **수호령을 선택한 후** 바로 노드 경로선택 공 발사로".
> **선택이 먼저고 route_aim은 그 다음이다.**

### 확정된 결함 (두 레인 독립 재현 · 반증 실패)

`tower_ascent_guardian_spring_node.gd:202~206`이 first_pick 분기에까지
`not visit_action_committed`를 걸었다.

1. 팜 커밋이 `operation == OP_PALM`인 history 레코드를 남긴다
2. `_has_committed_visit_action(node_id)`(`:1461`)가 true가 된다
3. `:202~206`의 first_pick 분기(`has_soul_summoning() and not first_pick_completed
   and not visit_action_committed`)가 **건너뛰어진다**
4. **first_pick 카드를 만드는 producer는 저장소 전체에 이것 하나뿐이다**
5. `_arm_guardian_spring_auto_route`(`tower_ascent_flow_node_progress.gd:704`)가
   `:708`에서 `"palm"`과 `"prayer"`를 **둘 다** 받아 팜 레코드에도 발동한다 →
   `GUARDIAN_SPRING_AUTO_ROUTE_HOLD_SEC = 0.45`초 뒤 ROUTE_AIM으로 밀어낸다.
   **플레이어가 머무를 수 없다.**

**실측 재현**(열린 슬롯 레그 · 만석 교체 확정 레그 둘 다):
팜 커밋(`accepted=true applied=true owned=true`) 후
`build_actions("nodeA")` → `[palm(enabled=false), prayer:0(enabled=false)]` **둘뿐**.
`build_actions("nodeB")` → first_pick 카드 3장.

**피해**: `tower_ascent_map_generator.gd:47`
`TEMP_EARLY_GUARDIAN_SPRING_GUARANTEE_COUNT := 1`(1~2층만)이고 샘터는 분기
대안이다. **런에서 샘터를 정확히 한 번 방문하면 초식 슬롯을 영구 소모하고도
수호령 0마리로 끝난다.** 지시문 A-4가 GRT-031로 명시 경고한 증상 그 자체가
다른 경로로 재현됐다.

**부수 피해**: `_prayer_locked`는 `_apply_first_pick`에서만 세워지므로
**기도도 영영 안 잠긴다.**

### ★선재 씰 3개를 재작성해 이 동작을 봉인했다

지시문은 **"기존 씰 GREEN 유지"** 를 명시 요구했다.

- `tower_ascent_guardian_spring_node_smoke.gd:233~244` —
  `"S3 palm completion must transition to three blind first-guardian cards"`
  단언을 `"palm completion must close both rituals for this visit..."`로 **교체**
- `tower_guardian_spring_presentation_smoke` — `first_pick_count == 3`을
  **`== 0`으로 반전**
- `tower_guardian_spring_chosik_bridge_smoke` — first_pick 단언 완화

**셋 다 원상복구하라.** 계약을 바꿔야 한다고 판단되면 **먼저 관제탑에 올려라.**

### 수리

1. **first_pick 분기에서 방문 게이트를 빼라.** `:202~206`을 커밋 이전 조건
   (`has_soul_summoning() and not first_pick_completed`)으로 되돌려라.
   손바닥·기도 **두 액션 카드**의 상호 배제(`:541`, `:588`)는 그대로 유지한다.
2. **자동 진행을 first_pick 대기 중에는 막아라.**
   `_arm_guardian_spring_auto_route`(`tower_ascent_flow_node_progress.gd:704`)를
   `not _guardian_spring_node.is_first_pick_pending()`으로 게이트하라.
   **수호령을 고른 뒤에 route_aim으로 간다.**
3. 씰 3개 원상복구.

## [P2] F2 — `_restore_soul_unlock_runtime`의 가드가 죽었다

`tower_ascent_guardian_spring_node.gd:1323`.

`_apply_soul_summoning_unlock`의 반환형을 `bool` → `Dictionary`로 바꾸고
(`:1094`) 호출자 `:951`은 고쳤는데, **`:1323`의
`if not _apply_soul_summoning_unlock(owner, registry): return false`를 안 고쳤다.**

모든 반환 경로가 비어 있지 않은 Dictionary를 준다 →
`not {"accepted": false, "pending_swap_started": true}` == **false** →
**가드가 절대 트립하지 않는다.**

지금은 `_capture_committed_soul_unlock_snapshots`(`:1297`)가 독립적으로 false를
돌려 가려져 있다. **soul_summon_art가 이미 장착됐는데 `apply_choice`가 false를
반환하는 경우** 가려지지 않는다 — 커밋 전엔 `restore_runtime`(`:166`)이 false,
커밋 후엔 true다.

⚠GDScript는 `not <Dictionary>`를 조용히 받는다. **파서·경고 스캔·헤드리스 로드
어느 것도 안 잡는다.**

**수리**: `if not bool(_apply_soul_summoning_unlock(owner, registry).get("accepted", false)):`
또는 dict를 받아 `accepted`와 `pending_swap_started` 둘 다로 분기하라.
⚠만석 복원이 지금 여기서 runtime unlock swap을 여는데 **아무도 취소하지 않는다.**

## [P2] F3 — ★X2와 조용히 깨진다 (GRT-048)

형제 브랜치 `codex/fb8-guardian-spring-first-pick`(`c425881d3`, X2)이
`grant_and_activate_tower_spring_guardian`의 시그니처를
`(pet_id, owner, registry, rng_seed)` **4인자로 넓혔고**, 자기 쪽 픽스처 3개
(`chosik_bridge` `:87` / `stage3` `:68` / `lingpet_egg_runtime.gd:1652`)를 고쳤다.

**X1이 새로 만든 3인자 fake**
(`tower_ascent_guardian_spring_node_smoke.gd:110~114`)는 X2 시점에 존재하지
않아 고쳐지지 않았다. 그리고 **X1이 이번에 그 fake를 실제로 구동한다.**

⚠**`git merge-tree --write-tree 8ce16ec88 c425881d3` = 텍스트 충돌 0**
(트리 `e87e247a6`). **조용히 깨진다.**

재현: `SCRIPT ERROR: Invalid call to function
'grant_and_activate_tower_spring_guardian (via call)' in base
'RefCounted (FakeThreeParam)'. Expected 3 argument(s).`
실패한 호출이 null을 반환 → `not bool(null)` == true → `_apply_first_pick`가
false를 반환 → 신규 단언 RED + SCRIPT ERROR.

**수리**: `:113`의 fake에 `_rng_seed: int = 0`을 추가하라(X2가 다른 세 fake에
이미 적용한 것과 동일).
⚠**검증은 병합된 트리에서 하라.** 어느 한쪽 브랜치 단독으로는 안 잡힌다.

## [P2] F4 — 초식 교체창이 매 프레임 두 번 전체화면으로 그려진다

선재 HUD 경로가 같은 교체창을 이미 매 프레임 전체화면으로 그리고 있는데,
이번 커밋이 그 위에 **두 번째 전체 렌더를 얹었다.**
어느 쪽이 소유자인지 정하고 하나로 줄여라. GRT-043 예산 문제다.

## [P2] F5 — ESC 가드가 새 방문 게이트와 모순된다

팜 커밋 직후 `is_first_pick_pending()==true`인데 **화면엔 첫뽑기 카드가 0개**다.
F1을 고치면 자연히 해소되지만, 고친 뒤 ESC 가드가 여전히 일관적인지 확인하라.

## [P2] F6 — 수련장 성공 영수증에 실패 문구가 뜬다

`record_action_feedback`의 새 `KEY_STATUS_DISABLED` 폴백이 **success 여부를
보지 않아** 수련장 **성공** 영수증에 `"지금은 선택할 수 없습니다."`를 그린다.
폴백을 실패 경로로 한정하라.

## [P2] F7 — 5지선다 카드 글자가 아이콘에 파묻힌다

교체창 카드에서 초식 이름 글자가 **불투명 아이콘 사각형에 그대로 묻힌다.**
z 순서나 여백을 조정하고 **픽셀 캡처로 확인하라.**

## [P3] F8 — `ESC_RESTORE_DELTA_PIXELS=0`이 항진명제다

픽셀 QA가 **프로덕션 취소 경로를 전혀 통과하지 않는다**
(`tower_guardian_spring_presentation_visual_qa.gd:238`).
0이 나오는 것이 당연한 구조다. 실제 취소 경로를 관통시켜라.

## [P3] F9 — 기도 성공 문구만 반말이다

같은 카드의 존댓말 설명문과 어투가 갈린다. **저장소 한국어 카피 규칙은
존댓말이다.** 통일하라.

## [P3] F10 — 워크트리 위생

`godot/tools/`에 구현 세션의 **미추적 프로브 스크립트 3개**가 남아 있다.
정리하라.

## 스코프 초과 (판단해 보고하라)

`_player_facing_node_status` 적용 범위가 지시문이 지목한 두 싱크
(`:409`, `:584`)를 넘어 `_execute_rest_action`(`:792`)과
`commit_guardian_spring_browse_purchase`(`:769`)에도 적용됐다.

저위험이고 A-6 취지("raw reason을 화면에 싣지 않는다")에는 부합한다.
그러나 **휴식·살핀다 노드의 실패 문구가 조용히 바뀐다.**
유지할지 되돌릴지 판단해 보고하라.

## 확인된 무결 (재작업 금지 · 관제탑이 직접 재현)

- **A-1 신호 보존 정확.** `has_pending_unlock_swap()`으로 판정하고
  **`runtime_perk_state.gd`를 건드리지 않았다**(커밋 파일 목록에 없다).
- **A-2 롤백 예외 정확.** `cancel_pending_unlock_swap`을 유지하고 술어로
  게이트했으며, 그 술어가 **load-bearing 임을 증명했다.**
- **A-4 확정 레그 5단계 전부 존재.**
- **GRT-054 / GRT-048 X1 내부는 깨끗.** 초식 상한은 `get_max_skill_slots()` 경유.
- **RED 반증 2건 모두 재현됨.**
- **씰 재작성(stage2)은 약화가 아니라 의미 전환**이었다. B-1 요구 충족.
- **RNG 파리티 단일 경로**이고 차등 대조로 비공허 확인.
- **문구 유지 프레임 + `forced_cleanup_count=0`** 재현됨.
- **CI/pre-push 245/245 정확히 락스텝.**
- **공유 인프라 5파일 변경 전부 필요했다**(신규 오버레이 호스트 배선).
- **픽셀 캡처 확인** — 교체창이 실제로 타워 지도 위에 그려진다.
- ✔`perk_slot_limit_smoke`는 기준선에서도 이미 GREEN이었다. **세션 판단이 옳다.**

## 반증된 지적 (대응 불필요)

- `KEY_STATUS_DISABLED` 다국어 공백 — X1 귀책 0, 선재 백로그
- `export_state()` pending 고아 — 프로덕션 도달 불가
- 신규 `.gd` `.uid` 누락 — "저장소 관례" 전제가 무너짐
- 드로우 경로 딥카피 — P3로 강등

## ★통합 충돌 (관제탑 실측 · 앞선 경고 정정)

**X1은 CI 3중 충돌의 당사자가 아니다.**
X1은 `.github/workflows/godot-ci.yml:148` / `run_pre_push_checks.ps1:152`
**샘터 블록 중간**(`res://tests/tower_ascent_guardian_spring_node_smoke.gd`
바로 뒤)에 삽입한다. X4·X5는 둘 다 **목록 꼬리**라 서로 충돌하지만 X1과는
겹치지 않는다.

| 조합 | 결과 |
|---|---|
| X1 × 현재 HEAD `8f0d884b7` | **무충돌** (트리 `db5d5e8ae`) |
| X1 × X4 `1a3c6528a` | **무충돌** (트리 `0ee2075ca`) |
| X1 × X2 `c425881d3` | 텍스트 무충돌 — ⚠**그러나 F3으로 런타임에서 깨진다** |

## 게이트·보고

포커스드 스모크(+RED 반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` → **픽셀 QA(F7 포함)**.

⚠**F1 수리 후 반드시 확인하라**: 팜 커밋 → **같은 방문에서** 첫 수호령 카드
3장이 뜨고 → 선택 후에야 route_aim으로 간다.
⚠**F3은 X2와 병합한 트리에서 검증하라.**
⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 추가 커밋 해시 · 씰 3개 원상복구 확인 · **F1 수리 후 팜→첫픽→route_aim
순서 실측** · F3 병합 트리 검증 결과 · 스코프 초과 판단 · 미해결.
