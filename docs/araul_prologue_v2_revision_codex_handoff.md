# 아라울 서막 v2 개정 — 대본·플레이트 제작 핸드오프

상태: **rev5 구현·픽셀 수용 게이트 완료** (2026-08-10). 설계·아트디렉션 = Claude /
생성·배선 = Codex.
현행 정본: `docs/araul_foundation_prologue_canon.md` v2.
과거 기준 커밋 `2b98dee0d`의 3플레이트 38.0초 구현은 이 문서의 **8플레이트
48.0초** 구현으로 대체됐다.

> **V3 아트 우선 규칙 (2026-08-11):** 이 문서의 서사·48초 타임라인·스트리밍·7언어
> 카피 계약은 계속 유효하다. 다만 §0의 V2 소스, §3~4의 플레이트 제작·마스크 좌표,
> §7의 픽셀 자산 판정, §8의 자산 경로는
> `docs/araul_prologue_art_v3_rebuild_codex_handoff.md`와
> `godot/assets/ui/story/han_miryang_prologue/araul_prologue_v3_manifest.json`이 대체한다.
> 특히 C1의 현행 계약은 `(835,350)` 중심 180px·190px 원환의 정확히 여덟 광선과
> 의미 마스크 밖 채널 감소 0이다. 아래 V2 `(735,485)`/180px·240px/전역 양(+) 합성 수치는
> 역사 기록일 뿐 현행 런타임 수용 기준이 아니다.

> **rev6.1 모션 우선 규칙 (2026-08-11):** 이 문서의 26.0~27.4초 B2→C1
> 크로스페이드와 27.4초 rays 큐는 역사 기록이다. 현행 런타임은
> `docs/araul_prologue_motion_pass_rev6_codex_handoff.md`에 따라 26.15초 rays 큐,
> 26.25초 플래시 아래 B2→C1 하드 컷, V3 파생 FX 4장과 강화된 카메라 모션을 쓴다.
> 총 길이 48.0초, 서사·대사·경과 자막·챕터 카드 시간은 변하지 않는다.

개정 사유: 서막이 "왜 하필 공으로 싸우는가"에 답하지 못했고, 이미 기획 정본이던
팔주령 여덟 방울(= 팔도 = 1부 Stage 1~8)을 쓰지 않았다. v2는 악령의 핵이 곧 공이고
사람은 남기고 숙주 안의 령만 쳐낸다는 **세계 법칙**으로 그 둘을 동시에 해결한다.

rev2 변경점: 원본 소스 승격 계약 신설(§0), 경과 자막 독해 시간 확보로 45.0→46.2초,
영어·중국어·pt-BR·스페인어 카피 교정, A1 결정적 합성 의무화, B1·D1 참조 이미지
의무화, 스트리밍 계약 4항 명시.

rev3 변경점: 자막 독해 예산을 **CPS 규칙 + 씰**로 정식화(§2.0), 경과 자막을 **순차 2줄**로
분리하고 46.2→48.0초, 영어 장문 6줄 압축, 중국어 챕터 카드 교정, C1 기하 불변의
**수치 판정 기준** 명시(§4.6).

rev4 변경점: CPS 초과 **17개 조합 축약 완료** — 대사표가 84개 전수 검산을 통과한
확정본이 되었다(더 이상 "출발점"이 아님). 축약 중 의미 핵이 빠진 4건(es·pt·ru의
`funeraria` 계열 누락, ru H5 명령형 인칭 불일치)을 보정. C1 휘도 검사를 **양방향
역조건**으로 강화.

역사적 구현 상태(2026-08-10): **rev5 런타임 랜딩 완료.** 1672×941 원본 3장 승격,
최종 소스 8장, 일괄 2배 업스케일, BPTC/ASTC+mipmap 임포트, 48초 타임라인,
A-only 시작 프리웜과 B/C/D 단계 스트리밍, 7언어 CPS 씰, Vulkan 1080p·1440p
캡처까지 구현했다. V3·rev6 수용 뒤 rev5 런타임은 퇴역했으며, 당시 제작 결과와
체크섬은 `art_sources/araul_prologue/final_rev5/araul_prologue_v2_rev5_manifest.json`에
원문 그대로 보존한다. 그 매니페스트의 `runtime_authority: true`는 당시 상태의 역사
기록이며 현행 런타임 권위를 뜻하지 않는다. 설정 정본은
`docs/araul_foundation_prologue_canon.md` v2를 따른다.

rev5 변경점: C1 청록 마스크를 **실측 기반으로 재설계**. `b>r && g>r` 단독은 야간
배경 때문에 효과 없는 판도 59.2%가 잡혀 무의미했다(실측표 §4.6). chroma_margin 32 +
A1 대비 델타 24 + 상대 3배·절대 2% 이중 조건 + 중립 영역 15% 하한을 추가했다.
최종 수용 보강에서 C1의 양(+) 합성과 두 극좌표 원환의 **정확히 여덟 광선**을 함께
잠갔고, A1의 실제 4-rect 합성·A3 연결부·D2의 5-ellipse 합성을 픽셀 검증기에 반영했다.

---

## 0. 【선행 필수】 원본 해상도 소스 승격

과거 커밋의 `*_bishoujo_v2.png` 3장은 3344×1882 업스케일본이라 편집 베이스로 쓰지
않는다. 착수 전에 진짜 1672×941 원본을 아래 추적 경로로 승격하고 체크섬을 고정했다.

| 현재 추적 경로 (`art_sources/araul_prologue/`) | SHA-256 |
|---|---|
| `01_araul_coronation_bishoujo_v2.png` | `2af617d49f5a411b715bbc523921da9cb9e3842de2699094a2cfc2a37fb28449` |
| `02_araul_ball_strike_no_tablet_bishoujo_v2.png` | `3425743f8ed69f545d5ec81e291822608110349f0a590ef7a47d57b01ecc6a68` |
| `03_araul_missing_beat_bishoujo_v2.png` | `b7f12d25affa82a60d8e70842b9f142764369a8ffda240664587982663cddb44` |

**승격 경로: 저장소 루트 `art_sources/araul_prologue/`.**
`godot/assets/` 아래에 두면 Godot이 임포트하여 익스포트 패키지까지 따라 들어가므로,
런타임이 쓰지 않는 원본 3장(약 9MB)이 빌드에 실린다. 루트 밖에 두면 임포트 자체가
일어나지 않는다. 굳이 `godot/assets/.../sources/`를 쓰려면 익스포트 제외 필터 등재가
동반되어야 한다.

v2 최종 플레이트 원본은 `art_sources/araul_prologue/final_rev5/`에 남기고 매니페스트에
체크섬을 기록했다. **이후 모든 편집은 이 1672×941 원본에서만 시작한다.**

---

## 1. 최종 타임라인 (48.0초)

| 시각 | 플레이트 | 대사/사건 | 오디오 |
|---|---|---|---|
| 0.0–0.8 | 페이드인 | — | 북 1회 |
| 0.8–4.2 | **A1** | 내레이션 | |
| 4.2–7.4 | A1 | 해원 ① | |
| 7.4–11.2 | A1 | 해원 ② | |
| 11.2–12.6 | A1→**A2** | 신주 출현 | **덕 시작** |
| 11.8–15.0 | A2 | 제관 | |
| 15.0–16.2 | A2→**A3** | 신주 균열·검은 기운 | |
| 15.6–18.4 | A3 | 한미량 ① | |
| 18.4–19.6 | A3→**B1** | 카메라 전환 | |
| 19.6–22.4 | B1 | **무대사** (저항) | **21.6–23.4 완전 무음** |
| 22.4–23.6 | B1→**B2** | 입에서 구체 | |
| 23.0–26.0 | B2 | 해원 ③ | 복귀 램프 |
| 26.0–27.4 | B2→**C1** | 구체 부양 | |
| 27.4–29.6 | C1 | **무대사** (여덟 줄기) | 추가 레이어 |
| 29.6–30.8 | C1→**D1** | 제관 폭주 | |
| 30.2–33.0 | D1 | 한미량 ② | |
| 33.0–34.0 | D1→**D2** | 타격 | 방울 1회 |
| 33.4–36.2 | D2 | 해원 ④ | |
| 36.2–39.4 | D2 | 해원 ⑤ | |
| **39.4–39.9** | D2 | **무자막 여백 (0.5초)** | |
| **39.9–42.4** | D2 | **경과 자막 1행 (2.5초)** | |
| **42.4–45.0** | D2 | **경과 자막 2행 (2.6초)** | |
| **45.0–47.5** | 챕터 카드 | 중앙 (2.5초) | |
| **47.5–48.0** | 자연 페이드 | — | |

경과 자막은 **두 문장을 동시에 띄우지 않고 순차 표시**한다. 한 화면에 2줄을 같이
띄우면 영어 기준 21단어를 한 번에 읽어야 해서 §2.0 예산을 통과할 수 없다.
총 길이를 짧게 맞추려고 독해 시간을 깎지 않는다 — 재감상자는 첫 프레임부터 즉시
스킵되므로 반복 부담이 없다.

- 스킵 락: 최초 감상 1.2초, 재감상 0초 (현행 유지).
- 재생 게이트: 캐릭터 선택 확정 시 매번 (현행 유지).
- **11.2초 전까지 "공"이라는 단어가 등장하지 않는다.** 아직 존재하지 않기 때문.

---

## 2. 7언어 대사표

### 2.0 자막 독해 예산 — CPS 규칙 (신설, 씰 대상)

⚠️ **창 길이는 7언어가 공유한다.** 따라서 긴 로케일에 맞춰 시간을 늘리면 한국어
사용자가 다른 언어의 장황함을 대신 지불한다. 규칙은 반대 방향이어야 한다.

> **창 길이는 한국어 원문 호흡으로 고정한다. 예산을 초과하는 로케일은 그 로케일의
> 문장을 줄인다.**

예산(자막 업계 표준 CPS = 초당 표시 글자수, 공백 포함):

| 문자 계열 | 상한 |
|---|---|
| 라틴·키릴 (en · es · pt-BR · ru) | **22 CPS** |
| CJK (ko · ja · zh) | **12 CPS** |

WPM이 아니라 CPS를 쓰는 이유는 CJK가 같은 정보를 훨씬 적은 글자로 담기 때문이다.
현재 N행 실측이 그 차이를 보여준다 — 3.4초 창에서 es 28.8 · pt 25.9 · en 25.6 ·
ru 23.2 CPS인데 ko는 9.7 CPS다. **영어는 최악의 경우가 아니다.**

⚠️ **씰로 잠근다.** `stage1_han_miryang_prologue_smoke.gd`에 다음을 추가한다.

- 모든 (로케일 × 대사) 조합에 대해 `len(text) / (end - start)`를 계산하고 위 상한을
  넘으면 **실패**시킨다. 실패 메시지에 로케일·행·실측 CPS를 찍는다.
- 경과 자막 2행과 챕터 카드도 같은 검사에 포함한다.
- 이 씰이 있으면 이후 카피를 고쳐도 독해 예산이 조용히 깨지지 않는다.

아래 표는 **rev4에서 84개 조합 전수 검산을 통과한 확정본**이다. rev3의 17개 초과
(N·H2·P의 es·pt·ru, H5의 en·es·pt·ru, 경과 자막의 es·pt)는 전부 축약했다.
이후 카피를 고칠 때는 반드시 씰을 다시 통과시킨다.

⚠️ **축약 시 의미 핵을 떨어뜨리지 말 것.** rev4 검토에서 실제로 걸린 사례:
`funeraria` / `funerária` / `Поминальная`(신주=제사용 위패)를 빼면 "살아 있는 사람의
위패"라는 사건 자체가 전달되지 않는다. 길이를 줄이려면 수식어가 아니라 **문장 끝의
의문·부연**을 자른다.

화자 표시명:

| 로케일 | 내레이션 | 해원 | 제관 | 한미량 |
|---|---|---|---|---|
| ko | 내레이션 | 여왕 해원 | 제관 | 한미량 |
| en | NARRATION | QUEEN HAEWON | RITUAL OFFICIANT | HAN MIRYANG |
| zh | 旁白 | 海元女王 | 祭官 | 韩美良 |
| ja | 語り | 女王ヘウォン | 祭官 | ハン・ミリャン |
| es | NARRACIÓN | REINA HAEWON | OFICIANTE | HAN MIRYANG |
| pt-BR | NARRAÇÃO | RAINHA HAEWON | OFICIANTE | HAN MIRYANG |
| ru | РАССКАЗЧИК | КОРОЛЕВА ХЭВОН | ЖРЕЦ | ХАН МИРЯН |

### 대사 9줄

**N — 내레이션**
- ko 옛 왕조가 무너진 뒤, 신의 소리를 듣던 여인이 왕좌에 올랐다.
- en The old dynasty fell. A woman who heard the divine voice took the throne.
- zh 旧王朝覆灭之后，一位能听见神灵之声的女子登上了王座。
- ja 旧き王朝が滅びた後、神の声を聞く一人の女が王座に就いた。
- es Cayó la antigua dinastía. Una mujer que oía espíritus subió al trono.
- pt-BR Caiu a antiga dinastia. Uma mulher que ouvia espíritos subiu ao trono.
- ru Старая династия пала. Женщина, слышавшая духов, взошла на трон.

**H1 — 해원**
- ko 오늘부터 이 땅의 이름은 아라울이다.
- en From this day forth, this land shall be called Araul.
- zh 从今日起，这片土地名为——阿罗蔚。
- ja 今日より、この地の名は——アラウル。
- es Desde hoy, esta tierra se llamará Araul.
- pt-BR A partir de hoje, esta terra se chamará Araul.
- ru С этого дня эта земля зовётся Араулом.

**H2 — 해원**
- ko 아라울은 피로 세운 나라가 아니다. 목숨 대신 승부로 결판내는 법을 세우겠다.
- en Araul was not founded in blood. Contests, not lives, shall settle it.
- zh 阿罗蔚并非以鲜血立国。我要立下法度——不以性命，而以胜负定高下。
- ja アラウルは血で建てた国ではない。命ではなく、勝負で競う法を立てる。
- es Araul no nació de la sangre. Las disputas se resolverán con duelos, no con vidas.
- pt-BR Araul não nasceu do sangue. Disputas serão resolvidas em duelos, não com vidas.
- ru Араул основан не на крови. Споры решат состязания, а не жизни.

**P — 제관**
- ko 살아 계신 전하의 신주가…… 어찌 이곳에…….
- en Her Majesty's memorial tablet... while she still lives... how?
- zh 陛下尚在人世，灵位怎会出现在此……
- ja ご存命の陛下の位牌が……なぜ、ここに……。
- es ¿La tablilla funeraria de Su Majestad… si aún vive?
- pt-BR A tabuleta funerária de Sua Majestade… e ela vive?
- ru Поминальная табличка Её Величества… но она жива?

**M1 — 한미량**
- ko 전하, 물러서십시오!
- en Majesty, stand back—!
- zh 陛下，请退后——！
- ja 陛下、お下がりください——！
- es ¡Majestad, apartaos!
- pt-BR Majestade, afaste-se—!
- ru Государыня, отойдите—!

**H3 — 해원** (침묵을 깨는 첫 대사)
- ko 내 몸에서 나가라.
- en Get out—of my body.
- zh 从我体内——出去。
- ja 我が身から——出よ。
- es Sal—de mi cuerpo.
- pt-BR Saia—do meu corpo.
- ru Изыди—из моего тела.

**M2 — 한미량** (호위들의 발도를 막으며)
- ko 그분을 베지 마십시오. 령이 사람을 숙주로 삼았습니다.
- en No blades—the spirit has taken him as its host.
- zh 不可挥刀——恶灵正以他为宿主。
- ja あの方を斬ってはなりません——霊が人を宿主にしています。
- es ¡No lo cortéis! El espíritu lo ha tomado como huésped.
- pt-BR Não o cortem—o espírito o tomou como hospedeiro.
- ru Не рубите — дух сделал его своим носителем.

**H4 — 해원** (한미량에게)
- ko 사람은 남겨라. 깃든 것만 쳐내라.
- en Spare the man. Strike only what dwells within.
- zh 留下此人。只击出附身之物。
- ja 人は残せ。宿りしものだけを打て。
- es Salva al hombre. Golpea solo lo que habita dentro.
- pt-BR Preserve o homem. Golpeie apenas o que habita dentro.
- ru Пощадите человека. Бейте лишь то, что засело внутри.

**H5 — 해원**
- ko 령을 쳐서 공으로 되돌리는 이 승부를 환격전이라 칭한다.
- en Strike the spirit back into the sphere. I name this Hwangyeokjeon.
- zh 击灵，使其归于球中——此赛，名为环击战。
- ja 霊を打ち、球へと返すこの勝負——環撃戦と称する。
- es Golpear al espíritu y devolverlo a la esfera. Lo llamo Hwangyeokjeon.
- pt-BR Golpear o espírito e devolvê-lo à esfera. A isto chamo Hwangyeokjeon.
- ru Бить духа и возвращать в сферу. Нарекаю это Хвангёкчоном.

수신자 수 일관성 메모: M2는 호위들을 향하지만 **비인칭 문형**으로 통일해 언어별
2인칭 수 문제를 회피했다. H4는 한미량 한 사람을 향하므로 단수 명령형이다. es는 왕실
경어로 vos/vosotros 계열을 쓰는 기존 출고 톤을 유지한다. pt-BR은 유럽식·고어식
혼용(afastai-vos / cortardes / Deixem)을 전부 브라질 표준으로 통일했다.

### 경과 자막 (순차 2행 — 1행 39.9–42.4 / 2행 42.4–45.0)

⚠️ 두 행을 **동시에 띄우지 않는다.** 각 행이 자기 창을 단독으로 쓴다.

| 로케일 | 1행 | 2행 |
|---|---|---|
| ko | 여덟 줄기는 그날 밤 팔도로 사라졌다. | 3년 뒤, 환격회가 첫 줄기의 행방을 찾았다. |
| en | That night, eight beams fled to the Eight Provinces. | Three years on, the Hwangyeokhoe tracked the first. |
| zh | 那一夜，八条光芒散入八道。 | 三年之后——环击会寻得了第一条光芒的下落。 |
| ja | 八条の光は、その夜、八道へと消えた。 | 三年の後——環撃会が、最初の一条の行方を掴んだ。 |
| es | Esa noche, ocho rayos huyeron a las Ocho Provincias. | Tres años después, el Hwangyeokhoe halló el primero. |
| pt-BR | Naquela noite, oito raios sumiram nas Oito Províncias. | Três anos depois, o Hwangyeokhoe encontrou o primeiro. |
| ru | В ту ночь восемь лучей унеслись в Восемь Провинций. | Три года спустя — Хвангёкхве напал на след первого. |

### 타이틀 / 챕터 카드

| 로케일 | 타이틀 (상시) | 챕터 카드 (45.0초) |
|---|---|---|
| ko | 아라울의 첫 승부 | 제1장 — 왕의 몸에 깃든 것 |
| en | The First Contest of Araul | CHAPTER I — WHAT DWELT IN THE QUEEN'S BODY |
| zh | 阿罗蔚的第一战 | 第一章 — 女王体内之物 |
| ja | アラウルの最初の勝負 | 第一章 — 王の身に宿りしもの |
| es | El primer duelo de Araul | CAPÍTULO I — LO QUE MORÓ EN EL CUERPO DE LA REINA |
| pt-BR | A primeira disputa de Araul | CAPÍTULO I — O QUE HABITOU O CORPO DA RAINHA |
| ru | Первое состязание Араула | ГЛАВА I — ТО, ЧТО ВСЕЛИЛОСЬ В ТЕЛО ГОСУДАРЫНИ |

⚠️ en·es·ru 챕터 카드는 길어서 중앙 카드가 **2줄 wrap을 수용**해야 한다. 레이아웃이
1줄 전제로 짜여 있으면 잘린다.

스킵 힌트는 현행 문자열 유지.

**표기 고정:** ja `環撃戦` / zh `环击战`. 還擊戰(反击战) 표기 금지 — 중국어에서
일반명사 "반격전"으로 읽혀 고유명사성이 사라진다. 현행 커밋의 zh `还击战`은 이번
개정에서 `环击战`으로 교정한다.

---

## 3. 캐릭터 고정 사항 (전 플레이트 공통)

**한미량** — 커밋된 `bishoujo_v2` 3장 및 `godot/assets/ui/character_live2d/` 출고
아트와 동일 인물로 읽혀야 한다. 감청 배자 · 백색 소매 · 주름치마 · 홍색 대와 금장식 ·
흰 꽃과 홍색 술 머리장식 · 청안.
⚠️**장비 좌우 고정: 방패는 왼팔, 명두(법구)는 오른손.**
근거 = `battle_smasher_sprite_paths.gd` 주석 "좌 접촉 = 왼팔 방패 배시 / 우 접촉 =
오른손 법구 오버헤드 스매시". 커밋된 키아트도 이 좌우를 지키고 있다.
⚠️**검·도 계열 소지 금지.** 그녀의 키트에 검은 존재하지 않는다.

**해원** — 커밋된 플레이트의 예복·왕관을 계승. 단 **채(방망이)는 전 플레이트에서
삭제**한다. v2에는 타구 행위가 없다.

**제관** — 커밋된 플레이트 3에서 제단 옆에 손을 든 흑색 관복 인물. A2의 발견자,
D1의 숙주, D2의 회복자가 **동일 인물**이어야 한다.

---

## 4. 플레이트 8장

신규 생성 3장(A1·B1·D1) + 결정적 파생 5장(A2·A3·C1·B2·D2).
전부 **§0에서 승격한 1672×941 원본**에서 작업 후 **한 배치**로 Real-ESRGAN
`realesr-animevideov3` 2배.

### 4.0 생성 방식 공통 규칙

⚠️ **프롬프트의 `EXACTLY`는 픽셀을 잠그지 않는다.** 이미지 편집 모델은 지시와 무관한
영역도 미세하게 다시 그린다. 따라서 **모든 편집 결과물은 받은 뒤 허용 마스크 밖을
원본 픽셀로 복원하는 결정적 합성을 거친다.** A1도 예외가 아니다 — A1은 "신규"로
분류되지만 실제로는 플레이트 3의 편집본이므로 같은 복원 단계를 밟는다. 지난 슬라이스
에서 편집-단독 제거안이 전역 드리프트로 실패하고 마스크 합성으로 내려간 전례가 있다.

⚠️ **B1·D1은 참조 이미지를 입력으로 넣는다.** B1은 해원 참조, D1은 한미량 참조와
동일 제관 참조. 텍스트 프롬프트만으로는 얼굴·복식이 드리프트한다.

### 4.1 A1 — 즉위식 광각 【플레이트 3 편집 + 결정적 복원】

베이스: `03_araul_missing_beat_bishoujo_v2.png` (1672×941 원본).

```
Edit this image. Keep the camera, architecture, curtains, night sky, crowd,
lighting and the warrior girl at the right edge as they are.

REMOVE: the memorial tablet and its teal spirit flames at the center; the
glowing sphere and its cyan trail in the lower area; the long mace/club held
by the queen.

REPAINT the queen only: she stands upright before the throne in her layered
red-black-gold robe and crown, BOTH HANDS EMPTY, arms relaxed at her sides,
addressing the court. Calm, commanding, no distress.

The central altar area becomes plain dark hall interior with candle stands,
slightly darker than the surrounding hall. Nothing bright or attention-drawing
there.

Style: Japanese bishoujo game CG, clean anime lineart, 2D cel shading, simple
hair rendering. Output 1672x941, identical framing.
```

편집 후 **복원 마스크**: 아래 영역만 편집본을 채택하고 나머지는 베이스 픽셀로 되돌린다.
실제 산출에 사용한 4개 hard rect를 계약으로 삼는다(끝 좌표 exclusive).

- `x 0.40–0.68, y 0.00–0.66` → `(668,0)–(1137,622)`
- `x 0.16–0.44, y 0.08–0.94` → `(267,75)–(736,885)`
- `x 0.10–0.26, y 0.42–0.76` → `(167,395)–(435,716)`
- `x 0.32–0.74, y 0.56–1.00` → `(535,526)–(1238,941)`

1672×941에서 변경 845,928px, 합집합 밖 변경 0px다. 넓어 보인다는 인상만으로
마스크를 축소하거나 A1을 재생성하지 않는다.

### 4.2 A2 — 신주 출현 【A1 파생】

A1에 플레이트 3의 신주·청록 영기를 **그대로 이식**(마스크 합성).
허용 변경 영역: **x 0.40–0.68, y 0.00–0.66**. 그 밖 델타 0.

### 4.3 A3 — 신주 균열·검은 기운 【A2 파생】

신주에 세로 균열, 갈라진 틈에서 검은 기운 한 줄기가 해원 쪽으로 뻗는다.
해원은 아직 반응 전(자세 불변), **얼굴 표정만 국소 변경 허용**.
허용 변경 영역: 신주 `x 0.40–0.68, y 0.00–0.66` + 기운 통로 `x 0.28–0.44,
y 0.18–0.52` + 해원 얼굴 `x 0.28–0.36, y 0.16–0.26` + 얼굴과 기운 통로 사이의
연결부 `x 0.36–0.40, y 0.159–0.18`. 그 밖 델타 0. 연결부는 실제 페더 경계 291px을
포함하며, 누락하면 올바른 산출도 거짓 RED가 된다.

### 4.4 B1 — 해원의 저항 【신규 + 해원 참조 필수】

```
Japanese bishoujo game CG, clean anime lineart, 2D cel shading.
Match the attached reference for the queen's face, crown and robe exactly.

Medium shot, strong backlight. A queen in a layered red-black-gold ceremonial
robe and tall gold crown, long black hair. Black spirit vapor coils around her
torso and throat. She is in pain but STANDING — one hand gripping the throne
arm, refusing to kneel. Jaw set, eyes open and defiant, not fainting.

Dark palace interior behind her, candles far out of focus, deep blue night
palette with warm rim light from the left.

No blood, no wet or grotesque detail. Output 1672x941.
```

카메라는 A 패밀리보다 확실히 가까워야 한다(전환이 읽혀야 함).

### 4.5 B2 — 구체 배출 【B1 파생】

B1에 입에서 청록 구체가 반쯤 빠져나온 상태를 추가.
⚠️**역광 실루엣 처리. 젖은 묘사·구토 표현·입안 디테일 금지.** 빛나는 구체가 목과
입을 지나 밀려 나오는 영적 신체공포로만 읽혀야 한다.
결정적 마스크: 중심 `(0.535, 0.30)`, 반경 `(0.13, 0.20)`, 내부 완전 채택 비율 `0.72`인
타원. 페더는 타원 **안쪽에서만** 끝나며, 그 밖은 B1과 델타 0이다. 이 범위가 얼굴
하단·목·구체와 직접 헤일로를 함께 감싼다.

### 4.6 C1 — 여덟 줄기 확산 【A1 파생 + 국소 재작화】

A1의 카메라·건축·군중·한미량을 계승. 해원과 제관 영역만 재작화하고 광원을 추가한다.
- 청록 구체가 제단 위 허공에 부양.
- 거기서 **굵은 여덟 줄기**가 서로 다른 방향으로 궁 밖을 향해 뻗는다.
- 동시에 **작은 불씨 수십 개**가 실내로 흩어진다. 그중 하나가 제관 쪽으로 향한다.
- 해원은 탈진했으나 선 자세. 무릎 꿇지 않는다.

⚠️**이 플레이트만 전역 변경이 허용된다.** 광원이 화면 전체를 지나므로 "허용 rect 밖
델타 0" 기준을 적용하지 않는다. 대신 1672×941 원본에서 다음 두 계약을 함께 검사한다.

1. **양(+) 합성:** 모든 픽셀·RGB 채널에서 `C1 >= A1`. 채널 감소 픽셀이 0이어야 한다.
   A1의 기하와 실루엣을 지우거나 옮기지 않고 빛만 더했다는 결정적 증거다.
2. **정확히 여덟 광선:** 구체 중심 `(735,485)`에서 반경 180px·240px, 두께 ±2px의
   원환을 1도 간격으로 샘플링한다. 아래 효과 마스크에 해당하는 각도 띠를 구하고,
   2도 이하의 틈만 닫은 뒤 폭 3도 미만 잡음을 버린다. 두 원환 모두 정확히 8개여야 하며
   중심각은 `[14,38,95,145,168,203,268,350]`의 각 항목에서 ±6도 이내여야 한다.
   335도 부근의 아홉 번째 가지는 금지한다.

원래 산출은 335도 가지까지 굵은 광선으로 검출되어 9개였고 같은 씰에서 RED였다.
A1을 tapered capsule로 국소 복원한 최종 C1은 180px 원환
`[14,41,96,146,168,202,268,350]`, 240px 원환
`[13,39,95,146,170,204,270,350]`으로 통과한다. 인접 350도 광선은 보존한다.

휘도 검사는 **양방향 조건**으로 둔다. 단순히 "C1 평균 휘도 > A1"만 보면 화면 전체
노출을 올려버린 잘못된 결과도 통과한다.

⚠️ **`b > r && g > r` 단독 마스크는 쓰면 안 된다.** 이 장면의 배경 자체가 검푸른
야간색이라 효과가 전혀 없는 플레이트도 대부분이 청록으로 잡힌다. v2 실측:

| chroma_margin | 신주 없는 판 | 신주 있는 판 | 분리도 |
|---|---|---|---|
| 0 | **59.2%** | **60.1%** | 0.9%p — 무의미 |
| 8 | 36.4% | 41.1% | 4.7%p |
| 16 | 10.7% | 15.5% | 4.8%p |
| 24 | 2.2% | 6.2% | 2.8× |
| **32 (채택)** | **0.9%** | **3.9%** | **4.3×** |
| 48 | 0.2% | 2.0% | 10× |

(커밋된 `bishoujo_v2` 2장을 A1/C1 대용으로 실측. 실제 C1은 여덟 줄기 + 불씨 수십으로
효과량이 훨씬 크므로 아래 기준은 보수적이다.)

**마스크 정의** — 비교 대상에 따라 조건 수가 다르다.

```
# 공통 색차 조건 (chroma)
px.b > px.r + CHROMA_MARGIN
px.g > px.r + CHROMA_MARGIN

# A1 기준 청록량  : 색차 조건 2개만 적용 (A1 vs A1 델타는 정의되지 않는다)
# C1 신규 효과량  : 색차 조건 2개 + 아래 델타 조건
max(abs(C1.rgb - A1.rgb)) >= DELTA_THRESHOLD
```

⚠️ **`32`과 `24`는 8비트 채널값(0~255) 기준이다.** Godot `Color`는 0.0~1.0 정규화
값이므로 GDScript QA·런타임에서는 반드시 변환해서 쓴다.

```gdscript
const CHROMA_MARGIN := 32.0 / 255.0
const DELTA_THRESHOLD := 24.0 / 255.0
```

⚠️ **여유가 크지 않다.** 위 실측표의 4.3배는 양쪽 모두 색차 조건만으로 센 값이다.
C1에만 델타 조건을 추가하면 A1과 겹치는 배경 청록(0.9%)이 빠져 신규 효과량이
약 3.0%가 되고, 배수는 **약 3.3배**로 좁혀진다 — 임계 3배에 거의 붙는다.
다만 이 실측은 신주 1개짜리 대용 플레이트 기준이고 실제 C1은 여덟 줄기 + 불씨
수십이라 훨씬 여유가 있어야 정상이다. **실제 C1이 3배에 미달하면 임계를 낮추지 말고
광선의 채도·휘도가 충분한지를 먼저 의심할 것.** 그게 이 검사가 잡으려는 실패다.

**판정**

1. **효과가 실제로 들어갔는가** — **C1 신규 효과량**(색차 + 델타)이 **A1 기준
   청록량**(색차만) 대비 **3배 이상**이고, 동시에 **전체의 2% 이상**일 것.
   상대·절대 두 조건을 모두 건다 (A1이 유난히 어두우면 상대 배수만으로는 통과가
   쉬워진다).
2. **전역 노출을 올린 게 아닌가** — 효과 마스크를 **폭의 5%만큼 팽창**시켜 빛이 닿는
   주변부까지 제외한 뒤, 남은 **원거리 중립 영역**의 평균 휘도가 A1 대비
   **±3% 이내**일 것.
3. **중립 영역이 유효한 표본인가** — 팽창 후 남은 중립 영역이 **화면의 15% 이상**일 것.
   미만이면 2번 검사가 공집합에 가까워 무의미하므로 **판정 불가로 실패** 처리한다.

2번이 역조건이다. 팽창을 두는 이유는 여덟 줄기가 기둥과 바닥을 실제로 비추므로
인접부의 밝아짐은 정상이기 때문이다.

최종 C1 실측은 신규 효과 10.789%, A1 대비 87.95배, 중립 표본 30.444%, 중립 휘도
변화 +0.003%, 채널 감소 0px다.

### 4.7 D1 — 대치 【신규 + 한미량·제관 참조 필수】

```
Japanese bishoujo game CG, clean anime lineart, 2D cel shading.
Match the attached references for the warrior woman and for the ritual
official's face and robes exactly.

Medium two-shot inside a dark palace hall at night.

LEFT: the same ritual official in black court robes, possessed — eyes glowing
pale teal, dark veins spreading from his collar, body twisted mid-lurch.

RIGHT: the warrior woman — navy sleeveless vest over white long sleeves, navy
pleated skirt with white and red panel, red sash with gold ornament, black
ponytail with a white flower and red tassel ornament, blue eyes.
Her LEFT arm holds a round demon-mask shield thrust sideways, BLOCKING two
palace guards behind her who are drawing their swords. Her RIGHT hand holds a
bronze ritual mirror on a staff, lowered and ready.
She carries NO sword of her own.

BETWEEN the two figures floats a pale, spent sphere — dim, drained of light.

Deep blue night palette, warm candle rim light. Output 1672x941.
```

### 4.8 D2 — 최초의 격령 【D1 파생】

- 명두가 공을 때린 순간. 공이 제관에게 닿는다.
- 제관에게서 **령편**(청록 파편)이 튀어나와 공으로 빨려 들어간다.
- ⚠️**제관의 자세·실루엣·의복은 불변.** 눈의 발광과 검은 핏줄은 **소멸**하고, 얼굴의
  긴장이 풀리는 정도만 국소 변경한다. "숙주인 사람은 남겼다"가 화면에서 증명되어야 한다.
- 호위와 방패의 배치는 불변.

결정적 마스크는 기존 타격 연출 2개, 최종 국소 정리 2개, 오른손 장갑 복원 1개로
총 5개 타원의 합집합이다.

- 제관 회복: 중심 `(0.235, 0.30)`, 반경 `(0.135, 0.28)`, 내부 비율 `0.74`.
- 공·령편·명두의 타격 호: 중심 `(0.47, 0.52)`, 반경 `(0.17, 0.25)`, 내부 비율 `0.74`.
- 명두·손 국소 정리: 중심 `(0.492, 0.705)`, 반경 `(0.070, 0.150)`, 내부 비율 `0.84`.
- 자루 국소 정리: 중심 `(0.476, 0.855)`, 반경 `(0.050, 0.145)`, 내부 비율 `0.84`.
- 오른손 장갑 복원: 중심 `(0.505, 0.685)`, 반경 `(0.075, 0.135)`, 내부 비율 `0.78`.

최종 편집 donor는 1671×941 출력의 오른쪽 끝 1열을 복제해 1672×941로 패딩했고,
`art_sources/araul_prologue/donors/d2_single_myeongdu_edit_exec-29e85642_padded.png`에
승격했다. 장갑 donor는
`art_sources/araul_prologue/donors/d2_gauntlet_edit_exec-b670ac5a.png`에 승격했고,
다섯 페더 모두 경계 안쪽에서 0으로 끝나며 합집합 밖은 D1과 델타 0이다.
최종 D2에는 공과 분리된 명두가 시각적으로 하나만 보인다. 피부를 청동색으로 오인하는
단순 RGB connected-component 검사는 수용 씰로 쓰지 않는다.

---

## 5. 오디오

| 시각 | 큐 |
|---|---|
| 0.0 | 북 1회 |
| 11.2 | BGM 게인 덕 시작(신주 출현) |
| 21.6–23.4 | **완전 무음** |
| 23.4–26.5 | 복귀 램프 |
| 27.4 | 여덟 줄기 확산 — **추가 레이어 1장** |
| 33.4 | 방울 1회(령편 배출) |

- ⚠️27.4초의 "고조"는 **사용자 BGM 설정 이상으로 게인을 올리지 않는다.** 별도 충격음
  또는 얇은 추가 레이어로 처리한다.
- 구현은 2단 덕·무음·복귀와 별도 `opening_drum` / `rays` / `spirit_bell` 큐를 사용한다.
  과거 `missing_beat` 메서드는 남기지 않는다.
- 공용 공(gong) 플레이어를 재사용하는 북 큐는 재생 뒤 `pitch_scale`을 복구한다. 그렇지
  않으면 같은 플레이어를 쓰는 스테이지 클리어 음이 0.72 피치로 오염된다.

---

## 6. 스트리밍 / VRAM 계약

3344×1882 BPTC + 밉맵 = 장당 약 8.4MB. **3장 25MB → 8장 67MB.**

현행 `stage1_han_miryang_prologue_presentation.gd`는 다음 4항을 구현한다.

1. **시작 전 프리웜 목록에는 A 패밀리(A1·A2·A3)만 등록한다.** B/C/D는 재생 중 확보.
2. **요청 시작 / 확보 마감**: B1 `0.0 / 12.0`, B2 `12.6 / 20.0`,
   C1 `16.2 / 22.0`, D1 `19.6 / 27.0`, D2 `23.6 / 30.0`초. 한 장을 끝낸 뒤
   다음 due 항목으로 진행하며, 아직 due가 아닌 요청은 열지 않는다.
3. **각 블렌드가 끝나는 즉시 이전 장을 개별 해제한다.** 정상 순서는
   `A1@12.6 → A2@16.2 → A3@19.6 → B1@23.6 → B2@27.4 → C1@30.8 → D1@34.0`이다.
   단, 후속 장이 늦거나 실패하면 직전 장을 fallback으로 유지하고, 그보다 뒤의 첫 성공
   장이 자기 전환을 끝낸 시점에 오래된 fallback까지 연쇄 해제한다. 정상·지연 경로의
   런타임 고유 플레이트 상주는 **최대 4장**이다.
4. **스킵·자연 종료·teardown 시 진행 중인 로드 요청의 결과를 폐기한다.** 공유 텍스처
   슬롯 트랩 준수 — 대기자는 자기 타임아웃 시계를 쓰고 소유자의 인플라이트를
   드레인하지 않는다.

⚠️ 마감을 놓치면 **동기 로드로 떨어지지 말고 직전 플레이트를 유지**한다. 이 금지는
회귀 씰로 봉인한다(§7-9).

---

## 7. 수용 기준

1. §0 원본 3장이 추적 경로로 승격되고 체크섬이 매니페스트에 기록되었을 것.
2. A2·A3·B2·D2가 각자의 **허용 변경 영역** 밖에서 델타 0. C1은 §4.6의 양(+) 합성,
   효과량·중립 휘도, 두 원환의 8광선 검사로 대체한다.
3. A1이 편집 후 **복원 마스크 밖은 베이스 픽셀과 완전 일치**할 것.
4. 순차 블렌드 오프라인 시뮬에서 A·B·D 각 패밀리 내부 인물이 흔들리지 않을 것.
5. D2에서 제관의 눈 발광·검은 핏줄이 **소멸**하고, 공과 분리된 명두가 하나만 보일 것.
   D1→D2 다섯 타원 밖 0px과 확대 crop/contact sheet를 함께 판정한다.
6. 한미량이 어느 플레이트에서도 **검을 들고 있지 않을 것**, 방패=왼팔 / 명두=오른손.
   D2의 오른손에는 D1과 같은 감청 장갑이 이어져야 한다. 해원이 어느 플레이트에서도
   **채를 들고 있지 않을 것**.
7. 8장 전부 3344×1882.
8. **7언어 전체** 1080p·1440p 실제 렌더 캡처. ja/zh 자막 잉크 단언에 더해, en·es·ru
   **챕터 카드 2줄 wrap이 잘리지 않는지** 확인한다. 영구 콘택트시트에는 pt-BR을 포함한
   7언어 1080p 자막, en·es·ru 1080p/1440p 챕터, D1/D2 비교, 최종 페이드를 남긴다.
9. 48.0초 자연 종료 레그 + 챕터 카드 중앙 표시 씰 + **B1을 마감 뒤까지 지연하는
   역검증**. 역검증은 A3 fallback 유지, B1만 deadline miss, 동기 로드 없음, 회복 뒤
   due 항목 catch-up과 순간 상주 최대 4장을 함께 잠근다.
10. **§2.0 CPS 씰 통과** — 모든 (로케일 × 행)이 라틴·키릴 22 CPS / CJK 12 CPS 이하.
    경과 자막 2행과 챕터 카드 포함.
11. `tools/validate_araul_prologue_asset_contract.ps1`가 승격 앵커·소스·런타임 SHA,
    해상도, 임포트 설정, A1/A2/A3/B2/D2 마스크와 C1 8광선 역검증을 실제 픽셀로
    완주할 것. 제작 중에는 `-SourceOnly`로 업스케일 전 소스 계약부터 검사할 수 있다.
12. **헤드리스 소유권 씰과 실제 스레드 QA를 분리한다.** 기본 smoke는 A1·A2·A3만
    동기 시드하고, B/C/D는 각 `request_at`에서
    작은 테스트 Texture2D를 그때 생성해 상태·타임라인·개별 해제·최대 4장·zero-leak을
    결정적으로 검사한다. 실제 8경로 `load_threaded_request/get`은
    `stage1_han_miryang_prologue_capture.gd -- --threaded-preflight-only`의 Vulkan 프로세스에서
    별도로 검사하며, 정확한 8경로 관측·요청 시각·deadline miss 0·실제 production-path
    presentation 상주 플레이트 peak 4·종료 시
    presentation/cache 참조 0을 단언한다. 자기 인플라이트 경로가 프로젝트 캐시나 엔진
    캐시에 먼저 노출되더라도 cache shortcut으로 빠지지 않고 반드시 terminal
    `load_threaded_get()`으로 회수한다. 수정 후 독립 Vulkan 프리플라이트 2회가 모두
    `exit 0`, `peak=4`,
    `observed=8`, `completed=5`, `deadline_misses=0`이며 ObjectDB 경고 없이 종료됐다.
    marker를 제거해 경고를 GREEN으로 위장하지 않으며, 깨끗한 시각 캡처는 프리플라이트
    없는 별도 프로세스로 생성한다.

---

## 8. 자산 처분

- 구형 3344 런타임 3장과 `araul_prologue_bishoujo_v2_manifest.json`은 rev5 수용 후
  런타임 권위를 잃었고, V3·rev6 수용 뒤 별도 정리 슬라이스에서 삭제했다.
- rev5 런타임 8장과 `.import` 8개도 같은 정리 슬라이스에서 제거했다. 1672×941
  원본 8장과 당시 매니페스트는 `art_sources/araul_prologue/final_rev5/`에 보존한다.
- `araul_missing_beat_keyart_bishoujo_v2.png`의 **구도·신주 요소만** §0의 1672 원본
  `03_...`을 통해 계승한다. 구형 3344 파일 자체는 런타임에서 계승하지 않는다.
- 미참조 v1 후보 2장과 `.import` 2개는
  `art_sources/araul_prologue/legacy_v1_runtime_archive/`로 비파괴 이동했다. 복구용
  SHA는 그 폴더의 `README.md`에 고정했으며 Godot 런타임·익스포트에는 포함하지 않는다.
- 정리 커밋은 V3 본체 `f95270ac9896`과 rev6 모션 `93fe02f6b922`가 먼저 성립한 뒤
  정확한 구형 경로만 제거하는 별도 슬라이스로 수행한다. 공유 WIP 파일은 포함하지 않는다.

---

## 9. 정본 문서 반영 결과

아래 항목은 `docs/araul_foundation_prologue_canon.md` v2에 반영됐다.

- §1 한 문단 — 빈 박 → 빙의·구체 배출·여덟 줄기·최초 격령.
- §2 확정 사실 — 위와 동일. 제관을 발견자 겸 최초 숙주로 명시.
- §3 팔주령 — **미정 → 확정**(1부 Stage 1~8의 여덟 령편).
- §6 연출 계약 — 3플레이트 38.0초 → 8플레이트 48.0초, 스트리밍 계약 4항, CPS 예산 규칙.

신설 반영:

- **숙주 개념** — 령은 인간·요괴·가면·신물·병기를 가리지 않고 숙주로 삼는다. 산 것과
  죽은 것을 구분하지 않는 이질성 자체가 령의 본성이다. 령은 그 존재가 원래 품은 욕망과
  힘을 폭주시킨다. 퇴마 후에도 숙주 본인의 악행과 개성은 남으므로
  면죄부가 아니다.
- **랠리·파진·실점의 퇴마적 의미** — 되받아치는 것은 숙주와 깃든 령이 겹친 존재. 파진 =
  영적 방어선이 깨져 령이 공 쪽으로 끌려 나옴. 실점 = 흐름이 역전되어 령이 더 깊이
  파고듦. 승리 = 핵심 령편을 공에 봉인. 듀스 = 추출과 재침식이 팽팽한 상태.
  ⚠️7점은 **환격회가 정립한 표준 퇴마 절차**이지 "한 숙주에 일곱 조각"이 아니다.
- **1부/2부 분할** — Stage 1~8 = 팔도의 여덟 령편 회수(1부). 완성된 팔주령이 봉인이
  아니라 저승·천상으로 향하는 열쇠였다는 반전으로 2부 개시. 2부 보스는 빙의 피해자가
  아니라 배후·수문장·상위 존재이며, **사천신(四天神)** 은 혼환을 이해하고 의도적으로
  되받아친다. ⚠️저장소의 후반 스테이지 번호는 플레이스홀더다(Stage 9 결번, 10=최종
  관문, 11=4천왕, 12=진엔딩) — 정본에는 숫자 대신 "1~8은 1부, 이후는 2부"로 기록한다.
- **어사화** — Stage 8 보상이 아니라 사천신·최종 관문까지 넘은 최종 승자에게 내리는
  왕실 증표.

대본·플레이트 수용과 함께 정본 개정을 완료했다.
