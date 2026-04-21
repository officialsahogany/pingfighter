# Claude Handoff: Teddy Bear Walk Gemini V4 Candidate Lock

아래 내용을 그대로 Claude에 전달하면 됩니다.

```text
이번 단계의 목적은 새 생성이 아니라 Teddy Bear Gemini walk 브랜치의 현재 상태를 정리하는 것이다.

판단:
- Gemini single-shot 브랜치에서 V4가 현재 best candidate다
- V5는 우측 응시는 고쳤지만 bow 위치 / safety pin / heart patch / motion이 무너져 reject
- 따라서 Gemini single-shot retake는 여기서 중단

결론:
- V4 = fast-mode best candidate
- Gemini single-shot branch = STOP

정리 규칙:
1. V4를 현재 best candidate로 명시
2. V5는 reject로 기록
3. 더 이상의 Gemini single-shot retake는 하지 않음
4. canonical overwrite 금지
5. 다음 선택지는 두 개뿐:
   - in-game candidate review
   - FLUX precise narrow touch-up

기록해야 할 핵심:
- V4 strengths:
  - front-facing lock nearly solved
  - identity preserved
  - same teddy species / props held
  - motion acceptable for fast-mode candidate
- V4 weakness:
  - slight rightward glance bias remains
- V5 reject reason:
  - pink gingham bow moved from head to neck
  - cream neck ribbon structure changed
  - safety pin drifted
  - motion flattened

파일 경로 note:
- if the saved V4 filename is already known in your workspace, record it explicitly
- if your actual V4 filename differs from the expected pattern, use the actual saved path
- expected naming if needed:
  `.tmp/teddy_bear_walk_gemini_frontwalk_v4.png`
  `.tmp/teddy_bear_walk_gemini_frontwalk_v4.jpeg`

출력:
- `.tmp/teddy_bear_walk_gemini_v4_candidate_lock_note.md`

The note should clearly say:
- V4 is the best fast-mode Gemini candidate so far
- Gemini retakes stop here
- next move is either gameplay candidate review or FLUX yaw-only precise touch-up
```
