"""
BossPong 게이지 밸런스 분석
"""

import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
import numpy as np

# 한글 폰트 설정
plt.rcParams['font.sans-serif'] = ['AppleGothic']
plt.rcParams['axes.unicode_minus'] = False

# 현재 게이지 시스템 데이터
skills = {
    "파워스매시": {
        "cost": 400,
        "effect": "공 속도 2배 증가, 포물선 궤적",
        "cooldown": 0,
        "color": "#FF6B6B"
    },
    "대시": {
        "cost": 160,  # 기본 비용 (연속 사용 시 할인)
        "effect": "순간 이동, 연속 사용 시 50% 할인",
        "cooldown": 0,
        "color": "#4ECDC4"
    },
    "드라이브": {
        "cost": 150,
        "effect": "퍼펙트 타이밍 시 강력한 공격",
        "cooldown": 0,
        "color": "#FFD93D"
    }
}

# 게이지 충전 정보
gauge_info = {
    "최대 게이지": 500,  # 기본값 (아카데미 스킬로 확장 가능)
    "패들 히트당 충전": 80,
    "아이템 충전": 220,  # gauge_charge 아이템
    "충전가방 보너스": "벽 충돌 시 +16 (패들 충전의 20%)"
}

# 사용 시나리오 분석
scenarios = {
    "파워스매시 준비": {
        "필요 히트": 5,  # 400 / 80
        "소요 시간": "약 10-15초",
        "전략적 가치": 9
    },
    "대시 3회 연속": {
        "총 비용": 280,  # 160 + 80 + 40
        "필요 히트": 4,  # 280 / 80
        "전략적 가치": 7
    },
    "드라이브 2회": {
        "총 비용": 300,  # 150 * 2
        "필요 히트": 4,  # 300 / 80
        "전략적 가치": 8
    }
}

# 분석 시작
fig = plt.figure(figsize=(16, 10))
fig.suptitle('BossPong 게이지 시스템 밸런스 분석', fontsize=18, fontweight='bold')

# 1. 스킬별 비용 비교
ax1 = plt.subplot(2, 3, 1)
skills_names = list(skills.keys())
skills_costs = [skills[s]["cost"] for s in skills_names]
colors = [skills[s]["color"] for s in skills_names]

bars = ax1.bar(skills_names, skills_costs, color=colors, alpha=0.8)
ax1.axhline(y=gauge_info["최대 게이지"], color='red', linestyle='--', alpha=0.5, label='최대 게이지')
ax1.axhline(y=gauge_info["패들 히트당 충전"], color='green', linestyle='--', alpha=0.5, label='1회 충전량')

ax1.set_ylabel('게이지 소모량')
ax1.set_title('스킬별 게이지 비용')
ax1.legend()
ax1.grid(True, alpha=0.3, axis='y')

# 값 표시
for bar, cost in zip(bars, skills_costs):
    height = bar.get_height()
    ax1.text(bar.get_x() + bar.get_width()/2., height,
            f'{cost}', ha='center', va='bottom', fontweight='bold')

# 2. 충전 효율성 분석
ax2 = plt.subplot(2, 3, 2)
charge_sources = ['패들 히트', '아이템 사용', '충전가방(벽)']
charge_amounts = [80, 220, 16]
charge_colors = ['#95E77E', '#9B59B6', '#F39C12']

bars2 = ax2.bar(charge_sources, charge_amounts, color=charge_colors, alpha=0.8)
ax2.set_ylabel('충전량')
ax2.set_title('충전 소스별 효율성')
ax2.grid(True, alpha=0.3, axis='y')

for bar, amount in zip(bars2, charge_amounts):
    height = bar.get_height()
    ax2.text(bar.get_x() + bar.get_width()/2., height,
            f'+{amount}', ha='center', va='bottom', fontweight='bold')

# 3. 필요 히트 수 분석
ax3 = plt.subplot(2, 3, 3)
required_hits = [skills_costs[0]/80, skills_costs[1]/80, skills_costs[2]/80]
skill_names_short = ['파워스매시', '대시', '드라이브']

bars3 = ax3.barh(skill_names_short, required_hits, color=colors, alpha=0.8)
ax3.set_xlabel('필요 패들 히트 수')
ax3.set_title('스킬 사용을 위한 최소 히트')
ax3.grid(True, alpha=0.3, axis='x')

for bar, hits in zip(bars3, required_hits):
    width = bar.get_width()
    ax3.text(width, bar.get_y() + bar.get_height()/2.,
            f'{hits:.1f}회', ha='left', va='center', fontweight='bold')

# 4. 시나리오별 효율성
ax4 = plt.subplot(2, 3, 4)
scenario_names = list(scenarios.keys())
strategic_values = [scenarios[s]["전략적 가치"] for s in scenario_names]
required_hits = [scenarios[s]["필요 히트"] for s in scenario_names]

x = np.arange(len(scenario_names))
width = 0.35

bars4_1 = ax4.bar(x - width/2, strategic_values, width, label='전략적 가치', color='#3498DB', alpha=0.8)
bars4_2 = ax4.bar(x + width/2, required_hits, width, label='필요 히트', color='#E74C3C', alpha=0.8)

ax4.set_xlabel('사용 시나리오')
ax4.set_ylabel('점수')
ax4.set_title('시나리오별 비용 대비 효율')
ax4.set_xticks(x)
ax4.set_xticklabels(scenario_names, rotation=15, ha='right')
ax4.legend()
ax4.grid(True, alpha=0.3, axis='y')

# 5. 대시 연속 사용 할인
ax5 = plt.subplot(2, 3, 5)
dash_counts = [1, 2, 3, 4, 5]
dash_costs = [160, 80, 40, 20, 10]
cumulative_costs = [sum(dash_costs[:i+1]) for i in range(len(dash_costs))]

line1 = ax5.plot(dash_counts, dash_costs, 'o-', linewidth=2, markersize=8, 
                label='회당 비용', color='#4ECDC4')
line2 = ax5.plot(dash_counts, cumulative_costs, 's-', linewidth=2, markersize=8,
                label='누적 비용', color='#E74C3C')

ax5.set_xlabel('연속 대시 횟수')
ax5.set_ylabel('게이지 소모')
ax5.set_title('대시 연속 사용 할인 효과')
ax5.legend()
ax5.grid(True, alpha=0.3)

# 값 표시
for x, y in zip(dash_counts, dash_costs):
    ax5.text(x, y, f'{y}', ha='center', va='bottom')
for x, y in zip(dash_counts, cumulative_costs):
    ax5.text(x, y, f'{y}', ha='center', va='top')

# 6. 밸런스 평가 및 권장사항
ax6 = plt.subplot(2, 3, 6)
ax6.axis('off')

balance_text = """
【 현재 밸런스 평가 】

✅ 적절한 부분:
• 대시 연속 할인 시스템 (전략적 깊이↑)
• 드라이브 적정 비용 (150)
• 기본 충전량 (80) 적절

⚠️ 조정 검토 필요:
• 파워스매시 비용 과도 (400)
  → 권장: 300-350으로 하향
• 대시 기본 비용 약간 높음
  → 권장: 140으로 하향

💡 제안사항:
1. 파워스매시: 400 → 320
2. 대시 기본: 160 → 140
3. 드라이브: 150 (유지)

【 예상 효과 】
• 파워스매시 사용 빈도 20% 증가
• 전투 템포 15% 상승
• 전략적 선택 다양화
"""

ax6.text(0.05, 0.95, balance_text, transform=ax6.transAxes,
        fontsize=11, verticalalignment='top',
        bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.3))

plt.tight_layout()
plt.savefig('gauge_balance_analysis.png', dpi=300, bbox_inches='tight')
print("게이지 밸런스 분석 완료: gauge_balance_analysis.png")

# 상세 분석 결과 출력
print("\n" + "="*60)
print("【 게이지 시스템 밸런스 상세 분석 】")
print("="*60)

print("\n📊 현재 설정값:")
print(f"• 파워스매시: {skills['파워스매시']['cost']} (필요 히트: {skills['파워스매시']['cost']/80:.1f}회)")
print(f"• 대시: {skills['대시']['cost']} (연속 할인 적용)")
print(f"• 드라이브: {skills['드라이브']['cost']} (필요 히트: {skills['드라이브']['cost']/80:.1f}회)")

print("\n⚖️ 밸런스 평가:")
print("• 파워스매시가 너무 비싸서 사용 빈도가 낮을 가능성")
print("• 대시는 연속 할인으로 적절하나 초기 비용이 약간 높음")
print("• 드라이브는 위험/보상 비율이 적절함")

print("\n✨ 권장 조정안:")
print("• 파워스매시: 400 → 320 (20% 감소)")
print("• 대시: 160 → 140 (12.5% 감소)")
print("• 드라이브: 150 (유지)")

# plt.show() 제거 - GUI 없이 실행