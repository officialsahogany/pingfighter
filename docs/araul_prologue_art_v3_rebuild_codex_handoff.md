# 아라울 서막 아트 v3 재구축 (5.5등신 · 먹/한지) — Codex 핸드오프

상태: **8장 수용·런타임 승격·Vulkan QA 완료, 최종 재검증 대기** (2026-08-11).
아트디렉션·판정 = Claude / 생성·배선 = Codex.
선행: 파일럿 2차 2장 검증 통과 — A1 등신 실측 여왕 ≈5.3 · 한미량 ≈5.9(오차 ±0.2,
보고치 5.45/5.72와 정합), B1 심각 톤 성립 확인. 스타일·등신 최종 승인 = 사용자
(이 문서는 승인 즉시 착수 가능하도록 선작성).

관련 문서 위계:
- `araul_prologue_v2_revision_codex_handoff.md` (rev5) = 서사·타임라인·카피·씰 정본. 유지.
- `araul_prologue_motion_pass_rev6_codex_handoff.md` = 모션 패스. **이 재구축 완료 후 착수**
  (델타 레이어는 새 플레이트에서 추출해야 하므로 순서 고정).
- 이 문서 = 8플레이트 아트 교체만 담당. 카피(M2/H4 숙주 교체)는 rev6 §1 소속이지만
  text.gd만 건드리는 독립 작업이라 **재구축과 병행/선행 가능**.

---

## 0. 표준 선언 (정본 기록 대상)

- **시네마틱/스토리 화면 표준 등신 = 5.5** (수용 밴드 5.25~5.75, 정수리~턱 대 전신,
  관·과장 신발 제외). 캐릭터 선택(장신 일러스트)·전투(SD) 표면은 각자 표준 유지.
- **스타일 = V3.5 먹/한지 셀**: 굵기 변화 있는 먹선, 한지 결, 평붓 셀 음영, 배경
  디테일 위계(얼굴>의복>배경), 군중 실루엣/단순 얼굴, 야간 남색 팔레트.
- **스타일·등신 앵커 = 파일럿 2차 2장** (모든 후속 생성에 참조 입력 필수):
  - `araul_a1_v35_proportion_fix.png` (신 A1 확정본)
  - `araul_b1_v35_serious_tone_test.png` (신 B1 확정본)
- **한미량 부츠 정본화**: A1 v35의 검은 부츠를 시네마틱 정본으로 채택(전투 SD와
  정합). D1·D2에도 동일 부츠. 맨다리(레그웨어 없음)+부츠 조합 고정.
- **B1 배경 신주 존치**: 타임라인상 정확(신주는 11.2에 출현). B2 파생 시 유지.

## 1. 작업 순서

1. **파일럿 2장 승격**: 1672 원본을 `art_sources/araul_prologue/final_v3/`로 복사,
   SHA-256 기록. 이후 모든 편집은 이 원본에서.
2. **D1 신규 생성** (§2.3) — 참조 입력 필수.
3. **파생 5장 재구축** (§3) — 검증된 2단 공정(이미지 편집 → 허용 마스크 밖 원본
   픽셀 결정적 복원). 마스크 좌표는 **신 구도 기준으로 전부 재정의**(구 좌표 무효).
4. 8장 일괄 Real-ESRGAN `realesr-animevideov3` 2배 → 3344×1882.
5. 런타임 교체: 텍스처 8경로 상수 교체, import(VRAM+밉맵) 일괄, 신 매니페스트
   (v3, 소스/런타임/donor SHA + 마스크 좌표), 스트리밍 스펙은 rev5 창 그대로.
6. 검증기 재조정 (§4) + 씰 락스텝.
7. 픽셀 QA: 7언어×1080p/1440p + 콘택트시트 + 프리플라이트 재실측.
8. 구 v2 8플레이트는 V3 최종 재검증까지 유지한다. V3 증거 수용 뒤에도 이번 작업에서
   삭제하지 않고 별도 정리 슬라이스에서 정확한 경로만 제거한다.

## 2. 베이스 3장

### 2.1 A1 = 파일럿 확정본 그대로

추가 작업 없음. 단 A2 신주 자리(여왕 우측 제단 상부)가 촛대와 겹치지 않는지
A2 파생 때 확인.

### 2.2 B1 = 톤 시험본 그대로

역광 미흡은 수용(배경 신주 광원이 대체 설명). B2 파생 시 구체 광원을 추가해 보완.

### 2.3 D1 신규 생성

```
Japanese cel illustration with Korean ink-line and hanji-paper texture,
matching the attached style anchors exactly (A1 v35 + B1 v35).
All figures at 5.5-head proportions — NOT chibi, NOT slender.

Medium two-shot, dark palace hall, night.
LEFT: a ritual official in black court robes, possessed — eyes glowing pale
teal, dark veins from his collar, body twisted mid-lurch. Same official as
the crowd attendant in the A1 anchor.
RIGHT: the warrior girl from the A1 anchor, identical costume: navy
sleeveless vest over white sleeves, navy pleated skirt, red sash with gold
ornament, black ponytail with white flower and red tassel, blue eyes, black
boots, bare legs. LEFT arm thrusts a round demon-mask shield sideways,
BLOCKING two palace guards behind her who are drawing swords. RIGHT hand
grips a bronze ritual mirror on a staff, lowered. She carries NO sword.
BETWEEN them floats a pale spent sphere, dim.
Crowd/guards as dark silhouettes or simple faces. Deep blue night palette,
candle rim light. 1672x941.
```

수용: 등신 게이트(두 인물 5.25~5.75, Claude 실측), 장비 좌우, 부츠, 구도가
타격(D2) 파생을 허용하는 배치(제관-공-한미량 축 확보).

## 3. 파생 5장 (전부 2단 공정 + 마스크 좌표 신규 실측)

| 플레이트 | 베이스 | 추가 요소 | 비고 |
|---|---|---|---|
| A2 | A1 | 신주 + 청록 영기 (제단 상부) | 신주 디자인은 B1 배경 신주와 동일 계열로 — 신스타일 재생성, 구 donor 사용 금지(화풍 충돌) |
| A3 | A2 | 신주 균열 + 검은 기운 한 줄기→여왕 | 여왕 자세 불변, 표정만 국소 |
| B2 | B1 | 입에서 청록 구체 반쯤 + 광원 보강 | 역광 실루엣, 젖은 묘사 금지. 배경 신주 유지 |
| C1 | A1 | 구체 부양 + 굵은 8줄기 + 불씨 + 여왕·제관 재작화 | 광선 중심·기하 기준 재실측. GRT-047 유의: 신스타일이 더 어두우면 광선 밝기 예산 선확인 |
| D2 | D1 | 타격 순간 + 령편→공 + 제관 회복(발광·핏줄 소멸) | 자세·의복 불변, 회복은 얼굴 국소 |

각 파생마다: 허용 마스크 정의(매니페스트 기록) → 편집 생성 → 마스크 밖 원본
복원 → 픽셀 델타로 마스크 밖 0 검증. C1만 예외(전역 광원) — 기하 불변은 rev5
방식(수치 게이트)을 신 좌표로 재정의.

## 4. 검증기·씰 재조정

- `validate_araul_c1_plate.ps1`: 광선 중심 좌표·환형 반경·8카운트·양방향 휘도
  기준을 신 C1 실측으로 갱신(판정 로직 불변, 파라미터만).
- `validate_araul_prologue_asset_contract.ps1`: 신 8경로·SHA·마스크 좌표·D2 회복
  픽셀 검사 갱신.
- 스모크: 텍스처 경로 상수 단언 갱신. 타임라인·CPS·스트리밍·no-sync 씰은 불변.
- **등신 게이트는 자동화하지 않는다** — 생성 단계 판정(Claude 실측)으로 충분하고,
  픽셀 자동 판정은 의상 가림 때문에 오탐이 크다. 매니페스트에 실측치만 기록.

## 5. 함정

1. **스타일 드리프트**: 모든 생성 호출에 앵커 2장 참조 입력. 앵커 없는 생성 금지.
2. **구 donor 재사용 금지**: 신주·구체·령편 등 효과 요소도 전부 신스타일로 재생성
   (구 화풍 오브젝트를 신 화풍 플레이트에 합성하면 즉시 이질).
3. GRT-047: 먹/한지 스타일은 전반적으로 어둡다 — C1 광선·B2 구체의 발광 예산을
   합성 전에 밝은 쪽으로 확보.
4. 클로즈업(B)과 광각(A/C/D)의 디테일 밀도 차이는 자연스러움 — 단 선 굵기·한지 결
   강도는 패밀리 간 일치 유지.
5. 업스케일은 8장 확정 후 **한 배치**. 파일럿과 신 생성물이 섞인 배치 금지.

## 6. 이후 순서 (재확인)

이 재구축 수용 → rev6 모션 패스(델타 추출은 신 플레이트에서) → 기존 커밋 계획에
합류(로더 헝크 분리 원칙 유지). 카피(M2/H4 숙주)는 언제든 독립 랜딩 가능.

## 7. 실행 결과 (2026-08-11)

- 최종 1672×941 소스 8장: `art_sources/araul_prologue/final_v3/`
- 단일 2배 배치: `godot/.tmp/araul_v3_upscale_batch_20260811/`
- 런타임 3344×1882 자산·SHA·임포트 계약:
  `godot/assets/ui/story/han_miryang_prologue/araul_prologue_v3_manifest.json`
- 소스 파생 계약: A2/A3/B2 승인 마스크 밖 델타 0, C1 의미 마스크 밖 채널 감소 0,
  D2 얼굴 마스크 밖 채널 감소 0·우측 30% 픽셀 고정.
- C1은 `(835,350)` 중심 180px·190px 원환에서 각각 정확히 8광선으로 검출됐다.
- Vulkan 풀 캡처 1회와 독립 threaded-only 런 1회가 모두 8경로 관측, 5경로 완료,
  상주 피크 4, 마감 누락 0, 종료 후 참조 0으로 통과했다.
- 영속 증거: `docs/qa_evidence/araul_prologue_v3/v3_vulkan_capture.json` 및
  `docs/qa_evidence/araul_prologue_v3/v3_vulkan_contact_sheet.png`.
- V2 삭제와 커밋은 이번 범위에 포함하지 않는다.
