# 미추적 참조 공백 감사 (untracked reference gap)

푸시 전 필수 감사. **커밋된 코드가 저장소에 없는 파일을 가리키는가**를
전수로 판정한다. 워크트리에서는 파일이 존재하므로 모든 게이트가 GREEN이고,
결함은 fresh checkout·CI·격리 워크트리에서만 드러난다.

## 사건 배경

- `cda444a33` — 커밋된 씰이 요구하는 상수가 **더티 상태의 부트 워밍업
  파일**에만 있었다. 본 트리는 GREEN이었지만 fresh checkout은 파스 에러로
  **CI 237 전체가 죽는** 상태였다.
- `cacc539d5` / `ea172afdd` — 미추적 stage4/6 소스 12개, 오디오·렌더러 3개.
- 관련 규칙: 미추적 자산은 격리 워크트리에 **존재하지 않으며**, 런타임
  `load`면 경고 없이 조용히 빈다.

## 4축 감사

`godot/`을 대상으로 아래 4개를 각각 독립 판정한다. 어느 하나라도 비어
있지 않으면 푸시 금지.

1. **씰 목록 락스텝**: `.github/workflows/godot-ci.yml`의 `tests/*_smoke.gd`
   집합 == `godot/tools/run_pre_push_checks.ps1`의 집합.
2. **씰 목록 × 미추적**: CI 씰 목록에 오른 파일 중 미추적인 것 0건.
3. **커밋된 코드 → 미추적 파일**(핵심): HEAD 전 파일 타입에서 뽑은
   `res://…` 리터럴 집합 ∩ 미추적 파일 집합 == ∅.
   `.gd`뿐 아니라 `png/json/wav/mp3/svg/gdshader/tres/tscn/ogg/ttf/otf`까지.
4. **전이 폐포**: 3번으로 파일을 착지시키면 그 파일의 `preload` 대상이
   새로 노출된다. **fixpoint까지 반복**할 것(2026-08-25 실사고).

재현 명령(요지):

```bash
# 미추적 집합
git ls-files --others --exclude-standard -- 'godot/' \
  | grep -vE '\.import$' | sed 's|^godot/|res://|' | sort -u > /tmp/untracked.txt
# 커밋된 참조 집합
git grep -h -o -E 'res://[A-Za-z0-9_/.-]+\.(png|gd|json|wav|mp3|svg|gdshader|tres|tscn|ogg|ttf|otf)' \
  HEAD -- 'godot/**' | sort -u > /tmp/head_refs.txt
# 교집합이 비어야 한다
comm -12 /tmp/head_refs.txt /tmp/untracked.txt
```

⚠`rg` 문자 클래스는 `[A-Za-z0-9_/.-]`로 쓸 것. `[…\.\-]`처럼 이스케이프를
넣으면 **매치가 조용히 줄어** 감사가 거짓 CLEAN을 낸다(2026-08-25 실측:
4122건 → 124건).

## 2026-08-25 실행 결과

미추적 파일 2,084개(`.import` 제외), `.gd` 423개 / 비-.gd 1,002개.

| 축 | 결과 |
| --- | --- |
| 1. 씰 락스텝 | CI 237 == pre-push 237 (동일) |
| 2. 씰 목록 × 미추적 | 0건 |
| 3. 커밋된 코드 → 미추적 | **16건 적발 → 전부 착지** |
| 4. 전이 폐포 | 1건 추가 노출 → 착지, fixpoint 도달 |

착지 커밋:

- `f6fe329ad` — 스크립트 3종.
  `smasher_void_phantom_state.gd`(903줄)는 **커밋된 프로덕션 카탈로그**
  `gameplay_actor_module_catalog.gd:113`이 경로로 등재 →
  fresh checkout에서 공허환영 모듈 해석이 조용히 실패.
  `battle_physics_gate_coordinator.gd`(307줄)는 CI 씰 3종이
  `ResourceLoader.exists` 가드로 조회 → 부재 시 폴백 분기를 타
  **추출 오너를 테스트하지 않는 공허 GREEN**(GRT-040).
  `battle_debug_menu_shortcut_router.gd`(61줄).
- `76cd75eb9` — 런타임 참조 PNG 12장(경신보 4·대성영단 8) + `.import`.
- `bec5d78c6` — `battle_debug_menu_switcher.gd`(전이 폐포). `f6fe329ad`이
  착지시킨 shortcut_router가 `:4`에서 하드 preload하는 대상이라, 1차
  착지가 **새 공백을 만들었다**. 4번 축이 필요한 이유.

잔여 CLEAN 히트는 `tools/online_match_live_visual_qa.gd`의 `OUTPUT_PATH`
1건뿐이며 **생성 산출물이므로 오탐**이다.

## 짝 착지 규칙 (다음 커밋부터)

미커밋 코드가 미추적 파일을 참조하는 **짝이 679쌍**(소스 244개 =
더티 추적 93 + 미추적 151) 남아 있다. 이들은 지금은 무해하지만,
**해당 헝크가 자산 없이 먼저 커밋되는 순간 지뢰가 된다**
(`battle_scene_frame_controller.gd:8`이 정확히 그 상태였다).

> 헝크를 스테이징할 때, 그 파일이 참조하는 미추적 `res://` 대상을
> **같은 커밋에 함께 올린다.** 자산만 빼고 코드를 올리지 않는다.

짝 규모 상위(자산 수):

| 소스 | 상태 | 요구 미추적 |
| --- | --- | --- |
| `scripts/lingpet/lingpet_catalog.gd` | DIRTY | 114 |
| `tests/guardian_spirit_skill_rebrand_smoke.gd` | 미추적 | 30 |
| `tests/lingpet_debug_picker_smoke.gd` | DIRTY | 19 |
| `tests/mika_hwangyeok_upperbody_live2d_smoke.gd` | 미추적 | 17 |
| `tests/character_select_hwangyeokjeon_chrome_smoke.gd` | 미추적 | 16 |
| `scripts/characters/commando_supply_drop_state.gd` | DIRTY | 13 |
| `tests/stage3_map_port_smoke.gd` | DIRTY | 13 |
| `scripts/stages/stage1/stage1_han_miryang_prologue_presentation.gd` | DIRTY | 12 |
| `scripts/core/battle_scene_frame_controller.gd` | DIRTY | 11 |

## 이 감사가 잡지 못하는 것

리터럴 경로만 본다. 아래는 **별도 판정**이 필요하다.

- **구성 경로**: 커밋된 `.gd`에 `res://…%s…` 템플릿이 22종 있다
  (`assets/sprites/items/%s.png`, `assets/sprites/perks/%s_perk_icon.png`,
  `assets/sprites/skills/commando_%s_skill_orb.png`,
  `assets/sprites/lingpet/resonance_egg_variant_%d.png` 등). 미추적 자산
  190개가 이 템플릿의 표적 폴더에 있다. 키 집합을 카탈로그에서 전개해
  대조해야 하며, **grep 0건은 도달 불가의 증거가 아니다**.
- **`class_name` 전역 참조**: 미추적 `.gd` 중 `class_name` 선언은 3종
  (`ScreenClipCanvasMaterial`, `VfxForgeLayerResource`,
  `VfxForgePresetResource`) — 커밋된 참조 0건으로 현재는 안전하나,
  전역 클래스 캐시는 `.godot/`(무시됨)에 있어 fresh checkout에서만
  드러난다.
- **`.import` 동반**: PNG는 `.png.import`를 함께 올려야 한다(저장소 관례
  1,749건). 감사 집합에서는 `.import`를 제외하므로 착지 시 수동 동반.
- **나이틀리 레인**: 나이틀리는 `*_smoke.gd` 전체를 도는데, 미추적 씰은
  fresh checkout에 없다. CI 237에는 없지만 로컬에만 있는 씰 = 저장소에
  증거가 없는 씰이다.
