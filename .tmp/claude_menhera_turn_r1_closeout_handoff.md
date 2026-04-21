# Claude Handoff Prompt: Menhera Turn R1 Close-Out

아래 프롬프트를 그대로 Claude에게 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl turn의 asset-side close-out 패스다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따르고
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행해줘
- 이번 패스에서는 새로운 생성 실험을 하지 않는다
- V5 같은 추가 narrow pass도 하지 않는다
- runtime integration / code change는 하지 않는다

결정 사항:
- R1 accepted
- canonical walk = sole identity anchor
- turn V3 = runtime playback auxiliary sheet only
- turn V3 is NON-ANCHOR

이번 패스의 목적:
1. 현재 asset-side 결정을 문서/산출물 기준으로 깔끔하게 고정
2. runtime migration 전에 필요한 asset-side 메모를 정리
3. 이후 작업자가 turn V3를 regen anchor로 잘못 재사용하지 못하게 guardrail을 명확히 남김

해야 할 일:

1. Asset-side final status note 정리
- `turn V3`가 왜 shipping/runtime accept 대상인지
- 왜 canonical identity anchor는 아닌지
- 왜 cap side-accent drift는 cosmetic runtime divergence로만 허용되는지
- future regen에선 canonical walk only 규칙을 다시 명시

2. Runtime handoff note 검토
- runtime migration은 Codex 소관임을 명확히 적어라
- 4x2 loader 전환 전까지는:
  - `items/menhera_boss_turn.png` 기존 자산 유지
  - `RENDER_TURN_FRAMES = False`
  - hop-only fallback 유지

3. Backup / rollback note 정리
- 기존 8x1 turn asset을 rollback backup으로 유지해야 한다는 점
- 새 V3 계열 4x2 시트는 runtime migration + local playback QA 전까지는 `.tmp` 또는 staging candidate 상태라는 점

4. Optional asset-side checklist only
- frame order documentation 확인
- V3 source / stitched sheet / jpeg / nukki png / gameplay QA render 경로 정리
- future worker가 찾아보기 쉽게 경로 목록만 짧게 남김

이번 패스에서 하지 말 것:
- 새 FLUX pass
- 새 AutoSprite pass
- V3를 canonical anchor라고 표현
- attack/dash/victory/defeat regen 기준으로 turn V3를 올리는 문구
- code 수정

최종 보고 형식:
1. asset-side close-out에서 남긴 결정 문서 / note 파일 경로
2. canonical walk only 규칙이 어디에 기록됐는지
3. runtime migration 전에 Codex가 해야 할 일 요약
4. asset-side에서 더 이상 할 테스트가 없는지 여부

핵심 문구:
- canonical walk = sole identity anchor
- turn V3 = runtime playback auxiliary sheet
- non-anchor
- no more generation passes for this branch
```
