"""
Network UI - 네트워크 멀티플레이어 UI
호스트/조인 인터페이스 및 연결 상태 표시
"""

import pygame
from typing import Optional, Tuple, Dict, Any
from core.events import EventType, emit_event
from core.global_manager import GlobalManager
from network.network_manager import get_network_manager, NetworkMode


class NetworkUI:
    """네트워크 UI 시스템"""
    
    def __init__(self, screen: pygame.Surface):
        """네트워크 UI 초기화
        
        Args:
            screen: 화면 Surface
        """
        self.screen = screen
        self.global_manager = GlobalManager.get_instance()
        self.network_manager = get_network_manager()
        
        # UI 상태
        self.active = False
        self.current_menu = 'main'  # main, host, join, lobby
        self.selected_option = 0
        
        # 입력 필드
        self.input_active = False
        self.input_field = ''
        self.input_type = None  # 'port' or 'address'
        
        # 연결 정보
        self.host_port = '12345'
        self.join_address = '127.0.0.1'
        self.join_port = '12345'
        
        # 로비 정보
        self.lobby_players = []
        self.ready_state = False
        
        # 폰트
        try:
            self.font_title = pygame.font.Font("NanumSquareEB.ttf", 48)
            self.font_large = pygame.font.Font("NanumSquareB.ttf", 36)
            self.font_medium = pygame.font.Font("NanumSquareR.ttf", 24)
            self.font_small = pygame.font.Font("NanumSquareR.ttf", 18)
        except:
            self.font_title = pygame.font.Font(None, 48)
            self.font_large = pygame.font.Font(None, 36)
            self.font_medium = pygame.font.Font(None, 24)
            self.font_small = pygame.font.Font(None, 18)
            
        # 애니메이션
        self.animation_timer = 0
        self.pulse_effect = 0
        
        # 메뉴 옵션
        self.menu_options = {
            'main': ['Host Game', 'Join Game', 'Back'],
            'host': ['Start Hosting', 'Change Port', 'Back'],
            'join': ['Connect', 'Change Address', 'Change Port', 'Back'],
            'lobby': ['Ready', 'Start Game', 'Leave']
        }
        
    def open(self):
        """네트워크 UI 열기"""
        self.active = True
        self.current_menu = 'main'
        self.selected_option = 0
        emit_event(EventType.MENU_OPENED, {'type': 'network'})
        
    def close(self):
        """네트워크 UI 닫기"""
        self.active = False
        self.input_active = False
        
    def handle_event(self, event: pygame.event.Event):
        """이벤트 처리
        
        Args:
            event: pygame 이벤트
        """
        if not self.active:
            return
            
        if self.input_active:
            self._handle_input_event(event)
        else:
            self._handle_menu_event(event)
            
    def _handle_menu_event(self, event: pygame.event.Event):
        """메뉴 이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                if self.current_menu == 'main':
                    self.close()
                else:
                    self.current_menu = 'main'
                    self.selected_option = 0
                    
            elif event.key == pygame.K_UP:
                options = self.menu_options[self.current_menu]
                self.selected_option = (self.selected_option - 1) % len(options)
                
            elif event.key == pygame.K_DOWN:
                options = self.menu_options[self.current_menu]
                self.selected_option = (self.selected_option + 1) % len(options)
                
            elif event.key == pygame.K_RETURN:
                self._execute_option()
                
    def _handle_input_event(self, event: pygame.event.Event):
        """입력 필드 이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.input_active = False
                self.input_field = ''
                
            elif event.key == pygame.K_RETURN:
                self._confirm_input()
                
            elif event.key == pygame.K_BACKSPACE:
                self.input_field = self.input_field[:-1]
                
            else:
                # 텍스트 입력
                if event.unicode and len(self.input_field) < 15:
                    self.input_field += event.unicode
                    
    def _execute_option(self):
        """선택한 옵션 실행"""
        option = self.menu_options[self.current_menu][self.selected_option]
        
        if self.current_menu == 'main':
            if option == 'Host Game':
                self.current_menu = 'host'
                self.selected_option = 0
            elif option == 'Join Game':
                self.current_menu = 'join'
                self.selected_option = 0
            elif option == 'Back':
                self.close()
                
        elif self.current_menu == 'host':
            if option == 'Start Hosting':
                self._start_hosting()
            elif option == 'Change Port':
                self.input_active = True
                self.input_type = 'host_port'
                self.input_field = self.host_port
            elif option == 'Back':
                self.current_menu = 'main'
                self.selected_option = 0
                
        elif self.current_menu == 'join':
            if option == 'Connect':
                self._join_game()
            elif option == 'Change Address':
                self.input_active = True
                self.input_type = 'join_address'
                self.input_field = self.join_address
            elif option == 'Change Port':
                self.input_active = True
                self.input_type = 'join_port'
                self.input_field = self.join_port
            elif option == 'Back':
                self.current_menu = 'main'
                self.selected_option = 0
                
        elif self.current_menu == 'lobby':
            if option == 'Ready':
                self._toggle_ready()
            elif option == 'Start Game':
                self._start_multiplayer_game()
            elif option == 'Leave':
                self._leave_lobby()
                
    def _confirm_input(self):
        """입력 확인"""
        if self.input_type == 'host_port':
            try:
                port = int(self.input_field)
                if 1024 <= port <= 65535:
                    self.host_port = self.input_field
            except:
                pass
                
        elif self.input_type == 'join_address':
            # 간단한 IP 검증
            if '.' in self.input_field or self.input_field == 'localhost':
                self.join_address = self.input_field
                
        elif self.input_type == 'join_port':
            try:
                port = int(self.input_field)
                if 1024 <= port <= 65535:
                    self.join_port = self.input_field
            except:
                pass
                
        self.input_active = False
        self.input_field = ''
        
    def _start_hosting(self):
        """호스팅 시작"""
        port = int(self.host_port)
        if self.network_manager.start_host(port):
            self.current_menu = 'lobby'
            self.selected_option = 0
            self.lobby_players = ['Host (You)']
            
    def _join_game(self):
        """게임 참가"""
        port = int(self.join_port)
        if self.network_manager.connect_to_host(self.join_address, port):
            self.current_menu = 'lobby'
            self.selected_option = 0
            self.lobby_players = ['Host', 'You']
            
    def _toggle_ready(self):
        """준비 상태 토글"""
        self.ready_state = not self.ready_state
        # 준비 상태 패킷 전송
        from network.network_manager import PacketType
        self.network_manager.send_packet(
            PacketType.READY,
            {'ready': self.ready_state}
        )
        
    def _start_multiplayer_game(self):
        """멀티플레이어 게임 시작"""
        if self.network_manager.mode == NetworkMode.HOST:
            # 게임 시작 패킷 전송
            from network.network_manager import PacketType
            self.network_manager.send_packet(
                PacketType.START_GAME,
                {'stage': 1}
            )
            # 게임 시작 이벤트
            emit_event(EventType.GAME_START, {
                'stage': 1,
                'multiplayer': True
            })
            self.close()
            
    def _leave_lobby(self):
        """로비 나가기"""
        self.network_manager.disconnect()
        self.current_menu = 'main'
        self.selected_option = 0
        self.lobby_players = []
        
    def update(self, dt: float):
        """업데이트
        
        Args:
            dt: 델타 타임
        """
        if not self.active:
            return
            
        # 애니메이션 업데이트
        self.animation_timer += dt
        self.pulse_effect = abs(math.sin(self.animation_timer * 2)) * 0.3 + 0.7
        
        # 네트워크 상태 체크
        if self.current_menu == 'lobby':
            # 연결 상태 확인
            if self.network_manager.mode == NetworkMode.OFFLINE:
                # 연결이 끊어짐
                self.current_menu = 'main'
                self.selected_option = 0
                self.lobby_players = []
                
    def render(self, screen: pygame.Surface):
        """렌더링
        
        Args:
            screen: 화면 Surface
        """
        if not self.active:
            return
            
        # 배경 (반투명)
        overlay = pygame.Surface((self.global_manager.get('WIDTH', 600), 
                                 self.global_manager.get('HEIGHT', 750)))
        overlay.set_alpha(200)
        overlay.fill((0, 0, 0))
        screen.blit(overlay, (0, 0))
        
        # 현재 메뉴에 따라 렌더링
        if self.current_menu == 'main':
            self._render_main_menu(screen)
        elif self.current_menu == 'host':
            self._render_host_menu(screen)
        elif self.current_menu == 'join':
            self._render_join_menu(screen)
        elif self.current_menu == 'lobby':
            self._render_lobby(screen)
            
        # 입력 필드 렌더링
        if self.input_active:
            self._render_input_field(screen)
            
    def _render_main_menu(self, screen: pygame.Surface):
        """메인 메뉴 렌더링"""
        # 제목
        title_text = self.font_title.render("Network Play", True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 150))
        screen.blit(title_text, title_rect)
        
        # 옵션들
        options = self.menu_options['main']
        y_start = 300
        
        for i, option in enumerate(options):
            color = (255, 255, 0) if i == self.selected_option else (255, 255, 255)
            
            # 선택된 옵션 애니메이션
            if i == self.selected_option:
                scale = 1.0 + self.pulse_effect * 0.1
                font = pygame.font.Font(None, int(36 * scale))
                text = font.render(option, True, color)
            else:
                text = self.font_large.render(option, True, color)
                
            text_rect = text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 
                                             y_start + i * 60))
            screen.blit(text, text_rect)
            
    def _render_host_menu(self, screen: pygame.Surface):
        """호스트 메뉴 렌더링"""
        # 제목
        title_text = self.font_title.render("Host Game", True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 150))
        screen.blit(title_text, title_rect)
        
        # 포트 정보
        port_text = self.font_medium.render(f"Port: {self.host_port}", True, (200, 200, 200))
        port_rect = port_text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 250))
        screen.blit(port_text, port_rect)
        
        # 옵션들
        options = self.menu_options['host']
        y_start = 350
        
        for i, option in enumerate(options):
            color = (255, 255, 0) if i == self.selected_option else (255, 255, 255)
            text = self.font_large.render(option, True, color)
            text_rect = text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 
                                             y_start + i * 60))
            screen.blit(text, text_rect)
            
    def _render_join_menu(self, screen: pygame.Surface):
        """조인 메뉴 렌더링"""
        # 제목
        title_text = self.font_title.render("Join Game", True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 150))
        screen.blit(title_text, title_rect)
        
        # 연결 정보
        addr_text = self.font_medium.render(f"Address: {self.join_address}", True, (200, 200, 200))
        addr_rect = addr_text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 240))
        screen.blit(addr_text, addr_rect)
        
        port_text = self.font_medium.render(f"Port: {self.join_port}", True, (200, 200, 200))
        port_rect = port_text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 280))
        screen.blit(port_text, port_rect)
        
        # 옵션들
        options = self.menu_options['join']
        y_start = 350
        
        for i, option in enumerate(options):
            color = (255, 255, 0) if i == self.selected_option else (255, 255, 255)
            text = self.font_large.render(option, True, color)
            text_rect = text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 
                                             y_start + i * 60))
            screen.blit(text, text_rect)
            
    def _render_lobby(self, screen: pygame.Surface):
        """로비 렌더링"""
        # 제목
        title_text = self.font_title.render("Game Lobby", True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 100))
        screen.blit(title_text, title_rect)
        
        # 네트워크 모드 표시
        mode_text = f"Mode: {self.network_manager.mode.value.upper()}"
        mode_surface = self.font_medium.render(mode_text, True, (200, 200, 200))
        mode_rect = mode_surface.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 160))
        screen.blit(mode_surface, mode_rect)
        
        # 플레이어 목록
        y_start = 220
        players_title = self.font_medium.render("Players:", True, (255, 255, 255))
        screen.blit(players_title, (100, y_start))
        
        for i, player in enumerate(self.lobby_players):
            player_text = self.font_small.render(f"  {player}", True, (200, 200, 200))
            screen.blit(player_text, (100, y_start + 30 + i * 25))
            
        # 네트워크 통계
        stats = self.network_manager.get_network_stats()
        if stats['connections'] > 0:
            latency_text = f"Latency: {stats['average_latency']:.1f}ms"
            latency_surface = self.font_small.render(latency_text, True, (150, 255, 150))
            screen.blit(latency_surface, (400, 240))
            
        # 준비 상태
        if self.ready_state:
            ready_text = self.font_medium.render("READY", True, (0, 255, 0))
            ready_rect = ready_text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 380))
            screen.blit(ready_text, ready_rect)
            
        # 옵션들
        options = self.menu_options['lobby']
        y_start = 450
        
        # 호스트만 게임 시작 가능
        if self.network_manager.mode != NetworkMode.HOST:
            options = [opt for opt in options if opt != 'Start Game']
            
        for i, option in enumerate(options):
            color = (255, 255, 0) if i == self.selected_option else (255, 255, 255)
            text = self.font_large.render(option, True, color)
            text_rect = text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 
                                             y_start + i * 60))
            screen.blit(text, text_rect)
            
    def _render_input_field(self, screen: pygame.Surface):
        """입력 필드 렌더링"""
        # 배경 - SRCALPHA로 macOS/Windows 모두 알파 블렌딩 지원
        input_bg = pygame.Surface((400, 100), pygame.SRCALPHA)
        input_bg.fill((30, 30, 30, 240))
        bg_rect = input_bg.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 
                                           self.global_manager.get('HEIGHT', 750) // 2))
        screen.blit(input_bg, bg_rect)
        
        # 입력 타이틀
        title = "Enter " + self.input_type.replace('_', ' ').title()
        title_text = self.font_medium.render(title, True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 
                                                self.global_manager.get('HEIGHT', 750) // 2 - 20))
        screen.blit(title_text, title_rect)
        
        # 입력 텍스트
        input_text = self.font_large.render(self.input_field + "_", True, (255, 255, 0))
        input_rect = input_text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 
                                                self.global_manager.get('HEIGHT', 750) // 2 + 20))
        screen.blit(input_text, input_rect)


# 싱글톤 인스턴스
_network_ui = None

def get_network_ui(screen: pygame.Surface) -> NetworkUI:
    """네트워크 UI 싱글톤 반환"""
    global _network_ui
    if _network_ui is None:
        _network_ui = NetworkUI(screen)
    return _network_ui