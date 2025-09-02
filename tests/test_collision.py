"""
Test Collision System - 충돌 시스템 테스트
충돌 감지 및 물리 처리 테스트
"""

import unittest
import pygame
from tests.test_base import BaseTest
from game_logic.collision import CollisionSystem, get_collision_system
from core.events import EventType


class TestCollisionSystem(BaseTest):
    """충돌 시스템 테스트"""
    
    def setUp(self):
        """테스트 설정"""
        super().setUp()
        self.collision_system = CollisionSystem()
        
        # 테스트용 오브젝트 생성
        self.ball_rect = pygame.Rect(300, 400, 20, 20)
        self.player_rect = pygame.Rect(250, 650, 100, 15)
        self.boss_rect = pygame.Rect(250, 50, 100, 15)
        
        # 공 속도
        self.ball_vel = [3, 5]
        
    def test_singleton(self):
        """싱글톤 패턴 테스트"""
        system1 = get_collision_system()
        system2 = get_collision_system()
        self.assertIs(system1, system2)
        
    def test_ball_wall_collision_left(self):
        """왼쪽 벽 충돌 테스트"""
        # 공을 왼쪽 벽에 위치
        self.ball_rect.x = -5
        self.ball_vel[0] = -3
        
        # 충돌 체크
        self.collision_system.check_ball_wall_collision(
            self.ball_rect, self.ball_vel, 600
        )
        
        # 속도 반전 확인
        self.assertGreater(self.ball_vel[0], 0)
        self.assertEqual(self.ball_rect.x, 0)
        
    def test_ball_wall_collision_right(self):
        """오른쪽 벽 충돌 테스트"""
        # 공을 오른쪽 벽에 위치
        self.ball_rect.x = 585
        self.ball_vel[0] = 3
        
        # 충돌 체크
        self.collision_system.check_ball_wall_collision(
            self.ball_rect, self.ball_vel, 600
        )
        
        # 속도 반전 확인
        self.assertLess(self.ball_vel[0], 0)
        self.assertEqual(self.ball_rect.right, 600)
        
    def test_ball_paddle_collision_player(self):
        """플레이어 패들 충돌 테스트"""
        # 공을 플레이어 패들 위에 위치
        self.ball_rect.bottom = self.player_rect.top + 5
        self.ball_rect.centerx = self.player_rect.centerx
        self.ball_vel[1] = 5  # 아래로 이동
        
        # 충돌 체크
        hit = self.collision_system.check_ball_paddle_collision(
            self.ball_rect, self.player_rect, self.ball_vel, is_player=True
        )
        
        # 충돌 확인
        self.assertTrue(hit)
        self.assertLess(self.ball_vel[1], 0)  # 속도 반전
        
    def test_ball_paddle_collision_boss(self):
        """보스 패들 충돌 테스트"""
        # 공을 보스 패들 아래에 위치
        self.ball_rect.top = self.boss_rect.bottom - 5
        self.ball_rect.centerx = self.boss_rect.centerx
        self.ball_vel[1] = -5  # 위로 이동
        
        # 충돌 체크
        hit = self.collision_system.check_ball_paddle_collision(
            self.ball_rect, self.boss_rect, self.ball_vel, is_player=False
        )
        
        # 충돌 확인
        self.assertTrue(hit)
        self.assertGreater(self.ball_vel[1], 0)  # 속도 반전
        
    def test_ball_spin_effect(self):
        """스핀 효과 테스트"""
        # 패들 왼쪽 가장자리 충돌
        self.ball_rect.centerx = self.player_rect.left + 10
        self.ball_rect.bottom = self.player_rect.top + 5
        self.ball_vel = [0, 5]
        
        # 충돌 체크
        self.collision_system.check_ball_paddle_collision(
            self.ball_rect, self.player_rect, self.ball_vel, is_player=True
        )
        
        # 스핀 효과로 x 속도 변경 확인
        self.assertNotEqual(self.ball_vel[0], 0)
        
    def test_ball_out_of_bounds_top(self):
        """상단 경계 벗어남 테스트"""
        # 공을 화면 위로
        self.ball_rect.bottom = -10
        
        # 경계 체크
        scorer = self.collision_system.check_ball_out_of_bounds(
            self.ball_rect, 750
        )
        
        # 플레이어 득점
        self.assertEqual(scorer, 'player')
        
    def test_ball_out_of_bounds_bottom(self):
        """하단 경계 벗어남 테스트"""
        # 공을 화면 아래로
        self.ball_rect.top = 760
        
        # 경계 체크
        scorer = self.collision_system.check_ball_out_of_bounds(
            self.ball_rect, 750
        )
        
        # 보스 득점
        self.assertEqual(scorer, 'boss')
        
    def test_no_collision(self):
        """충돌 없음 테스트"""
        # 공을 중앙에 위치
        self.ball_rect.center = (300, 375)
        
        # 패들 충돌 체크
        hit_player = self.collision_system.check_ball_paddle_collision(
            self.ball_rect, self.player_rect, self.ball_vel, is_player=True
        )
        hit_boss = self.collision_system.check_ball_paddle_collision(
            self.ball_rect, self.boss_rect, self.ball_vel, is_player=False
        )
        
        # 충돌 없음 확인
        self.assertFalse(hit_player)
        self.assertFalse(hit_boss)
        
    def test_corner_collision(self):
        """패들 모서리 충돌 테스트"""
        # 공을 패들 모서리에 위치
        self.ball_rect.bottom = self.player_rect.top + 5
        self.ball_rect.right = self.player_rect.left + 5
        self.ball_vel = [3, 5]
        
        # 충돌 체크
        hit = self.collision_system.check_ball_paddle_collision(
            self.ball_rect, self.player_rect, self.ball_vel, is_player=True
        )
        
        # 충돌 확인
        self.assertTrue(hit)
        # 모서리 충돌시 x 속도도 영향받음
        self.assertLess(self.ball_vel[1], 0)
        
    def test_high_speed_collision(self):
        """고속 충돌 테스트"""
        # 매우 빠른 속도
        self.ball_vel = [15, 20]
        self.ball_rect.bottom = self.player_rect.top + 5
        self.ball_rect.centerx = self.player_rect.centerx
        
        # 충돌 체크
        hit = self.collision_system.check_ball_paddle_collision(
            self.ball_rect, self.player_rect, self.ball_vel, is_player=True
        )
        
        # 충돌 확인
        self.assertTrue(hit)
        # 속도 제한 확인 (너무 빠르지 않게)
        self.assertLessEqual(abs(self.ball_vel[1]), 25)


class TestCollisionEvents(BaseTest):
    """충돌 이벤트 테스트"""
    
    def setUp(self):
        """테스트 설정"""
        super().setUp()
        self.collision_system = CollisionSystem()
        
        # 이벤트 리스너 설정
        self.collision_events = []
        self.event_manager.subscribe(
            EventType.COLLISION,
            lambda e: self.collision_events.append(e.data)
        )
        
    def test_wall_collision_event(self):
        """벽 충돌 이벤트 테스트"""
        ball_rect = pygame.Rect(-5, 400, 20, 20)
        ball_vel = [-3, 5]
        
        # 충돌 체크
        self.collision_system.check_ball_wall_collision(
            ball_rect, ball_vel, 600
        )
        
        # 이벤트 발생 확인
        event_data = self.assert_event_emitted(EventType.COLLISION)
        self.assertIsNotNone(event_data)
        
    def test_paddle_collision_event(self):
        """패들 충돌 이벤트 테스트"""
        ball_rect = pygame.Rect(300, 640, 20, 20)
        player_rect = pygame.Rect(250, 650, 100, 15)
        ball_vel = [0, 5]
        
        # 충돌 체크
        self.collision_system.check_ball_paddle_collision(
            ball_rect, player_rect, ball_vel, is_player=True
        )
        
        # 이벤트 발생 확인
        event_data = self.assert_event_emitted(EventType.COLLISION)
        self.assertIsNotNone(event_data)


if __name__ == '__main__':
    unittest.main()