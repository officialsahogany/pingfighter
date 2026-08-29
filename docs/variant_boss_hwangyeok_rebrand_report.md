# 변형 보스 4종 환격전 리브랜딩 수행 보고

작성일: 2026-08-21

## 1. 현재 상태

| 슬라이스 | 상태 |
|---|---|
| S1 표시 이름 교체 | 구현, 검증, 격리 커밋 완료 |
| S2 스킬 이름 개명안 | 사용자 수정 2건과 추가 2종 포함 승인 완료 |
| S3 스킬 이름 반영 | 13개 표시 이름, 7개 로케일, 씰과 Vulkan 검증 완료 |
| S4 스킬카드 아트 | 사용자 지시에 따라 대기 |
| S5 보스 스프라이트 시트 | 사용자 지시에 따라 대기 |

S1과 S3 범위는 `blocked=0`, `unverified=0`이다. 전체 `/goal`은 S4와 S5가
승인 대기이므로 완료 선언하지 않는다. 본 트리 통합과 push는 수행하지 않았다.

## 2. 격리 경계와 선행 WIP

| 항목 | 값 |
|---|---|
| 기준 HEAD | `252d6810856016f9287786b79a4f3c7dd13d1bad` |
| 격리 워크트리 | `C:\w\s1variant` |
| 격리 브랜치 | `codex/stage1-variant-boss-routing-20260821` |
| 선행 WIP 보존 커밋 | `59b3a38e5` |
| 선행 카탈로그 배선 커밋 | `927bc9bb5` |
| S1 구현 커밋 | `8e253e2f0` |
| S2 보고 커밋 | `d583aea87` |

본 트리의 전광판, 패배 정산, Stage 3 기본 보스 스킬 HUD 배선과
`variant_boss_display_name_smoke.gd`는 미커밋 WIP였다. 이 네 대상의 내용은
기존 격리 브랜치의 검증된 선행 커밋과 본 트리 파일 해시가 일치했다. 최신
HEAD 위에 그 두 선행 커밋을 보존한 뒤 S1을 별도 커밋으로 쌓았다.

`59b3a38e5`는 사용자 WIP를 격리 검증용 기준으로 보존한 커밋이고 통합 대상이
아니다. S1 통합 후보는 `8e253e2f0`이며, 본 트리의 선행 배선이 별도로
안정화되어 있어야 한다.

## 3. S1 표시 이름과 호환 ID

| 스테이지 | 호환 variant id | 구 표시 이름 | 새 표시 이름 |
|---|---|---|---|
| 2 | `arachne` | 아라크네 | 거미각시 |
| 2 | `molewang` | 두더지왕 | 지굴왕 |
| 3 | `alice` | 엘리스 | 옥토선자 |
| 3 | `teddy_bear` | 테디베어 | 포웅귀 |

`arachne`, `molewang`, `alice`, `teddy_bear`와 각 `codex_key`는 바꾸지
않았다. 스킬 id, 저장 키, 리소스 경로도 바꾸지 않았다.

표시 이름 정본은
`godot/scripts/stages/common/stage_boss_variant_catalog.gd`의
`display_name` 한 곳이다. 다음 소비자가 이 정본을 읽는다.

- 라운드 전광판
- 패배 정산 현재 보스 이름
- Stage 3 기본 보스 스킬 HUD builder
- Stage 2 거미각시와 지굴왕 전용 스킬 HUD
- Stage 3 옥토선자와 포웅귀 전용 스킬 HUD
- 탑 등정 2층과 3층 보스 슬롯, 전투 encounter, 지도 노드 label

탑 레지스트리의 2층과 3층 정적 슬롯에서는 `display_name` 중복값을 제거했다.
`get_floor_slots()`가 호환 `variant` 또는 기본 `boss_id`로 카탈로그 이름을
투영한다.

## 4. 7개 로케일

구 이름 번역 키는 세이브 호환을 위해 그대로 남겼다. 새 이름은 다음과 같이
추가했다.

| locale | 거미각시 | 지굴왕 | 옥토선자 | 포웅귀 |
|---|---|---|---|---|
| ko | 거미각시 | 지굴왕 | 옥토선자 | 포웅귀 |
| en | Spider Bride | Burrow King | Jade Rabbit Sage | Bear-Hug Ghost |
| zh | 蜘蛛新娘 | 地窟王 | 玉兔仙子 | 抱熊鬼 |
| ja | 蜘蛛の花嫁 | 地窟王 | 玉兎仙子 | 抱熊鬼 |
| es | Novia Araña | Rey de la Madriguera | Sabia del Conejo de Jade | Fantasma Abrazaosos |
| pt-BR | Noiva-Aranha | Rei da Toca | Sábia do Coelho de Jade | Fantasma Abraça-Urso |
| ru | Невеста-паучиха | Король нор | Мудрая Нефритовая Зайчиха | Дух медвежьих объятий |

한국어 신규 카피에는 엠대시를 사용하지 않았다.

### S3 스킬 표시 이름 로케일

한국어를 source key로 두고 나머지 6개 로케일에 다음 번역을 추가했다.

| ko | en | zh | ja | es | pt-BR | ru |
|---|---|---|---|---|---|---|
| 거미줄발사 | Web Shot | 蛛网发射 | クモの巣発射 | Disparo de telaraña | Disparo de Teia | Выстрел паутиной |
| 실공묶기 | Silken Ball Bind | 蛛丝缚球 | 糸でボール縛り | Atadura de bola con hilo | Amarra de Bola com Fio | Опутывание мяча нитью |
| 연쇄거미줄발사 | Chain Web Shot | 连锁蛛网发射 | 連続クモの巣発射 | Disparo encadenado de telaraña | Disparo em Cadeia de Teia | Цепной выстрел паутиной |
| 지맥잠행 | Earthvein Burrow | 地脉潜行 | 地脈潜行 | Acecho por la vena terrestre | Esgueira pela Veia da Terra | Ход земной жилой |
| 선조율풍 | Whirling Claw Gale | 旋爪律风 | 旋爪律風 | Vendaval de garra giratoria | Vendaval da Garra Giratória | Вихрь вращающихся когтей |
| 지굴원군 | Burrow Reinforcements | 地窟援军 | 地窟援軍 | Refuerzos de la madriguera | Reforços da Toca | Подземное подкрепление |
| 경화수월 | Flowers in a Mirror, Moon on Water | 镜花水月 | 鏡花水月 | Flores en el espejo, luna en el agua | Flor no Espelho, Lua na Água | Цветок в зеркале, луна в воде |
| 여의변화 | Willed Transformation | 如意变化 | 如意変化 | Transformación a voluntad | Transformação à Vontade | Преображение по воле |
| 옥토비탄 | Jade Rabbit Missile | 玉兔飞弹 | 玉兎飛弾 | Proyectil del Conejo de Jade | Projétil do Coelho de Jade | Снаряд Нефритового Кролика |
| 면운산화 | Cottoncloud Scatterbloom | 绵云散花 | 綿雲散花 | Floración de nube de algodón | Florescer da Nuvem de Algodão | Россыпь хлопковых облаков |
| 면화폭뢰 | Cottonflower Thunderbomb | 绵花爆雷 | 綿花爆雷 | Trueno explosivo de algodón | Trovão Explosivo de Algodão | Хлопковая гром-бомба |
| 사혼포옹 | Dead Soul Embrace | 死魂抱拥 | 死魂抱擁 | Abrazo del alma muerta | Abraço da Alma Morta | Объятие мёртвой души |
| 심광충파 | Heartlight Shockwave | 心光冲波 | 心光衝波 | Onda de choque del corazón | Onda de Choque do Coração | Ударная волна света сердца |

13개 한국어 source key에는 엠대시와 엔대시를 사용하지 않았다.

## 5. 하드코딩 전수 조사

`BOSS_NAMES_BY_STAGE`, `STAGE_BOSS_NAME`, 네 구 이름과 네 새 이름을 각각
독립 검색했다.

- `scoreboard_overlay_header_renderer.gd`의 `BOSS_NAMES_BY_STAGE`는 Stage
  4부터 8까지만 남아 있다. Stage 2와 3은 카탈로그를 먼저 읽는다.
- `defeat_settlement_screen.gd`의 `STAGE_BOSS_NAMES`는 Stage 1과 변형이 없는
  후속 스테이지 폴백만 남아 있다. Stage 2와 3은 카탈로그를 먼저 읽는다.
- `serve_wait_indicator_renderer.gd`의 `STAGE_BOSS_NAMES`는 Stage 1 `달지`만
  가진 기존 표다. 네 구 이름을 표시하지 않으며 이번 S1의 회귀 원인이 아니다.
- 네 구 이름의 production 스크립트 잔존은
  `language_settings_data.gd`의 호환 번역 키뿐이다.
- 네 새 이름의 production 정본은 변형 카탈로그 한 곳이다. 로케일 데이터는
  번역 정본이며, 테스트와 Vulkan QA의 기대값은 회귀 봉인용이다.

## 6. 씰과 검증

`variant_boss_display_name_smoke.gd`를 7개 레그로 확장했다.

1. 네 확정 이름과 네 호환 id 고정
2. 전광판, 정산, 전용 HUD, Stage 3 builder, 탑 슬롯의 카탈로그 투영
3. 기본 보스 `청린귀`, `환묘 연묘` 무손상
4. Stage 1 별도 호환 키 무손상
5. Stage 4부터 8까지 기존 폴백 무손상
6. 7개 로케일 새 번역과 구 번역 키 보존
7. production 소비자의 구 이름 하드코딩 금지

목표 문서에는 씰 수가 195개로 적혀 있으나 최신 기준 HEAD의 실제 두 목록은
각각 196개다. 기존 `variant_boss_display_name_smoke.gd`가 CI와 pre-push 양쪽에
등재되어 있고 집합 차이는 0개다. 신규 씰을 하나 더 추가하지 않고 이 기존
씰을 개정했다.

| 게이트 | 결과 |
|---|---|
| 집중 회귀 묶음 | `PASS=8 FAIL=0 TOTAL=8` |
| 배치 종단선 | `All Godot smoke tests passed.` |
| 리브랜딩 씰 | `PASS=7`, `SCRIPT ERROR` 0건 |
| RED 반증 | 거미각시를 임시로 아라크네로 되돌리자 확정 이름과 구 이름 금지 레그가 RED |
| RED 원복 | 원복 뒤 `PASS=1 FAIL=0 TOTAL=1`, 배치 종단선 재확인 |
| touched warning scan | 11 scripts, 경고 0건 |
| headless load | `Godot headless load check passed.` |
| Vulkan | Forward Mobile Vulkan, RTX 5070, 2020x1246, 오류 0건 |
| `git diff --check` | 통과 |

Vulkan 증거:

- 경로:
  `godot/.godot/codex_captures/variant_boss_hwangyeok_rebrand/scoreboard_four_variants_ko.png`
- SHA-256:
  `91F2F84A1BB78268C74524FA27D541A39B2EB07D42376A29F7A2ADBF57835DCA`
- 직접 확인: 거미각시, 지굴왕, 옥토선자, 포웅귀가 모두 production 전광판
  renderer에서 잘림 없이 표시됨

전체 3,353-script warning scan은 S1과 무관한 기존 parse debt 때문에 2,250번째
구간에서 중단됐다.

- `character_info_live_stats_smoke.gd`: 선언되지 않은 `PerkConversionFlags`
- `character_info_stat_source_attribution_smoke.gd`: 변경된 함수 인자 수와 불일치
- `commando_firearm_audio_routing_smoke.gd`: 제거된 `GameAudio` 상수 참조

S1 touched 11-script warning scan은 별도로 완주했다.

`defeat_settlement_screen_smoke.gd`의 별도 baseline RED도 S1과 무관하다. 이
테스트는 `_handle_defeat_settlement_input` 문자열이 input controller에 남아
있다고 단언하지만, 커밋 `2f89fc017`에서 해당 라우팅이
`battle_terminal_screen_input_router.gd`의 `_handle_defeat_settlement()`로
이동했다. 실제 S1 씰은 정산의 production snapshot builder를 호출해 새 보스
이름 투영을 검증한다.

### S3 검증

`variant_boss_skill_name_rebrand_smoke.gd`를 새로 추가하고 CI와 pre-push의
동일 위치에 등재했다. 두 목록은 각각 197개이며 집합 차이는 0개다.

1. 네 production HUD context의 13개 호환 id와 확정 label 고정
2. 추가 승인된 `spider_rage`, `friend_moles`의 실제 HUD 노출 고정
3. 공유 production tooltip의 live label fallback과 번역 소비 고정
4. 한국어 포함 7개 로케일의 exact-text 번역 고정
5. 네 보스 상태 owner에서 13개 구 표시 이름 제거
6. 스킬 id literal 유지와 지굴왕 HUD 발화의 새 이름 일치
7. 한국어 신규 카피의 엠대시와 엔대시 금지

| 게이트 | 결과 |
|---|---|
| S3 씰 | `PASS=7`, `SCRIPT ERROR` 0건 |
| 관련 회귀 묶음 | `PASS=7 FAIL=0 TOTAL=7` |
| 배치 종단선 | `All Godot smoke tests passed.` |
| RED 반증 | `실공묶기`를 승인 전 후보인 `주사견인`으로 임시 복귀하자 exact label 레그가 RED |
| RED 원복 | 원복 뒤 S3 씰 `PASS=7`, 단독 배치 `PASS=1 FAIL=0 TOTAL=1` |
| touched warning scan | 7 scripts, 경고 0건 |
| headless load | `Godot headless load check passed.` |
| Vulkan | Forward Mobile Vulkan, RTX 5070, 2020x1246, 오류 0건 |
| CI와 pre-push | 각각 197개, 집합 차이 0개 |
| `git diff --check` | 통과 |

Vulkan 증거:

- 경로:
  `godot/.godot/codex_captures/variant_boss_hwangyeok_rebrand/skill_names_four_variants_ko.png`
- SHA-256:
  `26B811646561FDE2C7EE2F655C8BAAA1AB109C50666E378734CC39A1D3BAFA43`
- 직접 확인: 거미각시 3개, 지굴왕 3개, 옥토선자 3개, 포웅귀 4개의
  production tooltip label이 모두 잘림 없이 표시됨

추가로 실행한 기존 광역 `language_settings_smoke.gd`는 이번 13개 exact-text
항목이 아니라 기존 아이템, 퍽, 캐릭터 카탈로그 번역 기대값에서 RED였다.
S3 전용 7로케일 exact-text 씰과 관련 회귀 7종은 별도로 완주했다.

## 7. S2 승인 확정과 S3 반영

승인된 11개와 추가 확정된 2개를 모두 production HUD 표시 이름에 반영했다.
`web_rescue`와 `spinning_claw`는 사용자 수정안을 최종값으로 사용했다.

| 보스 | skill id | 구 표시 이름 | 확정 표시 이름 | 한자와 의도 |
|---|---|---|---|---|
| 거미각시 | `web_trap` | 거미줄 장판 | 거미줄발사 | 거미줄을 발사하는 기술 |
| 거미각시 | `web_rescue` | 거미줄 구출 | 실공묶기 | 실로 공을 묶는 기술 |
| 거미각시 | `spider_rage` | 분노 거미줄 | 연쇄거미줄발사 | 거미줄을 연쇄 발사하는 기술 |
| 지굴왕 | `tunnel_raid` | 땅굴 습격 | 지맥잠행 | 地脈潛行, 땅속 지맥을 타고 기습함 |
| 지굴왕 | `spinning_claw` | 회전발톱 | 선조율풍 | 旋爪律風, 회전 발톱의 흐름을 바람으로 잇는 기술 |
| 지굴왕 | `friend_moles` | 친구두더지 | 지굴원군 | 地窟援軍, 지굴왕을 돕는 두더지 원군 |
| 옥토선자 | `mirror_world` | 거울 세계 | 경화수월 | 鏡花水月, 거울과 환영 세계를 함께 암시함 |
| 옥토선자 | `size_shift` | 사이즈 시프트 | 여의변화 | 如意變化, 뜻대로 몸의 크기를 바꿈 |
| 옥토선자 | `rabbit_projectile` | 토끼 투사체 | 옥토비탄 | 玉兔飛彈, 옥토끼가 날아드는 투사체 |
| 포웅귀 | `cotton_throw` | 솜뭉치 투척 | 면운산화 | 綿雲散花, 솜구름 덩이를 흩뿌림 |
| 포웅귀 | `cotton_bomb` | 솜뭉치 폭탄 | 면화폭뢰 | 綿花爆雷, 솜 소재의 폭발탄 |
| 포웅귀 | `deadly_hug` | 죽음의 포옹 | 사혼포옹 | 死魂抱擁, 죽은 혼의 치명적인 포옹 |
| 포웅귀 | `heart_beam` | 하트 빔 | 심광충파 | 心光衝波, 하트 빛이 충격파로 뻗음 |

`web_trap`, `web_rescue`, `spider_rage`, `tunnel_raid`, `spinning_claw`,
`friend_moles`, `mirror_world`, `size_shift`, `rabbit_projectile`,
`cotton_throw`, `cotton_bomb`, `deadly_hug`, `heart_beam` id는 바꾸지 않았다.
행동 상수, 판정, 쿨다운, 저장 키와 자산 경로도 건드리지 않았다.

## 8. 다음 승인 경계

S3까지만 완료했다. 사용자 지시에 따라 S4 스킬카드 아트와 S5 보스
스프라이트 시트는 계속 대기한다. sprite-generation skill도 실행하지 않았다.
