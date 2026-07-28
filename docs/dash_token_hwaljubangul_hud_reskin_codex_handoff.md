# 대쉬토큰 HUD → 활주방울(滑走鈴) 리스킨 — Codex 배선 핸드오프

작성: 2026-07-28 (Claude 아트디렉션). 실행 주체: Codex (imagegen 생성 + 누끼 +
repo 배치 + 런타임 배선 + 검증 — `docs/skill_vfx_workflow.md` 분담 기준).

## 0. 배경 / 명명 확정

- 환격전 리브랜딩 용어: 대쉬 = **활주**, 대쉬토큰 = **활주방울** (2026-07-28
  사용자 확정). 방울 = 무령(巫鈴)·풍경·범종으로 이어지는 게임 관통 상징이며,
  부제 후보 《팔주령(八珠鈴)》과 모티프 계승 관계.
- 이 문서의 스코프는 **HUD 아트 리스킨 + 그 배선**이다. 유저-대면 문구
  전환("대쉬 토큰"→"활주방울", 7언어 동기화)은 §9의 별도 후속 트랙 —
  이 슬라이스에 묶지 말 것.
- 코드/레포 내부 식별자(`dash_token`, `dash_amplification` 등)는 리브랜딩
  방침대로 **유지**. 파일명·상수명 리네임 금지.

## 1. 리스킨 컨셉 (아트디렉션 확정)

현행 대쉬토큰 다이얼 = "붉은 액체 섹터 + 회전 장식 프레임 + 유리 돔".
이걸 **청동 무령 다이얼**로 전환한다:

- **읽기 목표 (사용자 후속 확정)**: 방울은 토큰 수를 표현하는 셀이 아니다.
  다이얼 HUD 상단에 **항상 1개만 달린 장식**이며, 토큰 수·획득·빈 상태·충전
  진행은 기존 액체 섹터와 중앙 `N/M` 텍스트만 담당한다.
- **프레임(회전 링)**: 옻칠 흑갈 바탕 + 놋쇠/청동 림 + 단청풍 반복 문양 밴드
  + 4방위 매듭(노리개) 악센트. 토큰 소진 시 프레임이 회전하는 기존 연출이
  그대로 "방울을 흔든다"는 플레이버가 된다.
- **토큰 셀(섹터)**: 기존 액체 충전 섹터를 그대로 유지한다. 섹터 내부에는
  방울을 넣지 않는다. 상단 장식 방울은 상태에 따라 어두워지거나 늘어나지
  않고 항상 밝은 놋쇠 원색으로 표시한다.
- **팔레트**: 놋쇠 금 `#c9973f`~`#e8c66a` 계열 + 옻칠 흑갈 + 단청 적/청
  포인트 + 먹선 윤곽. 캐릭터별 토큰 정체성 색(context의 `token_*` 색 키)은
  액체/글로우 쪽에 남기고, 방울 본체는 놋쇠로 통일.
- **금지**: 프레임이나 섹터에 토큰 수만큼 방울을 반복 배치하는 것.
  `max_tokens`가 1~5로 바뀌어도 상단 장식 방울은 정확히 1개다. 프레임은
  개수 중립적이고, 방울은 토큰 개수 UI가 아닌 명칭/세계관 장식이다.
- **회전 친화**: 프레임은 소진 스핀으로 돌아가므로 상하 방향성이 강한
  단일 오너먼트 금지 — 4회 이상 방사 대칭이 기본.

## 2. 현행 구조 (2026-07-28 실측)

소유 체인은 단일이다 (preload 사이트 grep으로 확인):

```
stage1_pillar_hud_scene_drawer.gd  (stage6/7/8 씬 드로어가 재사용 — 주석 명시)
  └ stage1_pillar_ui_renderer.gd
      └ pillar_status_orb_renderer.gd      (플레이어 대쉬 + 보스 대쉬 + 게이지 오브)
          └ pillar_dash_orb_renderer.gd    (다이얼 본체)
              ├ pillar_dash_orb_body_renderer.gd
              ├ pillar_dash_token_renderer.gd
              │   ├ pillar_dash_token_fill_renderer.gd   (섹터 액체 + 컴팩트 단일토큰 베이크)
              │   │   └ pillar_dash_token_divider_renderer.gd
              │   └ pillar_dash_token_flash_renderer.gd
              └ dash_token_boost_fx_host.gd (GPU 셰이더 오버레이; CPU 폴백 병존)
```

핵심 실측값:

| 항목 | 값 | 출처 |
|---|---|---|
| 프레임 텍스처 경로 상수 | `DASH_TOKEN_FRAME_TEXTURE_PATH = "res://assets/sprites/orbs/dash_token_frame_imagegen_v2.png"` | `battle_core_texture_paths.gd:5` (단일 소스 — `battle_resources.gd:616` 스펙과 `battle_pso_prewarmer.gd:349`가 이 상수를 읽음) |
| 현행 v2 소스 크기 | 240x240 px | 실측 |
| 프레임 드로우 크기 | `radius * 196 / 55` (r=55에서 196px 박스, 중심 정렬) | `pillar_orb_chrome_drawer.gd:44 get_orb_frame_draw_size` |
| 오브 반경(라이브) | `55 * (game_size.y / 750)` 연속값; 프리웜 정확 키 = 55 / 79.2 / 105.6 | `pillar_orb_chrome_drawer.gd:36` |
| 섹터 내부 반경 | `radius - 5 * scale_factor` (r=55 → 50) | `pillar_dash_orb_renderer.gd:77` |
| 섹터 시작각 | `-PI/2` (12시), 시계방향 `TAU/max_tokens` | `pillar_dash_orb_renderer.gd:78-79` |
| max_tokens 범위 | 1~5 (분할선 프리웜 흔한 키 = [2,3]) | `pillar_dash_token_fill_renderer.gd:9` |
| 프레임 스핀 | 토큰 **감소** 시(소진) 스핀 시작 | `orb_hud_state.gd:66-68` |
| 드로우 순서 | body → 토큰 섹터 → 프레임 텍스처(회전) → 유리 돔 → 상단 장식 방울 1개 → boost FX host → flash → idle ring → "N/M" 카운트 텍스트(중앙, 16px) | `pillar_dash_orb_renderer.gd` |
| 보스 대쉬 오브 | 같은 렌더러 공유, 단 `boss_dash_frame_texture = null`(프레임 없음), 유리 림 보라 `(0.86,0.56,1.0)` | `stage1_pillar_hud_scene_drawer.gd:318`, `stage1_pillar_status_orb_context_builder.gd:65` |
| 게이지/스킬 오브 프레임 | **별도 텍스처 키**(`gauge_orb_frame_texture`, `skill_orb_frame_texture`) — 대쉬 프레임 교체가 게이지 오브에 영향 없음 | `stage1_pillar_hud_scene_drawer.gd:297,306` |

방울은 유리 돔과 회전 프레임보다 **나중에** 그리는 상단 전경 장식이다.
프레임이 소진 스핀으로 돌아도 방울 자체는 상단에 고정되어, 다이얼에 매달린
방울을 프레임이 흔드는 읽기를 만든다.

## 3. 에셋 목록 + 생성 스펙

생성 도구: imagegen (정지 HUD 크롬이므로 AutoSprite 요구 대상 아님).
`ui-hud-generation` 스킬 §3/§4 준수.

**⚠️ 크로마키는 마젠타 `#ff00ff` 필수.** 청동 녹청·단청 녹색 계열이 팔레트에
들어가므로 그린 키는 despill 사고 위험. `chroma_key.py <src> <dst> --key magenta`.

### 3.1 프레임 v3 (필수)

- 파일: `godot/assets/sprites/orbs/dash_token_frame_imagegen_v3.png`
  (+ `_source` / `_alpha` 시블링은 `images/ui/hud/`에 보관)
- 소스 240x240 유지 권장(교체 무배선). **v2의 알파 링 비율을 실측해 동일
  비율로 맞출 것** — 내부 투명 홀 지름은 드로우 박스 대비 `110/196`
  이상이어야 오브 본체(지름 110 @ r=55)를 가리지 않는다. 240px 소스 기준
  내부 홀 ≥ ~135px.
- 프롬프트 골격:

```text
Create a circular decorative HUD ring frame for a Korean mythic-martial
arcade game, on a perfectly flat solid #ff00ff chroma-key background.

The ring is an antique Korean bronze shamanic-instrument rim: dark
lacquered brown-black base band, polished brass / bronze double rim lines,
a repeating dancheong-style geometric pattern band (muted red, deep teal,
gold accents, thin black ink outlines), and four small knotted norigae
tassel ornaments placed at radially symmetric positions. The center is a
completely empty transparent hole. The pattern must repeat radially at
least 4 times so the ring reads well while slowly rotating.

No text, no numbers, no bells inside the hole, no characters, no gameplay
scene, no watermark. Background exactly flat #ff00ff, no gradient or
shadow. Do not use #ff00ff inside the ring art.
```

### 3.2 상단 장식 방울 (필수)

- 파일: `godot/assets/sprites/orbs/dash_token_bell_cell_imagegen_v1.png`
- 단일 방울 1개, 소스 128x128 내외, 여백 넉넉히. 토큰 상태와 무관한 고정
  장식이므로 런타임 상태 modulate와 dim 변형은 사용하지 않는다.
- 실루엣 조건: 기본 표시 크기 **~28px**(r=55)에서 "방울"로 읽혀야
  한다. 둥근 몸통 + 십자/일자 울림 구멍 + 상단 고리 정도의 단순 실루엣.
  주렁주렁한 술·끈 디테일 금지(축소 시 뭉갬).
- 프롬프트 골격:

```text
Create a single small Korean bronze shaman bell (bangul), game HUD icon
style, on a perfectly flat solid #ff00ff chroma-key background.

Round brass bell body with a simple cross-shaped sound slit, small top
loop, warm gold-brass metal with dark lacquer shading and thin black ink
outline. Bold, simple silhouette that stays readable at 20 pixels. Front
view, centered, generous transparent margin.

No text, no background scene, no cast shadow, no watermark. Background
exactly flat #ff00ff. Do not use #ff00ff inside the bell art.
```

### 3.3 후처리 공통

- `py .claude/skills/sprite-generation/chroma_key.py <src> <dst.png> --key magenta`
- 검증: 알파 채널 존재 / 네 모서리 투명 / 알파 bbox 에지 비접촉 / 마젠타
  프린지 없음(어두운·밝은 배경 양쪽 프리뷰).
- 업스케일 요청은 현재 없음 — Real-ESRGAN 게이트 불필요.

## 4. 소스 앵커 핸드오프 (에셋 수락 후 기록)

- 프레임 v3: 최종 PNG 크기, 알파 bbox, 내부 투명 홀 지름(px), 외곽 링
  지름(px), v2 대비 비율 차이(있다면 코드 보정 필요 여부).
- 상단 장식 방울: 최종 PNG 크기, 알파 bbox, 방울 본체의 시각적 무게중심.
  알파 중심이 구슬 최상단 경계에 오도록 Y 보정값을 실측으로 기록한다.

### 4.1 Codex 에셋 수락 실측 (2026-07-28)

- 프레임 v3: imagegen 마젠타 소스 `1254x1254`, 누끼/패딩 시블링
  `969x981`, 런타임 PNG `240x240`. `alpha > 16` bbox는
  `Rect2i(22, 21, 196, 198)`, 중심 투명 홀은 같은 임계값에서 가로
  `154px` / 세로 `157px`다. v2의 외곽 bbox `198x198` 대비 가로만
  `-2px`이고, 중심 홀은 v2 축 실측 `130~132px`보다 `24~27px` 넓다.
  기존 `196/55` 프레임 크기는 유지하되, 2026-07-28 실기 캡처에서 넓은
  홀 때문에 프레임과 구슬 사이 배경 틈이 확인되어 텍스처 프레임 사용 시
  구슬 콘텐츠 반경을 `orb_radius * 1.15`로 확장해 프레임 아래로 겹친다.
- 상단 장식 방울: imagegen 마젠타 소스 `1254x1254`, 누끼/패딩 시블링
  `615x892`, 런타임 PNG `128x128`. `alpha > 16` bbox는
  `Rect2i(27, 10, 74, 108)`. 알파 가중 무게중심은 `(63.61, 72.58)`로
  이미지 중심보다 Y가 `+8.58px` 아래이므로, 런타임은 셀 드로우 크기의
  `-0.067`만큼 위로 보정한다. 장식 방울은 중앙 `N/M` 텍스트와 분리하고
  구슬 내부가 아닌 상단 경계에 걸치도록 `inner_radius * -1.10`에 두며,
  프레임·유리 레이어 뒤가 아니라 그 위의 전경 오버레이로 그린다.
- 두 런타임 PNG 모두 네 모서리 알파 `0`, 불투명 마젠타 우세 픽셀 `0`.
  r=55 상단 장식 방울 드로우 박스는 `28px`이며 토큰 수와 무관하게 1개만
  표시되고, r=105.6에서도 동일 비율로 확대된다.

## 5. 런타임 배선 지점 (Codex)

1. **프레임 교체**: `battle_core_texture_paths.gd:5`의
   `DASH_TOKEN_FRAME_TEXTURE_PATH`를 v3 경로로 갱신. 스펙
   (`battle_resources.gd:616`)과 PSO 프리웜(`battle_pso_prewarmer.gd:349`)은
   상수를 읽으므로 자동 추종. v2 파일은 롤백 레퍼런스로 유지(삭제 금지).
2. **방울 텍스처 등록**: `battle_resources.gd` 텍스처 스펙에
   `dash_token_bell_cell_texture` 키 추가 → 파이프라인 프리웜에 합류.
   ⚠️ fill 렌더러에서 `load()` 직접 호출 금지 (핫패스 lazy-init 트랩).
   컨텍스트로 텍스처를 내려보내는 기존 패턴(`dash_frame_texture` 참조)을
   따라 `stage1_pillar_hud_scene_drawer` → `stage1_pillar_status_orb_context_builder`
   → fill 렌더러로 스레딩.
3. **상단 장식 방울 드로우**: 토큰 수와 무관하게 HUD 인스턴스당 정확히
   1개만 그린다. 알파 중심은 구슬 최상단 경계, 크기는 r=55에서 `28px`.
   프레임·유리보다 나중에 그려 섹터 안이 아니라 HUD 위에 달린 장식으로
   읽히게 한다. 확보/빈/충전 상태 modulate는 적용하지 않는다.
4. **정적 레이어 캐시**: 방울은 캐시된 액체/단일토큰 베이크에 넣지 않고
   전경 `draw_texture_rect` 1콜로 유지한다. 따라서 텍스처 상태를 캐시 키에
   추가할 필요가 없다.
5. **보스 대쉬 오브**: 공유 렌더러를 쓰므로 보스 다이얼도 상단 장식 방울
   1개를 공유한다 — **의도된 공유**로 승인함(보스도 활주방울을 쓰는 세계관).
   보스 팔레트(보라 계열)는 기존 context 색 키로 자동 적용. 프레임
   텍스처는 현행대로 보스 = null 유지(변경 금지, §9 후속 결정).
6. **스코프 확인**: 대쉬 오브 드로우는 위 체인이 유일한 소유자다
   (`PillarDashOrbRenderer` preload 사이트는 `pillar_status_orb_renderer.gd`
   하나). 배선 후 스테이지 2~8 각 1회 진입해 다이얼이 전 스테이지에서
   교체됐는지 확인 — 우회 렌더러가 발견되면 이 문서에 추기.

## 6. 함정 체크리스트 (기존 트랩 매핑)

- **핫패스 lazy-init**: 방울 텍스처는 프리웜 등록 + context 스레딩. draw
  경로에서 조건부 인스턴스화 금지.
- **Missing Reserved-Asset per-frame re-stat**: PNG가 레포에 실재하기 전에
  경로를 배선하지 말 것. 아트 랜딩 + `file_exists` 어서션 + 배선을 **같은
  슬라이스**로.
- **HUD 상시-가시성 × 절차 드로우 예산**: 대쉬 다이얼은 상시 가시. 방울
  장식은 토큰 수와 무관한 `draw_texture_rect` 1콜로 유지(절차적 다층
  글로우 추가 금지). static_hud_lod 경로에서도 방울은 그리되 부가 이펙트는
  기존 LOD 게이트를 따른다.
- **유리 림 프리웜 색 동기화**: 토큰 색 키를 바꾸면
  `pillar_orb_chrome_drawer.gd:27 GLASS_PREWARM_RIM_COLORS` 주석 계약대로
  동기화. (이번 스코프는 색 키 유지가 기본이라 해당 없음이 정상.)
- **`.import` 사이드카 게이트**: 신규 PNG 2장은 에디터/`--headless --import`
  임포트 패스로 `.png.import` + `.godot/imported/*.ctex` 생성 확인 후 PNG와
  함께 커밋. `run_headless_load_check.ps1` 통과는 증명이 아님.
- **비헤드리스 QA**: 픽셀 QA 전 임포트 실체화(스테일 RED 주의).
- **draw_set_transform**: 프레임 회전이 `draw_set_transform`을 쓰고 즉시
  IDENTITY 복원하는 기존 패턴(`pillar_orb_chrome_drawer.gd:61-63`)을 방울
  드로우가 깨지 않게 — 방울은 변환 없이 절대좌표 드로우 권장.

## 7. 검증 / 씰

- 기존 스모크 GREEN 유지: `dash_token_boost_fx_host_smoke.gd`,
  `dash_snapshot_builder_smoke.gd`, `stage1_dash_side_gauge_*` 계열.
- 신규 씰 1개: fill 렌더러가 (a) 토큰 수·상태와 무관하게 상단 장식 방울
  스펙을 정확히 1개만 내고 (b) 텍스처 부재 시 기존 액체 섹터만으로 안전
  폴백하는지. 표준 러너 `run_smoke_tests.ps1` 관통
  (공허-GREEN 트랩 — `ok / SCRIPT ERROR / ^ERROR` 3필드).
- `run_headless_load_check.ps1` + `run_warning_scan.ps1`.
- **픽셀 QA (사인오프 필수)**: 라이브 1판에서 ① r=55(창모드 1x)와
  1440p(r=105.6) 양쪽 상단 방울 가독 ② max_tokens 1 / 3 / 5 모두 방울이
  정확히 1개인지 ③ "N/M" 텍스트와 방울 겹침 없음 ④ 소진 스핀 중에도
  방울은 상단 고정인지 ⑤ 보스 다이얼에도 상단 방울 1개인지 확인.
- 스크린샷 아카이브: 교체 전/후 비교 1세트.

### 7.1 Codex 구현 검증 결과 (2026-07-28)

- `--headless --import`로 신규 PNG 2장의 `.png.import`와 대응 `.ctex` 생성
  확인. 신규 씰 `dash_token_bell_cell_renderer_smoke.gd`는 에셋/프리웜 스펙,
  플레이어·보스 컨텍스트 공유, 토큰 수와 무관한 상단 장식 1개 배치,
  텍스처 부재 폴백을 검증한다.
- 대쉬/리소스/PSO 집중 회귀 11개 GREEN. 생산 드로우 경로의 per-frame
  Dictionary 생성을 제거한 뒤 신규 씰, boost FX host, status-orb prewarm
  3개를 다시 GREEN으로 확인했다.
- Stage 2~8 공유 경로는 각 스테이지의 pillar/HUD/wiring 스모크 7개 GREEN.
  전 스테이지 드로어가 동일 `Stage1PillarHudSceneDrawer`를 소유하는 preload
  체인도 재확인했다.
- 최종 `run_headless_load_check.ps1` GREEN. 최종 `run_warning_scan.ps1`은
  3,187개 GDScript 전체를 경고 없이 통과했다.
- 비헤드리스 Vulkan 캡처에서 r=55 / r=105.6, 1·3·5토큰 모두 상단 장식
  방울이 정확히 1개이고, `N/M` 분리, 보스 보라 다이얼의 방울 공유와 보스
  프레임 null을 확인했다. 로컬 비교 캡처는
  `godot/.tmp/dash_token_hwaljubangul_visual_qa.png`에 보관한다.
- 사용자 실기 캡처 후속 수정은 v3 홀 실측 반경까지 구슬/액체 콘텐츠를
  확대해 프레임 사이 배경 틈을 제거하고, 장식 방울 알파 중심을 구슬 상단
  경계로 올린 뒤 프레임·유리보다 나중에 정확히 한 번 그리는 순서를 회귀
  씰로 고정한다.

```text
Use this HUD PNG as the single visual source. Runtime may slice repeatable
regions from it, but should not mix old HUD pieces underneath it.
```

## 8. 커밋 규율

- 이 워크트리는 외래 WIP 다수 — 이 슬라이스 파일만 헝크 분리 커밋
  (에셋 2 + `.import` 2 + 배선 + 씰 + 이 문서). `git add -A` 금지.

## 9. 명시적 비스코프 (후속 트랙)

1. **문구 전환**: 유저-대면 "대쉬 토큰" → "활주방울" + 7언어 동기화.
   기존 활주 리브랜드 씰(`common_mugong_dash_rebrand_smoke.gd`) 확장 대상.
   로딩 팁 활주 용어 6언어 미동기 잔무와 같은 트랙으로 묶는 것을 권장.
2. **활주 SFX**: 토큰 소진 시 짧은 방울 울림 원샷(이름-연출-사운드 삼위
   일치). 포지셔널 패닝 정책 준수. 별도 슬라이스.
3. **보스 프레임 텍스처**: 보스 다이얼에도 v3 프레임을 달지 여부는
   미결정 — 현행 null 유지.
4. **퍽 아이콘**: `dash_amplification`(활주 확장) 퍽 아이콘의 방울 모티프
   동기화 여부 — 사용자 결정 대기.

## 10. 기력구슬 짝 프레임 최종 통일안 (2026-07-28)

- 사용자 후속 검토에서 기력구슬 v2의 고정 청람 옥 8개는 제거하기로
  확정했다. 활주 토큰 수는 1~5 동적인데 한쪽 링에만 고정 노드 8개가 있으면
  별도 8칸 자원처럼 읽히므로, 두 HUD의 공통 문법은 **개수 중립 연속 단청
  링**으로 통일한다. 방울은 계속 활주방울 HUD 전용 상단 장식이다.
- 최종 기력 프레임은 `gauge_orb_frame_imagegen_v3.png`. v2의 옥과 별 받침을
  모두 없애고 옻칠 흑갈·놋쇠·단청 문양을 끊김 없이 이어 활주 v3와 같은
  재질 언어로 맞춘다. 기력 HUD의 정체성은 프레임 장식 수가 아니라 내부의
  푸른 액체 게이지가 담당한다.
- 활주 v3 PNG를 그대로 공유하면 중앙 홀이 `154x157px`라 기력 소켓의
  `129x130px`보다 25~28px 커지고 구슬-테두리 빈 공간이 재발한다. 따라서
  파일은 분리하되 문양만 통일한다.
- 기력 v3 런타임 PNG는 `240x240`, `alpha > 16` 외곽 bbox `198x198`, 중앙
  투명 홀 `128x130px`. 기존 v1/v2 소켓과 밀착 범위를 유지하므로 구슬 반경
  보정 없이 `GAUGE_ORB_FRAME_TEXTURE_PATH`만 v3로 교체한다. 기존 리소스
  스펙과 PSO 프리웜은 이 상수를 자동 추종한다.
- imagegen 편집 기준: 기력 v2는 정확한 소켓 기준, 활주 v3는 개수 중립 문양
  기준. 마젠타 `#ff00ff` 키 제거 후 외곽을 `198px`로 정규화하고 링을
  안쪽으로만 보정해 홀 밀착 계약을 복원했다.
- 검증 씰 `gauge_orb_hwangyeok_frame_smoke.gd`는 경로·임포트·알파 홀·bbox,
  불투명 마젠타 및 고정 청람 옥 부재, 컨텍스트 전달, 코어 프리웜 스펙,
  프레임 최종 전경 드로우 순서를 고정한다.

## 11. 기력구슬 단일 상단 장식 확정 (2026-07-28)

- 사용자 후속 요청으로 활주방울의 단일 방울과 짝을 이루는 **청옥 기력결정
  노리개 1개**를 기력구슬 12시 방향에 둔다. 이는 장식일 뿐 게이지 칸이나
  추가 자원을 뜻하지 않는다.
- 자산은 `gauge_orb_ki_jade_ornament_imagegen_v1.png`: `128x128`,
  `alpha > 16` bbox `68x108`. 놋쇠·옻칠·단청 받침에 푸른 옥 코어 한 알만
  두며, 추가 구슬·술·문자·방울은 넣지 않는다.
- 기준 반경 `55px`에서 `28x28px`로 그리고 중심은 구슬 중심에서
  `y=-65px`에 둔다. 활주방울의 상단 장식과 같은 시각 높이로 링에 걸치되
  액체 코어는 침범하지 않는다.
- 장식은 회전 프레임 PNG에 굽지 않고 `pillar_gauge_orb_renderer.gd`가
  프레임 드로우 이후에 별도 고정 오버레이로 그린다. 따라서 기력 소진 프레임 회전
  중에도 청옥은 12시 방향을 유지한다.
- `GAUGE_ORB_KI_JADE_ORNAMENT_TEXTURE_PATH` -> 코어 텍스처 스펙
  `gauge_orb_ki_jade_ornament_texture` -> 게이지 컨텍스트
  `ornament_texture`로만 전달한다. 핫패스 lazy load는 금지하며 PSO 프리웜도
  실제 게이지 드로우 컨텍스트에 이 텍스처를 포함한다.
