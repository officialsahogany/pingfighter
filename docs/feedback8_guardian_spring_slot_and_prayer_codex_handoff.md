# 지시문 X1 — [P0] 수호의 샘터 기능 결함 2종 (초식 만석 거절 · 기도 무제한 재시전)

- **발행**: 관제탑 2026-08-26. 대상: 본 트리 `d:\main\bosspong` HEAD `ea3d864bb`
  기준 **격리 워크트리 + 격리 브랜치**. 본 트리 편집·통합·푸시 금지.
- **선행 차단 조건**: ⚠**W5 `77efc52f9`(상점 좌우분할) 통합 이후에 착수하라.**
  W5가 `tower_ascent_flow_node_progress.gd`(+35)와
  `tower_ascent_node_modal_state.gd`(+194)를 건드리고 이 지시문도 같은 두
  파일을 반드시 편집한다. 통합 전에 착수하면 재작업이 확정이다.
  관제탑이 W5 통합을 마치면 그 커밋 해시를 기준선으로 다시 알린다.
- **범위**: 아래 A·B **둘만**. 연출·문구 은폐·수호령 스킬은 별도 지시문이다.

---

## A [P0] 초식 슬롯 5/5에서 "손바닥을 대본다"가 `effect_rejected`를 뱉는다

### 관측

초식 슬롯이 5/5인 상태에서 손바닥 카드를 누르면 2초 의식을 다 재생한 뒤
모달 상태문에 **`effect_rejected`** 라는 내부 문자열이 그대로 뜬다.

### 확정된 진범 (프로브 실측 · 추측 아님)

**교체 UI는 실제로 열린다. 그 신호가 `bool` 경계에서 소실되고, 곧바로
롤백이 방금 연 교체를 파괴한다.**

체인:

```
팜 카드 클릭 → 2초 의식 → TowerAscentGuardianSpringNode.execute_action
  → apply_once(effect=_apply_operation) → _apply_soul_summoning_unlock
  → RuntimePerkState.apply_choice → RuntimePerkChoiceApplyFlow PATH_UNLOCK
  → RuntimePerkUnlockChoiceApply.apply_choice
```

1. `runtime_perk_unlock_choice_apply.gd:71` — 슬롯 만석이면
   `_start_pending_unlock_swap()`이
   `{"accepted": false, "pending_swap_started": true}`를 반환한다.
   **이건 설계된 정상 동작이다.** `runtime_perk_unlock_choice_apply_smoke.gd:77~78`이
   `"slot-full unlock should not complete until swap confirm"` /
   `"slot-full unlock should start the pending swap"`으로 이미 씰을 박아
   "accepted=false는 실패가 아니라 교체 확인 대기"임을 문서화하고 있다.
2. **★신호 소실**: `runtime_perk_state.gd:1427`이
   `return bool(result.get("accepted", false))`로 dict를 납작하게 눌러
   `pending_swap_started`를 버린다.
3. `tower_ascent_guardian_spring_node.gd:976`이 그 false를 그대로 실패로
   승격 → `:814` `_apply_operation`의 OP_PALM 분기가 `:858~864`에서
   `_rollback_operation` 호출.
4. **★2차 파괴**: `:1038` `_rollback_operation`이
   `cancel_pending_unlock_swap`을 호출해 **방금 열린 교체 대기를 같은
   프레임에 취소한다.** 렌더러를 붙여도 이 줄을 손보지 않으면 화면에 안 뜬다.
5. `tower_ascent_node_action_transaction.gd:34`가 `reason: "effect_rejected"`
   dict를 만들고(`message` 키 없음), `tower_ascent_flow_node_progress.gd:584`의
   `str(result.get("message", result.get("reason", "")))` 폴백이 raw reason을
   모달 상태문에 그대로 그린다.

형제 소비자 둘은 이 계약을 **올바로 구현하고 있다** — `tower_reward_pick_state.gd:381`
(`_begin_vision_swap`), `tower_ascent_fallen_monk_node.gd:145`. **샘터만 모른다.**

### 반증 완료 (재조사 금지)

- ✔**"unlocks_skill이면 슬롯 미소모"는 무공 슬롯(6/7) 한정이다.**
  초식 오브 슬롯(5)은 **실제로 소모한다** —
  `smasher_skill_config.gd:308` `unlock_and_equip_skill`이
  `equipped_skills.size() >= get_max_skill_slots()`에서 false를 반환하고,
  `common_skill_catalog.gd:548` 주석이
  `"The battle Chosik orb still occupies one of the five combat slots"`라고
  명시한다. 5/5 거절 자체는 정당하다.
- ✔W1 `ddd9cde18`은 이 경로를 막지 않는다. W1의 `_validate_perk_slot_delta`는
  `is_slot_consuming_perk`가 false라 `extra_slots == 0` → 무조건 accepted.
  W1은 무공 슬롯 게이트만 중앙화했다.
- ✔관련 파일 전부 clean. **미커밋 WIP 탓이 아니다.**
- ✔기존 씰 3종(`tower_ascent_guardian_spring_node_smoke`,
  `runtime_perk_unlock_choice_apply_smoke`,
  `tower_guardian_spring_chosik_bridge_smoke`) PASS=3 FAIL=0.
  **GREEN인데 버그가 산다 = 씰 공백이다.**

### 사용자 확정 사양

> 초식 슬롯이 가득 찼을 경우, 손바닥 연출 후 **초식 슬롯 교체 UI**가 떠야 한다.
> 형태는 **5지선다 교체창** — 플레이어가 다섯 초식 중 무엇을 버릴지 직접 고른다.
> (1:1 결정적 교체 카드는 **반려**됐다.)

### 수리 방향

**`tower_reward_pick_state`의 2단 패턴을 이식하라.** 같은 노드 안에
수호령용 2단 패턴(browse compare)이 이미 있어 구조 선례가 두 겹이다.

1. **신호 보존.** `_apply_soul_summoning_unlock`이 bool 대신 상태로 판별하게
   하라. 정본 사례는 `runtime_perk_state.gd:877`
   `begin_tower_reward_unlock_swap` — `apply_choice` 반환값을 **의도적으로
   무시하고** `has_pending_unlock_swap()`으로 성패를 판정한다.
   ⚠`runtime_perk_state.gd:1427`의 `bool()` 납작화 **자체를 바꾸지 마라.**
   다른 호출자 전원이 그 시그니처에 묶여 있다. 샘터 쪽에서 판정하라.
2. **롤백 예외.** `:1038`의 `cancel_pending_unlock_swap`을 **삭제하지 마라.**
   그것은 진짜 실패(스냅샷 캡처 실패 `:823`, 첫뽑기/강화 실패)에서 반쪽
   상태를 청소하려고 존재한다. 무조건 제거하면 다른 실패 경로에 유령 교체
   대기가 남는다. **"의도적으로 연 교체"와 "실패 잔여물"을 구분하는 술어**를
   만들고 `_apply_operation`의 `:858~864` 분기를 갈라라.
3. **상태 보관.** `_state`에 `pending_chosik_swap`류 필드를 두고
   `has_pending_browse_compare` / `cancel_browse_compare` /
   `commit_browse_purchase`(`:295~385`)와 **대칭인 3종 API**를 신설하라.
   flow 배선도 `tower_ascent_flow_node_progress.gd:607~640` 블록과 대칭으로.
4. **★확정 레그 후처리 (누락 시 2차 사고).** 교체가 confirm되면 현재 성공
   경로가 한 덩어리로 하던 것을 **전부 재현**하라 —
   `soul_summoning_owned=true`(`:820`), `soul_summoning_node_id`,
   `_capture_committed_soul_unlock_snapshots`(`:823`),
   `first_pick_candidates` 시딩(`:828~832`), history append +
   `_capture_committed_runtime_snapshot`(`:286~289`).
   **누락하면 "교체는 됐는데 첫 수호령 선택 카드가 안 뜬다"가 된다(GRT-031).**
5. **UI 호스트 = 자립 오버레이.** `lingpet_overflow_choice_overlay_host.gd`
   패턴으로 타워 전용 오버레이 호스트를 세우고
   `runtime_perk_unlock_swap_layout` + `_draw_unlock_swap_dialog`를 재사용하라.
   타워 `flow_renderer`를 안 건드려도 되고 5지선다가 살아난다.
   ⚠**GRT-058**: 새 진입점은 형제 모달의 개폐 훅을 상속하지 않는다.
   `tower_ascent_node_modal_state`의 개폐 계약을 관통시켜라.
   ⚠`battle_scene_input_controller.gd:207~232` 오버레이 화이트리스트에는
   현재 `overflow_choice`와 `acquire_cutin` **둘만** 등재돼 있다.
   **신규 오버레이를 등재하지 않으면 타워 flow가 예/아니오 클릭을 먹는다.**
6. **표시 수리 (독립 착지 가능, 저위험).** `effect_rejected`가 화면에
   안 뜨게 하라. **권장안**: `tower_ascent_flow_node_progress.gd`의 상태문
   싱크 **두 곳(`:409`, `:584`) 모두**에서 raw reason 노출을 차단하고
   미매핑 reason에는 범용 문구를 쓴다. `:409`는 **모든 노드 종류**가
   지나가므로 이 한 수리가 계열 전체를 막는다.
   대조군: 상점은 같은 reason을 `KEY_SHOP_SLOT_FULL`로 번역한다
   (`tower_ascent_flow_economy_progress.gd:416~420`).
7. **팜 카드 UX.** 5/5여도 카드는 **활성 유지**가 맞다(교체가 정상 경로다).
   `get_shared_slot_swap_candidates`는 대상 스킬이 이미 장착됐을 때만 빈
   배열을 주므로 팜 시점 5/5에서 후보는 항상 5개 — "교체 불가"는 구조상
   발생하지 않는다. 카드 설명이나 배지에 "초식 교체 필요" 힌트를 넣어라
   (`tower_reward_pick_offer_builder.gd:167~171`의 `vision_swap_required`
   접미 처리와 일관되게).

---

## B [P1] "기도한다"가 한 방문에서 무제한 재시전된다

### 관측

무혼만 있으면 같은 샘터에서 기도를 계속 반복할 수 있다.

### 확정된 진범

**방문당 1회 가드가 아예 없다.** 유일한 가드는 런 단위 영구 잠금
`_prayer_locked`이고, 그건 첫 수호령 획득(`_apply_first_pick`,
`tower_ascent_guardian_spring_node.gd:887`)에서만 걸린다. 그 전까지는 무방비다.

- 비용 램프(0→2→4→+2)는 **방문 단위가 아니라 시전 단위**
  (`TowerAscentRunState._prayer_count`)다.
- 효과 +3.0도 count에 **선형 중첩**된다.
- 트랜잭션 중복 커밋 가드(`execute_action:229`)는 있지만, 액션 id가
  `guardian_spring:prayer:{count}`로 시전 횟수를 품기 때문에(`:446`)
  매 시전이 새 resolution_id를 얻어 **절대 트립하지 않는다.**
  비용 램프를 시전 단위로 구현한 선택이 곧 재실행 가드를 무력화한 원인이다.

### ★씰 충돌 (최우선 · 사용자 승인 완료)

`godot/tests/tower_guardian_spring_stage2_smoke.gd:124~143`이 **동일 node_id에서
3연속 기도 + 0/2/4 램프 + 총 6무혼 차감을 명시적으로 단언한다.**
즉 현재 동작은 버그가 아니라 **잘못 봉인된 사양**이다.

방문당 1회를 넣으면 이 씰은 즉시 RED다. **같은 커밋에서 재작성하라.**
CI 243 / pre-push 243 락스텝을 함께 갱신하라. 씰을 지우지 말고
"한 방문 1회 + 노드 이동마다 비용 상승"으로 **의미를 바꿔 재작성**하라.

### 사용자 확정 사양

> - 기도는 **방문당 1회**.
> - 손바닥과 기도 중 **하나만** 고를 수 있다. 하나를 쓰면 그 방문의 샘터
>   업무가 끝나고 **바로 노드 경로선택(ROUTE_AIM)으로 넘어간다.**
> - 결과 문구는 **"모든 능력치가 3.0%p 상승했다!"** — `%p`로 통일한다.
>   카드 설명이 이미 `%p`이고 구현도 체질수련과 **가산**되는 `%p` lane이다.
>   문구만 `%`로 쓰면 카드와 갈려 그 자체가 새 결함이 된다.
> - **런당 누적 상한은 두지 않는다.** 비용이 무료→2→4→6무혼으로 오르는 것이
>   실질 상한 역할을 한다.

### 수리 방향

1. **방문당 1회.** 신규 상태를 만들지 마라. 이미 있는
   `_operation_count(node_id, OP_PRAYER)`(`:1266`)를 재사용해
   `build_actions:210`의 조건을
   `not _prayer_locked and _operation_count(node_id, OP_PRAYER) == 0`으로 좁혀라.
   **권장 표현**: 휴식 노드 정본(`tower_ascent_rest_node.gd:31~47`)처럼
   카드를 **남기되 `enabled=false` + 전용 사유 문구**를 노출하라.
   "이번 방문엔 이미 기도했다"를 플레이어가 알 수 있다.
   비용 램프는 **손대지 마라** — 1회 가드가 걸리는 순간 시전 누계 == 방문
   누계가 되어 확정 사양(무료→2→4→+2)과 자동으로 일치한다.
   ⚠단 롤백 경로(`_capture_rollback:1023`, `restore_guardian_prayer_state`)의
   의미론이 '시전' 기준이므로 주석으로 명시 선언하라.
2. **한 방문 한 행동.** 손바닥·기도 중 하나가 커밋되면 나머지 카드도
   그 방문에서 닫아라. 위 `_operation_count` 술어를 두 액션에 대칭 적용하면
   된다.
3. **★자동 진행 — 정본 패턴이 없다.** 상점·수련장·휴식·타락승 전부 커밋 후
   모달을 유지하고, ROUTE_AIM 진입은 ESC 또는 `end_work` 카드 두 경로뿐이다.
   **새로 만들되 반드시 기존 종료구를 통과시켜라.**
   - 호출 지점: `tower_ascent_flow_runtime.gd:504` 폴링 레인.
   - 반드시 `_try_enter_route_aim_from_node_modal()` **하나만** 통과시켜라.
   - ⚠`_enter_route_aim`(`tower_ascent_flow_map_progress.gd:492~508`)을 직접
     복제하면 **브라우즈 비교 대기 거부 로직이 깨지고, 바람 롤·픽업 롤이
     `_gameplay_rng_state`를 전진시키는 순서가 어긋나 런 재현성이 깨진다.**
   - ⚠**GRT-058**: 자동 진행은 새 종료 진입점이다. 기존 ESC/end_work 경로와
     **동일한 부수효과 집합**(쿨다운 pause/resume, 공 freeze, 실점 차단 훅)을
     통과하는지 확인하라.
4. **★문구 → 자동 진행 순서 함정.** `_enter_route_aim`이
   `_node_modal_state.close()`를 부르고 `close()`가 `_interaction_receipt`를
   **즉시 파기한다**(`tower_ascent_node_modal_state.gd:135`).
   커밋 직후 자동 진행하면 420ms 영수증이 **한 프레임도 안 그려진다.**
   순서는 반드시:

   ```
   의식 시작 → 2초 경과 → 커밋 → 결과 문구 표시 → 짧은 유지 구간
     → _try_enter_route_aim_from_node_modal()
   ```

   ⚠자동 진행이 의식 종료 **전에** `close()`를 부르면
   `tower_guardian_spring_presentation_smoke.gd:280`의 `forced_cleanup_count`가
   올라 그 씰이 RED가 된다.
5. ⚠**기도 2초 연출은 이 지시문의 범위가 아니다.** 별도 지시문 X3이 소유한다.
   여기서는 **커밋 → 문구 → 자동 진행**의 기능 골격만 세우고, 연출 훅이
   들어갈 자리를 남겨라(현재 의식 상태기계가
   `tower_guardian_spring_presentation_state.gd:125`에서
   `operation == "palm"`으로 하드 게이트돼 있다는 사실만 기록하라).

---

## 통합 충돌 (반드시 읽어라)

- ⚠**W5 `77efc52f9`**: `tower_ascent_flow_node_progress.gd`(+35, 훅 위치
  `get_node_modal_render_context` `:112` 부근 / `_open_node_modal` `:206` 부근),
  `tower_ascent_node_modal_state.gd`(+194). **둘 다 이 지시문이 편집할 파일이다.**
  선행 통합 필수.
- ⚠**W1 `ddd9cde18`**: `tower_ascent_node_modal_localization.gd` +2줄.
  신규 `KEY_SPRING_*` 문구가 들어갈 바로 그 파일이다. W1은
  `KEY_MONK_MUGONG_SLOT_FULL` 상수를 const 블록(`:58` 부근)과 `TEXT_BY_LOCALE`
  ko 딕트(`:148` 부근) 두 곳에 넣는다. 키 추가 위치를 조율하라.
- ⚠**W1 2차**: `runtime_perk_catalog.gd`, `runtime_perk_choice_apply_flow.gd`,
  `tower_ascent_fallen_monk_node.gd`. **fallen_monk의 교체 로직을 공용
  헬퍼로 승격시키지 마라** — W1의 57줄 변경과 정면 충돌한다. 승격은 W1 통합
  이후 별건으로.
- ✔**W3 `590eab580`**: 겹침 없음.

## 함정 (기존 GRT)

- **GRT-031** 반쪽 랜딩 — 교체 UI만 얹고 confirm 후처리(A-4)를 빠뜨리면
  "교체는 됐는데 수호령 선택이 안 뜬다"가 된다.
- **GRT-048** 덕타이핑 arity — `runtime_state.call("begin_tower_reward_unlock_swap", ...)`
  계열을 새로 호출할 때 인자수를 파서가 검증하지 못한다.
  **형제 호출부에서 복붙하지 말고 대상 시그니처를 직접 대조하라.**
- **GRT-054** 파생 임계값 리터럴 — 초식 상한 `5`를 하드코딩하지 마라.
  반드시 `get_max_skill_slots()`를 경유하라(천문/광맥결류로 6이 될 수 있다).
- **GRT-050** — 의식 중 입력은 `discard_all_no_skip` 정책
  (`tower_guardian_spring_presentation_state.gd:253`)으로 **버린다**.
  자동 진행 시 그 사이 눌린 입력이 ROUTE_AIM 조준으로 새지 않는지 확인하라.

## 씰 요구

**A 관련**

1. **신규 프로덕션 경로 씰(필수)**: 초식 슬롯을 실제로 5/5로 채운 픽스처에서
   `guardian_spring:palm`을 `build_actions` → `execute_action`으로 관통시켜
   **한 레그에 묶어** 단언하라 — (a) 반환 reason이 `effect_rejected`가 **아님**,
   (b) `has_pending_unlock_swap()`이 true로 **살아있음**,
   (c) `_rollback_operation`이 그 대기를 **취소하지 않았음**.
   셋을 갈라 놓으면 GRT-031 반쪽 랜딩을 못 막는다.
2. **확정 레그**: confirm 후 `has_soul_summoning()==true`,
   `equipped_skills`에 soul_summon_art 존재 + **선택한 기존 초식 제거**,
   `equipped_skills.size()`가 상한 이하 유지, `first_pick_candidates`가
   비어있지 않음, history 레코드 1건 append.
3. **RED 반증 2건(필수)**: (1) `has_pending_unlock_swap` 분기를 제거하면 다시
   `effect_rejected`가 나오는가, (2) 롤백의 cancel 호출을 되살리면 교체
   대기가 사라지는가. **각각 RED로 떨어져야 한다.**
4. **음성 대조군**: 4/5(만석 아님)에서는 교체 UI가 열리지 않고 곧바로
   accepted+applied로 커밋되는가.
5. **표시 씰**: 노드 모달 상태문에 `effect_rejected` 같은 raw 내부 reason이
   절대 실리지 않음을 `:409`·`:584` **양쪽 싱크 관통**으로 단언하라.
   ⚠문자열 소스 검색이 아니라 **실제 `get_node_modal_view_model()`의
   status text를 읽어라.**
6. **`item_skill_slot_bonus` 레그**: 슬롯이 6이 된 상태에서 5/5는 만석이
   아니어야 하고 교체 UI가 뜨면 안 된다(GRT-054 계열).
7. **캐릭터 라우팅**: 팜은 캐릭터 제한 없는 공용 초식이다. 최소 2종
   (스매셔 + 비스매셔) 레그로 `_get_skill_config_key` 라우팅을 확인하라.

**B 관련**

8. `tower_guardian_spring_stage2_smoke.gd:124~143` **재작성**:
   한 방문 1회 + 노드 이동마다 비용 상승(0→2→4)으로.
9. 자동 진행 레그: 커밋 후 문구가 **실제로 최소 1프레임 이상 그려진 뒤**
   ROUTE_AIM에 진입하는가. `forced_cleanup_count`가 오르지 않는가.
10. RNG 파리티 레그: 자동 진행 경로가 `_gameplay_rng_state`를 **정확히
    기존 ESC 경로와 동일하게 한 번만** 전진시키는가(차등 시드 대조).
11. 다국어: 신규 `KEY_SPRING_*`를 KO/EN/ZH/JA **4개 최소 동기화**.
    ⚠ES(`:384`)·RU(`:452`) 로케일 블록에는 기도 키가 **원래 없어 한국어로
    폴백한다**(선재 결함, 이번 수정이 만든 것이 아님). 신규 키를 어느
    범위까지 넣을지 보고에 명시하라.
    ⚠**한국어 카피 엠대시(—) 금지.** 멈춤은 마침표나 쉼표로.
12. **기존 씰 GREEN 유지 확인**: `tower_ascent_guardian_spring_node_smoke`,
    `tower_guardian_spring_chosik_bridge_smoke`,
    `tower_guardian_spring_runtime_path_smoke`,
    `runtime_perk_unlock_choice_apply_smoke`,
    `tower_ascent_fallen_monk_node_smoke`, `tower_reward_pick_smoke`,
    `perk_slot_limit_smoke`.
    ⚠`perk_slot_limit_smoke`는 **HEAD에서 이미 RED**다(슬롯 상한 단언이
    빈 오퍼 배열로 공허 GREEN인 별건). 착지 전후 실패 집합을 **바이트
    대조**해 늘지 않았음을 보여라.
13. 신규 오버레이를 만들면 **비헤드리스 픽셀 캡처**로 타워 지도 위에
    다이얼로그가 실제로 그려지는지, ESC/포인터 입력이 배후 노드 모달로
    새지 않는지(GRT-058), 취소 시 교체 대기가 정리되고 팜 카드가 원상
    복귀하는지 확인하라.
14. **CI/pre-push 락스텝**: 신규 스모크를 `godot-ci.yml`과
    `run_pre_push_checks.ps1` **양쪽에 동시 등재**(현재 243/243).
    배치 실행 시 종단선 `All Godot smoke tests passed.` 확인(GRT-035/GRT-040).

## 게이트·보고

포커스드 스모크(+RED 반증 2건) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` → 픽셀 QA.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라**(기존
BattlePerf 로그 소실 실사고 이력).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고에 반드시 포함: 커밋 해시 · 씰 종단선 **원문** · RED 반증 2건의 실제
출력 · 교체 UI 호스트 선택과 그 근거 · `forced_cleanup_count` 관측값 ·
`perk_slot_limit_smoke` 실패 집합 바이트 대조 결과 · 미해결.
