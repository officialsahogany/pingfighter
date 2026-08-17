# 승천탑 페이즈 D 완료 보고서

- 기준 지시문: `docs/tower_ascent_phase_d_goal.md` (`04d8de98d1a97070cd02badb08ac38c077797020`)
  - 전달문에 적힌 `04dde98d`는 저장소에 없는 전치 오타였고, 실제 지시문 커밋 `04d8de98d`를 확인해 사용했다.
- 정본: `docs/tower_ascent_run_map_plan.md` v1.5
- 페이즈 D 착수 HEAD: `ebca72ca89ffadbcf7753ca17fa7f755e05f60c2`
- Godot: `4.6.2.stable.official.71f334935`
- 푸시: 하지 않음
- 판정: **GREEN — 항목 1~7 구현·검증, 필수 게이트 blocked 0건 / unverified 0건**

## 1. 커밋 목록

| 항목 | 커밋 | 상태 | 구현 요약 |
|---:|---|---|---|
| 1 | `00413058a` | fixed | `tower_ascent_record_store`에 최고 층·클리어 횟수·가짜/진엔딩·무패 훈장과 예약 리그 슬롯을 분리 영속화했다. |
| 2 | `1fa3f9510` | fixed | 9층 첫 클리어 판정을 결산보다 먼저 커밋하고 가짜 엔딩 티저를 1회 봉인했으며 판정·연출 상태를 스냅샷에 넣었다. |
| 3 | `841951bbf` | fixed | 재클리어에서 하산/더 오르기 물리차단 모달을 열고 더 오르기 선택에만 10~12층 잠금을 비가역 해제했다. |
| 4 | `bb1eff48b` | fixed | 클리어·패배 공용 런 결산을 신설해 유실 빌드 아래에 도감 신규 발견과 영속 기록을 표시하고 미정 해금 재화 슬롯은 만들지 않았다. |
| 5 | `4eae78e51` | fixed | 11층 4천왕 대역 4종을 한 노드의 `encounter_index` 연전으로 연결하고 내부 리셋·동일 대전 재도전·최종 상자 1개 계약을 봉인했다. |
| 6 | `4e1da4244` | fixed | 12층 진엔딩 기록과 `run_defeat_count == 0` 무패 훈장 판정, 진엔딩 전용 결산 변형을 연결했다. |
| 7 | 이 보고서를 포함하는 항목 7 커밋 (`feat(tower): 페이즈 D Vulkan 6장과 완료 보고 봉인`) | fixed | 실제 생산 플레이필드 드로어를 쓰는 Vulkan 6장 캡처 도구·래퍼·계약 스모크와 본 보고서를 함께 봉인한다. |

항목 1~6은 위 순서의 독립 로컬 커밋이다. 항목 7은 보고서가 자기 커밋 해시를 내용 안에 재귀적으로 고정할 수 없으므로 커밋 제목과 `HEAD` 위치로 식별한다. `git log --reverse ebca72ca8..HEAD`에서 7개 항목 순서를 확인할 수 있다. 공유 WIP 파일인 `battle_scene_match_flow_driver.gd`, `battle_scene_shell.gd`, `stage_clear_result_reward_plan_builder.gd`는 페이즈 D에서 수정하거나 스테이징하지 않았다.

## 2. 게이트 결과

### 2.1 최종 종단선

- 페이즈 A·B·C·D의 모든 `tower_ascent*_smoke.gd` 30종 + 주요 기존 소비자 8종: `PASS=38 FAIL=0 TOTAL=38`.
- 필수 종단선: `All Godot smoke tests passed.`
- 페이즈 D 변경 GDScript 집중 경고 스캔: `20/20`, 경고 0건.
- 헤드리스 로드: `Godot headless load check passed.`
- Vulkan 실캡처: NVIDIA GeForce RTX 5070, Vulkan Forward Mobile, `captures=6`, `ok`, exit 0.
- 플레이 중 정책: 사용자 게임 PID 31688을 종료하지 않았고 모든 래퍼가 `-AllowDuringPlay`, BelowNormal 검증, 고유 로그, `finally` 우선순위 복구 계약으로 실행됐다.
- 신규 GDScript UID: `15/15` 동반, `15/15` 고유, 누락 0건.

최종 스모크의 기존 소비자 8종은 `stage_clear_result_reward_plan_builder_smoke`, `stage_clear_reward_resolver_smoke`, `runtime_perk_starpoint_collection_flow_smoke`, `active_item_field_spawn_scheduler_smoke`, `active_item_field_spawn_queue_smoke`, `plaza_shop_stock_smoke`, `plaza_gacha_menu_smoke`, `match_flow_driver_applier_deps_smoke`다. 플래그 OFF의 점수 비례 상자·광장 보석·스타포인트 즉시 선택 경로는 `tower_ascent_phase_a_off_path_smoke`와 이 소비자 묶음으로 무손상을 재확인했다.

최종 출력 로그는 저장소 밖 `D:\codex_tmp\tower_ascent_phase_d_final_20260817`에 보존했다.

| 로그 | SHA-256 |
|---|---|
| `smoke_38.log` | `E56D1B730F6212ECB718092F39BA944ABBEE3A8179AF054B9730254B1D626D75` |
| `warning_20.log` | `785A728E6A5DF61FAD4F96B189D4DF76B9FBC80E4D5E2EB0B39EBEEC22FDE85E` |
| `headless.log` | `6DEC872B6BFF96FBE13592D299917798F6B4C124B4E32212619D7C1BA5C43277` |
| `vulkan_6.log` | `82EBA52DE919B71630EFAA897AE1FE179AB0050EB062BCC98CF3FC13AEE39C41` |

### 2.2 항목별 핵심 반증

- 항목 1: 빈 파일 기본값, 손상/미래 스키마 fail-closed, 즉시 저장 실패 롤백, 이벤트 멱등성, 게임 재시작 후 기록 유지를 검증했다.
- 항목 2: 첫 클리어에는 선택 모달이 뜨지 않고 티저만 1회 표시되며, 크래시 복구·판정 재호출이 클리어 횟수를 중복 증가시키지 않음을 검증했다.
- 항목 3: 하산은 10~12층을 잠긴 채 결산으로 보내고, 더 오르기만 잠금을 해제하며, 반대 선택 재호출을 거부하고 GRT-058 일시정지·재개·안전 장전을 검증했다.
- 항목 4: 유실 빌드가 영속 소득보다 먼저 조립되고, 도감 신규 발견·최고 층·클리어 기록이 병기되며, 해금 재화 키/슬롯이 없고, 보석 0 패배가 레거시 결산으로 새지 않음을 검증했다.
- 항목 5: 첫 3승의 리셋 계획은 액티브 쿨다운 초기화, 신화 스테이지 미증가, 필드 아이템·무공·초식·FX 유지, 회복 없음, 중간 상자 0개를 단언한다. 패배와 크래시 복구는 현재 `encounter_index`를 유지하고, 네 번째 승리만 최고 위험 플래그의 상자 1개를 만든다.
- 항목 6: 9층 계속 선택과 11층 완주 전에는 12층 진엔딩을 거부한다. 보석 재도전으로 런을 이어도 패배 횟수 1이면 훈장을 주지 않고, 패배 0이면 훈장을 즉시 영속하며 재호출은 클리어 횟수를 중복 증가시키지 않는다.
- 항목 7: 도구가 실제 `BattlePlayfieldSceneDrawer`를 사용하고, Headless/비Vulkan을 fail-closed하며, 6개 파일명과 760×750 크기를 계약 스모크로 고정했다.

## 3. `TEMP_PHASE_D_*` 상수 목록

**신설 0개.** 페이즈 D는 미정 수치를 사용하지 않았다. 4천왕 수 4, 9/11/12층, 상자 수 1은 정본의 확정 구조 계약이며 튜닝값으로 재정의하지 않았다. 4천왕 상대는 페이즈 B의 기존 슬롯과 대역만 사용했고 신규 명칭·킷·아트·확률을 발명하지 않았다.

## 4. 로컬라이제이션 키와 번역 공백

한국어 정본 키 23개를 세 카탈로그에 등재했다.

- 엔딩 8개: `tower_ascent.ending.fake_teaser.*` 3개, `tower_ascent.ending.choice.*` 5개.
- 결산 11개: `tower_ascent.settlement.clear.*`, `.defeat.*`, `.true_ending.*`, `.lost_build.*`, `.persistent_income.*`, `.prompt`.
- 연전 전환 4개: `tower_ascent.gauntlet.transition.*`.

번역 공백은 영어(`en`), 중국어(`zh`), 일본어(`ja`), 스페인어(`es`), 브라질 포르투갈어(`pt-BR`), 러시아어(`ru`)의 위 23개 키다. 한국어 fallback으로 fail-safe하며, 비한국어 번역은 콘텐츠/로컬라이제이션 후속 트랙으로 넘긴다. 한국어 표면 문구에는 엠대시·엔대시를 쓰지 않았다.

## 5. Vulkan 캡처 6장과 육안 검수

공통 경로: `godot/.godot/codex_captures/tower_ascent_phase_d/` (검증 산출물이므로 Git 비추적).

| 파일 | 상태 | SHA-256 | 육안 판정 |
|---|---|---|---|
| `01_fake_ending_teaser.png` | 760×750 | `F24A363470B9308F2621F73701373BFB77A5A70DE21F057352384820D7A6D892` | GREEN — 가짜 끝 제목, 왕의 시련 티저, 확인 문구가 중앙 패널 안에서 선명하다. |
| `02_reclear_choice.png` | 760×750 | `533E5240E8DFF2693FAF16FCB050289570C947C1234F75FC45D1D6A2F38368D5` | GREEN — 하산/더 오르기 2택과 비가역 경고가 겹침 없이 분리된다. |
| `03_clear_settlement.png` | 760×750 | `55C71153D735BF181347BCC3DB1108DFD4D3B51998D0906D583116F682147703` | GREEN — 유실 빌드 위, 영속 기록 아래의 위계와 9층 클리어 변형이 읽힌다. |
| `04_defeat_settlement.png` | 760×750 | `E660790A13E0611EC85E8F5B75541416AC75F8917BBF411036FE43B9526B1F87` | GREEN — 패배 문구와 최고 8층·클리어 0회 기록이 명확하고 해금 재화 슬롯이 없다. |
| `05_gauntlet_transition.png` | 760×750 | `29EAF09A75F82B1E6138AB08591E15C896CDEC198BE865C76EF1B3C9B47A21E7` | GREEN — 1→2번째 대전, 대역 이름, 회복·중간 상자 없음이 한 화면에서 읽힌다. |
| `06_true_ending_settlement.png` | 760×750 | `21B124384B385B42143EA9A22FFF76FE3D59DA76207ADD084C90E5CD91D593BD` | GREEN — 진엔딩 제목·12층·클리어 2회·무패 훈장이 표준 결산과 구분된다. |

## 6. fixed / deferred / blocked / unverified

### fixed

- §1의 7항목 전부.
- 기록·판정·결산·연전·진엔딩 상태의 멱등성과 스냅샷 복구.
- GRT-058 모달 생명주기, 플래그 OFF 무손상, Vulkan 가시 게이트.
- 지시문 기준 커밋 전치 오타를 실제 저장소 커밋으로 해소.

### deferred

- 페이즈 E: 레거시 은퇴, 광장 철거, 오퍼 게이트 은퇴, 플래그 승격과 현재 안정 API의 최종 라이브 진행 라우팅.
- 신규 콘텐츠: 9층 보스, 4천왕 4종, 12층 보스의 실제 킷·아트·도감 표면. 현재는 정본대로 페이즈 B 대역만 쓴다.
- 리그 상세 설계, 해금 재화, 진엔딩 시간 목표, 수치 밸런스, 비한국어 6개 언어 번역.
- 최종 지도 화풍 아트. 이번 캡처는 정본이 허용한 placeholder 검증판이다.

### blocked

- 없음.

### unverified

- 없음. 위 deferred 항목은 정본이 명시한 비범위이며 페이즈 D 완료 게이트가 아니다.

## 7. 다음 트랙 인계

1. 페이즈 E는 `TowerAscentFlowOwner`의 `begin_floor_nine_resolution`, `resolve_gauntlet_victory`, `begin_floor_twelve_true_ending`, 공용 `resolve_defeat`/결산 API를 최종 라이브 진행 라우터에 연결한 뒤 레거시·플래그를 은퇴한다.
2. 11층 라이브 소비자는 각 중간 승리에서 `resolve_gauntlet_victory`를 전리품보다 먼저 호출하고, 반환된 노드 내부 리셋 계획을 기존 `reset_for_continue` 계열 소비자에 연결한다. 마지막 승리에서만 `final_chest.context`로 상자 1개를 연다.
3. 보스 콘텐츠 트랙은 `floor_09_fake_ending`, `floor_11_king_01..04`, `floor_12_true_ending` 대역만 교체하며 상태·슬롯 ID·스냅샷 계약은 유지한다.
4. 로컬라이제이션 트랙은 §4의 23키를 6개 비한국어 로케일에 채우고 한국어 fallback을 유지한다.
5. 리그·해금 재화·시간 목표가 정본에서 확정되기 전에는 결산 슬롯이나 수치 상수를 추가하지 않는다.
