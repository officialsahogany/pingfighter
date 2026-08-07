# 수호령 탑다운 탑승 렌더 계약 (S3-a)

작성 2026-08-07 · rev2 · rev3 · rev4 · **rev5 2026-08-08**(준비도 cache-only · 오라/플래시 이관 · 게이지 렌더러 등재 · P12 정밀화 · 체크리스트 14행 · 백린 활성화 보류).
상태: **계약 확정 / 에셋 0장 · 코드는 인메모리 픽스처 골격부터 착수 가능**.
선행 = `docs/lingpet_baekrin_mokrin_slice_plan.md` §3(D3) · §4(S3 행) ·
`docs/sprite_socket_composition_contract.md` 레인 C(M+N 표준).

이 문서의 목적은 **에셋 크레딧을 쓰기 전에 좌표·키·드로우순서 계약을 닫는 것**이다.
§1은 실측 사실(파일:라인), §2~§6은 확정 계약, §7은 프로토타입 수락 기준,
§8은 결정 이력(전 항목 확정), §9는 착수 순서다.
에셋 생성은 §9-2 이전까지 금지한다.

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
| `companion_mount_base` | 탑다운 빈안장 베이스(라이더 없음) | **옵셔널**. 단 지원 선언은 이 키가 아니라 `mount_presentation_model`이 한다(아래) |

- `REQUIRED_VISUAL_KEYS`에 **넣지 않는다**. 넣으면 기존 14펫이 즉시 validate RED가 된다(§1-4). `companion_carry` 선례와 동일한 옵셔널 계약.
- **조건부 검증의 기준은 게이트 맵이 아니라 렌더 모델이다** (rev2 정정, 리뷰 P1):

  ```gdscript
  # 펫 카탈로그 엔트리
  "mount_presentation_model": "topdown",   # 미선언 = 렌더 분기 없음(현행 유지)
  ```
  `mount_presentation_model == "topdown"`인 펫만 `companion_mount_base` + 그리드 메타 4값 + 안장 소켓 2값을 **필수**로 검증한다.

  ⚠️ **rev1의 오류**: 기준을 `MOUNT_SADDLE_SKILL_IDS`로 잡았는데, 그 맵에는
  `"onimaru": "onimaru_saddle"`가 **이미 들어 있다**(`lingpet_mount_state.gd:36-39`).
  즉 rev1 규칙대로면 탑다운 키가 없는 온이마루가 즉시 validate RED가 되어,
  같은 문서 §D의 "온이마루 무접촉"과 정면으로 모순됐다.
  **게이트 자격(안장 장착)과 렌더 구도(목말/탑다운)는 서로 독립 축이다** —
  섞으면 S8에서 `onimaru_saddle`이 랜딩될 때 또 한 번 충돌한다.
- 값 후보는 `"topdown"` 하나로 시작하고, 미선언(=현행 목말/일반)은 문자열을 강요하지 않는다. 알 수 없는 값은 validate 이슈로 거부한다(`front_presentation_model` 선례와 동일).
- 메타는 `visual_layout`에 `companion_mount_base_cols/_rows/_frame_count/_draw_size` **4값 전부 명시**(누락 시 5×5/25 오슬라이스 — §1-4).

### A-2. N(캐릭터 착석 라이더 ×5)은 펫 카탈로그가 소유하지 **않는다**

★ 이 문서의 핵심 제안이다.

라이더 포즈는 **캐릭터 자산**이지 펫 자산이 아니다. 펫 `visuals`(평면 dict)에 5개
캐릭터 키를 넣으면 **데이터가 M×N으로 불어난다**(마운트 가능 펫이 늘 때마다 5줄씩
복제) — 소켓 계약이 금지한 바로 그 회귀다.

제안(rev2 확정): **경로만 담는 paths 파일이 아니라 카탈로그 모듈**을 신설한다.
캐릭터마다 셀·그리드·draw_size가 다르므로(§1-1: 발토르 128 vs 160), 경로와 규격이
따로 살면 둘이 어긋났을 때 조용히 오슬라이스된다.

```
godot/scripts/resources/player_mount_rider_sprite_catalog.gd

const RIDERS := {
    "smasher":    {"path": "...", "cols": 1, "rows": 1, "frame_count": 1, "draw_size": Vector2(160, 160)},
    "viper":      {...},
    "soldier":    {...},   # 코만도의 내부 id
    "blacksmith": {...},   # draw_size 128 계열
    "optimus":    {...},
}
static func get_rider(character_id: String) -> Dictionary   # 미등재 = 빈 dict (fail-closed)
```
- **path·cols·rows·frame_count·draw_size를 한 엔트리가 함께 소유**한다. 시트를 갈아끼울 때 규격이 같은 자리에서 갱신된다.
- id 키는 `PlayerCharacterRuntime.normalize()` 결과와 **동일 문자열**을 쓴다(`soldier`/`blacksmith`/`optimus`). 별칭(`commando`/`baltor`/`io`)을 키로 쓰지 않는다.
- 텍스처 로드는 기존 `battle_resources.gd`의 `_texture_spec(...)` 경로를 그대로 탄다(캐릭터 시트와 동일 취급, optional=true).
- `battle_draw_actor_context.gd`는 이 카탈로그를 조회해 컨텍스트에 발행만 한다(그리드 상수를 다시 적지 않는다).
- 결과: 에셋 = M(펫당 1장) + N(캐릭터당 1장), 조합 0장. 데이터 선언도 M+N.

### A-4. 런타임 fail-closed — 검증은 프로덕션에서 돌지 않는다 (rev4 신설, 리뷰 P2)

`validate_catalog()`는 **스모크에서만** 호출된다(§1-4). 따라서 카탈로그 검증만
믿으면, 실제 플레이에서 M 텍스처나 **현재 캐릭터의 N**이 없을 때 다음이 벌어진다:
N은 기존 걷기 포즈로 폴백해 그려지고 **M만 안 그려져** 캐릭터가 허공에 앉는다.

**계약 — 준비도(readiness)는 런타임에서 한 번 더 본다:**

```gdscript
mount_topdown_ready := (M 텍스처 로드됨) and (현재 character_id의 N 엔트리·텍스처 로드됨)
```
- **미준비면 탑다운 진입 차단**(비탑승 유지). 이미 탑승 중 미준비로 떨어지면 **같은 프레임 강제 하차**(permit 철회와 동일 전이 재사용).
- "M만 빠진 채 일반 포즈로 계속 그리기"는 **금지**한다. 무증상 결함이라 라이브에서만 드러난다.
- 준비도는 `has_method`/`null` 체크가 아니라 **실제 텍스처 유효성**으로 판정한다(경로 문자열 존재만으로는 부족 — 로더가 null을 돌려줄 수 있다).
- ⚠️ **cache-only 조회로 제한한다** (rev5, 리뷰): 준비도 판정은 매 프레임 탑승
  게이트에서 돈다. 여기서 로드를 트리거하면 **§1-2에서 지적한 첫 탑승 동기 로드
  히치를 게이트 자체가 되살린다**(그것도 매 프레임 후보로). 판정은 비-인스턴스화
  peek만 쓴다:
  - `LingpetVisualTextureCache.get_cached_texture(pet_id, key, null)` (`:74`)
  - `ProjectResourceLoader.get_cached_texture(path)` (`:134`)
  - `get_texture()` / `load_texture()` / `load_imported_*` 계열 **호출 금지**.
  준비는 **프리웜(8-8)이 책임지고**, 게이트는 "이미 준비됐나"만 본다.
- 씰: ① M 없음 / N 없음 / 둘 다 없음 3레그 × (진입 차단 · 탑승 중 철회) + 정상
  대조군 ② **판정 경로에서 로더 호출 0회**(스파이 로더로 `get_texture`/`load_texture`
  호출 수 == 0 단언) — 이게 없으면 cache-only 계약이 조용히 무너진다.

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

### B-3. 배치식 — **최종 rect를 인자로 받아야 성립한다** (rev2 정정, 리뷰 P1)

라이더의 **착석 기준점**(seat point)은 라이더 draw rect의 하단 중앙으로 고정한다
(N 시트를 그 기준으로 저작하면 캐릭터별 추가 상수가 필요 없다):

```
seat_point    = Vector2(rider_rect.position.x + rider_rect.size.x * 0.5, rider_rect.end.y)
saddle_screen = mount_rect.position + saddle_local / cell_size * mount_rect.size
mount_rect   := saddle_screen == seat_point 가 되도록 역산 배치
```

⚠️ **rev1의 구현 불가 지점**: 이 역산은 `rider_rect`가 **최종값**일 때만 성립한다.
그런데 현행 lingpet hook은 `stage1_player_actor_renderer.gd:291`에서 호출되고
인자도 `canvas` 하나뿐이며, 최종 rect는 그보다 한참 뒤인 **:555**에서야
확정된다(:533-538 조립 → :541 듀얼글리치 흔들림 → :546-554 wall-slide·회전 AABB
클램프 → :555 `last_player_visual_rect`). 즉 현 구조로는 역산 자체가 불가능하다.

**계약**: 탑다운 전용 콜백을 신설하고 최종 rect를 넘긴다.

```gdscript
# actor_context 주입 (battle_playfield_scene_drawer)
actor_context["lingpet_mount_base_draw"] = func(c: CanvasItem, final_rider_rect: Rect2) -> void: ...

# 호출 지점(rev3 정정): stage1_player_actor_renderer.gd
#   :626 `return`(홀로그램 플리커 숨김) **뒤**, :627 상태 글로우 **앞**
```

⚠️ **rev2의 지점(:555 직후)도 여전히 너무 일렀다** (rev3 정정, 리뷰 P1):
`:615-626`의 `paddle_hologram_plan.flicker_hidden` 분기가 **`:626`에서 return**한다.
:555 직후에 M을 그리면 그 플리커 프레임에 **M만 그려지고 N(플레이어 본체)은 사라지는
고아 프레임**이 생긴다. 따라서 콜백은 플리커 return 뒤로 내린다.
→ 숨김 계약은 **2경로가 아니라 3경로**다(§C-3).

### B-3c. M은 **전용 exact-dest 경로**로 그린다 (rev4 신설, 리뷰 P1)

§B-3에서 계산한 `mount_rect`를 기존 컴패니언 렌더 경로에 그냥 넘기면 **그 rect대로
그려지지 않는다.** 두 오프셋이 자동으로 얹히기 때문이다:

| 가산 | 값 | 위치 |
|---|---|---|
| 애니메이터 Y 오프셋 | MODE_WALK → `WALK_Y_OFFSET = −6.0` | `lingpet_companion_sprite_animator.gd:149` (`dest = Rect2(center − size*0.5 + Vector2(0, get_y_offset(mode)), size)`) |
| 렌더러 bob | `sin(now_ms*0.0048)*2.6` | `lingpet_companion_renderer.gd:60-62` |

bob만 0으로 눌러도 **−6px가 그대로 남아** §7 P2의 "정렬 오차 ≤2px"를 **구조적으로**
실패한다(튜닝으로 못 넘는다).

**계약**: M은 애니메이터의 mode-기반 지오메트리를 상속하지 않는 **전용 exact-dest
경로**로 그린다.
- 입력은 이미 완성된 `dest_rect` 하나이고, 그 안에서 **어떤 Y 오프셋도 bob도 더하지 않는다**.
- 그리드 슬라이싱(`source_rect`)만 기존 `_get_sheet_meta` 규칙을 재사용한다.
- 대안(오프셋을 한 소유자에서 명시적으로 흡수)도 가능하나, 그 경우 **흡수 지점이 단 하나**여야 하고 목말 경로의 −6은 건드리지 않아야 한다.

⚠️ **씰 요건**: 배치 헬퍼의 반환값만 단언하면 이 결함을 통과시킨다(헬퍼는 맞고
렌더 경로가 어긋나는 형태). 씰은 **실제 animator/renderer까지 관통**해 최종
`dest_rect`를 확인해야 한다.

**역할 분리(정밀)**: `source_rect` **슬라이싱은 animator가 계속 소유**하고
(`_get_sheet_meta` 규칙 재사용 — 그리드 계약을 두 벌로 만들지 않는다),
**최종 배치(dest)만 renderer의 exact-dest 경로가 소유**한다.

### B-3d. 오라·플래시 레이어 이관 (rev5 신설, 리뷰)

컴패니언 렌더러는 본체 말고도 `draw_center` 기준으로 **4개 레이어**를 항상/조건부로
그린다 — 상시 앰비언트 오라(`_draw_soft_aura`, `:66`), `hit_flash`, `gauge_flash`
버스트(`:73-77`), `skill_flash`(`:78~`). exact-dest 경로로 본체만 옮기면 이 레이어들의
거취가 미정으로 남는다.

**계약 = 이관(억제 아님)**:

| 레이어 | 탑다운 계약 | 이유 |
|---|---|---|
| `gauge_flash` · `skill_flash` | **이관** — M의 exact center 기준으로 그린다 | 게이지 충전·스킬 발동 **게임플레이 피드백**이다. 조용히 사라지면 결함(무증상) |
| `hit_flash` | **이관** | 피격 피드백. 탑승 중 본체 피격은 억제되지만(§1-2) 다른 경로의 플래시까지 죽이지 않는다 |
| 상시 앰비언트 오라 | **이관** | 탑승 중 "수호령이 여기 있다"의 시각 정체성. 안장 중심으로 따라간다 |

- 중심은 **M의 exact center**, 반경은 **M의 draw_size에서 파생**한다(walk 상수 미사용, §C-2 게이지와 같은 원칙).
- **bob은 넣지 않는다** — exact-dest 계약과 일관되게 오라·플래시도 bob 무가산이다(본체만 고정되고 오라만 흔들리는 어긋남 방지).
- 씰: 탑다운 탑승 + `skill_flash > 0` 프레임에 플래시 draw **1회** + 그 중심이 **M 중심과 일치**. 억제로 오해해 0회가 되면 RED.

### B-3b. shake 재가산 금지

`final_rider_rect`는 `:534-535`에서 이미 `shake_offset`을 **포함**해 조립된다.
M 배치식에서 `shake_offset`을 다시 더하면 흔들림이 2배가 되고 안장-라이더 정렬이
매 프레임 어긋난다. 콜백은 넘겨받은 rect만 쓰고 shake를 다시 만지지 않는다.
- 컴패니언의 X-SNAP / lane-Y 로직은 탑다운 분기에서 **사용하지 않는다**(목말 전용 계약).
- 기존 `lingpet_body_draw(canvas)` early hook과 목말 deferred 호출은 **시그니처·호출 위치 모두 불변**(§C-1).

### B-4. 바닥 클램프 — M 단독 클램프 **금지**

라이더 발밑(패들 하단 ≈ 750)에 붙는 M 베이스는 플레이필드 하단을 넘을 수 있다.
그렇다고 **M만 클램프하면 안장 소켓 ↔ seat point 정렬이 그 프레임에 깨진다**
(정렬 계약이 클램프에 의해 조용히 파괴됨).

우선순위:
1. **에셋·소켓 조정으로 무클램프 수용** — M 시트의 여백/`draw_size`/`saddle_y`를 조정해 클램프 없이 필드 안에 들어오게 한다. (기본안)
2. 1이 불가능할 때만 **M과 N 전체에 동일한 합성 오프셋**을 적용한다 — 둘을 같은 값으로 함께 올려 상대 정렬을 보존한다.
3. **M 단독 클램프는 어떤 경우에도 금지.** 씰로 봉인한다(하단 초과 픽스처에서 M·N의 상대 오프셋 불변 단언).

### B-5. 리프트는 0이 기본이다

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

따라서 `defer_lingpet_body`의 판정 근거를 **리프트 값**에서 **탑승 구도 모델**로 바꾼다:

```gdscript
# 현행: var defer_lingpet_body := float(context.get("player_mount_rider_lift_px", 0.0)) > 0.0
# 제안:
var defer_lingpet_body := bool(context.get("player_mount_body_over_rider", false))
```
- 목말 경로는 이 키를 true로 실어 **현행 픽셀 그대로** 유지(회귀 0). 근거를 리프트에서 떼어내야 §B-5(탑다운 lift=0)와 충돌하지 않는다.
- 탑다운은 이 키가 false이고, M은 §B-3의 전용 콜백이 그린다.

### C-2. 콜백 3종의 역할 분리 (rev2)

| 콜백 | 시그니처 | 호출 지점 | 대상 |
|---|---|---|---|
| 기존 early hook | `lingpet_body_draw(canvas)` | `:291` (본체 앞) | 일반 컴패니언 · 알 — **불변** |
| 기존 deferred 호출 | 같은 Callable | `:712-715` + 숨김 얼리리턴 `:309-310`, `:317-318` | 목말(온이마루) — **불변** |
| **신규** | `lingpet_mount_base_draw(canvas, final_rider_rect)` | **`:626` return 뒤 · `:627` 앞**(rev3) | 탑다운 M 베이스 |

- 탑다운 탑승 중에는 **early hook의 컴패니언 본체 draw가 자기 억제**해야 한다. 억제하지 않으면 lane 위치의 컴패니언과 안장 위치의 M이 **이중으로 그려진다**. 억제 지점은 egg runtime의 body draw(현행 `draw_lingpet_body_behind_actors`) 안이며, 판정은 "탑다운 모델 × 탑승 중" 하나다.
- ⚠️ **메서드 전체 return 금지** (rev3, 리뷰 P2): 같은 메서드가 **공존 인큐베이터 알**을 먼저 그린다(`lingpet_egg_runtime.gd:1079` `_item_egg_lifecycle_state.is_active()` 분기). 통째로 반환하면 탑승 중 아이템 알이 사라진다. 억제 대상은 **메인 컴패니언 본체 표현 하나**로 한정한다.
- ⚠️ **지속시간 게이지를 함께 이관** — 알파만으로는 부족하다(rev4, 리뷰 P2): 현행은 "어느 본체 표현을 그렸든 게이지는 공통 패스 한 곳에서만" 나간다(`:1155` `_draw_companion_duration_gauge`). 본체를 M 콜백으로 옮기면 게이지만 끊긴다. 그런데 게이지의 **크기와 Y가 `companion_walk_draw_size` + 고정 `WALK_Y_OFFSET`에 묶여 있다**(`lingpet_duration_field_gauge_renderer.gd:30-37`: `BODY_HALF_WIDTH_RATIO 0.30` × draw_size, `GAUGE_Y_OFFSET := WALK_Y_OFFSET`). 즉 `body_alpha`만 넘기면 게이지가 **안장이 아니라 옛 walk 기하 위치**에 뜬다.
  → 계약을 넓힌다: M 콜백이 **알파 + M의 실제 draw_size + 최종 중심**을 함께 넘기고, 게이지 렌더러는 탑다운일 때 그 값으로 기하를 잡는다(walk 상수 미사용). 씰은 게이지 draw 1회 **+ 그 중심이 M 중심과 일치**함을 단언한다.

### C-3. 플레이어 숨김 경로 — 탑다운은 **합성 전체 숨김** (rev3: 3경로)

플레이어 본체가 그려지지 않는 경로는 **셋**이다:

| # | 경로 | 위치 | 목말(온이마루) 현행 | 탑다운 계약 |
|---|---|---|---|---|
| 1 | `paddle_hologram_should_draw == false` | `:308-311` | deferred 호출 실행 → **마운트 유지** | M+N 전부 미출력 |
| 2 | `ghost_possession_paddle_hidden` | `:316-319` | deferred 호출 실행 → **마운트 유지** | M+N 전부 미출력 |
| 3 | `paddle_hologram_plan.flicker_hidden` | `:622-626` | deferred 호출 **없음** → 마운트도 미출력 | M+N 전부 미출력 |

- 경로 3은 원본 pygame 헬퍼가 그 프레임에 빈 서페이스를 돌려주는 계약(주석 `:619-621`)이라 **온이마루도 현행 0회**다. 대조군 기대값이 경로 1·2(1회)와 다르므로 씰에서 구분해 단언한다.
- 신규 콜백이 경로 3의 return **뒤**에 있으므로 M은 세 경로 모두에서 자연히 빠진다.
- 다만 §C-2의 early-hook 자기 억제가 **세 경로에서 모두 유지**돼야 lane 위치의 컴패니언이 되살아나지 않는다 — 조합을 씰로 봉인한다(탑다운 = 컴패니언 본체 draw 0회 / 온이마루 = 경로 1·2에서 1회, 경로 3에서 0회).

### C-3b. N(라이더) 렌더 소비 계약 (rev3 신설, 리뷰 P1)

카탈로그를 만들어도 **소비 지점이 없으면 M 위에 기존 걷기·타격 포즈가 그려진다.**
두 곳을 함께 배선해야 계약이 성립한다:

1. **draw_size 채택** — `stage1_player_actor_renderer.gd:430-431`에서 `player_paddle_scale`이
   곱해지기 **전**의 `player_draw_size`를 라이더 카탈로그 값으로 교체한다. 배율 곱은
   그대로 뒤에 적용돼 확대 패들에서도 정렬이 유지된다(§7 P6).
2. **착석 시트 우선 분기** — `stage1_player_sprite_renderer.gd`의 이른-return 체인
   **상단**에 탑다운 착석 분기를 넣어, 기존 walk/idle/attack/스킬 시트보다 먼저
   선택되게 한다. 넣지 않으면 안장 위에 걷기 포즈가 재생된다.

⚠️ **파츠·글로우 이월(명시)**: 착석 시트를 `_draw_texture_region()`으로 직접 그리면
장착 파츠·소켓 글로우가 사라진다(funnel은 `_draw_texture_with_customization_overlays()`
`:1174-1207`). 소켓 카탈로그에는 `mount_rider` 모션이 저작돼 있지 않으므로,
**S3에서는 파츠·글로우 미적용을 명시 이월**하고(착석 프레임 한정) 후속 슬라이스에서
`tools/author_player_sprite_sockets.py`로 `mount_rider` 모션을 저작한 뒤 funnel을
관통시킨다. S3 씰은 "착석 중 파츠·글로우 0건"을 **의도된 계약으로** 단언한다.

### C-3c. 변신 몸체와의 우선순위 — **탑다운 한정 철회** (rev4 재작성, 리뷰 P1)

오딘의 눈(`:642`)과 뿔딸기(`:656`)는 `sprite_renderer.draw()`를 **우회**해 자기
몸체를 그린다. N 분기만 추가하면 화면에 **M(안장) + 변신체** 조합이 남는다.

셋 중 **철회(강제 하차)**를 계약으로 확정한다:

| 후보 | 판정 |
|---|---|
| 탑다운 N 우선(변신체 위에 착석 포즈) | ✗ 변신체는 실루엣 자체가 바뀌는 급이라 소켓 합성 계약이 **합성 대상에서 이미 배제**(`sprite_socket_composition_contract.md:21-23`) |
| M 숨김(변신체만) | ✗ 탑승 상태는 살아 있는데 마운트만 사라져 하차 입력이 필요한 유령 상태가 된다 |
| **철회(강제 하차)** | ✔ `_mount_state.advance`가 이미 강제 하차 3조건을 소유하고, 스킬 위치 오버라이드가 탑승을 이기는 선례와 같은 축이다 |

⚠️ **rev3의 두 오류** (리뷰 P1):

**(a) 범위가 좁았다.** "변신 활성"은 뭉뚱그린 표현이고, 실제로 본체를 대체하는
조건은 **5개**다:

| 소스 | 조건 | 근거 |
|---|---|---|
| 오딘의 눈 | `transformed`(또는 `penalty_active`) · `revival_animation_active` · `death_animation_active` | `:249-256` `_is_odins_eye_body_swap_active` |
| 뿔딸기 | `transformed` · `event_playing` | `:656` 분기 + `:724-726` 주석(`_horn_strawberry_hide_paddle = is_transformed OR is_event_playing`) |

**(b) 적용 대상이 너무 넓었다.** `advance()`에 전역 변신 조건을 넣으면
**온이마루도 강제 하차**되어 §D "온이마루 무접촉"이 깨진다.

**rev4 계약 — 판정은 egg runtime, 철회만 mount state**:

```gdscript
# egg runtime: 모델 축 × 몸체 표현 축을 여기서 곱한다
var body_presentation_incompatible: bool = (
    is_topdown_mount_model()          # 탑다운 펫에서만 true
    and _is_player_body_replaced(owner, registry)   # 위 5조건 OR
)
_mount_state.advance(..., body_presentation_incompatible)   # 필수 인자
```
- `mount_state`는 **철회 전이만** 소유한다(현행 permit 철회와 동일 형태). 판정 로직을 mount_state에 넣지 않는다.
- 인자는 **필수**로 만든다(기본값 = 조용한 누락, S2 fail-open 교훈).
- 목말(온이마루)은 모델 축에서 이미 false라 **변신 중에도 현행 그대로 탑승 유지**된다.

씰: ① 탑다운 × 5조건 각각 → `is_mounted()` false + M 콜백 0회 ② 탑다운 × 비변신
대조군 → 정상 탑승 ③ **온이마루 × 변신 대조군 → 탑승 유지**(무접촉 증명).

### C-4. 컴패니언 bob 이중 채널 정리

컴패니언 본체에는 항상 `±2.6px` bob이 걸린다(§1-2). 탑다운에서 라이더는
패들 앵커라 bob이 없으므로 **안장만 흔들리고 라이더는 고정**되는 어긋남이 생긴다.
제안: 탑다운 분기에서 컴패니언 bob을 0으로 억제하고, 흔들림이 필요하면
라이더·안장에 **같은 값**을 먹인다. 프로토타입 픽셀 QA 항목으로 둔다.

---

## 5. 계약안 §D — 온이마루 현행 carry 보존 (미결 5-6 대기)

- 신규 분기의 진입 조건은 **`mount_presentation_model == "topdown"`** 하나다(rev2). 온이마루는 이 필드를 선언하지 않으므로 코드 경로가 바뀌지 않는다 — **안장 스킬 맵 등재 여부와 무관**하며, S8에서 `onimaru_saddle`이 랜딩돼도 그대로다.
- 현행 fail-closed(`companion_carry` 미저작 펫은 기존 시트 유지, `lingpet_companion_draw_context_builder.gd:174-179`)는 **계약으로 승격**해 씰링한다: "모델 미선언 펫은 탑다운 분기에 진입하지 않는다" + 온이마루 대조군.
- 미결 5-6이 "재제작"으로 닫히기 전까지 `companion_carry` / `ONIMARU_SADDLE_LIFT_PX` / 목말 draw order / 숨김 얼리리턴의 deferred 호출은 **무접촉**이다.
- 단 8-8은 예외다: `companion_carry` **프리웜 등재**는 렌더 픽셀을 바꾸지 않는 로드 타이밍 수정이므로 이번 슬라이스에서 함께 처리한다.

---

## 6. 갱신 필요 소비자 — 전수 체크리스트

신규 시각 키 1개를 파면 함께 손대야 하는 곳(조사로 확인된 전량):

| # | 위치 | 내용 |
|---|---|---|
| 1 | `lingpet_catalog.gd` 엔트리 | `mount_presentation_model: "topdown"` + `visuals.companion_mount_base` |
| 2 | `lingpet_catalog.gd` `visual_layout` | `_cols/_rows/_frame_count/_draw_size` + `_saddle_x/_saddle_y` |
| 3 | `lingpet_catalog.gd` 검증 | **모델 기반** 조건부 필수 + 미지의 모델 문자열 거부(§A-1) |
| 4 | `lingpet_visual_texture_cache.gd:6-15` | `companion_mount_base` **및 `companion_carry`** 프리웜 등재(8-8) |
| 5 | `lingpet_companion_draw_context_builder.gd:61-108` | 텍스처 1줄 + 메타 패스스루 3~4줄(**손으로 나열하는 구조**) |
| 6 | `lingpet_companion_renderer.gd:292-368` | `_resolve_companion_sprite_state` 분기에 케이스 추가(여기서 정한 visual_key가 곧 `_get_sheet_meta` 접두사) |
| 7 | egg runtime body draw `:1045~` | 탑다운 탑승 중 **메인 본체만** 자기 억제(§C-2, 알 분기 보존) + **게이지 이관** |
| 8 | `player_mount_rider_sprite_catalog.gd` (신규) + `battle_resources.gd` | N-세트 경로·규격·로드(8-1) |
| 9 | `battle_draw_actor_context.gd` | N-세트 발행 + `player_mount_body_over_rider` |
| 10 | `battle_playfield_scene_drawer.gd:96-100` | `lingpet_mount_base_draw` 콜백 주입(§B-3) |
| 11 | `stage1_player_actor_renderer.gd:285-292` / **`:626` 직후** | defer 스위치 근거 교체 + 신규 콜백 호출 지점(§B-3 rev3) |
| 12 | `stage1_player_actor_renderer.gd:430-431` | 탑다운 시 `player_draw_size`를 라이더 카탈로그 값으로 채택(**배율 곱 이전**, §C-3b) |
| 13 | `stage1_player_sprite_renderer.gd` | 착석 시트 **우선 분기**를 이른-return 체인 상단에(§C-3b) |
| 14 | `lingpet_mount_state.gd` `advance()` | **필수 인자**로 받은 `body_presentation_incompatible` 철회 전이만 처리(판정은 egg runtime, §C-3c rev4) |
| 14b | `lingpet_duration_field_gauge_renderer.gd:30-37` | 탑다운 경로에서 **`GAUGE_Y_OFFSET` 0 · 기하는 M의 draw_size/중심**(walk 상수 미사용, §C-2) |
| 15 | 씰 + `run_pre_push_checks.ps1` + `.github/workflows/godot-ci.yml` | 락스텝 등재(두 목록 동시) |

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
| P5 | 좌우 이동 | 미러 없음(8-4) — 좌/우 이동에서 M·N 모두 뒤집히지 않음 |
| P6 | 확대 패들 | `player_paddle_scale` 상향(220폭 등)에서 정렬 유지 — 기존 씰이 155 고정으로 결함을 가린 전례 있음 |
| P7 | 바닥 경계 | 무클램프로 필드 안(§B-4 1안). 불가 시 M·N **동일 오프셋**이 적용됐고 상대 정렬 불변임을 단언 |
| P8 | 숨김 **3경로** | 탑다운은 M+N 전부 미출력. 온이마루 대조군은 경로 1·2에서 **마운트 유지**, 경로 3(플리커)에서는 **현행대로 0회**(§C-3, 8-9) |
| P9 | 이중 드로우 | 탑다운 탑승 중 컴패니언 본체 draw **1회**(lane+안장 2회 아님), 공존 아이템 알은 **보존**, 지속시간 게이지 **1회**(§C-2) |
| P10 | 변신 충돌 | **5조건 각각**(오딘 transformed/revival/death · 뿔딸기 transformed/event) → `is_mounted()` false + M 콜백 0회 · 비변신 대조군 정상 탑승 · **온이마루×변신 대조군은 탑승 유지**(§C-3c) |
| P11 | 라이더 시트 | 탑다운 활성 시 착석 시트가 walk/idle/attack보다 **먼저** 선택되고 draw_size가 카탈로그 값(배율 곱 이전)임 |
| P12 | M 기하 | **실제 animator/renderer 관통**: `source_rect`는 animator 슬라이싱 규칙과 일치하고, **최종 `dest_rect`는 renderer exact-dest 값**과 일치(−6 오프셋·bob 미가산, §B-3c) |
| P13 | 게이지 기하 | 탑다운 게이지 draw 1회 + 중심이 **M 중심**과 일치(walk 상수 미사용, §C-2) |
| P14 | 준비도 | M·N 결손 3조합에서 진입 차단 / 탑승 중이면 같은 프레임 철회, 정상 대조군(§A-4) |
| P15 | 오라·플래시 | 탑다운 + `skill_flash>0`에 플래시 draw **1회** + 중심 == M 중심(억제 아님, §B-3d) |
| P16 | 준비도 비용 | 준비도 판정 경로에서 **로더 호출 0회**(cache-only, §A-4) |
| P17 | 대조군 | **온이마루** 목말 캡처가 커밋 전후 **픽셀 동일** |

⚠️ S3 한정 의도적 미적용(씰이 계약으로 단언): 착석 프레임의 **장착 파츠·소켓 글로우
0건**(§C-3b 이월).

씰 설계: 상태 씰은 `lingpet_mount_state_smoke`에 레그 추가, 정렬·순서는
`*_visual_qa.gd` 하네스로 캡처 후 수치 판정(S2-c에서 쓴 방식 — 카드 rect 크롭 + 픽셀 통계).
⚠️ 하네스는 **기준 해상도 2020×1246**으로 띄워야 1:1 캡처가 된다(canvas_items 스트레치).

---

## 8. 결정 — **전 항목 확정** (2026-08-07 리뷰)

| # | 결정 | 내용 |
|---|---|---|
| 8-1 | **승인(수정)** | N은 캐릭터 소유. 단 paths 파일이 아니라 **`player_mount_rider_sprite_catalog.gd`**가 path·grid·frame_count·draw_size를 함께 소유(§A-2) |
| 8-2 | **승인(수정)** | 조건부 필수 검증. 단 기준은 saddle 맵이 아니라 **`mount_presentation_model == "topdown"`**(§A-1) |
| 8-3 | **승인(조건부)** | lift=0 + 모델 기반 draw order. **최종 rect 콜백 추가가 필수 조건**(§B-3, §C-2) |
| 8-4 | **확정** | S3는 **1×1·1f 정적 포즈, 미러 없음**. 방향 애니메이션은 후속 locomotion 슬라이스로 이월 |
| 8-5 | **확정** | 스매셔 프로토타입은 **백린 M만**. S3 최종 전까지 「묵린 별도 M」 **또는** 「5-8 동시활성 금지」 중 하나를 확정할 것 |
| 8-6 | **보류 유지** | 온이마루 carry 무접촉(미결 5-6 그대로) |
| 8-7 | **확정** | 옵티머스 착석 시트는 **idle 정체성 기준으로 별도 제작 가능**. walk 시트 결손은 **비차단 별건** |
| 8-8 | **확정(확장)** | 신규 `companion_mount_base` **와 기존 `companion_carry`를 함께** 프리웜 등재 — 첫 탑승 동기 로드는 S3 렌더 수명주기의 일부다 |
| 8-10 | **신설·확정(rev5)** | **N 5종이 완비될 때까지 백린의 shipped 카탈로그에 `mount_presentation_model: "topdown"`을 넣지 않는다.** 스매셔 N만 있는 상태로 활성화하면 나머지 4캐릭터가 준비도 게이트에 걸려 **조용히 탑승 불가**가 된다(fail-closed는 정상 동작이지만 플레이어에겐 무증상 결함). 골격·프로토타입 단계에서는 **인메모리 픽스처 / 디버그 경로로만** 모델을 켠다 |
| 8-9 | **신설·확정** | 플레이어 숨김 **3경로**: 탑다운은 **M+N 전체 숨김**. 온이마루는 경로 1·2 마운트 유지 / 경로 3(플리커)은 현행대로 0회(§C-3) |

---

## 9. 착수 순서 (rev4)

1. **지금 착수 가능** — 에셋 없이 **인메모리 1×1 픽스처**로 코드 골격 + draw-order 씰부터. 대상: `mount_presentation_model` 판정 · 라이더 카탈로그 조회 · **준비도 fail-closed**(§A-4) · 신규 콜백 배선(`:626` 뒤) · **M 전용 exact-dest 경로**(§B-3c) · defer 스위치 근거 교체 · early-hook 본체만 자기 억제 + **게이지 기하 이관**(§C-2) · **숨김 3경로** · **body-presentation 비호환 철회**(§C-3c).
2. 그 골격이 씰로 GREEN이 된 뒤 **M 1장(백린)** 생성 → 스매셔 프로토타입 픽셀 QA(§7).
3. §7 17레그 통과 후에만 나머지 캐릭터 4종 N 시트로 확장한다.

**여전한 금지선**: §7 프로토타입 통과 전 N-세트 5종 일괄 생성 금지 · 온이마루 경로 무접촉 · M 단독 바닥 클램프 금지(§B-4).
