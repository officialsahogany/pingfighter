#!/usr/bin/env python3
"""
AK-47 통합 테스트 - 완전한 시스템 테스트
"""
import sys
import os
import pygame

# 경로 설정
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("AK-47 통합 테스트")

def resource_path(relative_path):
    """파일 경로 처리 함수"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

def test_ak47_system():
    """AK-47 시스템 전체 테스트"""
    print("🔫 AK-47 통합 테스트 시작")
    
    # 1. 아이템 모듈 테스트
    print("\n1️⃣ items.py에서 AK-47 확인...")
    try:
        import items
        
        # ITEM_TYPES에서 AK-47 검색
        ak47_found = False
        for item in items.ITEM_TYPES:
            if item.get("name") == "ak47":
                ak47_found = True
                print(f"   ✅ ITEM_TYPES에서 발견: {item}")
                break
        
        if not ak47_found:
            print("   ❌ ITEM_TYPES에서 AK-47을 찾을 수 없음")
            return False
        
        # unlocked_items 확인
        if "ak47" in items.unlocked_items and items.unlocked_items["ak47"]:
            print("   ✅ unlocked_items에서 활성화됨")
        else:
            print("   ❌ unlocked_items에서 비활성화됨")
            
    except Exception as e:
        print(f"   ❌ items.py 테스트 실패: {e}")
        return False
    
    # 2. 아이템 효과 모듈 테스트
    print("\n2️⃣ item_effects/ak47.py 테스트...")
    try:
        from item_effects.ak47 import get_ak47_instance, AK47
        
        ak47 = get_ak47_instance()
        print(f"   ✅ AK-47 인스턴스 생성: {type(ak47)}")
        print(f"   📊 초기 상태: active={ak47.active}, 탄약={ak47.current_ammo}/{ak47.max_ammo}")
        
        # 활성화 테스트
        ak47.activate(None, 1)
        print(f"   🔄 활성화 후: active={ak47.active}")
        
        # 발사 테스트
        if ak47.can_fire():
            # 가짜 player_rect와 ball_rect 생성
            import pygame
            player_rect = pygame.Rect(100, 300, 50, 50)
            ball_rect = pygame.Rect(400, 300, 20, 20)
            ak47.fire(player_rect, ball_rect)
            print(f"   🔫 발사 후 탄약: {ak47.current_ammo}/{ak47.max_ammo}")
            print(f"   💥 활성 총알 수: {len(ak47.bullets)}")
        
        # 업데이트 테스트
        ak47.update(1)
        print("   ✅ 업데이트 성공")
        
    except Exception as e:
        print(f"   ❌ item_effects/ak47.py 테스트 실패: {e}")
        return False
    
    # 3. 아이콘 테스트
    print("\n3️⃣ 아이콘 테스트...")
    try:
        # 아이콘 파일 확인
        icon_path = resource_path("items/ak47.png")
        if os.path.exists(icon_path):
            print(f"   ✅ 아이콘 파일 존재: {icon_path}")
            icon = pygame.image.load(icon_path)
            print(f"   📏 아이콘 크기: {icon.get_size()}")
        else:
            print(f"   ⚠️ 아이콘 파일 없음: {icon_path}")
            print("   ℹ️ 프로그래밍 방식으로 아이콘 생성됨")
            
    except Exception as e:
        print(f"   ❌ 아이콘 테스트 실패: {e}")
    
    # 4. 메인 게임 통합 테스트 (기본적인 import만)
    print("\n4️⃣ 메인 게임 통합 확인...")
    try:
        # pingfighter.py에서 AK-47 관련 함수들이 존재하는지 확인
        import pingfighter
        
        # 핵심 함수들 확인
        required_elements = [
            'get_ak47_instance',  # import 확인
            'soldier_weapons',    # 화기류 리스트
        ]
        
        checks_passed = 0
        for element in required_elements:
            if hasattr(pingfighter, element) or element in dir(pingfighter):
                print(f"   ✅ {element} 발견")
                checks_passed += 1
            else:
                print(f"   ⚠️ {element} 미확인")
        
        print(f"   📊 통합 점검: {checks_passed}/{len(required_elements)} 통과")
        
    except Exception as e:
        print(f"   ❌ 메인 게임 통합 확인 실패: {e}")
    
    print("\n🎯 AK-47 통합 테스트 완료!")
    print("   게임을 실행하여 실제 동작을 확인하세요.")
    return True

def test_visual_effects():
    """시각적 효과 테스트"""
    print("\n🎨 시각적 효과 테스트 시작...")
    
    try:
        from item_effects.ak47 import get_ak47_instance
        
        ak47 = get_ak47_instance()
        ak47.activate(None, 1)
        
        # 테스트용 화면
        screen.fill((0, 0, 0))
        
        # 총알 발사 및 그리기 테스트
        player_rect = pygame.Rect(100, 300, 50, 50)
        ball_rect1 = pygame.Rect(200, 300, 20, 20)  # 오른쪽 공
        ball_rect2 = pygame.Rect(50, 300, 20, 20)   # 왼쪽 공
        
        ak47.fire(player_rect, ball_rect1)  # 오른쪽으로 발사
        ak47.fire(player_rect, ball_rect2)  # 왼쪽으로 발사
        
        # 몇 프레임 업데이트
        for _ in range(10):
            ak47.update(1)
        
        # 총알 그리기
        ak47.draw_bullets(screen)
        
        print("   ✅ 총알 그리기 테스트 성공")
        print(f"   💥 활성 총알 수: {len(ak47.bullets)}")
        
        # 화면 업데이트
        pygame.display.flip()
        
        return True
        
    except Exception as e:
        print(f"   ❌ 시각적 효과 테스트 실패: {e}")
        return False

if __name__ == "__main__":
    print("🚀 AK-47 완전 통합 테스트")
    print("=" * 50)
    
    success = test_ak47_system()
    
    if success:
        test_visual_effects()
        print("\n🎉 모든 테스트 완료!")
        print("   F5를 눌러 솔져로 게임을 시작하고")
        print("   AK-47 아이템을 얻어 테스트해보세요!")
    else:
        print("\n❌ 일부 테스트 실패!")
    
    # 잠시 대기
    import time
    time.sleep(3)
    
    pygame.quit()
    sys.exit()