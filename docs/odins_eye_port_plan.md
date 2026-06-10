# 오딘의 눈 (Odin's Eye) — Godot 포팅 기획

> 상태: 초안 (2026-06-09). Phase 0–1(부활 + 페널티 코어 MVP)부터 구현 권장.
> 작성 맥락: 사용자 배선 + Claude 디자인/적대적 리뷰 분담
> ([[feedback_design_slice_review_division]]). 이 문서는 슬라이스 계획·신호
> 계약·트랩 브리프이며, GDScript 배선은 구현 슬라이스에서 진행한다.

## 0. 문서 라우팅 (충돌 시 우선순위)

- 런타임 통합 불변식 → `docs/item_runtime_checklist.md`, 특히 **§7
  (캐릭터-변신 / 부활 아이템)**. 이 문서는 §7을 오딘의 눈에 특화해 해석한 것.
- 비주얼 자산(아이콘 / 변신 캐릭터 / VFX) → `item-generation` /
  `sprite-generation` 스킬.
- 신화 아이템 런타임 아키텍처 → `godot/scripts/items/mythic_item_*`.
- 레거시 원본은 `legendary_items.py` / `pingfighter.py` — **타이밍·상태·확률의
  1차 참고 기준이며 구현 타겟이 아님**([[feedback_default_target_godot]]).
  의도적 분기(라운드/스테이지 경계 정책 등)는 본 문서와 코드 주석에 기록한다.

---

## 1. 정체성 & 게임플레이 계약

레거시 원본: `legendary_items.py` `class OdinsEye` (≈ L6644). 벨트 부위, 코드상
"전설(legendary)" 등급이나 unlock 조건은 "신화 아이템 획득".

### 핵심 루프 (실점 → 부활 → 페널티 변신 → 진짜 죽음)

| 단계 | 동작 | Python 앵커 |
|---|---|---|
| 롤 | 부활 확률 **30%~45%** (polish + enhancement 합산) | `legendary_items.py` `revival_chance` (≈ L6819) |
| 실점 | 플레이어가 **실점할 때마다** 부활 확률 롤 | `pingfighter.py` 듀스/일반 양 분기 (≈ L172540–172719) |
| 부활 성공 | 그 실점을 **무효화**, 공 숨김(`-100,-100`)·`ball_vel=0`, **즉시 `return`**, 3초 부활 연출 시작. **연출 시작과 동시에 `revival_used=True`, `penalty_active=True`** | `legendary_items.py` `start_revival_animation` (L7819, 플래그 L7859–7862) |
| 연출 완료(finalize) | 연출 종료 → 패들 착지 → 공 플레이어 위 재배치 → 위로 발사 → 어둠의 늪 스킬 활성화 | `pingfighter.py` `if animation_complete:` (L172/188872) |
| 페널티 상태 | 이동속도 **−50%**, 대시 토큰 **1개 고정**, 대시 쿨타임 **+100%** | 소비 지점 ≈ L26017 / L77213 / L90473 / L91463 |
| 페널티 중 실점 | **진짜 패배** → 죽음 연출 → 점수 확정 (2차 롤 없음) | `pingfighter.py` `start_death_animation` 분기 (L172577 / L172695) |
| 페널티 중 랠리 승리 | 페널티 해제 | (플레이어 득점 경로 / 라운드 리셋) |

### ⚠️ 포팅 최대 함정 — 트리거 의미가 기존 `revival`과 다름

현재 Godot `match_score_event_controller.gd` `_try_trigger_revival` (L208) 는
**`_would_score_finish`(매치를 끝내는 점수)에서만** 발동하는 단순 추가목숨이다.
오딘의 눈은 **모든 실점**에 발동하며 그 실점 자체를 무효화한다. 따라서:

- 기존 revival 게이트(`scoring_side == "boss" and _would_score_finish(...)`)를
  **재사용하면 안 된다**. 오딘 트리거는 매치-종료 한정이 아니라 임의 실점이다.
- 오딘 트리거 분기는 normal-loss 처리 **직전**, 그리고 기존 `revival` /
  `foul_whistle` 음수화 체크와 **나란히** 추가한다. 단 게이트 조건은
  `equipped AND not revival_used AND not penalty_active AND roll<=chance`.
- 페널티 중 실점은 같은 핸들러에서 "죽음 연출 → 진짜 패배" 분기로 라우팅
  (실점을 무효화하지 않고, 죽음 연출이 끝난 뒤 점수를 확정).

---

## 2. 등급 / 슬롯 결정

- **등급: mythic** (Godot 티어 체계가 mythic으로 통합돼 있고 레거시
  legendary→Godot mythic 매핑은 기확립 패턴, 사용자 호칭도 "신화아이템").
- **슬롯: belt** (`pingfighter.py` `ITEM_SLOT_BASE_MAP` `"odins_eye": "belt"`,
  L40979). Godot 카탈로그 `slot="belt"`.
- **획득 경로**: 신화 풀 일반 규칙을 따른다(필드/판도라/보물 등은
  `docs/item_runtime_checklist.md`의 경로별 감사 대상). 본 포팅 1차에서는
  카탈로그 등록 + 디버그 스폰까지만 보장하고 각 획득 풀 편입은 별도 확인.

---

## 3. 재사용 골격 (오딘 = 단순부활 + 변신의 합집합)

| 필요 조각 | 기존 참조 (템플릿) |
|---|---|
| 부활 상태/타이머/이펙트 게이트 | `revival_state.gd` + `mythic_item_revival_runtime.gd` |
| 변신 상태머신(IDLE→이벤트→변신→해제), 페이즈 타이머, 이동속도/패들 오버라이드, stage-once 게이팅 | `mythic_item_horn_strawberry_mask_state.gd` |
| 헬퍼 등록(INIT_ORDER + SCRIPT_PATHS) | `mythic_item_helper_registry.gd` |
| 중앙 런타임 var 선언 + `try_trigger_*` 퍼사드 | `mythic_item_runtime.gd` (L1800 `try_trigger_revival`) |
| 실점 트리거 지점 | `match_score_event_controller.gd` `_try_trigger_revival` (L208) |
| 카탈로그 등록 | `mythic_item_catalog_base_metadata.gd` / `_rolls.gd` / `_roll_definitions.gd` / `_fixed_options.gd` / `_icon_metadata.gd` / `_spawn_metadata.gd` / `_presentation.gd` / `_lists.gd` |
| owner 동기화 + 스냅샷 | `mythic_item_owner_syncer.gd` / `mythic_item_snapshot_builder.gd` |
| update / lifecycle / 라운드 리셋 | `mythic_item_update_runtime.gd` / `mythic_item_lifecycle_runtime.gd` |

신규 파일 2개:
- `godot/scripts/items/odins_eye_state.gd` — 순수 상태(부활/페널티/연출 페이즈,
  파생 getter). `revival_state.gd` + `horn_strawberry_mask_state.gd` 혼합 형태.
- `godot/scripts/items/mythic_item_odins_eye_runtime.gd` — 퍼사드. `runtime`의
  헬퍼들을 읽어 트리거/finalize/페널티 질의/이펙트 그리기를 노출.

---

## 4. 부활 트리거 흐름 (Phase 1 핵심)

### 4.1 트리거 분기 (실점 핸들러)

`match_score_event_controller.gd handle_score_event`에서 `scoring_side == "boss"`
경로에 **새 분기**를 추가. 의사 흐름:

```
if scoring_side == "boss":
    # 1) 페널티 중 실점 → 죽음(진짜 패배) 경로
    if odins.is_penalty_active():
        odins.begin_death_sequence(...)   # 죽음 연출 → 완료 시 점수 확정
        halt_normal_loss()                # 연출 동안 점수/패배 처리 정지
        return
    # 2) 첫 실점 → 부활 롤
    if odins.can_revive() and roll() <= odins.revival_chance():
        odins.begin_revival(...)          # revival_used=True, penalty_active=True
        hide_ball_and_zero_vel()
        halt_normal_loss()
        return
    # 3) 그 외 → 기존 normal loss
```

- 기존 `_try_trigger_foul_whistle` / `_try_trigger_revival`(단순 부활)와의
  **체크 순서**를 명시적으로 정한다. 권장: 페널티-죽음 → foul_whistle →
  단순 revival → 오딘 부활 롤 → normal loss. (foul whistle처럼 실점 자체를
  무효화하는 효과들과의 우선순위는 디자인 결정이므로 smoke로 봉인.)
- 부활/죽음 연출 진행 중에는 점수·라운드 진행을 정지한다. Python의
  전역 `odins_eye_revival_anim_active` / `odins_eye_death_anim_active`
  (점수/패배 블로킹, L171348 / L172423) 등가물을 런타임 플래그로 둔다.

### 4.2 finalize edge (연출 완료 → §7.2 패들 착지)

Python 참조: `pingfighter.py` `if animation_complete:` (L188872). **순서가 중요**:

1. 연출 플래그 해제, `dark_energy_until_round_end = true` (페널티 비주얼 유지).
2. **패들 착지** — Viper면 jetpack state 리셋 후 `apply_equipment_paddle_modifiers`
   등가 호출. 변신이 원래 캐릭터의 스킬-업데이트 블록을 끄므로, 이 프레임에
   패들을 바닥에 스냅하지 않으면 **공중부양 버그**(§7.2).
3. **그 다음** 공 재배치(`BALL.centery = PLAYER.top - 20`) + 위로 발사
   (`base_speed≈9`, 약간의 각도 변이), `last_hit_by="player"`. 착지는 공
   재배치 **이전**에 (§7.2: 안 그러면 공이 공중에 멈춘 패들 위에 놓임).
4. (Phase 3) 어둠의 늪 스킬 활성화.

> **의도적 분기 기록 — 부활 후 재시작 방식 (Phase 1 확정)**
> ([[feedback_default_target_godot]]): Python은 finalize에서 공을 패들 위에 놓고
> **즉시 위로 발사**(`base_speed≈9`)해 끊김 없이 이어간다. **Godot Phase 1은 대신
> 플레이어 서브 대기(`set_player_serves(true)` + `reset_round_wait()`)로 확정**한다.
> 코어 검증이 이미 이 계약으로 닫혔고, 즉시 발사는 VFX/서브 오디오/공 충돌 쿨다운까지
>함께 건드리는 feel 작업이라 **Phase 2 연출 고도화와 묶어서** 재검토한다(지금은 변경
> 안 함). Phase 2에서 즉시 발사로 바꾸기로 하면 이 줄을 갱신할 것.

> 페널티 플래그(`revival_used`/`penalty_active`)는 **연출 시작 시점**에 이미
> 켜진다(L7859). finalize는 "연출 종료 + 착지 + 공 재시작"만 담당한다. 따라서
> 연출 도중 라운드/스테이지가 끊겨도 상태가 일관되게 정리돼야 한다(§경계 정책).

> **Godot §7.2 착지는 `reset_ball` 재사용으로 자동 충족됨 (Python과 구조 차이).**
> Phase 1 finalize(`battle_scene_item_update_driver._reset_ball_after_odins_eye_revival`)는
> `battle_scene_ball_update_driver.reset_ball`을 호출하고, 그 체인이
> `ball_round_cleanup.reset_for_ball_reset` → `actor_cleanup.reset_actor_round_state`
> → `viper_jetpack_state.reset_round()`(→ `offset_y=0`) **그리고**
> `ball_round_controller`가 `player_pos.y = PLAYER_Y`로 정규화한다. 즉 Python처럼
> 별도 `_reset_viper_jetpack_state()`를 호출할 필요가 **없다**(Python의 `reset_ball`은
> 제트팩 오프셋을 안 건드려 명시적 리셋이 필요했지만 Godot `reset_ball`은 건드림).
> **금지**: 이 위에 중복 명시적 착지 호출을 추가하지 말 것. **가드 작성 완료** —
> `odins_eye_finalize_paddle_land_smoke`가 실 `reset_ball`+`ViperJetpackState`로
> finalize 후 `offset_y==0` / 패들 Y == `PLAYER_Y`를 단언한다. 이 가드가
> `build_reset_config`의 라이브-공중-y 보존 근본 버그를 잡았고
> (`player_y = height − player_paddle_height`로 수정), 표준 룰은
> `docs/item_runtime_checklist.md` §7.2.1에 백필됨.

---

## 5. 페널티 상태 모델

`odins_eye_state.gd` 파생 getter (Python 대응):

| getter | 값 | Python |
|---|---|---|
| `get_move_speed_mult()` | 0.5 (변신/페널티 시) | 이동속도 −50% |
| `get_dash_token_limit()` | 1 | `get_dash_token_limit()` (L26017 등) |
| `get_dash_cooldown_mult()` | 2.0 (+100%) | `get_dash_cooldown_multiplier()` (L91463) |

- 소비는 **기존 Godot 대시-토큰 / 쿨다운 / 이동속도 owner 필드 경유**로 한다
  (Horn Strawberry의 `get_move_speed()` 오버라이드와 동형). 신규 병렬 시스템 금지.
- 5개 캐릭터의 스킬-차단 게이트: Python은 `is_odins_eye_transformed()`가 30+
  사이트(전 캐릭 스킬 차단·옵티머스 팔·바이퍼 제트팩 등, L48744 / L61559 /
  L89401 …)에 박혀 있다. Godot은 이미 `is_horn_strawberry_skills_locked` 류
  게이트가 있으므로 **동일 지점에 오딘 변신 게이트를 OR로 합류**시킨다.
  (이 폭이 Phase 1에서 가장 손이 많이 가는 부분 — 슬라이스 시 캐릭터별 게이트
  목록을 먼저 grep으로 확정.)

---

## 6. 단계별 슬라이스

각 슬라이스 = 백본 + 전용 smoke + 트랩 브리프.

### Phase 0 — 등록 & 스캐폴딩
- 신규 `odins_eye_state.gd` / `mythic_item_odins_eye_runtime.gd`.
- `mythic_item_helper_registry.gd` INIT_ORDER + SCRIPT_PATHS 등록.
- `mythic_item_runtime.gd` var 선언 + `try_trigger_odins_eye_*` 퍼사드.
- 카탈로그 7종: base(`slot="belt"`) / rolls(`revival_chance` 30~45) /
  roll_definitions / fixed_options / icon_metadata / spawn_metadata /
  presentation / lists.
- 로컬라이즈 키("오딘의 눈" / "Odin's Eye" / 설명·롤 라벨), `localization/*.json`.
- **`BattleSceneState.DEFAULT_VALUES`** 에 owner 동기화 키 선언
  (`penalty_active`, `revival_used`, dash 토큰 한계, 쿨 배수 등).
- smoke: 카탈로그 build_item_by_name 비어있지 않음 + 롤 범위(30~45,
  polish/enhancement 합산) 검증.

### Phase 1 — 부활 + 페널티 코어 (게임플레이 MVP ⭐ 1차 목표)
- §4 트리거 분기 + finalize(§4.2) + §5 페널티 효과 + 5캐릭 스킬 게이트 합류.
- 페널티 해제(랠리 승리) / 페널티 중 실점 → 죽음 연출 → 진짜 패배.
- 라운드/스테이지/메뉴 경계 정책(§8) + 전용 boundary smoke.
- smoke(OUTCOME 단위): 실점 무효화 → 페널티 진입 → 페널티 중 실점=패배 →
  승리 시 해제, **패들 착지 회귀**, **경계 누수 회귀**(연출 도중 라운드 끊김).

### Phase 2 — 변신 정체성 & VFX (모듈러 + 절차적)
**진행 순서: 죽음 시네마틱 먼저** (현 1.2s placeholder 체감 보강) → 부활 시네마틱
→ 페널티-폼 지속 VFX.
- **죽음 시네마틱 (착수)** — 디자인 노트: `docs/odins_eye_death_cinematic_design.md`.
  결정: ~2.5s 3페이즈(축적/폭발/분해) + 모듈러+절차적 분해. 백본 = 상태머신에
  페이즈/진행도 노출(현재 단일 `death_timer_sec`만). finalize 계약 불변.
- 부활 시네마틱(형제): 어둠 구체 → 폭발 → 땅에서 솟아오르기.
- 페널티-폼 지속: 잔상(afterimage), **대시 다이브(땅속 잠수)**, 화면 흔들림.
  immediate-draw 캐릭터면 노드 fx_host 불가 → in-place 텍스처(링펫 컷인 패턴,
  [[project_lingpet_acquire_portal_modular_vfx]]).
- 변신 사운드(`odinchange.wav` 등가) 배선.

### Phase 3 — 어둠의 늪 액티브 스킬 + 럴커 가시 (선택 / 후순위)
- 변신 폼 전용 5-오브 스킬: 게이지 100 소모, 2초 쿨, 보스 방향 럴커 가시.
- 오브 HUD + 툴팁(이펙트 미리보기 포함, §7.5) + 스킬-골드 정책 + 효과 한 세트.
- **분량을 가장 크게 가르는 슬라이스.** 1차 MVP에서 제외 권장.

### Phase 4 — 변신 캐릭터 스프라이트
- AutoSprite 기반(원본은 절차적 실루엣). `sprite-generation` 스킬 경유.

---

## 7. 불변식 체크리스트 (배선 전 확인)

- [ ] **Owner-Field 스키마 트랩** — owner로 동기화하는 키 전부
  `BattleSceneState.DEFAULT_VALUES`에 선언. 미선언 `set()`은 조용히 no-op이고
  reader는 fallback(카탈로그 base)으로 떨어져 "값이 같을 때만" 정상처럼 보임.
  발산 케이스(페널티로 base와 달라질 때)로 테스트.
- [x] **§7.2 패들 착지** — Phase 1에서 `reset_ball` 재사용으로 충족(§4.2 박스 참조).
  중복 명시적 착지 호출 금지. **가드 작성 완료**: `odins_eye_finalize_paddle_land_smoke`가
  실제 reset 체인+`ViperJetpackState`로 `offset_y==0`/`player_pos.y==floor`를 단언하며,
  이 과정에서 `build_reset_config`가 라이브 공중 y를 보존하던 **근본 버그 1건을 잡음**
  (`player_y = height − player_paddle_height`로 수정). 표준 룰은
  `docs/item_runtime_checklist.md` §7.2.1에 백필.
- [ ] **부활/죽음 연출 중 점수·패배 정지** — 전역 anim 플래그 등가물.
- [ ] **ball_vel = px/frame** — 공 숨김/리셋/발사 시 단위 준수
  ([[feedback_godot_ball_vel_pxframe_units]]). smoke FakeOwner도 px/frame.
- [ ] **5캐릭 스킬 게이트 합류 누락 없음** — grep으로 게이트 사이트 확정 후 OR 합류.
- [ ] **schema-gated owner로 smoke** — 임의 키를 저장하는 dict FakeOwner는 이
  트랩을 통과시키므로 `BattleSceneState` 위임 owner 사용.

---

## 8. 라운드 / 스테이지 / 메뉴 경계 정책 (§7.8 매트릭스)

Python은 이 정책을 단일 reset 콜사이트로 정의하지 않으므로 **Godot 포팅이 정책을
소유**한다. Phase 0 스캐폴딩이 아래 정책을 코드로 확정했다(`odins_eye_state.gd`).
boundary smoke로 봉인 예정(Phase 1).

| 경계 이벤트 | 변신/연출 상태 | 페널티 상태 | `revival_used` | 담당 메서드 |
|---|---|---|---|---|
| 라운드 전환(실점 후 새 서브) | 정리(finalize 플래그만) | **유지**(승리/죽음까지) | **유지** | `reset_round()` |
| 페널티 해제(랠리 승리) | 정리 | 해제 | 리셋 | `clear_after_victory()` |
| 진짜 패배(죽음 연출 완료) | 정리 | 정리 | **리셋(†)** | `clear_after_death()` |
| 스테이지 전환 | 정리 | 정리 | 리셋 | `on_stage_advance()` |
| 게임 리셋 / 메인메뉴 | 정리 | 정리 | 리셋 | `reset_all()` |

**확정 정책 = "부활은 한 페널티-사이클(생애) 1회".** `reset_round()`는 의도적으로
`penalty_active`/`revival_used`를 보존하므로, 페널티는 라운드를 넘어 유지되고 추가
부활은 `not penalty_active` 게이트로 막힌다. 재충전은 **페널티 해제(승리) / 죽음 /
스테이지 / 게임 리셋** 시점에만 일어난다.

> **[x] 배선됨 (2026-06-10) — "페널티 해제(랠리 승리)" 행.** `clear_after_victory()`
> 는 정의돼 있었으나 **런타임 호출처가 없어** 플레이어가 페널티 중 득점해도 페널티가
> 유지되는 회귀가 있었다(다음 보스 득점이 `is_odins_eye_penalty_active()`를 보고 죽음
> 시퀀스로 라우팅 → 득점했는데도 사망). 수정: `match_score_event_controller`의
> 플레이어-득점 경로에 `_clear_odins_eye_penalty_after_player_victory()`를 추가
> (penalty-active 게이트 + 클리어 후 `_sync_mythic_owner`). `odins_eye_revival_penalty_smoke`
> 에 **실제 컨트롤러 경로**를 거치는 플레이어-승리 케이스를 추가해 봉인(수정 제거 시 FAIL
> 검증 완료). 나머지 경계 행(라운드 보존 / 스테이지·게임 리셋)은 여전히
> `odins_eye_round_boundary_smoke`로 별도 봉인 예정.

> **의도적 분기 기록**([[feedback_default_target_godot]]): Python은 normal-loss
> 경로의 `reset_for_new_round()`에서 매 실점마다 `revival_used`/`penalty_active`를
> 리셋하지만(부활-성공 경로는 `return`으로 건너뜀), Godot은 round 경계에서 보존하고
> 위 4지점에서만 리셋한다. 실전 거동은 수렴한다(부활 성공은 항상 페널티 진입이라
> "부활했으나 페널티 아님" 상태가 없음). 단 **(†) 비-매치-종료 페널티-죽음**에서
> Python은 다음 라운드에 재무장하므로, Godot도 죽음 finalize 시 반드시
> `clear_after_death()`를 호출해 `revival_used`를 리셋해야 한다. `update()`의 죽음
> finalize는 `penalty_active=false`만 처리하고 `revival_used`는 건드리지 않으므로,
> **이 호출을 빠뜨리면 비-매치-종료 페널티-죽음 후 다음 라운드 부활이 재무장되지
> 않는다(Python 대비 회귀).** boundary smoke에 이 케이스를 명시 포함할 것.

---

## 9. smoke 테스트 목록 (예정)

- `odins_eye_catalog_smoke` — 등록/롤 범위(Phase 0).
- [x] `odins_eye_revival_penalty_smoke` — 실점 무효화·페널티 진입·**랠리 승리 시 해제+재무장**·죽음 OUTCOME(Phase 1, **작성됨**; 승리-해제 케이스가 §8 페널티-해제 행을 봉인, 컨트롤러 경로 경유).
- [x] `odins_eye_finalize_paddle_land_smoke` — 체공 중 부활 시 착지 회귀(§7.2, **작성됨**, 근본 버그 1건 잡음).
- `odins_eye_round_boundary_smoke` — 나머지 경계 정책 매트릭스 봉인(§8: 라운드 보존 / 스테이지·게임 리셋, Phase 1).
- (Phase 3) `odins_eye_dark_swamp_skill_smoke`.

---

## 10. 열린 결정 / 유보 항목

1. **등급 = mythic** — 권장 확정.
2. **1차 범위 = Phase 0–1** — 권장. Phase 2 VFX / Phase 3 스킬은 후속 슬라이스.
3. **아이콘** — 원본 `icon_path=None`(고유 애니). Godot mythic 그리드용 정적
   아이콘과 32프레임 mythic 시트를 `item-generation` 경로로 생성 완료:
   `res://assets/sprites/items/odins_eye.png`,
   `res://assets/sprites/items/odins_eye_icon_sheet.png`.
   `odins_eye_catalog_smoke`가 `ProjectResourceLoader.load_texture()`와
   정적 32×32 / 시트 1024×32 크기를 함께 봉인한다.
4. **부활 1회 스코프** — "스테이지 1회 vs 페널티-해제 시 재충전"을 §8에서 결정·봉인.
5. **연쇄 부활(Yachaman Soul + Odin) — 유보.** §7.7은 Yachaman Soul이 Godot에
   포팅된 뒤에야 의미가 있다. **Yachaman은 현재 Python 전용 / Godot 미포팅**이므로
   본 포팅에서는 takeover 클린업 배선을 넣지 않고, Yachaman 포팅 시점에
   `docs/item_runtime_checklist.md` §7.7 매트릭스에 Godot 행을 추가한다.

---

## 11. 핵심 앵커 빠른 참조

| 항목 | 위치 |
|---|---|
| Python 클래스 | `legendary_items.py` `class OdinsEye` (≈ L6644) |
| Python 부활 트리거(듀스/일반) | `pingfighter.py` ≈ L172540–172719 |
| Python 부활 연출 시작(+플래그) | `legendary_items.py` `start_revival_animation` (L7819, 플래그 L7859) |
| Python finalize(착지) | `pingfighter.py` `if animation_complete:` (L188872) |
| Godot 실점 핸들러 | `match_score_event_controller.gd` `handle_score_event` (L6), `_try_trigger_revival` (L208) |
| Godot 단순부활 템플릿 | `revival_state.gd`, `mythic_item_revival_runtime.gd` |
| Godot 변신 템플릿 | `mythic_item_horn_strawberry_mask_state.gd` |
| Godot 등록 | `mythic_item_helper_registry.gd`, `mythic_item_runtime.gd`, `mythic_item_catalog_*.gd` |
| 런타임 통합 불변식 | `docs/item_runtime_checklist.md` §7 |
