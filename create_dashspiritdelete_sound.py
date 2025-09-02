#!/usr/bin/env python3
"""
대쉬 스피릿 소멸 사운드 생성 스크립트
레이저가 공에 맞아 사라질 때 나는 전자 소멸 효과음
"""

import numpy as np
import wave
import struct

# 샘플링 레이트
sample_rate = 44100
duration = 0.3  # 0.3초 (짧고 강렬한 소멸음)

# 시간 배열 생성
t = np.linspace(0, duration, int(sample_rate * duration))

# 대쉬 스피릿 소멸 사운드 생성 (전자 소멸 효과)
# 1. 초기 임팩트 (고주파수 전자음)
impact = np.exp(-15 * t) * np.sin(2 * np.pi * 3000 * t)  # 3000Hz 높은 전자음

# 2. 전기 방전 효과 (지지직 소리)
discharge_freq = 2000 * np.exp(-5 * t)  # 2000Hz에서 빠르게 감소
discharge = 0.6 * np.exp(-10 * t) * np.sin(2 * np.pi * discharge_freq * t)

# 3. 에너지 소멸 스윕 (높은 주파수에서 낮은 주파수로)
sweep_freq = 4000 * np.exp(-8 * t)  # 4000Hz에서 빠르게 하강
sweep = 0.4 * np.exp(-12 * t) * np.sin(2 * np.pi * sweep_freq * t)

# 4. 전기 스파크 노이즈
spark_noise = 0.3 * np.exp(-20 * t) * np.random.normal(0, 1, len(t))
# 고주파수 필터링 효과 (전기 느낌)
for i in range(1, len(spark_noise)):
    spark_noise[i] = spark_noise[i] * 0.3 + spark_noise[i-1] * 0.7

# 5. 잔향 효과 (에코)
echo = 0.2 * np.exp(-5 * t) * np.sin(2 * np.pi * 1500 * t)

# 모든 요소 합치기
delete_sound = impact + discharge + sweep + spark_noise + echo

# 볼륨 정규화 (클리핑 방지)
delete_sound = delete_sound / np.max(np.abs(delete_sound)) * 0.7

# 빠른 페이드 아웃 (소멸 느낌 강조)
fade_out = np.ones_like(delete_sound)
fade_out_start = int(len(delete_sound) * 0.5)
fade_out[fade_out_start:] = np.exp(-15 * np.linspace(0, 1, len(delete_sound) - fade_out_start))
delete_sound *= fade_out

# 16비트 정수로 변환
delete_sound_int = np.int16(delete_sound * 32767)

# WAV 파일로 저장
with wave.open('sounds/dashspiritdelete.wav', 'w') as wav_file:
    wav_file.setnchannels(1)  # 모노
    wav_file.setsampwidth(2)  # 16비트
    wav_file.setframerate(sample_rate)
    
    # 데이터 쓰기
    for sample in delete_sound_int:
        wav_file.writeframes(struct.pack('h', sample))

print("✅ dashspiritdelete.wav 파일이 생성되었습니다!")
print("   - 길이: 0.3초")
print("   - 특징: 전자 소멸 효과 (임팩트 + 방전 + 스윕 + 스파크)")
print("   - 용도: 대쉬 스피릿 레이저가 공에 맞아 사라질 때")