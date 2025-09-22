"""
Academy UI - 아카데미 모드 UI 화면
스킬 트리 시각화, TP 관리, 업그레이드 인터페이스
"""

import os
import pygame
import math
from typing import Dict, List, Optional, Tuple
from core.global_manager import GlobalManager
from core.events import EventType, emit_event
from modes.academy import get_academy_mode


ACADEMY_UI_DEBUG = os.getenv("ACADEMY_UI_DEBUG") == "1"


class SkillNode:
    """스킬 노드 UI 클래스"""
    
    def __init__(self, skill_data: Dict, x: int, y: int):
        self.data = skill_data
        self.x = x
        self.y = y
        self.radius = 30
        self.selected = False
        self.hover = False
        self.animation_timer = 0
        self.pulse_scale = 1.0
        self.glow_alpha = 0
        
    def update(self, dt: float, can_upgrade: bool, current_level: int, max_level: int):
        """노드 업데이트"""
        self.animation_timer += dt * 60
        
        # 펄스 애니메이션 (업그레이드 가능할 때)
        if can_upgrade:
            self.pulse_scale = 1.0 + math.sin(self.animation_timer * 0.1) * 0.1
            self.glow_alpha = abs(math.sin(self.animation_timer * 0.05)) * 100 + 155
        else:
            self.pulse_scale = 1.0
            self.glow_alpha = max(0, self.glow_alpha - dt * 60 * 5)
            
    def render(self, screen: pygame.Surface, font: pygame.font.Font, 
               current_level: int, max_level: int, can_upgrade: bool):
        """노드 렌더링"""
        # 노드 색상 결정
        if current_level == max_level:
            color = (255, 215, 0)  # 골드 (마스터)
        elif current_level > 0:
            color = (100, 200, 255)  # 파랑 (습득)
        elif can_upgrade:
            color = (100, 255, 100)  # 초록 (가능)
        else:
            color = (100, 100, 100)  # 회색 (잠김)
            
        # 글로우 효과
        if self.glow_alpha > 0 and can_upgrade:
            glow_surface = pygame.Surface((self.radius * 4, self.radius * 4), pygame.SRCALPHA)
            for i in range(10):
                alpha = int(self.glow_alpha * (1 - i / 10))
                pygame.draw.circle(glow_surface, (*color, alpha),
                                 (self.radius * 2, self.radius * 2),
                                 int(self.radius * self.pulse_scale) + i * 2)
            screen.blit(glow_surface, (self.x - self.radius * 2, self.y - self.radius * 2))
            
        # 노드 원
        radius = int(self.radius * self.pulse_scale)
        pygame.draw.circle(screen, color, (self.x, self.y), radius, 3)
        
        # 내부 채우기
        if current_level > 0:
            fill_radius = int(radius * (current_level / max_level))
            pygame.draw.circle(screen, color, (self.x, self.y), fill_radius)
            
        # 아이콘 또는 텍스트
        if 'icon' in self.data:
            # TODO: 아이콘 렌더링
            pass
        else:
            # 레벨 텍스트
            level_text = f"{current_level}/{max_level}"
            text_surface = font.render(level_text, True, (255, 255, 255))
            text_rect = text_surface.get_rect(center=(self.x, self.y))
            screen.blit(text_surface, text_rect)
            
        # 스킬 이름
        name_surface = font.render(self.data['name'], True, (255, 255, 255))
        name_rect = name_surface.get_rect(center=(self.x, self.y + self.radius + 20))
        screen.blit(name_surface, name_rect)
        
        # 선택 표시
        if self.selected:
            pygame.draw.circle(screen, (255, 255, 0), (self.x, self.y), radius + 5, 2)
            
        # 호버 표시
        if self.hover:
            pygame.draw.circle(screen, (255, 255, 255), (self.x, self.y), radius + 3, 1)
            
    def check_collision(self, pos: Tuple[int, int]) -> bool:
        """마우스 충돌 체크"""
        dx = pos[0] - self.x
        dy = pos[1] - self.y
        return dx * dx + dy * dy <= self.radius * self.radius


class SkillTreeUI:
    """스킬 트리 UI"""
    
    def __init__(self, tree_id: str, tree_data: Dict, x: int, y: int, width: int, height: int):
        self.tree_id = tree_id
        self.tree_data = tree_data
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.nodes: Dict[str, SkillNode] = {}
        self.connections = []
        self.selected_node = None
        
        # 노드 생성 및 배치
        self._create_nodes()
        
    def _create_nodes(self):
        """노드 생성 및 배치"""
        # 그리드 기반 배치
        node_spacing_x = 120
        node_spacing_y = 100
        start_x = self.x + 100
        start_y = self.y + 80
        
        for skill in self.tree_data['skills']:
            row = skill.get('row', 0)
            col = skill.get('col', 0)
            
            node_x = start_x + col * node_spacing_x
            node_y = start_y + row * node_spacing_y
            
            self.nodes[skill['id']] = SkillNode(skill, node_x, node_y)
            
            # 연결선 정보 저장
            if skill.get('requires'):
                self.connections.append((skill['requires'], skill['id']))
            if skill.get('requires_or'):
                for req in skill['requires_or']:
                    self.connections.append((req, skill['id']))
                    
    def update(self, dt: float, academy_mode):
        """스킬 트리 업데이트"""
        tree = academy_mode.skill_trees.get(self.tree_id)
        if not tree:
            return
            
        for skill_id, node in self.nodes.items():
            skill = tree.get_skill(skill_id)
            if skill:
                current_level = tree.get_skill_level(skill_id)
                max_level = skill['max_level']
                can_upgrade = tree.can_upgrade(skill_id, academy_mode.player_data['tp'])
                node.update(dt, can_upgrade, current_level, max_level)
                
    def render(self, screen: pygame.Surface, font: pygame.font.Font, academy_mode):
        """스킬 트리 렌더링"""
        # 배경
        pygame.draw.rect(screen, (30, 30, 50), (self.x, self.y, self.width, self.height))
        pygame.draw.rect(screen, self.tree_data['color'], (self.x, self.y, self.width, self.height), 2)
        
        # 제목
        title_font = pygame.font.Font(None, 28)
        title_surface = title_font.render(self.tree_data['name'], True, self.tree_data['color'])
        title_rect = title_surface.get_rect(topleft=(self.x + 10, self.y + 10))
        screen.blit(title_surface, title_rect)
        
        # 연결선 그리기
        tree = academy_mode.skill_trees.get(self.tree_id)
        if tree:
            for req_id, skill_id in self.connections:
                if req_id in self.nodes and skill_id in self.nodes:
                    req_node = self.nodes[req_id]
                    skill_node = self.nodes[skill_id]
                    
                    # 연결선 색상
                    req_level = tree.get_skill_level(req_id)
                    if req_level > 0:
                        line_color = (100, 200, 100)
                    else:
                        line_color = (80, 80, 80)
                        
                    pygame.draw.line(screen, line_color,
                                   (req_node.x, req_node.y),
                                   (skill_node.x, skill_node.y), 2)
                                   
        # 노드 렌더링
        for skill_id, node in self.nodes.items():
            skill = tree.get_skill(skill_id) if tree else None
            if skill:
                current_level = tree.get_skill_level(skill_id) if tree else 0
                max_level = skill['max_level']
                can_upgrade = tree.can_upgrade(skill_id, academy_mode.player_data['tp']) if tree else False
                node.render(screen, font, current_level, max_level, can_upgrade)
                
    def handle_click(self, pos: Tuple[int, int]) -> Optional[str]:
        """클릭 처리"""
        for skill_id, node in self.nodes.items():
            if node.check_collision(pos):
                self.selected_node = skill_id
                return skill_id
        return None
        
    def handle_hover(self, pos: Tuple[int, int]):
        """호버 처리"""
        for node in self.nodes.values():
            node.hover = node.check_collision(pos)


class AcademyUI:
    """아카데미 UI 메인 클래스"""
    
    def __init__(self, screen: pygame.Surface):
        self.screen = screen
        self.global_manager = GlobalManager.get_instance()
        self.academy_mode = get_academy_mode()
        
        self.width = self.global_manager.get('WIDTH', 600)
        self.height = self.global_manager.get('HEIGHT', 750)
        
        # UI 상태
        self.active = False
        self.selected_tree = None
        self.selected_skill = None
        self.animation_timer = 0
        
        # 폰트
        try:
            self.font_title = pygame.font.Font("NanumSquareEB.ttf", 36)
            self.font_normal = pygame.font.Font("NanumSquareR.ttf", 20)
            self.font_small = pygame.font.Font("NanumSquareR.ttf", 16)
        except:
            self.font_title = pygame.font.Font(None, 36)
            self.font_normal = pygame.font.Font(None, 20)
            self.font_small = pygame.font.Font(None, 16)
            
        # 스킬 트리 UI 생성
        self.skill_tree_uis = {}
        self._create_skill_tree_uis()
        
        # 탭 버튼
        self.tabs = []
        self._create_tabs()
        self.current_tab = 0
        self.selected_skills_by_tree: Dict[str, str] = {}
        self.tab_summaries = {
            'dash': "대쉬 가속, 통제력, 토큰 수 등을 향상시켜 전투 템포를 높입니다.",
            'item': "필드 드랍률과 아이템 쿨타임, 슬롯을 조정해 서포트 능력을 강화합니다.",
            'special': "필살기의 충전 속도와 지속 시간을 늘려 위기 돌파력을 확보합니다."
        }
        self._on_tab_changed()

    def _create_max_badge_surface(self, text_color):
        """최대 상태 배지를 생성 (텍스트 + 별 아이콘)"""
        label_surface = self.font_small.render("최대", True, text_color)
        star_size = max(4, label_surface.get_height() // 2)
        spacing = 6
        width = label_surface.get_width() + spacing + star_size * 2
        height = max(label_surface.get_height(), star_size * 2)
        badge_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        badge_surface.blit(label_surface, (0, (height - label_surface.get_height()) // 2))

        center_x = label_surface.get_width() + spacing + star_size
        center_y = height // 2
        points = []
        for i in range(10):
            angle = math.pi / 5 * i - math.pi / 2
            radius = star_size if i % 2 == 0 else star_size * 0.45
            px = center_x + radius * math.cos(angle)
            py = center_y + radius * math.sin(angle)
            points.append((px, py))
        pygame.draw.polygon(badge_surface, text_color, points)
        return badge_surface

    def _create_skill_tree_uis(self):
        """스킬 트리 UI 생성"""
        tree_data = self.academy_mode.skill_tree_data
        
        # 각 트리별 UI 생성
        y_offset = 150
        for tree_id, data in tree_data.items():
            self.skill_tree_uis[tree_id] = SkillTreeUI(
                tree_id, data, 50, y_offset, self.width - 100, 400
            )
            
    def _create_tabs(self):
        """탭 버튼 생성"""
        tab_names = ["대쉬", "아이템", "필살기"]
        tab_width = 120
        tab_height = 40
        start_x = 50
        y = 100
        
        for i, name in enumerate(tab_names):
            self.tabs.append({
                'name': name,
                'rect': pygame.Rect(start_x + i * (tab_width + 10), y, tab_width, tab_height),
                'active': i == 0
            })
            
    def open(self):
        """아카데미 UI 열기"""
        self.active = True
        emit_event(EventType.MENU_OPENED, {'type': 'academy'})
        
    def _get_current_tree_id(self) -> Optional[str]:
        tree_ids = ['dash', 'item', 'special']
        if self.current_tab < len(tree_ids):
            return tree_ids[self.current_tab]
        return None

    def close(self):
        """아카데미 UI 닫기"""
        self.active = False
        emit_event(EventType.MENU_CLOSED, {'type': 'academy'})
        
    def handle_event(self, event) -> bool:
        """이벤트 처리"""
        if not self.active:
            return False
            
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.close()
                return True
            elif event.key == pygame.K_TAB:
                # 탭 전환
                self.current_tab = (self.current_tab + 1) % len(self.tabs)
                self._on_tab_changed()
                self._update_tabs()
                return True
                
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # 좌클릭
                # 탭 클릭 체크
                for i, tab in enumerate(self.tabs):
                    if tab['rect'].collidepoint(event.pos):
                        self.current_tab = i
                        self._on_tab_changed()
                        self._update_tabs()
                        return True
                        
                # 스킬 노드 클릭 체크
                tree_ids = ['dash', 'item', 'special']
                if self.current_tab < len(tree_ids):
                    tree_id = tree_ids[self.current_tab]
                    tree_ui = self.skill_tree_uis.get(tree_id)
                    if tree_ui:
                        skill_id = tree_ui.handle_click(event.pos)
                        if skill_id:
                            self._handle_skill_click(tree_id, skill_id)
                            return True
                            
        elif event.type == pygame.MOUSEMOTION:
            # 스킬 노드 호버 체크
            tree_ids = ['dash', 'item', 'special']
            if self.current_tab < len(tree_ids):
                tree_id = tree_ids[self.current_tab]
                tree_ui = self.skill_tree_uis.get(tree_id)
                if tree_ui:
                    tree_ui.handle_hover(event.pos)
                    
        return False
        
    def _update_tabs(self):
        """탭 상태 업데이트"""
        for i, tab in enumerate(self.tabs):
            tab['active'] = (i == self.current_tab)

    def _render_tab_summary(self):
        """현재 탭 요약 문구 표시"""
        tree_ids = ['dash', 'item', 'special']
        if self.current_tab >= len(tree_ids):
            return

        tree_id = tree_ids[self.current_tab]
        summary = self.tab_summaries.get(tree_id)
        if not summary:
            return

        lines = self._wrap_text(summary, 36)
        y = 150
        for line in lines:
            text_surface = self.font_small.render(line, True, (170, 200, 255))
            self.screen.blit(text_surface, (60, y))
            y += 18

    def _set_selected_skill(self, tree_id: Optional[str], skill_id: Optional[str]):
        """선택된 스킬 상태를 갱신하고 노드 하이라이트 반영"""
        self.selected_tree = tree_id
        self.selected_skill = skill_id

        if tree_id is None:
            return

        if skill_id:
            self.selected_skills_by_tree[tree_id] = skill_id

        tree_ui = self.skill_tree_uis.get(tree_id)
        if not tree_ui:
            return

        tree_ui.selected_node = skill_id
        for node_id, node in tree_ui.nodes.items():
            node.selected = (skill_id is not None and node_id == skill_id)

    def _on_tab_changed(self):
        """탭 전환 시 기본 선택 스킬 설정"""
        tree_ids = ['dash', 'item', 'special']
        if self.current_tab >= len(tree_ids):
            self._set_selected_skill(None, None)
            return

        tree_id = tree_ids[self.current_tab]
        tree_data = self.academy_mode.skill_tree_data.get(tree_id, {})
        skills = tree_data.get('skills', [])
        saved_skill = self.selected_skills_by_tree.get(tree_id)

        valid_ids = {skill['id'] for skill in skills}
        if saved_skill not in valid_ids:
            selected_id = skills[0]['id'] if skills else None
        else:
            selected_id = saved_skill

        self._set_selected_skill(tree_id, selected_id)

    def _handle_skill_click(self, tree_id: str, skill_id: str):
        """스킬 클릭 처리"""
        self._set_selected_skill(tree_id, skill_id)

        # 업그레이드 시도
        if self.academy_mode.upgrade_skill(tree_id, skill_id):
            emit_event(EventType.PLAY_SOUND, {'sound': 'skill_upgrade'})
            # 성공 이펙트
            self._show_upgrade_effect()
        else:
            emit_event(EventType.PLAY_SOUND, {'sound': 'error'})
            
    def _show_upgrade_effect(self):
        """업그레이드 성공 이펙트"""
        # TODO: 파티클 이펙트 추가
        pass
        
    def update(self, dt: float):
        """UI 업데이트"""
        if not self.active:
            return
            
        self.animation_timer += dt
        
        # 현재 탭의 스킬 트리 업데이트
        tree_ids = ['dash', 'item', 'special']
        if self.current_tab < len(tree_ids):
            tree_id = tree_ids[self.current_tab]
            tree_ui = self.skill_tree_uis.get(tree_id)
            if tree_ui:
                tree_ui.update(dt, self.academy_mode)
                
    def render(self, screen: pygame.Surface = None):
        """UI 렌더링"""
        if not self.active:
            return
            
        if screen:
            self.screen = screen
            
        # 배경 (반투명)
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 230))
        self.screen.blit(overlay, (0, 0))
        
        # 타이틀
        title_text = "아카데미"
        title_surface = self.font_title.render(title_text, True, (255, 215, 0))
        title_rect = title_surface.get_rect(center=(self.width // 2, 40))
        self.screen.blit(title_surface, title_rect)
        
        # 플레이어 정보
        self._render_player_info()
        
        # 탭 렌더링
        self._render_tabs()
        self._render_tab_summary()

        # 현재 탭의 스킬 트리 렌더링
        tree_ids = ['dash', 'item', 'special']
        if self.current_tab < len(tree_ids):
            tree_id = tree_ids[self.current_tab]
            tree_ui = self.skill_tree_uis.get(tree_id)
            if tree_ui:
                tree_ui.render(self.screen, self.font_small, self.academy_mode)
                
        # 선택된 스킬 정보 (탭 전환 직후 selection이 비어도 기본 설명을 강제로 표시)
        self._render_skill_info()
            
        # ESC 안내
        esc_text = self.font_small.render("ESC: 닫기", True, (150, 150, 150))
        self.screen.blit(esc_text, (self.width - 100, self.height - 30))
        
    def _render_player_info(self):
        """플레이어 정보 렌더링"""
        info_y = 70
        
        # TP
        tp_text = f"TP: {self.academy_mode.player_data['tp']}"
        tp_surface = self.font_normal.render(tp_text, True, (0, 255, 255))
        self.screen.blit(tp_surface, (50, info_y))
        
        # 레벨
        level = self.academy_mode.player_data['level']
        exp = self.academy_mode.player_data['exp']
        exp_next = self.academy_mode.player_data['exp_to_next']
        level_text = f"Lv.{level} ({exp}/{exp_next})"
        level_surface = self.font_normal.render(level_text, True, (255, 255, 255))
        self.screen.blit(level_surface, (200, info_y))
        
        # 메달
        medals = self.academy_mode.player_data['medals']
        medal_text = f"메달: {medals}"
        medal_surface = self.font_normal.render(medal_text, True, (255, 215, 0))
        self.screen.blit(medal_surface, (400, info_y))

        current_tree_id = self._get_current_tree_id()
        if current_tree_id:
            tree_tp = getattr(self.academy_mode, 'get_tree_total_tp', lambda _: 0)(current_tree_id)
            tab_name = self.tabs[self.current_tab]['name'] if self.current_tab < len(self.tabs) else ""
            tree_text = f"{tab_name} 누적 TP: {tree_tp}"
            tree_surface = self.font_small.render(tree_text, True, (150, 200, 255))
            self.screen.blit(tree_surface, (50, info_y + 30))
        
    def _render_tabs(self):
        """탭 렌더링"""
        for tab in self.tabs:
            # 탭 배경
            if tab['active']:
                color = (100, 150, 255)
                border_width = 3
            else:
                color = (50, 50, 80)
                border_width = 1
                
            pygame.draw.rect(self.screen, color, tab['rect'])
            pygame.draw.rect(self.screen, (255, 255, 255), tab['rect'], border_width)
            
            # 탭 텍스트
            text_color = (255, 255, 255) if tab['active'] else (150, 150, 150)
            text_surface = self.font_normal.render(tab['name'], True, text_color)
            text_rect = text_surface.get_rect(center=tab['rect'].center)
            self.screen.blit(text_surface, text_rect)
            
    def _render_skill_info(self):
        """선택된 스킬 정보 렌더링"""
        tree_ids = ['dash', 'item', 'special']
        if self.current_tab < len(tree_ids):
            current_tree_id = tree_ids[self.current_tab]
            if self.selected_tree != current_tree_id:
                tree_data = self.academy_mode.skill_tree_data.get(current_tree_id, {})
                skills = tree_data.get('skills', [])
                saved_skill = self.selected_skills_by_tree.get(current_tree_id)
                valid_ids = {skill['id'] for skill in skills}
                if saved_skill not in valid_ids:
                    fallback_id = skills[0]['id'] if skills else None
                else:
                    fallback_id = saved_skill
                if ACADEMY_UI_DEBUG:
                    print(f"[AcademyUI] sync tab={current_tree_id} saved={saved_skill} -> fallback={fallback_id}")
                self._set_selected_skill(current_tree_id, fallback_id)
        else:
            # 존재하지 않는 탭은 정보 패널을 표시하지 않고 종료
            self._set_selected_skill(None, None)
            return

        if not self.selected_tree:
            self._on_tab_changed()
        if not self.selected_tree:
            return

        if not self.selected_skill:
            tree_data = self.academy_mode.skill_tree_data.get(self.selected_tree, {})
            skills = tree_data.get('skills', [])
            fallback_id = skills[0]['id'] if skills else None
            if fallback_id:
                self._set_selected_skill(self.selected_tree, fallback_id)
            else:
                return
            
        tree = self.academy_mode.skill_trees.get(self.selected_tree)
        if not tree:
            return
            
        skill = tree.get_skill(self.selected_skill)
        if not skill:
            tree_data = self.academy_mode.skill_tree_data.get(self.selected_tree, {})
            skills = tree_data.get('skills', [])
            fallback_id = skills[0]['id'] if skills else None
            if fallback_id:
                self._set_selected_skill(self.selected_tree, fallback_id)
                skill = tree.get_skill(fallback_id)
            if not skill:
                return

        if ACADEMY_UI_DEBUG:
            print(f"[AcademyUI] render_info tree={self.selected_tree} skill={self.selected_skill}")

        current_tree_id = self._get_current_tree_id()
        tree_tp_total = 0
        if current_tree_id and hasattr(self.academy_mode, 'get_tree_total_tp'):
            tree_tp_total = self.academy_mode.get_tree_total_tp(current_tree_id)
        total_tp_required = skill.get('total_tp_required', 0)

        # 정보 박스
        info_x = self.width - 250
        info_y = 200
        info_width = 200
        info_height = 250
        
        pygame.draw.rect(self.screen, (40, 40, 60), 
                        (info_x, info_y, info_width, info_height))
        pygame.draw.rect(self.screen, (100, 150, 255), 
                        (info_x, info_y, info_width, info_height), 2)
                        
        # 스킬 이름
        name_surface = self.font_normal.render(skill['name'], True, (255, 255, 255))
        self.screen.blit(name_surface, (info_x + 10, info_y + 10))
        
        # 현재 레벨
        current_level = tree.get_skill_level(self.selected_skill)
        max_level = skill['max_level']
        level_text = f"레벨: {current_level}/{max_level}"
        level_surface = self.font_small.render(level_text, True, (200, 200, 200))
        self.screen.blit(level_surface, (info_x + 10, info_y + 40))
        
        # 설명
        desc_lines = self._wrap_text(skill['description'], 20)
        y_offset = 70
        for line in desc_lines:
            desc_surface = self.font_small.render(line, True, (180, 180, 180))
            self.screen.blit(desc_surface, (info_x + 10, info_y + y_offset))
            y_offset += 20

        tp_info_text = f"누적 TP: {tree_tp_total}"
        if total_tp_required:
            tp_info_text = f"누적 TP: {tree_tp_total}/{total_tp_required}"
        tp_surface = self.font_small.render(tp_info_text, True, (150, 200, 255))
        self.screen.blit(tp_surface, (info_x + 10, info_y + info_height - 60))

        # 비용
        cost_text = f"비용: {skill['cost']} TP"
        cost_surface = self.font_small.render(cost_text, True, (0, 255, 255))
        cost_pos_y = info_y + info_height - 40
        self.screen.blit(cost_surface, (info_x + 10, cost_pos_y))

        # 업그레이드 가능 여부
        can_upgrade = tree.can_upgrade(self.selected_skill, self.academy_mode.player_data['tp'])
        status_pos_y = info_y + info_height - 20
        if current_level >= max_level:
            badge = self._create_max_badge_surface((255, 215, 0))
            self.screen.blit(badge, (info_x + 10, status_pos_y))
        elif can_upgrade:
            upgrade_surface = self.font_small.render("클릭하여 업그레이드", True, (100, 255, 100))
            self.screen.blit(upgrade_surface, (info_x + 10, status_pos_y))
        else:
            upgrade_surface = self.font_small.render("업그레이드 불가", True, (255, 100, 100))
            self.screen.blit(upgrade_surface, (info_x + 10, status_pos_y))
        
    def _wrap_text(self, text: str, max_chars: int) -> List[str]:
        """텍스트 줄바꿈"""
        words = text.split(' ')
        lines = []
        current_line = ""
        
        for word in words:
            if len(current_line + word) <= max_chars:
                current_line += word + " "
            else:
                if current_line:
                    lines.append(current_line.strip())
                current_line = word + " "
                
        if current_line:
            lines.append(current_line.strip())
            
        return lines
