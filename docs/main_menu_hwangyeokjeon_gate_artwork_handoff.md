# 환격전 메인메뉴 "귀문(鬼門)" 키아트 리터치 인계 (2026-07-21)

메인메뉴 배경 아트워크 리뉴얼 방향 패키지. 사용자가 승인한 귀문 목업의
무드를 유지하면서 "한국 신화무협" 정체성을 강화하는 리터치 라운드용.
아트 디렉션 = Claude, 최종 생성·후처리·배선 = Codex/후속 슬라이스.

## 0. 소스 앵커

| 파일 | 역할 |
|---|---|
| (사용자 보유 원본 목업 — 채팅 첨부본) | 무드 정본. `docs/references/main_menu_hwangyeokjeon_gate_mockup_v1.png`로 저장 필요(**미배치**, 사용자 보유) |
| `docs/references/main_menu_hwangyeokjeon_gate_concept_hangul_v1.jpg` | 한글 전면 락업 + 한국화 디테일 검증용 컨셉 드래프트 v1 (Gemini 1K 16:9). 배치 완료 |

무드 차이: 원본 목업이 더 어둡고 안개가 무겁다(신비/위압). 드래프트 v1은
더 밝고 포스터풍(가독 우위). 최종은 목업의 안개·어둠으로 다이얼을 되돌리되
타이틀 림라이트만 v1 수준을 유지하는 절충이 기본안.

## 1. 유지 잠금 (목업에서 확정된 것)

- 구도: 상단 좌측 달 / 중앙 거대 귀문 / 문틈 세로 청백 빛기둥 / 좌우 석등 /
  하늘의 거대 부적 원진(파이언트 만다라) / 하단 안개 바다.
- 서사: "시작 = 귀문이 열린다". 문틈 빛기둥이 시작 프롬프트의 시선 앵커.
- 팔레트: 심야 인디고 + 금 + 시안 악센트. 석등만 난색 촛불.
- 중앙 귀면 문고리(캐릭터 선택 UI 크롬의 귀면 크라운과 연속성).

## 2. 리터치 지시 (R1~R5)

- **R1 타이틀 락업 — 한글 전면(안 A, 기본 추천)**: 붓글씨 한글 "환격전"을
  주 타이틀로(금·균열 석질감 + 월광 림라이트), 한자 幻擊戰은 옆의 작은
  붉은 낙관(전각 도장)으로 격하. 안 B = 현행 한자 전면 유지 + 림라이트만
  보강. **사용자 확정 필요.**
- **R2 배너 한국화**: 문짝 세로 배너를 한글 붓글씨 부적(붉은 낙관 포함)으로.
  ⚠️ AI 글리프는 컨셉 전용 — v1 드래프트의 "부제목" 같은 무의미 문자열이
  나온다. **최종본 배너 문자는 텍스트 레이어로 별도 합성**(§3).
- **R3 건축 한국화**: 처마 밑 단청(녹·적·청 기하 문양), 조선 기와 곡선 마루,
  석등은 한국 석등 실루엣으로. 중화풍 사원 실루엣 금지.
- **R4 가독성**: 타이틀 명도 분리 — 림라이트/월광 백라이트 강화. 스토어
  캡슐 축소(가로 ~460px)에서 타이틀·귀면·빛기둥 3요소가 살아남아야 함.
- **R5 무드 다이얼**: v1 대비 안개 +2, 전체 명도 -1(목업 기준으로 회귀).
  빛기둥과 타이틀만 대비 유지.

## 3. 제작 규칙 — 텍스트 없는 플레이트 + 레이어 합성

최종 납품은 **3레이어**로 분리한다(현행 메뉴가 로고 베이크드 PNG + 글자
알파 마스크 구조이므로, 결정론 베이크가 가능해야 함):

1. **배경 플레이트(텍스트 전무)**: 타이틀·배너 문자·하단 카피 모두 없는
   순수 배경. 생성 프롬프트에 "no text, no lettering" 명시.
2. **타이틀 락업 레이어**: 한글 "환격전" 서예 로고(투명 PNG). 서체 기반
   제작 또는 생성 후 누끼 — AI 한글 글리프 오염 방지가 목적.
3. **배너 문자 레이어**: 실제 의미 있는 한글 부적 문구 2종(예: 좌 "귀문
   봉인" / 우 "파마항요" 계열 — 문구는 사용자 확정). 붓글씨 텍스처 합성.

해상도: 1536×864(장변 1536, Gemini 세션 트랩 준수) 생성 → Real-ESRGAN
x2(`realesr-animevideov3`, 체크리스트 §0.1 게이트) → 1920×1080 다운스케일.
드래프트 반복은 1K 유지.

## 4. 복붙 프롬프트

### 4.1 배경 플레이트(텍스트 없음) — 기본안(A 락업용 상단 여백 확보)

```
Dark fantasy Korean mythology game title screen background, night scene, NO TEXT anywhere.
Deep indigo storm clouds around a colossal ancient KOREAN palace gate (Joseon dynasty style)
floating in a sea of thick fog. Aged dark wood double doors with bronze stud rows, a giant
fierce bronze GWIMYEON (Korean dokkaebi goblin-mask) door knocker at center, gold filigree
wheel ornaments. A blinding vertical seam of blue-white spirit light leaks between the door
panels, spilling glowing particles into heavy mist. Under the curved eaves: traditional Korean
DANCHEONG painted patterns, Joseon giwa roof tiles with curved ridge. Two BLANK vertical
paper talisman banners hang on the door panels (no writing). Two Korean stone lanterns
(seokdeung) flank the gate in fog, warm candlelight. Full moon glowing through clouds
upper-left, faint giant talisman circle etched in the sky top-center. Upper third kept
relatively calm/dark for a title overlay. Heavy atmospheric fog, ominous and majestic,
painterly intricate detail. Gold + indigo palette with cyan accent light.
```

### 4.2 컨셉 반복용(문자 포함 시안 — 판단 전용)

v1 드래프트에 쓴 프롬프트(한글 타이틀+부적 문자 포함)는
`docs/references/main_menu_hwangyeokjeon_gate_concept_hangul_v1.jpg` 생성분과
동일 계열. 락업 비교 시안이 더 필요할 때만 사용, 산출물은 참조 전용.

## 5. 카피/락업 — 사용자 확정 (2026-07-21)

| 항목 | 후보 | 상태 |
|---|---|---|
| 플레이트 | 안개 강화형 | **확정** |
| 타이틀 락업 | A 한글 `환격전` 전면 + 한자 `幻擊戰` 낙관 | **확정** |
| 시작 프롬프트 | `문을 두드려 귀문을 연다`(탭/키 입력중립) | **확정** |
| 부적 문구 2종 | (좌)`귀문봉인` / (우)`벽사진경`(辟邪進慶) | **확정** |

확정값:
플레이트=안개강화형 / 락업=A / 카피="문을 두드려 귀문을 연다" /
부적=(좌)귀문봉인·(우)벽사진경. 이 값으로 합성·베이크·런타임 통합을 진행한다.

## 6. 통합 슬라이스 개요

현행 기계 장치 기준 교체 비용 목록 — 드롭인 아님:

- [x] `lingpia_main_menu_bg_logo.png`를 안개 강화형 플레이트+확정 락업으로 재베이크.
- [x] 글자 글린트 알파 마스크와 문틈 청백광 마스크를 오프라인 재생성.
- [x] `main_menu_flow_smoke` 픽셀 좌표 씰을 새 락업·문틈 기준으로 재튜닝.
- [x] 시작 줌 연출을 중앙 문틈 확산형 귀문 열림 전환으로 교체.
- [x] 시작 카피를 7로케일에 등재하고 런타임 언어 갱신 경로에 연결.
- 메뉴 BGM(조선의 달북 1악장)과 무드 정합은 확인 완료 — 달·북·야경 일치.

## 7. QA 체크리스트

- [x] 스토어 캡슐 축소(460px)에서 타이틀·귀면·빛기둥 판독
- [ ] 다크/라이트 환경 모니터에서 하단 안개 계조 뭉개짐 확인
- [x] 배너·낙관의 한글/한자가 실제 유효 문자인지(결정적 레이어 합성·매니페스트 검증)
- [x] 1920×1080 크롭 후 달·석등 절단 여부
- [x] 기존 메뉴 버튼 스택 영역(하단 중앙)과 명도 충돌 여부

## 8. Codex 텍스트리스 플레이트 생성 라운드 (2026-07-21)

### 8.1 후보

| 후보 | 원본 생성본 | Real-ESRGAN 후 1920×1080 | 판단 |
|---|---|---|---|
| 균형형 | `docs/references/main_menu_hwangyeokjeon_gate_plate_balanced_imagegen_v1_source_1672.png` | `docs/references/main_menu_hwangyeokjeon_gate_plate_balanced_imagegen_v1_1920.png` | 문짝·금속 장식 판독 우위. 안전한 비교 기준 |
| 안개 강화형 | `docs/references/main_menu_hwangyeokjeon_gate_plate_heavy_fog_imagegen_v1_source_1672.png` | `docs/references/main_menu_hwangyeokjeon_gate_plate_heavy_fog_imagegen_v1_1920.png` | R5의 안개·위압감 우위. 아트 디렉션 1순위 후보 |

두 후보 중 안개 강화형이 §5에서 최종 확정됐으며, 균형형은 비교 기준과 폴백으로
보존한다.

### 8.2 생성·후처리 기록

- 도구: Codex 내장 `imagegen` 편집 경로. 입력 앵커는
  `main_menu_hwangyeokjeon_gate_concept_hangul_v1.jpg`.
- 균형형 프롬프트: §4.1을 기본으로, 기존 구도를 잠그고 상단 금색 타이틀·붉은
  낙관·양쪽 배너 글리프를 제거했다. 배너는 낡은 **빈 종이**로 유지하고, v1보다
  안개를 늘리고 전체 명도를 낮추되 문틈 청백 빛과 석등 촛불 대비는 보존했다.
- 문자 오염 정리 프롬프트: 상단 원진에서 글자·숫자·룬·낙관처럼 읽히는 표식을
  전부 제거하고 비의미적 동심원·호·방사형 직선만 남겼다. 나머지 구도와 조명은
  변경 금지로 잠갔다.
- 안개 강화형 프롬프트: 균형형을 입력으로 사용해 하단 1/4과 문짝 하부·석등
  기단 주변의 체적 안개만 강화했다. 객체·구도·텍스트리스 조건은 그대로 잠갔다.
- 내장 도구 원본은 1672×941 RGB PNG로 산출되었다. 이를 리포 로컬
  `tools/realesrgan/realesrgan-ncnn-vulkan.exe`와
  `realesr-animevideov3 -s 2`로 3344×1882까지 실제 업스케일한 다음,
  Lanczos로 1920×1080 RGB PNG에 다운스케일했다. 재현 가능한 x2 중간 파일은
  최종 납품 목록에서 제외한다.

### 8.3 플레이트 범위 QA

- [x] 최종 후보 2종 모두 1920×1080 RGB PNG.
- [x] 상단 타이틀·낙관·배너 문자 없음. 배너는 빈 종이이며 원진은 비문자 기하선만 사용.
- [x] 460×259 축소 육안 QA에서 귀면·문틈 빛기둥·달·양쪽 석등 판독.
- [x] 1920×1080에서 달과 양쪽 석등이 프레임 안에 유지됨.
- [x] 타이틀 판독·배너 유효 문구·시작 카피를 §5 확정 합성본에서 QA.
- [x] 하단 버튼 스택 명도 충돌·글린트/문틈 마스크·전환 연출을 통합 슬라이스에서 QA.
- [ ] 원본 목업 정본은 아직 `docs/references/main_menu_hwangyeokjeon_gate_mockup_v1.png`에 미배치. 배치 후 최종 무드 대조 필요.

### 8.4 폴리시 라운드 R6 (2026-07-21 실행 완료, felt QA 대기)

배경 방향은 유지. 어색함의 근원은 아트워크가 아니라 락업·하단 UI라는
진단에 합의. 우선순위 순:

- **R6-1 타이틀 락업 v2 (헤드라인)**: 15~20% 축소, 두꺼운 라운드 외곽선
  제거, 낙관 높이 -25%. **디렉션 앵커 2종 배치 완료**:
  - `docs/references/main_menu_hwangyeokjeon_lockup_concept_ink_v1.jpg`
    (A 먹 번짐 붓글씨 + 월광 은빛 백라이트)
  - `docs/references/main_menu_hwangyeokjeon_lockup_concept_goldleaf_v1.jpg`
    (B 낡은 금박 — 태니시·헤어라인 크랙·패티나, 각진 붓글씨 골격)
  **아트 디렉션 1순위 = B(낡은 금박)**: 씬의 금동 문고리·단청·석등 금
  악센트와 동계열이라 조화 우위, 밝은 글자 전제인 글린트 마스크 기계와도
  호환(A의 검정 먹+은빛 글로우는 글린트 의미가 약해지고 하늘 원진과 글로우
  헤일로가 충돌 위험). A는 대안 보존. B가 씬에서 뻣뻣하면 A의 획 역동성 +
  B의 금박 질감 하이브리드를 v2 반복으로.
  베이커에서 폰트/질감 교체로 재현(각진 붓글씨 계열 폰트 — 리포 폰트 부재
  시 OFL 서예 폰트 도입+라이선스 기록) — 글린트 마스크 재생성 +
  `main_menu_flow_smoke` 픽셀 씰 재튜닝 동반 필수. 앵커의 하단 프레젠테이션
  문구·배경은 참조 전용(최종은 베이커 투명 레이어).
- **R6-2 하단 프롬프트 리본 교체**: 반투명 바 배경 알파 0으로 삭제, 텍스트
  는 현 런타임 Label 유지(은은한 부유) + 상하 1px 금동(#b08d57 계열)
  헤어라인과 중앙 소형 마름모 문양. 사이버펑크 인상 제거가 목적.
- **R6-3 문틈 광 유휴 연출**: 유휴 시 광 강도 ×0.80~0.85 + 사인 호흡
  (주기 ~3.5s, ±8%), 시작 입력 시 1.0 이상으로 증폭 램프 → 열림 전환으로
  연속. 일괄 감쇠 금지 — 시작 유도 앵커.
- **R6-4 안개 보강**: 화면 가장자리 비네트형 안개 + 문 하단 안개 +10%
  (베이커 플레이트 패스).
- **R6-5 배너 4자 온전 배치**: 귀문봉인·벽사진경 마지막 글자가 찢어진
  하단에 걸려 부분 절단 — 텍스트 블록 상향(4자 전부 온전한 종이 위).
- **R6-6 열림 전환 발광역 사각 클립 경계 페더링**: 가장자리 24~48px 페더
  (상단 수평 경계 노출 소거).

R6 검증 세트: 메뉴 스모크 9종 재실행 + 글린트/문틈 마스크 재생성 +
`main_menu_flow_smoke` 픽셀 좌표 재튜닝 + 픽셀 QA 3장(유휴/열림/460) 재캡처.

### 8.4b 리치니스 라운드 R7 (2026-07-21 사용자 레퍼런스 기반, 실행 대기)

사용자 제공 레퍼런스(무드 정본 v2 — `docs/references/
main_menu_hwangyeokjeon_gate_mockup_v2.png`로 저장 필요, **미배치·사용자
보유**)와 현행 R6 화면의 갭 4종을 닫는 라운드. 구도·귀면·석등·달·확정
카피("문을 두드려 귀문을 연다" — 레퍼런스의 "아무 키나"는 구 카피 잔재,
회귀 금지)는 잠금.

- **R7-1 플레이트 v3 대기 리치니스 (헤드라인)**: 다층 체적 구름 — 하단
  안개 바다 + 측면·지붕 뒤 구름벽 + 석등 주변 난색 광 풀. 문·배너 명도
  -1(환경에 묻힘, 배너 채도도 -1). 좌우 원경 탑·사찰 실루엣 다층 + 우측
  산봉 실루엣 추가. imagegen 편집: 현 heavy_fog 플레이트 입력 + 레퍼런스
  무드 앵커, 구도 잠금. 배너 위치/마스크/픽셀 씰 재튜닝 동반.
- **R7-2 타이틀 락업 v3**: 획 두께 약 -30%의 예리한 세필 서예 골격(금박
  질감 유지), 낙관 → 테두리 있는 진한 적갈 편액 플레이트(세로 幻擊戰).
- **R7-3 금 문양 프레임**: 화면 가장자리 얇은 금 테두리 + 모서리 장식
  (베이크 레이어). 460px 캡슐에서 프레임 생존 확인.
- **R7-4 카피 장식 보강**: 텍스트 좌우 대시 + 하단 소형 마름모 장식.
  ⚠️장식 글리프를 유니코드 문자(✦ U+2726 등)로 넣지 말 것 — CLAUDE.md
  한국어 폰트 tofu 트랩의 명시 사례. draw 프리미티브로 그린다.
- **R7-5 문틈 광 수직 그라디언트**: 상부 얇고 은은 → 귀면 부근 최대 →
  하부 확산. 현 균일 빔 교체(유휴 호흡·입력 증폭 R6-3 로직 위에 적용).

R7 검증 세트 = R6와 동일(스모크 9종 + 마스크 재생성 + flow_smoke 재튜닝 +
픽셀 3장) + 레퍼런스 대비 무드 대조 1장.

실행 체크포인트(2026-07-21):

- B `goldleaf_v1`을 정본으로 베이크. 폰트 크기 244→200(×0.82), 낙관 ×0.75,
  투명 레이어 실측 사용 영역 581×256. 17px 라운드 외곽선을 제거하고 5px
  산화 가장자리·금박 태니시·헤어라인 크랙·패티나로 교체했다.
- 배너 시작 y=423, 낙관 y=665로 올렸고, 플레이트에 가장자리 최대 알파 30,
  문 하단 최대 알파 26의 고정 시드 안개 패스를 추가했다.
- 하단 프롬프트는 배경 알파 0, `#b08d57` 1px 상하 헤어라인+중앙 마름모로
  교체. 문틈 광은 유휴 ×0.825, 3.5초 ±8% 호흡, 입력 램프 ×1.12로 봉인했다.
- 열림 발광역 상단과 좌우 문 그림자 경계를 36px 페더 처리했다. 1920 캡처
  기준 상단 경계 인접 최대 luma 점프 5.37, 좌측 경계 1px 점프 최대 3.28.
- 글린트 마스크는 610×280 / ON 63,997, 문틈 마스크는 220×780 / ON
  37,910으로 재생성. `main_menu_flow_smoke` 좌표 씰도 새 락업에 맞췄다.
- 재현 캡처:
  `docs/references/main_menu_hwangyeokjeon_r6_idle_1920.png`,
  `docs/references/main_menu_hwangyeokjeon_r6_opening_1920.png`,
  `docs/references/main_menu_hwangyeokjeon_r6_capsule_460.png`.

비채택 의견 기록: ①락업/배너 런타임 레이어화 — 카피는 이미 런타임 렌더,
락업 품질 문제는 질감/폰트로 해결(베이크 구조·마스크·씰 유지), 배너는
디제틱 오브젝트로 배경 소속 유지. ②카피 "아무 키나 눌러" 회귀 — 전시
부스·모바일 터치 맥락에서 키보드 전제 카피는 부적합, "문을 두드려" 확정
유지(재론은 사용자 결정만).

### 8.5 확정 합성·런타임 산출물

- `godot/tools/bake_main_menu_hwangyeokjeon_artwork.py`: 고정 시드와 정확한
  문자 상수로 배경·타이틀·부적 레이어를 재현하는 오프라인 베이커.
- `godot/assets/ui/main_menu/main_menu_hwangyeokjeon_title_lockup_a.png`:
  `환격전` 낡은 금박(태니시·헤어라인 크랙·패티나) 락업 + `幻擊戰` 축소
  적색 낙관 투명 레이어.
- `godot/assets/ui/main_menu/main_menu_hwangyeokjeon_banner_text_layer.png`:
  좌 `귀문봉인`, 우 `벽사진경` 투명 레이어.
- `godot/assets/ui/main_menu/main_menu_hwangyeokjeon_artwork_manifest.json`:
  플레이트 해시·폰트·시드·확정 문구·출력 파일 봉인.
- `godot/scripts/ui/main_menu_gate_transition_projection.gd`: 중앙 귀문 틈새에서
  청백광이 확산하고 마지막에 백색 전환으로 이어지는 순수 투영/엔벌로프 소유자.
- `godot/tools/main_menu_hwangyeokjeon_live_pixel_qa.gd`: 1920×1080 유휴/귀문
  열림 프레임과 460×259 축소본을 실제 창 렌더러에서 캡처하는 재현 QA 도구.
