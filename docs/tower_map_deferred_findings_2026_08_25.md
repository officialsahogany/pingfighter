# 탑 지도 보류 발견 2건 (2026-08-25, 사용자 판단으로 연기)

피드백6 프로브 중 스코프 밖에서 발견됐고, 사용자가 **둘 다 나중에**로
결정했다. 착수하지 말 것. 재발견 시 여기를 먼저 읽고 중복 조사를 피하라.

두 건 모두 관제탑 프로브와 **독립 반증 에이전트가 각각 실측 재현**했다.

---

## [보류 P0] 내보낸 빌드 구성에서 지도 생성 16.5% 실패

**증상**: `tower_audition` 구성에서 `generate_tower`가 200시드 중 33개
(16.5%)에서 **빈 Dictionary**를 반환한다. 기본 12층 구성은 0/200으로 정상.

**왜 프로덕션인가**: `godot/export_presets.cfg:42~48`의 `[preset.1]`
`name="Windows Desktop"`이 `custom_features="tower_audition"`을 싣는다.
게이트는 `godot/scripts/tower_ascent/tower_audition_build_config.gd:6~22`
(`TEMP_AUDITION_BUILD_ENABLED && OS.has_feature("tower_audition")`).
즉 **에디터와 내보낸 빌드가 서로 다른 지도를 쓴다** — 오디션 구성은
clear_floor 7, 37노드, 1층 3행/7노드, 레인 1·2·4, **1층 선택 보스 없음**.

**복구 경로 없음**: 유일 호출자
`godot/scripts/tower_ascent/tower_ascent_flow_map_progress.gd:435~443`
`_build_generated_graph`가 빈 그래프에 대해 그냥 `false`를 반환한다.
**다른 시드로 재시드해 재시도하는 경로가 없다.**

**귀속**: 격리된 fresh 프로세스에서 bisect 완료.
`f83d231b8` = 0/200, `984c28143` = 0/200, **`e6fcea080` = 33/200**,
HEAD = 33/200. 즉 `e6fcea080`(선택 우회 보스 분포)이 도입했다.

**재현 시드**: 9109, 56623, 64542, 135813, 302112.

**미조사**: 어느 검증기가 기각하는지는 추적하지 않았다. 후보 =
`analyze_visible_boss_contract`, `analyze_optional_extra_boss_bypass`,
`boss_registry:283~284`의 예산 검사.

**착수 시 유의**: 재시드 재시도를 넣는 것은 증상 완화이지 원인 수리가
아니다. 검증기 기각 사유를 먼저 특정할 것.

---

## [보류] 추가 보스가 4~8층에 구조적으로 절대 나오지 않음

**배경**: 피드백2 ⑧에 대해 사용자가 "나머지도 한명 더 놓는걸로"를 승인해
`e6fcea080`이 랜딩됐다. 그런데 **실제로는 2·3층에서만 작동한다.**

**실측**(200시드): 2층 77회 / 3층 87회 스폰. **4층 87회 굴림 0회 스폰,
5층 103/0, 6층 89/0, 7층 91/0, 8층 88/0 — 458회 전부
`skip_reason=unique_pool_exhausted`.** 런당 평균 0.82마리.

**메커니즘**: `tower_ascent_tuning.gd:213~233`의
`TEMP_BOSS_STANDIN_BY_SLOT`에서 4~8층은 **두 shell 슬롯이 모두 그 층의
포팅된 보스와 같은 stage/boss_id로 매핑**된다(예: `floor_04_ponk` /
`floor_04_shell_01` / `floor_04_shell_02`가 전부 stage 4 ponk).
`canonical_encounter_key`(`tower_ascent_boss_registry.gd:171~178`)가
variant가 비면 boss_id로 접어 `"4:ponk"` 하나로 붕괴시킨다. 관문이 그
유일 키를 소진하면 그 층엔 남는 키가 없다.

반면 2·3층은 실제 변형이 3종씩 살아 있다
(`boss_registry:47~56`: cheongringwi/molewang/arachne,
yeonmyo/teddy_bear/alice).

**즉 이것은 토폴로지 문제가 아니라 콘텐츠 문제다.** 4~8층에 진짜 보스
변형을 만들기 전에는 구조를 어떻게 바꿔도 추가 보스가 나올 수 없다.
루프 범위 자체는 `boss_registry:509~512` `range(2, active_clear_floor - 1 + 1)`
= 2~8층이라 1층과 9층 이상에는 원래 못 들어간다.

**착수 시 유의**: 스프라이트/런타임 작업이 선행되어야 하는 아트 트랙이다.
지도 생성기 튜닝으로는 해결되지 않는다.
