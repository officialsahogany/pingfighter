#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🚀 최종 통합 스크립트
모든 모듈을 통합하고 마이그레이션을 완료합니다
"""

import sys
import os
import pygame
from typing import Dict, Any, Optional

# 프로젝트 경로 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.game_state import GameState
from core.dependency_injection import get_container
from core.event_bus import get_event_bus
from game_logic.physics_engine import PhysicsEngine
from game_logic.collision_system import CollisionSystem
from ai.boss_ai_system import BossAISystem
from game_mechanics.item_system import ItemSystem
from game_mechanics.skill_system import SkillSystem
from rendering.render_system import RenderSystem
from ui.ui_system import UISystem
from migration.migration_bridge import MigrationBridge


class IntegratedGameSystem:
    """
    🎮 통합 게임 시스템
    
    모든 모듈화된 시스템을 통합하여 관리합니다.
    """
    
    def __init__(self, screen: pygame.Surface):
        """
        통합 시스템 초기화
        
        Args:
            screen: Pygame 화면
        """
        print("\n" + "="*60)
        print("🚀 PingFighter 통합 시스템 초기화")
        print("="*60)
        
        # DI 컨테이너
        self.container = get_container()
        
        # 이벤트 버스
        self.event_bus = get_event_bus()
        
        # 게임 상태
        self.game_state = GameState.get_instance()
        
        # 마이그레이션 브리지
        self.migration_bridge = MigrationBridge()
        
        # 시스템 초기화
        self._init_systems(screen)
        
        # 시스템 연결
        self._connect_systems()
        
        print("\n✅ 모든 시스템 초기화 완료!")
        print("="*60)
    
    def _init_systems(self, screen: pygame.Surface):
        """모든 시스템 초기화"""
        print("\n📦 시스템 초기화 중...")
        
        # 물리 엔진
        self.physics_engine = self.container.resolve(PhysicsEngine)
        print("  ✅ 물리 엔진")
        
        # 충돌 시스템
        self.collision_system = self.container.resolve(CollisionSystem)
        print("  ✅ 충돌 시스템")
        
        # AI 시스템
        self.ai_system = BossAISystem()
        print("  ✅ AI 시스템")
        
        # 아이템 시스템
        self.item_system = self.container.resolve(ItemSystem)
        print("  ✅ 아이템 시스템")
        
        # 스킬 시스템
        self.skill_system = self.container.resolve(SkillSystem)
        print("  ✅ 스킬 시스템")
        
        # 렌더링 시스템
        self.render_system = RenderSystem(screen)
        print("  ✅ 렌더링 시스템")
        
        # UI 시스템
        self.ui_system = UISystem(screen.get_width(), screen.get_height())
        print("  ✅ UI 시스템")
    
    def _connect_systems(self):
        """시스템 간 연결 설정"""
        print("\n🔗 시스템 연결 중...")
        
        # 충돌 콜백 등록
        self._register_collision_callbacks()
        
        # 이벤트 핸들러 등록
        self._register_event_handlers()
        
        # UI 요소 생성
        self._create_ui_elements()
        
        print("  ✅ 시스템 연결 완료")
    
    def _register_collision_callbacks(self):
        """충돌 콜백 등록"""
        from game_logic.collision_system import CollisionType
        
        # 공-패들 충돌
        self.collision_system.register_callback(
            CollisionType.BALL_PADDLE,
            self._on_ball_paddle_collision
        )
        
        # 공-보스 충돌
        self.collision_system.register_callback(
            CollisionType.BALL_BOSS,
            self._on_ball_boss_collision
        )
        
        # 공-아이템 충돌
        self.collision_system.register_callback(
            CollisionType.BALL_ITEM,
            self._on_ball_item_collision
        )
    
    def _register_event_handlers(self):
        """이벤트 핸들러 등록"""
        # 게임 시작 이벤트
        self.event_bus.subscribe("game.start", self._on_game_start)
        
        # 게임 종료 이벤트
        self.event_bus.subscribe("game.over", self._on_game_over)
        
        # 스테이지 클리어 이벤트
        self.event_bus.subscribe("stage.clear", self._on_stage_clear)
    
    def _create_ui_elements(self):
        """UI 요소 생성"""
        # HUD 생성
        hud = self.ui_system.create_hud()
        self.ui_system.add_element(hud)
        
        # 메인 메뉴 버튼들
        from ui.ui_system import Button
        
        play_button = Button(
            id="play_button",
            text="게임 시작",
            position=(250, 300),
            size=(100, 50)
        )
        play_button.on_click = lambda btn: self.start_game()
        
        self.ui_system.add_element(play_button)
    
    def update(self, dt: float):
        """
        전체 시스템 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 게임 상태 체크
        if not self.game_state.game_running:
            return
        
        if self.game_state.game_paused:
            # UI만 업데이트
            self.ui_system.update(dt)
            return
        
        # 물리 업데이트
        self.physics_engine.update(None, None, None, dt)
        
        # 충돌 검사
        entities = self._get_entities()
        self.collision_system.check_collisions(entities)
        
        # AI 업데이트
        if hasattr(self.game_state, 'boss'):
            self.ai_system.update(dt)
        
        # 아이템 시스템 업데이트
        self.item_system.update(dt, self.game_state)
        
        # 스킬 시스템 업데이트
        self.skill_system.update(dt)
        
        # 렌더링 시스템 업데이트
        self.render_system.update(dt)
        
        # UI 업데이트
        self.ui_system.update(dt)
    
    def render(self, screen: pygame.Surface):
        """
        전체 화면 렌더링
        
        Args:
            screen: Pygame 화면
        """
        # 화면 초기화
        self.render_system.clear()
        
        # 게임 렌더링
        self.render_system.render()
        
        # 아이템 렌더링
        self.item_system.draw_spawned_items(screen)
        
        # 스킬 효과 렌더링
        self.skill_system.draw_effects(screen)
        
        # UI 렌더링
        self.ui_system.draw(screen)
    
    def handle_event(self, event: pygame.event.Event):
        """
        이벤트 처리
        
        Args:
            event: Pygame 이벤트
        """
        # UI 이벤트 우선 처리
        if self.ui_system.handle_event(event):
            return
        
        # 게임 이벤트 처리
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.toggle_pause()
            elif event.key == pygame.K_SPACE:
                self.use_skill("dash")
    
    def start_game(self):
        """게임 시작"""
        print("\n🎮 게임 시작!")
        self.game_state.game_running = True
        self.game_state.current_stage = 1
        self.event_bus.publish({"type": "game.start"})
    
    def toggle_pause(self):
        """일시정지 토글"""
        self.game_state.game_paused = not self.game_state.game_paused
        print(f"⏸️ 게임 {'일시정지' if self.game_state.game_paused else '재개'}")
    
    def use_skill(self, skill_id: str):
        """스킬 사용"""
        # 플레이어 엔티티 가져오기
        player = getattr(self.game_state, 'player', None)
        if player:
            self.skill_system.use_skill(player, skill_id)
    
    def _get_entities(self) -> Dict[str, Any]:
        """엔티티 목록 반환"""
        entities = {}
        
        # 공
        if hasattr(self.game_state, 'balls'):
            entities['balls'] = self.game_state.balls
        
        # 패들
        if hasattr(self.game_state, 'player'):
            entities['paddles'] = [self.game_state.player]
        
        # 보스
        if hasattr(self.game_state, 'boss'):
            entities['boss'] = self.game_state.boss
        
        # 아이템
        entities['items'] = self.item_system.spawned_items
        
        return entities
    
    # 콜백 함수들
    def _on_ball_paddle_collision(self, ball, paddle):
        """공-패들 충돌 처리"""
        # 물리 엔진에 충돌 처리 위임
        self.physics_engine.handle_collision(
            ball, 'paddle', 
            (ball.x, paddle.rect.centery),
            (0, -1), paddle
        )
        
        # 효과 생성
        self.render_system.create_trail(
            (ball.x, ball.y),
            (ball.vel_x, ball.vel_y)
        )
    
    def _on_ball_boss_collision(self, ball, boss):
        """공-보스 충돌 처리"""
        # 데미지 처리
        if hasattr(boss, 'take_damage'):
            boss.take_damage(1)
        
        # 화면 흔들기
        self.render_system.shake_camera(5, 0.2)
    
    def _on_ball_item_collision(self, ball, item):
        """공-아이템 충돌 처리"""
        # 아이템 수집
        self.item_system.collect_item(item)
        
        # 효과 생성
        self.render_system.create_explosion(
            item.position,
            count=10,
            color=item.color
        )
    
    def _on_game_start(self, event):
        """게임 시작 이벤트 처리"""
        # 모든 시스템 리셋
        self.physics_engine.reset()
        self.collision_system.clear_frame()
        self.item_system.reset()
        self.skill_system.reset()
        self.render_system.reset()
    
    def _on_game_over(self, event):
        """게임 종료 이벤트 처리"""
        print("\n💀 게임 오버!")
        self.game_state.game_running = False
    
    def _on_stage_clear(self, event):
        """스테이지 클리어 이벤트 처리"""
        stage = event.get('stage', 0)
        print(f"\n🎉 스테이지 {stage} 클리어!")
        
        # 다음 스테이지로
        self.game_state.current_stage += 1


def validate_integration():
    """통합 검증"""
    print("\n" + "="*60)
    print("🔍 통합 시스템 검증")
    print("="*60)
    
    pygame.init()
    screen = pygame.display.set_mode((600, 750))
    
    try:
        # 통합 시스템 생성
        integrated_system = IntegratedGameSystem(screen)
        
        # 시스템 체크
        checks = {
            "물리 엔진": integrated_system.physics_engine is not None,
            "충돌 시스템": integrated_system.collision_system is not None,
            "AI 시스템": integrated_system.ai_system is not None,
            "아이템 시스템": integrated_system.item_system is not None,
            "스킬 시스템": integrated_system.skill_system is not None,
            "렌더링 시스템": integrated_system.render_system is not None,
            "UI 시스템": integrated_system.ui_system is not None,
            "게임 상태": integrated_system.game_state is not None,
            "이벤트 버스": integrated_system.event_bus is not None,
            "마이그레이션 브리지": integrated_system.migration_bridge is not None,
        }
        
        print("\n📋 시스템 체크리스트:")
        all_passed = True
        for name, status in checks.items():
            icon = "✅" if status else "❌"
            print(f"  {icon} {name}")
            if not status:
                all_passed = False
        
        if all_passed:
            print("\n🎉 모든 시스템 통합 성공!")
            
            # 간단한 업데이트 테스트
            print("\n🔄 업데이트 사이클 테스트...")
            for i in range(5):
                integrated_system.update(0.016)
            print("  ✅ 업데이트 사이클 정상 작동")
            
            return True
        else:
            print("\n❌ 일부 시스템 통합 실패")
            return False
            
    except Exception as e:
        print(f"\n❌ 통합 중 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    finally:
        pygame.quit()


if __name__ == "__main__":
    success = validate_integration()
    sys.exit(0 if success else 1)