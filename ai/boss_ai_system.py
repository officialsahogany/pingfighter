# -*- coding: utf-8 -*-
"""
보스 AI 시스템
모든 보스의 AI 행동 패턴과 난이도 관리
"""

import pygame
import math
import random
from typing import Dict, Any, Optional, Tuple, List
from enum import Enum
from dataclasses import dataclass


class AIDifficulty(Enum):
    """AI 난이도 레벨"""
    JUNIOR = "junior"      # 초보 - 반응 속도 느림, 실수 많음
    PRO = "pro"            # 프로 - 균형잡힌 플레이
    CHAMPION = "champion"  # 챔피언 - 빠른 반응, 예측 플레이
    MYTHIC = "mythic"      # 신화 - 완벽에 가까운 플레이


class AIBehavior(Enum):
    """AI 행동 패턴"""
    DEFENSIVE = "defensive"    # 수비적 플레이
    BALANCED = "balanced"      # 균형잡힌 플레이
    AGGRESSIVE = "aggressive"  # 공격적 플레이
    ADAPTIVE = "adaptive"      # 적응형 플레이


@dataclass
class AIConfig:
    """AI 설정"""
    reaction_time: float = 0.3      # 반응 시간 (초)
    prediction_depth: int = 1        # 예측 깊이
    error_rate: float = 0.1         # 실수 확률
    speed_multiplier: float = 1.0   # 속도 배수
    skill_usage_rate: float = 0.5   # 스킬 사용 빈도
    learning_rate: float = 0.0      # 학습률 (적응형 AI)


class BossAISystem:
    """
    보스 AI 시스템
    
    모든 보스의 인공지능을 관리하고 난이도별 행동을 제어합니다.
    """
    
    # 난이도별 기본 설정
    DIFFICULTY_CONFIGS = {
        AIDifficulty.JUNIOR: AIConfig(
            reaction_time=0.5,
            prediction_depth=0,
            error_rate=0.3,
            speed_multiplier=0.7,
            skill_usage_rate=0.2
        ),
        AIDifficulty.PRO: AIConfig(
            reaction_time=0.3,
            prediction_depth=1,
            error_rate=0.15,
            speed_multiplier=1.0,
            skill_usage_rate=0.4
        ),
        AIDifficulty.CHAMPION: AIConfig(
            reaction_time=0.15,
            prediction_depth=2,
            error_rate=0.05,
            speed_multiplier=1.3,
            skill_usage_rate=0.6
        ),
        AIDifficulty.MYTHIC: AIConfig(
            reaction_time=0.05,
            prediction_depth=3,
            error_rate=0.01,
            speed_multiplier=1.5,
            skill_usage_rate=0.8,
            learning_rate=0.1
        )
    }
    
    def __init__(self, difficulty: AIDifficulty = AIDifficulty.PRO):
        """
        AI 시스템 초기화
        
        Args:
            difficulty: AI 난이도
        """
        self.difficulty = difficulty
        # dataclass는 copy() 메서드가 없으므로 필드를 직접 복사
        import copy
        self.config = copy.deepcopy(self.DIFFICULTY_CONFIGS[difficulty])
        self.behavior = AIBehavior.BALANCED
        
        # 상태 추적
        self.last_decision_time = 0
        self.current_target = None
        self.prediction_cache = {}
        
        # 학습 데이터 (Mythic 모드)
        self.player_patterns = []
        self.adaptation_score = 0
        
        # 스테이지별 특수 AI
        self.stage_behaviors = {}
        
        print(f"🤖 Boss AI System 초기화 (난이도: {difficulty.value})")
    
    def update(self, boss: Any, ball: Any, player: Any, dt: float) -> Dict[str, Any]:
        """
        AI 업데이트 및 행동 결정
        
        Args:
            boss: 보스 객체
            ball: 공 객체
            player: 플레이어 객체
            dt: 델타 시간
            
        Returns:
            행동 딕셔너리 {move_direction, use_skill, special_action}
        """
        current_time = pygame.time.get_ticks() / 1000.0
        
        # 반응 시간 체크
        if current_time - self.last_decision_time < self.config.reaction_time:
            return {"move_direction": 0, "use_skill": False}
        
        self.last_decision_time = current_time
        
        # 공 위치 예측
        predicted_position = self._predict_ball_position(ball, self.config.prediction_depth)
        
        # 실수 적용
        if random.random() < self.config.error_rate:
            predicted_position = self._apply_error(predicted_position)
        
        # 이동 방향 결정
        move_direction = self._calculate_move_direction(boss, predicted_position)
        
        # 스킬 사용 결정
        use_skill = self._should_use_skill(boss, ball, player)
        
        # 특수 행동 결정
        special_action = self._determine_special_action(boss, ball, player)
        
        # Mythic 모드: 플레이어 패턴 학습
        if self.difficulty == AIDifficulty.MYTHIC:
            self._learn_player_pattern(player, ball)
        
        return {
            "move_direction": move_direction,
            "use_skill": use_skill,
            "special_action": special_action,
            "target_position": predicted_position
        }
    
    def _predict_ball_position(self, ball: Any, depth: int) -> Tuple[float, float]:
        """
        공의 미래 위치 예측
        
        Args:
            ball: 공 객체
            depth: 예측 깊이 (프레임 수)
            
        Returns:
            예측된 (x, y) 위치
        """
        if depth == 0 or not hasattr(ball, 'vel_x'):
            return (ball.x, ball.y)
        
        # 간단한 선형 예측
        future_x = ball.x + ball.vel_x * depth * 0.016  # 60fps 기준
        future_y = ball.y + ball.vel_y * depth * 0.016
        
        # 벽 반사 고려
        if future_x < 0 or future_x > 600:  # 화면 너비
            future_x = ball.x
        
        return (future_x, future_y)
    
    def _apply_error(self, position: Tuple[float, float]) -> Tuple[float, float]:
        """
        예측 위치에 오차 적용
        
        Args:
            position: 원래 위치
            
        Returns:
            오차가 적용된 위치
        """
        error_x = random.uniform(-30, 30) * self.config.error_rate
        error_y = random.uniform(-30, 30) * self.config.error_rate
        
        return (position[0] + error_x, position[1] + error_y)
    
    def _calculate_move_direction(self, boss: Any, target: Tuple[float, float]) -> float:
        """
        이동 방향 계산
        
        Args:
            boss: 보스 객체
            target: 목표 위치
            
        Returns:
            이동 방향 (-1: 왼쪽, 0: 정지, 1: 오른쪽)
        """
        if not hasattr(boss, 'rect'):
            return 0
        
        boss_center = boss.rect.centerx
        target_x = target[0]
        
        # 데드존 (움직이지 않는 범위)
        deadzone = 10 * (2 - self.config.speed_multiplier)
        
        if abs(boss_center - target_x) < deadzone:
            return 0
        elif boss_center < target_x:
            return 1 * self.config.speed_multiplier
        else:
            return -1 * self.config.speed_multiplier
    
    def _should_use_skill(self, boss: Any, ball: Any, player: Any) -> bool:
        """
        스킬 사용 여부 결정
        
        Args:
            boss: 보스 객체
            ball: 공 객체
            player: 플레이어 객체
            
        Returns:
            스킬 사용 여부
        """
        # 스킬 사용 빈도 체크
        if random.random() > self.config.skill_usage_rate:
            return False
        
        # 스킬별 조건 체크
        if hasattr(boss, 'special_gauge'):
            if boss.special_gauge >= 100:
                # 공이 가까이 올 때 스킬 사용
                if hasattr(ball, 'y') and abs(ball.y - boss.rect.y) < 200:
                    return True
        
        return False
    
    def _determine_special_action(self, boss: Any, ball: Any, player: Any) -> Optional[str]:
        """
        특수 행동 결정
        
        Args:
            boss: 보스 객체
            ball: 공 객체
            player: 플레이어 객체
            
        Returns:
            특수 행동 이름 또는 None
        """
        # 행동 패턴에 따른 특수 행동
        if self.behavior == AIBehavior.AGGRESSIVE:
            # 공격적 플레이: 스매시, 파워샷 등
            if random.random() < 0.3:
                return "power_shot"
        
        elif self.behavior == AIBehavior.DEFENSIVE:
            # 수비적 플레이: 방어 스킬
            if random.random() < 0.2:
                return "defensive_stance"
        
        elif self.behavior == AIBehavior.ADAPTIVE:
            # 적응형: 플레이어 스타일에 대응
            if self.adaptation_score > 0.5:
                return "counter_play"
        
        return None
    
    def _learn_player_pattern(self, player: Any, ball: Any):
        """
        플레이어 패턴 학습 (Mythic 모드)
        
        Args:
            player: 플레이어 객체
            ball: 공 객체
        """
        if not hasattr(player, 'rect'):
            return
        
        # 플레이어 위치와 공 위치 기록
        pattern = {
            'player_x': player.rect.centerx,
            'ball_x': ball.x,
            'ball_y': ball.y,
            'ball_vel': (getattr(ball, 'vel_x', 0), getattr(ball, 'vel_y', 0))
        }
        
        self.player_patterns.append(pattern)
        
        # 최근 100개 패턴만 유지
        if len(self.player_patterns) > 100:
            self.player_patterns.pop(0)
        
        # 패턴 분석을 통한 적응
        if len(self.player_patterns) >= 20:
            self._analyze_patterns()
    
    def _analyze_patterns(self):
        """플레이어 패턴 분석 및 적응"""
        if not self.player_patterns:
            return
        
        # 간단한 패턴 분석 (예: 평균 위치)
        avg_player_x = sum(p['player_x'] for p in self.player_patterns) / len(self.player_patterns)
        
        # 적응 점수 업데이트
        self.adaptation_score = min(1.0, self.adaptation_score + self.config.learning_rate)
        
        # 행동 패턴 조정
        if self.adaptation_score > 0.7:
            self.behavior = AIBehavior.ADAPTIVE
    
    def set_difficulty(self, difficulty: AIDifficulty):
        """
        난이도 변경
        
        Args:
            difficulty: 새로운 난이도
        """
        self.difficulty = difficulty
        self.config = self.DIFFICULTY_CONFIGS[difficulty].copy()
        print(f"🎮 AI 난이도 변경: {difficulty.value}")
    
    def set_behavior(self, behavior: AIBehavior):
        """
        행동 패턴 변경
        
        Args:
            behavior: 새로운 행동 패턴
        """
        self.behavior = behavior
        print(f"🎯 AI 행동 패턴 변경: {behavior.value}")
    
    def set_stage_behavior(self, stage: int, behavior: AIBehavior):
        """
        스테이지별 특수 행동 설정
        
        Args:
            stage: 스테이지 번호
            behavior: 해당 스테이지의 행동 패턴
        """
        self.stage_behaviors[stage] = behavior
    
    def get_stage_behavior(self, stage: int) -> AIBehavior:
        """
        스테이지별 행동 패턴 조회
        
        Args:
            stage: 스테이지 번호
            
        Returns:
            해당 스테이지의 행동 패턴
        """
        return self.stage_behaviors.get(stage, self.behavior)
    
    def reset(self):
        """AI 상태 초기화"""
        self.last_decision_time = 0
        self.current_target = None
        self.prediction_cache.clear()
        self.player_patterns.clear()
        self.adaptation_score = 0
        print("🔄 AI 시스템 리셋")
    
    def get_status(self) -> Dict[str, Any]:
        """
        AI 상태 정보 반환
        
        Returns:
            상태 정보 딕셔너리
        """
        return {
            'difficulty': self.difficulty.value,
            'behavior': self.behavior.value,
            'reaction_time': self.config.reaction_time,
            'error_rate': self.config.error_rate,
            'adaptation_score': self.adaptation_score,
            'patterns_learned': len(self.player_patterns)
        }


# 스테이지별 특수 AI 설정
class StageSpecificAI:
    """스테이지별 특수 AI 행동"""
    
    @staticmethod
    def stage1_ai(ai_system: BossAISystem, boss: Any, ball: Any, player: Any) -> Dict[str, Any]:
        """Stage 1: 기본 AI"""
        ai_system.set_behavior(AIBehavior.BALANCED)
        return ai_system.update(boss, ball, player, 0.016)
    
    @staticmethod
    def stage2_ai(ai_system: BossAISystem, boss: Any, ball: Any, player: Any) -> Dict[str, Any]:
        """Stage 2: 방어적 AI"""
        ai_system.set_behavior(AIBehavior.DEFENSIVE)
        result = ai_system.update(boss, ball, player, 0.016)
        
        # Stage 2 특수: 카운터 공격
        if random.random() < 0.1:
            result['special_action'] = 'counter_attack'
        
        return result
    
    @staticmethod
    def stage3_ai(ai_system: BossAISystem, boss: Any, ball: Any, player: Any) -> Dict[str, Any]:
        """Stage 3: 공격적 AI"""
        ai_system.set_behavior(AIBehavior.AGGRESSIVE)
        result = ai_system.update(boss, ball, player, 0.016)
        
        # Stage 3 특수: 연속 공격
        if random.random() < 0.15:
            result['special_action'] = 'combo_attack'
        
        return result
    
    @staticmethod
    def stage4_ai(ai_system: BossAISystem, boss: Any, ball: Any, player: Any) -> Dict[str, Any]:
        """Stage 4: 적응형 AI"""
        ai_system.set_behavior(AIBehavior.ADAPTIVE)
        return ai_system.update(boss, ball, player, 0.016)
    
    @staticmethod
    def stage5_ai(ai_system: BossAISystem, boss: Any, ball: Any, player: Any) -> Dict[str, Any]:
        """Stage 5: 최종 보스 AI"""
        # 체력에 따라 행동 변경
        if hasattr(boss, 'health'):
            if boss.health > 70:
                ai_system.set_behavior(AIBehavior.BALANCED)
            elif boss.health > 30:
                ai_system.set_behavior(AIBehavior.AGGRESSIVE)
            else:
                ai_system.set_behavior(AIBehavior.ADAPTIVE)
        
        result = ai_system.update(boss, ball, player, 0.016)
        
        # Stage 5 특수: 필살기
        if hasattr(boss, 'health') and boss.health < 20:
            if random.random() < 0.3:
                result['special_action'] = 'ultimate_skill'
        
        return result


# 전역 AI 시스템 인스턴스
_boss_ai_system = None


def get_boss_ai_system() -> BossAISystem:
    """보스 AI 시스템 싱글톤 반환"""
    global _boss_ai_system
    if _boss_ai_system is None:
        _boss_ai_system = BossAISystem()
    return _boss_ai_system


def init_boss_ai(difficulty: str = "pro"):
    """
    보스 AI 초기화
    
    Args:
        difficulty: 난이도 문자열
    """
    difficulty_map = {
        "junior": AIDifficulty.JUNIOR,
        "pro": AIDifficulty.PRO,
        "champion": AIDifficulty.CHAMPION,
        "mythic": AIDifficulty.MYTHIC
    }
    
    ai_difficulty = difficulty_map.get(difficulty, AIDifficulty.PRO)
    ai_system = get_boss_ai_system()
    ai_system.set_difficulty(ai_difficulty)
    
    return ai_system