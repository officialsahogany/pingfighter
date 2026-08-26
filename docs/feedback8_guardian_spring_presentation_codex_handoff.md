# 지시문 X3 — 수호의 샘터 연출 개편 + 첫 방문 스포일러 은폐

- **발행**: 관제탑 2026-08-26. 대상: 본 트리 `d:\main\bosspong` 기준
  **격리 워크트리 + 격리 브랜치**. 본 트리 편집·통합·푸시 금지.
- **★선행 차단 조건 — 전부 해소됐다. 바로 착수하라.**
  1. ✔**W5 착지** `efaf3ffc9`. 그것이 바꾼
     `tower_ascent_flow_renderer.gd` · `tower_ascent_node_modal_state.gd` ·
     `tower_ascent_flow_node_progress.gd` · `runtime_perk_overlay_renderer.gd`
     는 **이 지시문이 편집할 4개 파일 전부**다. 그 위에서 작업하고 되돌리지 마라.
  2. ✔**X1 착지** `9713a91ec`. 교체 UI(자립 오버레이 호스트)와 자동 진행
     골격이 이미 있다. **이 지시문은 그 위에 연출을 얹는 것이다.**
- **기준선 = 본 트리 현재 HEAD.** 착수 직전
  `git -C d:\main\bosspong rev-parse HEAD` 로 확인하라(작성 시점 `9713a91ec`).

## ⚠X1 착지로 달라진 전제 (원문보다 이것이 우선한다)

이 문서는 X1 착지 **전에** 작성됐다. 아래는 이미 존재하니 새로 만들지 마라.

- `guardian_spring_chosik_swap_overlay_host.gd` — 5지선다 교체창 자립 호스트
- `guardian_spring_chosik_swap_input_router.gd` — 전용 입력 라우터.
  `battle_lingpet_priority_input_router` 의 `pre_overflow_modal_router` 로
  주입돼 있고 **모달 활성 시 입력을 항상 삼킨다.**
  ⚠**그 이음매 파일을 건드리지 마라.** 연출용 입력이 필요하면 이 라우터
  안에서 처리하거나 관제탑에 판정을 요청하라.
- 자동 진행 — 기존 종료구 `_try_enter_route_aim_from_node_modal` 만 통과한다.
  ⚠**복제하지 마라.** RNG 파리티가 깨진다.
- 방문당 1행동 + **첫 수호령 선택은 같은 방문 유지**.
  ⚠아래 5항 시나리오의 "수호령 선택 후 경로선택" 은 **이미 그렇게 동작한다.**
  연출만 얹으면 된다.
- 결과 문구 `"모든 능력치가 3.0%p 상승했습니다."` KO/EN/ZH/JA 등재됨.

**씰**: `tower_guardian_spring_slot_and_prayer_smoke`(신규 등재),
`battle_overlay_input_priority_preservation_smoke`(우선순위 3레그),
`tower_ascent_guardian_spring_node_smoke`, `tower_guardian_spring_stage2_smoke`
가 전부 GREEN 이다. **연출 개편이 이것들을 깨면 안 된다.**

⚠**CI/pre-push 는 249/249 다.** 신규 씰을 등재할 때 통째 교체하지 말고
필요한 줄만 추가하라. 최근 통째 교체로 형제 씰이 소실된 사고가 있었다.

---

## 담는 항목

| # | 사용자 요구 |
|---|---|
| 1 | 초식 슬롯 5/5에서 손바닥을 눌렀을 때 연출이 **총 3~4초** 더 화려하게 (텍스처 조각 + 셰이더 + 파티클 + 트윈) |
| 3-a | "기도한다"에도 **2초** 연출 + `"모든 능력치가 3.0%p 상승했다!"` 문구 |
| 4 | **첫 방문**에는 두 선택지에 어떤 정보도(툴팁 포함) 없어야 함 |
| 5 | 손바닥 → 영혼소환술 부상 → `"영혼소환술 초식을 배우시겠습니까?"` 예/아니오 → 예 → **수용 연출 3초** → 수호령 선택 → 바로 노드 경로선택 |

⚠3-a의 **기능**(방문당 1회 · 커밋 · 자동 진행)은 X1이 소유한다. 여기서는
**연출과 문구만** 얹어라.
⚠5의 **수호령 선택 후 route_aim 전이**도 X1의 자동 진행 골격을 재사용하라.
새로 만들지 마라.

## 타임라인 확정 (관제탑 판정)

사용자 문구가 "3~4초"와 "3초"로 갈려 있어 관제탑이 아래로 확정한다.
다르면 되물어라.

```
[손바닥 클릭]
  부상(ASCEND)        3.4s   영혼소환술이 아래에서 위로 떠오름
  리빌 홀드(REVEAL)   0.4s   정점에서 정지, 광휘 최대
  확인 대기(CONFIRM)  ∞      "영혼소환술 초식을 배우시겠습니까?" 예/아니오
  ├ 아니오 → 즉시 메뉴 복귀 (트랜잭션 미커밋)
  └ 예 ↓
  수용(ABSORB)        3.0s   초식이 몸으로 흡수됨
  임팩트(IMPACT)      0.4s   섬광 + 셰이크
  → 초식 슬롯 5/5면 교체창(X1 소유) / 아니면 첫 수호령 선택 카드
  → 수호령 선택 → route_aim (X1 자동 진행 골격 재사용)

[기도 클릭]
  기도(PRAYER)        2.0s   석상 글로우 램프 + 향연 모트
  결과 문구           유지구간  "모든 능력치가 3.0%p 상승했다!"
  → route_aim
```

## 현행 상태 (프로브 실측)

- **손바닥** = 연출이 있는 유일한 액션. `PHASE_RITUAL` **정확히 2.0초**.
  0→1.12s 초식 아이콘이 `(322,554)`에서 `(322,206)`으로 ease-out-cubic 부상 →
  1.18s에 `draw_tower_acquisition_absorption` 시작 → 2.0s에 팜 트랜잭션 디스패치.
- 시각 레이어는 **절차 3피스뿐** — 4겹 채움 원 + 5개 빛부채
  `draw_colored_polygon` + 14개 결정론적 빛점 + 석상 텍스처 + 실루엣 정합 글로우
  (`alpha 0.44 + 0.16*sin(7t)`).
  **텍스처 조각·셰이더·파티클·트윈 노드는 하나도 없다.**
- **기도** = **연출 0초.** 클릭 즉시 `execute_node_action` → 상태문구만 갱신.
  프레젠테이션 분기가 `tower_guardian_spring_presentation_state.gd:125`에서
  `operation == "palm"`으로 **하드 게이트**돼 있어 기도는 구조적으로 진입 불가.
- **오디오는 샘터 전 경로에 전무**(training 노드만 audio 객체를 받는다).
- 샘터 스크립트·자산·스모크는 전부 **CLEAN(커밋됨)**, 씰 GREEN(PASS=3 FAIL=0).

## 정본 템플릿 = 신화 획득 시네마틱

`mythic_item_acquisition_*`의 6페이즈 타임라인이 5항 시나리오와 **구조가 1:1**이다.

```
BUILDUP 1.2 / IGNITE 0.4 / WHITE_FADE 0.5 / REVEAL=클릭 게이트
  / ABSORB 1.5 / IMPACT 0.5   (클릭 제외 4.6초)
```

레이어도 요청 그대로다 — 텍스처 6장 + 셰이더 2종(`mythic_writhe`,
`mythic_arc_flow`) + `GPUParticles2D` 3종(ambient/burst/absorb) +
VisualEnvelope 트윈 + 셰이크/크로마 스플릿. 좌표계 `FIELD 760x750`이
타워 `BASE_VIEW_SIZE`와 **동일**하고, 전투 밖 결과화면 위로 z=1305로
띄우는 선례(`stage_clear_result_mythic_acquisition_handler`)까지 있다.

### ★그러나 호스트는 통째로 이식하지 마라

**관제탑 판정: 타임라인·레이어 레시피만 이식하고 호스트는 타워 도메인에
새로 세워라.** 두 가지 이유다.

1. **GRT-058 실체 위험 (측정됨)**: `battle_physics_gate_coordinator.gd:106`의
   타워 게이트가 `:128`의 신화 유지보수 펌프보다 **먼저 `return true`** 한다.
   신화 시네마틱을 그대로 붙이면 **업데이트 클록이 없어 첫 프레임에서
   얼어붙는다.** 스테이지 클리어 화면이 전용 핸들러를 따로 둔 이유가 정확히
   이것이다.
2. **GRT-031 WIP 오염**: `mythic_item_acquisition_presentation_factory` 등
   7개 추출 모듈은 HEAD에 커밋돼 있지만 **HEAD의 `cinematic_v2`는 그것들을
   쓰지 않는다**(자기 스모크만 소비). 모듈화 배선은 워크트리 미커밋 상태다.
   이 factory를 재사용하면 **생산 경로가 미커밋 WIP에만 존재하는 모듈**에
   의존하게 된다.
   ⚠`mythic_item_acquisition_cinematic_v2.gd`와 `mythic_backplate` /
   `shard` / `arc_ribbon` LFS 3장이 현재 워크트리 수정 상태다.

## 배선 순서

1. **타임라인 먼저.** `TowerGuardianSpringPresentationState`의 단일
   `PHASE_RITUAL`을 위 확정 타임라인대로 페이즈 열로 분해하고, 각 페이즈
   상수를 **이 파일 한 곳**에 명명 상수로 두어라.
2. **예/아니오 확인창.** 타워 노드 모달에는 없다.
   `lingpet_overflow_choice_overlay_host._draw_confirmation`의 레이아웃과
   **한글 조사 처리 로직**("OO으로 교체하시겠습니까?")을 타워 쪽으로 복제하되
   **오너는 타워 프레젠테이션 상태에 두어라**(도메인 결합 회피).
   문구 키는 기존 `main_menu.yes` / `main_menu.no`를 재사용하고 질문문만
   신규 키로 추가하라.
   ⚠**`battle_scene_input_controller.gd:207~232` 오버레이 화이트리스트에
   등재하라.** 현재 `overflow_choice`와 `acquire_cutin` 둘만 있다.
   등재하지 않으면 타워 flow가 예/아니오 클릭을 먹는다.
   ⚠확인 페이즈 동안 입력 정책을 `discard_all_no_skip`
   (`tower_guardian_spring_presentation_state.gd:253`)에서 **확인창 소유로
   전환**하라. 안 그러면 리추얼 폐기 정책이 확인창 클릭까지 삼킨다.
3. **★드로우 예산을 먼저 비워라 (GRT-043).**
   현재 피크가 **약 95 draw op/frame**이고 그중 **약 64가 흡수 트레일**이다
   (`draw_muhon_fallback` 4회 × 약 16드로). 물리가 완전 차단된 프레임에서
   72Hz로 재발행된다.
   화려화 전에 이 트레일을 **베이크 텍스처 또는 트레일 개수 축소**로 먼저
   줄여라. 그 여유 안에서 텍스처 조각 레이어를 얹어라.
   ⚠계측 라벨은 이미 있다: `draw.scene.tower_fullscreen_map`.
   **착수 전 라이브 1판으로 기준선을 캡처하라**(이번 조사에서는 이 트리에
   BattlePerf 로그가 없어 미측정 — 추정이 아니라 미실측이다).
4. **드로우는 우선 즉시모드 유지.** 파티클/셰이더가 꼭 필요하다고 판정되면
   그때 Node2D 호스트 도입을 **별도 결정 사항으로 관제탑에 올려라.**
   ⚠신화 시네마틱은 리테인드 `Sprite2D` + `GPUParticles2D`라 즉시모드 드로
   비용이 사실상 0이다. 즉 **화려하게 만들면서 드로 op는 오히려 줄일 수 있는
   구조**이므로, 예산이 정말 모자라면 리테인드 전환이 정답일 수 있다.
   그 판단 근거를 수치로 보고하라.
5. **기도 2초는 가장 저비용 레그.** 석상 글로우 램프 + 향연 모트면 충분하다.
   `:125`의 palm 하드 게이트를 **operation 화이트리스트(`palm`, `prayer`)**
   기반으로 일반화하고, `tower_ascent_flow_node_progress.gd:400`의 palm
   하드코딩 분기와 `:593` 완료 디스패치도 같은 화이트리스트로 태워라.
   ⚠기도는 수호령 획득이 아니므로 **absorption(카드→슬롯 흡수) 구간을
   재사용하지 마라.** 석상 발광·광선 팬 등 연출 피스만 공유하고 아이콘 흡수
   레그를 끄는 분기를 두어라.
   완료 액션 인출도 palm 전용 명칭에서 **중립 명칭으로 승격**하라.

## 신규 아트 — 3장 발주

재고 재조합으로 0장도 가능하지만 **GRT-047 위험이 정확히 거기에 걸린다.**
기존 재고는 신화=보라·금, 대성영단=주홍·금 계열이고 샘터는
**옥록**(`0.58,1.0,0.84` / `0.34,0.86,0.68`)이다. ADD 합성에서 재염색하면
발광이 죽는다.

**발주 3장 (관제탑이 프롬프트를 별도 발행한다)**

1. **옥록 문양환** 1024² — 회전 링, 알파 배경
2. **옥록 발광 배판** 1024² — ⚠**가운데가 찬** 밝은 레이어.
   GRT-047 준수: 더할 빛을 이 레이어가 공급한다.
3. **영혼소환 인장 파편** 512² — 파티클/트윈용 조각

재사용 가능 재고(재염색 없이 형태만): `mythic_acquisition` 6장
(backplate / shard / arc_ribbon / icon_backdrop / soft_vignette /
soft_white_flash), `daeseong` 범용 5장(rune_ring 내외 / glow_backplate v2 /
glory_rays / confetti_flakes), 샘터 4장, 영혼소환술 아이콘 2종.

⚠**콜드 프리웜**: 현재 4장 **80.7ms**(`COLD_PREWARM_USEC=80727`, 스모크 실측).
3장 추가하면 비례 증가하므로 **GRT-042 관점에서 스텝 프리웜 레인에 얹어라.**

---

## 4항 — 첫 방문 스포일러 은폐

### 현행 노출 문구 전수 (한국어)

생산자는 **단 하나**다 — `tower_ascent_guardian_spring_node.gd`의
`_build_palm_action()`(`:388~435`)과 `_build_prayer_action()`(`:438~496`).
카드 제목·배지·설명·비용·호버 상세가 전부 여기서 액션 Dictionary에 실려
나가고, 렌더러 2경로(샘터 프리젠테이션 / 에셋 미준비 폴백)가 **같은
`draw_tower_node_card()`를 소비**한다.
따라서 **은폐 지점은 액션 데이터 한 곳**이면 두 경로가 동시에 덮인다.

- **손바닥**: 이름 `"손바닥을 대본다"` / 배지 `"영혼소환술"` /
  설명 `"영혼소환술을 익혀 첫 수호령을 맞이합니다."` / 비용 `"무료"` /
  호버 `"현재 빈 자리 → 결과 영혼소환술"` + `"대상 손바닥을 대본다 · 비용 무료"`
- **기도**: 이름 `"기도한다"` / 배지 `"샘터 기도"` /
  설명 `"이번 런 동안 플레이어 전능력치가 3.0%p 상승합니다."` / 비용 `"무료"`(첫 회) /
  호버 `"현재 기도 0회 → 결과 전능력치 상승"` + `"대상 기도한다 · 비용 무료"`
- **★비문자 누출**: **두 카드 모두 수호령 알 아이콘**(`icon_id="guardian_spirit_egg"`)을
  그린다. **문구를 다 지워도 "기도한다"에 수호령 알이 박혀 있어 스포일러가 남는다.**

### 관제탑 확정

- **스코프 = 런 단위.** 프로필 단위로 가면 신규 영속 플래그와 씰이
  추가로 필요한데 얻는 게 적다. 로그라이트 관례상 매 런 불확실성이 맞다.
- **판정 술어**를 `guardian_spring_node.gd` 내부에 단일 함수로 신설하라:

  ```gdscript
  func _is_spoiler_free_first_visit(run_state) -> bool:
      return (not has_soul_summoning()
          and _prayer_count(run_state) == 0
          and get_history().is_empty())
  ```

  세 신호 모두 **이미 스냅샷에 실려 있어** 세이브/재개를 넘는다.
  **추가 저장 스키마 불필요** — `SNAPSHOT_SCHEMA_VERSION` 유지.
  정의는 "아직 샘터 조작을 한 번도 커밋하지 않음"이다. 모달을 열었다 그냥
  닫은 것은 방문으로 치지 않는다.
- **아이콘도 가린다.** 첫 방문에는 중립 심볼로 대체하라. 문구만 지우면
  은폐가 반쪽이다.
- **비용 표기도 가린다.** 첫 방문엔 두 카드 모두 `"무료"`라 **정보 손실이
  0**이다. ⚠단 2회차부터 2·4·6 무혼으로 오르므로 **`prayer_count == 0`
  구간으로만 한정하라.** 가격 은폐가 이어지면 플레이어가 잔액을 모르고
  소모하는 조작 신뢰 문제가 된다.
- **복귀 시점**: 기도를 한 번 하면 같은 방문 안에서 카드 목록이 즉시
  재빌드된다(`_refresh_guardian_spring_modal`). **그 순간 바로 정보가
  나타나게 하라.** 술어가 이미 그렇게 동작한다.

### 은폐 구현

1. **액션 데이터 한 곳에서만** 하라. `_build_palm_action` / `_build_prayer_action`에
   **기본값 있는 파라미터**(`spoiler_free := false`)를 추가하고, 참일 때
   `choice.description=""`, `presentation={}`, `cost_text=""`로 내보내라.
   ⚠**`payload.cost`, 액션 ID, `enabled`, `disabled_reason`은 그대로 두어라.**
   그것들은 표시가 아니라 **트랜잭션 계약**이다(`:254` 차감,
   `tower_guardian_spring_stage2_smoke.gd:124`·`:127~128`).
   표시 은폐가 데이터까지 건드리면 결제가 깨진다.
2. ⚠**GRT-048 확정 위험**: `tower_guardian_spring_rest_card_adapter_smoke.gd:184`가
   `spring.call("_build_palm_action", true)`로 **인자 1개 동적 호출**을 한다.
   **새 파라미터에 기본값을 주지 않으면 그 레그 실행 시점에만 터진다.**
3. **★배지 폴백 트랩**: `level_text`를 빈 문자열로 두면 배지가 사라지는 게
   아니라 `_level_text()`가 폴백해서 **`"고유"`가 찍힌다**
   (`runtime_perk_overlay_renderer.gd:4907~4910` → `language_settings:540~559`).
   **실제로 presentation visual QA 픽스처가 이미 그 상태다.**
   빈 문자열 대신 **명시 억제 플래그**(예: `hide_level_text`)를 choice에 얹고
   `runtime_perk_overlay_renderer.gd:1083` 앞에서 게이트하라.
   ⚠**헤드리스 문자열 씰로는 안 잡힌다. 실제 픽셀에서만 드러난다.**
4. **호버**: `presentation`을 비우면 `source_rows`가 비어 hover rows도 0이 되어
   자동으로 꺼진다(`:830~845`). ⚠단 `cost_text`만 남기면
   `"대상 · 비용 무료"` 같은 **반쪽 문장**이 생긴다. `target`/`cost`를
   **한꺼번에** 비워라.
5. **아이콘**: `guardian_spirit_egg`를 중립 심볼로 대체하라.
   ⚠`rest_card_adapter_smoke:187~188`이 `card_content_kind`/`icon_id`를
   단언하므로 **그 씰은 '첫 방문 아님' 경로로 고정**하고 새 레그를 추가하라.
6. **GRT-021 텔레메트리 분리**: `text_layout`에
   `description_hidden_by_spoiler_gate` 같은 **명시 플래그**를 실어라.
   안 그러면 '예산 초과 숨김' / '스포일러 게이트 숨김' / '원래 할 말 없음'이
   한 값으로 뭉개져 이후 예산 씰의 변별력이 떨어진다.
7. **폴백 경로**: 에셋 미준비 시 노드 설명
   `"전투가 멎은 사이, 수호령과 인연을 정비합니다."`가 그대로 나온다.
   같은 술어로 게이트할지 판단해 보고하라.
8. **레이아웃**: 315x114 compact 카드에서 구분선(`y+58`) 아래가 빈다.
   ⚠**"빈 카드가 안 깨지는가"를 지금 어떤 씰로도 증명할 수 없다.**
   이 상태의 픽셀 캡처 레그를 presentation visual QA에 **반드시 추가**해
   눈으로 승인받게 하라.

---

## ★씰 충돌 (전부 이 슬라이스에서 동반 개정)

1. **소스텍스트 락스텝**: `tower_guardian_spring_presentation_smoke.gd:410~427`이
   리추얼 함수 본문을 문자열로 검사한다 — `draw_arc`/`draw_polyline` **금지**,
   `draw_colored_polygon` **필수**, `"for point_index in range(14)"` 리터럴
   **필수**, `draw_tower_acquisition_absorption` **필수**.
   리테인드 호스트나 셰이더로 바꾸는 순간 RED다.
   ⚠**'커밋된 상태 탓'이 아니라 '설계 변경 탓'으로 분류하라.**
   이 씰의 원래 목적은 **'절차 3피스 금지 리스트'** 를 지키는 것이었다.
   새 레이어 계약(텍스처 조각 N장 + 채움 다겹)으로 **재작성하되
   `draw_arc`/`draw_polyline` 금지 항목은 반드시 유지하라.**
2. **타임라인 락스텝**: 같은 스모크 `:258~272`가 `1.17`/`0.02`/`0.81` 스텝과
   **"정확히 2초"** 를 못박았고, `:284~357` 생산 flow 레그도 `0.99`/`0.02`로
   2초를 재확인한다. 3~4초로 바꾸면 **두 곳 + `docs/guardian_spring_statue_presentation_codex_handoff.md:20`·`:50`**
   을 동반 개정하라.
3. `:280`의 `palm_dispatch_count` / `acquisition_start_count` /
   `forced_cleanup_count` — 의식을 기도로 일반화하면 palm 전용 명칭 단언이
   흔들린다. ⚠**자동 진행이 의식 종료 전에 `close()`를 부르면
   `forced_cleanup_count`가 올라 RED가 된다.**

## 함정 (기존 GRT)

- **GRT-058** 개폐 계약 2건 (위 배선 순서 2번 참조 — 게이트 펌프 + 입력
  화이트리스트). 둘 다 **같은 슬라이스에서 함께 랜딩하라.**
- **GRT-034 변종**: `enter_modal_block`의 `stop_all`은 **모달 진입 시 1회**다.
  리추얼 중 **새로 시작하는** 루프 오디오는 이 경로가 정리하지 못한다.
  `close_scene()` / `forced_cleanup` 경로에서 자체 정지 +
  `gameplay_loop_audio_cleanup.gd` `STOP_METHODS` 등재가 **함께** 필요하다.
  선례: `stop_lingpet_guardian_enhance_cutin_loop`.
- **GRT-047**: 위 신규 아트 3장 절 참조.
- **GRT-043**: 위 배선 순서 3번 참조.
- **GRT-022**: 빈 카드 하단을 채우려고 아이콘·이름을 중앙 재배치하면
  compact 레이아웃 상수가 움직인다. **그린 자리와 클릭 자리가 갈라지는지
  반드시 상단 모서리로 히트테스트하라.**

## 통합 충돌

- ⚠**W5 `77efc52f9`** — 4개 파일 전면. 선행 통합 필수(위 참조).
  씰 쪽도 `tower_node_modal_feedback_smoke.gd`(+41, `payload.presentation`을
  읽는다) / `tower_node_modal_pointer_smoke.gd`가 겹친다.
- ⚠**W1 `ddd9cde18`** — `tower_ascent_node_modal_localization.gd` +2줄.
  신규 문구(예/아니오 질문, 기도 결과, 중립 카피)가 같은 파일에 들어간다.
- ⚠**X1** — 같은 샘터 파일. 선행 착지 필수.
- ✔**W3 `590eab580`** — 겹침 없음.

## 게이트·보고

포커스드 스모크(+RED 반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` →
**비헤드리스 픽셀 QA(빈 카드 상태 + 연출 각 페이즈 + 확인창)**.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라.**
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**
⚠**한국어 카피 엠대시(—) 금지.** 신규 문구 전부 KO/EN/ZH/JA 최소 동기화.

보고: 커밋 해시 · 씰 종단선 **원문** · `draw.scene.tower_fullscreen_map`
**착수 전/후 기준선 수치** · 흡수 트레일 절감량 · 즉시모드 유지 여부와 근거 ·
신규 아트 3장 사용처 · 콜드 프리웜 증가분 · 픽셀 캡처 경로 · 미해결.
