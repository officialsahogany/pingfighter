"""
대쉬 관리 시스템 (Dash Manager)
- 대쉬 로직 통합
- 상태 관리 캡슐화  
- 조건 검증 집중화
"""

import pygame
import math
from typing import Dict, Tuple, Optional

class DashManager:
    def __init__(self):
        # 토큰 시스템
        self.current_tokens = 1  # 현재 토큰 수
        self.max_tokens = 1      # 최대 토큰 수
        self.charge_timer = 0    # 충전 타이머
        
        # 대쉬 상태
        self.is_active = False          # 대쉬 중 여부
        self.direction = 0              # 대쉬 방향 (-1: 왼쪽, 1: 오른쪽)
        self.timer = 0                  # 대쉬 지속 시간
        self.stun_timer = 0             # 통제불능 시간
        self.cooldown_timer = 0         # 쿨다운 타이머
        
        # 연속 대쉬 시스템
        self.consecutive_count = 0      # 연속 대쉬 횟수
        
        # 아이템 보너스 (외부에서 설정)
        self.has_holder = False         # 대쉬홀더 보유
        self.has_gear = False           # 대쉬기어 보유
        self.has_spikeboots = False     # 스파이크부츠 보유
        
        # 스킬 보너스 함수 (외부에서 주입)
        self.get_skill_bonus = None
        
        # 게이지 시스템 참조 (외부에서 주입)
        self.get_gauge = None
        self.consume_gauge = None
        
        # 효과음 함수 (외부에서 주입)
        self.play_dash_sound = None

        # 외부 배율 (전설/버프 적용)
        self.external_cost_multiplier = 1.0
        self.external_cooldown_multiplier = 1.0
    
    def init_references(self, get_skill_bonus_func, get_gauge_func, consume_gauge_func, play_sound_func):
        """외부 참조 함수들 초기화"""
        self.get_skill_bonus = get_skill_bonus_func
        self.get_gauge = get_gauge_func
        self.consume_gauge = consume_gauge_func
        self.play_dash_sound = play_sound_func
    
    def update_bonuses(self, holder: bool, gear: bool, spikeboots: bool):
        """아이템 보너스 업데이트"""
        old_holder = self.has_holder
        self.has_holder = holder
        self.has_gear = gear
        self.has_spikeboots = spikeboots
        
        # 대쉬홀더 새로 획득 시 토큰 즉시 추가
        if holder and not old_holder:
            self.current_tokens += 1
        
        # 최대 토큰 수 재계산
        self._update_max_tokens()
    
    def _update_max_tokens(self):
        """최대 토큰 수 계산"""
        base_tokens = 1
        holder_bonus = 1 if self.has_holder else 0
        amplification_bonus = 0
        
        if self.get_skill_bonus:
            amplification_bonus = self.get_skill_bonus("dash_amplification")
        
        self.max_tokens = int(base_tokens + holder_bonus + amplification_bonus)
    
    def can_dash(self, ignore_stun: bool = False) -> Dict[str, any]:
        """대쉬 가능 여부 확인"""
        conditions = {
            'has_tokens': self.current_tokens > 0,
            'not_active': not self.is_active,
            'not_stunned': ignore_stun or self.stun_timer <= 0,
            'gauge_sufficient': True,  # 나중에 계산
            'result': False
        }

        # 게이지 충분 여부 확인 (대쉬부스트 활성화 시 무시)
        dash_cost_free = False
        try:
            from item_effects.dash_boost import get_dash_cost_multiplier
            cost_multiplier = get_dash_cost_multiplier()
            if cost_multiplier == 0.0:  # 대쉬 무료
                dash_cost_free = True
        except ImportError:
            pass

        if dash_cost_free:
            # 대쉬부스트로 무료일 때는 게이지 체크 안함
            conditions['gauge_sufficient'] = True
            conditions['required_gauge'] = 0
            conditions['current_gauge'] = self.get_gauge() if self.get_gauge else 0
        elif self.get_gauge:
            required_gauge = self.calculate_dash_cost()
            current_gauge = self.get_gauge()
            conditions['gauge_sufficient'] = current_gauge >= required_gauge
            conditions['required_gauge'] = required_gauge
            conditions['current_gauge'] = current_gauge

        # 최종 결과
        conditions['result'] = all([
            conditions['has_tokens'],
            conditions['not_active'],
            conditions['not_stunned'],
            conditions['gauge_sufficient']
        ])

        return conditions
    
    def calculate_dash_cost(self) -> int:
        """대쉬 게이지 소모량 계산"""
        base_cost = 140  # 기본 비용 조정: 160 → 140
        
        # 연속 대쉬 할인
        next_count = self.consecutive_count + 1
        consecutive_discount = 0.5 ** (next_count - 1)
        discounted_cost = int(base_cost * consecutive_discount)
        
        # 대쉬기어 할인 (20%)
        if self.has_gear:
            discounted_cost = int(discounted_cost * 0.8)
        
        # 아카데미 배터리팩 스킬 할인
        battery_bonus = 0
        if self.get_skill_bonus:
            battery_bonus = self.get_skill_bonus("dash_battery_pack")
        
        final_cost = max(10, int(discounted_cost * (1 - battery_bonus)))
        final_cost = int(final_cost * self.external_cost_multiplier)
        return final_cost
    
    def execute_dash(self, direction: int, ignore_stun: bool = False) -> bool:
        """대쉬 실행"""
        # 조건 확인
        conditions = self.can_dash(ignore_stun)
        if not conditions['result']:
            return False
        
        # 게이지 소모
        cost = conditions['required_gauge']
        if self.consume_gauge:
            self.consume_gauge(cost)
        
        # 대쉬 시작
        self._start_dash(direction, cost)
        
        # 효과음 재생
        if self.play_dash_sound:
            self.play_dash_sound()
        
        return True
    
    def _start_dash(self, direction: int, cost: int):
        """대쉬 시작 처리"""
        # 대쉬 상태 설정
        self.is_active = True
        self.direction = direction
        
        # 대쉬 거리 계산
        base_timer = 15  # 기본 대쉬 시간
        
        # 대쉬기어 보너스 (10% 증가)
        if self.has_gear:
            base_timer = 16
        
        # 아카데미 스킬 보너스 (경량화 + 도약)
        distance_bonus = 0
        if self.get_skill_bonus:
            lightweight_bonus = self.get_skill_bonus("dash_lightweight")
            jump_bonus = self.get_skill_bonus("dash_jump")
            distance_bonus = lightweight_bonus + jump_bonus
        
        self.timer = int(base_timer * (1 + distance_bonus))
        
        # 토큰 및 연속 카운터 업데이트 (왼쪽부터 소진)
        self.current_tokens -= 1
        self.consecutive_count += 1
        
        # 쿨다운 설정
        self._set_cooldown()
        
        print(f" ! : {'' if direction < 0 else ''},"
              f"연속: {self.consecutive_count}회, 소모: {cost}, "
              f"남은 토큰: {self.current_tokens}")
    
    def _set_cooldown(self):
        """쿨다운 설정"""
        # 아카데미 쿨다운 감소 스킬
        cooldown_reduction = 0
        if self.get_skill_bonus:
            dash_cooldown_bonus = self.get_skill_bonus("dash_cooldown")
            cooldown_reduction = int(dash_cooldown_bonus * 60)
        
        if self.has_holder:
            # 대쉬홀더: 차등 쿨다운
            if self.current_tokens >= 1:  # 첫 번째 대쉬 후
                self.cooldown_timer = max(6, int((60 - cooldown_reduction) * self.external_cooldown_multiplier))    # 1초
                self.charge_timer = max(6, int((60 - cooldown_reduction) * self.external_cooldown_multiplier))      # 1초 후 충전
            else:  # 두 번째 대쉬 후
                self.cooldown_timer = max(6, int((90 - cooldown_reduction) * self.external_cooldown_multiplier))    # 1.5초
                self.charge_timer = max(6, int((90 - cooldown_reduction) * self.external_cooldown_multiplier))      # 1.5초 후 충전
        else:
            # 일반: 기본 쿨다운
            base_cooldown = 90  # 1.5초
            if self.has_spikeboots:
                base_cooldown -= 30  # 0.5초 감소
            
            self.cooldown_timer = max(6, int((base_cooldown - cooldown_reduction) * self.external_cooldown_multiplier))
            self.charge_timer = max(6, int((base_cooldown - cooldown_reduction) * self.external_cooldown_multiplier))

    def set_external_multipliers(self, cost_mul=None, cooldown_mul=None):
        """외부 배율 설정(예: 전설/버프)"""
        if cost_mul is not None:
            self.external_cost_multiplier = max(0.1, cost_mul)
        if cooldown_mul is not None:
            self.external_cooldown_multiplier = max(0.1, cooldown_mul)

    def reset_external_multipliers(self):
        self.external_cost_multiplier = 1.0
        self.external_cooldown_multiplier = 1.0
    
    def update(self):
        """매 프레임 업데이트"""
        # 대쉬부스트 효과 확인
        cooldown_decrement = 1
        try:
            from item_effects.dash_boost import get_dash_cooldown_multiplier
            cooldown_multiplier = get_dash_cooldown_multiplier()
            if cooldown_multiplier < 1.0:
                # 쿨타임이 99% 감소하면 100배 빠르게 감소
                cooldown_decrement = int(1 / cooldown_multiplier) if cooldown_multiplier > 0 else 100
        except ImportError:
            pass

        # 대쉬 타이머 감소
        if self.timer > 0:
            self.timer -= 1
            if self.timer <= 0:
                self._end_dash()

        # 통제불능 타이머 감소
        elif self.stun_timer > 0:
            self.stun_timer -= cooldown_decrement
            if self.stun_timer < 0:
                self.stun_timer = 0

        # 쿨다운 타이머 감소 (대쉬부스트 효과 적용)
        if self.cooldown_timer > 0:
            self.cooldown_timer -= cooldown_decrement
            if self.cooldown_timer < 0:
                self.cooldown_timer = 0
        
        # 충전 타이머 처리 (대쉬부스트 효과 적용)
        if self.charge_timer > 0:
            self.charge_timer -= cooldown_decrement
            if self.charge_timer <= 0:
                self.charge_timer = 0
                self._charge_token()
    
    def _end_dash(self):
        """대쉬 종료 처리"""
        self.is_active = False

        # 통제불능 시간 설정
        base_stun = 30  # 0.5초

        # 아카데미 모듈제어 스킬 (통제불능 시간 감소)
        stun_reduction = 0
        if self.get_skill_bonus:
            module_control_bonus = self.get_skill_bonus("dash_module_control")
            stun_reduction = int(module_control_bonus * 30)  # 10%씩 감소

        # 스파이크부츠 효과 (15% 감소)
        if self.has_spikeboots:
            base_stun = int(base_stun * 0.85)

        # 대쉬부스트 효과: 통제불능 시간도 감소
        stun_time = max(1, base_stun - stun_reduction)
        try:
            from item_effects.dash_boost import get_dash_cooldown_multiplier
            cooldown_multiplier = get_dash_cooldown_multiplier()
            if cooldown_multiplier < 1.0:
                # 대쉬부스트 활성화 시 통제불능 시간도 거의 즉시 해제
                stun_time = max(1, int(stun_time * cooldown_multiplier))
        except ImportError:
            pass

        self.stun_timer = stun_time
    
    def _charge_token(self):
        """토큰 충전 (왼쪽부터)"""
        self._update_max_tokens()  # 최대 토큰 수 재계산
        self.current_tokens = min(self.current_tokens + 1, self.max_tokens)
        
        # 아직 부족하면 다음 충전 타이머 설정
        if self.current_tokens < self.max_tokens:
            if self.has_holder:
                cooldown_reduction = 0
                if self.get_skill_bonus:
                    dash_cooldown_bonus = self.get_skill_bonus("dash_cooldown")
                    cooldown_reduction = int(dash_cooldown_bonus * 60)
                
                self.charge_timer = max(6, 90 - cooldown_reduction)  # 1.5초
                print(f"  : {self.charge_timer/60:.1f}")
        
        # 모든 토큰 충전 완료 시 연속 카운터 리셋
        if self.current_tokens >= self.max_tokens:
            self.consecutive_count = 0
            print(f"   ! ({self.current_tokens}/{self.max_tokens})")
    
    def get_dash_state(self) -> Dict[str, any]:
        """현재 대쉬 상태 반환"""
        return {
            'active': self.is_active,
            'direction': self.direction,
            'timer': self.timer,
            'stun_timer': self.stun_timer,
            'cooldown_timer': self.cooldown_timer,
            'current_tokens': self.current_tokens,
            'max_tokens': self.max_tokens,
            'consecutive_count': self.consecutive_count,
            'charge_timer': self.charge_timer
        }
    
    def get_ui_info(self) -> Dict[str, any]:
        """UI 표시용 정보 반환"""
        # 쿨다운 진행률 계산
        cooldown_progress = 0
        if self.cooldown_timer > 0:
            # 아카데미 쿨다운 감소 스킬
            cooldown_reduction = 0
            if self.get_skill_bonus:
                dash_cooldown_bonus = self.get_skill_bonus("dash_cooldown")
                cooldown_reduction = int(dash_cooldown_bonus * 60)

            if self.has_holder:
                if self.current_tokens >= 1:
                    max_cooldown = 60 - cooldown_reduction  # 1초
                else:
                    max_cooldown = 90 - cooldown_reduction  # 1.5초
            else:
                max_cooldown = 90 - cooldown_reduction  # 1.5초
                if self.has_spikeboots:
                    max_cooldown = 60 - cooldown_reduction

            # 외부 배율(전설/버프) 적용
            max_cooldown = max(6, int(max_cooldown * self.external_cooldown_multiplier))

            cooldown_progress = self.cooldown_timer / max_cooldown

        return {
            'current': self.current_tokens,
            'max': self.max_tokens,
            'cooldown_progress': cooldown_progress,
            'consecutive_count': self.consecutive_count,
            'is_charging': self.charge_timer > 0,
            'can_dash': self.can_dash()['result']
        }
    
    def reset_to_base(self):
        """기본 상태로 리셋"""
        self.current_tokens = 1
        self.max_tokens = 1
        self.charge_timer = 0
        self.is_active = False
        self.direction = 0
        self.timer = 0
        self.stun_timer = 0
        self.cooldown_timer = 0
        self.consecutive_count = 0
    
    def reset_to_max(self):
        """최대 토큰으로 리셋"""
        self._update_max_tokens()
        self.current_tokens = self.max_tokens
        self.charge_timer = 0
        self.consecutive_count = 0
    
    def sync_with_legacy_system(self, legacy_tokens: int, legacy_timer: int, legacy_consecutive: int):
        """기존 시스템과 동기화"""
        self._update_max_tokens()
        self.current_tokens = min(legacy_tokens, self.max_tokens)
        self.charge_timer = legacy_timer
        self.consecutive_count = legacy_consecutive
        print(f"   :  {self.current_tokens}/{self.max_tokens},  {self.charge_timer}")
    
    def get_legacy_sync_data(self) -> tuple:
        """기존 시스템 동기화를 위한 데이터 반환"""
        self._update_max_tokens()
        return (self.current_tokens, self.charge_timer, self.consecutive_count, self.max_tokens)

# 전역 대쉬 매니저 인스턴스
_dash_manager = None
_GLOBAL_DASH_INST = None  # 외부 배율 조정을 위한 전역 참조

def get_dash_manager() -> DashManager:
    """대쉬 매니저 싱글톤 인스턴스 반환"""
    global _dash_manager
    if _dash_manager is None:
        _dash_manager = DashManager()
    return _dash_manager

def init_dash_manager(get_skill_bonus_func, get_gauge_func, consume_gauge_func, play_sound_func):
    """대쉬 매니저 초기화"""
    global _GLOBAL_DASH_INST
    manager = get_dash_manager()
    manager.init_references(get_skill_bonus_func, get_gauge_func, consume_gauge_func, play_sound_func)
    _GLOBAL_DASH_INST = manager
    return manager

# 테스트 코드
if __name__ == "__main__":
    print("")
    
    # 모든 스킬 보너스 테스트
    def mock_skill_bonus(skill_id):
        bonuses = {
            "dash_amplification": 2,      # 증폭 2레벨
            "dash_battery_pack": 0.15,    # 배터리팩 15% 할인
            "dash_lightweight": 0.09,     # 경량화 9% 거리 증가
            "dash_jump": 0.06,           # 도약 6% 거리 증가
            "dash_module_control": 0.20,  # 모듈제어 20% 통제불능 감소
            "dash_cooldown": 0.5         # 쿨다운 0.5초 감소
        }
        return bonuses.get(skill_id, 0)
    
    def mock_get_gauge():
        return 300  # 충분한 게이지
    
    def mock_consume_gauge(amount):
        print(f" {amount}")
    
    def mock_play_sound():
        print("!")
    
    # 매니저 초기화
    manager = init_dash_manager(mock_skill_bonus, mock_get_gauge, mock_consume_gauge, mock_play_sound)
    
    # 대쉬홀더 + 대쉬기어 적용
    manager.update_bonuses(holder=True, gear=True, spikeboots=False)
    
    print(f"  : {manager.get_ui_info()}")
    print(f"  : {manager.calculate_dash_cost()}")
    
    # 연속 대쉬 테스트
    for i in range(4):
        conditions = manager.can_dash()
        print(f"\n {i+1}  :")
        print(f"   : {conditions}")
        
        if conditions['result']:
            success = manager.execute_dash(-1)  # 왼쪽 대쉬
            print(f"   : {'' if success else ''}")
            print(f"   : {manager.get_dash_state()}")
        
        # 시간 경과 시뮬레이션 (대쉬 완료까지)
        while manager.timer > 0 or manager.stun_timer > 0:
            manager.update()
        
        # 충전 대기
        for _ in range(70):  # 약 1.2초
            manager.update()
    
    print(f"\n  : {manager.get_ui_info()}")
