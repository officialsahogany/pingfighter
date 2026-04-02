"""
온라인 멀티플레이 게임 모드
호스트/참가 → 로비(캐릭터/스테이지 선택) → 게임 시작
"""

import pygame
import socket
import time
import threading
import json
import os
from network.network_manager import get_network_manager, NetworkMode
from network.protocol import (
    OnlinePacketType, STAGE_MULTIPLAYER, WIN_GOAL_DEFAULT,
    serialize_lobby_state, deserialize_lobby_state,
    serialize_input, DEFAULT_PORT,
)

# ── IP 히스토리 저장/로드 ──
_IP_HISTORY_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ip_history.json")
_MAX_IP_HISTORY = 5


def _load_ip_history():
    try:
        if os.path.exists(_IP_HISTORY_FILE):
            with open(_IP_HISTORY_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("history", [])[:_MAX_IP_HISTORY]
    except Exception:
        pass
    return []


def _save_ip_history(history):
    try:
        with open(_IP_HISTORY_FILE, "w", encoding="utf-8") as f:
            json.dump({"history": history[:_MAX_IP_HISTORY]}, f, ensure_ascii=False)
    except Exception:
        pass


def _add_ip_to_history(ip_str):
    history = _load_ip_history()
    if ip_str in history:
        history.remove(ip_str)
    history.insert(0, ip_str)
    _save_ip_history(history[:_MAX_IP_HISTORY])


# 캐릭터 목록
CHARACTERS = [
    {"id": "ufo_player", "name": "스매셔", "color": (0, 200, 255),
     "stats": {"속도": 4, "파워": 7, "방어": 4}},
    {"id": "soldier", "name": "코만도", "color": (100, 200, 100),
     "stats": {"속도": 6, "파워": 6, "방어": 6}},
    {"id": "blacksmith", "name": "발토르", "color": (255, 180, 50),
     "stats": {"속도": 5, "파워": 7, "방어": 5}},
    {"id": "viper", "name": "바이퍼", "color": (180, 50, 255),
     "stats": {"속도": 4, "파워": 5, "방어": 3}},
]

# 스테이지 목록
STAGES = [
    {"num": 1, "name": "풍악보이 스테이지", "color": (120, 80, 60)},
    {"num": 2, "name": "악어장군 스테이지", "color": (40, 120, 50)},
    {"num": 3, "name": "멘헤라걸 스테이지", "color": (180, 80, 150)},
    {"num": 4, "name": "퐁크 스테이지", "color": (200, 160, 60)},
    {"num": 5, "name": "네메시스 스테이지", "color": (40, 80, 160)},
    {"num": 6, "name": "홍련 스테이지", "color": (200, 50, 30)},
]

# UI 색상
BG_COLOR = (18, 22, 32)
PANEL_COLOR = (30, 36, 50)
ACCENT_COLOR = (0, 180, 255)
READY_COLOR = (50, 220, 100)
TEXT_COLOR = (220, 225, 235)
DIM_COLOR = (100, 110, 130)
HIGHLIGHT_COLOR = (255, 220, 50)


class OnlineMultiplayer:
    """온라인 멀티플레이 관리 클래스"""

    def __init__(self, screen, width, height, get_font_func=None):
        self.screen = screen
        self.width = width
        self.height = height
        self.get_font = get_font_func or (lambda s, **kw: pygame.font.Font(None, s))
        self.clock = pygame.time.Clock()
        self.net = get_network_manager()
        self.running = True

        # 로비 상태
        self.is_host = False
        self.my_character_idx = 0
        self.my_ready = False
        self.opponent_ready = False
        self.selected_stage_idx = 0
        self.items_enabled = True
        self.opponent_character_idx = -1

        # 결과
        self.result_p1_char = None
        self.result_p2_char = None
        self.result_stage = 1
        self.result_items = True
        self.game_should_start = False

    def run(self):
        """메인 플로우: 모드 선택 → 접속 → 로비 → 게임 시작"""
        mode = self._show_mode_select()
        if mode is None:
            return None

        self.is_host = (mode == "host")

        if self.is_host:
            success = self._host_wait_screen()
        else:
            success = self._client_connect_screen()

        if not success:
            self.net.disconnect()
            self.net.reset_online_state()
            return None

        # 로비
        result = self._lobby_screen()
        if result is None:
            self.net.disconnect()
            self.net.reset_online_state()
            return None

        return result

    # ──────────────────────────────────────────────
    # 모드 선택 화면 (호스트/참가)
    # ──────────────────────────────────────────────
    def _show_mode_select(self):
        """호스트/참가 선택. 'host', 'join', 또는 None(취소)"""
        selected = 0
        options = ["방 만들기 (호스트)", "참가하기", "뒤로"]
        option_rects = []

        while self.running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return None
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        return None
                    if event.key in (pygame.K_UP, pygame.K_w):
                        selected = (selected - 1) % len(options)
                    if event.key in (pygame.K_DOWN, pygame.K_s):
                        selected = (selected + 1) % len(options)
                    if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                        if selected == 0:
                            return "host"
                        elif selected == 1:
                            return "join"
                        else:
                            return None
                if event.type == pygame.MOUSEMOTION:
                    mx, my = event.pos
                    for i, r in enumerate(option_rects):
                        if r.collidepoint(mx, my):
                            selected = i
                if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    mx, my = event.pos
                    for i, r in enumerate(option_rects):
                        if r.collidepoint(mx, my):
                            if i == 0:
                                return "host"
                            elif i == 1:
                                return "join"
                            else:
                                return None

            self.screen.fill(BG_COLOR)
            title_font = self.get_font(36)
            option_font = self.get_font(24)

            title_surf = title_font.render("온라인 대전", True, ACCENT_COLOR)
            title_rect = title_surf.get_rect(center=(self.width // 2, 120))
            self.screen.blit(title_surf, title_rect)

            option_rects = []
            for i, opt in enumerate(options):
                is_sel = i == selected
                color = HIGHLIGHT_COLOR if is_sel else TEXT_COLOR
                btn_rect = pygame.Rect(self.width // 2 - 160, 258 + i * 60, 320, 44)
                option_rects.append(btn_rect)
                bg = (40, 50, 70) if is_sel else PANEL_COLOR
                pygame.draw.rect(self.screen, bg, btn_rect, border_radius=8)
                pygame.draw.rect(self.screen, color, btn_rect, 2 if is_sel else 1, border_radius=8)
                surf = option_font.render(opt, True, color)
                self.screen.blit(surf, surf.get_rect(center=btn_rect.center))

            hint_font = self.get_font(16)
            hint = hint_font.render("↑↓/마우스 선택  Enter/클릭 확인  ESC 뒤로", True, DIM_COLOR)
            self.screen.blit(hint, hint.get_rect(center=(self.width // 2, self.height - 40)))

            pygame.display.flip()
            self.clock.tick(60)
        return None

    # ──────────────────────────────────────────────
    # 호스트 대기 화면
    # ──────────────────────────────────────────────
    def _host_wait_screen(self):
        """호스트 시작, 상대방 접속 대기. True/False"""
        success = self.net.start_host(DEFAULT_PORT)
        if not success:
            self._show_message("서버 시작 실패", "포트가 사용 중일 수 있습니다.", 2.0)
            return False

        self.net.online_mode = True
        local_ip = self.net.get_local_ip()
        dots_timer = 0

        while self.running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return False
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        return False

            # 상대방 접속 확인
            if self.net.connections:
                self.net.online_connected = True
                # 핸드셰이크 대기
                time.sleep(0.3)
                # 로비 초기 상태 전송
                self._init_lobby_state()
                return True

            # UI
            self.screen.fill(BG_COLOR)
            title_font = self.get_font(28)
            info_font = self.get_font(22)
            ip_font = self.get_font(32)

            title = title_font.render("상대방 대기 중", True, ACCENT_COLOR)
            self.screen.blit(title, title.get_rect(center=(self.width // 2, 150)))

            # IP 표시
            ip_label = info_font.render("접속 IP:", True, DIM_COLOR)
            self.screen.blit(ip_label, ip_label.get_rect(center=(self.width // 2, 280)))

            ip_text = ip_font.render(f"{local_ip}:{DEFAULT_PORT}", True, HIGHLIGHT_COLOR)
            ip_rect = ip_text.get_rect(center=(self.width // 2, 320))
            # 배경 박스
            box_rect = ip_rect.inflate(40, 20)
            pygame.draw.rect(self.screen, PANEL_COLOR, box_rect, border_radius=8)
            pygame.draw.rect(self.screen, ACCENT_COLOR, box_rect, 2, border_radius=8)
            self.screen.blit(ip_text, ip_rect)

            dots_timer = (dots_timer + 1) % 180
            dots = "." * ((dots_timer // 30) % 4)
            wait_text = info_font.render(f"대기 중{dots}", True, DIM_COLOR)
            self.screen.blit(wait_text, wait_text.get_rect(center=(self.width // 2, 420)))

            hint = self.get_font(16).render("이 IP를 상대방에게 알려주세요. ESC 취소", True, DIM_COLOR)
            self.screen.blit(hint, hint.get_rect(center=(self.width // 2, self.height - 40)))

            pygame.display.flip()
            self.clock.tick(60)
        return False

    # ──────────────────────────────────────────────
    # 클라이언트 접속 화면 (IP 입력)
    # ──────────────────────────────────────────────
    def _try_connect(self, ip_str):
        """IP 문자열로 접속 시도. 성공 시 True + 히스토리 저장."""
        host = ip_str.strip()
        if not host:
            return False, "IP를 입력하세요"
        port = DEFAULT_PORT
        if ":" in host:
            parts = host.rsplit(":", 1)
            host = parts[0]
            try:
                port = int(parts[1])
            except ValueError:
                pass
        success = self.net.connect_to_host(host, port)
        if success:
            self.net.online_mode = True
            self.net.online_connected = True
            _add_ip_to_history(ip_str.strip())
            time.sleep(0.3)
            return True, ""
        return False, "접속 실패 - IP 주소를 확인하세요"

    def _client_connect_screen(self):
        """IP 입력 → 접속. True/False"""
        ip_history = _load_ip_history()
        ip_text = ip_history[0] if ip_history else ""
        connecting = False
        error_msg = ""
        cursor_timer = 0
        history_rects = []

        while self.running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return False
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        if connecting:
                            connecting = False
                        else:
                            return False
                    elif event.key == pygame.K_RETURN and not connecting:
                        connecting = True
                        error_msg = ""
                        ok, err = self._try_connect(ip_text)
                        if ok:
                            return True
                        connecting = False
                        error_msg = err
                    elif event.key == pygame.K_BACKSPACE:
                        ip_text = ip_text[:-1]
                    elif not connecting:
                        if event.unicode and event.unicode.isprintable():
                            if len(ip_text) < 21:
                                ip_text += event.unicode
                # 마우스: 히스토리 클릭 (한 번=선택, 더블클릭=바로 접속)
                if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1 and not connecting:
                    mx, my = event.pos
                    for i, rect in enumerate(history_rects):
                        if rect.collidepoint(mx, my) and i < len(ip_history):
                            if ip_text.strip() == ip_history[i]:
                                # 이미 선택된 IP 다시 클릭 → 바로 접속
                                connecting = True
                                error_msg = ""
                                ok, err = self._try_connect(ip_text)
                                if ok:
                                    return True
                                connecting = False
                                error_msg = err
                            else:
                                ip_text = ip_history[i]
                            break

            # UI
            self.screen.fill(BG_COLOR)
            cx = self.width // 2
            title_font = self.get_font(28)
            input_font = self.get_font(28)
            info_font = self.get_font(18)
            hist_font = self.get_font(16)

            title = title_font.render("IP 주소 입력", True, ACCENT_COLOR)
            self.screen.blit(title, title.get_rect(center=(cx, 100)))

            # IP 입력 필드
            input_box = pygame.Rect(cx - 180, 180, 360, 50)
            pygame.draw.rect(self.screen, PANEL_COLOR, input_box, border_radius=8)
            pygame.draw.rect(self.screen, ACCENT_COLOR if not error_msg else (255, 80, 80),
                             input_box, 2, border_radius=8)

            cursor_timer = (cursor_timer + 1) % 60
            cursor = "|" if cursor_timer < 30 and not connecting else ""
            display_text = ip_text + cursor if not connecting else ip_text
            text_surf = input_font.render(display_text, True, TEXT_COLOR)
            self.screen.blit(text_surf, text_surf.get_rect(midleft=(input_box.x + 15, input_box.centery)))

            if not ip_text:
                placeholder = info_font.render("예: 192.168.0.10", True, DIM_COLOR)
                self.screen.blit(placeholder, placeholder.get_rect(midleft=(input_box.x + 15, input_box.centery)))

            if connecting:
                conn_text = info_font.render("접속 중...", True, ACCENT_COLOR)
                self.screen.blit(conn_text, conn_text.get_rect(center=(cx, 260)))

            if error_msg:
                err_surf = info_font.render(error_msg, True, (255, 80, 80))
                self.screen.blit(err_surf, err_surf.get_rect(center=(cx, 260)))

            # ── 최근 접속 IP 히스토리 ──
            history_rects = []
            if ip_history:
                hist_label = hist_font.render("최근 접속", True, DIM_COLOR)
                self.screen.blit(hist_label, hist_label.get_rect(center=(cx, 310)))

                for i, saved_ip in enumerate(ip_history):
                    btn_rect = pygame.Rect(cx - 150, 330 + i * 42, 300, 36)
                    history_rects.append(btn_rect)
                    is_hover = btn_rect.collidepoint(pygame.mouse.get_pos())
                    is_current = (saved_ip == ip_text.strip())
                    bg = (50, 60, 80) if is_hover else (35, 42, 58) if is_current else PANEL_COLOR
                    border = ACCENT_COLOR if is_current else (60, 70, 90)
                    pygame.draw.rect(self.screen, bg, btn_rect, border_radius=6)
                    pygame.draw.rect(self.screen, border, btn_rect, 1, border_radius=6)
                    ip_surf = hist_font.render(saved_ip, True, ACCENT_COLOR if is_current else TEXT_COLOR)
                    self.screen.blit(ip_surf, ip_surf.get_rect(center=btn_rect.center))

            hint = self.get_font(14).render("Enter/클릭 접속  ESC 뒤로", True, DIM_COLOR)
            self.screen.blit(hint, hint.get_rect(center=(cx, self.height - 30)))

            pygame.display.flip()
            self.clock.tick(60)
        return False

    # ──────────────────────────────────────────────
    # 로비 화면
    # ──────────────────────────────────────────────
    def _lobby_screen(self):
        """로비: 캐릭터 선택 + 스테이지 선택 + 레디"""
        self._init_lobby_state()
        self.my_character_idx = 0
        self.my_ready = False
        self.selected_stage_idx = 0
        self.items_enabled = True
        focus = "character"  # "character", "stage", "items", "ready"

        # 마우스 클릭 히트 영역 (draw에서 갱신)
        self._lobby_hit = {
            'char_left': None, 'char_right': None, 'char_box': None,
            'stage_left': None, 'stage_right': None, 'stage_box': None,
            'items_box': None, 'ready_btn': None,
        }

        while self.running:
            # 네트워크 상태 체크
            if not self.net.online_connected and not self.net.connections:
                self._show_message("연결 끊김", "상대방과의 연결이 끊어졌습니다.", 2.0)
                return None

            # 로비 상태 동기화 수신 처리
            if self.net.online_lobby_state:
                lobby = self.net.online_lobby_state
                if self.is_host:
                    opp_char = lobby.get('client_character')
                    self.opponent_ready = lobby.get('client_ready', False)
                else:
                    opp_char = lobby.get('host_character')
                    self.opponent_ready = lobby.get('host_ready', False)
                    self.selected_stage_idx = max(0, lobby.get('stage', 1) - 1)
                    self.items_enabled = lobby.get('items_enabled', True)

                if opp_char:
                    self.opponent_character_idx = next(
                        (i for i, c in enumerate(CHARACTERS) if c["id"] == opp_char), -1)

            # 게임 시작 확인
            if self.net.online_game_started:
                return self._build_result()

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return None
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        if self.my_ready:
                            self.my_ready = False
                            self._send_ready(False)
                        else:
                            return None
                    elif not self.my_ready:
                        self._handle_lobby_input(event, focus)
                        if event.key == pygame.K_TAB:
                            if focus == "character":
                                focus = "stage" if self.is_host else "ready"
                            elif focus == "stage":
                                focus = "items"
                            elif focus == "items":
                                focus = "ready"
                            else:
                                focus = "character"
                    if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                        if focus == "ready" or self.my_ready:
                            self.my_ready = not self.my_ready
                            self._send_ready(self.my_ready)
                            if self.is_host and self.my_ready and self.opponent_ready:
                                self._send_game_start()
                                return self._build_result()

                # ── 마우스 클릭 처리 ──
                if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    mx, my = event.pos
                    h = self._lobby_hit

                    # 캐릭터 좌/우 화살표 클릭
                    if not self.my_ready:
                        if h['char_left'] and h['char_left'].collidepoint(mx, my):
                            self.my_character_idx = (self.my_character_idx - 1) % len(CHARACTERS)
                            self._send_char_select()
                            focus = "character"
                        elif h['char_right'] and h['char_right'].collidepoint(mx, my):
                            self.my_character_idx = (self.my_character_idx + 1) % len(CHARACTERS)
                            self._send_char_select()
                            focus = "character"
                        elif h['char_box'] and h['char_box'].collidepoint(mx, my):
                            focus = "character"

                        # 스테이지 좌/우 화살표 클릭 (호스트만)
                        if self.is_host:
                            if h['stage_left'] and h['stage_left'].collidepoint(mx, my):
                                self.selected_stage_idx = (self.selected_stage_idx - 1) % len(STAGES)
                                self._send_stage_select()
                                focus = "stage"
                            elif h['stage_right'] and h['stage_right'].collidepoint(mx, my):
                                self.selected_stage_idx = (self.selected_stage_idx + 1) % len(STAGES)
                                self._send_stage_select()
                                focus = "stage"
                            elif h['stage_box'] and h['stage_box'].collidepoint(mx, my):
                                focus = "stage"

                        # 아이템 토글 클릭 (호스트만)
                        if self.is_host and h['items_box'] and h['items_box'].collidepoint(mx, my):
                            self.items_enabled = not self.items_enabled
                            self._send_stage_select()
                            focus = "items"

                    # 레디 버튼 클릭
                    if h['ready_btn'] and h['ready_btn'].collidepoint(mx, my):
                        self.my_ready = not self.my_ready
                        self._send_ready(self.my_ready)
                        focus = "ready"
                        if self.is_host and self.my_ready and self.opponent_ready:
                            self._send_game_start()
                            return self._build_result()

            self._draw_lobby(focus)
            pygame.display.flip()
            self.clock.tick(60)
        return None

    def _handle_lobby_input(self, event, focus):
        """로비 입력 처리"""
        if focus == "character":
            if event.key in (pygame.K_LEFT, pygame.K_a):
                self.my_character_idx = (self.my_character_idx - 1) % len(CHARACTERS)
                self._send_char_select()
            elif event.key in (pygame.K_RIGHT, pygame.K_d):
                self.my_character_idx = (self.my_character_idx + 1) % len(CHARACTERS)
                self._send_char_select()
        elif focus == "stage" and self.is_host:
            if event.key in (pygame.K_LEFT, pygame.K_a):
                self.selected_stage_idx = (self.selected_stage_idx - 1) % len(STAGES)
                self._send_stage_select()
            elif event.key in (pygame.K_RIGHT, pygame.K_d):
                self.selected_stage_idx = (self.selected_stage_idx + 1) % len(STAGES)
                self._send_stage_select()
        elif focus == "items" and self.is_host:
            if event.key in (pygame.K_LEFT, pygame.K_RIGHT, pygame.K_a, pygame.K_d):
                self.items_enabled = not self.items_enabled
                self._send_stage_select()

    def _draw_lobby(self, focus):
        """로비 화면 그리기"""
        self.screen.fill(BG_COLOR)
        cx = self.width // 2

        # 타이틀
        title_font = self.get_font(28)
        title = title_font.render("대전 로비", True, ACCENT_COLOR)
        self.screen.blit(title, title.get_rect(center=(cx, 30)))

        # 핑 표시
        if self.net.connections:
            ping = self.net.connections[0].latency
            ping_font = self.get_font(14)
            ping_text = ping_font.render(f"Ping: {ping:.0f}ms", True, DIM_COLOR)
            self.screen.blit(ping_text, (self.width - 100, 10))

        # ── 캐릭터 선택 영역 ──
        self._draw_character_panel(cx, 120, focus == "character")

        # ── 스테이지 선택 (호스트만 조작 가능) ──
        self._draw_stage_panel(cx, 400, focus == "stage")

        # ── 아이템 모드 ──
        self._draw_items_toggle(cx, 500, focus == "items")

        # ── 레디 버튼 ──
        self._draw_ready_area(cx, 600, focus == "ready")

        # 조작 힌트
        hint_font = self.get_font(14)
        hint = hint_font.render("←→/클릭 선택  TAB 항목이동  Enter/클릭 레디  ESC 나가기", True, DIM_COLOR)
        self.screen.blit(hint, hint.get_rect(center=(cx, self.height - 20)))

    def _draw_character_panel(self, cx, y, is_focused):
        """캐릭터 선택 패널 그리기"""
        label_font = self.get_font(18)
        char_font = self.get_font(22)
        stat_font = self.get_font(14)

        # 내 캐릭터 (왼쪽)
        my_char = CHARACTERS[self.my_character_idx]
        role = "호스트 (P1)" if self.is_host else "참가자 (P2)"
        my_label = label_font.render(f"나 ({role})", True, ACCENT_COLOR)
        self.screen.blit(my_label, my_label.get_rect(center=(cx - 140, y)))

        # 내 캐릭터 박스
        my_box = pygame.Rect(cx - 260, y + 20, 240, 200)
        border_color = HIGHLIGHT_COLOR if is_focused else my_char["color"]
        pygame.draw.rect(self.screen, PANEL_COLOR, my_box, border_radius=10)
        pygame.draw.rect(self.screen, border_color, my_box, 2 if not is_focused else 3, border_radius=10)

        name_surf = char_font.render(my_char["name"], True, my_char["color"])
        self.screen.blit(name_surf, name_surf.get_rect(center=(my_box.centerx, my_box.y + 50)))

        # 스탯
        stats_y = my_box.y + 90
        for stat_name, stat_val in my_char["stats"].items():
            stat_text = stat_font.render(f"{stat_name}: {'■' * stat_val}{'□' * (10 - stat_val)}",
                                         True, DIM_COLOR)
            self.screen.blit(stat_text, stat_text.get_rect(center=(my_box.centerx, stats_y)))
            stats_y += 22

        # 화살표 (항상 표시, 레디 안 했을 때)
        self._lobby_hit['char_box'] = my_box
        if not self.my_ready:
            arrow_font = self.get_font(28)
            left_arrow = arrow_font.render("◀", True, HIGHLIGHT_COLOR if is_focused else DIM_COLOR)
            right_arrow = arrow_font.render("▶", True, HIGHLIGHT_COLOR if is_focused else DIM_COLOR)
            la_rect = left_arrow.get_rect(midright=(my_box.left - 5, my_box.centery))
            ra_rect = right_arrow.get_rect(midleft=(my_box.right + 5, my_box.centery))
            self.screen.blit(left_arrow, la_rect)
            self.screen.blit(right_arrow, ra_rect)
            self._lobby_hit['char_left'] = la_rect.inflate(10, 20)
            self._lobby_hit['char_right'] = ra_rect.inflate(10, 20)

        # VS
        vs_font = self.get_font(36)
        vs_surf = vs_font.render("VS", True, (255, 80, 80))
        self.screen.blit(vs_surf, vs_surf.get_rect(center=(cx, y + 120)))

        # 상대 캐릭터 (오른쪽)
        opp_label = label_font.render("상대방", True, (255, 100, 100))
        self.screen.blit(opp_label, opp_label.get_rect(center=(cx + 140, y)))

        opp_box = pygame.Rect(cx + 20, y + 20, 240, 200)
        pygame.draw.rect(self.screen, PANEL_COLOR, opp_box, border_radius=10)

        if self.opponent_character_idx >= 0:
            opp_char = CHARACTERS[self.opponent_character_idx]
            pygame.draw.rect(self.screen, opp_char["color"], opp_box, 2, border_radius=10)
            opp_name = char_font.render(opp_char["name"], True, opp_char["color"])
            self.screen.blit(opp_name, opp_name.get_rect(center=(opp_box.centerx, opp_box.y + 50)))

            stats_y = opp_box.y + 90
            for stat_name, stat_val in opp_char["stats"].items():
                stat_text = stat_font.render(f"{stat_name}: {'■' * stat_val}{'□' * (10 - stat_val)}",
                                             True, DIM_COLOR)
                self.screen.blit(stat_text, stat_text.get_rect(center=(opp_box.centerx, stats_y)))
                stats_y += 22
        else:
            pygame.draw.rect(self.screen, DIM_COLOR, opp_box, 2, border_radius=10)
            wait = char_font.render("대기 중...", True, DIM_COLOR)
            self.screen.blit(wait, wait.get_rect(center=(opp_box.centerx, opp_box.centery)))

        # 레디 상태 표시
        if self.my_ready:
            ready_surf = label_font.render("READY!", True, READY_COLOR)
            self.screen.blit(ready_surf, ready_surf.get_rect(center=(my_box.centerx, my_box.bottom + 15)))
        if self.opponent_ready:
            ready_surf = label_font.render("READY!", True, READY_COLOR)
            self.screen.blit(ready_surf, ready_surf.get_rect(center=(opp_box.centerx, opp_box.bottom + 15)))

    def _draw_stage_panel(self, cx, y, is_focused):
        """스테이지 선택 패널"""
        label_font = self.get_font(18)
        stage_font = self.get_font(22)

        stage = STAGES[self.selected_stage_idx]
        label = label_font.render("스테이지", True, ACCENT_COLOR if is_focused else DIM_COLOR)
        self.screen.blit(label, label.get_rect(center=(cx, y)))

        stage_box = pygame.Rect(cx - 150, y + 20, 300, 45)
        pygame.draw.rect(self.screen, PANEL_COLOR, stage_box, border_radius=8)
        border = HIGHLIGHT_COLOR if is_focused else stage["color"]
        pygame.draw.rect(self.screen, border, stage_box, 2 if not is_focused else 3, border_radius=8)

        stage_text = stage_font.render(stage["name"], True, stage["color"])
        self.screen.blit(stage_text, stage_text.get_rect(center=stage_box.center))

        self._lobby_hit['stage_box'] = stage_box
        if self.is_host and not self.my_ready:
            arrow_font = self.get_font(24)
            left = arrow_font.render("◀", True, HIGHLIGHT_COLOR if is_focused else DIM_COLOR)
            right = arrow_font.render("▶", True, HIGHLIGHT_COLOR if is_focused else DIM_COLOR)
            sl_rect = left.get_rect(midright=(stage_box.left - 8, stage_box.centery))
            sr_rect = right.get_rect(midleft=(stage_box.right + 8, stage_box.centery))
            self.screen.blit(left, sl_rect)
            self.screen.blit(right, sr_rect)
            self._lobby_hit['stage_left'] = sl_rect.inflate(10, 20)
            self._lobby_hit['stage_right'] = sr_rect.inflate(10, 20)

        if not self.is_host:
            host_label = self.get_font(12).render("(호스트가 선택)", True, DIM_COLOR)
            self.screen.blit(host_label, host_label.get_rect(center=(cx, y + 75)))

    def _draw_items_toggle(self, cx, y, is_focused):
        """아이템 모드 토글"""
        label_font = self.get_font(18)
        toggle_font = self.get_font(20)

        label = label_font.render("아이템", True, ACCENT_COLOR if is_focused else DIM_COLOR)
        self.screen.blit(label, label.get_rect(center=(cx, y)))

        toggle_box = pygame.Rect(cx - 100, y + 20, 200, 40)
        pygame.draw.rect(self.screen, PANEL_COLOR, toggle_box, border_radius=8)
        border = HIGHLIGHT_COLOR if is_focused else DIM_COLOR
        pygame.draw.rect(self.screen, border, toggle_box, 2 if not is_focused else 3, border_radius=8)

        if self.items_enabled:
            text = toggle_font.render("아이템전 ON", True, READY_COLOR)
        else:
            text = toggle_font.render("노아이템전", True, (255, 100, 100))
        self.screen.blit(text, text.get_rect(center=toggle_box.center))
        self._lobby_hit['items_box'] = toggle_box

        if not self.is_host:
            host_label = self.get_font(12).render("(호스트가 선택)", True, DIM_COLOR)
            self.screen.blit(host_label, host_label.get_rect(center=(cx, y + 70)))

    def _draw_ready_area(self, cx, y, is_focused):
        """레디 버튼"""
        btn_font = self.get_font(24)
        btn_rect = pygame.Rect(cx - 100, y, 200, 50)

        if self.my_ready:
            pygame.draw.rect(self.screen, READY_COLOR, btn_rect, border_radius=10)
            text = btn_font.render("READY!", True, BG_COLOR)
        else:
            color = HIGHLIGHT_COLOR if is_focused else DIM_COLOR
            pygame.draw.rect(self.screen, PANEL_COLOR, btn_rect, border_radius=10)
            pygame.draw.rect(self.screen, color, btn_rect, 2 if not is_focused else 3, border_radius=10)
            text = btn_font.render("준비", True, color)

        self.screen.blit(text, text.get_rect(center=btn_rect.center))
        self._lobby_hit['ready_btn'] = btn_rect

        if self.my_ready and self.opponent_ready:
            start_text = self.get_font(16).render("양쪽 레디 완료! 게임 시작...", True, READY_COLOR)
            self.screen.blit(start_text, start_text.get_rect(center=(cx, y + 65)))

    # ──────────────────────────────────────────────
    # 네트워크 통신
    # ──────────────────────────────────────────────
    def _init_lobby_state(self):
        """로비 초기 상태 설정"""
        lobby = {
            'host_character': CHARACTERS[0]["id"],
            'client_character': None,
            'stage': 1,
            'items_enabled': True,
            'host_ready': False,
            'client_ready': False,
            'host_name': 'Player 1',
            'client_name': 'Player 2',
        }
        self.net.online_lobby_state = lobby
        if self.is_host:
            self.net.send_online_packet(
                OnlinePacketType.LOBBY_STATE,
                serialize_lobby_state(lobby))

    def _send_char_select(self):
        """내 캐릭터 선택 전송"""
        char_id = CHARACTERS[self.my_character_idx]["id"]
        self.net.send_online_packet(
            OnlinePacketType.CHAR_SELECT,
            {'character': char_id})
        # 로컬 상태 업데이트
        if self.net.online_lobby_state:
            if self.is_host:
                self.net.online_lobby_state['host_character'] = char_id
            else:
                self.net.online_lobby_state['client_character'] = char_id

    def _send_stage_select(self):
        """스테이지/아이템 설정 전송 (호스트만)"""
        if not self.is_host:
            return
        stage_num = STAGES[self.selected_stage_idx]["num"]
        self.net.send_online_packet(
            OnlinePacketType.STAGE_SELECT,
            {'stage': stage_num, 'items': self.items_enabled})
        if self.net.online_lobby_state:
            self.net.online_lobby_state['stage'] = stage_num
            self.net.online_lobby_state['items_enabled'] = self.items_enabled

    def _send_ready(self, ready):
        """레디 상태 전송"""
        self.net.send_online_packet(
            OnlinePacketType.LOBBY_READY,
            {'ready': ready})
        if self.net.online_lobby_state:
            if self.is_host:
                self.net.online_lobby_state['host_ready'] = ready
            else:
                self.net.online_lobby_state['client_ready'] = ready

    def _send_game_start(self):
        """게임 시작 신호 전송 (호스트)"""
        self.net.send_online_packet(OnlinePacketType.LOBBY_START, {})
        self.net.online_game_started = True

    # ──────────────────────────────────────────────
    # 결과 빌드
    # ──────────────────────────────────────────────
    def _build_result(self):
        """로비 결과 → 게임 시작 정보 반환"""
        my_char = CHARACTERS[self.my_character_idx]["id"]
        opp_char = (CHARACTERS[self.opponent_character_idx]["id"]
                     if self.opponent_character_idx >= 0 else "ufo_player")
        stage = STAGES[self.selected_stage_idx]["num"]

        if self.is_host:
            return {
                'is_host': True,
                'p1_character': my_char,
                'p2_character': opp_char,
                'stage': stage,
                'items_enabled': self.items_enabled,
            }
        else:
            return {
                'is_host': False,
                'p1_character': opp_char,  # 호스트가 P1
                'p2_character': my_char,   # 나(클라이언트)가 P2
                'stage': stage,
                'items_enabled': self.items_enabled,
            }

    # ──────────────────────────────────────────────
    # 유틸리티
    # ──────────────────────────────────────────────
    def _show_message(self, title, subtitle, duration=2.0):
        """간단한 메시지 표시"""
        start = time.time()
        while time.time() - start < duration:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return
            self.screen.fill(BG_COLOR)
            t_font = self.get_font(28)
            s_font = self.get_font(18)
            t_surf = t_font.render(title, True, (255, 80, 80))
            s_surf = s_font.render(subtitle, True, DIM_COLOR)
            self.screen.blit(t_surf, t_surf.get_rect(center=(self.width // 2, self.height // 2 - 20)))
            self.screen.blit(s_surf, s_surf.get_rect(center=(self.width // 2, self.height // 2 + 20)))
            pygame.display.flip()
            self.clock.tick(60)


def run_online_multiplayer(screen, width, height, get_font_func=None):
    """온라인 멀티플레이 진입점

    Returns:
        dict - 게임 시작 정보 또는 None (취소 시)
    """
    online = OnlineMultiplayer(screen, width, height, get_font_func)
    return online.run()
