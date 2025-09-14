# -*- coding: utf-8 -*-
"""
BGM Manager Module for PingFighter
배경음악 관리를 담당하는 모듈
"""

import pygame
import os
import sys

def resource_path(relative_path):
    """PyInstaller 번들과 일반 실행 모두에서 작동하는 리소스 경로 반환"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

class BGMManager:
    """배경음악 관리 클래스"""
    
    def __init__(self):
        """BGM 매니저 초기화"""
        self.current_bgm = None
        self.volume = 0.4  # 기본 볼륨 40%
        self.bgm_paths = {
            'intro': resource_path(os.path.join("bgm", "introbgm.mp3")),
            'menu': resource_path(os.path.join("bgm", "introbgm.mp3")),  # 메뉴도 같은 BGM 사용
            'stage1': resource_path(os.path.join("bgm", "stage1bgm.mp3")),
            'tutorial': resource_path(os.path.join("bgm", "tutorialbgm.mp3"))
        }
        self.is_initialized = False
        
    def initialize(self):
        """pygame mixer 초기화"""
        if not pygame.mixer.get_init():
            pygame.mixer.init()
        self.is_initialized = True
        print("BGM Manager 초기화 완료")
        
    def play_bgm(self, bgm_name, loop=-1):
        """
        지정된 BGM 재생
        
        Args:
            bgm_name: BGM 이름 ('intro', 'menu', 'stage1', 'tutorial')
            loop: 반복 횟수 (-1은 무한 반복)
        """
        if not self.is_initialized:
            self.initialize()
            
        # 이미 같은 BGM이 재생 중이면 다시 로드하지 않음
        if self.current_bgm == bgm_name and pygame.mixer.music.get_busy():
            print(f"{bgm_name} BGM이 이미 재생 중입니다.")
            return
            
        bgm_path = self.bgm_paths.get(bgm_name)
        if not bgm_path:
            print(f"BGM '{bgm_name}'을 찾을 수 없습니다.")
            return
            
        if not os.path.exists(bgm_path):
            print(f"BGM 파일이 존재하지 않습니다: {bgm_path}")
            return
            
        try:
            pygame.mixer.music.load(bgm_path)
            pygame.mixer.music.set_volume(self.volume)
            pygame.mixer.music.play(loop)
            self.current_bgm = bgm_name
            print(f"{bgm_name} BGM 재생 시작")
        except Exception as e:
            print(f"BGM 로드 실패 ({bgm_name}): {e}")
            
    def stop_bgm(self):
        """현재 재생 중인 BGM 정지"""
        if pygame.mixer.music.get_busy():
            pygame.mixer.music.stop()
            print(f"{self.current_bgm} BGM 정지")
            self.current_bgm = None
            
    def pause_bgm(self):
        """BGM 일시정지"""
        if pygame.mixer.music.get_busy():
            pygame.mixer.music.pause()
            print("BGM 일시정지")
            
    def unpause_bgm(self):
        """BGM 재개"""
        pygame.mixer.music.unpause()
        print("BGM 재개")
        
    def set_volume(self, volume):
        """
        BGM 볼륨 설정
        
        Args:
            volume: 볼륨 값 (0.0 ~ 1.0)
        """
        self.volume = max(0.0, min(1.0, volume))
        pygame.mixer.music.set_volume(self.volume)
        print(f"BGM 볼륨 설정: {self.volume * 100:.0f}%")
        
    def is_playing(self):
        """BGM이 재생 중인지 확인"""
        return pygame.mixer.music.get_busy()
        
    def play_intro_bgm(self):
        """인트로/오프닝 BGM 재생"""
        self.play_bgm('intro')
        
    def play_menu_bgm(self):
        """메인 메뉴 BGM 재생 (이미 재생 중이 아닌 경우)"""
        # 메뉴 BGM이 아닌 다른 BGM이 재생 중이면 멈추고 메뉴 BGM 재생
        if self.current_bgm != 'menu' and self.current_bgm != 'intro':
            self.stop_bgm()
            self.play_bgm('menu')
        elif not self.is_playing():
            self.play_bgm('menu')
            
    def play_stage_bgm(self, stage_num):
        """
        스테이지별 BGM 재생
        
        Args:
            stage_num: 스테이지 번호
        """
        if stage_num == 1:
            self.play_bgm('stage1')
        elif stage_num == 50:  # 튜토리얼
            self.play_bgm('tutorial')
        # 다른 스테이지 BGM은 추후 추가
        else:
            print(f"스테이지 {stage_num}의 BGM이 아직 설정되지 않았습니다.")
            
    def handle_game_start(self):
        """게임 시작 시 BGM 처리"""
        self.stop_bgm()
        
    def handle_return_to_menu(self):
        """메인 메뉴로 복귀 시 BGM 처리"""
        self.play_menu_bgm()

# 싱글톤 인스턴스
bgm_manager = BGMManager()

# 편의 함수들 (기존 코드와의 호환성을 위해)
def play_intro_bgm():
    """인트로 BGM 재생"""
    bgm_manager.play_intro_bgm()
    
def play_menu_bgm():
    """메뉴 BGM 재생"""
    bgm_manager.play_menu_bgm()
    
def play_stage_bgm(stage_num):
    """스테이지 BGM 재생"""
    bgm_manager.play_stage_bgm(stage_num)
    
def stop_bgm():
    """BGM 정지"""
    bgm_manager.stop_bgm()
    
def set_bgm_volume(volume):
    """BGM 볼륨 설정"""
    bgm_manager.set_volume(volume)