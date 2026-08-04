# 대성영단 시네마틱 비주얼 개선 핸드오프

작성일: 2026-08-04. 작성자: Claude (아트 디렉션 평가 → 실행 핸드오프).
분업 경계는 `CLAUDE.md` §0.1: 컨셉·팔레트·레이어 레시피·프롬프트·수용 판정 = Claude,
에셋 생성(imagegen)·누끼·리포 반입·로더/프리웜 배선·런타임 합성·씰 = Codex.

## 1. 배경 — 평가 결론

대상: 신화 액티브 아이템 **대성영단** (호환 ID `elixir_of_mastery`) 사용 시네마틱.

- 드로우: `godot/scripts/items/elixir_of_mastery_cinematic_draw.gd`
- 상태/타이밍: `godot/scripts/items/elixir_of_mastery_runtime.gd`
  (BUILDUP 3.0초 → REVEAL → CELEBRATION, 입자 60, 대성진 3겹 r=80/130/180)
- 픽셀 캡처 도구(기존): `godot/tools/daeseong_yeongdan_cinematic_capture.gd`

평가 총평: **구도·스테이징(암전 0.78 → 중앙 글로우 → 영단, 텍스트 페이드 순서)은
합격권. 그러나 화면 주역 3요소(대성진·글로우·영단)가 전부 절차적 프리미티브라
신화 티어 재질감 미달.** 월담야습 rev7·경신보에서 두 번 반려된 "절차적 프리미티브
주역 = 허접" 클래스와 동일.

확정 결함 (우선순위순):

| # | 결함 | 근거 |
|---|------|------|
| D1 | 대성진이 `draw_line` 현(버트 캡)+꼭짓점 점이라 진법이 아닌 레이더 도식/와이어프레임으로 읽힘 | `_draw_buildup` L59-72 |
| D2 | 글로우가 하드엣지 `draw_circle` 2겹 → 탁한 갈색 원반. 밝은 코어·소프트 폴오프 부재(발광 예산 미달) | L88-91 |
| D3 | 주인공 영단이 원 3겹+하이라이트 1점+스포크 6개, 받침대는 플랫 사각+라인 2개 = 화면에서 밀도 최저(위계 역전, placeholder급) | L97-127 |
| D4 | 빨간 방사 스포크 인장이 알람 시계/경고 별표로 오독 | L122-127 |
| D5 | 모션이 3초 내내 등속 사인 루프(글로우 sin3.0/입자 sin4.0/진법 sin2.0), 진법 수렴 30%뿐 → 클라이맥스 가속감 없음. 연단 컨셉인데 상승 기류 모티프 부재 | runtime + draw |

## 2. 해법 — 3피스 전용 텍스처 + 절차 보조 (확정 방향)

기존 반려 사례에서 확정된 정답 클래스 그대로: **정적 텍스처 소수 정예 + 런타임
합성**(`docs/skill_vfx_workflow.md` 모듈러 기본형). 16프레임 시트 대상 아님 —
링 회전·호흡 스케일은 런타임이 담당하므로 정적 피스가 맞다(의도된 선택).

에셋 폴더: `godot/assets/sprites/effects/daeseong_yeongdan/`
(선례: `effects/mythic_acquisition/`의 피스 구조, `*_imagegen_v1` + `_source`/`_alpha` 네이밍)

### P1. 대성진 링 텍스처 2장 (D1 해소)

- `daeseong_rune_ring_outer_imagegen_v1.png` — 바깥 링. 전서(篆書)체 한자 부적
  문양이 원환을 따라 배열된 무협 진법 링. 소스 1024², 런타임 512².
- `daeseong_rune_ring_inner_imagegen_v1.png` — 안쪽 링. 기하 문양(태극/팔괘 계열
  간소화) + 가는 이중 원환. 소스 1024², 런타임 512².
- 팔레트 앵커: 금 `#ED9C1F`~`#FFD138`, 포인트 단사 `#D6290F`. 배경 완전 투명,
  문양이 셀 가장자리에 닿지 않게 여백 확보.
- 런타임: 바깥 링 정회전 / 안쪽 링 **역회전**(이속), 기존 수렴 스케일 계승.
- imagegen 프롬프트 초안 (Gemini, FLUX 금지 — 표준 라우팅):

  > A circular martial-arts summoning formation ring on a fully transparent
  > background, ancient Korean-Chinese seal-script (전서체) calligraphy glyphs
  > arranged evenly along the ring band, thin double concentric gold lines,
  > glowing warm gold (#ED9C1F to #FFD138) with subtle crimson (#D6290F)
  > accent marks, flat 2D game VFX asset, crisp edges, no background, no
  > center content, generous transparent margin, top-down view, symmetrical.

  (안쪽 링은 "seal-script glyphs" 대신 "minimal taegeuk/palgwae-inspired
  geometric trigram marks"로 교체, 밴드 폭 더 얇게.)

### P2. 글로우 백플레이트 1장 (D2 해소)

- `daeseong_glow_backplate_imagegen_v1.png` — 중심이 **찬**(속이 빈 원환 금지)
  밝은 코어 → 부드러운 방사 폴오프. 코어 거의 백금색 `#FFED8F`→외곽 `#ED9C1F`→투명.
  소스 1024², 런타임 512².
- 프리베이크가 정답인 이유(둘 다 표준 트랩):
  - **immediate `_draw()` 안 `canvas.material` 스왑 = no-op** — ADD 블렌드를
    코드로 걸 수 없다. 광량은 텍스처에 굽는다(MIX로 그려도 0.78 암전 위라 발광으로 읽힘).
  - **겹원 알파 스태킹 금지** — 절차 원 다겹은 중심이 탁해진다. 알파 밴드
    프리베이크 1장이 정석.
- 절차 대비 요구 결과: 중심 휘도가 명확히 상승("VFX 발광 예산: 발광 정체성은
  가운데가 찬 밝은 레이어로 재공급"). 현행 sin 등속 펄스 대신 progress 램프
  (§4 모션 리튠과 세트).

### P3. 영단 + 화로 받침 일러스트 1장 (D3·D4 해소)

- `daeseong_pill_furnace_imagegen_v1.png` — 금단(金丹) 환약 + 무협 화로(삼족
  향로/단로) 받침을 한 장에. 환약 표면 인장은 방사 스포크가 아니라 **전서 한
  글자(예: 丹 또는 極) 인장**으로 교체(D4). 소스 1024², 런타임 256².
- 현행 절차 드로우 대비 유지할 것: 호흡 스케일(`bottle_scale` 그대로 적용),
  중심 앵커(현행 pill_center/casket 자리 대체). 스포크 회전 모티프는 삭제하고
  회전감은 P1 링이 전담.
- 프롬프트 초안:

  > A mythical golden elixir pill (금단) resting on an ornate dark-crimson
  > three-legged incense furnace pedestal, wuxia/Korean-mythology style, the
  > pill engraved with a single glowing seal-script character, warm gold body
  > (#F5A61A) with pale highlight (#FFED8F), deep crimson furnace (#6B0A05)
  > with bright edge trim (#D6290F), flat-shaded 2D game illustration with
  > clean outlines, fully transparent background, generous margin, front view.

### 스코프 아웃 (이번 슬라이스에서 하지 않음)

- 상승 영기 입자 텍스처화 — 절차 유지(§4에서 벡터만 상승 나선로 조정).
- REVEAL/CELEBRATION의 방사 광선(`_draw_radial_rays`, 같은 버트 캡 클래스)·폭죽 —
  후속 슬라이스 후보로만 기록. BUILDUP 3피스가 먼저.
- 타이틀 폰트 결(현재 `ThemeDB.fallback_font`) — 별건 P3 백로그.

## 3. 런타임 배선 지시 (Codex)

레이어 순서 (BUILDUP, 아래→위):

1. 암전 오버레이 (현행 유지)
2. **P2 글로우 백플레이트** (progress 램프 알파·스케일)
3. **P1 바깥 링** (정회전 + 수렴 스케일)
4. **P1 안쪽 링** (역회전 + 수렴 스케일)
5. 절차 입자 (현행, 상승 나선로 조정)
6. **P3 영단·화로** (호흡 스케일)
7. 텍스트·플래시 (현행 유지)

필수 준수 트랩 (전부 이 리포 표준 룰):

- **PNG-first + 절차 폴백**: 텍스처 로드 성공 시 절차 드로우를 대체, 실패 시
  현행 절차 경로 유지. 폴백 조기-return이 PNG 경로를 우회하지 않는지 grep으로
  승자 경로 확인(아이콘 우회 grep 규칙).
- **미생성 경로 선배선 금지** (Missing Reserved-Asset Per-Frame Re-Stat Trap):
  아트 랜딩 + `file_exists` 어서트를 같은 슬라이스로. 경로만 먼저 심지 말 것.
- **핫패스 콜드로드 금지** (Hot-Path Lazy Init Trap): 시네마틱 첫 프레임에서
  로드하지 말고 이산 시점(전투 로딩 프레임 or 아이템 획득/장착 적용 시점)에
  프리웜. 스레디드 프리웜을 쓰면 2단 폴백(STALE+MAX) 규칙 준수, 준비 게이트는
  sync-load 최후 폴백 금지.
- **texture spec ↔ loader 동기화** + `load_imported`/스트리밍 경로 사용(raw
  `load()` 우회 금지).
- **비헤드리스 .import 실체화**: PNG 반입 후 비헤드리스 에디터 패스로 .import
  실체화하지 않으면 캡처/씰이 스테일 RED.
- 회전 드로우는 `draw_set_transform` 사용 후 반드시 IDENTITY 복원.

모션 리튠 (에셋과 무관한 코드 작업, D5):

- 진법 수렴 30% → ease-in 커브로 강화(최종 0.5초 가속 수렴), 회전 속도도
  progress 비례 가속.
- 글로우: sin 등속 펄스 → progress 상승 램프 + 종반 펄스 가속(플래시 직전
  최대 휘도).
- 입자: 순수 궤도 → 궤도 + 상승 성분(연단 김/영기). 스폰·수명은 현행 유지.

## 4. 수용 게이트 (QA)

1. **픽셀 캡처 before/after**: `<godot> --path godot -s
   res://tools/daeseong_yeongdan_cinematic_capture.gd` (비헤드리스 필수)로
   buildup 프레임 재캡처. 판정은 인상이 아니라 캡처로(경신보 자기보고 반증 사례).
2. **강한 임계 픽셀 판정**: 중심부(반경 ~40px) 고휘도 픽셀 카운트(예: R>0.9 &
   G>0.7)가 현행 대비 유의미 증가. 약한 임계는 버그·정상이 같은 값이 나오므로 금지.
3. **링 가시성**: 링 밴드 반경 대역에서 채도 픽셀 카운트 > 0 + 절차 폴백
   OFF/ON 대조.
4. **씰**: 텍스처 3피스 `file_exists` + 로드 성공 + PNG 경로 승자 확인 레그를
   묶은 스모크 1본. 표준 러너(`run_smoke_tests.ps1`) 관통, `_failed` 게이트
   (공허-GREEN 방지).
5. **폴백 레그**: 텍스처 부재 픽스처에서 절차 드로우가 살아있고 에러 스팸이
   없는지(성공-only 캐시 재-stat 트랩 관점) 확인.
6. 프리웜 등록 확인: 시네마틱 발동 프레임에 콜드 로드 히치 없음(라이브 1판).

## 5. 아트 수용 판정 기준 (Claude 재검수 시)

- 대성진이 "진법 의식"으로 읽히는가 (레이더 도식 인상 소멸).
- 중앙이 "빛난다"고 읽히는가 (갈색 원반 인상 소멸).
- 영단·화로가 화면에서 가장 밀도 높은 오브젝트인가 (위계 정상화).
- 인장이 경고/시계로 오독되지 않는가.
- 전체 톤이 환격전 리브랜딩(무협·금+단사) 안에 있는가.

## 6. 재검수 결과 (2026-08-04, Claude) — **APPROVE**

구현: 내장 ImageGen 4피스 + PNG-first 배선 + 모션 리튠 (Codex). 재검수는
before/after 캡처 픽셀 대조 + 전 배선 코드 직독 + 신규 스모크
`daeseong_yeongdan_cinematic_visual_smoke.gd` 표준 러너 독립 재실행(GREEN)으로
수행.

§5 판정: 5항목 중 4항목 명확 통과. D1(레이더 도식)·D2(갈색 원반)·D3(밀도
역전)·D4(스포크 오독) 전부 해소 확인. 픽셀 수치(링 강광 220→14,716, 중심
고휘도 137→434)도 독립 샘플링과 부합.

배선 트랩 준수 확인: 캐시 딕셔너리 기반 PNG-first(재-stat 없음, 미완성 세트
= 절차 폴백 영구 캐시), 프리웜은 `battle_boot_resource_prewarm_controller`
→ `active_item_runtime.prewarm_assets_step` step 3으로 로딩 시퀀스 등재,
스레디드 로더 imported-폴백 사용, IDENTITY 복원, 스모크는 `_failures` 게이트
+ 핫패스 소스 계약 단언까지 공허-GREEN 방지 구조.

**P2 폴리시 노트 (승인 조건 아님)**: 글로우 백플레이트 색조가 앵커 대비
청색 채널 부족으로 황록빛 기운(측정: 글로우 밴드 G/R≈0.94에 B≈41 — 코어
앵커 `#FFED8F`는 B=143). 다음 에셋 터치 시 글로우만 웜 톤(B 상향)으로 v2
재생성 권장. 판정을 뒤집을 수준은 아님.

잔여: 라이브 인게임 1판 QA(발동 프레임 히치 무확인), 공유 파일 WIP 분리 후
헝크 커밋.
