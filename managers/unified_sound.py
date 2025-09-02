"""
Unified Sound Manager - Phase 101
통합 사운드 관리 시스템
"""

import pygame
import random
from collections import defaultdict

class UnifiedSoundManager:
    """통합 사운드 관리자"""
    
    def __init__(self):
        self.sounds = {}
        self.music_volume = 0.7
        self.sfx_volume = 0.8
        self.muted = False
        self.current_music = None
        self.sound_cooldowns = defaultdict(int)  # 사운드별 쿨다운
        
    def load_sound(self, name, filepath):
        """사운드 파일 로드"""
        try:
            sound = pygame.mixer.Sound(filepath)
            sound.set_volume(self.sfx_volume)
            self.sounds[name] = sound
            return True
        except:
            print(f"Failed to load sound: {filepath}")
            return False
            
    def load_sounds_batch(self, sound_dict):
        """여러 사운드 한번에 로드"""
        for name, filepath in sound_dict.items():
            self.load_sound(name, filepath)
            
    def play(self, sound_name, volume=None, loops=0):
        """사운드 재생"""
        if self.muted or sound_name not in self.sounds:
            return
            
        # 쿨다운 체크
        current_time = pygame.time.get_ticks()
        if current_time < self.sound_cooldowns[sound_name]:
            return
            
        sound = self.sounds[sound_name]
        if volume is not None:
            sound.set_volume(volume * self.sfx_volume)
        else:
            sound.set_volume(self.sfx_volume)
            
        sound.play(loops)
        
        # 쿨다운 설정 (같은 소리가 너무 자주 나지 않도록)
        self.sound_cooldowns[sound_name] = current_time + 50
        
    def play_random(self, sound_list, volume=None):
        """리스트에서 랜덤하게 하나 재생"""
        if sound_list:
            sound_name = random.choice(sound_list)
            self.play(sound_name, volume)
            
    def play_with_pitch(self, sound_name, pitch=1.0):
        """피치 변경하여 재생 (간단한 구현)"""
        if sound_name in self.sounds:
            # 실제 피치 변경은 복잡하므로 볼륨으로 대체
            volume = min(1.0, 0.5 + pitch * 0.5)
            self.play(sound_name, volume)
            
    def stop(self, sound_name):
        """특정 사운드 정지"""
        if sound_name in self.sounds:
            self.sounds[sound_name].stop()
            
    def stop_all(self):
        """모든 사운드 정지"""
        pygame.mixer.stop()
        
    def play_music(self, filepath, loops=-1, volume=None):
        """배경음악 재생"""
        try:
            pygame.mixer.music.load(filepath)
            if volume is not None:
                pygame.mixer.music.set_volume(volume * self.music_volume)
            else:
                pygame.mixer.music.set_volume(self.music_volume)
            pygame.mixer.music.play(loops)
            self.current_music = filepath
        except:
            print(f"Failed to play music: {filepath}")
            
    def stop_music(self):
        """배경음악 정지"""
        pygame.mixer.music.stop()
        self.current_music = None
        
    def pause_music(self):
        """배경음악 일시정지"""
        pygame.mixer.music.pause()
        
    def unpause_music(self):
        """배경음악 재개"""
        pygame.mixer.music.unpause()
        
    def fade_out_music(self, time_ms):
        """배경음악 페이드 아웃"""
        pygame.mixer.music.fadeout(time_ms)
        
    def set_sfx_volume(self, volume):
        """효과음 볼륨 설정"""
        self.sfx_volume = max(0.0, min(1.0, volume))
        for sound in self.sounds.values():
            sound.set_volume(self.sfx_volume)
            
    def set_music_volume(self, volume):
        """배경음악 볼륨 설정"""
        self.music_volume = max(0.0, min(1.0, volume))
        pygame.mixer.music.set_volume(self.music_volume)
        
    def toggle_mute(self):
        """음소거 토글"""
        self.muted = not self.muted
        if self.muted:
            pygame.mixer.music.set_volume(0)
            for sound in self.sounds.values():
                sound.set_volume(0)
        else:
            pygame.mixer.music.set_volume(self.music_volume)
            for sound in self.sounds.values():
                sound.set_volume(self.sfx_volume)
                
    def play_combo_sound(self, combo_count):
        """콤보 수에 따른 사운드 재생"""
        if combo_count <= 3:
            self.play('hit_1')
        elif combo_count <= 6:
            self.play('hit_2')
        elif combo_count <= 10:
            self.play('hit_3')
        else:
            self.play('hit_super')
            
    def play_impact_sound(self, force):
        """충격 강도에 따른 사운드"""
        if force < 5:
            self.play('impact_light')
        elif force < 10:
            self.play('impact_medium')
        else:
            self.play('impact_heavy')
            
    def create_sound_groups(self):
        """사운드 그룹 생성"""
        self.sound_groups = {
            'hits': ['hit_1', 'hit_2', 'hit_3'],
            'explosions': ['explosion_1', 'explosion_2', 'explosion_3'],
            'powerups': ['powerup_1', 'powerup_2', 'powerup_3'],
            'alerts': ['alert_1', 'alert_2', 'alert_3']
        }
        
    def play_from_group(self, group_name):
        """그룹에서 랜덤 사운드 재생"""
        if group_name in self.sound_groups:
            self.play_random(self.sound_groups[group_name])