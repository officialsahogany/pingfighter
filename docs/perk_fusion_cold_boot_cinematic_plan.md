# 퍽 융합 풀 시네마틱 — "링코어 콜드부트" 아트디렉션 + 스토리보드

상태: CB1 랜딩(6비트 타임라인·duration 단일 권위·스킵/reset 수렴·전이
이벤트 큐-드레인) + CB2 랜딩(티어 프레젠테이션 플랜 — 실 committed_record
파생 tell/카운트) + CB3 랜딩(Node2D 호스트·실 idle 경로 sync·degraded
폴백·finish 직접 종료) + CB4a 랜딩(fail-closed 픽셀 QA 하니스) + CB4b
랜딩(§5 에셋 8종 + 카트리지 페이스 아이콘 합성·B2/B3 도킹 유지 + 모듈별
앵커/크기/회전 SNAP OPEN 전개 + 시트 실내용 봉인) + CB4c-1 랜딩(B4
코어 페이스 대각 합성 융합 아이콘 — 공유 컴포지터를 실제 반대각
마스크로 정합(리빌 패널 동시 수혜)·prepare_fusion_pair_icon 프리웜
소유·publish-on-success·draw 캐시 소비 전용·암판+골드 헤어라인 페이스).
+ CB4c-2 랜딩(벤트/EJECT 방향성 스파크 팬 + 골드 각성 스파크 샤워 —
mythic shard 패턴 포크 GPUParticles2D, record 카운트 게이트 발화,
fixed-seed 픽셀 QA, finish 하드 클리어(false→restart→false)+sync별
앵커 재정렬). 잔여 CB4c-3~4(용융 셰이더 프리셋·§9 오디오).
2026-07-12 컨셉 선정(사용자: 옵션 3 풀 시네마틱,
"전혀 다른 방식" = 뻔한 슬램+빛줄기+히트스톱+카메라셰이크 거부). 7개 은유 병렬
발상 중 **링코어 콜드부트** 채택.

이 문서는 §0.1 분업의 **Claude 아트디렉션 산출물**이다 — 컨셉/무드/팔레트/
레이어 레시피/에셋 매니페스트/스토리보드/프롬프트 방향. Node2D 호스트·셰이더·
파티클·타임라인·prewarm·정리·스모크의 **런타임 완성은 Codex 영역**이며 §9 핸드오프에
계약을 적었다. 현행 연출(교체 대상)은
`perk_fusion_overlay_renderer.gd`의 즉시모드 절차 도형(파란 원+주황 원 선형 접근 +
"47%" 카운터, 1.1s, 결과차등 0)이다.

관련: `docs/perk_fusion_system_plan.md`(융합 메커닉·§6 UI 상태전이 S0~S4·§10.1
이름 계약), `docs/godot_runtime_traps.md`(컨텍스트-폴백 사이징/lazy-init/예약에셋
re-stat/음수-z 조상 fill), 포크 템플릿
`godot/scripts/items/mythic_item_acquisition_cinematic_v2.gd`(+ `_runtime.gd`,
`mythic_item_acquisition_timeline_state.gd`).

---

## 1. 컨셉 락

두 만렙 퍽 = 각각 **디스크하츠 카트리지**(정체성 플레이팅이 새겨진 하드웨어
모듈). 비어 있던 **링코어 섀시**에 레일을 타고 도킹·트위스트락된 뒤 **콜드부트**되어
하나의 새 코어로 각성한다. 도박(성공/부작용/부산물)은 이 **부팅이 어떻게
끝나는가** — 정상 동기화 / 과부하 벤트 / 스펙 초과 각성 — 로 갈린다.

핵심 원칙(이탈 금지):
- **은유가 곧 세계관.** 게임명 "디스크하츠"=디스크-하트 카트리지, "링코어"=도킹
  섀시, 시안+골드=정확히 그 팔레트. 링파츠(체스트 코어 플레이트·숄더 포드·이마
  젬·칼라 버클)를 은유가 아니라 **문자 그대로** 렌더한다.
- **도박 커튼 = 부팅 게이지(POST).** 게이지가 차오르는 것이 슬롯 레버를 당긴 뒤의
  긴장이고, **이그니션 crest**가 릴이 멈추는 순간이다. crest 전까지 결과를 진짜로
  모른다.
- **임팩트는 원반형 링 펄스**(빔 아님) + 하드웨어 THUNK. 전면 카메라 셰이크가
  아니라 모달-로컬 오버레이 넛지 + 하드웨어 래치 촉감.
- **티어는 색이 아니라 기계 거동으로 차등.** 리컬러 금지 — 서로 다른 부팅
  결말. 티어 모델은 **기본 3결과(성공/부작용/부산물) + stable 대체 분기**다:
  stable은 독립 4번째 롤이 아니라 부작용 롤이 core_stabilize 세이브(또는 빈
  페널티 해소)로 성공급 부팅으로 대체된 분기다.
- **순손실 없음 계약 유지.** 부작용도 코어는 살아서 부팅을 마친다.

---

## 2. 비주얼 언어 + 팔레트

기존 오버레이 팔레트 상수를 **결과 신호 문법**으로 승격해 재사용한다
(`perk_fusion_overlay_renderer.gd` 참조):

| 역할 | 색 | 상수 출처 |
|---|---|---|
| 진행/안정(시안) | `Color(0.32, 0.86, 1.0)` | `ACCENT_COLOR` |
| 잭팟/각성(골드) | `Color(1.0, 0.79, 0.27)` | `GOLD_COLOR` |
| 결함/과부하(적) | `Color(1.0, 0.48, 0.48)` | side_effect color |
| 안정 융합 세이브(시안-청) | `Color(0.45, 0.90, 1.0)` | core_stable color |
| 섀시 백드롭 | `Color(0.01, 0.015, 0.035)` 심연 | `BACKDROP_COLOR` |

신호 grammar: **시안=정상 동기화 / 앰버→적=과부하·벤트 / 골드=오버슈트 각성.**
모든 발광은 백열이 아니라 회로/룬 인레이의 점등(세그먼트 단위 딸깍)으로 읽힌다.

무드: 리액터/PC 콜드부트를 지켜보는 긴장. POST 리드아웃(SYNC OK / OVERLOAD·DERATE /
CORE AWAKENED)이 테크마법 톤을 못박는다. 정적 → 부팅 램프 → crest 정지 1비트 →
결말.

---

## 3. 스토리보드 타임라인

현행 단일 `animation_remaining` 1.1s를 **페이즈드 타임라인 ~3.0s**로 교체한다
(mythic `TimelineState` 포크). 총 6비트. 스킵은 어느 비트에서든 확정 코어 리빌로
점프(§9). 결과(`committed_record.outcome`)는 S2 확정 시 이미 롤돼 있으므로 애니는
그것을 읽어 **결정론적으로** 연출한다(라이브 RNG 아님 → 스모크 결정론 유지).

| # | 비트 | 길이 | 화면 |
|---|---|---|---|
| B0 | **DOCK_IN** | 0.5s | 확정 순간, 확인 패널의 재료 카드 2장이 **카트리지 모듈**로 물화. 좌우에서 레일을 타고 중앙의 비어 있는(꺼진) 링코어 섀시로 활주. 각 카트리지 페이스에 자기 퍽 아이콘 유지(정체성 보존). 아직 안 섞임. |
| B1 | **TWIST_LOCK** | 0.4s | 두 카트리지가 섀시 베이에 안착 → 링 칼라가 회전-스냅하며 트위스트락 체결(기계식 CHNK). 섀시 림의 룬이 시안으로 딸깍 점화. |
| B2 | **BOOT / POST** | 0.9s | 부팅 게이지(링 세그먼트 원형 게이지)가 차오른다. 세그먼트가 하나씩 점등, POST 리드아웃 라인이 프린트. **여기서 티어별 tell이 서서히 발현**(하단 §4). 판돈(55/25/20)이 게이지 곁에 잔존하다 crest에 소진. |
| B3 | **IGNITION CREST** | 0.25s | 게이지 마지막 세그먼트 도달 → 점화 임계 CREST. **원반형 이그니션 링 펄스**(빔 아님)가 통합 링을 관통 방사 + 하드웨어 THUNK + **crest 홀드 1비트**(히트스톱성 정지, 페이즈 타이머는 안 얼림 — 비주얼 엔벨로프만). 이 프레임이 운명 봉인점. |
| B4 | **REVEAL** | 0.7s | 이그니션이 완성 코어로 가라앉음: 섀시에 단일 통합 디스크하츠 코어 안착, 링 점등, 페이스에 **대각 합성 융합 아이콘**(`prepare_fusion_pair_icon` 재사용). 결과 로그가 POST 리드아웃 로그처럼 프린트. 이름/증감 라인 리빌. |
| B5 | **SETTLE(핸드오프)** | 홀드 | (CB4 확정) 호스트는 reveal 진입과 동시에 닫히고, 확인/스킵까지의 홀드는 **모달 리빌 패널이 소유**한다 — 재료 원본 2개의 "재료" 태그 잔존·결과 로그(§10.1 상세 패널 계약)는 리빌 패널의 기존 책임. 호스트에 SETTLE 렌더 분기를 두지 않는다(전환 프레임 단절 없음은 픽셀 QA로 봉인). |

카메라: 전면 셰이크 없음. B3의 넛지 = 오버레이 로컬 z-넛지 + held-shake 엔벨로프
(mythic `SHAKE_MAX_OFFSET`/`SHAKE_DECAY` 축소 재사용). 하드웨어 래치 CHNK가 촉감
앵커.

---

## 4. 결과 티어 차등 (데이터 구동, 리컬러 아님)

애니가 `committed_record`에서 읽는 값:
- `outcome` ∈ `success | side_effect | byproduct | stable`
- `option_penalties` / `deleted_options` 개수 → 벤트/브라운아웃/EJECT 수
- `byproducts` 배열 크기(1~3) → 전개 하드웨어 모듈 수

**성공(55%) — 정상 부팅 · SYNC OK.**
B2 게이지가 흔들림 없이 균일 상승, 세그먼트가 고른 시안으로 점등, 플리커 없음.
B3 crest = 깨끗한 시안 이그니션 링 펄스, 링이 전 세그먼트 동기 브리딩으로 락.
리드아웃 "동기화 완료 / SYNC OK". 코어 아이콘 선명 + 부드러운 시안 헤일로. CHNK +
낮은 차임.

**부작용(25%) — 과부하 · 출력 저하 · OVERLOAD·DERATE.**
B2 게이지 상승 중 **STUTTER** — 한 세그먼트가 앰버→적으로 명멸, 경고 글리프 블링크.
B3 crest에서 이그니션이 안전 임계를 SURGE로 넘김: `option_penalties` 수만큼 회로
레인이 **BROWN-OUT**(점등 트레이스가 어둡게 죽음 = 감소 옵션), `deleted_options`가
있으면 그만큼 **퓨즈-모듈이 베이에서 물리적으로 EJECT**되고 그 베이가 암전(=툴팁
취소선 "흉터" 규약과 직결). 링은 안착하나 세그먼트 일부가 붉게 죽은 채 "핫 러닝"
코어로 마감. 톤: 시안 베이스가 결함부에서 엠버-레드로 번짐. **코어는 살아 있음**
(순손실 없음 계약).

**부산물(20%, 레어) — 코어 각성 · CORE AWAKENED · 잭팟.**
B2 게이지가 ~90%에서 상한을 **OVERSHOOT** — 캡이 깨지고 시안 링 위로 **두 번째 골드
세그먼트 링**이 초임계 점화. B3~B4 코어가 부팅을 넘어 AWAKEN: 섀시의 숨은 보조 베이가
**SNAP OPEN**하며 `byproducts.size()`개 하드웨어 모듈이 바깥으로 전개(숄더 포드 신장 /
여분 칼라 링 회전 전개 / 이마-젬 플레이트 플립업 — **문자 그대로 하드웨어가 자라남**).
골드가 링 전체 범람, 이그니션은 골드+시안 이중 링. 리드아웃 "코어 각성 / CORE
AWAKENED" 골드, 각 베이 락오픈마다 부산물명이 금색 각인. 최대 도파민.

**안정 융합(stable, 부작용→성공 대체) — STABILIZED. 성립 경로 2가지.**
① `core_stabilize` 세이브: B3 surge 프레임에서 **별도 시안 안정화 코일이
SNAP-IN**해 과부하를 시안으로 클램프(`stabilizer_snap=true`). 아슬한 재앙을
붙잡는 긴장-해소. ② **빈 페널티 자가 해소**: 페널티 lane이 없는 소스 쌍
(캐릭터 제한 numeric passive 등 비-hookable)의 raw 부작용 롤이 벤트 없이
스스로 안착 — 코일 없음(`stabilizer_snap=false`), B2 게이지 스터터만 남고
서지는 확정되지 않으며(`ignition_surge=false`) 카운트 전부 0. 두 경로 모두
리드아웃 "안정 융합 / STABILIZED", 색은 core_stable 시안-청. 확인 패널의
`prob_core_stable` 표기와 정합하는 것은 ①(core_stabilize 무장 시 S2
프리뷰가 그 확률로 표기)뿐이다 — ②빈 페널티 경로는 사전에는 일반 부작용
확률로 보이고 커밋 후 stable로 자가 해소된다.

---

## 5. 에셋 매니페스트 (모듈러 3피스 레시피)

정적 텍스처 조각 + 런타임 합성 + 공유 셰이더 패밀리. mythic v2의 에셋 경로 컨벤션을
미러: `res://assets/sprites/effects/perk_fusion_cold_boot/`.

라우팅(CLAUDE.md): HUD 프레임 크롬 = **ui-hud-generation** 스킬 / 런타임 VFX 루프 =
**16프레임 AutoSprite** 시트 / 정적 글로우·플래시 조각 = imagegen / 대각 합성
아이콘 = 기존 런타임 합성 재사용.

| 에셋 | 유형 | 파이프라인 | 스펙 |
|---|---|---|---|
| 링코어 섀시 백플레이트 | 정적 크롬 | ui-hud-generation | 원반형 디스크하츠 섀시, 시안+골드 룬 인레이, **꺼짐/점등 2상태**, 중앙 빈 베이 2개 + 숨은 보조 베이. mythic `backplate` 대응 |
| 카트리지 모듈 폼 | 3피스 합성 | 정적 베이스 + 셰이더 + **각 퍽 아이콘 오버레이** | 디스크-하트 카트리지 셸(좌/우 미러), 페이스에 재료 아이콘 런타임 오버레이 |
| 부팅 게이지 링 | 절차 or 정적 | 절차 드로 권장(세그먼트 원형) | 원형 세그먼트 게이지, 시안 점등 / 앰버-적 스터터 / 골드 오버슈트 2차 링 |
| 이그니션 링 펄스 | VFX 루프 | 16프레임 AutoSprite | 원반형 압력 펄스(빔 아님) 1샷, 시안/골드 2틴트 |
| 벤트/EJECT 스파크 | VFX | imagegen 정적 조각 → GPUParticles2D | 방향성 스파크 팬(부작용), mythic `shard` 파티클 패턴 재사용 |
| 골드 각성 스파크 샤워 | VFX | GPUParticles2D | 부산물 전개 시 골드 낙하 스파크 |
| 전개 하드웨어 모듈 | 정적 링파츠 | imagegen | 숄더 포드/칼라 링/이마-젬 플레이트 — **몸에 마운트되는 링파츠**(플로팅 링 금지, 링파츠 정의 준수). 1~3종 |
| 융합 코어 아이콘 | 런타임 합성 | **기존 재사용** | `runtime_perk_icon_renderer.prepare_fusion_pair_icon`(대각 분할) |
| 소프트 비네트/화이트 플래시 | 정적 | imagegen | mythic `soft_vignette`/`soft_white_flash` 대응, 이그니션 블룸용 |
| 용융/열 아지랑이 셰이더 | 셰이더 | **공유 패밀리 확장** | mythic `WRITHE`/`ARC_FLOW` 프리셋 확장(distort). 일회용 인라인 셰이더 신설 지양 |

프롬프트 방향(Claude 후속): 카트리지·섀시·전개 모듈은 Lumion식 정체성 하드웨어
언어(체스트 코어 플레이트·시안/골드 인레이·기계 버클), 크로마키 배경 →
누끼. 이그니션/스파크는 넉넉한 투명 여백(셀 엣지 미접촉). 16프레임 = 4×4 루프.

---

## 6. 도파민 훅 (왜 짜릿한가)

부팅 게이지 자체가 슬롯 레버를 당긴 뒤의 긴장이고, 이그니션 crest가 릴이 멈추는
순간. crest 전까지 결과를 진짜 모름 — 깨끗이 부팅(안도) / 벤트하며 핫 러닝(신음하나
이득) / 게이지 캡을 OVERSHOOT하며 골든 각성으로 **하드웨어가 물리적으로 자라남**
(잭팟 환희). "게이지 캡이 깨지며 두 번째 골드 링이 초임계 점화"가 체리 세 개 스파이크.
하드웨어 래치 CHNK 촉감이 보상에 물리 앵커를 준다.

차별성(거부된 클리셰 대비): 수렴 빛줄기 없음 / 임팩트가 슬램이 아니라 **엔지니어드
부팅 시퀀스** + 원반형 링 펄스 / 긴장 축이 "임팩트 타이밍"이 아니라 "부팅 결과
서스펜스" / 3결과가 리컬러가 아니라 **서로 다른 기계 거동**(동기화/과부하-벤트/
오버슈트-각성+하드웨어 전개) / 게임 고유 디스크하트+링코어 하드웨어로 문자 그대로
조립돼 다른 게임 것일 수 없음.

---

## 7. 런타임 핸드오프 계약 (Codex)

포크: `mythic_item_acquisition_cinematic_v2.gd`(Node2D 본체) + `_runtime.gd`(RefCounted
래퍼: prewarm/start/update/handle_input/get_snapshot/ensure_host→owner.add_child) +
`mythic_item_acquisition_timeline_state.gd`(페이즈 타임라인). 신규:
`perk_fusion_cold_boot_cinematic.gd` (+ runtime/timeline).

무배선 이점: **outcome은 이미 데이터-레디.** `begin_committed_result(record)`가
`_phase=PHASE_ANIMATION` 이전에 `_committed_record`를 세팅하고 스냅샷이 이미
`committed_record`를 실어 보내므로, 기본 3결과+stable 대체 분기는 애니가
`record.outcome`(+ penalty/deleted/byproducts 카운트)을 읽는 것만으로 가능 —
게임플레이 재배선 0. (CB2 랜딩: 타임라인 스냅샷의 `presentation` 채널이 이
파생을 이미 수행한다 — CB3는 plan의 tell/카운트만 소비하면 된다.)

착수 시 필독 트랩(전부 리포 표준):
- [x] **이중 duration 상수** — (CB1 완료) 두 곳 모두 타임라인
      `TOTAL_ANIMATION_DURATION`(2.75s)의 파생 상수로 단일 권위화, 소스씰로 봉인.
- [ ] **컨텍스트-폴백 사이징** — 풀스크린 오버레이/플래시 rect는 반드시
      `canvas.get_viewport_rect().size`(엔진 트루스)에서. `view_size` 컨텍스트 키
      폴백 금지(몽환포영 "왼쪽 절반만" 재발).
- [ ] **핫패스 lazy-init** — 텍스처/셰이더/파티클은 **모달 오픈/로드아웃-apply에서
      prewarm**(스레디드 텍스처 + PSO). `_draw`/`update`에서 인스턴스화 금지. 호스트
      미프리웜 시 현행 즉시모드 드로를 **degraded 폴백**으로 유지.
- [ ] **예약 에셋 per-frame re-stat** — 미생성 에셋 경로를 per-frame 드로에 배선 금지.
      플레이스홀더 또는 아트+`file_exists`를 같은 슬라이스에 랜딩.
- [ ] **음수-z 호스트 vs 조상 opaque fill** — 시네마틱 호스트 z와 모달 패널/백드롭
      z 순서. state 스모크로 안 잡힘 → **픽셀 QA** 필수.
- [x] **모달 = idle 오버레이 tick** — (CB3 확정) 물리 flow는 choice_active에서
      조기 반환하므로 update 드라이버는 모달 중 도달 불가. 호스트 sync는
      `battle_scene_overlay_frame_controller.process_idle`의
      `runtime_perk_state.update` 직후가 소유하고, 같은 프레임 스킵→확정
      종료는 `_finish_perk_fusion_modal`이 호스트를 직접 닫는다.
- [x] **스킵 경로 보존** — (CB1 완료) confirm→reveal 점프 유지 + 어느 비트든
      SETTLE 수렴, 전이 이벤트는 큐-드레인으로 정확히-한-번 소비.
- [ ] **owner 스키마** — 새 owner sync 키가 생기면 `BattleSceneState.DEFAULT_VALUES`
      선언(현재 자기완결이라 불필요 예상, 생기면 준수).
- [ ] **AutoSprite (cols,rows) const 권위 / draw_polygon 정규화 UV** — 시트/절차 조각.

규모: 신화 시네마틱 재현급(신규 Node2D 호스트 + 타임라인 + 셰이더 프리셋 + 파티클
2~3 + 베이크 텍스처 5~8 + prewarm 스텝 + 정리 + 스모크). 검증된 인리포 템플릿이 있어
실현 가능하되 **다일 단위 멀티-슬라이스** 런타임 작업이다.

---

## 8. 슬라이스 + 씰

| 슬라이스 | 내용 | 씰 |
|---|---|---|
| CB1 | 타임라인 상태 포크(6비트) + duration 2곳 동기 + 스킵 경로 | 페이즈 전이/스킵→확정 리빌 점프 / duration 동기 |
| CB2 | outcome 데이터 구동 분기(기본 3결과+stable 대체) — 벤트/EJECT/전개 카운트가 penalty/deleted/byproducts에서 파생 | force-inject 아닌 **실 committed_record** 기본 3결과+삭제 변형+stable 대체 각 1레그 + 카운트 정합 |
| CB3 | Node2D 호스트 + 셰이더/파티클 + prewarm + degraded 폴백 | 미프리웜 시 즉시모드 폴백 무크래시 / lazy-init 반증 |
| CB4 | 에셋 합성(섀시/카트리지/이그니션/전개 모듈) + 대각 아이콘 재사용 | 알파/누끼/여백 QA + 최소해상도 픽셀 QA + 음수-z 조상 fill 픽셀 QA |

각 슬라이스 반증검증(in-place 토글 RED 재현) 필수. CB2 씰은 플래그가 아니라 실
트리거(확정→committed_record→애니 분기)를 구동.

---

## 9. 미결 / 밸런스

- 총 길이 ~3.0s 확정값(비트별 타이밍 튜닝은 라이브 관찰 후).
- 전개 하드웨어 모듈 아트 3종의 최종 실루엣(숄더 포드/칼라 링/이마-젬).
- POST 리드아웃 문구 7로케일(§10.1 로케일 계약과 동일 파이프).
- 오디오(CHNK 래치/부팅 램프/이그니션/각성 팡파르) — 별도 사운드 패스.
