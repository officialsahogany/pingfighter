"""
Test Scoring System - 점수 시스템 테스트
점수 계산, 라운드 승리 조건, 메달 시스템 테스트
"""

import unittest
from tests.test_base import BaseTest
from game_logic.scoring import ScoringSystem, get_scoring_system
from core.events import EventType


class TestScoringSystem(BaseTest):
    """점수 시스템 테스트"""
    
    def setUp(self):
        """테스트 설정"""
        super().setUp()
        self.scoring_system = ScoringSystem()
        
    def test_singleton(self):
        """싱글톤 패턴 테스트"""
        system1 = get_scoring_system()
        system2 = get_scoring_system()
        self.assertIs(system1, system2)
        
    def test_initial_state(self):
        """초기 상태 테스트"""
        self.assertEqual(self.scoring_system.player_score, 0)
        self.assertEqual(self.scoring_system.boss_score, 0)
        self.assertEqual(self.scoring_system.medal_score, 0)
        self.assertEqual(self.scoring_system.round_wins, 0)
        self.assertEqual(self.scoring_system.round_losses, 0)
        
    def test_add_player_score(self):
        """플레이어 점수 추가 테스트"""
        # 점수 추가
        self.scoring_system.add_player_score()
        self.assertEqual(self.scoring_system.player_score, 1)
        
        # 여러 번 추가
        for _ in range(4):
            self.scoring_system.add_player_score()
        self.assertEqual(self.scoring_system.player_score, 5)
        
    def test_add_boss_score(self):
        """보스 점수 추가 테스트"""
        # 점수 추가
        self.scoring_system.add_boss_score()
        self.assertEqual(self.scoring_system.boss_score, 1)
        
        # 여러 번 추가
        for _ in range(4):
            self.scoring_system.add_boss_score()
        self.assertEqual(self.scoring_system.boss_score, 5)
        
    def test_round_win_condition_normal(self):
        """일반 라운드 승리 조건 테스트"""
        # 11점 승리 설정
        self.scoring_system.set_stage_config(1)
        
        # 10점까지는 라운드 종료 안됨
        for _ in range(10):
            round_ended = self.scoring_system.add_player_score()
            self.assertFalse(round_ended)
            
        # 11점에서 라운드 종료
        round_ended = self.scoring_system.add_player_score()
        self.assertTrue(round_ended)
        self.assertEqual(self.scoring_system.round_wins, 1)
        
    def test_deuce_mode(self):
        """듀스 모드 테스트"""
        # 10-10 상황 만들기
        for _ in range(10):
            self.scoring_system.add_player_score()
            self.scoring_system.add_boss_score()
            
        # 듀스 모드 확인
        self.assertTrue(self.scoring_system.is_deuce)
        
        # 듀스에서는 2점 차이로 승리
        self.scoring_system.add_player_score()  # 11-10
        round_ended = self.scoring_system.add_player_score()  # 12-10
        self.assertTrue(round_ended)
        
    def test_deuce_back_and_forth(self):
        """듀스 모드 왔다갔다 테스트"""
        # 10-10 듀스
        for _ in range(10):
            self.scoring_system.add_player_score()
            self.scoring_system.add_boss_score()
            
        # 11-10
        self.scoring_system.add_player_score()
        self.assertTrue(self.scoring_system.is_deuce)
        
        # 11-11
        self.scoring_system.add_boss_score()
        self.assertTrue(self.scoring_system.is_deuce)
        
        # 12-11
        self.scoring_system.add_player_score()
        self.assertTrue(self.scoring_system.is_deuce)
        
        # 12-13 보스 승리
        self.scoring_system.add_boss_score()
        round_ended = self.scoring_system.add_boss_score()
        self.assertTrue(round_ended)
        self.assertEqual(self.scoring_system.round_losses, 1)
        
    def test_add_medal(self):
        """메달 추가 테스트"""
        # 메달 추가
        self.scoring_system.add_medal(10)
        self.assertEqual(self.scoring_system.medal_score, 10)
        
        # 추가 메달
        self.scoring_system.add_medal(5)
        self.assertEqual(self.scoring_system.medal_score, 15)
        
        # 음수 메달 (차감)
        self.scoring_system.add_medal(-3)
        self.assertEqual(self.scoring_system.medal_score, 12)
        
    def test_reset(self):
        """리셋 테스트"""
        # 점수 설정
        self.scoring_system.add_player_score()
        self.scoring_system.add_boss_score()
        self.scoring_system.add_medal(10)
        
        # 리셋
        self.scoring_system.reset()
        
        # 점수만 리셋, 라운드는 유지
        self.assertEqual(self.scoring_system.player_score, 0)
        self.assertEqual(self.scoring_system.boss_score, 0)
        self.assertEqual(self.scoring_system.medal_score, 10)
        
    def test_reset_stage(self):
        """스테이지 리셋 테스트"""
        # 라운드 승리 기록
        for _ in range(11):
            self.scoring_system.add_player_score()
        self.scoring_system.reset()
        
        # 스테이지 리셋
        self.scoring_system.reset_stage()
        
        # 라운드 승리도 리셋
        self.assertEqual(self.scoring_system.round_wins, 0)
        self.assertEqual(self.scoring_system.round_losses, 0)
        
    def test_reset_all(self):
        """전체 리셋 테스트"""
        # 모든 점수 설정
        self.scoring_system.add_player_score()
        self.scoring_system.add_medal(100)
        self.scoring_system.round_wins = 2
        
        # 전체 리셋
        self.scoring_system.reset_all()
        
        # 모든 것이 리셋
        self.assertEqual(self.scoring_system.player_score, 0)
        self.assertEqual(self.scoring_system.medal_score, 0)
        self.assertEqual(self.scoring_system.round_wins, 0)
        
    def test_get_score_text(self):
        """점수 텍스트 테스트"""
        self.scoring_system.player_score = 5
        self.scoring_system.boss_score = 3
        
        score_text = self.scoring_system.get_score_text()
        self.assertEqual(score_text, "5 - 3")
        
        # 듀스 모드
        self.scoring_system.player_score = 11
        self.scoring_system.boss_score = 10
        self.scoring_system.is_deuce = True
        
        score_text = self.scoring_system.get_score_text()
        self.assertEqual(score_text, "11 - 10 (DEUCE)")
        
    def test_stage_specific_config(self):
        """스테이지별 설정 테스트"""
        # 스테이지 3 설정 (변칙 룰)
        self.scoring_system.set_stage_config(3)
        
        # 7점 승리 확인
        for _ in range(6):
            round_ended = self.scoring_system.add_player_score()
            self.assertFalse(round_ended)
            
        round_ended = self.scoring_system.add_player_score()
        self.assertTrue(round_ended)
        
    def test_score_events(self):
        """점수 이벤트 테스트"""
        # 이벤트 리스너 설정
        score_events = []
        self.event_manager.subscribe(
            EventType.PLAYER_SCORE,
            lambda e: score_events.append(e.data)
        )
        
        # 플레이어 득점
        self.scoring_system.add_player_score()
        
        # 이벤트 확인
        event_data = self.assert_event_emitted(EventType.PLAYER_SCORE)
        self.assertIsNotNone(event_data)
        self.assertEqual(event_data['score'], 1)
        
    def test_deuce_event(self):
        """듀스 이벤트 테스트"""
        # 10-10 듀스 상황
        for _ in range(10):
            self.scoring_system.add_player_score()
            self.scoring_system.add_boss_score()
            
        # 듀스 이벤트 확인
        event_data = self.assert_event_emitted(EventType.DEUCE_MODE)
        self.assertIsNotNone(event_data)


class TestScoringIntegration(BaseTest):
    """점수 시스템 통합 테스트"""
    
    def setUp(self):
        """테스트 설정"""
        super().setUp()
        self.scoring_system = get_scoring_system()
        
    def test_full_match_flow(self):
        """전체 매치 플로우 테스트"""
        # 스테이지 1 설정
        self.scoring_system.set_stage_config(1)
        
        # 첫 라운드: 플레이어 승리
        for _ in range(11):
            self.scoring_system.add_player_score()
        self.assertEqual(self.scoring_system.round_wins, 1)
        
        # 리셋 후 두 번째 라운드
        self.scoring_system.reset()
        
        # 두 번째 라운드: 보스 승리
        for _ in range(11):
            self.scoring_system.add_boss_score()
        self.assertEqual(self.scoring_system.round_losses, 1)
        
        # 최종 스코어 확인
        self.assertEqual(self.scoring_system.round_wins, 1)
        self.assertEqual(self.scoring_system.round_losses, 1)
        
    def test_medal_accumulation(self):
        """메달 누적 테스트"""
        # 여러 라운드에 걸쳐 메달 획득
        self.scoring_system.add_medal(10)
        
        # 라운드 리셋
        self.scoring_system.reset()
        self.scoring_system.add_medal(5)
        
        # 스테이지 리셋
        self.scoring_system.reset_stage()
        self.scoring_system.add_medal(3)
        
        # 총 메달 확인
        self.assertEqual(self.scoring_system.medal_score, 18)


if __name__ == '__main__':
    unittest.main()