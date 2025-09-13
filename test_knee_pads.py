#!/usr/bin/env python3
"""무릎보호대 기능 테스트 스크립트"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from item_effects.knee_pads import get_knee_pads_instance

def test_knee_pads():
    print("=" * 50)
    print("무릎보호대 기능 테스트")
    print("=" * 50)
    
    # 무릎보호대 인스턴스 가져오기
    knee_pads = get_knee_pads_instance()
    print(f"1. 무릎보호대 인스턴스 생성: {knee_pads is not None}")
    print(f"   - 초기 active 상태: {knee_pads.active}")
    
    # 활성화 테스트
    print("\n2. 무릎보호대 활성화 테스트")
    knee_pads.activate()
    print(f"   - 활성화 후 active 상태: {knee_pads.active}")
    print(f"   - obtained 상태: {knee_pads.obtained}")
    
    # 하프대쉬 충돌 효과 테스트
    print("\n3. 하프대쉬 충돌 효과 테스트")
    ball_pos = (400, 300)
    result = knee_pads.on_half_dash_hit(ball_pos)
    print(f"   - on_half_dash_hit 호출 결과: {result}")
    print(f"   - flash_timer: {knee_pads.flash_timer}")
    print(f"   - flash_pos: {knee_pads.flash_pos}")
    print(f"   - particles 생성: {len(knee_pads.particles)} 개")
    print(f"   - energy_lines 생성: {len(knee_pads.energy_lines)} 개")
    print(f"   - charge_rings 생성: {len(knee_pads.charge_rings)} 개")
    
    # 업데이트 테스트
    print("\n4. 업데이트 테스트 (5 프레임)")
    for i in range(5):
        knee_pads.update()
        print(f"   프레임 {i+1}: flash_timer={knee_pads.flash_timer}, "
              f"particles={len(knee_pads.particles)}, "
              f"shockwave_radius={knee_pads.shockwave_radius}")
    
    # 비활성화 테스트
    print("\n5. 비활성화 테스트")
    knee_pads.deactivate()
    print(f"   - 비활성화 후 active 상태: {knee_pads.active}")
    print(f"   - obtained 상태: {knee_pads.obtained}")
    print(f"   - flash_timer: {knee_pads.flash_timer}")
    
    # 비활성 상태에서 효과 테스트
    print("\n6. 비활성 상태에서 하프대쉬 충돌 테스트")
    result = knee_pads.on_half_dash_hit(ball_pos)
    print(f"   - on_half_dash_hit 호출 결과: {result}")
    print(f"   - flash_timer: {knee_pads.flash_timer}")
    
    print("\n" + "=" * 50)
    print("테스트 완료!")
    print("=" * 50)

if __name__ == "__main__":
    test_knee_pads()