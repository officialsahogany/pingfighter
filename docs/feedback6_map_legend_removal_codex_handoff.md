# 지시문 T2 — 지도 하단 범례 띠 제거

- **발행**: 관제탑 2026-08-25. 기준 HEAD `e1c6c886d`. CI/pre-push 락스텝 237.
- **격리 워크트리**: `D:\codex_tmp\bosspong_maplegend_e1c6` (브랜치
  `codex/fb6-map-legend-removal-20260825`). T1·T3와 파일 무겹침 — 병렬 가능.
- **금지**: 본 트리 편집·푸시·통합. 보고 후 대기.

## 사용자 요구

> 지도 하단에 전투, 광폭화, 상점, 수련장, 파계승, 수호의 샘터, 휴식 같은
> 문구는 없애기.

## 실측 (관제탑 프로브)

- **라이브 오너는 단 한 곳**: `godot/scripts/tower_ascent/tower_ascent_flow_renderer.gd:1653~1669`
  (`_draw_fullscreen_map_model` 말미). MAP_OVERLAY는 스크린스페이스 정책
  (`tower_ascent_screen_space_surface_policy.gd:3`)이라
  `battle_scene_drawer.gd:429~449`의 `draw_fullscreen_surface` 경로로만
  그려지고, 그 경로가 renderer 532 → 513 → 1455로 이어진다.
- 문구는 **노드 종류 순회 조립이 아니라 통짜 하드코딩 리터럴**이다.
  `tower_ascent_map_overlay_localization.gd:48` `KEY_LEGEND_TYPES`.
  같은 파일 `:54~63`의 `NODE_KIND_KEYS`는 개별 노드 라벨 전용이며 범례
  생성에 관여하지 않는다.
- ★**문구만 지우면 빈 띠가 남는다.** `:1659` `draw_rect(legend_rect,
  Color(PAPER_DEEP, 0.7), true)`와 `:1660` `draw_rect(legend_rect, GOLD,
  false, 1.0)`이 문구와 독립된 별도 호출이다. `:1653`의 `legend_rect`
  선언까지 지우지 않으면 `UNUSED_VARIABLE` 경고로 경고 스캔이 RED가 된다.
- **레이아웃·히트테스트 영향 없음**: `content_rect`는 `:922`에서
  `TEMP_MAP_CONTENT_*_RATIO`로 독립 산출되고, 히트테스트(`:1407`
  `resolve_fullscreen_node_id_at_screen_position`)는 카메라/월드 좌표
  기반이라 범례 rect를 참조하지 않는다.
- **이 범례를 단언하는 씰은 0건이다.** ⚠단 아래 두 개는 혼동 주의:
  - `tests/tower_ascent_map_overlay_render_smoke.gd:91`의
    `["전투","광폭화",...,"휴식"]` 루프는 그래프 모델 노드의
    `node_kind_label()` 결과를 단언할 뿐 범례 문자열을 읽지 않는다.
  - `:102~119` `_verify_localization_catalog`의 required_keys에 LEGEND 키는
    없고, 등록 키 **개수** 단언도 없다(`has()`만 본다).

## 작업

1. **라이브 블록 제거**: `tower_ascent_flow_renderer.gd:1653~1669` 전체를
   삭제한다. `legend_rect` 선언·`draw_rect` 2회·`draw_string` 1회를 통째로.
2. **죽은 형제 은퇴**: `:3311` `_draw_map_overlay_legend(canvas)`는
   프로덕션 도달 불가다. 유일 호출자는 `:2238`
   `_draw_map_surface(canvas, flow, true)`이고 그 유일 진입은 `:497`
   `phase_name == "MAP_OVERLAY"` 분기인데, 그 경로로 가는
   `flow_owner.draw(canvas)`(`battle_scene_drawer.gd:255`)는
   `uses_playfield_flow_phase`가 참일 때만 실행되어 MAP_OVERLAY에서는
   **절대 호출되지 않는다**. 1번을 하면 이 함수가 유일한 소비자가 되므로,
   **도달 불가를 스스로 재확인한 뒤** 함수와 그 호출을 함께 제거하라.
   재확인에 실패하면 2번을 건너뛰고 보고하라(1번만으로도 요구는 충족된다).
3. **문자열·상수 정리**: 2번을 수행했다면 `KEY_LEGEND_TYPES`(`:24` 선언,
   `:48` 값)와 `KEY_LEGEND_STATES`(`:49`)를 제거하고,
   `TEMP_MAP_OVERLAY_LEGEND_Y` 상수도 소비자가 사라졌는지 확인 후 정리하라.
   ⚠**`KEY_NODE_*` 상수는 절대 지우지 마라** —
   `tests/tower_ascent_route_serve_smoke.gd:923`이 노드 라벨
   `"수호의 샘터"`를 단언하고 있고, 그것은 `_draw_fullscreen_map_node`의
   `fallback_label`(renderer `:2183~2197`) 경로다.
   `tower_ascent_node_modal_localization.gd`의 동명 문구도 별개 카탈로그이니
   보존하라.
4. **문서 드리프트**: `docs/tower_map_overlay_report.md:34`("하단 범례를
   제공한다"), `:82`(`TEMP_MAP_OVERLAY_LEGEND_Y` 표 행), `:106`("잠금·범례가
   프레임 안에 있고")를 현행에 맞게 갱신하라.

## 씰

- 기존 락스텝 GREEN 유지 필수: `tower_ascent_map_overlay_render_smoke`
  (pre-push `:117` / CI `:113`), `tower_map_scroll_wiring_contract_smoke`
  (`:141` / `:137`), `tower_ascent_route_serve_smoke`.
  ⚠`tower_map_scroll_wiring_contract_smoke:526~533`이 같은 파일의
  `draw_set_transform` **짝 개수**를 소스 텍스트로 센다. 범례 블록에는
  transform 호출이 없으므로 안전하지만, 편집 중 다른 transform 호출을
  건드리지 마라. 같은 씰 `:534~537`은 edges 루프와
  `_draw_fullscreen_floor_guides` 순서만 검사한다.
- **부재 레그 추가**: 전체화면 지도 렌더 결과의 `drawn_strings`에
  `"전투 · 광폭화"`로 시작하는 범례 문자열이 **0건**임을 단언.
  동시에 노드 라벨 `"수호의 샘터"`는 **여전히 존재**함을 같은 레그에서
  단언해 형제 오삭제를 막아라.
- **RED 반증**: 범례 블록을 되살린 픽스처에서 위 부재 단언이 실패할 것.
- **픽셀 QA**: 전체화면 지도 캡처 1장. 하단에 문구도 **띠도** 없어야 한다.
  `tools/tower_ascent_map_overlay_visual_qa.gd`는 베이스라인 비교 로직이
  없는 캡처 전용 툴이라 새 캡처만 달라진다.

## 게이트·보고

포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 캡처. 보고=워크트리·커밋 해시·씰 종단선 원문·
2번 수행 여부와 도달불가 재확인 근거·캡처 경로·미해결.
