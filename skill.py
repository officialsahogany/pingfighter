import pygame
import math

# 스킬 트리 관련 상수
SKILL_TREE_WIDTH = 800
SKILL_TREE_HEIGHT = 600
NODE_SIZE = 60
NODE_SPACING = 80
ARROW_THICKNESS = 3

# 색상 정의
SKILL_TREE_BG = (20, 20, 30)
NODE_BORDER = (139, 69, 19)  # 갈색 테두리
NODE_FILL = (40, 40, 50)     # 어두운 회색 배경
NODE_AVAILABLE = (100, 100, 150)  # 사용 가능한 노드
NODE_LOCKED = (60, 60, 70)   # 잠긴 노드
NODE_MAXED = (255, 215, 0)   # 최대 레벨 노드 (금색)
ARROW_COLOR = (255, 255, 255)  # 화살표 색상
TEXT_COLOR = (255, 255, 255)   # 텍스트 색상

# 스킬 트리 정의
skill_trees = {
    "paddle": {
        "name": "패들 스킬",
        "description": "패들 관련 능력 강화",
        "skills": {
            "paddle_size": {
                "name": "패들 크기 증가",
                "description": "패들 사이즈 2% 증가",
                "max_level": 10,
                "current_level": 0,
                "effect": "paddle_size_boost",
                "prerequisites": [],
                "position": (200, 100),
                "icon": "📏"
            },
            "paddle_speed": {
                "name": "패들 속도 증가", 
                "description": "최대 이동속도 1 증가",
                "max_level": 5,
                "current_level": 0,
                "effect": "paddle_speed_boost",
                "prerequisites": ["paddle_size"],
                "position": (200, 200),
                "icon": "⚡"
            },
            "gauge_boost": {
                "name": "게이지 충전 강화",
                "description": "패들이 공에 닿을 때 차는 게이지 +5 증가",
                "max_level": 8,
                "current_level": 0,
                "effect": "gauge_boost",
                "prerequisites": ["paddle_speed"],
                "position": (200, 300),
                "icon": "🔋"
            }
        }
    },
    "dash": {
        "name": "대쉬 스킬",
        "description": "대쉬 관련 능력 강화", 
        "skills": {
            "dash_distance": {
                "name": "대쉬 거리 증가",
                "description": "대쉬 거리 3% 증가",
                "max_level": 10,
                "current_level": 0,
                "effect": "dash_distance_boost",
                "prerequisites": [],
                "position": (400, 100),
                "icon": "🏃"
            },
            "dash_cooldown": {
                "name": "대쉬 쿨타임 감소",
                "description": "대쉬 사용 후 쿨타임 0.2초 감소",
                "max_level": 5,
                "current_level": 0,
                "effect": "dash_cooldown_reduction",
                "prerequisites": ["dash_distance"],
                "position": (400, 200),
                "icon": "⏱️"
            },
            "dash_cost": {
                "name": "대쉬 게이지 효율",
                "description": "대쉬 게이지 소모량 -10 감소",
                "max_level": 8,
                "current_level": 0,
                "effect": "dash_cost_reduction",
                "prerequisites": ["dash_cooldown"],
                "position": (400, 300),
                "icon": "💎"
            }
        }
    },
    "item": {
        "name": "아이템 스킬",
        "description": "아이템 관련 능력 강화",
        "skills": {
            "item_spawn": {
                "name": "아이템 스폰 증가",
                "description": "아이템 스폰확률 +10% 증가",
                "max_level": 5,
                "current_level": 0,
                "effect": "item_spawn_boost",
                "prerequisites": [],
                "position": (600, 100),
                "icon": "🎁"
            }
        }
    }
}

def can_upgrade_skill(tree_name, skill_name):
    """스킬 업그레이드 가능 여부 확인"""
    skill = skill_trees[tree_name]["skills"][skill_name]
    
    # 최대 레벨 도달
    if skill["current_level"] >= skill["max_level"]:
        return False, "최대 레벨 도달"
    
    # 선행 스킬 확인
    for prereq in skill["prerequisites"]:
        prereq_tree = None
        prereq_skill = None
        
        # 선행 스킬이 어느 트리에 있는지 찾기
        for tree_key, tree_data in skill_trees.items():
            if prereq in tree_data["skills"]:
                prereq_tree = tree_key
                prereq_skill = tree_data["skills"][prereq]
                break
        
        if prereq_skill and prereq_skill["current_level"] == 0:
            return False, f"선행 스킬 필요: {prereq_skill['name']}"
    
    return True, "업그레이드 가능"

def upgrade_skill(tree_name, skill_name):
    """스킬 업그레이드"""
    can_upgrade, message = can_upgrade_skill(tree_name, skill_name)
    if not can_upgrade:
        return False, message
    
    skill = skill_trees[tree_name]["skills"][skill_name]
    skill["current_level"] += 1
    
    return True, f"{skill['name']} 레벨 {skill['current_level']}로 업그레이드!"

def get_skill_effect_value(effect_name):
    """스킬 효과 값 반환"""
    total_value = 0
    
    for tree_name, tree_data in skill_trees.items():
        for skill_name, skill_data in tree_data["skills"].items():
            if skill_data["effect"] == effect_name:
                total_value += skill_data["current_level"]
    
    return total_value

def get_skill_effects():
    """모든 스킬 효과 반환"""
    effects = {}
    for tree_name, tree_data in skill_trees.items():
        for skill_name, skill_data in tree_data["skills"].items():
            effect_name = skill_data["effect"]
            if effect_name not in effects:
                effects[effect_name] = 0
            effects[effect_name] += skill_data["current_level"]
    return effects

def draw_skill_tree(screen, selected_tree="paddle"):
    """스킬 트리 그리기"""
    # 배경 그리기
    screen.fill(SKILL_TREE_BG)
    
    # 트리 제목 그리기
    font_large = pygame.font.Font("NanumSquareB.ttf", 24)
    font_medium = pygame.font.Font("NanumSquareB.ttf", 18)
    font_small = pygame.font.Font("NanumSquareB.ttf", 14)
    
    # 선택된 트리 정보
    tree_data = skill_trees[selected_tree]
    title_text = font_large.render(tree_data["name"], True, TEXT_COLOR)
    desc_text = font_medium.render(tree_data["description"], True, (200, 200, 200))
    screen.blit(title_text, (20, 20))
    screen.blit(desc_text, (20, 50))
    
    # 화살표 그리기
    for skill_name, skill_data in tree_data["skills"].items():
        for prereq in skill_data["prerequisites"]:
            if prereq in tree_data["skills"]:
                prereq_pos = tree_data["skills"][prereq]["position"]
                current_pos = skill_data["position"]
                
                # 화살표 그리기
                pygame.draw.line(screen, ARROW_COLOR, 
                               (prereq_pos[0] + NODE_SIZE//2, prereq_pos[1] + NODE_SIZE//2),
                               (current_pos[0] + NODE_SIZE//2, current_pos[1] + NODE_SIZE//2),
                               ARROW_THICKNESS)
                
                # 화살표 머리 그리기
                arrow_head_size = 8
                dx = current_pos[0] - prereq_pos[0]
                dy = current_pos[1] - prereq_pos[1]
                length = math.sqrt(dx*dx + dy*dy)
                if length > 0:
                    dx, dy = dx/length, dy/length
                    arrow_x = current_pos[0] + NODE_SIZE//2 - dx * (NODE_SIZE//2 + arrow_head_size)
                    arrow_y = current_pos[1] + NODE_SIZE//2 - dy * (NODE_SIZE//2 + arrow_head_size)
                    
                    # 화살표 머리 그리기
                    pygame.draw.polygon(screen, ARROW_COLOR, [
                        (arrow_x, arrow_y),
                        (arrow_x - arrow_head_size * dy, arrow_y + arrow_head_size * dx),
                        (arrow_x + arrow_head_size * dy, arrow_y - arrow_head_size * dx)
                    ])
    
    # 스킬 노드 그리기
    for skill_name, skill_data in tree_data["skills"].items():
        x, y = skill_data["position"]
        
        # 노드 색상 결정
        if skill_data["current_level"] >= skill_data["max_level"]:
            node_color = NODE_MAXED
        elif skill_data["current_level"] > 0:
            node_color = NODE_AVAILABLE
        else:
            can_upgrade, _ = can_upgrade_skill(selected_tree, skill_name)
            node_color = NODE_AVAILABLE if can_upgrade else NODE_LOCKED
        
        # 노드 그리기
        pygame.draw.rect(screen, node_color, (x, y, NODE_SIZE, NODE_SIZE))
        pygame.draw.rect(screen, NODE_BORDER, (x, y, NODE_SIZE, NODE_SIZE), 2)
        
        # 아이콘 그리기 (텍스트로 대체)
        icon_text = font_medium.render(skill_data["icon"], True, TEXT_COLOR)
        icon_rect = icon_text.get_rect(center=(x + NODE_SIZE//2, y + NODE_SIZE//2))
        screen.blit(icon_text, icon_rect)
        
        # 레벨 표시
        if skill_data["current_level"] > 0:
            level_text = font_small.render(f"{skill_data['current_level']}/{skill_data['max_level']}", True, TEXT_COLOR)
            level_rect = level_text.get_rect(center=(x + NODE_SIZE//2, y + NODE_SIZE + 15))
            screen.blit(level_text, level_rect)
    
    # 하단 안내 텍스트
    help_text = font_small.render("클릭: 스킬 업그레이드 | ESC: 나가기", True, (150, 150, 150))
    screen.blit(help_text, (20, SKILL_TREE_HEIGHT - 30))

def handle_skill_tree_click(pos, selected_tree="paddle"):
    """스킬 트리 클릭 처리"""
    tree_data = skill_trees[selected_tree]
    
    for skill_name, skill_data in tree_data["skills"].items():
        x, y = skill_data["position"]
        node_rect = pygame.Rect(x, y, NODE_SIZE, NODE_SIZE)
        
        if node_rect.collidepoint(pos):
            success, message = upgrade_skill(selected_tree, skill_name)
            return success, message
    
    return False, ""

def show_skill_tree_screen(screen):
    """스킬 트리 화면 표시"""
    selected_tree = "paddle"
    clock = pygame.time.Clock()
    
    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return True
                elif event.key == pygame.K_1:
                    selected_tree = "paddle"
                elif event.key == pygame.K_2:
                    selected_tree = "dash"
                elif event.key == pygame.K_3:
                    selected_tree = "item"
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:  # 좌클릭
                    success, message = handle_skill_tree_click(event.pos, selected_tree)
                    if message:
                        print(message)  #  UI 
        
        draw_skill_tree(screen, selected_tree)
        
        # 트리 선택 안내
        font_small = pygame.font.Font("NanumSquareB.ttf", 14)
        tree_text = font_small.render("1: 패들 | 2: 대쉬 | 3: 아이템", True, (150, 150, 150))
        screen.blit(tree_text, (20, SKILL_TREE_HEIGHT - 50))
        
        pygame.display.flip()
        clock.tick(60)

# 스킬 효과 적용 함수들
def apply_paddle_size_boost(base_size):
    """패들 크기 증가 효과"""
    boost = get_skill_effect_value("paddle_size_boost") * 0.02  # 2%씩 증가
    return base_size * (1 + boost)

def apply_paddle_speed_boost(base_speed):
    """패들 속도 증가 효과"""
    boost = get_skill_effect_value("paddle_speed_boost")
    return base_speed + boost

def apply_gauge_boost(base_gauge):
    """게이지 충전 증가 효과"""
    boost = get_skill_effect_value("gauge_boost") * 5
    return base_gauge + boost

def apply_dash_distance_boost(base_distance):
    """대쉬 거리 증가 효과"""
    boost = get_skill_effect_value("dash_distance_boost") * 0.03  # 3%씩 증가
    return base_distance * (1 + boost)

def apply_dash_cooldown_reduction(base_cooldown):
    """대쉬 쿨타임 감소 효과"""
    reduction = get_skill_effect_value("dash_cooldown_reduction") * 0.2  # 0.2초씩 감소
    return max(0, base_cooldown - reduction)

def apply_dash_cost_reduction(base_cost):
    """대쉬 게이지 소모 감소 효과"""
    reduction = get_skill_effect_value("dash_cost_reduction") * 10
    return max(0, base_cost - reduction)

def apply_item_spawn_boost(base_chance):
    """아이템 스폰 확률 증가 효과"""
    boost = get_skill_effect_value("item_spawn_boost") * 0.1  # 10%씩 증가
    return base_chance * (1 + boost)
