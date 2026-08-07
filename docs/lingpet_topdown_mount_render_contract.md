# 수호령 탑다운 탑승 렌더 계약 (S3-a)

작성 2026-08-07. 상태: **조사 완료 / 계약안 제출 · 코드 0줄 · 에셋 0장**.
선행 = `docs/lingpet_baekrin_mokrin_slice_plan.md` §3(D3) · §4(S3 행) ·
`docs/sprite_socket_composition_contract.md` 레인 C(M+N 표준).

이 문서의 목적은 **에셋 크레딧을 쓰기 전에 좌표·키·드로우순서 계약을 닫는 것**이다.
아래 §1은 실측 사실(파일:라인), §2~§6은 제안, §7은 사용자 결정 대기 항목이다.
제안은 승인 전까지 코드로 옮기지 않는다.

---

## 1. 실측 — 지금 코드가 실제로 하는 일

### 1-1. 플레이어 5종의 draw 소유자는 하나다

| 항목 | 사실 | 근거 |
|---|---|---|
| 본체 draw 소유자 | `stage1_player_actor_renderer.gd` **단일** — stage1~stage8 전 스테이지가 이 클래스를 preload + `new()` | `stage2_actor_renderer.gd:3,9` / `stage3:3,10` / `stage4:3,13` / `stage5_hongryun:3,9` / `stage6_tetriser:10,16` / `stage7_akamu:7,13` / `stage8_minotaur:7,13` |
| 텍스처·셀 선택 | 자식 `stage1_player_sprite_renderer.gd` (`_draw_texture_region` 단일 funnel) | `stage1_player_sprite_renderer.gd:1222`, 소켓 포함 경로 `:1174-1207` |
| 캐릭터 분기 위치 | 렌더러가 아니라 **컨텍스트 빌더** `battle_draw_actor_context.gd`의 `is_smasher/is_viper/is_commando/is_optimus/is_blacksmith` | `battle_draw_actor_context.gd:35-40`, id 정규화 `player_character_runtime.gd:4-20` (코만도=`soldier`, 발토르=`blacksmith`) |
| draw rect 좌표식 | x = `player_pos.x + paddle_size.x*0.5 − draw.x*0.5` (+shake +visual_x +wall_slide), y = `player_pos.y + paddle_size.y − draw.y + 12.0` (+shake +visual_y) | `stage1_player_actor_renderer.gd:533-538` |
| 배율 | `player_paddle_scale`이 **draw_size에** 곱해진 뒤 rect 생성 | `stage1_player_actor_renderer.gd:430-431` |
| 벽 여백 보정 | `PlayerSpriteWallSlide.resolve_offset_x` + `clamp_body_inside_walls`(회전 AABB) | `:475-489`, `:546-555` |
| 소켓 저작 범위 | **스매셔 1종뿐** (`foot_l`/`foot_r`/`head_top` × walk/dash/idle/attack, 셀 160×160) | `player_sprite_socket_catalog.gd:22-105` |
| 캐릭터별 그리드 | 스매셔 공격 4×4/16 · 바이퍼 4×2/8 · 코만도 idle 4×2/8(셀160) · 발토르 4×4/16 + **draw 128×128** · 옵티머스 idle 4×2/8 | `battle_draw_actor_context.gd:330-331`, `:18`, `:490-492` |
| 옵티머스 현황 | walk/attack 시트가 **디스크에 없음**(optional spec) → 이동 시 절차 플레이스홀더 | `battle_resources.gd:843-847`, `stage1_player_sprite_renderer.gd:657-669` |

⚠️ **N-세트에 직접 영향**: 캐릭터마다 셀 크기·그리드·draw_size가 다르고(발토르 128,
나머지 160), 소켓 저작은 스매셔에만 있으며, 옵티머스는 walk 시트조차 없다.
"5종 동일 규격"을 전제한 계약은 성립하지 않는다.

### 1-2. 온이마루 탑승(현행 목말)의 실제 계약

| 항목 | 값/식 | 근거 |
|---|---|---|
| 근접 진입 | 78.0px (하차는 거리 무관) | `lingpet_mount_state.gd:30`, `:175-197` |
| 라이더 리프트 | `14.0*(eased+overshoot) + bounce*eased` / 하차 `14.0*(1−t)²` — 정착 이동 14.0~17.2px, 정지 14.0~15.5px | `:53`, `:135-149` |
| 컴패니언 위치 | `Vector2(player_center_x, current.y)` — **lane Y 보존, X는 관성 없이 SNAP** | `:215-218` |
| 플레이어 중심 X | `player_pos.x + player_paddle_width*0.5` (선언 키 `player_paddle_width` 필수) | `:227-236`, `battle_scene_state.gd:45` |
| 시트 스왑 | `mount_carry_active` 하나로 **body 4키만**(idle/move_left/move_right/walk) `companion_carry`로 치환. strike·cast는 **스왑 안 됨** | `lingpet_companion_draw_context_builder.gd:174-179`, `:61-64` vs `:73-74` |
| 그리드 계약 | **visual_key는 안 바뀐다** → 스왑당한 키의 메타로 잘림. 온이마루는 메타 미선언 → 애니메이터 기본 5×5/25f(IDLE 12). 실제 시트 1280×1280(셀 256) | `lingpet_companion_renderer.gd:214,490-503`, `lingpet_companion_sprite_animator.gd:7-10`, `lingpet_catalog.gd:1118-1128` |
| draw size | MODE_WALK 유지 → `companion_walk_draw_size 92` + `WALK_Y_OFFSET −6` | `lingpet_catalog.gd:1125`, animator `:13-14` |
| 미러링 | 없음(전용 move_left/right 두 키가 같은 carry로 치환, flip=false) | `lingpet_companion_renderer.gd:409-433` |
| 추가 흔들림 | 컴패니언 본체에 **항상** `sin(t*0.0048)*2.6` bob이 얹힘(리프트와 비동기 2채널) | `lingpet_companion_renderer.gd:60-62` |
| 프리웜 | `companion_carry`는 `DEFAULT_PREWARM_KEYS`에 **없음** → 첫 탑승 프레임에 1280² 동기 로드 | `lingpet_visual_texture_cache.gd:6-15,54-71` |
| 레일 표시 | 온이마루 액티브는 `activation_model` 미선언(=launch) → permit 투영 항상 F/F → **현행 탑승은 레일에 아무 표시도 없음** | `lingpet_catalog.gd:1129-1162`, `lingpet_egg_runtime.gd:2192-2201` |

### 1-3. draw order — 현행 스위치는 단 하나

```
sprite_renderer.draw(플레이어 본체 + 소켓 글로우 + 퍽 파츠)
  → 코만도 무기 B2/일반 오버레이
  → [deferred] lingpet body        ← 마운트가 라이더 위
  → 저주 반전 머리 → 슬로우 파형 → 빙의 오버레이
```
- 스위치: `defer_lingpet_body := player_mount_rider_lift_px > 0.0` (`stage1_player_actor_renderer.gd:285-292`, 지연 호출 `:712-715`)
- 플레이어 숨김 얼리리턴 2곳에서도 지연 호출 보존 (`:308-311`, `:316-319`)
- lingpet body hook 주입은 `battle_playfield_scene_drawer.gd:96-100` 한 곳("배경과 플레이어 사이의 유일한 Z 슬롯")
- 노드 z 중앙 레지스트리는 **없다**(호스트별 `const Z_INDEX` 13개 파일). 현행 액터 합성은 전부 즉시모드 순서로 해결.

### 1-4. 시각 키 계약

- 필수 10키 = `REQUIRED_VISUAL_KEYS` (`lingpet_catalog.gd:19-30`). 검증은 **스모크에서만** 실행(`validate_catalog`의 프로덕션 호출 0건), `enabled:false`면 통째로 건너뜀(`:1739-1745`).
- `visuals` = 평면 `key → res:// 경로`. `visual_layout` = **float 전용**(문자열 불가, `:1434-1438`).
- 그리드 메타 규칙 `<visual_key>_cols/_rows/_frame_count` + `<mode>_draw_size`. **미선언 시 5×5/25f 기본값으로 오슬라이스**(`lingpet_companion_renderer.gd:490-503`).
- 백린 선례: idle 1장을 6키에 별칭하고 **6키 전부 1×1·1f 메타 명시**(`lingpet_catalog.gd:674-723`).
- `front_presentation_model="static"`은 동적 정면 3키를 면제하는 동시에 **정의 금지**(fail-closed 위장 방지, `:1773-1795`).
- ⚠️ **선재 구멍**: 광장(`plaza_actor_visual_projection.gd:11-13`)과 F7 디버그 피커(`lingpet_debug_picker.gd:30-32`)가 `companion_walk`를 **5×5/25로 하드코딩** → 1×1 별칭 펫(백린)은 두 화면에서 이미 1/25만 그려진다. S3와 별개로 존재하는 결함.

### 1-5. 합성 선례 / 탑다운 선례

- 합성 패턴은 **둘**뿐이다:
  - **P1 목말형** = carry 시트 스왑 + 라이더 Y 리프트 + hook 지연 (온이마루)
  - **P2 바인드형** = 전용 bind 시트 + 위치 오버라이드 + **보스 위 FRONT 패스** (오로샤 별똬리, `lingpet_egg_runtime.gd:975-997`)
- **탑다운 시점 렌더는 리포 전체에 0건**. `character_topdown_rim.gdshader`는 상단 림라이트일 뿐이고(`shaders/character_topdown_rim.gdshader:12-15`), `*_overhead_*`는 머리 위 스윙 포즈의 측면 뷰다.
- 백린 탑다운 에셋은 **아직 커밋되지 않았다**(`git ls-files` 기준 topdown/안장 시트 0건).
- ★ `docs/sprite_socket_composition_contract.md:15-19, 135-159`가 이미 **레인 C = 별도 엔티티**와 **M+N 표준**("수호령 M벌 + 캐릭터 탑승 포즈 N벌만 제작, 조합 0벌 … 수호령별 맞춤 포즈 금지(허용 시 M×N 회귀)")을 명문화하고 있다. S3는 새 표준을 만드는 게 아니라 **그 표준의 첫 실제 이행**이다.

---

## 2. 계약안 §A — 시각 키와 소유 위치

### A-1. M(수호령 빈안장 탑다운)은 펫 카탈로그가 소유한다

| 키 | 용도 | 필수성 |
|---|---|---|
| `companion_mount_base` | 탑다운 빈안장 베이스(라이더 없음) | **옵셔널**. 이 키 보유 = 탑다운 탑승 지원 선언 |

- `REQUIRED_VISUAL_KEYS`에 **넣지 않는다**. 넣으면 기존 14펫이 즉시 validate RED가 된다(§1-4). `companion_carry` 선례와 동일한 옵셔널 계약.
- 대신 **조건부 검증**을 신설한다: `MOUNT_SADDLE_SKILL_IDS`에 등재된 펫은 `companion_mount_base` + 그 그리드 메타 4값이 **반드시** 있어야 한다(없으면 validate 이슈). 안장 스킬이 있는데 베이스가 없으면 탑승이 무가시로 죽기 때문이다.
- 메타는 `visual_layout`에 `companion_mount_base_cols/_rows/_frame_count/_draw_size` **4값 전부 명시**(누락 시 5×5/25 오슬라이스 — §1-4).

### A-2. N(캐릭터 착석 라이더 ×5)은 펫 카탈로그가 소유하지 **않는다**

★ 이 문서의 핵심 제안이다.

라이더 포즈는 **캐릭터 자산**이지 펫 자산이 아니다. 펫 `visuals`(평면 dict)에 5개
캐릭터 키를 넣으면 **데이터가 M×N으로 불어난다**(마운트 가능 펫이 늘 때마다 5줄씩
복제) — 소켓 계약이 금지한 바로 그 회귀다.

제안: 플레이어 스프라이트 경로 레지스트리에 신규 모듈 1개를 신설한다.

```
godot/scripts/resources/player_mount_rider_sprite_paths.gd
  SMASHER_SEATED   := "res://assets/sprites/characters/smasher/smasher_mount_seated_topdown_*.png"
  VIPER_SEATED     := ...
  COMMANDO_SEATED  := ...   # 내부 id "soldier"
  BLACKSMITH_SEATED:= ...
  OPTIMUS_SEATED   := ...
```
- 로드는 기존 `battle_resources.gd`의 `_texture_spec(...)` 경로를 그대로 탄다(캐릭터 시트와 동일 취급).
- 그리드/셀/draw_size는 **`battle_draw_actor_context.gd`가 발행**한다(코만도·발토르 그리드와 같은 자리). 이렇게 하면 캐릭터별 규격 차이(발토르 128 vs 나머지 160)를 기존 방식 그대로 흡수한다.
- 결과: 에셋 = M(펫당 1장) + N(캐릭터당 1장), 조합 0장. 데이터 선언도 M+N.

### A-3. 백린 static 모델과의 충돌 없음

`STATIC_FRONT_FORBIDDEN_VISUAL_KEYS`는 정면 4키만 막는다(`lingpet_catalog.gd:39-52`).
`companion_mount_base`는 정면 계열이 아니므로 static 펫도 자유롭게 보유한다.
단 **"정적 1장을 동적 그리드 키에 꽂지 말 것"** 원칙은 동일하게 적용 — 1장이면
1×1·1f 메타를 명시한다.

---

## 3. 계약안 §B — 좌표·소켓·피벗

### B-1. 라이더는 패들 앵커를 유지한다 (변경 금지)

라이더 rect를 안장 소켓에 앵커하면 `wall_slide` 보정·회전 AABB 클램프·패들 배율
체인이 전부 깨진다(§1-1). 따라서:

> **라이더(플레이어 스프라이트)는 지금과 똑같이 패들 하단 앵커로 그린다.
> 움직이는 쪽은 M 베이스다.**

### B-2. 안장 소켓 = 셀-로컬 픽셀 앵커 (기존 소켓 계약 재사용)

M 시트에 **안장 착석점**을 선언한다. 좌표계는 `docs/sprite_socket_composition_contract.md`
와 동일한 **저작 셀 로컬 픽셀**이고, 화면 매핑식도 그대로 재사용한다:

```
screen = dest_rect.position + local / cell_size * dest_rect.size
```

`visual_layout`(float 전용)에 2값:
```
companion_mount_base_saddle_x   # 셀 로컬 px
companion_mount_base_saddle_y   # 셀 로컬 px
```

### B-3. 배치식

라이더의 **착석 기준점**(seat point)은 라이더 draw rect의 하단 중앙으로 고정한다
(N 시트를 그 기준으로 저작하면 캐릭터별 추가 상수가 필요 없다):

```
seat_point   = Vector2(rider_rect.position.x + rider_rect.size.x * 0.5, rider_rect.end.y)
saddle_screen= mount_rect.position + saddle_local / cell_size * mount_rect.size
mount_rect  := saddle_screen == seat_point 가 되도록 역산 배치
```
즉 M 베이스의 위치는 라이더에서 파생되며, 컴패니언의 X-SNAP/lane-Y 로직은
탑다운 분기에서 **사용하지 않는다**(P1의 lane Y 보존은 목말 전용 계약).

⚠️ 검증 필요: lane Y(기본 725) 대신 라이더 발밑(패들 하단 ≈ 750)에 붙으면 M 베이스가
플레이필드 하단 경계를 넘을 수 있다. **바닥밀착 클램프**(`min(anchor, FIELD_BOTTOM − h/2)`
트랩)를 탑다운 베이스에도 적용할지 프로토타입에서 픽셀로 판정한다.

### B-4. 리프트는 0이 기본이다

목말은 어깨에 올라타므로 14px 리프트가 필요했지만, 탑다운 착석은 라이더가
안장 위에 **앉은 포즈로 저작**되므로 스프라이트가 이미 그 높이를 포함한다.
`player_mount_rider_lift_px`는 탑다운 분기에서 **0**으로 두고(=현행 목말 계약 무접촉),
필요하면 `companion_mount_base_rider_lift_px`를 별도로 판다.

⚠️ 이는 §4의 draw order 스위치에 직접 영향한다(현행 스위치가 리프트>0을 본다).

---

## 4. 계약안 §C — draw order

### C-1. 탑다운은 순서가 **반대**다

| 구도 | 위에 그려지는 것 | 현행 스위치 |
|---|---|---|
| 목말(P1, 온이마루) | **마운트가 라이더 위**(머리·올린 손이 하반신을 가림) | `defer_lingpet_body = lift > 0` → 지연 |
| 탑다운(신규) | **라이더가 안장 위** | 지연하면 안 됨 |

따라서 `defer_lingpet_body`의 판정 근거를 **리프트 값**에서 **탑승 구도**로 바꾼다:

```gdscript
# 제안
var defer_lingpet_body := bool(context.get("player_mount_body_over_rider", false))
```
- 목말 경로는 이 키를 true로 실어 **현행 픽셀 그대로** 유지(회귀 0).
- 탑다운 경로는 false → lingpet body가 기존 behind-player Z 슬롯에서 그려지고, 라이더가 그 위에 얹힌다. **신규 Z 슬롯을 만들 필요가 없다.**
- 플레이어 숨김 얼리리턴 2곳의 지연 호출 보존 로직은 그대로 둔다(§1-3).

### C-2. 컴패니언 bob 이중 채널 정리

컴패니언 본체에는 항상 `±2.6px` bob이 걸린다(§1-2). 탑다운에서 라이더는
패들 앵커라 bob이 없으므로 **안장만 흔들리고 라이더는 고정**되는 어긋남이 생긴다.
제안: 탑다운 분기에서 컴패니언 bob을 0으로 억제하고, 흔들림이 필요하면
라이더·안장에 **같은 값**을 먹인다. 프로토타입 픽셀 QA 항목으로 둔다.

---

## 5. 계약안 §D — 온이마루 현행 carry 보존 (미결 5-6 대기)

- 신규 분기의 진입 조건은 **`companion_mount_base` 키 보유 여부** 하나다. 온이마루는 이 키가 없으므로 코드 경로가 바뀌지 않는다.
- 현행 fail-closed(`companion_carry` 미저작 펫은 기존 시트 유지, `lingpet_companion_draw_context_builder.gd:174-179`)는 **계약으로 승격**해 씰링한다: "탑다운 키 없는 펫은 탑다운 분기에 진입하지 않는다" + 온이마루 대조군.
- 미결 5-6이 "재제작"으로 닫히기 전까지 `companion_carry` / `ONIMARU_SADDLE_LIFT_PX` / 목말 draw order는 **무접촉**이다.

---

## 6. 갱신 필요 소비자 — 전수 체크리스트

신규 시각 키 1개를 파면 함께 손대야 하는 곳(조사로 확인된 전량):

| # | 위치 | 내용 |
|---|---|---|
| 1 | `lingpet_catalog.gd` `visuals` | `companion_mount_base` 경로 |
| 2 | `lingpet_catalog.gd` `visual_layout` | `_cols/_rows/_frame_count/_draw_size` + `_saddle_x/_saddle_y` |
| 3 | `lingpet_catalog.gd` 검증 | 조건부 필수 규칙(A-1) — 안장 스킬 보유 펫 한정 |
| 4 | `lingpet_visual_texture_cache.gd:6-15` | `DEFAULT_PREWARM_KEYS` 등재(미등재 시 draw 중 콜드 로드) |
| 5 | `lingpet_companion_draw_context_builder.gd:61-108` | 텍스처 1줄 + 메타 패스스루 3~4줄(**손으로 나열하는 구조**) |
| 6 | `lingpet_companion_renderer.gd:292-368` | `_resolve_companion_sprite_state` 분기에 케이스 추가(여기서 정한 visual_key가 곧 `_get_sheet_meta` 접두사) |
| 7 | `player_mount_rider_sprite_paths.gd` (신규) + `battle_resources.gd` | N-세트 경로·로드 |
| 8 | `battle_draw_actor_context.gd` | N-세트 텍스처/그리드/draw_size 발행 + `player_mount_body_over_rider` |
| 9 | `stage1_player_actor_renderer.gd:285-292` | draw order 스위치 근거 교체(§C-1) |
| 10 | 씰 + `run_pre_push_checks.ps1` + `.github/workflows/godot-ci.yml` | 락스텝 등재(두 목록 동시) |

**별건으로 분리 권고**: 광장·F7 피커의 5×5 하드코딩(§1-4 선재 구멍)은 S3 범위 밖이지만,
탑다운 펫이 광장에 서면 같은 방식으로 깨진다. 별도 슬라이스로 티켓만 세운다.

---

## 7. 프로토타입(캐릭터 1종) 수락 기준

대상 = **스매셔**(소켓 저작이 있는 유일 캐릭터, `player_sprite_socket_catalog.gd:100-105`).

| # | 레그 | 판정 |
|---|---|---|
| P1 | normal(비탑승) | 기존 컴패니언 렌더 픽셀 **불변**(탑다운 키 보유해도 비탑승은 무변화) |
| P2 | mount | 안장 소켓 ↔ 라이더 seat point 정렬 오차 **≤2px**(캡처 좌표 실측) |
| P3 | mount | 라이더가 안장 **위**(z 순서) — 안장 픽셀이 라이더를 가리지 않음 |
| P4 | dismount | 해제 프레임 이후 컴패니언이 lane Y 복귀, 라이더 rect 원복 |
| P5 | 좌우 이동 | facing/미러 계약 일치(§1-2 현행은 미러 없음 — 탑다운은 결정 필요, §8-4) |
| P6 | 확대 패들 | `player_paddle_scale` 상향(220폭 등)에서 정렬 유지 — 기존 씰이 155 고정으로 결함을 가린 전례 있음 |
| P7 | 바닥 경계 | 안장 베이스가 플레이필드 하단을 넘지 않음(§B-3) |
| P8 | 대조군 | **온이마루** 목말 캡처가 커밋 전후 **픽셀 동일** |

씰 설계: 상태 씰은 `lingpet_mount_state_smoke`에 레그 추가, 정렬·순서는
`*_visual_qa.gd` 하네스로 캡처 후 수치 판정(S2-c에서 쓴 방식 — 카드 rect 크롭 + 픽셀 통계).
⚠️ 하네스는 **기준 해상도 2020×1246**으로 띄워야 1:1 캡처가 된다(canvas_items 스트레치).

---

## 8. 사용자 결정 대기 항목

| # | 질문 | 제안(기본값) | 영향 |
|---|---|---|---|
| 8-1 | N-세트를 캐릭터 자산으로 둘 것인가(§A-2) | **예** — `player_mount_rider_sprite_paths.gd` 신설 | 아니오면 펫 카탈로그에 5키/펫 → 데이터 M×N |
| 8-2 | 탑다운 키를 조건부 필수로 검증할 것인가(§A-1) | **예** — 안장 스킬 보유 펫 한정 | 아니오면 무가시 실패가 스모크를 통과 |
| 8-3 | 라이더 리프트 0 + draw order 스위치 근거 교체(§B-4, §C-1) | **예** | 아니오면 탑다운에서 안장이 라이더를 덮음 |
| 8-4 | 탑다운 좌우 이동 표현 | **미러 금지 · 좌/우 시트 2장** vs **1장 미러** | 제작량 M×2 여부. 탑다운 안장은 좌우 비대칭이 적어 미러가 유력하나 아트 판단 필요 |
| 8-5 | 묵린 별도 M 베이스 제작 여부 | 백린 1장 + 리컬러는 **현재 불가**(렌더러 modulate가 `Color(1,1,1,a)`) → 별도 1장 권고 | 제작량 +1 |
| 8-6 | 미결 5-6(온이마루 carry 탑다운 재제작) | **보류 유지** — S3는 무접촉 | 닫히면 별도 슬라이스 |
| 8-7 | 옵티머스 N 시트 | 본체 walk 시트조차 없음(§1-1). 착석 시트만 먼저 만들지, 캐릭터 시트 결손을 별건으로 볼지 | 5종 완주 가능 여부 |
| 8-8 | `companion_mount_base` 프리웜 등재(§6-4) + 현행 `companion_carry` 미등재 결함 | 신규는 **등재**, 기존 carry는 별건 | 첫 탑승 프레임 히치 |

---

## 9. 착수 금지선

- 위 8항목이 닫히기 전 **AutoSprite 크레딧 소모 금지**(M 1장이라도).
- 코드도 8-1~8-3이 닫힌 뒤에 착수한다(키 이름·소유 위치·드로우 순서가 전부 바뀌는 항목).
- 프로토타입은 **1종(스매셔)** 통과 후에만 나머지 4종으로 확장한다.
