# Claude Handoff: Teddy Bear Front-Facing Walk Gemini V5 Retake

아래 내용을 그대로 Claude에 전달하면 됩니다.

```text
이번 재시도는 새 브랜치가 아니라 v4 보정이다.

목표:
- v4의 장점은 유지
- "살짝 우측을 바라보는 느낌"만 제거
- 시선 / 머리 / 주둥이 / 가슴을 완전 정면으로 교정

현재 판단:
- v4는 front-facing walk와 identity 복원은 거의 성공
- 하지만 stable walk에서 약간 screen-right glance가 남아 있음
- 이번엔 그 한 포인트만 보정하는 fast retake다

Gemini prompt source:
- `d:\main\bosspong\.tmp\teddy_bear_walk_frontfacing_gemini_prompt_v5.txt`

실행 원칙:
1. v4의 성공 요소를 유지
2. rightward glance / head yaw / eye aim만 제거
3. 새 drift가 생기면 즉시 reject
4. 이번에도 deep QA로 내려가지 말고 빠르게 ACCEPT / REJECT 판정

빠른 판정 기준:
- 여전히 완전 front-facing인가?
- 우측 시선 기울기가 사라졌는가?
- dangling eye / bow / heart / safety pin / black paw bow가 유지되는가?
- v4보다 좋아졌는가?

출력 경로:
- `.tmp/teddy_bear_walk_gemini_frontwalk_v5.png`
- `.tmp/teddy_bear_walk_gemini_frontwalk_v5.jpeg`
- optional:
  - `.tmp/teddy_bear_walk_gemini_frontwalk_v5_zoom.png`
  - `.tmp/teddy_bear_walk_gemini_frontwalk_v5_report.md`

결론은 짧게:
- ACCEPT for next-step candidate
또는
- REJECT and stop
```
