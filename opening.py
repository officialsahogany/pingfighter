# -*- coding: utf-8 -*-
import pygame
import pygame.freetype
import random
import sys
import math
import os
import bgm_manager

# 리소스 경로 헬퍼 (PyInstaller 호환)
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)


# ============================================================
# 인트로 컷씬 시스템 (Intro Cutscene System)
# ============================================================

class IntroCutscene:
    """인트로 컷씬 관리 클래스 - 명언 + 스토리 시퀀스"""

    def __init__(self, screen, width, height):
        self.screen = screen
        self.width = width
        self.height = height
        self.clock = pygame.time.Clock()
        self.skip_all = False  # Ctrl 키로 전체 스킵 플래그

        # 폰트 로드 (루트 디렉토리의 폰트 사용)
        try:
            self.font_large = pygame.freetype.Font(
                resource_path("NanumSquareB.ttf"), 32
            )
            self.font_medium = pygame.freetype.Font(
                resource_path("NanumSquareB.ttf"), 24
            )
            self.font_small = pygame.freetype.Font(
                resource_path("NanumSquareB.ttf"), 20
            )
            self.font_hint = pygame.freetype.Font(
                resource_path("NanumSquareR.ttf"), 14
            )
        except Exception as e:
            print(f"[IntroCutscene] 폰트 로드 실패, 기본 폰트 사용: {e}")
            self.font_large = pygame.freetype.SysFont("Arial", 32)
            self.font_medium = pygame.freetype.SysFont("Arial", 24)
            self.font_small = pygame.freetype.SysFont("Arial", 20)
            self.font_hint = pygame.freetype.SysFont("Arial", 14)

        # 명언 데이터 (두 명언을 한 화면에 표시)
        self.combined_quotes = [
            {"english": "To live is to choose.", "korean": "사는 것은 선택하는 것이다."},
            {"english": "Life is a series of choices.", "korean": "인생은 선택의 연속이다."}
        ]

        # 추가 명언 (여러 줄 텍스트)
        self.additional_quotes = [
            "어느 유명한 위인이나 인물들이 하는 여러 말들이",
            "하나의 본질로 조합해서 떠돌아다니는 말.",
            "",
            "그것이 모두의 마음을 울리며",
            "시대가 바뀌어도 계속 떠돌아 남아있는 말.",
            "",
            "사람들은, 기본적으로 선택이라는 자유를 누린다."
        ]

        # 스토리 컷씬 데이터 (나중에 이미지 경로와 텍스트 추가)
        self.story_scenes = []

    def _check_skip_all(self, event):
        """Ctrl 키로 전체 스킵 체크"""
        if event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_LCTRL, pygame.K_RCTRL):
                self.skip_all = True
                return True
        return False

    def _draw_skip_hint(self):
        """우측 하단에 스킵 힌트 표시"""
        hint_text = "Ctrl - 스킵"
        hint_surface, hint_rect = self.font_hint.render(hint_text, (120, 120, 140))
        hint_x = self.width - hint_rect.width - 20
        hint_y = self.height - hint_rect.height - 15

        # 반투명 배경
        bg_padding = 8
        bg_surface = pygame.Surface((hint_rect.width + bg_padding * 2, hint_rect.height + bg_padding * 2), pygame.SRCALPHA)
        bg_surface.fill((0, 0, 0, 100))
        self.screen.blit(bg_surface, (hint_x - bg_padding, hint_y - bg_padding))

        self.screen.blit(hint_surface, (hint_x, hint_y))

    def show_combined_quotes_screen(self, duration=9.0):
        """검은 배경에 두 명언을 한 화면에 페이드인/아웃으로 표시

        Args:
            duration: 명언 표시 시간 (초)
        """
        if self.skip_all:
            return

        fps = 60
        fade_in_frames = int(3.0 * fps)  # 3초 페이드인 (천천히)
        hold_frames = int((duration - 5.0) * fps)  # 유지 시간
        fade_out_frames = int(2.0 * fps)  # 2초 페이드아웃

        total_frames = fade_in_frames + hold_frames + fade_out_frames

        for frame in range(total_frames):
            # 이벤트 처리 (스킵 허용)
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if self._check_skip_all(event):
                    return  # Ctrl로 전체 스킵
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE or event.key == pygame.K_SPACE:
                        return  # 스킵
                if event.type == pygame.MOUSEBUTTONDOWN:
                    return  # 클릭으로 스킵

            # 알파 계산
            if frame < fade_in_frames:
                # 페이드인
                alpha = int(255 * (frame / fade_in_frames))
            elif frame < fade_in_frames + hold_frames:
                # 유지
                alpha = 255
            else:
                # 페이드아웃
                fade_progress = (frame - fade_in_frames - hold_frames) / fade_out_frames
                alpha = int(255 * (1.0 - fade_progress))

            # 검은 배경
            self.screen.fill((0, 0, 0))

            # 알파 적용을 위한 임시 서페이스
            text_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

            # 첫 번째 명언
            quote1 = self.combined_quotes[0]
            eng1_surface, eng1_rect = self.font_large.render(
                quote1["english"], (255, 255, 255)
            )
            eng1_x = (self.width - eng1_rect.width) // 2
            eng1_y = self.height // 2 - 100
            text_surface.blit(eng1_surface, (eng1_x, eng1_y))

            kor1_surface, kor1_rect = self.font_medium.render(
                quote1["korean"], (180, 180, 180)
            )
            kor1_x = (self.width - kor1_rect.width) // 2
            kor1_y = self.height // 2 - 55
            text_surface.blit(kor1_surface, (kor1_x, kor1_y))

            # 두 번째 명언
            quote2 = self.combined_quotes[1]
            eng2_surface, eng2_rect = self.font_large.render(
                quote2["english"], (255, 255, 255)
            )
            eng2_x = (self.width - eng2_rect.width) // 2
            eng2_y = self.height // 2 + 20
            text_surface.blit(eng2_surface, (eng2_x, eng2_y))

            kor2_surface, kor2_rect = self.font_medium.render(
                quote2["korean"], (180, 180, 180)
            )
            kor2_x = (self.width - kor2_rect.width) // 2
            kor2_y = self.height // 2 + 65
            text_surface.blit(kor2_surface, (kor2_x, kor2_y))

            # 알파 적용
            text_surface.set_alpha(alpha)
            self.screen.blit(text_surface, (0, 0))

            # 스킵 힌트 표시
            self._draw_skip_hint()

            pygame.display.flip()
            self.clock.tick(fps)

    def show_additional_quotes_screen(self, duration=11.0):
        """검은 배경에 추가 명언(여러 줄)을 페이드인/아웃으로 표시

        Args:
            duration: 명언 표시 시간 (초)
        """
        if self.skip_all:
            return

        fps = 60
        fade_in_frames = int(3.0 * fps)  # 3초 페이드인 (천천히)
        hold_frames = int((duration - 7.0) * fps)  # 유지 시간
        fade_out_frames = int(4.0 * fps)  # 4초 페이드아웃 (천천히 사라짐)

        total_frames = fade_in_frames + hold_frames + fade_out_frames

        for frame in range(total_frames):
            # 이벤트 처리 (스킵 허용)
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if self._check_skip_all(event):
                    return  # Ctrl로 전체 스킵
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE or event.key == pygame.K_SPACE:
                        return  # 스킵
                if event.type == pygame.MOUSEBUTTONDOWN:
                    return  # 클릭으로 스킵

            # 알파 계산
            if frame < fade_in_frames:
                alpha = int(255 * (frame / fade_in_frames))
            elif frame < fade_in_frames + hold_frames:
                alpha = 255
            else:
                fade_progress = (frame - fade_in_frames - hold_frames) / fade_out_frames
                alpha = int(255 * (1.0 - fade_progress))

            # 검은 배경
            self.screen.fill((0, 0, 0))

            # 알파 적용을 위한 임시 서페이스
            text_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

            # 여러 줄 텍스트 렌더링
            total_lines = len(self.additional_quotes)
            line_height = 40
            total_height = total_lines * line_height
            start_y = (self.height - total_height) // 2

            for i, line in enumerate(self.additional_quotes):
                if line:  # 빈 줄이 아닌 경우만 렌더링
                    line_surface, line_rect = self.font_medium.render(
                        line, (200, 200, 200)
                    )
                    line_x = (self.width - line_rect.width) // 2
                    line_y = start_y + i * line_height
                    text_surface.blit(line_surface, (line_x, line_y))

            # 알파 적용
            text_surface.set_alpha(alpha)
            self.screen.blit(text_surface, (0, 0))

            # 스킵 힌트 표시
            self._draw_skip_hint()

            pygame.display.flip()
            self.clock.tick(fps)

    def show_black_screen(self, duration=2.0):
        """검은 화면을 일정 시간 동안 표시 (사운드 연출용)

        Args:
            duration: 검은 화면 표시 시간 (초)
        """
        if self.skip_all:
            return

        fps = 60
        total_frames = int(duration * fps)

        for frame in range(total_frames):
            # 이벤트 처리 (스킵 허용)
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if self._check_skip_all(event):
                    return  # Ctrl로 전체 스킵
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        return  # ESC로만 스킵 (드라마틱 연출 유지)

            # 검은 배경
            self.screen.fill((0, 0, 0))

            # 스킵 힌트 표시
            self._draw_skip_hint()

            pygame.display.flip()
            self.clock.tick(fps)

    def show_story_scene(self, image_path, dialogues, text_delay=1.5, text_color=(255, 255, 255), speaker=None, skip_fade_in=False):
        """스토리 씬 표시 - 이미지 페이드인 후 대사들을 순차적으로 타이핑

        Args:
            image_path: 배경 이미지 경로
            dialogues: 대사 리스트 (쉼표로 구분된 문자열 또는 리스트)
            text_delay: 이미지 표시 후 텍스트 시작까지 딜레이 (초)
            text_color: 텍스트 색상 (주인공: 흰색, 다른 캐릭터: 색상 지정)
            speaker: 화자 이름 (예: "유이안", "이안" 등)
            skip_fade_in: 페이드인 생략 여부 (같은 이미지에서 화자만 바뀔 때 사용)
        """
        if self.skip_all:
            return

        fps = 60

        # 텍스트 박스 높이 설정
        text_box_height = 180  # 높이 증가

        # 이미지 로드 및 비율 유지 스케일링
        try:
            original_image = pygame.image.load(resource_path(image_path)).convert()
            orig_w, orig_h = original_image.get_size()

            # 이미지 표시 영역 (텍스트 박스 위쪽, 더 넉넉하게)
            available_height = self.height - text_box_height - 50  # 여유 공간 추가
            available_width = self.width

            # 비율 유지하면서 스케일 계산
            scale_w = available_width / orig_w
            scale_h = available_height / orig_h
            scale = min(scale_w, scale_h)  # 작은 쪽에 맞춤

            new_w = int(orig_w * scale)
            new_h = int(orig_h * scale)

            # 화면 전체 너비를 채우도록 조정 (검은 세로선 방지)
            if new_w < self.width:
                new_w = self.width
                new_h = int(orig_h * (self.width / orig_w))

            image = pygame.transform.smoothscale(original_image, (new_w, new_h))

            # 이미지 위치 (상단 중앙 정렬)
            image_x = (self.width - new_w) // 2
            image_y = (available_height - new_h) // 2

        except Exception as e:
            print(f"[IntroCutscene] 이미지 로드 실패: {e}")
            image = pygame.Surface((self.width, self.height - text_box_height - 50))
            image.fill((30, 30, 50))
            image_x = 0
            image_y = 0
            new_h = self.height - text_box_height - 50

        # 텍스트 박스 위치 (하단 검은 공간 중앙에 위치)
        text_box_y = self.height - text_box_height - 60

        # 페이드인 (이미지) - skip_fade_in이 True면 생략
        if not skip_fade_in:
            fade_in_frames = int(1.5 * fps)  # 1.5초 페이드인
            for frame in range(fade_in_frames):
                if self.skip_all:
                    return
                for event in pygame.event.get():
                    if event.type == pygame.QUIT:
                        pygame.quit()
                        sys.exit()
                    if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                        return
                    if self._check_skip_all(event):
                        return

                alpha = int(255 * (frame / fade_in_frames))
                self.screen.fill((0, 0, 0))

                # 이미지에 알파 적용
                temp_surface = image.copy()
                temp_surface.set_alpha(alpha)
                self.screen.blit(temp_surface, (image_x, image_y))

                self._draw_skip_hint()
                pygame.display.flip()
                self.clock.tick(fps)

            # 텍스트 시작 전 딜레이
            delay_frames = int(text_delay * fps)
            for frame in range(delay_frames):
                if self.skip_all:
                    return
                for event in pygame.event.get():
                    if event.type == pygame.QUIT:
                        pygame.quit()
                        sys.exit()
                    if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                        return
                    if self._check_skip_all(event):
                        return

                self.screen.fill((0, 0, 0))
                self.screen.blit(image, (image_x, image_y))
                self._draw_skip_hint()
                pygame.display.flip()
                self.clock.tick(fps)

        # 대사 리스트 처리 (쉼표로 구분된 경우 분리)
        if isinstance(dialogues, str):
            dialogue_list = [d.strip() for d in dialogues.split(',')]
        else:
            dialogue_list = dialogues

        # 각 대사를 순차적으로 표시
        for dialogue in dialogue_list:
            if not dialogue:
                continue

            self._show_typing_dialogue(image, image_x, image_y, dialogue, text_box_y, text_box_height, text_color, speaker)

    def show_dark_monologue_scene(self, image_path, dialogues, text_color=(255, 255, 255)):
        """어두운 명암 + 블러 처리된 독백 씬 표시

        Args:
            image_path: 배경 이미지 경로
            dialogues: 독백 대사 리스트
            text_color: 텍스트 색상
        """
        # Ctrl 스킵 체크
        if self.skip_all:
            return

        fps = 60

        # 텍스트 박스 높이 설정
        text_box_height = 180

        # 이미지 로드
        try:
            original_image = pygame.image.load(resource_path(image_path)).convert()
            orig_w, orig_h = original_image.get_size()

            # 이미지 표시 영역
            available_height = self.height - text_box_height - 50
            available_width = self.width

            # 비율 유지하면서 스케일 계산
            scale_w = available_width / orig_w
            scale_h = available_height / orig_h
            scale = min(scale_w, scale_h)

            new_w = int(orig_w * scale)
            new_h = int(orig_h * scale)

            # 화면 전체 너비를 채우도록 조정 (검은 세로선 방지)
            if new_w < self.width:
                new_w = self.width
                new_h = int(orig_h * (self.width / orig_w))

            image = pygame.transform.smoothscale(original_image, (new_w, new_h))

            # 부드러운 블러 효과 적용 (다단계 축소-확대)
            blurred_image = image.copy()
            for blur_pass in range(3):  # 여러 번 블러 적용
                blur_scale = 0.5  # 50%씩 축소 (더 부드러운 블러)
                small_w = max(1, int(blurred_image.get_width() * blur_scale))
                small_h = max(1, int(blurred_image.get_height() * blur_scale))
                small_image = pygame.transform.smoothscale(blurred_image, (small_w, small_h))
                blurred_image = pygame.transform.smoothscale(small_image, (new_w, new_h))

            # 어두운 오버레이 적용 (더 어둡게)
            dark_overlay = pygame.Surface((new_w, new_h), pygame.SRCALPHA)
            dark_overlay.fill((0, 0, 0, 200))  # 더 어두운 반투명 오버레이
            blurred_image.blit(dark_overlay, (0, 0))

            image = blurred_image

            # 이미지 위치 (상단 중앙 정렬)
            image_x = (self.width - new_w) // 2
            image_y = (available_height - new_h) // 2

        except Exception as e:
            print(f"[IntroCutscene] 이미지 로드 실패: {e}")
            image = pygame.Surface((self.width, self.height - text_box_height - 50))
            image.fill((15, 15, 25))
            image_x = 0
            image_y = 0

        # 텍스트 박스 위치
        text_box_y = self.height - text_box_height - 60

        # 페이드인 (어두운 이미지로)
        fade_in_frames = int(1.0 * fps)
        for frame in range(fade_in_frames):
            if self.skip_all:
                return
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                    return
                if self._check_skip_all(event):
                    return

            alpha = int(255 * (frame / fade_in_frames))
            self.screen.fill((0, 0, 0))

            temp_surface = image.copy()
            temp_surface.set_alpha(alpha)
            self.screen.blit(temp_surface, (image_x, image_y))

            self._draw_skip_hint()
            pygame.display.flip()
            self.clock.tick(fps)

        # 대사 리스트 처리
        if isinstance(dialogues, str):
            dialogue_list = [dialogues]
        else:
            dialogue_list = dialogues

        # 각 대사를 순차적으로 표시 (이름표 없음 - 독백)
        for dialogue in dialogue_list:
            if not dialogue:
                continue

            self._show_typing_dialogue(image, image_x, image_y, dialogue, text_box_y, text_box_height, text_color, speaker=None)

    def _draw_baroque_frame(self, surface, x, y, width, height, time_offset=0):
        """신비로운 화이트톤 다이아몬드 테두리 그리기"""
        # 화이트톤 색상 팔레트
        white_pure = (255, 255, 255)
        white_silver = (220, 225, 235)
        white_pearl = (240, 238, 245)
        white_ice = (200, 210, 225)
        white_ghost = (180, 185, 200)
        crystal_blue = (180, 200, 230)
        mystic_violet = (200, 190, 220)

        # 애니메이션 효과를 위한 시간 기반 값
        t = pygame.time.get_ticks() / 1000.0 + time_offset
        shimmer = int(15 * math.sin(t * 2.5))
        pulse = (math.sin(t * 1.5) + 1) / 2  # 0~1 사이 값

        # 메인 프레임 배경 (깊은 어둠)
        frame_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        frame_surface.fill((12, 14, 22, 245))
        surface.blit(frame_surface, (x, y))

        # 외곽 테두리 (3중 레이어 - 화이트톤)
        pygame.draw.rect(surface, white_ghost, (x, y, width, height), 3)
        pygame.draw.rect(surface, white_silver, (x + 2, y + 2, width - 4, height - 4), 2)
        pygame.draw.rect(surface, white_pure, (x + 4, y + 4, width - 8, height - 8), 1)

        # 내부 미세 테두리 (신비로운 느낌)
        inner_margin = 10
        inner_color = (white_ice[0], white_ice[1], white_ice[2], 100)
        inner_surface = pygame.Surface((width - inner_margin * 2, height - inner_margin * 2), pygame.SRCALPHA)
        pygame.draw.rect(inner_surface, inner_color, (0, 0, width - inner_margin * 2, height - inner_margin * 2), 1)
        surface.blit(inner_surface, (x + inner_margin, y + inner_margin))

        # 코너 다이아몬드 장식 (신비로운 크리스탈)
        corner_size = 24
        corners = [
            (x + 6, y + 6),  # 좌상
            (x + width - corner_size - 6, y + 6),  # 우상
            (x + 6, y + height - corner_size - 6),  # 좌하
            (x + width - corner_size - 6, y + height - corner_size - 6)  # 우하
        ]

        for i, (cx, cy) in enumerate(corners):
            center_x = cx + corner_size // 2
            center_y = cy + corner_size // 2

            # 외곽 글로우 (신비로운 빛)
            glow_size = 12 + int(2 * pulse)
            glow_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            glow_alpha = int(40 + 20 * pulse)
            pygame.draw.circle(glow_surface, (*crystal_blue, glow_alpha), (glow_size, glow_size), glow_size)
            surface.blit(glow_surface, (center_x - glow_size, center_y - glow_size))

            # 메인 다이아몬드 (크리스탈)
            diamond_size = 8
            diamond_points = [
                (center_x, center_y - diamond_size),
                (center_x + diamond_size, center_y),
                (center_x, center_y + diamond_size),
                (center_x - diamond_size, center_y)
            ]

            # 다이아몬드 내부 (그라데이션 효과)
            inner_diamond = [
                (center_x, center_y - diamond_size + 2),
                (center_x + diamond_size - 2, center_y),
                (center_x, center_y + diamond_size - 2),
                (center_x - diamond_size + 2, center_y)
            ]

            # 반짝이는 색상
            shimmer_color = (
                min(255, white_pure[0] + shimmer),
                min(255, white_pure[1] + shimmer),
                min(255, white_pure[2] + shimmer)
            )

            pygame.draw.polygon(surface, white_silver, diamond_points)
            pygame.draw.polygon(surface, shimmer_color, inner_diamond)
            pygame.draw.polygon(surface, white_pure, diamond_points, 1)

            # 다이아몬드 중앙 하이라이트
            highlight_alpha = int(150 + 50 * pulse)
            pygame.draw.circle(surface, white_pure, (center_x, center_y), 2)

            # 작은 장식 점들 (별처럼)
            dot_positions = [
                (center_x - 4, center_y - 4),
                (center_x + 4, center_y - 4),
                (center_x - 4, center_y + 4),
                (center_x + 4, center_y + 4),
            ]
            for dx, dy in dot_positions:
                dot_alpha = int(80 + 40 * math.sin(t * 3 + i))
                if dot_alpha > 0:
                    pygame.draw.circle(surface, white_pearl, (dx, dy), 1)

        # 상단/하단 중앙 장식 (절제된 라인)
        mid_x = x + width // 2

        # 상단 장식
        top_y = y + 5
        line_length = 50
        pygame.draw.line(surface, white_ghost, (mid_x - line_length, top_y), (mid_x - 15, top_y), 1)
        pygame.draw.line(surface, white_ghost, (mid_x + 15, top_y), (mid_x + line_length, top_y), 1)

        # 상단 중앙 다이아몬드
        small_diamond = [
            (mid_x, top_y - 4),
            (mid_x + 4, top_y),
            (mid_x, top_y + 4),
            (mid_x - 4, top_y)
        ]
        pygame.draw.polygon(surface, white_silver, small_diamond)
        pygame.draw.polygon(surface, white_pure, small_diamond, 1)

        # 하단 장식
        bot_y = y + height - 6
        pygame.draw.line(surface, white_ghost, (mid_x - line_length, bot_y), (mid_x - 15, bot_y), 1)
        pygame.draw.line(surface, white_ghost, (mid_x + 15, bot_y), (mid_x + line_length, bot_y), 1)

        # 하단 중앙 다이아몬드
        small_diamond_bot = [
            (mid_x, bot_y - 4),
            (mid_x + 4, bot_y),
            (mid_x, bot_y + 4),
            (mid_x - 4, bot_y)
        ]
        pygame.draw.polygon(surface, white_silver, small_diamond_bot)
        pygame.draw.polygon(surface, white_pure, small_diamond_bot, 1)

        # 좌우 미세 장식
        side_y = y + height // 2

        # 좌측 작은 다이아몬드
        left_diamond = [
            (x + 5, side_y - 3),
            (x + 8, side_y),
            (x + 5, side_y + 3),
            (x + 2, side_y)
        ]
        pygame.draw.polygon(surface, white_silver, left_diamond)
        pygame.draw.polygon(surface, white_pure, left_diamond, 1)

        # 우측 작은 다이아몬드
        right_diamond = [
            (x + width - 5, side_y - 3),
            (x + width - 2, side_y),
            (x + width - 5, side_y + 3),
            (x + width - 8, side_y)
        ]
        pygame.draw.polygon(surface, white_silver, right_diamond)
        pygame.draw.polygon(surface, white_pure, right_diamond, 1)

        # 미세한 빛나는 효과 (내부 글로우)
        glow_alpha = int(15 + 10 * math.sin(t * 2))
        glow_surface = pygame.Surface((width - 20, height - 20), pygame.SRCALPHA)
        pygame.draw.rect(glow_surface, (crystal_blue[0], crystal_blue[1], crystal_blue[2], glow_alpha),
                        (0, 0, width - 20, height - 20), 1)
        surface.blit(glow_surface, (x + 10, y + 10))

    def _wrap_text(self, text, max_width):
        """텍스트를 최대 너비에 맞게 줄바꿈"""
        words = []
        current_word = ""

        # 한글과 영어를 모두 처리
        for char in text:
            if char == ' ':
                if current_word:
                    words.append(current_word)
                    current_word = ""
                words.append(' ')
            else:
                current_word += char

        if current_word:
            words.append(current_word)

        lines = []
        current_line = ""

        for word in words:
            test_line = current_line + word
            test_surface, test_rect = self.font_medium.render(test_line, (255, 255, 255))

            if test_rect.width > max_width and current_line:
                lines.append(current_line.strip())
                current_line = word if word != ' ' else ""
            else:
                current_line = test_line

        if current_line.strip():
            lines.append(current_line.strip())

        return lines

    def _show_typing_dialogue(self, image, image_x, image_y, text, text_box_y, text_box_height, text_color, speaker=None):
        """단일 대사를 타이핑 효과로 표시 (클릭/스페이스로만 넘어감)"""
        # Ctrl 스킵 체크
        if self.skip_all:
            return

        fps = 60
        displayed_text = ""
        full_text = text

        typing_speed = 0.05  # 글자당 초
        char_timer = 0
        char_index = 0

        typing_done = False

        # 텍스트 박스 설정
        box_margin = 30
        box_x = box_margin
        box_width = self.width - box_margin * 2
        box_height = text_box_height - 20
        box_y = text_box_y

        # 화자 이름 영역 높이
        speaker_height = 35 if speaker else 0

        # 텍스트 영역 (테두리 안쪽 여백)
        text_padding = 25
        text_area_width = box_width - text_padding * 2

        # 전체 텍스트 줄바꿈 처리
        wrapped_full_text = self._wrap_text(full_text, text_area_width)
        full_text_joined = '\n'.join(wrapped_full_text)

        while True:
            if self.skip_all:
                return
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        return
                    if self._check_skip_all(event):
                        return
                    if event.key == pygame.K_SPACE or event.key == pygame.K_RETURN:
                        if typing_done:
                            return  # 다음 대사로 (클릭/스페이스 필요)
                        else:
                            # 타이핑 스킵
                            displayed_text = full_text_joined
                            char_index = len(full_text_joined)
                            typing_done = True
                if event.type == pygame.MOUSEBUTTONDOWN:
                    if typing_done:
                        return  # 다음 대사로 (클릭/스페이스 필요)
                    else:
                        displayed_text = full_text_joined
                        char_index = len(full_text_joined)
                        typing_done = True

            # 타이핑 애니메이션
            if char_index < len(full_text_joined):
                char_timer += 1 / fps
                while char_timer >= typing_speed and char_index < len(full_text_joined):
                    char_timer -= typing_speed
                    displayed_text += full_text_joined[char_index]
                    char_index += 1
            else:
                if not typing_done:
                    typing_done = True

            # 그리기
            self.screen.fill((0, 0, 0))
            self.screen.blit(image, (image_x, image_y))

            # 화자 이름 박스 (대화 박스 위에) - 화이트톤 디자인
            if speaker:
                speaker_box_width = len(speaker) * 22 + 50
                speaker_box_x = box_x + 15
                speaker_box_y = box_y - 32

                # 화자 이름 배경 (어두운 배경)
                speaker_surface = pygame.Surface((speaker_box_width, 30), pygame.SRCALPHA)
                speaker_surface.fill((12, 14, 22, 250))
                self.screen.blit(speaker_surface, (speaker_box_x, speaker_box_y))

                # 화자 이름 테두리 (화이트톤)
                white_silver = (220, 225, 235)
                white_pure = (255, 255, 255)
                pygame.draw.rect(self.screen, white_silver, (speaker_box_x, speaker_box_y, speaker_box_width, 30), 2)
                pygame.draw.rect(self.screen, white_pure, (speaker_box_x + 2, speaker_box_y + 2, speaker_box_width - 4, 26), 1)

                # 작은 다이아몬드 장식 (왼쪽)
                diamond_x = speaker_box_x + 12
                diamond_y = speaker_box_y + 15
                small_diamond = [
                    (diamond_x, diamond_y - 4),
                    (diamond_x + 4, diamond_y),
                    (diamond_x, diamond_y + 4),
                    (diamond_x - 4, diamond_y)
                ]
                pygame.draw.polygon(self.screen, white_silver, small_diamond)
                pygame.draw.polygon(self.screen, white_pure, small_diamond, 1)

                # 화자 이름 텍스트
                speaker_text, speaker_rect = self.font_medium.render(speaker, text_color)
                self.screen.blit(speaker_text, (speaker_box_x + 25, speaker_box_y + 3))

            # 바로크풍 텍스트 박스 그리기
            self._draw_baroque_frame(self.screen, box_x, box_y, box_width, box_height)

            # 텍스트 렌더링 (줄바꿈 지원)
            last_text_x = box_x + text_padding
            last_text_y = box_y + text_padding
            last_line_width = 0

            if displayed_text:
                lines = displayed_text.split('\n')
                line_height = 32
                # 대사 시작 위치 (박스 내 중앙 정렬)
                total_text_height = len(wrapped_full_text) * line_height
                start_y = box_y + (box_height - total_text_height) // 2

                for i, line in enumerate(lines):
                    if line:
                        text_surface, text_rect = self.font_medium.render(line, text_color)
                        text_x = box_x + text_padding
                        text_y = start_y + i * line_height
                        self.screen.blit(text_surface, (text_x, text_y))

                        # 마지막 줄 위치 저장
                        last_text_x = text_x
                        last_text_y = text_y
                        last_line_width = text_rect.width

                # 타이핑 중 커서 표시
                if not typing_done and int(pygame.time.get_ticks() / 500) % 2 == 0:
                    cursor_x = last_text_x + last_line_width + 3
                    pygame.draw.rect(self.screen, text_color, (cursor_x, last_text_y, 2, 24))

            # 계속하려면... 안내 (타이핑 완료 후) - 마지막 글자 옆에 표시
            if typing_done and displayed_text:
                hint_alpha = int(128 + 127 * math.sin(pygame.time.get_ticks() / 300))
                hint_surface, hint_rect = self.font_small.render("▼", text_color)
                hint_surface.set_alpha(hint_alpha)
                # 마지막 글자 바로 옆에 배치
                hint_x = last_text_x + last_line_width + 8
                hint_y = last_text_y + 2
                self.screen.blit(hint_surface, (hint_x, hint_y))

            # Ctrl 스킵 힌트 표시
            self._draw_skip_hint()

            pygame.display.flip()
            self.clock.tick(fps)

    def fade_out_to_black(self, duration=1.0):
        """페이드아웃 (검은색으로)"""
        # Ctrl 스킵 체크
        if self.skip_all:
            self.screen.fill((0, 0, 0))
            pygame.display.flip()
            return

        fps = 60
        frames = int(duration * fps)

        # 현재 화면 캡처
        current_screen = self.screen.copy()

        for frame in range(frames):
            if self.skip_all:
                break
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if self._check_skip_all(event):
                    break

            alpha = int(255 * (frame / frames))
            self.screen.blit(current_screen, (0, 0))

            fade_surface = pygame.Surface((self.width, self.height))
            fade_surface.fill((0, 0, 0))
            fade_surface.set_alpha(alpha)
            self.screen.blit(fade_surface, (0, 0))

            self._draw_skip_hint()
            pygame.display.flip()
            self.clock.tick(fps)

        self.screen.fill((0, 0, 0))
        pygame.display.flip()

    def run_intro_sequence(self):
        """전체 인트로 시퀀스 실행"""
        # 1. 두 명언을 한 화면에 표시
        self.show_combined_quotes_screen()

        # 2. 추가 명언 표시
        self.show_additional_quotes_screen()

        # 3. 검은 화면 대기 (드라마틱 연출용 - 사운드 삽입 가능)
        self.show_black_screen(duration=2.0)

        # 4. 스토리 컷씬들
        # 컷씬 1: 주인공 유이안 대사 (현실 - 흰색)
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20251219_234944201.png",
            dialogues="아하하! 가상현실~?, 그게 뭐야!, 현실을 놔두고 만들어 진 가상 세계 속에서 현실처럼 사는 거잖아?",
            text_delay=1.5,
            text_color=(255, 255, 255),  # 흰색 (주인공)
            speaker="유이안"  # 현실에서는 유이안
        )

        # 컷씬 1 연속: 독백 (이름표 없음)
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20251219_234944201.png",
            dialogues=[
                "입 안에 알코올 액체를 끝없이 들이붓는다.",
                "클럽의 북적거림은 취기 속에서 한없이 들뜨게 만들었고,",
                "그 속에서 오가는 화제는 더없이 심심하기 짝이 없는 화제였다.",
                "어둠 속에서 빛이 나는 미모들에 둘러 싸인 난",
                "비싼 술을 주문하며 놀고 먹는다.",
                "새로운 기술로 인한 사회의 커다란 변화는,",
                "달콤한 현실에 한껏 취해있는 내게 아무래도 좋을 화젯거리였다."
            ],
            text_delay=0.5,
            text_color=(128, 128, 128),  # 회색 (독백)
            speaker=None  # 독백 - 이름표 없음
        )
        self.fade_out_to_black(duration=1.0)

        # 컷씬 2: 유이안 대사 (현실)
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20251220_011347691_01.png",
            dialogues=[
                "인간이 만든 건 이미 현존하고 있는 현실에 못 미쳐!",
                "당연하잖아? 이미 현실에서 모든 것을 할 수 있고, 실현이 가능하단 말이지~ 딸꾹!"
            ],
            text_delay=1.5,
            text_color=(255, 255, 255),  # 흰색 (주인공)
            speaker="유이안"
        )

        # 컷씬 2 연속: 여자 대사 (핑크색)
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20251220_011347691.png",
            dialogues="어머나. 그건 도련님처럼 배경과 돈이 있을 때의 경우잖아요?",
            text_delay=0.5,
            text_color=(255, 80, 120),  # 더 진한 핑크색 (여자)
            speaker="여자"
        )

        # 컷씬 2 연속: 남자 대사 (파란색) - 페이드인 생략
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20251220_011347691.png",
            dialogues="맞아. 우리 같은 서민은 현실에서 이룰 수 있는 건 얼마 없다고요.",
            text_delay=0.5,
            text_color=(135, 206, 250),  # 파란색 (남자)
            speaker="남자",
            skip_fade_in=True  # 여자→남자 전환 시 깜빡임 없이 연결
        )

        # 컷씬 2 연속: 유이안 대사 (흰색)
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20251220_011347691_01.png",
            dialogues="하아~ 결국 돈인가… 뭐, 돈의 혜택을 잔뜩 누리고 있는 입장에서 할 말은 아니지만 말야. 흐흐.",
            text_delay=0.5,
            text_color=(255, 255, 255),  # 흰색 (주인공)
            speaker="유이안"
        )

        # 컷씬 2 마무리: 어두운 독백 (블러 + 명암 처리)
        self.show_dark_monologue_scene(
            image_path="introstory/KakaoTalk_20251220_011347691_01.png",
            dialogues=[
                "마음에 들지 않으면 고치거나 바꾸면 된다.",
                "이 단순하고도 당연한 사실은 현실에서 이룰 수 있는 사람은 극소수에 불과했다.",
                "그러지 못한 사람들이 부조리, 라고 외쳐 대지만 결국 그런 부조리한 사회를 만든 것은 인간이다.",
                "결국 모든 인간의 문제는 인간들의 타당한 말로에 가까운 것이다.",
                "더러운 자본주의 사회.",
                "하지만 그것은 인류가 선택한 수단에 불과할 뿐이었다."
            ],
            text_color=(128, 128, 128)  # 회색 (독백)
        )
        self.fade_out_to_black(duration=1.0)

        # 최종 페이드아웃
        self.fade_out_to_black(duration=0.5)


def show_intro_cutscene(screen, width, height):
    """인트로 컷씬 표시 함수 (외부에서 호출용)"""
    cutscene = IntroCutscene(screen, width, height)
    cutscene.run_intro_sequence()


# ============================================================
# 기존 코드 시작
# ============================================================


# 인트로 클릭 사운드 로드
_intro_click_sound = None

def _load_intro_click_sound():
    """인트로 클릭 사운드 로드 (지연 로딩)"""
    global _intro_click_sound
    if _intro_click_sound is None:
        try:
            sound_path = resource_path("sounds/introclick.wav")
            _intro_click_sound = pygame.mixer.Sound(sound_path)
            _intro_click_sound.set_volume(0.7)
        except Exception as e:
            print(f"[Opening] 인트로 클릭 사운드 로드 실패: {e}")
            _intro_click_sound = None
    return _intro_click_sound

def play_intro_click_sound():
    """인트로 클릭 사운드 재생"""
    sound = _load_intro_click_sound()
    if sound:
        try:
            sound.play()
        except Exception:
            pass


def show_opening_animation(SCREEN, WIDTH, HEIGHT):
    """게임 오프닝 애니메이션 - 간단한 버전"""
    # 인트로 BGM 재생
    bgm_manager.play_intro_bgm()

    # 배경 이미지 로드 (main.jpg)
    background_image = None
    try:
        bg_path = resource_path("main.jpg")
        if os.path.exists(bg_path):
            background_image = pygame.image.load(bg_path).convert()
            # 화면 크기에 맞게 스케일
            background_image = pygame.transform.smoothscale(background_image, (WIDTH, HEIGHT))
            print(f"[Opening] 배경 이미지 로드 완료: {bg_path}")
    except Exception as e:
        print(f"[Opening] 배경 이미지 로드 실패: {e}")
        background_image = None

    # 애니메이션 상태 변수들
    animation_timer = 0
    fade_alpha = 0
    text_alpha = 0
    logo_scale = 0.1
    logo_y = HEIGHT // 2
    logo_target_y = HEIGHT // 3
    
    # 텍스트 애니메이션
    typing_text = ""
    full_text = "핑파이터"
    typing_speed = 0.1
    typing_timer = 0
    
    # 파티클 효과
    particles = []
    sparkle_particles = []
    shooting_stars = []  # 별똥별
    fuzzy_stars = []     # 뿌연 별들
    
    # 이펙트 변수들
    glow_intensity = 0
    rotation_angle = 0
    
    # 3초 후에 "Press any key" 표시
    show_press_key = False
    press_key_alpha = 0
    
    # 10초 이상 대기 시 특별 애니메이션
    idle_timer = 0
    special_animation_active = False
    special_animation_timer = 0
    
    # 특별 애니메이션용 변수들
    battle_particles = []
    energy_waves = []
    boss_shadows = []
    paddle_projectiles = []
    screen_shake = 0
    flash_alpha = 0
    
    clock = pygame.time.Clock()
    
    while True:
        animation_timer += 1
        typing_timer += typing_speed

        # 단일 이벤트 수집(프레임당 1회) 후 처리: ESC만 즉시 스킵, 그 외 입력은 연출 트리거
        events = pygame.event.get()
        for event in events:
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN:
                # ESC는 즉시 스킵 허용
                if event.key == pygame.K_ESCAPE:
                    return
                # 안내 표시 이후에는 키 입력으로 특별 연출 시작
                if show_press_key and not special_animation_active:
                    play_intro_click_sound()  # 인트로 클릭 사운드 재생
                    special_animation_active = True
                    special_animation_timer = 0
            if event.type == pygame.MOUSEBUTTONDOWN:
                # 안내 표시 이후에는 클릭으로도 특별 연출 시작
                if show_press_key and not special_animation_active:
                    play_intro_click_sound()  # 인트로 클릭 사운드 재생
                    special_animation_active = True
                    special_animation_timer = 0
        
        # 1초 후에 "Press any key" 표시 시작
        if animation_timer > 60:  # 1초 = 60프레임 (60fps)
            show_press_key = True
            press_key_alpha = min(255, press_key_alpha + 3)
        
        # 특별 애니메이션 중일 때
        if special_animation_active:
            special_animation_timer += 1
            
            # 1.5초(90프레임) 후에 페이드 아웃 시작
            if special_animation_timer > 90:
                fade_alpha = min(255, fade_alpha + 5)
                if fade_alpha >= 255:
                    return  # 완전히 페이드 아웃되면 메뉴로
            
            # 화면 흔들림 효과
            screen_shake = int(10 * math.sin(special_animation_timer * 0.3))
            
            # 플래시 효과
            if special_animation_timer % 120 < 10:
                flash_alpha = 100
            else:
                flash_alpha = max(0, flash_alpha - 5)
            
            # 전투 파티클 생성
            if special_animation_timer % 5 == 0:
                for _ in range(3):
                    battle_particles.append({
                        'x': random.randint(0, WIDTH),
                        'y': random.randint(0, HEIGHT),
                        'dx': random.uniform(-8, 8),
                        'dy': random.uniform(-8, 8),
                        'life': 120,
                        'size': random.randint(3, 8),
                        'color': random.choice([(255, 100, 100), (100, 100, 255), (255, 255, 100), (255, 100, 255)])
                    })
            
            # 에너지 웨이브 생성
            if special_animation_timer % 60 == 0:
                energy_waves.append({
                    'x': WIDTH // 2,
                    'y': HEIGHT // 2,
                    'radius': 0,
                    'max_radius': WIDTH,
                    'speed': 15,
                    'life': 180,
                    'alpha': 255
                })
            
            # 보스 그림자 생성
            if special_animation_timer % 180 == 0:
                boss_shadows.append({
                    'x': random.randint(100, WIDTH - 100),
                    'y': random.randint(100, HEIGHT - 100),
                    'size': random.randint(50, 150),
                    'life': 300,
                    'alpha': 255,
                    'rotation': 0
                })
            
            # 패들 발사체 생성
            if special_animation_timer % 30 == 0:
                paddle_projectiles.append({
                    'x': random.randint(0, WIDTH),
                    'y': HEIGHT,
                    'dx': random.uniform(-5, 5),
                    'dy': random.uniform(-15, -8),
                    'life': 180,
                    'size': random.randint(5, 15)
                })
        
        # 추가 이벤트 처리는 위 단일 루프에서 처리함 (중복 소비 방지)

        # 화면 그리기 (필러 배경과 비슷한 어두운 색으로 채움)
        SCREEN.fill((15, 15, 25))  # 어두운 남색 (필러 배경 기본색)

        # 배경 이미지 그리기 (main.jpg)
        if background_image is not None:
            SCREEN.blit(background_image, (0, 0))
            # 어두운 오버레이 (텍스트 가독성)
            dark_overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            dark_overlay.fill((0, 0, 0, 120))
            SCREEN.blit(dark_overlay, (0, 0))
        else:
            # 배경 이미지가 없으면 기존 그라데이션 사용
            for y in range(HEIGHT):
                color_ratio = y / HEIGHT
                time_factor = math.sin(animation_timer * 0.02) * 0.3 + 0.7
                r = int(10 + color_ratio * 100 * time_factor)
                g = int(20 + color_ratio * 150 * time_factor)
                b = int(40 + color_ratio * 180 * time_factor)
                pygame.draw.line(SCREEN, (r, g, b), (0, y), (WIDTH, y))

        # 특별 애니메이션 중일 때 배경을 더 어둡게
        if special_animation_active:
            dark_special = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            dark_special.fill((10, 5, 15, 180))
            SCREEN.blit(dark_special, (0, 0))
        
        # 특별 애니메이션 중일 때만 특별 효과들 그리기
        if special_animation_active:
            # 에너지 웨이브 그리기
            for wave in energy_waves[:]:
                wave['radius'] += wave['speed']
                wave['alpha'] = int(255 * (1 - wave['radius'] / wave['max_radius']))
                
                if wave['alpha'] > 0 and wave['radius'] < wave['max_radius']:
                    wave_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
                    pygame.draw.circle(wave_surface, (100, 200, 255, wave['alpha']), 
                                     (wave['x'], wave['y']), wave['radius'], 5)
                    SCREEN.blit(wave_surface, (0, 0))
                else:
                    energy_waves.remove(wave)
            
            # 보스 그림자 그리기
            for shadow in boss_shadows[:]:
                shadow['life'] -= 2
                shadow['alpha'] = int(255 * (shadow['life'] / 300))
                shadow['rotation'] += 2
                
                if shadow['alpha'] > 0:
                    shadow_surface = pygame.Surface((shadow['size'] * 2, shadow['size'] * 2), pygame.SRCALPHA)
                    
                    # 보스 형태 그리기 (간단한 실루엣)
                    center = (shadow['size'], shadow['size'])
                    
                    # 몸체
                    pygame.draw.ellipse(shadow_surface, (100, 0, 100, shadow['alpha']), 
                                      (shadow['size']//4, shadow['size']//4, shadow['size']//2, shadow['size']//2))
                    
                    # 눈
                    eye_size = shadow['size'] // 8
                    pygame.draw.circle(shadow_surface, (255, 0, 0, shadow['alpha']), 
                                     (center[0] - eye_size, center[1] - eye_size), eye_size)
                    pygame.draw.circle(shadow_surface, (255, 0, 0, shadow['alpha']), 
                                     (center[0] + eye_size, center[1] - eye_size), eye_size)
                    
                    # 회전 적용
                    rotated_shadow = pygame.transform.rotate(shadow_surface, shadow['rotation'])
                    shadow_rect = rotated_shadow.get_rect(center=(shadow['x'], shadow['y']))
                    SCREEN.blit(rotated_shadow, shadow_rect)
                else:
                    boss_shadows.remove(shadow)
            
            # 패들 발사체 그리기
            for projectile in paddle_projectiles[:]:
                projectile['x'] += projectile['dx']
                projectile['y'] += projectile['dy']
                projectile['life'] -= 1
                
                if projectile['life'] > 0 and projectile['y'] > -projectile['size']:
                    # 발사체 꼬리 효과
                    for i in range(10):
                        trail_alpha = int(255 * (projectile['life'] / 180) * (1 - i / 10))
                        trail_size = max(1, projectile['size'] * (1 - i / 10))
                        trail_x = projectile['x'] - projectile['dx'] * i * 0.3
                        trail_y = projectile['y'] - projectile['dy'] * i * 0.3
                        
                        if trail_alpha > 0:
                            trail_surface = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                            pygame.draw.circle(trail_surface, (255, 255, 100, trail_alpha), 
                                             (trail_size, trail_size), trail_size)
                            SCREEN.blit(trail_surface, (trail_x - trail_size, trail_y - trail_size))
                    
                    # 발사체 본체
                    alpha = int(255 * (projectile['life'] / 180))
                    size = max(1, projectile['size'])
                    proj_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(proj_surface, (255, 255, 0, alpha), (size, size), size)
                    SCREEN.blit(proj_surface, (projectile['x'] - size, projectile['y'] - size))
                else:
                    paddle_projectiles.remove(projectile)
            
            # 전투 파티클 그리기
            for particle in battle_particles[:]:
                particle['x'] += particle['dx']
                particle['y'] += particle['dy']
                particle['life'] -= 1
                
                if particle['life'] > 0 and 0 <= particle['x'] <= WIDTH and 0 <= particle['y'] <= HEIGHT:
                    alpha = int(255 * (particle['life'] / 120))
                    size = max(1, particle['size'])
                    color = (*particle['color'], alpha)
                    
                    particle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(particle_surface, color, (size, size), size)
                    SCREEN.blit(particle_surface, (particle['x'] - size, particle['y'] - size))
                else:
                    battle_particles.remove(particle)
            
            # 화면 흔들림 효과 적용
            shake_offset = (random.randint(-abs(screen_shake), abs(screen_shake)), 
                           random.randint(-abs(screen_shake), abs(screen_shake)))
        
        # 배경에 움직이는 파티클 효과 (간단하게)
        if animation_timer % 10 == 0:
            for _ in range(2):
                particles.append({
                    'x': random.randint(0, WIDTH),
                    'y': random.randint(0, HEIGHT),
                    'dx': random.uniform(-1, 1),
                    'dy': random.uniform(-1, 1),
                    'life': 60,
                    'size': 2
                })
        
        # 별똥별 생성 (가끔씩)
        if animation_timer % 120 == 0:  # 2초마다
            shooting_stars.append({
                'x': random.randint(0, WIDTH),
                'y': random.randint(0, HEIGHT // 3),
                'dx': random.uniform(3, 6),
                'dy': random.uniform(2, 4),
                'life': 120,
                'size': random.randint(2, 4),
                'trail_length': random.randint(20, 40)
            })
        
        # 뿌연 별들 생성 (천천히)
        if animation_timer % 180 == 0:  # 3초마다
            for _ in range(random.randint(1, 3)):
                fuzzy_stars.append({
                    'x': random.randint(0, WIDTH),
                    'y': random.randint(0, HEIGHT),
                    'life': 300,
                    'size': random.randint(4, 8),
                    'fade_speed': random.uniform(0.5, 1.5),
                    'alpha': 255
                })
        
        # 로고 스케일 애니메이션 (더 부드럽게)
        logo_scale = min(1.3, logo_scale + 0.012)
        logo_y = logo_y + (logo_target_y - logo_y) * 0.025
        
        # 로고 그리기 (더 화려한 버전)
        logo_surface = pygame.Surface((600, 300), pygame.SRCALPHA)
        
        # 특별 애니메이션 중일 때 로고에 특별 효과
        if special_animation_active:
            # 로고에 전투 효과 추가
            for i in range(20):
                spark_x = random.randint(0, 600)
                spark_y = random.randint(0, 300)
                spark_size = random.randint(2, 6)
                spark_alpha = random.randint(50, 150)
                pygame.draw.circle(logo_surface, (255, 255, 0, spark_alpha), (spark_x, spark_y), spark_size)
        
        # 외곽 글로우 효과 (더 강하게)
        glow_radius = int(25 + math.sin(animation_timer * 0.08) * 15)
        for i in range(glow_radius, 0, -2):
            alpha = int(120 * (1 - i / glow_radius))
            # 무지개 색상 효과
            hue = (animation_timer * 2 + i * 10) % 360
            if hue < 60:
                color = (255, int(255 * hue / 60), 0, alpha)
            elif hue < 120:
                color = (int(255 * (120 - hue) / 60), 255, 0, alpha)
            elif hue < 180:
                color = (0, 255, int(255 * (hue - 120) / 60), alpha)
            elif hue < 240:
                color = (0, int(255 * (240 - hue) / 60), 255, alpha)
            elif hue < 300:
                color = (int(255 * (hue - 240) / 60), 0, 255, alpha)
            else:
                color = (255, 0, int(255 * (360 - hue) / 60), alpha)
            pygame.draw.rect(logo_surface, color, (i, i, 600 - i*2, 300 - i*2), 4)
        
        # 메인 로고 프레임 (더 화려하게)
        pygame.draw.rect(logo_surface, (150, 200, 255), (0, 0, 600, 300), 10)
        pygame.draw.rect(logo_surface, (200, 220, 255), (15, 15, 570, 270), 5)
        
        # 내부 장식 (더 복잡하게)
        for i in range(8):
            x = 50 + i * 70
            y = 50 + math.sin(animation_timer * 0.05 + i * 0.5) * 15
            size = 10 + math.sin(animation_timer * 0.03 + i) * 5
            pygame.draw.circle(logo_surface, (255, 255, 255), (int(x), int(y)), int(size))
            pygame.draw.circle(logo_surface, (100, 150, 255), (int(x), int(y)), int(size), 2)
        
        # 코너 장식
        corner_size = 20
        for corner in [(0, 0), (600-corner_size, 0), (0, 300-corner_size), (600-corner_size, 300-corner_size)]:
            pygame.draw.rect(logo_surface, (255, 255, 0), (corner[0], corner[1], corner_size, corner_size))
            pygame.draw.rect(logo_surface, (255, 255, 255), (corner[0], corner[1], corner_size, corner_size), 2)
        
        # 텍스트 타이핑 효과 (한글로 변경)
        if typing_timer >= 1:
            if len(typing_text) < len(full_text):
                typing_text = full_text[:len(typing_text) + 1]
                typing_timer = 0
        
        try:
            font_large = pygame.font.Font(resource_path("NanumSquareB.ttf"), 72)
        except:
            font_large = pygame.font.Font(None, 72)
        
        # 메인 텍스트 (한글로 변경)
        full_text = "핑파이터"
        if len(typing_text) < len(full_text):
            typing_text = full_text[:len(typing_text) + 1]
        
        # 귀여운 글자 애니메이션 - 각 글자가 살짝 튀어오르기
        char_positions = []
        # 중앙 정렬을 위한 계산 (4글자 기준)
        total_width = len(typing_text) * 70 - 10  # 글자 4개 * 70픽셀 간격 - 마지막 여백
        base_x = 300 - (total_width // 2) + 35  # 중앙에서 시작
        for i, char in enumerate(typing_text):
            # 각 글자별로 다른 타이밍으로 위아래 움직임
            bounce_offset = math.sin(animation_timer * 0.1 + i * 0.5) * 3
            wiggle_offset = math.cos(animation_timer * 0.08 + i * 0.7) * 2  # 좌우 흔들림
            char_positions.append((base_x + i * 70 + wiggle_offset, 150 + bounce_offset))
        
        # 귀여운 별 장식 (글자 주변에)
        if animation_timer % 20 == 0:
            for pos in char_positions:
                if random.random() > 0.7:  # 30% 확률로
                    sparkle_particles.append({
                        'x': pos[0] + random.randint(-30, 30),
                        'y': pos[1] + random.randint(-30, 30),
                        'life': 40,
                        'size': random.randint(2, 4),
                        'color': random.choice([(255, 192, 203), (255, 255, 150), (200, 255, 200)])  # 파스텔 색상
                    })
        
        # 부드러운 파스텔 그림자
        shadow_color = (150, 150, 200)  # 연한 보라색 그림자
        for i, (char, pos) in enumerate(zip(typing_text, char_positions)):
            shadow_text = font_large.render(char, True, shadow_color)
            shadow_rect = shadow_text.get_rect(center=(pos[0] + 3, pos[1] + 3))
            logo_surface.blit(shadow_text, shadow_rect)
        
        # 둥근 외곽선 효과 (파스텔 핑크)
        outline_color = (255, 182, 193)  # 연한 핑크
        for i, (char, pos) in enumerate(zip(typing_text, char_positions)):
            # 더 많은 위치에 외곽선을 그려서 둥글게
            for ox, oy in [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)]:
                outline_text = font_large.render(char, True, outline_color)
                outline_rect = outline_text.get_rect(center=(pos[0] + ox, pos[1] + oy))
                logo_surface.blit(outline_text, outline_rect)
        
        # 무지개 그라데이션 효과
        rainbow_colors = [
            (255, 165, 0),    # 주황빛 (핑)
            (255, 200, 150),  # 연한 주황
            (255, 255, 0),    # 진한 노랑
            (150, 255, 150),  # 연한 초록
            (150, 200, 255),  # 연한 파랑
        ]
        
        # 각 글자 그리기 (무지개 색상)
        for i, (char, pos) in enumerate(zip(typing_text, char_positions)):
            # 색상 선택 (순환)
            color_index = i % len(rainbow_colors)
            base_color = rainbow_colors[color_index]
            
            # 반짝임 효과
            sparkle = abs(math.sin(animation_timer * 0.05 + i * 0.3)) * 0.3 + 0.7
            char_color = tuple(int(c * sparkle) for c in base_color)
            
            # 글자 그리기
            char_text = font_large.render(char, True, char_color)
            char_rect = char_text.get_rect(center=pos)
            logo_surface.blit(char_text, char_rect)
            
            # 하이라이트 (뽀얀 효과)
            highlight_color = (255, 255, 255, 60)
            highlight_text = font_large.render(char, True, highlight_color)
            highlight_rect = highlight_text.get_rect(center=(pos[0] - 1, pos[1] - 2))
            logo_surface.blit(highlight_text, highlight_rect)
        
        
        # 귀여운 별 장식 추가
        star_positions = [(80, 120), (520, 120), (60, 170), (540, 170)]
        for sx, sy in star_positions:
            star_size = 5 + math.sin(animation_timer * 0.1 + sx) * 2
            star_color = (255, 255, 100, 180)
            # 별 그리기 (5각별)
            angle = animation_timer * 0.05
            points = []
            for i in range(10):
                r = star_size if i % 2 == 0 else star_size * 0.5
                theta = angle + (i * math.pi / 5)
                px = sx + r * math.cos(theta)
                py = sy + r * math.sin(theta)
                points.append((px, py))
            if len(points) > 2:
                pygame.draw.polygon(logo_surface, star_color, points)
        
        # 서브 타이틀
        try:
            font_medium = pygame.font.Font(resource_path("NanumSquareR.ttf"), 32)
        except:
            font_medium = pygame.font.Font(None, 32)
        
        subtitle_text = font_medium.render("핑퐁으로 보스를 물리쳐라!", True, (200, 220, 255))
        subtitle_rect = subtitle_text.get_rect(center=(300, 200))
        logo_surface.blit(subtitle_text, subtitle_rect)
        
        # 스케일 적용
        scaled_logo = pygame.transform.scale(logo_surface, 
                                           (int(600 * logo_scale), int(300 * logo_scale)))
        
        # 화면 흔들림 효과 적용
        if special_animation_active:
            logo_rect = scaled_logo.get_rect(center=(WIDTH // 2 + shake_offset[0], logo_y + shake_offset[1]))
        else:
            logo_rect = scaled_logo.get_rect(center=(WIDTH // 2, logo_y))
        
        SCREEN.blit(scaled_logo, logo_rect)
        
        # 스파클 파티클 (간단하게)
        if animation_timer % 15 == 0:
            for _ in range(3):
                sparkle_particles.append({
                    'x': random.randint(0, WIDTH),
                    'y': random.randint(0, HEIGHT),
                    'life': 60,
                    'size': 3
                })
        
        # 화면 전체 글로우 효과
        if animation_timer > 100:
            glow_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            glow_alpha = int(20 * math.sin(animation_timer * 0.05))
            glow_surface.fill((255, 255, 255))
            glow_surface.set_alpha(glow_alpha)
            SCREEN.blit(glow_surface, (0, 0))
        
        # 플래시 효과
        if flash_alpha > 0:
            flash_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            flash_surface.fill((255, 255, 255))
            flash_surface.set_alpha(flash_alpha)
            SCREEN.blit(flash_surface, (0, 0))
        
        # 페이드 아웃 효과
        if fade_alpha > 0:
            fade_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            fade_surface.fill((0, 0, 0))
            fade_surface.set_alpha(fade_alpha)
            SCREEN.blit(fade_surface, (0, 0))
        
        # "Press any key" 문구 (3초 후에 나타남)
        if show_press_key and not special_animation_active:
            try:
                font_small = pygame.font.Font(resource_path("NanumSquareR.ttf"), 24)
            except:
                font_small = pygame.font.Font(None, 24)
            
            # 깜빡이는 효과
            if animation_timer % 60 < 30:
                press_text = font_small.render("아무 키나 누르세요", True, (200, 200, 200))
                press_surface = pygame.Surface((WIDTH, 50), pygame.SRCALPHA)
                press_surface.fill((0, 0, 0, press_key_alpha))
                press_rect = press_text.get_rect(center=(WIDTH // 2, HEIGHT - 80))
                press_surface.blit(press_text, press_rect)
                SCREEN.blit(press_surface, (0, HEIGHT - 100))
        
        # 파티클 업데이트 및 그리기
        # 배경 파티클
        for particle in particles[:]:
            particle['x'] += particle['dx']
            particle['y'] += particle['dy']
            particle['life'] -= 1
            
            if particle['life'] > 0:
                alpha = int(255 * (particle['life'] / 60))
                size = max(1, particle['size'])  # 최소 크기 1로 제한
                particle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                # 기본 흰색으로 파티클 그리기
                pygame.draw.circle(particle_surface, (255, 255, 255, alpha), (size, size), size)
                SCREEN.blit(particle_surface, (particle['x'] - size, particle['y'] - size))
            else:
                particles.remove(particle)
        
        # 스파클 파티클
        for particle in sparkle_particles[:]:
            particle['life'] -= 1
            if particle['life'] > 0:
                # 파스텔 색상 지원
                if 'color' in particle:
                    base_color = particle['color']
                    alpha = int(255 * (particle['life'] / 40))  # 40은 life 최대값
                    color = (*base_color, alpha)
                else:
                    alpha = int(255 * (particle['life'] / 60))
                    color = (255, 255, 255, alpha)
                
                size = max(1, particle['size'])  # 최소 크기 1로 제한
                sparkle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                # 파스텔 색상 또는 기본 흰색으로 스파클 그리기
                pygame.draw.circle(sparkle_surface, color, (size, size), size)
                SCREEN.blit(sparkle_surface, (particle['x'] - size, particle['y'] - size))
            else:
                sparkle_particles.remove(particle)
        
        # 별똥별 업데이트 및 그리기
        for star in shooting_stars[:]:
            star['x'] += star['dx']
            star['y'] += star['dy']
            star['life'] -= 1
            
            if star['life'] > 0 and star['x'] < WIDTH + 50 and star['y'] < HEIGHT + 50:
                # 별똥별 꼬리 그리기
                for i in range(star['trail_length']):
                    trail_alpha = int(255 * (star['life'] / 120) * (1 - i / star['trail_length']))
                    trail_size = max(1, star['size'] * (1 - i / star['trail_length']))
                    trail_x = star['x'] - star['dx'] * i * 0.5
                    trail_y = star['y'] - star['dy'] * i * 0.5
                    
                    if trail_alpha > 0 and trail_size > 0:
                        trail_surface = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(trail_surface, (255, 255, 255, trail_alpha), (trail_size, trail_size), trail_size)
                        SCREEN.blit(trail_surface, (trail_x - trail_size, trail_y - trail_size))
                
                # 별똥별 본체
                alpha = int(255 * (star['life'] / 120))
                size = max(1, star['size'])
                star_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(star_surface, (255, 255, 255, alpha), (size, size), size)
                SCREEN.blit(star_surface, (star['x'] - size, star['y'] - size))
            else:
                shooting_stars.remove(star)
        
        # 뿌연 별들 업데이트 및 그리기
        for star in fuzzy_stars[:]:
            star['life'] -= star['fade_speed']
            star['alpha'] = int(255 * (star['life'] / 300))
            
            if star['life'] > 0 and star['alpha'] > 0:
                # 뿌연 별 그리기 (여러 개의 작은 원으로)
                size = max(1, star['size'])
                for i in range(3):
                    offset = i * 2
                    fuzzy_alpha = int(star['alpha'] * (1 - i * 0.3))
                    fuzzy_size = max(1, size - i * 2)
                    
                    if fuzzy_alpha > 0 and fuzzy_size > 0:
                        fuzzy_surface = pygame.Surface((fuzzy_size * 2, fuzzy_size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(fuzzy_surface, (255, 255, 255, fuzzy_alpha), (fuzzy_size, fuzzy_size), fuzzy_size)
                        SCREEN.blit(fuzzy_surface, (star['x'] - fuzzy_size + offset, star['y'] - fuzzy_size + offset))
            else:
                fuzzy_stars.remove(star)
        
        pygame.display.flip()
        clock.tick(60) 
