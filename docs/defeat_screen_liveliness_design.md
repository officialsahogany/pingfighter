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

---

## 8. 컨티뉴 확인 시네마틱 — "흔들림→박살→화이트아웃→스테이지 페이드백" (확인 후 3s)

방향(사용자 2026-06-20): 현재 = 화면 열리자마자 셰터 재생. **변경** = 화면 열림엔 보석
**온전**, **확인을 누르면** 3초 시네마틱: 보석이 막 **흔들리다(빌드업) → 1개 박살**(기존 파열
VFX를 이 순간으로 이동) → 화면이 점점 **하얘짐(화이트아웃)** → 화이트에서 **스테이지 화면으로
서서히 페이드백**(reset_for_continue는 화이트 절정 밑에서 은폐 실행). 보석-셰터 작업은
폐기 아님 = "박살" 비트로 재사용(재타이밍).

### 8.1 페이즈 머신 (신규)
컨티뉴 화면에 2-탑레벨 페이즈 + `confirm_elapsed` 단일 클럭:
- **PRESENT**(열림→확인): 보석 전부 **온전**(현 count 그대로 full, 셰터 호스트 **비활성**).
  `elapsed_sec`는 pulse/reveal만. 입력 대기.
- **CONSUMING**(확인→완료, ~3s, `confirm_elapsed` 구동):
  - **SHAKE** 0~~2.0s: 소모될 보석(top index)이 진폭 증가하며 흔들림(position+rotation
    jitter, bounded, ease-in 빌드업). 오디오 럼블/차지.
  - **SHATTER** ~2.0~2.6s: 그 보석 박살 — **기존 gem-shatter fx 호스트 + 64f 시트를 이
    서브윈도우로 재타이밍**(progress=(confirm_elapsed−SHATTER_START)/SHATTER_DUR). 게이지
    full→broken. 오디오 크랙.
  - **WHITEOUT** ~2.3~2.9s: 풀스크린 화이트 오버레이 alpha 0→1(셰터와 겹쳐 "터지며 하얘짐").
    `mythic_item_acquisition_cinematic_v2` 화이트아웃/슬램 재사용.
  - **RESET @절정** ~2.9s: **화이트 alpha≈1 밑에서** `reset_for_continue` 발동(점수 0-0·공
    리셋 은폐). 모달게이트 해제도 여기서.
  - **FADEBACK** ~2.9~3.5s+: 화이트 alpha 1→0 페이드아웃으로 살아있는 스테이지 드러남.
    컨티뉴 화면이 페이드 화이트를 계속 그리며(**비차단**) 라이브 스테이지 위에 얹고 alpha0에서
    close. (또는 `stage_landing_intro` 재트리거로 페이드인 — Codex 택1.)

### 8.2 핵심 계약/트랩
- **소모 타이밍 이동**: 현재 store consume = 리졸버 pre-screen(`battle_scene_match_flow_driver`
  :184). → **확인 핸들러로 이동**(리졸버는 `gems>0` 게이트만, consume 안 함; 화면 confirm이
  consume + reset_for_continue). "확인까지 온전" 의도 일치 + 감사 LOW(consume 비트랜잭셔널,
  화면 중 강종 시 보석만 소실) **동시 해소**. 게이트(gems>0?)는 pre-screen 유지.
- **표시**: PRESENT/SHAKE = 현 count 전부 full, SHATTER에서 top 1개 박살, 종료 count−1.
  "소모되었습니다" 카피는 박살 후로(전엔 "확인 시 1개 소모" 류 중립).
- **reset를 화이트 절정에**: alpha<1에서 reset 발동하면 급격한 0-0 리셋이 보임 → alpha≈1에서만.
- **모달게이트 해제 타이밍**: 확인이 아니라 **화이트 절정**으로 이동(그 전엔 게임 얼어있음).
  그 후 화면은 비차단 화이트 오버레이로 페이드백 소유(단일 owner 권장) 또는 battle intro 재사용.
- **파열 VFX 재사용**: 호스트를 `elapsed_sec`(open) 구동 → `confirm_elapsed` SHATTER 서브윈도우
  구동으로 **재타이밍**. 이중발동 금지.
- **흔들림**: gem slot draw에 bounded jitter(`draw_set_transform` 연속회전 금지 — position/
  rotation 오프셋으로). 소모될 보석이 가장 격렬, 나머지는 옵션 미세.
- **재사용 포인터**: 화이트아웃/슬램 = `mythic_item_acquisition_cinematic_v2`; 페이드백 =
  `stage_landing_intro` / `stage_ball_spawn_intro`.
- 오디오: 럼블(shake) → 크랙(shatter) → whoosh/boom(white).

### 8.3 슬라이스 + 검증
- **S-CC1**: 페이즈머신·확인=시네마틱시작(즉시리셋 아님)·consume를 confirm로 이동·표시
  pre-consume-until-shatter·파열호스트 재타이밍·shake jitter·화이트아웃·페이드백·reset@절정.
- smoke: 확인이 **즉시 reset 안 함**(reset는 ~절정 T에서만 1회)·PRESENT에서 셰터호스트
  비활성·SHATTER 윈도우만 활성·화이트 alpha가 reset 前 절정·모달게이트 해제 타이밍·단일
  `confirm_elapsed` 클럭·소모는 confirm 1회.
- **★FELT(필수)**: 3s 전체 **모션** 캡처(confirm_elapsed 0/0.5/1.5/2.0/2.4/2.8/3.0/3.4)로
  흔들림→박살→화이트→페이드백 읽히는지(stills lie). 캡처 하니스 크래시 시 라이브 룩.
- **UX**: 매 컨티뉴(최대 3회) 3s — v1 항상 풀, 반복 시 스킵/패스트포워드는 옵션(추후).
- 가드레일: 72fps, single clock, reset 정확히 1회·alpha≈1에서, 파열호스트 재타이밍(이중발동
  금지), no draw_set_transform 연속회전(shake), 정적배경 계약(§6) 유지.

---

## 9. 임팩트 비트 화려함 업그레이드 (S-CC2)

방향(사용자 결정 2026-06-20 "임팩트 비트 집중"): §8 컨티뉴 시네마틱이 작동·읽힘 확인됨
("좋아"). 화려함 업그레이드 = **이펙트를 사방에 뿌리지 않고 보석 깨짐→화이트 그 한
임팩트 비트를 시네마틱 타격으로** (§0 솔렘 + 단 하나의 임팩트 비트 유지). 전부 §8 페이즈머신
위 **비주얼-엔벨로프 레이어**(confirm_elapsed 키, reset 타이밍/클럭 무변, 3s 페이싱 무변).

재사용 툴킷: `mythic_item_acquisition_cinematic_v2`(Claude 타격감 튜닝) — `_white_flash_texture`
(소프트 화이트 플래시), `_shake_trauma`/`_shake_offset`(트라우마 셰이크), `_light_beams`(십자
광선), chroma split. **전부 비주얼-엔벨로프**(주석: "flash + held shake envelope rather than
freezing the phase timeline"). + `ImpactFlareTextureCache`(glow/burst/sparkle).

### 9.1 레이어 (페이즈별)
- **SHAKE 0~2.0s 예고**: 소모될 보석에 **균열 점진 번짐**(procedural lines — 삼각화 트랩 회피=
  animated filled polygon 금지) + **시안 charge**(수렴 wisp + 안쪽 글로우 강화, ImpactFlare) +
  다른 보석/화면 살짝 dim. 럼블.
- **SHATTER 2.0~2.6s 임팩트 비트**(break 순간 ~2.0~2.2 발화, 빠른 decay 엔벨로프):
  - 임팩트 플래시 + 블룸(ImpactFlare burst / mythic 화이트플래시)
  - 방사 충격파 링(팽창)
  - 색수차(chroma split, mythic 방식 재사용 — shader면 PSO 프리웜)
  - 화면 슬램 셰이크(`_shake_trauma` offset, 샤프 decay — **2.9s whiteout peak 전에 ~0 정착**)
  - 십자 광선(`_light_beams`, 깨짐 지점=소비슬롯 중심 앵커)
  - 더 큰 파편(파열 호스트 강화)
- **WHITEOUT 2.3~2.9s 리치**: 평면 흰색→**시안 프린지 + 에너지 리플**, 보석 에너지가 흰빛
  속으로 흩어짐.
- RESET@2.9s peak white · FADEBACK = §8 무변.

### 9.2 가드레일/트랩
- **reset 타이밍/단일클럭 무변** — 전부 비주얼-엔벨로프(confirm_elapsed 키), 클럭 freeze 금지
  (mythic 교훈 + S-CC1 smoke·D2 핀 계약). 기존 reset@2.9 + D2 핀 스모크 그대로 통과해야.
- **셰이크는 reset 프레임 전에 정착** — whiteout 풀스크린 화이트는 셰이크와 **무관하게
  (untransformed) 풀커버 draw** → reset-under-white(D2 핀) 불변. 슬램은 SHATTER(2.0~2.6)에서
  decay → 2.9 ~0.
- **정적 배경 SEALED(§1)** — 셰이크는 **전경 임팩트 레이어 offset**(또는 1회성 jolt),
  `_animate_backdrop_rect`/`_draw_portal_breath` 재도입 금지(smoke 유지). 배경 애니 아님.
- **프리웜** — mythic 화이트플래시 텍스처·광선·chroma shader를 show()/boot에서(현 화면 prewarm에
  추가), draw lazy 금지(Hot-Path Lazy).
- **72fps** — 임팩트 = break 순간 짧은 스파이크, 파편/광선 바운드, doubling<15% 측정.
- **draw_set_transform 연속회전 금지** — 셰이크 = position offset, 광선 = 정적 ray(텀블 금지,
  mythic 패턴).

### 9.3 슬라이스 + 검증
- **S-CC2**: SHAKE 균열/charge · SHATTER 임팩트(플래시/충격파/색수차/슬램/광선/파편) · 리치
  화이트아웃. mythic 타격감 재사용.
- smoke: 임팩트 = 비주얼-엔벨로프(confirm_elapsed/reset 타이밍 무변 — 기존 reset@2.9 + D2 핀
  스모크 통과) · 셰이크 2.9 전 정착 · whiteout 풀커버(셰이크 무관) · 프리웜 · 정적배경 계약 유지 ·
  chroma/광선/플래시 SHATTER 윈도우 게이트.
- **★FELT(모션, 필수)**: 임팩트가 진짜 타격으로 읽히는지(플래시/충격파/색수차/슬램/광선), 솔렘
  유지, reset 은폐 불변, 너무 busy/길지 않은지. confirm_elapsed 1.8/2.0/2.1/2.3/2.6/2.9 스트립.

---

## 10. 컨티뉴 부활 비트 (S-CC3)

방향(사용자 2026-06-20): 컨티뉴 복귀 시 플레이어가 **패배 포즈 유지 중 → 기회의 보석이
날아와 몸에 흡수 → 빛 발하며 → 짧은 승리 포즈 → 정상 플레이**. "다시 살아난다" 감정선
(현 shatter/whiteout보다 훨씬 명확). **신규 라투디 아님 = 기존 전투 승리/패배 시트 재사용.**
근거(두 그라운딩 수렴 — Claude 워크플로 + Codex): 인게임 렌더러가 이미
`player_victory_active`/`player_defeat_active` 지원(`stage1_player_actor_renderer.gd:155`),
패배 경로서 보석/승리/패배 시트 프리웜됨(`battle_resources.gd:559`), starpoint absorption이
흡수 템플릿(`runtime_perk_state.gd:736`/`runtime_perk_overlay_renderer.gd:956`),
`reset_for_continue`가 2.9s에 physics 언블록(=비트 동안 hold 필요).

### 10.1 범위 (사용자 결정: S/V/B 먼저 + 나머지 fallback)
- **Smasher/Viper/Blacksmith**: 풀 비트(패배포즈 → 흡수 → 승리포즈). 전투 승리/패배 시트 존재,
  신규 자산 0.
- **Commando/Optimus/maribo**: fallback = **보석 흡수 + 글로우 + 짧은 빛만**(포즈 스왑 생략, 인게임
  result 시트 없음). 나중에 신규 시트로 업그레이드 가능(sprite-generation).

### 10.2 페이즈 머신 (신규 배틀-side 상태)
새 모듈 `defeat_continue_revival_beat_state.gd`(RefCounted, `player_actor_animation_state` 패턴).
단일 beat 클럭. 트리거 = `reset_for_continue` 실호출 직후(2.9s, 화이트 밑).
- **defeat_hold**: 플레이어 패배 시트 유지(`player_defeat_active`+frame 주입). 화이트 fadeback이
  이걸 드러냄.
- **gem_flight**: 보석이 (게이지 위치 → game space) 플레이어 중심으로 하강(starpoint absorption
  구조 변형, **움직이는 player center 매 프레임 추적**).
- **absorb_flash**: 몸 흡수 + 시안 글로우(`player_state_glow_renderer` 신규 absorb state, defeat-skip
  예외) + 도착 burst(ImpactFlare).
- **victory_pulse**: 짧게 승리 시트(`player_victory_active`+frame). **S/V/B만**; fallback=글로우만.
- 종료 → 플래그 클리어 → physics/serve 정상 재개.

### 10.3 핵심 계약/트랩
- **★physics/serve HOLD**: beat active 동안 `blocks_battle_physics()=true` 유지(2.9 언블록을 비트
  종료까지 연장; `round_flow_state` serve 억제). 종료 후에만 정상 1.0s 서브. **그림만 추가 금지 —
  이게 핵심.**
- **포즈 드라이버**: `get_boss_result_context`와 같은 dict shape(player_defeat_active/frame,
  player_victory_active/frame)를 `battle_draw_actor_context.gd:486-517` build site에 **스코어보드
  비종속**으로 주입. 프레임 인덱스 자체 공급(스코어보드 타이머 아님).
- **글로우**: `player_state_glow_renderer.gd:35` defeat early-return 우회(신규 absorb state or
  게이팅 예외).
- **소유자 = 배틀-side**(game space, actor 파이프라인 재사용). 컨티뉴 화면 screen space 아님.
- **Owner-Field Schema**: 신규 플래그(`player_continue_beat_active` 등) `BattleSceneState.DEFAULT_VALUES`
  선언(아니면 owner.set() silent no-op).
- **프리웜**: 패배 경로가 이미 victory/defeat/gem 프리웜(battle_resources:559) — victory 시트 잔존 확인.
- **흡수 target**: 매 프레임 움직이는 player center 추적(고정 X 금지).
- reset@2.9 / 화이트 / D2핀 / 정적배경 계약 = S-CC1/CC2 그대로 무변.
- **페이싱**: 비트 타이트(~2s) + **반복 시 스킵/패스트포워드**(누적 ~5s/컨티뉴, 최대 3회 완화).
- 좌표: 보석 출발점(게이지 screen pos) → game space 변환 or 화면 위에서 하강.

### 10.4 슬라이스 + 검증
- **S-CC3**: 새 beat state machine · reset_for_continue 직후 트리거 · physics/serve hold · 포즈 플래그
  주입 · 보석 비행/흡수(starpoint 변형) · 글로우 · 승리 pulse(S/V/B) · fallback(others).
- smoke: beat active 동안 blocks_battle_physics=true · 종료 후 false · 포즈 플래그 스코어보드 비종속
  주입 · 단일 클럭 · Owner-Field Schema 선언 · 흡수 target player center 추적 · S/V/B 포즈 vs others
  fallback 분기 · reset@2.9/D2핀 회귀 통과.
- **★FELT(모션)**: 패배 → 보석 흡수 → 빛 → 승리 → 서브가 "다시 살아난다"로 읽히는지, 너무 길지
  않은지(페이싱), physics 정상 재개.

---

## 11. 신성한 부활광 오버레이 (S-CC4)

방향(사용자 2026-06-21): 33 IMMORTALS에서 **"신성한 느낌 + 살아있는(움직이는) 느낌"만 차용**
(베끼기 아님). 핵심 = 부활/소생 = 신성(神聖). S-CC3 부활 비트에 **전경 신성광 오버레이**를 얹어
"컨티뉴 = 기회의 보석이 플레이어를 되살렸다"로 읽히게. **배경은 정적 콜드 유지(§1 SEALED), 빛만
부활 순간 살아남.**

차용 감각(레퍼런스에서): 중앙에서 터지는 신성 광휘 · 빛줄기(god ray) · 느리게 맥동하는 bloom ·
떠다니는 성스러운 motes · 어둠 속 실루엣 대비.

팔레트 = **차가운 시안(상실) → 따뜻한 골드/화이트 신성광(소생)**. 부활 순간의 cold→warm 전환이
최대 감정 대비. 평소(패배 표시)엔 콜드 유지.

### 11.1 ★전 캐릭터 커버 (S-CC3 fallback 보완)
S-CC4는 **플레이어 위치 기준 전경 오버레이라 포즈 시트와 무관** → Commando/Optimus/maribo
(S-CC3 포즈 fallback)도 신성광 부활 순간을 동일하게 받음. 포즈 없는 캐릭의 "승리 포즈 부재"를
신성광이 메움.

### 11.2 엔벨로프 (S-CC3 beat 클럭에 키, 신규 타이머 없음)
- **defeat_hold 0~0.75**: 콜드/다크, 신성광 없음(or 후반 faint gather). 솔렘.
- **gem_flight 0.75~1.30**: 보석(콜드 시안) 하강에 faint 신성 trail(예고 빌드업).
- **absorb_flash 1.30~1.58 ★BLOOM**: 보석 흡수 → **콜드 시안이 따뜻한 골드/화이트 신성광으로
  터짐** — 중앙 radiant 광휘 + god ray 빛줄기 폭사 + 화이트 플래시 peak(mythic `_white_flash_texture`).
  플레이어가 부활광에 잠김. THE 신성 순간.
- **victory_pulse 1.58~2.05**: 신성광 SUSTAIN + 느린 맥동(breathing bloom) + 성스러운 motes
  상승, 플레이어 승리 포즈와 함께. 후반 fade → 정상 복귀. (3.50 fadeback과 자연 연결.)

### 11.3 레이어 (전경 오버레이)
1. 중앙 radiant bloom(골드/화이트, 플레이어 앵커, absorb서 bloom, victory 느린 맥동, fade).
2. god ray/빛줄기(bloom 중심서 방사, absorb 등장, **bounded/정적 fan이 맥동 — 연속회전 텀블 금지**,
   mythic `_light_beams` 재사용).
3. 떠다니는 성스러운 motes(골드/화이트, 상승, bounded, **stride-flicker 금지**).
4. 화이트 플래시 peak(absorb 순간 cold→warm flip, mythic 재사용).
5. 실루엣 대비(플레이어 포즈가 밝은 신성광에 실루엣, 배경 다크 유지).

### 11.4 가드레일/트랩
- **전경 오버레이 ONLY** — 배경 PNG 애니 금지(§1 SEALED, `_animate_backdrop_rect`/`_draw_portal_breath`
  재도입 금지, 기존 스모크 통과). 신성광은 배경+플레이어 위 신규 전경 레이어.
- **S-CC3 beat 클럭 구동**(단일 클럭, 신규 타이머 없음). S-CC3 beat draw_overlay와 같은 컨텍스트·
  플레이어 앵커로 그려 absorb burst와 정렬.
- **콜드→웜 핸드오프**: S-CC3 시안 absorb 글로우(player_state_glow absorb)가 absorb 순간 골드
  신성광에 바통터치.
- `draw_set_transform` 연속회전 금지(god ray=bounded fan/텍스처 shaft 맥동) · 삼각화 트랩(rays/bloom=
  텍스처 or triangulable, animated filled polygon 금지).
- 72fps(brief bloom + bounded motes/rays, doubling<15%) · 프리웜(신성 텍스처 show()/boot).
- **페이싱 무변**(S-CC3 2.05s 비트 안에 얹음, 추가 시간 0).
- 재사용 툴킷: mythic `_white_flash_texture`/`_light_beams`(S-CC2서 이미 continue 화면에 배선) +
  ImpactFlareTextureCache(glow/burst/sparkle) + 보류했던 L3 motes 패턴(고정셋/per-seed).

### 11.5 슬라이스 + 검증
- **S-CC4**: 전경 신성광 오버레이(중앙 bloom·god ray·motes·화이트 플래시) S-CC3 beat 클럭 키,
  cold→gold at absorb, 플레이어 앵커, 전 캐릭 커버.
- smoke: 신성광 beat 중에만(게이트)·absorb서 peak·beat 종료시 fade·전경 only(정적배경 계약 유지,
  `_animate_backdrop_rect` 부재)·단일 클럭·no draw_set_transform 연속회전·프리웜·포즈 무관 전 캐릭
  발화·S-CC3 reset@2.9/D2핀/physics-hold 회귀 통과.
- **★FELT(모션)**: cold→gold 신성 bloom이 "신성한 부활"로 읽히는지·god ray/motes 살아있는지·실루엣
  대비·너무 길/busy 아닌지·페이싱.

---

## 12. 컨티뉴 화면 상시 신성 ambient 모션 (S-CC5)

방향(사용자 2026-06-21): S-CC1~CC4 구현 후 라이브 FELT에서 **"레퍼런스(33 IMMORTALS)처럼 화면이
살아 움직이는 느낌이 하나도 없고 그대로(정적)"** 피드백. 진단: 배경 정적 SEALED + "살아있음"을
**확인 후 2초 부활 순간**(S-CC4)에만 넣어서, **컨티뉴 화면을 보는 대부분 시간(읽는 동안)엔
아무것도 안 움직여 정적**으로 느껴짐. 사용자 결정 = **(A) 전경 신성 모션 상시**(배경 정적 유지).

목표: 컨티뉴 화면이 **확인 전부터 화면 내내 살아 맥동하는 신성한 느낌**. 단 **느리고 장엄한
디바인 모션**이라 §0 솔렘과도 안 부딪힘(frantic 금지). 부활 2초만이 아니라 상시.

### 12.1 ★봉인 유지 (가장 중요)
§1 SEALED: 배경 PNG·포털 PNG **애니 금지**, smoke가 `_animate_backdrop_rect`/`_draw_portal_breath`
함수명 부재를 단언. → S-CC5는 **배경/포털 텍스처를 절대 안 건드리는 신규 전경 레이어**:
- **신규 함수명**(예: `_draw_ambient_divine_motes`/`_draw_ambient_light_shafts`/
  `_draw_ambient_portal_glow`) — 금지된 두 함수명 재도입 금지.
- 정적 포털 PNG **위에** foreground 글로우/레이를 얹는 것(포털 텍스처 자체를 맥동시키는 게 아님).
- 배경 rect/텍스처 변형·팬·패럴랙스 0. 기존 정적배경 smoke 그대로 통과해야.

### 12.2 레이어 (상시 전경, `elapsed_sec` 단일클럭 구동)
콜드 디바인 팔레트(시안-화이트, 포털 블루와 한 세트 — 따뜻한 골드는 S-CC4 부활 순간 전용):
- **드리프트 신성 모트** [핵심]: 화면 전역, 느리게 부유/상승(0.05~0.10Hz), bounded count,
  **stride-flicker 금지**(고정셋 per-seed). 상시 "살아있음"의 주역.
- **느린 god ray / light shaft**: 포털 중심에서 은은히 뻗어 **느린 sine 셰이드/flicker**
  (연속회전 텀블 금지 — 고정 fan, length/alpha만 sin 진동). mythic `_light_beams` 패턴.
- **숨쉬는 디바인 글로우**: 정적 포털 중심 **위에** foreground 라디얼 글로우, 느린 breath
  (0.08Hz, ImpactFlareTextureCache.draw_glow). 포털이 "살아 숨쉬는" 느낌(텍스처 애니 아님).
- (선택) 보석 옅은 빛 일렁임.
페이즈: PRESENT(읽는 동안)부터 상시. CONSUMING/부활(S-CC4 골드 bloom)으로 자연 escalate
(콜드 상시 ambient → 부활 순간 웜 bloom).

### 12.3 가드레일/트랩
- **전경 only**(배경/포털 PNG 미접촉, §1 seal·기존 smoke 통과, 금지 함수명 재도입 금지).
- 단일 클럭(`elapsed_sec`) · 느린 주파수(0.05~0.12Hz, §0) · **솔렘 유지**(slow·majestic, frantic 금지).
- no `draw_set_transform` 연속회전(god ray=고정 fan sin) · 삼각화 트랩(모트/레이=텍스처·line) ·
  72fps doubling<15% · 프리웜 · 가독성(모션은 텍스트/게이지/버튼 **뒤** 또는 충분히 옅게 —
  읽기 방해 금지).
- 재사용: ImpactFlareTextureCache(glow/sparkle) + 기존 모트 패턴 + mythic `_light_beams`.

### 12.4 슬라이스 + 검증
- **S-CC5**: 상시 전경 신성 ambient(모트·god ray·포털 글로우) `elapsed_sec` 구동, 콜드 디바인,
  PRESENT부터 상시, S-CC4로 escalate.
- smoke: 전경 only(`_animate_backdrop_rect`/`_draw_portal_breath` 여전히 부재·정적배경 계약 유지)·
  단일클럭·no draw_set_transform 회전·프리웜·ambient가 PRESENT에서 active(상시).
- **★FELT(모션)**: 화면이 **확인 전부터 살아 맥동**하는지(레퍼런스 느낌)·느리고 장엄해 솔렘 안
  깨는지·텍스트 가독성·busy 아닌지. (이번엔 라이브에서 "그대로/정적" 느낌이 사라졌는지가 핵심.)

---

## 13. 흑백 → 원형 색 복원 부활 후처리 (S-CC6)

방향(사용자 2026-06-21): 부활 비트 — 보석이 캐릭터에 흡수될 때 **화면 전체 흑백(desaturate)**,
승리 라투디 재생 시 **플레이어 중심에서 원형으로 색 복원**(radial color wipe). "세상이 회색이
됐다가, 부활하며 색이 되살아난다" = 소생 테마 정점.

근거(Codex+Claude 그라운딩 수렴): 기존 스크린-리드 후처리 **없음**(hint_screen_texture/
BackBufferCopy 0건) → **신규 풀스크린 screen-read 후처리 호스트 필요**(프로젝트 첫 BackBufferCopy).
ColorRect+ShaderMaterial FX 호스트 패턴은 다수(stage_ball_spawn_intro_fx_host / character_select_
confirm_flash_overlay) 재사용. CanvasLayer 없음 → owner child + 높은 z_index(shatter 1240 위).
비트는 phase/elapsed + player screen center 보유.

### 13.1 아키텍처
신규 `defeat_continue_color_restore_fx_host.gd` (Node2D, z_as_relative=false, z_index > 1240 예 1280):
- child: **BackBufferCopy**(화면 캡처) + **풀스크린 ColorRect**(ShaderMaterial).
- shader `defeat_continue_color_restore.gdshader`(canvas_item): `hint_screen_texture` 화면 샘플 →
  luma 흑백 → player center 기준 원형 마스크(원 안=원색/밖=흑백).
- 소유: 컨티뉴 화면이 shatter 호스트처럼 show()/prewarm서 1회 생성, sync_state 구동, reset서 비활성.

### 13.2 셰이더 (uniforms: screen_tex, center_px, view_size_px, restore_radius_px, feather_px, desaturate_amount)
col = texture(screen_tex, SCREEN_UV); gray = dot(col.rgb, vec3(0.299,0.587,0.114));
desat = mix(col.rgb, vec3(gray), desaturate_amount);
dist = distance(SCREEN_UV*view_size_px, center_px);
restore = 1 - smoothstep(restore_radius_px - feather_px, restore_radius_px, dist);  # 원안=1(색)/밖=0(회색)
COLOR = vec4(mix(desat, col.rgb, restore), 1.0);

### 13.3 비트 엔벨로프 (phase/elapsed 키)
- defeat_hold / gem_flight: 호스트 **비활성**(원색).
- **absorb_flash 1.30~1.58**: desaturate_amount 0→1 ramp(세상 회색) + restore_radius=0. 끝=풀 흑백.
- **victory_pulse 1.58~2.93**: desaturate_amount=1.0 유지 + restore_radius **0→화면 대각선**(player
  center서 ease-out 확장). 승리 라투디와 함께 색이 중심서 퍼져 복원. 끝=전체 복원.
- 종료: 호스트 비활성(원색 정상). restore_radius max = center→4코너 최대거리(회색 잔존 0).

### 13.4 가드레일/트랩
- **★프로젝트 첫 BackBufferCopy/screen-read** — 신규 영역. BackBufferCopy가 ColorRect보다 아래(먼저)
  화면 캡처, ColorRect가 그걸 읽음.
- **★72fps 비용** — 풀스크린 셰이더 1장(화면read+luma+radial). **BattlePerf 실측 필수**(doubling<15%,
  첫 도입이라 측정 없이 ship 금지).
- **z-order** z>shatter(1240, 예 1280) → 화면 전체(배틀/플레이어/HUD/오버레이) 위 후처리. burial 트랩 픽셀확인.
- **whiteout 비중첩** — absorb(confirm ~4.2s)는 화이트 fadeback(3.5s) 이후라 안 겹침. 호스트 absorb/victory만 active.
- **HUD/텍스트도 흑백** = "세상 회색" 의도 부합.
- **프리웜/PSO** 신규 셰이더(첫 absorb 컴파일 히치 방지), BackBufferCopy 비용 측정. 단일클럭·단일-cleanup·player center 추적.

### 13.5 슬라이스+검증
- S-CC6: 신규 color-restore fx 호스트(BackBufferCopy+풀스크린 ColorRect+desaturate-radial 셰이더),
  비트 구동(absorb→흑백/victory→원형복원), z>1240, 프리웜, 단일-cleanup.
- smoke: 호스트 absorb/victory만 active(전후 비활성)·desaturate absorb ramp·restore_radius victory 0→≥대각선·
  center=player screen center·z>1240·셰이더/머터리얼 빌드·단일클럭·정적배경/비트 계약 무변.
- ★FELT: "세상 회색→플레이어서 색 홍수"가 부활로 읽힘·승리 라투디 동기·whiteout 비중첩.
- ★BattlePerf: 풀스크린 셰이더 absorb/victory 프레임 doubling<15%.

### 13.6 그라운딩 확정 (Codex + Claude 워크플로 3에이전트 수렴, 2026-06-21)
- **수렴**: screen-read 셰이더 0건·BackBufferCopy 0건·CanvasLayer 0. 게임 전체 = 단일 즉시-draw
  Node2D(`battle_scene_shell._draw`, drawer 체인 battle_scene_drawer.gd:86-190). mythic "chroma split"은
  자기 텍스처 오프셋(screen-read 아님, mythic_writhe.gdshader:48-53). → **신규 screen-read 후처리 필요**.
- **노드-트리 seam 없음** → 후처리를 "배틀 레이어 뒤에 꽂을" 자리 없음. 정답 = **호스트 = owner child
  Node2D(z_as_relative=false, z=1280>shatter1240) + 그 자식으로 BackBufferCopy + 풀스크린 ColorRect**.
  ColorRect+ShaderMaterial idiom 다수 재사용(character_select_preview_vfx_host:258-275,
  stage4_ponk_meditation_fx_host:518/852, viper_emp_strike_fx_host:459).
- **Route A 확정(권장)**: `uniform sampler2D screen_tex : hint_screen_texture, filter_linear;` canvas_item 셰이더.
  Route B(즉시-draw 체인 전체에 desaturate 플래그 = drawer 모든 렌더러 침습)는 침습·취약 **반려**.
- **★기존 absorb 타이밍 훅 재사용**: `player_state_glow_renderer.gd:36/57/75`가 이미
  `player_continue_absorb_glow_ratio`(player_defeat_active 게이트) 소비 = 부활-absorb 신호 기배선.
  새 호스트는 비트 phase/elapsed에서 desat/radius 읽되 같은 absorb 비트와 동기.
- **인라인-셰이더 템플릿**: stage4_ponk_meditation_fx_host.gd:888-928(`Shader.new()`+`shader.code`,
  shader_type canvas_item). **PSO 프리웜**: battle_pso_prewarmer.gd(repo prewarm-split 컨벤션).
- **BackBufferCopy 순서**: ColorRect 아래(먼저) 화면 캡처 — 또는 hint_screen_texture 존재 시 Godot 자동 삽입.
  셸 _draw 출력 위에 앉는지 픽셀 확인(음수-z/burial 트랩).
- **★sacred light 레이어링 (FELT 선택지)**: 기본 = 후처리 최상위(z1280)라 sacred 부활광도 흑백→radius로
  복원("세상 회색→플레이어서 색 홍수"). 대안 = sacred light를 후처리 위로 올려 "회색 세상 속 금색 씨앗"
  상시 유지. **FELT서 결정**(기본 권장: 단순 + 의도 직결).

### 13.7 FELT 수정 — 흑백을 비트 시작부터 상수 1.0 (2026-06-21)
FELT 결과: 현재 전환 직후 **원색** → absorb서 잠깐 흑백 ramp → victory 색복원. 사용자 의도 =
**화면전환(인게임 복귀)하고 패배 라투디일 때 이미 흑백**. 색은 victory(부활)서만 복원.
narrative: 부활 비트 내내 세상은 **회색(패배 상태)**, victory 라투디서 캐릭터 중심으로 색이 홍수.

수정(get_color_restore_status, defeat_continue_revival_beat_state.gd):
- desaturate_amount = **1.0 상수**로 active 전체(defeat_hold/gem_flight/absorb_flash/victory_pulse).
  더 이상 absorb서 0→1 ramp 아님 — 비트 시작 프레임부터 풀 흑백.
- restore_radius는 **victory_pulse에서만** 0→max(player center, ease-out). 그 전 phase는 0.
- 가장 단순 형태:
  ```
  if active:
      desaturate_amount = 1.0
      if phase == PHASE_VICTORY_PULSE:
          restore_radius = max_radius * _ease_out_cubic(_get_victory_progress())
  ```
함의:
- host active 윈도우 absorb+victory(~1.6s) → **비트 전체(~2.93s)**로 확장(BattlePerf 재측정 대상, 여전히 1패스/유계).
- whiteout(confirm 2.9~3.5s)이 defeat_hold 초반 덮음 — 흰색 desaturate=흰색이라 무해, fade 후 회색 씬 노출. ✓
- absorb ramp(§13.3) 폐기 → absorb 상수 1.0. **MEDIUM-2 ramp-direction teeth(§13.6 봉인)는 "absorb 상수 full gray"로 교체**.
- victory radial restore teeth(코너 커버 §13.6 MEDIUM-1)는 **유지**.
smoke 변경:
- defeat_hold/gem_flight "inactive" 단언 → **"active + desaturate≈1.0 + radius≈0"** 로 flip.
- absorb early/late ramp 단언 → **"absorb desaturate==1.0 상수"**.
- victory radial restore(radius 0→max, 코너 커버) 단언 유지.
- 반증검증: desaturate를 phase별 0/ramp로 되돌리면 "defeat_hold 흑백" 단언 FAIL.
