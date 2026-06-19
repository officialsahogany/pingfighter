# SFX 위치 기반 스테레오 패닝 — 슬라이스 플랜 (단일 소스)

작성: 2026-06-20 · 상태: 설계 확정(리뷰 1회 반영), 배선 대기

> **리뷰 반영 (2026-06-20):** ① 버스 분기·타입정리(이미 §2.2/§4.2). ② **테스트 더블
> 깨짐** 신규 갭 → §4.4 / 트랩 #8 추가. ③ play_wall_hit 넓은 사용 → impact 경로만
> source_x(§4.3 강화). ④ `max_distance`만으론 원음량 미보장 → **`attenuation = 0.0`
> 명시**(§4.1) + `2d_panning_strength` 프로젝트 기본값 의존 명시.

이 문서는 "효과음을 소리 나는 위치(playfield X)에 따라 좌우로 패닝"하는
기능의 단일 소스 설계서다. 실제 GDScript 배선은 Codex/소유자가 하고
Claude는 적대적 리뷰 + 게이트를 맡는다 (repo 표준 분담).

---

## §0 확정 결정

- **범위(이번 슬라이스):** **타격 / 벽 바운스 사운드만.** 스킬·이펙트는 후속(§8).
- **강도:** **은은하게.** 화면 끝에서도 한쪽 채널로 쏠리지 않는 약한 패닝.
  단일 튜닝 레버 `HIT_PAN_STRENGTH`, 인게임 청취로 확정.
- **아키텍처(권장):** 타격 플레이어 2개(`paddle_hit_sfx`, `wall_hit_sfx`)만
  `AudioStreamPlayer2D`로 전환 + 중앙 `AudioListener2D` 1개. 나머지 수백 개
  SFX는 그대로 `AudioStreamPlayer`(비위치형, 중앙). → **사운드별 독립 패닝**,
  나중에 스킬/이펙트로 확장할 때 그대로 쓰는 백본.
- **경량 대안(Arch B):** §8.2. 노드 타입 안 바꾸고 단일 패닝 버스 하나로.
  더 작지만 동시 타격 겹칠 때 pan 공유 아티팩트.

핵심: **"가운데 = 기존 사운드 그대로"** 는 리스너를 중앙(x=380)에 두고 위치
없는 음을 전부 중앙에 두면 자동 충족된다. 즉 S1 백본은 **동작 변화 0**에서 출발.

---

## §1 신호 계약 (무엇이 어디로 흐르나)

```
playfield X (0..760, 중앙 380)
   └─ 타격 호출부에서 이미 보유 (ball_pos.x / impact_pos.x)
        └─ play_paddle_hit(source_x) / play_wall_hit(impact_speed, source_x)
             / play_rally_tier_accent(tier, source_x)
              └─ _play_with_pitch_at(player2d, pitch, source_x)
                   └─ player2d.position.x = source_x   (리스너 x=380 기준 상대 오프셋)
                        └─ 엔진이 panning_strength 로 좌우 패닝 자동 산출
```

- 호출부가 X를 안 넘기면 **기본값 = 중앙(380) = pan 0 = 기존과 동일**.
- X는 **playfield 좌표 그대로** 사용 (0..760). 변환 불필요.

---

## §2 하드 제약 — Godot 4 패닝의 진실 + 타입 함정 ⚠️

조사로 확정한 두 사실. 이 슬라이스의 위험은 거의 전부 여기서 나온다.

### §2.1 `AudioStreamPlayer`에는 pan 속성이 없다 (4.0~4.6 전부)

현재 게임의 모든 음은 `game_audio_player_factory.create()`가 만드는 비위치형
`AudioStreamPlayer`다. 이 노드의 오디오 조절 표면은 `volume_db` / `pitch_scale`
/ `bus`뿐 — **pan / balance 속성이 없다.** Godot 4에서 좌우 패닝은 두 군데만:

1. **위치형 노드**(`AudioStreamPlayer2D`/`3D`): pan을 직접 못 넣고 **위치**를
   넣으면 리스너 기준으로 엔진이 자동 산출 (`panning_strength` 스케일). ← 채택.
2. **`AudioEffectPanner`** (버스 이펙트): `pan` -1..+1을 직접 넣지만 **버스 전체가
   한 값을 공유** → 동시음이면 마지막 값이 전부 덮음. (Arch B에서만, §8.2)

`AudioStreamPlayerPolyphonic`도 per-voice pan API가 없다 → 제외.

### §2.2 ⚠️ 최대 함정: `AudioStreamPlayer2D ≠ AudioStreamPlayer` (타입 비호환)

둘은 상속 관계가 **아니다**:
- `AudioStreamPlayer` → `Node`
- `AudioStreamPlayer2D` → `Node2D` → `CanvasItem` → `Node`

공유 멤버(`volume_db`/`pitch_scale`/`stream`/`bus`/`play()`/`playing`/`stop()`)는
**덕타이핑으로만** 같고, GDScript 정적 타입은 둘을 서로 거부한다. 그래서
멤버 변수 타입만 `AudioStreamPlayer2D`로 바꾸면 다음이 줄줄이 깨진다:

| 위치 (game_audio.gd) | 깨지는 이유 | 처리 |
|---|---|---|
| `var paddle_hit_sfx: AudioStreamPlayer` (316), `var wall_hit_sfx:` (319) | 타입 선언 | → `AudioStreamPlayer2D` |
| `= player_factory.create(...)` (587, 590) | create()는 `AudioStreamPlayer` 반환 | → 새 `create_positional()` 사용 |
| `_play_with_pitch(paddle_hit_sfx, ...)` (2292) | 파라미터 타입 `AudioStreamPlayer` | → `_play_with_pitch_at(...)` |
| `_play_with_pitch(wall_hit_sfx, ...)` (2299, 2362, 2368, 2373) | 동상 (4곳) | → `_play_with_pitch_at(...)` |
| `_apply_sfx_bus_to_players()` (3110) `if player is AudioStreamPlayer` | **2D는 이 검사 통과 못 함 → 조용히 SFX 버스 누락 → 볼륨 슬라이더 안 먹음** | → `elif player is AudioStreamPlayer2D` 분기 추가 |
| `_configure_sfx_player(player: AudioStreamPlayer)` (3116) | 파라미터 타입 | → 위치형은 `create_positional()` 안에서 직접 SFX 버스 배정 |
| `_set_sfx_player_linear_volume(player: AudioStreamPlayer, …)` (2888) | 파라미터 타입 | 호출부가 타격 플레이어를 넘기는지 확인(현재 안 넘김), 넘기면 분기 |

→ `paddle_hit_sfx` / `wall_hit_sfx`를 건드리는 **`_play_with_pitch` 호출부는 정확히
5곳**(2292·2299·2362·2368·2373)이고 전부 정적 타입 에러로 드러난다. 누락하면
컴파일이 막아주므로 "조용히 안 됨"은 아니다 — **단, 버스 누락(3110)만은 컴파일이
못 잡는 조용한 함정**이라 반드시 §6 스모크로 봉인한다.

---

## §3 좌표 → 패닝 매핑

- playfield X = **0..760, 중앙 380** (확정: `battle_update_boss_ai_context_builder.gd`
  WIDTH=760, PLAY_LEFT=0, PLAY_RIGHT=WIDTH; MEMORY "Godot 플레이필드 = 풀 캔버스").
- 위치형 방식은 pan을 직접 안 넣는다. **리스너를 (380, 375)** 에 두고
  **player.position.x = source_x** 로 두면 (source_x − 380) 상대 오프셋을
  엔진이 패닝으로 변환. 중앙(380) → 오프셋 0 → **pan 0 = 기존 사운드**.
- y는 좌우 패닝에 무관(2D 오디오는 수평축만 L/R). 리스너/플레이어 y를 375로
  맞춰 순수 수평 오프셋만 남긴다.
- **정확한 pan 곡선은 Godot 내부 2D 패닝 math + 뷰포트에 의존** → 수식으로
  고정하지 말고 `HIT_PAN_STRENGTH` 한 레버로 인게임 튜닝. 명시 리스너가
  카메라와 무관하게 "중앙 기준"을 결정론적으로 고정한다.

거리 감쇠 무력화: **`attenuation = 0.0` 명시**(주 레버) + `max_distance` 크게(보조).
가장자리 vs 중앙 음량 동일 여부 인게임 확인. 상세 §4.1.

---

## §4 백본 변경 (구현 형태)

### §4.1 `game_audio_player_factory.gd` — 위치형 생성기 추가

기존 `create()` 옆에 형제 메서드. (전체 팩토리 교체 아님 — 타격 2개만.)

```gdscript
const HIT_PAN_STRENGTH := 0.4          # 단일 튜닝 레버 (은은하게)
const POSITIONAL_MAX_DISTANCE := 100000.0  # 보조 안전장치

func create_positional(parent: Node, name: String, path: String, volume_db: float) -> AudioStreamPlayer2D:
    var player := AudioStreamPlayer2D.new()
    player.name = name
    player.volume_db = volume_db
    player.panning_strength = HIT_PAN_STRENGTH
    player.attenuation = 0.0               # ★ 거리 음량 감쇠 OFF — 좌우 패닝만, 원음량 유지
    player.max_distance = POSITIONAL_MAX_DISTANCE   # 보조 (attenuation=0이 주 레버)
    player.position = Vector2(380.0, 375.0)   # 기본 중앙
    # bus 는 호출측(_configure)에서 SFX 로 배정
    if parent == null:
        return player
    var stream := ProjectResourceLoader.load_audio_stream(path, "Missing sound at %s", "Failed to load sound at %s")
    if stream != null:
        player.stream = stream
    parent.add_child(player)
    return player
```

> **거리 감쇠 (리뷰 ④):** `max_distance`만 크게 잡는 건 "완전한 원음량 유지"를
> 보장하지 못한다. **`attenuation = 0.0`을 명시**해 거리 기반 음량 변화를 끈다
> (패닝은 `panning_strength`가 별도 담당 → attenuation=0이 좌우 패닝을 죽이지 않음).
> 그래도 S3에서 가장자리 vs 중앙 음량 동일을 라이브로 확인. 또 프로젝트에
> `audio/general/2d_panning_strength` 설정이 없어 **기본값(1.0)** 이 곱해진다 —
> 최종 체감 강도 = `HIT_PAN_STRENGTH × 1.0`. 강도 조절은 노드 `panning_strength`
> 한 곳(`HIT_PAN_STRENGTH`)에서만, 프로젝트 전역 설정은 건드리지 말 것.

### §4.2 `game_audio.gd`

- 멤버 타입: `paddle_hit_sfx` / `wall_hit_sfx` → `AudioStreamPlayer2D` (316, 319).
- 생성: 587/590을 `player_factory.create_positional(...)`로 + SFX 버스 배정.
- **중앙 리스너 1개** (`setup_step` 노드 빌드 구간, owner_node 자식):
  ```gdscript
  hit_audio_listener = AudioListener2D.new()
  hit_audio_listener.position = Vector2(380.0, 375.0)
  owner_node.add_child(hit_audio_listener)
  hit_audio_listener.make_current()
  ```
  (리스너 없으면 카메라/뷰포트 기본으로 폴백하지만, 결정론 위해 명시.)
- 위치형 재생 헬퍼:
  ```gdscript
  const PLAYFIELD_CENTER_X := 380.0
  func _play_with_pitch_at(player: AudioStreamPlayer2D, pitch: float, source_x: float) -> bool:
      if player == null or player.stream == null:
          return false
      player.position = Vector2(source_x, 375.0)
      player.pitch_scale = pitch
      if player.playing:
          player.stop()
      player.play()
      return true
  ```
- 3개 공개 함수에 `source_x` 옵셔널 추가 + 5개 내부 호출부를 `_play_with_pitch_at`로:
  - `play_paddle_hit(source_x: float = PLAYFIELD_CENTER_X)` (2289)
  - `play_rally_tier_accent(tier: int, source_x: float = PLAYFIELD_CENTER_X)` (2296)
  - `play_wall_hit(impact_speed: float, source_x: float = PLAYFIELD_CENTER_X)` (2358)
  - `play_trampoline_bounce` / `play_trampoline_catch` (2366/2372) — wall_hit_sfx 재사용이라
    헬퍼만 교체, source_x는 기본 중앙(이번 슬라이스 범위 밖, 깨짐 방지용).
- `_apply_sfx_bus_to_players()` (3110) 2D 분기 추가:
  ```gdscript
  for player in _get_sfx_players():
      if player is AudioStreamPlayer:
          (player as AudioStreamPlayer).bus = SFX_BUS_NAME
      elif player is AudioStreamPlayer2D:
          (player as AudioStreamPlayer2D).bus = SFX_BUS_NAME
  ```

### §4.3 호출부 2곳 — X 흘려주기

- **패들 타격:** `paddle_bounce_rally_feedback_router.gd:55-60` — `register(ball_pos, …)`가
  `ball_pos`를 이미 보유. 접점 X는 `_get_paddle_contact_pos(ball_pos, is_player).x`
  (이미 펄스용으로 계산) 또는 `ball_pos.x`. →
  `audio.play_paddle_hit(ball_pos.x)`,
  `audio.play_rally_tier_accent(tier, ball_pos.x)`.
  - `has_method` 가드 유지(다른 audio 스텁 대비). 옵셔널 인자라 구버전 audio도 안전.
- **벽 바운스:** `wall_bounce_controller.gd:38-40` — `impact_pos` 보유. →
  `audio.play_wall_hit(impact_speed, impact_pos.x)`. **이게 이번 슬라이스에서
  source_x를 넘기는 유일한 wall_hit 경로다.**

> **⚠️ `play_wall_hit`는 "진짜 벽 바운스"보다 훨씬 넓게 쓰인다 (리뷰 ③).**
> `wall_hit_sfx`는 지형/장벽(홀리배리어·벽돌)/트램펄린/날씨/아이템 반사 fallback
> 등에서도 울린다(`ball_motion_event_processor.gd:63` 등, `ball_update_controller`,
> `mythic_item_audio_router`). **이들을 전부 위치 패닝하면 의도치 않은 좌우감이
> 생긴다.** 이번 범위는 "타격/벽 바운스만"이므로 **실제 impact 위치가 있는
> `wall_bounce_controller` 한 경로만 source_x를 넘기고, 나머지는 인자를 안 넘겨
> 전부 중앙(380) 기본값**으로 둔다. (`play_wall_hit`이 옵셔널 source_x를 갖는 한
> 이들은 코드 변경 없이 자동 중앙.)

### §4.4 ⚠️ 테스트 더블(fake audio) 갱신 — 리뷰 ②, 신규 갭

공개 함수에 옵셔널 인자를 더해도 **production 호출부가 인자를 넘기면
(`play_paddle_hit(ball_pos.x)`), 그 경로에 주입되는 fake가 0/1인자 함수면
런타임 에러**("too many arguments")가 난다. GDScript fake는 덕타이핑이라
실제 game_audio의 기본값과 무관하게 자기 시그니처대로 깨진다.

**전수 grep 결과 — 이 3개 메서드를 stub하는 fake (godot/tests):**

| 파일 | 메서드(현재) | 영향 |
|---|---|---|
| `paddle_bounce_rally_feedback_director_smoke.gd:63,66,75` | `play_paddle_hit()` ×2, `play_rally_tier_accent(tier)` | **확실히 깨짐** — 바꾸는 라우터 직접 구동 (must-fix) |
| `active_item_brick_wall_hit_runtime_smoke.gd:44` | `play_wall_hit(_impact_speed)` | 방어적 갱신(미변경 경로지만 미래대비) |
| `stage4_map_port_smoke.gd:139` | `play_wall_hit(_impact_speed := 0.0)` | 이미 옵셔널, 안전 |
| `lingpet_dragon_wing_skill_smoke.gd:39` · `lingpet_doll_curse_skill_smoke.gd:46` · `active_item_holy_barrier_dalji_whip_smoke.gd:33` | `play_wall_hit(_speed)` | 방어적 갱신 |
| `stage2_speed_defense_smoke.gd:31` · `stage3_psychoball_parity_smoke.gd:22` · `viper_jetpack_port_smoke.gd:59` · `chaos_spear_hit_release_smoke.gd:25` · `gamepad_vibration_feedback_smoke.gd:30` · `lingpet_soul_clone_skill_smoke.gd:40` · `viper_nerve_strike_port_smoke.gd:121` · `lingpet_egg_runtime_smoke.gd:396` | `play_paddle_hit()` | 미변경 경로면 안전, 방어적 갱신 권장 |

**규칙:** 이 3개 메서드를 stub하는 **모든 fake를 옵셔널 인자로 갱신** —
부작용 0(기본값), whack-a-mole 방지, S8 확장 때도 안 깨짐:
- `func play_paddle_hit(_source_x: float = 380.0) -> void:`
- `func play_rally_tier_accent(tier: int, _source_x: float = 380.0) -> void:`
- `func play_wall_hit(_impact_speed: float, _source_x: float = 380.0) -> void:`

`paddle_bounce_rally_feedback_director_smoke`의 FakeAudio는 더 나아가 `_source_x`를
**캡처**해 두면, S2 이후 "라우터가 ball_pos.x를 정확히 넘기는지" OUTCOME을
이 기존 스모크에서도 단언할 수 있다(선택, 권장).

---

## §5 슬라이스 단계

- **S1 — 백본(동작 변화 0).** create_positional(+`attenuation=0`) + 리스너 +
  `_play_with_pitch_at` + 타격 2개 노드 2D화 + 버스 분기 + 5개 내부 호출부 교체
  + **§4.4 fake 옵셔널 인자 갱신**. **X는 전부 기본 중앙.**
  → 게임 사운드는 이전과 **완전 동일**, 기존 스모크 전부 통과해야 함 (회귀 게이트).
- **S2 — X 배선.** 호출부 2곳(`paddle_bounce_rally_feedback_router`,
  `wall_bounce_controller`)에서 X 전달. director_smoke FakeAudio는 X 캡처+단언(선택).
  → 여기서 처음으로 패닝이 들림.
- **S3 — 튜닝 + 라이브 QA.** `HIT_PAN_STRENGTH` 인게임 청취 조절. 가장자리 타격이
  자연스럽게 살짝 쏠리는지, 중앙이 기존과 같은지, **가장자리/중앙 음량 동일**(리뷰 ④)인지,
  멀티볼 동시 타격이 각자 패닝되는지 확인.

---

## §6 트랩 브리프 (랜드마인)

1. **버스 누락 (조용함, 컴파일 안 잡힘).** `_apply_sfx_bus_to_players`의
   `is AudioStreamPlayer` 게이트가 2D를 건너뛰어 SFX 버스 미배정 → SFX 볼륨
   슬라이더가 타격음에 안 먹는다. **§6 스모크로 봉인.**
2. **타입 비호환 5+@곳 (컴파일이 잡음).** §2.2 표의 모든 지점을 한 번에 옮겨야
   에디터가 뜬다. 하나라도 빠지면 파스 에러.
3. **트램펄린 함수 동반 깨짐.** `play_trampoline_bounce/catch`도 wall_hit_sfx를
   쓰므로 헬퍼 교체 필수(범위 밖이지만 안 고치면 컴파일 에러).
4. **리스너 단일/현재성.** `make_current()` 필수, 동시에 하나만 current. 다른
   씬(메인메뉴/부트)이 자체 오디오를 만들지만 AudioListener2D는 전투 씬에만.
   전투 진입/이탈 시 리스너 생명주기 확인(owner_node 자식이라 씬과 함께 정리).
5. **거리 감쇠 (리뷰 ④).** `max_distance`만으론 원음량 미보장 → **`attenuation = 0.0`
   명시**가 주 레버. attenuation=0은 패닝(`panning_strength`)을 죽이지 않는다.
   `2d_panning_strength` 프로젝트 설정 부재 → 기본값 1.0 곱해짐(강도는 노드
   `HIT_PAN_STRENGTH`로만 조절). S3에서 가장자리 vs 중앙 음량 동일 확인.
6. **캔버스 변환 불확실성.** owner_node가 playfield 스케일 캔버스 아래인지에 따라
   절대 pan 곡선이 달라질 수 있다. 리스너+플레이어를 같은 부모/같은 좌표계에 두면
   **상대 오프셋은 일관**되므로 `HIT_PAN_STRENGTH`로만 흡수. 수식 고정 금지,
   인게임 튜닝.
7. **사운드는 픽셀 QA 아님.** 상태 스모크가 통과해도 "실제로 좌우로 들리는지"는
   라이브 청취로만 확정 (헤드폰/스테레오 스피커).
8. **테스트 더블 arity 깨짐 (리뷰 ②, 런타임 에러).** production 호출부가 X를 넘기는
   순간, 그 경로에 주입된 0/1인자 fake가 "too many arguments"로 죽는다. §4.4 표의
   fake를 **전부 옵셔널 인자로** 갱신(컴파일은 못 잡고 스모크 런타임에서 터짐).
   must-fix = `paddle_bounce_rally_feedback_director_smoke`.

---

## §7 스모크 스펙 — `game_audio_positional_pan_smoke.gd`

상태 단언(라이브 청취 전 회귀 봉인). FakeOwner를 owner_node로 setup 후:

- `_verify_hit_players_are_positional`: `paddle_hit_sfx`/`wall_hit_sfx`가
  `AudioStreamPlayer2D` 인스턴스.
- `_verify_hit_players_on_sfx_bus`: 두 플레이어 `.bus == "SFX"` (트랩 #1 봉인 —
  **반증검증:** 버스 분기 제거하면 이 단언이 FAIL해야 함).
- `_verify_listener_present_and_current`: AudioListener2D 자식 존재 + position.x≈380.
- `_verify_default_is_centered`: `play_paddle_hit()` 인자 없이 호출 후
  `paddle_hit_sfx.position.x == 380` (중앙 = 기존).
- `_verify_source_x_maps_to_position`: `play_paddle_hit(120.0)` 후
  `paddle_hit_sfx.position.x == 120`; `play_wall_hit(20.0, 700.0)` 후
  `wall_hit_sfx.position.x == 700` (배선 OUTCOME).
- `_verify_non_hit_players_unchanged`: 임의 비타격 플레이어(예 serve_sfx)는 여전히
  `AudioStreamPlayer` (블라스트 반경 봉인).
- `_verify_distance_attenuation_off`: `paddle_hit_sfx.attenuation == 0.0` (리뷰 ④,
  원음량 유지 봉인).
- (별도) **기존 `paddle_bounce_rally_feedback_director_smoke` 통과 유지**가 §4.4
  fake 갱신의 회귀 게이트 — S1 후 이 스모크가 깨지지 않아야 함.

실행: `run_smoke_tests.ps1 -Tests game_audio_positional_pan_smoke`
(SceneTree 스모크는 `_console.exe`; raw exe 위치인자=timeout — MEMORY 참고).

---

## §8 범위 밖 / 후속 / 대안

### §8.1 스킬·이펙트 확장 (후속 슬라이스)
- 스킬: `viper_skill_audio_router` 등 stateless `deps`-only 라우터 → 소유 런타임에서
  X를 한 단계 내려줘야 함. 백본(create_positional/리스너/`_play_with_pitch_at`)은 재사용.
- 이펙트: 벽돌파괴(impact_pos 보유) 쉬움 / 투척 폭발(모듈 상태) 중간 /
  `mythic_item_audio_router`(stateless) X 배선 필요.
- 확장 시 해당 플레이어만 추가로 2D화 + §2.2 타입 체크리스트 반복.

### §8.2 Arch B — 경량 대안 (단일 패닝 버스)
노드 타입 안 바꿈. `SFX` 자식으로 `SFX_PAN` 버스 + `AudioEffectPanner` 하나,
타격 2개 플레이어를 거기로 상시 라우팅, 재생 직전 `panner.set_pan((x-380)/380 * 강도)`.
- 장점: 타입 함정 전무, 변경 최소(~1시간).
- 단점: 동시 타격이 다른 X로 겹치면 **마지막 pan을 둘 다 공유**(아직 울리는 음이
  점프). 은은한 강도 + 짧은 타격음이라 대체로 가려지지만 깨끗하진 않음. 스킬/이펙트
  다수 독립 패닝으로 확장 불가.
- 권장: Arch A를 선호. 단 "최소 위험·hits-only"만 원하면 Arch B.

---

## 다음 단계
배선은 Codex/소유자, 리뷰는 Claude. S1(백본, 동작 변화 0) → S2(X 배선) →
S3(튜닝·라이브 청취) 순. 첫 PR은 S1+S2 묶고 §7 스모크 동봉 권장.
