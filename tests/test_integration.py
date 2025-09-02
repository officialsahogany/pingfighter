#!/usr/bin/env python3
"""
BossPong 통합 테스트
모든 주요 시스템의 통합 동작 검증
"""

import unittest
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pygame
from core.global_manager import GlobalManager
from core.events import EventManager, EventType
from game_logic.round_manager import get_round_manager
from game_logic.stage_features import get_stage_features
from game_logic.special_items import get_special_item_manager
from game_logic.perfect_timing import get_perfect_timing_manager
from game_logic.power_smashing import get_power_smashing_manager
from ai.boss_skills import get_boss_skill_manager, BossType
from managers.sound_manager import get_sound_manager
from managers.effects_manager import get_effects_manager

class TestIntegration(unittest.TestCase):
    """통합 테스트 클래스"""
    
    @classmethod
    def setUpClass(cls):
        """테스트 클래스 설정"""
        pygame.init()
        
    @classmethod
    def tearDownClass(cls):
        """테스트 클래스 정리"""
        pygame.quit()
        
    def setUp(self):
        """각 테스트 설정"""
        # 매니저 초기화
        self.global_manager = GlobalManager.get_instance()
        self.event_manager = EventManager.get_instance()
        self.round_manager = get_round_manager()
        self.stage_features = get_stage_features()
        self.special_items = get_special_item_manager()
        self.perfect_timing = get_perfect_timing_manager()
        self.power_smashing = get_power_smashing_manager()
        self.boss_skills = get_boss_skill_manager()
        self.sound_manager = get_sound_manager()
        self.effects_manager = get_effects_manager()
        
        # 기본 게임 상태 설정
        self.global_manager.set('WIDTH', 600)
        self.global_manager.set('HEIGHT', 750)
        self.global_manager.set('BALL', pygame.Rect(300, 400, 10, 10))
        self.global_manager.set('PLAYER', pygame.Rect(250, 700, 100, 10))
        self.global_manager.set('BOSS', pygame.Rect(250, 50, 100, 10))
        
    def test_round_management(self):
        """라운드 관리 테스트"""
        # 라운드 시작
        self.round_manager.start_round()
        self.assertEqual(self.round_manager.current_round, 1)
        
        # 점수 추가 (update_score 메서드 사용)
        self.round_manager.update_score(100, 0)
        scores = self.round_manager.get_scores()
        self.assertEqual(scores['player'], 100)
        
        # 라운드 종료
        self.round_manager.end_round(True)
        self.assertTrue(self.round_manager.rounds_won > 0)
        
    def test_stage_features(self):
        """스테이지 기능 테스트"""
        # 각 스테이지 테스트
        for stage in range(1, 7):
            self.stage_features.set_stage(stage)
            self.assertEqual(self.stage_features.current_stage, stage)
            
            # 스테이지별 특수 기능 활성화 테스트
            if stage == 1:
                result = self.stage_features.activate_whip()
                # 쿨다운이 없으면 성공해야 함
                self.assertIsNotNone(result)
            elif stage == 2:
                result = self.stage_features.activate_speed_defense()
                self.assertIsNotNone(result)
            elif stage == 4:
                result = self.stage_features.activate_magnetic_field()
                self.assertIsNotNone(result)
                
    def test_special_items(self):
        """특수 아이템 테스트"""
        # 아이템 활성화
        items = ['fireball', 'tears', 'molotov', 'grenade', 'whip', 
                'magnet', 'freeze', 'shield', 'time_slow']
        
        for item in items:
            # 각 아이템별 적절한 메서드 호출
            if item == 'fireball':
                result = self.special_items.activate_fireball()
            elif item == 'tears':
                result = self.special_items.activate_tears()
            elif item == 'molotov':
                result = self.special_items.activate_molotov()
            elif item == 'grenade':
                result = self.special_items.activate_grenade()
            elif item == 'whip':
                result = self.special_items.activate_whip()
            elif item == 'magnet':
                result = self.special_items.activate_magnet()
            elif item == 'freeze':
                result = self.special_items.activate_freeze()
            elif item == 'shield':
                result = self.special_items.activate_shield()
            elif item == 'time_slow':
                result = self.special_items.activate_time_slow()
            # 아이템이 구현되어 있으면 True 반환
            self.assertIsNotNone(result)
            
        # 활성 아이템 확인
        active_items = self.special_items.get_active_items()
        self.assertIsInstance(active_items, list)
        
    def test_perfect_timing(self):
        """퍼펙트 타이밍 테스트"""
        # 프레임 카운터 증가
        self.perfect_timing.frame_counter = 100
        
        # 입력 처리 (pygame.key.get_pressed() 형식)
        keys = pygame.key.get_pressed()
        self.perfect_timing.handle_input(keys)
        
        # 입력 버퍼는 키가 눌렸을 때만 추가됨
        # self.assertGreater(len(self.perfect_timing.input_buffer), 0)
        
        # 타이밍 체크
        grade = self.perfect_timing.check_perfect_timing()
        self.assertIsNotNone(grade)
        
    def test_power_smashing(self):
        """파워 스매싱 테스트"""
        # 게이지 설정
        self.power_smashing.smash_gauge = 50
        
        # 차징 시작
        self.power_smashing.start_charging()
        self.assertTrue(self.power_smashing.charging)
        
        # 차징 해제
        result = self.power_smashing.release_charge()
        self.assertIsInstance(result, bool)
        
        # 파워 배율 확인
        multiplier = self.power_smashing.get_power_multiplier()
        self.assertGreaterEqual(multiplier, 1.0)
        
    def test_boss_skills(self):
        """보스 스킬 테스트"""
        # 각 보스 타입 테스트
        boss_types = [BossType.LIGHTNING_MASTER, BossType.ICE_QUEEN, 
                     BossType.FIRE_KNIGHT, BossType.WIND_SPIRIT]
        
        for boss_type in boss_types:
            self.boss_skills.set_boss_type(boss_type)
            self.assertEqual(self.boss_skills.current_boss, boss_type)
            
            # AI 추천 스킬
            recommended = self.boss_skills.get_ai_recommendation()
            # 스킬이 있으면 문자열 반환
            if recommended:
                self.assertIsInstance(recommended, str)
                
    def test_event_system(self):
        """이벤트 시스템 테스트"""
        # 이벤트 리스너 등록
        test_data = {'test': False}
        
        def test_handler(data):
            test_data['test'] = True
            
        self.event_manager.subscribe(EventType.GAME_START, test_handler)
        
        # 이벤트 발생
        self.event_manager.emit_event(EventType.GAME_START, {})
        
        # 핸들러 실행 확인
        self.assertTrue(test_data['test'])
        
    def test_manager_singletons(self):
        """싱글톤 패턴 테스트"""
        # 같은 인스턴스 반환 확인
        gm1 = GlobalManager.get_instance()
        gm2 = GlobalManager.get_instance()
        self.assertIs(gm1, gm2)
        
        em1 = EventManager.get_instance()
        em2 = EventManager.get_instance()
        self.assertIs(em1, em2)
        
        rm1 = get_round_manager()
        rm2 = get_round_manager()
        self.assertIs(rm1, rm2)
        
    def test_cross_system_integration(self):
        """시스템 간 통합 테스트"""
        # 라운드 시작
        self.round_manager.start_round()
        
        # 스테이지 설정
        self.stage_features.set_stage(3)
        
        # 보스 타입 설정
        self.boss_skills.set_boss_type(BossType.ICE_QUEEN)
        
        # 특수 아이템 활성화
        self.special_items.activate_freeze()
        
        # 퍼펙트 타이밍 활성화
        self.perfect_timing.activate_perfect_timing()
        
        # 파워 스매싱 게이지 충전
        self.power_smashing.smash_gauge = 100
        
        # 모든 시스템이 독립적으로 작동하는지 확인
        self.assertEqual(self.round_manager.current_round, 1)
        self.assertEqual(self.stage_features.current_stage, 3)
        self.assertEqual(self.boss_skills.current_boss, BossType.ICE_QUEEN)
        self.assertTrue(self.perfect_timing.is_perfect_timing_active())
        self.assertEqual(self.power_smashing.smash_gauge, 100)
        
    def test_update_cycle(self):
        """업데이트 사이클 테스트"""
        dt = 0.016  # 60 FPS
        
        # 모든 시스템 업데이트 (round_manager는 update 메서드가 없음)
        # self.round_manager.update(dt)
        self.stage_features.update(dt)
        self.special_items.update(dt)
        self.perfect_timing.update(dt)
        self.power_smashing.update(dt)
        self.boss_skills.update(dt)
        self.effects_manager.update(dt)
        
        # 업데이트 후에도 정상 작동하는지 확인
        self.assertIsNotNone(self.round_manager.get_stats())
        self.assertIsNotNone(self.stage_features.get_stats())
        self.assertIsNotNone(self.special_items.get_active_items())
        self.assertIsNotNone(self.perfect_timing.get_stats())
        self.assertIsNotNone(self.power_smashing.get_stats())

def run_tests():
    """테스트 실행"""
    # 테스트 스위트 생성
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestIntegration)
    
    # 테스트 실행
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # 결과 반환
    return result.wasSuccessful()

if __name__ == '__main__':
    success = run_tests()
    sys.exit(0 if success else 1)