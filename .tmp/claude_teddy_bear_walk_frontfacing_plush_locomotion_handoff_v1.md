# Claude Handoff: Teddy Bear Front-Facing Plush Locomotion Pivot (Gemini Fast Mode)

아래 내용을 그대로 Claude에 전달하면 됩니다.

```text
이번 Teddy Bear walk 브랜치는 방향을 바꾼다.

이전 실패 요약:
- "정면을 본 상태에서 옆으로 걷기"를 literal walk로 밀수록
  slight gaze bias / backward-stepping impression / identity drift가 반복됐다
- 특히 left travel에서 backward-walking read가 blocker였다

새 목표:
- literal side-step walk 대신
- FRONT-FACING plush locomotion cycle
- hop-step / bounce-step / waddling bob
- 즉, 정면 combat read를 유지한 채 곰인형다운 이동감을 주는 방식

중요:
- 이번은 fast mode다
- deep QA / frame expansion / FLUX touch-up으로 바로 내려가지 않는다
- 먼저 이 design pivot이 더 매력적인지 본다

Gemini prompt source:
- `d:\main\bosspong\.tmp\teddy_bear_walk_frontfacing_plush_locomotion_gemini_prompt_v6.txt`

Reference mindset only (Gemini input ref가 아니라 판단 기준):
- accepted redesign anchor language
- existing procedural teddy plush feel
- do NOT use previous rejected walk sheets as generation masters

실행 원칙:
1. Gemini 1차 생성
2. 정면 plush locomotion으로 더 자연스럽고 귀여운지 빠르게 판정
3. side-facing / backward-step read / same-pose repeat면 즉시 reject
4. 필요하면 text-only retake 최대 1회
5. 좋아 보이면 거기서 멈추고 Codex에 candidate로 넘김

빠른 ACCEPT 기준:
- 완전 정면 read 유지
- left/right travel을 떠올려도 backward-walking처럼 안 보임
- literal walk보다 plush hop-step / bounce-step 쪽으로 읽힘
- identity 유지
- 현재 V4보다 overall appeal이 좋음

출력:
- `.tmp/teddy_bear_walk_gemini_plush_locomotion_v1.png`
- `.tmp/teddy_bear_walk_gemini_plush_locomotion_v1.jpeg`
- optional:
  - `.tmp/teddy_bear_walk_gemini_plush_locomotion_v1_zoom.png`
  - `.tmp/teddy_bear_walk_gemini_plush_locomotion_v1_report.md`

결론은 짧게:
- ACCEPT for next-step candidate
또는
- REJECT and stop
```
