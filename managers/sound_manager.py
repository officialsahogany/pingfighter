"""
Sound Manager - 사운드 시스템 관리
모든 사운드 효과 및 음악 재생 관리

개선 사항
- 카테고리 볼륨 분리: SFX / ENV(환경) / UI
- 소프트 리미터(이벤트 기반): 동시 효과음 피크 억제
- 간단한 뮤직 덕킹: 큰 SFX 시 BGM 일시 감쇄
- 리소스 로딩 일원화: resource_path 사용
"""

import pygame
import os
import math
import struct
import wave
import sys
from typing import Dict, Optional
from core.global_manager import GlobalManager
from core.events import EventType, EventManager


class SoundManager:
    """사운드 관리 시스템"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        self.event_manager = EventManager.get_instance()
        
        # Pygame mixer 초기화 (더 많은 채널)
        pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)
        pygame.mixer.set_num_channels(16)  # 16개 채널 사용
        
        # 사운드 캐시
        self.sounds = {}
        self.music = {}
        self.sound_pools = {}  # 사운드 풀 (동일 사운드 동시 재생용)
        
        # 볼륨 설정
        self.master_volume = 1.0
        # SFX 기본 볼륨(게임플레이 효과음)
        self.sound_volume = 1.0
        # 카테고리 볼륨(SFX/ENV/UI)
        self.category_volume = {
            'sfx': 1.0,
            'env': 0.8,   # 환경음(군중, 앰비언트 등)
            'ui': 0.8,    # UI 클릭/호버 등
        }
        # 음악 볼륨
        self.music_volume = 0.7
        # 기존 ambient 참조(호환성)
        self.ambient_volume = 0.5
        
        # 현재 재생 중인 음악
        self.current_music = None
        self.music_paused = False
        self.music_fade_time = 1000  # 페이드 시간 (ms)
        
        # 사운드 채널
        self.channels = {
            'paddle': pygame.mixer.Channel(0),
            'wall': pygame.mixer.Channel(1),
            'item': pygame.mixer.Channel(2),
            'skill': pygame.mixer.Channel(3),
            'ui': pygame.mixer.Channel(4),
            'explosion': pygame.mixer.Channel(5),
            'boss': pygame.mixer.Channel(6),
            'ambient': pygame.mixer.Channel(7)
        }
        
        # 사운드 풀 채널 (8-15)
        self.pool_channels = [pygame.mixer.Channel(i) for i in range(8, 16)]
        self.next_pool_channel = 0
        
        # 3D 오디오 설정
        self.enable_3d_audio = True
        self.listener_position = (300, 375)  # 화면 중앙

        # 소프트 리미터(이벤트 기반)
        self.limiter_enabled = True
        self._limiter_threshold = 1.0   # 목표 피크(상대치)
        self._limiter_tau_ms = 180      # 감쇠 시상수
        self._peak_level = 0.0
        self._peak_last_ms = pygame.time.get_ticks()

        # 뮤직 덕킹(큰 SFX 시 BGM 감소)
        self.duck_music_enabled = True
        self._duck_amount = 0.6         # duck 시 남기는 비율(0.0~1.0)
        self._duck_ms = 350
        self._duck_until_ms = 0
        # 덕킹 트리거 채널(사용자 설정 가능)
        self.duck_trigger_channels = {"boss", "explosion"}
        
        # 기본 사운드 로드
        self.load_sounds()
        
        # 이벤트 핸들러 등록
        self.setup_event_handlers()
        
    def setup_event_handlers(self):
        """이벤트 핸들러 설정"""
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
        
    def load_sounds(self):
        """사운드 파일 로드"""
        sounds_dir = "sounds"
        
        # 필수 사운드 파일들
        sound_files = {
            # 기본 사운드
            'paddle_hit': 'paddle_hit.wav',
            'wall_hit': 'wall_hit.wav',
            'item_pickup': 'item_pickup.wav',
            'active_item': 'active_item.wav',
            'skill_activate': 'skill_activate.wav',
            'explosion': 'explosion.wav',
            'button_click': 'button_click.wav',
            'button_hover': 'button_hover.wav',
            'game_over': 'game_over.wav',
            'victory': 'victory.wav',
            'dash': 'dash.wav',
            'charge': 'charge.wav',
            
            # 보스 전용 사운드
            'boss_hit': 'boss_hit.wav',
            'boss_special': 'boss_special.wav',
            'boss_phase': 'boss_phase.wav',
            'boss_defeat': 'boss_defeat.wav',
            
            # 스테이지별 특수 사운드
            'whip': 'whip.wav',
            'rock_spawn': 'rock_spawn.wav',
            # 'rock_break': 'rock_break.wav',  # removed - file no longer exists
            'tears': 'tears.wav',
            'magnetic': 'magnetic.wav',
            'flame': 'flame.wav',
            'missile': 'missile.wav',
            'yamato_charge': 'yamato_charge.wav',
            'yamato_fire': 'yamato_fire.wav',
            
            # 환경 사운드
            'ambient_menu': 'ambient_menu.wav',
            'ambient_battle': 'ambient_battle.wav',
            'crowd_cheer': 'crowd_cheer.wav'
        }
        
        # 사운드 파일 로드 또는 생성
        for sound_name, filename in sound_files.items():
            filepath = self._resource_path(os.path.join(sounds_dir, filename))
            
            if os.path.exists(filepath):
                try:
                    self.sounds[sound_name] = pygame.mixer.Sound(filepath)
                    self.sounds[sound_name].set_volume(self.sound_volume)
                except:
                    # 파일이 손상되었거나 로드 실패 시 생성
                    self._generate_sound(sound_name, filepath)
            else:
                # 파일이 없으면 생성
                self._generate_sound(sound_name, filepath)
                
        # GlobalManager에 사운드 등록
        self._register_sounds_to_global()
        
    def _generate_sound(self, sound_name: str, filepath: str):
        """사운드 파일 동적 생성"""
        # 디렉토리 생성
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        
        # 사운드별 생성 파라미터
        sound_params = {
            'paddle_hit': (440, 0.1, 'out', 0.8),
            'wall_hit': (220, 0.15, 'out', 0.6),
            'item_pickup': (880, 0.2, 'in_out', 0.7),
            'active_item': (660, 0.3, 'in', 0.8),
            'skill_activate': (550, 0.25, 'in_out', 0.9),
            'explosion': (110, 0.5, 'out', 1.0),
            'button_click': (330, 0.1, 'out', 0.7),
            'button_hover': (550, 0.05, 'in_out', 0.4),
            'game_over': (220, 1.0, 'out', 0.9),
            'victory': (440, 1.5, 'in_out', 1.0),
            'dash': (770, 0.15, 'out', 0.8),
            'charge': (330, 0.4, 'in', 0.7)
        }
        
        # 확장된 사운드 파라미터
        extended_params = {
            'boss_hit': (330, 0.2, 'out', 0.9),
            'boss_special': (550, 0.4, 'in_out', 1.0),
            'boss_phase': (440, 0.6, 'in', 0.9),
            'boss_defeat': (220, 1.5, 'out', 1.0),
            'whip': (880, 0.15, 'out', 0.8),
            'rock_spawn': (110, 0.3, 'in', 0.7),
            # 'rock_break': (150, 0.25, 'out', 0.9),  # removed - file no longer exists
            'tears': (660, 0.2, 'in_out', 0.6),
            'magnetic': (440, 0.35, 'in_out', 0.8),
            'flame': (220, 0.4, 'in', 0.9),
            'missile': (330, 0.3, 'out', 0.8),
            'yamato_charge': (110, 2.0, 'in', 1.0),
            'yamato_fire': (55, 1.0, 'out', 1.0),
            'ambient_menu': (100, 3.0, 'in_out', 0.3),
            'ambient_battle': (150, 2.0, 'in_out', 0.4),
            'crowd_cheer': (200, 1.5, 'in_out', 0.5)
        }
        
        # 모든 파라미터 통합
        all_params = {**sound_params, **extended_params}
        
        # 파라미터 가져오기
        params = all_params.get(sound_name, (440, 0.1, 'out', 0.7))
        wave_data = self._create_wave_data(*params)
        
        # WAV 파일로 저장
        self._save_wav_file(filepath, wave_data)
        
        # 로드
        try:
            self.sounds[sound_name] = pygame.mixer.Sound(filepath)
            self.sounds[sound_name].set_volume(self.sound_volume)
        except:
            pass
            
    def _create_wave_data(self, frequency: int, duration: float, 
                         fade_type: str, volume: float) -> list:
        """웨이브 데이터 생성"""
        sample_rate = 44100
        num_samples = int(sample_rate * duration)
        
        wave_data = []
        for i in range(num_samples):
            # 기본 사인파
            value = math.sin(2.0 * math.pi * frequency * i / sample_rate)
            
            # 페이드 적용
            if fade_type == 'in':
                fade_volume = i / num_samples
            elif fade_type == 'out':
                fade_volume = 1.0 - (i / num_samples)
            elif fade_type == 'in_out':
                if i < num_samples / 2:
                    fade_volume = 2 * i / num_samples
                else:
                    fade_volume = 2 * (1.0 - i / num_samples)
            else:  # 'none'
                fade_volume = 1.0
                
            # 최종 값 계산
            final_value = value * fade_volume * volume
            wave_data.append(int(final_value * 16383))
            
        return wave_data
        
    def _save_wav_file(self, filename: str, wave_data: list):
        """WAV 파일로 저장"""
        with wave.open(filename, 'w') as wav_file:
            wav_file.setnchannels(1)  # 모노
            wav_file.setsampwidth(2)  # 16비트
            wav_file.setframerate(44100)
            
            for sample in wave_data:
                wav_file.writeframes(struct.pack('h', sample))
                
    def _register_sounds_to_global(self):
        """GlobalManager에 사운드 등록"""
        sound_mapping = {
            'SOUND_PADDLE': 'paddle_hit',
            'SOUND_WALL': 'wall_hit',
            'SOUND_ITEM_PICKUP': 'item_pickup',
            'SOUND_ACTIVE_ITEM': 'active_item',
            'SOUND_SKILL': 'skill_activate',
            'SOUND_EXPLOSION': 'explosion',
            'SOUND_BUTTON': 'button_click',
            'SOUND_HOVER': 'button_hover',
            'SOUND_GAME_OVER': 'game_over',
            'SOUND_VICTORY': 'victory',
            'SOUND_DASH': 'dash',
            'SOUND_CHARGE': 'charge'
        }
        
        for global_name, sound_name in sound_mapping.items():
            if sound_name in self.sounds:
                self.global_manager.set(global_name, self.sounds[sound_name])
                
    def play_sound(self, sound_name: str, channel: str = None,
                   position: tuple = None, volume_override: float = None):
        """사운드 재생
        
        Args:
            sound_name: 사운드 이름
            channel: 재생할 채널 (None이면 자동 선택)
            position: 3D 오디오용 위치 (x, y)
            volume_override: 볼륨 오버라이드
        """
        # 덕킹 회복 체크(이벤트 구동)
        self._maybe_recover_ducking()

        if sound_name not in self.sounds:
            return
            
        sound = self.sounds[sound_name]
        
        # 3D 오디오 적용
        if position and self.enable_3d_audio:
            volume, pan = self._calculate_3d_audio(position)
            if volume_override is not None:
                volume *= volume_override
        else:
            volume = volume_override if volume_override is not None else 1.0
            pan = 0.0

        # 카테고리 볼륨
        category = self._category_from_channel(channel)
        cat_vol = self.category_volume.get(category, 1.0)

        # 리미터 업데이트 및 게인 계산(신규 사운드 기준 추정)
        limiter_gain = 1.0
        if self.limiter_enabled:
            limiter_gain = self._compute_limiter_gain(sound_name, channel, volume * self.sound_volume * cat_vol * self.master_volume)
            
        # 사운드 복사본 생성 (볼륨 독립 설정용)
        temp_sound = sound
        final_vol = max(0.0, min(1.0, volume * self.sound_volume * cat_vol * self.master_volume * limiter_gain))
        temp_sound.set_volume(final_vol)
        
        if channel and channel in self.channels:
            ch = self.channels[channel]
            ch.play(temp_sound)
            if self.enable_3d_audio and position:
                ch.set_volume(volume, 1.0 - volume)  # 좌우 패닝
        else:
            # 풀 채널 사용
            ch = self.pool_channels[self.next_pool_channel]
            ch.play(temp_sound)
            if self.enable_3d_audio and position:
                ch.set_volume(volume * (1.0 - pan), volume * (1.0 + pan))
            self.next_pool_channel = (self.next_pool_channel + 1) % len(self.pool_channels)

        # 큰 SFX에 대해 뮤직 덕킹
        if self.duck_music_enabled and self._is_loud_event(sound_name, channel):
            self._trigger_ducking()
            
    def play_music(self, music_file: str, loops: int = -1, fade_in: bool = True):
        """배경 음악 재생
        
        Args:
            music_file: 음악 파일 경로
            loops: 반복 횟수 (-1은 무한 반복)
            fade_in: 페이드 인 효과 사용
        """
        try:
            # 이전 음악 페이드 아웃
            if self.current_music and fade_in:
                pygame.mixer.music.fadeout(self.music_fade_time)
                pygame.time.wait(self.music_fade_time)
                
            # 음악 파일이 없으면 생성
            full_path = self._resource_path(music_file)
            if not os.path.exists(full_path):
                self._generate_music(full_path)

            pygame.mixer.music.load(full_path)
            pygame.mixer.music.set_volume(self.music_volume * self.master_volume)
            
            if fade_in:
                pygame.mixer.music.play(loops, fade_ms=self.music_fade_time)
            else:
                pygame.mixer.music.play(loops)
                
            self.current_music = full_path
            self.music_paused = False
        except Exception as e:
            print(f"음악 재생 실패: {e}")
            
    def stop_music(self):
        """배경 음악 정지"""
        pygame.mixer.music.stop()
        self.current_music = None
        self.music_paused = False
        
    def pause_music(self):
        """배경 음악 일시정지"""
        if self.current_music and not self.music_paused:
            pygame.mixer.music.pause()
            self.music_paused = True
            
    def resume_music(self):
        """배경 음악 재개"""
        if self.current_music and self.music_paused:
            pygame.mixer.music.unpause()
            self.music_paused = False
            
    def set_master_volume(self, volume: float):
        """마스터 볼륨 설정
        
        Args:
            volume: 볼륨 (0.0 ~ 1.0)
        """
        self.master_volume = max(0.0, min(1.0, volume))
        self._update_volumes()
        
    def set_sound_volume(self, volume: float):
        """효과음 볼륨 설정
        
        Args:
            volume: 볼륨 (0.0 ~ 1.0)
        """
        self.sound_volume = max(0.0, min(1.0, volume))
        self._update_volumes()
        
    def set_music_volume(self, volume: float):
        """음악 볼륨 설정
        
        Args:
            volume: 볼륨 (0.0 ~ 1.0)
        """
        self.music_volume = max(0.0, min(1.0, volume))
        pygame.mixer.music.set_volume(self.music_volume * self.master_volume)
    
    def set_sfx_volume(self, volume: float):
        """SFX 볼륨 설정 (set_sound_volume의 별칭)
        
        Args:
            volume: 볼륨 (0.0 ~ 1.0)
        """
        self.set_sound_volume(volume)
    
    def mute(self):
        """모든 사운드 음소거"""
        self.muted = True
        pygame.mixer.music.set_volume(0)
        for sound in self.sounds.values():
            sound.set_volume(0)
    
    def unmute(self):
        """음소거 해제"""
        self.muted = False
        self._update_volumes()
        pygame.mixer.music.set_volume(self.music_volume * self.master_volume)
        
    def _update_volumes(self):
        """모든 볼륨 업데이트"""
        for sound in self.sounds.values():
            # 카테고리별 개별 갱신은 재생 시점에 반영하므로 여기서는 마스터/SFX만 적용
            sound.set_volume(self.sound_volume * self.master_volume)
        pygame.mixer.music.set_volume(self.music_volume * self.master_volume)

    # --- 카테고리 볼륨 API ---
    def set_ui_volume(self, volume: float):
        self.category_volume['ui'] = max(0.0, min(1.0, float(volume)))

    def set_env_volume(self, volume: float):
        self.category_volume['env'] = max(0.0, min(1.0, float(volume)))

    def set_category_volume(self, category: str, volume: float):
        if category in self.category_volume:
            self.category_volume[category] = max(0.0, min(1.0, float(volume)))

    # --- 리미터/덕킹 설정 ---
    def set_limiter_enabled(self, enabled: bool):
        self.limiter_enabled = bool(enabled)

    def set_limiter_params(self, threshold: float | None = None, tau_ms: int | None = None):
        if threshold is not None:
            self._limiter_threshold = max(0.1, min(2.0, float(threshold)))
        if tau_ms is not None:
            self._limiter_tau_ms = max(30, int(tau_ms))

    def set_ducking(self, enabled: bool | None = None, amount: float | None = None, duration_ms: int | None = None):
        if enabled is not None:
            self.duck_music_enabled = bool(enabled)
        if amount is not None:
            self._duck_amount = max(0.0, min(1.0, float(amount)))
        if duration_ms is not None:
            self._duck_ms = max(50, int(duration_ms))

    def set_ducking_triggers(self, channels: list[str] | set[str]):
        """덕킹을 유발하는 채널 집합을 설정한다.

        Args:
            channels: 예) {"boss", "explosion"}
        """
        try:
            self.duck_trigger_channels = set(channels)
        except Exception:
            pass

    # -----------------------------
    # 내부 유틸리티
    # -----------------------------

    def _resource_path(self, relative_path: str) -> str:
        """PyInstaller/개발 환경 겸용 리소스 경로"""
        try:
            base_path = sys._MEIPASS  # type: ignore[attr-defined]
        except Exception:
            base_path = os.path.dirname(os.path.abspath(__file__))
        return os.path.join(base_path, relative_path)

    def _category_from_channel(self, channel: Optional[str]) -> str:
        if channel in ('ui',):
            return 'ui'
        if channel in ('ambient',):
            return 'env'
        # 그 외는 SFX로 취급
        return 'sfx'

    def _update_peak_meter(self) -> None:
        now = pygame.time.get_ticks()
        dt = max(0, now - self._peak_last_ms)
        self._peak_last_ms = now
        if dt <= 0:
            return
        # 지수 감쇠
        decay = math.exp(-dt / float(self._limiter_tau_ms))
        self._peak_level *= decay

    def _event_weight(self, sound_name: str, channel: Optional[str]) -> float:
        # 대략적인 상대 라우드니스 추정
        if channel in ('explosion', 'boss'):
            return 1.2
        if channel in ('skill', 'wall', 'paddle'):
            return 0.9
        if channel in ('ambient',):
            return 0.6
        if channel in ('ui',):
            return 0.5
        # 키워드 기반 보정
        lname = (sound_name or '').lower()
        if any(k in lname for k in ('explosion', 'boom', 'yamato', 'ragnarok')):
            return 1.1
        return 0.8

    def _compute_limiter_gain(self, sound_name: str, channel: Optional[str], incoming_gain: float) -> float:
        self._update_peak_meter()
        weight = self._event_weight(sound_name, channel)
        projected = self._peak_level + max(0.0, incoming_gain) * weight
        if projected <= self._limiter_threshold:
            # 업데이트만 수행
            self._peak_level = projected
            return 1.0
        # 초과분 비율만큼 신호 축소
        gain = max(0.3, self._limiter_threshold / projected)
        # 실제 반영된 최종 볼륨을 기준으로 피크 업데이트
        self._peak_level += max(0.0, incoming_gain) * weight * gain
        return gain

    def _is_loud_event(self, sound_name: str, channel: Optional[str]) -> bool:
        """덕킹 트리거 판단.

        우선순위:
        1) 사용자가 지정한 duck_trigger_channels가 있으면 그 집합만 따른다.
           - 'boss'가 포함되면 boss 채널에 반응
           - 'explosion'이 포함되면 explosion 채널 또는 키워드 매칭에 반응
        2) 지정이 비어있으면(예외적 케이스) 기본 키워드 규칙 사용
        """
        lname = (sound_name or '').lower()
        triggers = getattr(self, 'duck_trigger_channels', set()) or set()

        if triggers:
            if 'boss' in triggers and channel == 'boss':
                return True
            if 'explosion' in triggers:
                if channel == 'explosion':
                    return True
                if any(k in lname for k in ('explosion', 'boom', 'yamato', 'ragnarok')):
                    return True
            return False

        # 트리거가 정의되지 않은 경우의 안전한 기본(키워드 기반)
        if channel == 'boss':
            return True
        return any(k in lname for k in ('explosion', 'boom', 'yamato', 'ragnarok'))

    def _trigger_ducking(self) -> None:
        now = pygame.time.get_ticks()
        self._duck_until_ms = now + self._duck_ms
        vol = self.music_volume * self.master_volume * self._duck_amount
        pygame.mixer.music.set_volume(vol)
        # 덕킹 해제는 다음 재생 이벤트나 외부 호출에서 자연 복귀 처리
        self._maybe_recover_ducking()

    def _maybe_recover_ducking(self) -> None:
        if not self.duck_music_enabled:
            return
        if self._duck_until_ms == 0:
            return
        if pygame.time.get_ticks() >= self._duck_until_ms:
            self._duck_until_ms = 0
            pygame.mixer.music.set_volume(self.music_volume * self.master_volume)
        
    def on_collision(self, event):
        """충돌 이벤트 처리"""
        collision_type = event.data.get('type')
        position = event.data.get('position')
        
        if collision_type == 'ball_paddle':
            self.play_sound('paddle_hit', 'paddle', position)
        elif collision_type == 'wall':
            self.play_sound('wall_hit', 'wall', position)
        elif collision_type == 'boss':
            self.play_sound('boss_hit', 'boss', position)
            
    def on_item_collected(self, event):
        """아이템 획득 이벤트 처리 - 비활성화 (pingfighter.py에서 이미 사운드 재생)"""
        pass  # 중복 재생 방지
        
    def on_special_activated(self, event):
        """스킬 발동 이벤트 처리"""
        self.play_sound('skill_activate', 'skill')
        
    def on_game_start(self, event):
        """게임 시작 이벤트 처리"""
        stage = event.data.get('stage', 1)
        
        # 스테이지별 배경음악 재생
        music_files = {
            1: 'music/stage1_training.ogg',
            2: 'music/stage2_speed.ogg',
            3: 'music/stage3_emotion.ogg',
            4: 'music/stage4_zen.ogg',
            5: 'music/stage5_inferno.ogg',
            6: 'music/stage6_battleship.ogg'
        }
        
        music_file = music_files.get(stage, 'music/default.ogg')
        self.play_music(music_file, fade_in=True)
        
        # 전투 환경음 시작
        self.play_sound('ambient_battle', 'ambient')
            
    def on_game_over(self, event):
        """게임 오버 이벤트 처리"""
        winner = event.data.get('winner')
        
        if winner == 'player':
            self.play_sound('victory', 'ui')
        else:
            self.play_sound('game_over', 'ui')
            
        self.stop_music()
        
    def on_boss_special(self, event):
        """보스 특수 공격 이벤트 처리"""
        attack_type = event.data.get('attack')
        stage = event.data.get('stage', 1)
        
        self.play_boss_special_sound(attack_type)
        
    def on_boss_phase(self, event):
        """보스 페이즈 변경 이벤트 처리"""
        phase = event.data.get('phase')
        boss_name = event.data.get('boss_name')
        
        self.play_sound('boss_phase', 'boss')
        
        # 페이즈에 따른 음악 변경
        if phase >= 3:
            # 긴박한 음악으로 전환
            if self.current_music:
                # 템포 증가 효과 (실제로는 다른 트랙 재생)
                pygame.mixer.music.set_volume(
                    (self.music_volume * 1.2) * self.master_volume
                )
                
    def on_dash(self, event):
        """대시 이벤트 처리"""
        self.play_sound('dash', 'skill')
        
    def on_round_win(self, event):
        """라운드 승리 이벤트 처리"""
        # 요청: 라운드 승리 사운드 비활성화
        return
        
    def on_round_lose(self, event):
        """라운드 패배 이벤트 처리"""
        # 요청: 라운드 패배 사운드 비활성화
        return
        
    def _calculate_3d_audio(self, position: tuple) -> tuple:
        """3D 오디오 효과 계산
        
        Args:
            position: 사운드 소스 위치
            
        Returns:
            (volume, pan) 튜플
        """
        x, y = position
        lx, ly = self.listener_position
        
        # 거리 계산
        distance = math.sqrt((x - lx) ** 2 + (y - ly) ** 2)
        max_distance = 500  # 최대 청취 거리
        
        # 볼륨 감쇄 (거리에 따라)
        volume = max(0, 1.0 - (distance / max_distance))
        
        # 패닝 (좌우 위치에 따라)
        pan = (x - lx) / 300  # -1.0 ~ 1.0
        pan = max(-1.0, min(1.0, pan))
        
        return volume, pan
        
    def _generate_music(self, filepath: str):
        """배경음악 파일 생성 (간단한 버전)"""
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        
        # 스테이지별 음악 스타일
        stage_num = 1
        if 'stage2' in filepath:
            stage_num = 2
        elif 'stage3' in filepath:
            stage_num = 3
        elif 'stage4' in filepath:
            stage_num = 4
        elif 'stage5' in filepath:
            stage_num = 5
        elif 'stage6' in filepath:
            stage_num = 6
            
        # 각 스테이지별 템포와 분위기
        tempo_map = {
            1: 120,  # 트레이닝 - 보통 템포
            2: 140,  # 스피드 - 빠른 템포
            3: 100,  # 감정 - 느린 템포
            4: 110,  # 젠 - 차분한 템포
            5: 150,  # 인페르노 - 매우 빠른 템포
            6: 130   # 전함 - 웅장한 템포
        }
        
        # 간단한 루프 생성 (실제로는 더 복잡한 음악 생성 필요)
        tempo = tempo_map.get(stage_num, 120)
        duration = 30.0  # 30초 루프
        
        wave_data = self._create_music_loop(tempo, duration)
        self._save_wav_file(filepath, wave_data)
        
    def _create_music_loop(self, tempo: int, duration: float) -> list:
        """음악 루프 생성"""
        sample_rate = 44100
        num_samples = int(sample_rate * duration)
        wave_data = []
        
        # 베이스 라인과 멜로디 생성 (매우 간단한 버전)
        for i in range(num_samples):
            t = i / sample_rate
            
            # 베이스 (낮은 주파수)
            bass = math.sin(2.0 * math.pi * 55 * t) * 0.3
            
            # 멜로디 (템포에 따른 변화)
            melody_freq = 220 * (1 + math.sin(2.0 * math.pi * (tempo/60) * t) * 0.5)
            melody = math.sin(2.0 * math.pi * melody_freq * t) * 0.2
            
            # 드럼 비트 (펄스)
            beat = 0
            if (i % (sample_rate * 60 // tempo)) < 100:
                beat = random.random() * 0.1
                
            # 믹싱
            value = bass + melody + beat
            value *= 0.5  # 전체 볼륨 조절
            
            wave_data.append(int(value * 16383))
            
        return wave_data
        
    def set_listener_position(self, position: tuple):
        """3D 오디오 리스너 위치 설정
        
        Args:
            position: (x, y) 위치
        """
        self.listener_position = position
        
    def play_boss_special_sound(self, special_type: str, position: tuple = None):
        """보스 특수 공격 사운드 재생
        
        Args:
            special_type: 특수 공격 타입
            position: 위치
        """
        sound_map = {
            'whip': 'whip',
            'speed_defense': 'rock_spawn',
            'emotional_overdrive': 'tears',
            'magnetic_field': 'magnetic',
            'flame_throw': 'flame',
            'missile_barrage': 'missile',
            'yamato_charging': 'yamato_charge',
            'yamato_fire': 'yamato_fire'
        }
        
        sound_name = sound_map.get(special_type, 'boss_special')
        self.play_sound(sound_name, 'boss', position)
        
    def cleanup(self):
        """정리"""
        # 페이드 아웃 후 정지
        if self.current_music:
            pygame.mixer.music.fadeout(1000)
            pygame.time.wait(1000)
        
        self.stop_music()
        pygame.mixer.quit()


# 싱글톤 인스턴스
_sound_manager = None

def get_sound_manager() -> SoundManager:
    """사운드 매니저 싱글톤 반환"""
    global _sound_manager
    if _sound_manager is None:
        _sound_manager = SoundManager()
    return _sound_manager
