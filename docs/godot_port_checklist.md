# Godot Port Integration Checklist

Current implementation target: Godot **환격전**. Preserve established
PingFighter / DiskHearts / Ringpia identifiers as compatibility IDs unless an
explicit migration task owns them.

## Ball-Owning / `skip_ball_motion_step` Collision Checklist

Any Godot feature that owns the ball, hides it, freezes it, teleports it, or
manually advances it with `skip_ball_motion_step = true` must audit collision
preservation, not only cleanup.

- [ ] List which normal ball-loop paths are skipped while the feature owns the
      ball: `BallMotionCollisionDetector`, paddle bounce, wall bounce, score
      checks, stage collision hooks, active-item collision context, and
      character collision context.
- [ ] Decide explicitly whether player / boss paddle contact is allowed while
      `skip_ball_motion_step` is true. If it is disallowed, document why the
      ball cannot visibly overlap a paddle during the owned phase.
- [ ] Decide explicitly whether the owned-ball trajectory should live-track a
      moving target or lock its landing / plunge target at activation time. For
      locked trajectories, add a smoke test that moves the target after
      activation and verifies the ball keeps steering toward the original
      target instead of following the current target.
- [ ] If paddle contact is allowed, provide a release / bounce path that either
      reuses the normal paddle collision path or mirrors its important context:
      `hitbox_padding`, `player_collision_cooldown`, mirror / clone rects,
      dash / jetpack / warp / stopwatch recovery context, and any expanded
      paddle hitbox.
- [ ] Add focused smoke coverage for all three contact shapes before sign-off:
      descending overlap, horizontal slide / hover at the paddle Y-band, and
      upward overlap after a freeze / recovery / capture phase. Each test must
      verify that the skill releases ownership, clears `skip_ball_motion_step`,
      and resumes with a real ball velocity.
- [ ] Verify both release cleanup and boundary cleanup. Round end, result,
      stage leave, score events, explicit cancel, and paddle-hit release must
      all clear the same owned-ball state through one cleanup path or a clearly
      equivalent helper.
- [ ] Run the focused owner smoke together with any precedent smoke that covers
      the same failure class, for example stopwatch paddle passthrough,
      post-recovery collision, chaos-spear hit release, or the touched stage /
      skill smoke.

현재 실개발 대상은 Godot 버전 **환격전**이다. 원본
Python/Pygame PingFighter는 개발이 중단되었으며, 앞으로는 포팅할 때만
참고자료로 사용한다.

이 문서는 Python 원본 핑파이터에서 Godot으로 기능(아이템, 스킬, 보스,
UI, VFX, 오디오 등)을 옮기거나, 기존 Godot 구현을 원본과 비교할 때 모든
AI 에이전트(Codex, Claude, Manus 등)가 확인해야 하는 통합 체크리스트다.

단순히 런타임 로직을 번역하는 것만으로는 포팅이 완료되지 않는다. Godot
프로젝트의 아키텍처(모듈 레지스트리, 오버레이 프레임 컨트롤러, 모달
게이트, 오디오 정리, 리소스 경로 등)에 맞게 모든 연결 고리를 확인해야
한다.

## 0. 개발 대상 경계

- [ ] 수정 대상이 `godot/` 안에 있는지 확인한다.
- [ ] `pingfighter.py`와 원본 Python 모듈은 behavior reference로만 읽는다.
- [ ] 사용자가 명시적으로 원본 수정을 요청하지 않았다면 Python 런타임
      파일을 고치지 않는다.
- [ ] 현재 Godot 아키텍처의 소유 모듈을 먼저 찾는다. 없으면 가장 작은
      안정적인 모듈 경계를 만들고 `docs/godot_port_architecture.md`에
      기록한다.

## 1. 시그니처 및 의존성 검증

AI 에이전트는 종종 있을 법한 메서드명이나 시그니처를 추측한다. 호출
전에 실제 코드에서 존재 여부와 인자 구성을 확인한다.

- [ ] `registry.get_instance("...")`로 가져온 모듈의 실제 파일을 읽고
      호출할 메서드가 존재하는지 확인한다.
- [ ] `has_method()` 같은 가드가 조용한 실패를 숨기지 않는지 확인한다.
- [ ] 호출 인자 개수와 타입이 실제 선언과 맞는지 확인한다.
- [ ] 반환값 타입과 실패 시 동작을 확인한다.

- [ ] When a Python reference call is wrapped in broad `try/except` or points
      through a module alias, verify the callee exists in the imported live
      module and is actually rendered / updated before porting it as a visible
      Godot effect. Treat missing callees as dormant dead-calls unless the
      design explicitly asks to revive the intended effect.

## 2. 모달 / 시네마틱 / 전투 루프 연결

- [ ] 모달 또는 시네마틱 상태가 `battle_scene_modal_gate_controller.gd`의
      전투 물리 / 모바일 입력 차단 경로에 연결되어 있는지 확인한다.
- [ ] 매 프레임 갱신이 필요한 상태는 overlay frame controller의 update
      경로에 연결한다.
- [ ] 그려야 하는 상태는 overlay draw 경로에 연결한다.
- [ ] 확인 / 취소 / 스킵 입력이 필요한 상태는 overlay input controller에
      연결한다.
- [ ] 라운드 종료, 득점, 서브 대기, 재시작, 게임 리셋에서 상태와 VFX /
      loop audio가 정리되는지 확인한다.

## 3. 카탈로그 / 라우터 / 디버그 등록

- [ ] 관련 카탈로그(`active_item_catalog.gd`, `runtime_perk_catalog.gd`,
      `mythic_item_catalog.gd` 등)에 등록한다.
- [ ] effect id, icon path, rarity, character restriction, cooldown, cost,
      tooltip text 같은 메타데이터를 실제 렌더러가 읽는 경로에 등록한다.
- [ ] effect router 또는 owner module에 실행 분기를 연결한다.
- [ ] F2/F3/F9 같은 현재 Godot 디버그 메뉴에 필요한 항목을 추가한다.
- [ ] save/load/reset 경로에 소유 상태와 장착 상태를 분리해서 연결한다.

## 4. UI / 텍스트 / 오디오 / VFX

- [ ] visible Godot UI 텍스트는 한국어를 기본값으로 쓴다. 원본
      `localization/ko.json`이나 Python 표시 문자열은 참고자료로만 사용한다.
- [ ] 원본에 있던 사용음, 피격음, 루프음, 만료음, 취소음을 Godot 오디오
      소유자에 맞게 연결한다. 의도적으로 무음이면 이유를 남긴다.
- [ ] 보이는 gameplay VFX는 Python draw 코드 복사가 아니라 Godot-native
      layering, texture, shader, particles, tween / AnimationPlayer를 기본값으로
      삼는다.
- [ ] detached FX host는 논리 상태가 꺼질 때 직접 숨기거나 해제한다.

## 5. Runtime Performance Lifecycle

- [ ] Classify the feature cost before sign-off: per-frame, first-use,
      stage-entry, transition-time, or offline asset-prep work.
- [ ] Do not run heavyweight preparation inside hot `_draw()` / `_process()`
      paths. Avoid runtime `Image.get_image()`, alpha scans, atlas slicing,
      image compositing, `ImageTexture.create_from_image()`, large cache
      builds, large texture/JSON loads, or scene-wide node scans on the first
      visible battle frame.
- [ ] If a cache is needed, choose an explicit safe path: offline baked
      metadata/assets, owner-module prewarm, staged loading work spread across
      multiple frames, or a documented low-cost lazy path.
- [ ] Treat asset prewarm and runtime node / host prewarm as separate
      surfaces. Loading textures, shaders, materials, or sprite sheets is not
      enough for Node-backed VFX, HUD, overlay, result, or tooltip work. If the
      feature creates `Node2D`, `Sprite2D`, `ColorRect`, `GPUParticles2D`, or
      another detached host, expose a `prewarm_runtime_nodes()` /
      `prewarm_runtime_nodes_step(owner)` path, build the hidden child nodes
      during staged boot / transition work, and verify the host remains hidden
      and inactive after prewarm.
- [ ] Audit the first live `sync_*_fx()` / `sync_*_host()` frame separately
      from steady-state draw. A deferred `add_child()` host can be valid enough
      to build state but still return `is_inside_tree() == false`, causing the
      expensive canvas fallback to draw in the same frame. Pre-create the host
      before the visible state, or document why the fallback is intentionally
      cheap and cannot double the first-frame cost.
- [ ] For controller-driven loading, result, overlay, HUD, and detached FX
      hosts, keep the host's own `_process()` disabled unless it truly owns
      independent timing. Sync animation state from the owner/controller path
      and turn processing off again when inactive or hidden.
- [ ] For new stages, stage transitions, result scenes, HUD layers, item
      effects, character skills, boss actions, and gameplay VFX, inspect the
      focused `BattlePerf` hot path or add a smoke / micro-benchmark that
      covers first-entry, transition, and steady-state behavior separately.
- [ ] If `BattlePerf` reports high `draw calls`, `prims`, first-frame max
      values, `process_nodes outside_shell`, or `physics_nodes outside_shell`,
      resolve or document the accepted budget before claiming the feature is
      done.
- [ ] Read `BattlePerf` max spikes before averages. Low `avg` with a high
      `max` on labels such as `draw.scene.playfield`, `draw.frame.overlay`,
      `character_info.tooltip`, `viper.skill.*`, result callbacks, or
      scoreboard callbacks can still indicate a first-use / transition hitch.
      Treat `n=1..4` render-heavy samples as useful evidence, not noise, until
      the open / transition frame has been explained.
- [ ] Measure overlay / modal / tooltip open-frame cost separately from normal
      HUD draw. Character info, perk grids, skill tooltips, result panels, and
      scoreboard overlays may be cheap while closed but expensive on the first
      hover/open frame.
- [ ] For LOD or render-budget changes, verify the real state matrix rather
      than a single idle frame: selected character, airborne / grounded /
      thrust / glide state, hit-confirm or post-hit state, non-owner character
      fallback, and the relevant stage-specific HUD / playfield layer.

## 6. 통합 스모크 테스트

- [ ] repo-local Godot load check를 실행한다:
      `cd godot; .\tools\run_headless_load_check.ps1`
- [ ] Godot `.gd` 파일을 수정했다면 warning scan을 실행한다:
      `cd godot; .\tools\run_warning_scan.ps1`
- [ ] touched feature에 focused smoke test가 있으면 실행한다.
- [ ] 헤드리스 검사만으로 부족한 visible UI / VFX / animation 변경은 실제
      화면 확인 또는 스크린샷 검증을 추가한다.
- [ ] 검사를 실행하지 못했다면 최종 handoff에 이유를 명시한다.

## 7. 완료 기준

포팅 완료는 "동작한다"가 아니라 다음을 만족하는 상태다.

- [ ] 원본 Python은 필요한 만큼만 읽었고 수정하지 않았다.
- [ ] Godot 소유 모듈, 카탈로그, 라우터, UI, 오디오, VFX, 저장/리셋 경로가
      모두 연결되어 있다.
- [ ] round-boundary cleanup과 reset cleanup이 확인되었다.
- [ ] Godot load check와 warning scan 결과가 확인되었다.
- [ ] 남은 차이가 있다면 의도적 차이인지, 후속 작업인지 기록했다.
