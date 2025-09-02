import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
import numpy as np
from datetime import datetime
import json

# 한글 폰트 설정
plt.rcParams['font.sans-serif'] = ['AppleGothic']
plt.rcParams['axes.unicode_minus'] = False

# 리그별 난이도 데이터
league_data = {
    "주니어리그": {
        "boss_multiplier": 1.00,  # 보스 능력치 배수
        "ai_fail_rate": 0.25,     # AI 실수율
        "target_win_rate": 0.80,  # 목표 승률
        "speed_level": 1,          # 속도 레벨 (1-4)
        "reaction_time": 4,        # 반응시간 여유도 (1-4)
        "strategy_required": 1,    # 전략 필요도 (1-4)
        "color": "#64FF64",
        "icon": "🌱"
    },
    "프로리그": {
        "boss_multiplier": 1.05,
        "ai_fail_rate": 0.15,
        "target_win_rate": 0.60,
        "speed_level": 2,
        "reaction_time": 3,
        "strategy_required": 2,
        "color": "#FFC864",
        "icon": "⚡"
    },
    "챔피언리그": {
        "boss_multiplier": 1.10,
        "ai_fail_rate": 0.08,
        "target_win_rate": 0.35,
        "speed_level": 3,
        "reaction_time": 2,
        "strategy_required": 3,
        "color": "#FF96FF",
        "icon": "💎"
    },
    "신화리그": {
        "boss_multiplier": 1.15,
        "ai_fail_rate": 0.03,
        "target_win_rate": 0.15,
        "speed_level": 4,
        "reaction_time": 1,
        "strategy_required": 4,
        "color": "#FFD700",
        "icon": "👑"
    }
}

# 스테이지별 보스 기본 난이도 (1-6 스테이지)
stage_base_difficulty = {
    1: {"speed": 10.0, "predict": 0.70},
    2: {"speed": 11.5, "predict": 0.75},
    3: {"speed": 13.0, "predict": 0.80},
    4: {"speed": 14.5, "predict": 0.85},
    5: {"speed": 16.0, "predict": 0.90},
    6: {"speed": 18.0, "predict": 0.95}
}

# 분석 시작
fig = plt.figure(figsize=(18, 12))
fig.suptitle('BossPong 리그별 난이도 종합 분석', fontsize=20, fontweight='bold')

# 1. 리그별 주요 지표 비교
ax1 = plt.subplot(2, 3, 1)
leagues = list(league_data.keys())
boss_multipliers = [league_data[l]["boss_multiplier"] for l in leagues]
ai_fail_rates = [league_data[l]["ai_fail_rate"] for l in leagues]
target_win_rates = [league_data[l]["target_win_rate"] for l in leagues]

x = np.arange(len(leagues))
width = 0.25

bars1 = ax1.bar(x - width, boss_multipliers, width, label='보스 능력치 배수', color='#FF6B6B')
bars2 = ax1.bar(x, ai_fail_rates, width, label='AI 실수율', color='#4ECDC4')
bars3 = ax1.bar(x + width, target_win_rates, width, label='목표 승률', color='#95E77E')

ax1.set_xlabel('리그')
ax1.set_ylabel('비율')
ax1.set_title('리그별 핵심 난이도 지표')
ax1.set_xticks(x)
ax1.set_xticklabels(leagues, rotation=15, ha='right')
ax1.legend()
ax1.grid(True, alpha=0.3)

# 값 표시
for bars in [bars1, bars2, bars3]:
    for bar in bars:
        height = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.2f}', ha='center', va='bottom', fontsize=8)

# 2. 난이도 곡선 (Progressive Difficulty)
ax2 = plt.subplot(2, 3, 2)
x_curve = np.arange(len(leagues))

# 정규화된 난이도 점수 계산
difficulty_scores = []
for league in leagues:
    data = league_data[league]
    # 난이도 점수 = (보스배수 * 2) + ((1-AI실수율) * 3) + ((1-목표승률) * 1)
    score = (data["boss_multiplier"] * 2) + ((1 - data["ai_fail_rate"]) * 3) + ((1 - data["target_win_rate"]) * 1)
    difficulty_scores.append(score)

# 난이도 곡선 그리기
ax2.plot(x_curve, difficulty_scores, 'o-', linewidth=3, markersize=10, color='#FF6B6B')
ax2.fill_between(x_curve, 0, difficulty_scores, alpha=0.3, color='#FF6B6B')

# 이상적인 선형 증가선
ideal_line = np.linspace(difficulty_scores[0], difficulty_scores[-1], len(leagues))
ax2.plot(x_curve, ideal_line, '--', linewidth=2, alpha=0.5, color='green', label='이상적 난이도 증가')

ax2.set_xlabel('리그 진행도')
ax2.set_ylabel('종합 난이도 점수')
ax2.set_title('난이도 증가 곡선 분석')
ax2.set_xticks(x_curve)
ax2.set_xticklabels(leagues, rotation=15, ha='right')
ax2.legend()
ax2.grid(True, alpha=0.3)

# 각 포인트에 값 표시
for i, score in enumerate(difficulty_scores):
    ax2.text(i, score + 0.05, f'{score:.2f}', ha='center', fontweight='bold')

# 3. 레이더 차트 - 리그별 특성
ax3 = plt.subplot(2, 3, 3, projection='polar')

categories = ['속도', '반응시간\n(역)', '전략성', 'AI 정확도', '보스 강화']
num_vars = len(categories)
angles = np.linspace(0, 2 * np.pi, num_vars, endpoint=False).tolist()
angles += angles[:1]

for league in leagues:
    data = league_data[league]
    values = [
        data["speed_level"] / 4,
        (5 - data["reaction_time"]) / 4,  # 반응시간은 역으로
        data["strategy_required"] / 4,
        1 - data["ai_fail_rate"],
        (data["boss_multiplier"] - 1) * 5  # 스케일 조정
    ]
    values += values[:1]
    
    ax3.plot(angles, values, 'o-', linewidth=2, label=league, color=data["color"])
    ax3.fill(angles, values, alpha=0.15, color=data["color"])

ax3.set_xticks(angles[:-1])
ax3.set_xticklabels(categories)
ax3.set_ylim(0, 1)
ax3.set_title('리그별 특성 비교 (레이더)')
ax3.legend(loc='upper right', bbox_to_anchor=(1.3, 1.1))
ax3.grid(True)

# 4. 스테이지별 × 리그별 난이도 히트맵
ax4 = plt.subplot(2, 3, 4)

stages = list(range(1, 7))
heatmap_data = []

for league in leagues:
    row = []
    for stage in stages:
        base_speed = stage_base_difficulty[stage]["speed"]
        multiplier = league_data[league]["boss_multiplier"]
        final_speed = base_speed * multiplier
        row.append(final_speed)
    heatmap_data.append(row)

im = ax4.imshow(heatmap_data, cmap='YlOrRd', aspect='auto')
ax4.set_xticks(np.arange(len(stages)))
ax4.set_yticks(np.arange(len(leagues)))
ax4.set_xticklabels([f'Stage {s}' for s in stages])
ax4.set_yticklabels(leagues)
ax4.set_title('스테이지별 × 리그별 보스 속도 매트릭스')

# 히트맵에 값 표시
for i in range(len(leagues)):
    for j in range(len(stages)):
        text = ax4.text(j, i, f'{heatmap_data[i][j]:.1f}',
                       ha="center", va="center", color="white" if heatmap_data[i][j] > 14 else "black")

plt.colorbar(im, ax=ax4, label='보스 속도')

# 5. 승률 예측 그래프
ax5 = plt.subplot(2, 3, 5)

# 가상의 플레이어 실력 레벨별 승률
skill_levels = ['초보', '중수', '고수', '최고수']
skill_multipliers = [0.6, 0.8, 1.0, 1.2]

bar_width = 0.2
x_pos = np.arange(len(leagues))

for i, (skill, mult) in enumerate(zip(skill_levels, skill_multipliers)):
    win_rates = [min(1.0, league_data[l]["target_win_rate"] * mult) for l in leagues]
    offset = (i - 1.5) * bar_width
    bars = ax5.bar(x_pos + offset, win_rates, bar_width, label=skill)
    
    # 값 표시
    for bar, rate in zip(bars, win_rates):
        height = bar.get_height()
        ax5.text(bar.get_x() + bar.get_width()/2., height,
                f'{rate:.0%}', ha='center', va='bottom', fontsize=7)

ax5.set_xlabel('리그')
ax5.set_ylabel('예상 승률')
ax5.set_title('플레이어 실력별 예상 승률')
ax5.set_xticks(x_pos)
ax5.set_xticklabels(leagues, rotation=15, ha='right')
ax5.legend()
ax5.grid(True, alpha=0.3, axis='y')
ax5.set_ylim(0, 1.1)

# 6. 난이도 밸런스 평가
ax6 = plt.subplot(2, 3, 6)

# 난이도 증가율 계산
difficulty_increases = []
for i in range(1, len(difficulty_scores)):
    increase = (difficulty_scores[i] - difficulty_scores[i-1]) / difficulty_scores[i-1] * 100
    difficulty_increases.append(increase)

transitions = [f'{leagues[i]} → {leagues[i+1]}' for i in range(len(leagues)-1)]

bars = ax6.bar(transitions, difficulty_increases, color=['#4ECDC4', '#FFD93D', '#FF6B6B'])
ax6.axhline(y=20, color='green', linestyle='--', alpha=0.5, label='이상적 증가율 (20%)')
ax6.set_ylabel('난이도 증가율 (%)')
ax6.set_title('리그 전환 시 난이도 증가율')
ax6.set_xticklabels(transitions, rotation=30, ha='right')
ax6.legend()
ax6.grid(True, alpha=0.3, axis='y')

# 값 표시
for bar, rate in zip(bars, difficulty_increases):
    height = bar.get_height()
    ax6.text(bar.get_x() + bar.get_width()/2., height,
            f'{rate:.1f}%', ha='center', va='bottom')

plt.tight_layout()

# 저장
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
filename = f'league_difficulty_analysis_{timestamp}.png'
plt.savefig(filename, dpi=300, bbox_inches='tight')
print(f"✅ 난이도 분석 그래프 저장: {filename}")

# 분석 결과 JSON 저장
analysis_results = {
    "timestamp": timestamp,
    "league_data": league_data,
    "difficulty_scores": {leagues[i]: score for i, score in enumerate(difficulty_scores)},
    "difficulty_increases": {transitions[i]: increase for i, increase in enumerate(difficulty_increases)},
    "balance_evaluation": {
        "average_increase": np.mean(difficulty_increases),
        "std_increase": np.std(difficulty_increases),
        "is_balanced": all(10 <= inc <= 30 for inc in difficulty_increases),
        "recommendation": "난이도 증가율이 균형적입니다." if all(10 <= inc <= 30 for inc in difficulty_increases) else "일부 구간 조정 필요"
    }
}

json_filename = f'league_difficulty_analysis_{timestamp}.json'
with open(json_filename, 'w', encoding='utf-8') as f:
    json.dump(analysis_results, f, ensure_ascii=False, indent=2)
print(f"✅ 분석 데이터 저장: {json_filename}")

# plt.show() 제거 - GUI 없이 실행