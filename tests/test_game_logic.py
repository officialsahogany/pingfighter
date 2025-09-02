"""
Game Logic Tests - 게임 로직 테스트
충돌, 물리, 점수 시스템 테스트
"""

import unittest
import pygame
from tests.test_framework import GameTestCase
from game_logic.collision import CollisionSystem
from game_logic.physics import PhysicsSystem
from game_logic.scoring import ScoringSystem
from game_logic.round_manager import RoundManager


class TestCollisionSystem(GameTestCase):
    """충돌 시스템 테스트"""
    
    def setUp(self):
        super().setUp()
        self.collision = CollisionSystem()
        
    def test_ball_paddle_collision(self):
        """공-패들 충돌 테스트"""
        ball_rect = pygame.Rect(290, 640, 20, 20)  # 패들 근처
        paddle_rect = pygame.Rect(250, 650, 100, 20)
        ball_vel = [0, 5]  # 아래로 이동
        
        # 충돌 체크
        hit = self.collision.check_ball_paddle_collision(
            ball_rect, paddle_rect, ball_vel, is_player=True
        )
        
        self.assertTrue(hit)
        self.assertEqual(ball_vel[1], -5)  # Y 방향 반전
        
    def test_ball_wall_collision(self):
        """공-벽 충돌 테스트"""
        # 왼쪽 벽 충돌
        ball_rect = pygame.Rect(-5, 300, 20, 20)
        ball_vel = [-5, 0]
        
        hit = self.collision.check_ball_wall_collision(ball_rect, ball_vel, 600)
        self.assertTrue(hit)
        self.assertGreater(ball_vel[0], 0)  # X 방향 반전
        
        # 오른쪽 벽 충돌
        ball_rect = pygame.Rect(585, 300, 20, 20)
        ball_vel = [5, 0]
        
        hit = self.collision.check_ball_wall_collision(ball_rect, ball_vel, 600)
        self.assertTrue(hit)
        self.assertLess(ball_vel[0], 0)  # X 방향 반전
        
    def test_ball_out_of_bounds(self):
        """공 아웃 오브 바운드 테스트"""
        # 위쪽으로 나감 (보스 측)
        ball_rect = pygame.Rect(300, -30, 20, 20)
        result = self.collision.check_ball_out_of_bounds(ball_rect, 750)
        self.assertEqual(result, 'player')  # 플레이어 득점
        
        # 아래쪽으로 나감 (플레이어 측)
        ball_rect = pygame.Rect(300, 780, 20, 20)
        result = self.collision.check_ball_out_of_bounds(ball_rect, 750)
        self.assertEqual(result, 'boss')  # 보스 득점
        
        # 화면 내
        ball_rect = pygame.Rect(300, 375, 20, 20)
        result = self.collision.check_ball_out_of_bounds(ball_rect, 750)
        self.assertIsNone(result)


class TestPhysicsSystem(GameTestCase):
    """물리 시스템 테스트"""
    
    def setUp(self):
        super().setUp()
        self.physics = PhysicsSystem()
        
    def test_velocity_limits(self):
        """속도 제한 테스트"""
        # 최소 속도
        self.physics.set_velocity(0.5, 0.5)
        self.physics.limit_velocity()
        speed = self.physics.get_speed()
        self.assertGreaterEqual(speed, self.physics.MIN_SPEED)
        
        # 최대 속도
        self.physics.set_velocity(100, 100)
        self.physics.limit_velocity()
        speed = self.physics.get_speed()
        self.assertLessEqual(speed, self.physics.MAX_SPEED)
        
    def test_bounce(self):
        """튕기기 테스트"""
        self.physics.set_velocity(5, 5)
        
        # 수평 표면에서 튕기기
        self.physics.bounce((0, 1), 1.0)  # 법선이 위쪽
        self.assertAlmostEqual(self.physics.ball_velocity[0], 5, delta=0.1)
        self.assertAlmostEqual(self.physics.ball_velocity[1], -5, delta=0.1)
        
    def test_apply_force(self):
        """힘 적용 테스트"""
        self.physics.ball_acceleration = [0, 0]
        self.physics.add_force(10, 0)
        
        # 질량이 1이므로 가속도 = 힘
        self.assertEqual(self.physics.ball_acceleration[0], 10)
        self.assertEqual(self.physics.ball_acceleration[1], 0)
        
    def test_prediction(self):
        """위치 예측 테스트"""
        self.physics.ball_position = [300, 400]
        self.physics.set_velocity(10, -10)
        
        future_pos = self.physics.predict_position(1.0)  # 1초 후
        
        # 60 FPS 기준으로 계산
        expected_x = 300 + 10 * 60
        expected_y = 400 + (-10) * 60
        
        self.assertAlmostEqual(future_pos[0], expected_x, delta=1)
        self.assertAlmostEqual(future_pos[1], expected_y, delta=1)


class TestScoringSystem(GameTestCase):
    """점수 시스템 테스트"""
    
    def setUp(self):
        super().setUp()
        self.scoring = ScoringSystem()
        self.scoring.reset()
        
    def test_add_point(self):
        """점수 추가 테스트"""
        result = self.scoring.add_point('player')
        
        self.assertEqual(self.scoring.player_score, 1)
        self.assertEqual(self.scoring.boss_score, 0)
        self.assertEqual(result['scorer'], 'player')
        
    def test_win_condition(self):
        """승리 조건 테스트"""
        # 일반 승리
        self.scoring.player_score = 10
        self.scoring.boss_score = 5
        
        winner = self.scoring.check_round_winner()
        self.assertIsNone(winner)  # 아직 11점 미만
        
        self.scoring.player_score = 11
        winner = self.scoring.check_round_winner()
        self.assertEqual(winner, 'player')
        
    def test_deuce_mode(self):
        """듀스 모드 테스트"""
        # 듀스 진입
        self.scoring.player_score = 10
        self.scoring.boss_score = 10
        self.scoring.check_deuce_mode()
        
        self.assertTrue(self.scoring.deuce_mode)
        
        # 듀스에서 승리 (2점 차이 필요)
        self.scoring.player_score = 11
        winner = self.scoring.check_round_winner()
        self.assertIsNone(winner)  # 1점 차이로는 승리 못함
        
        self.scoring.player_score = 12
        winner = self.scoring.check_round_winner()
        self.assertEqual(winner, 'player')  # 2점 차이로 승리
        
    def test_rally_bonus(self):
        """랠리 보너스 테스트"""
        self.scoring.rally_count = 15
        self.scoring.end_rally()
        
        # 긴 랠리는 점수 배수 증가
        self.assertGreater(self.scoring.score_multiplier, 1.0)


class TestRoundManager(GameTestCase):
    """라운드 매니저 테스트"""
    
    def setUp(self):
        super().setUp()
        self.round_manager = RoundManager()
        self.round_manager.reset()
        
    def test_round_start(self):
        """라운드 시작 테스트"""
        success = self.round_manager.start_round()
        
        self.assertTrue(success)
        self.assertEqual(self.round_manager.round_state, 'serving')
        
    def test_server_rotation(self):
        """서브 로테이션 테스트"""
        # 첫 서브
        self.round_manager.determine_server()
        first_server = self.round_manager.server
        
        # 서비스 로테이션
        for _ in range(self.round_manager.service_rotation):
            self.round_manager.service_count += 1
            
        self.round_manager.determine_server()
        self.assertNotEqual(self.round_manager.server, first_server)
        
    def test_timeout(self):
        """타임아웃 테스트"""
        self.round_manager.round_state = 'playing'
        
        # 타임아웃 요청
        success = self.round_manager.call_timeout('player')
        
        self.assertTrue(success)
        self.assertTrue(self.round_manager.timeout_active)
        self.assertEqual(self.round_manager.timeout_count['player'], 1)
        
        # 타임아웃 종료
        self.round_manager.end_timeout()
        self.assertFalse(self.round_manager.timeout_active)
        
    def test_set_management(self):
        """세트 관리 테스트"""
        # 라운드 승리 기록
        self.round_manager.round_history.append({
            'winner': 'player',
            'set': 1,
            'score': (11, 5),
            'duration': 120
        })
        
        self.round_manager.round_history.append({
            'winner': 'player',
            'set': 1,
            'score': (11, 7),
            'duration': 150
        })
        
        # 세트 종료 체크
        should_end = self.round_manager.should_end_set()
        self.assertTrue(should_end)  # 2승으로 세트 종료


class TestIntegration(GameTestCase):
    """게임 로직 통합 테스트"""
    
    def test_full_point_flow(self):
        """전체 득점 플로우 테스트"""
        collision = CollisionSystem()
        physics = PhysicsSystem()
        scoring = ScoringSystem()
        
        # 공 설정
        physics.ball_position = [300, 100]
        physics.set_velocity(0, -10)
        
        # 공이 위쪽 경계 넘어감
        ball_rect = pygame.Rect(300, -30, 20, 20)
        scorer = collision.check_ball_out_of_bounds(ball_rect, 750)
        
        # 플레이어 득점
        self.assertEqual(scorer, 'player')
        
        # 점수 추가
        result = scoring.add_point(scorer)
        self.assertEqual(scoring.player_score, 1)
        
        # 공 리셋
        physics.reset()
        self.assertEqual(physics.ball_position[0], 300)
        self.assertEqual(physics.ball_position[1], 375)


if __name__ == '__main__':
    unittest.main()