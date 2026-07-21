# 로딩 화면 팰월드식 미니멀 전면 교체 + 달지 굴렁쇠 카메오 — 코덱스 인계서

작성: 2026-07-21 (Claude 기획 / 아트 디렉션). 실행(에셋 생성 + 배선 + 스모크)은
코덱스 담당. 사용자 확정 사항이므로 컨셉 재논의 없이 아래 스펙대로 진행.

## 0. 사용자 확정 결정

- **전 로딩화면 교체.** 기존 사이버 스테인드글라스 리빌 + 에너지 웨이브 +
  중앙 타이틀/진행도 구성을 폐기하고, 팰월드식 미니멀 로딩으로 통일한다.
  (근거: 환격전 리브랜딩 이후 "사이버" 컨셉 로딩 아트는 톤 불일치 +
  로딩 화면 자체가 무거움.)
- **타깃 룩**: 순검정 배경 + 우측 하단에 작게 움직이는 캐릭터 실루엣 +
  그 아래 영문 "Now Loading..." + 좌측 하단 흐린 게임플레이 팁 1줄.
- **우하단 카메오는 랜덤 로테이션.** 로딩 세션마다 등록된 카메오 시트 중
  1종을 랜덤으로 뽑는다. **1호 카메오 = 달지 굴렁쇠 굴리기.**
- 역할 분담: Claude=기획·아트 디렉션(이 문서), Codex=AutoSprite 생성·후처리·
  Godot 배선·스모크·픽셀 QA·커밋.

## 1. 타깃 룩 상세 (레퍼런스: 팰월드 로딩)

1280x720 기준 (스케일 팩터 `s = min(view.x/1280, view.y/720)`):

- **배경**: 풀스크린 순검정 `Color(0, 0, 0, 1)`. 그리드/글로우/웨이브 등
  장식 일절 없음.
- **카메오 스프라이트**: 우측 하단. 중심 위치 대략
  `(view.x - 150*s, view.y - 120*s)`. 표시 높이 약 `화면 높이의 9%`
  (720p에서 ~65px). 시트 프레임 루프 ~10–12fps.
  - **흰 실루엣 렌더**가 기본. 풀컬러 시트를 로드하고 CanvasItem 셰이더로
    `COLOR = vec4(1.0, 1.0, 1.0, tex.a)` 처리. 에셋 자체를 흰색으로 굽지
    말 것 (풀컬러 전환 여지 + 시트 재활용). 렌더러에
    `LOADING_CAMEO_SILHOUETTE := true` 급 상수 하나로 풀컬러 전환 가능하게.
  - 은은한 발광: 실루엣을 1.15x/1.3x 확대 + 알파 0.10/0.05로 뒤에 2겹
    겹치는 정도. 과한 글로우 금지 (레퍼런스는 거의 플랫).
- **"Now Loading..." 텍스트**: 카메오 바로 아래 (중심 기준 +55*s 정도),
  가로는 카메오 중심 정렬 또는 우측 여백 48*s 정렬. 폰트 크기 ~20*s,
  `Color(1, 1, 1, 0.92)`.
  - **영문 리터럴 고정.** `LanguageSettings.translate_text()`를 통과시키지
    말 것 — 이 표기는 국제 관례 그대로 둔다는 사용자 방향.
- **게임플레이 팁**: 좌측 하단. 왼쪽 여백 48*s, 세로는 "Now Loading..."과
  같은 밴드. 폰트 ~15*s, `Color(0.62, 0.66, 0.72, 0.85)`.
  기존 `BattleLoadingTips.rotation_tip_for_elapsed(tier, character, 0,
  tick_seconds)` 호출을 그대로 재사용 (위치만 이동). 팁은 번역 경로 유지.
- **진행도 표시 없음.** 퍼센트 숫자·진행 바 모두 제거 (미니멀 유지).
  진행도 값 자체는 내부 계약(§3)에서 계속 흐르지만 그리지 않는다.

## 2. 교체 범위 — 로딩 화면 오너는 2곳뿐

| 오너 | 표면 | 호출 경로 |
|---|---|---|
| `godot/scripts/core/boot_flow_scene.gd` | 앱 부트 → 캐릭터선택 프리웜 로딩 (메인메뉴 진입 전) | 자체 `_draw()` → `_draw_character_select_loading()` |
| `godot/scripts/core/battle_loading_screen_renderer.gd` | (a) 전투 진입 부트 로딩, (b) 스테이지 전환 로딩 | (a) `battle_scene_intro_frame_controller.gd:108–126`, (b) `battle_scene_match_event_driver.gd:177–198` (+`:512` prewarm) |

- 두 표면 모두 이번 슬라이스에서 미니멀 룩으로 교체한다.
- **Stage 7 아카무 예외는 유지**: 프리배틀 영상이 로딩 스펙터클을
  소유하고 로딩 화면은 숨김+검정 레터박스
  (`battle_scene_intro_frame_controller.gd:116–124`,
  `stage7_akamu_prebattle_live_frame_smoke` 씰). 건드리지 말 것.
- 카메오 카탈로그·실루엣 셰이더·레이아웃 상수는 **한 곳에 공용화**해서
  두 표면이 중복 구현 없이 공유한다 (§5).

## 3. `battle_loading_screen_renderer.gd` 교체 스펙

### 제거

- 스테인드글라스 배선 전부: `STAGE*_STAINED_GLASS_*_PATH` 상수 8쌍,
  `_load_stained_glass_textures` / `_get_stained_glass_*` /
  `_show_stained_glass_host` / `_ensure_stained_glass_host` /
  `_release_stained_glass_host*` / `_can_show_stained_glass` /
  `_get_stained_glass_display_progress` / `_get_stage_reveal_softness`,
  `StainedGlassHost` preload와 `battle_loading_stained_glass_host.gd` 노드
  호스트 사용.
- 에너지 웨이브: `LOADING_WAVE_*` 상수, `_draw_loading_energy_wave_layer`,
  `_load_loading_wave_textures`.
- 중앙 연출: `_draw_background`의 그리드/투톤, `_draw_center_glow`,
  `_draw_progress`(퍼센트 바), 중앙 타이틀/서브타이틀/상태 텍스트 드로우.
- 고아 호스트 스윕 로직은 스테인드글라스 호스트가 사라지면 함께 제거하되,
  기존 씬 트리에 남아 있을 수 있는 `BattleLoadingStainedGlassHost` 노드
  스윕 1회 방어는 hide/draw 진입 시 유지해도 좋다 (전환기 세이프티).

### 유지 (계약 — 소비자가 있으므로 시그니처 변경 금지)

- `draw(canvas, owner, module_getter, view_size, context)` — 인트로 프레임
  컨트롤러와 매치 이벤트 드라이버가 호출.
- `build_snapshot(...)` — `loading_title`/`loading_subtitle`/
  `loading_status`/`loading_progress` 컨텍스트 키를 받아들이는 계약 유지
  (스테이지 전환 경로 `_build_stage_transition_loading_context()`가 전달).
  그리지는 않더라도 스냅샷 필드는 채워서 반환 (스모크·전환 진행도 소비).
  `tip_tier`/`tip_character` 해석(`_resolve_tip_tier`/`_resolve_tip_character`)
  유지.
- `should_hold_completion(owner, module_getter)` — **홀드 로직 유지하되
  미니멀 타이밍으로 축소**: 스테인드글라스 상수 대신
  `MIN_LOADING_VISIBLE_SECONDS := 0.6` (깜빡 로딩 방지 최소 노출) +
  `FINAL_FADE_SECONDS := 0.2` 수준 권장. "완료 프레임에 로딩 화면 1프레임
  재출현 방지" 주석의 의도(`battle_scene_intro_frame_controller.gd:40–46`)
  는 그대로 살아 있어야 한다. 스테이지 제한(`[1,2,3,4,5,6,8]`) 없이 전
  스테이지 공통 적용하되 stage 7은 기존 인트로 컨트롤러 분기가 로딩
  화면 자체를 숨기므로 자연 면제.
- `hide_loading()` / `prewarm_assets()` / `prewarm_stage_assets(stage)` —
  시그니처 유지. 프리웜 내용물만 교체: 폰트 + **카메오 시트**(§5).
  `prewarm_stage_assets`는 스테이지별 에셋이 없어졌으므로 공용 프리웜으로
  위임하면 된다 (호출부 `battle_scene_match_event_driver.gd:512–514` 유지).
- 폰트 폴백 체인 `_get_loading_font()` / `LOADING_FONT_PATHS`,
  `_draw_centered_text` 헬퍼, `_safe_owner_get`.

### 새 드로우 순서

```
1. 순검정 풀스크린 rect
2. 카메오 실루엣 (뒤 글로우 2겹 → 본체 1겹, 현재 프레임 셀만
   draw_texture_rect_region; 셀 크기는 시트 상수에서 산출)
3. "Now Loading..." (영문 리터럴, 번역 금지)
4. 좌하단 팁 1줄 (기존 BattleLoadingTips 경로 재사용)
```

## 4. `boot_flow_scene.gd` 교체 스펙

- `_draw_character_select_loading()`을 같은 미니멀 룩으로 교체.
  퍼센트 숫자(`loading_display_percent` 표기)와 에너지 웨이브
  (`LOADING_WAVE_*`, `_draw_loading_energy_wave_layer`) 제거.
  내부 진행/완료 판정 로직(`loading_display_percent >= 100` 게이트,
  BGM 프리로드 트리거)은 **표시만 제거하고 로직은 유지**.
- 부트 시점에는 선택 캐릭터가 없으므로 팁은
  `BattleLoadingTips.TIER_BASIC` + 캐릭터 슬롯 없이 호출 (기존 API가
  빈 캐릭터를 허용하는지 확인 후, 아니면 "smasher" 기본값).
- 카메오 카탈로그·셰이더·레이아웃 상수는 §5 공용 모듈을 참조 —
  boot_flow에 사본 금지.

## 5. 공용 카메오 카탈로그 + 신규 모듈

새 파일 `godot/scripts/core/loading_cameo_catalog.gd` (RefCounted, static):

```gdscript
const ENTRIES := [
    {
        "id": "dalji_hoop_roll",
        "sheet_path": "res://assets/ui/loading/loading_cameo_dalji_hoop_roll_16f_autosprite_v1.png",
        "cols": 4, "rows": 4, "frame_count": 16,
        "fps": 11.0,
        "base_height_ratio": 0.09,  # 화면 높이 대비 표시 높이
    },
]
```

- **로딩 세션당 1회 랜덤 픽.** `hide_loading()`/세션 시작 마크 시점에
  `RandomNumberGenerator`로 엔트리 1개 선택해 멤버에 고정. draw마다
  재추첨 금지 (프레임마다 캐릭터가 바뀌는 사고 방지).
- 부트 플로우와 배틀 렌더러 모두 이 카탈로그를 소비.
- 이후 링펫·타 보스 카메오는 시트가 **repo에 실제 랜딩한 뒤에만**
  엔트리를 추가한다 — 미생성 경로를 먼저 배선하면 per-frame re-stat
  트랩(§8)에 걸린다.
- 실루엣 셰이더도 여기(또는 인접 헬퍼)에 상수 문자열로 두고 양쪽 공유.
  `LOADING_CAMEO_SILHOUETTE := true` 기본값.

## 6. 달지 굴렁쇠 시트 생성 스펙 (AutoSprite — 코덱스 실행)

- **AutoSprite 캐릭터 앵커**: `cmosac1jd001vljnj2wakn6ms`
  ("Dalji right walk ref", 우향 러닝 베이스 — 확인 완료, 굴렁쇠 밀며
  달리는 측면 모션에 적합). 대안 앵커:
  `cmosppixk00388czerl48g9uq` ("Dalji original walk motion reference").
- **생성 파라미터**: `kind: "custom"`, `loop: true`,
  `videoTier: "turbo"` (pro는 512셀 안에 ~170px 프레임을 밀집 팩하는
  트랩 — sprite-generation 스킬 §2.1 참조), `removeBg: "ultra"`,
  `spritesheet: {frameCount: 16, frameSize: 512}`.
- **프롬프트 초안** (조정 가능):

  ```
  Traditional Korean hoop rolling (gulleongsoe) play: the chibi girl runs
  to the right in side profile while rolling a large wooden hoop beside
  and slightly in front of her, guiding it with a short stick in her
  hand. The hoop keeps spinning and stays clearly separated from her
  body silhouette. Smooth looping run cycle, feet baseline consistent,
  same scale every frame.
  ```

- **실루엣 판독성이 1차 QA 기준.** 최종 렌더는 65px급 흰 실루엣이므로:
  굴렁쇠(큰 원) + 막대 + 달지 쌍둥이 머리(bun) 실루엣이 흰색 단색으로도
  즉시 읽혀야 한다. 굴렁쇠가 몸과 겹쳐 훌라후프처럼 보이면 리젝 —
  굴렁쇠는 몸 앞쪽으로 분리. 65px 축소 + 흰 단색화 프리뷰로 판정할 것
  (풀컬러 2K에서만 보고 승인 금지).
- **후처리**: removeBg ultra 출력 → 필요시 `halo_strip.py` → 16프레임을
  4x4 그리드 재배치. **셀 전체에 단일 고정 트랜스폼** (per-cell 자체
  bbox 재센터 금지 — 스킬 §2.3.2 anti-jitter). 런타임 시트는 셀 256px
  (1024x1024 PNG)로 다운스케일 — 표시 크기가 ~65px라 512셀은 과체급.
  소스 원본(512셀)은 스테이징에 보존.
- **경로/네이밍**:
  - 런타임: `godot/assets/ui/loading/loading_cameo_dalji_hoop_roll_16f_autosprite_v1.png`
    (기존 `loading_energy_wave_loop64_autosprite_v1.png` 네이밍 패턴 준수)
  - 소스 스테이징: `items/dalji_loading_cameo_hoop_roll_src_2048.png`
- **그리드 상수는 픽셀로 검증** 후 카탈로그에 기입 (atlas 메타데이터
  신뢰 금지 — video-tier 팩 트랩).
- 시트는 실루엣 용도지만 **풀컬러 원본을 그대로 커밋**한다 (§1 참조).
- 달지 정체성 락(walk 시트 앵커 대비 ±5% 바디 스케일)은 실루엣 용도라
  완화 적용하되, 명백한 비율 붕괴(머리 없는 실루엣 등)는 리젝.

## 7. 스모크 갱신 계획

- `godot/tests/battle_loading_screen_renderer_smoke.gd`:
  - **유지**: 인트로 게이트 3종 레그, completion-hold-does-not-block 레그,
    warmup 스냅샷/progress 계약 레그, perf batch 라벨 레그.
  - **교체**: 스테인드글라스 스테이지별 레그 6종 + 호스트 릴리즈/고아
    스윕 레그 → 미니멀 계약 레그로:
    1. `prewarm_assets()` 후 카메오 시트 텍스처 로드 확인.
    2. `draw()`가 카메오 로드 상태에서 에러 없이 완주 + 세션 내 카메오
       픽 고정 (draw 2회 간 동일 엔트리 id).
    3. `should_hold_completion` 최소 노출 홀드 → 시간 경과 후 해제.
    4. `hide_loading()` 후 세션 상태(픽/타이머) 리셋.
    5. 스냅샷 `tip_tier`/`tip_character`/`progress` 계약 유지.
- `battle_scene_stage_transition_loading_smoke.gd`: 컨텍스트 키 계약
  레그 유지 확인 (제목/서브타이틀 키는 계속 스냅샷으로 흘러야 함).
- `battle_loading_tips_smoke.gd`: 무변경 (배선 위치만 이동).
- boot_flow 쪽에 기존 스모크가 있으면 동일 원칙으로 갱신, 없으면 이번
  슬라이스에서 신규 강제하지 않음 (라이브 QA로 대체).
- **판정은 표준 러너 `run_smoke_tests.ps1` 관통** (엔진 `ERROR:` 실패
  승격 포함 — 공허 GREEN 트랩 주의).
- **반증검증(SAFE)**: 새 카메오-픽 고정 레그가 "draw마다 재추첨" 버그
  코드에서 FAIL함을 in-place 토글로 1회 증명. `git reset`/`checkout`/
  `stash` 절대 금지 (이 repo는 미커밋 WIP 다수).
- **픽셀 QA 필수**: 상태 스모크 GREEN만으로 사인오프 금지. 라이브 실행
  스크린샷으로 (a) 검정 배경 위 흰 실루엣 가독, (b) 우하단 위치/크기,
  (c) 팁 줄바꿈 없는 1줄 수용, (d) 스테이지 전환 로딩에서도 동일 룩
  확인.

## 8. 함정 체크리스트 (이 작업에서 걸리기 쉬운 것)

- **Hot-path lazy init**: 카메오 시트·폰트는 `prewarm_assets()` /
  `prewarm_stage_assets()`에서 로드. `draw()` 내 최초 로드 금지
  (기존 `_load_loading_wave_textures()`가 draw에서 lazy였던 패턴을
  답습하지 말 것).
- **Reserved-asset per-frame re-stat**: 카탈로그에 아직 생성 안 된 시트
  경로를 미리 넣지 말 것. 엔트리 추가 = 파일 랜딩 + `file_exists`
  검증과 같은 슬라이스.
- **에셋 파일 삭제 보류**: 스테인드글라스/웨이브 PNG는 이번 슬라이스에서
  **배선만 제거하고 파일은 남긴다.** 특히
  `stage6_tetriser_pillar_bg_imagegen_v1.png` /
  `stage8_minotaur_pillar_base_imagegen_v1.png`는 pillar HUD가 공유하는
  에셋이라 삭제 금지. 잔여 loading 전용 에셋 정리는 별도 감사 슬라이스
  (에셋청소 grep-blind 트랩 — manifest 확인 필요).
- **"Now Loading..." 번역 금지**: `translate_text` 경유하면 7언어 사전에
  키가 없어 원문 통과되긴 하지만, 의도(영문 고정 표기)를 코드 주석으로
  명시하고 번역 경로를 태우지 말 것. 팁은 반대로 번역 경로 유지.
- **BOM 트랩**: `.gd` 파일을 PowerShell `Out-File`로 쓰지 말 것.
- **스모크 공허 GREEN**: typed 객체 미선언 프로퍼티 대입은 레그 통째
  중단 + `ok` 출력. 표준 러너 관통으로만 판정.
- 실루엣 셰이더는 `CanvasItemMaterial`이 아닌 `ShaderMaterial` 1개를
  프리웜 시점에 만들어 재사용 (draw마다 생성 금지).

## 9. 완료 기준

1. 부트 로딩·전투 진입 로딩·스테이지 전환 로딩 3표면 모두 미니멀 룩.
2. 달지 굴렁쇠 카메오가 실루엣으로 우하단에서 루프하며, 로딩 세션당
   픽이 고정된다.
3. 스모크 표준 러너 GREEN + 반증검증 1회 + 라이브 픽셀 QA 스크린샷.
4. 기존 씰(stage7 프리배틀, 로딩 팁 스모크) 무손상.
5. 커밋은 헝크 분리 원칙 (외래 WIP 미포함).
