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

- **읽기 목표**: 플레이어가 다이얼을 봤을 때 "방울 N개가 걸린 청동 무구"로
  읽혀야 한다. 팔주령의 방사형 방울 배치가 현행 방사형 섹터 구조와 1:1로
  겹치므로, 구조 변경 없이 표피만 바꾼다.
- **프레임(회전 링)**: 옻칠 흑갈 바탕 + 놋쇠/청동 림 + 단청풍 반복 문양 밴드
  + 4방위 매듭(노리개) 악센트. 토큰 소진 시 프레임이 회전하는 기존 연출이
  그대로 "방울을 흔든다"는 플레이버가 된다.
- **토큰 셀(섹터)**: 기존 액체 충전 섹터는 **유지**(충전 진행도 가독성이
  이미 좋음). 각 섹터 중심(센트로이드)에 **방울 메달리온**을 올린다 —
  확보된 토큰 = 밝은 놋쇠 방울(십자 울림구멍), 빈 섹터 = 어두운 방울
  실루엣, 충전 중 섹터 = 기존 액체 충전 + 방울이 점점 밝아짐.
- **팔레트**: 놋쇠 금 `#c9973f`~`#e8c66a` 계열 + 옻칠 흑갈 + 단청 적/청
  포인트 + 먹선 윤곽. 캐릭터별 토큰 정체성 색(context의 `token_*` 색 키)은
  액체/글로우 쪽에 남기고, 방울 본체는 놋쇠로 통일.
- **금지**: 프레임에 방울 개수를 박아 넣는 것. `max_tokens`는 동적
  (1~5, 실전 base 1 + 증폭 +3)이라 프레임에 고정 개수 방울이 박히면
  섹터 분할선과 어긋난다. 프레임은 **개수 중립적**(방사 반복 문양)으로,
  방울 개수 표현은 런타임 셀이 담당.
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
| 드로우 순서 | body → 토큰 섹터 → 프레임 텍스처(회전) → 유리 돔 → boost FX host → flash → idle ring → "N/M" 카운트 텍스트(중앙, 16px) | `pillar_dash_orb_renderer.gd:62-136` |
| 보스 대쉬 오브 | 같은 렌더러 공유, 단 `boss_dash_frame_texture = null`(프레임 없음), 유리 림 보라 `(0.86,0.56,1.0)` | `stage1_pillar_hud_scene_drawer.gd:318`, `stage1_pillar_status_orb_context_builder.gd:65` |
| 게이지/스킬 오브 프레임 | **별도 텍스처 키**(`gauge_orb_frame_texture`, `skill_orb_frame_texture`) — 대쉬 프레임 교체가 게이지 오브에 영향 없음 | `stage1_pillar_hud_scene_drawer.gd:297,306` |

방울이 유리 돔 **아래**(fill 단계)에 그려지므로 "유리 안에 담긴 방울" 읽기가
공짜로 나온다. 방울 셀은 fill 렌더러 소속이라 프레임 스핀에 **딸려 돌지
않는다** (섹터 고정) — 의도된 동작이며 바꾸지 말 것.

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

### 3.2 방울 셀 (필수 — "방울 모양"의 본체)

- 파일: `godot/assets/sprites/orbs/dash_token_bell_cell_imagegen_v1.png`
- 단일 방울 1개, 소스 128x128 내외, 여백 넉넉히. 상태 표현은 런타임
  modulate(확보=원색, 빈 섹터=어둡게+저채도)로 처리 — 2상태 시트 불필요.
  modulate만으로 빈 상태 실루엣 가독이 안 나오면 그때 dim 변형 1장 추가.
- 실루엣 조건: 최소 표시 크기 **~20px**(5토큰 @ r=55)에서 "방울"로 읽혀야
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
- 방울 셀: 최종 PNG 크기, 알파 bbox, 방울 본체의 시각적 무게중심(고리
  포함 시 중심이 위로 쏠림 — 센트로이드 배치 시 Y 보정값을 실측으로 기록).

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
3. **방울 셀 드로우**: `pillar_dash_token_fill_renderer.gd`의
   `_draw_multi_dash_tokens` / `_draw_single_dash_token`에 섹터 센트로이드
   방울 드로우 추가. 배치 = `center + Vector2(cos, sin)(섹터 중앙각) *
   inner_radius * ~0.6`, 크기 = `inner_radius * ~0.5` 캡(싱글 토큰 모드는
   중앙 대형 방울 1개, "N/M" 텍스트와 겹침 검사). 상태 = modulate
   (확보/빈/충전-중 보간).
4. **정적 레이어 캐시**: 컴팩트 풀 단일토큰 베이크
   (`_build_compact_full_single_token_ops` + `_compact_token_cache_key`)에
   방울이 들어가면 **캐시 키에 방울 텍스처 유무를 포함**해 스테일 베이크
   방지. `prewarm_caches` 경로(로딩 프레임)에도 같은 조건 반영.
5. **보스 대쉬 오브**: fill 렌더러 공유라 방울 셀은 보스 다이얼에도
   나타난다 — **의도된 공유**로 승인함(보스도 활주방울을 쓰는 세계관).
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
  셀은 `draw_texture_rect` 1~5콜 + modulate 수준으로 유지(절차적 다층
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
- 신규 씰 1개: fill 렌더러가 (a) 방울 텍스처 컨텍스트 존재 시 토큰 수만큼
  방울 드로우 콜을 내고 (b) 텍스처 부재 시(부트 초기/헤드리스) 기존 액체
  섹터만으로 안전 폴백하는지. 표준 러너 `run_smoke_tests.ps1` 관통
  (공허-GREEN 트랩 — `ok / SCRIPT ERROR / ^ERROR` 3필드).
- `run_headless_load_check.ps1` + `run_warning_scan.ps1`.
- **픽셀 QA (사인오프 필수)**: 라이브 1판에서 ① r=55(창모드 1x)와
  1440p(r=105.6) 양쪽 방울 가독 ② max_tokens 1 / 3 / 5 각 상태(획득·소진·
  충전 중) ③ "N/M" 카운트 텍스트와 방울 겹침 없음 ④ 소진 스핀 시 프레임
  회전 읽기 ⑤ 보스 다이얼 보라 팔레트 방울 확인.
- 스크린샷 아카이브: 교체 전/후 비교 1세트.

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
