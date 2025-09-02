"""
Achievement System - 성취 시스템
도전과제 및 업적 관리
"""

import json
import os
import time
from typing import Dict, Any, List, Optional, Callable
from dataclasses import dataclass, asdict
from enum import Enum
from core.events import EventType, emit_event, subscribe
from core.global_manager import GlobalManager


class AchievementCategory(Enum):
    """성취 카테고리"""
    GENERAL = "일반"
    COMBAT = "전투"
    SKILL = "스킬"
    COLLECTION = "수집"
    SPECIAL = "특별"
    HIDDEN = "숨김"


class AchievementRarity(Enum):
    """성취 희귀도"""
    COMMON = ("일반", (200, 200, 200))
    RARE = ("희귀", (100, 150, 255))
    EPIC = ("영웅", (200, 100, 255))
    LEGENDARY = ("전설", (255, 200, 50))


@dataclass
class Achievement:
    """성취 정의"""
    id: str
    name: str
    description: str
    category: AchievementCategory
    rarity: AchievementRarity
    icon: str
    requirement: Dict[str, Any]
    reward: Dict[str, Any]
    hidden: bool = False
    
    def check_completion(self, stats: Dict[str, Any]) -> bool:
        """완료 조건 체크
        
        Args:
            stats: 통계 데이터
            
        Returns:
            완료 여부
        """
        for key, target_value in self.requirement.items():
            if key not in stats:
                return False
                
            current_value = stats[key]
            
            # 비교 연산자 처리
            if isinstance(target_value, dict):
                operator = target_value.get('operator', '>=')
                value = target_value.get('value', 0)
                
                if operator == '>=':
                    if current_value < value:
                        return False
                elif operator == '>':
                    if current_value <= value:
                        return False
                elif operator == '==':
                    if current_value != value:
                        return False
                elif operator == '<=':
                    if current_value > value:
                        return False
                elif operator == '<':
                    if current_value >= value:
                        return False
            else:
                # 단순 값 비교 (>=)
                if current_value < target_value:
                    return False
                    
        return True


class AchievementProgress:
    """성취 진행도"""
    
    def __init__(self, achievement_id: str):
        self.achievement_id = achievement_id
        self.progress = {}
        self.completed = False
        self.completed_at = None
        self.claimed = False
        
    def update_progress(self, key: str, value: Any):
        """진행도 업데이트
        
        Args:
            key: 진행도 키
            value: 값
        """
        if key not in self.progress:
            self.progress[key] = 0
            
        if isinstance(value, (int, float)):
            self.progress[key] = max(self.progress[key], value)
        else:
            self.progress[key] = value
            
    def get_progress_percentage(self, requirement: Dict[str, Any]) -> float:
        """진행도 퍼센트 계산
        
        Args:
            requirement: 요구사항
            
        Returns:
            진행도 (0.0 ~ 1.0)
        """
        if not requirement:
            return 1.0 if self.completed else 0.0
            
        total_progress = 0
        total_requirements = len(requirement)
        
        for key, target_value in requirement.items():
            current_value = self.progress.get(key, 0)
            
            if isinstance(target_value, dict):
                target = target_value.get('value', 1)
            else:
                target = target_value
                
            if target > 0:
                progress = min(1.0, current_value / target)
            else:
                progress = 1.0 if current_value >= target else 0.0
                
            total_progress += progress
            
        return total_progress / total_requirements if total_requirements > 0 else 0.0


class AchievementManager:
    """성취 시스템 매니저"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 성취 정의
        self.achievements: Dict[str, Achievement] = {}
        self.progress: Dict[str, AchievementProgress] = {}
        
        # 통계 추적
        self.stats = {
            # 기본 통계
            'total_games': 0,
            'total_wins': 0,
            'total_losses': 0,
            'win_streak': 0,
            'max_win_streak': 0,
            
            # 전투 통계
            'total_hits': 0,
            'perfect_wins': 0,
            'comeback_wins': 0,
            'total_rallies': 0,
            'longest_rally': 0,
            
            # 스킬 통계
            'dashes_used': 0,
            'perfect_dashes': 0,
            'specials_used': 0,
            'skills_unlocked': 0,
            
            # 수집 통계
            'items_collected': 0,
            'medals_earned': 0,
            'gacha_pulls': 0,
            'unique_items': set(),
            
            # 스테이지 통계
            'stages_cleared': set(),
            'boss_defeats': {},
            'fastest_clear': {},
            
            # 특별 통계
            'play_time': 0,
            'first_play_date': None,
            'last_play_date': None
        }
        
        # 성취 정의 로드
        self.load_achievements()
        
        # 진행 상황 로드
        self.load_progress()
        
        # 이벤트 핸들러 등록
        self.setup_event_handlers()
        
    def load_achievements(self):
        """성취 정의 로드"""
        # 기본 성취 정의
        self.define_achievement(
            id="first_win",
            name="첫 승리",
            description="첫 경기에서 승리하기",
            category=AchievementCategory.GENERAL,
            rarity=AchievementRarity.COMMON,
            icon="🏆",
            requirement={'total_wins': 1},
            reward={'medals': 10, 'exp': 100}
        )
        
        self.define_achievement(
            id="win_streak_3",
            name="3연승",
            description="3경기 연속 승리",
            category=AchievementCategory.COMBAT,
            rarity=AchievementRarity.COMMON,
            icon="🔥",
            requirement={'win_streak': 3},
            reward={'medals': 20, 'exp': 200}
        )
        
        self.define_achievement(
            id="win_streak_5",
            name="5연승",
            description="5경기 연속 승리",
            category=AchievementCategory.COMBAT,
            rarity=AchievementRarity.RARE,
            icon="🔥",
            requirement={'win_streak': 5},
            reward={'medals': 50, 'exp': 500}
        )
        
        self.define_achievement(
            id="perfect_game",
            name="완벽한 경기",
            description="점수를 내주지 않고 승리",
            category=AchievementCategory.COMBAT,
            rarity=AchievementRarity.RARE,
            icon="⭐",
            requirement={'perfect_wins': 1},
            reward={'medals': 30, 'exp': 300}
        )
        
        self.define_achievement(
            id="comeback_king",
            name="역전의 제왕",
            description="2점 이상 뒤진 상황에서 역전승",
            category=AchievementCategory.COMBAT,
            rarity=AchievementRarity.EPIC,
            icon="👑",
            requirement={'comeback_wins': 1},
            reward={'medals': 50, 'exp': 500}
        )
        
        self.define_achievement(
            id="rally_master",
            name="랠리 마스터",
            description="한 랠리에서 20회 이상 주고받기",
            category=AchievementCategory.SKILL,
            rarity=AchievementRarity.RARE,
            icon="🏓",
            requirement={'longest_rally': 20},
            reward={'medals': 40, 'exp': 400}
        )
        
        self.define_achievement(
            id="dash_expert",
            name="대시 전문가",
            description="대시 100회 사용",
            category=AchievementCategory.SKILL,
            rarity=AchievementRarity.COMMON,
            icon="💨",
            requirement={'dashes_used': 100},
            reward={'medals': 25, 'exp': 250}
        )
        
        self.define_achievement(
            id="collector",
            name="수집가",
            description="아이템 50개 수집",
            category=AchievementCategory.COLLECTION,
            rarity=AchievementRarity.COMMON,
            icon="📦",
            requirement={'items_collected': 50},
            reward={'medals': 20, 'exp': 200}
        )
        
        self.define_achievement(
            id="stage_1_clear",
            name="훈련 완료",
            description="스테이지 1 클리어",
            category=AchievementCategory.GENERAL,
            rarity=AchievementRarity.COMMON,
            icon="1️⃣",
            requirement={'stages_cleared': {'value': 1, 'operator': 'contains'}},
            reward={'medals': 15, 'exp': 150}
        )
        
        self.define_achievement(
            id="all_stages",
            name="진정한 챔피언",
            description="모든 스테이지 클리어",
            category=AchievementCategory.SPECIAL,
            rarity=AchievementRarity.LEGENDARY,
            icon="🏅",
            requirement={'stages_cleared': {'value': 6, 'operator': 'len>='}},
            reward={'medals': 200, 'exp': 2000, 'title': 'Champion'}
        )
        
        # 숨김 성취
        self.define_achievement(
            id="secret_move",
            name="비밀 기술",
            description="???",
            category=AchievementCategory.HIDDEN,
            rarity=AchievementRarity.EPIC,
            icon="🤫",
            requirement={'secret_move_discovered': 1},
            reward={'medals': 100, 'exp': 1000},
            hidden=True
        )
        
    def define_achievement(self, **kwargs):
        """성취 정의
        
        Args:
            **kwargs: 성취 속성
        """
        achievement = Achievement(**kwargs)
        self.achievements[achievement.id] = achievement
        
        # 진행도 초기화
        if achievement.id not in self.progress:
            self.progress[achievement.id] = AchievementProgress(achievement.id)
            
    def setup_event_handlers(self):
        """이벤트 핸들러 설정"""
        subscribe(EventType.GAME_OVER, self.on_game_over)
        subscribe(EventType.ROUND_WIN, self.on_round_win)
        subscribe(EventType.ROUND_LOSE, self.on_round_lose)
        subscribe(EventType.COLLISION, self.on_collision)
        subscribe(EventType.ITEM_COLLECTED, self.on_item_collected)
        subscribe(EventType.SPECIAL_ACTIVATED, self.on_special_activated)
        
    def on_game_over(self, event):
        """게임 종료 이벤트 처리"""
        winner = event.data.get('winner')
        stage = event.data.get('stage', 1)
        
        self.stats['total_games'] += 1
        
        if winner == 'player':
            self.stats['total_wins'] += 1
            self.stats['win_streak'] += 1
            self.stats['max_win_streak'] = max(self.stats['max_win_streak'], 
                                              self.stats['win_streak'])
            
            # 스테이지 클리어
            if isinstance(self.stats['stages_cleared'], set):
                self.stats['stages_cleared'].add(stage)
            else:
                self.stats['stages_cleared'] = {stage}
                
            # 보스 격파 기록
            if stage not in self.stats['boss_defeats']:
                self.stats['boss_defeats'][stage] = 0
            self.stats['boss_defeats'][stage] += 1
            
            # 퍼펙트 게임 체크
            boss_score = self.global_manager.get('boss_score', 0)
            if boss_score == 0:
                self.stats['perfect_wins'] += 1
                
        else:
            self.stats['total_losses'] += 1
            self.stats['win_streak'] = 0
            
        # 성취 체크
        self.check_achievements()
        
    def on_round_win(self, event):
        """라운드 승리 이벤트 처리"""
        # 컴백 체크
        score_diff = event.data.get('score_diff', 0)
        if score_diff <= -2:  # 2점 이상 뒤지고 있었음
            self.stats['comeback_wins'] += 1
            
    def on_round_lose(self, event):
        """라운드 패배 이벤트 처리"""
        pass
        
    def on_collision(self, event):
        """충돌 이벤트 처리"""
        if event.data.get('type') == 'ball_paddle':
            self.stats['total_hits'] += 1
            
            # 랠리 카운트
            rally_count = event.data.get('rally_count', 0)
            self.stats['total_rallies'] += 1
            self.stats['longest_rally'] = max(self.stats['longest_rally'], rally_count)
            
    def on_item_collected(self, event):
        """아이템 수집 이벤트 처리"""
        self.stats['items_collected'] += 1
        
        item_type = event.data.get('item_type')
        if item_type:
            if not isinstance(self.stats['unique_items'], set):
                self.stats['unique_items'] = set()
            self.stats['unique_items'].add(item_type)
            
    def on_special_activated(self, event):
        """특수 능력 사용 이벤트 처리"""
        self.stats['specials_used'] += 1
        
        # 대시 체크
        if event.data.get('type') == 'dash':
            self.stats['dashes_used'] += 1
            if event.data.get('perfect'):
                self.stats['perfect_dashes'] += 1
                
    def check_achievements(self):
        """성취 체크 및 완료 처리"""
        newly_completed = []
        
        for achievement_id, achievement in self.achievements.items():
            progress = self.progress[achievement_id]
            
            # 이미 완료된 성취는 스킵
            if progress.completed:
                continue
                
            # 완료 조건 체크
            if achievement.check_completion(self.stats):
                progress.completed = True
                progress.completed_at = time.time()
                newly_completed.append(achievement)
                
                # 보상 지급
                self.grant_reward(achievement)
                
                # 알림 이벤트
                emit_event(EventType.MENU_OPENED, {
                    'type': 'achievement_unlocked',
                    'achievement': achievement
                })
                
        # 진행 상황 저장
        if newly_completed:
            self.save_progress()
            
        return newly_completed
        
    def grant_reward(self, achievement: Achievement):
        """보상 지급
        
        Args:
            achievement: 성취
        """
        reward = achievement.reward
        
        # 메달 지급
        if 'medals' in reward:
            current_medals = self.global_manager.get('medal_score', 0)
            self.global_manager.set('medal_score', current_medals + reward['medals'])
            
        # 경험치 지급
        if 'exp' in reward:
            # 경험치 시스템과 연동
            pass
            
        # 타이틀 지급
        if 'title' in reward:
            # 타이틀 시스템과 연동
            pass
            
        print(f"🎉 성취 달성: {achievement.name}")
        
    def get_achievement_list(self, category: Optional[AchievementCategory] = None) -> List[Achievement]:
        """성취 목록 반환
        
        Args:
            category: 카테고리 필터
            
        Returns:
            성취 목록
        """
        achievements = []
        
        for achievement in self.achievements.values():
            # 숨김 성취는 완료되지 않으면 표시 안함
            if achievement.hidden and not self.progress[achievement.id].completed:
                continue
                
            # 카테고리 필터
            if category and achievement.category != category:
                continue
                
            achievements.append(achievement)
            
        # 희귀도와 이름으로 정렬
        achievements.sort(key=lambda x: (x.rarity.value[0], x.name))
        
        return achievements
        
    def get_achievement_progress(self, achievement_id: str) -> Optional[AchievementProgress]:
        """성취 진행도 반환
        
        Args:
            achievement_id: 성취 ID
            
        Returns:
            진행도 또는 None
        """
        return self.progress.get(achievement_id)
        
    def get_statistics(self) -> Dict[str, Any]:
        """통계 반환
        
        Returns:
            통계 딕셔너리
        """
        # set을 list로 변환
        stats_copy = self.stats.copy()
        if isinstance(stats_copy.get('unique_items'), set):
            stats_copy['unique_items'] = list(stats_copy['unique_items'])
        if isinstance(stats_copy.get('stages_cleared'), set):
            stats_copy['stages_cleared'] = list(stats_copy['stages_cleared'])
            
        return stats_copy
        
    def get_completion_rate(self) -> float:
        """전체 완료율 반환
        
        Returns:
            완료율 (0.0 ~ 1.0)
        """
        total = len(self.achievements)
        completed = sum(1 for p in self.progress.values() if p.completed)
        
        return completed / total if total > 0 else 0.0
        
    def save_progress(self):
        """진행 상황 저장"""
        try:
            save_data = {
                'stats': self.get_statistics(),
                'progress': {}
            }
            
            # 진행도 저장
            for achievement_id, progress in self.progress.items():
                save_data['progress'][achievement_id] = {
                    'progress': progress.progress,
                    'completed': progress.completed,
                    'completed_at': progress.completed_at,
                    'claimed': progress.claimed
                }
                
            # 파일 저장
            with open('achievement_save.json', 'w') as f:
                json.dump(save_data, f, indent=2)
                
            print("💾 성취 진행 상황 저장됨")
            
        except Exception as e:
            print(f"❌ 성취 저장 실패: {e}")
            
    def load_progress(self):
        """진행 상황 로드"""
        try:
            if os.path.exists('achievement_save.json'):
                with open('achievement_save.json', 'r') as f:
                    save_data = json.load(f)
                    
                # 통계 로드
                self.stats.update(save_data.get('stats', {}))
                
                # set 타입 복원
                if 'unique_items' in self.stats:
                    self.stats['unique_items'] = set(self.stats['unique_items'])
                if 'stages_cleared' in self.stats:
                    self.stats['stages_cleared'] = set(self.stats['stages_cleared'])
                    
                # 진행도 로드
                for achievement_id, data in save_data.get('progress', {}).items():
                    if achievement_id in self.progress:
                        progress = self.progress[achievement_id]
                        progress.progress = data.get('progress', {})
                        progress.completed = data.get('completed', False)
                        progress.completed_at = data.get('completed_at')
                        progress.claimed = data.get('claimed', False)
                        
                print("📂 성취 진행 상황 로드됨")
                
        except Exception as e:
            print(f"성취 로드 실패 (새 게임): {e}")


# 싱글톤 인스턴스
_achievement_manager = None

def get_achievement_manager() -> AchievementManager:
    """성취 매니저 싱글톤 반환"""
    global _achievement_manager
    if _achievement_manager is None:
        _achievement_manager = AchievementManager()
    return _achievement_manager