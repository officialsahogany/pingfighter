# 두더지왕 스킬 패리티 r2 완료 보고

## 결론

- 기준 HEAD `f3f1683dffd479ceb3f06fe68c3c1b0faee6dc74`에서 격리 브랜치 `codex/molewang-skill-parity-r2-f3f168`로 작업했다.
- 보고서 작성 직전 구현·검증 HEAD는 `17f96e6bde6f18d28f976dad8de198f6f8af23ce`이다. 보고서 자체는 후속 문서 커밋으로 분리한다.
- 회전발톱 공식은 바꾸지 않았다. 실제 생산 공 컨텍스트와 최종 프레임 스냅샷을 실측해 좌측 `+1`, 우측 `-1`이 최종 소비 결과로 남는 것을 확인했다.
- 원본 `sounds/clue.wav`를 그대로 승격하고 원본 선형 볼륨 `0.5`를 적용했다. 임의 대체음은 제거했다.
- 친구 두더지는 정확한 4점 해금을 보존하고 72 Hz 물리틱 기준 720틱 지속, 2880틱 재사용 주기로 개편했다.
- 땅굴 습격 생산 코드는 변경하지 않았다. 499 게이지 부정 레그와 500 게이지 발동 레그가 모두 GREEN이다.
- 차단 항목은 0건이다. 본 트리 통합·푸시·라이브 청음은 수행하지 않았다.

## 하나. 회전발톱 방향

### 원인 판정

제시된 소비 누락 가설은 과거에는 유효했지만, 기준 HEAD에는 이미 `c6c481c3468be317b6f8d9cb9f6c986512301141 fix(stage2): restore Molewang claw ball effect`가 포함되어 있었다. 현재 생산 경로는 다음과 같이 방향을 보존한다.

1. `stage2_molewang_boss_state.gd`가 `ball_spin_direction`을 반환한다.
2. `paddle_bounce_boss_post_hit_handler.gd`가 Stage 2 결과의 방향을 결과 딕셔너리에 복사한다.
3. `paddle_bounce_post_hit_handler.gd`와 `paddle_bounce_frame_state.gd`가 이를 최종 프레임 스냅샷까지 전달한다.
4. 실제 owner에서 `BallUpdateContext.build_update_context(owner)`를 호출해 만든 컨텍스트를 사용했다.

실측값은 다음과 같다.

```text
boss_paddle_width=124.0
ball_size=32.0
final_spin_left=1
final_spin_right=-1
```

두 크기 값은 0이 아니므로 왼쪽 모서리를 중심으로 오인하는 경로도 아니다. 공 중심과 보스 중심의 비교 공식은 원본과 동일한 채로 유지했다. Stage 2 비두더지왕 및 Stage 1·3·4가 공유 후처리기에서 방향을 물려받지 않는 부정 레그도 통과했다.

## 둘. 회전발톱 사운드

- `GameAudio.play_stage2_molewang_spinning_claw()`는 실제로 존재하며 `_play_with_pitch()`로 등록 플레이어를 재생한다.
- 원본 `sounds/clue.wav`를 `res://assets/sounds/clue.wav`로 그대로 승격했다.
- 원본과 승격 파일의 SHA-256은 모두 `2BAB14AC0B1579A85458B5102ECE436A100FB52738E3D86526B9AD184F251C9C`이고 크기는 352,880 bytes이다.
- 선형 볼륨 `0.5`를 정확히 보존하기 위해 `-6.020599913279624 dB`를 사용했다.
- import 메타데이터의 `edit/loop_mode=0`으로 단발음 계약을 확인했다.
- 생산 `AudioStream` 로드, 덕타이핑 메서드 존재, 정확한 플레이어 전달, 피치 정책 `0.97..1.04`를 스파이 테스트로 검증했다.

실제 사용자 청음은 목표 문서 지시에 따라 본 트리 라이브 확인 항목으로 남겼다. 자동 검증은 호출·스트림·볼륨·단발음 경로까지만 단언한다.

## 셋. 친구 두더지 지속 구조

`project.godot`의 물리틱은 72 Hz이다.

- 10초 지속: `72 * 10 = 720` 물리틱
- 40초 재사용 주기: `72 * 40 = 2880` 물리틱
- 쿨다운은 발동 시 시작하므로 발동 시작에서 다음 발동 시작까지 정확히 2880개의 유효 물리틱이다. 720틱 지속 종료 뒤에는 2160틱이 남는다.
- 기존 4점 해금 조건문은 그대로 유지했다. 4점 미만에는 해금되지 않는다.

다섯 필수 레그는 모두 생산 상태로 검증했다.

1. 4점 미만: 미해금
2. 정확히 4점: 다음 라운드에 해금되고 첫 유효 물리틱에 발동
3. 719틱까지 활성, 720번째 유효 물리틱 뒤 종료
4. 주기 2879틱까지 재발동 불가
5. 2880번째 유효 물리틱에 재발동

### 경계 정책

| 경계 | 정책 | 근거 |
|---|---|---|
| 득점 | 활성 창을 즉시 끝내고 두더지·파티클을 제거하되 해금과 남은 쿨다운은 보존 | 득점 뒤 논리 가시성만 꺼진 detached 액터/FX가 다음 상태에 남지 않게 한다. |
| 라운드 리셋 | 활성 액터·파티클을 제거하고 해금·쿨다운은 보존; 4점 pending을 해금 상태로 승격 | 라운드 경계가 쿨다운 우회나 재해금을 만들지 않게 한다. |
| 서브 대기/공 비활성 | 지속·쿨다운을 모두 정지하고 새 발동도 금지 | 플레이가 진행되지 않는 구간을 물리틱 시간으로 소비하지 않는다. |
| 첫 유효 물리틱 | 해금 상태이며 쿨다운이 0이면 발동 | 서브 대기 중 조기 발동을 막으면서 재개 시 결정적으로 시작한다. |
| 전체 매치 리셋 | 해금·타이머·액터·파티클 전부 초기화 | 새 매치로 이전 상태가 누출되지 않게 한다. |

## 땅굴 습격 무손상 씰

- 생산 상수 `TUNNEL_COST := 500.0`, `TUNNEL_COOLDOWN_SEC := 8.0`은 변경하지 않았다.
- 게이지 499에서는 상태가 `charging`이고 이동·오디오 부작용이 없다.
- 게이지 500에서는 기존 스케줄러로 `tunnel_warn`가 발동한다.
- 이번 방향/친구 두더지 변경은 땅굴 습격의 게이지 획득·소비·쿨다운을 바꾸지 않으므로 체감 발동 빈도에도 새 변화가 없다.

## 검증 결과

- 집중 스모크 배치: `PASS=3 FAIL=0 TOTAL=3`, 종단 문구 `All Godot smoke tests passed.`
  - `stage2_molewang_boss_port_smoke.gd`
  - `stage2_arachne_boss_port_smoke.gd`
  - `variant_boss_ball_path_snapshot_smoke.gd`
- touched GDScript 경고 스캔: 4/4, 경고 0건
- 헤드리스 로드: `[ApplicationQuitCoordinator] graceful headless shutdown complete`, PASS
- `git diff --check`: PASS
- Vulkan/Forward Mobile, NVIDIA GeForce RTX 5070, 2020x1246 캡처: 4/4 PASS
  - 좌측 최종 `+1`: `11F2E0244F4BCECAC1C1A8DF0859C2BF11AE9DB24A3545C98C074E2E1349C0E8`
  - 우측 최종 `-1`: `821DE6E084FCDC5C5A445B108CBF5739B152244285561A3BC30D1077510FA0CA`
  - 친구 두더지 활성: `D997EEA69F523A8838A1F7AEB7288F843117FD0064D2FE02192848CF6EF49BE4`
  - 720틱 종료 후 무잔상: `748B37CE6A6C3340FE61E845C22F32D6AF9D097326E745C9B5D6958A4226EC40`
- 증거 백업: `D:\main\bosspong_molewang_r2_evidence_f3f168_20260821`

첫 격리 스모크는 새 워크트리의 import 캐시에 폰트가 없어 실패했다. 격리 프로젝트의 캐시를 물질화한 뒤 동일 스모크가 통과했으므로 제품 실패와 분리했다. `clue.wav` 대상 reimport 때 기존 `skill_cutin1.wav`/`power_smash.wav` 중복 UID 경고가 한 번 기록됐지만, 대상 reimport는 완료됐고 최종 집중 경고·스모크·헤드리스 검증은 모두 통과했다.

## 구현·검증 분리 커밋

1. `9f4d405e1` `fix(stage2): restore Molewang claw source cue seal`
2. `92335a089` `chore(stage2): track Molewang clue import metadata`
3. `46abc30e7` `feat(stage2): time friend moles in physics ticks`
4. `17f96e6bd` `test(stage2): capture Molewang parity r2 Vulkan seals`

본 트리에 통합하거나 푸시하지 않았다. 사용자 라이브 방향 확인과 실제 청음은 `unverified`이며, 통합 지시를 기다린다.
