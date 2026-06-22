# 코만도 권총강화(pistol_enhance) 퍽 — 슬라이스 설계 (단일 소스)

작성 2026-06-21. 이 문서가 단일 소스다. 배선은 Codex/직접, Claude는 적대적 리뷰.
라우팅: `docs/character_skill_perk_checklist.md` + `CLAUDE.md`(효과-레벨 오버플로우 opt-out, 아이콘 elif/registry 트랩).

## 0. 요약

코만도(soldier) 전용 **상시 패시브 강화 퍽**. 쿨다운/발동/오브 없음. 5레벨.
**기본권총만** 강화한다 — 베레타(commando_pistol)는 스프레드/탄약 모두 범위 밖, 무수정.

두 효과:
- **A. 정확도** — 기본권총 스프레드 반각을 레벨별로 좁힘 (기본 ±15° → Lv5 ±1°).
- **B. 탄창** — 기본권총 탄창을 Lv3 +1, Lv5 추가 +1(누적 +2).

## 1. 수치 계약 (확정)

### A. 스프레드 반각 (기본권총 전용)
| 레벨 | 반각 | rad | 비고 |
|---|---|---|---|
| Lv0(미보유) | ±15° | `PI/12` = 0.261799 | 현 기본값, 폴백 |
| Lv1 | ±12° | `deg_to_rad(12)` = 0.209440 | |
| Lv2 | ±9° | 0.157080 | 베레타(±10.5°)보다 타이트해지기 시작 |
| Lv3 | ±6° | 0.104720 | + 탄창 |
| Lv4 | ±3° | 0.052360 | 풀거리 명중 ~100% 진입 |
| Lv5 | ±1° | 0.017453 | + 탄창, 사실상 레이저 |
| 베레타 | ±10.5° | `BERETTA_SPREAD_RADIANS` | **무수정** |

체감 환산(풀거리 ~640px, 보스 반폭 50px → 명중 허용각 `atan(50/640)≈4.47°`, 명중률 ≈ `min(1, 4.47/반각)`):
Lv0 ~30% → Lv1 ~37% → Lv2 ~50% → Lv3 ~75% → **Lv4~5 ~100%**.
→ Lv4부터 풀거리 명중이 포화되므로 Lv5의 ±1°는 명중률 이득보다 "정밀 폴리시", Lv5의 실 보상은 탄창 +2. (사용자 지정 커브 그대로 채택.)

### B. 탄창 (기본권총 전용)
| 레벨 | 델타 | 유효 탄창 | 베레타 |
|---|---|---|---|
| Lv0~2 | +0 | 5 | 12 (무수정) |
| Lv3~4 | +1 | 6 | 12 |
| Lv5 | +2 | 7 | 12 |
| **Lv6+** | **+1/레벨 계속** | 8, 9, … | 12 |

기준 상수 `PISTOL_AMMO_MAX := 5`. 보너스 함수(레벨 ≥6는 계속 증가, 결정 2 참조):
```
func _pistol_enhance_ammo_bonus(level: int) -> int:
    if level <= 2: return 0
    if level <= 4: return 1      # Lv3, Lv4 → +1
    return level - 3             # Lv5 +2, Lv6 +3, Lv7 +4, … (오버플로우 계속 스케일링)
```

## 2. 결정 (권장값 — 이의 없으면 확정)

1. **레벨업 시 탄창 정책**: 증가 시 **즉시 top-off**(현재 탄을 새 최대치로 채움), 감소(언이큅→0) 시 현재 탄을 새 최대로 clamp-down. *(권장. "다음 재장전 때 채움"은 체감 약함.)*
2. **Lv6+ 오버플로우(transcendent_crown/sage_ring) — 확정**: **두 레인을 분리.**
   - **스프레드는 Lv5(±1°)에서 캡** — `clampi(level,0,5)`로 테이블 조회. ±1°는 이미 사실상 0에 가까운 바닥이라 더 줄일 의미가 없고 음수 방지. (스프레드 한 레인만 캡이므로 CLAUDE.md "계속 스케일링 기본"의 *합리적 바닥* 케이스.)
   - **탄창은 Lv6부터 +1/레벨 계속 증가** — `level-3`(Lv5 +2, Lv6 +3, …). 캡 없음 → CLAUDE.md 오버플로우 opt-out 기본과 **합치**, 별도 예외 기록 불필요.
   - 효과 지점: 스프레드는 `clampi(level,0,5)` 적용, 탄창은 **clamp 없이** 보너스 함수 그대로.
3. **표시명/키**: 표시명 `권총강화`. 현지화 키는 `pistol_enhance` 그대로(별칭 불필요). soldier_unlock_* 네임스페이스 일관성을 원하면 `PERK_LOCALIZATION_ALIASES`에 `pistol_enhance→soldier_pistol_enhance` 추가.
4. **어휘**: 각도 정확도는 베레타 카피와 동일 레지스터 `정확도`/`accuracy` 사용(kick_enhance의 `정밀도`/`precision` 아님).
5. **아이콘 패밀리**: 캐릭터 전용 패시브/강화 → 라운드/오브 스타일(viper 강화 아이콘 계열). **첫 soldier 패시브-강화 아이콘**이라 신규 PNG 필요(별도 자산 작업).

## 3. 통합 지점 (배선 체크리스트)

미러 패턴: 효과 주입은 **도핑 포션 경로**(deps 읽기→config/options 주입→resolver 소비), 퍽 등록은 **viper kick_enhance**(5레벨 상시 강화), 컨트롤러 도달은 **`runtime_perk_state._sync_commando_weapon_controller`**.

### (R) 등록 — 코드변경 최소, 대부분 자동
- **카탈로그 엔트리**: `runtime_perk_catalog.gd` 의 **SOLDIER_PERKS 블록**(~:571-656)에 `pistol_enhance` 추가. 형태는 `kick_enhance`(:524-538) 복사 — `name/max_level:5/descriptions{1..5}/detail/icon_color/tree:"soldier"/character_restriction:"soldier"`. **`is_weapon_unlock`/`unlocks_skill`/`weapon_name` 절대 금지**(무기언락 패밀리로 오라우팅, 공유 슬롯 소비). 기존 6개 SOLDIER_PERKS는 전부 max_level:1 무기언락이라 **형태 복사 금지**, kick_enhance를 복사.
- **오퍼 풀/적용/세이브/리셋**: **코드변경 0** (검증만). `_append_pool_choices(SOLDIER_PERKS)`(:744)·디버그피커(:825)·일반 레벨업 분기(`runtime_perk_state.gd:1022-1028`)·`get_snapshot`(:1084)·`reset`(:136) 전부 신규 id를 자동 처리. current≥max에서 오퍼 중단(:843-844)도 자동.
- **레벨 읽기**: 효과 지점에서 **`runtime_perk_state.get_runtime_skill_level("pistol_enhance")`** (`:1116`). raw `runtime_skill_levels.get()` 금지(크라운/링 오버플로우 누락). **스프레드 레인만 `clampi(level,0,5)`**, 탄창 레인은 raw level로 보너스 함수(결정 2 — Lv6+ 탄창 계속 증가).

### (A) 스프레드 효과 — 단일 펀넬 훅
- **`commando_firearm_runtime._spawn_firearm_effect`** 옵션 딕셔너리(:1226) `"pistol_spread_radians": PISTOL_SPREAD_RADIANS` 를 **퍽 레벨로 계산한 유효값**으로 교체. `deps`가 이미 이 함수에 있음 → `lvl=get_runtime_skill_level(...)`, 테이블 `[12,9,6,3,1]°`(clamp), `lvl<=0`이면 `PISTOL_SPREAD_RADIANS`(15°).
  - **즉시발사(`pistol_input_state:102`)·24프레임 지연발사(`timer_state:136`) 둘 다 `_spawn_firearm_effect`로 수렴** → 단일 훅으로 양쪽 커버. ⚠️(HIGH 트랩) 두 경로 중 하나만 손대면 지연발사가 옛 스프레드 유지.
- **베레타 격리는 구조적으로 보장**: 스프레드 선택은 `commando_firearm_profile_resolver.gd:92` 한 줄뿐 — `weapon_id=="commando_pistol" ? beretta_spread_radians : pistol_spread_radians`. base 분기(`else`)만 바뀌므로 베레타 무수정. **per-level 테이블이 공유 상수 `PISTOL_SPREAD_RADIANS`를 변형하지 말 것**(베레타가 그걸 0.70배로 파생). 별도 유효값으로.
- 스프레드 적용 가드(`profile_resolver.gd:87-91`)는 `not profile.has("angle_offset")` AND non-slingshot일 때만 → 일반 기본권총 발사는 통과, AK47/슬링샷/명시offset 경로는 면제(정상).

### (B) 탄창 효과 — 컨트롤러 setter + 매프레임 재적용
- **권위 소스 = `commando_weapon_controller`의 `base_weapon_runtime["ammo_max"]`** (시드 `PISTOL_AMMO_MAX=5`). ⚠️(HIGH 트랩) `commando_firearm_runtime.gd:987`의 `pistol_ammo_max` 옵션은 **죽은 폴백**(컨트롤러가 항상 ammo_max 공급) — 그것만 고치면 인게임 무변화. **컨트롤러를 고쳐야 함.**
- 컨트롤러에 `set_base_pistol_ammo_max(int)` (또는 `set_base_pistol_ammo_bonus`) 추가: `base_weapon_runtime["ammo_max"]=PISTOL_AMMO_MAX+bonus`, 증가 시 `ammo_current`/`reload_display_ammo` top-off, 감소 시 clamp-down(결정 1).
- **호출 지점 = `commando_firearm_runtime.update_input`** (매프레임, deps 보유, 이미 `weapon_controller.update_timers` 호출 :605-606). 여기서 `bonus = _pistol_enhance_ammo_bonus(get_runtime_skill_level("pistol_enhance"))`(§1.B 함수, **clamp 없음** — Lv6+ 계속 증가) → setter. ⚠️(HIGH 트랩) `controller.reset()`(:120)가 base_weapon_runtime를 템플릿에서 재시드 → bonus 소실. **매프레임 재적용이 reset/round/stage 후 자가치유**(별도 reset 보존 불필요).
- ⚠️(INFO) selector_renderer 탄환 핍 표시는 최대 12 슬롯 clamp(:1452). 크라운/링 극단 오버플로우로 유효 탄창이 >12가 되면(예: Lv10 → 12, Lv11 → 13) 핍이 12에서 멈춤 — 코스메틱 한계, 게임플레이 탄창값은 정상.
- **리필/재장전 자동 반영**: `_update_base_pistol_reload`(:654, 완료 시 `ammo_current=ammo_max`)·`prepare_stage_start`(:299 refill)·`_refill_basic_ammo_to_max`(:760)가 전부 dict의 `ammo_max`를 읽음 → setter가 dict를 갱신하면 자동. 폴백 `.get("ammo_max",PISTOL_AMMO_MAX)`(:617/641/735/736)도 유효 헬퍼로 교체 권장(키 누락 안전).
- **베레타 독립 확인**: `_apply_pistol_display_fields`(:706)·`_refill_pistol_to_max`·`_sanitize_*`가 commando_pistol ammo_max를 무조건 12로 강제 → bonus 누수 불가. 건드리지 말 것.
- **HUD 자동 반영**: selector_renderer(:1361-1362)·ammo_text(:592)가 dict의 ammo_max/current를 직접 읽음 → 추가 작업 없음(7 이하라 슬롯 레이아웃 무리 없음).

### (I) 아이콘 — 누락 시 조용히 깨짐
- **`runtime_perk_icon_renderer.gd` `PERK_ICON_PATHS`에 `"pistol_enhance": "res://assets/sprites/perks/soldier_pistol_enhance_perk_icon.png"` 추가** + `DRAW_SCALE` `"pistol_enhance": 1.06`(kick_enhance 미러). ⚠️(MEDIUM 트랩) 엔트리 없으면 `draw_icon` false 반환 = **무아이콘(절차 폴백 없음)**, 상태 스모크는 통과·비주얼 QA만 잡음. **UNLOCK_ALIASES/배지 블록(:92-124)·SKILL_ICON_PATHS(오브) 라우팅 금지** — 강화 퍽은 PERK_ICON_PATHS 패밀리.
- PNG 자산: item-generation/sprite-generation 파이프라인, 라운드/오브 스타일, 투명코너+알파bbox+Lv.1/Lv.5 라벨 여백(모듈제어 아이콘 사이즈 기준) QA.

### (L) 현지화 — 12개 맵 + 멀티효과 평탄화 트랩
- **`language_settings_data.gd`**: `PERK_NAME_{EN,ZH,JA,ES,PT_BR,RU}` 6개 + `PERK_SUMMARY_{...}` 6개 = **12개 엔트리** 추가(한국어는 카탈로그가 소스). viper_blade_amp 행(NAME :936/995/1054/1113/1172/1231, SUMMARY :1290~) 미러.
- ⚠️(HIGH 트랩) **멀티효과 평탄화**: `language_settings.gd:386-392`가 비-한국어에선 **모든 레벨 설명을 단일 PERK_SUMMARY로 덮어씀** → Lv3/Lv5의 정확도+탄창 2레인 구분은 **한국어 descriptions{1..5}에서만 레벨별 유지**. **6개 SUMMARY 각각이 두 레인(정확도↑ AND 탄창↑)을 한 문장에 모두 담아야** 6개 언어에서 한 효과가 사라지지 않음.
- ⚠️(HIGH 트랩) **localization-sync 봉인**: `localization_coverage_smoke._verify_same_keys`(:99-108)가 12개 맵 키셋 일치 요구(EN-only/NAME만 추가 시 실패), `_verify_perk_catalog`(:225-228) 비-KO 한글 누수 스캔. **NAME·SUMMARY를 6개 언어에 동시 추가**해야 함.

### (T) 스테일 카피 — 기본권총 툴팁
- ⚠️(INFO) `commando_firearm_tooltip_renderer.gd:134` "기본 권총은 **5발** 탄창…" 이 Lv3+에서 스테일(6/7발). 동적화하거나 최소한 감사. (베레타 12발 카피는 무관, 혼동 주의.)

## 4. 스모크 봉인 (반증검증 — 미배선 코드에서 RED)

1. **신규 `commando_pistol_enhance_smoke.gd`** (핵심 OUTCOME):
   - 레벨→스프레드: `runtime_skill_levels{pistol_enhance:N}`로 유효 `pistol_spread_radians`가 N=1..5에서 `deg_to_rad(12/9/6/3/1)`, N=0에서 `PI/12`. **미배선이면 항상 15°라 N=1..5 단언이 구조적으로 실패.**
   - 레벨→탄창: 유효 base ammo_max == `5 + _pistol_enhance_ammo_bonus(N)` (N=3→6, N=5→7, **N=6→8·N=7→9 오버플로우 계속 증가 케이스 포함**), **베레타 ammo_max는 모든 N에서 12 불변**(범위 밖 가드).
   - 레벨→스프레드 캡: N=6·N=7에서 스프레드는 Lv5 값(±1°)에 머묾(탄창만 증가). **미배선이면 N=6/7에서 탄창 5라 RED.**
   - 베레타 스프레드 격리: 모든 N에서 commando_pistol 분기는 `beretta_spread_radians` 유지(±10.5°).
2. **`commando_perk_catalog_smoke.gd` 확장**: `get_choices("soldier")`에 pistol_enhance 포함 AND `is_weapon_unlock==false` AND `descriptions[3]≠[1]`·`descriptions[5]≠[1]`(탄창 레인이 Lv3 등장·Lv5 증가 증명, Lv1 문자열 복붙 회귀 차단).
3. **`localization_coverage_smoke.gd`**: 카탈로그 진입 시 자동 봉인 + 명시 단언 추가(6개 SUMMARY 각각이 정확도 토큰 AND 탄창 토큰 동시 포함).
4. **퍽-아이콘 스모크**: `RuntimePerkIconRenderer.has_icon("pistol_enhance")==true` AND `_needs_unlock_badge("pistol_enhance")==false`. (commando_icon_alias_smoke는 언락-배지용이라 확장 대상 아님.)
5. **보너스(별건)**: 기존 `commando_firearm_profile_resolver_smoke.gd:111` 베레타 스프레드 단언은 단일 draw 상한이라 teeth 없음(이전 리뷰 지적). base-pistol override 케이스를 추가하며 **상수 비율 락(`BERETTA==PISTOL*0.70`) + 선택 결정론 단언**도 같이 넣어 그 갭을 닫을 수 있음.

각 단언은 in-place 토글로 RED 확인 후 적용(반증검증).

## 5. 결정 현황 / 후속

- 배선 분담: **Codex 핸드오프 + Claude 적대 리뷰** (확정).
- 결정 2(Lv6+): **스프레드 Lv5 캡 + 탄창 Lv6부터 +1/레벨 계속** (확정).
- 아이콘 PNG 생성(첫 soldier 패시브-강화 아이콘) = 별도 자산 작업(라운드/오브 스타일).
- 정확한 카탈로그 블록 const명(SOLDIER_PERKS vs EXCLUSIVE_PERKS+restriction)은 배선 시 파일 확인.

## 6. Codex 배선 순서 (turnkey)

1. **등록**: SOLDIER_PERKS에 `pistol_enhance` 엔트리(kick_enhance 형태, 무기언락 필드 0, character_restriction:"soldier", descriptions{1..5} 정확도°+탄창 두 레인 KO).
2. **효과 A**: `_spawn_firearm_effect` 옵션 `pistol_spread_radians`를 `deg_to_rad(SPREAD_DEG[clampi(lvl,0,5)])`로(lvl=get_runtime_skill_level). 베레타 분기 무수정 확인.
3. **효과 B**: 컨트롤러 `set_base_pistol_ammo_max` setter + `update_input` 매프레임 호출(보너스 함수, clamp 없음). 베레타 12 강제 경로 무수정 확인.
4. **아이콘**: PERK_ICON_PATHS + DRAW_SCALE 엔트리(PNG 자산 준비 후).
5. **현지화**: 12개 맵(NAME×6 + SUMMARY×6), 각 SUMMARY 두 레인 동시 명시.
6. **스테일**: tooltip_renderer:134 "5발" 동적화/감사.
7. **스모크 §4** 작성 — 각 단언 in-place 토글로 RED 확인(반증검증) 후 적용.
8. 커밋 전: warning_scan + headless + 해당 스모크 green, 무관 WIP 분리.

→ 배선 완료되면 Claude가 4관문(누락/베레타격리/오버플로우 분리/스모크 teeth) 적대 리뷰.

## 7. 적대 리뷰 결과 (5게이트, 배선 후)

**게임플레이 APPROVE — 버그 0.** 게이트1·3·5 PASS, 2·4 CONCERNS(격리 자체 확인, CONCERNS는 비-격리 항목). 핵심 teeth(Lv5 스프레드 캡·Lv6+ 탄창 연속)를 인플레이스 토글→RED→복원으로 실증, on-disk 트리 클린(+47-2, stub 잔여 0).

**pistol_enhance 리뷰 완전 종료**: 게임플레이 APPROVE + #2 씰 teeth 실증.
- ✅ **#2 베레타 스프레드 씰 완료**: resolver smoke에 `seed(930105)` 96샘플 결정론 단언 추가. Claude 반증검증으로 resolver:92 회귀 토글 시 "draw spread from the Beretta band" 단언 RED→정확 복원 실증. 단일-draw 갭 닫힘.

**커밋 차단 2건 — 둘 다 무관 Lingpet WIP**:
1. milk_shot 우유발사 비-KO 번역 6건 누락 → `localization_coverage_smoke` RED.
2. `lingpet_skill_runtime_host.gd` `_get_star_coil_skill()` 미정의 parse error(:118/300/354) → `run_warning_scan` RED.
- 공유파일(`language_settings_data.gd`·`localization_coverage_smoke.gd`)을 둘이 함께 수정 → Lingpet WIP 해소 후 커밋 또는 통째 체크포인트.

**아이콘 자산 ✅완료+배치(Claude)**: `godot/assets/sprites/perks/soldier_pistol_enhance_perk_icon.png`(839×840 투명, 제너릭 권총·베레타 배제, 코너0·프린지없음 QA통과) + raw provenance. 마젠타 누끼 `chroma_key.py --key magenta --pad 12`.
**아이콘 배선 ✅완료(Codex)**: PERK_ICON_PATHS 엔트리 + DRAW_SCALE `1.06`(viper강화 미러) + §4.4 스모크(`has_icon==true`/`_needs_unlock_badge==false`, UNLOCK_ALIASES/SKILL_ICON_PATHS 금지). 32px 셀 QA는 `commando_pistol_enhance_smoke.gd`의 레이아웃 단언으로 봉인.

## 8. 효과 C 추가 — 탄환속도 (Lv당 +10%, 기본권총 전용)

### 값
- Lv1~5: 탄환속도 **+10/20/30/40/50%** = 배수 `1.0 + 0.10*level`. 기본 `PISTOL_BULLET_SPEED=25` → Lv1 27.5 … Lv5 37.5 (px/frame).
- **Lv6+ 결정 = Lv5 +50% 캡, `clampi(level,0,5)`**: 스프레드처럼 캡. 이유 ①극단 오버플로우 탄속 폭주 시 보스 밴드(40px) **터널링** 위험(Lv5 37.5는 안전, Lv8+ ≥50px/frame은 1프레임 스킵 가능), ②+50%면 충분. 탄창 레인만 Lv6+ 계속 증가.
- 베레타(commando_pistol, `BERETTA_BULLET_SPEED`) **무수정**.

### 훅 (Effect A 미러)
- 런타임: `get_pistol_enhance_speed_multiplier(level) -> float = 1.0 + 0.10*clampi(level,0,5)`(캡 결정 반영). `_build_firearm_spawn_options`에 `"base_pistol_speed_mult"` 추가(deps perk level).
- `commando_firearm_fire_spawn_state`: `options.get("base_pistol_speed_mult", 1.0)`를 `build_spawn_profile_state`로 전달(신규 **default param** `base_pistol_speed_mult: float = 1.0` → 기본값이라 기존 콜러·스모크 무변).
- `commando_firearm_profile_resolver.build_spawn_profile_state`: **base-pistol 분기**(`is_pistol_weapon` AND `weapon_id != "commando_pistol"` AND `not slingshot`)에서 `profile["speed"] = float(profile.get("speed", …)) * base_pistol_speed_mult`. 기존 `commando_pistol`+doping speed 분기와 대칭. **commando_pistol 분기 무수정 → 베레타 격리 구조적.**

### 트랩
- **베레타 격리**: 속도 배수는 base-pistol 분기에서만. commando_pistol은 doping 분기(별개)라 무영향.
- **슬링샷 격리**: `profile["slingshot"]` override는 기존 charge-level 속도를 보존하고 pistol_enhance speed mult를 받지 않음.
- **도핑 비간섭**: doping speed는 commando_pistol 전용 → base pistol 속도와 무중첩(이중적용 없음).
- **두 발사경로**: `_spawn_firearm_effect` 단일 펀넬이 즉시·24f지연 모두 커버(Effect A 동일).
- **3-레인 설명 클립**: Lv 설명이 정확도+**속도**+탄창 3개로 길어짐 → 퍽 선택 카드/TAB 그리드 클립·wrap 확인(설명 라인 버짓).
- **현지화 3-레인**: 비-KO PERK_SUMMARY 6개는 단일 요약이라 **속도 레인도 추가 명시** 필요(현재 정확도+탄창만).

### 배선 (Codex) ✅완료
1. 런타임 speed mult 함수 + `_build_firearm_spawn_options` + fire_spawn_state 전달 + profile_resolver base-pistol speed 분기.
2. 카탈로그 descriptions 1~5에 `탄환속도 +N%` 추가(3-레인).
3. 6개 PERK_SUMMARY에 속도 레인 추가.
4. 스모크 확장: base pistol effective speed `== 25*(1+0.1*level)` Lv1-5, Lv0=25, Lv6/7 캡 37.5(또는 continue), **베레타 speed 전 레벨 불변**; `_build_firearm_spawn_options` speed_mult 단언; localization summary copy에 **속도 토큰** 추가.
5. 반증검증 후보: speed mult 함수/분기 토글→해당 스모크 RED 확인.

### 리뷰 (Claude)
배선 후: 베레타 speed 격리 / 두 경로 / Lv6+ 캡(또는 continue) / 도핑 비간섭 / 3-레인 설명·현지화 가시성 / 스모크 teeth 반증검증.

선택 하드닝(LOW): switch-away 스모크 / 베레타-탄약 가드 non-tooth / 카탈로그 KO카피 탄창숫자 미봉인 / dead fallback `pistol_ammo_max=5`(무해).

## 9. 효과 D 추가 — 정상타 넉백 길이 (Lv당 +10%, 기본권총 전용)

### 값
- Lv1~5: 기본권총 **정상타 넉백 길이 +10/20/30/40/50%** = 배수 `1.0 + 0.10*level`.
- Lv6+ 결정 = **Lv5 +50% 캡, `clampi(level,0,5)`**. `PISTOL_BOSS_KNOCKBACK_POWER=8.0`의 주석이 과한 보스 플링 위험을 이미 경고하므로 탄속 레인처럼 캡한다. 탄창 레인만 Lv6+ 계속 증가.
- 적용 범위 = **기본권총 정상타만**. 베레타(commando_pistol), 슬링샷, 헤드샷(스턴/넉백 0), 레그샷(`knockback_without_stun` 별도 경로)은 무수정.

### 훅
- 런타임: `get_pistol_enhance_knockback_multiplier(level) -> float = 1.0 + 0.10*clampi(level,0,5)` 추가.
- `_build_firearm_spawn_options`에 `"base_pistol_knockback_mult"` 추가(deps perk level).
- `_spawn_firearm_effect` → `commando_firearm_fire_spawn_state` → `commando_firearm_projectile_spawn_state.build_projectile`로 전달.
- 투사체 carry: `weapon_id == "pistol"` AND non-slingshot일 때만 `"pistol_enhance_knockback_mult"` 저장. 베레타와 슬링샷은 carry 자체가 없음.
- 소비 지점: `commando_firearm_pistol_hit_state.build_hit_payload`의 normal-hit branch에서만 `normal_knockback_power * base_pistol_knockback_mult`. `weapon_id == "commando_pistol"`이면 배수 무시.

### 스모크
- `commando_pistol_enhance_smoke.gd`: Lv0~7 배수 표(1.0~1.5 캡), 기본권총 normal hit power `8*mult`, 베레타 normal hit 8.0 불변, 헤드샷 0, 레그샷 normal `knockback_power` 없음, 투사체 carry는 기본권총만.
- `commando_firearm_pistol_hit_state_smoke.gd`: direct payload와 runtime `apply_runtime_hit_effects` 모두 기본권총 12.0 / 베레타 8.0 단언.
- `commando_perk_catalog_smoke.gd`: KO descriptions/detail에 넉백 레인과 Lv6+ `탄속과 넉백은 +50%` 캡 문구, choice-card 2-line budget 유지.
- `localization_coverage_smoke.gd`: 6개 PERK_SUMMARY가 accuracy/speed/knockback/magazine 4레인을 모두 포함.
