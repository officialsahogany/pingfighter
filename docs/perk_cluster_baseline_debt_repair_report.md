# 퍽 기준선 부채 11종 수리 완료 보고서

- 기준 지시문: `docs/perk_cluster_baseline_debt_repair_goal.md` @ `e652bfebf`
- 작업 위치: 격리 워크트리 `D:\main\bosspong_perk_cluster_debt_repair`
- 기능 커밋: `9253ecb2b`, `3af91d3ee`, `6cdec487b`
- 푸시: 없음
- 최종 판정: **GREEN — 기준선 부채 11종 전부 수리, blocked/unverified 0건**

## 1. 동결과 기준선

- 동결 HEAD: `e652bfebffc34484920545262046757342c51203`
- 동결 증거: `D:\codex_tmp\perk_cluster_debt_repair_20260817_170000`
- 상태 SHA-256: `86A737FB95E02B23EF41A56A5832A27D06C0B1F631490FE58077D12CBC952927`
- 변경 파일 매니페스트 SHA-256:
  `CD815E5EDB25BCA57C8E354AB69D7B8B04E6D983B4BBAD0EF97C44AE3F7779E9`
- exact 124종 목록 SHA-256:
  `112D03546EAAC6A06491C7841AFE4CFEAD5CB019FB6BC955585F372771D50A8B`
- 기준선 재현: 부채 11종 `PASS=0 FAIL=11`, exact 124종
  `PASS=113 FAIL=11`.

기준선 11종은 다음과 같다.

1. `mystic_dice_active_item_smoke`
2. `perk_fusion_cold_boot_cinematic_smoke`
3. `perk_fusion_cold_boot_timeline_smoke`
4. `perk_fusion_display_consumer_smoke`
5. `perk_fusion_localization_smoke`
6. `perk_fusion_value_hooks_smoke`
7. `runtime_perk_callback_map_smoke`
8. `runtime_perk_character_context_smoke`
9. `runtime_perk_general_icon_static_smoke`
10. `runtime_perk_payload_access_smoke`
11. `runtime_perk_runtime_state_access_smoke`

## 2. 그룹별 커밋과 수리 내용

### 2.1 그룹 1 — 런타임 퍽 모듈 분리 이관 계약 5종

- 커밋: `9253ecb2bde99c703e38e830daedaebcb0065459`
- 메시지: `refactor(perk): complete shared runtime access migration`
- 범위: 49파일, `+639/-1463`

callback map, character context, general icon, payload, runtime-state 접근을 공유 정본
모듈로 완결했다. 다수 소비자에 남아 있던 중복 로컬 도우미를 정본 접근자로
교체했고, 씰은 폐기된 로컬 함수명 대신 현재 공유 소유권과 실제 위임을 검증하도록
개정했다. 이는 씰 약화가 아니라 이미 진행된 모듈 분리의 미완 이관을 닫은 것이다.

- 대상 부채 5종: `5/5 PASS`
- 관련 소비자 회귀: `18/18 PASS`
- 그룹 1 뒤 exact 124종: `PASS=118 FAIL=6`
- 변경 GDScript 49종 경고: 0
- 헤드리스 로드·staged/unstaged diff check: PASS

### 2.2 그룹 2 — 융합 4종과 수호령 강화 오디오

- 커밋: `3af91d3ee9aaf5cc3f89d7e88476a9ceb4bca5e8`
- 메시지: `fix(perk): repair fusion baseline debt contracts`
- 범위: 20파일, `+585/-39`

런타임 수리는 다음과 같다.

- `runtime_perk_state`의 stats registry 강참조를 `WeakRef`와 reset 정리로 바꿔
  `registry -> state -> registry` 순환과 81개 리소스 잔류를 제거했다. owner 없음과
  reset 역방향 레그를 추가했다.
- Golden Trajectory만 정본 골드 적립 flow의 명시적 visible-feedback 옵션을
  사용한다. 일반 적립의 기존 무표시 기본값은 보존했다.
- 수호령 강화 컷인의 ROLL → STAMP → TAIL 오디오 타이밍을 실제 presentation
  coordinator와 `GameAudio`에 연결했다. roll만 루프이며 stream을 복제한 뒤 loop를
  설정한다. `gameplay_loop_audio_cleanup.gd`에
  `stop_lingpet_guardian_enhance_cutin_loop`를 등록해 score, scoreboard, serve wait,
  round restart, reset, cancel 정리 경계를 공통 owner로 통과시켰다.
- 같은 중앙 정리 씰이 드러낸 기존 `stop_stage4_illusion_loop` 등록 누락도 동일한
  loop-cleanup 불변식 안에서 보완했다.

씰 개정은 다음 정본 변경만 반영했다.

- 한국어 최대 무공 레벨 헤더는 낡은 `Lv.5`가 아니라 `극성`이며, `Lv.5` 부정
  레그를 추가했다.
- es/pt-BR/ru 무공 용어를 현재 언어 정본과 동기화하고 one-off 표기는
  `format_mugong_rank()`를 거치도록 검증한다.
- 콜드부트 strict leak 씰은 무관한 `GameAudio` 전체를 가짜 부팅하지 않고 실제
  오디오 owner, 플레이어 팩토리, WAV, SFX 버스와 facade를 연결한다. 재생 종료 뒤
  플레이어와 stream을 해제하고 오디오 서버 프레임을 배출한다.

#### 결정론적 오디오 파생과 GRT-036

사용자가 승인한 1안에 따라
`godot/tools/derive_guardian_enhance_audio.py`를 도구로 함께 커밋했다. 입력은 기존
`mining.wav`, `roundgong.wav`, stamp의 확정 징 레이어
`stage2_speed_defense_block_chime.wav`이며, 부동소수 난수 없이 고정 정수 연산으로
44.1 kHz PCM16 mono 산출물을 만든다. `--write` 뒤 `--check`를 실행해 같은 바이트와
해시가 재현됨을 확인했다.

| 산출물 | 길이 | SHA-256 |
|---|---:|---|
| `guardian_enhance_roll_loop.wav` | 0.750초 | `641B4D42D95C6D2B72B2EF8AC8012BF747652D56E17EE75A6589CE9EB03E466F` |
| `guardian_enhance_stamp.wav` | 0.400초 | `B3B57347C235E392143A9AB78A3DC434E8E144735C29E7425E32D50F7BD16723` |
| `guardian_enhance_result_tail.wav` | 1.200초 | `A757A8D541B493788559C9DEBD9D9A87DACAB92CF4A0C041F0FB79CA4E4F9E1B` |

세 파일은 `godot/assets/sounds/lingpet/` 아래 `game_audio.gd` 계약 경로에 있다.
파생기는 원본의 metadata·trailing chunk를 복사하지 않고 `fmt `와 `data` 청크만
새로 쓰며, 실제 바이트 길이에서 RIFF 크기를 다시 계산한다. 자체 컨테이너 검증과
실제 GameAudio owner 스모크 모두 통과했고, 러너의 WAV 경고는 0건이었다.

**가공 파생 = 임시 확정, 신규 음원 확보 시 동일 경로 교체 가능.** 교체 때도
GRT-036 인테이크와 loop-cleanup 계약 및 기존 owner 스모크를 그대로 통과해야 한다.

- 그룹 2 집중 배터리: `13/13 PASS`
- 파생기 `--check`: PASS, 3종 해시 일치
- 변경 GDScript 16종 경고: 0
- 헤드리스 로드·diff check: PASS

### 2.3 그룹 3 — 팔자윷 32px 아이콘 계약

- 커밋: `6cdec487b786c812479872fc32229ff042acddb6`
- 메시지: `fix(item): restore Fate Yut 32px icon contract`
- 범위: 3파일, `+77/-5`

에셋·카탈로그·`item-generation` 규칙을 대조해 32×32 원본이 정본임을 확인했다.
기존 256×256 윷 이미지를 최근접 32×32 RGBA로 축소해 기존 윷 4개의 정체, 파일명,
카탈로그 경로를 유지했다. 최근접 후보는 32px에서 반투명 픽셀이 15개로, Lanczos
121개와 area 119개보다 하드에지·소형 가독성 계약에 맞았다. 아이콘 SHA-256은
`8C425B251F1C500C9120729DCC4C71869F75725C7058F9AC231106218092F013`이다.

씰은 import cache의 크기가 아니라 원본 PNG 바이트를 직접 읽어 32×32를 검증하도록
강화했다. `run_mystic_dice_active_item_icon_qa.ps1`를 추가해 플레이 중에도
BelowNormal 우선순위·고유 로그·복구 계약으로 실제 `ActiveItemHudSlotRenderer`의
Vulkan 캡처를 실행한다. 54px compact, 78px standard, 96px detail 모두 윷 실루엣이
읽혔고 클리핑·반투명 번짐이 없었다.

- 팔자윷 관련 배터리: `11/11 PASS`
- 변경 GDScript 경고: 0
- 헤드리스 로드·Vulkan Forward Mobile 캡처·diff check: PASS
- 광역 `item_field_spawn_pool_smoke`는 이 그룹과 무관한 선재 액티브 아이템 WIP
  (`HOLOGRAM_DISK_ICON_PATH`, reset/query 서명 등)로 RED였다. 팔자윷 소유 11종과
  exact 124종에는 신규·악화 RED가 없다.

## 3. 최종 회귀 종단선

동결 때 고정한 동일 `tests_124.txt`를 수정 없이 재사용했다.

```text
Smoke count: 124
Smoke summary: PASS=124 FAIL=0 TOTAL=124
All Godot smoke tests passed.
```

따라서 기준선 113 PASS는 전부 보존됐고 부채 11종은 `11 -> 0`으로 개선됐다.

타워와 페이즈 회귀도 별도 실행했다.

```text
Tower-ascent suite: PASS=23 FAIL=0 TOTAL=23
Phase A/B/C focused core: PASS=7 FAIL=0 TOTAL=7
All Godot smoke tests passed.
```

최종 기능 커밋 범위 `e652bfebf..6cdec487b`의 GDScript 64종 집중 경고 스캔은
`64/64`, 경고 0건이었다. 최종 헤드리스 로드는
`Godot headless load check passed.`였고, commit-range `git diff --check`도 PASS다.

전체 저장소 경고 스캔에서 별도로 보인 `active_item_effect_renderer.gd`의
`HOLOGRAM_DISK_ICON_PATH` 누락은 이 작전 전후에 존재하는 다른 액티브 아이템 WIP
기준선 RED다. 이번 세 그룹의 touched-path 경고 및 exact 회귀와 분리했다.

## 4. fixed / deferred / blocked / unverified

| 구분 | 결과 |
|---|---|
| fixed | 기준선 11종 전부. 그룹 1 모듈 이관 5종, 그룹 2 융합 5개 실패 서명과 오디오 계약, 그룹 3 팔자윷 1종 |
| deferred | 수호령 강화의 외부 신규 음원 제작. 현재 결정론적 파생 3종은 임시 확정이며 동일 경로 교체 가능 |
| blocked | 0건 |
| unverified | 0건 |

지시문 §3 완료 조건인 11종 GREEN, 동일 124종의 기존 113 PASS 보존과 RED 0,
타워 23종 및 페이즈 A/B/C 핵심 GREEN, 독립 그룹 커밋, 보고서 작성을 모두
충족했다. 따라서 이 기준선 부채 수리 목표는 **완료 선언 가능**하다.
