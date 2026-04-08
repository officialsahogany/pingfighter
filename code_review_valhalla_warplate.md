# 발할라의 전갑 (Valhalla Warplate) - 코드리뷰 문서

## 1. 아이템 개요

| 항목 | 내용 |
|------|------|
| **이름** | 발할라의 전갑 (Valhalla Warplate) |
| **등급** | 전설 (Legendary) |
| **부위** | 상의 (torso) |
| **핵심 효과** | 공 타격 시 일정 확률(8~15%)로 투기장 영웅을 호위무사로 소환, 스킬 1회 발동 후 포탈로 퇴장 |
| **롤 옵션** | summon_chance (8~15%), gauge_cost (30~60, reverse) |
| **상점 가격** | 4,080 골드 |
| **필드 드랍률** | 0.04% |

---

## 2. 파일별 코드 위치 맵

| # | 파일 | 위치/줄번호 | 역할 |
|---|------|------------|------|
| 1 | `item_effects/valhalla_warplate.py` | 전체 (1~1011줄) | **핵심 효과 모듈** - 상태머신, 소환, 포탈, 컷신 |
| 2 | `legendary_items.py` | L104~107 | 롤 옵션 정의 (summon_chance, gauge_cost) |
| 3 | `legendary_items.py` | L12285~12555 | ValhallaWarplate 클래스 (아이콘 애니메이션) |
| 4 | `legendary_items.py` | L12963, 13017~13019, 13065~13066 | LegendaryManager 등록/초기화 |
| 5 | `items.py` | L1686~1693 | ITEMS_LEGEND 아이템 정의 |
| 6 | `items.py` | L2018 | obtained 플래그 (`valhalla_warplate_obtained`) |
| 7 | `items.py` | L2101 | unlocked_items 등록 |
| 8 | `items.py` | L2138 | PASSIVE_DUPLICATE_ALLOWED 등록 |
| 9 | `items.py` | L2469 | legendary_names 스폰 풀 |
| 10 | `items.py` | L2492 | passive_names 분류 |
| 11 | `items.py` | L1073~1090 | 아이콘 애니메이션 캐시 동기화 |
| 12 | `pingfighter.py` | L82044~82051 | handle_player 공 타격 시 소환 트리거 |
| 13 | `pingfighter.py` | L151829~151836 | handle_ball 공 타격 시 소환 트리거 |
| 14 | `pingfighter.py` | L85142~85167 | store_passive_item 획득 처리 |
| 15 | `pingfighter.py` | L30308~30328 | sync_equipped_passive_effects 장착 동기화 |
| 16 | `pingfighter.py` | L30398~30407 | 장착 해제 시 비활성화 |
| 17 | `pingfighter.py` | L30437~30449 | 인장 해제 시 발할라 bodyguard 보호 |
| 18 | `pingfighter.py` | L159476~159481 | 게임 종료 시 상태 초기화 |
| 19 | `pingfighter.py` | L29917 | sync_bool 획득 플래그 동기화 |
| 20 | `pingfighter.py` | L84092 | store_active_item 패시브 필터 |
| 21 | `pingfighter.py` | L138819, 138988~138994 | get_item_icon 아이콘 렌더 |
| 22 | `pingfighter.py` | L136026 | LEGENDARY_SLOT_ORDER 부위 분류 |
| 23 | `pingfighter.py` | L15781 | 보물찾기 전설 풀 |
| 24 | `game_mechanics/ingame_bodyguard.py` | L346~347, 442~443 | _valhalla_dismissed, _valhalla_portal_moving 플래그 |
| 25 | `game_mechanics/ingame_bodyguard.py` | L445~503 | dismiss_keep_skills(), has_active_skills(), check_dismissed_cleanup() |
| 26 | `game_mechanics/ingame_bodyguard.py` | L580~581, 688, 961 | dismissed/portal 상태 분기 처리 |
| 27 | `entities/body_parts/item_parts_registry.py` | L60~62, 334 | 뼈대 파츠 레지스트리 |
| 28 | `entities/body_parts/item_torso_parts.py` | L395~474 | ValhallaWarplatePart 시각적 파츠 |
| 29 | `gacha.py` | L328, 721, 1710, 2116 | 뽑기 시스템 풀 |
| 30 | `downtown/building_interior.py` | L3170~3182, 8630, 8676 | 상점 판매 등록 |
| 31 | `downtown/constants.py` | L552~564 | LEGENDARY_ITEM_NAMES 세트 |
| 32 | `localization/ko.json` | L2598~2599 | 한국어 번역 |
| 33 | `localization/en.json` | L2598~2599 | 영어 번역 |
| 34 | `localization/ja.json` | L2598~2599 | 일본어 번역 |

---

## 3. 핵심 로직 코드

### 3.1 상태 머신 (ValhallaWarplateState)

```
IDLE → (공 타격 + 확률 통과 + 게이지 충분 + 빈 슬롯) → CUTSCENE
CUTSCENE → (1초 후) → PORTAL_DESCEND
PORTAL_DESCEND → (포탈 열림 2초 → 하강 1초 → 닫힘 1초, 총 4초) → SUMMONED
SUMMONED → (스킬 발동 감지) → SKILL_ACTIVE
SKILL_ACTIVE → (스킬 완료 + 1초 대기) → PORTAL_ASCEND
PORTAL_ASCEND → (포탈 열림 2초 → 상승 1초 → 닫힘 1초, 총 4초) → IDLE
```

**안전장치**: SUMMONED에서 10초 내 스킬 미발동 시 강제 포탈 상승, PORTAL_ASCEND에서 18초(10+8) 초과 시 강제 해산

### 3.2 소환 시도 (try_summon) - `item_effects/valhalla_warplate.py:176~270`

```python
def try_summon(self, ball_x: int = 380) -> bool:
    """공 타격 시 소환 시도. ball_x는 공을 친 시점의 X좌표."""
    if not self.active or self.state != self.IDLE:
        return False

    # 소환 쿨타임 체크 (연속 소환 방지)
    if self.summon_cooldown > 0:
        return False

    # 실제 소환 확률 계산 (연마 + 강화 보너스 적용)
    effective_chance = self.summon_chance
    try:
        from legendary_items import get_legendary_roll_value
        effective_chance = get_legendary_roll_value(
            "valhalla_warplate", "summon_chance",
            apply_polish=True,
            enhancement_bonus_pct=self.enhancement_bonus_pct
        ) / 100.0
    except Exception:
        pass

    if random.random() > effective_chance:
        return False

    # 게이지 소모량 계산 (롤옵션, reverse=True이므로 낮을수록 좋음)
    gauge_cost = 45  # 기본값
    try:
        from legendary_items import get_legendary_roll_value
        gauge_cost = get_legendary_roll_value(
            "valhalla_warplate", "gauge_cost",
            apply_polish=True,
            enhancement_bonus_pct=self.enhancement_bonus_pct
        )
    except Exception:
        pass

    # 빈 슬롯 확인 먼저! (게이지 소모 전에 소환 가능 여부 확인)
    try:
        from game_mechanics.ingame_bodyguard import get_bodyguard, get_bodyguard2
        _bg = get_bodyguard()
        _bg2 = get_bodyguard2()
        _bg1_avail = not _bg.active or getattr(_bg, '_valhalla_dismissed', False)
        _bg2_avail = not _bg2.active or getattr(_bg2, '_valhalla_dismissed', False)
        if not _bg1_avail and not _bg2_avail:
            return False
    except Exception:
        return False

    # 게이지 잔량 체크 + 소모 (슬롯 확인 후 소모 - 게이지 낭비 방지)
    try:
        import pingfighter
        if pingfighter.special_gauge < gauge_cost:
            return False  # 게이지 부족
        pingfighter.consume_special_gauge(int(gauge_cost))
        self._consumed_gauge = int(gauge_cost)  # 환불용 저장
    except Exception:
        pass

    # 컷신 시작! (실제 소환은 컷신 끝에)
    hero = random.choice(VALHALLA_HEROES)
    self._pending_hero = hero
    skill_idx = random.randint(0, 1)
    # 스토리모드에서 작동하지 않는 스킬 회피:
    # - 밴시 매혹(인덱스 0): 적 호위무사가 없어 발동 불가 → 유령소환(인덱스 1) 강제
    if hero["id"] == "banshee" and skill_idx == 0:
        skill_idx = 1  # 유령소환 사용
    self._pending_skill_idx = skill_idx
    self.state = self.CUTSCENE
    self.summoning = True
    # 소환 위치를 공을 친 X좌표로 설정 (화면 범위 내 클램프)
    self.portal_x = float(max(100, min(660, ball_x)))
    # 컷신 시작 사운드
    self._play_sound("potal2.wav", 0.8)
    self.cutscene_timer = 0.0
    self.summoned_hero_name = hero["name"]
    # (파티클 생성 코드 생략)
    return True
```

### 3.3 실제 소환 (_do_actual_summon) - `item_effects/valhalla_warplate.py:272~351`

```python
def _do_actual_summon(self):
    """컷신 종료 후 실제 호위무사 소환"""
    hero = self._pending_hero
    skill_idx = self._pending_skill_idx
    if not hero:
        self._clear_state()
        return

    _setup_bg = None  # setup() 성공한 bodyguard 추적 (예외 시 정리용)
    try:
        from game_mechanics.ingame_bodyguard import get_bodyguard, get_bodyguard2
        _bg = get_bodyguard()
        _bg2 = get_bodyguard2()
        # dismissed 상태(스킬 잔여물만 남은 슬롯)는 강제 정리 후 재사용
        def _is_available(bg):
            if not bg.active:
                return True
            if getattr(bg, '_valhalla_dismissed', False):
                bg.reset()  # 잔여 스킬도 정리하고 재사용
                return True
            return False
        target_bg = _bg if _is_available(_bg) else (_bg2 if _is_available(_bg2) else None)
        if not target_bg:
            # 슬롯이 사라졌으면 게이지 환불
            self._refund_gauge()
            self._clear_state()
            return

        hero_data = {
            "id": hero["id"],
            "name": hero["name"],
            "color": tuple(hero["color"]),
            "title": ""
        }
        skill_sel = {hero["id"]: skill_idx}
        target_bg.setup(hero_data, skill_selections=skill_sel, first_spawn=True)
        _setup_bg = target_bg  # setup 성공 → 예외 시 reset 대상

        if target_bg._guard_system:
            target_bg._guard_system.cooldown_bottom = 0.1

        self._bodyguard_ref = target_bg
        self.summon_timer = 0.0
        self.post_skill_timer = 0.0

        # 포탈 하강 시작: guard_system의 위치와 phase를 강제 오버라이드
        gs = target_bg._guard_system
        if gs:
            gs.x_bottom = self.portal_x
            gs.y_bottom = self.PORTAL_Y - 30
            gs.phase_bottom = None
            gs.active_bottom = gs.guard_warriors_bottom[0] if gs.guard_warriors_bottom else None
            gs.cooldown_bottom = 99.0
            if gs.hero_paddle_renderer and hero:
                gs.hero_paddle_renderer.update_movement(hero["id"], self.portal_x, 0.016)

        self.state = self.PORTAL_DESCEND
        self.portal_timer = 0.0
        # (나머지 초기화 코드 생략)
        target_bg._valhalla_portal_moving = True
        self._play_sound("potal.wav", 0.7)

    except Exception as e:
        print(f"[WARN] 발할라 전갑 소환 실패: {e}")
        # setup() 이후 예외 → 이미 활성화된 bodyguard 정리
        if _setup_bg is not None:
            try:
                _setup_bg.reset()
            except Exception:
                pass
        self._refund_gauge()
        self._clear_state()
```

### 3.4 게이지 환불 (_refund_gauge) - `item_effects/valhalla_warplate.py:352~372`

```python
def _refund_gauge(self):
    """소환 실패 시 소모된 게이지 환불 (special_ready / game_state 동기화 포함)"""
    refund = getattr(self, '_consumed_gauge', 0)
    if refund > 0:
        try:
            import pingfighter
            pingfighter.special_gauge = min(
                pingfighter.special_gauge + refund,
                pingfighter.special_gauge_max
            )
            # consume_special_gauge()와 동일한 상태 동기화
            pingfighter.special_ready = pingfighter.special_gauge >= 350
            try:
                pingfighter.game_state.special_gauge = pingfighter.special_gauge
                pingfighter.game_state.special_ready = pingfighter.special_ready
            except Exception:
                pass
        except Exception:
            pass
        self._consumed_gauge = 0
```

### 3.5 호위무사 퇴장 (dismiss_keep_skills) - `game_mechanics/ingame_bodyguard.py:445~487`

```python
def dismiss_keep_skills(self):
    """호위무사 캐릭터만 퇴장시키고 활성 스킬 이펙트는 유지.

    발할라의 전갑 등 짧은 소환 후 퇴장 시 사용.
    소환물(해골궁수, 뼈장막, 수리검 등)은 지속시간이 끝날 때까지 유지됨.
    active=True를 유지하여 update/draw가 계속 호출되고,
    _valhalla_dismissed 플래그로 캐릭터 렌더링만 숨김.
    스킬이 모두 완료되면 자동으로 완전 reset.
    """
    # 개틀링 버스트 변신 상태 초기화
    if self._hero_paddle_renderer and self.hero_data and self.hero_data.get('id') == 'android':
        try:
            state = self._hero_paddle_renderer._get_state('android')
            state['gatling_firing'] = False
            # ... (기타 초기화)
        except Exception:
            pass

    # 캐릭터만 비활성화 (스킬 인스턴스 + guard_paddles는 유지!)
    if self._guard_system:
        self._guard_system.active_bottom = None
        self._guard_system.phase_bottom = None
        self._guard_system._patrol_target_bottom = None
        self._guard_system._patrol_wait_bottom = 0.0
        # 새 스킬 발동 방지 (쿨다운을 매우 길게)
        self._guard_system.cooldown_bottom = 99999.0

    # active=True 유지! (update/draw 계속 호출되어 스킬 이펙트 유지)
    self._valhalla_dismissed = True
    self.hero_data = None
```

### 3.6 트리거 포인트 (pingfighter.py)

**handle_player (L82044~82051)**:
```python
# 발할라의 전갑 효과 발동 (handle_player에서의 공 타격)
try:
    from item_effects.valhalla_warplate import get_valhalla_warplate_state
    _vw_hp = get_valhalla_warplate_state()
    if _vw_hp.active:
        _vw_hp.try_summon(ball_x=int(BALL.centerx))
except Exception:
    pass
```

**handle_ball (L151829~151836)** — 동일 패턴:
```python
# 발할라의 전갑 효과 발동 (장착 중일 때, 공 타격 시 영웅 소환 시도)
try:
    from item_effects.valhalla_warplate import get_valhalla_warplate_state
    _vw_state = get_valhalla_warplate_state()
    if _vw_state.active:
        _vw_state.try_summon(ball_x=int(BALL.centerx))
except Exception:
    pass
```

### 3.7 장착/해제 동기화 (pingfighter.py:30308~30407)

**장착 시 (sync_equipped_passive_effects)**:
```python
# 발할라의 전갑: 강화 보너스 동기화 + 소환 상태 활성화
if legend_name == "valhalla_warplate":
    warplate_item = next((item for item in equipped_items if item.get("name") == "valhalla_warplate"), None)
    if warplate_item:
        warplate = legendary_manager.get_item("valhalla_warplate")
        if warplate:
            warplate.enhancement_bonus_pct = warplate_item.get("enhancement_bonus_pct", 0)
    # 발할라 전갑 인게임 상태 활성화
    try:
        from item_effects.valhalla_warplate import get_valhalla_warplate_state
        vw_state = get_valhalla_warplate_state()
        summon_chance = 10  # 기본값
        try:
            from legendary_items import get_legendary_roll_value
            summon_chance = get_legendary_roll_value(
                "valhalla_warplate", "summon_chance",
                apply_polish=True,
                enhancement_bonus_pct=warplate_item.get("enhancement_bonus_pct", 0) if warplate_item else 0
            )
        except Exception:
            pass
        # ... activate(summon_chance) 호출
    except Exception:
        pass
```

**해제 시**:
```python
elif legend_name == "valhalla_warplate":
    warplate = legendary_manager.get_item("valhalla_warplate")
    if warplate:
        warplate.enhancement_bonus_pct = 0
    # 발할라 전갑 인게임 상태 비활성화
    try:
        from item_effects.valhalla_warplate import get_valhalla_warplate_state
        get_valhalla_warplate_state().deactivate()
    except Exception:
        pass
```

### 3.8 인장 해제 시 보호 (pingfighter.py:30437~30449)

```python
# 발할라의 전갑이 사용 중인 bodyguard도 인장 해제에서 제외
try:
    from item_effects.valhalla_warplate import get_valhalla_warplate_state
    _vw_s = get_valhalla_warplate_state()
    if _vw_s.state != _vw_s.IDLE and _vw_s._bodyguard_ref:
        _temp_seal_active_bg.add(id(_vw_s._bodyguard_ref))
except Exception:
    pass
```

### 3.9 획득 처리 (pingfighter.py:85142~85167)

```python
elif item_data["name"] == "valhalla_warplate":
    # 발할라의 전갑 전설 아이템 획득 (상의 부위 - 공 타격 시 영웅 소환)
    # ⚠️ 효과는 장착 시에만 활성화됨
    if not items.valhalla_warplate_obtained:
        items.valhalla_warplate_obtained = True
        _apply_item_to_skin(_skeletal_skin, "valhalla_warplate")  # 뼈대 외형 변경
        try:
            legendary_manager = get_legendary_manager()
            if "valhalla_warplate" not in legendary_manager.unlocked_items:
                legendary_manager.unlocked_items.append("valhalla_warplate")
                legendary_manager.items["valhalla_warplate"].unlocked = True
            from legendary_items import randomize_legendary_rolls
            randomize_legendary_rolls("valhalla_warplate")
            warplate = legendary_manager.items.get("valhalla_warplate")
            if warplate:
                enhancement_pct = item_data.get("enhancement_bonus_pct", 0)
                warplate.enhancement_bonus_pct = enhancement_pct
        except Exception as e:
            print(f"발할라의 전갑 효과 적용 오류: {e}")
    # 전설 아이템 획득 애니메이션 트리거 (매 획득 시 재생)
    trigger_legendary_acquisition("valhalla_warplate", "발할라의 전갑", item_icon,
                                 (item_data.get("x", WIDTH//2), item_data.get("y", HEIGHT - 100)))
    item_data["type"] = "legendary"
    ensure_legendary_rolls(item_data)
    apply_roll_bonuses_from_item(item_data)
    show_item_obtained_effect(item_data, item_data.get("x"), item_data.get("y"))
```

### 3.10 게임 종료 시 리셋 (pingfighter.py:159476~159481)

```python
# 발할라의 전갑 상태 초기화
try:
    from item_effects.valhalla_warplate import get_valhalla_warplate_state
    get_valhalla_warplate_state().reset()
except Exception:
    pass
```

### 3.11 롤 옵션 정의 (legendary_items.py:104~107)

```python
"valhalla_warplate": [
    {"key": "summon_chance", "label": "영웅 소환 확률", "min": 8, "max": 15, "unit": "%", "default": 10},
    {"key": "gauge_cost", "label": "게이지 소모", "min": 30, "max": 60, "unit": "", "default": 45, "reverse": True},
],
```

### 3.12 영웅 목록 (item_effects/valhalla_warplate.py:21~37)

```python
VALHALLA_HEROES = [
    {"id": "mugen",      "name": "무겐",       "color": (120, 60, 180)},
    {"id": "kraken",     "name": "크라켄",      "color": (40, 120, 140)},
    {"id": "chronos",    "name": "크로노스",    "color": (200, 170, 100)},
    {"id": "onimaru",    "name": "오니마루",    "color": (200, 50, 70)},
    {"id": "maria",      "name": "연화",        "color": (180, 100, 150)},
    {"id": "ignis",      "name": "이그니스",    "color": (220, 100, 40)},
    {"id": "gear",       "name": "기어",        "color": (140, 100, 60)},
    {"id": "kurokage",   "name": "쿠로카게",    "color": (50, 50, 70)},
    {"id": "banshee",    "name": "벤시",        "color": (80, 130, 160)},
    {"id": "necro",      "name": "네크로",      "color": (80, 60, 100)},
    {"id": "joker",      "name": "조커",        "color": (220, 60, 80)},
    {"id": "mirage",     "name": "세트",        "color": (210, 180, 100)},
    {"id": "android",    "name": "안드로이드",  "color": (130, 140, 160)},
    {"id": "ra",         "name": "호루스",      "color": (230, 160, 40)},
    {"id": "monkeyking", "name": "원숭이왕",    "color": (205, 165, 75)},
]
```

### 3.13 뼈대 외형 파츠 (entities/body_parts/item_torso_parts.py:395~474)

```python
class ValhallaWarplatePart(BodyPart):
    """발할라의 전갑 (valhalla_warplate).
    은빛 강철 갑옷 + 금빛 날개 문양 + 룬 각인.
    효과: 공 타격 시 영웅 소환.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_TORSO, draw_order=ORDER_TORSO,
            joint_a="torso", joint_b="hip",
        )
        self.block = block

    def _render(self, surface, joint_a, joint_b, palette, phase):
        b = self.block
        cx, ty = joint_a.world_int()
        # 갑옷 본체, 중앙 장식선, 발할라 문양(원형+날개), 룬 각인, 어깨 보호대 등
        # (총 80줄의 렌더링 코드)
```

---

## 4. 아이템 정의 (items.py:1686~1693)

```python
{
    "name": "valhalla_warplate",  # 발할라의 전갑 전설 아이템 (상의 부위)
    "color": (180, 190, 210),     # 은빛 강철
    "effect": "valhalla_warplate",
    "icon": None,
    "chance": 0.0004,             # 전설 아이템 필드 드랍 0.04% 확률
    "duration": 600,
    "unlock_condition": None,
    "body_part": "torso"          # 상의(갑옷) 부위
}
```

---

## 5. 등록 체크리스트 현황

| # | 항목 | 상태 | 위치 |
|---|------|------|------|
| 1 | items.py ITEM_TYPES 정의 | ✅ | L1686 |
| 2 | items.py unlocked_items | ✅ | L2101 |
| 3 | items.py obtained 플래그 | ✅ | L2018 |
| 4 | items.py passive_names | ✅ | L2492 |
| 5 | items.py PASSIVE_DUPLICATE_ALLOWED | ✅ | L2138 |
| 6 | items.py legendary_names | ✅ | L2469 |
| 7 | pingfighter.py store_active_item 필터 | ✅ | L84092 |
| 8 | pingfighter.py store_passive_item 처리 | ✅ | L85142 |
| 9 | pingfighter.py get_item_icon | ✅ | L138819 |
| 10 | pingfighter.py sync_bool | ✅ | L29917 |
| 11 | pingfighter.py sync_equipped_passive_effects | ✅ | L30308 |
| 12 | pingfighter.py 게임 종료 리셋 | ✅ | L159476 |
| 13 | legendary_items.py 클래스 정의 | ✅ | L12285 |
| 14 | legendary_items.py 롤 옵션 | ✅ | L104 |
| 15 | legendary_items.py Manager 등록 | ✅ | L12963 |
| 16 | gacha.py 뽑기 풀 | ✅ | L328 |
| 17 | downtown 상점 등록 | ✅ | L3170 |
| 18 | downtown LEGENDARY_ITEM_NAMES | ✅ | L552 |
| 19 | localization (ko/en/ja) | ✅ | L2598 |
| 20 | 뼈대 파츠 레지스트리 | ✅ | item_parts_registry L60 |
| 21 | 뼈대 파츠 클래스 | ✅ | item_torso_parts L395 |
| 22 | 보물찾기 전설 풀 | ✅ | pingfighter L15781 |

---

## 6. 코드리뷰 요청 항목

아래 항목들에 대해 코드리뷰를 요청합니다:

### 6.1 구조/설계
- [ ] 상태 머신 6단계(IDLE→CUTSCENE→PORTAL_DESCEND→SUMMONED→SKILL_ACTIVE→PORTAL_ASCEND→IDLE)의 전이 조건이 빠짐없이 올바른가?
- [ ] 싱글톤 패턴(`get_valhalla_warplate_state()`)이 멀티스레드에 안전한가? (현재 pygame 단일 스레드이므로 문제없을 수 있음)
- [ ] `_bodyguard_ref` 참조가 GC되지 않고 안전하게 유지되는가?

### 6.2 리소스 관리
- [ ] `_cached_sounds`, `_cached_surfaces`, `_cached_text` 캐시가 무한히 커지지 않는가?
- [ ] `_clear_state()`에서 텍스트 캐시를 `hero_` 접두사 기준으로만 정리하는데, 정리 기준이 충분한가?
- [ ] portal_particles/portal_lightning 상한(20개/6개)이 성능상 적절한가?

### 6.3 게이지/경제 시스템
- [ ] `_refund_gauge()`에서 `special_gauge_max`으로 클램프하는데, 환불 시 max를 초과할 가능성은?
- [ ] `special_ready` 하드코딩(`>= 350`)이 `consume_special_gauge()`와 동기화되어 있는가?
- [ ] 게이지 소모 → 슬롯 확인 → 소환 실패 시 환불 흐름에 누수 가능성은?

### 6.4 안전장치/에지 케이스
- [ ] 밴시 매혹(인덱스 0) 회피 외에 스토리모드에서 작동하지 않는 다른 스킬은 없는가?
- [ ] `_do_actual_summon()`에서 `_is_available()` 내부 `bg.reset()` 호출이 다른 시스템(인장 등)과 충돌하지 않는가?
- [ ] handle_player와 handle_ball 양쪽에서 `try_summon()`이 호출되는데, 같은 프레임에 2번 호출될 가능성은?
- [ ] PORTAL_ASCEND 완료 시 `dismiss_keep_skills()` 호출 → `check_dismissed_cleanup()`으로 최종 정리되는 흐름에서 타이밍 이슈는?

### 6.5 코드 품질
- [ ] `try/except Exception: pass` 패턴이 과도하게 사용되어 디버깅을 어렵게 하지 않는가?
- [ ] `import pingfighter` 지연 임포트가 순환 참조 문제를 일으킬 가능성은?
- [ ] `_create_default_animation()`의 8프레임 하드코딩 애니메이션 코드(100줄+)를 데이터 구동 방식으로 개선할 수 있는가?
- [ ] `_extract_corners()`에 `return result`가 2번 있음 (L12351, 12352) - 중복 코드

### 6.6 비주얼/UX
- [ ] 포탈 연출(열림 2초 + 하강/상승 1초 + 닫힘 1초 = 총 4초 × 2회)이 게임 진행에 방해가 되지 않는가?
- [ ] 컷신 1초간 화면 정지가 플레이어 경험에 미치는 영향
- [ ] 소환 쿨타임 5초가 게임 밸런스상 적절한가?

---

---

## 7. 코드리뷰 결과 및 수정 내역 (2026-04-09)

### 7.1 [High] 스킬 잔여물 조기 종료 — 수정 완료 ✅
**문제**: `has_active_skills()`가 `skill.is_active`만 체크하여, is_active=False 이후에도 추가 프레임이 필요한 스킬(유령소환 dying_ghosts, 해골궁수 arrows, 크로노스 shrink_timer, 촉수 retracting, 먹물 dissolving, 풍선 popping)이 조기 reset() 됨.
**수정**: `_has_lingering_effects()` 정적 메서드 추가. 6종 스킬의 잔여 이펙트 상태를 개별 체크하여 `has_active_skills()`에 반영.
**파일**: `game_mechanics/ingame_bodyguard.py` L489~

### 7.2 [High] dismissed 슬롯 강제 재사용으로 잔여 이펙트 중단 — 수정 완료 ✅
**문제**: `_do_actual_summon()`이 dismissed 슬롯을 즉시 `bg.reset()`으로 정리하여, 이전 영웅의 잔여 스킬(해골궁수 등)이 중간에 끊김. `try_summon()`도 동일하게 dismissed를 빈 슬롯으로 취급.
**수정**: dismissed + `has_active_skills()==False`인 경우만 재사용 가능. 잔여 이펙트가 남아있으면 슬롯 점유 유지.
**파일**: `item_effects/valhalla_warplate.py` L212~, L285~

### 7.3 [Medium] 게이지 차감 fail-open — 수정 완료 ✅
**문제**: 게이지 소모 코드가 `except Exception: pass`로 감싸져, import/consume 실패 시 게이지 0 소모로 소환 진행(무료 소환).
**수정**: `except Exception: return False`로 변경. 게이지 시스템 오류 시 소환 중단.
**파일**: `item_effects/valhalla_warplate.py` L224~

### 7.4 [Low] _extract_corners() 중복 return — 수정 완료 ✅
**문제**: `return result`가 2줄 연속 (dead code).
**수정**: 중복 제거.
**파일**: `legendary_items.py` L12351~12352

---

*문서 생성일: 2026-04-09*
*대상 브랜치: feature/refactor-ui*
