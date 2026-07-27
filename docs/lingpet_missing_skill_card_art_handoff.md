# 링펫 스킬카드 미제작분 아트 핸드오프 (→ Codex)

작성일: 2026-07-03 · 작성: Claude(아트 디렉션) · 실행: Codex(생성/후처리/배선)

## 0. 목적 / 범위

`godot/scripts/lingpet/lingpet_catalog.gd`의 액티브 스킬 24개 중 **전용 스킬카드가
없는 4개**가 다른 자산(플레이스홀더)을 재사용 중입니다. 이 4개의 **전용 스킬카드
(+ 짝 아이콘)** 아트를 생성해 교체합니다.

| # | 펫 | 스킬 | 현재(플레이스홀더) | 문제 |
|---|---|---|---|---|
| 1 | 세라비(orbi) · **라이브** | 중력가속 `orbi_gravity_accel` | `orbi_ring_orbit_skillcard_imagegen_v1.png` | 범용 링오빗 아트 재사용 |
| 2 | 세라비(orbi) · **라이브** | 난쟁이마술 `orbi_dwarf_magic` | `orbi_ring_orbit_skillcard_imagegen_v1.png` | **1번과 동일 파일** → 두 스킬 구분 불가 |
| 3 | 방망깨비(onimaru) · **F7 디버그** | 뿔박치기 `onimaru_headbutt` | `onimaru_lingpet_live2d_anchor_v2_amber.png` | 라투디 앵커 재사용 |
| 4 | 라호세트(rahoset) · **F7 디버그** | 모래감옥 `rahoset_sand_prison` | `rahoset_lingpet_live2d_anchor_v1.png` | 라투디 앵커 재사용 |

우선순위:
- **P0 = 세라비 2종.** `enabled: true` 정식 부화풀 펫이라 실제 노출되고, 두 스킬이
  카드·아이콘을 **완전히 같은 파일**로 공유해 인게임에서 구분되지 않음. 두 카드는
  **한눈에 서로 다르게** 읽혀야 함(아래 §3.1/§3.2 distinguishing 참조).
- **P1 = 방망깨비·라호세트.** `enabled: false` + `debug_enabled: true`(부화풀 밖 F7 전용).
  카드/아이콘 아트는 만들되, **이 작업이 정식 승격(enabled 플립)을 의미하지 않음.**
  `enabled` 값은 그대로 두고 카드/아이콘만 교체.

아이콘 포함 여부: 위 4개는 **아이콘도 전부 플레이스홀더**(세라비는 아이콘도 두 스킬이
공유). 기존 파이프라인은 카드+아이콘을 항상 한 쌍으로 납품하므로 본 핸드오프는
**카드+아이콘 쌍**을 기본 스코프로 잡음. 카드만 원하면 §4에서 아이콘 라인 교체만 생략.

## 1. 공통 산출물 규격 (기존 승인 카드와 동일)

레퍼런스 매니페스트: `orosha_star_coil_skill_art_manifest.json`,
`maribo_bubble_trap_skillcard_imagegen_v1_manifest.json` (둘 다 Codex 내장 imagegen 파이프라인).

| 항목 | 스킬카드 | 스킬아이콘 |
|---|---|---|
| 최종 크기 | **1720 × 541 px** (와이드 배너, ~3.18:1) | **1254 × 1254 px** (정사각) |
| 배경 | **불투명 풀씬** (`transparent_background: false`) | 불투명 풀씬 |
| 베이크 텍스트 | **금지** (`no_text_baked_into_art: true`) | 금지 |
| 베이크 보더/프레임 | 생성 단계에선 넣지 말 것. 레일카드 프레임이 필요하면 후처리 오버레이로만(선택). | 없음 |
| 파일명 규약 | `<pet>_<skill>_skillcard_imagegen_v1.png` | `<pet>_<skill>_skill_icon_imagegen_v1.png` |
| 배치 | `godot/assets/sprites/lingpet/` | 동일 |

생성 파이프라인(승인 카드와 동일하게 유지):
1. **Codex 내장 imagegen**으로 초안 생성(정사각~와이드 소스 무관, 넉넉하게).
2. **Pillow 결정론적 crop/resize**로 카드는 1720×541, 아이콘은 1254×1254로 맞춤.
   (예: orosha는 1774×887 소스에서 y=20 와이드 크롭 후 리사이즈)
3. RGB 정규화 + PNG 최적화. 소스 원본은 `*_source.png`로 함께 보관.
4. **매니페스트 JSON** 동반 작성(레퍼런스 매니페스트 필드 그대로: asset id, generator,
   outputs.path/size/sha256/bytes, prompts, qa 플래그).

신규 파일명(권장):
- `orbi_gravity_accel_skillcard_imagegen_v1.png` / `orbi_gravity_accel_skill_icon_imagegen_v1.png`
- `orbi_dwarf_magic_skillcard_imagegen_v1.png` / `orbi_dwarf_magic_skill_icon_imagegen_v1.png`
- `onimaru_headbutt_skillcard_imagegen_v1.png` / `onimaru_headbutt_skill_icon_imagegen_v1.png`
- `rahoset_sand_prison_skillcard_imagegen_v1.png` / `rahoset_sand_prison_skill_icon_imagegen_v1.png`

## 2. 정체성 락 원칙 (전 카드 공통)

- 각 펫의 **cutin_art / 컨셉 원화를 아이덴티티 앵커**로 참조해 색/실루엣/링파츠를 고정.
  카드 안의 펫이 인게임 동행체·컷인과 **같은 캐릭터**로 읽혀야 함.
- 스킬 카드의 주인공은 **펫 본체 + 그 스킬의 효과**. 스킬 효과가 무엇인지(무엇을 하는지)
  한눈에 읽히게. 별도 로고/보더/HUD 요소는 넣지 않음.
- 다른 펫의 플레이스홀더 아트(예: `orbi_ring_orbit_*`)를 **복붙/변형하지 말 것.**
  펫 정체성만 참조하고 구도·효과는 새로 그림.

## 3. 스킬별 아트 디렉션

각 항목: 정체성 앵커 → 컨셉 → 팔레트 → 구도 → (필요시)구분 요구 → 그대로 쓸 프롬프트.

### 3.1 세라비 중력가속 `orbi_gravity_accel` — Gravity Accel  [P0]

- **정체성 앵커**: `res://assets/sprites/lingpet/orbi_cutin_art.png` (세라비 = 시공/크로노스
  계열 신비 링펫, 퍼플-인디고 코스믹 팔레트, 귀여운 신비체).
- **컨셉**: 세라비가 시공의 힘으로 **중력을 왜곡**해, 하강하던 공을 **위쪽(보스 진영)으로
  끌어올림.** 투사체가 아니라 **중력 우물/공간 왜곡**이 본체.
- **팔레트**: 퍼플-인디고 + 바이올렛 은하, 별/성운 악센트, 따뜻한 골드 림라이트.
- **구도(와이드)**: 한쪽에서 시전하는 세라비 → 소용돌이치는 **중력 볼텍스/시공 파문**이
  빛나는 공을 위로 끌어당김 → 반대/상단의 어두운 보스 실루엣. 위로 향하는 곡선 모션라인.
- **구분 요구(vs 난쟁이마술)**: 이 카드는 **공-상승 중력 우물**이 핵심. 반짝이는 투사체나
  작아진 보스는 넣지 말 것.
- **프롬프트**:
  > Wide Serabi Gravity Accel Lingpet skill card: cute purple-indigo cosmic chronos lingpet
  > (identity locked to orbi cut-in art) on the left, warping space-time; a swirling gravity
  > well / spacetime ripple lifts a glowing pong ball UPWARD along a curved path toward a dark
  > enemy boss silhouette on the far side; violet galaxy and starlight accents, warm gold rim
  > light, upward gravity streaks; no projectile bolt, no shrunken boss, no text, no border.

### 3.2 세라비 난쟁이마술 `orbi_dwarf_magic` — Dwarf Magic  [P0]

- **정체성 앵커**: `res://assets/sprites/lingpet/orbi_cutin_art.png` (동일 세라비).
- **컨셉**: 세라비가 **보라색 빛가루 유도 마법**을 보스에게 쏘아 올림. 명중하면 **보스가
  작아지고 느려짐**(패들 축소 + 둔화).
- **팔레트**: 세라비 퍼플 계열이되 **반짝이는 빛가루 트레일 + 축소 모티프**를 강조.
- **구도(와이드)**: 세라비가 반짝이는 퍼플 빛가루 투사체를 곡선으로 발사 → 우스꽝스럽게
  **작아진** 어두운 보스 실루엣, 스파클 트레일, 축소를 암시하는 크기 대비/수축 링.
- **구분 요구(vs 중력가속)**: 이 카드는 **반짝이는 유도 빛가루 볼트 + 작아진 보스**가 핵심.
  중력 우물/공-상승은 넣지 말 것. 두 세라비 카드가 **한눈에 달라야** 함.
- **프롬프트**:
  > Wide Serabi Dwarf Magic Lingpet skill card: same cute purple-indigo chronos lingpet
  > (identity locked to orbi cut-in art) casting a glittering purple light-dust homing bolt
  > that arcs toward a comically SHRUNKEN dark enemy boss silhouette; sparkling violet dust
  > trail, downscaling shrink rings around the tiny boss, mystical light-dust motif; distinct
  > from a gravity well (no ball-lift, no vortex), no text, no border.

### 3.3 방망깨비 뿔박치기 `onimaru_headbutt` — Horn Charge  [P1 · 디버그]

- **정체성 앵커**: `res://assets/sprites/lingpet/onimaru_lingpet_live2d_anchor_v2_amber.png`
  (붉은 도깨비 오니, 앰버/골드 링파츠 젬 팔레트, 뿔).
- **컨셉**: 방망깨비가 **뿔을 앞세워 보스에게 돌진**, 착지 순간 **지면 강타 → 지진
  충격파/흙먼지.** 단일 커밋 박치기.
- **팔레트**: 붉은 오니 바디 + 앰버/골드 젬, 주황-적색 임팩트 버스트, 방사형 충격파/먼지 링.
- **구도(와이드)**: 머리를 낮추고 뿔을 앞세워 돌진하는 방망깨비, 모션 스트릭 → 어두운 보스
  실루엣에 충돌, 방사형 충격파 + 지진 균열 + 흙먼지.
- **프롬프트**:
  > Wide Onimaru Horn Charge Lingpet skill card: fierce cute red oni lingpet with horns and
  > amber-gold ring-part gems (identity locked to onimaru amber Live2D anchor) charging
  > horn-first into a dark enemy boss silhouette; head lowered, motion streaks, a heavy
  > ground-slam shockwave with radial dust burst and earthquake cracks on impact; red-oni and
  > amber-gold palette, no kanabo focus, no text, no border.

### 3.4 라호세트 모래감옥 `rahoset_sand_prison` — Sand Prison  [P1 · 디버그]

- **정체성 앵커**: `res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1.png`
  (이집트 사막 신 컨셉 공중 링펫, 골드/사암/터쿼이즈 이집트 팔레트, 상형문자 악센트).
- **컨셉**: 라호세트가 보스 주위에 **회오리치는 모래감옥/사암 우리**를 세워 가둠. 보스의
  좌우 이동이 감옥 안으로 제한됨.
- **팔레트**: 사막 골드, 사암 탄색, 터쿼이즈 이집트 악센트, 상형문자 글로우.
- **구도(와이드)**: 공중에서 팔/지팡이를 들어 시전하는 라호세트 → 어두운 보스 실루엣을
  둘러싸는 **원통형 모래 소용돌이 + 사암 기둥 감옥**, 이집트 글리프 링.
- **프롬프트**:
  > Wide Rahoset Sand Prison Lingpet skill card: Egyptian desert-deity flight lingpet with
  > gold/sandstone/turquoise palette and hieroglyphic accents (identity locked to rahoset
  > Live2D anchor) hovering, arms/staff raised, conjuring a swirling cylindrical prison of
  > desert sand and sandstone pillars that cages a dark enemy boss silhouette inside; sand
  > vortex, glowing Egyptian glyph rings, confinement read; no text, no border.

## 4. 런타임 배선 (카탈로그 교체)

파일: `godot/scripts/lingpet/lingpet_catalog.gd`. 아래 라인의 경로를 신규 파일로 교체.
(라인 번호는 현재 스냅샷 기준 — 편집 전 `id`로 재확인 권장.)

| 스킬 | card 라인 | icon 라인 |
|---|---|---|
| `orbi_gravity_accel` | 501 | 502 |
| `orbi_dwarf_magic` | 516 | 517 |
| `onimaru_headbutt` | 1004 | 1005 |
| `rahoset_sand_prison` | 1073 | 1074 |

- `orbi_gravity_accel` / `orbi_dwarf_magic`는 현재 **둘 다** `orbi_ring_orbit_*`를 가리킴 →
  각자 **서로 다른** 신규 파일로 갈라줄 것.
- 교체 후 각 펫 `note` 문자열의 플레이스홀더 문구도 갱신:
  - orbi note: "temporarily reuse the accepted orbi ring-orbit purple art as a placeholder
    pending dedicated 중력가속 / 난쟁이마술 art" → 전용 아트 반영 문구로.
  - onimaru/rahoset note의 "스킬카드/아이콘 아트 … 전까지 디버그 전용" 문구 갱신
    (단, `enabled`는 계속 false 유지 — 카드 제작이 승격이 아님).

## 5. 함정 (CLAUDE.md 표준 규칙)

- ⚠️ **예약-부재 자산 매프레임 re-stat 트랩.** 리소스 로더는 성공만 캐시하므로, 카탈로그가
  아직 없는 파일 경로를 가리키면 레일카드 draw가 매프레임 파일시스템을 re-stat(경고는
  once-only로 무음). 그래서 현재 플레이스홀더도 "존재하는 파일"을 일부러 가리키고 있음
  (onimaru 라인 1000-1003 주석 참조). → **신규 PNG 배치와 카탈로그 경로 교체를 같은
  커밋에** 반영. 파일이 repo에 실재하고 `.import`가 생성된 뒤에만 경로를 바꿀 것.
- ⚠️ **세라비 두 스킬은 반드시 서로 다른 카드/아이콘.** 같은 파일로 두면 지금 버그 그대로.
- ⚠️ **텍스트/보더 베이크 금지** — 런타임이 프레임/라벨을 얹으므로 아트에 굽지 말 것.
- ⚠️ **디버그 게이트 유지** — onimaru/rahoset `enabled: false` 그대로. 카드 제작 ≠ 정식 출시.

## 6. 수락 전 QA 체크리스트

- [ ] 카드 4장 = 1720×541, 아이콘 4장 = 1254×1254, 전부 불투명 RGB.
- [ ] 베이크 텍스트/보더 없음.
- [ ] 각 카드가 **해당 펫 정체성**으로 읽힘(색/실루엣/링파츠 = cutin_art와 일치).
- [ ] **세라비 중력가속 vs 난쟁이마술 카드/아이콘이 한눈에 구분**됨.
- [ ] 스킬 효과가 아트에서 읽힘(중력 우물 / 축소 빛가루 / 뿔 강타 / 모래 감옥).
- [ ] 소형 HUD/레일카드 크기로 축소해도 아이콘 주피사체가 뭉개지지 않음.
- [ ] 매니페스트 JSON 4쌍 작성(sha256/bytes/size/prompts/qa 포함).
- [ ] 신규 PNG 배치 + Godot `.import` 생성 + 카탈로그 경로 교체가 **같은 커밋**.
- [ ] 인게임 픽셀 QA: 세라비 획득 → 두 액티브 카드가 각자 신규 아트로 뜨는지 확인
      (디버그 2종은 F7로 확인).
