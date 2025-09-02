"""
Balance Configuration - 게임 밸런싱 설정
각 스테이지별 밸런스 파라미터 정의
"""

from typing import Dict, Any


class StageBalance:
    """스테이지별 밸런스 설정"""
    
    STAGES = {
        1: {  # Training Bot - 튜토리얼 스테이지
            'name': 'Training Bot',
            'description': '기본 조작 학습',
            'difficulty_multiplier': 0.6,
            'ball_speed': {
                'initial': 4.0,
                'max': 7.0,
                'acceleration': 0.02
            },
            'paddle_size': {
                'player': 100,
                'boss': 120  # 보스가 약간 더 큼
            },
            'scoring': {
                'rounds_to_win': 3,
                'points_per_round': 11,
                'deuce_enabled': False
            },
            'special_abilities': {
                'whip': {
                    'damage': 1,
                    'cooldown': 5.0,
                    'range': 150
                }
            },
            'item_spawn': {
                'frequency': 0.003,  # 0.3% 확률
                'max_items': 2,
                'types': ['speed_up', 'size_up', 'slow_ball']
            },
            'rewards': {
                'medal_per_win': 10,
                'exp_per_win': 100,
                'bonus_perfect': 50
            }
        },
        
        2: {  # Speed Demon - 속도 중심
            'name': 'Speed Demon',
            'description': '빠른 반응 속도 필요',
            'difficulty_multiplier': 0.75,
            'ball_speed': {
                'initial': 5.0,
                'max': 9.0,
                'acceleration': 0.03
            },
            'paddle_size': {
                'player': 100,
                'boss': 100
            },
            'scoring': {
                'rounds_to_win': 3,
                'points_per_round': 11,
                'deuce_enabled': True
            },
            'special_abilities': {
                'speed_boost': {
                    'duration': 3.0,
                    'multiplier': 1.5,
                    'cooldown': 8.0
                },
                'rock_wall': {
                    'hp': 3,
                    'count': 3,
                    'duration': 10.0
                }
            },
            'item_spawn': {
                'frequency': 0.002,
                'max_items': 3,
                'types': ['speed_up', 'speed_down', 'dash_refresh']
            },
            'rewards': {
                'medal_per_win': 15,
                'exp_per_win': 150,
                'bonus_perfect': 75
            }
        },
        
        3: {  # Trickster - 예측 불가능
            'name': 'Trickster',
            'description': '변칙적인 패턴',
            'difficulty_multiplier': 0.85,
            'ball_speed': {
                'initial': 5.0,
                'max': 8.0,
                'acceleration': 0.025,
                'curve_enabled': True  # 커브볼 활성화
            },
            'paddle_size': {
                'player': 100,
                'boss': 90  # 보스가 더 작음 (더 어려움)
            },
            'scoring': {
                'rounds_to_win': 3,
                'points_per_round': 11,
                'deuce_enabled': True
            },
            'special_abilities': {
                'emotional_overdrive': {
                    'duration': 5.0,
                    'tear_damage': 1,
                    'cooldown': 15.0
                },
                'feint': {
                    'frequency': 0.2,
                    'fake_movement': 0.3
                }
            },
            'item_spawn': {
                'frequency': 0.0025,
                'max_items': 3,
                'types': ['confusion', 'curve_ball', 'multi_ball']
            },
            'rewards': {
                'medal_per_win': 20,
                'exp_per_win': 200,
                'bonus_perfect': 100
            }
        },
        
        4: {  # Guardian - 방어 중심
            'name': 'Guardian',
            'description': '철벽 수비',
            'difficulty_multiplier': 0.9,
            'ball_speed': {
                'initial': 5.5,
                'max': 8.5,
                'acceleration': 0.02
            },
            'paddle_size': {
                'player': 90,
                'boss': 110  # 보스가 더 큼 (방어적)
            },
            'scoring': {
                'rounds_to_win': 4,  # 더 긴 경기
                'points_per_round': 11,
                'deuce_enabled': True
            },
            'special_abilities': {
                'magnetic_field': {
                    'pull_strength': 3.0,
                    'duration': 3.0,
                    'cooldown': 10.0
                },
                'shield': {
                    'hp': 5,
                    'duration': 5.0,
                    'cooldown': 12.0
                }
            },
            'item_spawn': {
                'frequency': 0.002,
                'max_items': 2,
                'types': ['shield', 'magnet', 'heavy_ball']
            },
            'rewards': {
                'medal_per_win': 25,
                'exp_per_win': 250,
                'bonus_perfect': 125
            }
        },
        
        5: {  # Destroyer - 공격적
            'name': 'Destroyer',
            'description': '강력한 공격',
            'difficulty_multiplier': 0.95,
            'ball_speed': {
                'initial': 6.0,
                'max': 10.0,
                'acceleration': 0.035
            },
            'paddle_size': {
                'player': 90,
                'boss': 90
            },
            'scoring': {
                'rounds_to_win': 4,
                'points_per_round': 11,
                'deuce_enabled': True
            },
            'special_abilities': {
                'flame_throw': {
                    'damage': 2,
                    'burn_duration': 2.0,
                    'cooldown': 8.0
                },
                'inferno_mode': {
                    'duration': 10.0,
                    'damage_multiplier': 1.5,
                    'cooldown': 20.0
                }
            },
            'item_spawn': {
                'frequency': 0.0015,  # 더 적은 아이템
                'max_items': 2,
                'types': ['power_shot', 'explosion', 'fire_ball']
            },
            'rewards': {
                'medal_per_win': 30,
                'exp_per_win': 300,
                'bonus_perfect': 150
            }
        },
        
        6: {  # Final Boss - 종합
            'name': 'Final Boss',
            'description': '최종 도전',
            'difficulty_multiplier': 1.0,
            'ball_speed': {
                'initial': 6.0,
                'max': 11.0,
                'acceleration': 0.04,
                'curve_enabled': True,
                'multi_ball_enabled': True
            },
            'paddle_size': {
                'player': 85,  # 플레이어 패들 더 작음
                'boss': 100
            },
            'scoring': {
                'rounds_to_win': 5,  # 최종전은 5라운드
                'points_per_round': 11,
                'deuce_enabled': True
            },
            'special_abilities': {
                'yamato_cannon': {
                    'damage': 3,
                    'charge_time': 2.0,
                    'cooldown': 15.0
                },
                'missile_barrage': {
                    'count': 10,
                    'damage': 1,
                    'duration': 5.0,
                    'cooldown': 12.0
                },
                'all_abilities': True  # 모든 이전 능력 사용 가능
            },
            'item_spawn': {
                'frequency': 0.001,  # 매우 적은 아이템
                'max_items': 1,
                'types': ['ultimate_power', 'time_slow', 'invincibility']
            },
            'rewards': {
                'medal_per_win': 50,
                'exp_per_win': 500,
                'bonus_perfect': 250,
                'special_reward': 'championship_trophy'
            }
        }
    }
    
    @classmethod
    def get_stage_balance(cls, stage: int) -> Dict[str, Any]:
        """스테이지 밸런스 설정 반환
        
        Args:
            stage: 스테이지 번호
            
        Returns:
            밸런스 설정 딕셔너리
        """
        return cls.STAGES.get(stage, cls.STAGES[1])
    
    @classmethod
    def get_difficulty_curve(cls, stage: int, progress: float) -> float:
        """스테이지 내 난이도 커브 계산
        
        Args:
            stage: 스테이지 번호
            progress: 진행도 (0.0 ~ 1.0)
            
        Returns:
            난이도 배율
        """
        base = cls.STAGES[stage]['difficulty_multiplier']
        
        # 스테이지가 진행될수록 어려워짐
        # S자 커브 사용
        import math
        curve = 0.5 + 0.5 * math.sin((progress - 0.5) * math.pi)
        
        # 스테이지별 커브 강도
        curve_strength = {
            1: 0.1,  # 거의 평평
            2: 0.15,
            3: 0.2,
            4: 0.25,
            5: 0.3,
            6: 0.35  # 가장 가파른 커브
        }
        
        strength = curve_strength.get(stage, 0.2)
        return base * (1.0 + curve * strength)


class ItemBalance:
    """아이템 밸런스 설정"""
    
    ITEMS = {
        # 기본 아이템
        'speed_up': {
            'duration': 5.0,
            'effect': 1.3,
            'rarity': 'common'
        },
        'speed_down': {
            'duration': 5.0,
            'effect': 0.7,
            'rarity': 'common'
        },
        'size_up': {
            'duration': 7.0,
            'effect': 1.5,
            'rarity': 'common'
        },
        'size_down': {
            'duration': 7.0,
            'effect': 0.7,
            'rarity': 'common'
        },
        
        # 중급 아이템
        'multi_ball': {
            'count': 3,
            'duration': 10.0,
            'rarity': 'rare'
        },
        'shield': {
            'hp': 3,
            'duration': 10.0,
            'rarity': 'rare'
        },
        'magnet': {
            'strength': 2.0,
            'duration': 8.0,
            'rarity': 'rare'
        },
        'curve_ball': {
            'curve_strength': 3.0,
            'duration': 10.0,
            'rarity': 'rare'
        },
        
        # 고급 아이템
        'power_shot': {
            'damage': 2,
            'duration': 5.0,
            'rarity': 'epic'
        },
        'time_slow': {
            'slow_factor': 0.5,
            'duration': 5.0,
            'rarity': 'epic'
        },
        'invincibility': {
            'duration': 3.0,
            'rarity': 'epic'
        },
        'ultimate_power': {
            'all_effects': True,
            'duration': 10.0,
            'rarity': 'legendary'
        }
    }
    
    @classmethod
    def get_item_spawn_weight(cls, item_type: str) -> float:
        """아이템 스폰 가중치 반환
        
        Args:
            item_type: 아이템 타입
            
        Returns:
            스폰 가중치
        """
        item = cls.ITEMS.get(item_type, {})
        rarity = item.get('rarity', 'common')
        
        weights = {
            'common': 1.0,
            'rare': 0.5,
            'epic': 0.2,
            'legendary': 0.05
        }
        
        return weights.get(rarity, 1.0)


class GameBalance:
    """전체 게임 밸런스 관리"""
    
    # 전역 설정
    GLOBAL_SETTINGS = {
        'max_ball_speed': 15.0,
        'min_ball_speed': 3.0,
        'dash_cooldown': 2.0,
        'dash_duration': 0.2,
        'dash_speed_multiplier': 3.0,
        'medal_exchange_rate': 10,  # 10 메달 = 1 가챠
        'exp_per_level': 1000,
        'skill_point_per_level': 1
    }
    
    @classmethod
    def calculate_damage(cls, base_damage: float, modifiers: Dict[str, float]) -> float:
        """데미지 계산
        
        Args:
            base_damage: 기본 데미지
            modifiers: 수정자 딕셔너리
            
        Returns:
            최종 데미지
        """
        final_damage = base_damage
        
        # 곱셈 수정자
        for key, value in modifiers.items():
            if key.endswith('_multiplier'):
                final_damage *= value
                
        # 덧셈 수정자
        for key, value in modifiers.items():
            if key.endswith('_bonus'):
                final_damage += value
                
        return max(0, final_damage)
    
    @classmethod
    def calculate_exp_required(cls, level: int) -> int:
        """레벨업에 필요한 경험치 계산
        
        Args:
            level: 현재 레벨
            
        Returns:
            필요 경험치
        """
        base = cls.GLOBAL_SETTINGS['exp_per_level']
        # 레벨이 올라갈수록 더 많은 경험치 필요
        return int(base * (1.0 + level * 0.1))