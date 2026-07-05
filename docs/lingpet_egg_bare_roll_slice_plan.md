# 링펫알 — 받침 제거 + 맨 타원형 알 + 물리 구르기 슬라이스 (Codex 핸드오프)

단일 소스. `docs/lingpet_egg_color_neutralize_slice_plan.md`(받침+변종 5장 레이어 합성, 배선 완료)의
**후속 조정 슬라이스**다. 그 문서의 변종 시스템(RNG 인덱스·글로우 맵·save/load·스포 차단)은 전부
유지하고, **필드 비주얼만** 바꾼다.

배경(사용자 결정, 2026-07-03):
- 현재 필드 알은 받침(`resonance_egg_holder`)과 함께 통째로 미끄러져 "동상이 스케이트 타는" 느낌.
  물리는 이미 굴러다니는 물체(대쉬 넉백 13.5, 벽 반발 0.72)인데 비주얼만 설치물이다.
- **D1 (확정)**: 필드에서는 받침 제거. 받침 컨셉은 "상점 진열 전용 크롬"으로 보존
  (현재 유일 라이브 소비처 = 슬롯 아이콘 사전합성; 향후 광장 상점 진열 UI가 생기면 재사용).
- **알은 약간 타원형(실제 계란처럼)**으로 다시 그리고, 대쉬로 밀리면 **물리적으로 구르게** 한다
  (타원이므로 덜컹덜컹 출렁이며 구르는 계란 느낌).
- 에셋 생성 도구 = **Codex imagegen (사용자 명시 지정)**. 정적 스틸이므로 AutoSprite 요건(시트 전용)
  비대상. "비-시트=Gemini" 기존 메모리 규칙보다 이 사용자 지정이 우선한다.

분담: Claude = 이 스펙 + 아트 디렉션/수용 판정 + 적대 리뷰. **Codex = imagegen 생성 + 누끼 +
repo 배치 + 런타임 배선 + 스모크**.

---

## 0. 핵심 결정 요약

| # | 결정 | 상태 |
|---|---|---|
| D1 | 받침 = 필드 제거, 상점/아이콘 전용 크롬으로 보존 | 사용자 확정 |
| D2 | 맨 알 변종 5장 **신규 세트** 생성(중앙정렬·타원형). 기존 `resonance_egg_variant_*` + `holder`는 아이콘·향후 진열·롤백용으로 디스크 보존(참조만 정리) | 권장안 |
| D3 | 슬롯 아이콘 `resonance_egg_item_icon.png`(받침+crystal 합성)은 **현행 유지** — "진열" 컨셉과 일치 | 권장안 |
| D4 | 정지 시 알은 가장 가까운 직립 자세로 셋틀(오뚝이 락킹). 임의 각도(뾰족한 끝이 바닥) 정지 금지 | 권장안 |
| D5 | 코이그지스트(아이템) 알도 동일 비주얼 적용 — 두 알이 같은 `LingpetEggFieldState`/렌더러를 공유하므로 자동 | 권장안 |

---

## 0.5 후속 승인 변경 (2026-07-03, 사용자 명시 요청 — 별도 커밋 스코프 권장)

이 슬라이스 이후 사용자가 추가로 요청·승인한 변경들. **게임플레이 밸런스 변경(부화 난이도)은
시각/감각 폴리시와 커밋을 분리한다.**

### A. 알별 부화 난이도 1/2/3 랜덤 (게임플레이 밸런스 — 별도 커밋)
사용자 요청 원문: "어떤 알은 1번만 맞으면 바로 깨지고, 어떤 알은 2번(1번 맞으면 금), 어떤 알은
3번(맞을 때마다 금). **주니어리그 첫 알은 항상 1번**."
- `LingpetEggFieldState.HATCH_REQUIRED_HITS_POOL = [1,2,3]`, 스폰 1회 롤(`roll_required_hits`),
  0 = 미굴림 센티넬(색인덱스 -1과 동형) → 미굴림 시 카탈로그/profile fallback.
- 권위 = 알의 롤. 런타임 `_get_main_egg_required_hits()`/`_get_item_egg_required_hits()`가 알 롤 우선,
  profile은 fallback. 주니어(`is_auto_present_league`)만 `_spawn_egg`에서 `set_required_hits(1)` 강제.
- 크랙 비주얼은 기존 `hatch_hits` 단계 렌더 그대로 정합(2-hit=1금/3-hit=누적금).
- save/load 보존(reset 스냅샷 `required_hits=0` 센티넬), owner키 `lingpet_hatch_required_hits`는
  이미 `battle_scene_state.DEFAULT_VALUES` 선언됨.
- ⚠️ **회귀 주의(리뷰 P1)**: 카탈로그 required_hits는 여전히 전 펫 1. 이 변경으로 비주니어/아이템
  알이 런타임 랜덤 2~3히트가 되어 "알이 더 안 깨짐" 체감이 생긴다. **의도된 승인 밸런스**이나
  코스메틱과 섞이면 감사하기 어려우므로 커밋을 분리한다.
- 씰: `_verify_egg_hatch_required_hits_roll`(로컬 RNG 통계 씰=전역 randi 무소비[리뷰 P2 대응]·
  주니어 강제·3-hit OUTCOME·save/load·item소스).

### B. 시각/감각 폴리시 4건 (코스메틱 — 별도 커밋)
1. 아이템 아이콘 받침대 제거 → `resonance_egg_item_icon.png`를 맨 크리스탈(bare_variant_0 트림·센터)로 교체.
2. 설치 알 글로우 완화 → 파스텔 4층 폴오프(`_draw_soft_egg_glow`), 피크알파 0.38→0.20.
3. 셋틀 = 감쇠 복원 스프링(오뚜기 진동): `roll_settle_vel`+STIFFNESS 0.055/DAMPING 0.90.
4. 걷기 nudge ~1.5x(RADIUS 40→47·STRENGTH 0.32→0.50·MAXVX 0.75→1.2·STEP 0.45→0.74).
- 씰: `_verify_egg_settle_oscillation` + 기존 nudge 테스트 캡 갱신.

### P2 대응 (테스트 전역 RNG 결합 완화)
`roll_required_hits(rng := null)` 주입 가능화(null=전역, 프로덕션 불변). 통계 씰은 로컬 시드 RNG로
60롤 → 전역 randi 미소비. 주니어 반복 12→3(결정적 강제라 소량으로 충분). 잔여: V3-2c/보상덱 스모크
자체가 전역 RNG 결합이라 여전히 상류 변화에 민감 — 그 테스트들이 자기 RNG를 시드하는 게 근본책(별도 백로그).

변종 정체성/글로우 맵은 **불변**: 0 crystal(시안) / 1 mech(골드) / 2 nebula(바이올렛) /
3 rose(핑크) / 4 rune(제이드). `EGG_VARIANT_GLOW` 그대로.

---

## 1. 에셋 — Codex imagegen 스펙 (맨 알 5종)

파일: `godot/assets/sprites/lingpet/resonance_egg_bare_variant_{0..4}.png` (512×512, 알파 PNG).

### 1.1 조형 요구 (5장 공통 — 실루엣 통일이 회귀 요건)

- **타원형 계란 실루엣**: 폭:높이 ≈ **1 : 1.22~1.30**. 아래가 둥글고 넓고, 위가 살짝 갸름한
  전형적 계란. 완전 구형 금지, 극단적 럭비공도 금지.
- **5장 모두 동일 실루엣/스케일**. 구르기 물리 상수(장반경 a·단반경 b)를 5종이 공유하므로,
  변종 간 차이는 **표면 테마만**. 실루엣을 깨는 큰 돌출 장식(날개/지느러미/외부 링) 금지 —
  표면 인레이·각인·무늬 수준까지만.
- **캔버스 정중앙 정렬**: 알파 bbox 중심이 캔버스 중심에서 **±2px 이내** (회전 피벗 = 캔버스
  중심이므로 어긋나면 구를 때 흔들린다). 여백 넉넉히, edge-touch 금지.
- **베이크 금지 목록**: 바닥 그림자(회전하면 그림자가 같이 돈다), 받침, 에너지 링, 배경 요소,
  강한 방향성 스펙큘러 줄기(뒤집히면 어색). 부드러운 상단광 셰이딩까지는 허용.

### 1.2 변종 테마 + 크로마키 색 (변종별)

| idx | 테마 | 표면 디렉션 | 키 배경 |
|---|---|---|---|
| 0 | crystal | 반투명 시안 크리스탈 셸, 파셋 글린트, 은은한 내부 발광 | `#ff00ff` 마젠타 |
| 1 | mech | 골드/앰버 기계 셸, 미세 기어 인레이, 브러시드 메탈 플레이트 | `#ff00ff` 마젠타 |
| 2 | nebula | 딥 바이올렛 성운 셸, 성운 소용돌이 + 잔별 | `#00ff00` 그린 (마젠타와 팔레트 충돌) |
| 3 | rose | 핑크 펄스케일 셸, 소프트 이리데선스 | `#00ff00` 그린 (마젠타와 팔레트 충돌) |
| 4 | rune | 제이드 셸, 발광 룬 각인 | `#ff00ff` 마젠타 |

프롬프트 골격(변종 테마 줄만 교체):

> single fantasy game egg item, slightly ovoid egg shape (width to height about 1 : 1.25),
> upright, perfectly centered, {THEME LINE}, clean crisp game-asset rendering, soft ambient
> top light, no ground shadow, no pedestal, no rings, no background elements, perfectly flat
> solid {KEY COLOR} background, generous empty margins on all sides

실루엣 통일 팁: 1장을 먼저 뽑아 실루엣 마스터로 수용한 뒤, 같은 세션에서 테마 리스타일
편집으로 나머지 4장을 파생시키는 쪽이 실루엣 드리프트가 적다.

### 1.3 누끼 + QA 게이트

- 누끼는 `chroma_key.py` 사용 (**`remove_bg.py` 금지** — 흰색 전용, 그린/마젠타에서 조용히 실패).
- QA: 4코너 알파 0 / 알파 bbox edge-touch 없음 / bbox 중심 ±2px / 다크·라이트 프리뷰에서
  마젠타·그린 프린지 없음 / 5장 실루엣 오버레이 비교(폭·높이 편차 ±3% 이내).
- raw 키 소스와 클린 알파 PNG 둘 다 보존, 키 색·클린업 방법 기록
  (`.claude/skills/sprite-generation/checklists.md` §0.4 준용).
- ⚠️ 기존 `resonance_egg_variant_*` / `resonance_egg_holder` / `maribo_egg_*` **삭제 금지**
  (아이콘 합성 원본·향후 진열·롤백용). 참조만 정리한다.
- ⚠️ `.import` 실체화: 비-헤드리스 QA/스모크 전에 임포트를 실제로 돌려서 pending `.import`가
  스테일 아티팩트로 스모크를 붉게 만들지 않게 할 것 (기존 루나비 1024셀 사고 패턴).

---

## 2. 상태 — 구르기 물리 (`lingpet_egg_field_state.gd`)

기존 물리(넉백·마찰·벽반발·wobble 스프링)는 **그대로**. 추가는 회전 적분 하나다.

### 2.1 신규 상태 + 상수

```gdscript
var roll_angle := 0.0   # 라디안, [0, TAU) 랩. 직립 = 0.

const EGG_ROLL_CONTACT_RADIUS := 30.0   # ≈ (a + b) / 2, §3.1의 a/b에서 유도. 단일 권위(스모크로 렌더러와 교차봉인)
const EGG_ROLL_SETTLE_RATE := 0.22      # 정지 시 직립 복귀 이징 계수 (frame_scale 곱)
const EGG_ROLL_SETTLE_EPSILON := 0.02   # 이 이하면 0으로 스냅
```

### 2.2 적분 규칙 (핵심: 시간이 아니라 **이동량** 기반)

`update_player_contact()`의 모션 블록에서, 넛지/대쉬/벽클램프가 `pos.x`를 실제로 움직인
총량으로 굴린다:

```gdscript
var x_before: float = pos.x
# ... 기존 넛지 스텝 + _advance_dash_motion(frame_scale) ...
roll_angle = fposmod(roll_angle + (pos.x - x_before) / EGG_ROLL_CONTACT_RADIUS, TAU)
```

- Δx 기반이므로: 움직이면 굴러가고, 멈추면 회전도 멈추고, 벽 반발로 Δx 부호가 뒤집히면
  회전 방향도 자동 반전. 대쉬·넛지·벽클램프 케이스를 개별 배선할 필요 없음.
- Godot 2D(y-down)에서 +각도 = 시계방향 = 오른쪽으로 구르는 방향. 부호 그대로 맞는다.
- `fposmod` 랩이 **필수** — 무한 누적 각도 금지 (연속회전 텀블/정밀도 트랩 예방).
- frame_scale은 기존 모션 블록 것을 그대로 타므로 72/144Hz 페이싱 자동 대응.

### 2.3 정지 셋틀 (D4)

`dash_vx == 0.0 and absf(nudge_vx) <= 0.05`일 때만, 가장 가까운 직립(0 또는 TAU)으로
최단경로 이징:

```gdscript
var settle_delta: float = -roll_angle if roll_angle <= PI else TAU - roll_angle
roll_angle += settle_delta * minf(1.0, EGG_ROLL_SETTLE_RATE * frame_scale)
if absf(settle_delta) <= EGG_ROLL_SETTLE_EPSILON:
    roll_angle = 0.0
```

기존 wobble 스프링(±8°)이 셋틀 위에 얹혀 "뒤뚱뒤뚱하다 바로 서는" 락킹을 공짜로 만든다.

### 2.4 선택 디테일 (착지 덜컹)

구르는 중(|dash_vx| > 1.0) `floor((roll_angle - PI * 0.5) / PI)` 인덱스가 바뀌는 순간(옆면이
바닥을 치는 순간) `wobble_vel += sign(dash_vx) * 2.0`. 없어도 §3.2의 출렁임만으로 충분히
읽히므로 후순위.

### 2.5 리셋/스냅샷

- `reset_contact_motion()`에 `roll_angle = 0.0` 추가 (라운드/스폰/부화 리셋 전부 이 경로).
- `get_snapshot()`에 `"egg_roll_angle": roll_angle` 추가 (스모크 관측용). save/load 키는
  **추가하지 않는다** — 접촉 모션과 같은 휘발성 비주얼 상태.

---

## 3. 렌더러 — 맨 알 + 회전 + 출렁임 (`lingpet_egg_field_renderer.gd`)

### 3.1 상수/시그니처

```gdscript
const EGG_BARE_VARIANT_PATHS := [ ...resonance_egg_bare_variant_0..4... ]
const EGG_SEMI_MAJOR := 34.0   # a: 세로 반경(px, draw 스케일) — 최종 아트 알파 bbox 실측으로 확정
const EGG_SEMI_MINOR := 27.0   # b: 가로 반경(px) — 위와 동일하게 실측
```

- draw 박스는 이전 합성에서 **알 본체가 차지하던 화면 크기와 동일한 바디 리드**가 되도록 잡는다
  (felt-QA에서 구판 스크린샷과 비교). 88×88 박스 전체가 알이 되면 커진다 — 주의.
- a/b는 추정치 금지, 수용된 최종 아트의 알파 bbox × draw 스케일 실측으로 채운다.
  `(a + b) / 2 ≈ EGG_ROLL_CONTACT_RADIUS` 관계를 스모크로 교차봉인(§5).
- `draw_egg(canvas, center, hatch_hits, required_hits, wobble_angle, variant_index, roll_angle := 0.0)`
  — 호출부 2곳에서 `egg_state.roll_angle` 전달. `draw_profile_egg`도 동일 위임(D5).

### 3.2 그리기 순서 (받침 draw 제거)

1. **글로우 서클**: 기존 그대로 (접지점 기준, 회전 무관).
2. **출렁임(bob)**: 타원 접촉 높이 `h(θ) = sqrt((a·cos θ)² + (b·sin θ)²)`, θ = roll_angle.
   직립(θ=0)에서 h=a, 옆으로 누우면 h=b. 시각 중심을 아래로 `a - h(θ)`만큼 내린다
   (한 바퀴에 두 번 출렁 = 계란 특유의 덜컹덜컹). 물리 `pos`는 불변, 순수 비주얼 오프셋.
3. **알 본체 (회전)**: 최종 회전각 = `roll_angle + deg_to_rad(wobble_angle)`.
   기존 `EGG_PLAYER_WOBBLE_VISUAL_PIXELS` 픽셀 시프트 핵은 **삭제** (실제 기울기 회전으로 승격).
   구현은 **수동 포인트 회전 + `draw_polygon`** 권장: 쿼드 4코너를 시각 중심 기준으로
   회전시키고 UV `[(0,0),(1,0),(1,1),(0,1)]`로 텍스처 매핑.
   - ⚠️ UV는 **정규화 필수** — 픽셀 rect를 UV로 넘기면 클램프되어 알이 안 보인다(에러 없음).
   - `draw_set_transform` 사용은 차선 — 쓸 경우 `docs/godot_runtime_traps.md`의
     draw_set_transform 트랩(IDENTITY 리셋 금지 계열)을 먼저 읽고 기존 extra transform 복원
     규약을 지킬 것. 수동 회전이 트랩-프리라 1순위.
4. **크랙 라이트 (회전 동기 — 필수)**: `_draw_egg_crack_light`의 폴리라인 점들을 rect 비율
   좌표에서 뽑은 뒤 **알과 같은 (시각중심, 최종 회전각)으로 회전**시켜 그린다. 안 돌리면
   알만 돌고 균열이 허공에 서 있는 버그가 된다.
5. 부화 플래시/파편(`draw_hatch_flash`)은 무회전 유지 (터지는 순간이라 회전 정합 불필요).

### 3.3 받침/프리웜 정리

- `HOLDER_PATH` 로드·draw를 필드 경로에서 제거. `prewarm()`은 bare 세트 5장으로 교체.
- `resonance_egg_holder.png` 파일 자체는 보존 (슬롯 아이콘 합성 원본 + 향후 상점 진열 소재).
- 렌더러에 죽은 holder 코드가 남지 않게 정리하되, 파일 존재 스모크(기존 smoke 680행)는
  "진열 소재 보존" 명목으로 **유지**.

### 3.4 성능

프레임당 sqrt 1회 + 포인트 회전 수십 개 — 무시 가능. 핫패스 lazy-load 금지(기존 prewarm 패턴
유지), per-frame 텍스처 재로드 금지 규약 그대로.

---

## 4. 호출부 (`lingpet_egg_runtime.gd`)

- `draw_lingpet_body_behind_actors()`의 두 호출부(메인 ~621 / 코이그지스트 ~636)에
  `roll_angle` 인자 추가 전달. 그 외 변경 없음.
- 두 알 상태 모두 `update_player_contact`를 이미 타고 있는지 확인 — 코이그지스트 알이 접촉
  업데이트를 안 받는 경로라면 롤은 0으로 남고 직립 유지(그것대로 안전 폴백).

---

## 5. 봉인 (스모크 — `lingpet_egg_runtime_smoke.gd` 조정 + 신규)

기존 조정:
- 구 "2-레이어(받침+알) 같은 rect draw" 단언 → **"필드 draw에 holder draw 없음 + bare 변종
  텍스처 사용"** 단언으로 flip.
- 파일 존재 단언: bare 5장 추가, holder/구 변종/레거시 보존 단언 유지 (680~689행 계열).
- `EGG_VARIANT_COUNT == 렌더러 count` 봉인 유지 (bare 세트에도 동일 적용).

신규:
1. **롤 적분(OUTCOME)**: 대쉬 넉백 주입 → N프레임 스텝 → `roll_angle` 변화량 ==
   `Σ(실제 pos.x 변위) / EGG_ROLL_CONTACT_RADIUS` (dash_vx가 아니라 **변위 합산** 대조).
2. **랩**: 큰 변위 후 `roll_angle ∈ [0, TAU)`.
3. **방향 반전**: 벽 반발 후 Δroll 부호가 뒤집힘.
4. **셋틀**: 모션 정지 후 N프레임 → `roll_angle ≈ 0` (ε 이내), 뾰족 끝 정지 없음.
5. **크랙 회전 동기**: θ=0 vs θ=π/2에서 크랙 폴리라인 점들이 알과 같은 회전 관계
   (레코더 캔버스 또는 지오메트리 헬퍼 단위 검증).
6. **반경 교차봉인**: `EGG_ROLL_CONTACT_RADIUS ≈ (EGG_SEMI_MAJOR + EGG_SEMI_MINOR) / 2` (±1px).

반증검증 (repo 규약: **in-place Edit 토글만**, git reset/checkout/stash 절대 금지):
- Δx 적분 라인을 0으로 토글 → 스모크 1·3 FAIL 확인 후 원복.
- holder draw를 필드 경로에 임시 재삽입 → flip 단언 FAIL 확인 후 원복.
- 크랙 회전을 무회전으로 토글 → 스모크 5 FAIL 확인 후 원복.
- 스텝은 실제 frame_scale 경로로 (고정 1.0 가정 금지 — 고주사율 페이싱 규약).

---

## 6. felt-QA (수용 게이트)

- 대쉬로 밀기 → 덜컹덜컹 출렁이며 구르는 계란 리드(등속 미끄럼 아님).
- 벽 반발 → 스핀 방향 즉시 반전.
- 정지 → 뒤뚱뒤뚱 락킹 후 직립 (뾰족 끝으로 서거나 임의 각도 정지 없음).
- 크랙 라이트가 회전을 타고 알 표면에 붙어 있음. 부화 플래시 정상.
- 알 바디 리드가 구판(받침 합성)의 알 본체와 동급 크기. 5변종 글로우색 정상.
- 두 알(메인 + 코이그지스트) 모두 확인. 10초+ 연속 관찰(장기 회전 아티팩트 없음).
- 픽셀 QA: 상태 스모크 그린만으로 사인오프 금지 (음수-z/가림 계열 함정 예방).

---

## 7. 터치 파일 체크리스트 (Codex)

| 파일 | 작업 |
|---|---|
| `godot/assets/sprites/lingpet/resonance_egg_bare_variant_{0..4}.png` (+`.import`) | §1 신규 생성·배치·임포트 |
| `godot/scripts/lingpet/lingpet_egg_field_renderer.gd` | §3 전체 (bare draw·회전·bob·크랙 동기·holder 제거·prewarm 교체) |
| `godot/scripts/lingpet/lingpet_egg_field_state.gd` | §2 (roll_angle 적분·셋틀·리셋·스냅샷) |
| `godot/scripts/lingpet/lingpet_egg_runtime.gd` | §4 (두 호출부 roll_angle 전달) |
| `godot/tests/lingpet_egg_runtime_smoke.gd` | §5 (flip + 신규 6종 + 반증검증) |
| `docs/lingpet_egg_color_neutralize_slice_plan.md` | ✅ 상단 후속 포인터 1줄 (문서 작성 시 완료) |

커밋 선별: 이 슬라이스 = 위 파일들 + bare PNG/.import 10파일만. 트리의 다른 untracked WIP
`.import` 혼입 금지 (구 슬라이스와 동일 규약).
