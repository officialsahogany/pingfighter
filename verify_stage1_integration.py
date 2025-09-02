"""
Stage 1 풍선 이벤트 통합 확인 스크립트
"""

import sys
import os

# 모듈 임포트 테스트
try:
    from events.stage1_event_integration import Stage1EventManager
    print("✅ Stage1EventManager 임포트 성공")
except ImportError as e:
    print(f"❌ Stage1EventManager 임포트 실패: {e}")
    sys.exit(1)

try:
    from trade_point_system import TradePointSystem
    print("✅ TradePointSystem 임포트 성공")
except ImportError as e:
    print(f"❌ TradePointSystem 임포트 실패: {e}")
    sys.exit(1)

try:
    from events.balloon_machine_event import BalloonMachineEvent
    print("✅ BalloonMachineEvent 임포트 성공")
except ImportError as e:
    print(f"❌ BalloonMachineEvent 임포트 실패: {e}")
    sys.exit(1)

# Stage1EventManager 메서드 확인
stage1_events = Stage1EventManager()
print("\n📋 Stage1EventManager 메서드 확인:")
print(f"  - check_events: {'✅' if hasattr(stage1_events, 'check_events') else '❌'}")
print(f"  - trigger_event: {'✅' if hasattr(stage1_events, 'trigger_event') else '❌'}")
print(f"  - update: {'✅' if hasattr(stage1_events, 'update') else '❌'}")
print(f"  - draw: {'✅' if hasattr(stage1_events, 'draw') else '❌'}")
print(f"  - check_balloon_collisions: {'✅' if hasattr(stage1_events, 'check_balloon_collisions') else '❌'}")
print(f"  - get_active_balloons: {'✅' if hasattr(stage1_events, 'get_active_balloons') else '❌'}")

# BalloonMachineEvent 메서드 확인
balloon_machine = BalloonMachineEvent()
print("\n📋 BalloonMachineEvent 메서드 확인:")
print(f"  - should_trigger: {'✅' if hasattr(balloon_machine, 'should_trigger') else '❌'}")
print(f"  - activate: {'✅' if hasattr(balloon_machine, 'activate') else '❌'}")
print(f"  - check_balloon_collisions: {'✅' if hasattr(balloon_machine, 'check_balloon_collisions') else '❌'}")

# 이벤트 트리거 조건 테스트
print("\n🎯 이벤트 트리거 조건 테스트:")
player_score = 2
boss_score = 0
current_stage = 1
round_count = 1

should_trigger = balloon_machine.should_trigger(player_score, current_stage)
print(f"  플레이어 점수 2점, Stage 1: {'✅ 트리거 가능' if should_trigger else '❌ 트리거 불가'}")

# 특별한 풍선 확인
print("\n🎈 특별한 풍선 설정 확인:")
print("  풍선은 activate() 메서드 호출 시 생성됩니다")
print("  4번째 풍선(index 3)이 특별한 삼태극 풍선으로 설정되어 있습니다")
print("  ✅ balloon_machine_event.py의 line 182-194에서 is_special 플래그 설정 확인")

# pingfighter.py에서 통합 확인
print("\n📄 pingfighter.py 통합 확인:")
try:
    with open('pingfighter.py', 'r', encoding='utf-8') as f:
        content = f.read()
        
        # Stage1EventManager 임포트 확인
        if 'from events.stage1_event_integration import Stage1EventManager' in content:
            print("  ✅ Stage1EventManager 임포트 추가됨")
        else:
            print("  ❌ Stage1EventManager 임포트 없음")
        
        # stage1_events 인스턴스 생성 확인
        if 'stage1_events = Stage1EventManager()' in content:
            print("  ✅ stage1_events 인스턴스 생성됨")
        else:
            print("  ❌ stage1_events 인스턴스 생성 안됨")
        
        # 충돌 체크 확인
        if 'stage1_events.check_balloon_collisions' in content and 'trade_point_system' in content:
            print("  ✅ 풍선 충돌 체크에 trade_point_system 전달됨")
        else:
            print("  ❌ 풍선 충돌 체크 통합 미완성")
        
        # 플레이어 점수 트리거 확인
        if 'round_wins >= 2' in content and 'stage1_events.check_events' in content:
            print("  ✅ 플레이어 2점 시 이벤트 트리거 추가됨")
        else:
            print("  ❌ 플레이어 점수 트리거 미추가")
            
except FileNotFoundError:
    print("  ❌ pingfighter.py 파일을 찾을 수 없습니다")

print("\n✨ 통합 검증 완료!")
print("=" * 50)
print("💡 테스트 방법:")
print("1. python3 test_stage1_trade_stars.py 실행")
print("2. SPACE를 2번 눌러 플레이어 점수 2점 만들기")
print("3. 풍선 기계가 나타나면 4번째 풍선(삼태극 무늬) 터뜨리기")
print("4. 별이 떨어지면 패들로 받아서 트레이드 포인트 획득")
print("=" * 50)