# Claude Handoff: Teddy Bear Front-Facing Walk via Gemini (Fast Mode)

아래 내용을 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 Teddy Bear walk를 Gemini로 빠르게 다시 뽑는 fast-mode 브랜치다.

핵심 목표:
- "정면을 본 상태에서 옆으로 걷는" 8프레임 4x2 walk sheet
- 테디 identity는 redesign anchor와 같은 계열
- 이번 단계에서는 deep QA / frame expansion / runtime 작업으로 바로 내려가지 않는다
- 먼저 한 장이 정말 좋아 보이는지 빠르게 판정한다

참고 기준 자산 (비교용, Gemini input ref 아님):
- `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`
- `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`

Gemini prompt source:
- `d:\main\bosspong\.tmp\teddy_bear_walk_frontfacing_gemini_prompt_v1.txt`

실행 원칙:
1. Gemini로 1차 생성
2. side-facing / 3/4 / same-pose repeat / generic mascot이면 즉시 reject
3. 필요한 경우 text-only retry는 최대 1회만
4. 괜찮으면 거기서 멈추고 Codex에 보여줄 결과만 정리
5. 아직 items/ canonical overwrite 금지

출력 경로:
- `.tmp/teddy_bear_walk_gemini_frontwalk_v1.png`
- `.tmp/teddy_bear_walk_gemini_frontwalk_v1.jpeg`
- optional:
  - `.tmp/teddy_bear_walk_gemini_frontwalk_v1_zoom.png`
  - `.tmp/teddy_bear_walk_gemini_frontwalk_v1_report.md`

빠른 판정 기준:
- 정말 front-facing인가?
- direct 8-frame sheet가 같은 자세 반복처럼 보이지 않는가?
- plush waddling walk가 읽히는가?
- Gemini single-shot인데도 현재 FLUX teddy walk보다 더 매력적인가?

결론은 짧게:
- ACCEPT for next-step candidate
또는
- REJECT and stop

이번 브랜치에서는 over-analysis하지 말고, "좋다 / 별로다"를 빠르게 가른다.
```
