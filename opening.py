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
            # 대화창용 함초롱바탕 Bold 폰트
            self.font_medium = pygame.freetype.Font(
                resource_path(os.path.join("font", "HCRBatang-Bold.ttf")), 24
            )
            self.font_small = pygame.freetype.Font(
                resource_path(os.path.join("font", "HCRBatang-Bold.ttf")), 20
            )
            self.font_hint = pygame.freetype.Font(
                resource_path("NanumSquareR.ttf"), 14
            )
            # 기본 폰트 (대화창 텍스트용)
            self.font = self.font_medium
        except Exception as e:
            print(f"[IntroCutscene] 폰트 로드 실패, 기본 폰트 사용: {e}")
            self.font_large = pygame.freetype.SysFont("Arial", 32)
            self.font_medium = pygame.freetype.SysFont("Arial", 24)
            self.font_small = pygame.freetype.SysFont("Arial", 20)
            self.font_hint = pygame.freetype.SysFont("Arial", 14)
            self.font = self.font_medium

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
        from localization.manager import get_localization_manager
        hint_text = get_localization_manager().get_text("opening.skip_hint", "Ctrl - 스킵")
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
                    if event.key in (pygame.K_ESCAPE, pygame.K_SPACE, pygame.K_RETURN):
                        return  # ESC, 스페이스, 엔터로 스킵
                if event.type == pygame.MOUSEBUTTONDOWN:
                    return  # 마우스 클릭으로 스킵

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

        # 텍스트 박스 위치 (하단에 정렬)
        text_box_y = self.height - text_box_height - 30

        # 페이드인 (이미지) - skip_fade_in이 True면 생략
        if not skip_fade_in:
            fade_in_frames = int(1.5 * fps)  # 1.5초 페이드인
            skip_fade = False
            for frame in range(fade_in_frames):
                if self.skip_all or skip_fade:
                    break
                for event in pygame.event.get():
                    if event.type == pygame.QUIT:
                        pygame.quit()
                        sys.exit()
                    if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                        return
                    if self._check_skip_all(event):
                        return
                    # 마우스 클릭 또는 스페이스/엔터로 페이드인 스킵
                    if event.type == pygame.MOUSEBUTTONDOWN or (event.type == pygame.KEYDOWN and event.key in (pygame.K_SPACE, pygame.K_RETURN)):
                        skip_fade = True
                        break

                alpha = int(255 * (frame / fade_in_frames))
                self.screen.fill((0, 0, 0))

                # 이미지에 알파 적용
                temp_surface = image.copy()
                temp_surface.set_alpha(alpha)
                self.screen.blit(temp_surface, (image_x, image_y))

                self._draw_skip_hint()
                pygame.display.flip()
                self.clock.tick(fps)

            # 텍스트 시작 전 딜레이 (페이드인 스킵 시 딜레이도 스킵)
            if not skip_fade:
                delay_frames = int(text_delay * fps)
                skip_delay = False
                for frame in range(delay_frames):
                    if self.skip_all or skip_delay:
                        break
                    for event in pygame.event.get():
                        if event.type == pygame.QUIT:
                            pygame.quit()
                            sys.exit()
                        if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                            return
                        if self._check_skip_all(event):
                            return
                        # 마우스 클릭 또는 스페이스/엔터로 딜레이 스킵
                        if event.type == pygame.MOUSEBUTTONDOWN or (event.type == pygame.KEYDOWN and event.key in (pygame.K_SPACE, pygame.K_RETURN)):
                            skip_delay = True
                            break

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

    def show_zoom_in_scene(self, image_path, dialogues, zoom_target=(0.45, 0.35), zoom_start=1.0, zoom_end=1.8, zoom_duration=3.0, text_color=(255, 255, 255), speaker=None):
        """줌인 효과가 있는 스토리 씬 표시 (대화와 동시에 줌인)

        Args:
            image_path: 배경 이미지 경로
            dialogues: 대사 리스트
            zoom_target: 줌인 목표 지점 (0~1 비율, x, y) - 상자 가운데
            zoom_start: 시작 줌 배율
            zoom_end: 최종 줌 배율
            zoom_duration: 줌인 지속 시간 (초)
            text_color: 텍스트 색상
            speaker: 화자 이름
        """
        if self.skip_all:
            return

        fps = 60
        text_box_height = 180

        # 이미지 로드
        try:
            original_image = pygame.image.load(resource_path(image_path)).convert()
            orig_w, orig_h = original_image.get_size()
        except Exception as e:
            print(f"[IntroCutscene] 이미지 로드 실패: {e}")
            return

        # 텍스트 박스 위치
        text_box_y = self.height - text_box_height - 30
        available_height = self.height - text_box_height - 50
        display_w = self.width
        display_h = available_height

        # 원본 이미지를 화면에 맞게 스케일 (show_story_scene과 동일한 방식)
        scale_w = display_w / orig_w
        scale_h = available_height / orig_h
        base_scale = min(scale_w, scale_h)

        # 화면을 채우도록 조정
        if int(orig_w * base_scale) < display_w:
            base_scale = display_w / orig_w

        base_w = int(orig_w * base_scale)
        base_h = int(orig_h * base_scale)
        base_image = pygame.transform.smoothscale(original_image, (base_w, base_h))
        base_x = (display_w - base_w) // 2
        base_y = (available_height - base_h) // 2

        # 줌 레벨에 따른 이미지 생성 함수 (줌인 시 타겟으로 이동)
        def get_zoomed_image(zoom_progress):
            # zoom_progress: 0.0 = 원본, 1.0 = 최대 줌인
            current_scale = base_scale * (1 + (zoom_end / zoom_start - 1) * zoom_progress)

            zoomed_w = int(orig_w * current_scale)
            zoomed_h = int(orig_h * current_scale)
            zoomed_image = pygame.transform.smoothscale(original_image, (zoomed_w, zoomed_h))

            # 줌 진행에 따라 타겟으로 이동
            # 시작: 중앙, 끝: 타겟 위치
            center_x = zoomed_w // 2
            center_y = zoomed_h // 2
            target_x = int(zoom_target[0] * zoomed_w)
            target_y = int(zoom_target[1] * zoomed_h)

            # 현재 포커스 위치 (중앙에서 타겟으로 보간)
            focus_x = int(center_x + (target_x - center_x) * zoom_progress)
            focus_y = int(center_y + (target_y - center_y) * zoom_progress)

            # 포커스가 화면 중앙에 오도록 오프셋 계산
            offset_x = focus_x - display_w // 2
            offset_y = focus_y - display_h // 2
            offset_x = max(0, min(offset_x, zoomed_w - display_w))
            offset_y = max(0, min(offset_y, zoomed_h - display_h))

            crop_rect = pygame.Rect(offset_x, offset_y, min(display_w, zoomed_w), min(display_h, zoomed_h))
            cropped = zoomed_image.subsurface(crop_rect).copy()

            if cropped.get_width() < display_w or cropped.get_height() < display_h:
                cropped = pygame.transform.smoothscale(cropped, (display_w, display_h))

            return cropped

        # 페이드인 (원본 이미지로)
        fade_in_frames = int(1.5 * fps)
        skip_fade = False
        for frame in range(fade_in_frames):
            if self.skip_all or skip_fade:
                break
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                    return
                if self._check_skip_all(event):
                    return
                if event.type == pygame.MOUSEBUTTONDOWN or (event.type == pygame.KEYDOWN and event.key in (pygame.K_SPACE, pygame.K_RETURN)):
                    skip_fade = True
                    break

            alpha = int(255 * (frame / fade_in_frames))
            self.screen.fill((0, 0, 0))

            # 원본 이미지로 페이드인 (줌 없음)
            temp_surface = base_image.copy()
            temp_surface.set_alpha(alpha)
            self.screen.blit(temp_surface, (base_x, base_y))

            self._draw_skip_hint()
            pygame.display.flip()
            self.clock.tick(fps)

        # 대사 리스트 처리
        if isinstance(dialogues, str):
            dialogue_list = [dialogues]
        else:
            dialogue_list = dialogues

        # 줌 관련 변수 (백그라운드에서 계속 진행)
        zoom_total_frames = int(zoom_duration * fps)
        zoom_frame = 0

        # 텍스트 영역 설정
        box_margin = 30
        box_x = box_margin
        box_width = self.width - box_margin * 2
        box_height = text_box_height - 20
        text_padding = 25

        # 각 대사를 순차적으로 표시 (줌인은 백그라운드에서 계속 진행)
        for dialogue in dialogue_list:
            if self.skip_all or not dialogue:
                continue

            typing_speed = 0.05
            char_timer = 0
            char_index = 0
            displayed_text = ""
            typing_done = False

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
                                break  # 다음 대사로
                            else:
                                # 타이핑 스킵
                                displayed_text = dialogue
                                char_index = len(dialogue)
                                typing_done = True
                    if event.type == pygame.MOUSEBUTTONDOWN:
                        if typing_done:
                            break  # 다음 대사로
                        else:
                            displayed_text = dialogue
                            char_index = len(dialogue)
                            typing_done = True
                else:
                    # 타이핑 애니메이션
                    if char_index < len(dialogue):
                        char_timer += 1 / fps
                        while char_timer >= typing_speed and char_index < len(dialogue):
                            char_timer -= typing_speed
                            displayed_text += dialogue[char_index]
                            char_index += 1
                    else:
                        if not typing_done:
                            typing_done = True

                    # 줌 진행 (백그라운드에서 계속)
                    if zoom_frame < zoom_total_frames:
                        zoom_frame += 1
                    zoom_progress = min(zoom_frame / zoom_total_frames, 1.0)

                    # 그리기
                    self.screen.fill((0, 0, 0))

                    # 줌인된 이미지
                    zoomed_img = get_zoomed_image(zoom_progress)
                    img_x = (self.width - zoomed_img.get_width()) // 2
                    img_y = (available_height - zoomed_img.get_height()) // 2
                    self.screen.blit(zoomed_img, (img_x, img_y))

                    # 바로크풍 텍스트 박스 그리기
                    self._draw_baroque_frame(self.screen, box_x, text_box_y, box_width, box_height)

                    # 텍스트 렌더링 (줄바꿈 지원)
                    if displayed_text:
                        text_x = box_x + text_padding
                        lines = displayed_text.split('\n')
                        line_height = 32
                        total_text_height = len(lines) * line_height
                        start_y = text_box_y + (box_height - total_text_height) // 2

                        last_rect = None
                        for i, line in enumerate(lines):
                            if line:
                                text_surface, text_rect = self.font_medium.render(line, text_color)
                                text_y = start_y + i * line_height
                                self.screen.blit(text_surface, (text_x, text_y))
                                last_rect = text_rect
                                last_y = text_y

                        # 타이핑 중 커서 표시
                        if not typing_done and int(pygame.time.get_ticks() / 500) % 2 == 0 and last_rect:
                            cursor_x = text_x + last_rect.width + 3
                            pygame.draw.rect(self.screen, text_color, (cursor_x, last_y, 2, 24))

                    # 계속하려면... 안내
                    if typing_done:
                        hint_alpha = int(128 + 127 * math.sin(pygame.time.get_ticks() / 300))
                        hint_surface, hint_rect = self.font_small.render("▼", text_color)
                        hint_surface.set_alpha(hint_alpha)
                        hint_x = box_x + box_width - 40
                        hint_y = text_box_y + box_height - 35
                        self.screen.blit(hint_surface, (hint_x, hint_y))

                    self._draw_skip_hint()
                    pygame.display.flip()
                    self.clock.tick(fps)
                    continue

                # break로 나왔으면 다음 대사로
                break

    def show_final_black_scene(self, text, text_color=(255, 80, 80)):
        """마지막 검은 배경 씬 - 텍스트 페이드인 후 클릭 대기, 페이드아웃

        Args:
            text: 표시할 텍스트
            text_color: 텍스트 색상 (기본: 빨간색)
        """
        if self.skip_all:
            return

        fps = 60

        # 텍스트 위치 계산
        text_surface, text_rect = self.font_large.render(text, text_color)
        text_x = (self.width - text_rect.width) // 2
        text_y = (self.height - text_rect.height) // 2

        # 텍스트 페이드인 (1.5초)
        fade_in_frames = int(1.5 * fps)
        skip_to_next = False
        for frame in range(fade_in_frames):
            if self.skip_all or skip_to_next:
                break
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                    return
                if self._check_skip_all(event):
                    return
                if event.type == pygame.MOUSEBUTTONDOWN or (event.type == pygame.KEYDOWN and event.key in (pygame.K_SPACE, pygame.K_RETURN)):
                    skip_to_next = True
                    break

            alpha = int(255 * (frame / fade_in_frames))
            self.screen.fill((0, 0, 0))

            text_surface, text_rect = self.font_large.render(text, text_color)
            text_surface.set_alpha(alpha)
            self.screen.blit(text_surface, (text_x, text_y))

            self._draw_skip_hint()
            pygame.display.flip()
            self.clock.tick(fps)

        # 클릭 대기 (텍스트 표시 상태)
        waiting = True
        while waiting:
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
                    if event.key in (pygame.K_SPACE, pygame.K_RETURN):
                        waiting = False
                        break
                if event.type == pygame.MOUSEBUTTONDOWN:
                    waiting = False
                    break

            self.screen.fill((0, 0, 0))
            text_surface, text_rect = self.font_large.render(text, text_color)
            self.screen.blit(text_surface, (text_x, text_y))

            self._draw_skip_hint()
            pygame.display.flip()
            self.clock.tick(fps)

        # 텍스트 페이드아웃 (1.5초)
        fade_out_frames = int(1.5 * fps)
        for frame in range(fade_out_frames):
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

            alpha = int(255 * (1 - frame / fade_out_frames))
            self.screen.fill((0, 0, 0))

            text_surface, text_rect = self.font_large.render(text, text_color)
            text_surface.set_alpha(alpha)
            self.screen.blit(text_surface, (text_x, text_y))

            self._draw_skip_hint()
            pygame.display.flip()
            self.clock.tick(fps)

        # 완전히 검은 화면으로 마무리 (0.5초)
        for frame in range(int(0.5 * fps)):
            if self.skip_all:
                return
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
            self.screen.fill((0, 0, 0))
            pygame.display.flip()
            self.clock.tick(fps)

    def show_zoom_in_out_scene(self, image_path, dialogues, zoom_target=(0.75, 0.4), zoom_in_duration=1.0, hold_duration=2.5, zoom_out_duration=1.0, zoom_end=1.4, text_color=(255, 255, 255), speaker=None, skip_fade_in=False):
        """줌인 후 줌아웃 효과가 있는 스토리 씬 (얼굴 클로즈업용)

        Args:
            image_path: 배경 이미지 경로
            dialogues: 대사 리스트
            zoom_target: 줌인 목표 지점 (0~1 비율, x, y)
            zoom_in_duration: 줌인 시간 (초)
            hold_duration: 줌인 유지 시간 (초)
            zoom_out_duration: 줌아웃 시간 (초)
            zoom_end: 최대 줌 배율
            text_color: 텍스트 색상
            speaker: 화자 이름
            skip_fade_in: 페이드인 생략 여부
        """
        if self.skip_all:
            return

        fps = 60
        text_box_height = 180

        # 이미지 로드
        try:
            original_image = pygame.image.load(resource_path(image_path)).convert()
            orig_w, orig_h = original_image.get_size()
        except Exception as e:
            print(f"[IntroCutscene] 이미지 로드 실패: {e}")
            return

        # 텍스트 박스 위치
        text_box_y = self.height - text_box_height - 30
        available_height = self.height - text_box_height - 50
        display_w = self.width
        display_h = available_height

        # 원본 이미지를 화면에 맞게 스케일
        scale_w = display_w / orig_w
        scale_h = available_height / orig_h
        base_scale = min(scale_w, scale_h)
        if int(orig_w * base_scale) < display_w:
            base_scale = display_w / orig_w

        base_w = int(orig_w * base_scale)
        base_h = int(orig_h * base_scale)
        base_image = pygame.transform.smoothscale(original_image, (base_w, base_h))
        base_x = (display_w - base_w) // 2
        base_y = (available_height - base_h) // 2

        # 줌 레벨에 따른 이미지 생성 함수
        def get_zoomed_image(zoom_progress):
            current_scale = base_scale * (1 + (zoom_end - 1) * zoom_progress)
            zoomed_w = int(orig_w * current_scale)
            zoomed_h = int(orig_h * current_scale)
            zoomed_image = pygame.transform.smoothscale(original_image, (zoomed_w, zoomed_h))

            center_x = zoomed_w // 2
            center_y = zoomed_h // 2
            target_x = int(zoom_target[0] * zoomed_w)
            target_y = int(zoom_target[1] * zoomed_h)

            focus_x = int(center_x + (target_x - center_x) * zoom_progress)
            focus_y = int(center_y + (target_y - center_y) * zoom_progress)

            offset_x = focus_x - display_w // 2
            offset_y = focus_y - display_h // 2
            offset_x = max(0, min(offset_x, zoomed_w - display_w))
            offset_y = max(0, min(offset_y, zoomed_h - display_h))

            crop_rect = pygame.Rect(offset_x, offset_y, min(display_w, zoomed_w), min(display_h, zoomed_h))
            cropped = zoomed_image.subsurface(crop_rect).copy()

            if cropped.get_width() < display_w or cropped.get_height() < display_h:
                cropped = pygame.transform.smoothscale(cropped, (display_w, display_h))

            return cropped

        # 페이드인 (원본 이미지로) - skip_fade_in이 True면 건너뜀
        if not skip_fade_in:
            fade_in_frames = int(1.0 * fps)
            skip_fade = False
            for frame in range(fade_in_frames):
                if self.skip_all or skip_fade:
                    break
                for event in pygame.event.get():
                    if event.type == pygame.QUIT:
                        pygame.quit()
                        sys.exit()
                    if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                        return
                    if self._check_skip_all(event):
                        return
                    if event.type == pygame.MOUSEBUTTONDOWN or (event.type == pygame.KEYDOWN and event.key in (pygame.K_SPACE, pygame.K_RETURN)):
                        skip_fade = True
                        break

                alpha = int(255 * (frame / fade_in_frames))
                self.screen.fill((0, 0, 0))
                temp_surface = base_image.copy()
                temp_surface.set_alpha(alpha)
                self.screen.blit(temp_surface, (base_x, base_y))
                self._draw_skip_hint()
                pygame.display.flip()
                self.clock.tick(fps)

        # 대사 리스트 처리
        if isinstance(dialogues, str):
            dialogue_list = [dialogues]
        else:
            dialogue_list = dialogues

        # 줌 타이밍 계산
        zoom_in_frames = int(zoom_in_duration * fps)
        hold_frames = int(hold_duration * fps)
        zoom_out_frames = int(zoom_out_duration * fps)
        total_zoom_frames = zoom_in_frames + hold_frames + zoom_out_frames
        zoom_frame = 0

        # 텍스트 영역 설정
        box_margin = 30
        box_x = box_margin
        box_width = self.width - box_margin * 2
        box_height = text_box_height - 20
        text_padding = 25

        # 각 대사를 순차적으로 표시
        for dialogue in dialogue_list:
            if self.skip_all or not dialogue:
                continue

            typing_speed = 0.05
            char_timer = 0
            char_index = 0
            displayed_text = ""
            typing_done = False

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
                                break
                            else:
                                displayed_text = dialogue
                                char_index = len(dialogue)
                                typing_done = True
                    if event.type == pygame.MOUSEBUTTONDOWN:
                        if typing_done:
                            break
                        else:
                            displayed_text = dialogue
                            char_index = len(dialogue)
                            typing_done = True
                else:
                    # 타이핑 애니메이션
                    if char_index < len(dialogue):
                        char_timer += 1 / fps
                        while char_timer >= typing_speed and char_index < len(dialogue):
                            char_timer -= typing_speed
                            displayed_text += dialogue[char_index]
                            char_index += 1
                    else:
                        if not typing_done:
                            typing_done = True

                    # 줌 진행 (줌인 → 유지 → 줌아웃)
                    if zoom_frame < total_zoom_frames:
                        zoom_frame += 1

                    if zoom_frame <= zoom_in_frames:
                        # 줌인 단계
                        zoom_progress = zoom_frame / zoom_in_frames
                    elif zoom_frame <= zoom_in_frames + hold_frames:
                        # 유지 단계
                        zoom_progress = 1.0
                    else:
                        # 줌아웃 단계
                        out_frame = zoom_frame - zoom_in_frames - hold_frames
                        zoom_progress = 1.0 - (out_frame / zoom_out_frames)

                    zoom_progress = max(0.0, min(1.0, zoom_progress))

                    # 그리기
                    self.screen.fill((0, 0, 0))
                    zoomed_img = get_zoomed_image(zoom_progress)
                    img_x = (self.width - zoomed_img.get_width()) // 2
                    img_y = (available_height - zoomed_img.get_height()) // 2
                    self.screen.blit(zoomed_img, (img_x, img_y))

                    # 바로크풍 텍스트 박스 그리기
                    self._draw_baroque_frame(self.screen, box_x, text_box_y, box_width, box_height)

                    # 텍스트 렌더링
                    if displayed_text:
                        text_surface, text_rect = self.font_medium.render(displayed_text, text_color)
                        text_x = box_x + text_padding
                        text_y = text_box_y + (box_height - 32) // 2
                        self.screen.blit(text_surface, (text_x, text_y))

                        if not typing_done and int(pygame.time.get_ticks() / 500) % 2 == 0:
                            cursor_x = text_x + text_rect.width + 3
                            pygame.draw.rect(self.screen, text_color, (cursor_x, text_y, 2, 24))

                    if typing_done:
                        hint_alpha = int(128 + 127 * math.sin(pygame.time.get_ticks() / 300))
                        hint_surface, hint_rect = self.font_small.render("▼", text_color)
                        hint_surface.set_alpha(hint_alpha)
                        hint_x = box_x + box_width - 40
                        hint_y = text_box_y + box_height - 35
                        self.screen.blit(hint_surface, (hint_x, hint_y))

                    self._draw_skip_hint()
                    pygame.display.flip()
                    self.clock.tick(fps)
                    continue

                break

    def show_overlay_fade_scene(self, base_image_path, overlay_image_path, dialogues, fade_duration=2.0, text_color=(255, 255, 255), speaker=None, skip_fade_in=False):
        """베이스 이미지 위에 오버레이 이미지가 점점 페이드인되는 씬

        Args:
            base_image_path: 베이스 배경 이미지 경로
            overlay_image_path: 위에 겹쳐질 오버레이 이미지 경로 (투명 배경)
            dialogues: 대사 리스트
            fade_duration: 오버레이 페이드인 시간 (초)
            text_color: 텍스트 색상
            speaker: 화자 이름
            skip_fade_in: 초기 페이드인 생략 여부
        """
        if self.skip_all:
            return

        fps = 60
        text_box_height = 180

        # 베이스 이미지 로드
        try:
            base_original = pygame.image.load(resource_path(base_image_path)).convert()
            base_orig_w, base_orig_h = base_original.get_size()
        except Exception as e:
            print(f"[IntroCutscene] 베이스 이미지 로드 실패: {e}")
            return

        # 오버레이 이미지 로드 (알파 채널 포함)
        try:
            overlay_original = pygame.image.load(resource_path(overlay_image_path)).convert_alpha()
            overlay_orig_w, overlay_orig_h = overlay_original.get_size()

            # 흰색 배경 투명하게 처리 (경계는 자연스러운 그라데이션)
            for x in range(overlay_orig_w):
                for y in range(overlay_orig_h):
                    r, g, b, a = overlay_original.get_at((x, y))
                    brightness = (r + g + b) // 3

                    # 흰색/밝은색 (200 이상) - 완전 투명
                    if brightness > 200:
                        overlay_original.set_at((x, y), (r, g, b, 0))
                    # 밝은 경계 (170~200) - 부드러운 그라데이션
                    elif brightness > 170:
                        new_alpha = int(255 * (200 - brightness) / 30)
                        overlay_original.set_at((x, y), (r, g, b, new_alpha))
                    # 나머지는 원본 유지 (완전 불투명)
        except Exception as e:
            print(f"[IntroCutscene] 오버레이 이미지 로드 실패: {e}")
            return

        # 텍스트 박스 위치
        text_box_y = self.height - text_box_height - 30
        available_height = self.height - text_box_height - 50
        display_w = self.width
        display_h = available_height

        # 베이스 이미지 스케일
        scale_w = display_w / base_orig_w
        scale_h = available_height / base_orig_h
        base_scale = min(scale_w, scale_h)
        if int(base_orig_w * base_scale) < display_w:
            base_scale = display_w / base_orig_w

        base_w = int(base_orig_w * base_scale)
        base_h = int(base_orig_h * base_scale)
        base_image = pygame.transform.smoothscale(base_original, (base_w, base_h))
        base_x = (display_w - base_w) // 2
        base_y = (available_height - base_h) // 2

        # 오버레이 이미지 스케일 (베이스보다 10% 크게)
        overlay_scale = base_scale * 1.1  # 10% 더 크게
        overlay_w = int(overlay_orig_w * overlay_scale)
        overlay_h = int(overlay_orig_h * overlay_scale)
        overlay_image = pygame.transform.smoothscale(overlay_original, (overlay_w, overlay_h))
        overlay_x = (display_w - overlay_w) // 2
        overlay_y = (available_height - overlay_h) // 2

        # 초기 페이드인 (베이스 이미지만)
        if not skip_fade_in:
            fade_in_frames = int(1.0 * fps)
            skip_fade = False
            for frame in range(fade_in_frames):
                if self.skip_all or skip_fade:
                    break
                for event in pygame.event.get():
                    if event.type == pygame.QUIT:
                        pygame.quit()
                        sys.exit()
                    if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                        return
                    if self._check_skip_all(event):
                        return
                    if event.type == pygame.MOUSEBUTTONDOWN or (event.type == pygame.KEYDOWN and event.key in (pygame.K_SPACE, pygame.K_RETURN)):
                        skip_fade = True
                        break

                alpha = int(255 * (frame / fade_in_frames))
                self.screen.fill((0, 0, 0))
                temp_surface = base_image.copy()
                temp_surface.set_alpha(alpha)
                self.screen.blit(temp_surface, (base_x, base_y))
                self._draw_skip_hint()
                pygame.display.flip()
                self.clock.tick(fps)

        # 대사 리스트 처리
        if isinstance(dialogues, str):
            dialogue_list = [dialogues]
        else:
            dialogue_list = dialogues

        # 오버레이 페이드 타이밍
        overlay_fade_frames = int(fade_duration * fps)
        overlay_frame = 0

        # 텍스트 영역 설정
        box_margin = 30
        box_x = box_margin
        box_width = self.width - box_margin * 2
        box_height = text_box_height - 20
        text_padding = 25

        # 각 대사를 순차적으로 표시
        for dialogue in dialogue_list:
            if self.skip_all or not dialogue:
                break

            # 텍스트 타이핑 상태
            visible_chars = 0
            typing_speed = 2
            typing_done = False
            frame_count = 0

            while True:
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
                    if event.type == pygame.MOUSEBUTTONDOWN or (event.type == pygame.KEYDOWN and event.key in (pygame.K_SPACE, pygame.K_RETURN)):
                        if typing_done:
                            break
                        else:
                            visible_chars = len(dialogue)
                            typing_done = True

                # 오버레이 알파 계산 (점점 페이드인)
                if overlay_frame < overlay_fade_frames:
                    overlay_alpha = int(255 * (overlay_frame / overlay_fade_frames))
                    overlay_frame += 1
                else:
                    overlay_alpha = 255

                # 화면 그리기
                self.screen.fill((0, 0, 0))

                # 베이스 이미지
                self.screen.blit(base_image, (base_x, base_y))

                # 오버레이 이미지 (알파 적용)
                overlay_with_alpha = overlay_image.copy()
                overlay_with_alpha.set_alpha(overlay_alpha)
                self.screen.blit(overlay_with_alpha, (overlay_x, overlay_y))

                # 타이핑 업데이트
                frame_count += 1
                if frame_count % typing_speed == 0 and not typing_done:
                    visible_chars += 1
                    if visible_chars >= len(dialogue):
                        visible_chars = len(dialogue)
                        typing_done = True

                # 텍스트 박스 그리기
                self._draw_baroque_frame(self.screen, box_x, text_box_y, box_width, box_height)

                # 텍스트 렌더링
                visible_text = dialogue[:visible_chars]
                lines = visible_text.split('\n')
                text_y = text_box_y + text_padding

                for line in lines:
                    if line:
                        text_surface, text_rect = self.font.render(line, text_color)
                        text_x = box_x + (box_width - text_rect.width) // 2
                        self.screen.blit(text_surface, (text_x, text_y))
                        text_y += text_rect.height + 8
                    else:
                        text_y += 24

                # 커서 깜빡임
                if not typing_done and frame_count % 30 < 15:
                    if lines and lines[-1]:
                        last_line = lines[-1]
                        cursor_surface, cursor_rect = self.font.render(last_line, text_color)
                        cursor_x = box_x + (box_width - cursor_rect.width) // 2 + cursor_rect.width
                        pygame.draw.rect(self.screen, text_color, (cursor_x, text_y - text_rect.height - 8, 2, 24))

                # 다음 힌트
                if typing_done:
                    hint_alpha = int(128 + 127 * math.sin(pygame.time.get_ticks() / 300))
                    hint_surface, hint_rect = self.font_small.render("▼", text_color)
                    hint_surface.set_alpha(hint_alpha)
                    hint_x = box_x + box_width - 40
                    hint_y = text_box_y + box_height - 35
                    self.screen.blit(hint_surface, (hint_x, hint_y))

                self._draw_skip_hint()
                pygame.display.flip()
                self.clock.tick(fps)

                # 대사 완료 후 클릭 대기
                if typing_done:
                    for event in pygame.event.get():
                        if event.type == pygame.QUIT:
                            pygame.quit()
                            sys.exit()
                        if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                            return
                        if self._check_skip_all(event):
                            return
                        if event.type == pygame.MOUSEBUTTONDOWN or (event.type == pygame.KEYDOWN and event.key in (pygame.K_SPACE, pygame.K_RETURN)):
                            break
                    else:
                        continue
                    break

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

        # 텍스트 박스 위치 (하단에 정렬)
        text_box_y = self.height - text_box_height - 30

        # 페이드인 (어두운 이미지로)
        fade_in_frames = int(1.0 * fps)
        skip_fade = False
        for frame in range(fade_in_frames):
            if self.skip_all or skip_fade:
                break
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                    return
                if self._check_skip_all(event):
                    return
                # 마우스 클릭 또는 스페이스/엔터로 페이드인 스킵
                if event.type == pygame.MOUSEBUTTONDOWN or (event.type == pygame.KEYDOWN and event.key in (pygame.K_SPACE, pygame.K_RETURN)):
                    skip_fade = True
                    break

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

        skip_fade = False
        for frame in range(frames):
            if self.skip_all or skip_fade:
                break
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if self._check_skip_all(event):
                    break
                # 마우스 클릭 또는 스페이스/엔터로 페이드 스킵
                if event.type == pygame.MOUSEBUTTONDOWN or (event.type == pygame.KEYDOWN and event.key in (pygame.K_SPACE, pygame.K_RETURN)):
                    skip_fade = True
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
        # 인트로 시작 BGM 재생 (introstart.mp3 - 검은화면 2장 동안 재생)
        try:
            introstart_path = resource_path(os.path.join("bgm", "intro", "introstart.mp3"))
            if os.path.exists(introstart_path):
                pygame.mixer.music.load(introstart_path)
                pygame.mixer.music.set_volume(0.5)
                pygame.mixer.music.play()
        except Exception as e:
            print(f"[IntroCutscene] introstart.mp3 로드 실패: {e}")

        # 1. 두 명언을 한 화면에 표시 ("사는 것은 선택하는 것이다")
        self.show_combined_quotes_screen()

        # 2. 추가 명언 표시 ("선택이라는 자유를 누린다")
        self.show_additional_quotes_screen()

        # introstart BGM 페이드아웃
        try:
            pygame.mixer.music.fadeout(1000)  # 1초 페이드아웃
        except Exception:
            pass

        # 3. 검은 화면 대기 (드라마틱 연출용 - 사운드 삽입 가능)
        self.show_black_screen(duration=2.0)

        # 4. 스토리 컷씬들
        # 클럽 BGM 재생 시작 (introclub.mp3 - 클럽 장면 동안 재생)
        try:
            introclub_path = resource_path(os.path.join("bgm", "intro", "introclub.mp3"))
            if os.path.exists(introclub_path):
                pygame.mixer.music.load(introclub_path)
                pygame.mixer.music.set_volume(0.5)
                pygame.mixer.music.play(-1)  # 루프 재생
        except Exception as e:
            print(f"[IntroCutscene] introclub.mp3 로드 실패: {e}")

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

        # 컷씬 3: 유이안 작별 인사 (손 흔드는 장면)
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20260103_180952143.png",
            dialogues="맞다. 아버지가 불렀던 게 이제야 생각났어.",
            text_delay=0.5,
            text_color=(255, 255, 255),
            speaker="유이안"
        )
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20260103_180952143.png",
            dialogues=["아쉽지만 오늘은 이쯤하고.. 다음에 또 만나자, 이쁜이들~"],
            text_delay=0.5,
            text_color=(255, 255, 255),
            speaker="유이안",
            skip_fade_in=True
        )
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20260103_180952143.png",
            dialogues=["계산은 외상으로 달고, 나중에 사람 보낼게."],
            text_delay=0.5,
            text_color=(255, 255, 255),
            speaker="유이안",
            skip_fade_in=True
        )

        # 컷씬 3 연속: 독백 (술집 나서며)
        self.show_dark_monologue_scene(
            image_path="introstory/KakaoTalk_20260103_180952143.png",
            dialogues=[
                "그렇게 가볍게 손을 흔들며 술집을 나서니, 도로변에 검은 리무진이 세워져 있었다.",
                "운전 기사가 내려, 내게 차 문을 열어줘서 몸을 숙이며 푹신한 좌석에 앉았다."
            ],
            text_color=(128, 128, 128)  # 회색 (독백)
        )

        # 클럽 BGM 페이드아웃
        try:
            pygame.mixer.music.fadeout(1500)  # 1.5초 페이드아웃
        except Exception:
            pass

        # 차 BGM 재생 시작 (introcar.mp3 - 리무진 장면부터 마지막까지)
        try:
            introcar_path = resource_path(os.path.join("bgm", "intro", "introcar.mp3"))
            if os.path.exists(introcar_path):
                pygame.mixer.music.load(introcar_path)
                pygame.mixer.music.set_volume(0.5)
                pygame.mixer.music.play(-1)  # 루프 재생
        except Exception as e:
            print(f"[IntroCutscene] introcar.mp3 로드 실패: {e}")

        # 컷씬 4: 리무진 안 독백 (파트 1 - _01.png, 선명한 이미지)
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20260103_180952143_01.png",
            dialogues=[
                "고급스럽지 않는 것들이 없었다.",
                "상류층만 오가는 값비싼 클럽, 입고 있는 옷, 부르지 않아도 알아서 태우는 전용 차, 나고 자란 사립학교….",
                "이 모든 것들이 대한민국 국민들의 피와 눈물로 이루어진, 국회의원 아들의 호화로운 삶이었다."
            ],
            text_color=(128, 128, 128)  # 회색 (독백)
        )

        # 컷씬 4: 리무진 안 독백 (파트 2 - _02.png, 실루엣 등장)
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20260103_180952143_02.png",
            dialogues=[
                "…그래. 선택. 이 얼마나 자비롭고도 잔혹한 단어란 말인가.",
                "이기심의 기반이 되고, 정의감의 희생 찬가가 되는,",
                "모든 것들의 원인이자 과정이며 결과이자… 책임인 그것."
            ],
            text_color=(128, 128, 128),  # 회색 (독백)
            skip_fade_in=True
        )

        # 컷씬 4: 리무진 안 독백 (파트 3 - 살짝 웃는 얼굴, 줌인/줌아웃)
        self.show_zoom_in_out_scene(
            image_path="introstory/KakaoTalk_20260104_224853913.png",
            dialogues=[
                "나는 이상향의 전부를 대부분 누리지만,",
                "나 개인은 정말 이대로 좋은지는 잘 모르겠다."
            ],
            zoom_target=(0.75, 0.4),  # 우측 이안 얼굴
            zoom_in_duration=1.0,  # 1초 줌인
            hold_duration=2.5,  # 2.5초 유지
            zoom_out_duration=1.0,  # 1초 줌아웃
            zoom_end=1.4,
            text_color=(128, 128, 128),  # 회색 (독백)
            skip_fade_in=True  # 리무진 씬 내에서 즉각적 전환
        )

        # 컷씬 4: 리무진 안 독백 (파트 4 - _04.png)
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20260103_180952143_04.png",
            dialogues=[
                "밖을 잠깐 걸어도, 창가 밖으로 보아도 사람들의 얼굴에 나와 같은 미소를 찾기는 불가능에 가까웠다.",
                "그들 대부분의 웃음은, 순수하지 못했다."
            ],
            text_color=(128, 128, 128),  # 회색 (독백)
            skip_fade_in=True
        )

        # 컷씬 4: 리무진 안 독백 (파트 4-2 - _03.png)
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20260103_180952143_03.png",
            dialogues=[
                "나 또한 그럴 지도 모른다."
            ],
            text_color=(128, 128, 128),  # 회색 (독백)
            skip_fade_in=True
        )

        # 컷씬 4: 리무진 안 독백 (파트 5 - _05.png, 어두운 얼굴)
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20260103_180952143_05.png",
            dialogues=["그저 눈치채지 못했을 뿐."],
            text_color=(128, 128, 128),  # 회색 (독백)
            skip_fade_in=True
        )

        # 컷씬 4: 리무진 안 독백 (파트 6 - _06.png, 상자로 줌인)
        self.show_zoom_in_scene(
            image_path="introstory/KakaoTalk_20260103_180952143_06.png",
            dialogues=[
                "그래서 줄곧 관심 없던,",
                "전세계적으로 유행하는 가상현실 기술에 대해\n아버지가 내게 권하셨을 때…"
            ],
            zoom_target=(0.42, 0.32),  # VR 상자 가운데
            zoom_start=1.0,
            zoom_end=1.6,
            zoom_duration=2.0,  # 2초 동안 줌인
            text_color=(128, 128, 128)  # 회색 (독백)
        )

        # 컷씬 4: 리무진 안 독백 (파트 7 - _07.png, 선택)
        self.show_story_scene(
            image_path="introstory/KakaoTalk_20260103_180952143_07.png",
            dialogues=[
                "나는 또 다른 세계를 알아 가는 것을 [선택]한 것이었다.",
                "앞으로 이 [선택]이 내 삶을 어떠한 [선택]들로 가득 채울지……"
            ],
            text_color=(128, 128, 128),  # 회색 (독백)
            skip_fade_in=False  # 페이드인 처리
        )

        # 마지막 씬: 검은 배경 + 빨간 글씨 + 흩어지는 애니메이션
        self.show_final_black_scene(
            text="아무것도 모르는 채로..",
            text_color=(255, 80, 80)  # 빨간색
        )

        # 차 BGM 정지 (비동기 페이드아웃 — show_opening_animation이 music.stop() 호출)
        try:
            pygame.mixer.music.fadeout(800)
        except Exception:
            try:
                pygame.mixer.music.stop()
            except Exception:
                pass


def show_intro_cutscene(screen, width, height):
    """인트로 컷씬 표시 함수 (외부에서 호출용)"""
    cutscene = IntroCutscene(screen, width, height)
    cutscene.run_intro_sequence()


# ============================================================
# 기존 코드 시작
# ============================================================


# ------------------------------------------------------------
# 이징 유틸리티 (Easing Utilities)
# ------------------------------------------------------------
def _ease_out_cubic(t: float) -> float:
    """t ∈ [0,1] → ease-out cubic (빠르게 시작, 부드럽게 감속)"""
    return 1.0 - (1.0 - t) ** 3

def _ease_in_out_sine(t: float) -> float:
    """t ∈ [0,1] → ease-in-out sine (양쪽 끝에서 부드럽게)"""
    return -(math.cos(math.pi * t) - 1.0) / 2.0

def _ease_out_expo(t: float) -> float:
    """t ∈ [0,1] → ease-out expo (급출발, 완만한 착지)"""
    return 1.0 if t >= 1.0 else 1.0 - 2.0 ** (-10.0 * t)


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
    """게임 오프닝 애니메이션 — 상태 기계(State Machine) 구조, 이징 보간, 렌더 버퍼 최적화"""

    # ── BGM ──
    try:
        pygame.mixer.music.stop()
    except Exception:
        pass
    bgm_manager.play_intro_bgm()

    # ── 배경 이미지 로드 (Ken Burns 여유분 15%) ──
    background_image = None
    try:
        bg_path = resource_path("main.jpg")
        if os.path.exists(bg_path):
            background_image = pygame.image.load(bg_path).convert()
            orig_w, orig_h = background_image.get_size()
            aspect = orig_h / orig_w
            KB_EXTRA = 1.15
            new_w = int(WIDTH * KB_EXTRA)
            new_h = int(new_w * aspect)
            if new_h < int(HEIGHT * KB_EXTRA):
                new_h = int(HEIGHT * KB_EXTRA)
                new_w = int(new_h / aspect)
            background_image = pygame.transform.smoothscale(background_image, (new_w, new_h))
    except Exception:
        background_image = None

    # ── 폰트 (루프 밖 1회 로드) ──
    try:
        font_large = pygame.font.Font(resource_path("NanumSquareB.ttf"), 72)
    except Exception:
        font_large = pygame.font.Font(None, 72)
    try:
        font_medium = pygame.font.Font(resource_path("NanumSquareR.ttf"), 32)
    except Exception:
        font_medium = pygame.font.Font(None, 32)
    try:
        font_small = pygame.font.Font(resource_path("NanumSquareR.ttf"), 24)
    except Exception:
        font_small = pygame.font.Font(None, 24)

    from localization.manager import get_localization_manager
    _loc = get_localization_manager()
    full_text = _loc.get_text("opening.title", "핑파이터")
    subtitle_str = _loc.get_text("opening.subtitle", "핑퐁으로 보스를 물리쳐라!")
    press_key_str = _loc.get_text("opening.press_any_key", "아무 키나 누르세요")

    # ── 상태 기계 (State Machine) ──
    ST_INTRO_WAIT = 0      # 로고 등장 + Press any key 대기
    ST_IMPACT_ACTION = 1   # 키/클릭 후 탁구공 임팩트 + 전투 이펙트
    ST_FADE_OUT = 2        # 페이드 아웃 → return
    current_state = ST_INTRO_WAIT

    # ── 렌더 버퍼 (SCREEN.copy() 제거 최적화) ──
    buf = pygame.Surface((WIDTH, HEIGHT))
    # 재사용 오버레이 서피스 (매 프레임 할당 방지)
    _overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)

    # ── 타이머 / 보간 변수 ──
    animation_timer = 0
    special_animation_timer = 0
    fade_out_timer = 0
    fade_alpha = 0
    screen_shake = 0.0
    flash_alpha = 0

    # 로고 이징 파라미터
    LOGO_SCALE_FRAMES = 108   # ~1.8s
    LOGO_Y_FRAMES = 120       # 2s
    logo_start_y = HEIGHT // 2
    logo_target_y = HEIGHT // 3

    # 텍스트 타이핑
    typing_text = ""
    typing_speed = 0.1
    typing_timer = 0.0

    # ── 파티클 컨테이너 ──
    particles = []
    sparkle_particles = []
    shooting_stars = []
    fuzzy_stars = []
    battle_particles = []
    energy_waves = []
    boss_shadows = []
    paddle_projectiles = []
    pong_impact_balls = []
    pong_impact_sparks = []

    # ── 환경 파티클: 먼지 입자 (Dust Motes) ──
    dust_motes = []
    for _ in range(35):
        dust_motes.append({
            'x': random.uniform(0, WIDTH), 'y': random.uniform(0, HEIGHT),
            'dx': random.uniform(-0.3, 0.3), 'dy': random.uniform(-0.25, -0.04),
            'size': random.uniform(1, 3),
            'alpha': random.randint(25, 70),
            'phase': random.uniform(0, math.pi * 2),
        })

    # ── 환경 파티클: 빛내림 (God Rays) ──
    god_rays = []
    for _ in range(4):
        god_rays.append({
            'x': random.uniform(WIDTH * 0.1, WIDTH * 0.9),
            'width': random.uniform(40, 100),
            'alpha': random.uniform(8, 18),
            'phase': random.uniform(0, math.pi * 2),
        })

    # ── 탁구공 스폰 헬퍼 ──
    def _spawn_pong_balls():
        for _ in range(3):
            pong_impact_balls.append({
                'x': random.randint(WIDTH // 4, WIDTH * 3 // 4),
                'y': float(HEIGHT + 20),
                'target_y': logo_target_y,
                'vy': -random.uniform(18, 28),
                'vx': random.uniform(-3, 3),
                'size': random.randint(10, 18),
                'hit': False, 'trail': [], 'life': 180,
            })

    clock = pygame.time.Clock()

    # ====================================================================
    #                         메인 루프
    # ====================================================================
    while True:
        dt_ms = clock.tick(60)
        animation_timer += 1
        typing_timer += typing_speed

        # ── 1) 이벤트 처리 ──
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                return

            if current_state == ST_INTRO_WAIT and animation_timer > 60:
                triggered = False
                if event.type == pygame.KEYDOWN and event.key != pygame.K_ESCAPE:
                    triggered = True
                elif event.type == pygame.MOUSEBUTTONDOWN:
                    triggered = True
                if triggered:
                    play_intro_click_sound()
                    current_state = ST_IMPACT_ACTION
                    special_animation_timer = 0
                    screen_shake = 30.0
                    _spawn_pong_balls()

        # ── 2) 상태 업데이트 ──
        if current_state == ST_IMPACT_ACTION:
            special_animation_timer += 1
            screen_shake = max(0.0, screen_shake * 0.90)
            # 플래시
            if special_animation_timer % 120 < 10:
                flash_alpha = 100
            else:
                flash_alpha = max(0, flash_alpha - 5)
            # 전투 파티클 생성
            if special_animation_timer % 5 == 0:
                for _ in range(3):
                    battle_particles.append({
                        'x': random.randint(0, WIDTH), 'y': random.randint(0, HEIGHT),
                        'dx': random.uniform(-8, 8), 'dy': random.uniform(-8, 8),
                        'life': 120, 'size': random.randint(3, 8),
                        'color': random.choice([(255,100,100),(100,100,255),(255,255,100),(255,100,255)])
                    })
            if special_animation_timer % 60 == 0:
                energy_waves.append({
                    'x': WIDTH//2, 'y': HEIGHT//2, 'radius': 0,
                    'max_radius': WIDTH, 'speed': 15, 'life': 180, 'alpha': 255
                })
            if special_animation_timer % 180 == 0:
                boss_shadows.append({
                    'x': random.randint(100, WIDTH-100), 'y': random.randint(100, HEIGHT-100),
                    'size': random.randint(50,150), 'life': 300, 'alpha': 255, 'rotation': 0
                })
            if special_animation_timer % 30 == 0:
                paddle_projectiles.append({
                    'x': random.randint(0, WIDTH), 'y': HEIGHT,
                    'dx': random.uniform(-5,5), 'dy': random.uniform(-15,-8),
                    'life': 180, 'size': random.randint(5,15)
                })
            # 1.5초 후 페이드 아웃 상태로 전환
            if special_animation_timer > 90:
                current_state = ST_FADE_OUT
                fade_out_timer = 0

        if current_state == ST_FADE_OUT:
            special_animation_timer += 1
            fade_out_timer += 1
            screen_shake = max(0.0, screen_shake * 0.90)
            flash_alpha = max(0, flash_alpha - 5)
            # 이징 페이드 아웃 (ease-out-cubic)
            fade_t = min(1.0, fade_out_timer / 51.0)
            fade_alpha = int(255 * _ease_out_cubic(fade_t))
            if fade_alpha >= 255:
                return
            # 전투 파티클 계속 생성 (잔여 연출)
            if special_animation_timer % 8 == 0:
                battle_particles.append({
                    'x': random.randint(0, WIDTH), 'y': random.randint(0, HEIGHT),
                    'dx': random.uniform(-6,6), 'dy': random.uniform(-6,6),
                    'life': 80, 'size': random.randint(2,6),
                    'color': random.choice([(255,100,100),(100,100,255),(255,255,100)])
                })

        # ── 배경 파티클 생성 (모든 상태) ──
        if animation_timer % 10 == 0:
            for _ in range(2):
                particles.append({'x': random.randint(0,WIDTH), 'y': random.randint(0,HEIGHT),
                                  'dx': random.uniform(-1,1), 'dy': random.uniform(-1,1), 'life': 60, 'size': 2})
        if animation_timer % 120 == 0:
            shooting_stars.append({
                'x': random.randint(0,WIDTH), 'y': random.randint(0,HEIGHT//3),
                'dx': random.uniform(3,6), 'dy': random.uniform(2,4),
                'life': 120, 'size': random.randint(2,4), 'trail_length': random.randint(20,40)})
        if animation_timer % 180 == 0:
            for _ in range(random.randint(1,3)):
                fuzzy_stars.append({
                    'x': random.randint(0,WIDTH), 'y': random.randint(0,HEIGHT),
                    'life': 300, 'size': random.randint(4,8), 'fade_speed': random.uniform(0.5,1.5), 'alpha': 255})
        if animation_timer % 15 == 0:
            for _ in range(3):
                sparkle_particles.append({'x': random.randint(0,WIDTH), 'y': random.randint(0,HEIGHT), 'life': 60, 'size': 3})

        # ── 이징 적용 로고 스케일 / Y ──
        logo_t_scale = min(1.0, animation_timer / LOGO_SCALE_FRAMES)
        logo_scale = 0.1 + 1.2 * _ease_out_cubic(logo_t_scale)
        logo_t_y = min(1.0, animation_timer / LOGO_Y_FRAMES)
        logo_y = logo_start_y + (logo_target_y - logo_start_y) * _ease_in_out_sine(logo_t_y)

        # ── 먼지 입자 업데이트 ──
        for mote in dust_motes:
            mote['x'] += mote['dx'] + math.sin(animation_timer * 0.01 + mote['phase']) * 0.15
            mote['y'] += mote['dy']
            if mote['y'] < -5:
                mote['y'] = HEIGHT + 5; mote['x'] = random.uniform(0, WIDTH)
            if mote['x'] < -5: mote['x'] = WIDTH + 5
            elif mote['x'] > WIDTH + 5: mote['x'] = -5

        # ── 탁구공 임팩트 업데이트 ──
        for ball in pong_impact_balls[:]:
            ball['life'] -= 1
            if ball['life'] <= 0:
                pong_impact_balls.remove(ball); continue
            ball['trail'].append((ball['x'], ball['y']))
            if len(ball['trail']) > 12: ball['trail'].pop(0)
            ball['x'] += ball['vx']; ball['y'] += ball['vy']
            if not ball['hit'] and ball['y'] <= ball['target_y']:
                ball['hit'] = True; ball['vy'] = -ball['vy'] * 0.4
                screen_shake = max(screen_shake, 20.0)
                for _ in range(25):
                    a = random.uniform(0, math.pi*2); spd = random.uniform(3,14)
                    pong_impact_sparks.append({
                        'x': ball['x'], 'y': ball['y'],
                        'dx': math.cos(a)*spd, 'dy': math.sin(a)*spd,
                        'life': random.randint(20,50), 'size': random.randint(2,6),
                        'color': random.choice([(255,255,255),(255,220,80),(255,160,60),(100,200,255)])})
            elif ball['hit']:
                ball['vy'] += 0.8
        for spark in pong_impact_sparks[:]:
            spark['x'] += spark['dx']; spark['y'] += spark['dy']
            spark['dy'] += 0.3; spark['dx'] *= 0.97; spark['life'] -= 1
            if spark['life'] <= 0: pong_impact_sparks.remove(spark)

        # ================================================================
        #                  3) 렌더링 (buf 에 그리기)
        # ================================================================
        buf.fill((0, 0, 0))

        # ── 배경 (Ken Burns - 이징 패닝) ──
        if background_image is not None:
            bg_w, bg_h = background_image.get_size()
            kb_phase = animation_timer * 0.004
            # ease-in-out-sine 으로 끝에서 감속하는 부드러운 패닝
            kb_raw_x = math.sin(kb_phase)
            kb_raw_y = math.cos(kb_phase * 0.75)
            kb_pan_x = kb_raw_x * 25 * _ease_in_out_sine((kb_raw_x + 1) / 2)
            kb_pan_y = kb_raw_y * 18 * _ease_in_out_sine((kb_raw_y + 1) / 2)
            bg_x = (WIDTH - bg_w) // 2 + int(kb_pan_x)
            bg_y = (HEIGHT - bg_h) // 2 + int(kb_pan_y)
            buf.blit(background_image, (bg_x, bg_y))
            _overlay.fill((0, 0, 0, 120))
            buf.blit(_overlay, (0, 0))
        else:
            for _y in range(HEIGHT):
                cr = _y / HEIGHT
                tf = math.sin(animation_timer * 0.02) * 0.3 + 0.7
                buf.fill((int(10+cr*100*tf), int(20+cr*150*tf), int(40+cr*180*tf)),
                         (0, _y, WIDTH, 1))

        # ── 빛내림 God Rays ──
        _overlay.fill((0, 0, 0, 0))
        for ray in god_rays:
            rx = ray['x'] + math.sin(animation_timer * 0.005 + ray['phase']) * 60
            ra = int(ray['alpha'] * (0.5 + 0.5 * math.sin(animation_timer * 0.008 + ray['phase'])))
            ra = max(0, min(40, ra))
            tw = ray['width'] * 0.3; bw = ray['width'] * 1.2
            pts = [(rx-tw, 0), (rx+tw, 0), (rx+bw, HEIGHT), (rx-bw, HEIGHT)]
            pygame.draw.polygon(_overlay, (255, 255, 200, ra), pts)
        buf.blit(_overlay, (0, 0))

        # ── 먼지 입자 렌더링 ──
        for mote in dust_motes:
            ms = max(1, int(mote['size']))
            flicker = int(mote['alpha'] * (0.7 + 0.3 * math.sin(animation_timer * 0.03 + mote['phase'])))
            flicker = max(0, min(255, flicker))
            mote_s = pygame.Surface((ms*2, ms*2), pygame.SRCALPHA)
            pygame.draw.circle(mote_s, (255, 255, 220, flicker), (ms, ms), ms)
            buf.blit(mote_s, (int(mote['x'])-ms, int(mote['y'])-ms))

        # ── 임팩트 상태 어두운 오버레이 ──
        if current_state >= ST_IMPACT_ACTION:
            _overlay.fill((10, 5, 15, 180))
            buf.blit(_overlay, (0, 0))

        # ── 특별 이펙트 (에너지 웨이브 / 보스 그림자 / 패들 발사체 / 전투 파티클) ──
        if current_state >= ST_IMPACT_ACTION:
            for wave in energy_waves[:]:
                wave['radius'] += wave['speed']
                wave['alpha'] = int(255*(1-wave['radius']/wave['max_radius']))
                if wave['alpha'] > 0 and wave['radius'] < wave['max_radius']:
                    ws = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
                    pygame.draw.circle(ws, (100,200,255,wave['alpha']), (wave['x'],wave['y']), wave['radius'], 5)
                    buf.blit(ws, (0,0))
                else: energy_waves.remove(wave)

            for shadow in boss_shadows[:]:
                shadow['life'] -= 2; shadow['alpha'] = int(255*(shadow['life']/300)); shadow['rotation'] += 2
                if shadow['alpha'] > 0:
                    ss = pygame.Surface((shadow['size']*2, shadow['size']*2), pygame.SRCALPHA)
                    c = (shadow['size'], shadow['size'])
                    pygame.draw.ellipse(ss, (100,0,100,shadow['alpha']),
                                        (shadow['size']//4, shadow['size']//4, shadow['size']//2, shadow['size']//2))
                    es = shadow['size']//8
                    pygame.draw.circle(ss, (255,0,0,shadow['alpha']), (c[0]-es, c[1]-es), es)
                    pygame.draw.circle(ss, (255,0,0,shadow['alpha']), (c[0]+es, c[1]-es), es)
                    rs = pygame.transform.rotate(ss, shadow['rotation'])
                    buf.blit(rs, rs.get_rect(center=(shadow['x'], shadow['y'])))
                else: boss_shadows.remove(shadow)

            for proj in paddle_projectiles[:]:
                proj['x'] += proj['dx']; proj['y'] += proj['dy']; proj['life'] -= 1
                if proj['life'] > 0 and proj['y'] > -proj['size']:
                    for i in range(10):
                        ta = int(255*(proj['life']/180)*(1-i/10)); tsz = max(1, proj['size']*(1-i/10))
                        tx = proj['x'] - proj['dx']*i*0.3; ty = proj['y'] - proj['dy']*i*0.3
                        if ta > 0:
                            ts = pygame.Surface((tsz*2, tsz*2), pygame.SRCALPHA)
                            pygame.draw.circle(ts, (255,255,100,ta), (tsz,tsz), tsz)
                            buf.blit(ts, (tx-tsz, ty-tsz))
                    pa = int(255*(proj['life']/180)); psz = max(1, proj['size'])
                    ps = pygame.Surface((psz*2, psz*2), pygame.SRCALPHA)
                    pygame.draw.circle(ps, (255,255,0,pa), (psz,psz), psz)
                    buf.blit(ps, (proj['x']-psz, proj['y']-psz))
                else: paddle_projectiles.remove(proj)

            for p in battle_particles[:]:
                p['x'] += p['dx']; p['y'] += p['dy']; p['life'] -= 1
                if p['life'] > 0 and 0 <= p['x'] <= WIDTH and 0 <= p['y'] <= HEIGHT:
                    pa = int(255*(p['life']/120)); psz = max(1, p['size'])
                    ps = pygame.Surface((psz*2, psz*2), pygame.SRCALPHA)
                    pygame.draw.circle(ps, (*p['color'], pa), (psz,psz), psz)
                    buf.blit(ps, (p['x']-psz, p['y']-psz))
                else: battle_particles.remove(p)

        # ── 탁구공 임팩트 렌더링 ──
        for ball in pong_impact_balls:
            for i, (tx, ty) in enumerate(ball['trail']):
                t = i / max(1, len(ball['trail']))
                ta = int(120*t); tsz = max(1, int(ball['size']*t*0.7))
                ts = pygame.Surface((tsz*2, tsz*2), pygame.SRCALPHA)
                pygame.draw.circle(ts, (255,255,255,ta), (tsz,tsz), tsz)
                buf.blit(ts, (int(tx)-tsz, int(ty)-tsz))
            bs = ball['size']
            bsurf = pygame.Surface((bs*2, bs*2), pygame.SRCALPHA)
            pygame.draw.circle(bsurf, (255,255,255), (bs,bs), bs)
            pygame.draw.arc(bsurf, (200,200,200), (2,2,bs*2-4,bs*2-4), 0.3, 2.8, 2)
            buf.blit(bsurf, (int(ball['x'])-bs, int(ball['y'])-bs))
        for spark in pong_impact_sparks:
            if spark['life'] > 0:
                sa = int(255*(spark['life']/50)); sz = max(1, spark['size'])
                ss = pygame.Surface((sz*2, sz*2), pygame.SRCALPHA)
                pygame.draw.circle(ss, (*spark['color'], sa), (sz,sz), sz)
                buf.blit(ss, (int(spark['x'])-sz, int(spark['y'])-sz))

        # ── 로고 서피스 생성 ──
        logo_surface = pygame.Surface((600, 300), pygame.SRCALPHA)

        if current_state >= ST_IMPACT_ACTION:
            for _ in range(20):
                sx2 = random.randint(0,600); sy2 = random.randint(0,300)
                pygame.draw.circle(logo_surface, (255,255,0,random.randint(50,150)), (sx2,sy2), random.randint(2,6))

        # 외곽 무지개 글로우
        glow_radius = int(25 + math.sin(animation_timer * 0.08) * 15)
        for i in range(glow_radius, 0, -2):
            a = int(120 * (1 - i / glow_radius))
            hue = (animation_timer * 2 + i * 10) % 360
            if hue < 60:    c = (255, int(255*hue/60), 0, a)
            elif hue < 120: c = (int(255*(120-hue)/60), 255, 0, a)
            elif hue < 180: c = (0, 255, int(255*(hue-120)/60), a)
            elif hue < 240: c = (0, int(255*(240-hue)/60), 255, a)
            elif hue < 300: c = (int(255*(hue-240)/60), 0, 255, a)
            else:            c = (255, 0, int(255*(360-hue)/60), a)
            pygame.draw.rect(logo_surface, c, (i, i, 600-i*2, 300-i*2), 4)

        pygame.draw.rect(logo_surface, (150,200,255), (0,0,600,300), 10)
        pygame.draw.rect(logo_surface, (200,220,255), (15,15,570,270), 5)

        for i in range(8):
            dx = 50 + i*70; dy = 50 + math.sin(animation_timer*0.05+i*0.5)*15
            sz = 10 + math.sin(animation_timer*0.03+i)*5
            pygame.draw.circle(logo_surface, (255,255,255), (int(dx), int(dy)), int(sz))
            pygame.draw.circle(logo_surface, (100,150,255), (int(dx), int(dy)), int(sz), 2)

        corner_size = 20
        for cx, cy in [(0,0),(600-corner_size,0),(0,300-corner_size),(600-corner_size,300-corner_size)]:
            pygame.draw.rect(logo_surface, (255,255,0), (cx,cy,corner_size,corner_size))
            pygame.draw.rect(logo_surface, (255,255,255), (cx,cy,corner_size,corner_size), 2)

        # ── 타이핑 텍스트 ──
        if typing_timer >= 1:
            if len(typing_text) < len(full_text):
                typing_text = full_text[:len(typing_text)+1]
                typing_timer = 0

        char_spacing = 70 if len(full_text) <= 5 else 40
        total_w = len(typing_text) * char_spacing - 10
        bx = 300 - (total_w // 2) + char_spacing // 2
        char_positions = []
        for i, ch in enumerate(typing_text):
            bounce = math.sin(animation_timer*0.1+i*0.5)*3
            wiggle = math.cos(animation_timer*0.08+i*0.7)*2
            char_positions.append((bx + i*char_spacing + wiggle, 150 + bounce))

        if animation_timer % 20 == 0:
            for pos in char_positions:
                if random.random() > 0.7:
                    sparkle_particles.append({
                        'x': pos[0]+random.randint(-30,30), 'y': pos[1]+random.randint(-30,30),
                        'life': 40, 'size': random.randint(2,4),
                        'color': random.choice([(255,192,203),(255,255,150),(200,255,200)])})

        shadow_color = (150, 150, 200)
        for ch, pos in zip(typing_text, char_positions):
            st = font_large.render(ch, True, shadow_color)
            logo_surface.blit(st, st.get_rect(center=(pos[0]+3, pos[1]+3)))

        outline_color = (255, 182, 193)
        for ch, pos in zip(typing_text, char_positions):
            for ox, oy in [(-2,0),(2,0),(0,-2),(0,2),(-1,-1),(1,-1),(-1,1),(1,1)]:
                ot = font_large.render(ch, True, outline_color)
                logo_surface.blit(ot, ot.get_rect(center=(pos[0]+ox, pos[1]+oy)))

        rainbow = [(255,165,0),(255,200,150),(255,255,0),(150,255,150),(150,200,255)]
        for i, (ch, pos) in enumerate(zip(typing_text, char_positions)):
            bc = rainbow[i % len(rainbow)]
            sp = abs(math.sin(animation_timer*0.05+i*0.3))*0.3+0.7
            cc = tuple(int(v*sp) for v in bc)
            ct = font_large.render(ch, True, cc)
            logo_surface.blit(ct, ct.get_rect(center=pos))
            ht = font_large.render(ch, True, (255,255,255,60))
            logo_surface.blit(ht, ht.get_rect(center=(pos[0]-1, pos[1]-2)))

        # 별 장식
        for sx2, sy2 in [(80,120),(520,120),(60,170),(540,170)]:
            ssz = 5 + math.sin(animation_timer*0.1+sx2)*2
            ang = animation_timer*0.05
            pts = []
            for j in range(10):
                r = ssz if j%2==0 else ssz*0.5
                th = ang+(j*math.pi/5)
                pts.append((sx2+r*math.cos(th), sy2+r*math.sin(th)))
            if len(pts) > 2: pygame.draw.polygon(logo_surface, (255,255,100,180), pts)

        # 서브타이틀
        stxt = font_medium.render(subtitle_str, True, (200,220,255))
        logo_surface.blit(stxt, stxt.get_rect(center=(300, 200)))

        # 스케일 + blit
        scaled = pygame.transform.scale(logo_surface, (int(600*logo_scale), int(300*logo_scale)))
        if current_state >= ST_IMPACT_ACTION:
            ish = max(1, int(screen_shake))
            sox = random.randint(-ish, ish); soy = random.randint(-ish, ish)
            buf.blit(scaled, scaled.get_rect(center=(WIDTH//2+sox, int(logo_y)+soy)))
        else:
            buf.blit(scaled, scaled.get_rect(center=(WIDTH//2, int(logo_y))))

        # ── 화면 전체 글로우 ──
        if animation_timer > 100:
            ga = int(20 * math.sin(animation_timer * 0.05))
            if ga > 0:
                _overlay.fill((255,255,255)); _overlay.set_alpha(ga)
                buf.blit(_overlay, (0,0)); _overlay.set_alpha(255)

        # ── 플래시 ──
        if flash_alpha > 0:
            _overlay.fill((255,255,255)); _overlay.set_alpha(flash_alpha)
            buf.blit(_overlay, (0,0)); _overlay.set_alpha(255)

        # ── 페이드 아웃 ──
        if fade_alpha > 0:
            _overlay.fill((0,0,0)); _overlay.set_alpha(fade_alpha)
            buf.blit(_overlay, (0,0)); _overlay.set_alpha(255)

        # ── Press any key (이징 숨쉬기) ──
        if current_state == ST_INTRO_WAIT and animation_timer > 60:
            raw_pulse = (math.sin(animation_timer * 0.07) + 1) / 2
            pulse_alpha = int(80 + 175 * _ease_in_out_sine(raw_pulse))
            ptxt = font_small.render(press_key_str, True, (200,200,200))
            ptxt.set_alpha(pulse_alpha)
            buf.blit(ptxt, ptxt.get_rect(center=(WIDTH//2, HEIGHT-80)))

        # ── 배경 파티클 렌더링 ──
        for p in particles[:]:
            p['x'] += p['dx']; p['y'] += p['dy']; p['life'] -= 1
            if p['life'] > 0:
                pa = int(255*(p['life']/60)); psz = max(1, p['size'])
                ps = pygame.Surface((psz*2, psz*2), pygame.SRCALPHA)
                pygame.draw.circle(ps, (255,255,255,pa), (psz,psz), psz)
                buf.blit(ps, (p['x']-psz, p['y']-psz))
            else: particles.remove(p)

        for p in sparkle_particles[:]:
            p['life'] -= 1
            if p['life'] > 0:
                if 'color' in p:
                    bc2 = p['color']; pa = int(255*(p['life']/40)); col = (*bc2, pa)
                else:
                    pa = int(255*(p['life']/60)); col = (255,255,255,pa)
                psz = max(1, p['size'])
                ps = pygame.Surface((psz*2, psz*2), pygame.SRCALPHA)
                pygame.draw.circle(ps, col, (psz,psz), psz)
                buf.blit(ps, (p['x']-psz, p['y']-psz))
            else: sparkle_particles.remove(p)

        for s in shooting_stars[:]:
            s['x'] += s['dx']; s['y'] += s['dy']; s['life'] -= 1
            if s['life'] > 0 and s['x'] < WIDTH+50 and s['y'] < HEIGHT+50:
                for i in range(s['trail_length']):
                    ta = int(255*(s['life']/120)*(1-i/s['trail_length']))
                    tsz = max(1, s['size']*(1-i/s['trail_length']))
                    tx = s['x']-s['dx']*i*0.5; ty = s['y']-s['dy']*i*0.5
                    if ta > 0 and tsz > 0:
                        ts = pygame.Surface((tsz*2, tsz*2), pygame.SRCALPHA)
                        pygame.draw.circle(ts, (255,255,255,ta), (tsz,tsz), tsz)
                        buf.blit(ts, (tx-tsz, ty-tsz))
                sa = int(255*(s['life']/120)); ssz = max(1, s['size'])
                ss = pygame.Surface((ssz*2, ssz*2), pygame.SRCALPHA)
                pygame.draw.circle(ss, (255,255,255,sa), (ssz,ssz), ssz)
                buf.blit(ss, (s['x']-ssz, s['y']-ssz))
            else: shooting_stars.remove(s)

        for s in fuzzy_stars[:]:
            s['life'] -= s['fade_speed']; s['alpha'] = int(255*(s['life']/300))
            if s['life'] > 0 and s['alpha'] > 0:
                ssz = max(1, s['size'])
                for i in range(3):
                    off = i*2; fa = int(s['alpha']*(1-i*0.3)); fsz = max(1, ssz-i*2)
                    if fa > 0 and fsz > 0:
                        fs = pygame.Surface((fsz*2, fsz*2), pygame.SRCALPHA)
                        pygame.draw.circle(fs, (255,255,255,fa), (fsz,fsz), fsz)
                        buf.blit(fs, (s['x']-fsz+off, s['y']-fsz+off))
            else: fuzzy_stars.remove(s)

        # ── 4) 최종 출력: 렌더 버퍼 → SCREEN (흔들림 오프셋) ──
        if screen_shake > 0.5:
            ish = max(1, int(screen_shake))
            sx = random.randint(-ish, ish); sy = random.randint(-ish, ish)
            SCREEN.fill((0, 0, 0))
            SCREEN.blit(buf, (sx, sy))
        else:
            SCREEN.blit(buf, (0, 0))

        pygame.display.flip()
