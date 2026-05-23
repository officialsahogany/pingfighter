# 코만도 Godot 포팅 기획서

작성일: 2026-05-06

## 0B. 2026-05-07 기본 무기 방향 전환

포팅 중 live 체감 기준으로 군용새총은 코만도 캐릭터의 첫인상과 화기류 판타지에 맞지 않아 기본 슬롯에서 제거한다. 호환을 위해 내부 기본 슬롯 id `pistol`은 유지하지만, 표시명과 발사 프로필은 이제 `권총`이다.

- 기본 `pistol`: 4발 탄창, 좌클릭/SPACE 입력 시 `gunroad.wav` 준비음 후 24프레임 조준 지연을 거쳐 발사, `gunshot.wav` 발사음과 권총 탄환/탄피를 사용한다. 새총 차징/새총 투사체/새총 게이지 UI는 사용하지 않는다.
- 기본 권총 재장전: 탄약 0 상태에서 좌클릭/SPACE를 누르면 150 게이지를 한 번 소모해 재장전을 시작한다. 재장전 중에는 화기 전환과 권총 발사가 막히며, 탄창이 4발로 가득 찰 때까지 한 발씩 표시/장전음이 진행된다.
- `commando_pistol`: 별도 해금 영구 화기로 유지하되 표시명은 `베레타`로 분리한다. 8발 탄약을 운용하며, 기본 권총보다 연사가 2배 빠르고 탄속 20%, 정확도 30%가 향상된다. 기본 화기가 아니므로 탄약 0 상태에서 발사 입력으로 재장전하지 않고, 다른 영구 화기처럼 재장전 스킬로만 탄약을 보충한다. 헤드샷/레그샷/3히트 보스 피해/게이지 보상은 이 베레타 전용 성능이다.
- 아래 `0A`와 과거 체크리스트의 "기본 군용새총" 항목은 당시 재조사 기록으로만 남긴다. 이후 구현/QA 기준은 이 `0B` 결정을 우선하며, 활성 기본 무기는 권총이다.

## 0A. 화기 재조사 정정

2026-05-06 재조사 기준으로, 현재 Godot 구현의 화기류는 "포팅 완료"가 아니라 "스모크 경로가 이어진 1차 스캐폴딩"으로 재분류한다. 기존 체크리스트의 `[x]`는 모듈 라우팅, UI 고정 패널, 오디오 hook, 최소 draw context가 존재한다는 뜻이지, Python 원본의 무기별 원리와 체감이 모두 구현됐다는 뜻이 아니다.

확인된 핵심 오류와 현재 보정 상태:

- 초기 Godot 구현에서는 기본 화기 정체성이 여러 차례 바뀌었다. Python 원본 재조사 당시에는 기본 슬롯을 `slingshot`처럼 분리하려 했지만, 2026-05-07 live 체감 결정으로 군용새총은 비활성화하고 기본 `pistol` 슬롯을 실제 권총으로 사용한다.
- Godot `commando_weapon_controller.gd`는 호환을 위해 `BASE_WEAPON := "pistol"`을 유지한다. 현재 런타임은 기본 권총의 4발 탄약을 별도 runtime으로 보존하고, 휠 전환 직후 이미 눌린 입력이 발사로 새지 않도록 action edge smoke를 유지한다.
- Godot `commando_firearm_runtime.gd`는 화기별 프로필을 한 런타임 안에서 처리한다. 현재 1차 재포팅으로 기본 권총/베레타/AK-47/바주카/그물덫총/화력지원/볼링트랩/자폭드론의 핵심 입력 gate와 생명주기는 Python 기준 smoke와 베레타 밸런스 smoke에 묶였고, 남은 위험은 주로 live 조작감, 최종 포즈, 무기별 VFX 체감 QA다.
- 사운드와 VFX는 cue 이름과 최소 context가 연결된 상태이며, 무기별 projectile identity는 Stage 1 renderer audit로 1차 고정했다. 다만 최종 발사 타이밍, 충돌 타이밍, 포즈 연출, live 체감까지 완성됐다고 볼 수는 없다.
- 현재 테스트는 존재 여부와 handoff 위주의 smoke test가 많다. 이제부터는 "입력 유지 중 몇 발이 나가는가", "탄약/쿨타임/내구가 원본처럼 감소하는가", "충돌 결과가 상태이상/공 물리/보스 체력에 정확히 반영되는가"를 검증하는 행동 테스트로 승격해야 한다.

원본 재조사에서 확인한 화기별 기준:

| 화기 | Python 기준 핵심 원리 | 현재 Godot 갭 |
|---|---|---|
| 기본 권총 `pistol` | 내부 기본 슬롯. 탄약 4발, 입력 시 `gunroad.wav` 준비음, 24프레임 조준 지연 뒤 탄환/탄피 생성과 `gunshot.wav`, 탄약 0 상태 좌클릭 시 150 게이지로 전체 탄창 재장전 시작, 재장전 중 화기 전환/권총 발사 불가, 일반 명중 42프레임 스턴 + 18프레임 감속 넉백, 헤드샷/레그샷/3히트 보스 피해 lane 공유 | 기본 슬롯을 권총으로 고정했다. 탄약 소모, 준비음과 실제 발사음 분리, 24프레임 지연 발사, 탄피, 권총 특수판정, 빈 탄창 좌클릭 150게이지 전체 재장전 smoke가 들어갔다. 남은 영역은 최종 조준 포즈와 live 사격감 QA다 |
| 베레타 `commando_pistol` | `soldier_pistol_perk` 해금 후 별도 영구 화기. 탄약 8발, 기본 권총보다 2배 빠른 30프레임 쿨타임, 기본 권총보다 20% 빠른 탄속 30, 권총보다 30% 좁은 탄 퍼짐, 18프레임 후딜, 조준 애니메이션 후 발사, 일반 42프레임 스턴 + 18프레임 감속 넉백, 헤드샷 108프레임 스턴, 헤드샷/레그샷/일반 게이지 50/40/30, 3히트 체력 피해. 탄약은 발사 입력이 아니라 재장전 스킬로만 보충 | headshot/legshot/combo/gauge 결과와 8발 탄약/30프레임 쿨타임/정확도 30% 향상/18프레임 후딜 이동 잠금/24프레임 발사 지연/빈 탄약 발사 실패 smoke를 `commando_pistol` 전용 경로로 유지했다. 남은 영역은 최종 조준 포즈와 live 사격감 QA다 |
| AK-47 | 탄약 60, 30초 내구, 6프레임 발사 간격, 첫 입력 2발 burst, 홀드 시 자동 연사, 반동 누적/회복, 탄속 16, 수명 60프레임, 발사 중 이동속도 50%, 20히트당 체력 피해 | 전용 hold/burst/auto-fire 상태기계, 탄약/내구 표시, 반동 spread, 이동속도 50% 디버프, 탄속/수명 smoke가 들어갔다. 남은 영역은 최종 연사감/live VFX 체감 QA다 |
| 바주카포 | 탄약 4, 120프레임 쿨타임, 30프레임 조작 잠금, y=-3으로 시작해 프레임당 0.8 가속, 최대 35, 연기 꼬리 10개, 벽/보스 충돌 폭발 반경 155, 넉백 40, 스턴 90, 발사 포즈/머즐 플래시 | 전용 입력 상태기계로 4발 탄약, 120프레임 내부 쿨타임, 30프레임 제어 잠금/발사 포즈, 수직 가속 로켓, 연기 꼬리, 폭발 반경 155, 넉백 40, 스턴 90 smoke가 들어갔다. 남은 영역은 최종 live 발사 포즈/VFX 체감 QA다 |
| 그물덫총 | 탄약 3, 120프레임 쿨타임, 30프레임 조작 잠금, 투사체 속도 18, 12x12 투사체, 보스 rect 120x80 inflate 및 segment proximity 6, 성공 시 4초 그물, 실패 시 0.35초 dissolve, 플레이어 대시로 rope break, 보스 X 이동 제한 | 전용 입력 상태기계로 3발 탄약, 120프레임 내부 쿨타임, 30프레임 조작 잠금/throw pose, 속도 18 하푼, rope trail 18개, 성공 그물/실패 dissolve, 대시 rope break, 플레이어 70% 이동속도, 보스 X clamp smoke가 들어갔다. 남은 영역은 최종 rope/net live VFX 체감 QA다 |
| 화력지원 | 호출권형 탄약, 42프레임 무전 잠금, 랜덤 지연 뒤 항공기 진입, 5-7발 폭격, 60프레임 폭격 간격, 폭탄 중력 0.35, 항공기 루프, 공 충돌 no-crash | 42프레임 무전 잠금, 120~180프레임 호출 지연, 항공기 진입 후 60프레임 drop-arm, 5~7발 폭격, 60프레임 간격, `vy=2.0` / 중력 0.35 낙탄, 항공기 루프 cleanup, 공 충돌 no-crash smoke가 들어갔다. 남은 영역은 최종 폭격 VFX와 live 체감 QA다 |
| 볼링트랩 | 탄약 3, 설치 48프레임, 쿨타임 120, 조작 잠금 30, 플레이어 진영 60% 아래 설치, 하강 공 포획, 90프레임 고정 뒤 4배속 상향 발사, 보스 가드 시 22 power/60프레임 스턴/원속도 70% 복구 | 전용 입력 상태기계로 3발 탄약, 120프레임 쿨타임, 30프레임 조작 잠금, 60% 하단 설치 gate, 설치 포즈/게이지 context, 하강 공 포획, 90프레임 클로 고정, 4배속 상향 재발사, 보스 가드 handoff smoke가 들어갔다. 남은 영역은 최종 클로/화염 궤적 live VFX 체감 QA다 |
| 자폭드론 | 탄약 4, 폭발 후 90프레임 쿨타임, 48x48 드론, 6프레임 grace, 플레이어 위치 고정, 입력 가속 1.2/최대속도 14, 수동/보스/공/상단벽 충돌 폭발, 반경 150 스턴 0.8초, 화염지대 150프레임, 공 충돌 시 속도 3배 상향 부채꼴 재설정, `drone.wav` 루프 | 전용 수동 조종 상태기계로 4발 탄약, 48x48 드론, 6프레임 grace, 플레이어 이동 잠금, 입력 가속/최대속도, 수동 폭발, 공 충돌 3배속 상향 부채꼴 재설정, 보스 반격 시 원속도 복구, 루프 시작/폭발/라운드 cleanup smoke가 들어갔다. 남은 영역은 최종 rotor/폭발 live VFX와 상단벽/보스 충돌 체감 QA다 |

재구현 순서:

1. 기본 슬롯 정체성부터 고친다. Godot 내부 id는 호환을 위해 `pistol`을 유지하고, display/fire profile도 기본 권총으로 고정한다.
2. `commando_firearm_runtime.gd` 안에 단일 `WEAPON_PROFILES`만 키우지 말고, `pistol`, `commando_pistol`, `ak47`, `bazooka`, `net_gun`, `fire_support`, `bowling_trap`, `suicide_drone`별 작은 상태기계를 둔다. 상태기계 소유권은 계속 `commando_firearm_runtime.gd`에 두되, 파일이 비대해지면 `scripts/characters/commando_firearms/` 하위로 무기별 모듈을 분리한다.
3. 입력을 `pressed` 1회 이벤트만 보지 말고 `action_down`, `action_just_pressed`, `action_just_released`, 이동 입력, 마우스 에지까지 전달한다. 권총의 fresh press 지연 발사, AK 홀드, 자폭드론 수동 폭발에 필요하다.
4. 탄약/탄창/내구/호출권/설치 gate를 `commando_weapon_controller.gd`의 표시용 값과 런타임 실제 값이 어긋나지 않게 동기화한다. 특히 AK-47은 탄약과 30초 내구가 함께 존재하고, 기본 권총은 4발 탄창을 발사 입력으로 재장전하지만, 베레타는 8발 탄약만 보유하고 재장전 스킬로만 보충된다.
5. 사운드는 `game_audio.gd`를 유지하되, 발사 시작음, 실제 투사체 생성음, 충돌음, 루프음, 취소/만료음을 무기별 원본 타이밍에 맞춰 다시 호출한다.
6. VFX는 현재 texture-piece/FX host를 활용하되, 임시 원형 projectile이 아니라 권총/AK 탄환, 권총 탄피, 로켓 연기, rope/net dissolve, 항공기/폭탄, 클로/화염 궤적, 드론 rotor/폭발로 identity를 분리한다.
7. 테스트는 기존 smoke 유지 + 무기별 행동 테스트를 추가한다. 각 테스트는 최소한 발사 조건, 탄약 변화, projectile count/속도, 충돌 결과, 상태이상/보스 체력 result, 오디오 hook, 라운드 cleanup을 확인한다.

이 섹션이 이후 작업의 우선 기준이다. 아래 기존 완료 목록과 QA 체크는 "현재 존재하는 scaffold" 기록으로만 읽고, 실제 완료 판정은 `15A. 화기 메커닉 재포팅 체크리스트`를 따른다.

## 0. 현재 포팅 스냅샷

이 문서는 신규 착수 전 기획서가 아니라, 이미 진행 중인 Godot 코만도 포트의 기준 문서다. 아래 상태를 기준으로 남은 작업을 이어간다.

완료 / 진행된 구현:

- `game_selection_state.gd`는 `soldier`와 `commando` 입력을 모두 코만도 런타임 id인 `soldier`로 정규화한다.
- `player_character_runtime.gd`는 코만도 전용 controller, input reader, skill config, skill state, icon texture key, render context, 이동 기본값을 반환한다.
- `gameplay_actor_module_catalog.gd`에는 `commando_skill_config`, `commando_skill_state`, `commando_weapon_controller`, `commando_emergency_supply_state`, `commando_firearm_runtime`, `commando_supply_drop_state`, `commando_input_reader`, `commando_player_controller`가 등록되어 있다.
- `gameplay_hud_module_catalog.gd`에는 1개 고정 화기 패널용 `commando_firearm_selector_renderer`와 hover tooltip용 `commando_firearm_tooltip_renderer`가 등록되어 있다.
- `battle_resources.gd`에는 코만도 스킬 오브 PNG 경로와 코만도 idle / walk 스프라이트 경로, prewarm / load 경로가 들어가 있다.
- `battle_draw_actor_context.gd`와 sprite-context builder 계열은 `selected_character_type == "soldier"`일 때 코만도 스프라이트 texture key를 사용한다.
- `runtime_perk_catalog.gd`에는 코만도 전용 해금 퍽과 `soldier_pistol_perk -> commando_pistol` 매핑이 들어가 있다.
- `commando_weapon_controller.gd`는 `permanent_owned`, `equipped_permanent`, `rental_weapons`, `current_weapon_id`, 파생 `weapons` 리스트의 1차 상태 모델과 기본 `pistol`의 4발 탄약, 베레타 `commando_pistol`의 8발 탄약 / 발사 입력 재장전 차단 / 재장전 스킬 보충, 그물덫총의 3발 영구 탄약, 바주카의 4발 영구 탄약, AK-47의 60발 탄약 / 1800프레임 내구 표시와 보충 동기화를 구현한다.
- `commando_emergency_supply_state.gd`는 아래키 더블탭 입력, 좌우 이동 중 무효 처리, 게이지/쿨타임 gate, 현재 선택 영구 화기 보충, 실패 시 비용/쿨타임 미소모를 구현한다.
- `commando_supply_drop_state.gd`는 홀드 입력, 지연 드롭, 1~3개 payload 큐, Godot 포팅 완료 일반 아이템과 대여 화기가 섞인 weighted payload 테이블, `ammo_box` / `doping_potion`의 Python 조건부 후보 필터, 낙하산 상자 직접 회수, 일반 아이템의 `active_item_runtime` pickup 경로 수납, 항공기 루프/드롭/획득 오디오, 항공기/낙하산 상자/추락 폭발의 texture-piece 레이어와 `commando_supply_drop_fx_host.gd` shader / `GPUParticles2D` / Tween VFX host, 라운드 cleanup, 플레이어 공/플레이어 패들/Brick 벽 기반 항공기 격추/추락/폭발 흐름을 구현한다.
- `commando_firearm_runtime.gd`는 현재 선택 화기 발사 입력, 탄약 소모, 기본 쿨타임 트리거, 휠 전환 직후 발사 억제, 기본 `pistol`의 4발 탄약과 베레타 `commando_pistol`의 8발 탄약 소모 / `gunroad.wav` 준비음 / 24프레임 조준 지연 / `gunshot.wav` 실제 발사 / 탄피 context, 기본 `pistol` 탄약 0 상태 좌클릭 150게이지 전체 재장전 / 재장전 중 화기 전환 및 권총 발사 차단 / 발당 장전음, 베레타의 30프레임 발사 쿨타임 / 탄속 30 / 권총보다 30% 좁은 탄 퍼짐 / 18프레임 후딜 이동 잠금 / 빈 탄약 발사 실패와 재장전 스킬 전용 보충, 도핑주사기 활성 중 30프레임 권총 쿨타임 / 9프레임 조작 잠금 / 헤드샷·레그샷 확률 2배 / 탄속 1.2배 metadata, 그물덫총의 3발 탄약 / 120프레임 쿨타임 / 30프레임 조작 잠금 / 속도 18 하푼 / rope trail / 성공 4초 그물 / 실패 0.35초 dissolve / 대시 rope break / 플레이어 70% 이동속도 / 보스 X clamp, 바주카의 4발 탄약 / 120프레임 쿨타임 / 30프레임 조작 잠금 / 플레이어 상단 수직 로켓 / 0.8프레임 가속 / 연기 꼬리 / 155 반경 폭발 / 40 넉백 / 90프레임 스턴, AK-47의 6프레임 hold 연사 / 첫 입력 2발 burst / 60발 탄약 / 30초 내구 tick / 반동 spread / 50% 이동속도 디버프 / Python 기준 탄속·수명, 화기별 최소 투사체/머즐/충돌 플래시 상태, Python 기준 화기별 hitbox/폭발 반경 판정, 타깃 명중 이벤트, 공용 피격 파티클/화면 흔들림/보스 피격 애니메이션/공 hit pulse, 화기별 전용 발사·충돌 cue 라우팅, 화기별 1차 보스 상태이상 결과, 권총 헤드샷/레그샷 상태·게이지 result와 피드백 텍스트 context, 보스 체력 피해 result handoff, 권총 헤드샷/3-hit combo 보스 체력 피해, AK-47 20회 누적 보스 체력 피해, 그물장/화염지대/트랩 잔상/폭격 잔광 지속 필드, 화력지원 호출 대기 후 120~180프레임 지연 / 60프레임 항공기 drop-arm / 5~7발 중력 낙탄 생명주기, 전용 무전 cue/항공기 루프 cleanup/공 충돌 no-crash pass-through, 볼링트랩의 3발 탄약 / 120프레임 쿨타임 / 30프레임 조작 잠금 / 하단 60% 설치 gate / 48프레임 설치 게이지 / 하강 공 포획 / 90프레임 고정 / 4배속 상향 재발사, 재발사 공의 보스 가드 시 감속 복구/넉백/스턴 handoff, 자폭드론의 4발 탄약 / 6프레임 grace / 플레이어 고정 수동 조종 / 입력 가속 / 수동 폭발 / 공 3배속 상향 부스트 / 보스 반격 시 원속도 복구를 구현한다.
- `stage1_commando_firearm_renderer.gd`는 `commando_firearm_runtime.gd`의 최소 VFX draw context, 지속 필드 context, 권총 헤드샷/레그샷 피드백 context, 볼링트랩 설치/포획 context를 읽어 Stage 1 전투 화면에 화기 피드백을 그리며, direct-draw detail 위에 texture-piece 레이어와 playfield-local FX host를 동기화한다. 또한 visual identity report로 권총/베레타/AK-47/바주카/그물/화력지원/볼링트랩/자폭드론의 서로 다른 silhouette/FX layer를 점검한다.
- `stage1_commando_firearm_fx_host.gd`는 Stage 1 코만도 화기 머즐/충돌/잔류장의 `ShaderMaterial`, `GPUParticles2D`, pulse `Tween` 레이어를 소유한다.
- `commando_firearm_selector_renderer.gd`는 좌측 필러에 현재 선택 화기만 보이는 1개 고정 패널을 그린다.
- `commando_firearm_tooltip_renderer.gd`는 현재 화기 패널 hover에서 탄약, 기본/영구/대여 상태, 최종 쿨타임, 재장전 가능 여부, 해금 스킬구슬 alias를 한국어로 보여준다.
- `commando_skill_config.gd`는 Python 기준 스킬 사용 골드 정책을 소유한다. `supply_drop`만 기본 쿨타임 기반 96골드를 지급하고, `emergency_supply`, 영구 화기류, `commando_pistol`은 0으로 둔다.
- `commando_firearm_selector_renderer_smoke.gd`는 영구/대여 화기가 여러 개 있어도 좌측 필러 화기 UI가 1개 고정 패널만 노출하고, 현재 선택 화기 전환으로 패널 크기와 위치가 흔들리지 않는지 검증한다.
- `commando_firearm_tooltip_smoke.gd`는 화기 패널 tooltip의 한국어 이름/탄약/소유상태/alias와 오브 snapshot/tooltip의 최종 쿨타임 일치를 검증한다.
- `commando_skill_gold_policy_smoke.gd`는 `supply_drop` 보상이 공통 `skill_gold_award` 경로로 한 번만 적립되고, 재장전/영구 화기 발사가 골드를 직접 또는 중복 지급하지 않는지 검증한다.
- `commando_weapon_controller_smoke.gd`는 영구 화기 공유 슬롯 용량, 파생 live weapon list, 대여/영구 badge, 대여 탄약 0 제거, 라운드 리셋 보존, stage-start 영구 화기 보충, 다음 스테이지 대여 제거, AK-47 hold 연사 중 50% 이동속도 적용을 검증한다.
- `commando_supply_drop_field_item_smoke.gd`는 대여 후보가 모두 막힌 물자보급이 일반 아이템 낙하산 상자를 만들고, 플레이어 직접 회수 시 `active_item_runtime` pickup 경로로 슬롯에 수납하며, 슬롯 full 거절 시 상자를 유지하는지 검증한다.
- `commando_supply_drop_multi_payload_smoke.gd`는 물자보급이 3개 payload를 예약할 때 대여 화기를 중복 예약하지 않고, 낙하 간격마다 하나씩 낙하산 상자로 만든 뒤 플레이어 직접 회수 시에만 지급하는지 검증한다.
- `commando_supply_drop_weighted_table_smoke.gd`는 물자보급 weighted table이 대여 가능 상태에서도 일반 아이템을 뽑을 수 있고, 높은 roll의 대여 payload 예약이 같은 화기를 중복 예약하지 않는지 검증한다.
- `commando_supply_drop_item_candidates_smoke.gd`는 `ammo_box` / `doping_potion` 카탈로그, 보급 후보 조건부 필터, 탄약상자의 영구 화기 전체 재보충, 도핑주사기의 권총 전용 활성 조건과 권총 사격 버프를 검증한다.
- `commando_supply_drop_audio_cleanup_smoke.gd`는 물자보급 호출음, 항공기 루프 시작/정지, 드롭 해소음, 획득음, 짧은 낙하물 효과, 라운드 cleanup 정리와 화력지원 항공기 루프 및 자폭드론 루프의 round-boundary cleanup을 검증한다.
- `commando_supply_drop_aircraft_crash_smoke.gd`는 보급 항공기가 플레이어 공에 맞으면 payload 큐를 취소하고 추락/폭발 수명주기로 들어가며, 보스 공은 통과하고 항공기 루프 사운드가 즉시 정리되는지 검증한다.
- `commando_supply_drop_obstacle_crash_smoke.gd`는 보급 항공기가 플레이어 패들 또는 Brick 벽에 닿으면 같은 추락/폭발 수명주기를 재사용하고, Brick 벽은 소모하지 않는지 검증한다.
- `commando_supply_drop_vfx_remaster_smoke.gd`는 보급 항공기, 낙하산 상자, 추락 폭발 경로가 texture-piece 레이어, shader host, `GPUParticles2D`, pulse `Tween`을 함께 노출하고, reset에서 FX host가 숨는지 검증한다.
- `commando_emergency_supply_smoke.gd`는 더블탭 재장전 성공, 기본 `pistol` 최대 보충, 베레타를 포함한 현재 선택 영구 화기 최대 탄약 보충, 대여 화기 실패 시 게이지/쿨타임 미소모, 이동 중 더블탭 무효를 검증한다.
- `commando_weapon_switch_smoke.gd`는 `soldier` / `commando` alias에서만 마우스 휠 화기 순환이 동작하고 다른 캐릭터에는 새지 않는 것을 검증한다.
- `commando_runtime_routing_smoke.gd`는 캐릭터 런타임 라우팅, 모듈 카탈로그 등록, 선택 상태의 `soldier` 유지 여부를 검증한다.
- `commando_resource_sprite_smoke.gd`는 코만도 플레이어 스프라이트와 스킬 오브 PNG가 Godot 리소스 경로에서 로드되고 draw/update context가 스매셔 스프라이트로 fallback하지 않는지 검증한다.
- `commando_perk_catalog_smoke.gd`는 코만도 해금 퍽 후보, debug 목록, 해금 시 `commando_skill_config`와 `commando_weapon_controller`까지 이어지는 side effect, 공유 슬롯 full 상태의 pending swap, 취소 no-op, 확정 시 이전 unlock cleanup을 검증한다.
- `commando_firearm_runtime_vfx_smoke.gd`는 화기 발사 시 투사체/머즐/충돌 플래시와 AK-47/권총 탄피 context가 생성되고, AK-47의 60발 탄약/30초 내구/6프레임 연사 간격/첫 입력 2발 burst/홀드 자동 연사/50% 이동속도/탄속 16/수명 60프레임을 확인한다. 기본 `pistol`은 입력 직후 바로 발사하지 않고 탄약 1발을 소비한 뒤 `gunroad.wav` 준비 cue, 24프레임 조준 지연, 권총 탄환/탄피 생성과 `gunshot.wav` 발사 cue로 이어지며, 일반 명중 42프레임 스턴 + 18프레임 감속 넉백과 `slingshot` metadata를 남기지 않는지 확인한다. 또한 베레타 `commando_pistol`의 8발 탄약/24프레임 지연 발사/30프레임 쿨타임/탄속 30/권총보다 30% 좁은 탄 퍼짐/빈 탄약 발사 실패와 일반/헤드샷/레그샷 확률 경계, 30/50/40 게이지, 42프레임 일반 스턴 + 18프레임 감속 넉백, 108프레임 헤드샷 스턴, 132프레임 레그샷 슬로우를 확인하고, Python 기준 탄환 rect/그물 확장 hitbox/바주카 폭발 반경으로 명중 판정이 갈리는지 확인하며, 타깃 명중 시 공용 피격 피드백, 오디오 hook, 화기별 `status_effect_state` 보스 상태이상 결과, 권총 헤드샷/레그샷 게이지 handoff, 피드백 텍스트 context/timer와 지속 필드 tick이 실행되며, 화력지원이 호출 대기 후 5~7발 폭격으로 이어지고, 전용 무전 cue/항공기 루프/라운드 cleanup과 Python 기준 공 충돌 no-crash pass-through를 검증한다. 볼링트랩은 탄약 3/120프레임 쿨타임/30프레임 조작 잠금/하단 60% 설치 gate/48프레임 설치 게이지, 하강 공 포획, 90프레임 뒤 4배속 재발사, 보스 가드 handoff를 검증하고, 자폭드론은 탄약 4/6프레임 grace/수동 조종/플레이어 이동 잠금/공 3배속 부스트/보스 반격 복구를 검증하며, 보급 홀드/쿨타임/휠 전환 직후 입력에서는 발사와 탄약 소모가 새지 않는지 검증한다.
- `commando_firearm_audio_routing_smoke.gd`는 화기별 전용 발사/충돌 cue 메서드가 generic hook보다 우선 호출되고, 전용 cue가 없는 test double에서는 기존 generic fallback이 유지되며, `fire_support` 호출 프레임에는 폭발/발사음 대신 전용 무전 cue만 쓰는지와 Godot `game_audio.gd`가 권총 준비 `gunroad.wav`, 권총 발사 `gunshot.wav`, 권총 1발 재장전 `pistolreload.wav`, Python 기준 화기 wav/gain 및 AK-47 연사용 layered player pool을 로드하는지 검증한다.
- `commando_firearm_vfx_texture_remaster_smoke.gd`는 Stage 1 코만도 화기 렌더러가 머즐/충돌/잔류장에 캐시된 glow/burst/sparkle/ring texture piece 레이어, shader / GPU particle host pipeline, 권총 피드백 텍스트 pipeline을 함께 노출하는지 검증한다. 추가로 visual identity report가 권총/베레타/AK-47/바주카/그물/화력지원/볼링트랩/자폭드론 8개 화기 family와 aimed bullet, brass casing, rocket smoke, harpoon rope, aircraft marker, trap claw, drone rotor layer를 구분하는지 확인한다.
- `commando_firearm_stage1_visual_qa_smoke.gd`는 Stage 1 실제 렌더러 draw 경로에서 권총/베레타/AK-47/바주카/그물/화력지원/볼링트랩/자폭드론 8개 화기를 한 화면에 배치한다. headless에서는 draw callback / visual identity context를 검증하고, windowed 실행에서는 viewport pixel signature로 각 무기 영역이 비어 있지 않고 서로 구분되는지 확인한다.
- `commando_firearm_fx_host_smoke.gd`는 코만도 화기 FX host가 shader layer, muzzle/impact `GPUParticles2D`, texture cache prewarm, pulse `Tween`, playfield-local shake anchor를 구성하는지 검증한다.
- `commando_firearm_renderer_fx_host_lifecycle_smoke.gd`는 Stage 1 렌더러가 실제 canvas 경로에서 FX host를 deferred attach해도 `_ready()` 이후 활성 동기화와 impact anchor를 잃지 않고, VFX가 사라진 프레임에는 host를 숨기는지 검증한다.
- `commando_firearm_boss_damage_smoke.gd`는 화기 명중 `damage_units`가 effects result로 한 번만 소비되고, 권총/강화 권총은 Python 기준 헤드샷 즉시 1 피해와 3회 보스 명중 combo 1 피해를 내보내며, 레그샷은 즉시 headshot 피해 없이 combo 카운트에만 참여하는지 확인한다. AK-47은 Python 기준 20회 보스 명중마다 체력 피해 1을 내보내고, `battle_scene_effects_update_result_applier.gd`를 통해 설정된 보스 체력 필드와 코만도 화기 피해 누적 필드에 반영되며, 체력 0 플래그가 플레이어 득점 이벤트로 한 번만 소비되는지 검증한다.
- `commando_save_load_snapshot_smoke.gd`는 코만도 스킬 config의 장착 슬롯/쿨감/슬롯 보너스, 무기 소유/장착/대여/탄약/재장전/스테이지 준비 상태, 스킬 쿨타임 pause 상태, 물자보급 진행/낙하물 상태가 각 런타임의 save snapshot에서 왕복되는지 검증한다.
- `boss_health_flow_smoke.gd`는 Python 기준 체력형 스테이지(11/16/21)의 15 HP 초기화, 비체력형 스테이지 HP clear, bootstrap health snapshot, 보스 체력 0 득점 플래그의 one-shot 소비를 검증한다.
- `item_update_boss_health_reset_smoke.gd`는 Foul Whistle 같은 지연 라운드 reset 경로에서도 공 reset과 함께 보스 HP가 복구되는지 검증한다.
- `commando_ui_text_audit_smoke.gd`는 캐릭터 선택 카드, 런타임 퍽 선택 카드, 슬롯 full 스왑 다이얼로그, debug 지급 피드백, TAB 캐릭터 정보 overlay에서 코만도 퍽/해금명과 `soldier` alias가 한국어 표시명으로 이어지는지 검증한다.
- `commando_icon_alias_smoke.gd`는 `soldier_unlock_*` / `soldier_pistol_perk` 퍽 카드가 실제 코만도 오브 skill id와 같은 PNG 경로/텍스처를 쓰고, 퍽 카드에만 해금 뱃지가 얹히는지 검증한다.
- `docs/godot_port_architecture.md`에는 코만도 skill config, weapon controller, emergency/supply/firearm runtime, input reader, player controller, 고정 화기 패널/tooltip 렌더러, Stage 1 최소 화기 VFX 렌더러의 소유권을 기록했다.

미구현 / 부분 구현:

- 화기별 투사체/머즐/충돌 플래시, 기본 권총의 준비음/지연발사/탄약/탄피/권총 hit lane, AK-47 탄피 배출, 최소 발사/명중 피드백, Python 기준 화기별 hitbox/폭발 반경, `status_effect_state` 기반 1차 보스 상태이상 결과, 권총 헤드샷/레그샷 상태·게이지 result와 보스 근처 한국어 피드백 텍스트, 보스 체력 피해 result handoff, 권총 헤드샷/3-hit combo 보스 체력 피해, AK-47 20회 누적 보스 체력 피해, 보스 HP HUD/체력 0 플레이어 득점 flow, 그물장/자폭드론 화염지대/볼링트랩 잔상/화력지원 폭격 잔광의 1차 지속 필드, 화력지원 호출 대기 후 120~180프레임 지연 / 60프레임 항공기 drop-arm / 5~7발 중력 낙탄 생명주기, 전용 무전 cue/항공기 루프 cleanup, 화기별 발사/충돌 cue 라우팅과 Python 기준 wav asset 연결, AK-47 연사용 layered player pool, Stage 1 머즐/충돌/잔류장 texture-piece VFX 레이어와 shader / `GPUParticles2D` / Tween FX host, Stage 1 실제 렌더러 windowed pixel visual QA, Python 기준 화력지원 항공기 공 충돌 no-crash pass-through, 볼링트랩 설치/포획/재발사 공 물리 결과와 보스 가드 시 넉백/스턴 패들 충돌 경로는 들어갔다. 남은 영역은 장시간 플레이 체감 QA와 최종 포즈 polish다.
- `supply_drop`은 현재 1~3개 payload를 weighted table로 순차 예약하고, 플레이어가 낙하산 상자를 직접 회수할 때 대여 화기 또는 일반 아이템을 지급하며, 일반 아이템 슬롯 full 거절 시 상자를 유지한다. 항공기/낙하산 상자/추락 폭발의 Godot-native texture-piece, shader host, `GPUParticles2D`, pulse `Tween` VFX remaster와 호출/항공기/드롭/획득/폭발 오디오 cleanup, 플레이어 공/패들/Brick 벽 기반 항공기 격추/추락/폭발까지 연결했다. Python 후보였던 `ammo_box`와 `doping_potion`도 Godot active-item 런타임과 권총 버프 경로까지 들어갔다.
- 코만도 전용 스킬 오브 tooltip, 화기 패널 tooltip, TAB 캐릭터 정보, 런타임 퍽 선택/스왑/피드백, 캐릭터 선택 카드의 한국어/alias 기본 경로는 들어갔다. 코만도 해금 퍽 카드도 실제 오브 PNG와 같은 모티프를 공유한다. Python식 별도 승리 tooltip이나 스테이지 클리어 해금 선택 UI가 Godot에 들어오면 같은 catalog / skill config 표시명 소스를 재사용해야 한다.
- 공유 슬롯 full 상태의 Godot 스왑 다이얼로그 기본 경로와 취소 no-op QA는 runtime perk overlay / state 경로에 들어갔다. academy/NPC/스테이지 보상 같은 외부 해금 제안 경로는 같은 pending swap API를 재사용해야 한다.
- save/load는 아직 전역 세이브 파일에 연결되지는 않았지만, 코만도 스킬 config / 무기 컨트롤러 / 스킬 쿨타임 / 물자보급 진행 상태는 `get_save_snapshot()` / `apply_save_snapshot()`로 왕복 가능한 1차 런타임 표면을 갖췄다. stage-transition rental cleanup과 영구 화기 stage-start 보충은 Godot 컨트롤러/플레이어 업데이트 경로에 연결했다.
- `soldier`를 미지원 fallback으로 보던 오래된 selection smoke 기대값은 코만도 포팅 기준으로 갱신했다.

## 1. 목적

코만도는 Python 원본에서 화기류, 물자보급, 재장전, 5구슬 스킬, 런타임 퍽 해금이 한 덩어리로 얽혀 있는 캐릭터다. Godot 포팅에서는 Python의 플레이 감각과 상태 규칙은 유지하되, `pingfighter.py`식 모놀리식 구조를 복사하지 않고 Godot의 도메인별 모듈로 나눈다.

이번 포팅 기획의 가장 중요한 UI 변경점은 다음과 같다.

- 좌측 필러에 화기류 UI가 획득 수만큼 하나씩 쌓이는 방식을 사용하지 않는다.
- 좌측 필러 화기 UI는 항상 1개 고정 패널만 표시한다.
- 현재 선택 화기만 이 1개 패널에 표시한다.
- 전투 중 화기 변경은 마우스 휠 순환으로 처리한다.
- 좌측 필러의 여러 화기 슬롯 클릭 선택, 획득 수만큼 늘어나는 슬롯, 영구/대여 화기별 개별 필러 카드 나열은 Godot 포트 1차 범위에서 제외한다.

## 2. 기준 문서와 원본 참조

포팅 기준은 아래 순서로 둔다.

1. `docs/commando_firearm_overhaul.md`
   - Python 원본의 코만도 화기 시스템 재정의 문서.
   - 영구 보유, 장착, 대여 화기 분리 모델을 기준으로 삼는다.
2. `docs/character_skill_perk_checklist.md`
   - 캐릭터 스킬, 5구슬, 퍽, 해금, 스왑, 저장/로드 QA 기준.
3. `CLAUDE.md`의 캐릭터 스킬 hidden-knowledge 섹션
   - 아이콘 alias, 최종 쿨타임 HUD, 7개 UI 텍스트 경로, 스테이지 전환 규칙.
4. `docs/godot_port_architecture.md`
   - Godot 모듈 경계와 포팅 원칙.
5. `pingfighter.py`
   - 동작 참조 전용. 아키텍처 참조로 삼지 않는다.

주의:

- `docs/WEAPON_SYSTEM_GUIDE.md`는 Python 시절의 누적형 화기 HUD와 오래된 노후화 모델을 포함한 참고 문서다. Godot 코만도 포트의 UI/상태 기준으로 삼지 않는다.
- Godot 1차 포트 기준은 이 문서의 영구/장착/대여 분리 모델과 좌측 필러 1개 고정 화기 패널 정책이다.

현재 Python 원본에서 확인한 주요 기준:

- 기본 스킬: `supply_drop`, `emergency_supply`
- 영구 화기 후보: `net_gun`, `fire_support`, `bowling_trap`, `suicide_drone`, `bazooka`, `ak47`, `commando_pistol`
- 기본 화기: 내부 슬롯 id는 `pistol`이며 실제 표시/발사 동작도 기본 권총이다. `commando_pistol`은 기본 권총보다 빠른 별도 영구 화기인 `베레타`이다.
- 현재 Python 기준 `emergency_supply` 기본 쿨타임은 60초다. 기존 문서의 120초와 다르므로, Godot 1차 포트는 현재 코드값 60초를 기준으로 하고 밸런스 변경은 별도 결정으로 둔다.

## 3. 포팅 목표

### 3.1. 플레이 목표

- 코만도는 "보급을 굴려 화기 선택지를 늘리고, 상황에 맞는 화기를 휠로 바꿔 쓰는 캐릭터"로 유지한다.
- 영구 해금 화기는 런 중 소유 상태를 유지하고, 5구슬 공유 슬롯 예산을 점유한다.
- 물자보급 화기는 대여 화기로 취급하며, 다음 실제 스테이지 전환에서 제거한다.
- 대여 화기는 영구 화기와 UI/저장/재장전 규칙이 섞이지 않게 한다.
- 일반 라운드 리셋과 실제 스테이지 전환을 엄격히 분리한다.

### 3.2. UI 목표

- 5구슬 HUD는 기존 캐릭터들과 같은 스킬 오브 문법을 사용한다.
- 화기 인벤토리 표현은 1개 고정 패널로 압축한다.
- 고정 패널은 현재 선택 화기만 보여준다.
- 화기 수가 늘어나도 좌측 필러 레이아웃 높이와 슬롯 수는 변하지 않는다.
- 플레이어가 보유 화기 전체를 확인할 필요가 있을 때도 상시 슬롯 나열이 아니라 임시 툴팁, TAB 정보, 또는 패널 내 작은 텍스트 카운터로 처리한다.

## 4. 비목표

- Python 원본 수정은 이번 기획서의 범위가 아니다.
- Godot `scenes/main.gd`에 코만도 전용 대형 블록을 추가하지 않는다.
- 화기 획득마다 좌측 필러에 새 아이콘/카드/슬롯을 쌓지 않는다.
- 필러 슬롯 클릭으로 무기를 직접 선택하는 UX는 1차 포트에서 제외한다.
- 중클릭 권총 토글, 숫자키 직접 선택, 상시 펼침 화기 바는 1차 포트 기본 조작으로 넣지 않는다. 필요하면 별도 접근성 옵션으로 재검토한다.
- 오래된 "노후화" 모델은 부활시키지 않는다. 대여/영구 모델만 사용한다.

## 5. Godot 모듈 경계

새 구현은 아래 모듈을 기준으로 나눈다.

### 5.1. 캐릭터 런타임

- `godot/scripts/characters/commando_skill_config.gd`
  - 코만도 스킬/화기 메타데이터, 게이지 비용, 기본 쿨타임, 색상, 한국어 이름, tooltip 문구.
- `godot/scripts/characters/commando_skill_state.gd`
  - 스킬 쿨타임, 활성 순간, tooltip pause/resume, 저장 가능한 쿨타임 잔여 상태.
  - `smasher_skill_state.gd`의 구조를 재사용 가능한 기준으로 삼는다.
- `godot/scripts/characters/commando_weapon_controller.gd`
  - 영구 보유, 장착 영구 화기, 대여 화기, 파생 live weapon list, 현재 선택 화기.
  - Python `soldier/controller.py`의 분리 모델을 Godot식으로 이식한다.
- `godot/scripts/characters/commando_firearm_runtime.gd`
  - 화기별 발사/설치/호출/탄약/쿨타임/타격 결과.
- `godot/scripts/characters/commando_supply_drop_state.gd`
  - 물자보급 홀드 시간, 호출 중 상태, 항공기/낙하물/라디오 모션, 드롭 테이블, 드롭 후 회수 가능 상태.
  - 일반 아이템 드롭과 대여 화기 드롭을 같은 호출 흐름에서 분기하되, 지급 경로는 서로 섞지 않는다.
- `godot/scripts/characters/commando_input_reader.gd`
  - 마우스 휠 화기 순환, 좌클릭/SPACE 발사, 아래 더블탭 재장전, 물자보급 홀드 입력.
- `godot/scripts/characters/commando_player_controller.gd`
  - 배틀 루프와 코만도 런타임의 얇은 연결. 직접 상태를 많이 소유하지 않는다.

새 캐릭터 모듈은 `godot/scripts/resources/gameplay_actor_module_catalog.gd`에 등록한다.

기존 전역 라우팅도 포트 범위다.

- `godot/scripts/core/game_selection_state.gd`는 `soldier` 또는 `commando` 런타임 id를 `smasher`로 정규화하면 안 된다.
- `godot/scripts/characters/player_character_runtime.gd`는 코만도용 controller, input reader, skill config, skill state, icon texture, render context 키를 반환해야 한다.
- 캐릭터 선택 화면의 `runtime_id: "soldier"`가 전투 시작 후 `selected_character_type`까지 유지되는 것을 smoke test로 고정한다.
- 코만도 이동 기본값은 스매셔 fallback에 묻히지 않게 명시한다. Python/선택 카드 기준의 속도/파워/방어 의도를 확인한 뒤 Godot movement config에 별도 값으로 둔다.

### 5.2. HUD

- `godot/scripts/hud/commando_skill_orb_context_builder.gd`
  - 5구슬에 들어갈 코만도 스킬 상태를 만든다.
- `godot/scripts/hud/commando_firearm_selector_renderer.gd`
  - 좌측 필러 1개 고정 화기 패널을 그린다.
- `godot/scripts/hud/commando_firearm_tooltip_renderer.gd`
  - 현재 화기 상세 정보, 탄약, 대여/영구, 재장전 가능 여부를 보여준다.

기존 `smasher_skill_orb_renderer.gd`가 캐릭터 중립적으로 쓸 수 있으면, 코만도용 오브 렌더러를 새로 복사하지 않고 context만 바꿔 재사용한다. 고정 화기 패널은 별도 렌더러로 둔다.

새 HUD 모듈은 `godot/scripts/resources/gameplay_hud_module_catalog.gd`에 등록한다.

tooltip/hover 경로는 기존 `battle_scene_skill_tooltip_driver.gd` 계열의 pause/resume 규칙을 따른다. 코만도 오브와 화기 패널 tooltip은 쿨타임, 탄약, 대여/영구 상태, 해금 alias 설명을 모두 한국어로 보여주되, 하단 조작 힌트나 효과 preview 영역과 겹치지 않게 실제 렌더 높이를 확인한다.

### 5.3. 오디오

- 발사, 재장전, 보급 호출, 보급 획득, 대여 획득, 화기 전환, 실패 피드백은 `godot/scripts/audio/game_audio.gd`를 통해 호출한다.
- 루프성 사운드가 생기면 `godot/scripts/audio/gameplay_loop_audio_cleanup.gd`에 stop 메서드를 추가한다.
- 점수 이벤트, 스코어보드, 서브 대기, 라운드 재시작, 게임 리셋에서 루프가 남지 않아야 한다.

### 5.4. 캐릭터 선택과 플레이어 스프라이트

코만도는 선택 카드만 보이는 상태로 끝나면 안 된다. 선택, 런타임 라우팅, 전투 중 플레이어 렌더링이 모두 같은 캐릭터 id를 공유해야 한다.

- `godot/scripts/ui/character_select_data.gd`의 코만도 항목은 `id: "soldier"`와 `runtime_id: "soldier"`를 유지한다.
- battle startup lifecycle은 selection state의 `runtime_character_id`를 전투 scene으로 그대로 전달한다.
- `stage1_player_sprite_renderer.gd` 또는 공통 player sprite renderer가 코만도일 때 스매셔 텍스처를 조용히 fallback으로 쓰지 않게 한다.
- Python 원본의 `items/commando_subculture_idle_sheet.png`, `items/commando_subculture_left_walk_sheet.png`, `items/commando_subculture_right_walk_sheet.png`, `items/commando_subculture_back_walk_sheet.png`를 Godot asset tree로 복사하거나 동등한 런타임 스프라이트를 준비한다.
- idle/walk 방향별 source rect, frame count, cadence, 기준점, 스케일, hit flash, low-HP tint, victory/defeat fallback 정책을 문서화한다.
- 전투에서 코만도를 고르면 실제 플레이어 actor가 코만도 스프라이트로 보이는지 smoke test를 둔다.

## 6. 런타임 상태 모델

Godot 포트의 코만도 화기 상태는 4개 레이어로 나눈다.

```gdscript
permanent_owned: Dictionary      # 런 중 영구 해금한 화기
equipped_permanent: Array        # 5구슬 공유 슬롯에 장착된 영구 화기
rental_weapons: Dictionary       # 물자보급으로 얻은 스테이지 한정 화기
weapons: Array                   # ["pistol" 내부 기본 슬롯 = 기본 권총] + equipped_permanent + rental_weapons.keys()
```

`weapons`는 입력/전투에서 쓰기 위한 파생 리스트다. 소유, 장착, 대여의 원본 상태로 사용하지 않는다.

필수 규칙:

- `pistol`은 호환용 내부 기본 슬롯 id이며 UI와 발사 동작도 기본 권총이다. 5구슬 공유 슬롯을 점유하지 않는다.
- `commando_pistol`은 `soldier_pistol_perk`로 해금되는 베레타 영구 화기이며 공유 슬롯을 점유한다.
- 대여 화기는 5구슬 슬롯을 점유하지 않는다.
- 대여 화기는 영구 화기로 승격되지 않는다.
- 영구 화기와 대여 화기가 같은 id로 중복 존재하지 않는다.
- 현재 선택 화기가 제거되면 `pistol`로 돌아간다.

## 7. 5구슬 스킬 모델

코만도 오브 슬롯은 아래 구조로 둔다.

| 슬롯 | 의미 |
|---|---|
| 1 | `supply_drop` 고정 |
| 2 | `emergency_supply` 고정 |
| 3-5 | 영구 화기 / `commando_pistol` 공유 슬롯 |
| 6 | 천상의 망토 슬롯 보너스가 있을 때만 공유 슬롯 확장 |

공유 슬롯 후보:

- `net_gun`
- `fire_support`
- `bowling_trap`
- `suicide_drone`
- `bazooka`
- `ak47`
- `commando_pistol`

고정 슬롯은 스왑 대상이 아니다. 공유 슬롯이 가득 찬 상태에서 새 영구 화기를 해금하면 기존 스왑 다이얼로그 흐름을 Godot UI로 이식한다. 취소는 완전한 no-op이어야 하며, 취소 시 ownership, unlock flag, runtime level, controller inventory가 오염되면 안 된다.

## 8. 화기 UI 정책

### 8.1. 좌측 필러 고정 화기 패널

좌측 필러에는 코만도 화기 패널을 1개만 둔다.

패널 표시 정보:

- 현재 선택 화기 아이콘
- 현재 선택 화기 이름
- 탄약 / 탄창 / 호출권 / 지속시간 중 해당 화기에 맞는 1줄 상태
- 영구 / 대여 뱃지
- 쿨타임 또는 사용 불가 상태
- 휠 전환 가능 힌트는 과하게 노출하지 않고, 필요 시 작은 아이콘 또는 tooltip로만 표시

금지 사항:

- 화기 획득 수만큼 패널을 추가하지 않는다.
- 좌측 필러에 전체 화기 목록을 상시 나열하지 않는다.
- 화기별 버튼을 만들어 클릭 전환하지 않는다.
- 대여 화기를 별도 필러 슬롯으로 쌓지 않는다.

### 8.2. 마우스 휠 전환

전투 중 화기 전환은 마우스 휠로 한다.

기본 방향:

- 휠 위: 이전 화기
- 휠 아래: 다음 화기
- 수평 휠이 들어오면 Python 원본처럼 좌/우를 이전/다음으로 매핑할 수 있다.

순환 대상:

- 파생 `weapons` 리스트 전체
- 기본 `pistol`
- 현재 장착된 영구 화기
- 현재 보유 중인 대여 화기

사용 불가 화기 처리:

- 영구 화기는 탄약이 0이어도 리스트에 남고, 패널에는 사용 불가로 표시한다.
- 대여 화기는 탄약이 0이 되면 즉시 제거한다.
- 제거된 대여 화기가 현재 선택 화기였으면 `pistol`로 돌아간다.

입력 안정성:

- 휠 전환은 짧은 ms 디바운스를 둔다.
- 전환 직후 잔류 좌클릭/SPACE 발사가 섞이지 않도록 2-3프레임 발사 억제를 둔다.
- 휠 이벤트는 UI 오버레이, 일시정지, 선택 모달이 열려 있을 때 전투 화기 전환으로 소비하지 않는다.

## 9. 스킬별 포팅 요약

### 9.1. `supply_drop`

- 게이지 비용: Python 현재 기준 350
- 쿨타임: Python 현재 기준 40초
- 입력: 아래/우클릭 홀드 계열을 포팅하되 Godot 입력 액션으로 명확히 분리
- 결과: 일반 아이템 또는 대여 화기 드롭
- 대여 화기 중복 방지:
  - 이미 영구 보유한 화기 제외
  - 이미 대여 중인 화기 제외
- 드롭 VFX는 Godot-native 방식으로 포팅한다.

물자보급은 단순 즉시 지급 스킬이 아니라 별도 생명주기를 가진다.

- hold 시간, active/timer, 항공기 진입, 낙하물 spawn, 라디오/손동작 연출, 플레이어 공/패들/Brick 벽 기반 항공기 격추/추락/폭발, 드롭 후 회수 가능 상태를 `commando_supply_drop_state.gd`에 둔다.
- 일반 아이템이 나올 때는 보급 낙하산 상자를 직접 회수한 뒤 기존 active item pickup / 슬롯 수납 경로를 타고, 대여 화기가 나올 때만 `commando_weapon_controller.gd`의 rental 지급 경로를 탄다.
- 라운드 재시작에서는 진행 중 연출과 입력 버퍼만 정리하고, 실제 스테이지 전환에서 대여 화기를 제거한다.
- 보급 항공기나 beacon에 루프 사운드가 붙으면 round-boundary cleanup 대상에 포함한다.

### 9.2. `emergency_supply`

- 게이지 비용: 기본 권총 1발 보충 기준 150, 영구 화기 보충도 현재 Godot 기준 150
- 쿨타임: Python 현재 기준 60초
- 입력: 아래 더블탭
- 대상: 현재 선택한 기본 `pistol` 또는 영구 화기 1개
- 제외:
  - 대여 화기
  - 이미 탄약/지속시간이 가득 찬 화기
- 실패 시 게이지와 쿨타임을 소비하지 않는다.
- 오브 쿨타임, 남은 시간, tooltip 쿨타임은 최종 쿨감 적용값으로 일치해야 한다.

### 9.3. 영구 화기

영구 화기는 해금 퍽을 통해 얻고 공유 오브 슬롯을 점유한다.

각 화기는 다음 공통 필드를 가진다.

- `weapon_id`
- `display_name_ko`
- `ammo_current`
- `ammo_max`
- `cooldown_seconds`
- `kind = "owned"`
- `is_equipped_permanent`
- `can_fire`
- `fire`
- `refill_by_emergency_supply`
- `refill_on_stage_start`

화기별 탄약/재장전 표시는 shared helper로 묶는다. Python의 `get_weapon_ammo_info`, `_refill_soldier_weapon_ammo`, `release_rental_if_depleted` 역할을 Godot에서 각각 UI 조회, 영구 화기 보충, 대여 화기 탄약 0 제거 경로로 분리한다. 각 화기는 탄약형, 호출권형, 지속시간형, 설치 gate형 중 어떤 표시 모델을 쓰는지 명시해야 한다.

### 9.4. 대여 화기

대여 화기는 물자보급으로만 얻는다.

대여 화기 규칙:

- `kind = "rental"`
- `acquired_stage`를 저장한다.
- 5구슬 공유 슬롯에 들어가지 않는다.
- `emergency_supply` 대상이 아니다.
- 스테이지 전환 전 save/load에서는 유지된다.
- 다음 실제 스테이지 진입 시 제거된다.
- 탄약이 0이 되면 즉시 제거된다.
- 고정 화기 패널에는 `대여` 뱃지를 표시한다.

## 10. 퍽과 해금 흐름

코만도 전용 해금 퍽은 Godot `runtime_perk_catalog`와 코만도 스킬/무기 상태 양쪽에 반영되어야 한다.

필수 해금 매핑:

| 퍽 id | 스킬/화기 id |
|---|---|
| `soldier_unlock_net_gun` | `net_gun` |
| `soldier_unlock_fire_support` | `fire_support` |
| `soldier_unlock_bowling_trap` | `bowling_trap` |
| `soldier_unlock_suicide_drone` | `suicide_drone` |
| `soldier_unlock_bazooka` | `bazooka` |
| `soldier_unlock_ak47` | `ak47` |
| `soldier_pistol_perk` | `commando_pistol` |

Godot 포트에서는 다음을 함께 구현한다.

- 코만도 전용 퍽 풀 등록
- 캐릭터 제한
- 5구슬 공유 슬롯 fullness 검사
- 슬롯 가득 참 상태에서 해금 퍽 제안 억제 또는 스왑 플로우
- 스왑 취소 no-op
- `perk_id != skill_id` alias cleanup
- TAB 캐릭터 정보, ESC/상태 패널, 승리/스테이지 선택 계열 텍스트 동기화
- tooltip 한국어 문구

`godot/scripts/characters/runtime_perk_catalog.gd`에서는 다음 연결을 놓치지 않는다.

- `SOLDIER_PERKS` 또는 동등한 코만도 전용 풀 추가
- `get_choices()`가 현재 캐릭터가 `soldier`일 때 코만도 퍽을 후보로 포함
- `get_all_perk_data()`와 developer/debug perk 목록에 코만도 퍽 포함
- `UNLOCK_SLOT_BUDGET` 또는 후속 슬롯 검사에서 코만도 공유 슬롯 수를 반영
- fullness 판정은 단순 `unlocks_skill` 개수만 보지 않고 `equipped_permanent`와 `soldier_pistol_perk -> commando_pistol` alias를 기준으로 계산
- academy/NPC/스테이지 보상에서 해금 제안이 나올 때 ownership-vs-equipped, 취소 no-op, `perk_id`-vs-`skill_id` cleanup을 같은 규칙으로 적용

## 11. 아이콘과 에셋

Python 원본에 있는 코만도 아이콘은 Godot asset tree로 복사 또는 대응 생성한다.

권장 경로:

- `godot/assets/sprites/skills/commando_supply_drop_skill_orb.png`
- `godot/assets/sprites/skills/commando_pistol_base_weapon_icon.png` (기본 권총 화기 패널/tooltip용, 현재 1차 UI는 procedural 심볼 fallback)
- `godot/assets/sprites/skills/commando_slingshot_base_weapon_icon.png` / `godot/assets/sprites/effects/commando_slingshot_stone_projectile_sheet_imagegen_v1.png`는 군용새총 실험용 legacy asset이며 현재 기본무기 경로에서는 사용하지 않는다.
- `godot/assets/sprites/skills/commando_pistol_skill_orb.png`
- `godot/assets/sprites/skills/commando_net_gun_skill_orb.png`
- `godot/assets/sprites/skills/commando_fire_support_skill_orb.png`
- `godot/assets/sprites/skills/commando_bowling_trap_skill_orb.png`
- `godot/assets/sprites/skills/commando_suicide_drone_skill_orb.png`
- `godot/assets/sprites/skills/commando_bazooka_skill_orb.png`
- `godot/assets/sprites/skills/commando_ak47_skill_orb.png`
- `godot/assets/sprites/perks/` 아래 해금 퍽 alias용 아이콘 필요 여부 확인

플레이어 스프라이트 권장 경로:

- `godot/assets/sprites/characters/commando/commando_subculture_idle_sheet.png`
- `godot/assets/sprites/characters/commando/commando_subculture_left_walk_sheet.png`
- `godot/assets/sprites/characters/commando/commando_subculture_right_walk_sheet.png`
- `godot/assets/sprites/characters/commando/commando_subculture_back_walk_sheet.png`

아이콘 규칙:

- Python의 PNG crop/normalization이 있으면 Godot에서도 비슷한 시각 크기로 맞춘다.
- unlock 퍽 카드와 실제 오브가 서로 다른 id를 쓰더라도 같은 모티프가 보이게 한다.
- 대여/영구 뱃지는 원본 아이콘을 오염시키지 않고 HUD overlay로 표현한다.
- 새 texture key는 Godot resource loader/prewarm 목록에 등록해 첫 전투 진입 때 누락 fallback이 발생하지 않게 한다.
- 코만도 player render context는 스매셔 텍스처 fallback이 아니라 코만도 sprite sheet 로드 성공 여부를 기준으로 한다.

## 12. 저장, 로드, 리셋

Godot 포트에서 저장/로드가 해당 런타임까지 확장될 때 아래 상태를 보존한다.

- `permanent_owned`
- `equipped_permanent`
- `rental_weapons`
- `current_weapon_id`
- 화기별 탄약/지속시간/쿨타임 상태
- 코만도 스킬 쿨타임 잔여 시간
- 물자보급 진행 중 상태가 저장 범위에 들어갈 경우 hold/aircraft/drop/pickup 상태
- 코만도 스킬 해금 상태
- 코만도 장착 스킬 리스트

현재 Godot 1차 런타임 표면:

- `commando_skill_config.gd`는 shared-slot `equipped_permanent`, 쿨타임 multiplier, item slot bonus를 save snapshot으로 내보내고 복원한다. 복원 중 알 수 없는 skill id, 중복 id, 현재 capacity를 넘는 id는 버린다.
- `commando_weapon_controller.gd`는 `permanent_owned`, `equipped_permanent`, `rental_weapons`, `current_weapon_id`, `prepared_stage_id`, 화기별 탄약/탄창/재장전/AK-47 지속시간을 save snapshot으로 내보내고 복원한다.
- `commando_skill_state.gd`는 스킬 쿨타임, pause 시작 시각, active transition 시각을 save snapshot으로 내보내고 복원한다.
- `commando_supply_drop_state.gd`는 진행 중 hold / aircraft / crash / pending payload / collectible drop 상태를 save snapshot으로 내보내고 복원한다.
- 전역 저장 파일과 runtime perk unlock-level save schema 연결은 별도 통합 단계로 남긴다.

리셋 규칙:

- 새 게임/메인 메뉴 복귀: 코만도 상태 전체 초기화
- 일반 라운드 리셋: 발사 중인 임시 효과, 입력 버퍼, transient VFX 정리
- 실제 스테이지 전환: 대여 화기 제거, 영구 화기 보충, 스테이지 단위 플래그 정리
- 쿨타임 리셋과 active runtime teardown은 별도 책임으로 유지

## 13. 오디오/VFX 포팅 기준

코만도는 화기별 피드백이 플레이 감각의 핵심이므로 오디오와 VFX를 포팅 범위에 포함한다.

필수 오디오 표면:

- 화기 전환
- 권총 준비/발사/1발 재장전
- 바주카 발사/폭발
- AK-47 발사 루프 또는 연사음
- 그물덫총 발사/포획
- 화력지원 호출/낙탄
- 볼링트랩 설치/충돌
- 자폭드론 발진/폭발
- 물자보급 호출/드롭/획득
- 재장전 성공/실패

현재 Godot 1차 상태에서는 화기별 전용 발사/명중 cue 이름을 `commando_firearm_runtime.gd`와 `game_audio.gd`에 연결하고, Python 기준 wav를 우선 로드한다. 기본 권총과 베레타는 준비음 `gunroad.wav`, 실제 발사음 `gunshot.wav`를 공유하되, 재장전 시작음 `pistolreloadstart.wav`와 발당 재장전음 `pistolreload.wav`는 기본 권총의 발사 입력 재장전 및 재장전 스킬 성공 경로에서만 사용한다. AK-47은 `ak47.wav`, 바주카 발사 준비는 `bazukagoing.wav`, 그물 포획은 `net.wav`, 볼링트랩 설치/포획은 `ballingtrapsetup.wav` / `ballingtrapgrap.wav`, 자폭드론은 `drone.wav` 루프를 사용한다. `fire_support`는 호출 프레임에 generic 발사음을 겹치지 않고 전용 무전 cue만 사용하며, 바주카/화력지원/자폭드론 폭발은 Python 기준 수류탄 폭발 cue를 탄다. AK-47은 단일 player 재시작으로 앞 발사음을 끊지 않도록 같은 wav/gain을 쓰는 layered player pool로 재생한다.

VFX 포팅 기준:

- Python의 타이밍과 판정은 보존한다.
- 최종 Godot 표현은 texture, sprite sheet, ShaderMaterial, GPUParticles2D, Tween/AnimationPlayer를 우선한다.
- direct `canvas.draw_*()`는 임시 parity scaffold 또는 작은 fallback으로만 둔다.
- detached FX host는 viewport transform을 명확히 적용한다.

보상/골드 표면:

- Python 원본의 `calculate_soldier_skill_gold_reward`와 `trigger_soldier_skill_cooldown` 기준을 따른다.
- Godot 1차 포트는 `supply_drop` 스킬 사용 골드만 유지한다. 지급량은 기본 쿨타임 40초 기준 96이며, 쿨감 아이템/런타임 배율로 변하지 않는다.
- `emergency_supply`, 영구 화기류, `commando_pistol`은 스킬 사용 골드를 지급하지 않는다.
- 지급은 `commando_player_controller.gd`가 `skill_gold_award` 결과 키로만 반환하고, 실제 적립은 공통 `battle_scene_actor_update_result_applier.gd`가 한 번만 수행한다. 코만도 모듈은 `runtime_perk_gold`를 직접 쓰지 않는다.

## 14. 구현 단계

### 1단계: 모듈 스캐폴딩

- `game_selection_state.gd`와 `player_character_runtime.gd`에 `soldier` 라우팅 추가
- `commando_skill_config.gd`
- `commando_skill_state.gd`
- `commando_weapon_controller.gd`
- `commando_supply_drop_state.gd`
- module catalog 등록
- 코만도 스프라이트/아이콘 texture key와 prewarm 등록
- 기본 단위 테스트 또는 smoke test 추가

### 2단계: 입력과 1개 고정 화기 패널

- 마우스 휠 화기 순환 구현
- 좌측 필러 `commando_firearm_selector_renderer.gd` 구현
- 화기 획득 수와 무관하게 패널 수가 1개로 유지되는 smoke test 추가
- 필러 슬롯 클릭 선택은 구현하지 않음

### 3단계: 5구슬/해금/스왑

- 고정 오브 2개와 공유 슬롯 모델 구현
- 코만도 unlock perk 매핑
- `runtime_perk_catalog.gd`의 soldier 풀, choice, debug 목록 등록
- 슬롯 full 필터링/스왑 다이얼로그
- 취소 no-op QA
- tooltip pause/resume 연결

### 4단계: 화기별 실제 효과

- `commando_firearm_runtime.gd`에서 화기별 발사와 탄약 처리
- 대여/영구 분기
- `emergency_supply` 대상 규칙
- 휠 전환 직후 잔류 발사 억제
- Stage 1 최소 화기 투사체/머즐/충돌 플래시 draw context와 임시 direct-draw 렌더러
- 타깃 명중 이벤트와 공용 피격 파티클/화면 흔들림/보스 피격 애니메이션/공 hit pulse/one-shot 오디오 hook
- `status_effect_state`를 통한 화기별 1차 보스 상태이상 결과
- `commando_firearm_lingering_effects`를 통한 그물장/화염지대/트랩/폭격 잔광 1차 지속 필드
- 화력지원 호출 대기, 항공기 진입, 순차 5~7발 중력 폭격 생명주기
- 볼링트랩 설치 완료, 하강 공 포획, 90프레임 고정, 4배속 상향 재발사
- 화기별 쿨타임과 item-instance식 내부 gate 동기화

### 5단계: 보급/대여/스테이지 전환

- `supply_drop` 드롭 테이블
  - 현재 Godot 포팅 완료 active item subset(`grenade`, `molotov`, `flare`, `spider_mine`, `dynamite`, `gauge_charge`, `ammo_box`, `doping_potion`)과 대여 화기 weighted table을 사용한다.
  - `ammo_box`는 영구 화기가 최소 1개 있을 때만 후보가 되고, `doping_potion`은 `commando_pistol` 영구 해금 후에만 후보가 된다.
- 물자보급 hold/항공기/낙하물 생명주기
- 일반 아이템 드롭은 보급 낙하산 직접 회수 후 기존 active item pickup / 슬롯 수납 경로 사용
- 대여 화기 지급
- 대여 중복 방지
- 대여 탄약 0 즉시 제거
- 다음 실제 스테이지 전환에서 대여 제거
- 영구 화기 스테이지 시작 보충

### 6단계: 오디오/VFX/QA

- 주요 사운드 연결
- 루프 사운드 cleanup
- 화기별 VFX remaster
  - Stage 1 renderer는 1차 texture-piece glow/burst/ring 레이어와 shader / `GPUParticles2D` / Tween 기반 FX host를 함께 사용한다.
  - 권총 헤드샷/레그샷은 60프레임 한국어 피드백 텍스트를 보스 근처에 띄우고, 레그샷은 보스 근처에 보라색 wave를 추가한다.
  - 다음 단계에서는 실제 플레이 화면 기준으로 무기별 VFX identity와 체감 QA를 확인한다.
- 코만도 전용 골드/보상 정책 확정 및 중복 지급 방지
- headless load check
- windowed/scaled visual check
- save/load가 준비된 영역까지 smoke test

## 15. QA 체크리스트

- [x] 캐릭터 선택에서 코만도를 고르면 `runtime_character_id == "soldier"`가 전투 진입 후까지 유지된다.
- [x] `game_selection_state.gd`와 `player_character_runtime.gd`가 코만도를 스매셔로 정규화하지 않는다.
- [x] 전투 중 플레이어 actor가 코만도 스프라이트로 렌더되고 스매셔 fallback 텍스처가 보이지 않는다.
- [x] 코만도 아이콘/스프라이트 texture key가 resource loader/prewarm에서 누락되지 않는다.
- [x] 코만도로 시작하면 좌측 필러 화기 패널이 1개만 보인다.
- [x] 화기를 여러 개 해금/대여해도 좌측 필러 패널 수가 늘지 않는다.
- [x] 마우스 휠 위/아래로 현재 화기가 순환된다.
- [x] 전환 직후 잔류 좌클릭/SPACE가 발사로 새지 않는다.
- [x] 필러에 쌓인 화기 슬롯을 클릭해 선택하는 UX가 없다.
- [x] `supply_drop`과 `emergency_supply`는 고정 오브로 유지된다.
- [x] 영구 화기는 공유 오브 슬롯을 점유한다.
- [x] 대여 화기는 오브 슬롯을 점유하지 않는다.
- [x] 공유 슬롯이 가득 찬 상태에서 새 해금은 스왑 플로우를 탄다.
- [x] 스왑 취소는 ownership, unlock, runtime level, controller 상태를 바꾸지 않는다.
- [x] `runtime_perk_catalog.gd`의 선택 후보, 전체 데이터, debug 목록에 코만도 퍽이 들어간다.
- [x] `emergency_supply`는 현재 선택한 기본 `pistol` 또는 영구 화기를 보충한다.
- [x] `emergency_supply`는 기본 `pistol`에는 150 게이지로 1발만 보충하고, 대여 화기에는 실패하며 비용을 쓰지 않는다.
- [x] `supply_drop`은 1~3개 payload를 큐에 넣고, 대여 화기를 중복 예약하지 않는다.
- [x] `supply_drop`은 대여 가능 상태에서도 일반 아이템이 나올 수 있는 weighted table을 사용한다.
- [x] `supply_drop` 일반 아이템은 기존 active item pickup / 슬롯 수납 경로를 타고, 대여 화기만 rental 지급 경로를 탄다.
- [x] `supply_drop` payload는 즉시 지급되지 않고 항공기 아래 보급 위치에서 낙하산 상자로 생성되며, 플레이어 직접 회수 시 지급된다.
- [x] `supply_drop` 일반 아이템은 슬롯 full 등으로 수납이 거절되면 낙하산 상자를 유지한다.
- [x] `supply_drop`은 Python 후보였던 `ammo_box` / `doping_potion`을 조건부 후보로 포함하고, 두 아이템 모두 기존 active-item 슬롯 / 사용 경로로 이어진다.
- [x] `ammo_box`는 대여 화기를 제외한 모든 영구 화기의 탄약과 AK-47 내구를 최대치로 보충한다.
- [x] `doping_potion`은 `commando_pistol` 보유 시에만 활성화되고, 8초 동안 권총 쿨타임 30프레임, 조작 잠금 9프레임, 헤드샷 / 레그샷 확률 2배, 탄속 1.2배 메타데이터를 제공한다.
- [x] 물자보급 진행 중 라운드 재시작/스테이지 전환/게임 리셋에서 항공기, 낙하물, 루프 사운드가 남지 않는다.
- [x] `supply_drop` 항공기는 플레이어 공에 맞으면 보급 payload를 취소하고 추락/폭발 후 사운드와 VFX가 정리된다.
- [x] `supply_drop` 항공기는 플레이어 패들 또는 Brick 벽에 닿아도 payload를 취소하고 추락/폭발하며, Brick 벽은 소모하지 않는다.
- [x] `supply_drop` 항공기, 낙하산 상자, 추락 폭발은 texture-piece 레이어와 shader / `GPUParticles2D` / Tween FX host로 최종 Godot-native VFX remaster 경로를 탄다.
- [x] 영구 화기는 일반 라운드 리셋으로 보충되지 않는다.
- [x] 대여 화기는 일반 라운드 리셋으로 사라지지 않는다.
- [x] 대여 화기는 다음 실제 스테이지 전환에서 사라진다.
- [x] 대여 화기는 탄약 0이 되면 즉시 제거된다.
- [x] 화기 발사 성공 시 최소 투사체/머즐/충돌 플래시가 actor draw context와 Stage 1 렌더러로 이어진다.
- [x] 기본 `pistol` 슬롯은 호환 id를 유지하면서 권총 fire profile을 사용하고, 입력 즉시 투사체를 만들지 않고 준비음 뒤 24프레임 지연 발사한다.
- [x] 기본 권총은 총 4발 탄약을 보유하고, 발사 입력마다 1발을 소모하며, 실제 투사체/탄피는 지연 발사 프레임에 생성된다.
- [x] 기본 권총은 휠 전환 직후 이미 눌린 action held 상태를 fresh press로 오인하지 않고, 새 press edge에서만 장전/조준 발사를 시작한다.
- [x] 기본 권총 명중은 `commando_pistol`과 같은 headshot/legshot/combo/게이지 result lane을 사용하되, 베레타의 영구 화기 탄약 보충 규칙과는 분리된다.
- [x] `commando_pistol`은 베레타로 표시되며 8발 탄약, 24프레임 조준 지연 발사, 30프레임 발사 쿨타임, 탄속 30, 권총보다 30% 좁은 탄 퍼짐, 18프레임 수평 이동 잠금, 빈 탄약 발사 실패, 재장전 스킬 전용 보충을 별도 영구 화기 경로에서 처리한다.
- [x] 화기 타깃 명중 시 hit event, 공용 피격 파티클, 화면 흔들림, 보스 피격 애니메이션, 공 hit pulse, 발사/명중 오디오 hook이 실행된다.
- [x] 화기 발사/충돌 오디오는 화기별 전용 cue 메서드를 우선 사용하고, 전용 cue가 없는 환경에서는 기존 generic hook으로 fallback한다.
- [x] 권총/베레타/AK-47/바주카/그물/볼링트랩/자폭드론은 Python 기준 wav asset을 Godot `game_audio.gd`에서 직접 로드하고, 권총 준비/기본 권총 재장전 cue와 자폭드론 루프 폭발/라운드 cleanup을 처리한다.
- [x] AK-47 발사음은 Python 기준 `ak47.wav` / -6dB gain을 유지하면서 연사 중 앞 발사음을 끊지 않는 layered player pool로 재생한다.
- [x] AK-47 발사 시 Python 기준 3초 수명, 중력, 바운스, 회전이 있는 탄피 context가 생성되고 Stage 1에서 작은 brass casing으로 그려진다.
- [x] 권총/강화 권총은 Python 기준 일반/헤드샷/레그샷 명중 게이지 30/50/40을 effects result로 넘기고, 시각 잔류 효과가 없는 명중이어도 pending result update 경로를 통해 controller가 현재 게이지에 반영한다.
- [x] 권총 헤드샷은 Python 기준 60프레임 스턴, 레그샷은 132프레임 70% 이동속도 slow를 `status_effect_state`에 기록한다.
- [x] Stage 1 renderer는 권총 헤드샷/레그샷 feedback context를 읽어 보스 근처 한국어 텍스트와 레그샷 wave를 그린다.
- [x] 권총/강화 권총은 Python 기준 헤드샷 즉시 1 피해와 3회 보스 명중 combo 1 피해를 effects result로 넘긴다.
- [x] AK-47은 Python 기준 20회 보스 명중마다 보스 체력 피해 1을 effects result로 넘긴다.
- [x] 권총/AK-47/바주카/그물덫총/화력지원/자폭드론의 투사체 충돌은 Python 기준 탄환 rect, 그물 확장 boss hitbox, 폭발 반경을 따른다.
- [x] Stage 1 코만도 화기 머즐/충돌/잔류장 VFX는 캐시된 texture piece 레이어를 먼저 그리고, 기존 direct draw는 세부선/fallback로 유지한다.
- [x] Stage 1 코만도 화기 머즐/충돌/잔류장 VFX는 playfield-local `ShaderMaterial` / `GPUParticles2D` / pulse `Tween` host를 동기화한다.
- [x] Stage 1 코만도 화기 FX host는 렌더러의 deferred attach 경로에서도 `_ready()` 이후 첫 활성 동기화 상태를 유지하고, VFX context가 비면 숨겨진다.
- [x] Stage 1 코만도 화기 renderer는 visual identity report로 권총/베레타/AK-47/바주카/그물/화력지원/볼링트랩/자폭드론 8개 화기 family가 서로 다른 silhouette/FX layer를 쓰는지 자동 점검한다.
- [x] 화기 타깃 명중 시 바주카/화력지원/볼링트랩/자폭드론은 보스 스턴 계열, 그물덫총/자폭드론 잔류 화염은 보스 둔화 계열, AK-47/권총은 짧은 경직 계열의 1차 상태이상 결과를 공유 상태 시스템에 기록한다.
- [x] 그물덫총 명중 후 4초 그물장, 자폭드론 폭발 후 2.5초 화염지대, 볼링트랩/화력지원의 짧은 잔상 필드가 actor draw context에 남고, 그물장/화염지대는 보스가 안에 있을 때 공유 둔화 상태를 주기적으로 갱신한다.
- [x] 화력지원은 사용 즉시 탄약을 소모하고 호출 대기, 항공기 진입, 순차 5~7발 폭격으로 이어지며 각 폭격 명중마다 보스 상태이상, hit event, 명중 오디오를 남긴다.
- [x] 화력지원 항공기는 전용 무전 cue와 항공기 루프를 사용하고, 폭격 종료/라운드 reset에서 루프를 정리하며, Python 기준 공 충돌 no-crash pass-through를 유지한다.
- [x] 보스 체력형 전투에서는 코만도 화기 피해가 `boss_current_health`를 깎고, 체력 0 도달 시 플레이어 득점 flow로 한 번만 소비되며, 다음 라운드 reset에서 체력이 최대치로 복구된다.
- [x] 보스 HP HUD context와 체력바 렌더러는 `boss_max_health > 0`일 때 actor draw 경로까지 전달된다.
- [x] 볼링트랩은 설치 완료 후 플레이어 진영에 남고, 하강 공을 포획해 90프레임 동안 공 이동을 소유한 뒤 Python 기준 4배속 상향 발사 결과를 공 업데이트 경로로 반환한다.
- [x] 볼링트랩 재발사 공이 보스 패들에 가드되면 1회성 guard 상태를 소비하고, 공속을 원래 속도의 70%로 되돌리며, 공유 보스 스턴/넉백 AI 컨텍스트로 Python 기준 22px power / 60프레임 스턴을 적용한다.
- [x] 화기 패널 hover tooltip은 현재 화기의 탄약, 기본/영구/대여 상태, 재장전 가능 여부, 해금 스킬구슬 alias를 한국어로 보여준다.
- [x] 오브 쿨타임 wedge, 남은 시간, tooltip 쿨타임이 같은 최종 쿨감 값을 쓴다.
- [x] 코만도 스킬 사용 골드/보상 정책이 공통 보상과 이중 지급되지 않는다.
- [x] TAB/ESC/선택/스왑/피드백 텍스트에 코만도 퍽과 해금명이 한국어로 보인다. 현재 Godot 경로는 `commando_ui_text_audit_smoke.gd`로 1차 smoke 완료.
- [x] unlock 퍽 아이콘과 실제 오브 아이콘 alias가 같은 모티프를 사용한다.
- [x] 모든 새 Godot UI 문자열은 한국어다.
- [x] 코만도 스킬 config/무기/스킬 쿨타임/물자보급의 준비된 save snapshot 범위는 smoke test로 왕복 검증된다.
- [x] Godot headless load check가 통과한다.

## 15A. 화기 메커닉 재포팅 체크리스트

아래 항목은 2026-05-06 재조사 이후 새로 추가한 실제 완료 기준이다. 이 목록이 끝나기 전에는 화기류 포팅을 완료로 보지 않는다.

- [x] 기본 슬롯은 UI/tooltip/발사 결과에서 `권총`으로 보이고, `commando_pistol`은 별도 영구 화기 `베레타`로 구분된다.
- [x] 기본 권총은 총 4발 탄약, 입력 시 `gunroad.wav` 준비음, 24프레임 조준 지연, 지연 프레임의 탄환/탄피 생성과 `gunshot.wav` 발사음을 구현한다. 입력 직후 바로 투사체가 생성되지 않는 smoke로 고정했다.
- [x] 기본 권총은 탄약 0 상태 좌클릭/SPACE로 150 게이지를 한 번 소모해 전체 탄창 재장전을 시작하고, 재장전 중에는 화기 전환과 권총 발사가 막히며, 4발이 가득 찰 때까지 발당 `pistolreload.wav` 계열 장전음을 재생한다. 대여 화기는 여전히 재장전 대상이 아니다.
- [x] `commando_pistol`은 별도 영구 화기로만 선택 가능하고, 베레타 표시명, 탄약 8발, 발사 입력 재장전 차단, 재장전 스킬 전용 보충, 30프레임 발사 쿨타임, 탄속 30, 권총보다 30% 좁은 탄 퍼짐, 18프레임 후딜, 발사 애니메이션 지연을 반영한다. 현재 smoke는 수평 이동 잠금과 탄피/오디오 타이밍까지 확인했고, 최종 권총 조준 포즈 visual QA는 별도 VFX pass로 남긴다.
- [x] 권총 일반/헤드샷/레그샷은 원본 확률, 게이지 30/50/40, 스턴/슬로우, 체력형 보스 3히트 combo와 헤드샷 피해를 행동 테스트로 검증한다. 현재 smoke는 10% 헤드샷 / 12% 레그샷 확률 경계, `commando_pistol` 일반 42프레임 스턴 + 18프레임 감속 넉백, 헤드샷 108프레임 스턴, 레그샷 132프레임 70% 슬로우, 일반/헤드/레그 게이지 30/50/40, 헤드샷 즉시 피해, 레그샷 combo-only 피해를 확인한다.
- [x] AK-47은 탄약 60, 30초 내구, 6프레임 발사 간격, 첫 입력 2발 burst, 홀드 자동 연사, 반동 누적/회복, 발사 중 이동속도 50%, 탄피/연사 사운드 풀을 구현한다. 현재 smoke는 선택 idle 내구 미소모, 탄약/내구 sync, 첫 발/두 번째 burst/이후 auto-fire, 이동속도 clamp, 탄피 3개, rapid-fire cue 3회를 확인한다.
- [x] AK-47 투사체는 탄속 16, 수명 60프레임, 6x6 충돌, 6프레임 짧은 스턴/넉백, 20히트당 체력 피해를 검증한다. 현재 smoke는 속도/수명과 기존 hitbox/status/boss-health 누적 경로를 함께 고정한다.
- [x] 바주카포는 탄약 4, 120프레임 쿨타임, 30프레임 조작 잠금, 초기 속도 3에서 0.8씩 가속해 최대 35가 되는 로켓, 연기 꼬리 10개, 벽/보스 충돌 폭발을 구현한다.
- [x] 바주카 폭발은 반경 155, 넉백 40, 스턴 90, 발사 포즈 30프레임, muzzle flash 5프레임, 폭발 사운드와 화면 피드백을 검증한다.
- [x] 그물덫총은 탄약 3, 120프레임 쿨타임, 30프레임 조작 잠금, 속도 18 투사체, rope trail, 보스 확장 hitbox/segment proximity, 빗나감 dissolve net을 구현한다.
- [x] 그물 성공 시 4초 동안 보스 X 이동 제한/둔화, 플레이어 rope slow 0.7, 대시 rope break, `net.wav` 포획음을 검증한다.
- [x] 화력지원은 호출권, 42프레임 무전 잠금, 120~180프레임 호출 지연, 항공기 진입 후 60프레임 drop-arm, 5~7발 폭격, 60프레임 폭격 간격, `vy=2.0` / 중력 0.35 낙탄, 항공기 루프 cleanup, 공 충돌 no-crash를 구현한다.
- [x] 볼링트랩은 탄약 3, 120프레임 쿨타임, 30프레임 조작 잠금, 48프레임 설치, 플레이어 진영 60% 설치 제한, 설치 포즈/게이지/사운드, 하강 공 포획, 90프레임 클로 애니메이션, 4배속 상향 발사를 구현한다. 현재 smoke는 held 입력 중복 설치 방지, 설치 중 재입력 실패, 상단 필드 설치 실패 시 탄약 미소모까지 함께 확인한다.
- [x] 볼링트랩 발사 공은 보스 가드 시 22 power/60프레임 스턴/원속도 70% 복구를 공유 패들 충돌 경로로 넘긴다.
- [x] 자폭드론은 탄약 4, 폭발 후 90프레임 쿨타임, 48x48 드론, 6프레임 grace, 플레이어 위치 고정, 입력 가속 1.2/최대속도 14, rotor/루프 사운드를 구현한다.
- [x] 자폭드론은 수동/보스/공/상단벽 충돌 폭발, 반경 150, 0.8초 스턴, 150프레임 화염지대, 공 충돌 시 3배 상향 부채꼴 가속과 보스 반격 시 속도 복구를 검증한다.
- [x] 모든 무기 발사/충돌/루프 사운드는 원본 타이밍에 맞고, score event, scoreboard, serve wait, round restart, game reset에서 루프가 남지 않는다. 현재 `commando_firearm_audio_routing_smoke.gd`와 `commando_supply_drop_audio_cleanup_smoke.gd`로 전용 cue/루프 cleanup을 1차 고정한다.
- [x] 무기별 행동 테스트는 smoke보다 강한 기준으로 작성한다. 발사 조건, 입력 지속/해제, 탄약/내구, projectile 속도/수명, 충돌 결과, 상태이상, 보스 체력 피해, 오디오 hook, cleanup을 각각 확인한다.
- [x] 최종 Godot headless load check와 Stage 1 실제 화면 visual QA에서 권총/베레타/AK-47/바주카/그물/화력지원/볼링트랩/자폭드론이 서로 다른 무기로 읽힌다. 현재 `commando_firearm_stage1_visual_qa_smoke.gd`는 headless draw-path QA와 windowed viewport pixel signature QA를 모두 통과했고, renderer identity report도 8개 family를 유지한다.

## 16. 포트 수락 기준

코만도 포팅 1차 완료는 다음 상태를 의미한다.

- 코만도 선택 후 전투 진입 가능
- 전투 런타임 id가 `soldier`로 유지되고 스매셔 런타임으로 fallback되지 않음
- 전투 중 코만도 플레이어 스프라이트 렌더링
- 기본 권총 4발 탄약 / 준비음 / 지연발사 / 150게이지 1발 재장전 동작
- 물자보급/재장전 오브 동작
- 영구 화기 해금 및 공유 슬롯 장착/스왑 동작
- 대여 화기 획득/사용/스테이지 제거 동작
- 좌측 필러 화기 UI 1개 고정
- 마우스 휠로만 현재 화기 순환
- 화기별 원본 기준 projectile, 탄약/내구/쿨타임, 상태이상, 오디오, VFX, cleanup 동작
- Godot headless load check 통과
- 코만도 관련 smoke test 통과
- `15A. 화기 메커닉 재포팅 체크리스트` 통과

이 기준을 만족하기 전에는 "코만도 포팅 완료"로 보지 않는다.
