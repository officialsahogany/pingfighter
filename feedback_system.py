# -*- coding: utf-8 -*-
"""
상세한 피드백 시스템
플레이어의 등급별 맞춤형 피드백과 개선 조언을 제공
"""

def get_skill_feedback(score: float, grade: str) -> str:
    """스킬 활용 능력 피드백"""
    if grade == "플레이 필요":
        return "🎯 스킬 활용 분석 대기 중입니다. 게임을 플레이하여 드라이브와 파워스매싱 실력을 확인해보세요!"
    
    feedback = "🎯 **스킬 활용 능력 분석**\n\n"
    
    if grade == "S":
        feedback += "🌟 **완벽한 스킬 마스터!** 🌟\n"
        feedback += "당신은 진정한 스킬의 달인입니다! 드라이브와 파워스매싱을 완벽하게 구사하며, "
        feedback += "타이밍과 정확도 모든 면에서 최고 수준의 실력을 보여주고 있습니다.\n\n"
        feedback += "📚 **스킬 마스터리 특징:**\n"
        feedback += "• 퍼펙트 타이밍 구사율 90% 이상\n"
        feedback += "• 상황에 맞는 최적의 스킬 선택\n"
        feedback += "• 압박 상황에서도 냉정한 판단력\n"
        feedback += "• 스킬 연계를 통한 승리 창출 능력\n\n"
        feedback += "🎓 **전문가 조언:** 이미 완성된 실력입니다. 후배들에게 노하우를 전수해보세요!"
        
    elif grade == "A":
        feedback += "🔥 **뛰어난 스킬 실력!** 🔥\n"
        feedback += "상당히 높은 수준의 스킬 활용 능력을 보유하고 있습니다. 대부분의 상황에서 "
        feedback += "적절한 스킬을 구사하며, 승리에 크게 기여하고 있습니다.\n\n"
        feedback += "📚 **현재 강점:**\n"
        feedback += "• 안정적인 드라이브 타이밍 구사\n"
        feedback += "• 파워스매싱 활용도 우수\n"
        feedback += "• 위기 상황 대응 능력 뛰어남\n\n"
        feedback += "🎯 **S등급 도달 팁:**\n"
        feedback += "• 극한 상황에서의 스킬 정확도 향상\n"
        feedback += "• 연속 스킬 콤보 연습\n"
        feedback += "• 상대방 패턴 예측 후 선제 스킬 사용"
        
    elif grade == "B":
        feedback += "💪 **양호한 스킬 실력** 💪\n"
        feedback += "기본적인 스킬 활용은 잘 하고 있지만, 조금 더 정교함이 필요합니다. "
        feedback += "꾸준한 연습으로 더 높은 등급에 도달할 수 있습니다.\n\n"
        feedback += "📚 **개선 포인트:**\n"
        feedback += "• 타이밍 정확도 향상 필요\n"
        feedback += "• 상황 판단력 개발\n"
        feedback += "• 스킬 사용 빈도 증가\n\n"
        feedback += "🎯 **A등급 도달 팁:**\n"
        feedback += "• 퍼펙트 타이밍 연습을 늘려보세요\n"
        feedback += "• 위험한 상황에서 적극적인 스킬 사용\n"
        feedback += "• 게이지 관리와 스킬 타이밍의 균형"
        
    elif grade == "C":
        feedback += "📈 **발전 가능성이 높음** 📈\n"
        feedback += "스킬의 기초는 이해하고 있지만, 실전 활용에서 아쉬움이 있습니다. "
        feedback += "좀 더 적극적인 스킬 사용과 타이밍 연습이 필요합니다.\n\n"
        feedback += "📚 **학습 가이드:**\n"
        feedback += "• 드라이브: 방향키 + 스페이스 동시 입력\n"
        feedback += "• 파워스매싱: 스페이스 길게 누르기\n"
        feedback += "• 퍼펙트 타이밍: 공이 패들에 가까워질 때 사용\n\n"
        feedback += "🎯 **B등급 도달 팁:**\n"
        feedback += "• 매 라운드마다 최소 2-3회 스킬 사용 목표\n"
        feedback += "• 타이밍 연습을 위한 반복 플레이\n"
        feedback += "• 게이지 충전 상태 항상 확인"
        
    elif grade in ["D", "E"]:
        feedback += "🌱 **스킬 연습이 필요함** 🌱\n"
        feedback += "아직 스킬 활용에 익숙하지 않은 것 같습니다. 기본기부터 차근차근 "
        feedback += "연습하시면 분명히 실력이 향상될 것입니다.\n\n"
        feedback += "📚 **기초 학습:**\n"
        feedback += "• 스킬 조작법 완전 숙지\n"
        feedback += "• 게이지 시스템 이해\n"
        feedback += "• 타이밍 감각 개발\n\n"
        feedback += "🎯 **C등급 도달 팁:**\n"
        feedback += "• 연습 모드에서 스킬 조작 반복 연습\n"
        feedback += "• 천천히 타이밍 맞추는 연습부터 시작\n"
        feedback += "• 게이지가 충분할 때 적극적으로 스킬 사용"
    else:  # F
        feedback += "🎮 **기초부터 다시 시작** 🎮\n"
        feedback += "스킬 시스템에 대한 이해가 부족해 보입니다. 하지만 걱정하지 마세요! "
        feedback += "모든 고수들도 처음에는 초보였습니다.\n\n"
        feedback += "📚 **첫걸음 가이드:**\n"
        feedback += "• 튜토리얼 다시 확인\n"
        feedback += "• 조작법 숙지가 최우선\n"
        feedback += "• 천천히 한 가지씩 연습\n\n"
        feedback += "🎯 **D등급 도달 팁:**\n"
        feedback += "• 스킬 버튼 조합 완전히 외우기\n"
        feedback += "• 게이지 150 이상일 때만 스킬 사용\n"
        feedback += "• 무리하지 말고 성공률부터 높이기"
        
    return feedback

def get_dash_feedback(score: float, grade: str) -> str:
    """대쉬 활용 능력 피드백"""
    if grade == "플레이 필요":
        return "⚡ 대쉬 활용 분석 대기 중입니다. 아래 방향키로 대쉬를 사용해보세요!"
    
    feedback = "⚡ **대쉬 활용 능력 분석**\n\n"
    
    if grade == "S":
        feedback += "🌪️ **대쉬의 신!** 🌪️\n"
        feedback += "당신의 대쉬 활용은 예술 수준입니다! 완벽한 타이밍과 상황 판단으로 "
        feedback += "위기를 기회로 바꾸는 능력이 탁월합니다.\n\n"
        feedback += "📚 **대쉬 마스터 특징:**\n"
        feedback += "• 생명을 구하는 완벽한 타이밍\n"
        feedback += "• 공격적 대쉬로 승리 창출\n"
        feedback += "• 대쉬 후 완벽한 포지셔닝\n"
        feedback += "• 게이지 관리와 대쉬의 완벽한 조화\n\n"
        feedback += "🎓 **마스터 조언:** 대쉬의 달인이군요! 다른 플레이어들의 롤모델입니다."
        
    elif grade == "A":
        feedback += "💨 **훌륭한 대쉬 컨트롤!** 💨\n"
        feedback += "대쉬를 매우 효과적으로 활용하고 있습니다. 위기 상황에서의 판단력과 "
        feedback += "실행력이 뛰어납니다.\n\n"
        feedback += "📚 **현재 강점:**\n"
        feedback += "• 위험 상황 인지 능력 우수\n"
        feedback += "• 대쉬 타이밍 안정적\n"
        feedback += "• 생존율 크게 향상\n\n"
        feedback += "🎯 **S등급 도달 팁:**\n"
        feedback += "• 공격적 대쉬 활용 늘리기\n"
        feedback += "• 연속 대쉬 콤보 연습\n"
        feedback += "• 예측 대쉬로 선제 대응"
        
    elif grade == "B":
        feedback += "🏃 **괜찮은 대쉬 활용** 🏃\n"
        feedback += "기본적인 대쉬 활용은 할 수 있지만, 더 적극적이고 전략적인 사용이 "
        feedback += "필요합니다.\n\n"
        feedback += "📚 **개선 포인트:**\n"
        feedback += "• 대쉬 사용 빈도 증가\n"
        feedback += "• 타이밍 정확도 향상\n"
        feedback += "• 상황 판단력 개발\n\n"
        feedback += "🎯 **A등급 도달 팁:**\n"
        feedback += "• 위험해 보이는 상황에서 과감한 대쉬\n"
        feedback += "• 대쉬 후 즉시 다음 동작 준비\n"
        feedback += "• 대쉬홀더 아이템 적극 활용"
        
    elif grade == "C":
        feedback += "🚶 **대쉬 연습이 필요** 🚶\n"
        feedback += "대쉬의 기본 개념은 이해하고 있지만, 실전에서의 활용도가 아쉽습니다. "
        feedback += "더 많은 연습이 필요합니다.\n\n"
        feedback += "📚 **학습 가이드:**\n"
        feedback += "• 대쉬 조작: 아래 방향키\n"
        feedback += "• 대쉬 게이지: 160 소모 (기본)\n"
        feedback += "• 대쉬 효과: 빠른 이동으로 공 받기 가능\n\n"
        feedback += "🎯 **B등급 도달 팁:**\n"
        feedback += "• 공이 닿기 어려운 곳에 있을 때 적극 사용\n"
        feedback += "• 대쉬 후 패들 위치 빠르게 조정\n"
        feedback += "• 게이지 여유 있을 때 연습 삼아 사용"
        
    elif grade in ["D", "E"]:
        feedback += "🐌 **대쉬 기초 연습** 🐌\n"
        feedback += "대쉬 활용에 많은 연습이 필요합니다. 기본기부터 차근차근 익혀나가세요.\n\n"
        feedback += "📚 **기초 학습:**\n"
        feedback += "• 대쉬 버튼 위치 숙지\n"
        feedback += "• 게이지 관리 방법 학습\n"
        feedback += "• 대쉬 타이밍 감각 개발\n\n"
        feedback += "🎯 **C등급 도달 팁:**\n"
        feedback += "• 위기 상황에서만 대쉬 사용\n"
        feedback += "• 대쉬 후 침착하게 다음 동작\n"
        feedback += "• 게이지가 충분할 때 연습"
    else:  # F
        feedback += "🔰 **대쉬 입문자** 🔰\n"
        feedback += "대쉬 시스템을 아직 활용하지 못하고 있습니다. 천천히 배워나가면 됩니다!\n\n"
        feedback += "📚 **첫걸음:**\n"
        feedback += "• 아래 방향키가 대쉬 버튼\n"
        feedback += "• 게이지 160 이상일 때 사용 가능\n"
        feedback += "• 위급할 때만 사용하는 것부터 시작\n\n"
        feedback += "🎯 **시작 팁:**\n"
        feedback += "• 공을 놓칠 것 같을 때만 사용\n"
        feedback += "• 대쉬 후 패들 움직임 확인\n"
        feedback += "• 게이지 소모량 체크"
        
    return feedback

def get_item_feedback(score: float, grade: str) -> str:
    """아이템 활용 능력 피드백"""
    if grade == "플레이 필요":
        return "🎁 아이템 활용 분석 대기 중입니다. 아이템을 획득하고 사용해보세요!"
    
    feedback = "🎁 **아이템 활용 능력 분석**\n\n"
    
    if grade == "S":
        feedback += "🏆 **아이템 마스터!** 🏆\n"
        feedback += "아이템 활용의 달인입니다! 다양한 아이템을 상황에 맞게 완벽하게 활용하며, "
        feedback += "전략적 사고가 돋보입니다.\n\n"
        feedback += "📚 **마스터 특징:**\n"
        feedback += "• 상황별 최적 아이템 선택\n"
        feedback += "• 아이템 조합 전략 구사\n"
        feedback += "• 타이밍의 완벽한 조절\n"
        feedback += "• 아이템 효과 극대화 활용\n\n"
        feedback += "🎓 **전문가 인정:** 아이템 활용의 교과서입니다!"
        
    elif grade == "A":
        feedback += "🎖️ **뛰어난 아이템 센스!** 🎖️\n"
        feedback += "아이템을 매우 효과적으로 활용하고 있습니다. 다양한 아이템을 적절한 "
        feedback += "타이밍에 사용하는 능력이 뛰어납니다.\n\n"
        feedback += "📚 **현재 강점:**\n"
        feedback += "• 아이템 효과 정확히 이해\n"
        feedback += "• 적절한 사용 타이밍\n"
        feedback += "• 다양한 아이템 경험\n\n"
        feedback += "🎯 **S등급 도달 팁:**\n"
        feedback += "• 아이템 연계 전략 개발\n"
        feedback += "• 상황별 우선순위 최적화\n"
        feedback += "• 새로운 아이템 조합 실험"
        
    elif grade == "B":
        feedback += "📦 **아이템 활용 양호** 📦\n"
        feedback += "기본적인 아이템 사용은 잘 하고 있지만, 더 다양하고 전략적인 활용이 "
        feedback += "가능할 것 같습니다.\n\n"
        feedback += "📚 **개선 포인트:**\n"
        feedback += "• 아이템 사용 빈도 증가\n"
        feedback += "• 다양한 아이템 경험\n"
        feedback += "• 타이밍 최적화\n\n"
        feedback += "🎯 **A등급 도달 팁:**\n"
        feedback += "• 매 라운드 아이템 적극 사용\n"
        feedback += "• 새로운 아이템 조합 시도\n"
        feedback += "• 상황에 맞는 아이템 선택 연습"
        
    elif grade == "C":
        feedback += "📝 **아이템 학습 중** 📝\n"
        feedback += "아이템의 기본적인 사용은 하고 있지만, 더 효과적인 활용 방법을 "
        feedback += "배워나가면 좋겠습니다.\n\n"
        feedback += "📚 **학습 가이드:**\n"
        feedback += "• 아이템 효과 완전 숙지\n"
        feedback += "• 사용 타이밍 연구\n"
        feedback += "• 다양한 아이템 실험\n\n"
        feedback += "🎯 **B등급 도달 팁:**\n"
        feedback += "• 아이템 설명 꼼꼼히 읽기\n"
        feedback += "• 위기 상황에서 적극 사용\n"
        feedback += "• 아이템 조합 효과 확인"
        
    elif grade in ["D", "E"]:
        feedback += "🎒 **아이템 연습 필요** 🎒\n"
        feedback += "아이템 활용에 더 많은 관심과 연습이 필요합니다. 아이템은 게임의 "
        feedback += "재미와 전략성을 크게 높여줍니다.\n\n"
        feedback += "📚 **기초 학습:**\n"
        feedback += "• 아이템 사용법 완전 숙지\n"
        feedback += "• 각 아이템 효과 이해\n"
        feedback += "• 기본적인 사용 타이밍\n\n"
        feedback += "🎯 **C등급 도달 팁:**\n"
        feedback += "• 획득한 아이템은 반드시 사용\n"
        feedback += "• 간단한 아이템부터 시작\n"
        feedback += "• 아이템 효과 확인 후 사용"
    else:  # F
        feedback += "🆕 **아이템 시작 단계** 🆕\n"
        feedback += "아이템 시스템을 거의 활용하지 않고 있습니다. 아이템은 게임의 핵심 "
        feedback += "요소 중 하나입니다!\n\n"
        feedback += "📚 **시작 가이드:**\n"
        feedback += "• 아이템 획득 방법 학습\n"
        feedback += "• 기본 사용 키 숙지\n"
        feedback += "• 간단한 아이템 효과 확인\n\n"
        feedback += "🎯 **첫걸음:**\n"
        feedback += "• 숫자키로 아이템 사용\n"
        feedback += "• 회복 아이템부터 시작\n"
        feedback += "• 아이템 설명 꼼꼼히 읽기"
        
    return feedback

def get_guard_feedback(score: float, grade: str) -> str:
    """가드 능력 피드백"""
    if grade == "플레이 필요":
        return "🛡️ 가드 능력 분석 대기 중입니다. 게임을 플레이하여 수비 실력을 확인해보세요!"
    
    feedback = "🛡️ **가드 능력 분석**\n\n"
    
    if grade == "S":
        feedback += "🏰 **완벽한 수비의 벽!** 🏰\n"
        feedback += "당신의 수비는 난공불락입니다! 어떤 공격도 막아내는 철벽 수비와 "
        feedback += "완벽한 반격 능력을 보여주고 있습니다.\n\n"
        feedback += "📚 **가드 마스터 특징:**\n"
        feedback += "• 95% 이상의 놀라운 성공률\n"
        feedback += "• 완벽한 위치 선정과 타이밍\n"
        feedback += "• 수비에서 공격으로의 완벽한 전환\n"
        feedback += "• 어떤 상황에서도 흔들리지 않는 멘탈\n\n"
        feedback += "🎓 **레전드 인정:** 수비의 신이라 불러도 손색없습니다!"
        
    elif grade == "A":
        feedback += "🛡️ **믿음직한 수비수!** 🛡️\n"
        feedback += "매우 안정적인 수비력을 보여주고 있습니다. 대부분의 공격을 성공적으로 "
        feedback += "막아내며, 팀에 큰 신뢰감을 줍니다.\n\n"
        feedback += "📚 **현재 강점:**\n"
        feedback += "• 높은 성공률 유지\n"
        feedback += "• 안정적인 볼 컨트롤\n"
        feedback += "• 좋은 위치 선정 능력\n\n"
        feedback += "🎯 **S등급 도달 팁:**\n"
        feedback += "• 극한 상황에서의 정확도 향상\n"
        feedback += "• 반격 패턴 다양화\n"
        feedback += "• 예측 수비 능력 개발"
        
    elif grade == "B":
        feedback += "⚔️ **괜찮은 수비력** ⚔️\n"
        feedback += "기본적인 수비는 잘 하고 있지만, 조금 더 정교함과 안정성이 필요합니다. "
        feedback += "꾸준한 연습으로 향상 가능합니다.\n\n"
        feedback += "📚 **개선 포인트:**\n"
        feedback += "• 성공률 안정화\n"
        feedback += "• 어려운 상황 대응력 향상\n"
        feedback += "• 반응 속도 개선\n\n"
        feedback += "🎯 **A등급 도달 팁:**\n"
        feedback += "• 집중력 유지 연습\n"
        feedback += "• 다양한 공 궤도 경험\n"
        feedback += "• 패들 움직임 최적화"
        
    elif grade == "C":
        feedback += "🏃 **수비 연습 중** 🏃\n"
        feedback += "기본적인 볼 받기는 할 수 있지만, 더 안정적이고 정확한 수비가 "
        feedback += "필요합니다.\n\n"
        feedback += "📚 **학습 가이드:**\n"
        feedback += "• 공의 궤도 예측 연습\n"
        feedback += "• 패들 위치 조절 능력 향상\n"
        feedback += "• 집중력 유지 방법 학습\n\n"
        feedback += "🎯 **B등급 도달 팁:**\n"
        feedback += "• 침착함 유지하며 플레이\n"
        feedback += "• 패들 중앙으로 공 받기 연습\n"
        feedback += "• 예측보다는 반응에 집중"
        
    elif grade in ["D", "E"]:
        feedback += "🥅 **수비 기초 연습** 🥅\n"
        feedback += "수비에 많은 연습이 필요합니다. 기본기부터 차근차근 익혀나가면 "
        feedback += "분명히 향상될 것입니다.\n\n"
        feedback += "📚 **기초 학습:**\n"
        feedback += "• 패들 조작법 완전 숙지\n"
        feedback += "• 공의 움직임 관찰\n"
        feedback += "• 기본적인 반응 속도 향상\n\n"
        feedback += "🎯 **C등급 도달 팁:**\n"
        feedback += "• 천천히 정확하게 받기 연습\n"
        feedback += "• 공에만 집중하기\n"
        feedback += "• 패들 중앙 활용도 높이기"
    else:  # F
        feedback += "🔰 **수비 입문 단계** 🔰\n"
        feedback += "수비 기초부터 시작해야 합니다. 하지만 걱정하지 마세요. 모든 고수도 "
        feedback += "처음에는 공을 많이 놓쳤습니다!\n\n"
        feedback += "📚 **첫걸음:**\n"
        feedback += "• 패들 움직임 익히기\n"
        feedback += "• 공의 기본 궤도 이해\n"
        feedback += "• 침착함 유지하기\n\n"
        feedback += "🎯 **시작 팁:**\n"
        feedback += "• 급하지 말고 천천히\n"
        feedback += "• 공에만 집중\n"
        feedback += "• 실수해도 괜찮다는 마음가짐"
        
    return feedback

def get_overall_feedback(skill_score: float, dash_score: float, 
                        item_score: float, guard_score: float) -> str:
    """전체적인 피드백"""
    avg_score = (skill_score + dash_score + item_score + guard_score) / 4
    
    def score_to_grade_text(score: float) -> str:
        if score == 0:
            return "플레이 필요"
        elif score >= 90:
            return "S"
        elif score >= 80:
            return "A"
        elif score >= 70:
            return "B"
        elif score >= 60:
            return "C"
        elif score >= 50:
            return "D"
        elif score >= 30:
            return "E"
        else:
            return "F"
    
    avg_grade = score_to_grade_text(avg_score)
    
    if avg_grade == "플레이 필요":
        return "🎮 분석을 위해 더 많은 플레이 데이터가 필요합니다!"
    
    feedback = "🏅 **종합 평가**\n\n"
    
    # 최고 점수와 최저 점수 찾기
    scores = [
        ("스킬 활용", skill_score),
        ("대쉬 활용", dash_score), 
        ("아이템 활용", item_score),
        ("가드 능력", guard_score)
    ]
    scores.sort(key=lambda x: x[1], reverse=True)
    
    strongest = scores[0]
    weakest = scores[-1]
    
    if avg_grade in ["S", "A"]:
        feedback += f"🌟 **훌륭한 실력입니다!** (평균 {avg_grade}등급)\n"
        feedback += f"특히 {strongest[0]} 분야에서 뛰어난 능력을 보여주고 있습니다. "
        feedback += f"현재 실력으로도 충분히 높은 수준이지만, "
        if weakest[1] < 70:
            feedback += f"{weakest[0]} 분야를 조금 더 연습하면 완벽한 플레이어가 될 수 있습니다."
        else:
            feedback += "모든 분야에서 균형잡힌 실력을 보여주고 있습니다."
            
    elif avg_grade in ["B", "C"]:
        feedback += f"💪 **성장하고 있는 플레이어** ({avg_grade}등급)\n"
        feedback += f"{strongest[0]} 분야는 잘하고 있습니다! "
        feedback += f"앞으로 {weakest[0]} 분야에 조금 더 집중하여 연습하면 "
        feedback += "전체적인 실력 향상을 기대할 수 있습니다."
        
    else:  # D, E, F
        feedback += f"🌱 **발전 가능성이 무궁무진** ({avg_grade}등급)\n"
        feedback += "모든 고수들도 처음에는 초보였습니다! "
        feedback += f"현재는 {strongest[0]} 분야가 상대적으로 나은 편이니, "
        feedback += "이 부분을 중심으로 자신감을 키워나가세요."
        
    return feedback

def get_improvement_tips(skill_score: float, dash_score: float,
                        item_score: float, guard_score: float) -> str:
    """개선 팁"""
    tips = "💡 **맞춤형 개선 조언**\n\n"
    
    # 가장 약한 분야 찾기
    weak_areas = []
    if skill_score < 60:
        weak_areas.append(("스킬 활용", skill_score))
    if dash_score < 60:
        weak_areas.append(("대쉬 활용", dash_score))
    if item_score < 60:
        weak_areas.append(("아이템 활용", item_score))
    if guard_score < 60:
        weak_areas.append(("가드 능력", guard_score))
        
    if not weak_areas:
        tips += "🎉 **완성도 높은 플레이어**\n"
        tips += "모든 분야에서 우수한 실력을 보여주고 있습니다! "
        tips += "현재 수준을 유지하면서 더욱 정교한 플레이를 연구해보세요.\n\n"
        tips += "🎯 **더 높은 수준을 위한 조언:**\n"
        tips += "• 새로운 전략과 패턴 개발\n"
        tips += "• 극한 상황에서의 안정성 향상\n"
        tips += "• 창의적인 플레이 스타일 연구"
    else:
        tips += f"🎯 **우선 개선 분야:** {len(weak_areas)}개 영역\n\n"
        
        for area, score in weak_areas:
            if area == "스킬 활용":
                tips += "⚡ **스킬 마스터가 되는 법:**\n"
                tips += "• 매일 10분씩 타이밍 연습\n"
                tips += "• 퍼펙트 타이밍 구간 완전 숙지\n"
                tips += "• 상황별 최적 스킬 선택 연구\n\n"
            elif area == "대쉬 활용":
                tips += "🏃 **대쉬 전문가가 되는 법:**\n"
                tips += "• 위험 상황 미리 예측하기\n"
                tips += "• 대쉬 후 즉시 다음 동작 준비\n"
                tips += "• 게이지 관리와 대쉬 타이밍 최적화\n\n"
            elif area == "아이템 활용":
                tips += "🎁 **아이템 마스터가 되는 법:**\n"
                tips += "• 모든 아이템 효과 완전 숙지\n"
                tips += "• 상황별 아이템 우선순위 정하기\n"
                tips += "• 아이템 조합 효과 실험해보기\n\n"
            elif area == "가드 능력":
                tips += "🛡️ **수비 달인이 되는 법:**\n"
                tips += "• 공의 궤도 예측 능력 기르기\n"
                tips += "• 패들 중앙으로 공 받기 연습\n"
                tips += "• 집중력 유지 방법 개발하기\n\n"
                
    tips += "🌟 **성공의 비결:**\n"
    tips += "꾸준함이 가장 중요합니다. 매일 조금씩이라도 연습하면 "
    tips += "분명히 실력이 향상될 것입니다. 실수를 두려워하지 말고 "
    tips += "적극적으로 도전해보세요!"
    
    return tips


