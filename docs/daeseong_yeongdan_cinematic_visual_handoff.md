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

---

## 7. 후속 슬라이스 핸드오프 — 극성 도달 (REVEAL/CELEBRATION) (2026-08-05)

작성: Claude. 분업 경계는 §0과 동일(아트 디렉션·프롬프트·수용 판정 = Claude,
생성·반입·배선·씰 = Codex). 슬라이스 1(BUILDUP)이 프리미엄으로 올라가면서
직후에 나오는 이 화면과의 품질 낙차가 전보다 커졌다 — 같은 방법론으로 정렬한다.

### 7.1 현행 구조와 확정 결함

극성 도달 연출 흐름: REVEAL 1.5초(플래시 감쇠 + 결과 페이드인, 스파클 80) →
CELEBRATION(확인 대기, 쇼크웨이브 3호 + 폭죽 50/버스트 + 콘페티 140 + 배너 +
극성 배지). 렌더는 전부
`elixir_of_mastery_cinematic_draw.gd`의 `_draw_result` 이하 절차 드로우.

| # | 결함 | 근거 |
|---|------|------|
| C1 | 방사광선 12줄이 `draw_line` 버트 캡 균일 방사 = 반려된 "별표" 클래스. 빌드업 부적 링 직후라 대비가 가장 큼 | `_draw_radial_rays` |
| C2 | 극성 배지가 플랫 노란 원 + 텍스트 → 디버그 배지 인상, 아이콘 프레임 우측과 어정쩡하게 겹침(cx+95 고정 앵커) | `_draw_level5_badge` |
| C3 | 콘페티 140개가 플랫 사각형 → 78% 암전 위에서 축하 꽃가루가 아니라 깨진 픽셀/노이즈로 오독(라이브 스크린샷 확인) | `_draw_confetti` |
| C4 | 아이콘 프레임이 사각 rect 3겹 외곽선 + 하드엣지 원 글로우 = placeholder급 | `_draw_result` 프레임/글로우 블록 |
| C5 | (보조) 폭죽이 원 2겹 점 — C1~C4 해소 후 재평가, 이번 슬라이스 교체 대상 아님 | `_draw_fireworks` |

유지(정상 판정): 배너 "극성 도달!" 스테이징·카피, "N성 → 극성" 전환 텍스트,
공용 무공 아이콘 연동(TAB/카드 정체성 일치 — 절대 훼손 금지), 쇼크웨이브
draw_arc 확산(순간 이펙트라 절차 유지 가능), 플래시, Space/Click 안내.

### 7.2 신규 3피스 + 재사용 2종

에셋 폴더·네이밍·마스터 보존(`_source`/`_alpha`)·해상도 규칙은 §2와 동일.

**N1. 방사광선 버스트 텍스처 1장** (C1 해소)
- `daeseong_glory_rays_imagegen_v1.png` — 중심에서 뻗는 금빛 광선 부챗살.
  길이·폭 불균일(수작업 후광 느낌), 중심부는 투명(아이콘 프레임 자리),
  끝단은 부드러운 페이드. 소스 1024², 런타임 512².
- 런타임: 현행 `rays_rotation`(42°/s) 재사용해 통째 회전, 알파는 셀레브레이션
  진입 페이드인. 필요 시 같은 텍스처를 역방향 저알파로 한 장 더 겹쳐 깊이.
- 프롬프트 초안:

  > Radiant golden glory rays bursting outward from an empty transparent
  > center, uneven hand-painted ray lengths and widths, warm gold
  > (#ED9C1F to #FFD138) fading softly at the tips, subtle crimson
  > (#D6290F) accent rays interleaved, flat 2D game VFX asset, fully
  > transparent background and center hole, generous margin, symmetrical
  > enough to rotate seamlessly.

**N2. 아이콘 인장 프레임 1장** (C4 해소)
- `daeseong_icon_seal_frame_imagegen_v1.png` — 무공 아이콘(82px)을 감싸는
  금장 장식 프레임. 사각 기반 + 모서리 여의두/운문 장식, 프레임 뒤 은은한
  발광 포함. 소스 1024², 런타임 256².
- 현행 rect 3겹 + 하드엣지 원 글로우를 대체. 아이콘은 프레임 위에 현행
  그대로 draw(공용 렌더러 경로 불변).
- `mythic_icon_backdrop` (`effects/mythic_acquisition/`) 선례 참고 — 단
  대성영단 금+단사 팔레트로 차별화.

**N3. 극성 인장 배지 1장** (C2 해소)
- `daeseong_geukseong_seal_imagegen_v1.png` — 붉은 전각 낙관(도장) 스타일
  인장. 문양만 아트로, "극성" 글자는 런타임 텍스트 유지(다국어 대응 —
  `format_mugong_level` 경로 불변). 소스 1024², 런타임 128².
- **배치 재설계 포함**: 현행 cx+95 고정 앵커가 프레임과 겹침 — 프레임
  우상단 모서리에 도장 찍힌 구도(프레임 rect 기준 상대 앵커)로 이동,
  `level5_impact_scale` 임팩트 스케일은 유지.
- 프롬프트 초안:

  > A traditional East-Asian red seal stamp (낙관) impression, square
  > carved-relief border with an ornate abstract martial emblem inside,
  > deep crimson (#B8140A) ink with slightly rough stamped edges, flat 2D
  > game UI badge asset, fully transparent background, generous margin.

**재사용 R1. 콘페티 → 금빛 불티/꽃잎** (C3 해소)
- 신규 대형 텍스처 대신 **소형 조각 텍스처 1장**(금박 조각 3~4개가 한 시트에
  들어간 미니 아틀라스, 소스 512² → 런타임 128²)으로
  `daeseong_confetti_flakes_imagegen_v1.png` 생성. 런타임은 현행 콘페티
  물리(중력·드래그·140개)를 유지하고 draw만 사각형 → 조각 텍스처 회전
  draw로 교체. 색은 금·단사 2계열로 제한(현행 무채색 혼입 제거).
- 140개 x 텍스처 draw는 즉시 드로우 예산 내(빌드업 입자 60개와 동급 규모,
  프레임당 1회). 성능 씰은 기존 오버레이 성능 스모크 재실행으로 갈음.

**재사용 R2. 대성진 링 + 글로우 백플레이트 저알파 배경**
- 셀레브레이션 배경에 슬라이스 1의 `daeseong_rune_ring_outer`를 저알파
  (~0.16) 저속 회전으로 깔아 의식의 연속성 부여. 추가 에셋 0장.
- **§6 P2 글로우 웜 톤 v2를 이 슬라이스에 편입**: 글로우 백플레이트만
  청색 채널 상향(코어 앵커 `#FFED8F`, B=143 계열)으로 재생성해 빌드업·
  셀레브레이션 양쪽에서 교체. 에셋 라운드를 한 번으로 합친다.

### 7.3 배선 지시 (Codex)

- 텍스처 스펙: `BUILDUP_TEXTURE_SPECS`와 같은 형태로 신규 키를 스펙
  테이블에 추가(별도 `RESULT_*` 테이블로 나누든 통합하든 프리웜 스텝이
  자동 확장되는 쪽으로). 준비 게이트는 **결과 화면 세트 별도**
  (`is_textured_result_ready()` 류) — 부분 세트면 해당 화면만 절차 폴백,
  빌드업 게이트와 독립.
- 레이어 순서 (아래→위): 암전 → 대성진 링 저알파(R2) → 쇼크웨이브(절차
  유지) → 방사광선 N1(회전) → 아이콘 발광(글로우 v2 재사용) → 인장 프레임
  N2 → 무공 아이콘(공용 렌더러, 불변) → 극성 인장 N3+텍스트 → 폭죽(절차
  유지) → 콘페티 R1 → 배너 → 안내 텍스트 → 플래시.
- §3의 트랩 목록 전부 동일 적용(재-stat 금지·프리웜 이산 시점·imported
  폴백·IDENTITY 복원·material 스왑 금지). 추가 1건: 콘페티 조각 draw가
  개별 `draw_set_transform` 회전을 쓰면 **루프 종료 후 IDENTITY 복원 1회**
  가 아니라 다음 드로우 전 복원이 보장되는 구조로.
- 스모크 확장: `daeseong_yeongdan_cinematic_visual_smoke.gd`의
  `expected_keys` 목록에 신규 키 추가(스펙 검증 루프는 자동 커버), 결과
  화면 textured/폴백 draw 레그 추가, `_verify_hot_path_source_contract`의
  대상 슬라이스에 `_draw_result` 구간 포함.
- 캡처 도구는 이미 `daeseong_yeongdan_peak_result.png`를 찍는다 —
  before를 백업한 뒤 after와 픽셀 대조.

### 7.4 수용 게이트

1. peak_result 캡처 before/after — 강한 임계 픽셀 판정: 방사광선 대역
   (프레임 밖 반경 80~240px) lit 카운트 상승, 배지 영역 적색 채도 카운트.
2. 콘페티: 무채색(회색 계열) 조각 픽셀 0 확인(금·단사 2계열 제한 검증).
3. 스모크(확장분 포함) 표준 러너 GREEN + 기존 63종 회귀 GREEN.
4. 오버레이 성능 스모크 재실행(콘페티 텍스처화 비용 확인).
5. Claude 아트 재검수: 별표 인상 소멸 / 배지가 도장으로 읽힘 / 콘페티가
   축하로 읽힘 / 프레임-배지 겹침 해소 / 아이콘 정체성 불변 / 환격전 톤
   (글로우 v2 웜 톤 포함).

### 7.5 스코프 아웃

- 폭죽 절차 드로우(C5) — C1~C4 반영 후 재평가.
- 타이틀 폰트 결 — 별건 백로그 유지.
- REVEAL 플래시·쇼크웨이브 — 현행 유지.

### 7.6 재검수 결과 (2026-08-05, Claude) — **APPROVE**

구현: 내장 ImageGen 5피스(방사광선·금장 프레임·극성 낙관·콘페티 조각 2x2·
글로우 웜 톤 v2) + 결과 화면 전용 6레이어 프리웜/게이트 (Codex). 재검수는
peak_result before/after + production-icon QA 캡처 픽셀 대조, 전 배선 코드
직독, 시각 스모크·오버레이 성능 스모크 표준 러너 독립 재실행(GREEN)으로 수행.

§7.4 게이트 판정: 전부 통과. C1(별표)·C2(디버그 배지+겹침)·C3(콘페티
노이즈)·C4(placeholder 프레임) 해소 확인. 픽셀 수치(광선 대역 6,665→27,378,
배지 적색 503→2,898)는 캡처 육안 대조와 부합. **글로우 v2 웜 톤 실측
확인**(중심 R255 G232 B200 → 외곽 R246 G174 B39 — §6 P2 황록빛 해소).
production QA 캡처에서 공용 무공 아이콘(순환결) 정체성 불변 확인.

배선 트랩 준수: RESULT_TEXTURE_SPECS 6키가 결과-로컬 캐시 키로 분리돼
부분 세트 시 결과 화면만 폴백(빌드업 게이트 독립), 통합 스텝 프리웜 10스펙,
콘페티 조각별 즉시 IDENTITY 복원, `draw_texture_rect_region` 픽셀 rect
정합(API 올바름), 핫패스 소스 계약이 `_draw_result` 구간까지 확장, 배지는
frame_rect 상대 앵커. 스모크는 아틀라스 4분면 가시성 + 회색 픽셀 0 +
글로우 웜 톤까지 에셋 픽셀 단언 포함 — 공허-GREEN 방지 충실.

P3 메모(비차단): 축하 피크에서 "[ Space / Click 으로 계속 ]" 안내가
광선·콘페티에 묻혀 저대비 — 라이브 블링크로 완화되므로 관찰만.

잔여: 슬라이스 1+2 구현부 헝크 분리 커밋, 라이브 인게임 1판 QA(빌드업→
극성 도달 전체 사이클 + 발동 프레임 히치).
