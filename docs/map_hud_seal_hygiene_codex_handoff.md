# 지시문 V3 — 착지분 잔여 수리 (드래그 회귀 P1 + 씰 위생)

- **발행**: 관제탑 2026-08-25. 기준 HEAD `e4a90dddd`. 락스텝 240/240.
- **격리 워크트리**: `D:\codex_tmp\bosspong_maphud_e4a9` (브랜치
  `codex/map-hud-seal-hygiene-20260825`).
- **금지**: 본 트리 편집·푸시·통합. 보고 후 대기.
- **배경**: U1·T2-후속·T3·R2 네 트랙을 **이미 통합했다**(`eb8a7edfa`
  R2 / `5a85fdc02` T2후속 / `6fdf0f612` U1 / `a797e987c`+`e4a90dddd` T3).
  기저 RED 2종은 GREEN으로 회복됐고 전 게이트 통과했다. 이 문서는
  그 착지분에 남은 결함을 다룬다.

---

## [P1] U1이 만든 드래그 회귀 — 재앵커가 동일 프레임 변위를 먹는다

**증상**: 노드 이동 전환(줌 램프가 도는 약 1.6초) 중에는 전체화면 지도를
드래그해도 **전혀 팬되지 않는다.** 줌 램프가 끝나면 회복되지만 그 동안
쌓인 변위는 버려진다. 휠을 굴린 적 있는 surface는 면제된다
(`has_manual_zoom`).

**기전**(폐형식으로 확정):
`tower_ascent_flow_renderer.gd:836`에서 읽은 라이브 `_manual`
(= `_press_camera_offset + displacement`)이 **`:852`에서 무조건 재대입**된다.
재대입 값 `reanchor_map_camera_manual_offset(...)`
(`tower_ascent_flow_runtime.gd:416~433`)의 반환은
`cursor_anchored_offset(view_center, previous_camera.offset, previous_zoom,
camera_render_multiplier)`뿐이고 **인자 어디에도 라이브 `_manual`이 없다.**
풀면 `O_N = view_center + (O_0 − view_center) · z_N / z_0` — 드래그 항이
항등적으로 0이다. 이어 `tower_ascent_map_drag_state.gd:102~112`의
`_press_camera_offset += R_N − _manual`이 다음 프레임 변위도 똑같이 폐기한다.

**왜 씰이 못 잡았나**: 카메라 씰 3레그 모두 **고정 progress에서만** 드래그한다.
`:246~291`은 press·motion·release를 끝낸 **뒤** progress를 전진시켜서,
신설 단언 "manual drag must preserve its released world anchor across
automatic zoom"이 현행 구현과 수리안 **양쪽 모두** 통과한다.

**수리**: `reanchor_map_camera_manual_offset`의 `old_offset` 인자에
**라이브 `manual_camera_offset`을 넘겨라.** 그러면
`R' = R_N + Δd · (z_N / z_{N−1})`가 되어 무입력 정상 상태의 월드 앵커 보존은
그대로이고 동일 프레임 변위만 살아남는다(배율 계수 ≈1.0006, 무해).
지시문 U1 항목 9는 "자동 줌이 바뀔 때마다 재적용"만 요구했지 동시 입력을
버리라고 하지 않았다.

**씰**: **드래그와 줌 변화가 겹치는 레그**를 추가하라 — press → motion →
progress 전진 → motion → release 순서로, 전진 도중에도 팬이 누적되는지
단언. 현행 구현에서 RED가 되는지 먼저 확인하라(반증 선행).

---

## [P2] R2가 만든 표시 회귀 — 4개 페이즈에서 스테일 보스 카드 레일

- `battle_scene_drawer.gd:549`의 억제를 ROUTE_AIM/MAP_OVERLAY로 좁힌 결과,
  **ENDING_CHOICE · RUN_SETTLEMENT · FAKE_ENDING_TEASER ·
  GAUNTLET_TRANSITION** 네 페이즈에서 좌측 필러에 **직전 전투의 보스 카드
  레일이 그대로 남아 보인다.**
- 이 네 페이즈는 `TowerAscentScreenSpaceSurfacePolicy.FLOW_PHASES`
  (MAP_OVERLAY/MAP_TRANSITION/NODE_MODAL)에 없어
  `draw_fullscreen_surface`를 타지 않고 760x750 게임좌표 안에서만 그려진다.
  **필러는 레터박스라 덮이지 않는다.** `draw_fullscreen_fade`도 전환 알파가
  0이면 아무것도 칠하지 않는다.
- ⚠관제탑 지시문(R2 작업 5번)이 "ROUTE_AIM/맵 오버레이"만 지목한 탓이다.
  세션 잘못이 아니다.
- 수리: 억제 조건을 **"불투명 스크린 패스가 필러를 덮는 페이즈"** 기준으로
  다시 유도하라. 위 4개 페이즈를 포함하되, 랠리 중에는 반드시 표시돼야
  한다. 씰에 4개 페이즈 각각의 음성 레그를 추가하라.

---

## [P2] T2-후속 씰이 심은 false-RED 지뢰 2종

3. **기록 캔버스 스텁 소실**: `tower_ascent_map_overlay_render_smoke.gd:24`
   `RecordingFullscreenMapCanvas`가 `draw_circle`/`draw_line`/
   `draw_texture_rect` no-op 오버라이드를 잃었다. 관통 경로에 정상적인
   네이티브 드로우를 **한 줄만 추가해도**
   `ERROR: Drawing is only allowed inside this node's _draw()`가 뜨고,
   러너의 심각 ERROR 게이트가 발동해 CI 등재 씰이 RED가 된다.
   제품은 완전히 정상인데 씰만 터진다.
   수리: no-op 오버라이드를 복원·확장하라 — `draw_circle`, `draw_line`,
   `draw_dashed_line`, `draw_multiline`, `draw_polyline`, `draw_texture`,
   `draw_texture_rect`, `draw_texture_rect_region`, `draw_polygon`,
   `draw_colored_polygon`, `draw_arc`, `draw_set_transform`,
   `draw_set_transform_matrix`. 각각
   `@warning_ignore("native_method_override")` 필요.
4. **footer 타입 의존**: 새 씰이 `_draw_fullscreen_map_footer(canvas: Object)`의
   완화에 구조적으로 의존한다. 그 헬퍼를 `CanvasItem`으로 좁히는 순간
   정적 디스패치가 네이티브로 가서 기록되지 않고 씰이 RED가 된다
   (스텁을 복원해도 해결 안 된다).
   수리: 관통 증거를 footer가 아니라 `_draw_fullscreen_map_model` **본문이
   직접 그리는 문자열**(`:1611` KEY_TITLE 조합 또는 `:1623`
   `flow.get_header_subtitle()`)로 옮겨라. 그러면 나중에 footer 타입을 조일
   수 있다.
5. **노드 라벨 오삭제 방어 소멸**: 픽스처 모델이 `"nodes": []`라
   `_draw_fullscreen_map_node`가 한 번도 호출되지 않는다. 대체 단언
   `guardian_spring_label == "수호의 샘터"`는 같은 파일 `:132~133`의 카탈로그
   루프와 **완전 중복**이라 방어력이 0이다. 지금은 그 함수의 라벨
   `draw_string`을 통째로 지워도 240개 씰이 전부 GREEN이다.
   수리: 픽스처에 **아이콘이 잡히지 않는 노드 1개**(kind="combat",
   boss_slot_id 없음, world_art_rect가 content_rect 안쪽)를 넣고 fallback
   라벨과 상태 라벨이 `drawn_strings`에 나타남을 단언하라. 3번의 스텁
   복원이 선행돼야 하고, 사본 소스 치환을 `_draw_fullscreen_map_node`의
   `canvas: CanvasItem`까지 확장해야 한다.

## [P3] 잔여

6. `tower_ascent_map_overlay_render_smoke.gd:147`의 `production_signature`가
   개행·탭 포함 정확 문자열 앵커다. 파라미터를 한 줄로 합치는 등 동작 무관한
   포맷 변경만으로 count==0 → 단언 실패 후 **early return이라 그 뒤 부재
   검사가 통째로 건너뛰어진다.** 정규식 앵커로 바꿔라.
7. **드로우 예산 여유 소진**: T3 밀도 상향으로 전체화면 지도 드로우 콜이
   1464 → **1523~1533**이 됐다(상한 `TEMP_MAP_PATH_DRAW_CALL_BUDGET = 1536`).
   여유가 3~13뿐이다. 초과 시 렌더러는 실패하지 않고 `dot_gap`을 넓혀
   **점선이 조용히 성겨진다**(`tower_ascent_flow_renderer.gd:1094`,
   `for _budget_attempt in range(4)`). 어떤 씰도 이를 보고하지 않고
   `map_overlay_render_smoke`는 시드 1개만 표본한다.
   수리: 다시드 스윕으로 **최악 시드의 총 드로우 콜과 최종 dot_gap을
   측정해 보고**하고, 예산을 올릴지 점선 밀도를 낮출지 판단 근거를 제시하라.
   (⚠GRT-043 봉인 예산 락스텝 — 상한을 올리려면 근거를 남길 것.)
8. R2 신규 씰의 공허 레그 2건:
   `stage1_boss_card_reencounter_prewarm_smoke.gd:400`의
   "카드 0장" 단언은 `card_rect_count`가 0으로 초기화된 뒤 한 번도 대입되지
   않아 **항진명제**다(`:401` 로그의 `card_rects=0`도 측정값이 아니라 리터럴).
   같은 파일 콜드 레그의 "must not cold-create" 단언 4건도 카운터를 켜지
   않은 데다 생산 드로우 경로가 애초에 `get_instance`를 타지 않아 실패
   불가능하다. 실측 레그로 바꿔라.

## 게이트·보고

지도·카메라 씰 8종(`map_camera_drag_contract`·`map_wheel_zoom_contract`·
`map_camera_tracking`·`fullscreen_map_cover_contract`·
`map_overlay_render`·`map_scroll_wiring_contract`·`12_floor_map`·
`floor_one_expansion_contract`) + `stage1_boss_card_reencounter_prewarm` +
`tower_route_screen_cleanup`을 한 배치로(+RED 반증) → `-Paths` 경고 →
헤드리스 로드 → `git diff --check` → **전환 중 드래그 픽셀 QA 1장**.
보고=워크트리·커밋 해시·씰 종단선 원문·7번 최악 시드 측정치·미해결.
