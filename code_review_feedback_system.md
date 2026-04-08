# 리플레이 피드백 시스템 코드리뷰 문서

> PingFighter 리플레이 + 피드백 시스템의 전체 코드 구조를 정리한 문서.
> Codex 또는 코드리뷰어가 전체 시스템을 파악할 수 있도록 작성됨.

---

## 1. 시스템 아키텍처 개요

```
┌──────────────────────────────────────────────────────────────────┐
│                    게임 플레이 (pingfighter.py)                    │
│                                                                    │
│  ┌──────────────┐   ┌──────────────────┐   ┌──────────────────┐  │
│  │ ReplayRecorder│   │PlayerSkillAnalyzer│   │  Sound Events   │  │
│  │  .capture()   │   │  .record_hit()   │   │  .add_sound()   │  │
│  │  .add_sound() │   │  .record_dash()  │   │                 │  │
│  └──────┬───────┘   └────────┬─────────┘   └────────┬────────┘  │
│         │                    │                       │            │
└─────────┼────────────────────┼───────────────────────┼────────────┘
          ▼                    ▼                       ▼
   ┌──────────┐        ┌───────────┐           ┌───────────┐
   │ .rpl 파일 │        │ PlayerStats│           │ metadata  │
   │ (프레임)  │        │ (통계 누적)│           │(sound_events)│
   └────┬─────┘        └─────┬─────┘           └─────┬─────┘
        │                    │                       │
        ▼                    ▼                       ▼
  ┌───────────┐     ┌────────────────────────────┐  ┌──────────────────┐
  │ Replay    │     │ get_detailed_feedback()     │  │ _analyze_replay()│
  │ Viewer UI │     │  ├─ LiteraryFeedbackSystem  │  │ (메타데이터 분석) │
  │           │     │  │  (우선: 문학적 서사)       │  │                  │
  │           │     │  └─ feedback_system.py       │  │                  │
  │           │     │     (폴백: 등급별 텍스트)      │  │                  │
  └─────┬─────┘     └────────────┬───────────────┘  └────────┬─────────┘
        │                       │                           │
        ▼                       ▼                           ▼
  ┌─────────────────────────────────────────────────────────────┐
  │              피드백 표시 (2가지 경로)                          │
  │                                                              │
  │  경로 A: 리플레이 뷰어 → _show_replay_feedback()              │
  │          (사운드 이벤트 기반 사후 분석)                         │
  │                                                              │
  │  경로 B: F키 오버레이 → get_detailed_feedback() → dict 반환    │
  │          LiteraryFeedbackSystem 우선, ImportError 시 폴백      │
  │          HUD는 feedback_data["skill_feedback"]만 렌더링        │
  └─────────────────────────────────────────────────────────────┘
```

---

## 2. 파일별 역할 및 코드 구조

### 2.1 `replay/replay_system.py` (703줄)

리플레이 녹화/재생/관리의 핵심 모듈.

#### 클래스: `ReplayRecorder` (L59-310)

```python
class ReplayRecorder:
    # 싱글톤 패턴 (get_recorder()로 접근)
    # 비동기 압축: 게임 루프에서는 screen.copy()만, 압축은 백그라운드 스레드

    def start(self, stage, boss_name, ai_mode, character, ...):
        # 녹화 시작. 백그라운드 압축 스레드 생성 (클로저 기반)
        # _writer() 클로저가 deque에서 raw 프레임을 꺼내 zlib 압축 후 파일에 쓰기

    def capture(self, screen: pygame.Surface):
        # 매 프레임 호출. screen → tostring → deque에 push
        # MAX_PENDING_FRAMES(300) 초과 시 프레임 스킵
        # MAX_DURATION(600초=10분) 초과 시 자동 중지

    def add_sound(self, sound_id: str, volume: float | None = None):
        # 사운드 이벤트를 현재 캡처 프레임에 기록
        # {프레임번호: [sound_id, ...]} 또는 {프레임번호: [{id, volume}, ...]}

    def stop(self, result: str = "") -> bool:
        # 녹화 중지. 메타데이터 작성 후 _finalize_file()을 백그라운드에서 실행
        # 싱글톤 필드를 즉시 초기화하여 다음 start()가 안전하게 시작 가능

    @staticmethod
    def _finalize_file(file_handle, filepath, metadata) -> bool:
        # 메타데이터 pickle → 파일 끝에 기록
        # 파일명 변경: _recording_*.tmp → replay_s{stage}_{timestamp}.rpl
        # _cleanup_old_replays() 호출
```

#### 클래스: `ReplayPlayer` (L315-501)

```python
class ReplayPlayer:
    # 메모리 절약형 스트리밍 재생. 프레임 위치만 인덱싱, 재생 시 1프레임씩 디스크에서 읽기.
    SPEED_OPTIONS = [0.25, 0.5, 1.0, 1.5, 2.0, 4.0]

    def load(self, filepath: str) -> bool:
        # .rpl 파일 스캔 → 프레임 offset/size 인덱싱 (메모리에 데이터 안 올림)
        # 마지막 청크를 메타데이터로 해석 (pickle.loads)

    def advance(self):
        # 매 프레임(60fps) 호출. capture_fps에 맞춰 정속 재생
        # Returns (surface, (start_idx, end_idx)) — 사운드 재생용 범위
```

#### 메타데이터 관리 (L506-557)
```python
# replay_meta.json 기반 (커스텀 이름, 잠금 상태)
rename_replay(filename, new_name)
set_replay_locked(filename, locked)
is_replay_locked(filename) -> bool
get_replay_custom_name(filename) -> str
```

#### 유틸리티 (L562-690)
```python
list_replays() -> List[Dict]     # 모든 .rpl 파일 메타데이터 반환 (최신순)
delete_replay(filepath) -> bool  # 파일 + 메타 제거
_cleanup_old_replays()           # MAX_REPLAYS(10) 초과 시 잠금 안 된 가장 오래된 파일 삭제
                                 # 고아 .tmp 파일(10분↑), 이전 포맷 잔여 파일 정리
```

#### .rpl 바이너리 포맷
```
[4B] Magic: b'PFRP'
[4B] meta_len (메타데이터 크기, 파일 끝에서 역참조용)
[4B+data] 프레임 청크 (size + zlib 압축 데이터) × N
[4B+data] 메타데이터 청크 (size + pickle 직렬화)
```

#### 메타데이터 구조
```python
{
    'version': 4,
    'stage': int,           # 스테이지 번호
    'boss_name': str,       # 보스 이름
    'ai_mode': str,         # 난이도
    'character': str,       # 'smasher'|'viper'|'soldier'|'blacksmith'
    'result': str,          # 'win'|'lose'|''
    'duration': float,      # 녹화 시간(초)
    'total_frames': int,    # 캡처된 프레임 수
    'created_at': float,    # 타임스탬프
    'screen_w': 760, 'screen_h': 750,
    'scaled_w': 760, 'scaled_h': 750,
    'capture_fps': 60,
    'capture_mode': 'screen',
    'bgm_track': str,       # 배경음 트랙명
    'bgm_volume': float,
    'sfx_volume': float,
    'sound_events': {frame_idx: [sound_id_or_dict, ...]},  # 핵심!
    'dropped_frames': int,
}
```

---

### 2.2 `player_skill_analyzer.py` (1090줄)

실시간 플레이어 통계 수집, 등급 산출, **상세 피드백 생성의 진입점**.

#### 데이터클래스: `PlayerStats` (L13-87)
```python
@dataclass
class PlayerStats:
    # 기본 통계
    total_hits: int = 0
    total_misses: int = 0

    # 고급 통계
    perfect_timing_hits: int = 0   # ±3프레임 정밀 히트
    power_smash_success: int = 0
    skill_usage_count: int = 0

    # 대쉬
    dash_usage_count: int = 0
    dash_success_count: int = 0
    good_dash_count: int = 0       # 적절한 상황에서 사용

    # 아이템
    items_used_count: int = 0
    items_effective_count: int = 0
    item_types_used: List[str]     # 사용한 아이템 종류
    item_combo_count: int = 0

    # 가드
    successful_guards: int = 0
    defensive_saves: int = 0       # 위험 상황 구원
    close_call_recoveries: int = 0

    # 승부 결과
    perfect_victories: int = 0     # 3-0
    dominant_victories: int = 0    # 3-1
    close_victories: int = 0      # 3-2
    consecutive_losses: int = 0

    # 실수/페널티
    critical_misses: int = 0
    wasted_skills: int = 0
    wasted_dash: int = 0
    missed_opportunities: int = 0

    # 연속 성공/실패
    current_hit_streak: int = 0
    max_hit_streak: int = 0

    # 반응 시간 (최근 50개)
    reaction_times: deque
```

#### 클래스: `SkillRank` (L89-147)
6단계 등급 체계:

| 등급 | 최소 점수 | 아이콘 |
|------|----------|--------|
| 초보 (Beginner) | 0 | 🎯 |
| 주니어 (Junior) | 400 | 🔰 |
| 세미프로 (Semi-Pro) | 650 | ⭐ |
| 프로 (Pro) | 900 | 💎 |
| 챔피언 (Champion) | 1300 | 🏆 |
| 신 (God) | 1700 | 🌟 |

#### 클래스: `PlayerSkillAnalyzer` (L149-1084)

**기록 메서드** (게임 루프에서 호출):
```python
record_hit(is_perfect_timing, is_power_smash)  # 히트 기록 + 반응시간 계산
record_miss()                                   # 미스 기록
record_skill_usage(success)                     # 스킬 사용
record_dash_usage(ball_distance, ball_speed)     # 대쉬 사용 + 상황 분석
record_item_usage(item_name, was_effective)      # 아이템 사용
record_guard_action(ball_distance, ball_speed)   # 가드 성공
record_victory_result(player_wins, boss_wins)    # 승부 결과 (3-0, 3-1 등)
record_critical_miss()                           # 치명적 실수
record_wasted_skill()                            # 스킬 낭비
record_wasted_dash()                             # 대쉬 낭비
record_speed_adaptation(ball_speed)              # 고속 공 적응 보너스
```

**평가 메서드** (4가지 핵심 능력):
```python
get_skill_mastery_score() -> float    # 스킬 활용 능력 (0-100)
get_dash_mastery_score() -> float     # 대쉬 활용 능력 (0-100)
get_item_mastery_score() -> float     # 아이템 활용 능력 (0-100)
get_guard_ability_score() -> float    # 가드 능력 (0-100)
get_current_rank(stage) -> dict       # 종합 등급 산출
get_detailed_analysis(stage) -> dict  # 통계+업적+개선팁 (HUD 기본 뷰)
get_detailed_feedback(stage) -> dict  # 상세 피드백 (F키 오버레이용, 아래 참조)
```

**`get_detailed_feedback()` 상세 (L985-1064) — 실시간 피드백의 핵심 진입점**:

이 함수는 **dict를 반환** (str이 아님!):
```python
def get_detailed_feedback(self, current_stage=1) -> dict:
    try:
        from literary_feedback_system import LiteraryFeedbackSystem  # 우선 경로
        literary_system = LiteraryFeedbackSystem(self)
        # 4가지 능력 점수 계산 → 문학적 서사 생성
        return {
            "skill_feedback": format_feedback(skill_fb),   # 문학적 서사 텍스트
            "dash_feedback": format_feedback(dash_fb),
            "item_feedback": format_feedback(item_fb),
            "guard_feedback": format_feedback(guard_fb),
            "overall_feedback": literary_system.generate_epic_narrative(),
            "improvement_tips": literary_system.compose_journey_ahead(...)
        }
    except ImportError:
        # 폴백 경로: feedback_system.py의 등급별 텍스트 사용
        return {
            "skill_feedback": get_skill_feedback(score, grade),
            "dash_feedback": get_dash_feedback(score, grade),
            ...
        }
```

**우선순위 체인**: `LiteraryFeedbackSystem` → (ImportError 시) → `feedback_system.py`
`enhanced_feedback_system.py`는 이 경로에서 **호출되지 않음** (독립적인 분석 도구로만 존재).

**특이사항**:
- 캐릭터별 분석기 분리 (`player_analyzer_profiles` 딕셔너리)
- `_ensure_new_fields()`: 새 필드 추가 시 하위호환 보장 (기존 인스턴스에 동적 추가)
- 대쉬 상황 자동 분류: `ball_distance > 150 + ball_speed > 8` → `urgent_rescue`

---

### 2.3 `feedback_system.py` (463줄)

등급별 한글 피드백 텍스트 생성. 순수 함수 모듈 (상태 없음).

```python
get_skill_feedback(score, grade) -> str    # 스킬 피드백 (S/A/B/C/D/E/F 분기)
get_dash_feedback(score, grade) -> str     # 대쉬 피드백
get_item_feedback(score, grade) -> str     # 아이템 피드백
get_guard_feedback(score, grade) -> str    # 가드 피드백
get_overall_feedback(skill, dash, item, guard) -> str  # 종합 평가
get_improvement_tips(skill, dash, item, guard) -> str  # 맞춤형 개선 조언
```

**구조 패턴** (모든 함수 동일):
```python
def get_xxx_feedback(score: float, grade: str) -> str:
    if grade == "플레이 필요": return "대기 메시지"
    if grade == "S": ...     # 마스터 수준
    elif grade == "A": ...   # 뛰어남
    elif grade == "B": ...   # 양호
    elif grade == "C": ...   # 발전 가능
    elif grade in ["D","E"]: ... # 연습 필요
    else: ...                # F: 기초부터
    return feedback
```

**리뷰 포인트**:
- 마크다운 `**bold**` 구문 사용 → pygame에서 렌더링 시 raw 텍스트로 표시될 수 있음
- 이모지 사용 → 일부 폰트에서 깨질 수 있음
- grade "플레이 필요"는 문자열 비교 (enum이 아님)

---

### 2.4 `literary_feedback_system.py` (472줄) — **활성 경로**

**`get_detailed_feedback()`의 우선 경로.** 문학적 표현과 유머로 플레이어 실력을 서술.

```python
class LiteraryFeedbackSystem:
    def __init__(self, player_analyzer):
        self.analyzer = player_analyzer
        self.stats = player_analyzer.stats

    def get_skill_narrative(score, grade) -> dict:
        # {title, grade, narrative, highlights, growth, wisdom}
        # 점수 구간별 (90+, 70+, 50+, 30+, 0+) 서로 다른 문학적 서사 반환
        # 예: "당신의 손끝에서 번개가 춤춥니다..."

    def get_dash_narrative(score, grade) -> dict
    def get_item_narrative(score, grade) -> dict
    def get_guard_narrative(score, grade) -> dict

    def generate_epic_narrative() -> str      # 종합 서사
    def compose_journey_ahead(...) -> str     # 다음 목표 제안
```

**format_feedback()** (player_skill_analyzer.py L1013-1021에서 정의):
dict → 문자열 변환. `━━━ {title} ━━━\n🏆 등급: ...\n📖 이야기\n...` 포맷.

---

### 2.5 `enhanced_feedback_system.py` (577줄) — **비활성 경로 (독립 분석 도구)**

> **주의**: 이 모듈은 `get_detailed_feedback()` 체인에서 호출되지 않음.
> 독립적인 정밀 분석 도구로, `get_enhanced_feedback()` 함수를 통해 직접 호출해야 동작.
> 현재 런타임에서 이 모듈을 import하는 코드는 없음.

게임 메커니즘 기반 정밀 분석. `PlayerSkillAnalyzer` 인스턴스를 주입받아 동작.

#### 클래스: `EnhancedFeedbackSystem`

```python
class EnhancedFeedbackSystem:
    def __init__(self, player_analyzer):
        self.analyzer = player_analyzer
        self.stats = player_analyzer.stats

    # 각 카테고리별 상세 분석 (Dict 반환)
    def get_skill_detailed_feedback(score, grade) -> Dict:
        # {title, grade, metrics, strengths, weaknesses, tips}

    def get_dash_detailed_feedback(score, grade) -> Dict
    def get_item_detailed_feedback(score, grade) -> Dict
    def get_guard_detailed_feedback(score, grade) -> Dict

    # 종합 리포트 생성
    def generate_comprehensive_feedback() -> str:
        # 4가지 카테고리 분석 + 플레이 스타일 분석 + 다음 목표 제안
```

**분석 지표 예시 (스킬)**:
```python
perfect_ratio = (perfect_timing_hits / total_hits) * 100  # ±3프레임 정밀도
power_smash_ratio = (power_smash_success / skill_usage_count) * 100
skill_victory_ratio = (skill_victories / total_hits) * 100
```

**플레이 스타일 분류**:
| 최고 점수 영역 | 스타일 |
|---------------|--------|
| 스킬 | 🎯 테크니션 |
| 대쉬 | ⚡ 스피드스터 |
| 아이템 | 🎁 전략가 |
| 가드 | 🛡️ 수비수 |

**진입점 함수**:
```python
def get_enhanced_feedback(player_analyzer, current_stage=1) -> str:
    enhanced_system = EnhancedFeedbackSystem(player_analyzer)
    return enhanced_system.generate_comprehensive_feedback()
```

---

### 2.6 `pingfighter.py` 내 통합 코드

#### 2.6.1 리플레이 뷰어 UI (`show_replay_viewer()`, L123835-124006)

2패널 레이아웃:
- **좌측**: 리플레이 목록 (스크롤, 선택, 더블클릭 재생)
- **우측**: 썸네일 미리보기 + 정보 + 6개 버튼

```
┌─ 목록 (295px) ─┐ ┌─ 정보 패널 ──────────┐
│ replay_s1_... ▶│ │ [썸네일 미리보기]       │
│ replay_s2_...  │ │ Stage 1 - 풍악보이      │
│ replay_s3_...  │ │ 캐릭터: 스매셔           │
│                │ │ 시간: 2분 30초           │
│                │ │ 결과: 승리               │
│                │ │                          │
│                │ │ [▶재생] [✏이름변경]      │
│                │ │ [🔒잠금] [🗑삭제]        │
│                │ │ [📤내보내기] [📊피드백]   │
└────────────────┘ └──────────────────────────┘
```

**버튼 동작**:
- `play` → `_play_replay(filepath)` — 리플레이 재생 모드 진입
- `rename` → `_replay_rename_dialog()` → `rename_replay()`
- `lock` → `set_replay_locked()` — 자동 삭제 방지
- `delete` → 확인 다이얼로그 → `delete_replay()`
- `export` → `_export_replay_to_mp4()` — ffmpeg 기반 MP4 변환
- `feedback` → `_show_replay_feedback()` — **피드백 화면 진입**

**썸네일**: 비동기 로딩 (`threading.Thread`), `thumb_cache` 딕셔너리 캐시.

#### 2.6.2 리플레이 분석 (`_analyze_replay()`, L124277-124471)

```python
def _analyze_replay(replay_info: dict) -> list:
    """리플레이 메타데이터에서 캐릭터별 경기 분석 피드백 생성
    Returns: [(title, description, color_rgb), ...]
    """
```

**분석 파이프라인**:
1. `.rpl` 메타데이터 fast-read (프레임 데이터 디코딩 없음)
2. 사운드 이벤트 카운트 집계
3. 공통 지표 계산 (패들 히트, 대시, 아이템)
4. **캐릭터별 전용 분석**
5. 종합 점수 산출 (0-100, S/A/B/C/D 등급)

**추적하는 사운드 이벤트 ID**:

| 공통 | 스매셔 | 바이퍼 | 코만도 | 발토르 |
|------|--------|--------|--------|--------|
| PADDLE | POWER_SMASH | VIPER_BLADE | GRENADE | BLACKSMITH_HAMMER_CHARGE |
| WALL | DRIVE | VIPER_BLADE_SPIN | THROW | BLACKSMITH_HAMMER_THROW |
| DASH | | VIPER_SHADOW_KICK | AK47 | BLACKSMITH_HAMMER_EXPLOSION |
| HALF_DASH | | VIPER_PHANTOM_KICK_HIT | BAZOOKA_GOING | BLACKSMITH_UMBRELLA_SWING |
| SERVE | | VIPER_DIVE_STRIKE | SPIDER_MINE_SETUP | BLACKSMITH_UMBRELLA_OPEN |
| ITEM_GET | | VIPER_BACKSTEP | | BLACKSMITH_UMBRELLA_BLOCK |
| ACTIVE_ITEM | | | | |

**종합 점수 계산식**:
```python
score = 0
score += min(25, int(rallies_per_round * 2))   # 랠리 (최대 25)
score += min(15, total_dash * 2)                # 대시 (최대 15)
score += min(25, score_bonus)                   # 캐릭터 보너스 (최대 25)
score += min(10, item_get * 2)                  # 아이템 획득 (최대 10)
score += min(10, active_item * 3)               # 아이템 사용 (최대 10)
score += min(10, drive * 3)                     # 드라이브 (최대 10)
score += 5 if result == 'win' else 0            # 승리 보너스
score = min(100, score)
```

#### 2.6.3 피드백 표시 (`_show_replay_feedback()`, L124474-124527)

```python
def _show_replay_feedback(replay_info: dict):
    """리플레이 피드백 화면 — 카드 형태로 분석 결과 표시"""
    feedback = _analyze_replay(replay_info)
    # 스크롤 가능한 카드 리스트 렌더링
    # 각 카드: 좌측 컬러 바(4px) + 제목(fcolor) + 설명(grey)
    # 카드 크기: (WIDTH-60) × 48px, 간격 55px
    # ESC/클릭/Enter/Space → 복귀
```

#### 2.6.4 실시간 피드백 HUD (F키, L155645 / L169726+)

```python
# pingfighter.py 내부 전역 변수
player_analyzer = None
player_analyzer_profiles = {}  # 캐릭터별 별도 분석기

def initialize_player_analyzer(reset_session=False):
    # 캐릭터별 프로필 관리. 캐릭터 변경 시 해당 프로필로 교체.
    global player_analyzer, player_analyzer_profiles
    player_analyzer = player_analyzer_profiles[char_type]
```

**HUD 기본 뷰** (L169799):
- `player_analyzer.get_current_rank(current_stage)` → 등급 표시
- `player_analyzer.get_detailed_analysis(current_stage)` → stats, achievements, improvement_tips
- 좌측: 텍스트 통계 + 우측: 레이더 차트
- 하단 좌측: 업적 (최근 3개) + 하단 우측: 개선 피드백 (최대 2개)

**F키 상세 피드백 오버레이** (L169922-169956):
```python
if show_feedback:
    feedback_data = player_analyzer.get_detailed_feedback(current_stage)  # dict 반환
    # 500×600 반투명 패널
    # ⚠️ skill_feedback 키의 텍스트만 렌더링 (최대 20줄)
    skill_feedback = feedback_data["skill_feedback"]
    lines = skill_feedback.split('\n')
    for line in lines[:20]:
        # font_tiny로 렌더링 (70자 초과 시 잘림)
```

**현재 UI 계약**: `get_detailed_feedback()`가 반환하는 dict의 6개 키 중
`skill_feedback`만 HUD에 렌더링됨. `dash_feedback`, `item_feedback`,
`guard_feedback`, `overall_feedback`, `improvement_tips`는 **사용되지 않음**.

---

## 3. 데이터 흐름 요약

### 경로 A: 리플레이 → 사후 분석

```
게임 플레이 중
  │
  ├─ ReplayRecorder.capture(screen)  → raw 프레임 → deque → 압축 스레드 → .rpl
  ├─ ReplayRecorder.add_sound(id)    → sound_events[frame] = [id, ...]
  │
  ▼
ReplayRecorder.stop()
  │
  ├─ 메타데이터 pickle → 파일 끝에 기록
  ├─ 파일명 변경: _recording_*.tmp → replay_s{stage}_{ts}.rpl
  │
  ▼
show_replay_viewer()  → 사용자가 [📊피드백] 클릭
  │
  ▼
_analyze_replay(replay_info)
  │
  ├─ _read_metadata_fast()  → pickle.loads (프레임 디코딩 없음!)
  ├─ sound_events 카운트 집계
  ├─ 캐릭터별 전용 분석
  ├─ 종합 점수 산출 (0-100)
  │
  ▼
_show_replay_feedback()  → 카드 UI 렌더링
```

### 경로 B: 실시간 통계 → 라이브 피드백

```
게임 플레이 중
  │
  ├─ player_analyzer.record_hit()
  ├─ player_analyzer.record_miss()
  ├─ player_analyzer.record_dash_usage()
  ├─ player_analyzer.record_item_usage()
  ├─ player_analyzer.record_guard_action()
  ├─ player_analyzer.record_victory_result()
  │
  ▼
HUD 기본 뷰 (항상 표시)
  │
  ├─ get_current_rank(stage) → 등급 + 점수
  ├─ get_detailed_analysis(stage) → stats, achievements, improvement_tips
  │
  ▼
F키 토글 → 상세 오버레이
  │
  ├─ player_analyzer.get_detailed_feedback(stage)  → dict 반환
  │   ├─ [우선] LiteraryFeedbackSystem (literary_feedback_system.py)
  │   │   └─ 문학적 서사 텍스트 생성 (━━━ 스킬 마스터리 ━━━ ...)
  │   └─ [폴백] feedback_system.py (ImportError 시)
  │       └─ 등급별 정형 텍스트 생성
  │
  ▼
HUD 렌더링: feedback_data["skill_feedback"]만 표시 (최대 20줄)
  ⚠️ dash/item/guard/overall/tips 키는 미사용
```

---

## 4. 코드리뷰 체크리스트 / 잠재적 이슈

### 4.1 설계 관련

| # | 이슈 | 심각도 | 위치 | 설명 |
|---|------|--------|------|------|
| 1 | **피드백 모듈 3중화** | Medium | literary_feedback_system.py, feedback_system.py, enhanced_feedback_system.py | 3개 모듈이 유사 역할. `literary_feedback_system.py`가 활성 경로, `feedback_system.py`가 폴백, `enhanced_feedback_system.py`는 어디에서도 호출되지 않는 데드 코드. 정리 또는 통합 필요 |
| 2 | **두 분석 경로의 데이터 불일치** | Medium | _analyze_replay vs PlayerSkillAnalyzer | 리플레이 분석은 사운드 이벤트 기반, 실시간 분석은 통계 누적 기반. 같은 경기에 대해 다른 등급이 나올 수 있음 |
| 3 | **등급 체계 불일치** | Low | 4곳에서 각각 정의 | `SkillRank`(6단계), `feedback_system.py`(7단계 S~F), `_analyze_replay`(5단계 S~D), `_score_to_grade_text`(7단계). 통일 필요 |
| 4 | **PlayerStats 필드 동적 추가** | Medium | player_skill_analyzer.py:157 | `_ensure_new_fields()`로 런타임에 필드 추가. dataclass 사용 의미 감소 |
| 4b | **F키 오버레이 skill_feedback만 표시** | Medium | pingfighter.py:169942 | `get_detailed_feedback()`가 6개 키를 반환하지만 HUD는 `skill_feedback`만 렌더링. 나머지 5개 키(dash/item/guard/overall/tips)는 계산만 하고 버려짐. 의도적 미구현인지 불명 |

### 4.2 보안/안정성

| # | 이슈 | 심각도 | 위치 | 설명 |
|---|------|--------|------|------|
| 5 | **pickle 역직렬화** | High | replay_system.py:610 | `pickle.loads(meta_bytes)` — 악의적 .rpl 파일로 임의 코드 실행 가능. JSON 전환 또는 unpickler 제한 권장 |
| 6 | **파일 핸들 누수 가능성** | Medium | ReplayPlayer.load():340 | `load()` 성공 시 파일 핸들 유지. `__del__`에서 close() 하지만 GC 타이밍 불확실. context manager 패턴 권장 |
| 7 | **busy-wait 비효율** | Low | replay_system.py:147 (_writer 클로저) | `time.sleep(0.005)`로 5ms 폴링. 소비자(writer thread) 1개 + 생산자(게임 루프) 1개 구조라 race 이슈는 없으나, `queue.Queue`의 블로킹 get()으로 교체하면 CPU 낭비 제거 가능 |

### 4.3 성능

| # | 이슈 | 심각도 | 위치 | 설명 |
|---|------|--------|------|------|
| 8 | **프레임 원본 크기 유지** | Low | replay_system.py:24-25 | `SCALE_FACTOR=1.0`으로 760×750 풀 해상도 캡처. 파일 크기 증가. 0.5 축소 고려 |

### 4.4 UX/기능

| # | 이슈 | 심각도 | 위치 | 설명 |
|---|------|--------|------|------|
| 9 | **마크다운 렌더링 안됨** | Low | feedback_system.py 전체 | `**bold**` 구문이 pygame 텍스트에서 raw로 표시됨. 이모지도 폰트 미지원 시 깨짐 |
| 10 | **리플레이 피드백 고정 카드 높이** | Low | _show_replay_feedback:L124515 | 카드 높이 48px 고정. 긴 설명 텍스트 잘림 가능 |
| 11 | **캐릭터 미인식 시 fallback 없음** | Low | _analyze_replay:L124288 | 새 캐릭터 추가 시 전용 분석 누락 (공통 분석만 적용) |

---

## 5. 테스트 현황

### 존재하는 테스트
- `test_feedback_display.py` (155줄) — 피드백 UI 렌더링 테스트 (수동 실행, pygame 창)

### 미비한 테스트 영역
- `_analyze_replay()` 단위 테스트 없음
- `PlayerSkillAnalyzer` 점수 계산 로직 테스트 없음
- `ReplayRecorder`/`ReplayPlayer` 녹화-재생 라운드트립 테스트 없음
- `feedback_system.py`의 등급별 분기 테스트 없음

---

## 6. 파일 위치 인덱스

| 파일 | 줄 수 | 역할 | 활성 경로 |
|------|-------|------|----------|
| `replay/replay_system.py` | 703 | 리플레이 녹화/재생/관리 핵심 모듈 | ✅ 경로 A |
| `replay/__init__.py` | 2 | 패키지 마커 | - |
| `literary_feedback_system.py` | 472 | **문학적 서사형 피드백 (우선 경로)** | ✅ 경로 B 우선 |
| `feedback_system.py` | 463 | 등급별 한글 피드백 텍스트 (폴백) | ✅ 경로 B 폴백 |
| `enhanced_feedback_system.py` | 577 | 게임 메커니즘 기반 정밀 분석 | ❌ 미사용 (데드 코드) |
| `player_skill_analyzer.py` | 1090 | 실시간 통계 수집 + 등급 산출 + 피드백 진입점 | ✅ 경로 B |
| `test_feedback_display.py` | 155 | 피드백 UI 렌더링 테스트 | 테스트용 |
| `pingfighter.py:123835-124006` | 171 | 리플레이 뷰어 UI | ✅ 경로 A |
| `pingfighter.py:124277-124471` | 194 | `_analyze_replay()` — 사운드 이벤트 기반 분석 | ✅ 경로 A |
| `pingfighter.py:124474-124527` | 53 | `_show_replay_feedback()` — 피드백 카드 렌더링 | ✅ 경로 A |
| `pingfighter.py:153463+` | ~40 | `initialize_player_analyzer()` — 캐릭터별 분석기 초기화 | ✅ 경로 B |
| `pingfighter.py:169726-169975` | ~250 | `show_player_info()` HUD 기본 뷰 + F키 상세 오버레이 | ✅ 경로 B |
| `replays/` | - | .rpl 파일 저장 디렉토리 | ✅ 경로 A |
| `replays/replay_meta.json` | - | 커스텀 이름/잠금 상태 저장 | ✅ 경로 A |
