# 변형 보스 표시 이름 카탈로그 연결 수행 보고

작성일: 2026-08-21

## 1. 결과

요청 범위의 변형 보스 표시 이름 결함을 격리 브랜치에서 수정했다.

- 전광판, 패배 정산, 3층 기본 보스 스킬 HUD가
  `stage_boss_variant_catalog.gd`의 `get_entry()`와 `display_name`을 읽는다.
- 2층 `cheongringwi` / `molewang` / `arachne`, 3층 `yeonmyo` /
  `teddy_bear` / `alice`를 카탈로그 목록 자체를 순회해 단언한다.
- 스테이지 1은 기존 `stage1_boss_variant` 키와 변형 이름 표를 그대로 쓴다.
  `stage_boss_variant`와 합치지 않았다.
- 변형 카탈로그가 없는 스테이지 4부터 8까지는 각 소비자의 기존 폴백을
  그대로 유지한다.
- 7개 지원 로케일 모두에서 카탈로그의 모든 변형 이름이 한국어 원문으로
  폴백하지 않는지 자동 검사한다.
- blocked 0건이다. 본 트리 라이브 플레이 확인은 지시문에 따라 수행하지 않았고
  `unverified`로 남긴다.

## 2. 격리 경계와 커밋

| 항목 | 값 |
|---|---|
| 기준 HEAD | `f3f1683dffd479ceb3f06fe68c3c1b0faee6dc74` |
| 격리 워크트리 | `D:\main\bosspong_r4_s5_stageproof` |
| 격리 브랜치 | `codex/variant-boss-display-name-f3f168` |
| WIP 기준 보존 커밋 | `9c4a1627899ccab5837cc3b57f4b37a75a535c51` |
| 구현 커밋 | `ec061b24a` |
| 통합 / 푸시 | 수행하지 않음 |

`9c4a16278`은 본 트리에서 지목된 두 tracked WIP 파일과 Stage 3 분리 모듈만
정확 경로로 보존한 격리 검증용 기준 커밋이다. 통합 대상이 아니다. 실제 변경은
`ec061b24a` 한 커밋에 있다.

## 3. 수정 내용

### 3.1 전광판

`godot/scripts/hud/scoreboard_overlay_header_renderer.gd`는 스테이지 2와 3 행을
`BOSS_NAMES_BY_STAGE`에서 제거했다. 스테이지 1은 기존
`STAGE1_BOSS_NAMES_BY_VARIANT` 분기를 먼저 유지하고, 그 밖의 스테이지는
`StageBossVariantCatalog.get_entry(current_stage, stage_boss_variant)`의
`display_name`을 쓴 뒤 빈 경우에만 스테이지 4부터 8까지의 기존 표로 폴백한다.

### 3.2 패배 정산

`godot/scripts/core/defeat_settlement_screen.gd`는 owner의
`stage_boss_variant`를 스냅샷에 전달한다. 현재 도달 보스 이름은 카탈로그를 먼저
조회하고, 카탈로그에 없는 스테이지만 기존 `STAGE_BOSS_NAMES` 또는
`스테이지 N 보스` 표기를 쓴다. 이전에 클리어한 스테이지는 변형 이력을 보관하지
않으므로 기존 기본 이름 폴백을 유지했다.

### 3.3 3층 기본 보스 스킬 HUD

`godot/scripts/stages/stage3/stage3_boss_skill_hud_state_builder.gd`의 고정
`BOSS_NAME`을 제거했다. builder는 optional `stage_boss_variant`를 받아 Stage 3
카탈로그의 `display_name`을 반환한다. 인자를 주지 않는 기존 기본 호출은
`yeonmyo`를 유지한다.

### 3.4 다국어와 씰

`godot/scripts/core/language_settings_data.gd`에 아래 네 이름을 6개 비한국어
로케일에 추가했다. 한국어는 카탈로그의 `display_name` 자체가 정본이다.

| 한국어 | en | zh | ja | es | pt-BR | ru |
|---|---|---|---|---|---|---|
| 테디베어 | Teddy Bear | 泰迪熊 | テディベア | Oso de peluche | Urso de pelúcia | Плюшевый медведь |
| 엘리스 | Alice | 爱丽丝 | アリス | Alicia | Alice | Алиса |
| 두더지왕 | Mole King | 鼹鼠王 | モグラ王 | Rey Topo | Rei Toupeira | Король кротов |
| 아라크네 | Arachne | 阿拉克涅 | アラクネ | Aracne | Aracne | Арахна |

기존 `청린귀`와 `환묘 연묘`도 6개 비한국어 로케일에 이미 있었으며 새 씰이
이 둘을 포함한 카탈로그 전체를 검사한다.

신규 `godot/tests/variant_boss_display_name_smoke.gd`는 변형 id 목록을 다시
하드코딩하지 않고 `StageBossVariantCatalog.VARIANTS`를 순회한다. 따라서
카탈로그에 변형을 추가하면 다음 검사가 자동으로 늘어난다.

1. 전광판 이름
2. 패배 정산 현재 보스 이름
3. Stage 3 변형이면 기본 HUD builder 이름
4. 7개 로케일 번역 누락

스테이지 1의 세 변형과 스테이지 4부터 8까지의 기존 폴백은 별도 부정 레그로
봉인했다. focused CI와 pre-push 두 literal 목록은 각각 192개에서 193개가 됐고
집합 차이는 0개다.

## 4. 전수 조사

검색은 본 트리 WIP와 격리 결과에서 `BOSS_NAMES_BY_STAGE`,
`STAGE_BOSS_NAMES`, `BOSS_NAME`, `환묘 연묘`, `청린귀`를 각각 독립 실행하고,
추가로 네 변형 이름 리터럴도 각각 확인했다.

| 위치 | 판정 | 처리 |
|---|---|---|
| `scoreboard_overlay_header_renderer.gd`의 `BOSS_NAMES_BY_STAGE` | Stage 2와 3을 스테이지 번호로 고정한 실제 결함 | 카탈로그 선조회로 수정 |
| `defeat_settlement_screen.gd`의 `STAGE_BOSS_NAMES` | Stage 2와 3을 스테이지 번호로 고정한 실제 결함 | 카탈로그 선조회로 수정 |
| `stage3_boss_skill_hud_state_builder.gd`의 `BOSS_NAME` | 정본을 읽지 않는 고정 상수 | 제거하고 카탈로그 조회 |
| `serve_wait_indicator_renderer.gd`의 `STAGE_BOSS_NAMES` | Stage 1 `달지`만 보유하며 Stage 2와 3은 `Boss` 폴백이다. 이번 오표시 원인이 아니며 Stage 1은 별도 키 체계다 | 무변경, 후속 조사 후보로 보고 |
| Stage 6, 7, 8 state의 `BOSS_NAME` | 변형이 없는 스테이지별 단일 HUD owner | 무해, 종전 표기 유지 |
| `stage2_boss_skill_state.gd`의 `청린귀` | Stage 2 기본 state 전용. variant router가 두더지왕과 아라크네의 전용 state로 분기한다 | 현재 경로에서 올바름, 무변경 |
| `stage2_molewang_boss_state.gd`, `stage2_arachne_boss_state.gd`의 이름 | 변형별 state가 자기 HUD payload를 구성하며 현재 카탈로그와 일치 | 무변경 |
| `stage3_teddy_bear_boss_state.gd`, `stage3_alice_boss_state.gd`의 이름 | variant router가 전용 state로 분기하며 현재 카탈로그와 일치 | 무변경 |
| `tower_ascent_boss_registry.gd`의 6개 변형 이름 | 스테이지 번호 fallback이 아니라 변형별 슬롯 레지스트리이며 현재 카탈로그와 일치 | 무변경 |
| `common_skill_catalog.gd`, rage warning의 `청린귀` 포함 문구 | 보스 표제 이름이 아니라 무공명, 설명, 경고 카피 | 무해 |
| `language_settings_data.gd`의 이름 리터럴 | 번역 정본 | 누락 4종을 6개 비한국어 로케일에 추가 |

`serve_wait_indicator_renderer.gd`는 Stage 1의 `gaksi`와 `podo`를 구분하지 않는
잠재 표면이지만, Stage 2와 3의 잘못된 변형 이름을 노출하는 경로는 아니다.
또한 Stage 1은 `stage_boss_variant_catalog`의 소유 범위가 아니므로 이번 수정에
새 Stage 1 이름 표를 만들거나 두 호환 키를 합치지 않았다.

## 5. 폰크 / 퐁크 정본 판정

정본 표기는 **퐁크**다.

근거는 다음과 같다.

- 현재 변형 및 탑 보스 레지스트리의 Stage 4 `display_name`은 `퐁크`다.
- 전광판의 Stage 4 표기도 `퐁크`다.
- Stage 4 보스 전용 설계, 결과 화면 handoff, 런타임 trap 문서는 일관되게
  `퐁크`를 쓴다.
- `docs/hwangyeokjeon_codex_design.md`는 패배 정산의 `폰크`를 오탈자로 직접
  기록한다.

요청대로 이번 커밋에서는 패배 정산의 `폰크`를 고치지 않았다. 스테이지 4부터
8까지의 기존 표기를 바꾸지 않는 부정 레그도 이 차이를 그대로 봉인한다.

## 6. 검증

| 게이트 | 결과 |
|---|---|
| 집중 smoke | `PASS=1 FAIL=0 TOTAL=1`, `All Godot smoke tests passed.` |
| 반증 RED | 전광판 catalog 결과를 고정 stage 표로 임시 토글하자 6변형과 Stage 2, 3 기본값 레그가 실패. in-place 원복 후 GREEN 재확인 |
| touched-file warning scan | 5 scripts, 경고 0건 |
| headless load | `Godot headless load check passed.` |
| focused 목록 lockstep | CI 193, pre-push 193, delta 0 |
| `git diff --check` | 구현 커밋 범위 통과 |
| Vulkan capture | 2020x1246, Forward Mobile Vulkan, RTX 5070, 12장, `SCRIPT ERROR` / `ERROR:` 0건 |
| 본 트리 라이브 플레이 | 지시문에 따라 미수행, `unverified` |

Vulkan 캡처 위치:

`godot/.godot/codex_captures/variant_boss_display_name/`

전광판 6장과 패배 정산 6장을 직접 열어 확인했다. 테디베어, 엘리스,
두더지왕, 아라크네, 환묘 연묘, 청린귀가 모두 2020x1246 프레임에 올바르게
표시됐고 잘림은 없었다.

| 파일 | SHA-256 |
|---|---|
| `scoreboard_teddy_bear.png` | `C3827752C31A4D3A1E4F678D1D83648AD5C285919CBD284753E24910D3FDE7CD` |
| `scoreboard_alice.png` | `24AE690F21189A60A2363FD01C95CF2EF914FF4609748BE68A25359C74F86820` |
| `scoreboard_molewang.png` | `38681A75F4F5F6B306B62C483EBF5C621A15012BD1A4101E5A09BE52ECB2D797` |
| `scoreboard_arachne.png` | `4C5B4314F9839F6D6425FC43F5B6514BFC643F9BDB5A09D69A42FA1078263581` |
| `scoreboard_yeonmyo.png` | `F4CD1EFE4E2F4B43C2F2B69854D6A131680D5C3AB3981FE7351ED038D073C8B9` |
| `scoreboard_cheongringwi.png` | `CDA65EE8645134783D1C8D732E5DF5478B801676C589C45E481596B054C66940` |
| `defeat_teddy_bear.png` | `AC9AE32BE7841879694335E473C250BC70A8BC11FE59B14CE0723C40A7113A97` |
| `defeat_alice.png` | `40990A6538C7DB95D48C637ADF649CD65693A0A551EA138F660BA780C3C06EC9` |
| `defeat_molewang.png` | `2BA739844ABDFBDECD484893EA43730FAB01687262744920DCB0E2FD6F279771` |
| `defeat_arachne.png` | `C6B3F19E1CE3407A1A5E0D41C03605F51D7C15AB44550790F028274F943B50A4` |
| `defeat_yeonmyo.png` | `48FAC87AADC6B2A365251653FF6F6C6EF1573C03D205308C999169D0DC526BFD` |
| `defeat_cheongringwi.png` | `AD20B259B3B3CACEE63990F47D1366BB6E4AFFD4416B47A750CDD1AD4509E2FC` |

Vulkan 로그:

- 경로: `godot/.godot/codex_logs/variant_boss_display_name_visual_qa_52664_20260820163437737.log`
- SHA-256: `091C6BF8D24F466F1810AD6923A2EAFD27CB6155523ABE97A9E74600CCC54A55`
- 오류 카운트: 0

## 7. 통합 대기

본 트리에는 통합하지 않았고 push도 하지 않았다. 통합 시에는 WIP 기준 보존
커밋 `9c4a16278`이 아니라 구현 커밋 `ec061b24a`만 검토해야 한다. 본 트리의
대상 WIP가 안정화된 뒤 사용자가 직접 라이브 전투와 패배 정산을 확인하는 것이
남은 수동 게이트다.
