# Academy Skill Showcase — Gemini Code Review

## 1. Purpose & Context

`PingFighter`의 광장(Downtown) 아카데미 건물에서, 학장 NPC가 플레이어에게
**액티브 스킬 퍽을 하나 제안**할 때 표시되는 "퍽 소개 쇼케이스"의 렌더링 코드.

### Runtime flow
1. 플레이어가 광장 아카데미 입장 (AP=1 소비, `manager._enter_building`)
2. 학장 NPC 클릭/스페이스바 → 대화창 `"기술을 배우시겠습니까?"`
3. "예" 선택 → `academy.show_academy_menu(...)` 호출 → **이 쇼케이스 모달 루프**
4. 유저가 `[교환하기]` / `[배우기(1000G)]` / `[그만두기]` 선택 후 닫힘

### Technical context
- Python 3 + pygame (+ `pygame.freetype`).
- 모달 루프: `clock.tick(60)`, 매 프레임 전체 재그림.
- 의존 함수: `pf._draw_skill_icon_symbol(surface, skill_name, cx, cy, size, is_active, color)` —
  pingfighter 본체의 HUD용 고퀄리티 스킬 아이콘 렌더러 (각 스킬별 elif 브랜치,
  `is_active=True` 시 내장 idle 애니메이션). 미구현 스킬은 내부적으로
  `draw_skill_icon_mini` 로 폴백 보장.

---

## 2. Inputs (at the showcase block)

```python
# 이미 모달 루프 상단에서 결정된 값들
offered_perk    : str         # 예: "unlock_plasma", "dark_blade"
perk_name       : str         # 한글 표시명, 예: "플라즈마", "다크 블레이드"
perk_desc       : str         # 설명 텍스트 (lv1 descriptions)
perk_color      : tuple       # (R, G, B) 스킬별 대표 색
skill_name      : str         # 실제 스킬 id (예: "plasma"). _draw_skill_icon_symbol 에 넘길 값
slots_full      : bool        # 현재 캐릭터 5구슬 슬롯 가득찼는지

dialog_x, dialog_y, dialog_w, dialog_h  : int  # 대화창 패널 위치 (560 x 480)
content_y       : int         # 현재 content 수직 커서
screen          : pygame.Surface
```

상수:
```python
BG_DARK       = (25, 15, 45)
TEXT_WHITE    = (240, 245, 255)
TEXT_GOLD     = (255, 215, 100)
```

---

## 3. The Showcase Code (academy.py 362–429)

```python
# === 스킬 쇼케이스 (애니메이션 아이콘 + 회전 룬 + 펄스 헤일로 + 궤도 스파클) ===
now_ticks = pygame.time.get_ticks()
t_sec = now_ticks / 1000.0
cx = dialog_x + dialog_w // 2
cy = content_y + 78  # 쇼케이스 중심

# 1) 외곽 소프트 오라 (3단계 그라데이션 원)
aura_pulse = 0.45 + 0.35 * math.sin(t_sec * 1.6)
for i, (r, a) in enumerate([(100, 18), (78, 32), (58, 52)]):
    a = int(a * (0.7 + 0.3 * aura_pulse))
    aura_surf = pygame.Surface((r * 2 + 4, r * 2 + 4), pygame.SRCALPHA)
    pygame.draw.circle(
        aura_surf,
        (*perk_color[:3], max(0, min(255, a))),
        (r + 2, r + 2),
        r,
    )
    screen.blit(aura_surf, (cx - r - 2, cy - r - 2))

# 2) 회전 룬 링 (대시 8개, 천천히 회전)
rune_r = 62
rune_angle = t_sec * 0.6
for k in range(8):
    ang = rune_angle + k * (2 * math.pi / 8)
    rx = cx + int(math.cos(ang) * rune_r)
    ry = cy + int(math.sin(ang) * rune_r)
    # 금색 별 모양 작은 마커
    pygame.draw.circle(screen, TEXT_GOLD, (rx, ry), 3)
    pygame.draw.circle(screen, (255, 255, 230), (rx, ry), 1)

# 3) 내부 펄스 헤일로 (얇은 링, 밝기 맥박)
halo_pulse = 0.5 + 0.5 * math.sin(t_sec * 3.2)
halo_alpha = int(130 + 80 * halo_pulse)
halo_r = 46
halo_surf = pygame.Surface((halo_r * 2 + 6, halo_r * 2 + 6), pygame.SRCALPHA)
halo_color = tuple(min(255, c + 40) for c in perk_color[:3])
pygame.draw.circle(halo_surf, (*halo_color, halo_alpha), (halo_r + 3, halo_r + 3), halo_r, 3)
screen.blit(halo_surf, (cx - halo_r - 3, cy - halo_r - 3))

# 4) 중앙 대형 아이콘 (is_active=True → idle 애니메이션 on)
icon_size = 64
# 배경판 (어두운 원)
pygame.draw.circle(screen, BG_DARK, (cx, cy), 36)
pygame.draw.circle(screen, TEXT_GOLD, (cx, cy), 36, 2)
try:
    pf._draw_skill_icon_symbol(
        screen, skill_name, cx, cy, icon_size, True, perk_color
    )
except Exception:
    # 최악의 폴백: 컬러 원
    pygame.draw.circle(screen, perk_color, (cx, cy), icon_size // 2 - 4)
    pygame.draw.circle(screen, TEXT_WHITE, (cx, cy), icon_size // 2 - 4, 2)

# 5) 궤도 스파클 (4개, 서로 다른 속도/반경)
sparkle_specs = [
    (72, 1.4, 0.0, (255, 240, 160)),
    (58, -1.9, math.pi / 2, (255, 215, 100)),
    (82, 1.1, math.pi, (220, 200, 255)),
    (68, -1.6, math.pi * 1.5, (180, 220, 255)),
]
for (srad, sspd, soffset, scolor) in sparkle_specs:
    sang = t_sec * sspd + soffset
    sx = cx + int(math.cos(sang) * srad)
    sy = cy + int(math.sin(sang) * srad * 0.55)  # 타원 궤도
    # 십자 반짝임
    pygame.draw.line(screen, scolor, (sx - 3, sy), (sx + 3, sy), 1)
    pygame.draw.line(screen, scolor, (sx, sy - 3), (sx, sy + 3), 1)
    pygame.draw.circle(screen, scolor, (sx, sy), 1)

content_y = cy + 52  # 쇼케이스 아래로 진행
```

### Layering (back → front)
| # | Layer | Size | Animation |
|---|---|---|---|
| 1 | 외곽 소프트 오라 (3단 그라데이션) | r=100/78/58 | 1.6 rad/s 펄스 |
| 2 | 회전 룬 링 (금색 별 8개) | r=62 | 0.6 rad/s 회전 |
| 3 | 펄스 헤일로 (얇은 컬러 링) | r=46 | 3.2 rad/s 밝기 맥박 |
| 4 | 아이콘 배경판 (어두운 원 + 금테) | r=36 | 정적 |
| 5 | 대형 스킬 아이콘 | size=64 | 스킬 내장 idle 애니메이션 |
| 6 | 궤도 스파클 (십자 반짝임) | r=58~82, 타원 궤도 | 서로 다른 속도/방향 |

---

## 4. Known Performance Characteristics

- **매 프레임 `pygame.Surface(..., SRCALPHA)` 3회 생성** (오라 3장) + **1회** (헤일로).
  → `CLAUDE.md` 의 "per-frame Surface 할당은 가장 큰 비용" 가이드를
  의도적으로 위반하고 있음. 다만:
  - 이 모달은 **아카데미 방문 시에만 열리는 단일 모달** (게임 루프/전투 무관)
  - 대화창이 열려있는 시간은 보통 수 초 ~ 10초 내외
  - 그래서 CPU 비용 누적이 무의미하다고 판단해서 의도적으로 캐싱 생략
- `pygame.draw.circle` 호출 수: 프레임당 오라 3 + 룬 16 + 헤일로 1 + 배경판 2 +
  스킬아이콘 내부 N개 + 스파클 4×1 = 대략 30~50 drawcall. 모달 한정이라 OK.

---

## 5. Review Focus Points

무엇을 봐줬으면 하는지:

1. **시각적 밸런스**
   - 6개 레이어가 한 프레임에 겹치는데 스킬 아이콘이 충분히 선명하게 보이는가?
   - 펄스/회전/궤도가 서로 경쟁해서 혼란스럽지는 않은가?
   - 컬러 가이드가 "스킬 컬러 1개 + 금색 악센트" 정도로 충분한지,
     아니면 보라/시안 톤도 필요한지.

2. **애니메이션 타이밍**
   - 오라 1.6 rad/s, 룬 0.6 rad/s, 헤일로 3.2 rad/s, 스파클 1.1~1.9 rad/s.
     상수 선택이 적절한지, 일부를 하모닉(정수비)으로 맞추면 더 좋을지.
   - 타원 궤도 비율 0.55: 더 납작 또는 더 원형이 낫지 않을까?

3. **코드 품질**
   - 같은 `pygame.Surface(..., SRCALPHA) + circle + blit` 패턴이
     오라/헤일로 양쪽에 반복. 작은 헬퍼 `_blit_alpha_circle(...)` 로 묶을
     가치가 있는지 (현재는 파라미터가 달라서 굳이 안 묶음).
   - `sparkle_specs` 리스트: 튜플 풀기 대신 dataclass/dict 로 바꾸는 게 나은지
     (여기서만 쓰이는 로컬 설정이라 현상 유지를 선호).

4. **`_draw_skill_icon_symbol` 의존**
   - 해당 함수는 `(skill_name, is_active, color)` 를 받고,
     미구현 스킬은 내부에서 `draw_skill_icon_mini` 로 폴백.
   - try/except 로 최종 폴백(컬러 원 + 테두리)까지 3단 방어.
     오버엔지니어링인지, 적절한지.

5. **펄스 한도 계산**
   - `aura_pulse = 0.45 + 0.35 * sin(...)` → [0.10, 0.80] 범위
   - `a = int(a * (0.7 + 0.3 * aura_pulse))` →
     원본 alpha 의 [0.73, 0.94] 배 범위. 즉 거의 풀 알파에 근접.
     "숨 쉬는 느낌"은 괜찮은 진폭인지, 너무 미묘한지.

6. **접근성 / 저사양**
   - 스킬 아이콘 자체가 지름 64px. 기본 창 해상도에서 충분히 크다고 봤음.
   - 깜빡임(flicker) 위험: 헤일로 alpha [130~210] 범위, 스파클은 상시 표시.
     sin 기반이라 전-후 프레임이 연속이므로 발작 유발 위험은 없을 것으로 판단.

---

## 6. Not In Scope

이 쇼케이스 바깥의 로직은 리뷰 대상이 아님:
- `_visit_pick_cache` / 방문당 1회 캐시
- 구매/스왑 적용 로직 (`apply_academy_skill_*`)
- 골드 싱크 (`manager.py` 의 `player_data['gold']` 역싱크)
- 퍽 제거 로직 (스왑 시 옛 퍽 `runtime_skill_levels.pop`)
- 스킬 슬롯 5/5 필터 (`filter_full_slot_unlock_perks`)

오직 "학장 아르카나가 스킬을 소개하는 시각 연출"만 봐주세요.
