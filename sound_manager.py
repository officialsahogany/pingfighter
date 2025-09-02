"""
사운드 매니저 모듈
- 게임 내 사운드 생성 및 관리 기능
- 동적 사운드 생성 (WAV 파일 생성)
- 메뉴 사운드 자동 생성
"""

import math
import struct
import wave
import os


def create_button_sound():
    """메뉴 버튼 클릭 사운드 생성"""
    sample_rate = 44100
    duration = 0.1  # 0.1초
    num_samples = int(sample_rate * duration)
    
    wave_data = []
    for i in range(num_samples):
        # 상승하는 주파수 (200Hz에서 400Hz로)
        freq = 200 + (i * 200 / num_samples)
        # 페이드 아웃 효과
        volume = 1.0 - (i / num_samples)
        value = math.sin(2.0 * math.pi * freq * i / sample_rate) * volume
        wave_data.append(int(value * 16383))
    
    return wave_data


def create_hover_sound():
    """버튼 호버 사운드 생성"""
    sample_rate = 44100
    duration = 0.05  # 0.05초
    num_samples = int(sample_rate * duration)
    
    wave_data = []
    for i in range(num_samples):
        # 고정 주파수 (300Hz)
        freq = 300
        # 부드러운 페이드 인/아웃
        volume = math.sin(math.pi * i / num_samples)
        value = math.sin(2.0 * math.pi * freq * i / sample_rate) * volume
        wave_data.append(int(value * 8191))  # 더 작은 볼륨
    
    return wave_data


def save_wav_file(filename, wave_data, sample_rate=44100):
    """WAV 파일로 저장"""
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)  # 모노
        wav_file.setsampwidth(2)  # 16비트
        wav_file.setframerate(sample_rate)
        
        for sample in wave_data:
            wav_file.writeframes(struct.pack('h', sample))


def generate_menu_sounds():
    """메뉴 사운드 파일들이 없으면 생성"""
    sounds_dir = "sounds"
    if not os.path.exists(sounds_dir):
        os.makedirs(sounds_dir)
    
    # 버튼 클릭 사운드
    if not os.path.exists("sounds/button_click.wav"):
        print("...")
        button_sound = create_button_sound()
        save_wav_file("sounds/button_click.wav", button_sound)
        print("button_click.wav")
    
    # 버튼 호버 사운드
    if not os.path.exists("sounds/button_hover.wav"):
        print("...")
        hover_sound = create_hover_sound()
        save_wav_file("sounds/button_hover.wav", hover_sound)
        print("button_hover.wav")


def create_custom_sound(frequency, duration=0.1, fade_type="out", volume=1.0):
    """사용자 정의 사운드 생성
    
    Args:
        frequency (int): 주파수 (Hz)
        duration (float): 지속 시간 (초)
        fade_type (str): 페이드 타입 ("in", "out", "in_out", "none")
        volume (float): 볼륨 (0.0 ~ 1.0)
    
    Returns:
        list: 웨이브 데이터
    """
    sample_rate = 44100
    num_samples = int(sample_rate * duration)
    
    wave_data = []
    for i in range(num_samples):
        # 기본 사인파 생성
        value = math.sin(2.0 * math.pi * frequency * i / sample_rate)
        
        # 페이드 효과 적용
        fade_volume = volume
        if fade_type == "out":
            fade_volume = volume * (1.0 - (i / num_samples))
        elif fade_type == "in":
            fade_volume = volume * (i / num_samples)
        elif fade_type == "in_out":
            fade_volume = volume * math.sin(math.pi * i / num_samples)
        
        # 최종 값 계산
        final_value = value * fade_volume
        wave_data.append(int(final_value * 16383))
    
    return wave_data


def create_sweep_sound(start_freq, end_freq, duration=0.2, fade_type="out"):
    """주파수 스윕 사운드 생성 (주파수가 변화하는 사운드)
    
    Args:
        start_freq (int): 시작 주파수 (Hz)
        end_freq (int): 끝 주파수 (Hz)
        duration (float): 지속 시간 (초)
        fade_type (str): 페이드 타입
    
    Returns:
        list: 웨이브 데이터
    """
    sample_rate = 44100
    num_samples = int(sample_rate * duration)
    
    wave_data = []
    for i in range(num_samples):
        # 선형 주파수 변화
        progress = i / num_samples
        current_freq = start_freq + (end_freq - start_freq) * progress
        
        # 사인파 생성
        value = math.sin(2.0 * math.pi * current_freq * i / sample_rate)
        
        # 페이드 효과
        fade_volume = 1.0
        if fade_type == "out":
            fade_volume = 1.0 - progress
        elif fade_type == "in":
            fade_volume = progress
        elif fade_type == "in_out":
            fade_volume = math.sin(math.pi * progress)
        
        final_value = value * fade_volume
        wave_data.append(int(final_value * 16383))
    
    return wave_data


# 초기화 함수
def initialize_sound_manager():
    """사운드 매니저 초기화 - 게임 시작 시 호출"""
    print("...")
    generate_menu_sounds()
    print("")


# 모듈 로드 시 자동 실행
if __name__ == "__main__":
    # 테스트용 - 직접 실행 시 모든 사운드 생성
    print("")
    initialize_sound_manager()
    
    # 추가 테스트 사운드 생성
    print("...")
    
    # 승리 사운드 (상승)
    victory_sound = create_sweep_sound(300, 600, 0.3, "in")
    save_wav_file("sounds/test_victory.wav", victory_sound)
    
    # 실패 사운드 (하강)
    defeat_sound = create_sweep_sound(400, 200, 0.4, "out")
    save_wav_file("sounds/test_defeat.wav", defeat_sound)
    
    print("")
else:
    # 일반 import 시 기본 사운드만 생성
    initialize_sound_manager()

