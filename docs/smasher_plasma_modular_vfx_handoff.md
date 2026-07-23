# Smasher Plasma — 3-Piece Modular VFX Remake (handoff)

절차적 라인-그리기 플라즈마 이펙트를 버리고, **정적 텍스처 3장 + writhe-ember 셰이더
+ GPUParticles2D + intensity 엔벨로프**로 재제작한다. 모션은 전부 엔진 측(셰이더/파티클/
트윈)이고 텍스처는 still이다.

Claude가 이번 슬라이스로 납품한 것: 에셋 3장 + 셰이더 프리셋 + **backbone FX 호스트**
+ 스모크 3종. 남은 것: **라이브 런타임 sync_state 배선(사용자/Codex)** → Claude 적대리뷰.

---

## 1. 에셋 (Gemini imagegen, 휘도→알파 + 라디얼 마스크)

| piece | 역할 | 경로 | 블렌드 |
|---|---|---|---|
| backplate | 분위기·깊이 아우라 + (재사용) 실체 코어 | `res://assets/sprites/skills/plasma_vfx/plasma_backplate.png` (1024²) | ADD / 코어는 MIX |
| arc | 율동(회전 전기 필라멘트 링) | `res://assets/sprites/skills/plasma_vfx/plasma_arc.png` (1024²) | ADD |
| particle | 에너지 모트(GPUParticles2D 아틀라스) | `res://assets/sprites/skills/plasma_vfx/plasma_particle.png` (256²) | ADD |

- 원본 JPEG: `plasma_vfx/raw/*.jpeg` (provenance).
- 알파 준비 = `scratchpad/bake_plasma_vfx.py`: `alpha = max(r,g,b)`(시안-블루 글로우가
  luminance보다 정확) + 블랙포인트 리프트(JPEG 노이즈 제거) + 라디얼 마스크.
- QA 완료: **전 코너 알파=0, 알파 bbox 엣지 미접촉**, 코어 maxA=255 보존.
- `.import` 3개 생성 완료(익스포트 패킹). dev/스모크는 `ProjectResourceLoader.load_texture`
  raw-first 경로로 `.import` 없이도 로드된다.

색 재생성이 필요하면 raw 프롬프트를 재사용하되, **정체성 = 시안-백 전자기**를 유지.

## 2. 셰이더 프리셋 (`writhe_ember_material.gd`, 재사용 — 색/속도 uniform만 변경)

| 프리셋 | 용도 | 성격 |
|---|---|---|
| `smasher_plasma_orb` | backplate + 코어 기본 | 시안-백 코어 / 전기-블루 ember / 딥블루 depth |
| `smasher_plasma_orb_enraged` | 최대 차징/enraged | 니어-화이트 코어, flow/flicker/distort ↑ |
| `smasher_plasma_arc` | arc 필라멘트 | flow 강 + breath 약 = 흐르는 필라멘트 |
| `smasher_plasma_arc_enraged` | enraged arc | 더 빠른 flow/flicker |

enraged는 **별도 튜닝 테이블**(같은 셰이더, uniform만). 호스트가 `enraged` 플립 시
`apply_preset`으로 스왑.

## 3. FX 호스트 API (`scripts/characters/smasher_plasma_fx_host.gd`)

`sync_state(next_state: Dictionary, active: bool)` — 렌더러가 매 프레임 호출.

| state 키 | 의미 | 소스(라이브 배선) |
|---|---|---|
| `phase_active` | 이펙트 표시 여부 | `charging or wave_active` |
| `pos` | **스크린 좌표** | `game_offset + (playfield_pos + shake) * render_scale` |
| `render_scale` | 플레이필드→스크린 배율 | 렌더 컨텍스트 |
| `radius` | 오브 반경(playfield px) | 차징=`FIELD_MIN+..*cs`, 웨이브=`wave_radius` |
| `intensity` | 0~1 세기 | 차징=`charge_size`, 웨이브=에너지(예: `wave_slow_amount` 또는 1.0) |
| `enraged` | enraged 테이블 | `charge_size >= ~0.9` 또는 최대 차징 발사 |
| `quality_scale` | LOD 0~1 | 렌더 LOD (파티클 게이트 0.55) |

호스트는 `position=pos`, `scale=render_scale`, 자식은 ZERO. 레이어는 `radius`에 스케일.

## 4. 블렌드 의도 분리 (빛=ADD, 실체=MIX)

- backplate / arc: writhe-ember(`render_mode blend_add`) = **빛**.
- particles: additive `CanvasItemMaterial` = **빛**.
- core: `material=null` 기본 **MIX** Sprite2D(backplate 텍스처 중심부 재사용) = **실체**.

## 5. Intensity 엔벨로프 (Tween — 라이브 배선 시)

호스트는 `intensity`를 받아 알파/셰이더 intensity/파티클 색을 구동한다. 라이브에서:
- **개시(charge)**: `intensity = charge_size`가 0→1로 자라며 backplate/arc/particle이
  자연스럽게 부풀어 오름(별도 Tween 불필요, charge_size가 곧 엔벨로프).
- **발사(wave)**: 발사 순간 `intensity`를 1.0 근처로 튀겼다가(짧은 Tween로 pop) 유지.
  Codex 배선 시 `Tween`으로 발사 pop(≈0.12s ease-out) + 소멸 fade(≈0.2s)를 권장.
- **종료**: 웨이브 clear/차징 취소 시 `sync_state(active=false)` 한 번 → 전 자식 off.

## 6. 파티클

`GPUParticles2D`, ring emission(반경=`radius*0.95`, 내반경=`radius*0.55`), 방사/접선
가속, scale/fade, additive, `local_coords`, `fixed_fps=30`, `visibility_rect` 컬링,
`quality_scale < 0.55`면 emit off(LOD).

## 7. 회귀 가드 (반드시 유지)

- [x] **별도 `_draw` 셰이더 패스 없음** → `draw_set_transform`+IDENTITY 트랩 원천 회피.
  각 Sprite2D가 자기 ShaderMaterial을 들고 노드가 transform 처리(1-노드-1-머티리얼).
  ([feedback_godot_draw_set_transform_trap])
- [x] **좌표** = `game_offset + (playfield_pos+shake)*render_scale`, 사이즈 `*render_scale`.
  호스트 position/scale로 구현(FX host child 규약). ([feedback_fx_host_world_pos_formula])
- [x] **평면 스프라이트 가짜 3D 금지** — 순수 2D 발광/가산 합성, 탑라이팅 흉내 없음.
  ([feedback_godot_25d_flat_sprite_ceiling])
- [x] **음수 z / 조상 불투명 fill 주의** — 호스트 `z_index=9`(양수), 자식 z 0~3.
  라이브 배선 시 스포너가 조상 z를 넘기지 않는지 픽셀 확인. ([feedback_godot_negative_z_host_ancestor_fill])
- [x] **단일 cleanup** — `set_active(false)` 한 번에 전 자식 off(leak 없음).
- [x] **핫패스 lazy-init 금지** — `prewarm_assets()`가 셰이더+텍스처 프리웜.
  라이브 배선 시 boot/loadout-apply에서 프리웜 호출. ([Godot Hot-Path Lazy Init Trap])

## 8. 남은 배선 (사용자/Codex → Claude 적대리뷰)

1. 배틀 씬에 `SmasherPlasmaFxHost` 인스턴스 추가 + `prewarm_assets()` 프리웜 등록.
2. 플라즈마 렌더 경로에서 매 프레임 `sync_state({...}, phase_active)` 호출:
   차징/웨이브 상태에서 pos(스크린)/radius/intensity/enraged/quality_scale/render_scale 구성.
3. 기존 절차적 `smasher_plasma_state.gd::_draw_charge_field` / `_draw_wave`를
   **은퇴**(또는 저사양 폴백으로만 유지)하고 호스트로 대체.
4. 발사 pop / 소멸 fade `Tween` 엔벨로프 추가(§5).
5. 인게임 픽셀 QA: 차징→발사→소멸, non-enraged vs enraged, LOD 저품질.
6. Claude 적대리뷰 요청.

## 9. 스모크 씰

- `smasher_plasma_fx_host_smoke.gd` — 파이프라인 준비/렌더 에러0/좌표 규약/블렌드 의도
  분리/enraged 스왑/단일 cleanup.
- `smasher_plasma_visual_render_smoke.gd` — 기존 절차적 draw 라이브 실행(폴백 유지 시).
- `smasher_plasma_charge_size_speed_smoke.gd` / `smasher_plasma_parity_smoke.gd` —
  게임플레이(크기/감속/쿨타임/보스 둔화) 불변.
