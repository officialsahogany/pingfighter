# 스테이지 3 변형 보스 draw transform 리셋 회귀 완료 보고

- 기준 HEAD: `aebbfb1b1`
- 격리 브랜치: `codex/stage3-variant-transform-reset-fix-aebb`
- 격리 워크트리: `D:\main\bosspong_perk_cluster_minimal2`
- 상태: S1~S3 완료, blocked 0, 본 트리 통합/푸시 없음
- 범위 밖인 스킬카드 아트는 변경하지 않았다.

## 결과

테디베어와 엘리스의 타원 드로우에서 `draw_set_transform`을 완전히 제거했다.
타원은 중심/반지름을 직접 반영한 정점 배열과 `draw_colored_polygon`으로 그리며,
`Geometry2D.triangulate_polygon`이 빈 결과를 내면 채우지 않는다. 따라서 상위
플레이필드 변환을 읽거나 복원할 필요가 없고 GRT-006을 지킨다. 선으로 원을
흉내 내지 않으므로 GRT-055의 line-cap 함정도 만들지 않았다.

구현 커밋은 다음 두 개로 분리했다.

1. `1029339cd` `fix(stage3): preserve playfield transform for variant bosses`
2. `2d6ba4310` `test(render): seal playfield transform retention by pixels`

## S2 identity reset 전수 조사

기준 HEAD에서 다음 명령으로 tracked `*.gd` 전체를 검색했다.

```powershell
git grep -n -F 'draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)' aebbfb1b1 -- '*.gd'
```

기준 HEAD 결과는 20개였다. 판정은 호출되는 즉시 드로우 패스의 소유자와
`BattleSceneDrawer`의 플레이필드 변환 경계를 따라 확인했다.

| 기준 HEAD 위치 | 개수 | 상위 플레이필드 변환 안에서 호출 | 판정 및 근거 |
|---|---:|---|---|
| `scripts/stages/stage3/stage3_variant_boss_renderer.gd:423` | 1 | 예 | **결함.** `BattleSceneDrawer`가 변환을 건 뒤 actor → Stage3 actor → variant renderer를 호출하고, 공은 그 뒤에 그린다. 이번 수정에서 제거했다. |
| `scripts/core/battle_scene_drawer.gd:165` | 1 | 변환 소유자 자신 | 안전. 전체 플레이필드 패스가 끝난 뒤 상위 소유자가 화면공간 HUD 전에 복원한다. |
| `scripts/core/stage_ball_spawn_intro_ball_renderer.gd:168` | 1 | 아니오 | 안전. `BattleSceneFrameController`가 battle scene 반환 후 별도 spawn overlay로 호출한다. battle scene 소유자의 복원이 이미 끝난 상태다. |
| `scripts/core/stage_landing_intro.gd:192,210` | 2 | 아니오 | 안전. 전체 화면 intro 분기가 직접 소유한 zoom/target 변환이며, 이 분기는 battle scene을 그리지 않고 반환한다. |
| `scripts/core/victory_highlight_renderer.gd:276` | 1 | 아니오 | 안전. `VictoryHighlightPlaybackState.ReplayDrawBridge`라는 별도 `Control`의 content 패스가 자기 변환을 복원한다. |
| `scripts/hud/angel_blessing_roll_overlay_host.gd:600,625` | 2 | 아니오 | 안전. 분리된 overlay draw bridge가 각각의 회전 변환을 소유한다. 다른 CanvasItem의 즉시 드로우 상태를 지우지 않는다. |
| `scripts/hud/pillar_orb_chrome_drawer.gd:63` | 1 | 아니오 | 안전. 화면공간 pillar HUD 패스에서 orb 자체 회전만 복원한다. 플레이필드 패스 전 또는 상위 복원 후에 호출된다. |
| `scripts/plaza/plaza_interior_object_renderer.gd:179` | 1 | 아니오 | 안전. `PlazaInteriorView`의 자체 `Control._draw()`에서 strewn object 회전을 소유한다. |
| `scripts/stages/stage1/stage1_han_miryang_prologue_overlay_host.gd:988` | 1 | 아니오 | 안전. 별도 전체 화면 `Control` 오버레이가 자기 변환을 소유한다. intro 분기는 battle scene 전에 반환한다. |
| `scripts/stages/stage1/stage1_pillar_layer_geometry.gd:69` | 1 | 아니오 | 안전. 참조 소비자는 Stage 1 pillar layer/cloud/tree/petal/butterfly 렌더러뿐이며 화면공간 pillar 패스에서 호출된다. |
| `scripts/stages/stage2/stage2_ambient_visual_renderer.gd:102` | 1 | 아니오 | 안전. Stage 2 pillar background 또는 pillar overlay 안에서 ambient sprite 변환을 복원한다. |
| `scripts/ui/character_live_preview.gd:1053,1667,1677` | 3 | 아니오 | 안전. 독립 `Control._draw()`가 타원/눈/텍스처 변환을 직접 소유한다. |
| `scripts/ui/stage_clear_result_box_draw_helper.gd:217,257` | 2 | 아니오 | 안전. 독립 `StageClearResultScene`의 `Control._draw()` 결과상자 패스다. battle scene 대신 이 화면을 그리고 반환한다. |
| `tools/stage2_arachne_live_round_qa.gd:149` | 1 | 아니오 | 안전한 테스트 전용 최상위 capture canvas 복원이다. |
| `tools/stage2_arachne_parity_visual_qa.gd:102` | 1 | 아니오 | 안전한 테스트 전용 최상위 capture canvas 복원이다. |

기준 판정 합계는 **결함 1 + 안전 19 = 20**이다. 수정 후 같은 전수검색은
21개다. 제품 결함 1개가 제거됐고, 공통 픽셀 씰 안에 아래 테스트 전용 2개가
추가됐다.

| 수정 후 추가 위치 | 판정 |
|---|---|
| `tests/playfield_draw_transform_retention_pixel_smoke.gd:66` | 강제 RED에서만 옛 결함을 재현하는 의도적 identity reset |
| `tests/playfield_draw_transform_retention_pixel_smoke.gd:72` | 테스트 최상위 소유자가 보스와 공까지 모두 그린 뒤 수행하는 정상 복원 |

따라서 수정 후 제품/도구에 남은 기존 19개는 모두 자기 화면공간 변환의
소유자이고, 플레이필드 자식 렌더러에 남은 identity reset은 0개다.

## S3 공통 픽셀 씰

`playfield_draw_transform_retention_pixel_smoke.gd`는 2020×1246 실제 레이아웃에
상위 플레이필드 변환을 적용하고 다음 네 레그를 같은 계약으로 캡처한다.

- Stage 3 테디베어
- Stage 3 엘리스
- Stage 3 환묘 연묘 형제 무손상
- Stage 2 몰왕 안전 구현 기준

보스 전 green sentinel과 보스/공 후 magenta sentinel의 화면 좌표를 함께 세어
전후 변환 유지도 픽셀로 확인한다. `EXPECTED_CAPTURE_LEG_COUNT = 4`가 manifest
증가 누락을 막으며, 씰은 CI와 pre-push의 두 리터럴 목록에 함께 등재했다.
헤드리스 CI/pre-push에서는 source/manifest 계약을 검사하고 픽셀 캡처는 명시적으로
skip한다. 실제 픽셀 합격/반증은 별도 windowed Vulkan 래퍼가 담당한다.

2020×1246 Vulkan/Forward Mobile, NVIDIA GeForce RTX 5070 최종 GREEN 결과:

| 레그 | 좌측 필러 전경 픽셀 | 플레이필드 보스 픽셀 | 플레이필드 공 픽셀 | 전 sentinel | 후 sentinel |
|---|---:|---:|---:|---:|---:|
| Stage 3 테디베어 | **0** | 17,375 | 7,988 | 322 | 323 |
| Stage 3 엘리스 | **0** | 16,611 | 7,988 | 322 | 323 |
| Stage 3 환묘 연묘 | **0** | 6,386 | 7,988 | 322 | 323 |
| Stage 2 몰왕 | **0** | 8,328 | 7,988 | 322 | 323 |

캡처는 격리 워크트리의
`godot/.godot/codex_artifacts/playfield_transform_retention/green_final/`에 남겼다.
네 GREEN 이미지는 플레이필드 안의 보스·공과 빈 좌측 필러를 픽셀로 확인했다.

강제 반증 레그는 보스 직전 옛 identity reset을 주입한다. GREEN 단언은 예상대로
비정상 종료했고 다음 시그니처를 냈다.

- 좌측 필러 누출: **12,292픽셀**
- 정상 플레이필드 보스/공 픽셀: 각각 **0/0**
- 전 sentinel: 322픽셀 유지
- 후 sentinel: 정상 위치 0픽셀, 원시 위치 156픽셀
- 래퍼 종단선: `Playfield transform retention counterproof: RED (expected)`

반증 로그는
`godot/.godot/codex_logs/playfield_transform_retention_33124_20260820132638148.log`에
보존했다.

## 최종 검증

| 게이트 | 결과 |
|---|---|
| 집중 스모크 5개 | `PASS=5 FAIL=0 TOTAL=5`, `All Godot smoke tests passed.`, `SCRIPT ERROR` 0건 |
| 수정 GDScript `-Paths` 경고 스캔 | 3개 검사, 경고 0건 |
| 헤드리스 로드 | `[ApplicationQuitCoordinator] graceful headless shutdown complete`, 통과 |
| 2020×1246 Vulkan 공통 픽셀 씰 | 4/4 GREEN, 좌측 필러 픽셀 각 0 |
| 강제 legacy reset 반증 | RED expected, 좌측 필러 12,292픽셀 |
| `git diff --check` | 통과 |
| blocked | 0 |

개발 중 잘못 적은 세 스모크 경로가 `File not found`를 낸 호출 1회가 있었으며,
실제 파일명을 `rg --files`로 확인한 뒤 위 최종 5개 경로로 재실행해 모두 통과했다.
이는 코드/기준선 실패가 아니다.

## 남은 확인 경계

사용자 본 트리의 실제 라이브 전투 확인은 지시대로 **unverified**다. 이 격리
브랜치는 통합하거나 푸시하지 않았으며, 본 트리에 랜딩된 뒤 사용자가 테디베어와
엘리스 전투를 직접 확인해야 한다.
