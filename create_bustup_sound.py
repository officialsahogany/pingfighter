#!/usr/bin/env python3
"""
버스트업 대쉬 사운드 생성 스크립트
강력한 폭발/확장 느낌의 사운드 생성
"""

import numpy as np
import wave
import struct

# 샘플링 레이트
sample_rate = 44100
duration = 0.5  # 0.5초

# 시간 배열 생성
t = np.linspace(0, duration, int(sample_rate * duration))

# 버스트업 사운드 생성 (폭발적인 확장 느낌)
# 1. 강력한 초기 임팩트 (낮은 주파수 펄스)
impact = np.exp(-10 * t) * np.sin(2 * np.pi * 80 * t)  # 80Hz 임팩트

# 2. 확장 효과 (주파수가 올라가는 스윕)
sweep_freq = 150 + 600 * t  # 150Hz에서 750Hz로 스윕
sweep = 0.5 * np.exp(-3 * t) * np.sin(2 * np.pi * sweep_freq * t)

# 3. 파워풀한 윙 사운드 (고주파수)
whoosh = 0.3 * np.exp(-5 * t) * np.sin(2 * np.pi * 2000 * t) * np.sin(2 * np.pi * 50 * t)

# 4. 폭발 노이즈 효과
noise = 0.2 * np.exp(-8 * t) * np.random.normal(0, 1, len(t))

# 5. 서브 베이스 (깊은 울림)
sub_bass = 0.4 * np.exp(-2 * t) * np.sin(2 * np.pi * 40 * t)

# 모든 요소 합치기
burst_sound = impact + sweep + whoosh + noise + sub_bass

# 볼륨 정규화 (클리핑 방지)
burst_sound = burst_sound / np.max(np.abs(burst_sound)) * 0.8

# 부드러운 페이드 아웃
fade_out = np.ones_like(burst_sound)
fade_out_start = int(len(burst_sound) * 0.7)
fade_out[fade_out_start:] = np.linspace(1, 0, len(burst_sound) - fade_out_start)
burst_sound *= fade_out

# 16비트 정수로 변환
burst_sound_int = np.int16(burst_sound * 32767)

# WAV 파일로 저장
with wave.open('sounds/bustup.wav', 'w') as wav_file:
    wav_file.setnchannels(1)  # 모노
    wav_file.setsampwidth(2)  # 16비트
    wav_file.setframerate(sample_rate)
    
    # 데이터 쓰기
    for sample in burst_sound_int:
        wav_file.writeframes(struct.pack('h', sample))

print("✅ bustup.wav 파일이 생성되었습니다!")
print("   - 길이: 0.5초")
print("   - 특징: 폭발적인 확장 사운드 (임팩트 + 스윕 + 윙 + 서브베이스)")
print("   - 용도: 버스트업 스킬 대쉬 사운드")