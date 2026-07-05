# 루미온 천둥 낙뢰 (Solar Bolt) 슬라이스 플랜 — v1.2

루미온의 **두 번째 액티브 스킬** — 원본 핑파이터 영웅 라(Ra)/호루스의 `SolarBolt`
(`downtown/hero_skills.py:16204-16612`, 한글명 "천둥 낙뢰")를 Godot 링펫 액티브로
포팅한다. 원본은 **공이 시전자 쪽으로 내려올 때 번개로 타격해 상대 방향으로 반사**시키는
방어형 반사 스킬이며(디바인쉴드 번개 요격 `pingfighter.py:169865-169940`과 동일 로직),
여기에 링피아 신규 사양(레벨별 쿨타임 점감 + Lv.3+ 50% 재발사 체인)을 얹는다.

- **포팅 원칙:** 반사 메커니즘·반사 수학·VFX는 원본 충실 포팅이 기본. 의도적 분기는 **부록 B**.
- **분담:** 이 문서 = 디자인 노트(신호 계약) + 슬라이스 브리프. GDScript 배선은 사용자/Codex가
  직접, Claude는 적대적 리뷰. ([[feedback_design_slice_review_division]])
- **작성일:** 2026-06-14
- **v1.1 갱신:** 적대적 리뷰 2렌즈(배선/코드충돌 + 게임플레이) 반영 — must-fix 5건 + should-fix
  다수. 리뷰 로그는 문서 맨 끝.
- **출시 범위 (2026-06-30 정정):** Solar Bolt 런타임/카탈로그/전용 카드·아이콘은 라이브이며,
  V3-2 다중 액티브 경로도 랜딩했다. slot-0 선택지로 배정되거나 second active slot에 들어가도
  slot-aware 효과 레벨(`active_skill_bonus` / `second_active_skill_bonus`)을 받는다. 과거
  "slot-1 교체형만 완전 동작" 전제는 보존된 리뷰 이력이다.
- **자매 문서:** `docs/lingpet_monkeyring_wild_roar_slice_plan.md`(가장 가까운 선례 — **하강공
  자동시전 + ball_vel 쓰기 + can_arm가 ball 키 읽음**),
  `docs/lingpet_monkeyring_banana_slice_plan.md`,
  `docs/lingpet_affinity_system_plan.md` §13 (링코어 게이트 = 이 스킬의 **해금 프레임워크**).
- **기존 형제 스킬:** 루미온 1번 액티브 = **천둥 뇌구**(`lumion_thunder_orb` /
  `lingpet_thunder_orb_skill.gd`, 구체 발사→보스 폭발→감전). 천둥 낙뢰는 같은 호루스
  킷("ra" = `[SolarBolt, ThunderOrb]`)의 나머지 한 짝.
- **원본 보조 레퍼런스:** `hero_skills.py` 16273 `_check_ball_conditions`, 16378 `_apply_effect`,
  16297 `_gen_lightning`, 16466 `draw`, 16605 `reset_for_new_round`; HeroSkill 베이스 138-249.

> **해금 프레임워크와의 관계 (2026-06-30 정정):** 링코어/교감 시스템(§13)이 언제·어떻게
> 이 스킬이 주어지는지를 담당한다. unlock-choice→loadout 배선과 second active 레벨 reading은
> V3-2에서 완료됐고, Solar Bolt는 `launch_context.active_skill_level`만 읽으면 된다.
> V3-2 이전의 "slot-1 액티브로 선택/배정될 때만 레벨 스케일" 전제는 더 이상 현재 구현이 아니다.

---

## §0 구현 결정

| # | 결정 | 제안값 | 근거 |
|---|---|---|---|
| D1 | 발동 모델 | 자동 시전(보편 `_should_arm` + 쿨타임) | 원본 `ON_COOLDOWN`; 모든 링펫 액티브 컨벤션 |
| D2 | 발동 게이트(`can_arm`) | `ball_active` **AND** `companion_visible` **AND** `companion_pos≠0` **AND** `not skip_ball_motion_step` **AND** 공 하강(`ball_vel.y>0`) **AND** 하단 절반(공 중심 y≥375) **AND** `_player_can_block==false` | wild_roar `can_arm` 게이트 직역(`lingpet_wild_roar_skill.gd:99-111`) + 원본 하강 조건 + **비위협/인터셉트 충돌 방지(아래 D5/리뷰)**. 필드 전체는 Q3 유지(로컬존 미적용) |
| D3 | 윈드업 | **0.0s (즉발 리플렉스)** | 하강공을 놓치지 않으려면 즉발. 스트라이크 애님은 발동 후 재생 |
| D4 | 1차 반사(STRIKE #1) 수학 | `_speed_locked = max(1, ball_vel.length())` 캡처(첫 타격 직전, 체인 내내 보존), `base_angle = -PI/2`(위) `±PI/4` 콘, 최소 상승 `nvy ≤ -1.0` | 원본 16407-16427 직역, **px/frame 단위** |
| D5 | 요격 결과 | 확정 세이브(위치/적중 판정 없음). 단 D2 `_player_can_block` 게이트로 **플레이어가 못 막는 공만** | 원본은 조건 게이트 반사. `_player_can_block`은 defense_rate 인터셉트와의 이중발동·쿨다운 낭비 차단 |
| D6 | 쿨타임(베이스) | **22.0s** (플레이스홀더; V3-6 income QA 확정). + 옵션: 실제 발사된 추가타마다 +4~6s 가산 | 확정 트리플세이브가 보스-스턴 형제(25s)보다 싸면 안 됨(리뷰). 원본 12.0은 패들스킬 기준 |
| D7 | 레벨별 쿨타임 | 전역 감소 테이블(Lv.5 −12%) | 카탈로그 `cooldown` 베이스만 선언 |
| D8 | 재발사 체인 (Lv.3+/Lv.5) | **launch 시 1회 프리롤**, **후속타마다 0.5~1.0s 랜덤 간격**(v1.3, 후속타당 1회 롤). Lv.<3 → 0 / Lv.3-4 → 50%×1 / Lv.5 → 50% **체인**×2 (총 ≤3타) | Q확정. **매-프레임 롤 금지(압축 트랩) — 간격도 후속타당 1회만 롤**. 체인=첫 롤 실패 시 둘째 롤 없음 |
| D9 | 재발사 동작 (v1.2 확정) | **launch-time 프리롤 후속타 — 각 후속타는 실행 순간 1회 재조준(현재 `ball_pos`→현재 `boss_center`). per-frame 추적(homing) 아님.** `dir = (boss_center - ball_pos).normalized()`(실패 시 `Vector2(0,-1)`), `ball_vel = dir * _speed_locked`(첫 타격 직전 크기, 체인 내내 보존) | Q2 "보스 방향 재타격" 확정. 상승공 no-op 회피. **'homing'(유도탄) 어휘 금지 — 1회 재조준임** |
| D10 | 재충돌 방지 | 반사 프레임에 짧은 `player_collision_cooldown`(6프레임 floor) 세팅 + D2가 공을 패들 위(`y < player_y - margin`)에서만 잡음 | body-hit 선례는 `ball_vel`+`ball_pos`+쿨다운을 함께 씀. bare `ball_vel`만으론 저속 반사 시 패들 재포착 가능(리뷰) |
| D11 | VFX 팔레트 | **금색** (태양신, 원본 `(255,230,100)`) | Q4 확정. 청백 천둥 뇌구와 구분 |
| D12 | VFX 구현 (v1.3 — 원본 문양 충실 포팅) | 절차적 즉시-draw. **원본 SolarBolt `_gen_lightning` 그대로**: 재귀 midpoint-displacement 볼트 + 3~5 분기(+40% 서브분기, **used_indices 중복 가드 포함**) + 4레이어(글로우/금코어/백코어/라벤더 분기) + 3중 시간차 폭발 링(금)·방사 아크(청백) + streak/dot/flash 스파크 22개. 강타 시 1회 생성·고정 경로 + 85% 플리커 | 텍스처 불요 → `prewarm()` no-op. **Godot 한계**: BLEND_ADD 글로우 → 알파-에뮬 와이드 라인 |
| D13 | 공 소유권 (v1.1 신규) | 매 스트라이크에 `ball_intensity.register_contact("lingpet","player",{...})` 호출 | 점수/콤보/보스 재타격 귀속. **wild_roar 복사론 안 됨** — body-hit 가드의 `_register_ball_intensity_contact` 미러(리뷰) |
| D14 | 레벨 공급 전제 (2026-06-30 정정) | solar_bolt는 slot-0/second active slot 모두 `launch_context.active_skill_level` 기반으로 Lv.3/5 재발사 스케일 | V3-2 완료. `LingpetCurrentProfile`이 slot-aware active bonus를 읽고 runtime host가 슬롯별 launch_context를 전달 |

함의: 자기완결 공-반사 모듈. 공을 1프레임만 만지고(소유 안 함, 단 owner-ship은 register_contact로
귀속), 새 owner 키 불요, 레벨 차별화는 재발사 체인이 전담. 최대 위험은 D8 매-프레임 롤 트랩 하나로 집중.

---

## §1 타임라인

| 페이즈 | 길이 | 내용 | 원본 근거 |
|---|---|---|---|
| ARM | 쿨타임 경과 + `can_arm`(D2) | 보편 `_should_arm` + D2 전체 게이트 | `hero_skills.py:16273` + wild_roar |
| WINDUP | **0.0s** | 즉발 (D3) | — |
| STRIKE #1 | 즉시(1프레임) | **콘 반사**(D4, 위로) + 번개/플래시/스파크 + `register_contact` + `player_collision_cooldown` + **체인 프리롤(D8)** | `_apply_effect:16378` |
| RE-FIRE 대기 | 0.5~1.0s × N (후속타당 랜덤) | delta 타이머. 예약된 후속타 대기 | 신규 |
| STRIKE #2/#3 | 즉시 | **보스 중심 재조준**(D9) + VFX 재스폰 + `register_contact` | 신규 (Q2/D9) |
| VFX 페이드 | ~0.55s | 번개 0.20s / 폭발 0.38s / 스파크 0.55s TTL | `LIGHTNING_DISPLAY`/`EXPLOSION_DISPLAY` |

**STRIKE #1 — 콘 반사 (px/frame, base 7.65 / cap 26):**

```gdscript
_speed_locked = maxf(1.0, ball_vel.length())          # 첫 타격 직전 크기 — 체인 내내 보존
var base_angle: float = -PI / 2.0                     # 위(보스 방향)
var offset: float = randf_range(-PI / 4.0, PI / 4.0)  # ±45° 콘 (원본 패리티)
var nvx: float = cos(base_angle + offset) * _speed_locked
var nvy: float = sin(base_angle + offset) * _speed_locked
if nvy >= -1.0:
	nvy = -1.0
owner.set("ball_vel", Vector2(nvx, nvy))
owner.set("player_collision_cooldown", maxf(owner.get("player_collision_cooldown"), 6.0))  # D10
# 모션은 정상 step_motion 처리(pos += vel*fps_scale, fps_scale=delta*60). skip 플래그 안 씀.
```

**STRIKE #2/#3 — 1회 보스 중심 재조준 (D9, per-frame 추적 아님):**

```gdscript
# _speed_locked = launch 시(첫 타격 직전) 1회 캡처. 체인 내내 동일.
var boss_center: Vector2 = _get_boss_rect(owner).get_center()   # thunder_orb _get_boss_rect 재사용
var to_boss: Vector2 = boss_center - ball_pos                    # 실행 순간의 현재 ball_pos
var dir: Vector2 = to_boss.normalized() if to_boss.length() > 0.001 else Vector2(0, -1)  # 안전 fallback
owner.set("ball_vel", dir * _speed_locked)                      # 1회 재조준 — 이후 추적 없음
# 캡(26 px/frame) 다음 틱 재클램프. _speed_locked 보존이라 보통 캡 이하
```

**체인 프리롤 (launch 시 1회 — 매 프레임 롤 절대 금지):**

```gdscript
var level: int = launch_context.get("active_skill_level", 1)
var max_extra: int = 2 if level >= 5 else (1 if level >= 3 else 0)
_scheduled_refires = 0
for _i in range(max_extra):
	if _roll_unit() < refire_chance:   # 체인: 실패 시 break
		_scheduled_refires += 1
	else:
		break
# _scheduled_refires 만큼 후속타당 0.5~1.0s 랜덤 간격(_roll_refire_delay, 후속타당 1회 롤)으로 예약.
# 타이머는 update(delta)에서만 감소(벽시계 금지).
```

> **프리롤이 "1초 뒤 50%"와 동등한 이유:** 각 잠재 재발사의 독립 50%(체인)를 굴리는 **시점만**
> launch로 옮길 뿐 OUTCOME 동일. 매-프레임 롤 사이트 부재 → 압축 트랩 구조적 차단, 봉인 최용이.

---

## §2 신호 계약 — 공 파이프라인 채널

**메커니즘:** owner 키 신설 없음. 스트라이크마다 `owner.set("ball_vel", v)`(+ 1차에 `ball_pos`
불요·`player_collision_cooldown` 세팅) 1프레임 쓰기 → 다음 `step_motion` 정상 처리. **공 소유권은
`registry`의 `ball_intensity.register_contact`로 귀속**(owner 키 아님).

**읽기:**
```
launch_context(=params).ball_active : bool      # can_arm / 재발사 가드
launch_context.ball_pos    : Vector2            # 게이트(하단 절반) + 번개 타겟 + 보스조준 기준
launch_context.ball_vel    : Vector2            # 게이트(하강) + _speed_locked 캡처 (px/frame)
launch_context.ball_size   : float              # 공 중심 y = pos.y + size/2 (원본 보정)
launch_context.companion_pos    : Vector2       # 번개 시각 원점 (§3)
launch_context.companion_visible: bool          # can_arm 게이트
launch(launch_context).active_skill_level : int # 체인 max_extra
launch(launch_context).refire_chance_pct  : float # 기본 50.0 (§6.3 1줄 추가)
owner.player_pos / player_paddle_width / ...    # _player_can_block 계산 (wild_roar/ring_dash 헬퍼 미러)
```

**쓰기:**
```
owner.set("ball_vel", Vector2)                  # 스트라이크마다 (이미 DEFAULT_VALUES)
owner.set("player_collision_cooldown", >=6.0)   # 1차 반사 프레임 (이미 DEFAULT_VALUES)
registry → ball_intensity.register_contact("lingpet","player",{"source":"solar_bolt"})  # 소유권 귀속 (D13)
```

**프로듀서→컨슈머:** `lingpet_companion_skill_controller.update`(호스트 매 프레임 틱, :20-21) →
`LingpetSkillRuntimeHost.update(delta,owner,registry,skill_id,launch_context)`(solar_bolt 케이스) →
`LingpetSolarBoltSkill.update(delta,owner,registry,launch_context)` → 스트라이크 시 `owner.set("ball_vel")`
+ `register_contact` → 다음 프레임 정상 `step_motion`. **skip 플래그·소유 토큰 없음.**

---

## §3 신호 계약 — 번개 VFX 원점 (라이브 컴패니언 위치)

번개는 시전자(컴패니언) → 공으로 그린다(원본 caster→ball). 재발사는 1~2초 뒤라 컴패니언이
패트롤로 이동해 있을 수 있음 → 라이브 위치 필요.

**배선(v1.1 정정 — 호스트 시그니처 일치):** 호스트 update 디스패치의 4번째 인자는
`launch_context: Dictionary`이고, **매 프레임 forwarding되는 그 dict가 곧 `params`**(controller
:21이 params를 5번째 인자로 전달; params에 `companion_pos` 포함, `lingpet_egg_runtime.gd:1639`).
따라서 모듈은:
```gdscript
func update(delta, owner, registry, launch_context: Dictionary = {}) -> void:
	var origin := launch_context.get("companion_pos", _stored_origin)  # INF/미존재 → 저장 origin 폴백
```
INF/미존재 센티넬은 launch_context-less 리셋/콜드 경로 가드용. 매 프레임 틱은 항상 companion_pos 공급.
참조 시그니처: `lingpet_milk_production_skill.gd:46`.

---

## §4 owner 스키마 — **새 키 불필요 (의도적)**

- `ball_vel`, `player_collision_cooldown` — 이미 `battle_scene_state.gd DEFAULT_VALUES`. 추가 불요.
- 공 소유권은 `registry`의 `ball_intensity.register_contact`로 귀속 — owner 키 아님(스키마 무관).
- 레일 카드 캐스팅 표시용 `solar_bolt_*_active` 플래그는 **`get_snapshot()` 호스트 병합 스냅샷**에만
  실리며 owner `_set_pair`를 안 타므로 `DEFAULT_VALUES` 변경 불요.

> **회귀 가드:** 추후 쿨다운/체인 상태를 다른 모듈이 owner로 읽어야 하면 그 키를 반드시
> `DEFAULT_VALUES`에 선언(Owner-Field Schema Trap). plain-dict FakeOwner 아닌 `BattleSceneState`
> 위임 owner로 스모크.

---

## §5 라운드 / 리셋 정리

- **`reset()`:** `_phase=IDLE`, 예약 재발사 큐/타이머·`_scheduled_refires=0`·`_speed_locked=0`·VFX
  상태 클리어, `_stored_origin` 리셋. (오디오 루프·보스 상태 미보유 → plain `reset()`로 충분.)
- **라운드 리셋:** `ball_round_state`가 `ball_vel` 재서브 + `skip_ball_motion_step=false` 강제 →
  반사 속도는 라운드 경계 못 넘음 → **진행 중 재발사 체인은 라운드 리셋에서 폐기**. 호스트
  `reset` 경로가 `reset()` 호출 → 자동 정리. 스모크 봉인(S10).
- **펫 전환:** 쿨다운은 기존 기전으로 보관/복원. 모듈 체인 상태는 `reset()`로 정리.

---

## §6 코드 배선 슬라이스

**신규 파일:**
- `godot/scripts/lingpet/lingpet_solar_bolt_skill.gd`
- `godot/scripts/lingpet/lingpet_solar_bolt_payload_factory.gd` (스파크/번개 dict 빌더, **선택** —
  만들면 `gameplay_lingpet_module_catalog.gd:16` 등록 + 카탈로그 해석 스모크 필수(thunder_orb 패턴).
  안 만들면 dict 빌더를 모듈에 인라인해 이 오버헤드 회피. 리뷰 Medium #2)
- `godot/tests/lingpet_solar_bolt_skill_smoke.gd`

### §6.1 디스패처 `lingpet_skill_dispatcher.gd`
- `const SKILL_KIND_SOLAR_BOLT := "solar_bolt"` (≈12행)
- `const SOLAR_BOLT_SKILL_ID := "lumion_solar_bolt"` (≈28행)
- `SUPPORTED_SKILL_KINDS`에 `SKILL_KIND_SOLAR_BOLT: true,`
- `get_skill_kind` match에 `SOLAR_BOLT_SKILL_ID: return SKILL_KIND_SOLAR_BOLT`
- `static func is_solar_bolt(skill_id) -> bool`

### §6.2 호스트 `lingpet_skill_runtime_host.gd`
- `const SOLAR_BOLT_SKILL_PATH`, `var _solar_bolt_skill`, `_get_solar_bolt_skill()` 지연 게터(≈613)
- match 케이스:
  - `update`(72): `_get_solar_bolt_skill().update(safe_delta, owner, registry, launch_context)`
    — **launch_context 전달**(companion_pos·ball_* 포함). (시그니처 v1.1 정정)
  - `can_arm`(≈186): **기본 true 아님** — D2 전체 게이트 구현(wild_roar 패턴, `_get_context_or_owner_vector2`)
  - `is_launch_blocked`(156): `is_active()` (천둥 뇌구처럼)
  - `launch`(211): `launch(origin, owner, launch_context)`
  - **`get_launch_origin`(240-275): HOST match에 SOLAR_BOLT 케이스 추가** — `companion_pos`
    (또는 `+Vector2(0,-radius-8)`). **스킬 레벨 `get_launch_origin`은 호출 안 됨 — 만들지 말 것.**
    (v1.1 정정)
  - `trigger_launch_feedback`(375): 금색 플래시 + 셰이크
  - `_get_skill_for_kind`(557): 프리웜
- 비-스위치 순회 목록에 `_solar_bolt_skill` 추가: `reset`(46), `_draw_skill`(104),
  `has_visible_effects`(124), `_merge_skill_snapshot`(419).

### §6.3 에그 런타임 `lingpet_egg_runtime.gd`
- `launch_context` dict(1678-1692)에 1줄: `"refire_chance_pct": float(current_active_skill.get("refire_chance_pct", 50.0)),`
  (`active_skill_level`은 1683행 이미 스레딩.)

### §6.4 공 파이프라인 + 소유권 (v1.1 강화)
- 반사 = `owner.set("ball_vel", v)`. 1차에 `player_collision_cooldown ≥ 6.0`(D10).
- **소유권:** 매 스트라이크에 `_get_registry_instance(registry,"ball_intensity").register_contact("lingpet","player",{...})`
  — body-hit 가드 `_register_ball_intensity_contact`(`lingpet_companion_body_hit_state.gd:176-179`) 미러.
  `ball_intensity.gd:56-68`이 `last_hit_by`/rally 갱신. **wild_roar reflect는 이걸 안 하므로 복사 금지.**

### §6.5 오디오 `game_audio` (RESOLVED — 원본 패리티 포팅 완료 2026-06-14)
- 원본 `devinethunder.wav`(pygame volume 0.5, `hero_skills.py:16260`; 디바인쉴드 번개요격과 **동일 음원**
  `SOUND_DIVINE_THUNDER`)를 **Godot로 바이트 동일 포팅**: `godot/assets/sounds/devinethunder.wav`
  (+`.import` 사이드카), `SOLAR_BOLT_STRIKE_SOUND_PATH := "res://assets/sounds/devinethunder.wav"`,
  gain **−6.0206dB(=원본 0.5 음량과 일치)**. `play_solar_bolt_strike()`가 **pitch 1.0(원본 `_sound.play()`
  무변조 패리티)**로 재생, `trigger_launch_feedback`에서 호출. **이전 라그나로크샷 fallback + 피치 변조 폐기
  — 이제 원본 음원·피치와 동일.**
  검증: 헤드리스 로드(wav import)·solar_bolt 스모크·경고스캔 통과.

### §6.6 카탈로그 `lingpet_catalog.gd` — 루미온 풀 전환 + 해치 정책
현재 단일 `active_skill`(466-477) → `active_skill_pool` 배열(maribo 154-185 패턴). solar_bolt를
두 번째 항목으로. **링코어 모델에서 풀 = 2중1 해금 후보군.**

```gdscript
"active_skill_pool": [
	{ ...기존 lumion_thunder_orb 그대로 (pool[0])... },
	{
		"id": "lumion_solar_bolt",
		"runtime_kind": "solar_bolt",
		"name": "천둥 낙뢰",          # §7 네이밍 노트: 천둥 뇌구와 혼동 위험 — 차별화 검토
		"description": "태양신의 번개가 내려오는 공을 내리쳐 보스 진영으로 되돌려보냅니다. 레벨이 오르면 일정 확률로 1초 뒤 보스를 향해 번개가 한 번 더 내리칩니다.",
		"cooldown": 22.0,             # D6 플레이스홀더
		"windup_seconds": 0.0,
		"refire_chance_pct": 50.0,
		"card_texture_path": "res://assets/sprites/lingpet/lumion_solar_bolt_skillcard_imagegen_v1.png",
		"icon_texture_path": "res://assets/sprites/lingpet/lumion_solar_bolt_skill_icon_imagegen_v1.png",
	},
],
```
- **해치 노출 정책(v1.2 — Codex High #2):** 사용자 설계상 신규 모델은 **부화 즉시 스킬 0, 친밀도로
  해금**이다. 따라서 `active_skill_pool`은 **친밀도 2중1 해금 후보군**이지 `pick_skill_loadout` 랜덤
  해치-픽 대상이 아니어야 한다 — 그대로 두면 `lingpet_catalog.gd:1132-1146`의 랜덤 픽이 해금 전
  Solar Bolt를 그냥 튀어나오게 한다(획득 의미 붕괴). **결정:**
  1. solar_bolt **모듈/디스패처/호스트/스모크는 standalone으로 지금 빌드** — 카탈로그 미노출이라 랜덤픽
     영향 0, 친밀도 작업과 독립적으로 검증 가능.
  2. **카탈로그 풀 노출 + `pick_skill_loadout` 비활성화(no-skill-at-hatch)는 친밀도 해금 작업과 같은
     슬라이스에서 합류.** 그 작업이 active 배정을 소유하면 풀은 자동으로 '해금 후보'로만 읽힌다.
  3. 기존 저장 루미온 thunder_orb는 `normalize_active_skill_id`로 유지(save-compat).
  - 스모크: '신규 해치 루미온이 의도된 상태(무보유 또는 default)로 resolve' + '해금 후 의도 액티브
    resolve' + '기존 세이브 로드'.
- `effect_text`(478)/`note`(481) 두 스킬 모두 언급하도록 갱신.
- `_validate_active_skill`(1281)이 풀 각 항목 `cooldown>0`·텍스처 존재 검증 → 카드/아이콘 자산 선행.

### §6.7 레일 카드 `godot/scripts/stages/common/lingpet_rail_card.gd`
- `get_snapshot()`가 `solar_bolt_active`(+`solar_bolt_refire_pending`) 키 emit.
- 캐스팅 OR 목록(**182-199행** 전체, thunder_orb 키는 193-195)에 그 키 추가. (쿨다운/duration/ready 제네릭.)
- **주의(v1.1):** OR 목록은 선택적이라 wild_roar/banana 등은 빠져 있음 → "OR 추가가 유일 HUD 변경"
  가정 금지. 인게임에서 캐스팅 표시 실측.

### 스킬 클래스 공개 API (호스트 계약 — v1.1 정정)
```gdscript
func update(delta: float, owner: Object, registry: Object = null, launch_context: Dictionary = {}) -> void
func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> void
func can_arm(params: Dictionary) -> bool          # D2 전체 게이트
func draw(canvas: CanvasItem, shake_offset := Vector2.ZERO) -> void
func reset() -> void
func prewarm() -> void                            # 텍스처 없으면 pass
func is_active() -> bool
func is_projectile_active() -> bool               # is_launch_blocked + 캐스팅 표시용 (VFX/체인 진행 중)
func has_visible_effects() -> bool
func get_snapshot() -> Dictionary                 # "solar_bolt_*" 키
# get_launch_origin은 스킬에 두지 않음 — HOST match 케이스로 처리(§6.2)
# 테스트 접근자
func get_strike_count_for_tests() -> int
func get_scheduled_refires_for_tests() -> int
func set_force_roll_for_tests(value: float) -> void
```

---

## §7 자산

| 자산 | 형식 | 비고 |
|---|---|---|
| 번개+플래시+스파크 | **절차적 즉시-draw — 원본 SolarBolt 문양 충실 포팅 (v1.3)** | `_gen_lightning`/`_subdivide`(재귀 분기) + `_draw_effect`(4레이어) + `_draw_explosion`(3링/방사아크) + streak/dot/flash 스파크. 메인 금색, 분기 라벤더, 폭발아크 청백(원본 색). 매 프레임 Surface 할당·rotate 없음(즉시 draw_polyline) |
| 스킬 카드 | PNG (imagegen) | `lumion_solar_bolt_skillcard_imagegen_v1.png` |
| 스킬 아이콘 | PNG (imagegen) | `lumion_solar_bolt_skill_icon_imagegen_v1.png`. 알파 코너/bbox QA |
| 컴패니언 캐스트 포즈 | 기존 `lumion_companion_strike` 재사용 | 발동 시 스트라이크 애님(D3) |

- **네이밍/아이콘 차별화(리뷰 note):** 천둥 뇌구·천둥 낙뢰 둘 다 "천둥*" 번개 스킬이라 해금 카드·
  레일 카드에서 혼동 위험. 카드 제목/실루엣을 구분(예: 반사형 정체성 강조 "태양 낙뢰" 또는
  "낙뢰 반사", 아이콘 = 하강 볼트가 공 때리고 위 화살표 vs 뇌구의 이동 구체). **두 카드가
  나란히 보이는 디버그/QA surface에서 QA.** (현재 `name`은 사용자 지정 "천둥 낙뢰" 유지 — 변경 시 확정 필요.)

---

## §8 스모크 브리프 `lingpet_solar_bolt_skill_smoke.gd`

> 헤더: 공은 **`vel*delta*60`**로 핸드 어드밴스(raw `vel` 금지). 실패 방향 먼저 쓰고 단언.
> OUTCOME(`ball_vel.y<0` / 보스 방향) 단언, 시도 플래그 금지. ([[feedback_godot_ball_vel_pxframe_units]])

| ID | 단언 |
|---|---|
| S1 | 하강공(하단 절반, 플레이어 못 막음) launch → 반사 후 `ball_vel.y<0` |
| S2 | 1차 속도 보존: `ball_vel.length()` ≈ 반사 전(±콘), 최소 상승 `nvy≤-1.0` |
| S3 | `can_arm` 게이트: 상승/상단절반/`_player_can_block`/`companion_visible=false`/`skip_ball_motion_step=true` 중 하나라도면 `false` |
| S4 | **(압축 트랩 봉인)** Lv.3 프리롤 **강제 실패** → 총 1타(재발사 0). 매-프레임 재롤 없음 |
| S5 | 레벨별 체인: Lv.2→0 / Lv.3-4 강제성공→2타 / Lv.5 강제성공×2→3타 / Lv.5 첫롤실패→1타(둘째 롤 없음) |
| S6 | `skip_ball_motion_step` 미설정(소스+상태), 공 미소유 |
| S7 | 재발사 타이밍 ~1.0s(delta 틱), 벽시계 아님 |
| S8 | **(v1.2)** 재발사 시 공이 상승 중이어도 `ball_vel`이 **현재 보스 중심 방향**, no-op 아님. **보스 중심이 이동/변경돼도 각 follow-up 방향이 그 순간 현재 중심을 향함**(1회 재조준, per-frame 추적 아님). 크기 = `_speed_locked` |
| S9 | 재발사 시점 `ball_active=false` → 재발사 스킵, 크래시/스트레이 없음 |
| S10 | `reset()`/라운드 리셋이 체인·VFX 클리어 → 경계 후 재발사 없음 |
| S11 | 새 owner 키 불요(체인 상태 모듈 내부, 스냅샷에 카운트 노출) |
| S12 | 쿨다운/재발사 타이머 delta 기반 — `update` 미호출 시 동결(모달 안전) |
| S13 | **(v1.1 신규)** 반사 후 `ball_intensity.last_hit_by == "player"`(소유권 귀속, D13) |
| S14 | **(v1.1 신규)** 1차 반사 프레임에 `player_collision_cooldown ≥ 6.0`(즉시 재포착 방지, D10) |
| S15 | **(v1.1 신규)** solar 반사(`ball_vel.y<0`) 후 다음 틱 defense 인터셉트 disarm(`ball_vel.y≤0`에 클리어) → 더블 바운스 없음 |

- 골격: `lingpet_thunder_orb_skill_smoke.gd` FakeOwner/FakeRegistry/FakeAudio + ball_intensity 페이크.
- S4/S5는 `set_force_roll_for_tests` RNG 주입. **성공-only 테스트 금지**(압축 버그 가림).

---

## §9 트랩 체크리스트

- [ ] **매-프레임 확률 롤 트랩 (최우선):** launch 시 1회 프리롤(매-프레임 롤 부재). **봉인:** S4/S5.
  `lingpet_ring_dash_state._rolled_this_descent` 선례. ([[feedback_godot_ball_vel_pxframe_units]] 별개)
- [ ] **ball_vel px/frame:** `_speed_locked = ball_vel.length()`(px/frame, base7.65/cap26). **봉인:** S2/S8.
- [ ] **Owner-Field Schema:** `ball_vel`/`player_collision_cooldown` 기선언, 소유권은 register_contact.
  새 영속 키 신설 금지. **봉인:** S11.
- [ ] **핫패스 지연 init + 프리웜:** `prewarm()` 구현(텍스처 없으면 pass), 모듈 인스턴스화는
  `_prewarm_current_skill_runtime`(로드아웃) 커버. **봉인:** `_verify_loadout_apply_prewarms_active_skill_runtime`.
- [ ] **`skip_ball_motion_step` 미사용:** 1프레임 반사 → 소유 플래그 불요. **봉인:** S6.
- [ ] **즉시 재충돌(D10):** body-hit 선례는 ball_pos+쿨다운도 씀. solar는 `player_collision_cooldown≥6`
  + D2가 패들 위에서만 발동. **봉인:** S14.
- [ ] **defense 인터셉트 이중발동(리뷰):** D2 `_player_can_block==false`로 비위협 제외 + solar 반사가
  인터셉트를 다음 틱 disarm. **봉인:** S15. (CLAUDE.md "두 자동 세이브" 경고)
- [ ] **공 소유권 귀속(D13):** register_contact("lingpet","player"). **봉인:** S13.
- [ ] **컴패니언 walk/idle + 모달 일시정지:** 즉발 리플렉스라 park 안 함(위치 오버라이드 없음).
  스트라이크 애님 accumulator 구동. **표기:** 비해당에 가깝지만 명시.
- [ ] **라운드 리셋 정규화:** `reset()`에서 예약 체인 클리어. **봉인:** S10.
- [ ] **쿨다운 벽시계 (비해당):** delta 기반, 모달과 함께 동결. `Time.get_ticks_msec()` 금지. **봉인:** S12.
- [x] **홀리배리어 owned-ball 트랩 (검증 — 비해당/안전):** solar는 skip 플래그를 안 써서 반사된 공이
  정상 `step_motion` 경로(holy barrier/floor/brick 처리 유지). 홍련 inferno류와 반대. **미래 독자가
  "고친다"고 skip 소유 추가 금지.**

---

## §10 완료 결정 / 오픈 항목

**확정:** D1~D14. Q1~Q4 사용자 확정 + v1.1 리뷰 반영.

**합류 의존 (V3-1/V3-2 — 2026-06-30 현재 완료):**
- **A. unlock-choice → loadout 배선:** 친밀도 해금 결과를 로드아웃 slot-0/slot-1에 쓰는 소비자는
  V3-2c/V3-2d에서 랜딩했다. Solar Bolt는 Lumion active pool 후보이고, unlock/loadout reconciler가
  선택 결과를 현재 런타임 로드아웃에 반영한다. (D14)
- **B. second-active 레벨 reading:** V3-2 합류 완료. 프로파일이 slot-aware active bonus를 읽고,
  second slot에 solar_bolt가 들어가도 `second_active_skill_bonus` 기반 스케일(재발사 포함)이 동작한다.
  (두 액티브 동시 = loadout/owner schema/TAB/skill controller/host 변경 = V3-2 완료 범위.)

**오픈(착수 시 확인):**
1. 베이스 쿨타임 22s + 체인길이 가산(+4~6s/추가타) — V3-6 income/밸런스 QA 확정.
2. `_player_can_block` 헬퍼 — ring_dash/motion_state 미러(slot 위치 무관 공용).
3. ~~오디오 메서드~~ — **RESOLVED(2026-06-14):** `devinethunder.wav` 원본 패리티 포팅 완료(§6.5).
4. 금색 카드/아이콘 imagegen + 네이밍 차별화(§7).
5. 보스 중심(`_get_boss_rect`) 재사용 — thunder_orb 헬퍼 공유 or 복제.

---

## 부록 A — 수치 빠른참조

| 항목 | 원본 (`hero_skills.py`) | Godot 포팅값 |
|---|---|---|
| 쿨타임 | `cooldown=12.0` | 22.0 베이스 + Lv.5 −12% (플레이스홀더) |
| 윈드업 | 없음 | 0.0s |
| 1차 base_angle | bottom `-pi/2` | `-PI/2` (위) |
| 1차 콘 | `uniform(-pi/4,pi/4)` | `randf_range(-PI/4,PI/4)` |
| 속도 | `max(1, hypot)` 보존 | `maxf(1, ball_vel.length())` px/frame |
| 최소 상승 | bottom `nvy≥-1→-1` | 동일 |
| 발동 게이트 | bottom `vy>0 AND cy≥375` | `+ _player_can_block=false + visible + companion≠0 + not skip` |
| 번개/폭발 TTL | 0.20 / 0.38 | 동일 |
| 스파크 | `SPARK_COUNT=22` | 동일(절차적) |
| 플래시/셰이크 | `0.15s (255,230,100)`, `shake 6` | 동일 |

## 부록 B — 원본 대비 의도적 분기

| 항목 | 원본 | 이 포팅 |
|---|---|---|
| 재발사 체인 | 없음 | 링피아 신규: Lv.3+ 50%×1 / Lv.5 체인×2. 프리롤 |
| 재발사 동작 | — | **launch-time 프리롤 후속타, 각 후속타 1회 보스 중심 재조준**(per-frame homing 아님; 상승공 no-op 회피) |
| 1차 vs 재발사 수학 | 단일 콘 반사 | 1차=콘 반사(패리티) / 재발사=보스 조준(분기) |
| 시전자/원점 | 영웅 패들 중심 | 플레이어측 링펫 컴패니언(라이브 위치) |
| 발동 범위 | bottom 하단절반(패들스킬) | 필드 전체(Q3) + `_player_can_block` 비위협 제외 |
| 쿨타임 | 12.0 | 22.0(확정세이브, 보스-스턴 형제 25 대비) |
| 레벨 스케일 | 없음 | 쿨타임 점감 + 재발사 체인 |
| 단위 | px/frame (substep 스케일) | px/frame (Source A plain, substep 미포팅) |
| 해금 | 아레나 영웅 고정 | 링코어/친밀도 게이트(§13) — **배선 선결조건 A/B 필요** |

---

## 적대적 리뷰 로그

> **2026-06-14 — 리뷰 2렌즈(배선/코드충돌 + 게임플레이), v1.0 → v1.1.** 적용한 수정:
> - **(must) update 시그니처:** `(…, companion_pos)` → `(…, launch_context: Dictionary)`. 호스트
>   4번째 인자는 launch_context(=forwarding된 params, companion_pos 포함). §3/§6.2/API/§2 정정.
> - **(must) get_launch_origin:** 스킬 메서드 아님(죽은 코드) → HOST match 케이스. §6.2/API 정정.
> - **(2026-06-30 fixed) 과거 친밀도 레벨 배선 공백:** V3-2에서 unlock-choice→loadout 소비자와
>   second active bonus reading이 랜딩했다. D14/§10은 현재 완료 상태로 정정됨.
> - **(must) D9 재발사 no-op:** 상승공에 "또 위로 반사"는 무의미 → **보스 중심 재조준**(Q2 충실
>   해석)으로 변경. §1 재발사 수학 블록 + S8 정정.
> - **(must) defense 인터셉트 충돌:** D2에 `_player_can_block==false` 추가 + solar 반사가 인터셉트
>   disarm. D5/§9 + S15.
> - **(should) 공 소유권:** wild_roar 복사로는 누락 → `ball_intensity.register_contact("lingpet","player")`
>   미러. D13 + §6.4 + S13.
> - **(should) 재충돌:** bare ball_vel만으론 저속 반사 재포착 위험 → `player_collision_cooldown≥6`
>   + 패들 위 발동. D10 + S14.
> - **(should) 해치 정책:** 풀 전환 = 신규 해치 랜덤픽 → 정책 명시 + 해치-resolve/save-compat 스모크. §6.6.
> - **(should) 쿨타임:** 16 → 22 베이스(보스-스턴 형제 25 대비, 확정 트리플세이브 가격). D6.
> - **(should) 레일 카드:** OR 목록 선택적(wild_roar 등 부재) → get_snapshot 키 emit + 인게임 실측. §6.7.
> - **(note) 홀리배리어:** skip 미사용 → 정상 step_motion 처리, 검증-안전으로 §9 기록.
> - **(note) 네이밍:** 천둥 뇌구/천둥 낙뢰 혼동 위험 → 차별화 검토(§7 오픈).

> **2026-06-14 — Codex 리뷰, v1.1 → v1.2.** Looks-good: 반사 조건/속도 보존/launch-time 프리롤
> (매-프레임 롤 함정 회피). 적용:
> - **(2026-06-30 fixed) 출시 범위:** 과거 리뷰는 액티브 1개 런타임을 전제로 Solar Bolt를
>   slot-1 교체형으로 먼저 출시했지만, 현재는 V3-2 multi-active path가 랜딩되어 second active slot에서도
>   slot-aware level로 동작한다. 헤더 출시-범위 callout 정정.
> - **(High) active_skill_pool 노출:** 랜덤 해치-픽이 해금 전 노출시킴 → 풀=해금 후보군, 카탈로그 노출은
>   친밀도 해금 작업과 합류(no-skill-at-hatch), 모듈은 standalone 선빌드. §6.6 재작성.
> - **(Med) 오디오:** 전용 `play_solar_bolt_strike()` 기본, 재사용은 부록 B 명시. §6.5 확정.
> - **(Med) payload factory:** 사용 시 `gameplay_lingpet_module_catalog.gd` 등록 + 해석 스모크. §6 명시.
> - **(확정) D9 어휘 잠금:** 'homing'(유도탄) 어휘 금지 → "launch-time prerolled follow-up strikes;
>   each follow-up retargets once toward current boss center; no per-frame homing". 속도 = 첫 타격
>   직전 `_speed_locked` 보존, 방향 = 실행 순간 `ball_pos`→`boss_center`, fallback `Vector2(0,-1)`,
>   Lv5 최대 3타 고정. S8이 '보스 중심 이동 시에도 그 순간 현재 중심 조준' 봉인.

> **2026-06-14 — 구현 리뷰 3렌즈(스모크 변이 + 정확성/트랩 + 배선), v1.2 구현 검증.**
> - **정확성/트랩: SEAL-CLEAN (ship-ready).** §9 트랩 9건 전부 충족 — 매-프레임 롤 구조적 차단(randf는
>   launch의 `_schedule_refires`에서만, 체인 break-on-fail), ball_vel px/frame(min-upward는 magnitude
>   보존 재정규화), D9 1회 재조준(ball_center 사용), skip 미사용, register_contact 매 스트라이크,
>   `_player_can_block` 실제 탄도 예측. **모듈 버그 0.**
> - **배선: 계약 end-to-end 일치, silent no-op 0.** dispatcher(:12/29/47/81/131)·host(모든 match
>   블록 + 비스위치 순회)·egg(:1696 refire_chance_pct)·rail(:196-198 키 일치)·audio(:1861) 전부 확인.
>   카탈로그 미노출 유지(스코프 OK).
> - **당시 남은 봉인 갭 (아래 2026-06-14 SEALED 로그로 닫힘):**
>   1. (must-for-seal) **S15 당시 공백** — defense 인터셉트 disarm/더블바운스 방지 스모크 0개. 모듈 동작은
>      올바름(반사가 `ball_vel.y<0` → 인터셉트가 자기 `ball_vel.y<=0` 게이트로 자동 disarm = emergent),
>      단 **계약상 S15 봉인이 빠짐**. 실 `lingpet_companion_motion_state` 인터셉트를 reflect 후 1틱 돌려
>      disarm OUTCOME 단언 추가.
>   2. (should) **S2 후속타 속도 re-read 변이 미적발** — 후속타 직전 `owner.ball_vel`을 다른 크기(예: 40)로
>      세팅 후 `_speed_locked` 유지 단언해야 re-read 변이가 FAIL.
>   3. (should) **S4/S5 fire-time 재롤 변이 미적발** — 프리롤 소비분보다 많은 강제 롤(여분=FAIL) 주입해
>      schedule-후-fire-재롤 변이 적발.
>   4. (should) **catch-up delta** — `_update_refires` while→if(타이머 carry)로 1 update당 최대 1 refire,
>      물리 캐치업 스파이크에서 1.0s 케이던스 붕괴 방지([[project_physics_catchup_redraw_spiral]]).
>   5. (note) S6 후속타 skip 재확인 + 모듈 소스 grep, S14 maxf-보존 케이스, S10 host.reset 경로 스모크.
> - **§6.7 경로 정정 반영:** 실제 `godot/scripts/stages/common/lingpet_rail_card.gd:196-198`.

> **2026-06-14 — 봉인 갭 재검증 → SEALED.** 배선측 후속 5건 모두 정확히 반영·검증 완료:
> - (must) **catch-up clamp** `_update_refires` `while`→`if` + `timer_carry`(오버슈트 음수 이월) →
>   update당 최대 1 refire, 거대 delta에서도 케이던스 따라잡음. 봉인: lv5 update(2.05)→2타/잔여1,
>   update(0.0)→3타/잔여0.
> - (must) **S15 크로스모듈** — 실 `LingpetCompanionMotionState` arm → 반사 → 1틱 → `defense_intercept_active=false`
>   + decision timer clear OUTCOME 단언. (옵션 하더닝: 하강공 유지 카운터케이스 — 비차단.)
> - (should) **S2** 후속타 직전 `ball_vel=(0,40)` 변이 후 length≈`_speed_locked`(≠40); **S4/S5** fire-time
>   재롤 변이(여분 FAIL 롤); **S14** 기존 9.0 cooldown maxf 보존; **S10** host.reset; **S6** 소스 grep.
> **결론: 모듈·배선·스모크 전부 SEAL-CLEAN. standalone 런타임 출시 준비 완료.** 잔여는 친밀도 해금
> 슬라이스 합류 시 카탈로그 노출 전환(§6.6) + 자산(금색 카드/아이콘 imagegen, 네이밍 §7) + V3-6 수치 튜닝(쿨타임 등).
