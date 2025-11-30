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
        self._is_paused = False
        self._user_muted = False  # 사용자 토글로 음소거 상태인지
        self._muted_volume_cache = self.volume
        self._muted_last_bgm = None  # 사용자 음소거 시점의 트랙을 기억해 재진입 시 복원
        # 포맷 호환성 확보: mp3 실패 시 ogg/wav 순으로 대체 시도
        # Windows PyInstaller 번들에서 mp3 코덱 누락 시 재생 실패할 수 있음
        self.bgm_candidates = {
            'intro': [
                os.path.join("bgm", "introbgm.ogg"),
                os.path.join("bgm", "introbgm.mp3"),
                os.path.join("bgm", "introbgm.wav"),
            ],
            'menu': [
                os.path.join("bgm", "introbgm.ogg"),
                os.path.join("bgm", "introbgm.mp3"),
                os.path.join("bgm", "introbgm.wav"),
            ],
            'stage1': [
                os.path.join("bgm", "stage1bgm.ogg"),
                os.path.join("bgm", "stage1bgm.mp3"),
                os.path.join("bgm", "stage1bgm.wav"),
            ],
            'stage2': [
                # 새 스테이지2 테마는 WAV 우선으로 재생한다.
                os.path.join("bgm", "stage2bgm.wav"),
                os.path.join("bgm", "stage2bgm.ogg"),
                os.path.join("bgm", "stage2bgm.mp3"),
            ],
            'stage3': [
                os.path.join("bgm", "stage3bgm.ogg"),
                os.path.join("bgm", "stage3bgm.mp3"),
                os.path.join("bgm", "stage3bgm.wav"),
            ],
            'stage4': [
                os.path.join("bgm", "stage4bgm.ogg"),
                os.path.join("bgm", "stage4bgm.mp3"),
                os.path.join("bgm", "stage4bgm.wav"),
            ],
            # Stage 5는 기존 Stage 6 테마(네메시스)를 사용한다.
            'stage5': [
                os.path.join("bgm", "stage6bgm.ogg"),
                os.path.join("bgm", "stage6bgm.mp3"),
                os.path.join("bgm", "stage6bgm.wav"),
            ],
            # Stage 6는 새 Stage 5 테마로 교체
            'stage6': [
                os.path.join("bgm", "stage5bgm.wav"),
                os.path.join("bgm", "stage5bgm.ogg"),
                os.path.join("bgm", "stage5bgm.mp3"),
            ],
            'stage7': [
                os.path.join("bgm", "stage7bgm.wav"),
            ],
            'stage8': [
                os.path.join("bgm", "stage8bgm.wav"),
            ],
            'downtown': [
                os.path.join("bgm", "tutorialmainbgm.mp3"),
                os.path.join("bgm", "tutorialmainbgm.ogg"),
                os.path.join("bgm", "tutorialmainbgm.wav"),
            ],
            'tutorial': [
                os.path.join("bgm", "tutorialmainbgm.ogg"),
                os.path.join("bgm", "tutorialmainbgm.mp3"),
                os.path.join("bgm", "tutorialmainbgm.wav"),
            ],
            'tutorial_genie': [
                os.path.join("bgm", "tutorialbgm.ogg"),
                os.path.join("bgm", "tutorialbgm.mp3"),
                os.path.join("bgm", "tutorialbgm.wav"),
            ],
        }
        self.is_initialized = False
        
    def initialize(self):
        """pygame mixer 초기화"""
        if self.is_initialized:
            return
        if not pygame.mixer.get_init():
            try:
                pygame.mixer.init()
            except Exception as e:
                # 오디오 장치가 없는 환경에서도 실행 가능하도록 dummy 드라이버로 재시도
                try:
                    os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
                    pygame.mixer.init()
                    print(f"⚠️ 오디오 장치 미탑재 감지, dummy 드라이버 사용 ({e})")
                except Exception as e2:
                    print(f"⚠️ BGM 초기화 실패: {e2}")
                    return
        self.is_initialized = True
        pygame.mixer.music.set_volume(self.volume)
        print("BGM Manager 초기화 완료")
        
    def _resolve_bgm_path(self, bgm_name: str) -> str | None:
        """여러 포맷 후보 중 가장 먼저 존재하는 파일 경로를 반환."""
        import os
        # 환경변수로 포맷 강제 (예: PINGF_BGM_EXT=ogg)
        ext_pref = os.getenv('PINGF_BGM_EXT')
        candidates = list(self.bgm_candidates.get(bgm_name, []))
        if ext_pref:
            base_names = set(os.path.splitext(p)[0] for p in candidates)
            forced = [f"{b}.{ext_pref.lstrip('.')}" for b in base_names]
            candidates = forced + candidates
        for rel in candidates:
            full = resource_path(rel)
            if os.path.exists(full):
                return full
        return None

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
            
        # 사용자 음소거 상태면 트랙만 기억하고 재생을 건너뜀
        if getattr(self, "_user_muted", False):
            self._muted_last_bgm = bgm_name
            self.current_bgm = bgm_name
            self._is_paused = True
            print(f"{bgm_name} BGM 요청됨 (사용자 음소거 중, 재생 건너뜀)")
            return
            
        bgm_path = self._resolve_bgm_path(bgm_name)
        if not bgm_path:
            print(f"BGM '{bgm_name}'을 찾을 수 없습니다.")
            return
            
        try:
            try:
                pygame.mixer.music.load(bgm_path)
            except Exception as e:
                print(f"BGM 로드 실패(코덱/포맷 문제 가능): {e}")
                # mp3 실패 시 ogg/wav 재시도 (후보 목록에서 현재 경로 제외)
                retry = None
                for rel in self.bgm_candidates.get(bgm_name, []):
                    alt = resource_path(rel)
                    if alt != bgm_path and os.path.exists(alt):
                        try:
                            pygame.mixer.music.load(alt)
                            retry = alt
                            break
                        except Exception:
                            continue
                if not retry:
                    raise
                else:
                    bgm_path = retry
            pygame.mixer.music.set_volume(self.volume)
            pygame.mixer.music.play(loop)
            self.current_bgm = bgm_name
            self._is_paused = False
            try:
                file_size = os.path.getsize(bgm_path)
            except Exception:
                file_size = "?"
            print(f"{bgm_name} BGM 재생 시작: {os.path.basename(bgm_path)} ({bgm_path}, size={file_size}) busy={pygame.mixer.music.get_busy()}")
        except Exception as e:
            print(f"BGM 로드 실패 ({bgm_name}): {e}")
            
    def stop_bgm(self):
        """현재 재생 중인 BGM 정지"""
        if pygame.mixer.music.get_busy():
            pygame.mixer.music.stop()
            import traceback
            caller = traceback.format_stack(limit=3)[0].strip()
            print(f"{self.current_bgm} BGM 정지 (caller: {caller})")
            self.current_bgm = None
        self._muted_last_bgm = None
        self._is_paused = False
            
    def pause_bgm(self):
        """BGM 일시정지"""
        if pygame.mixer.music.get_busy():
            pygame.mixer.music.pause()
            print("BGM 일시정지")
            self._is_paused = True
            
    def unpause_bgm(self):
        """BGM 재개"""
        if self._user_muted:
            print("BGM 재개 요청 무시: 사용자 음소거 중")
            return
        pygame.mixer.music.unpause()
        self._is_paused = False
        print("BGM 재개")

    def toggle_bgm(self):
        """BGM 토글 (사용자 음소거 on/off)"""
        if not self.is_initialized:
            self.initialize()
        # 음소거 해제
        if self._user_muted:
            self._user_muted = False
            # 볼륨 복원
            pygame.mixer.music.set_volume(self.volume)
            if self._is_paused and pygame.mixer.music.get_busy():
                self.unpause_bgm()
                return False
            target = self.current_bgm or self._muted_last_bgm
            self._muted_last_bgm = None
            if target:
                self.play_bgm(target)
            else:
                print("BGM 토글: 재생할 트랙이 없습니다.")
            return False

        # 음소거로 전환 (현재 재생 중이면 일시정지 + 볼륨 0)
        try:
            # 일시정지가 아니라 완전 정지로 전환해 즉시 끊기도록 처리
            pygame.mixer.music.stop()
        except Exception as e:
            print(f"BGM 정지 실패: {e}")
        self._is_paused = False
        self._muted_last_bgm = self.current_bgm
        self._muted_volume_cache = self.volume
        pygame.mixer.music.set_volume(0)
        self._user_muted = True
        return True
        
    def set_volume(self, volume):
        """
        BGM 볼륨 설정
        
        Args:
            volume: 볼륨 값 (0.0 ~ 1.0)
        """
        self.volume = max(0.0, min(1.0, volume))
        if not self.is_initialized:
            self.initialize()
        if self._user_muted:
            # 음소거 상태에서는 즉시 적용하지 않고 값만 기억
            self._muted_volume_cache = self.volume
        else:
            pygame.mixer.music.set_volume(self.volume)
        print(f"BGM 볼륨 설정: {self.volume * 100:.0f}% (음소거={self._user_muted})")
        
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
        elif stage_num == 2:
            self.play_bgm('stage2')
        elif stage_num == 3:
            self.play_bgm('stage3')
        elif stage_num == 4:
            self.play_bgm('stage4')
        elif stage_num == 5:
            # 네메시스 스테이지 전용 테마
            self.play_bgm('stage5')
        elif stage_num == 6:
            self.play_bgm('stage6')
        elif stage_num == 7:
            self.play_bgm('stage7')
        elif stage_num == 8:
            self.play_bgm('stage8')
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
    
def play_downtown_bgm():
    """번화가 BGM 재생"""
    bgm_manager.play_bgm('downtown')
    
def stop_bgm():
    """BGM 정지"""
    bgm_manager.stop_bgm()
    
def set_bgm_volume(volume):
    """BGM 볼륨 설정"""
    bgm_manager.set_volume(volume)

def toggle_bgm():
    """BGM 토글 (일시정지/재개)"""
    bgm_manager.toggle_bgm()
