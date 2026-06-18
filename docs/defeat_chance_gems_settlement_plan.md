# 기회의 보석(Chance Gems) + 루트 패배 / 최종 결산 설계

상태: 설계 확정 단계 (구현 전). 이 문서가 본 기능의 **단일 소스**.
대상: Godot `디스크하츠 - 링피아` (`godot/`). Python `pingfighter.py`는
`show_death_evaluation()` 결산 내용 **패리티 참고**로만 사용.

분담(메모리 `feedback_design_slice_review_division`): 설계·트랩 브리프·적대적
리뷰 = Claude / GDScript 배선 = 사용자. 슬라이스마다 smoke + 반증검증 명시.

**이미지 자산 = Codex 인계.** 보석·포털·시길 등 비주얼 생성+알파+로더/프리웜 배선은
Codex가 실행(미적 방향·프롬프트·QA는 Claude). 핸드오프 브리프 =
`docs/defeat_chance_gems_asset_handoff.md`. 코드 배선(S1~S5)은 본 문서.

### 정정 로그 (Codex 코드리뷰 2026-06-17)
- **[Critical] `reset_game` ≠ 진행상태 보존.** 초기 조사가 "reset_game이
  아이템/퍽/골드를 안 건드린다"고 **오판**했으나 코드 실측 결과 `reset_game`은
  **풀 와이프**(items/perks/gold/equipment/mythic → 빈 값,
  `match_reset_controller.gd:19,22,242-255`). 소프트 컨티뉴는 `reset_game`이 아닌
  **진행상태 보존 리셋**(`reset_for_stage_transition` 계열, mythic 스테이지-어드밴스
  제외)을 써야 함. 4·5·8장 반영.
- **[High] 결산 골드 = `plaza_gold + owner.runtime_perk_gold` 합산.** 승리 경로만
  owner `runtime_perk_gold`를 저장소로 transfer 후 0으로 만든다
  (`stage_clear_result_screen.gd:899-903`). 패배는 그 경로를 안 타므로 둘을 합산.
  6장 반영.
- **[Medium] 보석 아이콘 = `ui-hud-generation`** (item-generation은 32/64px
  픽셀아트·검정외곽 강제 → 프리미엄 페인터리 크리스탈과 정반대). 5·7장 + 핸드오프 반영.
- **[Medium] 결산 보스 로스터 = Godot 매핑 고정** (5=홍련, 6=테트리서, 네메시스
  제외; Python 번호 베끼기 금지). 6·10장 반영.

---

## 0. 결정 잠금 (재론 금지)

| # | 결정 | 값 |
|---|------|-----|
| D1 | 보석 풀 범위 | **런 전체 공유** — 새 런(스테이지1 진입)에서만 풀 충전. 스테이지 전환·플라자 왕복·소프트 패배 컨티뉴를 모두 관통해 줄어든 채 유지. 골드/아이템/퍽과 같은 수명. |
| D2 | 기존 부활 아이템과의 순서 | **아이템 먼저·무료, 보석은 최후의 보루.** 파울휘슬/리바이벌/오딘의 눈이 발동하면 보석 **불소모**. 보석은 "아이템이 못 막은 매치 패배"의 터미널 floor. |
| D3 | 시작 기회 / 마지막 보석 의미 | **보석 3개 = 3회 컨티뉴.** 보석 1개 이상이면 소모하고 컨티뉴(소프트 패배). 보석 0개 상태의 패배(4번째)가 **찐패배 → 최종 결산 → 메인메뉴**. |

`MAX_CHANCE_GEMS = 3` (D3). 튜닝 상수일 뿐 의미는 위로 고정.

---

## 1. 확정된 현재 지형도 (코드 실측)

### 1.1 패배가 흐르는 단일 터미널 — 여기에 꽂는다
`battle_scene_match_flow_driver.gd:118-127` `_apply_scoreboard_update_result()`:

```
UPDATE_RESET_GAME (= match_finished, 전광판 ~1.5s 종료 후)
  → _show_stage_clear_result()              # 승리면 결과창 띄우고 return
      └ stage_clear_result_screen.show_from_scoreboard()
          if player_score <= boss_score: return false   # 패배는 여기서 false
  → false면 곧장 reset_game_callback()       # ★현재: 같은 보스 조용히 0-0 재시작
```

즉 **현재 패배는 아무 연출/메뉴복귀/결산 없이 같은 보스를 무한 재시작**한다.
이 `false → reset_game` 한 분기를 **패배 리졸버**로 바꾸는 게 전부.

### 1.2 부활 체인은 점수 적용 전에 끝난다 (보석은 그 뒤)
`match_score_event_controller.gd:13-31` `handle_score_event()` — 보스 득점 시:
```
1 _try_start_odins_eye_death_sequence   (페널티 폼 재실점 → 사망 애니)
2 _try_negate_boss_score                (파울휘슬)
3 _try_trigger_revival                  (리바이벌, 매치종료 실점 한정)
4 _try_trigger_odins_eye_revival        (오딘의 눈 35%)
   ↓ 아무도 안 막음
   score_state.score_for()  (line 38)  → match_finished 판정 → 전광판
```
- 이 4개는 모두 **`score_state.score_for()` 전에** 발동·early-return. 전광판이
  끝나고 1.1의 리셋 분기에 도달했다 = **아이템이 아무도 못 막았다**. 보석을
  터미널(1.1)에 두면 D2(아이템 우선·무료)가 자동 성립. 부활 아이템 로직은
  **건드릴 필요 없음**.
- **오딘 사망 funnel 확인**: 오딘 사망 시퀀스는 애니 종료 후
  `odins_eye_death_finalize_score = true`로 재진입하여 1~4를 전부 skip하고
  정상 점수 적용 → match_finished → 전광판 → 1.1 터미널로 흘러든다. 따라서
  **오딘 사망 케이스도 보석 리졸버가 자동 포착**한다(오딘이 이미 1회
  살려줬어도, 보석이 최후 floor가 됨 — D2 일관).

### 1.3 메뉴 복귀 경로 (확정)
`battle_scene_match_flow_driver.gd` `_exit_to_main_menu()` →
`change_scene_to_file("res://scenes/main_menu.tscn")`.
★정정(2026-06-19 라이브 QA): 찐패배는 **진짜 메인 메뉴(main_menu.tscn)**로 복귀.
초기엔 `_exit_to_main_menu`가 이름과 달리 `character_select`를 여는 misnomer였고
QA에서 패배 후 char_select로 가는 버그로 발견 → 함수를 main_menu로 정정, 승리 exit는
`_exit_to_character_select()`로 분리(동작 불변, 공유 헬퍼 `_change_to_scene`). 결산
dismiss 시 이 콜백 재사용.

### 1.4 상태 수명 (확정)
- **골드** = `plaza_save_store.gd` (`user://plaza_save.cfg`, 스키마 v4). 런 스코프.
  `reset_gold_and_ap_for_new_playthrough()` (line 111-122)가 새 런에서 0으로.
- 새 런 리필 훅 = `battle_scene_selection_startup_lifecycle.gd:31-43`
  `reset_plaza_progress_if_new_game(entry_stage, save_path)` — `entry_stage==1`
  AND 실제 save_path일 때만. 주석 명시: 스테이지 전환·플라자 왕복은 같은 씬
  재사용이라 여기 안 옴 → 스테이지>1은 절대 fresh start 아님.
- **아이템/퍽** = 런 동안 owner/runtime에 누적되지만, 현재 일반
  `reset_game()`은 이를 **풀 와이프**한다(3.3). 소프트 패배 컨티뉴가
  아이템/퍽/골드를 유지하려면 반드시 전용 진행상태 보존 리셋
  (`reset_for_continue`)을 써야 한다.

### 1.5 오버레이 배선 템플릿
`stage_clear_result_screen`가 모듈로 등록·구동되는 경로를 그대로 따른다:
- 등록: `gameplay_core_module_catalog.gd`
- 구동: `battle_scene_frame_controller.gd`(update) /
  `battle_playfield_overlay_drawer.gd`(draw) /
  `battle_scene_input_controller.gd`(input) / `battle_scene_lifecycle.gd`(cleanup)
- 즉시-draw(immediate `_draw`) + 선택적 scene 노드 spawn 패턴.

---

## 2. 전체 흐름 (한 장)

```
보스 득점 (매치 종료점)
  → [부활 아이템 체인 1.2]  ── 발동 ──▶ 같은 매치 계속 (보석 불소모, 기존 그대로)
  └ 아무도 안 막음
      → 전광판 ~1.5s
      → 터미널 리졸버 [1.1 후크]
          if 승리: 스테이지 클리어 결과창 (기존)
          else 패배:
            gems = run_store.chance_gems
            ┌ gems > 0 :  gems -= 1 ; store 저장 ; HUD 3→2 shatter
            │             ▶ 「루트 패배(소프트)」 오버레이 (한 번 더!)
            │             ▶ 확인 → reset_for_continue()  (★reset_game 아님 — 진행상태
            │                보존; 같은 보스 0-0, 아이템·퍽·골드·장비·mythic 유지)
            └ gems == 0:  ▶ 「최종 결산(찐패배)」 오버레이 (런 스냅샷)
                          ▶ dismiss(입력) → _exit_to_main_menu()  (main_menu.tscn, 전체 리셋)
```

---

## 3. 상태 모델 & 수명

### 3.1 보석 카운트의 집 = `plaza_save_store.gd` (런 스코프 영속)
이유: 플라자 왕복(scene change)·스테이지 전환을 관통해 살아남아야 함 → 배틀씬
모듈로는 부족(왕복 시 teardown). 골드와 동일 저장소가 정답.

추가:
```gdscript
const CHANCE_GEMS_KEY := "chance_gems"
const MAX_CHANCE_GEMS := 3
var _chance_gems := MAX_CHANCE_GEMS
# SAVE_SCHEMA_VERSION 4 → 5 (마이그레이션: 키 없으면 MAX로 채움)

func get_chance_gems() -> int            # _ensure_loaded
func consume_chance_gem() -> int         # max(0, _chance_gems-1); save(); 반환 = 남은 수
func reset_chance_gems_for_new_playthrough() -> void  # _chance_gems = MAX; save()
```
- `reset_gold_and_ap_for_new_playthrough()` **또는** 그 호출부
  (`reset_plaza_progress_if_new_game`, 1.4)에서 보석 리필을 **함께** 호출
  (move-together: 새 런 리셋 1군데에 골드·AP·보석을 같이). D1 성립.
- 스키마 v5 마이그레이션 필수(기존 세이브엔 키 없음 → 로드 시 MAX로 시드).
  CLAUDE.md ConfigFile BOM 트랩 주의(이 파일은 이미 BOM-strip 경로 있음).

### 3.2 HUD/리졸버가 읽을 배틀씬 미러 (Owner-Field Schema 트랩)
HUD가 owner에서 보석 수를 읽으려면 **반드시**
`battle_scene_state.gd` `DEFAULT_VALUES`에 키 선언(미선언 set은 silent no-op —
CLAUDE.md "Owner-Field Schema Trap"):
```
"chance_gems_count": 3,
"chance_gems_max": 3,
```
- bootstrap에서 store→owner 동기화(1회). consume 시 store와 owner 둘 다 갱신
  (move-together). 결산/리졸버는 store를 진실로, HUD는 owner 미러를 읽음.
- 스모크는 **schema-gated owner**(BattleSceneState 위임)로 검증 — plain dict
  FakeOwner는 이 트랩을 못 잡는다(CLAUDE.md 명시).

### 3.3 리셋 2종의 진실 + 회귀 가드 (★Codex 정정)
`match_reset_controller.gd` 실측:
- **`reset_game()` = 풀 와이프.** `_reset_item_runtimes`(line 19→93-106:
  active/mythic/treasure 런타임 reset), `_reset_player_skill_state`(line 22→121-138:
  `runtime_perk_state` 포함), `_build_reset_result`(line 242-255:
  `runtime_perk_levels/gold`, `passive_item_inventory`, `equipped_passive_items`,
  `mythic_item_state` → 빈 값). **즉 현재 게임은 패배 시 이미 모든 아이템/퍽/골드를
  날리고 보스를 맨몸으로 재시작 중.**
- **`reset_for_stage_transition()` = 진행상태 보존.** `_reset_item_runtimes` /
  `_reset_player_skill_state`를 **호출하지 않고**, 결과 dict도
  `special_gauge`/`drive_text`/`optimus_energy`만 리셋(line 63-74 주석 명시:
  "Perks, items, equipment, mythic state ... intentionally NOT included so the
  result applier reads from the owner and preserves progression"). 매치/라운드/스테이지
  transient(score·scoreboard·round·dash·stage FX)는 정상 리셋.

따라서 **소프트 컨티뉴는 `reset_game` 절대 금지** → 진행상태 보존 리셋을 쓴다(4장).
보석 카운트는 둘 중 어느 리셋도 안 건드림(별도 store, 3.1). 새 런 리필(3.1)만 MAX로.
- `reset_game`은 본 기능의 패배 터미널에서 **퇴역**(리졸버가 대체). 디버그/뉴게임 등
  다른 호출부는 그대로 둠 — 패배 분기에서만 안 쓴다.

---

## 4. 터미널 리졸버 (정확한 삽입)

`battle_scene_match_flow_driver.gd` `_apply_scoreboard_update_result()`
line 118-127를:
```gdscript
if update_result == ScoreboardState.UPDATE_RESET_GAME:
    if _show_stage_clear_result(registry, reset_game_callback, owner):
        return                               # 승리 (기존)
    _resolve_match_defeat(registry, owner, continue_callback)   # ★신규 (기존 reset_game 직접호출 대체)
```
신규 `_resolve_match_defeat(registry, owner, continue_callback)`:
```gdscript
gems = run_store.get_chance_gems()           # plaza_save_store
if gems > 0:
    remaining = run_store.consume_chance_gem()
    owner.set("chance_gems_count", remaining) # 미러 (스키마 선언됨)
    soft_defeat_screen.show(owner, registry, continue_callback)  # 확인 → continue_callback()
else:
    defeat_settlement_screen.show(owner, registry,
        Callable(self, "_exit_to_main_menu").bind(owner))           # dismiss → 메뉴
```
- **`continue_callback` ≠ `reset_game_callback`** (★Codex 정정). 진행상태 보존
  리셋이어야 함 — 신규 `reset_for_continue`로 라우팅:
  - 컨트롤러 레벨 `reset_for_stage_transition`(진행상태 보존, score·round·stage
    transient 리셋)을 재사용하되,
  - 드라이버 레벨에서 `_notify_mythic_stage_advance`는 **호출 안 함**(컨티뉴는
    스테이지 어드밴스가 아님). 액티브아이템 쿨다운 리셋은 포함 가능(프레시 매치).
  - 배선: 기존 `reset_game_callback`이 plumb되는 경로와 동일하게
    `continue_callback`(또는 `reset_drive_input_callback`)을 리졸버까지 thread.
    `_apply_scoreboard_update_result`는 현재 `reset_ball_callback`만 보유 →
    `update_scoreboard` 시그니처에 continue 경로 인자 추가 필요.
- 두 화면도 registry 모듈(1.5). 리졸버는 인스턴스 lookup만.
- **재진입 가드**: 화면이 이미 active면 재-consume 금지(per-defeat 1회 edge).
  소프트/결산 화면 각자 `is_active()` 게이트.
- `continue_callback`은 **소프트 패배에서만** 호출. 찐패배는 어떤 reset도 호출 안 함
  → 씬 teardown 전 owner 상태(아이템·퍽·골드) 그대로 결산이 읽음
  (snapshot-before-reset 위험 0).

---

## 5. 화면 A — 「패배(소프트 컨티뉴)」 오버레이 — 프리미엄 베스포크

비주얼 기준 = 승인된 목업(LoL/원신 그레이드). 위→아래 구성:

```
        ✦ (나침반-별 시길, 기존 로고 모티프 재사용)
                패  배                        ← 제목 (밝은 화이트, 자간 넓게)
       아쉽지만 다음 기회를 노려보세요.        ← 부제 (디머)
   ┌──────── 원형 포털 백드롭 ────────┐
   │   [방금 나를 이긴 스테이지 보스]   │      ← 어둡고 위압적, 포털 림 글로우
   └──────────────────────────────────┘
        기회의 보석이 1개 소모되었습니다.        ← "1개" 액센트 블루
   ◇──  ◈(깨짐)   ◆(온전)   ◆(온전)  ──◇      ← 보석 게이지 3칸 + 장식 디바이더
   기회의 보석은 패배 시 1개가 소모됩니다.
   모든 보석이 소모되면 더 이상 도전할 수 없습니다.  ← 빌드업 경고
            [   확인   ]                        ← 장식 버튼, 수동 컨티뉴
```

확정 카피(채용):
- 제목 `패배` / 부제 `아쉽지만 다음 기회를 노려보세요.`
- 본문 `기회의 보석이 {n}개 소모되었습니다.` (`{n}`=이번 소모량=1, 숫자만 액센트)
- 안내 `기회의 보석은 패배 시 1개가 소모됩니다. / 모든 보석이 소모되면 더 이상 도전할 수 없습니다.`
- 버튼 `확인`

동작:
- consume(4장)는 **화면 띄우기 직전 1회**. 게이지는 소모분이 shatter되는
  3→2 애니(이번 턴 깨지는 칸 1개 강조). 나머지 온전 보석은 미세 펄스/글린트.
- **수동 확인** (입력/버튼 클릭) → `continue_callback()` = 진행상태 보존
  `reset_for_continue` (★`reset_game` 아님 — 4장 정정). 같은 보스 0-0 재개,
  아이템·퍽·골드·장비·mythic 유지. auto-skip 없음(플레이어가 손실을 인지).
- **"마지막 기회" 변형**: 이번 소모로 남은 보석 0(=loss #3, 게이지 3칸 전부
  깨짐)일 때, 안내문을 `이것이 마지막 기회입니다. 다음 패배 시 게임이 종료됩니다.`
  로 교체 + 경고 톤(레드 액센트). 그래도 컨티뉴는 정상 진행(찐패배는 loss #4).

포털 안 주인공 = **방금 나를 이긴 스테이지 보스**(현재 `current_stage`→보스 매핑).
대안(쓰러진 플레이어 링펫)은 보류. 보스 렌더는 기존 보스 시트 재사용 가능.

신규 자산(8장 S3에서 생성·라우팅):
- 보석 아이콘 PNG — **온전 / 깨짐 2상태**(HUD 게이지 7장과 **공유**). 청색 결정
  다이아 실루엣. 라우팅: **`ui-hud-generation`** (★Codex 정정 — item-generation은
  32/64px 픽셀아트·검정외곽·NO-painterly를 강제하므로 프리미엄 페인터리
  크리스탈엔 부적합). 포털과 같은 스킬·같은 페인터리 톤으로 일관 생성.
- 원형 포털 백드롭 + 장식 프레임 + 시길 + 버튼 프레임 — 큰 HUD 크롬이므로
  `ui-hud-generation` 스킬. 공명 포털 비주얼 언어 echo 가능.
- 직접 draw 요청(`그려줘`) 들어오면 CLAUDE.md "Direct Draw Request Routing"대로
  imagegen 실제 비트맵 생성 후 PNG-first 로더 배선(절차적 폴백 금지).

재사용(코드): `stage_clear_result_*` text/font/shape 헬퍼(그림자텍스트/폰트캐시/
패널). 배경 백드롭은 신규 PNG, 게이지/시길은 PNG+절차적 합성.

배선/트랩:
- 1.5 템플릿(모듈 등록 + frame/overlay/input 구동). 백드롭 PNG가 있으므로
  scene 노드 또는 즉시-draw 텍스처 블릿(컷인 호스트 패턴 참고).
- mid-round 모달 → 라이브 재렌더 말고 **스냅샷 배경**(메모리), modal-gate 등록.
- 백드롭/시길 텍스처는 **이산 프리웜**(draw에서 lazy 로드 금지, Hot-Path Lazy).
  패배 확정 시점에 큐. 음수 z 백드롭이면 조상 불투명 풀필 트랩 픽셀 검증.

## 6. 화면 B — 「최종 결산(찐패배)」 오버레이 (Python 패리티)

원본 `show_death_evaluation()` 섹션을 Godot 자산으로 재현:

| 섹션 | 내용 | Godot 소스 |
|------|------|-----------|
| 헤더 | "GAME OVER" / 패배 무드(다크·레드) | 신규 카피 |
| 골드 (+플레이타임) | 런 누적 골드 = **`plaza_gold + owner.runtime_perk_gold` 합산** (★Codex 정정). 플레이타임은 v2 | `plaza_save_store.get_plaza_gold()` + owner `runtime_perk_gold` |
| 도달/처치 보스 | 스테이지 N 도달 + 1..N-1 보스명 | `current_stage` + **Godot 스테이지 매핑 고정**(아래) |
| 획득 아이템 | 패시브/액티브 아이콘 그리드(중복 dedup, +N overflow) | owner `passive_item_inventory` / `equipped_passive_items` / `active_item_slots` |
| 획득 퍽 | 퍽 아이콘 + 레벨 뱃지 | owner `runtime_perk_levels` + `runtime_perk_catalog` |
| 최종 스코어 | "최종 스코어: P-B" + 스테이지/보스명 | score snapshot |

- **골드(★High 정정)**: 패배 결산은 승리의 골드-transfer 경로
  (`stage_clear_result_screen.gd:899-903`, owner `runtime_perk_gold`→저장소 후 0)를
  **안 타므로**, 표시값 = `plaza_save_store.get_plaza_gold()` + owner
  `runtime_perk_gold`(미은행 런 골드)를 **합산**. 찐패배는 런이 끝나고 다음 런에서
  새 런 리필로 골드 0이 되므로 transfer 불필요 — 합산값을 **표시만** 하면 됨.
- **보스 로스터(★Medium 정정)**: Godot 스테이지 매핑 고정 — `current_stage==5`=홍련,
  `6`=테트리서(원본 Python 7 포팅), **네메시스 제외**. Python 번호(원본 5=네메시스 등)
  베끼기 금지. 메모리 `project_godot_stage_numbering` / AGENTS.md 참조. 선형 진행이라
  도달 스테이지 N → 1..N-1 보스 도출(분기/스킵 진입 있으면 10장 cleared-bosses 리스트).
- 재사용: `stage_clear_result_reward_card_draw_helper`(아이콘 그리드),
  `stage_clear_result_reward_icon_resolver`(텍스처), `..._summary_draw_helper`
  (골드/스코어 타일), `..._shape_helper`/`..._text_layout_helper`/`..._font_cache`.
  무드만 다크·레드 계열로(승리 시안 팔레트 대비).
- 동작: **입력(ESC/SPACE/클릭) 1회 → dismiss → `_exit_to_main_menu()`**
  (main_menu.tscn, 전체 리셋). 원본은 any-input 즉시 dismiss.
- v1 범위: 골드 / 스테이지·보스 / 패시브·액티브 아이템 / 퍽 / 스코어.
  플레이타임·처치보스 썸네일은 v2(또는 보스명 텍스트로 축약).
- **트랩(행 예산)**: CLAUDE.md "Stats-Panel Row Budget" — 결산 섹션이 rect를
  넘치면 행이 silent drop. 아이콘 그리드 overflow는 "+N"으로, 텍스트 행은
  draw-time capacity 검증.

## 7. HUD — 기회의 보석 게이지

- 위치: 비전투 정보존(예: 코너). 보석 N개 아이콘, 소모분은 깨짐/회색.
- 읽기: owner `chance_gems_count` (3.2 미러, 스키마 선언 필수).
- 소모 시 shatter 1회(화면 A와 동일 비주얼 톤).
- 아이콘 자산: **화면 A(5장)와 동일한 온전/깨짐 2상태 보석 PNG 공유**(청색
  결정 다이아). HUD 게이지와 패배 오버레이가 같은 자산을 써야 톤 일관.
  라우팅: **`ui-hud-generation`** (★Codex 정정 — item-generation 픽셀아트 강제와
  충돌). 프리미엄 페인터리 크리스탈.

---

## 8. 슬라이스 플랜 (각 슬라이스 = smoke + 반증검증)

반증검증 = 수정 전 코드로 새 smoke가 **FAIL**함을 in-place Edit 토글/임시패치/
픽스처로 증명(절대 `git reset/checkout/stash` 금지 — WIP 보호).

- **S1 — 보석 상태 + 수명** (`plaza_save_store` + 새 런 리필 + reset 불변).
  smoke: 소모→남은 수, 새 런 리필 MAX, 매치/스테이지 reset이 보석 불변,
  스키마 v4→v5 마이그레이션(키 없으면 MAX). 반증: 리필을 stage>1에서도 돌게
  바꾸면 "스테이지 전환에 안 줄어듦" 케이스 FAIL.
- **S2a — 컨티뉴 리셋(진행상태 보존)** 우선 (★Critical 선결). `reset_for_continue`
  추가(컨트롤러 `reset_for_stage_transition` 재사용, mythic 스테이지-어드밴스 제외).
  smoke: 컨티뉴 리셋 후 owner의 `passive_item_inventory`/`equipped_passive_items`/
  `runtime_perk_levels`/`runtime_perk_gold`/`mythic_item_state`가 **보존**되고
  score는 0-0, `_notify_mythic_stage_advance` 미호출. 반증: 대신 `reset_game`을
  연결하면 위 진행상태가 빈 값이 되어 "보존" 케이스 FAIL(이것이 Codex가 잡은 버그).
- **S2b — 터미널 리졸버 + 분기** (4장). 화면은 아직 stub(로그만).
  smoke: 패배+gems>0 → consume 1회+`continue_callback`(=reset_for_continue) 호출,
  패배+gems==0 → exit 콜백 호출+**어떤 reset도 미호출**, 승리 → 기존 경로 무변경,
  per-defeat consume 정확히 1회(재진입 가드). 반증: 가드 제거 시 다중 consume FAIL.
  + Owner-Field Schema: chance_gems_count 미선언 시 미러 silent-drop FAIL
  (schema-gated owner로).
- **S3 — 화면 A(소프트)** 실 오버레이 + 배선(1.5) + HUD 게이지(7장).
  smoke: show→확인이 `continue_callback` 호출, HUD 미러 3→2 반영,
  modal-gate 등록. 반증: 확인 경로 미배선이면 영구 활성 FAIL.
- **S4 — 화면 B(결산)** 실 오버레이 + 배선 + 콘텐츠(6장).
  smoke: 결산이 owner 아이템/퍽/골드/스코어를 정확히 모음, dismiss→exit 콜백,
  행 예산 capacity(6장 트랩). 반증: snapshot을 reset 뒤로 옮기면 빈 결산 FAIL.
- **S5 — 통합 라이브 QA** (윈도우드 실행): 3패배 컨티뉴→4번째 결산→메뉴.
  컨티뉴 시 **아이템/퍽/골드 빌드가 그대로 유지**되는지 인게임 확인(맨몸 재시작
  아님). 부활 아이템(파울휘슬/리바이벌/오딘) 발동 시 보석 불소모 확인. 결산 골드가
  plaza+runtime 합산으로 맞는지. 픽셀 QA.

각 슬라이스는 독립 커밋(픽스 자체 스모크가 회귀 봉인 — 메모리
`project_godot_wip_branch_moving_head`).

---

## 9. 트랩 브리프 (적용되는 CLAUDE.md 규칙)

- **Owner-Field Schema Trap** — `chance_gems_count/_max`를
  `battle_scene_state.DEFAULT_VALUES`에 선언 안 하면 HUD 미러 set이 silent
  no-op. schema-gated owner로 스모크.
- **ConfigFile UTF-8 BOM** — `plaza_save.cfg` 스키마 v5 추가/마이그레이션 시
  BOM 트랩(이 파일은 이미 strip 경로 존재).
- **Stats-Panel Row Budget Trap** — 결산 섹션 overflow는 silent drop. 아이콘은
  +N, 행은 draw-time capacity 검증.
- **모달 배경 스냅샷** — 소프트/결산 mid-round 모달은 라이브 재렌더 말고
  스냅샷 배경(메모리). modal-gate 등록으로 일시정지/스킵 브랜치와 분리.
- **이산 프리웜** — 결산 아이콘 텍스처를 draw에서 lazy 로드 금지(Hot-Path Lazy
  Init). 패배 확정 시점/스코어 result-texture 프리웜 큐 재사용 검토.
- **move-together** — 새 런 리셋(골드·AP·보석), consume(store·owner 미러)을
  각각 한 곳에 모아 유지.

---

## 10. 검증/확정 필요 (구현 시)

- `plaza_save_store`가 보석의 정식 런-스토어인지 최종 확인(현재 골드/AP/뱅크
  보관소 = 적합). 보석을 디스크 영속(골드처럼)할지 vs 세션-only인지 결정 —
  **추천: 골드처럼 영속 + 새 런 리필**(중간 종료 후 재개 시 일관).
- 화면 A/B를 `gameplay_core_module_catalog`에 어떻게 등록·구동하는지
  `stage_clear_result_screen` 배선을 1:1 미러(update/draw/input/cleanup 4경로).
- **`reset_for_continue` 정의**(★Critical): 컨트롤러 `reset_for_stage_transition`
  재사용 + 드라이버에서 mythic 스테이지-어드밴스 제외. 액티브아이템 쿨다운 리셋
  포함 여부 결정. `continue_callback`을 리졸버까지 plumb(시그니처 확장).
- 결산 "처치 보스" — Godot 매핑 고정(5=홍련/6=테트리서/네메시스 제외, 6장). 선형
  진행 가정으로 `current_stage`에서 파생 가능한지(분기/스킵 진입이 있으면 런-스코프
  cleared-bosses 리스트 신규 필요).
- 결산 골드 = `plaza_gold + owner.runtime_perk_gold` 합산(★High, 6장). transfer
  말고 표시만(런 종료 후 새 런 리필이 0으로).
- 플레이타임 표시는 v2(런 시작 ticks 저장 필요) — v1 생략 가능.
