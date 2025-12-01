"""
🎭 Stage 1 Boss Sprite Animation - 풍악보이 걷기 애니메이션
스프라이트 시트를 활용한 좌우 이동 애니메이션 시스템
"""

import pygame
import os
import sys


def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)


class Stage1BossSprite:
    """
    🎭 풍악보이 (Stage 1 보스) 걷기 애니메이션 클래스

    스프라이트 시트 구조:
    - 상단 행: 왼쪽 이동 애니메이션 (12프레임)
    - 하단 행: 오른쪽 이동 애니메이션 (12프레임)
    """

    def __init__(self, sprite_sheet_path: str = None,
                 frame_width: int = 48, frame_height: int = 64,
                 total_frames: int = 12, animation_speed: float = 0.1):
        """
        애니메이션 초기화

        Args:
            sprite_sheet_path: 스프라이트 시트 이미지 경로
            frame_width: 각 프레임의 너비 (픽셀)
            frame_height: 각 프레임의 높이 (픽셀)
            total_frames: 한 방향당 총 프레임 수
            animation_speed: 애니메이션 속도 (초 단위, 낮을수록 빠름)
        """
        self.frame_width = frame_width
        self.frame_height = frame_height
        self.total_frames = total_frames
        self.animation_speed = animation_speed

        # 애니메이션 상태
        self.current_frame = 0
        self.animation_timer = 0.0
        self.direction = 0  # -1: 왼쪽, 0: 정지, 1: 오른쪽
        self.prev_x = 0.0

        # 프레임 저장 리스트
        self.frames_left = []   # 왼쪽 이동 프레임
        self.frames_right = []  # 오른쪽 이동 프레임
        self.idle_frame = None  # 정지 프레임

        # 기본 이미지 (폴백용)
        self.fallback_surface = None

        # 스프라이트 시트 로드
        if sprite_sheet_path:
            self.load_sprite_sheet(sprite_sheet_path)
        else:
            # 기본 경로 시도
            default_path = resource_path(os.path.join("assets", "stage1walking.jpg"))
            self.load_sprite_sheet(default_path)

    def load_sprite_sheet(self, path: str) -> bool:
        """
        스프라이트 시트 로드 및 프레임 분할

        Args:
            path: 스프라이트 시트 이미지 경로

        Returns:
            성공 여부
        """
        try:
            sprite_sheet = pygame.image.load(path).convert_alpha()
            sheet_width = sprite_sheet.get_width()
            sheet_height = sprite_sheet.get_height()

            print(f"🎭 스프라이트 시트 로드: {sheet_width}x{sheet_height}")

            # 스프라이트 시트 분석
            # 이미지 구조: 상단에 큰 캐릭터, 하단에 2행의 걷기 애니메이션
            # 걷기 애니메이션 영역 계산 (하단 2행)

            # 이미지에서 실제 애니메이션 프레임 영역 찾기
            # 스프라이트 시트 하단의 작은 캐릭터들이 걷기 애니메이션

            # 프레임 크기 자동 감지 (하단 애니메이션 기준)
            # 원본 이미지에서 하단 영역의 캐릭터들을 추출

            # 이미지 하반부 분석 (걷기 애니메이션 영역)
            animation_start_y = int(sheet_height * 0.55)  # 애니메이션은 하단 45%에 위치
            animation_height = sheet_height - animation_start_y
            row_height = animation_height // 2  # 2행으로 나눔

            # 프레임 너비 계산 (12프레임 기준)
            frame_width = sheet_width // self.total_frames

            print(f"🎭 프레임 크기: {frame_width}x{row_height}, 시작 Y: {animation_start_y}")

            # 첫 번째 행 (왼쪽 이동) 프레임 추출
            self.frames_left = []
            for i in range(self.total_frames):
                frame_rect = pygame.Rect(
                    i * frame_width,
                    animation_start_y,
                    frame_width,
                    row_height
                )
                frame = sprite_sheet.subsurface(frame_rect).copy()
                # 흰색 배경을 투명하게 처리
                frame = self._remove_white_background(frame)
                self.frames_left.append(frame)

            # 두 번째 행 (오른쪽 이동) 프레임 추출
            self.frames_right = []
            for i in range(self.total_frames):
                frame_rect = pygame.Rect(
                    i * frame_width,
                    animation_start_y + row_height,
                    frame_width,
                    row_height
                )
                frame = sprite_sheet.subsurface(frame_rect).copy()
                # 흰색 배경을 투명하게 처리
                frame = self._remove_white_background(frame)
                self.frames_right.append(frame)

            # 정지 프레임 (첫 번째 프레임 사용)
            self.idle_frame = self.frames_right[0] if self.frames_right else None

            # 상단의 큰 캐릭터를 정지 프레임으로 사용 (선택적)
            idle_height = animation_start_y
            idle_width = int(sheet_width * 0.4)  # 중앙 40% 영역
            idle_x = (sheet_width - idle_width) // 2

            try:
                idle_rect = pygame.Rect(idle_x, 0, idle_width, idle_height)
                large_idle = sprite_sheet.subsurface(idle_rect).copy()
                large_idle = self._remove_white_background(large_idle)
                # 정지 프레임은 나중에 크기 조절하여 사용
                self.large_idle_frame = large_idle
            except:
                self.large_idle_frame = None

            print(f"✅ 프레임 로드 완료: 왼쪽 {len(self.frames_left)}개, 오른쪽 {len(self.frames_right)}개")
            return True

        except Exception as e:
            print(f"❌ 스프라이트 시트 로드 실패: {e}")
            self._create_fallback_frames()
            return False

    def _remove_white_background(self, surface: pygame.Surface,
                                  threshold: int = 240) -> pygame.Surface:
        """
        흰색/밝은 배경을 투명하게 처리

        Args:
            surface: 처리할 서피스
            threshold: 흰색으로 판단할 RGB 최소값 (기본 240)

        Returns:
            배경이 투명하게 처리된 서피스
        """
        # 새 서피스 생성 (알파 채널 포함)
        new_surface = pygame.Surface(surface.get_size(), pygame.SRCALPHA)

        width, height = surface.get_size()

        for x in range(width):
            for y in range(height):
                pixel = surface.get_at((x, y))
                # 흰색/밝은 색상 감지 (RGB 모두 threshold 이상)
                if pixel.r >= threshold and pixel.g >= threshold and pixel.b >= threshold:
                    # 투명하게 설정
                    new_surface.set_at((x, y), (0, 0, 0, 0))
                else:
                    new_surface.set_at((x, y), pixel)

        return new_surface

    def _create_fallback_frames(self):
        """폴백 프레임 생성 (스프라이트 로드 실패 시)"""
        frame_size = (self.frame_width, self.frame_height)

        # 기본 캐릭터 모양 생성
        base_frame = pygame.Surface(frame_size, pygame.SRCALPHA)
        pygame.draw.rect(base_frame, (100, 80, 60), (5, 5, 38, 54), border_radius=5)
        pygame.draw.circle(base_frame, (255, 220, 180), (24, 20), 12)  # 얼굴

        self.frames_left = [base_frame.copy() for _ in range(self.total_frames)]
        self.frames_right = [base_frame.copy() for _ in range(self.total_frames)]
        self.idle_frame = base_frame.copy()

        print("⚠️ 폴백 프레임 생성됨")

    def update(self, current_x: float, dt: float = 1/60):
        """
        애니메이션 업데이트

        Args:
            current_x: 현재 보스 X 좌표
            dt: 델타 타임 (초 단위)
        """
        # 이동 방향 감지
        dx = current_x - self.prev_x

        if abs(dx) > 0.5:  # 데드존
            self.direction = 1 if dx > 0 else -1

            # 이동 속도에 따라 애니메이션 속도 조절
            speed_factor = min(abs(dx) / 5.0, 2.0)  # 최대 2배속
            adjusted_speed = self.animation_speed / max(speed_factor, 0.5)

            # 애니메이션 타이머 업데이트
            self.animation_timer += dt
            if self.animation_timer >= adjusted_speed:
                self.animation_timer = 0
                self.current_frame = (self.current_frame + 1) % self.total_frames
        else:
            # 정지 상태
            self.direction = 0
            self.current_frame = 0
            self.animation_timer = 0

        self.prev_x = current_x

    def get_current_frame(self, scale_size: tuple = None) -> pygame.Surface:
        """
        현재 프레임 반환

        Args:
            scale_size: (width, height) 크기로 스케일링 (None이면 원본 크기)

        Returns:
            현재 애니메이션 프레임 서피스
        """
        if self.direction == -1 and self.frames_left:
            frame = self.frames_left[self.current_frame % len(self.frames_left)]
        elif self.direction == 1 and self.frames_right:
            frame = self.frames_right[self.current_frame % len(self.frames_right)]
        else:
            # 정지 상태
            frame = self.idle_frame if self.idle_frame else self.frames_right[0]

        if scale_size and frame:
            frame = pygame.transform.smoothscale(frame, scale_size)

        return frame

    def draw(self, surface: pygame.Surface, x: float, y: float,
             width: int = None, height: int = None, center: bool = True):
        """
        애니메이션 프레임 그리기

        Args:
            surface: 그릴 대상 서피스
            x: X 좌표
            y: Y 좌표
            width: 출력 너비 (None이면 원본 크기)
            height: 출력 높이 (None이면 원본 크기)
            center: True면 (x, y)가 중심점, False면 좌상단
        """
        if width and height:
            frame = self.get_current_frame((width, height))
        else:
            frame = self.get_current_frame()

        if frame:
            if center:
                rect = frame.get_rect(center=(int(x), int(y)))
            else:
                rect = frame.get_rect(topleft=(int(x), int(y)))

            surface.blit(frame, rect)


# 전역 인스턴스 (싱글톤 패턴)
_stage1_boss_sprite_instance = None


def get_stage1_boss_sprite() -> Stage1BossSprite:
    """
    Stage 1 보스 스프라이트 인스턴스 반환 (싱글톤)

    Returns:
        Stage1BossSprite 인스턴스
    """
    global _stage1_boss_sprite_instance

    if _stage1_boss_sprite_instance is None:
        _stage1_boss_sprite_instance = Stage1BossSprite()

    return _stage1_boss_sprite_instance


def init_stage1_boss_sprite(sprite_sheet_path: str = None) -> Stage1BossSprite:
    """
    Stage 1 보스 스프라이트 초기화

    Args:
        sprite_sheet_path: 스프라이트 시트 경로 (선택적)

    Returns:
        초기화된 Stage1BossSprite 인스턴스
    """
    global _stage1_boss_sprite_instance

    if sprite_sheet_path:
        _stage1_boss_sprite_instance = Stage1BossSprite(sprite_sheet_path)
    else:
        _stage1_boss_sprite_instance = Stage1BossSprite()

    return _stage1_boss_sprite_instance


def reset_stage1_boss_sprite():
    """Stage 1 보스 스프라이트 리셋"""
    global _stage1_boss_sprite_instance
    _stage1_boss_sprite_instance = None


# 테스트 코드
if __name__ == "__main__":
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("Stage 1 Boss Walking Animation Test")
    clock = pygame.time.Clock()

    # 스프라이트 초기화
    boss_sprite = init_stage1_boss_sprite()

    # 테스트용 보스 위치
    boss_x = 400.0
    boss_y = 300.0
    boss_vel = 0.0

    running = True
    while running:
        dt = clock.tick(60) / 1000.0

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

        # 키 입력으로 보스 이동
        keys = pygame.key.get_pressed()
        if keys[pygame.K_LEFT]:
            boss_vel = -5.0
        elif keys[pygame.K_RIGHT]:
            boss_vel = 5.0
        else:
            boss_vel *= 0.9  # 감속

        boss_x += boss_vel
        boss_x = max(50, min(750, boss_x))

        # 애니메이션 업데이트
        boss_sprite.update(boss_x, dt)

        # 화면 그리기
        screen.fill((50, 50, 80))

        # 보스 그리기
        boss_sprite.draw(screen, boss_x, boss_y, 120, 160)

        # 정보 표시
        font = pygame.font.Font(None, 36)
        info_text = f"Direction: {boss_sprite.direction}, Frame: {boss_sprite.current_frame}"
        text_surface = font.render(info_text, True, (255, 255, 255))
        screen.blit(text_surface, (10, 10))

        help_text = "Arrow keys to move, ESC to exit"
        help_surface = font.render(help_text, True, (200, 200, 200))
        screen.blit(help_surface, (10, 50))

        pygame.display.flip()

    pygame.quit()
