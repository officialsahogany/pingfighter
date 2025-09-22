import pygame
import json
import os
import math
import sys

ACADEMY_DEBUG = os.getenv("ACADEMY_DEBUG") == "1"

# PyInstaller 실행 파일에서 리소스 경로를 찾기 위한 함수
def resource_path(relative_path):
    """PyInstaller로 패키징된 실행 파일에서 리소스 경로를 찾는 함수"""
    try:
        # PyInstaller가 생성한 임시 폴더 경로
        base_path = sys._MEIPASS
    except Exception:
        # 현재 파일의 디렉토리를 기준으로 함 (academy.py가 있는 위치)
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    return os.path.join(base_path, relative_path)

# 스킬 데이터 구조
SKILL_TREES = {
    "dash": {
        "name": "대쉬 스킬",
        "color": (100, 150, 255),  # 파란색
        "skills": [
            # 상단 시작 스킬들 (선행 조건 없음)
            {
                "id": "dash_lightweight",
                "name": "경량화",
                "description": "대쉬토큰 충전시간 7% 감소",
                "max_level": 5,
                "cost": 1,
                "icon_color": (100, 150, 255),
                "requires": None,
                "row": 0,
                "col": 0
            },
            {
                "id": "dash_module_control", 
                "name": "모듈제어",
                "description": "통제불능시간 10% 감소",
                "max_level": 5,
                "cost": 1,
                "icon_color": (100, 150, 255),
                "requires": None,
                "row": 0,
                "col": 1
            },
            
            # 2단계 스킬들 (경량화 또는 모듈제어 필요 + 누적 TP 4 이상)
            {
                "id": "dash_jump",
                "name": "도약",
                "description": "대쉬 거리 4% 증가\n(누적 ★4 필요)",
                "max_level": 5,
                "cost": 1,
                "icon_color": (150, 200, 255),
                "requires": "dash_lightweight",
                "total_tp_required": 4,
                "row": 1,
                "col": 0
            },
            {
                "id": "dash_battery_pack",
                "name": "배터리팩",
                "description": "게이지 소모량 8% 감소\n(누적 ★4 필요)",
                "max_level": 5,
                "cost": 1,
                "icon_color": (150, 200, 255),
                "requires": "dash_module_control",
                "total_tp_required": 4,
                "row": 1,
                "col": 1
            },
            
            # 3단계 스킬들 (배터리팩 또는 도약으로 가속화 해금 + 누적 TP 8 이상)
            {
                "id": "dash_acceleration",
                "name": "버스트업",
                "description": "대쉬 사용시 패들 세로 크기 60% 증가\n(누적 ★8 필요)",
                "max_level": 5,
                "cost": 2,
                "icon_color": (200, 220, 255),
                "requires_or": ["dash_battery_pack", "dash_jump"],  # 배터리팩 또는 도약 중 하나만 있으면 해금
                "total_tp_required": 8,
                "row": 2,
                "col": 0
            },
            {
                "id": "dash_amplification",
                "name": "증폭",
                "description": "대쉬토큰 1개 증가\n(누적 ★8 필요)",
                "max_level": 2,
                "cost": 3,
                "icon_color": (200, 220, 255),
                "requires": "dash_battery_pack",
                "total_tp_required": 8,
                "row": 2,
                "col": 1
            },
            
            # 최종 스킬 (가속화만 필요 + 누적 TP 12 이상)
            {
                "id": "dash_spirit",
                "name": "대쉬 스피릿",
                "description": "대쉬 시전시 30% 확률로 하늘색 레이저 잔상 생성\n(레벨2: 50% 확률)\n(누적 ★12 필요)",
                "max_level": 2,
                "cost": 4,
                "icon_color": (255, 200, 100),
                "requires": "dash_acceleration",
                "total_tp_required": 12,
                "row": 3,
                "col": 0
            }
        ]
    },
    "item": {
        "name": "아이템 스킬",
        "color": (255, 150, 100),  # 주황색
        "skills": [
            {
                "id": "item_luck",
                "name": "행운",
                "description": "아이템 스폰 대기시간 5% 감소\n(Lv5: 추가 -5%)",
                "max_level": 5,
                "cost": 1,
                "icon_color": (255, 150, 100),
                "requires": None,
                "row": 0,
                "col": 0
            },
            {
                "id": "item_cooldown_mastery",
                "name": "숙련",
                "description": "엑티브 아이템 쿨타임 8% 감소",
                "max_level": 5,
                "cost": 1,
                "icon_color": (255, 150, 120),
                "requires": None,
                "row": 0,
                "col": 1
            },
            {
                "id": "item_gauge_mastery",
                "name": "숙달",
                "description": "엑티브 아이템 사용 시 게이지 +10\n(누적 ★4 필요)",
                "max_level": 5,
                "cost": 1,
                "icon_color": (255, 180, 140),
                "requires": "item_luck",
                "total_tp_required": 4,
                "row": 1,
                "col": 0
            },
            {
                "id": "item_bag_expansion",
                "name": "가방 확장",
                "description": "엑티브 아이템 슬롯 1칸 증가\n(누적 ★4 필요)",
                "max_level": 3,
                "cost": 2,
                "icon_color": (255, 180, 150),
                "requires": "item_cooldown_mastery",
                "total_tp_required": 4,
                "row": 1,
                "col": 1
            },
            {
                "id": "item_gamble",
                "name": "도박",
                "description": "가챠 후 25% 확률로 추가 1회 자동 실행\n(누적 ★8 필요)",
                "max_level": 3,
                "cost": 3,
                "icon_color": (255, 205, 160),
                "requires": "item_gauge_mastery",
                "total_tp_required": 8,
                "row": 2,
                "col": 0
            },
            {
                "id": "item_recycle",
                "name": "연금술",
                "description": "연금술로 사용한 아이템이 유지될 확률 20%\n(누적 ★8 필요)",
                "max_level": 3,
                "cost": 3,
                "icon_color": (255, 205, 170),
                "requires": "item_bag_expansion",
                "total_tp_required": 8,
                "row": 2,
                "col": 1
            },
            {
                "id": "item_treasure_map",
                "name": "보물지도",
                "description": "전설 필드 확률 +300%, 가챠 전설 +5%\n(누적 ★12 필요)",
                "max_level": 3,
                "cost": 4,
                "icon_color": (255, 220, 120),
                "requires_or": ["item_gamble", "item_recycle"],
                "total_tp_required": 12,
                "row": 3,
                "col": 0.5
            }
        ]
    },
    "paddle": {
        "name": "패들 스킬",
        "color": (100, 255, 150),  # 초록색
        "skills": [
            {
                "id": "paddle_gauge",
                "name": "게이지 충전량 증가",
                "description": "패들 충돌 시 게이지 +5 증가",
                "max_level": 5,
                "cost": 1,
                "icon_color": (100, 255, 150),
                "requires": None,
                "row": 0,
                "col": 0  # 왼쪽 시작
            },
            {
                "id": "paddle_speed",
                "name": "패들 속도 증가",
                "description": "패들 최대 속도 0.5 증가",
                "max_level": 5,
                "cost": 1,
                "icon_color": (100, 255, 150),
                "requires": None,
                "row": 0,
                "col": 1  # 오른쪽 시작
            },
            {
                "id": "paddle_size",
                "name": "패들 크기 증가",
                "description": "패들 크기 2% 증가",
                "max_level": 5,
                "cost": 1,
                "icon_color": (100, 255, 150),
                "requires": "paddle_gauge",
                "row": 1,
                "col": 0  # 게이지에서 이어짐
            },
            {
                "id": "paddle_max_gauge",
                "name": "최대 게이지 증가",
                "description": "게이지 최대치 30 증가",
                "max_level": 5,
                "cost": 1,
                "icon_color": (100, 255, 150),
                "requires": "paddle_speed",
                "row": 1,
                "col": 1  # 속도에서 이어짐
            },
            {
                "id": "paddle_bio",
                "name": "바이오 패들",
                "description": "공이 하단으로 떨어질 때 자력 효과",
                "max_level": 1,
                "cost": 3,
                "icon_color": (255, 200, 100),
                "requires_or": ["paddle_size", "paddle_max_gauge"],  # 둘 중 하나만 있어도 해금
                "row": 2,
                "col": 0.5  # 중앙에서 합쳐짐
            }
        ]
    },
    "smasher": {
        "name": "스매셔 스킬",
        "color": (255, 100, 100),  # 빨간색
        "skills": []  # 더미 데이터 - 실제로는 smasher_skills 모듈 사용
    }
}

TREE_SUMMARIES = {
    "dash": "대쉬 속도와 통제력을 끌어올려 공격 템포를 높이는 스킬입니다.",
    "item": "필드 드랍률과 가챠, 아이템 쿨타임을 다뤄 보조 능력을 강화합니다.",
    "paddle": "패들의 크기·속도·게이지를 조정해 안정적인 운영을 도와줍니다.",
    "smasher": "스매셔 전용 스킬로 특수 공격 루프를 확장합니다."
}

class SkillSystem:
    def __init__(self):
        # 기본값 설정 (스킬은 초기화하지 않음)
        self.skill_points = 0
        self.skill_levels = {}
        self.total_invested_points = 0  # 누적으로 투자한 총 TP
        self.total_invested_points_by_tree = {}
        self.skill_to_tree = {}
        self._initialize_tree_trackers()
        # 스킬 레벨 초기화는 reset_all()을 통해서만 수행
        # 게임 세션 동안 스킬 레벨 유지를 위해 자동 초기화 제거

    def init_fresh_skills(self):
        """스킬을 항상 초기화 (저장/로드 없음)"""
        self.skill_points = 0
        self.skill_levels = {}
        self.total_invested_points = 0
        self._initialize_tree_trackers()
        # 모든 스킬 레벨을 0으로 초기화
        for tree_id, tree_data in SKILL_TREES.items():
            for skill in tree_data["skills"]:
                self.skill_levels[skill["id"]] = 0
        print("(   0)")

    def _initialize_tree_trackers(self):
        """트리별 누적 TP와 스킬-트리 매핑 초기화"""
        self.total_invested_points_by_tree = {tree_id: 0 for tree_id in SKILL_TREES.keys()}
        self.skill_to_tree = {}
        for tree_id, tree_data in SKILL_TREES.items():
            for skill in tree_data["skills"]:
                self.skill_to_tree[skill["id"]] = tree_id

    def _add_tree_points(self, tree_id, amount):
        if tree_id is None or amount <= 0:
            return
        self.total_invested_points_by_tree[tree_id] = self.total_invested_points_by_tree.get(tree_id, 0) + amount

    def get_tree_total(self, tree_id):
        return self.total_invested_points_by_tree.get(tree_id, 0)

    def get_tree_id_for_skill(self, skill_id):
        return self.skill_to_tree.get(skill_id)

    def register_manual_investment(self, tree_id, amount):
        if amount <= 0:
            return
        self.total_invested_points += amount
        self._add_tree_points(tree_id, amount)

    def add_skill_points(self, points):
        """스킬 포인트 추가 (저장하지 않음)"""
        self.skill_points += points
        
    def reset_all(self):
        """모든 스킬과 포인트를 완전히 초기화"""
        self.init_fresh_skills()
        # 화살표 애니메이션 기록도 초기화
        if hasattr(self, 'played_arrow_animations'):
            self.played_arrow_animations.clear()
        
    def reset_skill_points(self):
        """스킬 포인트만 0으로 초기화"""
        self.skill_points = 0
    
    def can_upgrade_skill(self, skill_id):
        """스킬 업그레이드 가능 여부 확인"""
        # 스킬 정보 찾기
        skill_data = None
        for tree_data in SKILL_TREES.values():
            for skill in tree_data["skills"]:
                if skill["id"] == skill_id:
                    skill_data = skill
                    break
        
        if not skill_data:
            return False
        
        # 현재 레벨 확인
        current_level = self.skill_levels.get(skill_id, 0)
        if current_level >= skill_data["max_level"]:
            return False
        
        # 스킬 포인트 확인 (레벨과 상관없이 정의된 코스트 사용)
        actual_cost = skill_data["cost"]
        if self.skill_points < actual_cost:
            return False
        
        # 선행 스킬 확인
        if skill_data.get("requires"):
            if isinstance(skill_data["requires"], list):
                # 여러 스킬이 모두 필요한 경우 (AND 조건)
                for required_skill in skill_data["requires"]:
                    required_level = self.skill_levels.get(required_skill, 0)
                    if required_level == 0:
                        return False
            else:
                # 단일 선행 스킬이 필요한 경우
                required_level = self.skill_levels.get(skill_data["requires"], 0)
                if required_level == 0:
                    return False
        
        # OR 조건 선행 스킬 확인
        if skill_data.get("requires_or"):
            # 하나 이상의 스킬이 필요한 경우 (OR 조건)
            has_any_required = False
            for required_skill in skill_data["requires_or"]:
                required_level = self.skill_levels.get(required_skill, 0)
                if required_level > 0:
                    has_any_required = True
                    break
            if not has_any_required:
                return False
        
        # 누적 TP 조건 확인
        if skill_data.get("total_tp_required"):
            tree_id = self.skill_to_tree.get(skill_id)
            tree_total = self.get_tree_total(tree_id)
            if tree_total < skill_data["total_tp_required"]:
                return False

        return True
    
    def upgrade_skill(self, skill_id):
        """스킬 업그레이드"""
        if not self.can_upgrade_skill(skill_id):
            return False
        
        # 스킬 정보 찾기
        skill_data = None
        for tree_data in SKILL_TREES.values():
            for skill in tree_data["skills"]:
                if skill["id"] == skill_id:
                    skill_data = skill
                    break
        
        if skill_data:
            old_level = self.skill_levels.get(skill_id, 0)
            
            # 실제 비용은 스킬 정의에 고정된 값을 사용
            actual_cost = skill_data["cost"]

            self.skill_points -= actual_cost
            self.skill_levels[skill_id] = self.skill_levels.get(skill_id, 0) + 1
            self.total_invested_points += actual_cost  # 실제 투자한 포인트만 누적
            tree_id = self.skill_to_tree.get(skill_id)
            self._add_tree_points(tree_id, actual_cost)
            print(f"  : {skill_id} (: {actual_cost}) →   TP: {self.total_invested_points}")
            
            # 0→1 전환시에만 애니메이션 (누적 TP 업데이트 후 체크)
            if old_level == 0:
                print(f"   : {skill_id} (0→1),")
                # 여기서 academy_ui 인스턴스를 통해 애니메이션 실행 필요
            
            # self.save_skills()  # 1회차용으로 저장 비활성화
            return True
        
        return False
    
    def get_skill_level(self, skill_id):
        """스킬 레벨 반환"""
        return self.skill_levels.get(skill_id, 0)
    
    def get_skill_data(self, skill_id):
        """스킬 데이터 가져오기"""
        for tree_data in SKILL_TREES.values():
            for skill in tree_data["skills"]:
                if skill["id"] == skill_id:
                    return skill
        return None

class AcademyUI:
    def __init__(self, screen, width, height, selected_character="smasher"):  # 테스트를 위해 기본값을 "smasher"로 변경
        self.screen = screen
        self.width = width
        self.height = height
        self.skill_system = skill_system  # 전역 스킬 시스템 인스턴스 사용
        self.selected_tree = "dash"
        self.selected_skill_index = 0  # 현재 선택된 스킬 인덱스
        self.tab_selection_mode = False  # 탭 선택 모드 여부
        
        # 강제로 스매셔 캐릭터로 설정 (테스트)
        self.selected_character = "smasher"
        
        print(f" AcademyUI  -  : {self.selected_character}")
        
        # 스매셔 스킬 시스템 임포트
        if self.selected_character == "smasher":
            from skills.smasher_skills import get_smasher_skills
            self.smasher_skills = get_smasher_skills()
            print("")
        
        # 애니메이션 관련 변수
        self.unlock_animations = {}  # {skill_id: {"start_time": time, "duration": 1000}}
        self.arrow_animations = {}  # {arrow_id: {"start_time": time, "duration": 1000, "from_skill": id, "to_skill": id}}
        self.played_arrow_animations = set()  # 이미 재생된 화살표 애니메이션 추적
        self.is_animating = False  # 애니메이션 중 키보드 입력 차단
        
        # 스킬 레벨업 테두리 빛 애니메이션
        self.skill_levelup_animations = {}  # {skill_id: {"start_time": time, "duration": 500}}
        
        # 네비게이션 관련 변수
        self.skill_positions = {}  # {skill_id: {"x": x, "y": y, "row": row, "col": col}}
        
        # 스킬 포인트 이펙트 관련 변수
        self.sp_effect_particles = []  # 파티클 리스트
        self.sp_effect_time = 0  # 이펙트 시작 시간
        self.sp_effect_duration = 1500  # 이펙트 지속 시간 (1.5초)
        self.sp_glow_alpha = 0  # 글로우 효과 알파값
        self.sp_scale_factor = 1.0  # 스케일 애니메이션
        
        # 캐시된 glow surface들
        self.glow_cache = {}
        self._create_glow_cache()
        
        # 폰트 로드 (크기 조정)
        try:
            self.font_large = pygame.font.Font(resource_path("NanumSquareB.ttf"), 24)
            self.font_medium = pygame.font.Font(resource_path("NanumSquareR.ttf"), 18)
            self.font_small = pygame.font.Font(resource_path("NanumSquareR.ttf"), 14)
        except:
            self.font_large = pygame.font.Font(None, 24)
            self.font_medium = pygame.font.Font(None, 18)
            self.font_small = pygame.font.Font(None, 14)

    
    def _create_glow_cache(self):
        """Glow surface들을 미리 생성하여 캐시"""
        skill_size = 60
        
        # 시안색 glow (언락된 스킬용)
        for radius in range(10, 31, 5):  # 다양한 크기의 glow
            glow_key = f"cyan_{radius}"
            glow_surface = pygame.Surface((skill_size + radius * 4, skill_size + radius * 4), pygame.SRCALPHA)
            for i in range(radius):
                alpha = int(100 * (1 - i/radius))
                pygame.draw.rect(glow_surface, (0, 255, 255, alpha), 
                               (radius * 2 - i, radius * 2 - i, 
                                skill_size + i * 2, skill_size + i * 2), 2)
            self.glow_cache[glow_key] = glow_surface

    def _wrap_text_lines(self, text: str, font, max_width: int) -> list[str]:
        """지정된 폭에 맞춰 텍스트를 줄바꿈"""
        if not text:
            return []

        words = text.split()
        lines: list[str] = []
        current_line = ""

        for word in words:
            candidate = f"{current_line} {word}".strip() if current_line else word
            if font.size(candidate)[0] <= max_width:
                current_line = candidate
            else:
                if current_line:
                    lines.append(current_line)
                current_line = word

        if current_line:
            lines.append(current_line)

        return lines if lines else [text]

    def _draw_star_icon(self, target_surface, center_x: int, center_y: int, size: int, color):
        """단순 5각 별을 그린다"""
        points = []
        for i in range(10):
            angle = math.pi / 5 * i - math.pi / 2
            radius = size if i % 2 == 0 else size * 0.45
            px = center_x + radius * math.cos(angle)
            py = center_y + radius * math.sin(angle)
            points.append((px, py))
        pygame.draw.polygon(target_surface, color, points)

    def _create_master_badge_surface(self, color):
        """★ MASTER ★ 배지를 생성"""
        label_surface = self.font_small.render("MASTER", True, color)
        star_size = max(4, label_surface.get_height() // 2)
        spacing = 6
        width = star_size * 2 + spacing * 2 + label_surface.get_width()
        height = max(label_surface.get_height(), star_size * 2)
        surface = pygame.Surface((width, height), pygame.SRCALPHA)

        center_y = height // 2
        # 왼쪽 별
        self._draw_star_icon(surface, star_size, center_y, star_size, color)
        # 오른쪽 별
        self._draw_star_icon(surface, width - star_size, center_y, star_size, color)

        text_x = star_size + spacing
        text_y = (height - label_surface.get_height()) // 2
        surface.blit(label_surface, (text_x, text_y))
        return surface

    def handle_mouse_click(self, pos):
        """마우스 클릭 처리"""
        x, y = pos
        
        # 탭 클릭 확인
        tab_y = 160
        tab_height = 30
        tab_width = 100
        
        # 대쉬 탭
        if 200 <= x <= 200 + tab_width and tab_y <= y <= tab_y + tab_height:
            self.selected_tree = "dash"
            self._clamp_selection_to_current_tree()
            self.tab_selection_mode = False
            self.update_skill_positions()
            return None
            
        # 아이템 탭
        if 300 <= x <= 300 + tab_width and tab_y <= y <= tab_y + tab_height:
            self.selected_tree = "item"
            self._clamp_selection_to_current_tree()
            self.tab_selection_mode = False
            self.update_skill_positions()
            if ACADEMY_DEBUG:
                print("[AcademyUI] mouse tab -> item")
            return None
            
        # 패들 탭
        if 400 <= x <= 400 + tab_width and tab_y <= y <= tab_y + tab_height:
            self.selected_tree = "paddle"
            self._clamp_selection_to_current_tree()
            self.tab_selection_mode = False
            self.update_skill_positions()
            return None
        
        # 스킬 클릭 확인
        if hasattr(self, 'skill_positions'):
            for skill_id, pos_data in self.skill_positions.items():
                skill_x = pos_data['x']
                skill_y = pos_data['y']
                skill_size = 60
                
                # 스킬 박스 영역 체크
                if skill_x <= x <= skill_x + skill_size and skill_y <= y <= skill_y + skill_size:
                    # 스킬 선택
                    self.set_selected_skill_by_id(skill_id)
                    
                    # 더블클릭처럼 바로 업그레이드 시도
                    tree_data = SKILL_TREES.get(self.selected_tree)
                    if tree_data:
                        for i, skill in enumerate(tree_data["skills"]):
                            if skill["id"] == skill_id:
                                self.selected_skill_index = i
                                if self.skill_system.can_upgrade_skill(skill_id):
                                    self.skill_system.upgrade_skill(skill_id)
                                    self.start_levelup_animation(skill_id)
                                break
                    return None
        
        return None
    
    def handle_mouse_hover(self, pos):
        """마우스 호버 처리"""
        x, y = pos
        
        # 스킬 호버 확인
        if hasattr(self, 'skill_positions'):
            for skill_id, pos_data in self.skill_positions.items():
                skill_x = pos_data['x']
                skill_y = pos_data['y']
                skill_size = 60
                
                # 스킬 박스 영역 체크
                if skill_x <= x <= skill_x + skill_size and skill_y <= y <= skill_y + skill_size:
                    # 호버 상태로 선택 (시각적 피드백용)
                    tree_data = SKILL_TREES.get(self.selected_tree)
                    if tree_data:
                        for i, skill in enumerate(tree_data["skills"]):
                            if skill["id"] == skill_id:
                                self.selected_skill_index = i
                                break
                    break
    
    def start_levelup_animation(self, skill_id):
        """스킬 레벨업 반짝임 애니메이션 시작"""
        import random
        current_time = pygame.time.get_ticks()
        print(f"  ! skill={skill_id}, time={current_time}")
        
        # 스타버스트 파티클 생성 (반짝이는 별 효과)
        starburst_particles = []
        for i in range(24):  # 24개로 증가 (더 화려하게)
            angle = (math.pi * 2 / 24) * i  # 균등한 각도로 배치
            for j in range(3):  # 각 방향으로 3개씩 (더 많이)
                # 최종 도달 거리 설정 (픽셀 단위)
                max_distance = random.uniform(40, 60) + j * 15  # 40-90 픽셀 범위로 더 확대
                starburst_particles.append({
                    "angle": angle + random.uniform(-0.1, 0.1),  # 약간의 랜덤성
                    "max_distance": max_distance,  # 최종 도달 거리
                    "size": random.uniform(2, 4),
                    "brightness": 255,
                    "sparkle_phase": random.uniform(0, math.pi * 2)
                })
        
        # 글리터 파티클 생성 (작은 반짝임들)
        glitter_particles = []
        for _ in range(25):  # 30->25개로 감소
            glitter_particles.append({
                "x": random.uniform(-20, 20),  # 범위 축소 (-30,30 -> -20,20)
                "y": random.uniform(-20, 20),  # 범위 축소
                "phase": random.uniform(0, math.pi * 2),
                "speed": random.uniform(0.02, 0.05),
                "size": random.uniform(1, 2),
                "delay": random.uniform(0, 600)  # 순차적으로 나타나기 (2초에 맞춤)
            })
        
        self.skill_levelup_animations[skill_id] = {
            "start_time": current_time,
            "duration": 2000,  # 2초로 설정
            "starburst": starburst_particles,
            "glitter": glitter_particles,
            "flash_intensity": 0
        }
    
    def start_unlock_animation(self, skill_id):
        """스킬 해금 애니메이션 시작 (아이콘 효과만, 짧게)"""
        current_time = pygame.time.get_ticks()
        self.unlock_animations[skill_id] = {
            "start_time": current_time,
            "duration": 2000,  # 2초로 증가 (반짝임 효과 추가)
            "flash_count": 0,  # 반짝임 카운트
            "sparkle_particles": []  # 스파클 파티클 리스트
        }
        
        # 스파클 파티클 생성
        import random
        for _ in range(15):  # 15개의 스파클 파티클
            particle = {
                "angle": random.uniform(0, 2 * 3.14159),
                "distance": 0,
                "max_distance": random.uniform(30, 60),
                "speed": random.uniform(2, 4),
                "size": random.randint(2, 5),
                "life": random.randint(30, 60)
            }
            self.unlock_animations[skill_id]["sparkle_particles"].append(particle)
        
        # 입력 차단 없음 - 화살표 애니메이션이 있을 때만 차단
        # 화살표 애니메이션은 check_and_animate_unlocked_skills에서만 실행
        
        # 스킬 포인트 이펙트 시작
        self.start_sp_effect()
    
    def start_sp_effect(self):
        """스킬 포인트 이펙트 시작"""
        current_time = pygame.time.get_ticks()
        self.sp_effect_time = current_time
        self.sp_glow_alpha = 255
        self.sp_scale_factor = 1.5
        
        # 파티클 생성 (별 모양 파티클)
        import random
        sp_rect = pygame.Rect(self.width - 150, 10, 130, 30)  # 스킬 포인트 표시 영역
        
        for _ in range(20):  # 20개의 파티클 생성
            particle = {
                "x": sp_rect.centerx + random.randint(-20, 20),
                "y": sp_rect.centery + random.randint(-10, 10),
                "vx": random.uniform(-3, 3),
                "vy": random.uniform(-4, -1),
                "size": random.randint(3, 8),
                "life": 60,  # 60프레임 동안 생존
                "color": random.choice([
                    (255, 255, 100),  # 노란색
                    (255, 220, 0),    # 금색
                    (255, 255, 255),  # 흰색
                    (255, 200, 0)     # 주황색
                ])
            }
            self.sp_effect_particles.append(particle)
    
    def update_sp_effect(self):
        """스킬 포인트 이펙트 업데이트"""
        current_time = pygame.time.get_ticks()
        
        # 글로우 및 스케일 애니메이션 업데이트
        if self.sp_effect_time > 0:
            elapsed = current_time - self.sp_effect_time
            if elapsed < self.sp_effect_duration:
                # 페이드 아웃
                progress = elapsed / self.sp_effect_duration
                self.sp_glow_alpha = int(255 * (1 - progress))
                
                # 스케일 애니메이션 (1.5 -> 1.0)
                self.sp_scale_factor = 1.0 + 0.5 * (1 - progress)
            else:
                self.sp_glow_alpha = 0
                self.sp_scale_factor = 1.0
                self.sp_effect_time = 0
        
        # 파티클 업데이트
        import math
        for particle in self.sp_effect_particles[:]:
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            particle["vy"] += 0.2  # 중력 효과
            particle["life"] -= 1
            
            # 회전 효과
            angle = math.atan2(particle["vy"], particle["vx"])
            particle["vx"] = math.cos(angle) * 2
            
            if particle["life"] <= 0:
                self.sp_effect_particles.remove(particle)
    
    def draw_sp_effect(self):
        """스킬 포인트 이펙트 렌더링"""
        import math
        
        # 파티클 렌더링
        for particle in self.sp_effect_particles:
            alpha = int(255 * (particle["life"] / 60))
            
            # 별 모양 그리기
            star_points = []
            center_x, center_y = particle["x"], particle["y"]
            size = particle["size"]
            
            for i in range(10):
                angle = math.pi * i / 5
                if i % 2 == 0:
                    # 바깥쪽 점
                    x = center_x + size * math.cos(angle)
                    y = center_y + size * math.sin(angle)
                else:
                    # 안쪽 점
                    x = center_x + size * 0.5 * math.cos(angle)
                    y = center_y + size * 0.5 * math.sin(angle)
                star_points.append((x, y))
            
            # 별 그리기
            if len(star_points) >= 3:
                star_surf = pygame.Surface((size * 2 + 4, size * 2 + 4), pygame.SRCALPHA)
                adjusted_points = [(p[0] - center_x + size + 2, p[1] - center_y + size + 2) for p in star_points]
                
                # 글로우 효과
                for j in range(2, 0, -1):
                    glow_color = (*particle["color"], alpha // (3 - j))
                    pygame.draw.polygon(star_surf, glow_color, adjusted_points, j)
                
                # 메인 별
                main_color = (*particle["color"], alpha)
                pygame.draw.polygon(star_surf, main_color, adjusted_points)
                
                self.screen.blit(star_surf, (center_x - size - 2, center_y - size - 2))

    def check_and_animate_unlocked_skills(self, recently_upgraded_skill_id):
        """누적 TP 업데이트 후 새로 해금된 스킬들에 대한 화살표 애니메이션 실행"""
        tree_tp_total = self.skill_system.get_tree_total(self.selected_tree)
        print(f"  TP    : {recently_upgraded_skill_id} (tree TP: {tree_tp_total}, total TP: {self.skill_system.total_invested_points})")
        
        # 애니메이션 생성 전에 기존 입력 차단 해제
        animation_created = False
        
        tree_data = SKILL_TREES[self.selected_tree]
        current_time = pygame.time.get_ticks()
        
        for skill in tree_data["skills"]:
            # 아직 잠금 상태인 스킬만 검사
            if self.skill_system.get_skill_level(skill["id"]) > 0:
                continue
                
            # 모든 해금 조건을 완전히 만족하는지 확인
            # (선행스킬 조건 + 누적 TP 조건 모두 확인)
            requires = skill.get("requires")
            requires_or = skill.get("requires_or")
            total_tp_required = skill.get("total_tp_required", 0)
            
            # 조건 체크
            prereq_satisfied = False
            
            if requires_or:
                # OR 조건: 하나라도 만족하면 됨
                for req_skill in requires_or:
                    if self.skill_system.get_skill_level(req_skill) > 0:
                        prereq_satisfied = True
                        break
            elif requires:
                # 단일 선행 스킬 조건
                if self.skill_system.get_skill_level(requires) > 0:
                    prereq_satisfied = True
            else:
                # 선행 스킬 조건이 없음
                prereq_satisfied = True
            
            # 누적 TP 조건도 확인
            tp_satisfied = tree_tp_total >= total_tp_required
            
            # 모든 조건을 만족할 때만 애니메이션
            if prereq_satisfied and tp_satisfied:
                print(f"    : {skill['id']}")
                # 화살표 애니메이션 생성 (이미 재생된 것은 스킵)
                arrow_id = f"{recently_upgraded_skill_id}_to_{skill['id']}"
                
                # 이미 재생된 화살표 애니메이션인지 확인
                if arrow_id not in self.played_arrow_animations:
                    self.arrow_animations[arrow_id] = {
                        "start_time": current_time, 
                        "duration": 1000, 
                        "from_skill": recently_upgraded_skill_id, 
                        "to_skill": skill["id"]
                    }
                    self.played_arrow_animations.add(arrow_id)  # 재생 기록
                    animation_created = True
                    print(f"   : {recently_upgraded_skill_id} → {skill['id']} (tree TP: {tree_tp_total})")
                else:
                    print(f"   ( ): {recently_upgraded_skill_id} → {skill['id']}")
            else:
                if not prereq_satisfied:
                    print(f" {skill['id']}")
                if not tp_satisfied:
                    print(f" {skill['id']}  TP : {tree_tp_total}/{total_tp_required}")
        
        # 실제로 화살표 애니메이션이 생성된 경우에만 입력 차단
        if animation_created:
            self.is_animating = True

    def start_arrow_animations_deprecated(self, unlocked_skill_id):
        """방금 0→1이 된 스킬에서 실제로 해금되는 자식 스킬로 레이저 애니메이션 시작"""
        print(f" start_arrow_animations : {unlocked_skill_id}")
        current_time = pygame.time.get_ticks()
        tree_data = SKILL_TREES[self.selected_tree]
        # 위치 최신화 (좌표 사용)
        self.update_skill_positions()
        tree_tp_total = self.skill_system.get_tree_total(self.selected_tree)
        
        for skill in tree_data["skills"]:
            requires = skill.get("requires")
            requires_or = skill.get("requires_or")
            total_tp_required = skill.get("total_tp_required", 0)
            
            print(f"   : {skill['id']}, requires: {requires}, requires_or: {requires_or}, total_tp: {total_tp_required}")
            
            # 타겟 스킬이 아직 잠금 상태여야 함 (해금 순간만 애니메이션)
            target_level = self.skill_system.get_skill_level(skill["id"])
            if target_level > 0:
                print(f"⏭ {skill['id']}   (: {target_level})")
                continue
            
            print(f" {skill['id']}   ... ( : {target_level})")
            
            # 모든 해금 조건 확인
            can_unlock = True
            
            # 1. 선행 스킬 조건 확인
            if requires_or:
                # OR 조건: 하나라도 만족하면 됨
                has_any_required = False
                for req_skill in requires_or:
                    if self.skill_system.get_skill_level(req_skill) > 0:
                        has_any_required = True
                        break
                if not has_any_required:
                    can_unlock = False
            elif requires:
                # AND 조건: 모든 스킬이 필요
                if isinstance(requires, list):
                    if not all(self.skill_system.get_skill_level(r) > 0 for r in requires):
                        can_unlock = False
                else:
                    if self.skill_system.get_skill_level(requires) == 0:
                        can_unlock = False
            
            # 2. 누적 TP 조건 확인
            if total_tp_required > 0:
                if tree_tp_total < total_tp_required:
                    print(f" {skill['id']}  TP : {tree_tp_total}/{total_tp_required}")
                    can_unlock = False
                else:
                    print(f" {skill['id']}  TP : {tree_tp_total}/{total_tp_required}")
            
            # 모든 조건을 만족하면 애니메이션 실행 (방금 투자한 스킬과 관련된 경우)
            if can_unlock:
                should_animate = False
                
                # 1. 직접적인 선행 조건인 경우
                if requires_or:
                    if unlocked_skill_id in requires_or:
                        should_animate = True
                elif requires:
                    if isinstance(requires, list):
                        if unlocked_skill_id in requires:
                            should_animate = True
                    else:
                        if unlocked_skill_id == requires:
                            should_animate = True
                
                # 2. 누적 TP 조건이 이번 투자로 만족된 경우 (선행 조건도 만족하고 있어야 함)
                if not should_animate and total_tp_required > 0:
                    # 선행 스킬 조건이 이미 만족되어 있는 상태에서 누적 TP만 부족했던 경우
                    prereq_satisfied = False
                    if requires_or:
                        prereq_satisfied = any(self.skill_system.get_skill_level(req_skill) > 0 for req_skill in requires_or)
                    elif requires:
                        if isinstance(requires, list):
                            prereq_satisfied = all(self.skill_system.get_skill_level(r) > 0 for r in requires)
                        else:
                            prereq_satisfied = self.skill_system.get_skill_level(requires) > 0
                    else:
                        prereq_satisfied = True  # 선행 조건이 없는 경우
                    
                    # 선행 조건이 만족되어 있고, 이번 투자로 누적 TP 조건이 달성된 경우
                    if prereq_satisfied and tree_tp_total >= total_tp_required:
                        should_animate = True
                
                if should_animate:
                    arrow_id = f"{unlocked_skill_id}_to_{skill['id']}"
                    # 이미 재생된 화살표 애니메이션인지 확인
                    if arrow_id not in self.played_arrow_animations:
                        self.arrow_animations[arrow_id] = {"start_time": current_time, "duration": 1000, "from_skill": unlocked_skill_id, "to_skill": skill["id"]}
                        self.played_arrow_animations.add(arrow_id)  # 재생 기록
                        print(f"   : {unlocked_skill_id} → {skill['id']} (tree TP: {tree_tp_total})")
                    else:
                        print(f"   ( ): {unlocked_skill_id} → {skill['id']}")

    def update_animations(self):
        """애니메이션 업데이트"""
        current_time = pygame.time.get_ticks()
        
        # 완료된 스킬 애니메이션 제거
        finished_animations = []
        for skill_id, anim_data in self.unlock_animations.items():
            if current_time - anim_data["start_time"] > anim_data["duration"]:
                finished_animations.append(skill_id)
        for skill_id in finished_animations:
            del self.unlock_animations[skill_id]
        
        # 완료된 화살표 애니메이션 제거
        finished_arrow_animations = []
        for arrow_id, anim_data in self.arrow_animations.items():
            if current_time - anim_data["start_time"] > anim_data["duration"]:
                finished_arrow_animations.append(arrow_id)
        for arrow_id in finished_arrow_animations:
            if arrow_id in self.arrow_animations:
                del self.arrow_animations[arrow_id]
        
        # 화살표 애니메이션이 끝나면 입력 허용 (unlock_animations은 무시)
        if not self.arrow_animations:
            self.is_animating = False
        
        # 파티클 애니메이션 제거됨

    def draw_unlock_animation(self, skill_id, center_x, center_y):
        """스킬 해금 애니메이션 그리기 - 파티클 제거됨"""
        # 파티클 애니메이션 제거, 화살표 애니메이션만 사용
        pass

    def draw_arrow_animation(self, from_skill_id, to_skill_id):
        """형광 레이저가 위에서 아래(부모→자식)로 흘러드는 애니메이션"""
        import math
        arrow_id = f"{from_skill_id}_to_{to_skill_id}"
        if arrow_id not in self.arrow_animations:
            return
        current_time = pygame.time.get_ticks()
        anim = self.arrow_animations[arrow_id]
        progress = (current_time - anim["start_time"]) / anim["duration"]
        if progress > 1.0:
            return
        # 좌표
        self.update_skill_positions()
        from_pos = (self.skill_positions[from_skill_id]["x"], self.skill_positions[from_skill_id]["y"])  # 아이콘 좌상단
        to_pos = (self.skill_positions[to_skill_id]["x"], self.skill_positions[to_skill_id]["y"])        # 아이콘 좌상단
        skill_size = 60
        start = (from_pos[0] + skill_size // 2, from_pos[1] + skill_size)
        end = (to_pos[0] + skill_size // 2, to_pos[1])
        
        # 레이저 진행 위치
        # 처음 80%는 진행, 마지막 20%는 전체 선이 네온 그린으로 점등되는 페이드
        if progress < 0.8:
            laser_p = progress / 0.8
            cur_x = start[0] + (end[0] - start[0]) * laser_p
            cur_y = start[1] + (end[1] - start[1]) * laser_p
            # 진행 경로에 점 진하게 찍기 (네온 그린 사이언 계열)
            num_points = max(8, int(laser_p * 30))
            for i in range(num_points):
                t = (i / num_points) * laser_p
                px = start[0] + (end[0] - start[0]) * t
                py = start[1] + (end[1] - start[1]) * t
                # 컬러 사이클
                cycle = (pygame.time.get_ticks() * 0.004 + t * 2) % 2
                if cycle < 1:
                    color = (0, 255, max(0, min(255, int(255 * cycle))))  # 네온그린→시안
                else:
                    color = (max(0, min(255, int(255 * (cycle - 1)))), 255, 255)  # 시안→화이트
                intensity = 1.0 - (i / num_points) * 0.3
                point_size = max(2, int(4 * intensity))
                pygame.draw.circle(self.screen, color, (int(px), int(py)), point_size)
                # 글로우
                glow_alpha = max(0, min(255, int(80 * intensity)))
                if glow_alpha > 0:
                    glow_surface = pygame.Surface((point_size * 4, point_size * 4), pygame.SRCALPHA)
                    glow_color = (*color, glow_alpha)
                    pygame.draw.circle(glow_surface, glow_color, (point_size * 2, point_size * 2), point_size * 2)
                    self.screen.blit(glow_surface, (int(px - point_size * 2), int(py - point_size * 2)))
        else:
            # 전체 라인이 네온 그린으로 점등되며 서서히 안정화
            fade = (progress - 0.8) / 0.2
            alpha = max(0.0, 1.0 - fade)
            pulse = 1.0 + 0.2 * math.sin(pygame.time.get_ticks() * 0.01)
            base_color = (0, 255, 160)
            final_color = (
                max(0, min(255, int(base_color[0] * alpha * pulse))), 
                max(0, min(255, int(base_color[1] * alpha * pulse))), 
                max(0, min(255, int(base_color[2] * alpha * pulse)))
            )
            pygame.draw.line(self.screen, final_color, start, end, int(6 * pulse))
            # 화살표 머리 강조
            angle = math.atan2(end[1] - start[1], end[0] - start[0])
            head_len = 12
            ax1 = end[0] - head_len * math.cos(angle - math.pi / 6)
            ay1 = end[1] - head_len * math.sin(angle - math.pi / 6)
            ax2 = end[0] - head_len * math.cos(angle + math.pi / 6)
            ay2 = end[1] - head_len * math.sin(angle + math.pi / 6)
            pygame.draw.line(self.screen, final_color, end, (int(ax1), int(ay1)), 3)
            pygame.draw.line(self.screen, final_color, end, (int(ax2), int(ay2)), 3)

    def update_skill_positions(self):
        """현재 스킬트리의 스킬 위치 정보 업데이트"""
        self.skill_positions.clear()
        
        # 스매셔 탭 처리
        if self.selected_tree == "smasher":
            # 스매셔도 대쉬와 동일한 트리 구조 사용
            skill_size = 60
            row_spacing = 140
            col_spacing = 200
            available_width = self.width - 190
            start_x = (available_width - col_spacing * 2) // 2 + 30
            start_y = 160
            
            if hasattr(self, 'smasher_skills'):
                for skill in self.smasher_skills.skills:
                    row = skill["row"]
                    col = skill["col"]
                    
                    # col이 0.5인 경우 중앙 배치
                    if col == 0.5:
                        skill_x = start_x + col_spacing // 2
                    else:
                        skill_x = start_x + int(col) * col_spacing
                    
                    skill_y = start_y + row * row_spacing
                    
                    self.skill_positions[skill["id"]] = {
                        "x": skill_x,
                        "y": skill_y,
                        "row": row,
                        "col": col
                    }
            return
        
        tree_data = SKILL_TREES[self.selected_tree]
        
        if self.selected_tree in ["dash", "item", "paddle"]:
            # 트리 구조 스킬트리 (대쉬, 아이템, 패들)
            skill_size = 60
            row_spacing = 140
            col_spacing = 200
            available_width = self.width - 190
            start_x = (available_width - col_spacing * 2) // 2 + 30
            start_y = 160
            
            for skill in tree_data["skills"]:
                row = skill["row"]
                col = skill["col"]
                
                # col이 0.5인 경우 중앙 배치
                if col == 0.5:
                    skill_x = start_x + col_spacing // 2
                else:
                    skill_x = start_x + int(col) * col_spacing
                    
                skill_y = start_y + row * row_spacing
                
                self.skill_positions[skill["id"]] = {
                    "x": skill_x,
                    "y": skill_y,
                    "row": row,
                    "col": col
                }
        else:
            # 다른 스킬트리는 선형 구조
            start_y = 120
            skill_size = 50
            margin = 15
            
            for i, skill in enumerate(tree_data["skills"]):
                skill_x = 50
                skill_y = start_y + i * (skill_size + margin)
                
                self.skill_positions[skill["id"]] = {
                    "x": skill_x,
                    "y": skill_y,
                    "row": i,
                    "col": 0
                }

    def get_available_skills(self):
        """현재 선택 가능한 스킬 목록 반환 (해금된 스킬만)"""
        available_skills = []
        
        # 스매셔 스킬트리 처리
        if self.selected_tree == "smasher" and hasattr(self, 'smasher_skills'):
            for skill in self.smasher_skills.skills:
                is_available = False
                
                # 선행 스킬이 없으면 항상 선택 가능
                if skill.get("requires") is None and skill.get("requires_or") is None:
                    is_available = True
                else:
                    # AND 조건 선행 스킬 확인
                    if skill.get("requires"):
                        required_skill = self.smasher_skills.skills_dict.get(skill["requires"])
                        if required_skill and required_skill["current_level"] > 0:
                            is_available = True
                    
                    # OR 조건 선행 스킬 확인
                    if skill.get("requires_or") and not is_available:
                        for req_id in skill.get("requires_or"):
                            required_skill = self.smasher_skills.skills_dict.get(req_id)
                            if required_skill and required_skill["current_level"] > 0:
                                is_available = True
                                break
                
                if is_available:
                    available_skills.append(skill["id"])
            
            return available_skills
        
        # 기존 스킬트리 처리
        tree_data = SKILL_TREES[self.selected_tree]
        tree_tp_total = self.skill_system.get_tree_total(self.selected_tree)

        for skill in tree_data["skills"]:
            is_available = False
            
            # 선행 스킬이 없으면 항상 선택 가능
            if skill.get("requires") is None and skill.get("requires_or") is None:
                is_available = True
            else:
                # AND 조건 선행 스킬 확인
                if skill.get("requires"):
                    requires = skill.get("requires")
                    if isinstance(requires, list):
                        # 여러 선행 스킬이 모두 필요
                        if all(self.skill_system.get_skill_level(req_id) > 0 for req_id in requires):
                            is_available = True
                    else:
                        # 단일 선행 스킬
                        if self.skill_system.get_skill_level(requires) > 0:
                            is_available = True
                
                # OR 조건 선행 스킬 확인
                if skill.get("requires_or") and not is_available:
                    # 하나 이상의 스킬이 있으면 해금
                    if any(self.skill_system.get_skill_level(req_id) > 0 for req_id in skill.get("requires_or")):
                        is_available = True
            
            # 누적 TP 조건 확인
            if is_available and skill.get("total_tp_required"):
                if tree_tp_total < skill.get("total_tp_required", 0):
                    is_available = False
            
            if is_available:
                available_skills.append(skill["id"])
        
        return available_skills

    def find_nearest_skill(self, current_skill_id, direction):
        """현재 스킬에서 특정 방향으로 가장 가까운 스킬 찾기 (해금 여부 상관없이 모든 스킬)"""
        if current_skill_id not in self.skill_positions:
            return None
            
        current_pos = self.skill_positions[current_skill_id]
        
        best_skill = None
        best_distance = float('inf')
        
        # 스매셔 스킬트리 처리
        if self.selected_tree == "smasher" and hasattr(self, 'smasher_skills'):
            skills_to_check = self.smasher_skills.skills
        else:
            tree_data = SKILL_TREES[self.selected_tree]
            skills_to_check = tree_data["skills"]
        
        # 해금 여부에 상관없이 모든 스킬을 대상으로 검색
        for skill in skills_to_check:
            skill_id = skill["id"]
            if skill_id == current_skill_id:
                continue
                
            if skill_id not in self.skill_positions:
                continue
                
            pos = self.skill_positions[skill_id]
            
            # 방향에 따른 필터링
            if direction == "up" and pos["y"] >= current_pos["y"]:
                continue
            elif direction == "down" and pos["y"] <= current_pos["y"]:
                continue
            elif direction == "left" and pos["x"] >= current_pos["x"]:
                continue
            elif direction == "right" and pos["x"] <= current_pos["x"]:
                continue
            
            # 거리 계산 (맨하탄 거리 사용)
            distance = abs(pos["x"] - current_pos["x"]) + abs(pos["y"] - current_pos["y"])
            
            if distance < best_distance:
                best_distance = distance
                best_skill = skill_id
        
        return best_skill

    def get_current_skill_id(self):
        """현재 선택된 스킬 ID 반환"""
        # 스매셔 탭 처리
        if self.selected_tree == "smasher" and hasattr(self, 'smasher_skills'):
            if 0 <= self.selected_skill_index < len(self.smasher_skills.skills):
                return self.smasher_skills.skills[self.selected_skill_index]["id"]
            return None
        
        tree_data = SKILL_TREES[self.selected_tree]
        if 0 <= self.selected_skill_index < len(tree_data["skills"]):
            return tree_data["skills"][self.selected_skill_index]["id"]
        return None

    def set_selected_skill_by_id(self, skill_id):
        """스킬 ID로 선택된 스킬 설정"""
        # 스매셔 탭 처리
        if self.selected_tree == "smasher" and hasattr(self, 'smasher_skills'):
            for i, skill in enumerate(self.smasher_skills.skills):
                if skill["id"] == skill_id:
                    self.selected_skill_index = i
                    return True
            return False
            
        tree_data = SKILL_TREES[self.selected_tree]
        for i, skill in enumerate(tree_data["skills"]):
            if skill["id"] == skill_id:
                self.selected_skill_index = i
                if ACADEMY_DEBUG:
                    print(f"[AcademyUI] select tree={self.selected_tree} idx={i} skill={skill_id}")
                return True
        return False

    def _clamp_selection_to_current_tree(self):
        """현재 선택된 스킬 인덱스를 해당 탭 범위로 보정"""
        if self.selected_tree == "smasher" and hasattr(self, 'smasher_skills'):
            skill_count = len(self.smasher_skills.skills)
        else:
            tree_data = SKILL_TREES.get(self.selected_tree)
            skill_count = len(tree_data["skills"]) if tree_data else 0

        if skill_count == 0:
            self.selected_skill_index = 0
            return

        if self.selected_skill_index >= skill_count:
            self.selected_skill_index = skill_count - 1
        elif self.selected_skill_index < 0:
            self.selected_skill_index = 0

    def create_skill_icon(self, skill_data, level, max_level, size=60):
        """스킬 아이콘 생성"""
        icon = pygame.Surface((size, size), pygame.SRCALPHA)
        
        # 배경색 (레벨에 따른 밝기 조절)
        if level == 0:
            bg_color = (60, 60, 60)  # 어두운 회색 (미학습)
        elif level == max_level:
            bg_color = skill_data["icon_color"]  # 최대 레벨 (밝은 색)
        else:
            # 부분 학습 (중간 밝기)
            base_color = skill_data["icon_color"]
            factor = 0.3 + (level / max_level) * 0.7
            bg_color = tuple(int(c * factor) for c in base_color)
        
        # 원형 배경
        pygame.draw.circle(icon, bg_color, (size//2, size//2), size//2 - 2)
        
        # 테두리
        is_master = (max_level == 5 and level == 5)  # 레벨 6 보너스 받는 마스터
        is_maxed = (level == max_level)  # 최대 레벨 도달 (모든 스킬)
        
        if is_master:
            # 마스터 스킬은 황금색 테두리와 광채 효과 (레벨 6 보너스)
            pygame.draw.circle(icon, (255, 215, 0), (size//2, size//2), size//2 - 2, 3)  # 황금색 두꺼운 테두리
            pygame.draw.circle(icon, (255, 255, 150), (size//2, size//2), size//2 - 4, 1)  # 내부 광채
        elif is_maxed:
            # 일반 MAX 스킬은 은색 테두리 (보너스 없음)
            pygame.draw.circle(icon, (220, 220, 220), (size//2, size//2), size//2 - 2, 3)  # 은색 두꺼운 테두리
            pygame.draw.circle(icon, (240, 240, 240), (size//2, size//2), size//2 - 4, 1)  # 내부 광채
        else:
            border_color = (255, 255, 255) if level > 0 else (100, 100, 100)
            pygame.draw.circle(icon, border_color, (size//2, size//2), size//2 - 2, 2)
        
        # 스킬별 아이콘 그리기
        self.draw_skill_symbol(icon, skill_data["id"], size, level > 0)
        
        # MAX 스킬에 별 그리기
        is_master = (max_level == 5 and level == 5)  # 레벨 6 보너스 받는 마스터
        is_maxed = (level == max_level)  # 최대 레벨 도달 (모든 스킬)
        
        if is_master or is_maxed:
            # 양옆에 별 그리기
            star_color = (255, 215, 0) if is_master else (220, 220, 220)  # 마스터는 황금색, 일반 MAX는 은색
            
            # 왼쪽 별 (5각 별)
            star_points_left = []
            star_x, star_y = size//2 - 18, size - 10
            star_size = 5
            for i in range(10):
                angle = (i * 36 - 90) * 3.14159 / 180
                if i % 2 == 0:
                    x = star_x + star_size * 1.0 * math.cos(angle)
                    y = star_y + star_size * 1.0 * math.sin(angle)
                else:
                    x = star_x + star_size * 0.5 * math.cos(angle)
                    y = star_y + star_size * 0.5 * math.sin(angle)
                star_points_left.append((x, y))
            pygame.draw.polygon(icon, star_color, star_points_left)
            
            # 오른쪽 별 (5각 별)
            star_points_right = []
            star_x, star_y = size//2 + 18, size - 10
            for i in range(10):
                angle = (i * 36 - 90) * 3.14159 / 180
                if i % 2 == 0:
                    x = star_x + star_size * 1.0 * math.cos(angle)
                    y = star_y + star_size * 1.0 * math.sin(angle)
                else:
                    x = star_x + star_size * 0.5 * math.cos(angle)
                    y = star_y + star_size * 0.5 * math.sin(angle)
                star_points_right.append((x, y))
            pygame.draw.polygon(icon, star_color, star_points_right)
        
        # 레벨 표시 제거 - 이제 게이지로 표시
        
        return icon
    
    def draw_skill_symbol(self, surface, skill_id, size, unlocked):
        """스킬별 심볼 그리기"""
        import math
        center_x, center_y = size // 2, size // 2
        color = (255, 255, 255) if unlocked else (150, 150, 150)
        skill_data = self.skill_system.get_skill_data(skill_id)
        current_level = self.skill_system.get_skill_level(skill_id)
        max_level = skill_data.get("max_level", 1) if skill_data else 1
        
        # 스매셔 스킬트리는 아이콘을 그리지 않음 (빈 상태로 유지)
        if skill_id in ["heavy_impact", "speed_charge", "burst_wave", "power_break", 
                       "dual_smash", "impact_zone", "ultra_charge", "berserker", 
                       "chain_impact", "final_smash", "omega_burst", "devastator"]:
            # 스매셔 스킬은 아이콘을 그리지 않고 빈 상태로 둠
            return
        
        # 대쉬 스킬트리 아이콘들
        if skill_id == "dash_lightweight":
            # 🪶 깃털 (경량화)
            # 깃털 중심축
            pygame.draw.line(surface, color, (center_x, center_y - 12), (center_x, center_y + 8), 2)
            # 깃털 날개
            for i in range(5):
                y_offset = -8 + i * 3
                x_width = 8 - abs(i - 2) * 2
                pygame.draw.line(surface, color, (center_x - x_width, center_y + y_offset), 
                               (center_x, center_y + y_offset), 1)
                pygame.draw.line(surface, color, (center_x + x_width, center_y + y_offset), 
                               (center_x, center_y + y_offset), 1)
        
        elif skill_id == "dash_module_control":
            # ⚙️ 기어 (모듈제어)
            pygame.draw.circle(surface, color, (center_x, center_y), 8, 2)
            # 기어 톱니
            import math
            for i in range(6):
                angle = i * math.pi / 3
                x1 = center_x + 8 * math.cos(angle)
                y1 = center_y + 8 * math.sin(angle)
                x2 = center_x + 11 * math.cos(angle)
                y2 = center_y + 11 * math.sin(angle)
                pygame.draw.line(surface, color, (x1, y1), (x2, y2), 2)
        
        elif skill_id == "dash_jump":
            # 🏃 도약 화살표
            # 위로 향하는 곡선 화살표
            pygame.draw.arc(surface, color, (center_x - 10, center_y - 5, 20, 15), 0, 3.14, 2)
            # 화살표 머리
            pygame.draw.polygon(surface, color, [
                (center_x + 10, center_y - 2),
                (center_x + 8, center_y - 8),
                (center_x + 14, center_y - 6)
            ])
        
        elif skill_id == "dash_battery_pack":
            # 🔋 배터리팩
            pygame.draw.rect(surface, color, (center_x - 6, center_y - 8, 12, 16), 2)
            pygame.draw.rect(surface, color, (center_x - 2, center_y - 10, 4, 2))
            # 충전 표시
            for i in range(3):
                pygame.draw.rect(surface, color, (center_x - 4, center_y - 6 + i * 5, 8, 3))
        
        elif skill_id == "dash_acceleration":
            # 💥 버스트업 - 확장/폭발 효과
            # 중앙 원
            pygame.draw.circle(surface, color, (center_x, center_y), 5, 2)
            # 바깥으로 퍼지는 파동 (3개의 동심원)
            pygame.draw.circle(surface, color, (center_x, center_y), 8, 1)
            pygame.draw.circle(surface, color, (center_x, center_y), 11, 1)
            # 폭발 파편 (8방향)
            import math
            for i in range(8):
                angle = i * math.pi / 4
                x1 = center_x + 6 * math.cos(angle)
                y1 = center_y + 6 * math.sin(angle)
                x2 = center_x + 12 * math.cos(angle)
                y2 = center_y + 12 * math.sin(angle)
                pygame.draw.line(surface, color, (x1, y1), (x2, y2), 2)
        
        elif skill_id == "dash_amplification":
            # ➕ 증폭 (더하기 기호)
            pygame.draw.line(surface, color, (center_x - 8, center_y), (center_x + 8, center_y), 3)
            pygame.draw.line(surface, color, (center_x, center_y - 8), (center_x, center_y + 8), 3)
            # 외곽 원
            pygame.draw.circle(surface, color, (center_x, center_y), 12, 1)
        
        elif skill_id == "dash_spirit":
            # 👻 대쉬 스피릿 (이미 구현됨)
            pygame.draw.circle(surface, color, (center_x, center_y - 5), 8, 2)
            pygame.draw.polygon(surface, color, [(center_x - 8, center_y + 3), 
                                               (center_x, center_y + 10), (center_x + 8, center_y + 3)])
            # 눈 추가
            pygame.draw.circle(surface, color, (center_x - 3, center_y - 5), 2)
            pygame.draw.circle(surface, color, (center_x + 3, center_y - 5), 2)
        
        elif "dash" in skill_id:
            if skill_id == "dash_distance":
                # 화살표 (거리)
                points = [(center_x - 15, center_y), (center_x + 10, center_y), 
                         (center_x + 5, center_y - 5), (center_x + 5, center_y + 5)]
                pygame.draw.polygon(surface, color, points)
            elif skill_id == "dash_cooldown":
                # 시계 (쿨타임)
                pygame.draw.circle(surface, color, (center_x, center_y), 12, 2)
                pygame.draw.line(surface, color, (center_x, center_y), (center_x, center_y - 8), 2)
                pygame.draw.line(surface, color, (center_x, center_y), (center_x + 6, center_y), 2)
            elif skill_id == "dash_stun":
                # 번개 (통제불능)
                points = [(center_x - 5, center_y - 10), (center_x + 2, center_y - 2),
                         (center_x - 2, center_y + 2), (center_x + 5, center_y + 10)]
                pygame.draw.lines(surface, color, False, points, 3)
            elif skill_id == "dash_gauge":
                # 배터리 (게이지)
                pygame.draw.rect(surface, color, (center_x - 8, center_y - 6, 16, 12), 2)
                pygame.draw.rect(surface, color, (center_x + 8, center_y - 3, 3, 6))
            elif skill_id == "dash_spirit":
                # 유령 (스피릿)
                pygame.draw.circle(surface, color, (center_x, center_y - 5), 8, 2)
                pygame.draw.polygon(surface, color, [(center_x - 8, center_y + 3), 
                                                   (center_x, center_y + 10), (center_x + 8, center_y + 3)])
        
        elif skill_id == "item_luck":
            # 🍀 행운 - 네잎클로버 (단색 라인 스타일)
            # 중앙 줄기
            pygame.draw.line(surface, color, (center_x, center_y + 2), (center_x, center_y + 10), 2)
            # 네 개의 잎 (심플한 원형)
            for angle in [45, 135, 225, 315]:
                rad = math.radians(angle)
                lx = center_x + int(8 * math.cos(rad))
                ly = center_y - 2 + int(8 * math.sin(rad))
                # 원형 잎 윤곽선만
                pygame.draw.circle(surface, color, (lx, ly), 4, 2)

        elif skill_id == "item_cooldown_mastery":
            # ⏱️ 숙련 - 스톱워치 (단색 라인 스타일)
            # 시계 본체
            pygame.draw.circle(surface, color, (center_x, center_y), 10, 2)
            # 상단 버튼
            pygame.draw.rect(surface, color, (center_x - 4, center_y - 14, 8, 4), 2)
            # 시침과 분침
            pygame.draw.line(surface, color, (center_x, center_y), (center_x, center_y - 7), 2)
            pygame.draw.line(surface, color, (center_x, center_y), (center_x + 6, center_y + 3), 2)

        elif skill_id == "item_gauge_mastery":
            # 📊 숙달 - 반원 게이지 미터
            radius = 10
            # 반원 테두리 (위쪽 반원 형태)
            pygame.draw.arc(surface, color, (center_x - radius, center_y - radius, radius * 2, radius * 2), 0, math.pi, 2)
            # 게이지 바닥
            pygame.draw.line(surface, color, (center_x - radius, center_y), (center_x + radius, center_y), 2)
            # 눈금 표시
            for angle_deg in (-60, -30, 0, 30, 60):
                angle_rad = math.radians(angle_deg + 90)
                inner = (center_x + (radius - 3) * math.cos(angle_rad), center_y + (radius - 3) * math.sin(angle_rad))
                outer = (center_x + radius * math.cos(angle_rad), center_y + radius * math.sin(angle_rad))
                pygame.draw.line(surface, color, inner, outer, 2)
            # 지침 (포인터)
            pointer_angle = math.radians(150)
            pointer_end = (center_x + (radius - 4) * math.cos(pointer_angle), center_y + (radius - 4) * math.sin(pointer_angle))
            pygame.draw.line(surface, color, (center_x, center_y), pointer_end, 3)
            # 중심 캡
            pygame.draw.circle(surface, color, (center_x, center_y), 2)

        elif skill_id == "item_bag_expansion":
            # 🎒 가방확장 - 백팩 (단색 라인 스타일)
            # 가방 본체
            pygame.draw.rect(surface, color, (center_x - 9, center_y - 5, 18, 14), 2)
            # 가방 뚜껑 (반원)
            pygame.draw.arc(surface, color, (center_x - 9, center_y - 11, 18, 12), math.pi, 2 * math.pi, 2)
            # 가방 주머니 선
            pygame.draw.line(surface, color, (center_x - 6, center_y + 1), (center_x + 6, center_y + 1), 1)
            # 가방 끈 (손잡이)
            pygame.draw.arc(surface, color, (center_x - 5, center_y - 16, 10, 8), 0, math.pi, 2)

        elif skill_id == "item_gamble":
            # 🎲 도박 - 주사위 (단색 라인 스타일)
            # 첫 번째 주사위
            pygame.draw.rect(surface, color, (center_x - 11, center_y - 7, 10, 10), 2)
            # 첫 번째 주사위 점 (3)
            pygame.draw.circle(surface, color, (center_x - 8, center_y - 4), 1)
            pygame.draw.circle(surface, color, (center_x - 6, center_y - 2), 1)
            pygame.draw.circle(surface, color, (center_x - 4, center_y), 1)
            # 두 번째 주사위
            pygame.draw.rect(surface, color, (center_x + 1, center_y - 3, 10, 10), 2)
            # 두 번째 주사위 점 (4)
            pygame.draw.circle(surface, color, (center_x + 3, center_y - 1), 1)
            pygame.draw.circle(surface, color, (center_x + 9, center_y - 1), 1)
            pygame.draw.circle(surface, color, (center_x + 3, center_y + 5), 1)
            pygame.draw.circle(surface, color, (center_x + 9, center_y + 5), 1)

        elif skill_id == "item_recycle":
            # ⚗️ 연금술 - 연금 플라스크 (단색 라인 스타일)
            # 플라스크 몸체 (삼각형 형태)
            base_y = center_y + 9
            neck_height = 6
            body_top = center_y - 2
            flask_points = [
                (center_x - 9, base_y),
                (center_x + 9, base_y),
                (center_x + 5, body_top),
                (center_x - 5, body_top)
            ]
            pygame.draw.polygon(surface, color, flask_points, 2)
            # 목 부분과 코르크
            neck_rect = pygame.Rect(center_x - 4, body_top - neck_height, 8, neck_height)
            pygame.draw.rect(surface, color, neck_rect, 2)
            cork_rect = pygame.Rect(center_x - 6, body_top - neck_height - 4, 12, 4)
            pygame.draw.rect(surface, color, cork_rect, 2)
            # 플라스크 내부 연금 물질 (수평 라인)
            liquid_y = base_y - 5
            pygame.draw.line(surface, color, (center_x - 7, liquid_y), (center_x + 7, liquid_y), 2)
            # 별빛 효과
            star_y = body_top - neck_height - 6
            pygame.draw.line(surface, color, (center_x, star_y - 2), (center_x, star_y + 2), 2)
            pygame.draw.line(surface, color, (center_x - 2, star_y), (center_x + 2, star_y), 2)
            pygame.draw.circle(surface, color, (center_x + 6, star_y + 3), 1)

        elif skill_id == "item_treasure_map":
            # 🗺️ 보물지도 - 지도와 X표시 (단색 라인 스타일)
            # 지도 본체 (펼쳐진 두루마리 형태)
            pygame.draw.rect(surface, color, (center_x - 10, center_y - 7, 20, 14), 2)
            # 지도 롤 (양쪽 끝)
            pygame.draw.line(surface, color, (center_x - 10, center_y - 7), (center_x - 10, center_y + 7), 3)
            pygame.draw.line(surface, color, (center_x + 10, center_y - 7), (center_x + 10, center_y + 7), 3)
            # X 표시 (보물 위치)
            pygame.draw.line(surface, color, (center_x - 3, center_y - 3), (center_x + 3, center_y + 3), 2)
            pygame.draw.line(surface, color, (center_x - 3, center_y + 3), (center_x + 3, center_y - 3), 2)
            # 점선 경로 (보물까지의 길)
            for i in range(3):
                dot_y = center_y - 4 + i * 4
                pygame.draw.circle(surface, color, (center_x - 6, dot_y), 1)

        elif "item" in skill_id:
            # 기타 아이템 스킬은 아직 전용 아이콘이 없음
            return
        
        elif "paddle" in skill_id:
            # 패들 스킬은 아이콘을 그리지 않고 빈 상태로 둠
            return
    
    def show_academy(self):
        """아카데미 메인 화면 표시"""
        running = True
        clock = pygame.time.Clock()
        
        # 초기 선택 설정
        self.update_skill_positions()
        # 스매셔 스킬트리는 첫 번째 스킬 선택
        if self.selected_tree == "smasher" and hasattr(self, 'smasher_skills'):
            if len(self.smasher_skills.skills) > 0:
                self.selected_skill_index = 0
        else:
            # 기존 스킬트리는 선택 가능한 스킬로 설정
            available_skills = self.get_available_skills()
            if available_skills:
                self.set_selected_skill_by_id(available_skills[0])
        
        while running:
            # 애니메이션 업데이트
            self.update_animations()
            
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return "quit"
                elif event.type == pygame.MOUSEBUTTONDOWN:
                    result = self.handle_mouse_click(event.pos)
                    if result:
                        return result
                elif event.type == pygame.MOUSEMOTION:
                    self.handle_mouse_hover(event.pos)
                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        return "back"
                    elif event.key == pygame.K_8:
                        # 디버그 기능: 스킬포인트 99개 생성 (누적 투자는 실제 투자할 때만 증가)
                        self.skill_system.skill_points = 99
                        print(":  99 ! (  TP    )")
                    elif event.key in [pygame.K_LEFT, pygame.K_RIGHT, pygame.K_UP, pygame.K_DOWN] and not self.is_animating:
                        if self.tab_selection_mode:
                            # 탭 선택 모드에서의 키 처리
                            if event.key == pygame.K_LEFT:
                                # 왼쪽 탭으로 이동
                                # 스매셔 캐릭터일 때는 스매셔 탭도 포함
                                if self.selected_character == "smasher":
                                    if self.selected_tree == "item":
                                        self.selected_tree = "dash"
                                    elif self.selected_tree == "paddle":
                                        self.selected_tree = "item"
                                    elif self.selected_tree == "smasher":
                                        self.selected_tree = "paddle"
                                    else:  # dash
                                        self.selected_tree = "smasher"
                                else:
                                    # 일반 캐릭터
                                    if self.selected_tree == "item":
                                        self.selected_tree = "dash"
                                    elif self.selected_tree == "paddle":
                                        self.selected_tree = "item"
                                    else:  # dash
                                        self.selected_tree = "paddle"
                                self._clamp_selection_to_current_tree()
                                self.update_skill_positions()
                            elif event.key == pygame.K_RIGHT:
                                # 오른쪽 탭으로 이동
                                # 스매셔 캐릭터일 때는 스매셔 탭도 포함
                                if self.selected_character == "smasher":
                                    if self.selected_tree == "dash":
                                        self.selected_tree = "item"
                                    elif self.selected_tree == "item":
                                        self.selected_tree = "paddle"
                                    elif self.selected_tree == "paddle":
                                        self.selected_tree = "smasher"
                                    else:  # smasher
                                        self.selected_tree = "dash"
                                else:
                                    # 일반 캐릭터
                                    if self.selected_tree == "dash":
                                        self.selected_tree = "item"
                                    elif self.selected_tree == "item":
                                        self.selected_tree = "paddle"
                                    else:  # paddle
                                        self.selected_tree = "dash"
                                self._clamp_selection_to_current_tree()
                                self.update_skill_positions()
                            elif event.key == pygame.K_DOWN:
                                # 탭 선택 모드 종료하고 스킬로 이동
                                self.tab_selection_mode = False
                                self.update_skill_positions()
                                # 스매셔 스킬트리는 첫 번째 스킬 선택
                                if self.selected_tree == "smasher" and hasattr(self, 'smasher_skills'):
                                    if len(self.smasher_skills.skills) > 0:
                                        self.selected_skill_index = 0
                                else:
                                    # 기존 스킬트리는 선택 가능한 스킬로 이동
                                    available_skills = self.get_available_skills()
                                    if available_skills:
                                        self.set_selected_skill_by_id(available_skills[0])
                                    else:
                                        self.selected_skill_index = 0
                        else:
                            # 스킬 선택 모드에서의 키 처리
                            # 스킬 위치 정보 업데이트
                            self.update_skill_positions()
                            
                            # 현재 선택된 스킬 ID 가져오기
                            current_skill_id = self.get_current_skill_id()
                            tree_data = SKILL_TREES[self.selected_tree]  # tree_data 정의 추가
                            
                            if current_skill_id:
                                # 방향에 따른 이동
                                direction_map = {
                                    pygame.K_LEFT: "left",
                                    pygame.K_RIGHT: "right", 
                                    pygame.K_UP: "up",
                                    pygame.K_DOWN: "down"
                                }
                                
                                direction = direction_map[event.key]
                                next_skill_id = self.find_nearest_skill(current_skill_id, direction)
                                
                                if next_skill_id:
                                    # 선택 가능한 스킬로 이동
                                    self.set_selected_skill_by_id(next_skill_id)
                                elif event.key == pygame.K_UP:
                                    # 위쪽 방향키로 탭 선택 모드로 이동 (최상단 스킬에서만)
                                    # 스매셔 스킬트리 처리
                                    if self.selected_tree == "smasher" and hasattr(self, 'smasher_skills'):
                                        if self.selected_skill_index < len(self.smasher_skills.skills):
                                            current_skill = self.smasher_skills.skills[self.selected_skill_index]
                                            # 최상단 스킬인지 확인 (row 0)
                                            if current_skill.get("row") == 0:
                                                # 탭 선택 모드로 전환
                                                self.tab_selection_mode = True
                                    else:
                                        # 기존 스킬트리 처리
                                        current_skill = tree_data["skills"][self.selected_skill_index]
                                        
                                        # 대쉬 스킬트리에서 최상단 스킬인지 확인 (row 0)
                                        if (self.selected_tree == "dash" and current_skill.get("row") == 0) or \
                                           (self.selected_tree != "dash" and self.selected_skill_index == 0):
                                            # 탭 선택 모드로 전환
                                            self.tab_selection_mode = True
                    elif event.key in [pygame.K_SPACE, pygame.K_RETURN] and not self.is_animating:
                        # 탭 선택 모드가 아닐 때만 스킬 업그레이드
                        if not self.tab_selection_mode:
                            # 스매셔 스킬트리 처리
                            if self.selected_tree == "smasher" and hasattr(self, 'smasher_skills'):
                                if self.selected_skill_index < len(self.smasher_skills.skills):
                                    skill = self.smasher_skills.skills[self.selected_skill_index]
                                    if self.smasher_skills.can_upgrade(skill["id"], self.skill_system.skill_points):
                                        # 스킬 업그레이드
                                        old_level = skill["current_level"]
                                        cost = self.smasher_skills.upgrade_skill(skill["id"])
                                        new_level = skill["current_level"]
                                        
                                        # 스킬 포인트 차감
                                        if cost > 0:
                                            self.skill_system.skill_points -= cost
                                            self.skill_system.save_skill_points()
                                        
                                        # 레벨업 애니메이션 시작
                                        if new_level > old_level:
                                            self.start_levelup_animation(skill["id"])
                                        
                                        # 0→1 전환시 언락 애니메이션
                                        if old_level == 0 and new_level == 1:
                                            self.start_unlock_animation(skill["id"])
                            else:
                                # 기존 스킬트리 처리
                                tree_data = SKILL_TREES[self.selected_tree]
                                if self.selected_skill_index < len(tree_data["skills"]):
                                    skill = tree_data["skills"][self.selected_skill_index]
                                    if self.skill_system.can_upgrade_skill(skill["id"]):
                                        # 스킬 업그레이드 전 레벨 확인
                                        old_level = self.skill_system.get_skill_level(skill["id"])
                                        self.skill_system.upgrade_skill(skill["id"])
                                        new_level = self.skill_system.get_skill_level(skill["id"])
                                        
                                        # 레벨업 애니메이션 시작 (모든 레벨업에서)
                                        if new_level > old_level:
                                            self.start_levelup_animation(skill["id"])
                                        
                                        # 0→1 전환시에만 언락 애니메이션
                                        if old_level == 0 and new_level == 1:
                                            self.start_unlock_animation(skill["id"])  # 내부에서 화살표 애니메이션 포함
                                        
                                        # 누적 TP 업데이트 후 추가 해금 체크 및 애니메이션
                                        self.check_and_animate_unlocked_skills(skill["id"])
            
            self.draw_academy_screen()
            pygame.display.flip()
            clock.tick(60)
        
        return "back"
    
    def handle_click(self, pos):
        """마우스 클릭 처리"""
        x, y = pos
        
        # 스킬 트리 탭 클릭 확인
        tab_y = 60  # draw_academy_screen과 일치
        tab_width = 150
        tab_height = 35
        
        # 스매셔 캐릭터일 경우 탭 개수 조정
        if self.selected_character == "smasher":
            # 스매셔 캐릭터일 때는 모든 탭 표시 (스매셔 포함)
            tabs_to_show = list(SKILL_TREES.items())
        else:
            # 일반 캐릭터일 때는 스매셔 탭 제외
            tabs_to_show = [(k, v) for k, v in SKILL_TREES.items() if k != "smasher"]
        
        total_tab_width = len(tabs_to_show) * tab_width + (len(tabs_to_show) - 1) * 10
        start_x = (self.width - total_tab_width) // 2
        
        for i, (tree_id, tree_data) in enumerate(tabs_to_show):
            tab_x = start_x + i * (tab_width + 10)
            tab_rect = pygame.Rect(tab_x, tab_y, tab_width, tab_height)
            if tab_rect.collidepoint(pos):
                self.selected_tree = tree_id
                self._clamp_selection_to_current_tree()
                self.update_skill_positions()
                return None
        
        # 스킬 아이콘 클릭 확인
        if self.selected_tree == "smasher" and self.selected_character == "smasher":
            # 스매셔 스킬 클릭 처리
            if hasattr(self, 'smasher_skills'):
                clicked_skill = self.smasher_skills.handle_click(pos, 50, 110, self.skill_system.skill_points)
                if clicked_skill:
                    # 스킬 업그레이드
                    cost = self.smasher_skills.upgrade_skill(clicked_skill)
                    if cost > 0:
                        self.skill_system.skill_points -= cost
                        self.skill_system.register_manual_investment("smasher", cost)
                    return None
        elif self.selected_tree in SKILL_TREES:
            tree_data = SKILL_TREES[self.selected_tree]
            start_y = 200
            skill_size = 80
            margin = 20
            
            for i, skill in enumerate(tree_data["skills"]):
                skill_x = self.width // 2 - skill_size // 2
                skill_y = start_y + i * (skill_size + margin)
                skill_rect = pygame.Rect(skill_x, skill_y, skill_size, skill_size)
                
                if skill_rect.collidepoint(pos):
                    if self.skill_system.can_upgrade_skill(skill["id"]):
                        # 스킬 업귵58이드 전 레벨 확인
                        old_level = self.skill_system.get_skill_level(skill["id"])
                        self.skill_system.upgrade_skill(skill["id"])
                        new_level = self.skill_system.get_skill_level(skill["id"])
                        
                        # 레벨이 올랐으면 애니메이션 시작
                        if new_level > old_level:
                            # 레벨업 애니메이션 시작 (모든 레벨업에서)
                            self.start_levelup_animation(skill["id"])
                            
                            # 0→1 전환시에만 언락 애니메이션
                            if old_level == 0:
                                self.start_unlock_animation(skill["id"])
                    return None
        
        # 닫기 버튼 클릭 확인
        close_button = pygame.Rect(self.width - 100, 20, 80, 40)
        if close_button.collidepoint(pos):
            return "back"
        
        return None
    
    def draw_academy_screen(self):
        """아카데미 화면 그리기 - 사이버펑크 테마"""
        import math
        import random
        
        # 사이버펑크 그라데이션 배경
        for y in range(self.height):
            ratio = y / self.height
            r = int(10 + ratio * 20)
            g = int(20 + ratio * 30)
            b = int(30 + ratio * 50)
            pygame.draw.line(self.screen, (r, g, b), (0, y), (self.width, y))
        
        # 홀로그램 격자 패턴
        grid_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        grid_color = (0, 255, 255, 20)
        for x in range(0, self.width, 30):
            pygame.draw.line(grid_surf, grid_color, (x, 0), (x, self.height))
        for y in range(0, self.height, 30):
            pygame.draw.line(grid_surf, grid_color, (0, y), (self.width, y))
        self.screen.blit(grid_surf, (0, 0))
        
        # 네온 파티클 효과
        if not hasattr(self, 'neon_particles'):
            self.neon_particles = []
            for _ in range(20):
                self.neon_particles.append({
                    'x': random.randint(0, self.width),
                    'y': random.randint(0, self.height),
                    'speed': random.uniform(0.2, 0.8),
                    'size': random.randint(1, 3),
                    'alpha': random.randint(50, 150)
                })
        
        # 파티클 업데이트 및 그리기
        for particle in self.neon_particles:
            particle['y'] -= particle['speed']
            if particle['y'] < 0:
                particle['y'] = self.height
                particle['x'] = random.randint(0, self.width)
            
            alpha = int(particle['alpha'] * (0.5 + 0.5 * math.sin(pygame.time.get_ticks() * 0.005)))
            size = particle['size']
            
            for i in range(2):
                glow_surf = pygame.Surface((size * (3-i), size * (3-i)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (0, 255, 255, alpha // (i+1)), 
                                 (size * (3-i) // 2, size * (3-i) // 2), size * (3-i) // 2)
                self.screen.blit(glow_surf, (particle['x'] - size * (3-i) // 2, 
                                            particle['y'] - size * (3-i) // 2))
        
        # 네온 제목
        title_text = "◈ NEURAL UPGRADE SYSTEM ◈"
        
        # 글로우 효과를 위한 여러 레이어
        for i in range(3):
            alpha = 100 - i * 30
            glow_text = self.font_large.render(title_text, True, (0, 255, 255))
            glow_text.set_alpha(alpha)
            glow_rect = glow_text.get_rect(center=(self.width // 2 - i, 30 - i))
            self.screen.blit(glow_text, glow_rect)
        
        # 메인 제목
        title_text_surf = self.font_large.render(title_text, True, (255, 255, 255))
        title_rect = title_text_surf.get_rect(center=(self.width // 2, 30))
        self.screen.blit(title_text_surf, title_rect)
        
        # 스킬 포인트 이펙트 업데이트 및 렌더링
        self.update_sp_effect()
        self.draw_sp_effect()
        
        # Star Point UI (오리지널 스타일)
        star_x = self.width - 80
        star_y = 25
        star_size = 12
        display_size = star_size * self.sp_scale_factor

        if self.sp_glow_alpha > 0:
            glow_radius = int(display_size * 2)
            for i in range(3):
                glow_alpha = min(30, int(self.sp_glow_alpha) // (i + 1))
                glow_surf = pygame.Surface((glow_radius * 4, glow_radius * 4), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (255, 255, 100, glow_alpha),
                                   (glow_radius * 2, glow_radius * 2), glow_radius - i * 3)
                self.screen.blit(glow_surf, (star_x - glow_radius * 2, star_y - glow_radius * 2))

        star_points = []
        for i in range(10):
            angle = -math.pi / 2 + (i * math.pi / 5)
            radius = display_size if i % 2 == 0 else display_size * 0.5
            px = star_x + radius * math.cos(angle)
            py = star_y + radius * math.sin(angle)
            star_points.append((px, py))

        pygame.draw.polygon(self.screen, (255, 255, 100), star_points)
        pygame.draw.polygon(self.screen, (255, 215, 0), star_points, 2)

        gloss_points = []
        for i in range(10):
            angle = -math.pi / 2 + (i * math.pi / 5)
            radius = display_size * 0.3 if i % 2 == 0 else display_size * 0.15
            px = star_x + radius * math.cos(angle)
            py = star_y - 2 + radius * math.sin(angle)
            gloss_points.append((px, py))
        pygame.draw.polygon(self.screen, (255, 255, 200, 180), gloss_points)

        sp_text = self.font_medium.render(f"{self.skill_system.skill_points}", True, (255, 255, 100))
        sp_rect = sp_text.get_rect(midleft=(star_x + display_size + 20, star_y))
        self.screen.blit(sp_text, sp_rect)

        total_sp_text = self.font_small.render(f"누적 투자 TP (전체): {self.skill_system.total_invested_points}", True, (150, 200, 255))
        total_sp_rect = total_sp_text.get_rect(topright=(self.width - 20, sp_rect.bottom + 5))
        self.screen.blit(total_sp_text, total_sp_rect)

        tree_label = SKILL_TREES.get(self.selected_tree, {}).get("name", self.selected_tree)
        tree_tp_total = self.skill_system.get_tree_total(self.selected_tree)
        tree_sp_text = self.font_small.render(f"{tree_label} 누적 ★{tree_tp_total}", True, (150, 200, 255))
        tree_sp_rect = tree_sp_text.get_rect(topright=(self.width - 20, total_sp_rect.bottom + 5))
        self.screen.blit(tree_sp_text, tree_sp_rect)
        
        # 조작 안내
        control_text = self.font_small.render("←→: 탭 전환 | ↑↓: 스킬 선택 | Space: 업그레이드 | ESC: 닫기", True, (150, 150, 150))
        control_rect = control_text.get_rect(center=(self.width // 2, self.height - 20))
        self.screen.blit(control_text, control_rect)
        
        # 스킬 트리 탭 (크기 축소)
        tab_y = 60
        tab_width = 150
        tab_height = 35
        
        # 스매셔 캐릭터일 경우 탭 개수 조정
        # 강제로 스매셔 모드로 설정 (테스트)
        self.selected_character = "smasher"
        
        if self.selected_character == "smasher":
            # 스매셔 캐릭터일 때는 모든 탭 표시 (스매셔 포함)
            tabs_to_show = list(SKILL_TREES.items())
        else:
            # 일반 캐릭터일 때는 스매셔 탭 제외
            tabs_to_show = [(k, v) for k, v in SKILL_TREES.items() if k != "smasher"]
        
        total_tab_width = len(tabs_to_show) * tab_width + (len(tabs_to_show) - 1) * 10
        start_x = (self.width - total_tab_width) // 2
        
        for i, (tree_id, tree_data) in enumerate(tabs_to_show):
            tab_x = start_x + i * (tab_width + 10)
            tab_rect = pygame.Rect(tab_x, tab_y, tab_width, tab_height)
            
            # 탭 색상
            if tree_id == self.selected_tree:
                tab_color = tree_data["color"]
                border_color = (255, 255, 255)
                # 탭 선택 모드일 때 추가 하이라이트
                if self.tab_selection_mode:
                    border_color = (255, 255, 0)  # 노란색 테두리
                    border_width = 4
                else:
                    border_width = 2
            else:
                tab_color = (60, 60, 60)
                border_color = (150, 150, 150)
                border_width = 2
            
            pygame.draw.rect(self.screen, tab_color, tab_rect)
            pygame.draw.rect(self.screen, border_color, tab_rect, border_width)
            
            # 탭 선택 모드일 때 현재 선택된 탭에 추가 효과
            if self.tab_selection_mode and tree_id == self.selected_tree:
                # 반짝이는 효과
                glow_surface = pygame.Surface((tab_width + 8, tab_height + 8), pygame.SRCALPHA)
                glow_color = (*border_color, 100)  # 반투명
                pygame.draw.rect(glow_surface, glow_color, (0, 0, tab_width + 8, tab_height + 8), 4)
                self.screen.blit(glow_surface, (tab_x - 4, tab_y - 4))
            
            # 탭 텍스트
            tab_text = self.font_small.render(tree_data["name"], True, (255, 255, 255))
            tab_text_rect = tab_text.get_rect(center=tab_rect.center)
            self.screen.blit(tab_text, tab_text_rect)
            
            # 탭 번호 표시
            num_text = self.font_small.render(f"{i+1}", True, (255, 255, 100))
            num_rect = num_text.get_rect(topleft=(tab_x + 5, tab_y + 2))
            self.screen.blit(num_text, num_rect)
        
        # 선택된 스킬 트리 표시
        if self.selected_tree == "smasher" and self.selected_character == "smasher":
            # 스매셔 스킬탭 그리기
            self.draw_smasher_skill_tree()
        else:
            self.draw_skill_tree()
    
    def draw_smasher_skill_tree(self):
        """스매셔 전용 스킬트리 그리기 - 아이콘과 화살표를 모두 제거하고 설명 패널만 표시"""
        if not hasattr(self, 'smasher_skills'):
            return
        
        # 우측 설명 패널만 그리기
        self.draw_smasher_skill_description_panel()
    
    def create_smasher_skill_icon(self, skill_data, level, max_level, size=60):
        """스매셔 스킬 아이콘 생성 - 빈 아이콘만 반환"""
        icon = pygame.Surface((size, size), pygame.SRCALPHA)
        # 아무것도 그리지 않고 빈 Surface 반환
        return icon
    
    def draw_smasher_skill_symbol(self, icon, skill_id, size, active):
        """스매셔 스킬 심볼 그리기 - 아무것도 그리지 않음"""
        pass  # 스킬 아이콘 내부를 비워둠
    
    def draw_smasher_skill_description_panel(self):
        """스매셔 스킬 설명 패널 그리기 - 대쉬와 동일한 스타일"""
        if not self.tab_selection_mode and self.selected_skill_index < len(self.smasher_skills.skills):
            selected_skill = self.smasher_skills.skills[self.selected_skill_index]
            
            # 우측 패널 영역
            panel_x = self.width - 180
            panel_y = 150
            panel_width = 160
            panel_height = 400
            
            # 패널 배경 (사이버펑크 스타일)
            panel_surface = pygame.Surface((panel_width, panel_height), pygame.SRCALPHA)
            pygame.draw.rect(panel_surface, (0, 20, 40, 200), (0, 0, panel_width, panel_height))
            pygame.draw.rect(panel_surface, (0, 255, 255, 100), (0, 0, panel_width, panel_height), 2)
            
            # 코너 장식
            corner_size = 10
            corners = [
                (0, 0), (panel_width - corner_size, 0),
                (0, panel_height - corner_size), (panel_width - corner_size, panel_height - corner_size)
            ]
            for cx, cy in corners:
                pygame.draw.lines(panel_surface, (0, 255, 255), False, 
                                [(cx, cy + corner_size), (cx, cy), (cx + corner_size, cy)], 2)
            
            self.screen.blit(panel_surface, (panel_x, panel_y))
            
            # 스킬 이름
            name_color = selected_skill["icon_color"]
            name_surf = self.font_large.render(selected_skill["name"], True, name_color)
            name_rect = name_surf.get_rect(centerx=panel_x + panel_width//2, y=panel_y + 20)
            self.screen.blit(name_surf, name_rect)
            
            # 레벨 게이지 표시 (이름 아래)
            gauge_y = panel_y + 55
            gauge_x = panel_x + (panel_width - 120) // 2  # 중앙 정렬
            self.draw_skill_level_gauge(selected_skill, gauge_x, gauge_y, 120, 20)
            
            # 구분선 (게이지 아래로 이동)
            pygame.draw.line(self.screen, (0, 255, 255, 100), 
                           (panel_x + 10, panel_y + 85), 
                           (panel_x + panel_width - 10, panel_y + 85), 1)
            
            # 스킬 설명
            desc_y = panel_y + 105
            desc_lines = selected_skill["description"].split("\n")
            for line in desc_lines:
                # 줄 바꿈 처리
                words = line.split()
                current_line = ""
                for word in words:
                    test_line = current_line + " " + word if current_line else word
                    if self.font_small.size(test_line)[0] <= panel_width - 20:
                        current_line = test_line
                    else:
                        if current_line:
                            desc_surf = self.font_small.render(current_line, True, (230, 230, 230))
                            self.screen.blit(desc_surf, (panel_x + 10, desc_y))
                            desc_y += 20
                        current_line = word
                
                if current_line:
                    desc_surf = self.font_small.render(current_line, True, (230, 230, 230))
                    self.screen.blit(desc_surf, (panel_x + 10, desc_y))
                    desc_y += 25
            
            # 현재 효과
            current_level = selected_skill["current_level"]
            if current_level > 0:
                pygame.draw.line(self.screen, (0, 255, 255, 100), 
                               (panel_x + 10, desc_y + 10), 
                               (panel_x + panel_width - 10, desc_y + 10), 1)
                
                effect_value = current_level * selected_skill["effect_per_level"]
                
                # 스킬별 효과 표시
                if selected_skill["id"] in ["smash_power", "smash_charge", "smash_critical", "smash_speed", "smash_shield", "mega_smash"]:
                    effect_text = f"현재: {effect_value*100:.0f}%"
                else:
                    effect_text = f"현재: {effect_value:.0f}"
                
                effect_surf = self.font_medium.render(effect_text, True, (100, 255, 100))
                self.screen.blit(effect_surf, (panel_x + 10, desc_y + 25))
            
            # 업그레이드 정보
            if current_level < selected_skill["max_level"]:
                cost_y = panel_y + panel_height - 80
                
                # 비용
                cost_text = f"비용: {selected_skill['cost']} TP"
                can_upgrade = self.smasher_skills.can_upgrade(selected_skill["id"], self.skill_system.skill_points)
                cost_color = (255, 255, 100) if can_upgrade else (150, 150, 150)
                cost_surf = self.font_medium.render(cost_text, True, cost_color)
                self.screen.blit(cost_surf, (panel_x + 10, cost_y))
                
                # 다음 레벨 효과
                next_effect = (current_level + 1) * selected_skill["effect_per_level"]
                if selected_skill["id"] in ["smash_power", "smash_charge", "smash_critical", "smash_speed", "smash_shield", "mega_smash"]:
                    next_text = f"다음: {next_effect*100:.0f}%"
                else:
                    next_text = f"다음: {next_effect:.0f}"
                
                next_surf = self.font_small.render(next_text, True, (150, 150, 255))
                self.screen.blit(next_surf, (panel_x + 10, cost_y + 25))
                
                # Space 키 안내
                if can_upgrade:
                    space_text = "[SPACE] 업그레이드"
                    space_surf = self.font_small.render(space_text, True, (255, 255, 100))
                    space_rect = space_surf.get_rect(centerx=panel_x + panel_width//2, y=cost_y + 50)
                    self.screen.blit(space_surf, space_rect)
            else:
                # MAX 레벨 표시
                max_text = "MAX LEVEL"
                max_color = (255, 215, 0) if selected_skill["max_level"] == 5 else (220, 220, 220)
                max_surf = self.font_large.render(max_text, True, max_color)
                max_rect = max_surf.get_rect(centerx=panel_x + panel_width//2, y=panel_y + panel_height - 50)
                self.screen.blit(max_surf, max_rect)

    def draw_tree_summary_text(self, tree_id: str):
        """현재 선택된 탭에 대한 요약 문구 표시"""
        summary = TREE_SUMMARIES.get(tree_id)
        if not summary:
            return

        lines = self._wrap_text_lines(summary, self.font_small, 420)
        base_x = 50
        base_y = 110
        for line in lines:
            text_surf = self.font_small.render(line, True, (160, 200, 255))
            self.screen.blit(text_surf, (base_x, base_y))
            base_y += 18

    def draw_skill_tree(self):
        """선택된 스킬트리 그리기"""
        if self.selected_tree == "smasher":
            # 스매셔 탭이 선택되었지만 스매셔 캐릭터가 아닌 경우 대시 탭으로 변경
            self.selected_tree = "dash"
            self._clamp_selection_to_current_tree()
        tree_data = SKILL_TREES[self.selected_tree]
        self.draw_tree_summary_text(self.selected_tree)

        # 모든 스킬트리를 트리 구조로 표시 (아이템과 패들도 포함)
        if self.selected_tree == "dash":
            self.draw_dash_skill_tree(tree_data)
        elif self.selected_tree in ["item", "paddle"]:
            self.draw_tree_skill_tree(tree_data)
        else:
            self.draw_linear_skill_tree(tree_data)

        if self.selected_tree in {"dash", "item", "paddle"}:
            self.draw_skill_description(tree_data)
    

    def draw_tree_skill_tree(self, tree_data):
        """아이템/패들 스킬트리를 대쉬와 동일한 스타일로 렌더링"""
        self._draw_branch_skill_tree(tree_data, cost_scaling=False)

    def draw_dash_skill_tree(self, tree_data):
        """대쉬 스킬트리를 트리 구조로 그리기"""
        self._draw_branch_skill_tree(tree_data, cost_scaling=True)

    def _draw_branch_skill_tree(self, tree_data, cost_scaling):
        skill_size = 60
        row_spacing = 140
        col_spacing = 200

        tree_width = col_spacing * 2
        available_width = self.width - 190
        start_x = (available_width - tree_width) // 2 + 30
        start_y = 160

        skill_positions: dict[str, tuple[int, int]] = {}
        for skill in tree_data["skills"]:
            row = skill["row"]
            col = skill["col"]
            if col == 0.5:
                x = start_x + col_spacing // 2
            else:
                x = start_x + int(col) * col_spacing
            y = start_y + row * row_spacing
            skill_positions[skill["id"]] = (x, y)

        for skill in tree_data["skills"]:
            current_pos = skill_positions[skill["id"]]
            tree_id_for_skill = self.skill_system.get_tree_id_for_skill(skill["id"]) or self.selected_tree
            tree_tp_total = self.skill_system.get_tree_total(tree_id_for_skill)
            tp_requirement = skill.get("total_tp_required", 0)
            tp_met = tree_tp_total >= tp_requirement

            requires = skill.get("requires")
            if requires:
                if isinstance(requires, list):
                    for required_skill in requires:
                        if required_skill in skill_positions:
                            required_pos = skill_positions[required_skill]
                            required_level = self.skill_system.get_skill_level(required_skill)
                            line_color = (100, 255, 100) if (required_level > 0 and tp_met) else (100, 100, 100)
                            pygame.draw.line(
                                self.screen,
                                line_color,
                                (required_pos[0] + skill_size // 2, required_pos[1] + skill_size),
                                (current_pos[0] + skill_size // 2, current_pos[1]),
                                3,
                            )
                            pygame.draw.polygon(
                                self.screen,
                                line_color,
                                [
                                    (current_pos[0] + skill_size // 2, current_pos[1]),
                                    (current_pos[0] + skill_size // 2 - 8, current_pos[1] - 15),
                                    (current_pos[0] + skill_size // 2 + 8, current_pos[1] - 15),
                                ],
                            )
                            self.draw_arrow_animation(required_skill, skill["id"])
                else:
                    if requires in skill_positions:
                        required_pos = skill_positions[requires]
                        required_level = self.skill_system.get_skill_level(requires)
                        line_color = (100, 255, 100) if (required_level > 0 and tp_met) else (100, 100, 100)
                        pygame.draw.line(
                            self.screen,
                            line_color,
                            (required_pos[0] + skill_size // 2, required_pos[1] + skill_size),
                            (current_pos[0] + skill_size // 2, current_pos[1]),
                            3,
                        )
                        pygame.draw.polygon(
                            self.screen,
                            line_color,
                            [
                                (current_pos[0] + skill_size // 2, current_pos[1]),
                                (current_pos[0] + skill_size // 2 - 8, current_pos[1] - 15),
                                (current_pos[0] + skill_size // 2 + 8, current_pos[1] - 15),
                            ],
                        )
                        self.draw_arrow_animation(requires, skill["id"])

            requires_or = skill.get("requires_or")
            if requires_or:
                for required_skill in requires_or:
                    if required_skill in skill_positions:
                        required_pos = skill_positions[required_skill]
                        required_level = self.skill_system.get_skill_level(required_skill)
                        line_color = (100, 255, 100) if (required_level > 0 and tp_met) else (100, 100, 100)
                        pygame.draw.line(
                            self.screen,
                            line_color,
                            (required_pos[0] + skill_size // 2, required_pos[1] + skill_size),
                            (current_pos[0] + skill_size // 2, current_pos[1]),
                            3,
                        )
                        pygame.draw.polygon(
                            self.screen,
                            line_color,
                            [
                                (current_pos[0] + skill_size // 2, current_pos[1]),
                                (current_pos[0] + skill_size // 2 - 8, current_pos[1] - 15),
                                (current_pos[0] + skill_size // 2 + 8, current_pos[1] - 15),
                            ],
                        )
                        self.draw_arrow_animation(required_skill, skill["id"])

        for i, skill in enumerate(tree_data["skills"]):
            skill_x, skill_y = skill_positions[skill["id"]]

            if i == self.selected_skill_index and not self.tab_selection_mode:
                highlight_rect = pygame.Rect(skill_x - 5, skill_y - 5, skill_size + 10, skill_size + 10)
                pygame.draw.rect(self.screen, (100, 100, 150, 50), highlight_rect)
                pygame.draw.rect(self.screen, (255, 255, 255), highlight_rect, 2)

            current_level = self.skill_system.get_skill_level(skill["id"])
            max_level = skill["max_level"]
            tree_id_for_skill = self.skill_system.get_tree_id_for_skill(skill["id"]) or self.selected_tree
            tree_tp_total = self.skill_system.get_tree_total(tree_id_for_skill)

            if i == self.selected_skill_index and not self.tab_selection_mode:
                pulse = abs(math.sin(pygame.time.get_ticks() * 0.005)) * 0.5 + 0.5
                select_size = skill_size + int(8 + pulse * 5)
                pygame.draw.circle(
                    self.screen,
                    (0, 255, 255),
                    (skill_x + skill_size // 2, skill_y + skill_size // 2),
                    select_size,
                    3,
                )
                angle = pygame.time.get_ticks() * 0.002
                hex_points = []
                for j in range(6):
                    hex_angle = angle + j * math.pi / 3
                    hx = skill_x + skill_size // 2 + (skill_size + 12) * math.cos(hex_angle)
                    hy = skill_y + skill_size // 2 + (skill_size + 12) * math.sin(hex_angle)
                    hex_points.append((hx, hy))
                pygame.draw.polygon(self.screen, (0, 255, 255, 100), hex_points, 2)

            icon = self.create_skill_icon(skill, current_level, skill["max_level"], skill_size)
            self.screen.blit(icon, (skill_x, skill_y))

            if skill["id"] in self.skill_levelup_animations:
                anim_data = self.skill_levelup_animations[skill["id"]]
                current_time = pygame.time.get_ticks()
                elapsed = current_time - anim_data["start_time"]
                if elapsed < anim_data["duration"]:
                    progress = elapsed / anim_data["duration"]
                    center_x = skill_x + skill_size // 2
                    center_y = skill_y + skill_size // 2
                    if elapsed < 50:
                        flash_alpha = int(120 * (1 - elapsed / 50))
                        flash_surface = pygame.Surface((skill_size + 20, skill_size + 20), pygame.SRCALPHA)
                        pygame.draw.circle(
                            flash_surface,
                            (255, 255, 255, flash_alpha),
                            (flash_surface.get_width() // 2, flash_surface.get_height() // 2),
                            skill_size // 2 + 10,
                        )
                        self.screen.blit(flash_surface, (skill_x - 10, skill_y - 10))
                    for particle in anim_data["starburst"]:
                        if progress < 0.5:
                            movement_progress = 4 * progress * progress * progress
                        else:
                            p = 2 * progress - 2
                            movement_progress = 1 + p * p * p / 2
                        current_distance = particle["max_distance"] * movement_progress
                        px = center_x + math.cos(particle["angle"]) * current_distance
                        py = center_y + math.sin(particle["angle"]) * current_distance
                        twinkle = abs(math.sin(particle["sparkle_phase"] + elapsed * 0.01)) * 0.5 + 0.5
                        if progress < 0.85:
                            fade = 1.0
                        else:
                            fade = 1 - ((progress - 0.85) / 0.15)
                        brightness = int(particle["brightness"] * fade * twinkle)
                        if brightness > 0:
                            star_surface = pygame.Surface((12, 12), pygame.SRCALPHA)
                            star_center = 6
                            pygame.draw.line(star_surface, (255, 255, 200, brightness), (star_center, 2), (star_center, 10), 2)
                            pygame.draw.line(star_surface, (255, 255, 200, brightness), (2, star_center), (10, star_center), 2)
                            pygame.draw.line(star_surface, (255, 255, 230, brightness // 2), (3, 3), (9, 9), 1)
                            pygame.draw.line(star_surface, (255, 255, 230, brightness // 2), (9, 3), (3, 9), 1)
                            pygame.draw.circle(star_surface, (255, 255, 255, min(255, brightness + 50)), (star_center, star_center), int(particle["size"] / 2))
                            self.screen.blit(star_surface, (px - 6, py - 6))
                    for glitter in anim_data["glitter"]:
                        if elapsed > glitter["delay"]:
                            glitter["phase"] += glitter["speed"]
                            sparkle = (math.sin(glitter["phase"]) + 1) / 2
                            glitter_alpha = int(255 * sparkle)
                            glitter_surface = pygame.Surface((6, 6), pygame.SRCALPHA)
                            pygame.draw.circle(glitter_surface, (255, 255, 255, glitter_alpha), (3, 3), 2)
                            self.screen.blit(glitter_surface, (skill_x + skill_size // 2 + glitter["x"], skill_y + skill_size // 2 + glitter["y"]))
                    pulse = abs(math.sin(elapsed * 0.01)) * 0.5 + 0.5
                    glow_radius = int(skill_size // 2 + 15 * pulse)
                    glow_surf = pygame.Surface((glow_radius * 4, glow_radius * 4), pygame.SRCALPHA)
                    glow_alpha = int(60 * (1 - elapsed / anim_data["duration"]))
                    for j in range(3):
                        alpha = glow_alpha // (j + 1)
                        radius = glow_radius + j * 5
                        pygame.draw.circle(glow_surf, (255, 255, 100, alpha), (glow_radius * 2, glow_radius * 2), radius, 2)
                    self.screen.blit(glow_surf, (skill_x + skill_size // 2 - glow_radius * 2, skill_y + skill_size // 2 - glow_radius * 2))
                else:
                    del self.skill_levelup_animations[skill["id"]]

            name_text = self.font_small.render(skill["name"], True, (255, 255, 255))
            name_rect = name_text.get_rect(centerx=skill_x + skill_size // 2, top=skill_y + skill_size + 5)
            self.screen.blit(name_text, name_rect)

            gauge_width = skill_size + 20
            gauge_height = 10
            gauge_x = skill_x - 10
            gauge_y = name_rect.bottom + 5
            self.draw_skill_level_gauge(skill, gauge_x, gauge_y, gauge_width, gauge_height)

            label_y = gauge_y + gauge_height + 5
            if current_level >= max_level:
                badge_surface = self._create_master_badge_surface((255, 215, 0))
                badge_rect = badge_surface.get_rect(centerx=skill_x + skill_size // 2, top=label_y)
                self.screen.blit(badge_surface, badge_rect)
            else:
                cost_color = (0, 255, 255) if self.skill_system.can_upgrade_skill(skill["id"]) else (255, 120, 120)
                actual_cost = skill['cost']
                cost_surface = self.font_small.render(f"비용: ★{actual_cost}", True, cost_color)
                cost_rect = cost_surface.get_rect(centerx=skill_x + skill_size // 2, top=label_y)
                self.screen.blit(cost_surface, cost_rect)


    def draw_skill_level_gauge(self, skill, x, y, width=120, height=25):
        """스킬 레벨 게이지를 그리기 - 네모 단계 게이지 시스템"""
        current_level = self.skill_system.get_skill_level(skill["id"])
        max_level = skill["max_level"]
        
        # 게이지 박스 크기
        box_width = width // max_level - 2
        box_height = height
        
        for i in range(max_level):
            box_x = x + i * (box_width + 2)
            
            # 외곽선 색상 결정
            if i < current_level:
                # 채워진 레벨 - 밝은 색상
                fill_color = (255, 50, 50) if current_level == max_level else (255, 100, 100)
                border_color = (255, 150, 150)
            else:
                # 비어있는 레벨 - 어두운 색상
                fill_color = (40, 10, 10)
                border_color = (80, 30, 30)
            
            # 게이지 박스 그리기
            pygame.draw.rect(self.screen, fill_color, 
                           (box_x, y, box_width, box_height))
            pygame.draw.rect(self.screen, border_color, 
                           (box_x, y, box_width, box_height), 2)
            
            # 채워진 레벨에 광택 효과
            if i < current_level:
                gloss_surface = pygame.Surface((box_width - 4, box_height // 3), pygame.SRCALPHA)
                gloss_surface.fill((255, 255, 255, 30))
                self.screen.blit(gloss_surface, (box_x + 2, y + 2))
    
    def draw_dash_skill_tree(self, tree_data):
        """대쉬 스킬트리를 트리 구조로 그리기"""
        # 스킬 아이콘 크기 및 여백
        skill_size = 60
        row_spacing = 140  # 행 간격 (글자 겹침 방지를 위해 증가)
        col_spacing = 200  # 열 간격
        
        # 좌측 중앙 배치를 위한 계산 (우측 설명 패널 고려)
        tree_width = col_spacing * 2  # 2열로 구성
        tree_height = row_spacing * 3  # 4행으로 구성 (0~3)
        available_width = self.width - 190  # 우측 설명 패널(150px) + 여백(40px) 제외
        start_x = (available_width - tree_width) // 2 + 30  # 좌측 영역의 중앙에 배치
        start_y = 160      # 시작 Y 위치 (제목 아래 여백)
        
        # 스킬 위치 매핑 (row, col에 따라)
        skill_positions = {}
        for skill in tree_data["skills"]:
            row = skill["row"]
            col = skill["col"]
            
            # col이 0.5인 경우 (대쉬 스피릿) 중앙 배치
            if col == 0.5:
                x = start_x + col_spacing // 2
            else:
                x = start_x + int(col) * col_spacing
            
            y = start_y + row * row_spacing
            skill_positions[skill["id"]] = (x, y)
        
        # 연결선 먼저 그리기
        for skill in tree_data["skills"]:
            tree_id_for_skill = self.skill_system.get_tree_id_for_skill(skill["id"]) or self.selected_tree
            tree_tp_total = self.skill_system.get_tree_total(tree_id_for_skill)
            tp_requirement = skill.get("total_tp_required", 0)
            if skill.get("requires"):
                current_pos = skill_positions[skill["id"]]

                if isinstance(skill.get("requires"), list):
                    # 여러 선행 스킬이 있는 경우 (대쉬 스피릿)
                    for required_skill in skill.get("requires"):
                        if required_skill in skill_positions:
                            required_pos = skill_positions[required_skill]
                            required_level = self.skill_system.get_skill_level(required_skill)
                            tp_met = tree_tp_total >= tp_requirement
                            line_color = (100, 255, 100) if required_level > 0 and tp_met else (100, 100, 100)
                            
                            # 화살표 선 그리기
                            pygame.draw.line(self.screen, line_color, 
                                           (required_pos[0] + skill_size//2, required_pos[1] + skill_size),
                                           (current_pos[0] + skill_size//2, current_pos[1]), 3)
                            
                            # 화살표 머리 그리기
                            arrow_head_x = current_pos[0] + skill_size//2
                            arrow_head_y = current_pos[1]
                            pygame.draw.polygon(self.screen, line_color, [
                                (arrow_head_x, arrow_head_y),
                                (arrow_head_x - 8, arrow_head_y - 15),
                                (arrow_head_x + 8, arrow_head_y - 15)
                            ])
                            
                            # 레이저 애니메이션 오버레이
                            self.draw_arrow_animation(required_skill, skill["id"])
                else:
                    # 단일 선행 스킬이 있는 경우
                    required_skill = skill.get("requires")
                    if required_skill in skill_positions:
                        required_pos = skill_positions[required_skill]
                        required_level = self.skill_system.get_skill_level(required_skill)
                        tp_met = tree_tp_total >= tp_requirement
                        line_color = (100, 255, 100) if (required_level > 0 and tp_met) else (100, 100, 100)
                        
                        # 화살표 선 그리기
                        pygame.draw.line(self.screen, line_color, 
                                       (required_pos[0] + skill_size//2, required_pos[1] + skill_size),
                                       (current_pos[0] + skill_size//2, current_pos[1]), 3)
                        
                        # 화살표 머리 그리기
                        arrow_head_x = current_pos[0] + skill_size//2
                        arrow_head_y = current_pos[1]
                        pygame.draw.polygon(self.screen, line_color, [
                            (arrow_head_x, arrow_head_y),
                            (arrow_head_x - 8, arrow_head_y - 15),
                            (arrow_head_x + 8, arrow_head_y - 15)
                        ])
                        
                        # 레이저 애니메이션 오버레이
                        self.draw_arrow_animation(required_skill, skill["id"])
            
            # OR 조건 선행 스킬 연결선 그리기
            if skill.get("requires_or"):
                current_pos = skill_positions[skill["id"]]
                for required_skill in skill.get("requires_or"):
                    if required_skill in skill_positions:
                        required_pos = skill_positions[required_skill]
                        required_level = self.skill_system.get_skill_level(required_skill)
                        tp_met = tree_tp_total >= tp_requirement
                        line_color = (100, 255, 100) if (required_level > 0 and tp_met) else (100, 100, 100)
                        
                        # 화살표 선 그리기
                        pygame.draw.line(self.screen, line_color, 
                                       (required_pos[0] + skill_size//2, required_pos[1] + skill_size),
                                       (current_pos[0] + skill_size//2, current_pos[1]), 3)
                        
                        # 화살표 머리 그리기
                        arrow_head_x = current_pos[0] + skill_size//2
                        arrow_head_y = current_pos[1]
                        pygame.draw.polygon(self.screen, line_color, [
                            (arrow_head_x, arrow_head_y),
                            (arrow_head_x - 8, arrow_head_y - 15),
                            (arrow_head_x + 8, arrow_head_y - 15)
                        ])
                        
                        # 레이저 애니메이션 오버레이
                        self.draw_arrow_animation(required_skill, skill["id"])
        
        # 스킬 아이콘 및 정보 그리기
        for i, skill in enumerate(tree_data["skills"]):
            skill_x, skill_y = skill_positions[skill["id"]]
            
            # 선택된 스킬 하이라이트 (탭 선택 모드가 아닐 때만)
            if i == self.selected_skill_index and not self.tab_selection_mode:
                highlight_rect = pygame.Rect(skill_x - 5, skill_y - 5, skill_size + 10, skill_size + 10)
                pygame.draw.rect(self.screen, (100, 100, 150, 50), highlight_rect)
                pygame.draw.rect(self.screen, (255, 255, 255), highlight_rect, 2)
            
            # 스킬 아이콘 - 사이버펑크 스타일
            current_level = self.skill_system.get_skill_level(skill["id"])
            is_available = self.skill_system.can_upgrade_skill(skill["id"])
            is_unlocked = current_level > 0
            
            # 홀로그램 글로우 효과 제거 (배경 원 제거)
            if is_unlocked:
                bg_color = (0, 100, 100)
            else:
                bg_color = (40, 40, 40)
            
            # 선택된 스킬 펄스 효과
            if i == self.selected_skill_index and not self.tab_selection_mode:
                import math
                pulse = abs(math.sin(pygame.time.get_ticks() * 0.005)) * 0.5 + 0.5
                select_size = skill_size + int(8 + pulse * 5)
                pygame.draw.circle(self.screen, (0, 255, 255), (skill_x + skill_size//2, skill_y + skill_size//2), select_size, 3)
                
                # 회전하는 육각형 효과
                angle = pygame.time.get_ticks() * 0.002
                hex_points = []
                for j in range(6):
                    hex_angle = angle + j * math.pi / 3
                    hx = skill_x + skill_size//2 + (skill_size + 12) * math.cos(hex_angle)
                    hy = skill_y + skill_size//2 + (skill_size + 12) * math.sin(hex_angle)
                    hex_points.append((hx, hy))
                pygame.draw.polygon(self.screen, (0, 255, 255, 100), hex_points, 2)
            
            icon = self.create_skill_icon(skill, current_level, skill["max_level"], skill_size)
            self.screen.blit(icon, (skill_x, skill_y))
            
            # 레벨업 반짝임 애니메이션 (깔끔하고 화려한 효과)
            if skill["id"] in self.skill_levelup_animations:
                anim_data = self.skill_levelup_animations[skill["id"]]
                current_time = pygame.time.get_ticks()
                elapsed = current_time - anim_data["start_time"]
                
                # 디버그: 애니메이션 시간 확인
                if elapsed < 500 or elapsed > 1900:  # 처음과 끝에 출력
                    print(f"Animation: skill={skill['id']}, elapsed={elapsed}ms, duration={anim_data['duration']}ms")
                
                if elapsed < anim_data["duration"]:
                    import math
                    progress = elapsed / anim_data["duration"]
                    center_x = skill_x + skill_size // 2
                    center_y = skill_y + skill_size // 2
                    
                    # 1. 초기 플래시 효과 (Initial flash)
                    if elapsed < 50:  # 처음 0.05초로 단축 (50% 감소)
                        flash_alpha = int(120 * (1 - elapsed / 50))
                        flash_surface = pygame.Surface((skill_size + 20, skill_size + 20), pygame.SRCALPHA)
                        pygame.draw.circle(flash_surface, (255, 255, 255, flash_alpha),
                                         (flash_surface.get_width()//2, flash_surface.get_height()//2),
                                         skill_size//2 + 10)
                        self.screen.blit(flash_surface, (skill_x - 10, skill_y - 10))
                    
                    # 2. 스타버스트 효과 (Starburst particles) - 방사형으로 퍼지는 반짝임
                    for particle in anim_data["starburst"]:
                        # 전체 애니메이션 진행도
                        progress = min(1.0, elapsed / anim_data["duration"])  # 2000ms 기준, 최대 1.0
                        
                        # 프레임당 1번만 디버그 출력 (첫 번째 파티클만)
                        if particle == anim_data["starburst"][0] and elapsed < 500:
                            print(f"Particle animation - elapsed={elapsed}ms, progress={progress:.2f}")
                        
                        # 매우 부드러운 ease-in-out (cubic)
                        if progress < 0.5:
                            # 처음 절반: 매우 천천히 시작 (cubic ease in)
                            movement_progress = 4 * progress * progress * progress  # 0 -> 0.5
                        else:
                            # 나머지 절반: 부드럽게 감속 (cubic ease out)  
                            p = 2 * progress - 2
                            movement_progress = 1 + p * p * p / 2  # 0.5 -> 1
                        
                        # 현재 거리 계산 (프레임 독립적)
                        current_distance = particle["max_distance"] * movement_progress  # 100% 사용
                        
                        # 위치 계산
                        px = center_x + math.cos(particle["angle"]) * current_distance
                        py = center_y + math.sin(particle["angle"]) * current_distance
                        
                        # 반짝임 효과 (twinkle) - 더 역동적으로
                        twinkle = abs(math.sin(particle["sparkle_phase"] + elapsed * 0.01)) * 0.5 + 0.5  # 더 느린 반짝임
                        
                        # 페이드아웃 (끝부분에만 적용)
                        if progress < 0.85:  # 1700ms까지는 완전히 보임
                            fade = 1.0
                        else:
                            fade = 1 - ((progress - 0.85) / 0.15)  # 마지막 300ms에서 페이드
                        
                        brightness = int(particle["brightness"] * fade * twinkle)
                        
                        if brightness > 0:
                            # 별 모양 그리기 (4각 스타)
                            star_surface = pygame.Surface((12, 12), pygame.SRCALPHA)
                            star_center = 6
                            
                            # 십자가 모양
                            pygame.draw.line(star_surface, (255, 255, 200, brightness),
                                           (star_center, 2), (star_center, 10), 2)
                            pygame.draw.line(star_surface, (255, 255, 200, brightness),
                                           (2, star_center), (10, star_center), 2)
                            
                            # 대각선 (더 얇게)
                            pygame.draw.line(star_surface, (255, 255, 230, brightness//2),
                                           (3, 3), (9, 9), 1)
                            pygame.draw.line(star_surface, (255, 255, 230, brightness//2),
                                           (9, 3), (3, 9), 1)
                            
                            # 중앙 밝은 점
                            pygame.draw.circle(star_surface, (255, 255, 255, min(255, brightness + 50)),
                                             (star_center, star_center), int(particle["size"]/2))
                            
                            self.screen.blit(star_surface, (px - 6, py - 6))
                    
                    # 3. 글리터 효과 (Glitter sparkles) - 주변에 작은 반짝임
                    for glitter in anim_data["glitter"]:
                        if elapsed > glitter["delay"]:
                            glitter_elapsed = elapsed - glitter["delay"]
                            
                            # 반짝임 계산
                            glitter["phase"] += glitter["speed"]
                            sparkle = (math.sin(glitter["phase"]) + 1) / 2
                            
                            # 페이드 인/아웃 (2초에 맞춤)
                            if glitter_elapsed < 200:
                                fade = glitter_elapsed / 200
                            elif glitter_elapsed > 1600:
                                fade = max(0, 1 - (glitter_elapsed - 1600) / 400)
                            else:
                                fade = 1
                            
                            alpha = int(200 * sparkle * fade)
                            
                            if alpha > 0:
                                # 글리터 위치
                                gx = center_x + glitter["x"]
                                gy = center_y + glitter["y"]
                                
                                # 다이아몬드 모양의 작은 반짝임
                                glitter_surface = pygame.Surface((6, 6), pygame.SRCALPHA)
                                # 작은 십자가
                                pygame.draw.line(glitter_surface, (255, 255, 255, alpha),
                                               (3, 1), (3, 5), 1)
                                pygame.draw.line(glitter_surface, (255, 255, 255, alpha),
                                               (1, 3), (5, 3), 1)
                                # 중앙 밝은 점
                                pygame.draw.circle(glitter_surface, (255, 255, 255, min(255, alpha + 100)),
                                                 (3, 3), int(glitter["size"]))
                                
                                self.screen.blit(glitter_surface, (gx - 3, gy - 3))
                    
                    # 4. 중앙 하이라이트 (Center highlight) - 아이콘 중앙에 부드러운 빛
                    if progress < 0.5:
                        highlight_alpha = int(80 * (1 - progress * 2))
                        highlight_surface = pygame.Surface((skill_size, skill_size), pygame.SRCALPHA)
                        
                        # 방사형 그라디언트
                        for i in range(5):
                            radius = (skill_size // 2) - i * 5
                            alpha = highlight_alpha * (1 - i * 0.2)
                            pygame.draw.circle(highlight_surface, (255, 250, 200, int(alpha)),
                                             (skill_size//2, skill_size//2), radius)
                        
                        self.screen.blit(highlight_surface, (skill_x, skill_y), special_flags=pygame.BLEND_ADD)
                    
                else:
                    # 애니메이션 종료
                    print(f"Deleting animation for {skill['id']} - elapsed={elapsed}ms, duration={anim_data['duration']}ms")
                    del self.skill_levelup_animations[skill["id"]]
            
            # 업그레이드 애니메이션 효과 (아이콘 위에 오버레이)
            if skill["id"] in self.unlock_animations:
                anim_data = self.unlock_animations[skill["id"]]
                current_time = pygame.time.get_ticks()
                elapsed = current_time - anim_data["start_time"]
                
                if elapsed < anim_data["duration"]:
                    import math
                    
                    # 반짝임 효과 (플래시)
                    flash_interval = 150  # 150ms 간격으로 반짝임
                    flash_on_duration = 75  # 75ms만 켜짐 (50% 감소)
                    if (elapsed % flash_interval) < flash_on_duration:
                        flash_surf = pygame.Surface((skill_size, skill_size), pygame.SRCALPHA)
                        flash_surf.fill((255, 255, 200, 80))
                        self.screen.blit(flash_surf, (skill_x, skill_y))
                    
                    # 스파클 파티클 효과
                    for particle in anim_data["sparkle_particles"]:
                        if particle["life"] > 0:
                            # 파티클 위치 계산
                            px = skill_x + skill_size//2 + math.cos(particle["angle"]) * particle["distance"]
                            py = skill_y + skill_size//2 + math.sin(particle["angle"]) * particle["distance"]
                            
                            # 파티클 업데이트
                            particle["distance"] = min(particle["distance"] + particle["speed"], particle["max_distance"])
                            particle["life"] -= 1
                            
                            # 알파값 계산
                            alpha = int(255 * (particle["life"] / 60))
                            
                            # 스파클 그리기
                            sparkle_surf = pygame.Surface((particle["size"] * 4, particle["size"] * 4), pygame.SRCALPHA)
                            
                            # 십자 모양 스파클
                            sparkle_color = (255, 255, 200, alpha)
                            pygame.draw.line(sparkle_surf, sparkle_color, 
                                           (particle["size"] * 2, particle["size"]), 
                                           (particle["size"] * 2, particle["size"] * 3), 2)
                            pygame.draw.line(sparkle_surf, sparkle_color, 
                                           (particle["size"], particle["size"] * 2), 
                                           (particle["size"] * 3, particle["size"] * 2), 2)
                            
                            # 대각선 스파클
                            sparkle_color2 = (255, 255, 255, alpha // 2)
                            pygame.draw.line(sparkle_surf, sparkle_color2,
                                           (particle["size"], particle["size"]),
                                           (particle["size"] * 3, particle["size"] * 3), 1)
                            pygame.draw.line(sparkle_surf, sparkle_color2,
                                           (particle["size"] * 3, particle["size"]),
                                           (particle["size"], particle["size"] * 3), 1)
                            
                            self.screen.blit(sparkle_surf, (px - particle["size"] * 2, py - particle["size"] * 2))
                    
                    # 펄싱 글로우 효과
                    pulse = abs(math.sin(elapsed * 0.01)) * 0.5 + 0.5
                    glow_radius = int(skill_size//2 + 15 * pulse)
                    glow_surf = pygame.Surface((glow_radius * 4, glow_radius * 4), pygame.SRCALPHA)
                    glow_alpha = int(60 * (1 - elapsed / anim_data["duration"]))
                    
                    for i in range(3):
                        alpha = glow_alpha // (i + 1)
                        radius = glow_radius + i * 5
                        pygame.draw.circle(glow_surf, (255, 255, 100, alpha), 
                                         (glow_radius * 2, glow_radius * 2), radius, 2)
                    
                    self.screen.blit(glow_surf, (skill_x + skill_size//2 - glow_radius * 2, 
                                                skill_y + skill_size//2 - glow_radius * 2))
                else:
                    # 애니메이션 종료
                    del self.unlock_animations[skill["id"]]
            
            # 스킬 이름 (아이콘 아래)
            name_text = self.font_small.render(skill["name"], True, (255, 255, 255))
            name_rect = name_text.get_rect(centerx=skill_x + skill_size // 2, top=skill_y + skill_size + 5)
            self.screen.blit(name_text, name_rect)

            current_level = self.skill_system.get_skill_level(skill["id"])
            max_level = skill["max_level"]

            gauge_width = skill_size + 20
            gauge_height = 10
            gauge_x = skill_x - 10
            gauge_y = name_rect.bottom + 5
            self.draw_skill_level_gauge(skill, gauge_x, gauge_y, gauge_width, gauge_height)

            label_y = gauge_y + gauge_height + 5
            if current_level >= max_level:
                badge_surface = self._create_master_badge_surface((255, 215, 0))
                badge_rect = badge_surface.get_rect(centerx=skill_x + skill_size // 2, top=label_y)
                self.screen.blit(badge_surface, badge_rect)
            else:
                cost_color = (100, 255, 100) if self.skill_system.can_upgrade_skill(skill["id"]) else (255, 100, 100)
                actual_cost = skill['cost']
                cost_surface = self.font_small.render(f"비용: ★{actual_cost}", True, cost_color)
                cost_rect = cost_surface.get_rect(centerx=skill_x + skill_size // 2, top=label_y)
                self.screen.blit(cost_surface, cost_rect)
            
            # 잠금 상태 표시
            is_locked = False
            
            # AND 조건 선행 스킬 확인
            if skill.get("requires"):
                if isinstance(skill.get("requires"), list):
                    # 여러 스킬이 모두 필요한 경우
                    for required_skill in skill.get("requires"):
                        required_level = self.skill_system.get_skill_level(required_skill)
                        if required_level == 0:
                            is_locked = True
                            break
                else:
                    # 단일 스킬이 필요한 경우
                    required_level = self.skill_system.get_skill_level(skill.get("requires"))
                    if required_level == 0:
                        is_locked = True
            
            # OR 조건 선행 스킬 확인
            if skill.get("requires_or") and not is_locked:
                # OR 조건에서는 모든 스킬이 없을 때만 잠금
                all_missing = True
                for required_skill in skill.get("requires_or"):
                    required_level = self.skill_system.get_skill_level(required_skill)
                    if required_level > 0:
                        all_missing = False
                        break
                if all_missing:
                    is_locked = True
            
            # 누적 TP 조건 확인
            if skill.get("total_tp_required") and not is_locked:
                if tree_tp_total < skill.get("total_tp_required", 0):
                    is_locked = True
            
            if skill.get("requires") or skill.get("requires_or") or skill.get("total_tp_required"):
                        
                if is_locked:
                    # 잠금 오버레이만 (자물쇠 아이콘 제거)
                    lock_surface = pygame.Surface((skill_size, skill_size), pygame.SRCALPHA)
                    lock_surface.fill((0, 0, 0, 128))
                    self.screen.blit(lock_surface, (skill_x, skill_y))
        
    def _collect_current_effect_lines(self, skill_id: str, current_level: int) -> list[str]:
        """현재 레벨 기준 효과 설명 문자열 집계"""
        if current_level <= 0:
            return []

        lines: list[str] = []

        if skill_id == "dash_lightweight":
            lines.append(f"현재: 충전시간 -{current_level * 7:.0f}%")
        elif skill_id == "dash_module_control":
            lines.append(f"현재: 통제불능 -{current_level * 10:.0f}%")
        elif skill_id == "dash_jump":
            lines.append(f"현재: 대쉬 거리 +{current_level * 4:.0f}%")
        elif skill_id == "dash_battery_pack":
            lines.append(f"현재: 게이지 소모 -{current_level * 8:.0f}%")
        elif skill_id == "dash_acceleration":
            lines.append(f"현재: 패들 높이 +{current_level * 60:.0f}%")
        elif skill_id == "dash_amplification":
            lines.append(f"현재: 대쉬 토큰 +{current_level}")
        elif skill_id == "dash_spirit":
            chance = 35 + max(0, current_level - 1) * 15
            lines.append(f"현재: 잔상 확률 {chance:.0f}%")
        elif skill_id == "dash_distance":
            lines.append(f"현재: 대쉬 거리 +{current_level * 3:.0f}%")
        elif skill_id == "dash_cooldown":
            lines.append(f"현재: 쿨타임 -{current_level * 0.2:.1f}초")
        elif skill_id == "dash_stun":
            lines.append(f"현재: 통제불능 -{current_level * 0.05:.2f}초")
        elif skill_id == "dash_gauge":
            lines.append(f"현재: 게이지 +{current_level * 10}")
        elif skill_id == "item_luck":
            multiplier = compute_item_spawn_delay_multiplier(current_level)
            lines.append(f"현재: 딜레이 {multiplier * 100:.1f}%")
            if current_level >= 5:
                lines.append("보너스: 추가 -5% 적용")
        elif skill_id == "item_cooldown_mastery":
            multiplier = compute_item_cooldown_multiplier(current_level)
            lines.append(f"현재: 쿨타임 {multiplier * 100:.1f}%")
            if current_level >= 5:
                lines.append("보너스: 추가 -8% 적용")
        elif skill_id == "item_gauge_mastery":
            bonus = compute_item_gauge_bonus(current_level)
            lines.append(f"현재: 게이지 +{bonus}")
            if current_level >= 5:
                lines.append("보너스: 추가 +10 적용")
        elif skill_id == "item_bag_expansion":
            lines.append(f"현재: 슬롯 +{current_level}칸")
        elif skill_id == "item_gamble":
            chance = min(0.95, 0.25 + 0.15 * (current_level - 1))
            max_extra = 1 if current_level < 3 else 2
            lines.append(f"현재: 추가 가챠 {int(chance * 100)}%")
            lines.append(f"현재: 최대 {max_extra}회")
        elif skill_id == "item_recycle":
            recycle_chance = min(0.9, 0.2 + 0.1 * (current_level - 1))
            lines.append(f"현재: 연금술 {int(recycle_chance * 100)}%")
        elif skill_id == "item_treasure_map":
            lines.append(f"현재: 필드 전설 +{current_level * 300}%")
            lines.append(f"현재: 가챠 전설 +{current_level * 5}%")
        elif skill_id == "item_spawn":
            lines.append(f"현재: 확률 +{current_level * 10}%")
        elif skill_id == "item_cooldown":
            lines.append(f"현재: 쿨타임 -{current_level * 0.6:.1f}초")
        elif skill_id == "item_slot":
            lines.append(f"현재: 슬롯 +{current_level}칸")
        elif skill_id == "item_pachinko":
            lines.append(f"현재: {current_level * 5}% 확률")
        elif skill_id == "item_legendary":
            lines.append("현재: 활성화")
        elif skill_id == "paddle_gauge":
            lines.append(f"현재: 게이지 +{current_level * 5}")
        elif skill_id == "paddle_speed":
            lines.append(f"현재: 속도 +{current_level * 0.5:.1f}")
        elif skill_id == "paddle_size":
            lines.append(f"현재: 크기 +{current_level * 2}%")
        elif skill_id == "paddle_max_gauge":
            lines.append(f"현재: 최대치 +{current_level * 30}")
        elif skill_id == "paddle_bio":
            lines.append("현재: 활성화")

        return lines

    def _collect_next_effect_lines(self, skill_id: str, next_level: int | None, max_level: int) -> list[str]:
        """다음 레벨 효과 미리보기 문자열 집계"""
        if not next_level or next_level > max_level:
            return []

        lines: list[str] = []

        if skill_id == "dash_lightweight":
            lines.append(f"다음: 충전시간 -{next_level * 7:.0f}%")
        elif skill_id == "dash_module_control":
            lines.append(f"다음: 통제불능 -{next_level * 10:.0f}%")
        elif skill_id == "dash_jump":
            lines.append(f"다음: 대쉬 거리 +{next_level * 4:.0f}%")
        elif skill_id == "dash_battery_pack":
            lines.append(f"다음: 게이지 소모 -{next_level * 8:.0f}%")
        elif skill_id == "dash_acceleration":
            lines.append(f"다음: 패들 높이 +{next_level * 60:.0f}%")
        elif skill_id == "dash_amplification":
            lines.append(f"다음: 대쉬 토큰 +{next_level}")
        elif skill_id == "dash_spirit":
            chance = 35 + max(0, next_level - 1) * 15
            lines.append(f"다음: 잔상 확률 {chance:.0f}%")
        elif skill_id == "dash_distance":
            lines.append(f"다음: 대쉬 거리 +{next_level * 3:.0f}%")
        elif skill_id == "dash_cooldown":
            lines.append(f"다음: 쿨타임 -{next_level * 0.2:.1f}초")
        elif skill_id == "dash_stun":
            lines.append(f"다음: 통제불능 -{next_level * 0.05:.2f}초")
        elif skill_id == "dash_gauge":
            lines.append(f"다음: 게이지 +{next_level * 10}")
        elif skill_id == "item_luck":
            multiplier = compute_item_spawn_delay_multiplier(next_level)
            lines.append(f"다음: 딜레이 {multiplier * 100:.1f}%")
            if next_level >= 5:
                lines.append("보너스: 추가 -5% 적용")
        elif skill_id == "item_cooldown_mastery":
            multiplier = compute_item_cooldown_multiplier(next_level)
            lines.append(f"다음: 쿨타임 {multiplier * 100:.1f}%")
            if next_level >= 5:
                lines.append("보너스: 추가 -8% 적용")
        elif skill_id == "item_gauge_mastery":
            bonus = compute_item_gauge_bonus(next_level)
            lines.append(f"다음: 게이지 +{bonus}")
            if next_level >= 5:
                lines.append("보너스: 추가 +10 적용")
        elif skill_id == "item_bag_expansion":
            lines.append(f"다음: 슬롯 +{next_level}칸")
        elif skill_id == "item_gamble":
            chance = min(0.95, 0.25 + 0.15 * (next_level - 1))
            max_extra = 1 if next_level < 3 else 2
            lines.append(f"다음: 추가 가챠 {int(chance * 100)}%")
            lines.append(f"다음: 최대 {max_extra}회")
        elif skill_id == "item_recycle":
            recycle_chance = min(0.9, 0.2 + 0.1 * (next_level - 1))
            lines.append(f"다음: 연금술 {int(recycle_chance * 100)}%")
        elif skill_id == "item_treasure_map":
            lines.append(f"다음: 필드 전설 +{next_level * 300}%")
            lines.append(f"다음: 가챠 전설 +{next_level * 5}%")
        elif skill_id == "item_spawn":
            lines.append(f"다음: 확률 +{next_level * 10}%")
        elif skill_id == "item_cooldown":
            lines.append(f"다음: 쿨타임 -{next_level * 0.6:.1f}초")
        elif skill_id == "item_slot":
            lines.append(f"다음: 슬롯 +{next_level}칸")
        elif skill_id == "item_pachinko":
            lines.append(f"다음: {next_level * 5}% 확률")
        elif skill_id == "item_legendary":
            lines.append("다음: 활성화")
        elif skill_id == "paddle_gauge":
            lines.append(f"다음: 게이지 +{next_level * 5}")
        elif skill_id == "paddle_speed":
            lines.append(f"다음: 속도 +{next_level * 0.5:.1f}")
        elif skill_id == "paddle_size":
            lines.append(f"다음: 크기 +{next_level * 2}%")
        elif skill_id == "paddle_max_gauge":
            lines.append(f"다음: 최대치 +{next_level * 30}")
        elif skill_id == "paddle_bio":
            lines.append("다음: 활성화")

        return lines

    def draw_skill_description(self, tree_data):
        """선택된 스킬 상세 설명 패널"""
        if self.selected_skill_index >= len(tree_data["skills"]):
            if tree_data["skills"]:
                self.selected_skill_index = 0
            else:
                return

        if self.selected_skill_index < 0:
            self.selected_skill_index = 0

        selected_skill = tree_data["skills"][self.selected_skill_index]
        tree_id_for_skill = self.skill_system.get_tree_id_for_skill(selected_skill["id"]) or self.selected_tree
        tree_tp_total = self.skill_system.get_tree_total(tree_id_for_skill)

        if ACADEMY_DEBUG and self.selected_tree == "item":
            print(f"[AcademyUI] tree=item idx={self.selected_skill_index} skill={selected_skill['id']}")

        desc_width = 220
        desc_height = 360
        desc_x = self.width - desc_width - 30
        desc_y = 170

        desc_surface = pygame.Surface((desc_width, desc_height), pygame.SRCALPHA)
        for y in range(desc_height):
            ratio = y / desc_height
            alpha = int(210 - ratio * 90)
            color_intensity = int(60 + ratio * 40)
            pygame.draw.line(
                desc_surface,
                (0, color_intensity, min(255, color_intensity * 2), alpha),
                (0, y),
                (desc_width, y),
            )

        for i in range(3):
            alpha = max(0, 60 - i * 20)
            pygame.draw.rect(
                desc_surface,
                (0, 0, 0, alpha),
                (i, i, desc_width - i * 2, desc_height - i * 2),
                1,
                border_radius=10,
            )

        pygame.draw.rect(
            desc_surface,
            (0, 255, 255),
            (0, 0, desc_width, desc_height),
            2,
            border_radius=10,
        )

        corners = [
            (0, 0),
            (desc_width - 10, 0),
            (0, desc_height - 10),
            (desc_width - 10, desc_height - 10),
        ]
        for cx, cy in corners:
            corner_points = [
                (cx + (10 if cx == 0 else 0), cy),
                (cx, cy),
                (cx, cy + (10 if cy == 0 else 0)),
            ]
            pygame.draw.lines(desc_surface, (0, 255, 255), False, corner_points, 2)

        self.screen.blit(desc_surface, (desc_x, desc_y))
        pygame.draw.rect(
            self.screen, (0, 255, 255), (desc_x, desc_y, desc_width, desc_height), 2
        )

        icon_size = 18
        icon_surface = pygame.Surface((icon_size, icon_size), pygame.SRCALPHA)
        center_x = icon_size // 2
        center_y = icon_size // 2
        hex_points = []
        for i in range(6):
            angle = i * math.pi / 3
            hx = center_x + 7 * math.cos(angle)
            hy = center_y + 7 * math.sin(angle)
            hex_points.append((hx, hy))
        pygame.draw.polygon(icon_surface, (100, 200, 255), hex_points)
        pygame.draw.polygon(icon_surface, (255, 255, 255), hex_points, 1)
        pygame.draw.circle(icon_surface, (255, 255, 255), (center_x, center_y), 2)
        self.screen.blit(icon_surface, (desc_x + 10, desc_y + 10))

        title_text = self.font_small.render("정보", True, (255, 255, 100))
        self.screen.blit(title_text, (desc_x + 34, desc_y + 10))

        skill_name = self.font_small.render(selected_skill["name"], True, (255, 255, 255))
        self.screen.blit(skill_name, (desc_x + 10, desc_y + 34))

        desc_text = selected_skill["description"]
        wrapped_lines = self._wrap_text_lines(desc_text, self.font_small, desc_width - 20)
        text_y = desc_y + 60
        for line in wrapped_lines:
            if text_y >= desc_y + desc_height - 110:
                break
            line_surf = self.font_small.render(line, True, (220, 220, 220))
            self.screen.blit(line_surf, (desc_x + 10, text_y))
            text_y += 18

        current_level = self.skill_system.get_skill_level(selected_skill["id"])
        max_level = selected_skill["max_level"]

        effect_lines = self._collect_current_effect_lines(selected_skill["id"], current_level)
        info_y = text_y + 8
        for line in effect_lines:
            line_surf = self.font_small.render(line, True, (100, 255, 140))
            self.screen.blit(line_surf, (desc_x + 10, info_y))
            info_y += 18
        if effect_lines:
            info_y += 4

        is_master = max_level == 5 and current_level == 5
        is_maxed = current_level == max_level
        level_y = info_y

        if is_master:
            master_text = self.font_small.render("★ MASTER ★", True, (255, 215, 0))
            self.screen.blit(master_text, (desc_x + 10, level_y))
            bonus_text = self.font_small.render("보너스: 추가 Lv.1 효과 적용", True, (255, 200, 120))
            self.screen.blit(bonus_text, (desc_x + 10, level_y + 18))
            level_y += 18
        elif is_maxed:
            max_text = self.font_small.render("[ MAX LEVEL ]", True, (220, 220, 220))
            self.screen.blit(max_text, (desc_x + 10, level_y))
        else:
            level_text = self.font_small.render(
                f"Lv. {current_level}/{max_level}", True, (150, 255, 150)
            )
            self.screen.blit(level_text, (desc_x + 10, level_y))

        cost_y = level_y + 22

        if current_level < max_level:
            next_level = current_level + 1
            next_lines = self._collect_next_effect_lines(
                selected_skill["id"], next_level, max_level
            )

            actual_cost = selected_skill["cost"]

            can_upgrade = self.skill_system.can_upgrade_skill(selected_skill["id"])
            cost_color = (100, 255, 100) if can_upgrade else (255, 120, 120)
            cost_text = f"비용: ★{actual_cost}"

            if not can_upgrade:
                if self.skill_system.skill_points < actual_cost:
                    cost_text += "\n(포인트 부족)"
                elif selected_skill.get("total_tp_required", 0) > tree_tp_total:
                    cost_text += f"\n(누적 ★{selected_skill['total_tp_required']} 필요)"
                elif selected_skill.get("requires") or selected_skill.get("requires_or"):
                    cost_text += "\n(선행스킬 필요)"

            cost_lines = cost_text.split("\n")
            for index, line in enumerate(cost_lines):
                cost_surface = self.font_small.render(line, True, cost_color)
                self.screen.blit(cost_surface, (desc_x + 10, cost_y + index * 16))

            next_y = cost_y + len(cost_lines) * 16 + 6
            for line in next_lines:
                next_surface = self.font_small.render(line, True, (150, 150, 255))
                self.screen.blit(next_surface, (desc_x + 10, next_y))
                next_y += 18
        else:
            pass

    def draw_linear_skill_tree(self, tree_data):
        """기존 방식의 선형 스킬트리 그리기 (item, paddle용)"""
        start_y = 120
        skill_size = 50  # 크기 축소
        margin = 15     # 마진 축소
        
        # 스킬 목록이 화면을 벗어나지 않도록 조정
        available_height = self.height - start_y - 60  # 하단 여백 고려
        total_skills_height = len(tree_data["skills"]) * (skill_size + margin) - margin
        
        if total_skills_height > available_height:
            # 스킬이 많으면 더 작게 조정
            skill_size = 40
            margin = 10
        
        for i, skill in enumerate(tree_data["skills"]):
            skill_x = 50  # 왼쪽 여백
            skill_y = start_y + i * (skill_size + margin)
            
            # 선택된 스킬 하이라이트 (탭 선택 모드가 아닐 때만)
            if i == self.selected_skill_index and not self.tab_selection_mode:
                highlight_rect = pygame.Rect(skill_x - 5, skill_y - 5, self.width - 100, skill_size + 10)
                pygame.draw.rect(self.screen, (100, 100, 150, 50), highlight_rect)
                pygame.draw.rect(self.screen, (255, 255, 255), highlight_rect, 2)
            
            # 스킬 연결선 (선행 스킬이 있는 경우)
            if skill.get("requires") and i > 0:
                prev_skill_y = start_y + (i - 1) * (skill_size + margin) + skill_size // 2
                current_skill_y = skill_y + skill_size // 2
                line_x = skill_x + skill_size // 2
                
                # 선행 스킬 확인 (단일 스킬일 때만 연결선 그리기)
                if not isinstance(skill.get("requires"), list):
                    required_level = self.skill_system.get_skill_level(skill.get("requires"))
                    # 화살표는 선행 스킬이 해금되면 초록색
                    line_color = (100, 255, 100) if required_level > 0 else (100, 100, 100)
                    
                    pygame.draw.line(self.screen, line_color, 
                                   (line_x, prev_skill_y + 5), (line_x, current_skill_y - 5), 2)
            
            # 스킬 아이콘 - 사이버펑크 스타일
            current_level = self.skill_system.get_skill_level(skill["id"])
            is_available = self.skill_system.can_upgrade_skill(skill["id"])
            is_unlocked = current_level > 0
            
            # 홀로그램 글로우 효과 제거 (배경 원 제거)
            if is_unlocked:
                bg_color = (0, 100, 100)
            else:
                bg_color = (40, 40, 40)
            
            # 선택된 스킬 펄스 효과
            if i == self.selected_skill_index and not self.tab_selection_mode:
                import math
                pulse = abs(math.sin(pygame.time.get_ticks() * 0.005)) * 0.5 + 0.5
                select_size = skill_size + int(8 + pulse * 5)
                pygame.draw.circle(self.screen, (0, 255, 255), (skill_x + skill_size//2, skill_y + skill_size//2), select_size, 3)
                
                # 회전하는 육각형 효과
                angle = pygame.time.get_ticks() * 0.002
                hex_points = []
                for j in range(6):
                    hex_angle = angle + j * math.pi / 3
                    hx = skill_x + skill_size//2 + (skill_size + 12) * math.cos(hex_angle)
                    hy = skill_y + skill_size//2 + (skill_size + 12) * math.sin(hex_angle)
                    hex_points.append((hx, hy))
                pygame.draw.polygon(self.screen, (0, 255, 255, 100), hex_points, 2)
            
            icon = self.create_skill_icon(skill, current_level, skill["max_level"], skill_size)
            self.screen.blit(icon, (skill_x, skill_y))
            
            # 레벨업 반짝임 애니메이션 (두 번째 중복 코드 - 비활성화됨)
            if False:  # skill["id"] in self.skill_levelup_animations:
                anim_data = self.skill_levelup_animations[skill["id"]]
                current_time = pygame.time.get_ticks()
                elapsed = current_time - anim_data["start_time"]
                
                if elapsed < anim_data["duration"]:
                    import math
                    progress = elapsed / anim_data["duration"]
                    center_x = skill_x + skill_size // 2
                    center_y = skill_y + skill_size // 2
                    
                    # 1. 초기 플래시 효과 (Initial flash)
                    if elapsed < 50:  # 처음 0.05초로 단축 (50% 감소)
                        flash_alpha = int(120 * (1 - elapsed / 50))
                        flash_surface = pygame.Surface((skill_size + 20, skill_size + 20), pygame.SRCALPHA)
                        pygame.draw.circle(flash_surface, (255, 255, 255, flash_alpha),
                                         (flash_surface.get_width()//2, flash_surface.get_height()//2),
                                         skill_size//2 + 10)
                        self.screen.blit(flash_surface, (skill_x - 10, skill_y - 10))
                    
                    # 2. 스타버스트 효과 (Starburst particles) - 방사형으로 퍼지는 반짝임
                    for particle in anim_data["starburst"]:
                        # 전체 애니메이션 진행도
                        progress = min(1.0, elapsed / anim_data["duration"])  # 2000ms 기준, 최대 1.0
                        
                        # 프레임당 1번만 디버그 출력 (첫 번째 파티클만)
                        if particle == anim_data["starburst"][0] and elapsed < 500:
                            print(f"Particle animation - elapsed={elapsed}ms, progress={progress:.2f}")
                        
                        # 매우 부드러운 ease-in-out (cubic)
                        if progress < 0.5:
                            # 처음 절반: 매우 천천히 시작 (cubic ease in)
                            movement_progress = 4 * progress * progress * progress  # 0 -> 0.5
                        else:
                            # 나머지 절반: 부드럽게 감속 (cubic ease out)  
                            p = 2 * progress - 2
                            movement_progress = 1 + p * p * p / 2  # 0.5 -> 1
                        
                        # 현재 거리 계산 (프레임 독립적)
                        current_distance = particle["max_distance"] * movement_progress  # 100% 사용
                        
                        # 위치 계산
                        px = center_x + math.cos(particle["angle"]) * current_distance
                        py = center_y + math.sin(particle["angle"]) * current_distance
                        
                        # 반짝임 효과 (twinkle) - 더 역동적으로
                        twinkle = abs(math.sin(particle["sparkle_phase"] + elapsed * 0.01)) * 0.5 + 0.5  # 더 느린 반짝임
                        
                        # 페이드아웃 (끝부분에만 적용)
                        if progress < 0.85:  # 1700ms까지는 완전히 보임
                            fade = 1.0
                        else:
                            fade = 1 - ((progress - 0.85) / 0.15)  # 마지막 300ms에서 페이드
                        
                        brightness = int(particle["brightness"] * fade * twinkle)
                        
                        if brightness > 0:
                            # 별 모양 그리기 (4각 스타)
                            star_surface = pygame.Surface((12, 12), pygame.SRCALPHA)
                            star_center = 6
                            
                            # 십자가 모양
                            pygame.draw.line(star_surface, (255, 255, 200, brightness),
                                           (star_center, 2), (star_center, 10), 2)
                            pygame.draw.line(star_surface, (255, 255, 200, brightness),
                                           (2, star_center), (10, star_center), 2)
                            
                            # 대각선 (더 얇게)
                            pygame.draw.line(star_surface, (255, 255, 230, brightness//2),
                                           (3, 3), (9, 9), 1)
                            pygame.draw.line(star_surface, (255, 255, 230, brightness//2),
                                           (9, 3), (3, 9), 1)
                            
                            # 중앙 밝은 점
                            pygame.draw.circle(star_surface, (255, 255, 255, min(255, brightness + 50)),
                                             (star_center, star_center), int(particle["size"]/2))
                            
                            self.screen.blit(star_surface, (px - 6, py - 6))
                    
                    # 3. 글리터 효과 (Glitter sparkles) - 주변에 작은 반짝임
                    for glitter in anim_data["glitter"]:
                        if elapsed > glitter["delay"]:
                            glitter_elapsed = elapsed - glitter["delay"]
                            
                            # 반짝임 계산
                            glitter["phase"] += glitter["speed"]
                            sparkle = (math.sin(glitter["phase"]) + 1) / 2
                            
                            # 페이드 인/아웃 (2초에 맞춤)
                            if glitter_elapsed < 200:
                                fade = glitter_elapsed / 200
                            elif glitter_elapsed > 1600:
                                fade = max(0, 1 - (glitter_elapsed - 1600) / 400)
                            else:
                                fade = 1
                            
                            alpha = int(200 * sparkle * fade)
                            
                            if alpha > 0:
                                # 글리터 위치
                                gx = center_x + glitter["x"]
                                gy = center_y + glitter["y"]
                                
                                # 다이아몬드 모양의 작은 반짝임
                                glitter_surface = pygame.Surface((6, 6), pygame.SRCALPHA)
                                # 작은 십자가
                                pygame.draw.line(glitter_surface, (255, 255, 255, alpha),
                                               (3, 1), (3, 5), 1)
                                pygame.draw.line(glitter_surface, (255, 255, 255, alpha),
                                               (1, 3), (5, 3), 1)
                                # 중앙 밝은 점
                                pygame.draw.circle(glitter_surface, (255, 255, 255, min(255, alpha + 100)),
                                                 (3, 3), int(glitter["size"]))
                                
                                self.screen.blit(glitter_surface, (gx - 3, gy - 3))
                    
                    # 4. 중앙 하이라이트 (Center highlight) - 아이콘 중앙에 부드러운 빛
                    if progress < 0.5:
                        highlight_alpha = int(80 * (1 - progress * 2))
                        highlight_surface = pygame.Surface((skill_size, skill_size), pygame.SRCALPHA)
                        
                        # 방사형 그라디언트
                        for i in range(5):
                            radius = (skill_size // 2) - i * 5
                            alpha = highlight_alpha * (1 - i * 0.2)
                            pygame.draw.circle(highlight_surface, (255, 250, 200, int(alpha)),
                                             (skill_size//2, skill_size//2), radius)
                        
                        self.screen.blit(highlight_surface, (skill_x, skill_y), special_flags=pygame.BLEND_ADD)
                    
                else:
                    # 애니메이션 종료
                    del self.skill_levelup_animations[skill["id"]]
            
            # 업그레이드 애니메이션 효과 (아이콘 위에 오버레이)
            if skill["id"] in self.unlock_animations:
                anim_data = self.unlock_animations[skill["id"]]
                current_time = pygame.time.get_ticks()
                elapsed = current_time - anim_data["start_time"]
                
                if elapsed < anim_data["duration"]:
                    import math
                    
                    # 반짝임 효과 (플래시)
                    flash_interval = 150  # 150ms 간격으로 반짝임
                    flash_on_duration = 75  # 75ms만 켜짐 (50% 감소)
                    if (elapsed % flash_interval) < flash_on_duration:
                        flash_surf = pygame.Surface((skill_size, skill_size), pygame.SRCALPHA)
                        flash_surf.fill((255, 255, 200, 80))
                        self.screen.blit(flash_surf, (skill_x, skill_y))
                    
                    # 스파클 파티클 효과
                    for particle in anim_data["sparkle_particles"]:
                        if particle["life"] > 0:
                            # 파티클 위치 계산
                            px = skill_x + skill_size//2 + math.cos(particle["angle"]) * particle["distance"]
                            py = skill_y + skill_size//2 + math.sin(particle["angle"]) * particle["distance"]
                            
                            # 파티클 업데이트
                            particle["distance"] = min(particle["distance"] + particle["speed"], particle["max_distance"])
                            particle["life"] -= 1
                            
                            # 알파값 계산
                            alpha = int(255 * (particle["life"] / 60))
                            
                            # 스파클 그리기
                            sparkle_surf = pygame.Surface((particle["size"] * 4, particle["size"] * 4), pygame.SRCALPHA)
                            
                            # 십자 모양 스파클
                            sparkle_color = (255, 255, 200, alpha)
                            pygame.draw.line(sparkle_surf, sparkle_color, 
                                           (particle["size"] * 2, particle["size"]), 
                                           (particle["size"] * 2, particle["size"] * 3), 2)
                            pygame.draw.line(sparkle_surf, sparkle_color, 
                                           (particle["size"], particle["size"] * 2), 
                                           (particle["size"] * 3, particle["size"] * 2), 2)
                            
                            # 대각선 스파클
                            sparkle_color2 = (255, 255, 255, alpha // 2)
                            pygame.draw.line(sparkle_surf, sparkle_color2,
                                           (particle["size"], particle["size"]),
                                           (particle["size"] * 3, particle["size"] * 3), 1)
                            pygame.draw.line(sparkle_surf, sparkle_color2,
                                           (particle["size"] * 3, particle["size"]),
                                           (particle["size"], particle["size"] * 3), 1)
                            
                            self.screen.blit(sparkle_surf, (px - particle["size"] * 2, py - particle["size"] * 2))
                    
                    # 펄싱 글로우 효과
                    pulse = abs(math.sin(elapsed * 0.01)) * 0.5 + 0.5
                    glow_radius = int(skill_size//2 + 15 * pulse)
                    glow_surf = pygame.Surface((glow_radius * 4, glow_radius * 4), pygame.SRCALPHA)
                    glow_alpha = int(60 * (1 - elapsed / anim_data["duration"]))
                    
                    for i in range(3):
                        alpha = glow_alpha // (i + 1)
                        radius = glow_radius + i * 5
                        pygame.draw.circle(glow_surf, (255, 255, 100, alpha), 
                                         (glow_radius * 2, glow_radius * 2), radius, 2)
                    
                    self.screen.blit(glow_surf, (skill_x + skill_size//2 - glow_radius * 2, 
                                                skill_y + skill_size//2 - glow_radius * 2))
                else:
                    # 애니메이션 종료
                    del self.unlock_animations[skill["id"]]
            
            # 스킬 이름
            name_text = self.font_small.render(skill["name"], True, (255, 255, 255))
            name_rect = name_text.get_rect(left=skill_x + skill_size + 15, top=skill_y + 5)
            self.screen.blit(name_text, name_rect)
            
            # 스킬 설명
            desc_text = self.font_small.render(skill["description"], True, (230, 230, 230))
            desc_rect = desc_text.get_rect(left=skill_x + skill_size + 15, top=skill_y + 22)
            self.screen.blit(desc_text, desc_rect)
            
            # 비용 및 상태 표시
            cost_color = (100, 255, 100) if self.skill_system.can_upgrade_skill(skill["id"]) else (255, 100, 100)
            if current_level < skill["max_level"]:
                actual_cost = skill['cost']
                
                cost_text = self.font_small.render(f"비용: ★{actual_cost}", True, cost_color)
                cost_rect = cost_text.get_rect(left=skill_x + skill_size + 15, top=skill_y + 35)
                self.screen.blit(cost_text, cost_rect)
            
            # 잠금 상태 표시
            is_locked = False
            
            # AND 조건 선행 스킬 확인
            if skill.get("requires"):
                if isinstance(skill.get("requires"), list):
                    # 여러 스킬이 모두 필요한 경우
                    for required_skill in skill.get("requires"):
                        required_level = self.skill_system.get_skill_level(required_skill)
                        if required_level == 0:
                            is_locked = True
                            break
                else:
                    # 단일 스킬이 필요한 경우
                    required_level = self.skill_system.get_skill_level(skill.get("requires"))
                    if required_level == 0:
                        is_locked = True
            
            # OR 조건 선행 스킬 확인
            if skill.get("requires_or") and not is_locked:
                # OR 조건에서는 모든 스킬이 없을 때만 잠금
                all_missing = True
                for required_skill in skill.get("requires_or"):
                    required_level = self.skill_system.get_skill_level(required_skill)
                    if required_level > 0:
                        all_missing = False
                        break
                if all_missing:
                    is_locked = True
            
            # 누적 TP 조건 확인
            if skill.get("total_tp_required") and not is_locked:
                if tree_tp_total < skill.get("total_tp_required", 0):
                    is_locked = True
                        
            if (skill.get("requires") or skill.get("requires_or") or skill.get("total_tp_required")) and is_locked:
                    # 잠금 오버레이
                    lock_surface = pygame.Surface((skill_size, skill_size), pygame.SRCALPHA)
                    lock_surface.fill((0, 0, 0, 128))
                    self.screen.blit(lock_surface, (skill_x, skill_y))
                    
                    # 잠금 아이콘 (텍스트 대신 간단한 그래픽)
                    lock_color = (255, 100, 100)
                    center_x, center_y = skill_x + skill_size//2, skill_y + skill_size//2
                    pygame.draw.rect(self.screen, lock_color, (center_x - 6, center_y - 2, 12, 8), 2)
                    pygame.draw.arc(self.screen, lock_color, (center_x - 8, center_y - 8, 16, 12), 0, 3.14, 2)
                    
                    # 추가 패턴 없이 잠금 오버레이 유지


skill_system = SkillSystem()


def get_skill_bonus(skill_id):
    """스킬 보너스 값 반환"""
    level = skill_system.get_skill_level(skill_id)
    
    # 마스터 보너스: max_level이 5이고 현재 레벨이 5인 경우 레벨 6 효과 적용
    skill_data = skill_system.get_skill_data(skill_id)
    if skill_data and skill_data.get("max_level") == 5 and level == 5:
        level = 6  # 마스터 보너스로 레벨 6 효과 적용
    
    bonuses = {
        # 새로운 대시 스킬 ID들 (사용자 요구사항에 맞게 수정)
        "dash_lightweight": level * 0.07,    # 경량화: 충전시간 7% 감소
        "dash_module_control": level * 0.10, # 모듈제어: 통제불능시간 10% 감소
        "dash_jump": level * 0.04,           # 도약: 대쉬거리 4% 증가
        "dash_battery_pack": level * 0.08,   # 배터리팩: 게이지 소모량 8% 감소
        "dash_acceleration": level * 0.6,    # 버스트업: 대쉬 중 패들 세로 사이즈 60% 증가
        "dash_amplification": level,         # 증폭: 대쉬토큰 1개 증가
        "dash_spirit": (0.35 + (level - 1) * 0.15) if level > 0 else 0,  # 대쉬 스피릿: 레벨1: 35%, 레벨2: 50% (스킬 없으면 0%)
        
        # 기존 호환성을 위해 남겨둠 (점진적 제거 예정)
        "dash_distance": level * 0.03,  # 3% per level (구 버전)
        "dash_cooldown": level * 0.2,   # 0.2초 per level (구 버전)
        "dash_stun": level * 0.05,      # 0.05초 per level (구 버전)
        "dash_gauge": level * 10,       # 10 per level (구 버전)
        
        "item_luck": level,                 # 레벨 정보 (별도 헬퍼에서 사용)
        "item_cooldown_mastery": level,
        "item_gauge_mastery": level * 10,   # 게이지 +10 per level
        "item_bag_expansion": level,        # 슬롯 +1 per level
        "item_gamble": level,               # 레벨 정보 (도박 설정용)
        "item_recycle": level,              # 레벨 정보 (연금술 확률용)
        "item_treasure_map": level,         # 레벨 정보 (전설 확률용)
        
        "paddle_gauge": level * 5,      # 5 per level
        "paddle_speed": level * 0.5,    # 0.5 per level
        "paddle_size": level * 0.02,    # 2% per level
        "paddle_max_gauge": level * 30, # 30 per level
        "paddle_bio": level,            # 0 or 1
    }
    
    return bonuses.get(skill_id, 0)


def get_skill_level(skill_id):
    """특정 스킬 레벨 조회"""
    return skill_system.get_skill_level(skill_id)


def compute_item_spawn_delay_multiplier(level):
    """행운 스킬 레벨을 받아 실제 딜레이 배율 계산"""
    base = max(0.05, 1.0 - 0.05 * level)
    if level >= 5:
        base = max(0.05, base - 0.05)
    return base



def compute_item_cooldown_multiplier(level: int) -> float:
    base = max(0.1, 1.0 - 0.08 * level)
    if level >= 5:
        base = max(0.1, base - 0.08)
    return base


def compute_item_gauge_bonus(level: int) -> int:
    bonus = level * 10
    if level >= 5:
        bonus += 10
    return bonus


def get_item_spawn_delay_multiplier():
    """행운 스킬에 따른 아이템 스폰 대기시간 배율"""
    level = get_skill_level("item_luck")
    return compute_item_spawn_delay_multiplier(level)


def get_active_item_cooldown_multiplier():
    """숙련 스킬에 따른 엑티브 아이템 쿨타임 배율"""
    level = get_skill_level("item_cooldown_mastery")
    return compute_item_cooldown_multiplier(level)


def get_active_item_gauge_bonus():
    """숙달 스킬에 따른 게이지 보너스"""
    level = get_skill_level("item_gauge_mastery")
    bonus = level * 10
    if level >= 5:
        bonus += 10
    return bonus


def get_item_slot_bonus():
    """가방 확장 스킬에 따른 추가 슬롯 수"""
    return get_skill_level("item_bag_expansion")


def get_item_recycle_chance():
    """연금술 스킬 확률"""
    level = get_skill_level("item_recycle")
    if level <= 0:
        return 0.0
    return min(0.9, 0.2 + 0.1 * (level - 1))


def get_item_gamble_settings():
    """도박 스킬 확률과 최대 추가 횟수"""
    level = get_skill_level("item_gamble")
    if level <= 0:
        return 0.0, 0
    chance = min(0.95, 0.25 + 0.15 * (level - 1))
    max_extra = 1 if level < 3 else 2
    return chance, max_extra


def get_treasure_map_field_multiplier():
    """보물지도 스킬이 전설 필드 확률에 주는 배율"""
    level = get_skill_level("item_treasure_map")
    return 1.0 + 3.0 * level


def get_treasure_map_gacha_bonus():
    """보물지도 스킬이 가챠 전설 확률에 주는 추가치"""
    level = get_skill_level("item_treasure_map")
    return 0.05 * level

def add_skill_points(points):
    """스킬 포인트 추가 (스테이지 클리어 시 호출)"""
    skill_system.add_skill_points(points)

def reset_skill_points():
    """스킬 포인트만 0으로 초기화"""
    skill_system.reset_skill_points()

def reset_all_skills():
    """모든 스킬과 포인트를 완전히 초기화 (게임 종료/죽음/회차 종료 시)"""
    skill_system.reset_all()

def check_all_dash_skills_mastered():
    """모든 대쉬 스킬이 마스터되었는지 확인"""
    dash_skills = [
        "dash_lightweight",     # 경량화
        "dash_module_control",  # 모듈제어
        "dash_jump",           # 도약
        "dash_battery_pack",   # 배터리팩
        "dash_acceleration",   # 버스트업
        "dash_amplification",  # 증폭
        "dash_spirit"          # 대쉬 스피릿
    ]
    
    # 모든 대쉬 스킬이 최대 레벨인지 확인
    for skill_id in dash_skills:
        level = skill_system.get_skill_level(skill_id)
        
        # 각 스킬의 최대 레벨 확인
        max_level = 0
        for tree_data in SKILL_TREES.values():
            for skill in tree_data["skills"]:
                if skill["id"] == skill_id:
                    max_level = skill["max_level"]
                    break
        
        # 하나라도 최대 레벨이 아니면 False
        if level < max_level:
            return False
    
    return True

def debug_max_dash_skills():
    """디버그용: 모든 대쉬 스킬을 최대 레벨로 설정"""
    dash_skills_max = {
        "dash_lightweight": 5,     # 경량화
        "dash_module_control": 5,  # 모듈제어
        "dash_jump": 5,           # 도약
        "dash_battery_pack": 5,   # 배터리팩
        "dash_acceleration": 5,   # 버스트업
        "dash_amplification": 2,  # 증폭
        "dash_spirit": 2          # 대쉬 스피릿
    }
    
    for skill_id, max_level in dash_skills_max.items():
        skill_system.skill_levels[skill_id] = max_level
    
    print("DEBUG:      !")

def show_academy_menu(screen, width, height, selected_character="smasher"):  # 테스트를 위해 기본값을 "smasher"로 변경
    """아카데미 메뉴 표시"""
    academy_ui = AcademyUI(screen, width, height, selected_character)
    return academy_ui.show_academy()
