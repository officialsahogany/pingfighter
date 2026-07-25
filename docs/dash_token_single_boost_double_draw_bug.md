# 버그: 단일 대쉬토큰 부스트 무지개 링 이중 드로우 (별건, LOD 무관)

상태: **OPEN / 미확인(트리아지 리포트 발). 고치기 전 실제 재현 확인 선행.**
분리 근거: 2026-07-06 severe-LOD 복구 트리아지 중 파생 발견이지만 **LOD/프레임 예산과
무관한 로직 버그**라, 복구 흐름과 섞으면 범위가 흐려짐 → 별도 티켓으로 분리(사용자 결정).
LOD 복구 자체는 PARKED (`docs/severe_lod_triage.md` 참조).

## 증상 (가설)
`max_tokens == 1` 이고 부스트 차징 중일 때, CPU가 그리는 부스트 무지개 링과 셰이더
FX 호스트가 그리는 무지개가 **동시에 그려질 수 있음**(이중 드로우 → 과밝음/겹침).

## 코드 근거 (트리아지 관측, 편집 전 재확인 필수)
- 멀티토큰 섹터 경로는 host-guard 있음:
  `hud/pillar_dash_token_fill_renderer.gd:149` — `if _has_active_boost_fx_host: continue`
- **단일토큰 부스트 경로는 그 가드가 없음**:
  `hud/pillar_dash_token_fill_renderer.gd` `_draw_single_boost_charging_token`(~:267),
  진입 `~:98-101 → ~:250` 에 `_has_active_boost_fx_host` 체크 부재.
- 셰이더 호스트가 무지개를 그림: `hud/pillar_dash_orb_renderer.gd:~213-224`
  (`dash_token_boost_fx_host.gd`).
- 결과: 호스트 활성 + `max_tokens==1` 이면 CPU 무지개 링이 host 무지개와 co-draw.

## 재현/확인 방법 (고치기 전)
1. 스매셔, 대쉬 토큰 최대치 1 상태 구성.
2. 부스트 차징 발동 → 부스트 FX 호스트 활성 프레임에서 오브를 픽셀 확인.
3. 무지개가 이중으로(더 밝게/겹쳐) 보이면 확정. 안 보이면 CLOSE(가드가 상위에서 이미
   커버하거나 두 경로가 상호배타일 수 있음 — 반드시 실측).

## 수정 방향 (확인된 경우)
- 멀티토큰 경로와 동일하게 단일토큰 부스트 진입에 `_has_active_boost_fx_host` 억제 가드
  추가(호스트 활성 시 CPU 링 스킵).
- 씰: `max_tokens==1` + active-host 스모크로 "CPU 부스트 링 draw-call 0" 검증
  (draw-call은 헤드리스 직접검증 불가 → 가드 분기/카운터를 함수로 분리해 봉인).
- 반증검증(SAFE, in-place Edit 토글, git reset 금지).

## 스코프 주의
LOD/severe 관련 없음. `docs/severe_lod_triage.md` 의 class 분류(3/4)와 무관한 별건.
