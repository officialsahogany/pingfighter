# Claude Handoff: Teddy Bear AutoSprite Custom Front-Facing Walk Retry

아래 내용을 Claude에 전달하면 됩니다.

```text
이번 AutoSprite 재시도 목표는 명확하다:

- 이전 결과처럼 side-facing right-profile walk를 만들지 않는다
- "정면을 본 상태에서 옆으로 걷는" plush waddling walk motion block을 만든다

중요:
- `walk` 템플릿 기본 해석은 side-profile로 빠질 수 있으니 가능하면 `kind = custom`으로 진행
- 만약 UI나 MCP에서 direction / travel 방향을 넣어야 하면 `right`는 "이동 방향"으로만 사용하고, 몸/얼굴은 계속 정면이라고 프롬프트에 강하게 명시

참고 자산:
- `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`
- `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`

핵심 프롬프트는 아래 파일 그대로 사용:
- `d:\main\bosspong\.tmp\teddy_bear_walk_autosprite_custom_frontwalk_prompt_v2.txt`

실행 가이드:
1. AutoSprite에서 `walk` 기본 템플릿보다 `custom` 우선
2. 8-frame 4x2 motion block 생성
3. 결과 저장:
   - `.tmp/teddy_bear_walk_autosprite_motion_v2.png`
   - 가능하면 zoom / report도 같이
4. QA:
   - side-facing / 3/4면 즉시 reject
   - direct f1..f8 strip이 실제로 서로 다른 walk slot인지 확인
   - "같은 곰 8장"처럼 보이면 reject

질문에 대한 작업 원칙:
- 이번 재시도는 "정면 + 측면 이동" 가능 여부를 확인하는 실험이다
- AutoSprite가 또 side-profile로 빠지면, AutoSprite는 teddy walk에선 motion ideation 도구로도 부적합하다고 기록
- 통과하면 그 motion block만 FLUX에 넘긴다
```
