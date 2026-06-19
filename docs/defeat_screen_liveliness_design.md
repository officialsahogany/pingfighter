# 패배 화면 생동감(liveliness) 설계 노트

상태: 설계 (Claude). 구현·테스트 = Codex. 이 문서가 단일 소스.
대상: `godot/scripts/core/defeat_chance_gems_continue_screen.gd` (풀스크린 패배 컨티뉴 씬).
분담: 설계·트랩 브리프·적대 리뷰 = Claude / GDScript 배선 = Codex
([[feedback_design_slice_review_division]]). 같은 파일 동시수정 금지.

목적: "압솔룸처럼 화면이 살아있는" 느낌을 패배 화면에 — 단, 그 게임의 수제 프레임
물량 재현이 아니라 **절차적 오버레이 모션으로 "솔렘하게 살아있는" 2D**.

---

## 0. 아트 디렉션 — "솔렘하게 살아있다" (북극성)

패배 화면 = 상실·무게·긴장의 순간. **busy / 에너제틱 / 화려함 금지.**
- 느리고 무겁고 ambient한 생동감(부유·맥동·서서히)
- + 단 **하나의 날카로운 임팩트 비트** = 보석이 깨지는 순간("기회를 잃었다")
- 차갑고 절제된 팔레트: 잔불·모트도 **차가운 청/재(ash) 색**, 불꽃·따뜻한 색 금지.
  기존 보석 시안(코어 `#2A6CFF`/림 `#7FD0FF`)·포털 블루와 한 세트.
- 주파수 감각: ambient는 0.05~0.12Hz(8~20초/사이클), 임팩트만 빠르게.

테스트: "정적 스틸처럼 죽어 보이지 않으면서, 슬픔/긴장의 무게는 유지되는가."

---

## 1. 절대 제약 (재론 금지 — 이미 봉인/측정됨)

1. **★정적 배경 계약 SEALED.** smoke `defeat_chance_gems_continue_screen_smoke.gd:125`가
   `_animate_backdrop_rect` / `_draw_portal_breath` 함수 부재를 단언. **배경 PNG·포털 링을
   애니메이션하지 말 것**(과거 시도→반려). 생동감은 **정적 배경 위 오버레이/전경 레이어로만**.
   이 두 함수명 + 배경 패럴랙스/왜곡/팬 절대 재도입 금지 → §4 명시적 제외.
2. **모달 게이트 = 물리 정지.** 화면 active 동안 battle physics frozen
   (`battle_scene_modal_gate_controller.gd:118`). 모션은 화면 자체 `update(delta)` →
   `elapsed_sec` 누적으로만 구동(`battle_scene_frame_controller.gd:93-101` idle 경로).
3. **단일 클럭.** 모든 모션은 `elapsed_sec`(+entry용 별도 `reveal_elapsed`) 위상-락.
   이펙트 드로어 타이머 키는 하나만(read/write 동일 필드) — static-frame 트랩 회피.
4. **즉시-draw RefCounted.** 노드 안 띄움(v1). 모든 모션 = `draw(canvas)` 절차적.
   레퍼런스 패턴 = `lingpet_acquire_cutin_overlay_host`("정적 텍스처를 draw-time 절차
   envelope로 살림 — 셰이더 패스·draw_set_transform 없이").
5. **프리웜.** 텍스처/캐시는 `show()`에서. draw/update에서 lazy 생성 금지(Hot-Path Lazy).
6. **72fps 예산.** 오버레이 draw 이미 감시 대상(character_info 6.4ms 초과 전례). 헤드룸
   ~5-8ms. `particle×lifetime×layer` 곱 경고 — 싸게. doubling<15% 회귀 게이트.
7. **draw 트랩.** `draw_set_transform` 연속회전 금지(유계 `sin*amp` 또는 UV/셰이더 각도).
   애니 폴리곤은 `Geometry2D.triangulate_polygon` 사전검증(자기교차 금지). stride-LOD 희소
   깜빡임 금지(고정 개수 + per-element 시드, index-stride 아님).
8. **사인오프 = 윈도우드 픽셀 캡처.** 상태 스모크만으론 불가(묻힘/클립/안 보임 가능).
   모션 on/off 토글 비교 + 최종 캡처에서 가시·부드러움 확인.

---

## 2. 재사용 툴킷 (즉시-draw 호출 가능, 노드 불요)

- **`ImpactFlareTextureCache`** (`effects/impact_flare_texture_cache.gd`, RefCounted, 캐시):
  `draw_glow / draw_burst / draw_sparkle(canvas, center, radius, color, alpha)`. 모트·플래시·
  파편·글린트·쇼크웨이브 코어. 텍스처는 캐시(프리웜 1회).
- **`SkillOrbTooltipPreviewDrawPrimitives`** (`hud/skill_orb_tooltip_preview_draw_primitives.gd`,
  RefCounted): `draw_ellipse / draw_ellipse_arc / draw_circle_xf / rainbow_color / alpha(color,v)`.
  절차 링/호(쇼크웨이브 링, 포털 림 오버레이 호).
- **시네마틱 페이즈 패턴**: `elixir_of_mastery_cinematic_draw`(RefCounted 즉시-draw, 페이즈
  타임라인 + 절차 도형). entry reveal 타임라인 구조 참고.
- **v1 노드형 회피**: WritheEmber 셰이더 머터리얼 / GPUParticles2D 호스트는 노드 수명 +
  fx-host world-pos 베이킹(`game_offset+pos*render_scale`) + teardown 트랩 표면이 큼.
  화면-스페이스 모달엔 과함 → 더 리치한 ambient가 필요하면 v2에서 helper host로 분리.

---

## 3. 레버 (우선순위 + 신호 계약)

### L1 — 시네마틱 entry reveal [HIGH, 가장 큰 "alive" 상승]
지금은 화면이 즉시 pop-in. Absolum 결은 "씬이 조립됨".
- 별도 `reveal_elapsed` 클럭(~0.9~1.1s), `reveal_stage 0→1→2`. `show()`에서 0 리셋,
  `update`에서 누적, `reset`에서 0.
- 전경 요소가 순차 등장(엇박 ease): 클리어되는 veil → 타이틀 fade/미세 slam → 포털+보스
  fade-in + 1회 pulse → 게이지 settle(아래서 살짝 떠오름) → 마지막에 §L2 깨짐 비트 발화.
- **배경은 불변.** reveal는 `_draw_scene_backdrop` 건드리지 않고, **별도 클리어 veil
  오버레이**(`_draw_reveal_veil`, 검정→투명 알파 ramp) + 전경 요소의 draw-time 알파/오프셋
  envelope로만. (`_animate_backdrop_rect` 재도입 아님 — 계약 유지.)
- 신호: `get_reveal_progress() -> float`(0..1), 각 요소가 자기 구간 보간.

### L2 — 보석 깨짐 임팩트 비트 [HIGH, 감정 비트]
지금은 64f 셰터 시트만 재생. 무게를 준다.
- 단일 타이머 = 셰터 progress(`elapsed_sec / GEM_SHATTER_DURATION_SEC`). 초반 구간
  (progress 0~0.15, ~첫 0.3초)에 동시 발화:
  - **flash**: `draw_glow` 소비 슬롯 중심, 알파 급감(차가운 화이트-블루).
  - **확장 쇼크웨이브 링** 1~2개: `draw_ellipse_arc`/`draw_burst`, 반경 0→max ease-out, 알파 감.
  - **낙하 파편 sparkle 2~3개**: `draw_sparkle`, 중력 낙하 + fade(셰터 시트의 파편과 호응).
  - **짧은 비네트 펄스**(전체 화면 가장자리 어둠 1회 깜빡) — 임팩트 감.
- 가벼움: 캐시 텍스처 + 한 번의 envelope. triangulable(도형 아닌 텍스처/원).

### L3 — ambient 모트/잔불 [MED, "씬이 살아있다"]
- **고정 14~20개**(index-stride 데시메이션 금지 → 희소 깜빡임 트랩). per-mote 결정 시드로
  위상/속도/크기 분산. `draw_glow`(작은 반경) 또는 `draw_circle`.
- 차가운 청/재색, 느린 상승 또는 부유(0.05~0.12Hz), 화면 가장자리/하단에서 옅게.
- **텍스트 밴드 회피**: 타이틀(y58-174)·게이지/문구(y470-592) 위에 진하게 깔지 말 것
  (가독성). 포털 주변·바닥 영역에 집중.

### L4 — 보스 presence 엔리치 [LOW, 옵션 폴리시]
기존 hover(±5px, 6.25s)+victory 프레임 위에: 미세 rim 글린트(느린 스페큘러) 또는 완만한
scale-breath(±1~2%, 8s+). 전경 합성이라 배경 무관. 과하면 "위압적 미지" 무드 해침 — 절제.

### L5 — 잔존 보석 glint [LOW, 옵션]
온전 보석에 느린 스페큘러 글린트/미세 펄스 → "살아있는 기회" vs 깨진 슬롯 대비 강화.
`draw_sparkle` 이동 하이라이트. (이미 breaking 슬롯엔 glow 있음 — 잔존엔 없음.)

---

## 4. 명시적 제외 (봉인 존중)

- 배경 PNG 패럴랙스 / 왜곡 / 팬 / 컬러 시프트 — **금지**(smoke 계약, 과거 반려).
- 포털 링 breath / 애니메이션 — **금지**(`_draw_portal_breath` 봉인). 포털은 정적 유지.
  (정 필요하면 포털 위 별도 additive 림-글로우 오버레이인데, 봉인 이유가 있으니 **사용자
  확인 후에만**. v1 범위 밖.)
- 노드형 GPUParticles2D / WritheEmber 호스트 — v1 제외(§2). 필요 시 v2 helper host.

---

## 5. 슬라이스 플랜 (각: smoke + 픽셀 캡처 사인오프)

- **S-L1 entry reveal**: `reveal_elapsed`/`reveal_stage` + `_draw_reveal_veil` + 전경 envelope.
  smoke: 정적배경 계약 유지(금지 함수명 부재 재확인), reveal_progress 0→1 단조, reset가 0.
  픽셀: 토글 비교로 reveal 가시.
- **S-L2 gem 임팩트 비트**: 셰터 progress 게이팅 flash/쇼크웨이브/파편/비네트.
  smoke: 단일 타이머(progress) 사용, breaking 슬롯에서만 발화, 비-breaking 슬롯 무발화.
  triangulable(텍스처/원만). 픽셀: 깨짐 순간 임팩트 가시.
- **S-L3 ambient 모트**: 고정셋 + per-mote 시드. smoke: 개수 고정·index-stride 부재·
  텍스트 밴드 회피 분포. 픽셀: 모트가 읽히되 텍스트 안 가림. 72fps doubling<15% 재측정.
- **S-L4/L5 옵션 폴리시**: 마지막. 과하면 컷.

순서 권장: **S-L1 → S-L2 먼저**(가장 큰 체감, 싸고 계약-안전) → S-L3 → 옵션.
각 슬라이스 독립 커밋(자체 스모크가 회귀 봉인).

---

## 6. 트랩 브리프 (압축)

- 봉인 함수명(`_animate_backdrop_rect`/`_draw_portal_breath`) 재도입 = smoke FAIL. 배경/포털 정적.
- 모션은 `update(delta)`/`elapsed_sec`로만(물리 정지). 단일 타이머 키.
- 프리웜 at `show()`. draw/update lazy 생성 금지.
- no `draw_set_transform` 연속회전(유계 sin/UV). 애니 폴리곤 triangulate 사전검증.
- 모트는 고정 개수 + per-element 시드(index-stride 깜빡임 금지).
- 72fps 헤드룸 ~5-8ms, particle×lifetime×layer 곱 주의, doubling<15%.
- 사인오프 = 윈도우드 픽셀 캡처(on/off 토글), 상태 스모크 불충분.
- 팔레트 차갑게·절제(잔불도 청/재). busy 금지 — 솔렘. (예외 = §7 보석 깨짐 1회 에너지 스파이크.)

---

## 7. L2+ — 보석 깨짐 "살아있는 시안 에너지 버스트" (WritheEmber 노드 호스트, v2)

방향(사용자 레퍼런스 bandicam 2026-06-20 확정): 패싯 코어 + 사방으로 **꿈틀대는 방사형
에너지 tendrils** + 숨쉬는 글로우 + 크래클링 스파크, 지속적으로 살아있음. **이것이 §0의
"단 하나의 날카로운 임팩트 비트(보석 깨짐)"를 레퍼런스급으로 실현** — 화면 나머지는 솔렘
유지, 보석 깨짐만 이 에너지 스파이크(솔렘 방향과 모순 아님, 그 한 비트의 고급 실현).
팔레트 = **보석 시안/블루 유지**(#2A6CFF/#7FD0FF), 레퍼런스 금색의 **모션만** 차용
(사용자 결정 2026-06-20). 구현 방식 = WritheEmber 노드 호스트(사용자 결정).

**기술 = 신규 아님.** `writhe_ember_material.gd`(FBM 왜곡+측면리플+jitter+chroma flicker
+3색 팔레트)가 정확히 이 "꿈틀 에너지" 룩(result_box_burst·hongryun_inferno 등에서 사용).
→ 신규 시안 프리셋 `chance_gem_shatter_cyan`(hot=시안-화이트 / ember=브라이트 블루 /
amethyst=딥 블루)만 추가, `apply_preset`로 라이브 구동.

### 7.1 아키텍처 — 스크린-스페이스 fx-host (`drive_cutin_fx_host.gd` 클론)
신규 `defeat_gem_shatter_fx_host.gd` (extends Node2D). drive_cutin 패턴 그대로:
- `z_as_relative=false` + 높은 `z_index`(드라이브 컷인=40 참고)로 **즉시-draw 패배 오버레이
  위에** 그림. ★음수-z/burial 트랩 → 픽셀로 "위에 그려지는지" 확인.
- 자식: (1) **WritheEmber Sprite2D quad**(꿈틀 시안 에너지 코어/tendrils, 신규 프리셋),
  (2) **GPUParticles2D 스파크**(시안, ADD blend, amount 바운드 ~24, fixed_fps 30,
  local_coords=true). 선택: 소프트 글로우(ImpactFlareTextureCache).
- 스크린-스페이스 배치: `position = 소비 보석 슬롯 view-space 중심`(패배 화면이 이미 계산),
  `scale = view_size.y / REF`. **game_offset/render_scale 쓰지 말 것**(플레이필드 공식 아님
  — drive_cutin 주석과 동일, 안 그러면 에너지가 레터박스로 샘).
- static `prewarm_assets()`(텍스처 + WritheEmber 머터리얼 빌드)을 show()/boot에서.
  draw/update lazy 생성 금지(Hot-Path Lazy).
- `sync_state(state, active)` dict 구동: 패배 화면이 매 update에 {view_size, gem_center,
  progress(=셰터 0→1), quality_scale} 피드. quad 머터리얼 `set_shader_parameter("elapsed",
  elapsed)` + `intensity` 엔벨로프(progress 동기).
- **단일-cleanup**: `set_active(false)`=숨김+emission 정지 한 번에. + **self-timeout 가드**
  (_process, grace창 내 active sync 없으면 자동 숨김 → 모달 dismiss/스킵 시 누수 방지).
  패배 화면 `reset()`/dismiss가 host.set_active(false) 호출.

### 7.2 코레오그래피 (단일 클럭 = 셰터 progress)
- **0→0.15**: 에너지 ERUPT(급상승) + 기존 §L2 impact flash/burst 동반.
- **0.15→0.7**: 꿈틀 sustain(tendrils 살아 움직임, 글로우 숨쉼, 스파크 크래클). 그 아래
  기존 64f 셰터 시트가 보석 코어로 균열 — 에너지가 코어를 가리지 않게 alpha/scale 튜닝
  (레퍼런스도 패싯 코어가 보임).
- **0.7→1.0**: 에너지 collapse + 기존 셰터→broken 크로스페이드(이미 구현, FIX B)와 함께
  사그라듦. 끝 = 정적 broken + 옅은 에너지 잔향.
- **기존 gem 코어(셰터+크로스페이드) 재사용**, 에너지는 그 위 신규 레이어(대체 아님).

### 7.3 통합 확인 (Codex 결정/배선)
- **호스트 소유/부모**: RefCounted 패배 화면은 노드 없음 → 호스트를 show()/boot prewarm에서
  **1회 생성**(owner 하위 또는 고-z CanvasLayer), update마다 sync_state. catalog 등록 검토
  (다른 fx 호스트처럼). draw에서 생성 금지.
- **z-order**: 즉시-draw 패배 오버레이 위에 그려지는지 픽셀 확인(burial 트랩).
- **PSO 프리웜**: 신규 시안 프리셋/셰이더 변형을 `battle_pso_prewarmer` 컨텍스트에 추가
  (첫 발동 셰이더 컴파일 히치 방지).
- **모달 게이트**: 물리 정지 → 호스트는 화면 update/elapsed로만 구동(physics 아님).
  self-timeout이 dismiss 누수 커버.
- **perf**: WritheEmber quad 1개(FBM) + 바운드 스파크 → 72fps 헤드룸 내, doubling<15% 측정.

### 7.4 슬라이스 + 검증
- **S-L2+**: 신규 프리셋 + `defeat_gem_shatter_fx_host`(drive_cutin 클론) + 패배 화면
  구동 배선 + PSO 프리웜.
- smoke: 호스트 prewarm·단일-cleanup·self-timeout, 화면 reset가 host 비활성, 정적배경 계약
  유지, 단일 클럭, game_offset 미사용(스크린-스페이스).
- **픽셀 QA(필수)**: 윈도우드 캡처 — 에너지가 **시안으로 꿈틀대며 보석 코어 위에 살아있게**
  읽히는지(레퍼런스 모션), 텍스트/포털 안 가리는지, z 위로 그려지는지, on/off 토글. 72fps 회귀.
- 자산: 신규 PNG 거의 불요(WritheEmber=절차 셰이더, 스파크=기존 텍스처/ImpactFlare). 시안
  프리셋 정의 + 호스트 + 배선이 작업의 전부.
