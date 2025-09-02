# -*- coding: utf-8 -*-
"""
향상된 피드백 시스템 - 게임 메커니즘 기반 정밀 분석
Enhanced Feedback System with Deep Game Mechanics Integration
"""

from typing import Dict, List, Tuple
import math

class EnhancedFeedbackSystem:
    """게임 시스템 통찰을 접목한 정밀 피드백 시스템"""
    
    def __init__(self, player_analyzer):
        self.analyzer = player_analyzer
        self.stats = player_analyzer.stats
        
    def get_skill_detailed_feedback(self, score: float, grade: str) -> Dict[str, str]:
        """스킬 활용에 대한 상세 분석"""
        
        # 실제 게임 데이터 기반 분석
        total_hits = self.stats.total_hits if self.stats.total_hits > 0 else 1
        perfect_ratio = (self.stats.perfect_timing_hits / total_hits) * 100
        power_smash_ratio = (self.stats.power_smash_success / max(1, self.stats.skill_usage_count)) * 100
        skill_victory_ratio = (self.stats.skill_victories / total_hits) * 100
        
        feedback = {
            "title": "⚡ 스킬 시스템 정밀 분석",
            "grade": f"{grade} ({score:.1f}점)",
            "metrics": self._analyze_skill_metrics(perfect_ratio, power_smash_ratio, skill_victory_ratio),
            "strengths": self._identify_skill_strengths(perfect_ratio, power_smash_ratio, skill_victory_ratio),
            "weaknesses": self._identify_skill_weaknesses(perfect_ratio, power_smash_ratio, skill_victory_ratio),
            "tips": self._generate_skill_tips(perfect_ratio, power_smash_ratio, skill_victory_ratio, grade)
        }
        
        return feedback
    
    def _analyze_skill_metrics(self, perfect_ratio: float, power_smash_ratio: float, skill_victory_ratio: float) -> str:
        """스킬 메트릭 분석"""
        metrics = []
        
        # 퍼펙트 타이밍 분석 (±3프레임 윈도우 기준)
        if perfect_ratio >= 30:
            metrics.append(f"🎯 퍼펙트 타이밍: {perfect_ratio:.1f}% (프로 수준! ±3프레임 정확도)")
        elif perfect_ratio >= 15:
            metrics.append(f"⭐ 퍼펙트 타이밍: {perfect_ratio:.1f}% (우수한 프레임 컨트롤)")
        elif perfect_ratio >= 5:
            metrics.append(f"📊 퍼펙트 타이밍: {perfect_ratio:.1f}% (타이밍 감각 개발 중)")
        else:
            metrics.append(f"⚠️ 퍼펙트 타이밍: {perfect_ratio:.1f}% (±3프레임 윈도우 연습 필요)")
        
        # 파워스매시 성공률
        if power_smash_ratio >= 70:
            metrics.append(f"💥 파워스매시: {power_smash_ratio:.1f}% (차지 타이밍 완벽)")
        elif power_smash_ratio >= 40:
            metrics.append(f"💪 파워스매시: {power_smash_ratio:.1f}% (스페이스 홀드 숙련)")
        else:
            metrics.append(f"🔋 파워스매시: {power_smash_ratio:.1f}% (차지 게이지 관리 필요)")
        
        # 스킬 승리 기여도
        if skill_victory_ratio >= 10:
            metrics.append(f"🏆 스킬 결정력: {skill_victory_ratio:.1f}% (클러치 능력 탁월)")
        elif skill_victory_ratio >= 5:
            metrics.append(f"✨ 스킬 결정력: {skill_victory_ratio:.1f}% (중요 순간 활약)")
        else:
            metrics.append(f"📈 스킬 결정력: {skill_victory_ratio:.1f}% (결정적 순간 활용도 향상 필요)")
        
        return "\n".join(metrics)
    
    def _identify_skill_strengths(self, perfect_ratio: float, power_smash_ratio: float, skill_victory_ratio: float) -> str:
        """스킬 강점 식별"""
        strengths = []
        
        if perfect_ratio >= 20:
            strengths.append("• 뛰어난 프레임 정밀도 (±3프레임 윈도우 활용)")
        if power_smash_ratio >= 60:
            strengths.append("• 차지 메커니즘 완벽 이해")
        if skill_victory_ratio >= 8:
            strengths.append("• 결정적 순간의 스킬 활용 능력")
        if self.stats.skill_usage_count > 50:
            strengths.append("• 적극적인 스킬 사용 성향")
        
        # 특수 패턴 인식 (하도켄, 승룡권 등)
        if perfect_ratio >= 15 and power_smash_ratio >= 50:
            strengths.append("• 콤보 입력 가능성 (→↓→+Space 패턴 준비됨)")
        
        return "\n".join(strengths) if strengths else "• 스킬 시스템 학습 중"
    
    def _identify_skill_weaknesses(self, perfect_ratio: float, power_smash_ratio: float, skill_victory_ratio: float) -> str:
        """스킬 약점 식별"""
        weaknesses = []
        
        if perfect_ratio < 10:
            weaknesses.append("• 퍼펙트 타이밍 정확도 부족 (±3프레임 놓침)")
        if power_smash_ratio < 40:
            weaknesses.append("• 차지 타이밍 조절 미숙")
        if skill_victory_ratio < 3:
            weaknesses.append("• 결정적 순간 스킬 활용 부족")
        if self.stats.skill_usage_count < 20:
            weaknesses.append("• 소극적 스킬 사용")
        
        # 게이지 관리 문제
        if hasattr(self.stats, 'wasted_skills') and self.stats.wasted_skills > 5:
            weaknesses.append("• 게이지 150 미만에서 스킬 시도 (낭비 발생)")
        
        return "\n".join(weaknesses) if weaknesses else "• 큰 약점 없음"
    
    def _generate_skill_tips(self, perfect_ratio: float, power_smash_ratio: float, skill_victory_ratio: float, grade: str) -> str:
        """스킬 개선 팁 생성"""
        tips = []
        
        if grade in ["F", "E", "D"]:
            tips.append("🎮 **기초 훈련 필요**")
            tips.append("• 스페이스바 타이밍: 공이 패들에서 3픽셀 거리일 때")
            tips.append("• 차지 연습: 스페이스 0.5초 홀드 → 게이지 150 소모")
            tips.append("• 드라이브: 방향키 + 스페이스 동시 입력")
        elif grade in ["C", "B"]:
            tips.append("⚡ **중급 기술 연마**")
            tips.append("• 퍼펙트 존: 패들 중앙 ±10픽셀 구간 집중")
            tips.append("• 게이지 관리: 항상 150 이상 유지")
            tips.append("• 연속 스킬: 첫 스킬 후 0.8초 내 추가 입력")
        else:
            tips.append("🏆 **고급 테크닉**")
            tips.append("• 프레임 캔슬: 스킬 모션 중 다음 입력 준비")
            tips.append("• 특수 패턴: ↓→Space (하도켄) 연습")
            tips.append("• 맥스 차지: 1.5초 홀드로 200% 파워")
        
        return "\n".join(tips)
    
    def get_dash_detailed_feedback(self, score: float, grade: str) -> Dict[str, str]:
        """대쉬 활용에 대한 상세 분석"""
        
        # 실제 게임 데이터 기반 분석
        dash_count = self.stats.dash_usage_count if self.stats.dash_usage_count > 0 else 1
        dash_success = (self.stats.dash_success_count / dash_count) * 100
        dash_saves = self.stats.dash_life_saves
        dash_defensive = getattr(self.stats, 'dash_defensive_saves', 0)
        half_dash_ratio = 0  # 하프대쉬 사용 비율 (게이지 부족 시 자동 발동)
        
        # 대쉬 토큰 시스템 분석
        if dash_count > 0:
            # 대쉬 토큰 효율성 (rolling_charges 기반)
            token_efficiency = min(100, (dash_saves / dash_count) * 200)
        else:
            token_efficiency = 0
        
        feedback = {
            "title": "🏃 대쉬 시스템 정밀 분석", 
            "grade": f"{grade} ({score:.1f}점)",
            "metrics": self._analyze_dash_metrics(dash_success, dash_saves, dash_defensive, token_efficiency),
            "strengths": self._identify_dash_strengths(dash_success, dash_saves, dash_defensive, token_efficiency),
            "weaknesses": self._identify_dash_weaknesses(dash_success, dash_saves, dash_defensive, token_efficiency),
            "tips": self._generate_dash_tips(dash_success, dash_saves, grade)
        }
        
        return feedback
    
    def _analyze_dash_metrics(self, success_rate: float, saves: int, defensive: int, token_eff: float) -> str:
        """대쉬 메트릭 분석"""
        metrics = []
        
        # 대쉬 성공률
        if success_rate >= 80:
            metrics.append(f"✅ 대쉬 성공률: {success_rate:.1f}% (정확한 판단력)")
        elif success_rate >= 50:
            metrics.append(f"📊 대쉬 성공률: {success_rate:.1f}% (안정적)")
        else:
            metrics.append(f"⚠️ 대쉬 성공률: {success_rate:.1f}% (타이밍 개선 필요)")
        
        # 생명 구조
        if saves >= 10:
            metrics.append(f"💖 생명 구조: {saves}회 (클러치 플레이어!)")
        elif saves >= 5:
            metrics.append(f"❤️ 생명 구조: {saves}회 (위기 대응 우수)")
        else:
            metrics.append(f"💔 생명 구조: {saves}회 (더 적극적 활용 필요)")
        
        # 토큰 효율성
        if token_eff >= 70:
            metrics.append(f"🎯 토큰 효율: {token_eff:.1f}% (최적화됨)")
        elif token_eff >= 40:
            metrics.append(f"🪙 토큰 효율: {token_eff:.1f}% (양호)")
        else:
            metrics.append(f"💸 토큰 효율: {token_eff:.1f}% (낭비 주의)")
        
        # 하프대쉬 정보
        metrics.append("💫 하프대쉬: 게이지<160일 때 자동 발동 (50% 거리)")
        
        return "\n".join(metrics)
    
    def _identify_dash_strengths(self, success_rate: float, saves: int, defensive: int, token_eff: float) -> str:
        """대쉬 강점 식별"""
        strengths = []
        
        if success_rate >= 70:
            strengths.append("• 정확한 대쉬 타이밍 판단")
        if saves >= 8:
            strengths.append("• 위기 상황 극복 능력 탁월")
        if defensive >= 5:
            strengths.append("• 수비적 대쉬 활용 우수")
        if token_eff >= 60:
            strengths.append("• 토큰 관리 효율적")
        
        # 대쉬 콤보 가능성
        if saves >= 5 and success_rate >= 60:
            strengths.append("• 연속 대쉬 가능 (쿨다운 0.5초)")
        
        return "\n".join(strengths) if strengths else "• 대쉬 시스템 학습 중"
    
    def _identify_dash_weaknesses(self, success_rate: float, saves: int, defensive: int, token_eff: float) -> str:
        """대쉬 약점 식별"""
        weaknesses = []
        
        if success_rate < 50:
            weaknesses.append("• 대쉬 타이밍 판단 미숙")
        if saves < 3:
            weaknesses.append("• 위기 상황 인지 부족")
        if token_eff < 30:
            weaknesses.append("• 토큰 낭비 심각")
        if self.stats.dash_usage_count < 10:
            weaknesses.append("• 대쉬 사용 빈도 너무 낮음")
        
        # 하프대쉬 미활용
        if self.stats.dash_usage_count > 0 and saves < 2:
            weaknesses.append("• 하프대쉬 활용 미흡 (게이지 부족 시)")
        
        return "\n".join(weaknesses) if weaknesses else "• 큰 약점 없음"
    
    def _generate_dash_tips(self, success_rate: float, saves: int, grade: str) -> str:
        """대쉬 개선 팁 생성"""
        tips = []
        
        if grade in ["F", "E", "D"]:
            tips.append("🎮 **대쉬 기초**")
            tips.append("• 아래 방향키: 대쉬 발동 (게이지 160 소모)")
            tips.append("• 하프대쉬: 게이지<160일 때 자동 (50% 거리)")
            tips.append("• 토큰 시스템: 대쉬 1회 = 토큰 1개")
        elif grade in ["C", "B"]:
            tips.append("🏃 **대쉬 활용법**")
            tips.append("• 위험 감지: 공 속도 15+ 또는 거리 100픽셀+")
            tips.append("• 쿨다운: 0.5초 (연속 사용 시 주의)")
            tips.append("• 대쉬홀더: 토큰 최대치 증가 아이템")
        else:
            tips.append("💨 **고급 대쉬 테크닉**")
            tips.append("• 예측 대쉬: 공 궤적 미리 계산")
            tips.append("• 대쉬 캔슬: 방향 전환으로 거리 조절")
            tips.append("• 토큰 관리: 항상 1개 이상 비축")
        
        return "\n".join(tips)
    
    def get_item_detailed_feedback(self, score: float, grade: str) -> Dict[str, str]:
        """아이템 활용에 대한 상세 분석"""
        
        # 실제 게임 데이터 기반 분석
        items_used = self.stats.items_used_count if self.stats.items_used_count > 0 else 1
        item_effectiveness = (self.stats.items_effective_count / items_used) * 100
        item_variety = len(set(self.stats.item_types_used))
        combo_rate = (self.stats.item_combo_count / items_used) * 100 if items_used > 0 else 0
        
        feedback = {
            "title": "🎁 아이템 시스템 정밀 분석",
            "grade": f"{grade} ({score:.1f}점)",
            "metrics": self._analyze_item_metrics(item_effectiveness, item_variety, combo_rate),
            "strengths": self._identify_item_strengths(item_effectiveness, item_variety, combo_rate),
            "weaknesses": self._identify_item_weaknesses(item_effectiveness, item_variety, combo_rate),
            "tips": self._generate_item_tips(item_effectiveness, item_variety, grade)
        }
        
        return feedback
    
    def _analyze_item_metrics(self, effectiveness: float, variety: int, combo_rate: float) -> str:
        """아이템 메트릭 분석"""
        metrics = []
        
        # 아이템 효과성
        if effectiveness >= 70:
            metrics.append(f"🎯 효과성: {effectiveness:.1f}% (타이밍 완벽)")
        elif effectiveness >= 40:
            metrics.append(f"📊 효과성: {effectiveness:.1f}% (적절한 활용)")
        else:
            metrics.append(f"⚠️ 효과성: {effectiveness:.1f}% (타이밍 개선 필요)")
        
        # 아이템 다양성
        if variety >= 10:
            metrics.append(f"🌈 다양성: {variety}종 (아이템 마스터!)")
        elif variety >= 5:
            metrics.append(f"🎨 다양성: {variety}종 (다양한 경험)")
        else:
            metrics.append(f"📦 다양성: {variety}종 (더 많은 아이템 시도)")
        
        # 콤보 활용
        if combo_rate >= 30:
            metrics.append(f"⚡ 콤보율: {combo_rate:.1f}% (시너지 활용 탁월)")
        elif combo_rate >= 10:
            metrics.append(f"🔗 콤보율: {combo_rate:.1f}% (조합 이해)")
        else:
            metrics.append(f"🔓 콤보율: {combo_rate:.1f}% (시너지 연구 필요)")
        
        return "\n".join(metrics)
    
    def _identify_item_strengths(self, effectiveness: float, variety: int, combo_rate: float) -> str:
        """아이템 강점 식별"""
        strengths = []
        
        if effectiveness >= 60:
            strengths.append("• 적절한 타이밍에 아이템 사용")
        if variety >= 8:
            strengths.append("• 다양한 아이템 경험과 이해")
        if combo_rate >= 20:
            strengths.append("• 아이템 시너지 활용 능력")
        if self.stats.items_used_count >= 30:
            strengths.append("• 적극적인 아이템 활용 성향")
        
        # 특정 아이템 숙련도
        if "devil_dice" in self.stats.item_types_used:
            strengths.append("• 악마의 주사위 활용 (6가지 랜덤 효과)")
        
        return "\n".join(strengths) if strengths else "• 아이템 시스템 학습 중"
    
    def _identify_item_weaknesses(self, effectiveness: float, variety: int, combo_rate: float) -> str:
        """아이템 약점 식별"""
        weaknesses = []
        
        if effectiveness < 40:
            weaknesses.append("• 아이템 사용 타이밍 부적절")
        if variety < 3:
            weaknesses.append("• 제한적인 아이템 경험")
        if combo_rate < 5:
            weaknesses.append("• 아이템 시너지 미활용")
        if self.stats.items_used_count < 10:
            weaknesses.append("• 소극적 아이템 사용")
        
        return "\n".join(weaknesses) if weaknesses else "• 큰 약점 없음"
    
    def _generate_item_tips(self, effectiveness: float, variety: int, grade: str) -> str:
        """아이템 개선 팁 생성"""
        tips = []
        
        if grade in ["F", "E", "D"]:
            tips.append("🎮 **아이템 기초**")
            tips.append("• 숫자키 1-5: 액티브 아이템 사용")
            tips.append("• 패시브: 자동 효과 (중복 불가)")
            tips.append("• 가챠: 캡슐머신에서 획득")
        elif grade in ["C", "B"]:
            tips.append("🎁 **아이템 활용**")
            tips.append("• 시너지: 대쉬기어+대쉬홀더 조합")
            tips.append("• 타이밍: 위기 상황 우선 사용")
            tips.append("• 관리: 슬롯 5개 효율적 운용")
        else:
            tips.append("💎 **고급 아이템 전략**")
            tips.append("• 메타 빌드: 스피드+대쉬 조합")
            tips.append("• 상황별: 보스별 최적 아이템 선택")
            tips.append("• 희귀템: 악마의 주사위 확률 극대화")
        
        return "\n".join(tips)
    
    def get_guard_detailed_feedback(self, score: float, grade: str) -> Dict[str, str]:
        """가드 능력에 대한 상세 분석"""
        
        # 실제 게임 데이터 기반 분석
        total_attempts = self.stats.total_hits + self.stats.total_misses
        if total_attempts > 0:
            guard_rate = (self.stats.successful_guards / total_attempts) * 100
            accuracy = (self.stats.total_hits / total_attempts) * 100
        else:
            guard_rate = 0
            accuracy = 0
        
        danger_saves = self.stats.defensive_saves
        clutch_recoveries = self.stats.close_call_recoveries
        
        feedback = {
            "title": "🛡️ 가드 시스템 정밀 분석",
            "grade": f"{grade} ({score:.1f}점)",
            "metrics": self._analyze_guard_metrics(guard_rate, accuracy, danger_saves, clutch_recoveries),
            "strengths": self._identify_guard_strengths(guard_rate, accuracy, danger_saves, clutch_recoveries),
            "weaknesses": self._identify_guard_weaknesses(guard_rate, accuracy, danger_saves, clutch_recoveries),
            "tips": self._generate_guard_tips(guard_rate, accuracy, grade)
        }
        
        return feedback
    
    def _analyze_guard_metrics(self, guard_rate: float, accuracy: float, danger: int, clutch: int) -> str:
        """가드 메트릭 분석"""
        metrics = []
        
        # 기본 수비율
        if accuracy >= 80:
            metrics.append(f"🎯 정확도: {accuracy:.1f}% (철벽 수비!)")
        elif accuracy >= 60:
            metrics.append(f"📊 정확도: {accuracy:.1f}% (안정적)")
        else:
            metrics.append(f"⚠️ 정확도: {accuracy:.1f}% (집중력 필요)")
        
        # 위기 대응
        if danger >= 20:
            metrics.append(f"⚡ 위기 구조: {danger}회 (반사신경 탁월!)")
        elif danger >= 10:
            metrics.append(f"💪 위기 구조: {danger}회 (대응력 우수)")
        else:
            metrics.append(f"🔄 위기 구조: {danger}회 (반응 속도 개선)")
        
        # 클러치 상황
        if clutch >= 15:
            metrics.append(f"🔥 극한 회복: {clutch}회 (멘탈 강함!)")
        elif clutch >= 5:
            metrics.append(f"✨ 극한 회복: {clutch}회 (침착함)")
        else:
            metrics.append(f"📈 극한 회복: {clutch}회 (압박 대응 연습)")
        
        # 패들 물리
        metrics.append("🎮 패들 충돌: 중앙±10px = 직선, 가장자리 = 각도변화")
        
        return "\n".join(metrics)
    
    def _identify_guard_strengths(self, guard_rate: float, accuracy: float, danger: int, clutch: int) -> str:
        """가드 강점 식별"""
        strengths = []
        
        if accuracy >= 70:
            strengths.append("• 안정적인 볼 컨트롤")
        if danger >= 15:
            strengths.append("• 빠른 반사신경")
        if clutch >= 10:
            strengths.append("• 압박 상황 대응력")
        if self.stats.max_hit_streak >= 20:
            strengths.append(f"• 집중력 유지 (최대 {self.stats.max_hit_streak}연속)")
        
        # 패들 활용
        if accuracy >= 75 and self.stats.perfect_timing_hits > 10:
            strengths.append("• 패들 중앙 활용 우수 (각도 컨트롤)")
        
        return "\n".join(strengths) if strengths else "• 가드 시스템 학습 중"
    
    def _identify_guard_weaknesses(self, guard_rate: float, accuracy: float, danger: int, clutch: int) -> str:
        """가드 약점 식별"""
        weaknesses = []
        
        if accuracy < 50:
            weaknesses.append("• 기본 수비 불안정")
        if danger < 5:
            weaknesses.append("• 위기 상황 대응 미흡")
        if clutch < 3:
            weaknesses.append("• 압박 상황 취약")
        if self.stats.current_miss_streak > 3:
            weaknesses.append(f"• 연속 실수 발생 ({self.stats.current_miss_streak}회)")
        
        # 반응 시간
        avg_reaction = self.analyzer.get_average_reaction_time()
        if avg_reaction > 1.0:
            weaknesses.append(f"• 반응 속도 느림 ({avg_reaction:.2f}초)")
        
        return "\n".join(weaknesses) if weaknesses else "• 큰 약점 없음"
    
    def _generate_guard_tips(self, guard_rate: float, accuracy: float, grade: str) -> str:
        """가드 개선 팁 생성"""
        tips = []
        
        if grade in ["F", "E", "D"]:
            tips.append("🎮 **수비 기초**")
            tips.append("• 패들 이동: ←→ 또는 A/D")
            tips.append("• 충돌 판정: 패들 전체 영역")
            tips.append("• 집중: 공만 보고 따라가기")
        elif grade in ["C", "B"]:
            tips.append("🛡️ **수비 전략**")
            tips.append("• 예측: 벽 반사각 미리 계산")
            tips.append("• 포지션: 화면 중앙 유지")
            tips.append("• 각도: 패들 가장자리로 방향 조절")
        else:
            tips.append("⚔️ **고급 수비술**")
            tips.append("• 프레임 예측: 3프레임 앞 위치 계산")
            tips.append("• 반격 준비: 수비→공격 전환 0.2초")
            tips.append("• 멘탈: 실수 후 즉시 리셋")
        
        return "\n".join(tips)
    
    def generate_comprehensive_feedback(self) -> str:
        """종합 피드백 생성"""
        
        # 각 카테고리 점수 계산
        skill_score = self.analyzer.get_skill_mastery_score()
        dash_score = self.analyzer.get_dash_mastery_score()
        item_score = self.analyzer.get_item_mastery_score()
        guard_score = self.analyzer.get_guard_ability_score()
        
        # 등급 변환
        def score_to_grade(score):
            if score >= 90: return "S"
            elif score >= 80: return "A"
            elif score >= 70: return "B"
            elif score >= 60: return "C"
            elif score >= 50: return "D"
            elif score >= 30: return "E"
            else: return "F"
        
        # 각 카테고리별 상세 피드백
        skill_feedback = self.get_skill_detailed_feedback(skill_score, score_to_grade(skill_score))
        dash_feedback = self.get_dash_detailed_feedback(dash_score, score_to_grade(dash_score))
        item_feedback = self.get_item_detailed_feedback(item_score, score_to_grade(item_score))
        guard_feedback = self.get_guard_detailed_feedback(guard_score, score_to_grade(guard_score))
        
        # 통합 피드백 구성
        feedback_text = "=" * 60 + "\n"
        feedback_text += "🎮 **플레이어 실력 정밀 분석 리포트**\n"
        feedback_text += "=" * 60 + "\n\n"
        
        # 각 카테고리별 섹션
        for fb in [skill_feedback, dash_feedback, item_feedback, guard_feedback]:
            feedback_text += f"### {fb['title']}\n"
            feedback_text += f"**등급**: {fb['grade']}\n\n"
            feedback_text += f"**📊 성능 지표**\n{fb['metrics']}\n\n"
            feedback_text += f"**💪 강점**\n{fb['strengths']}\n\n"
            feedback_text += f"**⚠️ 개선점**\n{fb['weaknesses']}\n\n"
            feedback_text += f"**💡 맞춤 조언**\n{fb['tips']}\n\n"
            feedback_text += "-" * 40 + "\n\n"
        
        # 종합 평가
        avg_score = (skill_score + dash_score + item_score + guard_score) / 4
        overall_grade = score_to_grade(avg_score)
        
        feedback_text += "=" * 60 + "\n"
        feedback_text += f"### 🏆 종합 평가: {overall_grade}등급 ({avg_score:.1f}점)\n\n"
        
        # 플레이 스타일 분석
        style = self._analyze_play_style(skill_score, dash_score, item_score, guard_score)
        feedback_text += f"**플레이 스타일**: {style}\n\n"
        
        # 다음 목표
        next_goals = self._suggest_next_goals(skill_score, dash_score, item_score, guard_score)
        feedback_text += f"**다음 목표**:\n{next_goals}\n\n"
        
        feedback_text += "=" * 60 + "\n"
        
        return feedback_text
    
    def _analyze_play_style(self, skill: float, dash: float, item: float, guard: float) -> str:
        """플레이 스타일 분석"""
        
        scores = {"스킬": skill, "대쉬": dash, "아이템": item, "가드": guard}
        highest = max(scores, key=scores.get)
        
        styles = {
            "스킬": "🎯 테크니션 - 정밀한 스킬 활용으로 승부",
            "대쉬": "⚡ 스피드스터 - 빠른 움직임과 기동력",
            "아이템": "🎁 전략가 - 아이템 활용과 시너지",
            "가드": "🛡️ 수비수 - 안정적인 수비와 반격"
        }
        
        return styles[highest]
    
    def _suggest_next_goals(self, skill: float, dash: float, item: float, guard: float) -> str:
        """다음 목표 제안"""
        goals = []
        
        # 가장 낮은 점수 영역 찾기
        scores = {"스킬": skill, "대쉬": dash, "아이템": item, "가드": guard}
        weakest = min(scores, key=scores.get)
        
        if scores[weakest] < 50:
            goals.append(f"1. {weakest} 능력 집중 향상 (현재 {scores[weakest]:.0f}점 → 목표 60점)")
        
        # 전체 평균 기준 목표
        avg = sum(scores.values()) / 4
        if avg < 70:
            goals.append(f"2. 전체 평균 70점 달성 (현재 {avg:.0f}점)")
        elif avg < 85:
            goals.append(f"2. 전체 평균 85점 달성 (현재 {avg:.0f}점)")
        else:
            goals.append("2. 모든 영역 S등급 도전!")
        
        # 특별 목표
        if self.stats.max_hit_streak < 30:
            goals.append(f"3. 연속 히트 30회 달성 (현재 최고 {self.stats.max_hit_streak}회)")
        
        return "\n".join(goals)


def get_enhanced_feedback(player_analyzer, current_stage: int = 1) -> str:
    """향상된 피드백 시스템 메인 함수"""
    
    enhanced_system = EnhancedFeedbackSystem(player_analyzer)
    return enhanced_system.generate_comprehensive_feedback()