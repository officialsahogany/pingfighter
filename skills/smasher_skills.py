"""
스매셔 캐릭터 전용 스킬 시스템
"""

import pygame
import json
import os

class SmasherSkillSystem:
    def __init__(self):
        # 스킬 리스트 - 스크린샷과 동일하게 구성
        self.skills = [
            # Row 0 - 시작 스킬
            {
                "id": "heavy_impact",
                "name": "중격타",
                "description": "기본 공격력이 10% 증가합니다.",
                "max_level": 5,
                "current_level": 0,
                "cost": 1,
                "effect_per_level": 0.1,
                "icon_color": (255, 100, 100),
                "row": 0,
                "col": 0,
                "requires": None,
                "requires_or": None
            },
            
            # Row 1 - 두 번째 줄
            {
                "id": "speed_charge", 
                "name": "스피드",
                "description": "차지 속도가 15% 증가합니다.",
                "max_level": 3,
                "current_level": 0,
                "cost": 1,
                "effect_per_level": 0.15,
                "icon_color": (100, 255, 100),
                "row": 1,
                "col": -1,
                "requires": "heavy_impact",
                "requires_or": None
            },
            {
                "id": "burst_wave",
                "name": "버스트웨이브",
                "description": "공격 시 폭발 범위가 생성됩니다.",
                "max_level": 3,
                "current_level": 0,
                "cost": 1,
                "effect_per_level": 50,
                "icon_color": (255, 200, 100),
                "row": 1,
                "col": 1,
                "requires": "heavy_impact",
                "requires_or": None
            },
            
            # Row 2 - 세 번째 줄
            {
                "id": "power_break",
                "name": "파워브레이크",
                "description": "적 방어력을 20% 무시합니다.",
                "max_level": 3,
                "current_level": 0,
                "cost": 2,
                "effect_per_level": 0.2,
                "icon_color": (200, 100, 255),
                "row": 2,
                "col": -1,
                "requires": "speed_charge",
                "requires_or": None
            },
            {
                "id": "dual_smash",
                "name": "듀얼스매시",
                "description": "연속 공격 확률이 10% 증가합니다.",
                "max_level": 5,
                "current_level": 0,
                "cost": 1,
                "effect_per_level": 0.1,
                "icon_color": (100, 200, 255),
                "row": 2,
                "col": 0,
                "requires": None,
                "requires_or": ["speed_charge", "burst_wave"]
            },
            {
                "id": "impact_zone",
                "name": "충격지대",
                "description": "피격 영역이 확대됩니다.",
                "max_level": 3,
                "current_level": 0,
                "cost": 2,
                "effect_per_level": 1.2,
                "icon_color": (255, 150, 150),
                "row": 2,
                "col": 1,
                "requires": "burst_wave",
                "requires_or": None
            },
            
            # Row 3 - 네 번째 줄
            {
                "id": "ultra_charge",
                "name": "울트라차지",
                "description": "궁극기 게이지 충전 속도가 30% 증가합니다.",
                "max_level": 3,
                "current_level": 0,
                "cost": 2,
                "effect_per_level": 0.3,
                "icon_color": (255, 255, 100),
                "row": 3,
                "col": -1,
                "requires": "power_break",
                "requires_or": None
            },
            {
                "id": "berserker",
                "name": "광폭화",
                "description": "체력이 낮을수록 공격력이 증가합니다.",
                "max_level": 3,
                "current_level": 0,
                "cost": 3,
                "effect_per_level": 0.25,
                "icon_color": (255, 50, 50),
                "row": 3,
                "col": 0,
                "requires": "dual_smash",
                "requires_or": None
            },
            {
                "id": "chain_impact",
                "name": "체인임팩트",
                "description": "타격 시 추가 연쇄 공격이 발생합니다.",
                "max_level": 3,
                "current_level": 0,
                "cost": 2,
                "effect_per_level": 0.15,
                "icon_color": (150, 100, 255),
                "row": 3,
                "col": 1,
                "requires": "impact_zone",
                "requires_or": None
            },
            
            # Row 4 - 마지막 줄 (궁극 스킬들)
            {
                "id": "final_smash",
                "name": "파이널스매시",
                "description": "모든 스매시 공격이 치명타가 됩니다.",
                "max_level": 1,
                "current_level": 0,
                "cost": 5,
                "effect_per_level": 1.0,
                "icon_color": (255, 215, 0),
                "row": 4,
                "col": -1,
                "requires": None,
                "requires_or": ["ultra_charge", "berserker"]
            },
            {
                "id": "omega_burst",
                "name": "오메가버스트",
                "description": "최종 폭발로 전체 화면을 공격합니다.",
                "max_level": 1,
                "current_level": 0,
                "cost": 5,
                "effect_per_level": 1.0,
                "icon_color": (255, 0, 255),
                "row": 4,
                "col": 0,
                "requires": "berserker",
                "requires_or": None
            },
            {
                "id": "devastator",
                "name": "파괴자",
                "description": "모든 스매시 스킬의 효과가 50% 증가합니다.",
                "max_level": 1,
                "current_level": 0,
                "cost": 5,
                "effect_per_level": 0.5,
                "icon_color": (255, 100, 0),
                "row": 4,
                "col": 1,
                "requires": None,
                "requires_or": ["berserker", "chain_impact"]
            }
        ]
        
        # 스킬 딕셔너리로도 접근 가능하게
        self.skills_dict = {skill["id"]: skill for skill in self.skills}
        
        self.load_skills()
    
    def save_skills(self):
        """스킬 데이터 저장"""
        save_data = {}
        for skill in self.skills:
            save_data[skill["id"]] = skill["current_level"]
        
        # academy_save.json과 통합
        save_path = "academy_save.json"
        try:
            if os.path.exists(save_path):
                with open(save_path, 'r') as f:
                    data = json.load(f)
            else:
                data = {}
            
            data["smasher_skills"] = save_data
            
            with open(save_path, 'w') as f:
                json.dump(data, f)
        except:
            pass
    
    def load_skills(self):
        """스킬 데이터 로드"""
        save_path = "academy_save.json"
        try:
            if os.path.exists(save_path):
                with open(save_path, 'r') as f:
                    data = json.load(f)
                    if "smasher_skills" in data:
                        for skill_id, level in data["smasher_skills"].items():
                            if skill_id in self.skills_dict:
                                self.skills_dict[skill_id]["current_level"] = level
        except:
            pass
    
    def can_upgrade(self, skill_id, skill_points):
        """스킬 업그레이드 가능 여부 확인"""
        if skill_id not in self.skills_dict:
            return False
        
        skill = self.skills_dict[skill_id]
        
        # 최대 레벨 확인
        if skill["current_level"] >= skill["max_level"]:
            return False
        
        # 스킬 포인트 확인
        if skill_points < skill["cost"]:
            return False
        
        # 선행 스킬 확인
        if "requires" in skill and skill["requires"]:
            prereq = skill["requires"]
            if self.skills_dict[prereq]["current_level"] == 0:
                return False
        
        # OR 조건 선행 스킬 확인
        if "requires_or" in skill and skill["requires_or"]:
            has_prereq = False
            for prereq in skill["requires_or"]:
                if self.skills_dict[prereq]["current_level"] > 0:
                    has_prereq = True
                    break
            if not has_prereq:
                return False
        
        return True
    
    def upgrade_skill(self, skill_id):
        """스킬 업그레이드"""
        if skill_id in self.skills_dict:
            skill = self.skills_dict[skill_id]
            if skill["current_level"] < skill["max_level"]:
                skill["current_level"] += 1
                self.save_skills()
                return skill["cost"]
        return 0
    
    def get_skill_effect(self, skill_id):
        """스킬 효과 값 반환"""
        if skill_id in self.skills_dict:
            skill = self.skills_dict[skill_id]
            return skill["current_level"] * skill["effect_per_level"]
        return 0
    
    def get_power_multiplier(self):
        """파워 스매시 배율 반환"""
        return 1 + self.get_skill_effect("smash_power")
    
    def get_charge_speed_multiplier(self):
        """차지 속도 배율 반환"""
        return 1 + self.get_skill_effect("smash_charge")
    
    def get_critical_chance(self):
        """치명타 확률 반환"""
        return self.get_skill_effect("smash_critical")
    
    def get_burst_radius(self):
        """폭발 범위 반환"""
        return self.get_skill_effect("smash_burst")
    
    def get_double_hit_chance(self):
        """더블 히트 확률 반환 - 삭제됨"""
        return 0  # 스킬 구조 변경으로 사용 안함
    
    def get_recovery_multiplier(self):
        """회복 시간 배율 반환"""
        return 1 - self.get_skill_effect("smash_speed")
    
    def get_mega_smash_chance(self):
        """메가 스매시 확률 반환"""
        return self.get_skill_effect("mega_smash")
    
    def get_shield_reduction(self):
        """실드 피해 감소율 반환"""
        return self.get_skill_effect("smash_shield")
    
    def draw_skill_tab(self, screen, x, y, width, height, font, skill_points, mouse_pos, show_flash=False):
        """스매셔 스킬탭 그리기 - 대쉬 스킬탭과 동일한 트리 구조"""
        # 스킬 아이콘 크기와 간격 (대쉬와 동일)
        skill_size = 60
        row_spacing = 140
        col_spacing = 200
        available_width = width - 100
        start_x = x + (available_width - col_spacing) // 2 + 50
        start_y = y + 50
        
        # 스킬 연결선 그리기
        for skill in self.skills:
            skill_x = start_x + skill["col"] * col_spacing
            skill_y = start_y + skill["row"] * row_spacing
            
            # 선행 스킬 연결선
            if skill.get("requires"):
                prereq = next((s for s in self.skills if s["id"] == skill["requires"]), None)
                if prereq:
                    prereq_x = start_x + prereq["col"] * col_spacing
                    prereq_y = start_y + prereq["row"] * row_spacing
                    
                    # 연결선 색상
                    if prereq["current_level"] > 0:
                        line_color = (100, 150, 100)
                    else:
                        line_color = (50, 50, 50)
                    
                    # 화살표 그리기
                    self.draw_arrow(screen, 
                                  (prereq_x + skill_size // 2, prereq_y + skill_size // 2),
                                  (skill_x + skill_size // 2, skill_y + skill_size // 2),
                                  line_color, 2)
            
            # OR 조건 연결선
            if skill.get("requires_or"):
                for prereq_id in skill["requires_or"]:
                    prereq = next((s for s in self.skills if s["id"] == prereq_id), None)
                    if prereq:
                        prereq_x = start_x + prereq["col"] * col_spacing
                        prereq_y = start_y + prereq["row"] * row_spacing
                        
                        # 점선으로 표시
                        if prereq["current_level"] > 0:
                            line_color = (150, 150, 100)
                        else:
                            line_color = (60, 60, 60)
                        
                        # 점선 화살표
                        self.draw_dotted_arrow(screen,
                                             (prereq_x + skill_size // 2, prereq_y + skill_size // 2),
                                             (skill_x + skill_size // 2, skill_y + skill_size // 2),
                                             line_color, 2)
        
        # 스킬 아이콘 그리기
        for skill in self.skills:
            skill_x = start_x + skill["col"] * col_spacing
            skill_y = start_y + skill["row"] * row_spacing
            
            # 스킬 아이콘 배경
            if skill["current_level"] > 0:
                bg_color = (60, 60, 70)
            else:
                bg_color = (40, 40, 50)
            pygame.draw.rect(screen, bg_color, (skill_x, skill_y, skill_size, skill_size))
            
            # 업그레이드 가능 여부에 따른 테두리
            can_upgrade = self.can_upgrade(skill["id"], skill_points)
            if can_upgrade and show_flash:
                border_color = (255, 255, 100)
                pygame.draw.rect(screen, border_color, (skill_x-2, skill_y-2, skill_size+4, skill_size+4), 3)
            elif skill["current_level"] > 0:
                border_color = skill["icon_color"]
                pygame.draw.rect(screen, border_color, (skill_x, skill_y, skill_size, skill_size), 2)
            else:
                border_color = (80, 80, 80)
                pygame.draw.rect(screen, border_color, (skill_x, skill_y, skill_size, skill_size), 1)
            
            # 스킬 아이콘
            self.draw_skill_icon(screen, skill["id"], skill_x + skill_size // 2, skill_y + skill_size // 2,
                               skill_size // 3, skill["current_level"] > 0)
            
            # 스킬 이름
            name_surf = font.render(skill["name"], True, (255, 255, 255))
            name_rect = name_surf.get_rect(center=(skill_x + skill_size // 2, skill_y + skill_size + 15))
            screen.blit(name_surf, name_rect)
            
            # 레벨 표시
            level_text = f"{skill['current_level']}/{skill['max_level']}"
            level_surf = font.render(level_text, True, (255, 255, 255))
            screen.blit(level_surf, (skill_x + 5, skill_y + skill_size - 20))
            
            # 비용 표시 (잠금 상태일 때만)
            if skill["current_level"] == 0:
                cost_text = f"{skill['cost']}TP"
                cost_surf = font.render(cost_text, True, (255, 200, 100))
                screen.blit(cost_surf, (skill_x + skill_size - 35, skill_y + 5))
            
            # 마우스 호버 시 설명 표시
            if skill_x <= mouse_pos[0] <= skill_x + skill_size and skill_y <= mouse_pos[1] <= skill_y + skill_size:
                self.draw_skill_tooltip(screen, font, skill, skill_x + skill_size + 10, skill_y)
        
        return None
    
    def draw_arrow(self, screen, start, end, color, width):
        """화살표 그리기"""
        import math
        pygame.draw.line(screen, color, start, end, width)
        
        # 화살표 머리 그리기
        angle = math.atan2(end[1] - start[1], end[0] - start[0])
        head_len = 10
        ax1 = end[0] - head_len * math.cos(angle - math.pi / 6)
        ay1 = end[1] - head_len * math.sin(angle - math.pi / 6)
        ax2 = end[0] - head_len * math.cos(angle + math.pi / 6)
        ay2 = end[1] - head_len * math.sin(angle + math.pi / 6)
        pygame.draw.line(screen, color, end, (int(ax1), int(ay1)), width)
        pygame.draw.line(screen, color, end, (int(ax2), int(ay2)), width)
    
    def draw_dotted_arrow(self, screen, start, end, color, width):
        """점선 화살표 그리기"""
        import math
        # 점선 그리기
        distance = math.sqrt((end[0] - start[0])**2 + (end[1] - start[1])**2)
        segments = int(distance // 10)
        for i in range(0, segments, 2):
            t1 = i / segments
            t2 = min((i + 1) / segments, 1)
            x1 = start[0] + (end[0] - start[0]) * t1
            y1 = start[1] + (end[1] - start[1]) * t1
            x2 = start[0] + (end[0] - start[0]) * t2
            y2 = start[1] + (end[1] - start[1]) * t2
            pygame.draw.line(screen, color, (x1, y1), (x2, y2), width)
        
        # 화살표 머리 그리기
        angle = math.atan2(end[1] - start[1], end[0] - start[0])
        head_len = 8
        ax1 = end[0] - head_len * math.cos(angle - math.pi / 6)
        ay1 = end[1] - head_len * math.sin(angle - math.pi / 6)
        ax2 = end[0] - head_len * math.cos(angle + math.pi / 6)
        ay2 = end[1] - head_len * math.sin(angle + math.pi / 6)
        pygame.draw.line(screen, color, end, (int(ax1), int(ay1)), width)
        pygame.draw.line(screen, color, end, (int(ax2), int(ay2)), width)
    
    def draw_skill_icon(self, screen, skill_id, x, y, size, active):
        """스킬 아이콘 그리기 - 아이콘 내부는 비워둠"""
        skill = self.skills_dict.get(skill_id)
        if not skill:
            return
        # 아이콘 내부를 비워두고 아무것도 그리지 않음
        pass
    
    def draw_skill_tooltip(self, screen, font, skill, x, y):
        """스킬 툴팁 그리기"""
        # 배경
        tooltip_width = 250
        tooltip_height = 120
        pygame.draw.rect(screen, (20, 20, 30), (x, y, tooltip_width, tooltip_height))
        pygame.draw.rect(screen, (100, 100, 120), (x, y, tooltip_width, tooltip_height), 1)
        
        # 스킬 이름
        name_surf = font.render(skill["name"], True, skill["icon_color"])
        screen.blit(name_surf, (x + 10, y + 10))
        
        # 스킬 설명
        desc_lines = []
        words = skill["description"].split()
        current_line = ""
        for word in words:
            test_line = current_line + " " + word if current_line else word
            if font.size(test_line)[0] <= tooltip_width - 20:
                current_line = test_line
            else:
                desc_lines.append(current_line)
                current_line = word
        if current_line:
            desc_lines.append(current_line)
        
        for i, line in enumerate(desc_lines[:3]):  # 최대 3줄
            desc_surf = font.render(line, True, (200, 200, 200))
            screen.blit(desc_surf, (x + 10, y + 35 + i * 20))
        
        # 현재 효과
        if skill["current_level"] > 0:
            effect_value = skill["current_level"] * skill["effect_per_level"]
            # 퍼센트로 표시할 스킬들
            percentage_skills = ["heavy_impact", "speed_charge", "power_break", "dual_smash", 
                               "ultra_charge", "berserker", "chain_impact", "final_smash", "devastator"]
            if skill["id"] in percentage_skills:
                effect_text = f"현재 효과: {effect_value*100:.0f}%"
            else:
                effect_text = f"현재 효과: {effect_value:.0f}"
            effect_surf = font.render(effect_text, True, (100, 255, 100))
            screen.blit(effect_surf, (x + 10, y + tooltip_height - 25))
        
        # 비용
        cost_text = f"비용: {skill['cost']} SP"
        cost_surf = font.render(cost_text, True, (255, 200, 100))
        screen.blit(cost_surf, (x + tooltip_width - 80, y + tooltip_height - 25))
    
    def handle_click(self, mouse_pos, x, y, skill_points):
        """스킬 아이콘 클릭 처리"""
        skill_size = 60
        row_spacing = 140
        col_spacing = 200
        available_width = 500  # width를 직접 받아야 하는데 임시로 고정
        start_x = x + (available_width - col_spacing) // 2 + 50
        start_y = y + 50
        
        for skill in self.skills:
            skill_x = start_x + skill["col"] * col_spacing
            skill_y = start_y + skill["row"] * row_spacing
            
            if skill_x <= mouse_pos[0] <= skill_x + skill_size and skill_y <= mouse_pos[1] <= skill_y + skill_size:
                if self.can_upgrade(skill["id"], skill_points):
                    return skill["id"]
        
        return None

# 싱글톤 인스턴스
smasher_skills_instance = None

def get_smasher_skills():
    """스매셔 스킬 시스템 인스턴스 반환"""
    global smasher_skills_instance
    if smasher_skills_instance is None:
        smasher_skills_instance = SmasherSkillSystem()
    return smasher_skills_instance

def reset_smasher_skills():
    """스매셔 스킬 초기화 (새 게임 시작 시)"""
    global smasher_skills_instance
    smasher_skills_instance = SmasherSkillSystem()
    # 모든 스킬 레벨을 0으로 초기화
    for skill in smasher_skills_instance.skills:
        skill["current_level"] = 0
    smasher_skills_instance.save_skills()