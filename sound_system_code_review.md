# PingFighter 사운드 시스템 코드 리뷰 문서

## 1. 아키텍처 개요

사운드 시스템이 **5개 모듈**에 분산되어 있으며, 각 모듈이 독립적으로 mixer를 초기화하고 볼륨을 관리한다.

```
┌─────────────────────────────────────────────────────────────┐
│                    pingfighter.py (메인)                      │
│  - pygame.mixer.init() + set_num_channels(64)               │
│  - 130+ SOUND_* 전역 상수                                    │
│  - play_sound_with_volume() / get_cached_sound()            │
│  - sfx_volume 전역 변수로 볼륨 직접 관리                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐  ┌───────────────────┐                │
│  │ bgm_manager.py   │  │ sound_effects.py  │                │
│  │ (BGM 전용)        │  │ (SFX 로딩 전용)   │                │
│  │ - 싱글톤 패턴     │  │ - SOUND_PATHS     │                │
│  │ - 포맷 fallback   │  │   (130+항목)       │                │
│  │ - 뮤트 2종        │  │ - load_sound_     │                │
│  │   (user/system)   │  │   effects()       │                │
│  └──────────────────┘  └───────────────────┘                │
│                                                              │
│  ┌──────────────────┐  ┌───────────────────┐                │
│  │ managers/        │  │ managers/         │                │
│  │ sound_manager.py │  │ unified_sound.py  │                │
│  │ (고급 SFX)       │  │ (경량 대안)        │                │
│  │ - 채널 8+8 할당   │  │ - 쿨다운 방지     │                │
│  │ - 3D 오디오      │  │ - 콤보 사운드     │                │
│  │ - 소프트 리미터   │  │ - 뮤트 토글       │                │
│  │ - 뮤직 덕킹      │  │                   │                │
│  │ - 이벤트 구독     │  │                   │                │
│  └──────────────────┘  └───────────────────┘                │
│                                                              │
│  ┌──────────────────┐  ┌───────────────────┐                │
│  │ game_state/      │  │ ui/pause_menu.py  │                │
│  │ audio.py         │  │ (설정 UI)          │                │
│  │ - AudioSettings  │  │ - BGM/SFX 슬라이더│                │
│  │   dataclass      │  │ - 뮤트 체크박스   │                │
│  │ - 볼륨 get/set   │  │ - 타격음 선택     │                │
│  └──────────────────┘  └───────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Mixer 초기화 (3곳에서 중복 초기화)

### 2-1. pingfighter.py (메인 게임 - 라인 22908~22927)
```python
# 메인 초기화 - 64채널
try:
    pygame.mixer.init()
    mixer_initialized = True
except pygame.error as exc:
    print(f"[WARN] pygame.mixer.init() 실패: {exc}")
    if os.environ.get("SDL_AUDIODRIVER", "").lower() != "dummy":
        os.environ["SDL_AUDIODRIVER"] = "dummy"
        try:
            pygame.mixer.init()
            mixer_initialized = True
        except pygame.error as dummy_exc:
            pass
    else:
        AUDIO_DISABLED = True
if mixer_initialized and not AUDIO_DISABLED:
    pygame.mixer.set_num_channels(64)  # ← 64채널
```

### 2-2. managers/sound_manager.py (SoundManager 클래스 - 라인 30~32)
```python
# SoundManager 자체 초기화 - 16채널 (충돌!)
pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)
pygame.mixer.set_num_channels(16)  # ← 16채널로 덮어쓰기!
```

### 2-3. pingfighter.py 인트로 영상 (라인 2435)
```python
# 영상 오디오 재생용 재초기화
pygame.mixer.init(frequency=freq, channels=mixer_channels)
```

### 2-4. bgm_manager.py (BGMManager.initialize - 라인 147~165)
```python
def initialize(self):
    if not pygame.mixer.get_init():
        try:
            pygame.mixer.init()
        except Exception as e:
            os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
            pygame.mixer.init()
    self.is_initialized = True
    pygame.mixer.music.set_volume(self.volume)
```

> **문제점**: `SoundManager`가 생성되면 `set_num_channels(16)`으로 메인의 64채널 설정을 덮어쓴다. 초기화 순서에 따라 채널 수가 달라질 수 있다.

---

## 3. 채널 할당 체계

### 3-1. SoundManager 채널 구조 (managers/sound_manager.py:59~73)
```python
# 명명 채널 (0~7) - 용도별 고정 할당
self.channels = {
    'paddle':    pygame.mixer.Channel(0),   # 패들 히트
    'wall':      pygame.mixer.Channel(1),   # 벽 충돌
    'item':      pygame.mixer.Channel(2),   # 아이템 획득
    'skill':     pygame.mixer.Channel(3),   # 스킬 발동
    'ui':        pygame.mixer.Channel(4),   # UI 클릭/호버
    'explosion': pygame.mixer.Channel(5),   # 폭발/충격
    'boss':      pygame.mixer.Channel(6),   # 보스 공격
    'ambient':   pygame.mixer.Channel(7),   # 환경음
}

# 풀 채널 (8~15) - 라운드로빈 동적 할당
self.pool_channels = [pygame.mixer.Channel(i) for i in range(8, 16)]
self.next_pool_channel = 0
```

### 3-2. pingfighter.py 직접 채널 사용 (전역)
```python
# 전용 채널 변수들 (명시적 채널 번호 없이 play() 반환값 사용)
blacksmith_hammer_charge_sound_channel = None
poseidon_wave_sound_channel = None
stage4_magnetic_sound_channel = None
spider_mine_walk_channel = None
optimus_charge_sound_channel = None
```

```python
# 루프 재생 예시
spider_mine_walk_channel = SOUND_SPIDER_MINE_WALK.play(loops=-1)
optimus_charge_sound_channel = SOUND_OPTIMUS_CHARGE.play(loops=-1)
SOUND_RAGNAROK_SHOCK.play(-1)  # 무한 루프
SOUND_QUAKE.play(loops=-1)     # 무한 루프
```

> **문제점**: pingfighter.py는 `sound.play()` 반환 채널을 사용하고, SoundManager는 고정 채널을 사용한다. 두 시스템이 같은 채널 번호를 사용할 수 있어 충돌 가능성이 있다.

---

## 4. 사운드 로딩 시스템

### 4-1. sound_effects.py (메인 SFX 로더)
```python
SOUND_PATHS = {
    "SERVE": "sounds/serve.wav",
    "WALL": "sounds/wall_hit.wav",
    "PADDLE": "sounds/paddle_hit.wav",
    "PADDLE2": "sounds/paddle_hit2.wav",
    "PADDLE3": "sounds/paddle_hit3.wav",
    # ... 130+ 항목
    "VIPER_PHANTOM_KICK_HIT": "sounds/pentomkick.wav",
}

def load_sound_effects(resource_path) -> Dict[str, pygame.mixer.Sound]:
    sounds = {}
    for key, rel_path in SOUND_PATHS.items():
        try:
            full_path = resource_path(rel_path)
            sounds[key] = pygame.mixer.Sound(full_path)
        except Exception as exc:
            print(f"[WARN] Failed to load sound {rel_path}: {exc}")
            sounds[key] = None  # ← 실패 시 None, 호출 시 None 체크 필요
    return sounds
```

### 4-2. pingfighter.py 전역 상수 바인딩 (라인 22969~23182)
```python
# sound_effects 딕셔너리에서 전역 변수로 추출
SOUND_SERVE = sound_effects['SERVE']
SOUND_WALL = sound_effects['WALL']
SOUND_PADDLE = sound_effects['PADDLE']
SOUND_DASH = sound_effects['DASH']
# ... 130+ 개

# 선택적 사운드 (없을 수 있는 것)
SOUND_STAGE5_WARNING = sound_effects.get('STAGE5_WARNING')
```

### 4-3. SoundManager 자체 로딩 (managers/sound_manager.py:113~176)
```python
# 별도의 사운드 파일 목록으로 독립 로딩
sound_files = {
    'paddle_hit': 'paddle_hit.wav',
    'wall_hit': 'wall_hit.wav',
    'explosion': 'explosion.wav',
    # ... 30+ 항목
}

# 파일이 없으면 사인파로 WAV를 동적 생성!
if os.path.exists(filepath):
    self.sounds[sound_name] = pygame.mixer.Sound(filepath)
else:
    self._generate_sound(sound_name, filepath)  # ← 프로시저럴 사운드 생성
```

### 4-4. get_cached_sound() (pingfighter.py:21983~21998)
```python
_sound_cache = {}

def get_cached_sound(relative_path: str) -> "pygame.mixer.Sound | None":
    """사운드를 캐시에서 가져오거나, 없으면 로드 후 캐시."""
    if relative_path in _sound_cache:
        return _sound_cache[relative_path]
    try:
        full_path = resource_path(relative_path)
        if os.path.exists(full_path):
            snd = pygame.mixer.Sound(full_path)
            _sound_cache[relative_path] = snd
            return snd
        else:
            _sound_cache[relative_path] = None
            return None
    except Exception:
        _sound_cache[relative_path] = None
        return None
```

> **문제점**: 사운드 로딩이 3개의 독립적인 경로(sound_effects.py, SoundManager, get_cached_sound)로 이루어지며, 같은 WAV 파일이 메모리에 중복 로드될 수 있다.

---

## 5. 볼륨 관리 체계 (4개의 독립적 볼륨 상태)

### 5-1. game_state/audio.py (AudioSettings 데이터클래스)
```python
@dataclass(slots=True)
class AudioSettings:
    bgm_volume: float = 0.4   # 기본 40%
    sfx_volume: float = 0.7   # 기본 70%
    bgm_muted: bool = False
    sfx_muted: bool = False

audio_settings = AudioSettings()  # 싱글톤 인스턴스

# 접근 함수
get_bgm_volume() -> float
set_bgm_volume(value) -> float
get_sfx_volume() -> float
set_sfx_volume(value) -> float
get_bgm_muted() -> bool
set_bgm_muted(muted) -> bool
get_sfx_muted() -> bool
set_sfx_muted(muted) -> bool
```

### 5-2. BGMManager 볼륨 (bgm_manager.py)
```python
class BGMManager:
    self.volume = 0.4                    # 자체 볼륨 상태
    self._muted_volume_cache = self.volume
```

### 5-3. SoundManager 볼륨 (managers/sound_manager.py)
```python
class SoundManager:
    self.master_volume = 1.0
    self.sound_volume = 1.0
    self.music_volume = 0.7
    self.ambient_volume = 0.5
    self.category_volume = {
        'sfx': 1.0,
        'env': 0.8,
        'ui': 0.8,
    }
```

### 5-4. UnifiedSoundManager 볼륨 (managers/unified_sound.py)
```python
class UnifiedSoundManager:
    self.music_volume = 0.7
    self.sfx_volume = 0.8
    self.muted = False
```

### 5-5. pingfighter.py 전역 볼륨
```python
sfx_volume = ...  # 전역 변수로 직접 관리
```

### 5-6. settings.json 설정값
```json
"audio": {
    "master_volume": 0.8,
    "sfx_volume": 1.0,
    "music_volume": 0.4,
    "ambient_volume": 0.5,
    "ui_volume": 0.8,
    "env_volume": 0.8,
    "enable_limiter": true,
    "ducking_enabled": true,
    "duck_boss_trigger": true,
    "duck_explosion_trigger": true,
    "mute_all": false,
    "spatial_audio": true,
    "dynamic_music": true,
    "paddle_hit_sound": 1
}
```

> **문제점**: 볼륨 상태가 최소 5곳에 분산되어 있으며, 상호 동기화 로직이 없다. settings.json의 `master_volume: 0.8`과 SoundManager의 `master_volume = 1.0`이 다른 값이다.

---

## 6. 음소거(Mute) 시스템

### 6-1. BGM 음소거 - 2개의 독립 플래그

```python
# bgm_manager.py
class BGMManager:
    self._user_muted = False     # B키 토글
    self._system_muted = False   # 옵션 메뉴 설정
    self._muted_last_bgm = None  # 음소거 시점 트랙 기억
```

**toggle_bgm()** - B키 사용자 토글 (라인 277~311):
```python
def toggle_bgm(self):
    if self._user_muted:
        # 해제: 볼륨 복원 + 마지막 트랙 재생
        self._user_muted = False
        pygame.mixer.music.set_volume(self.volume)
        target = self._muted_last_bgm or self.current_bgm
        self.current_bgm = None
        self.play_bgm(target)
    else:
        # 음소거: 트랙 저장 + 정지
        self._muted_last_bgm = self.current_bgm
        pygame.mixer.music.stop()
        pygame.mixer.music.set_volume(0)
        self._user_muted = True
```

**set_system_mute()** - 옵션 메뉴 (라인 313~341):
```python
def set_system_mute(self, muted: bool):
    self._system_muted = muted
    if muted:
        self._muted_last_bgm = self.current_bgm
        pygame.mixer.music.stop()
        pygame.mixer.music.set_volume(0)
    else:
        pygame.mixer.music.set_volume(self.volume)
        target = self._muted_last_bgm or self.current_bgm
        if target and not self._user_muted:
            self.current_bgm = None
            self.play_bgm(target)
```

### 6-2. SFX 음소거

```python
# game_state/audio.py
get_sfx_muted() -> bool
set_sfx_muted(muted: bool) -> bool

# managers/sound_manager.py
SoundManager.mute() / SoundManager.unmute()

# managers/unified_sound.py
UnifiedSoundManager.toggle_mute()  # 자체 muted 플래그
```

> **문제점**: BGM에 `_user_muted`와 `_system_muted` 2개의 독립 플래그가 있어 상태 조합이 복잡하다. SFX 음소거도 3곳에서 독립 관리된다.

---

## 7. BGM 관리 시스템 (bgm_manager.py)

### 7-1. 포맷 폴백 시스템
```python
# 각 BGM에 대해 여러 포맷 후보 지정 (OGG → MP3 → WAV 등)
self.bgm_candidates = {
    'stage1': [
        os.path.join("bgm", "stage1bgm.ogg"),
        os.path.join("bgm", "stage1bgm.mp3"),
        os.path.join("bgm", "stage1bgm.wav"),
    ],
    # stage2는 WAV 우선
    'stage2': [
        os.path.join("bgm", "stage2bgm.wav"),
        os.path.join("bgm", "stage2bgm.ogg"),
        os.path.join("bgm", "stage2bgm.mp3"),
    ],
    # ... 20+ BGM 트랙
}

# 환경변수로 포맷 강제 가능
# PINGF_BGM_EXT=ogg → 모든 BGM을 ogg로 우선 시도
```

### 7-2. 스테이지 BGM 매핑 (주의: 코드 변수명 ≠ 실제 스테이지)
```python
# ⚠️ stage5 후보 = stage6bgm 파일 (네메시스)
'stage5': [os.path.join("bgm", "stage6bgm.ogg"), ...],
# ⚠️ stage6 후보 = stage5bgm 파일 (홍련)  
'stage6': [os.path.join("bgm", "stage5bgm.wav"), ...],
```

### 7-3. 광장 BGM 랜덤 선택
```python
def play_downtown_bgm():
    """3개 BGM 중 랜덤 선택"""
    available_tracks = []
    for track_name in ['downtown', 'downtown1', 'downtown2']:
        bgm_path = bgm_manager._resolve_bgm_path(track_name)
        if bgm_path:
            available_tracks.append(track_name)
    if available_tracks:
        selected = random.choice(available_tracks)
        bgm_manager.play_bgm(selected)
```

### 7-4. 콜로세움 BGM
```python
# 4곡 중 랜덤
elif stage_num == 30:
    colosseum_bgm = random.choice(['colosseum1', 'colosseum2', 'colosseum3', 'colosseum4'])
    self.play_bgm(colosseum_bgm)
```

---

## 8. 고급 기능 (managers/sound_manager.py)

### 8-1. 3D 오디오 (라인 695~718)
```python
def _calculate_3d_audio(self, position: tuple) -> tuple:
    x, y = position
    lx, ly = self.listener_position  # 기본: (300, 375)

    # 거리 기반 볼륨 감쇄
    distance = math.sqrt((x - lx) ** 2 + (y - ly) ** 2)
    max_distance = 500
    volume = max(0, 1.0 - (distance / max_distance))

    # 좌우 패닝
    pan = (x - lx) / 300  # -1.0 ~ 1.0
    pan = max(-1.0, min(1.0, pan))

    return volume, pan
```

### 8-2. 소프트 리미터 (동시 효과음 피크 억제)
```python
# 설정
self.limiter_enabled = True
self._limiter_threshold = 1.0   # 목표 피크
self._limiter_tau_ms = 180      # 감쇠 시상수

def _compute_limiter_gain(self, sound_name, channel, incoming_gain):
    self._update_peak_meter()
    weight = self._event_weight(sound_name, channel)
    projected = self._peak_level + incoming_gain * weight
    if projected <= self._limiter_threshold:
        self._peak_level = projected
        return 1.0  # 감쇄 없음
    # 초과분 비율만큼 축소
    gain = max(0.3, self._limiter_threshold / projected)
    self._peak_level += incoming_gain * weight * gain
    return gain

# 채널별 가중치
def _event_weight(self, sound_name, channel):
    if channel in ('explosion', 'boss'): return 1.2
    if channel in ('skill', 'wall', 'paddle'): return 0.9
    if channel in ('ambient',): return 0.6
    if channel in ('ui',): return 0.5
    # 키워드 기반 보정
    if any(k in lname for k in ('explosion', 'boom', 'yamato', 'ragnarok')):
        return 1.1
    return 0.8
```

### 8-3. 뮤직 덕킹 (큰 SFX → BGM 일시 감소)
```python
self.duck_music_enabled = True
self._duck_amount = 0.6    # duck 시 BGM을 60%로
self._duck_ms = 350         # 350ms 동안 유지
self.duck_trigger_channels = {"boss", "explosion"}

def _trigger_ducking(self):
    now = pygame.time.get_ticks()
    self._duck_until_ms = now + self._duck_ms
    vol = self.music_volume * self.master_volume * self._duck_amount
    pygame.mixer.music.set_volume(vol)

def _maybe_recover_ducking(self):
    """덕킹 해제 - 다음 재생 이벤트 시 체크"""
    if self._duck_until_ms == 0:
        return
    if pygame.time.get_ticks() >= self._duck_until_ms:
        self._duck_until_ms = 0
        pygame.mixer.music.set_volume(self.music_volume * self.master_volume)
```

### 8-4. 프로시저럴 사운드 생성 (파일 미존재 시)
```python
def _generate_sound(self, sound_name, filepath):
    """사운드 파일이 없으면 사인파로 WAV 동적 생성"""
    params = all_params.get(sound_name, (440, 0.1, 'out', 0.7))
    wave_data = self._create_wave_data(*params)  # (freq, duration, fade_type, volume)
    self._save_wav_file(filepath, wave_data)
    self.sounds[sound_name] = pygame.mixer.Sound(filepath)
```

> **주의**: 프로덕션 빌드에서 사운드 파일이 누락되면 디스크에 WAV를 생성한다. PyInstaller 번들에서는 쓰기 권한 문제가 발생할 수 있다.

---

## 9. SFX 재생 패턴

### 9-1. 직접 재생 (pingfighter.py - 가장 많이 사용)
```python
# 단순 재생
play_sound_with_volume(SOUND_PADDLE, sfx_volume)

# 무한 루프
channel = SOUND_SPIDER_MINE_WALK.play(loops=-1)

# 시간 제한 재생
SOUND_THROW_BEFORE.play(maxtime=200)  # 200ms만

# 채널 저장 후 나중에 정지
spider_mine_walk_channel = SOUND_SPIDER_MINE_WALK.play(loops=-1)
# ... 나중에 ...
if spider_mine_walk_channel:
    spider_mine_walk_channel.stop()
```

### 9-2. play_sound_with_volume() (pingfighter.py:22009)
```python
def play_sound_with_volume(sound, volume=None):
    global sfx_volume
    if not sound:
        return None
    if volume is None:
        volume = sfx_volume
    sound.set_volume(volume)
    channel = sound.play()
    return channel
```

### 9-3. SoundManager.play_sound() (managers/sound_manager.py:300)
```python
def play_sound(self, sound_name, channel=None, position=None, volume_override=None):
    # 1. 덕킹 회복 체크
    self._maybe_recover_ducking()
    # 2. 3D 오디오 적용
    if position and self.enable_3d_audio:
        volume, pan = self._calculate_3d_audio(position)
    # 3. 카테고리 볼륨
    category = self._category_from_channel(channel)
    cat_vol = self.category_volume.get(category, 1.0)
    # 4. 리미터 게인
    limiter_gain = self._compute_limiter_gain(...)
    # 5. 최종 볼륨 = volume * sound_volume * cat_vol * master * limiter
    final_vol = volume * self.sound_volume * cat_vol * self.master_volume * limiter_gain
    # 6. 채널 선택 (명명 채널 or 풀 라운드로빈)
    if channel in self.channels:
        self.channels[channel].play(temp_sound)
    else:
        self.pool_channels[self.next_pool_channel].play(temp_sound)
        self.next_pool_channel = (self.next_pool_channel + 1) % 8
    # 7. 뮤직 덕킹 트리거
    if self._is_loud_event(sound_name, channel):
        self._trigger_ducking()
```

---

## 10. 이벤트 기반 사운드 (managers/sound_manager.py:100~111)

```python
def setup_event_handlers(self):
    self.event_manager.subscribe(EventType.COLLISION, self.on_collision)
    self.event_manager.subscribe(EventType.ITEM_COLLECTED, self.on_item_collected)
    self.event_manager.subscribe(EventType.SPECIAL_ACTIVATED, self.on_special_activated)
    self.event_manager.subscribe(EventType.GAME_START, self.on_game_start)
    self.event_manager.subscribe(EventType.GAME_OVER, self.on_game_over)
    self.event_manager.subscribe(EventType.BOSS_SPECIAL_ATTACK, self.on_boss_special)
    self.event_manager.subscribe(EventType.BOSS_PHASE_CHANGED, self.on_boss_phase)
    self.event_manager.subscribe(EventType.DASH_STARTED, self.on_dash)
    self.event_manager.subscribe(EventType.ROUND_WIN, self.on_round_win)
    self.event_manager.subscribe(EventType.ROUND_LOSE, self.on_round_lose)
```

> **참고**: `on_item_collected`와 `on_round_win/lose`는 중복 방지를 위해 비활성화(pass/return)되어 있다. 실제 사운드 재생은 pingfighter.py에서 직접 수행한다.

---

## 11. 설정 UI (ui/pause_menu.py)

### BGM/SFX 볼륨 슬라이더
- BGM 슬라이더: 0~100% 범위, 5% 단위 조절
- SFX 슬라이더: 0~100% 범위, 5% 단위 조절
- 뮤트 체크박스: BGM/SFX 각각 독립

### 타격음 선택 (3종)
```python
paddle_hit_sound = int(settings.get_setting('audio', 'paddle_hit_sound', 1))
# 1: PADDLE, 2: PADDLE2, 3: PADDLE3
```

---

## 12. 사운드 파일 현황

### 디렉토리 구조
```
sounds/         → 250+ WAV 파일 (SFX)
bgm/            → 19 WAV + 9 MP3 파일 (BGM)
```

### 주요 카테고리별 사운드 수
| 카테고리 | 파일 수 | 예시 |
|----------|---------|------|
| 패들/공 | 6 | paddle_hit.wav, wall_hit.wav, serve.wav |
| 아이템 | 4 | itemget.wav, activeitem.wav, drink.wav |
| 대시/스킬 | 6 | dash.wav, dashcharge.wav, halfdash.wav |
| 보스 스킬 | 15+ | godstart.wav, ragnarokshot.wav |
| 스테이지별 | 20+ | stage1door.wav, stage6beam.wav |
| 캐릭터별 | 30+ | umbopen.wav, blade.wav, jetpack.wav |
| UI | 2 | button_click.wav, button_hover.wav |
| 폭발 | 5 | explosion.wav, ragnarokboom.wav |

---

## 13. 주요 이슈 요약

| # | 이슈 | 심각도 | 설명 |
|---|------|--------|------|
| 1 | **Mixer 다중 초기화** | 높음 | 3곳에서 독립적으로 `pygame.mixer.init()` 호출. SoundManager가 채널 수를 64→16으로 덮어쓸 수 있음 |
| 2 | **볼륨 상태 분산** | 높음 | AudioSettings, BGMManager, SoundManager, UnifiedSoundManager, pingfighter.py 전역 - 5곳에서 볼륨 독립 관리 |
| 3 | **사운드 중복 로딩** | 중간 | sound_effects.py, SoundManager, get_cached_sound()가 같은 WAV를 각각 메모리에 로드 |
| 4 | **채널 충돌 가능성** | 중간 | pingfighter.py의 `sound.play()` 자동 채널과 SoundManager의 고정 채널(0~7)이 겹칠 수 있음 |
| 5 | **미사용 시스템 존재** | 낮음 | UnifiedSoundManager, SoundManager의 이벤트 핸들러(on_round_win 등)가 비활성화 상태 |
| 6 | **프로시저럴 사운드 생성** | 중간 | SoundManager가 파일 미존재 시 디스크에 WAV 생성 - PyInstaller 번들에서 쓰기 실패 가능 |
| 7 | **뮤트 상태 복잡도** | 중간 | BGM에 user_muted + system_muted 2종, SFX에 3곳 독립 뮤트 플래그 |
| 8 | **덕킹 복구 타이밍** | 낮음 | `_maybe_recover_ducking()`이 다음 사운드 재생 시에만 체크됨 - 사운드가 없으면 BGM이 낮은 상태로 유지될 수 있음 |

---

## 14. 실제 사용 흐름 (어떤 시스템이 실제로 활성?)

| 기능 | 실제 담당 모듈 | 비고 |
|------|---------------|------|
| BGM 재생/정지/토글 | `bgm_manager.py` | 싱글톤, 직접 호출 |
| SFX 재생 (대부분) | `pingfighter.py` 직접 | `play_sound_with_volume()` + 전역 `SOUND_*` |
| SFX 볼륨 상태 | `game_state/audio.py` | AudioSettings 참조 |
| 설정 UI | `ui/pause_menu.py` | 슬라이더/체크박스 |
| 3D/리미터/덕킹 | `managers/sound_manager.py` | SoundManager (제한적 사용) |
| UnifiedSoundManager | `managers/unified_sound.py` | **거의 미사용** |
| settings.json | 디스크 저장 | 설정 영속화 |

> **핵심**: 실제 게임 루프에서는 `pingfighter.py`의 직접 재생 + `bgm_manager.py`가 메인이고, `SoundManager`와 `UnifiedSoundManager`는 리팩토링 과정에서 추가된 것으로 보이며 부분적으로만 활용되고 있다.
