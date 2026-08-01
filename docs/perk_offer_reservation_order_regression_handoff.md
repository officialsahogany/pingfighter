# 퍽 오퍼 예약 체인 회귀 핸드오프 (Codex 실행용) — 씰 노후화 + mythic jackpot 밀림 리스크

작성 2026-08-01. Claude 검수 발견. **`2f7beb4be`(초식 만석 교체 오퍼)
자체는 계약대로 구현됐고 승인**이다 — 이 문서는 그 검수 중 드러난 **선행
커밋발 회귀 1건 + 신규 리스크 1건**을 다룬다.

## 1. RED — `perk_offer_owned_upgrade_priority_smoke` (선행 커밋 소관)

**현재 RED**: `full-slot offer should keep the guaranteed soul-summon
reservation first`(:58).

- 원인: **`5125ecd26`(영혼소환술 랜덤화)이 예약 레인을 폐지**했는데, 이 씰은
  예약 보장을 여전히 단언한다(:58 / :125 / :164 / :165 — 4곳).
- 이 씰의 마지막 수정은 `cbc186742`이므로 랜덤화 커밋에서 **손대지 않았고**,
  Codex 보고·Claude 검수 양쪽 다 이 씰을 실행 목록에 넣지 않아 놓쳤다.
- ⚠️ 단순 삭제 금지: **:164~165는 "jackpot이 나머지 target을 채운다"는
  슬롯 경쟁 계약**을 봉인하던 유일한 지점이다. 폐지가 아니라 **새 예약
  체인에 맞게 재조준**해야 §2의 리스크가 다시 봉인된다.

## 2. 리스크 — mythic jackpot이 신규 레인에 밀린다

현재 예약 체인 실측 순서(`get_choices()` :1409~1438):

```
guardian_enhance → full_chosik_swap(신규) → mythic → dash_token
→ owned_upgrade → 일반 셔플
```

문서화된 계약(:1379 주석)은 **"mythic -> dash token -> owned upgrades ->
ring-core -> shuffled"**다. 즉 신규 레인 2개가 **계약 문서보다 앞에 삽입**됐고
주석은 갱신되지 않았다.

- `target_choice_count`가 3일 때 `guardian_enhance` + `full_chosik_swap`이
  둘 다 성립하면 **mythic은 1칸만 남는다.**
- mythic jackpot은 `mythic_count = target_choice_count`(:1376)로 **판 전체를
  채우는 이벤트**인데, 1칸만 들어가면 **잭팟이 잭팟이 아니게 된다.**
- 동시 발생 확률은 낮지만(만석 교체 0.15 × 잭팟 0.1) 발생 시 체감 손실이
  가장 큰 조합이다.

### 권고 (기획 판단 필요)

**mythic jackpot을 최우선으로 되돌린다** — 가장 희귀하고 임팩트가 크며,
"판 전체를 채운다"는 사양이 다른 레인과 애초에 양립하지 않는다:

```
mythic → guardian_enhance → full_chosik_swap → dash_token → owned_upgrade → 셔플
```

또는 **잭팟일 때는 다른 예약 레인을 전부 건너뛴다**(잭팟 = 전용 화면).
어느 쪽이든 **:1379 fill order 주석을 실제 순서와 일치하게 갱신**할 것 —
지금은 문서와 코드가 어긋나 있어 다음 사람이 또 앞에 끼워 넣는다.

## 3. 작업 계약

1. `perk_offer_owned_upgrade_priority_smoke`의 soul-summon 예약 단언 4곳을
   **현행 계약으로 재조준**:
   - 영혼소환술은 **일반 셔플 후보**로만 등장(예약 레인 부재).
   - jackpot 레그(:164~165)는 **새 체인 기준**으로 "잭팟이 실제로 target을
     채우는가"를 단언하도록 고친다.
2. §2 순서 결정을 반영하고 **:1379 주석 갱신**.
3. 신규 레그: **guardian_enhance + full_chosik_swap + jackpot 동시 성립**
   픽스처에서 우선순위가 결정대로인지 단언(결정론 RNG 주입).
4. 반증 1회(순서를 뒤집으면 해당 단언 RED).
5. 회귀: `chosik_slot_full_swap_offer_smoke`,
   `guardian_enhance_offer_engine_smoke`, `perk_slot_limit_smoke`,
   `soul_summon_art_skill_contract_smoke` GREEN 유지.

## 4. 재발 방지 메모

예약 레인을 **추가**하거나 **폐지**할 때는 반드시
`perk_offer_owned_upgrade_priority_smoke`를 실행 목록에 넣을 것. 이 씰이
예약 체인 전체의 우선순위를 봉인하는 유일한 지점인데, 이름이
"owned_upgrade"라서 **레인 변경과 무관해 보이는 함정**이 있다.

## 5. 보고 형식

커밋 해시 / §2 순서 결정과 근거 / 재조준한 단언 목록 / 씰 원문·반증 /
주석 갱신 확인 / 미결·발견 사항.
