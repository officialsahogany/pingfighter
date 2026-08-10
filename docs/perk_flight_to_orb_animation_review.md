# 퍽 선택 → 스킬 슬롯 비행 연출 포팅 참고 패킷

**작성일:** 2026-04-19
**최종 갱신:** 2026-04-21 (R2 — 2초 단축 + 코덱스 리뷰 반영)
**현재 대상:** Godot **환격전** (영문 제품명 미정)
**원본 참고 파일:** `pingfighter.py`
**리뷰 목적:** frozen Python/Pygame PingFighter의 "unlock_* 액티브 스킬 퍽 획득 시 오로라 파티클이 좌측 필러 빈 스킬 슬롯으로 날아가는 2초 연출" 구현 리뷰.

이 문서는 레거시 구현 리뷰다. 아래 `pingfighter.py` 라인과 `pygame`
예시는 Godot 포팅의 타이밍 / 좌표계 / 연출 의도 참고로만 사용한다.
새 구현은 `godot/`의 퍽 선택 UI, 스킬 오브 HUD, VFX host, audio owner,
smoke test에 매핑한 뒤 진행한다.

**2026-04-21 R2 갱신 내역 (코덱스 리뷰 반영):**
- **총 길이 3.4s → 2.0s 단축.** 선택→진입 대기 25 frame → 10 frame, 연출 본체 180 frame → 110 frame.
- **도착 클라이맥스 ↔ 실제 흡수 타이밍 동기화 (코덱스 High #1).** 파티클 arrival window 를 `delay(0-5) + flight_dur(35-48)` 로 타이트하게 묶고 (burst 기준 35-53 frame), `PHASE_ARRIVAL_START` 를 62 로 당겨 "약 30% 도착 → 마지막 파티클 융합" 구간에 클라이맥스가 피크치도록 재설계.
- **도착 후 fadeout 완화 (20/frame → 6/frame).** 초기 도착분도 클라이맥스 내내 잔광으로 유지되어 "증발" 인상 제거.
- **슬롯에 꽂히는 코어 오브 비트 신설 (코덱스 High #2).** 타겟 좌표에 `perk_color` 코어 + 화이트 림이 cubic ease-out 으로 성장해 icon_radius (~21px) 근처에 안착 → "새 오브가 슬롯에 맺힌다" 는 촉각적 마무리.
- **퍽 정체성 강화 (코덱스 Med #5).** Burst 림 2겹, Portal 링, Arrival ring2, 코어 오브 모두 `perk_color` 우선 사용. 폴백은 기존 오로라 톤.
- 라인 번호 전반 재산정 (파일 크기 증가에 따른 시프트).

**2026-04-21 R1 갱신 (이전 반영분):**
- 사운드 효과 (`sounds/itemget.wav`), 저사양 폴백 (100/40 파티클), `src_real_*/tgt_real_*` 네이밍, 비네트 cap 180 하향, `perk_color` palette head+tail 3회 삽입, QUIT 실제 종료, pillar/gauge size 가드, 바이퍼 unlock 퍽 3종 추가 반영.

---

## 1. 요구사항 (사용자 명세)

1. 퍽 선택 화면에서 **캐릭터 전용 액티브 스킬 해금 퍽** (`unlock_*` 류) 선택 시에만 연출 발동.
   - 예: 스매셔의 `unlock_cleanse`, `unlock_warp_gate`, 바이퍼의 `double_marshal_kick`(팬텀킥), `unlock_nerve_strike`(EMP strike), `unlock_chaos_spear`, `unlock_ignition_aura` 등.
   - 일반 퍽, 즉시형 퍽(`instant_*`), 골드변환 등은 연출 skip.
2. 화면을 잠시 동결 → 선택된 퍽 카드가 응축된 에너지 구체로 변형 → 오로라 가루 파티클로 분산 → 좌측 필러 배경에 있는 **비어 있는** 스킬 구슬 슬롯으로 흡수 → 슬롯에 코어 오브가 맺혀 안착.
3. 연출 종료 후 해당 슬롯에 획득한 액티브 스킬 구슬이 정상적으로 표시됨 (연출 내부의 맺힌 코어 오브가 이 전환을 시각적으로 brid하는 역할).
4. 총 지속 시간: 약 2초 (110 frame 연출 @ 60fps + 10 frame 사전 대기 ≒ 120 frame ≒ 2.0s).

---

## 2. 전체 데이터 흐름

```
show_runtime_skill_choices()  [blocking loop, 60fps]
  ├─ user selects perk (mouse click / ENTER)
  ├─ phase = "selected", frame_count = 0
  ├─ frame_count > 25 후:
  │     ├─ _resolve_unlock_perk_slot_target(perk_id, char)  → (real_x, real_y) or None
  │     └─ None 이 아니면:
  │           _play_perk_flight_to_orb_effect(SCREEN, card_rect, target, color, id)
  │           ↑ 이 안에서 자체 180-frame blocking 루프 실행, REAL_SCREEN 에 직접 그림
  ├─ active = False → loop 종료
  └─ apply_runtime_skill_effect(perk_id)
        └─ unlock_*_skill() + equip_*_skill() → 슬롯에 새 스킬 등록
            (다음 메인 루프 frame 에서 _draw_*_skill_icons 가 새 구슬을 렌더)
```

**핵심 타이밍 가정:** 연출은 `apply_runtime_skill_effect` 이전에 끝나야 한다. 즉 연출 중에 캡처한 `_player_gauge_surface_left` 스냅샷에는 아직 타겟 슬롯이 비어 있으며, 연출 종료 후 메인 루프가 재개될 때 비로소 새 스킬 구슬이 그려진다.

---

## 3. 관련 코드 위치 요약

| 역할 | 경로 | 라인 |
|---|---|---|
| 훅 사이트 (selected phase 종료 분기) | `pingfighter.py` | 27274-27292 |
| unlock_* 퍽 매핑 (기존 상수, 재사용) | `pingfighter.py` | 22529 (`_CHARACTER_UNLOCK_PERKS`) |
| 캐릭터별 매핑 조회 helper | `pingfighter.py` | 22550 (`_get_character_unlock_perks`) |
| 슬롯 타겟 resolver | `pingfighter.py` | 28616 (`_resolve_unlock_perk_slot_target`) |
| 애니메이션 함수 | `pingfighter.py` | 28674 (`_play_perk_flight_to_orb_effect`) |
| 스매셔 스킬 아이콘 렌더 (각도 기준 원본) | `pingfighter.py` | 7027 (`_draw_smasher_skill_icons`) |
| 바이퍼 스킬 아이콘 렌더 (각도 기준 원본) | `pingfighter.py` | 7221 (`_draw_viper_skill_icons`) |
| 패턴 참조 (기존 연출) | `pingfighter.py` | `_play_megingjord_activation_effect` (메긴교르드 75-frame 번개 연출) |

---

## 4. 렌더링 파이프라인 배경 (필수 컨텍스트)

PingFighter는 **SCREEN ≠ REAL_SCREEN** 아키텍처를 사용한다:

- `SCREEN`: 내부 오프스크린 버퍼. `pygame.Surface((WIDTH, HEIGHT))` = 760×750.
  - 모든 게임 로직/UI 는 이 버퍼에 그려진다.
- `REAL_SCREEN`: 실제 디스플레이 surface. `pygame.display.set_mode(..., SCALED)` 의 리턴값.
  - 보통 REAL_SCREEN 이 더 크며, 좌우로 **필러 배경** 영역이 있다.
  - 좌측 필러에는 `_player_gauge_surface_left` (플레이어 게이지 + 5구슬 스킬 HUD) 가 블릿된다.

**모듈 초기화 시 `pygame.display.flip` 이 monkey-patch 된다** (`_fullscreen_flip` / `_windowed_flip`). `_original_flip = pygame.display.flip` 로 진짜 flip 이 보존되어 있다. monkey-patched flip 은 매 호출마다:
1. 필러 배경 캐시(`_pillar_bg_cache`)를 REAL_SCREEN 에 blit
2. SCREEN 을 `(GAME_OFFSET_X, GAME_OFFSET_Y)` 에 blit (scale 적용)
3. `_draw_pillar_ui` 등으로 `_player_gauge_surface_left` 를 REAL_SCREEN 에 blit
4. `_original_flip()` swap

### 파티클이 게임 영역 경계를 넘어야 하는 이유

사용자가 선택한 퍽 카드는 SCREEN 좌표계(0..760) 에 있고, 좌측 필러의 스킬 구슬은 REAL_SCREEN 좌측의 필러 영역에 있다. SCREEN 에만 그리면 파티클이 `x=0` 에서 잘려 필러 구슬에 도달하지 못한다.

**해결책:** 연출 중에는 SCREEN 이 아니라 **REAL_SCREEN 에 직접 그린다.** 그리고 파이프라인이 REAL_SCREEN 을 다시 덮어쓰지 않도록 monkey-patched flip 을 우회하고 `_original_flip()` 만 호출한다.

### 좌표 변환

```python
scale = GAME_SCALE_FACTOR  # SCALED 윈도우 모드에선 1.0, 전체화면 폴백에선 >1
src_real_x = GAME_OFFSET_X + card_center_x_in_SCREEN * scale
src_real_y = GAME_OFFSET_Y + card_center_y_in_SCREEN * scale

# 좌측 필러 surface 내부 (local 좌표):
orb_local_x = gauge_w // 2
orb_local_y = gauge_h - 55 - 15          # orb_radius_base(55) + 하단 여백(15)
slot_local_x = orb_local_x + cos(angle) * (55 + 21 + 18)   # orb_radius + icon_radius + 간격
slot_local_y = orb_local_y + sin(angle) * (55 + 21 + 18)

pillar_pos = _player_gauge_surface_left_screen_pos
tgt_real_x = pillar_pos[0] + slot_local_x * scale
tgt_real_y = pillar_pos[1] + slot_local_y * scale
```

### 캐릭터별 슬롯 각도

| 캐릭터 | base_angle | step | MAX | equipped 조회 |
|---|---|---|---|---|
| smasher | 165° | 30° | 5 | `get_smasher_equipped_skills()` |
| viper | 155° | 28° | 5 | `get_viper_equipped_skills()` |
| soldier | — | — | — | 현재 연출 미지원 (5구슬 구조 다름) |
| blacksmith | — | — | 1 (hammer_shock) | 연출 미지원 |
| optimus | — | — | — | 5구슬 시스템 없음 |

---

## 5. 5-페이즈 타임라인 (총 110 frame @ 60fps ≒ 1.83s, + 선행 대기 10 frame → 2.0s)

| 페이즈 | frame 범위 | 내용 |
|---|---|---|
| **Freeze** | 0–4 | 배경 동결, 선택 카드 테두리 하이라이트 펄스 (짧은 click-confirm 비트) |
| **Compress** | 5–19 | 카드가 중심으로 85% 수축. 배경 응축 글로우 3겹 circle. 카드가 `_aurora_palette[0]` 색 에너지 큐브로 변형 |
| **Burst** | 20 (단발) | 파티클 생성 (기본 100개, 저사양 40개) + 흰색 플래시 원 + **퍽 색 림 2겹** (68px border 4, 92px border 2). Quadratic Bezier (src → midpoint → target) |
| **Flight** | 20–73 | 파티클이 곡선 따라 이동. Trail 최대 8점. 도착한 파티클은 `arrived_time * 6` 으로 fadeout (약 42 frame, 클라이맥스 내내 잔광). 동시에 타겟 지점에 3중 링 "흡수 포털" (color = perk_color) |
| **Arrival + Orb Materialize** | 62–109 | 타겟 슬롯에 2중 확산 링 (흰색 + perk_color) + **cubic ease-out 으로 성장하는 코어 오브** (6→21px, perk_color 바디 + 화이트 하이라이트 림) → "꽂히는 손맛" |

파티클 arrival window:
- 최빠른 도착: burst(20) + delay(0) + flight_dur(35) = frame **55**
- 최늦은 도착: burst(20) + delay(5) + flight_dur(48) = frame **73**
- `PHASE_ARRIVAL_START = 62` → 약 30% 도착 시점에 클라이맥스 점화, 마지막 파티클이 포털로 흡수될 때 orb 성장 피크.
- fadeout 6/frame 이라 frame 55 도착분도 frame 55+42=97 까지 잔광 유지 → 클라이맥스 (62–109) 의 초반 35 frame 동안 잔광 풀 유지.

각 파티클 개별 속성:
- `delay`: 0–5 frame (burst 후 지연 출발, staggered feel)
- `flight_dur`: 35–48 frame
- `base_size`: 1.8–4.8 × `max(1, scale)`
- `cx, cy`: src 와 tgt 사이 중간 제어점 (Y 는 위로 20–200px 솟은 활 모양)
- `color`: perk icon_color 가 강하게 섞인 `_aurora_palette` 에서 랜덤 선택
- `arrived`, `arrived_time`: 도착 시 True, 이후 매 frame +1 → 알파 6/frame 감소

**비네트:** 게임 영역(`GAME_OFFSET_X..+GAME_SCALED_WIDTH`) 에만 검은 오버레이 적용.
- frame < 20: alpha `min(60, frame*3)`  (카드가 보이는 동안 부드러운 어둠)
- frame ≥ 20: alpha `min(180, 60 + (frame-20)*3)`  (frame 60 에 180 도달 → 클라이맥스 직전 포화)

필러 영역은 비네트를 적용하지 않아 타겟 슬롯이 선명하게 유지된다.

**사운드:** 연출 시작 시 `sounds/itemget.wav` 1회 재생 (`pygame.mixer.Sound(...).play()`). 실패 시 조용히 통과.

---

## 6. 전체 코드

### 6-1. 훅 사이트 (`show_runtime_skill_choices` 내, line 27274-27292)

```python
# Selected animation - exit after delay
elif phase == "selected":
    if frame_count > 10:
        # unlock_* 액티브 스킬 퍽일 때만 오로라 비행 연출 (스매셔/바이퍼)
        try:
            _tgt_real = _resolve_unlock_perk_slot_target(
                selected_result, character_type
            )
            if _tgt_real is not None:
                _sel_rect = card_rects[selected_index] if 0 <= selected_index < len(card_rects) else None
                _sel_color = None
                if 0 <= selected_index < len(choices):
                    _sel_color = choices[selected_index].get("icon_color")
                _play_perk_flight_to_orb_effect(
                    SCREEN, _sel_rect, _tgt_real, _sel_color, selected_result
                )
        except Exception:
            pass
        active = False
```

`character_type` 은 동일 함수 상단에서 `selected_character_type` 으로 이미 세팅됨. `selected_result` 는 선택된 choice dict 의 `"id"` 필드 (예: `"unlock_plasma"`).

### 6-2. `_CHARACTER_UNLOCK_PERKS` (line 22529, 기존 상수 재사용)

```python
_CHARACTER_UNLOCK_PERKS = {
    "smasher": {
        "unlock_magnum_grip": "magnum_grip",
        "unlock_plasma": "plasma",
        "unlock_recovery_skill": "recovery",
        "unlock_cleanse": "cleanse",
        "unlock_ghost_shot": "ghost_shot",
        "unlock_warp_gate": "warp_gate",
    },
    "viper": {
        "unlock_nerve_strike": "nerve_strike",
        "unlock_dive_strike": "dive_strike",
        "unlock_chaos_spear": "chaos_spear",
        "unlock_ignition_aura": "ignition_aura",
        "double_marshal_kick": "phantom_kick",
        "dark_blade": "dark_blade",
        "core_flip": "core_flip",
    },
}


def _get_character_unlock_perks(character_type: str) -> dict:
    return _CHARACTER_UNLOCK_PERKS.get(character_type, {})
```

> 바이퍼의 `double_marshal_kick`, `dark_blade`, `core_flip` 처럼 `unlock_` 접두 없이도 연출 대상이 되는 퍽이 있다는 점에 주의. 이 상수는 **연출 발동 화이트리스트**이자, 퍽 id ↔ 실제 액티브 스킬 id 매핑표 역할도 겸한다.

### 6-3. `_resolve_unlock_perk_slot_target` (line 28616)

```python
def _resolve_unlock_perk_slot_target(perk_id, character_type):
    """unlock_* 류(액티브 스킬 해금) 퍽의 타겟 스킬 슬롯 REAL_SCREEN 좌표를 반환.

    - `_CHARACTER_UNLOCK_PERKS` 에 등록되지 않은 퍽이면 None → 연출 skip.
    - 스매셔/바이퍼는 equipped_skills 개수 = 새 스킬이 들어갈 슬롯 인덱스.
    - 슬롯이 가득 차 있으면 스왑 대상이 모호하므로 None 반환 (swap 다이얼로그에 맡김).
    - 5구슬 시스템이 없는 캐릭터(코만도/발토르/옵티머스)도 None.
    """
    import math as _m
    if not perk_id or not character_type:
        return None
    mapping = _get_character_unlock_perks(character_type)
    if perk_id not in mapping:
        return None

    gauge_surf = globals().get('_player_gauge_surface_left')
    gauge_pos = globals().get('_player_gauge_surface_left_screen_pos')
    if gauge_surf is None or gauge_pos is None:
        return None

    gauge_w = gauge_surf.get_width()
    gauge_h = gauge_surf.get_height()
    if gauge_w <= 0 or gauge_h <= 0:
        return None

    # 스킬 구슬 중심 (gauge_surf local 좌표)
    orb_local_x = gauge_w // 2
    orb_local_y = gauge_h - 55 - 15  # orb_radius_base(55) + 하단 여백(15)
    orb_radius = 55
    icon_radius = 21
    orbit_radius = orb_radius + icon_radius + 18

    # 캐릭터별 슬롯 각도
    if character_type == "smasher":
        slot_idx = len(get_smasher_equipped_skills())
        if slot_idx >= 5:
            return None
        base_angle, step = 165, 30
        angle_deg = base_angle + slot_idx * step
    elif character_type == "viper":
        slot_idx = len(get_viper_equipped_skills())
        if slot_idx >= 5:
            return None
        base_angle, step = 155, 28
        angle_deg = base_angle + slot_idx * step
    else:
        return None

    angle_rad = _m.radians(angle_deg)
    slot_local_x = orb_local_x + _m.cos(angle_rad) * orbit_radius
    slot_local_y = orb_local_y + _m.sin(angle_rad) * orbit_radius

    scale = GAME_SCALE_FACTOR if GAME_SCALE_FACTOR and GAME_SCALE_FACTOR > 0 else 1.0
    real_x = gauge_pos[0] + slot_local_x * scale
    real_y = gauge_pos[1] + slot_local_y * scale
    return (real_x, real_y)
```

### 6-4. `_play_perk_flight_to_orb_effect` (line 28674)

> **R2 주의:** 아래 스니펫은 R2 이후 현재 코드 상태를 반영한다 (110 frame, PHASE_ARRIVAL_START=62, orb materialize, perk_color 확장). 이전 R1 3초 버전과는 타임라인 / 파티클 파라미터 / arrival 섹션이 모두 다르다.

```python
def _play_perk_flight_to_orb_effect(screen, source_rect, target_real_pos, perk_color=None, perk_id=None):
    """퍽 선택 후 오로라 가루로 변해 좌측 필러 스킬 구슬 **빈 슬롯**으로
    날아가는 3초 연출.

    REAL_SCREEN 에 직접 렌더링하여 게임 영역과 좌측 필러를 동시에 합성.
    타겟은 호출자가 `_resolve_unlock_perk_slot_target` 등으로 미리 계산한
    실제 슬롯 좌표를 넘겨야 한다 (애니메이션 도중에는 스킬이 아직 장착되기
    전이므로 슬롯은 비어 보인다).

    Args:
        screen: 호환성용 (현재 미사용; REAL_SCREEN 전역 사용)
        source_rect: 선택된 퍽 카드 rect (SCREEN 내부 좌표)
        target_real_pos: 목표 슬롯 (REAL_SCREEN 좌표, (x, y))
        perk_color: 퍽 아이콘 색상 RGB
        perk_id: 선택된 퍽 id (디버그용)
    """
    import math as _m
    import random as _r

    global REAL_SCREEN

    if source_rect is None or REAL_SCREEN is None or target_real_pos is None:
        return

    scale = GAME_SCALE_FACTOR if GAME_SCALE_FACTOR and GAME_SCALE_FACTOR > 0 else 1.0
    real_w, real_h = REAL_SCREEN.get_size()

    # ── SFX (획득 사운드) ──
    try:
        _sound = pygame.mixer.Sound(resource_path("sounds/itemget.wav"))
        _sound.play()
    except Exception:
        pass

    # ── 프리즈 스냅샷 합성 (pillars + game SCREEN + 좌측 필러 UI) ──
    snapshot = pygame.Surface((real_w, real_h)).convert()
    snapshot.fill((15, 15, 25))
    # 필러 배경 (캐시, size 0 방어)
    _pb_cache = globals().get('_pillar_bg_cache')
    if _pb_cache is not None:
        try:
            if _pb_cache.get_width() > 0 and _pb_cache.get_height() > 0:
                snapshot.blit(_pb_cache, (0, 0))
        except Exception:
            pass
    # 게임 영역 (SCREEN)
    try:
        if scale != 1.0 and GAME_SCALED_WIDTH > 0 and GAME_SCALED_HEIGHT > 0:
            _game_scaled = pygame.transform.scale(SCREEN, (GAME_SCALED_WIDTH, GAME_SCALED_HEIGHT))
            snapshot.blit(_game_scaled, (GAME_OFFSET_X, GAME_OFFSET_Y))
        else:
            snapshot.blit(SCREEN, (GAME_OFFSET_X, GAME_OFFSET_Y))
    except Exception:
        pass
    # 좌측 필러 gauge surface (스킬 구슬 포함)
    gauge_surf = globals().get('_player_gauge_surface_left')
    gauge_pos = globals().get('_player_gauge_surface_left_screen_pos') or (0, 0)
    pillar_x_left = int(gauge_pos[0])
    pillar_y_left = int(gauge_pos[1])
    gauge_w = gauge_h = 0
    if gauge_surf is not None:
        gauge_w = gauge_surf.get_width()
        gauge_h = gauge_surf.get_height()
        if gauge_w > 0 and gauge_h > 0:
            try:
                if scale != 1.0:
                    _sgw = max(1, int(gauge_w * scale))
                    _sgh = max(1, int(gauge_h * scale))
                    _sgauge = pygame.transform.scale(gauge_surf, (_sgw, _sgh))
                    snapshot.blit(_sgauge, (pillar_x_left, pillar_y_left))
                else:
                    snapshot.blit(gauge_surf, (pillar_x_left, pillar_y_left))
            except Exception:
                pass

    # ── 좌표 변환: SCREEN(내부) → REAL_SCREEN ──
    src_real_x = float(GAME_OFFSET_X + source_rect.centerx * scale)
    src_real_y = float(GAME_OFFSET_Y + source_rect.centery * scale)
    src_w = max(6, int(source_rect.width * scale))
    src_h = max(6, int(source_rect.height * scale))

    # 타겟 슬롯 좌표 (REAL_SCREEN)
    try:
        tgt_real_x = float(target_real_pos[0])
        tgt_real_y = float(target_real_pos[1])
    except Exception:
        return

    # 오로라 팔레트 (퍽 색상을 head + tail 에 중복 삽입해 확률 가중)
    _aurora_palette = [
        (140, 220, 255),
        (180, 140, 255),
        (120, 255, 200),
        (255, 180, 220),
        (255, 230, 140),
    ]
    if perk_color and len(perk_color) >= 3:
        try:
            _pc = (
                max(0, min(255, int(perk_color[0]))),
                max(0, min(255, int(perk_color[1]))),
                max(0, min(255, int(perk_color[2]))),
            )
            _aurora_palette.insert(0, _pc)       # core_color 용 (index 0)
            _aurora_palette.extend([_pc, _pc])   # random.choice 가중치 ↑
        except Exception:
            pass

    _particles = []
    _burst_done = False
    _overlay = pygame.Surface((real_w, real_h), pygame.SRCALPHA)
    _clock = pygame.time.Clock()
    _duration = 110

    PHASE_COMPRESS_START = 5
    PHASE_BURST_START = 20
    PHASE_ARRIVAL_START = 62

    for frame in range(_duration):
        REAL_SCREEN.blit(snapshot, (0, 0))
        _overlay.fill((0, 0, 0, 0))

        # ── 게임 영역 비네트: 버스트 이후 강화해 카드 UI 를 가림 ──
        if frame < PHASE_BURST_START:
            vignette_alpha = min(60, frame * 3)
        else:
            _bf = frame - PHASE_BURST_START
            vignette_alpha = min(180, 60 + _bf * 3)
        if vignette_alpha > 0 and GAME_SCALED_WIDTH > 0 and GAME_SCALED_HEIGHT > 0:
            pygame.draw.rect(
                _overlay,
                (5, 5, 15, vignette_alpha),
                (GAME_OFFSET_X, GAME_OFFSET_Y, GAME_SCALED_WIDTH, GAME_SCALED_HEIGHT),
            )

        # ─────────────── Compress ───────────────
        if frame < PHASE_BURST_START:
            if frame < PHASE_COMPRESS_START:
                pulse = 0.5 + 0.5 * _m.sin(frame * 0.5)
                hl_alpha = int(90 + 100 * pulse)
                hl_rect = pygame.Rect(
                    int(src_real_x - src_w // 2 - 5),
                    int(src_real_y - src_h // 2 - 5),
                    src_w + 10, src_h + 10,
                )
                pygame.draw.rect(_overlay, (255, 255, 255, hl_alpha), hl_rect, 3, border_radius=10)
            else:
                ct = (frame - PHASE_COMPRESS_START) / max(1, (PHASE_BURST_START - PHASE_COMPRESS_START))
                ct = max(0.0, min(1.0, ct))
                ease = ct * ct
                shrink = 1.0 - 0.85 * ease
                cur_w = max(6, int(src_w * shrink))
                cur_h = max(6, int(src_h * shrink))
                cur_rect = pygame.Rect(0, 0, cur_w, cur_h)
                cur_rect.center = (int(src_real_x), int(src_real_y))
                for layer in range(3):
                    la = int(140 * (1 - layer / 3.5))
                    gr = int(max(cur_w, cur_h) * (0.9 + 0.35 * _m.sin(frame * 0.35))) + layer * 10
                    pygame.draw.circle(_overlay, (180, 220, 255, max(0, la)),
                                       (int(src_real_x), int(src_real_y)), gr)
                core_color = _aurora_palette[0]
                pygame.draw.rect(_overlay, (*core_color, 230), cur_rect, border_radius=6)
                pygame.draw.rect(_overlay, (255, 255, 255, 230), cur_rect, 2, border_radius=6)

        # ─────────────── Burst ───────────────
        if frame >= PHASE_BURST_START and not _burst_done:
            _burst_done = True
            try:
                num_particles = 40 if _adaptive_performance_enabled() else 100
            except Exception:
                num_particles = 100
            _part_size_scale = max(1.0, scale)
            for _ in range(num_particles):
                angle = _r.uniform(0, _m.pi * 2)
                launch_speed = _r.uniform(1.2, 4.2)
                mid_x = (src_real_x + tgt_real_x) * 0.5 + _r.uniform(-140 * scale, 140 * scale)
                mid_y = min(src_real_y, tgt_real_y) - _r.uniform(20 * scale, 200 * scale)
                color = _r.choice(_aurora_palette)
                _particles.append({
                    "x": src_real_x + _m.cos(angle) * 6,
                    "y": src_real_y + _m.sin(angle) * 6,
                    "vx": _m.cos(angle) * launch_speed,
                    "vy": _m.sin(angle) * launch_speed,
                    "cx": mid_x,
                    "cy": mid_y,
                    "t": 0.0,
                    "delay": _r.randint(0, 5),
                    "flight_dur": _r.randint(35, 48),
                    "base_size": _r.uniform(1.8, 4.8) * _part_size_scale,
                    "color": color,
                    "trail": [],
                    "arrived": False,
                })
            pygame.draw.circle(_overlay, (255, 255, 255, 230),
                               (int(src_real_x), int(src_real_y)), int(48 * scale))
            _burst_rim = perk_color if perk_color and len(perk_color) >= 3 else (220, 240, 255)
            pygame.draw.circle(_overlay, (*_burst_rim[:3], 220),
                               (int(src_real_x), int(src_real_y)), int(68 * scale), 4)
            pygame.draw.circle(_overlay, (*_burst_rim[:3], 150),
                               (int(src_real_x), int(src_real_y)), int(92 * scale), 2)

        # ─────────────── Flight ───────────────
        if frame >= PHASE_BURST_START:
            flight_frame = frame - PHASE_BURST_START
            for p in _particles:
                if flight_frame < p["delay"]:
                    p["x"] += p["vx"]
                    p["y"] += p["vy"]
                    p["vx"] *= 0.88
                    p["vy"] *= 0.88
                    sz = max(1, int(p["base_size"] * 0.9))
                    pygame.draw.circle(_overlay, (*p["color"], 200),
                                       (int(p["x"]), int(p["y"])), sz)
                    continue
                p["t"] += 1.0 / p["flight_dur"]
                pt = min(1.0, p["t"])
                ease = pt * pt * (3 - 2 * pt)
                u = 1.0 - ease
                bx = u * u * src_real_x + 2 * u * ease * p["cx"] + ease * ease * tgt_real_x
                by = u * u * src_real_y + 2 * u * ease * p["cy"] + ease * ease * tgt_real_y
                p["trail"].append((bx, by))
                if len(p["trail"]) > 8:
                    p["trail"].pop(0)
                p["x"] = bx
                p["y"] = by
                tlen = len(p["trail"])
                for ti, (tx_, ty_) in enumerate(p["trail"][:-1]):
                    ta = int(55 * (ti + 1) / tlen)
                    ts = max(1, int(p["base_size"] * 0.55 * (ti + 1) / tlen))
                    pygame.draw.circle(_overlay, (*p["color"], ta),
                                       (int(tx_), int(ty_)), ts)
                brightness = 0.7 + 0.3 * ease
                alpha = int(255 * brightness)
                size = max(1, int(p["base_size"] * (1.0 - 0.3 * ease)))
                pygame.draw.circle(_overlay, (*p["color"], alpha),
                                   (int(bx), int(by)), size)
                # 도착 전까지만 highlight core
                if size > 2 and not p.get("arrived"):
                    pygame.draw.circle(_overlay, (255, 255, 255, min(255, alpha + 30)),
                                       (int(bx), int(by)), max(1, size - 1))
                if pt >= 1.0:
                    if not p.get("arrived"):
                        p["arrived"] = True
                        p["arrived_time"] = 0
                if p.get("arrived"):
                    p["arrived_time"] = p.get("arrived_time", 0) + 1
                    fade = max(0, 255 - p["arrived_time"] * 6)
                    if fade > 0:
                        pygame.draw.circle(_overlay, (*p["color"], fade), (int(bx), int(by)), max(1, size))

        # ─────────────── Target portal (좌측 구슬 흡수 지점) ───────────────
        if frame >= PHASE_BURST_START:
            flight_t = min(1.0, (frame - PHASE_BURST_START) / 55.0)
            arrived_count = sum(1 for p in _particles if p.get("arrived"))
            absorb = (arrived_count / max(1, len(_particles))) if _particles else 0.0
            portal_pulse = 0.5 + 0.5 * _m.sin(frame * 0.28)
            portal_r = int((32 + 14 * portal_pulse + 50 * absorb) * scale)
            portal_a = max(0, min(255, int(90 + 120 * flight_t + 60 * absorb)))
            _portal_rim = perk_color if perk_color and len(perk_color) >= 3 else (160, 220, 255)
            _portal_core = perk_color if perk_color and len(perk_color) >= 3 else (220, 240, 255)
            for ring in range(3):
                rr = portal_r + int(ring * 12 * scale)
                aa = max(0, portal_a - ring * 55)
                pygame.draw.circle(_overlay, (*_portal_rim[:3], aa),
                                   (int(tgt_real_x), int(tgt_real_y)), rr, 2)
            pygame.draw.circle(_overlay, (*_portal_core[:3], min(255, int(portal_a * 0.7))),
                               (int(tgt_real_x), int(tgt_real_y)), max(6, int(portal_r * 0.45)))

        # ─────────────── Arrival flash + orb materialization ───────────────
        if frame >= PHASE_ARRIVAL_START:
            af = (frame - PHASE_ARRIVAL_START) / max(1, (_duration - PHASE_ARRIVAL_START))
            af = max(0.0, min(1.0, af))
            # 확산 링 2겹
            ring_r = int((40 + 180 * af) * scale)
            ring_a = int(230 * (1.0 - af))
            pygame.draw.circle(_overlay, (255, 255, 255, ring_a),
                               (int(tgt_real_x), int(tgt_real_y)), ring_r, max(1, int(4 * (1.0 - af))))
            ring2_r = int((20 + 120 * af) * scale)
            ring2_a = int(200 * (1.0 - af))
            _ring2_color = perk_color if perk_color and len(perk_color) >= 3 else (255, 220, 140)
            pygame.draw.circle(_overlay, (*_ring2_color[:3], ring2_a),
                               (int(tgt_real_x), int(tgt_real_y)), ring2_r, max(1, int(3 * (1.0 - af))))
            # 슬롯에 맺히는 코어 오브 (cubic ease-out 로 icon_radius 근처까지 성장 → "꽂히는 손맛")
            _orb_rise = 1.0 - (1.0 - af) ** 3
            _orb_r = max(3, int((6 + 15 * _orb_rise) * scale))
            _orb_col = perk_color if perk_color and len(perk_color) >= 3 else _aurora_palette[0]
            pygame.draw.circle(_overlay, (*_orb_col[:3], int(120 * _orb_rise)),
                               (int(tgt_real_x), int(tgt_real_y)), int(_orb_r * 1.8))
            pygame.draw.circle(_overlay, (*_orb_col[:3], min(255, int(230 * _orb_rise))),
                               (int(tgt_real_x), int(tgt_real_y)), _orb_r)
            pygame.draw.circle(_overlay, (255, 255, 255, int(230 * _orb_rise)),
                               (int(tgt_real_x), int(tgt_real_y)), max(1, _orb_r - 2), 2)

        REAL_SCREEN.blit(_overlay, (0, 0))
        # monkey-patched flip 은 REAL_SCREEN 을 재합성하므로 original flip 로 swap 만 수행
        try:
            _original_flip()
        except Exception:
            pygame.display.flip()
        _clock.tick(60)
        for _evt in pygame.event.get():
            if _evt.type == pygame.QUIT:
                try:
                    pygame.quit()
                    import sys
                    sys.exit(0)
                except Exception:
                    pass
```

---

## 7. 기존 패턴과의 비교

`show_runtime_skill_choices` 함수는 이미 유사한 blocking cinematic 을 하나 호출한다: `_play_megingjord_activation_effect(SCREEN)` (퍽 선택 후 메긴교르드 발동 시 번개/파티클 75-frame 연출). 새 연출은 이 구조를 참고했지만 한 가지 핵심 차이:

- **메긴교르드 연출은 SCREEN 에 그리고 `pygame.display.flip()` (monkey-patched) 호출.** SCREEN 에 그린 내용을 flip 이 REAL_SCREEN 에 합성하며 필러가 자동으로 유지된다.
- **새 연출은 REAL_SCREEN 에 직접 그리고 `_original_flip()` 호출.** 필러 재합성을 우회해야 우리가 그린 파티클/오버레이가 덮어씌워지지 않기 때문이다.

이 차이로 인해 스냅샷을 수동 합성하고 (`_pillar_bg_cache` + `SCREEN` + `_player_gauge_surface_left`) 매 프레임 snapshot 을 REAL_SCREEN 에 blit 후 overlay 를 덮는다.

---

## 8. 알려진 엣지 케이스 / 설계 결정

### 8-1. 슬롯 가득(5/5) 상황
`_resolve_unlock_perk_slot_target` 은 slot 이 가득 차면 `None` 반환 → 연출 skip. 이유: `apply_runtime_skill_effect` 가 swap 다이얼로그(`_show_*_skill_swap_dialog`)로 빠지며 새 스킬이 어느 기존 슬롯을 대체할지 연출 시점에 결정 불가. 다이얼로그 경로는 별도 UI 고, 스왑 성공 후엔 연출이 없다 (개선 여지 있음).

### 8-2. 튜토리얼 플로우 (`_tutorial_waiting_runtime_skill_select`)
훅 사이트는 `phase == "selected"` 시점에 실행되므로 튜토리얼 모드도 동일하게 연출이 발동한다. `unlock_plasma` 가 튜토리얼 고정 선택지 중 하나이므로 첫 획득 시에도 연출이 재생됨. 블로킹 루프라 튜토리얼 프로그레스에는 영향 없지만, 입력은 3초간 받지 않는다.

### 8-3. AI 플레이 모드 (`player_ai_enabled`)
AI 모드는 `show_runtime_skill_choices` 진입 즉시 `apply_runtime_skill_effect` 호출하고 리턴하므로 연출이 아예 실행되지 않는다. 의도된 동작.

### 8-4. 메긴교르드 후속 선택 (추가 퍽 기회)
`apply_runtime_skill_effect` 후 메긴교르드가 장착되어 있으면 `_play_megingjord_activation_effect(SCREEN)` 가 이어서 재생되고 `pending_skill_choices += 1` 되어 `show_runtime_skill_choices` 가 루프된다. 두 번째 퍽이 또 `unlock_*` 이면 또다시 3초 비행 연출이 재생된다. (의도된 동작.)

### 8-5. `apply_runtime_skill_effect` 실패 재귀
`apply_runtime_skill_effect` 가 False 반환 시 `show_runtime_skill_choices` 가 재귀 호출되어 동일 choices 로 다시 뜬다. 이 때 이미 연출은 끝났고, 사용자가 다시 선택하면 다시 연출이 재생된다. (실패 경로가 드물다고 가정 — 허용 가능.)

### 8-6. scale ≠ 1.0 (전체화면 폴백 모드)
전체화면 폴백 모드에서 `GAME_SCALE_FACTOR > 1.0`. 파티클 크기, 포털 반경, arrival flash 반경은 모두 `* scale` 로 곱해져 스케일 대응. 다만 속도(`launch_speed`, `flight_dur`)는 스케일 독립 → 시각적으로 동일한 체감 속도를 유지.

### 8-7. Viper orb drag 중 연출 실행
`_draw_viper_skill_icons` 내 `_viper_orb_dragging` 로직은 스냅샷 시점의 `_player_gauge_surface_left` 에 이미 반영됨. 하지만 퍽 선택 창이 떠 있는 동안 드래그가 일어날 가능성은 낮음. 엣지 케이스로 남겨 둠.

### 8-8. `unlock_` 접두가 없는 퍽 id (viper 전용 어휘 편차)
바이퍼의 `double_marshal_kick`, `dark_blade`, `core_flip` 는 이름 자체가 스킬명이지만 `_CHARACTER_UNLOCK_PERKS["viper"]` 에는 포함되어 연출이 발동된다. 즉 "이름에 `unlock_` 이 있으면 연출" 이 아니라 **`_CHARACTER_UNLOCK_PERKS` 에 등록되었는지**가 유일한 판단 기준. 향후 신규 퍽 추가 시 이 상수에 넣지 않으면 silently skip.

---

## 9. 성능 고려

- 파티클 기본 100개 / 저사양 40개, 110 frame, 매 프레임:
  - `_overlay.fill((0,0,0,0))` — SRCALPHA clear (2.3MB)
  - 파티클 × (trail 8 + body + highlight) 당 `pygame.draw.circle` 호출
  - 타겟 포털 3 ring + center
  - Arrival phase (frame 62+) 에서 코어 오브 3겹 (glow + core + rim)
  - `REAL_SCREEN.blit(snapshot, (0,0))` — 프레임당 full-screen blit
- CLAUDE.md 성능 가이드에 따르면 `Surface(..., SRCALPHA)` 루프 내 생성은 금지, 하지만 본 코드는 **루프 밖에서 overlay 1회 생성** 후 재사용 → OK.
- `pygame.transform.scale(SCREEN, ...)` 는 스냅샷 빌드 시 1회만 호출됨 (루프 밖) → OK.
- 전체 연출 2초 동안 게임 로직은 멈춰있음 (blocking loop) — 플레이어는 퍽 선택 직후라 게임 상태 진행 없음 — OK.
- `_adaptive_performance_enabled()` True 일 때 파티클 수만 40 으로 낮춤. 타임라인 / 포털 / flash / 코어 오브는 동일 → 저사양 환경에서도 실루엣은 유지.
- R2 단축으로 총 frame 수가 180 → 110 으로 줄어 총 드로우 비용도 약 39% 감소.

---

## 9-B. 코덱스 리뷰 대응 (2026-04-21)

| # | 코덱스 지적 | 심각도 | R2 처리 |
|---|---|---|---|
| 1 | 도착 클라이맥스(155) vs 실제 흡수(100-157) 어긋남 → 초기 도착분은 클라이맥스 전 증발, 끝은 "늦은 추가 링" | High | ✅ 파티클 window 타이트화 (`delay 0-5 + flight 35-48`, burst 기준 35-53 frame 내 전원 도착), `PHASE_ARRIVAL_START=62` 로 당김, fadeout 20→6/frame 으로 잔광 유지 |
| 2 | 슬롯에 "스킬이 꽂혔다" 감각 없음 — 포털 링 + 플래시만, 실제 오브는 연출 후 메인루프에서 등장 → 흡수보다 소멸 느낌 | High | ✅ Arrival phase 에 cubic ease-out 으로 성장하는 코어 오브 추가 (perk_color 바디 + 화이트 림). 연출 종료 시점의 맺힌 오브 → 메인루프 복귀 시 실제 아이콘이 시각적으로 이어받음 |
| 3 | 체감 정지 3.4s+ — 25 frame 대기 + 180 frame 연출 + 튜토리얼/메긴교르드 체인 시 누적 답답함 | Medium | ✅ 25→10 frame 대기, 180→110 frame 본체 → 총 120 frame ≒ 2.0s |
| 4 | 슬롯 5/5 가득 시 연출 완전 소실 — "가장 중요한 수락 결정 순간" 에 피드백 없음 | Medium | ❌ **별도 제안** — 스왑 다이얼로그 + 전용 "슬롯 교체" 연출은 스코프가 커서 R2 범위 밖. 사용자 결정 후 별건으로 진행 제안 |
| 5 | 출발부가 공용 색 큐브 + 오로라 팔레트 위주 → "새 스킬 획득" 보다 "희귀도 연출" 인상 | Medium | ✅ Burst 림 2겹, Portal 링, Arrival ring2 가 `perk_color` 를 1차 색으로 사용 (폴백만 오로라 톤). 압축 큐브 코어는 기존 `_aurora_palette[0]` (퍽 색 prepend 돼 있으므로 실제로 퍽 색) |
| 6 | 문서 라인 번호 실제 코드와 어긋남 | Low | ✅ R2 기준 재산정 (22529 / 28616 / 28674 / 27274) |

R2 에서 다루지 않은 것:
- **슬롯 5/5 가득 경로의 전용 연출.** 현재 `_resolve_unlock_perk_slot_target` 이 None 을 반환하면 swap 다이얼로그로 직행. 스왑 성공 후 "기존 오브 퇴장 + 새 오브 입장" 연출을 추가하려면 (a) 스왑 다이얼로그의 결과값을 잡아 (b) 연출을 재호출하는 새 훅이 필요. 스코프가 커서 사용자 승인 후 별건 진행 제안.
- **선택 연출 스킵 단축키.** 튜토리얼 / 메긴교르드 체인에서 2번째 이상 연속 재생 시 스킵 입력을 받을지. 현재 2초로 단축됐으므로 우선순위 낮음.

---

## 10. 리뷰어(Gemini) 에게 묻고 싶은 것

1. **REAL_SCREEN 직접 렌더링 + `_original_flip()` 우회 전략이 타당한가?** 더 깨끗한 대안 (예: `_fullscreen_flip` 에 overlay 훅 추가) 이 있는지?
2. **`_pillar_bg_cache` / `_player_gauge_surface_left` 을 스냅샷에 blit 할 때** 가용하지 않은 상태(로딩 중, 스테이지 전환 직후) 에서 `None` 또는 비어 있을 가능성? 지금은 `globals().get(...)` + `width>0/height>0` + `try/except` 로 3중 방어하지만 더 근본적인 가드 필요한지?
3. **비네트 alpha cap 180** 이 카드 UI 를 완전히 가리지는 않는데 (약 frame 75 부터 포화) 이 수준이 적절한지? 이전 210 에서 하향한 이유는 "필러 밝기와의 위화감 완화" 였음.
4. **파티클 수 폴백 (100 → 40)** 이 시각적 임팩트를 충분히 유지하는지? `_adaptive_performance_enabled()` 기준선이 이 연출과 맞는지?
5. **5/5 슬롯 가득 시 연출 없음** 이 맞는 설계인지? 스왑 성공 후 따로 "슬롯 교체" 연출 (기존 구슬 → 퇴장 + 새 구슬 → 입장) 을 주고 싶다면 어느 지점이 적절?
6. **오로라 팔레트 + perk_color 혼합 비중** (`insert(0, _pc) + extend([_pc, _pc])` → 8개 슬롯 중 3개 = 37.5% perk 고유색) 이 적절한지? perk 정체성을 더 강조해야 하는지, 아니면 오로라 톤을 유지해야 하는지?
7. **`arrived_time * 20` fadeout** (13 frame 만에 소멸) 이 적절한 속도인지? 너무 빨라 파티클이 목표에 도달하자마자 사라지는 인상을 주는지?
8. **소리 `itemget.wav` 선택** 이 "스킬 해금" 감각에 맞는지? 기존 메긴교르드 `megin.wav` 같은 전용 효과음이 필요한지?
9. **바이퍼 전용 `unlock_` 접두 없는 퍽 (double_marshal_kick, dark_blade, core_flip)** 의 명명 일관성 — `unlock_phantom_kick`, `unlock_dark_blade`, `unlock_core_flip` 로 리네이밍해야 하는지, 아니면 `_CHARACTER_UNLOCK_PERKS` 화이트리스트 방식을 유지하는지?
10. **QUIT 이벤트 처리** — 현재 연출 중 `QUIT` → `pygame.quit(); sys.exit(0)` 즉시 종료. 저장되지 않은 상태 손실 위험은 없는지 (퍽 획득 직후 = 상태 변화 시점)?

---

## 11. Legacy Python 실행/검증 방법

```bash
# 원본 PingFighter 소스 작업을 명시적으로 요청받은 경우에만 사용
py pingfighter.py

# 1. 튜토리얼 이후 아무 스테이지 진입
# 2. 보스에게 피해 입혀 퍽 선택창 띄우기
# 3. unlock_plasma / unlock_cleanse / unlock_warp_gate / unlock_chaos_spear 중 하나 선택
# 4. 2초간 오로라 비행 연출 + itemget.wav + 슬롯에 맺히는 코어 오브 확인
# 5. 연출 종료 후 좌측 필러의 스킬 구슬 슬롯에 해당 스킬이 맺힌 코어 오브 위에 이어서 뜨는지 확인
```

Current Godot work should instead map this scenario to the Godot perk-choice
UI, skill-orb HUD renderer, VFX host, audio owner, and focused smoke / visual
check before sign-off.

대조군:
- 일반 퍽 (예: `dash_lightweight` 레벨업) 선택 시 연출 없이 기존 flow 그대로.
- 슬롯 5/5 상태에서 신규 `unlock_*` 퍽 선택 시 연출 없이 swap 다이얼로그로 이어짐.
- AI 모드 (`player_ai_enabled = True`) 일 때도 연출 없음.
- 저사양 환경 (`_adaptive_performance_enabled() == True`) 에서 파티클 밀도만 낮아짐, 타임라인 동일.
