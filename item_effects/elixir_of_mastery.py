"""
엘릭서 오브 마스터리 (Elixir of Mastery)
신화급 액티브 아이템 - 사용 시 보유 퍽 중 랜덤 1개를 Lv.5로 만듦
시네마틱 연출: 화면 정지 → 3초 신비 애니메이션 → 결과 공개
"""
import pygame
import math
import random
import time


class ElixirOfMastery:
    """엘릭서 오브 마스터리 - 신화급 액티브 아이템"""

    def __init__(self):
        self.active = False
        # 시네마틱 연출 상태
        self.cinematic_active = False
        self.cinematic_phase = 0  # 0=빌드업, 1=공개, 2=대기
        self.cinematic_timer = 0.0
        self.cinematic_start_time = 0.0
        # 결과 데이터
        self.selected_skill_id = None
        self.selected_skill_data = None
        self.old_level = 0
        # 애니메이션 변수
        self.particles = []
        self.rune_circles = []
        self.flash_alpha = 0
        self.result_alpha = 0
        self.bottle_rotation = 0
        self.bottle_scale = 1.0
        self.magic_streams = []
        self.sparkles = []
        # 결과 확인 대기
        self.waiting_for_confirm = False

    def reset(self):
        """상태 초기화"""
        self.active = False
        self.cinematic_active = False
        self.cinematic_phase = 0
        self.cinematic_timer = 0.0
        self.selected_skill_id = None
        self.selected_skill_data = None
        self.old_level = 0
        self.particles = []
        self.rune_circles = []
        self.flash_alpha = 0
        self.result_alpha = 0
        self.bottle_rotation = 0
        self.bottle_scale = 1.0
        self.magic_streams = []
        self.sparkles = []
        self.waiting_for_confirm = False

    def get_eligible_perks(self, runtime_skill_levels, all_skill_pools):
        """Lv.5 미만인 퍽 목록 반환 (max_level이 5 이상인 퍽만)"""
        eligible = []
        for pool in all_skill_pools:
            for skill_id, skill_data in pool.items():
                max_level = skill_data.get("max_level", 0)
                if max_level < 5:
                    continue  # max_level이 5 미만인 퍽은 제외
                current = runtime_skill_levels.get(skill_id, 0)
                if current < 5:
                    eligible.append((skill_id, skill_data, current))
        return eligible

    def activate(self, runtime_skill_levels, all_skill_pools, apply_skill_func):
        """
        엘릭서 사용 - 랜덤 퍽 선택 후 Lv.5로 설정
        Returns: True if activated, False if no eligible perks
        """
        eligible = self.get_eligible_perks(runtime_skill_levels, all_skill_pools)
        if not eligible:
            return False

        # 랜덤 퍽 선택
        skill_id, skill_data, old_level = random.choice(eligible)
        self.selected_skill_id = skill_id
        self.selected_skill_data = skill_data
        self.old_level = old_level

        # Lv.5로 설정 (레벨업 함수를 (5 - current) 번 호출)
        levels_to_add = 5 - old_level
        for _ in range(levels_to_add):
            apply_skill_func(skill_id)

        # 시네마틱 시작
        self.cinematic_active = True
        self.cinematic_phase = 0
        self.cinematic_timer = 0.0
        self.cinematic_start_time = time.time()
        self.active = True
        self._init_particles()
        return True

    def _init_particles(self):
        """초기 파티클 생성"""
        self.particles = []
        self.magic_streams = []
        self.sparkles = []
        self.rune_circles = []
        # 마법 입자
        for _ in range(60):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(50, 200)
            self.particles.append({
                "angle": angle,
                "dist": dist,
                "speed": random.uniform(0.5, 2.0),
                "size": random.uniform(2, 5),
                "color": random.choice([
                    (180, 100, 255),  # 보라
                    (100, 200, 255),  # 하늘
                    (255, 200, 100),  # 금색
                    (255, 255, 255),  # 흰색
                ]),
                "alpha": random.randint(150, 255),
                "phase": random.uniform(0, math.pi * 2),
            })
        # 룬 서클
        for i in range(3):
            self.rune_circles.append({
                "radius": 80 + i * 50,
                "rotation": i * 1.2,
                "speed": 0.8 + i * 0.3,
                "segments": 6 + i * 2,
                "alpha": 180 - i * 30,
            })

    def should_pause_game(self):
        """게임 루프에서 일시정지 여부 확인"""
        return self.cinematic_active

    def update(self, dt):
        """시네마틱 업데이트 (dt: 초 단위)"""
        if not self.cinematic_active:
            return

        self.cinematic_timer += dt

        if self.cinematic_phase == 0:
            # Phase 0: 빌드업 (0~3초) - 물약 회전, 마법진, 입자 수렴
            self.bottle_rotation += dt * 180  # 초당 180도
            self.bottle_scale = 1.0 + 0.2 * math.sin(self.cinematic_timer * 3)

            progress = min(1.0, self.cinematic_timer / 3.0)
            # 입자가 중심으로 수렴
            for p in self.particles:
                p["angle"] += p["speed"] * dt
                p["dist"] = max(5, p["dist"] - progress * 80 * dt)

            # 룬 서클 회전
            for rc in self.rune_circles:
                rc["rotation"] += rc["speed"] * dt

            # 3초 후 폭발 + 공개 단계로
            if self.cinematic_timer >= 3.0:
                self.cinematic_phase = 1
                self.cinematic_timer = 0.0
                self.flash_alpha = 255
                self._spawn_explosion_sparkles()

        elif self.cinematic_phase == 1:
            # Phase 1: 결과 공개 (0~1.5초) - 플래시 → 아이콘 등장
            self.flash_alpha = max(0, 255 - int(self.cinematic_timer * 300))
            self.result_alpha = min(255, int(self.cinematic_timer * 200))

            # 스파클 업데이트
            for s in self.sparkles[:]:
                s["life"] -= dt
                s["x"] += s["vx"] * dt
                s["y"] += s["vy"] * dt
                s["vy"] += 50 * dt  # 중력
                if s["life"] <= 0:
                    self.sparkles.remove(s)

            if self.cinematic_timer >= 1.5:
                self.cinematic_phase = 2
                self.waiting_for_confirm = True

        elif self.cinematic_phase == 2:
            # Phase 2: 결과 표시 대기 (스페이스/클릭 대기)
            self.result_alpha = 255
            # 스파클 지속 업데이트
            for s in self.sparkles[:]:
                s["life"] -= dt
                s["x"] += s["vx"] * dt
                s["y"] += s["vy"] * dt
                if s["life"] <= 0:
                    self.sparkles.remove(s)

    def _spawn_explosion_sparkles(self):
        """폭발 스파클 생성"""
        for _ in range(80):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(100, 400)
            self.sparkles.append({
                "x": 0, "y": 0,  # 화면 중심 기준 오프셋
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed,
                "size": random.uniform(2, 6),
                "color": random.choice([
                    (255, 215, 0),    # 금색
                    (200, 100, 255),  # 보라
                    (100, 220, 255),  # 하늘
                    (255, 255, 255),  # 흰색
                    (255, 180, 50),   # 주황금
                ]),
                "life": random.uniform(1.0, 3.0),
                "max_life": 3.0,
            })

    def handle_input(self, event):
        """입력 처리 - 결과 확인"""
        if not self.waiting_for_confirm:
            return False
        if event.type == pygame.KEYDOWN and event.key in (pygame.K_SPACE, pygame.K_RETURN):
            self._finish_cinematic()
            return True
        if event.type == pygame.MOUSEBUTTONDOWN:
            self._finish_cinematic()
            return True
        return False

    def _finish_cinematic(self):
        """시네마틱 종료"""
        self.cinematic_active = False
        self.waiting_for_confirm = False
        self.active = False

    def draw_cinematic(self, screen, draw_skill_icon_func=None):
        """시네마틱 연출 그리기"""
        if not self.cinematic_active:
            return

        width, height = screen.get_size()
        cx, cy = width // 2, height // 2

        # 어두운 오버레이
        overlay = pygame.Surface((width, height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 200))
        screen.blit(overlay, (0, 0))

        if self.cinematic_phase == 0:
            self._draw_buildup(screen, cx, cy, width, height)
        elif self.cinematic_phase >= 1:
            self._draw_result(screen, cx, cy, width, height, draw_skill_icon_func)

        # 플래시 효과
        if self.flash_alpha > 0:
            flash = pygame.Surface((width, height), pygame.SRCALPHA)
            flash.fill((255, 255, 255, min(255, self.flash_alpha)))
            screen.blit(flash, (0, 0))

    def _draw_buildup(self, screen, cx, cy, width, height):
        """Phase 0: 빌드업 연출"""
        progress = min(1.0, self.cinematic_timer / 3.0)

        # 룬 서클 그리기
        for rc in self.rune_circles:
            alpha = int(rc["alpha"] * (0.5 + 0.5 * math.sin(self.cinematic_timer * 2)))
            surf = pygame.Surface((width, height), pygame.SRCALPHA)
            r = int(rc["radius"] * (1.0 - progress * 0.3))
            segments = rc["segments"]
            rot = rc["rotation"]
            for i in range(segments):
                angle1 = rot + (2 * math.pi * i / segments)
                angle2 = rot + (2 * math.pi * (i + 0.7) / segments)
                x1 = cx + int(r * math.cos(angle1))
                y1 = cy + int(r * math.sin(angle1))
                x2 = cx + int(r * math.cos(angle2))
                y2 = cy + int(r * math.sin(angle2))
                color = (180, 100, 255, alpha)
                pygame.draw.line(surf, color, (x1, y1), (x2, y2), 2)
                # 꼭짓점에 작은 원
                pygame.draw.circle(surf, (255, 200, 100, alpha), (x1, y1), 3)
            screen.blit(surf, (0, 0))

        # 마법 입자 그리기
        for p in self.particles:
            px = cx + int(p["dist"] * math.cos(p["angle"]))
            py = cy + int(p["dist"] * math.sin(p["angle"]))
            pulse = 0.5 + 0.5 * math.sin(self.cinematic_timer * 4 + p["phase"])
            size = max(1, int(p["size"] * pulse))
            alpha = int(p["alpha"] * pulse)
            surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            color = (*p["color"][:3], alpha)
            pygame.draw.circle(surf, color, (size, size), size)
            screen.blit(surf, (px - size, py - size))

        # 중앙 물약 그리기
        self._draw_elixir_bottle(screen, cx, cy, progress)

        # 텍스트: "엘릭서 오브 마스터리"
        if progress > 0.3:
            text_alpha = min(255, int((progress - 0.3) * 400))
            try:
                font = pygame.font.SysFont("malgungothic", 28, bold=True)
            except Exception:
                font = pygame.font.Font(None, 28)
            text_surf = font.render("엘릭서 오브 마스터리", True, (255, 215, 0))
            text_surf.set_alpha(text_alpha)
            tr = text_surf.get_rect(center=(cx, cy + 100))
            screen.blit(text_surf, tr)

        # 하단 안내
        if progress > 0.5:
            sub_alpha = min(200, int((progress - 0.5) * 300))
            try:
                small_font = pygame.font.SysFont("malgungothic", 16)
            except Exception:
                small_font = pygame.font.Font(None, 16)
            sub_text = small_font.render("퍽의 운명이 결정됩니다...", True, (200, 180, 255))
            sub_text.set_alpha(sub_alpha)
            sr = sub_text.get_rect(center=(cx, cy + 130))
            screen.blit(sub_text, sr)

    def _draw_elixir_bottle(self, screen, cx, cy, progress):
        """물약병 그리기 (회전 + 글로우)"""
        bottle_size = int(60 * self.bottle_scale)
        half = bottle_size // 2

        # 글로우
        glow_r = int(80 + 40 * math.sin(self.cinematic_timer * 3))
        glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
        glow_alpha = int(100 + 50 * progress)
        pygame.draw.circle(glow_surf, (180, 100, 255, glow_alpha), (glow_r, glow_r), glow_r)
        pygame.draw.circle(glow_surf, (220, 180, 255, glow_alpha + 30), (glow_r, glow_r), glow_r // 2)
        screen.blit(glow_surf, (cx - glow_r, cy - glow_r))

        # 물약병 본체
        bottle_surf = pygame.Surface((bottle_size, bottle_size), pygame.SRCALPHA)
        bcx, bcy = half, half

        # 병 몸체 (둥근 하단)
        body_color = (120, 50, 200)
        pygame.draw.ellipse(bottle_surf, body_color,
                            (bcx - 18, bcy - 5, 36, 30))
        # 액체 (빛나는 보라)
        liquid_color = (200, 100, 255)
        pygame.draw.ellipse(bottle_surf, liquid_color,
                            (bcx - 15, bcy, 30, 22))
        # 병목
        neck_color = (150, 80, 220)
        pygame.draw.rect(bottle_surf, neck_color,
                         (bcx - 6, bcy - 18, 12, 18))
        # 병 뚜껑
        cap_color = (255, 215, 0)
        pygame.draw.rect(bottle_surf, cap_color,
                         (bcx - 8, bcy - 22, 16, 6), border_radius=2)
        # 별 하이라이트
        star_color = (255, 255, 200, 200)
        pygame.draw.circle(bottle_surf, star_color, (bcx - 8, bcy + 4), 3)

        # 회전 적용
        rotated = pygame.transform.rotate(bottle_surf, self.bottle_rotation % 360)
        rr = rotated.get_rect(center=(cx, cy))
        screen.blit(rotated, rr)

    def _draw_result(self, screen, cx, cy, width, height, draw_skill_icon_func):
        """Phase 1-2: 결과 공개 연출"""
        # 스파클 그리기
        for s in self.sparkles:
            alpha = int(255 * max(0, s["life"] / s["max_life"]))
            size = max(1, int(s["size"] * (s["life"] / s["max_life"])))
            sx = cx + int(s["x"])
            sy = cy + int(s["y"])
            if 0 <= sx < width and 0 <= sy < height:
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                color = (*s["color"][:3], alpha)
                pygame.draw.circle(surf, color, (size, size), size)
                screen.blit(surf, (sx - size, sy - size))

        if self.selected_skill_data is None:
            return

        # 결과 프레임 (신화급 테두리)
        frame_size = 120
        frame_x = cx - frame_size // 2
        frame_y = cy - frame_size // 2 - 30

        # 글로우 배경
        glow_pulse = (math.sin(time.time() * 4) + 1) / 2
        glow_r = frame_size // 2 + 20
        glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
        glow_alpha = int(80 + 60 * glow_pulse)
        # 3중 글로우 (보라 → 금 → 흰)
        pygame.draw.circle(glow_surf, (120, 50, 200, glow_alpha),
                           (glow_r, glow_r), glow_r)
        pygame.draw.circle(glow_surf, (200, 150, 50, glow_alpha + 20),
                           (glow_r, glow_r), int(glow_r * 0.75))
        pygame.draw.circle(glow_surf, (255, 255, 255, glow_alpha + 40),
                           (glow_r, glow_r), int(glow_r * 0.5))
        glow_surf.set_alpha(min(255, self.result_alpha))
        screen.blit(glow_surf, (cx - glow_r, cy - 30 - glow_r))

        # 아이콘 배경 (진한 프레임)
        frame_surf = pygame.Surface((frame_size, frame_size), pygame.SRCALPHA)
        frame_surf.fill((20, 10, 40, 220))
        # 테두리 - 신화급 보라+금 펄스
        border_pulse = (math.sin(time.time() * 6) + 1) / 2
        outer_color = (
            int(150 + 80 * border_pulse),
            int(50 + 50 * border_pulse),
            int(200 + 40 * border_pulse)
        )
        inner_color = (255, 215, int(50 + 50 * border_pulse))
        pygame.draw.rect(frame_surf, outer_color, (0, 0, frame_size, frame_size), 3)
        pygame.draw.rect(frame_surf, inner_color, (3, 3, frame_size - 6, frame_size - 6), 2)
        # 코너 장식
        corner_color = (255, 215, 0)
        corner_len = 12
        corners = [(0, 0), (frame_size, 0), (0, frame_size), (frame_size, frame_size)]
        for (ccx, ccy) in corners:
            dx = 1 if ccx == 0 else -1
            dy = 1 if ccy == 0 else -1
            pygame.draw.line(frame_surf, corner_color,
                             (ccx, ccy), (ccx + dx * corner_len, ccy), 2)
            pygame.draw.line(frame_surf, corner_color,
                             (ccx, ccy), (ccx, ccy + dy * corner_len), 2)
            pygame.draw.circle(frame_surf, corner_color, (ccx, ccy), 3)

        frame_surf.set_alpha(min(255, self.result_alpha))
        screen.blit(frame_surf, (frame_x, frame_y))

        # 퍽 아이콘 그리기
        if draw_skill_icon_func and self.result_alpha > 50:
            icon_size = 80
            icon_x = cx - icon_size // 2
            icon_y = cy - icon_size // 2 - 30
            skill_for_draw = {
                "id": self.selected_skill_id,
                "name": self.selected_skill_data.get("name", ""),
                "icon_color": self.selected_skill_data.get("icon_color", (200, 100, 255)),
            }
            draw_skill_icon_func(screen, skill_for_draw, icon_x, icon_y, icon_size,
                                 scale_multiplier=1.5)

        # 텍스트 표시
        if self.result_alpha > 100:
            try:
                name_font = pygame.font.SysFont("malgungothic", 24, bold=True)
                level_font = pygame.font.SysFont("malgungothic", 20)
                info_font = pygame.font.SysFont("malgungothic", 16)
            except Exception:
                name_font = pygame.font.Font(None, 24)
                level_font = pygame.font.Font(None, 20)
                info_font = pygame.font.Font(None, 16)

            # 퍽 이름
            skill_name = self.selected_skill_data.get("name", "???")
            name_surf = name_font.render(skill_name, True, (255, 215, 0))
            name_surf.set_alpha(min(255, self.result_alpha))
            nr = name_surf.get_rect(center=(cx, cy + 45))
            screen.blit(name_surf, nr)

            # 레벨 변화
            level_text = f"Lv.{self.old_level} → Lv.5"
            level_surf = level_font.render(level_text, True, (100, 255, 200))
            level_surf.set_alpha(min(255, self.result_alpha))
            lr = level_surf.get_rect(center=(cx, cy + 72))
            screen.blit(lr, lr)  # intentionally using lr for both

            # Lv.5 설명
            desc = self.selected_skill_data.get("descriptions", {}).get(5, "")
            if desc:
                desc_surf = info_font.render(desc, True, (220, 220, 255))
                desc_surf.set_alpha(min(255, self.result_alpha))
                dr = desc_surf.get_rect(center=(cx, cy + 96))
                screen.blit(desc_surf, dr)

        # 확인 안내
        if self.waiting_for_confirm:
            try:
                hint_font = pygame.font.SysFont("malgungothic", 14)
            except Exception:
                hint_font = pygame.font.Font(None, 14)
            blink = int((math.sin(time.time() * 4) + 1) * 127)
            hint_surf = hint_font.render("[ Space / Click 으로 계속 ]", True,
                                         (200, 200, 255, blink))
            hr = hint_surf.get_rect(center=(cx, cy + 130))
            screen.blit(hint_surf, hr)


# 싱글톤
_elixir_instance = None


def get_elixir_of_mastery_instance():
    global _elixir_instance
    if _elixir_instance is None:
        _elixir_instance = ElixirOfMastery()
    return _elixir_instance


def activate_elixir_of_mastery():
    """외부에서 호출하는 활성화 함수 (pingfighter.py에서 사용)"""
    return get_elixir_of_mastery_instance()
