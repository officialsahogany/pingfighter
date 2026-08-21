# 무공 아이콘 신세대 배선 완료 보고

- 기준 커밋: `28e9bfdfbfeb42b20055585dd17d385ff276e29a`
- 격리 워크트리: `D:/main/bosspong_mugong_icon_wiring`
- 구현 브랜치: `codex/mugong-icon-wiring-28e9bfdfb`
- 배선 커밋: `2654c1df81a1a59c20b40843ca3e9ea103cce438`
- 범위: 기존 아이콘 경로 배선과 그 검증만 변경했다. 아트, 수치, 기능, 카피는 변경하지 않았고 본 트리에 통합하거나 푸시하지 않았다.

## 에셋 및 import 전수 감사

`godot/assets/sprites/perks/*_mugong_icon.png`를 파일 시스템에서 수집했다. 기준
커밋에는 36종이 있었고 맵과의 대조 결과는 기존 일치 10종, 구세대 경로 23종,
맵 엔트리 없음 3종이었다.

- 기존 신세대 배선 10종: `blade_amp`, `combo_amplifier_chip`, `dash_spirit`,
  `extension_gear`, `four_poisons`, `gravitybelt`, `jetpack_enhance`,
  `kick_enhance`, `pistol_enhance`, `smartphone`
- 구세대에서 교체한 23종: `adversity_armor`, `battery`, `bluetooth_ring`,
  `bulletproof_hat`, `chargebag`, `commando_arm`, `dowsing_goggles`,
  `dowsing_pendulum`, `foul_whistle`, `fuel_pouch`, `gold_digger`, `knee_pads`,
  `lucky_coin`, `master`, `neural_helmet`, `rainbow_fur_glove`,
  `reinforced_boomerang_gauntlet`, `sage_ring`, `sensor`, `shrapnel_armor`,
  `soul_burst`, `star_detector`, `venom_mist_gauntlet`
- 에셋은 있으나 맵에 없던 호환 ID 3종: `revival`, `speedgear`,
  `spiked_helmet`. 현재 카탈로그에 다시 노출하지 않고, 저장 데이터나 진단
  소비자가 ID를 요청할 때만 같은 신세대 인장을 반환하도록 등록했다.

36종 모두 다음 체인이 확인됐다.

- PNG 36/36 및 추적된 `.png.import` 36/36
- `.import`의 `source_file`이 실제 PNG와 일치: 36/36
- `remap/type="CompressedTexture2D"`, `remap/path=*.ctex`, `dest_files` 일치:
  36/36
- warm worktree의 선언된 `.ctex` 실재: 36/36
- `ProjectResourceLoader.load_imported_texture()`가 raw PNG가 아닌
  `CompressedTexture2D`를 반환: 36/36
- 정적 크기 256x256, 가시 픽셀/soft-alpha/투명 외곽: 36/36

따라서 raw-PNG 디코드 폴백만으로 통과한 것이 아니다. 기존 절차 폴백과 미지 ID
fail-safe는 수정하지 않았다.

## 소비자 전수 감사

`icon_path`, 대문자 `ICON*`, `_icon`, `RuntimePerkIconRenderer`/`draw_icon`, 실제
36개 basename 리터럴을 각각 독립적으로 검색했다. 그 결과 대상 구세대 경로의
생산 코드 직접 참조는 맵 23곳뿐이었고, 배선 뒤에는 0곳이다. 별도 효과 렌더러의
`sage_ring_mugong_icon.png` 직접 참조는 공유 맵과 같은 경로다.
`angel_blessing_roll_overlay_host.gd`의 직접 `ICON_PATH`는 대상 36종이 아닌
`angel_blessing` 전용이라 유지했다.

다음 소비자는 표시 ID를 같은 `RuntimePerkIconRenderer.draw_icon()` 계약으로
전달한다.

- 전투 및 Tower 무공 선택 카드, 카드 툴팁, 획득 비행
- F4 무공 도감/디버그 picker와 프리웜
- TAB 캐릭터 정보창의 무공 컬렉션, 보유 무공, 능력치 원인 툴팁
- 무공 합일 재료 카드, 합성 아이콘, 공개/결과 표시
- 전투 HUD strip, 광장 표시
- 스테이지 클리어 보상 카드와 보물찾기 획득 화면

정적 씰은 위 소비자 소스의 양성 `draw_icon(id)` 진입점을 단언하고, 생산
`scripts/`와 `scenes/`를 재귀 스캔해 각 파일 시스템 수집 ID마다 다른
`*_perk_icon.png` 또는 충돌하는 perk-icon 리터럴이 없음을 함께 확인한다.

프리웜 작업은 `PERK_ICON_PATHS`를 순회해 생성되므로 별도 경로 목록이 없다.
디버그 picker의 전체/단계형 프리웜과 융합 icon 준비 스모크가 갱신된 맵으로
통과했다.

## 동적 씰 및 RED 반증

`runtime_perk_general_icon_static_smoke.gd`에서 ID 상수 목록을 제거했다. 현재
PNG, `.import` sidecar, `PERK_ICON_PATHS`의 `*_mugong_icon.png` 값을 합집합으로
수집하므로 새 에셋이나 맵 엔트리가 추가돼도 자동으로 감사 대상이 된다.

이 씰은 수집된 모든 ID에 대해 다음을 단언한다.

- 파일 시스템 경로와 공유 맵 경로가 정확히 일치
- `.import` -> `.ctex` remap 및 imported texture 로드 성공
- prewarm 뒤 신세대 경로만 캐시되고 같은 ID의 구세대 경로는 미캐시
- 실제 `draw_icon()` 드로우 성공
- 생산 소비자 전부가 같은 ID 기반 공유 렌더러 계약을 사용

`run_mugong_icon_missing_asset_red_counterproof.ps1`는 파일 시스템에서 첫 PNG를
동적으로 골라 잠시 이동한 뒤 같은 씰을 실행하고 `finally`에서 복원한다.
`adversity_armor_mugong_icon.png`를 잠시 제거한 실측에서
`adversity_armor filesystem-discovered Mugong source PNG should exist`로 RED가
났고 wrapper가 기대 실패를 확인했다. 복원 뒤 씰은 다시
`runtime_perk_general_icon_static_smoke: ok assets=36`으로 GREEN이다.

## 아트 트랙 후보

`PERK_ICON_PATHS` 113개 중 신세대 Mugong PNG가 없는 값은 77개다. 여기서
액티브 아이템 호환 1개, 체질 수련 11개, 융합 오퍼/절차 아이콘 6개,
도깨비 꾸러미 전용 1개를 제외한 아트 트랙 후보는 58개다. 이번 작업에서는
경로를 바꾸지 않았다.

`angel_blessing`, `baal_boots`, `celestial_armor`, `common_bulk_up`,
`common_expansion`, `common_refresh`, `common_swiftness`, `common_training`,
`convert_to_gold`, `core_stabilize`, `dash_acceleration`, `dash_amplification`,
`dash_jump`, `dash_lightweight`, `dash_module_control`, `downtown_bargain`,
`downtown_gamble`, `downtown_treasure_map`, `dual_catalyst`, `golden_trajectory`,
`heavenly_cape`, `hermes_shoes`, `horn_strawberry_mask`, `instant_gauge_full`,
`instant_monkey_blessing`, `item_caffeine`, `item_cooldown_mastery`,
`item_gauge_mastery`, `item_luck`, `item_polish`, `item_recycle`, `limit_break`,
`lingpet_resonance`, `linked_arsenal`, `magnet_burst`, `megingjord`,
`meridian_expand`, `mutation_factor`, `odins_eye`, `overflow`,
`overload_circuit`, `pandora_legacy`, `perk_boost_charge`, `perk_laurel_shield`,
`poseidon_trident`, `ragnarok_hammer`, `recycle_protocol`,
`returning_light_step`, `reverb`, `sacred_laurel`, `sleeve_cosmos`,
`spellbreaker_guard`, `static_field`, `training_mastery`, `transcendent_crown`,
`twin_roulette`, `weather_adapt`, `yangui_hoechun`

## 검증 결과

| 게이트 | 결과 | 증거 |
| --- | --- | --- |
| 파일 시스템 동적 배선/import 씰 | GREEN | `assets=36`; 경로 불일치 0, `.import` 누락 0, `.ctex` 누락 0, imported type 불일치 0 |
| PNG 임시 제거 RED 반증 | RED 확인 후 복원 | `adversity_armor_mugong_icon.png` 임시 이동 시 대상 누락 단언으로 exit 1, 복원 뒤 GREEN |
| 대상 소비자 smokes | GREEN | 선택/컬렉션/툴팁/융합/도감 프리웜/보상/보물찾기 9개 개별 GREEN |
| headless load | GREEN | graceful shutdown marker와 `Godot headless load check passed.` |
| touched warning scan | GREEN | GDScript 4개, 각 focused scan warning 0 |
| Vulkan visual QA wrapper | GREEN | Forward Mobile/Vulkan, 선택·컬렉션·F4 무공 탭·TAB 정보창 4/4 terminal marker |
| `git diff --check` | GREEN | 공백 오류 0 |

넓은 baseline `character_info_overlay_prewarm_smoke`는 별도 실행에서 RED였다.
대상 무공 아이콘이 아니라 warm cache에 없는 ball-spawn/lingpet `.ctex` 4종과
기존 acquired-perk cache/shared-color 소스씰 불일치 때문에 wrapper가
`PASS=9 FAIL=1 TOTAL=10`으로 종료했다. 같은 TAB 생산 드로우의 Vulkan 캡처와
대상 36종 import 체인은 GREEN이므로 선택 범위 밖 baseline 실패로 분리한다.

## Vulkan 캡처 판정

- 선택 카드 1280x720: 낙성결·회선철수·칠채순환 신세대 인장 확인.
  SHA-256 `92094E59F97CA5BE9C0C50B9242C8663D9AD98419CB4AF3318FF350E4BCEE9FA`
- 선택 카드 compact 760x750: 같은 3종이 축소 레이아웃에서도 실루엣과 외곽
  인장 구분을 유지. SHA-256
  `F2CC7591585438D319C60BC8FAB9760E1003F283C71527FE360A0C8C65A76BAE`
- 무공 컬렉션 1180x920: 82px/32px 쌍에서 31종 모두 폴백 심볼 없이 표시되고
  32px에서도 주제 실루엣이 구분됨. SHA-256
  `B549B0809D407B91237AD5C419572289A771805BFA7ED5551FB0ACEE26A599AD`
- F4 무공 탭 1180x720: 실제 `runtime_perk_debug_picker.draw()`에서 낙성결·
  회선철수·칠채순환 36px 인장 확인. SHA-256
  `D8B5C9BDFC60A0CFD4ED10E7F7FB7B201DB3463F53357C9C6E928429DBA8D634`
- TAB 캐릭터 정보 1180x280: 반탄심법·감응보 신세대 인장과 융합 표시 확인.
  SHA-256 `7B7EACEF304043C5F5912DAA8BC145CA2084B1B829075FCA4E018172F3BA806E`

캡처는 `D:/tmp/bosspong_ui_panel_capture/mugong_icon_wiring_28e9bfdfb/`와
격리 worktree의 `godot/.tmp/`에 보존했다. RED 로그는
`godot/.godot/codex_logs/mugong_icon_missing_asset_red_*.log`에 보존했다.
