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

## 5. 카피/락업 — 사용자 확정 대기

| 항목 | 후보 | 상태 |
|---|---|---|
| 타이틀 락업 | A 한글 전면(+한자 낙관) / B 한자 전면(+한글 부제) | 대기 (v1=A 시각화) |
| 시작 프롬프트 | "아무 키나 눌러 귀문을 연다" / 입력중립 "문을 두드려 귀문을 연다" 등 | 대기 — 모바일 touch-accept 고려 |
| 부적 문구 2종 | 미정 | 대기 |

## 6. 통합 슬라이스 개요 (아트 확정 후 별도 슬라이스)

현행 기계 장치 기준 교체 비용 목록 — 드롭인 아님:

- `lingpia_main_menu_bg_logo.png` 교체 = 새 플레이트+락업 **재베이크**.
- `main_menu_scene` AmbientLayer의 글자 글린트 알파 마스크·오브 이펙트
  마스크 재생성(보라 오브 글로우 → 문틈 청색 빛기둥 펄스로 이식).
- `main_menu_flow_smoke`의 **픽셀 좌표 씰**(_is_logo_letter_source_pixel 등)
  재튜닝 필수 — 좌표가 구 로고 기준 하드코딩.
- 시작 전환 연출: 줌+덕킹 → "문이 열리는" 연출로 교체 검토(빛기둥 확산).
- 시작 프롬프트 카피 교체 시: "TOUCH TO START" 씰 갱신 + 7로케일 등재.
- 메뉴 BGM(조선의 달북 1악장)과 무드 정합은 확인 완료 — 달·북·야경 일치.

## 7. QA 체크리스트

- [ ] 스토어 캡슐 축소(460px)에서 타이틀·귀면·빛기둥 판독
- [ ] 다크/라이트 환경 모니터에서 하단 안개 계조 뭉개짐 확인
- [ ] 배너·낙관의 한글/한자가 실제 유효 문자인지(레이어 합성 검증)
- [ ] 1920×1080 크롭 후 달·석등 절단 여부
- [ ] 기존 메뉴 버튼 스택 영역(하단 중앙)과 명도 충돌 여부
