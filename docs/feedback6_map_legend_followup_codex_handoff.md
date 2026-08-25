# 지시문 T2-후속 — 공허 GREEN 씰 · 요청하지 않은 시그니처 완화 되돌리기

- **발행**: 관제탑 2026-08-25. 기준 HEAD `8ae319ce7`(T2 착지 완료).
- **격리 워크트리**: `D:\codex_tmp\bosspong_legendfix_8ae3` (브랜치
  `codex/fb6-map-legend-followup-20260825`).
- **금지**: 본 트리 편집·푸시·통합. 보고 후 대기.
- **선행 판정**: T2 본체는 **이미 통합했다**(`8ae319ce7`). 사용자 요구는
  충족됐다 — 라이브 오너(`_draw_fullscreen_map_model` 말미 legend_rect +
  `draw_rect` ×2 + `draw_string`)와 죽은 형제(`_draw_map_overlay_legend`
  + 호출)가 통째로 제거됐고, 캡처 하단에 문구도 금테 띠도 없다.
  형제 보존도 GREEN이다(`KEY_NODE_*` 생존, route_serve_smoke의
  "수호의 샘터" 단언 통과, node_modal_localization 미접촉, scroll_wiring의
  `draw_set_transform` 짝 성립). **이 문서는 잔여 위생만 다룬다.**

## [P1] F1 — 새 부재 씰이 제거 지점을 한 줄도 실행하지 않는다 (공허 GREEN)

- `tests/tower_ascent_map_overlay_render_smoke.gd:157` 부근의
  `drawn_strings` 레그(`:165~172`)는 `debug_draw_fullscreen_map_footer`와
  `debug_draw_fullscreen_map_node` **둘만** 호출한다. 전자는
  `KEY_CLOSE_HINT` 한 줄만 그리는 새 추출 헬퍼이고 후자는 노드 하나만
  그린다. **범례가 있던 자리를 실행하지 않는다.**
- 저장소 전수 grep 결과 `_draw_fullscreen_map_model`을 fake canvas로
  구동하는 테스트는 **0건**이고, 생산 호출자는 renderer `:529` 하나뿐이다.
- 결과: 누군가 `_draw_fullscreen_map_model` 본문에
  `canvas.draw_string(font, ..., "전투 · 광폭화 · …", ...)`를 리터럴로
  다시 넣어도 이 씰은 GREEN을 유지한다. 회귀 방어가 없다.
- 수리: 부재 단언이 **`_draw_fullscreen_map_model`을 실제로 관통**하게
  하라. 기록 canvas를 주입해 그 함수를 통째로 돌리고, 결과
  `drawn_strings`에 범례 문자열이 0건임을 단언하라. 같은 레그에서
  노드 라벨 형제가 **여전히 존재**함을 함께 단언해 오삭제 방어를 유지할 것.
- **RED 반증 필수**: 리터럴로 범례를 되살린 픽스처에서 이 단언이
  실제로 실패하는지 확인하라. ⚠종전 보고의 RED 반증이 리터럴 복원인지
  `KEY_LEGEND_TYPES` 복원인지 불명이다. 후자라면 그 RED는 파싱 실패였을
  뿐 부재 단언의 힘을 증명하지 못한다. **리터럴 복원으로 반증하라.**

## [P2] F2 — 요청하지 않은 생산 시그니처 완화를 되돌려라

`850afed9f`는 지시문에 없는 생산 구조 변경 3건을 넣었다.

1. `tower_ascent_flow_renderer.gd:1647` `_draw_fullscreen_map_footer` 추출
   — 동작 불변을 관제탑이 부모 본문 직독으로 확인했다. **유지해도 된다.**
2. ★`:2095` `_draw_fullscreen_map_node`의 `canvas`를 `CanvasItem`에서
   **`Object`로 완화** — **되돌려라.** 이 113줄 드로우 함수 안의
   `draw_circle`/`draw_texture_rect`/`draw_line`/`draw_string` 호출이
   더는 파서 검증을 받지 않는다. 앞으로 오타나 인자수 오류를 넣으면
   파싱·경고 스캔·헤드리스 로드를 전부 통과한 뒤 MAP_OVERLAY 프레임이
   실제로 그려질 때만 `Invalid call`로 터진다(GRT-048 덕타이핑 트랩과
   같은 구조). 게다가 이 완화의 명분이던 씰이 F1대로 제거 지점을
   관통하지 못하므로 **비용만 치르고 얻은 것이 없다.**
   - F1을 제대로 고치면 기록 canvas는 `CanvasItem`을 상속한 스텁으로
     만들 수 있다. 타입을 좁힌 채로 씰을 세워라.
3. `:5507`/`:5511` `debug_draw_*` 훅 2개 — 파일 관례(`debug_draw_route_aim`
   등)와 일치하므로 유지해도 된다. 다만 F1 수리 후에도 쓰이지 않으면
   정리하라.

## [P3] 잔여 2건

4. **문서 문장 오류**: `docs/tower_map_overlay_report.md:34`에 새로 쓴
   "각 노드의 종류·상태 표기는 유지하되 하단 범례 띠는 표시하지 않는다"가
   실제와 다르다. 라이브 전체화면 지도의 모든 노드는 아이콘을 갖고 있고
   `tower_ascent_map_iconography.gd:55`가 아이콘이 잡히면 `fallback_label`을
   빈 문자열로 만들므로 **종류 라벨은 0건**이다(캡처 4배 확대 확인).
   상태 라벨도 current/vanished/locked/completed가 아니면 빈 문자열이다.
   문서만 보고 라벨 회귀를 판정하면 오진한다.
5. **형제 보존 레그의 경로 불일치**: `:173` 레그가 통과하는 이유는
   픽스처 노드가 `boss_slot_id`/standin 없이 `kind="combat"`만 줘서
   텍스처 해석에 실패하고 폴백 분기로 떨어지기 때문이다. 단언 문구
   "preserve fullscreen node-label fallback text"가 서술하는 경로를
   라이브는 쓰지 않는다. 문구를 실제 경로에 맞게 고치거나, 라벨 카탈로그
   문자열 자체를 단언하는 형태로 바꿔라(`guardian_spring_label`이
   `node_kind_label("guardian_spring")`로 계산되므로 카탈로그가 바뀌면
   깨지긴 한다 — 그 성질은 보존할 것).

## 게이트·보고

포커스드 스모크(+**리터럴 복원 RED 반증**) → `-Paths` 경고 →
헤드리스 로드 → `git diff --check` → 캡처.
보고=워크트리·커밋 해시·씰 종단선 원문·RED 반증이 리터럴 복원이었음을
명시·캡처 경로·미해결.
