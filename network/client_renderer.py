"""
온라인 멀티플레이 - 클라이언트 렌더러
호스트에서 수신한 게임 상태를 Y축 반전하여 렌더링한다.
클라이언트(P2)는 자기 패들이 아래, 상대(P1)가 위에 보인다.
"""

import pygame
import time
import math
from network.protocol import (
    OnlinePacketType, serialize_input, deserialize_game_frame,
)


# 색상
BG_COLOR = (18, 22, 32)
P1_COLOR = (0, 150, 255)      # 호스트 (상대방) - 파란색
P2_COLOR = (255, 100, 100)    # 나 (클라이언트) - 빨간색
BALL_COLOR = (255, 255, 255)
TEXT_COLOR = (220, 225, 235)
DIM_COLOR = (100, 110, 130)
ACCENT_COLOR = (0, 180, 255)
SCORE_COLOR = (255, 220, 50)


class ClientRenderer:
    """클라이언트 렌더링 루프.
    호스트에서 GAME_FRAME 패킷을 수신하여 화면에 렌더링한다.
    """

    def __init__(self, screen, width, height, get_font_func, net_manager):
        self.screen = screen
        self.width = width
        self.height = height
        self.get_font = get_font_func
        self.net = net_manager
        self.clock = pygame.time.Clock()
        self.running = True

        # 게임 상태
        self.ball_x = width // 2
        self.ball_y = height // 2
        self.ball_vx = 0
        self.ball_vy = 0
        self.p1_x = width // 2 - 50  # 상대방 (호스트)
        self.p2_x = width // 2 - 50  # 나 (클라이언트)
        self.p1_score = 0
        self.p2_score = 0
        self.p1_gauge = 0
        self.p2_gauge = 0
        self.game_over = None
        self.waiting_serve = False
        self.round_wins = 0   # 호스트 기준 (P1 승리 수)
        self.round_losses = 0 # 호스트 기준 (P2 승리 수 = 내 승리 수)

        # P2 패들 예측 (로컬 입력 즉시 반영)
        self.local_p2_x = width // 2 - 50
        self.local_input = {}

        # 볼 트레일
        self.ball_trail = []
        self.max_trail = 8

        # 연결 상태
        self.disconnect_timer = 0
        self.last_frame_time = time.time()

        # 패들 크기
        self.paddle_width = 100
        self.paddle_height = 15
        self.ball_size = 12

    def run(self):
        """클라이언트 메인 루프"""
        while self.running:
            dt = self.clock.tick(60) / 1000.0

            # 이벤트 처리
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.running = False
                    return
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        self.running = False
                        return

            # 입력 수집 & 전송
            self._collect_and_send_input()

            # 네트워크 상태 수신
            self._receive_state()

            # 연결 체크
            if not self.net.connections or not self.net.online_connected:
                self.disconnect_timer += dt
                if self.disconnect_timer > 5.0:
                    self._show_disconnect()
                    return
            else:
                self.disconnect_timer = 0

            # 렌더링
            self._draw()
            pygame.display.flip()

            # 게임 종료 체크
            if self.game_over:
                self._show_result()
                return

    def _collect_and_send_input(self):
        """로컬 입력 수집 → 서버 전송 + 로컬 패들 예측"""
        keys = pygame.key.get_pressed()

        self.local_input = {
            'left': keys[pygame.K_LEFT] or keys[pygame.K_a],
            'right': keys[pygame.K_RIGHT] or keys[pygame.K_d],
            'up': keys[pygame.K_UP] or keys[pygame.K_w],
            'down': keys[pygame.K_DOWN] or keys[pygame.K_s],
            'dash': keys[pygame.K_LSHIFT] or keys[pygame.K_RSHIFT] or keys[pygame.K_SPACE],
            'skill_q': keys[pygame.K_q],
            'skill_w': keys[pygame.K_w],
            'skill_e': keys[pygame.K_e],
            'mouse_left': pygame.mouse.get_pressed()[0],
            'mouse_right': pygame.mouse.get_pressed()[2],
            'mouse_x': pygame.mouse.get_pos()[0],
            'mouse_y': pygame.mouse.get_pos()[1],
        }

        # 네트워크 전송
        serialized = serialize_input(self.local_input)
        self.net.send_online_packet(OnlinePacketType.GAME_INPUT, serialized)

        # 로컬 패들 예측 (즉시 반영)
        speed = 8
        if self.local_input['dash']:
            speed = 20
        if self.local_input['left']:
            self.local_p2_x -= speed
        if self.local_input['right']:
            self.local_p2_x += speed
        self.local_p2_x = max(0, min(self.width - self.paddle_width, self.local_p2_x))

    def _receive_state(self):
        """호스트에서 수신한 게임 프레임 적용"""
        frame = self.net.online_game_frame
        if frame is None:
            return

        self.last_frame_time = time.time()

        # 볼 위치 (호스트 좌표계 그대로 저장 → 렌더 시 Y반전)
        ball = frame.get('ball', [0, 0, 0, 0])
        self.ball_x = ball[0]
        self.ball_y = ball[1]
        self.ball_vx = ball[2]
        self.ball_vy = ball[3]

        # 패들 위치
        p1 = frame.get('p1', [0, 0, 0])
        p2 = frame.get('p2', [0, 0, 0])
        self.p1_x = p1[0]
        self.p1_gauge = p1[1]
        self.round_wins = frame.get('round_wins', 0)   # P1 승리 = 내 패배
        self.round_losses = frame.get('round_losses', 0) # P1 패배 = 내 승리

        # P2 서버 위치로 보정 (예측과 블렌딩)
        server_p2_x = p2[0]
        self.local_p2_x = self.local_p2_x + (server_p2_x - self.local_p2_x) * 0.5
        self.p2_x = self.local_p2_x

        self.p2_gauge = p2[1]
        self.game_over = frame.get('game_over', None)
        self.waiting_serve = frame.get('waiting_serve', False)

        # 트레일 업데이트
        self.ball_trail.append((self.ball_x + self.ball_size // 2,
                                self.ball_y + self.ball_size // 2))
        if len(self.ball_trail) > self.max_trail:
            self.ball_trail.pop(0)

    def _flip_y(self, y, obj_height=0):
        """Y축 반전 (P2 시점: 자기 패들이 아래에 보이도록)"""
        return self.height - y - obj_height

    def _draw(self):
        """게임 화면 그리기 (Y 반전)"""
        self.screen.fill(BG_COLOR)

        # 중앙선
        center_y = self.height // 2
        for x in range(0, self.width, 20):
            pygame.draw.rect(self.screen, (40, 45, 55),
                             (x, center_y - 1, 10, 2))

        # ── 볼 트레일 (Y 반전) ──
        for i, (tx, ty) in enumerate(self.ball_trail):
            alpha = int(60 * (i + 1) / len(self.ball_trail)) if self.ball_trail else 0
            size = max(2, int(self.ball_size * 0.5 * (i + 1) / max(1, len(self.ball_trail))))
            trail_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(trail_surf, (255, 255, 255, alpha), (size, size), size)
            flipped_ty = self._flip_y(ty - size, 0)
            self.screen.blit(trail_surf, (tx - size, flipped_ty))

        # ── 볼 (Y 반전) ──
        ball_draw_y = self._flip_y(self.ball_y, self.ball_size)
        # 글로우
        glow_surf = pygame.Surface((40, 40), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (255, 255, 255, 30), (20, 20), 18)
        self.screen.blit(glow_surf, (self.ball_x + self.ball_size // 2 - 20,
                                      ball_draw_y + self.ball_size // 2 - 20))
        pygame.draw.circle(self.screen, BALL_COLOR,
                           (int(self.ball_x + self.ball_size // 2),
                            int(ball_draw_y + self.ball_size // 2)),
                           self.ball_size // 2)

        # ── 패들: 상대방(P1) → 상단에 표시 (Y 반전 후) ──
        p1_draw_y = self._flip_y(710, self.paddle_height)  # P1 원래 y=710 → 반전 후 상단
        pygame.draw.rect(self.screen, P1_COLOR,
                         (self.p1_x, p1_draw_y, self.paddle_width, self.paddle_height),
                         border_radius=4)
        # 윤곽
        pygame.draw.rect(self.screen, (100, 200, 255),
                         (self.p1_x, p1_draw_y, self.paddle_width, self.paddle_height),
                         1, border_radius=4)

        # ── 패들: 나(P2) → 하단에 표시 (Y 반전 후) ──
        p2_draw_y = self._flip_y(25, self.paddle_height)  # P2 원래 y=25(보스) → 반전 후 하단
        pygame.draw.rect(self.screen, P2_COLOR,
                         (self.p2_x, p2_draw_y, self.paddle_width, self.paddle_height),
                         border_radius=4)
        pygame.draw.rect(self.screen, (255, 150, 150),
                         (self.p2_x, p2_draw_y, self.paddle_width, self.paddle_height),
                         1, border_radius=4)

        # ── 스코어 (Y 반전: 내 점수(P2)가 아래, 상대(P1)가 위) ──
        score_font = self.get_font(36)
        # 내 승리 횟수 = 호스트 기준 round_losses
        my_score = self.round_losses
        opp_score = self.round_wins

        my_score_surf = score_font.render(str(my_score), True, SCORE_COLOR)
        opp_score_surf = score_font.render(str(opp_score), True, SCORE_COLOR)

        # 내 점수 → 하단
        self.screen.blit(my_score_surf,
                         my_score_surf.get_rect(center=(self.width // 2, self.height - 60)))
        # 상대 점수 → 상단
        self.screen.blit(opp_score_surf,
                         opp_score_surf.get_rect(center=(self.width // 2, 60)))

        # ── 레이블 ──
        label_font = self.get_font(14)
        me_label = label_font.render("나 (P2)", True, P2_COLOR)
        opp_label = label_font.render("상대 (P1)", True, P1_COLOR)
        self.screen.blit(me_label, me_label.get_rect(center=(self.width // 2, self.height - 30)))
        self.screen.blit(opp_label, opp_label.get_rect(center=(self.width // 2, 30)))

        # ── 핑 표시 ──
        if self.net.connections:
            ping = self.net.connections[0].latency
            ping_font = self.get_font(12)
            ping_text = ping_font.render(f"Ping: {ping:.0f}ms", True, DIM_COLOR)
            self.screen.blit(ping_text, (self.width - 90, 5))

        # ── 연결 경고 ──
        if self.disconnect_timer > 1.0:
            warn_font = self.get_font(20)
            warn = warn_font.render("연결 불안정...", True, (255, 80, 80))
            self.screen.blit(warn, warn.get_rect(center=(self.width // 2, self.height // 2)))

        # ── 서브 대기 ──
        if self.waiting_serve:
            serve_font = self.get_font(16)
            serve_text = serve_font.render("서브 대기 중...", True, DIM_COLOR)
            self.screen.blit(serve_text,
                             serve_text.get_rect(center=(self.width // 2, self.height // 2 + 40)))

    def _show_result(self):
        """게임 결과 표시"""
        result_time = time.time()
        # P2 시점: game_over가 'p2'면 내가 이긴 것 (P2 = 호스트 기준 보스)
        # 아니, 반대. game_over='p1'이면 P1(호스트) 승리, 'p2'면 P2(나) 승리
        i_won = (self.game_over == 'p2')

        while time.time() - result_time < 5.0:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return
                if event.type == pygame.KEYDOWN:
                    return

            self.screen.fill(BG_COLOR)
            result_font = self.get_font(48)
            sub_font = self.get_font(24)

            if i_won:
                title = result_font.render("승리!", True, SCORE_COLOR)
            else:
                title = result_font.render("패배", True, (255, 80, 80))

            self.screen.blit(title, title.get_rect(center=(self.width // 2, self.height // 2 - 40)))

            score_text = sub_font.render(
                f"나 {self.round_losses} : {self.round_wins} 상대",
                True, TEXT_COLOR)
            self.screen.blit(score_text,
                             score_text.get_rect(center=(self.width // 2, self.height // 2 + 30)))

            hint = self.get_font(16).render("아무 키나 누르면 돌아갑니다", True, DIM_COLOR)
            self.screen.blit(hint, hint.get_rect(center=(self.width // 2, self.height // 2 + 80)))

            pygame.display.flip()
            self.clock.tick(60)

    def _show_disconnect(self):
        """연결 끊김 화면"""
        start = time.time()
        while time.time() - start < 3.0:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return
            self.screen.fill(BG_COLOR)
            font = self.get_font(28)
            text = font.render("연결이 끊어졌습니다", True, (255, 80, 80))
            self.screen.blit(text, text.get_rect(center=(self.width // 2, self.height // 2)))
            pygame.display.flip()
            self.clock.tick(60)


def run_client_renderer(screen, width, height, get_font_func, net_manager):
    """클라이언트 렌더러 진입점"""
    renderer = ClientRenderer(screen, width, height, get_font_func, net_manager)
    renderer.run()
