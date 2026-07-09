# 퍽 융합 시스템 — 세션 핸드오프 (2026-07-09)

다른 기기(노트북)에서 이어서 작업하기 위한 브리프. 본 문서는 상태
스냅샷이고, **설계의 단일 소스는 `docs/perk_fusion_system_plan.md`**다.
설계 내용이 궁금하면 이 문서가 아니라 플랜 문서를 읽어라.

## 현재 단계

**설계 확정 완료, 구현 0줄.** 리포에 융합/fusion 런타임 코드는 아직
존재하지 않는다 (grep해도 안 나오는 게 정상).

진행 경위:
1. 사용자 기획 피칭 (만렙 퍽 2개 → 융합 카드 → 3분기 랜덤 결과).
2. Claude 설계 피드백 + 부산물 아이디어 제안 → 사용자 수치 조정 확정
   (부작용 -10~-30%, 옵션 랜덤 1~2개 감소 / 드물게 1개 삭제).
3. Codex 설계 리뷰 5 findings (High 3: 저장모델 불명확 / 신화 분류
   필요 / 2차 모달 상태 전이표 필요, Medium 2: 툴팁 렌더 예산 /
   부산물 캡) — **전부 수용, 플랜 문서에 반영 완료**. 리뷰 원문은
   데스크톱 로컬 첨부파일이라 이 기기에는 없지만, 결정 사항은 플랜
   문서에 모두 흡수됐으므로 원문 불필요.
4. `docs/perk_fusion_system_plan.md` 작성 + 단독 커밋 (`af353e07f`).

## 리포 상태 주의

- 브랜치: `fix/plaza-lingpet-egg-full-roster-test`.
- 커밋 `af353e07f`(플랜 문서)와 본 핸드오프 커밋은 **로컬 전용**
  (push 안 함 — 표준 정책). 노트북에서 받으려면 데스크톱에서 push가
  선행돼야 한다.
- 데스크톱 워크트리에는 이 작업과 **무관한** WIP가 다수 잔존
  (퍽 4종 삭제 스테이징, 문서 수정 등). 융합 작업 커밋 시 반드시
  스코프 분리할 것 — 이번 세션에서 스테이징된 삭제 WIP가 커밋에
  쓸려 들어갔다가 soft reset + `git commit --only <path>`로 분리한
  사고가 실제로 있었다. **이 인덱스 상태에서는 `git commit -a`나
  경로 없는 `git commit` 금지, 항상 `--only <경로>`로 커밋.**

## 핵심 결정 (재논의 금지, 상세는 플랜 문서)

- 저장 모델: 원본 퍽 2개 `runtime_skill_levels` 유지 + `perk_fusion_state`
  오버레이 레코드. `fusion:A:B` 합성 ID 기각.
- 페널티 적용점: 공용 값 헬퍼의 단일 게이트웨이 훅 1곳.
- `fusion_class` 6분류. 신화·boolean 고유 퍽은 후보 O / 부작용 면제.
  해금(`unlock_*`)·즉발(`instant_*`)·시스템 축은 후보 제외.
- 후보 판정 = base level == max_level (유효레벨 아님).
- 롤·레코드 커밋 = 확정 버튼 시점. 연출은 표현일 뿐 (중단 안전).
- 플로우 전체가 기존 퍽 모달 세션 내부 — 새 freeze actor 금지.
- 부산물 중복 = 보유분 롤 풀 제외. 반복 트리거형은 캡 필수.
- 연쇄 융합 v1 금지. 특수 레시피는 v2 여지로만 기록.

## 다음 작업 (우선순위 순)

1. **S1 슬라이스 구현**: `fusion_class` 분류 + 후보 판정 + 레코드
   스키마 + 세이브/로드 (플랜 §8 슬라이스 표, 씰 명세 포함).
   이후 S2(모달) → S3(롤+값 훅+슬롯) → S4(부산물) → S5(툴팁/아이콘/연출).
2. **융합 선택지 카드 아이콘 5종** imagegen — 미착수. "뭉쳐진" 모티프
   정적 아이콘, 리포 정책상 비-시트 = Gemini 경로 (FLUX 금지).
3. 밸런스 패스 (플랜 §10): 55/25/20, 부작용 80/20, 카드 등장 35% 등
   전부 시작값일 뿐 미확정.

## 구현 착수 전 필독

- 플랜 §9 트랩 체크리스트 (연쇄 모달 입력가드, 복귀 램프, DEFAULT_VALUES
  스키마, row budget, per-opportunity 롤, 슬롯카운트 브리지, 유효레벨,
  다국어, 값 헬퍼 우회 소비자).
- `docs/character_skill_perk_checklist.md` §4.4 / §4.5 / §5.
- 각 슬라이스 반증검증(in-place 토글 RED 재현) 필수 — `git reset` /
  `checkout` / `stash` 검증 금지 (리포 표준).
- 참고한 실제 카탈로그 위치: `godot/scripts/characters/runtime_perk_catalog.gd`
  (COMMON/SMASHER/VIPER/SOLDIER/CONVERTED/CONVERTED_MYTHIC/INSTANT_PERKS,
  슬롯 상수 BASE 6 / MAX 10 / `common_expansion`).
