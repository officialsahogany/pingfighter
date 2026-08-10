# 전환 퍽 아이콘 리드로우 코덱스 핸드오프 (아트 디렉션)

발주: 2026-07-07. **Claude = 아트 디렉션/프롬프트/적대 리뷰, Codex = imagegen 생성
+ 배선 + QA** ([Skill VFX Tool Boundary](skill_vfx_workflow.md#tool-boundary) 분담).
선행: 패시브→퍽 개편 C 커밋
(`08cb116e9`) 완료 — 전환 퍽 37종이 인게임에 뜨지만 **전부 절차적 폴백(색 원)**.
대표 결정: **전량 imagegen 리페인트**(재사용 아님).

라우팅: 아이콘 비주얼 = `.claude/skills/item-generation/`(또는 Codex 미러),
애니메이션 시트 = `.claude/skills/sprite-generation/`(AutoSprite MCP 필수).
퍽 아이콘 런타임 규칙 = CLAUDE.md "Legacy Python Perk Icon Rendering" +
"Instant-trigger perk icon animation rule". imagegen 소스 = Gemini(비-시트),
AutoSprite(시트) — repo 규칙 준수.

## 목표

전환 퍽 37종(일반 26 + 신화 11)을 **퍽 라운드/오브 패밀리 스타일**의 폴리시된
아이콘으로 새로 그리고 런타임 배선한다. 신화 11종은 **살아 움직이는 8프레임
애니메이션 시트**(차원개방/풀게이징 계열).

## 합격 조건

1. 37종 전부 `runtime_perk_icon_renderer.gd`의 `PERK_ICON_PATHS`(및 신화는 시트
   경로)에 등록되어 절차폴백이 아닌 **실제 아이콘**으로 렌더.
2. 퍽 오퍼 카드 / TAB 정보창 / 32px 소셀 그리드 3곳에서 읽기 양호,
   `Lv.` 라벨 안 가림.
3. 신화 11종은 카드 안에서 애니메이션 재생(시트 우선 → 정적 폴백 → 절차).
4. 기존 퍽 아이콘(경량화·신속·차원개방 등)들과 **같은 패밀리 스타일** — 이질감
   없음.

## 비주얼 패밀리 규칙 (핵심)

- **퍽 라운드/오브 스타일**: 아이템 아트("아이템이 배경 위에")가 아니라 기존
  퍽 아이콘 언어(원형/오브 프레임, 발광, 상징 모티프). 레퍼런스 = TAB
  `dash_module_control`(모듈제어) 소셀 크기/충만도. "폴리시되고 자신있게
  채워지되 하단 레벨 라벨은 안 가림"이 목표.
- **정체성 소스 = 기존 아이템 아트**: 각 퍽의 "무엇을 그리는가"는 대응 아이템
  PNG(`assets/sprites/items/<id>.png`)가 이미 인코딩하고 있다. 그 주제(subject)를
  퍽 패밀리 스타일로 **재해석**하라 — 아이템 아트를 그대로 복사하지 말고, 그
  아이덴티티를 퍽 오브 언어로 다시 그린다.
- **가족 분류**(CLAUDE.md 아이콘 패밀리 규칙): 캐릭터 전용/언락 퍽 = 라운드·오브
  언어 / 기본 공용 퍽 = 자유 실루엣 가능. 전환 퍽은 대부분 아이템 유래라 오브
  프레임 + 상징 모티프 조합을 기본으로.
- 팔레트: 각 퍽의 `icon_color`(catalog CONVERTED_PERKS/MYTHIC에 지정됨)를 주조색
  앵커로.

## 일반 퍽 26종 — 정적 아이콘 (모티프 표)

각 항목: perk_id | 한글명 | 비주얼 모티프(아이템 아이덴티티 → 퍽 오브 재해석).

| perk_id | 한글명 | 모티프 |
|---|---|---|
| star_detector | 별탐지기 | 별 + 탐지 레이더/스캐너 펄스 |
| adversity_armor | 역경의힘 | 무적벽/방패 오라 |
| reinforced_boomerang_gauntlet | 부메랑장인 | 메탈 부메랑 + 강화 장갑 |
| sensor | 위험감지센서 | 위험 감지 레이더 펄스(자동대쉬 토큰) |
| gravitybelt | 무중력화 | 무중력 부양 벨트/입자 |
| dowsing_pendulum | 다우징 | 진자 + 자력 끌림선 |
| chargebag | 충전가방 | 게이지 충전 가방/전하 |
| battery | 배터리팩 | 배터리 셀 + 잔량 |
| revival | 윤회 | 윤회 고리/부적 |
| master | 벽돌장인 | 수리 망치 + 벽돌 |
| gold_digger | 골드디거 | 곡괭이 + 골드 광맥 |
| lucky_coin | 럭키코인 | 행운 코인 + 클로버/광 |
| shrapnel_armor | 파편사출 | 가시 파편 사출 갑옷 |
| fuel_pouch | 연료탱크 | 연료 파우치/게이지 확장 |
| bluetooth_ring | 블루투스링 | 반지 + 신호 파동 |
| foul_whistle | 반칙호루라기 | 호루라기 + 판정 무효 |
| smartphone | 오토파일럿 | 스마트폰 + 자동 조준 UI |
| neural_helmet | 뉴럴링크 | 헬멧 + 뇌파/AI 링크 |
| commando_arm | 투척병기 | 전투 팔/투척 궤적 |
| rainbow_fur_glove | 무지개장갑 | 무지개 털장갑 + 쿨감 스파크 |
| knee_pads | 킥차져 | 무릎 보호대 + 충전 |
| soul_burst | 소울버스트 | 영혼 폭발/풀대쉬 오라 |
| bulletproof_hat | 스턴저항 | 방탄모자 + 스턴 차단 |
| spiked_helmet | 넉백저항 | 가시투구 + 버팀 |
| venom_mist_gauntlet | 독안개 | 독 건틀릿 + 안개(바이퍼 전용 틴트) |
| speedgear | 보정제어 | 보정 벨트/기어 + 방향 화살 |

## 신화 퍽 11종 — 8프레임 애니메이션 시트 (모션 표)

"반짝이는 아이템"이 아니라 **카드 안에서 에너지/룬/차원문/후광이 살아 움직이는**
차원개방·풀게이징 계열. **포맷 = 가로 스트립의 정사각 프레임 8개(8:1 비율)** —
렌더러가 `width/height`로 프레임 수를 자동 감지하고 ~110ms/프레임으로 재생하므로
정사각 프레임을 옆으로 나열하면 그대로 동작(신규 코드 불필요). 프레임 8→1 루프
연속성, 넉넉한 투명 여백(글로우가 셀 가장자리 안 닿게). 정적 대표 프레임(폴백)도
함께 보관.

| perk_id | 한글명 | 모션 |
|---|---|---|
| pandora_legacy | 판도라의 유산 | 보라 균열이 열렸다 닫히는 상자 |
| transcendent_crown | 초월자의 관 | 왕관 뒤 금빛 원환 회전 |
| odins_eye | 오딘의 눈 | 눈동자 + 예언 룬 깜빡임 |
| heavenly_cape | 천상의 권능 | 망토 주변 별먼지 흐름 |
| baal_boots | 바알의 계약 | 부츠로 날씨 입자가 빨려 들어감 |
| megingjord | 메긴교르드 | 힘의 벨트 룬 발광 맥동 |
| ragnarok_hammer | 라그나로크 | 망치 + 전기 스파크/번개 룬 |
| hermes_shoes | 헤르메스의 축복 | 날개 신발 + 스피드 라인 흐름 |
| poseidon_trident | 포세이돈 | 삼지창 + 물 소용돌이 |
| horn_strawberry_mask | 뿔딸기의 계약 | 가면 + 변신 에너지 맥동 |
| celestial_armor | 부동갑주 | 갑주 + 천구 오라 회전 |

(참고: 신화 아이템 시절 `assets/sprites/items/<id>_icon_sheet.png`가 이미 존재 —
아이덴티티 레퍼런스로 활용 가능하나, 아이템 스타일이므로 퍽 패밀리 오브 언어로
재해석. 프레임 수/레이아웃이 8프레임 가로와 다르면 재생성.)

## 생성 소스 (repo 규칙)

- 정적 아이콘(일반 26 + 신화 정적 폴백): **Gemini imagegen**(비-시트). FLUX 금지.
- 애니메이션 시트(신화 11): **AutoSprite MCP 필수**(animated 퍽/item 시트 규칙).
  Gemini는 컨셉/프롬프트 분석·정적 폴백만.
- Claude(발주자)가 프롬프트 워딩·팔레트·실루엣·alpha/nukki 시각 리뷰를 담당하니,
  후보 생성 후 **정체성/패밀리 일관성 리뷰를 요청**할 것.

## 런타임 배선

1. `runtime_perk_icon_renderer.gd` `PERK_ICON_PATHS`에 일반 26종 정적 PNG 경로 등록
   (`assets/sprites/perks/<perk_id>_perk_icon.png` 관례).
2. 신화 11종: **`PERK_SHEET_PATHS` 맵**에 시트 경로
   (`assets/sprites/perks/<perk_id>_perk_icon_sheet.png`) + `PERK_ICON_PATHS`에
   정적 폴백 PNG. 렌더러는 이미 **시트 → 정적 PNG → 절차 폴백** 우선순위 구현됨
   (instant_gauge_full/instant_dimension_gate가 `PERK_SHEET_PATHS` 사용하는 동일
   패턴 — 프레임 슬라이스/캐시 로직 재사용). 신규 아키텍처 불필요, 맵 등록만.
3. 소스 캐시: 큰 PNG/시트는 디코드 소스를 스케일 출력과 분리 캐시(핫패스 재로드
   금지). 시트는 1회 슬라이스 + `(size, active, frame)` 캐시.
4. 별칭 감사: 전환 퍽 id는 아이템 id와 동일 — 오퍼/HUD/TAB 경로가 모두 같은
   PNG를 히트하는지 확인.

## QA (사인오프)

- 최소 실셀 크기(32px TAB 그리드, `dash_module_control` 레퍼런스)에서 주제 충만도
  + `Lv.1`/`Lv.5` 라벨 미가림.
- alpha 코너 투명 + alpha bbox 비-가장자리 + 다운스케일 후 사각/다크 프린지 없음.
- 신화 시트: 8프레임 루프 연속성, 카드 안 애니 재생, 정적 폴백 정상.
- 인게임 3곳(퍽 오퍼 카드 / TAB 퍽 그리드 / 소셀) 실렌더 스크린샷 리뷰.
- 헤드리스 로드 체크 + 워닝 스캔 + 리소스 import.

## 배치 권장

- **배치 1 = 신화 11종 애니메이션**(가장 distinctive·대표 관심사, "wow" 효과 먼저).
- **배치 2 = 일반 26종 정적**.
- 각 배치 후 Claude 적대 리뷰(패밀리 일관성·소셀 읽기·alpha·런타임 우선순위).

## 완료 보고 형식

(1) 생성/배선 파일 목록, (2) PERK_ICON_PATHS 등록 + 시트 우선순위 배선 확인,
(3) 생성 소스(Gemini/AutoSprite) 및 프레임 규격, (4) 3곳 실렌더 스크린샷/리뷰,
(5) alpha·소셀·Lv 라벨 QA, (6) 헤드리스/워닝, (7) 미해결/이탈.
