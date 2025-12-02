"""
🐊 Stage 2 Boss Sprite Animation - 악어장군 걷기 애니메이션
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


class Stage2BossSprite:
    """
    🐊 악어장군 (Stage 2 보스) 걷기 애니메이션 클래스

    스프라이트 시트 구조 (stage2walking.png):
    - 상단 행: 왼쪽 이동 애니메이션 (4프레임)
    - 하단 행: 오른쪽 이동 애니메이션 (4프레임)
    - 총 8프레임 (4x2 레이아웃)
    """

    def __init__(self, sprite_sheet_path: str = None,
                 total_frames: int = 4, animation_speed: float = 0.12):
        """
        애니메이션 초기화

        Args:
            sprite_sheet_path: 스프라이트 시트 이미지 경로
            total_frames: 한 방향당 총 프레임 수 (4프레임)
            animation_speed: 애니메이션 속도 (초 단위, 낮을수록 빠름)
        """
        self.total_frames = total_frames
        self.animation_speed = animation_speed

        # 애니메이션 상태
        self.current_frame = 0
        self.animation_timer = 0.0
        self.direction = 0  # -1: 왼쪽, 0: 정지, 1: 오른쪽
        self.prev_x = 0.0

        # 방향 전환 안정화 (떨림 방지)
        self.direction_change_cooldown = 0.0
        self.direction_change_threshold = 0.15
        self.movement_accumulator = 0.0

        # 프레임 저장 리스트
        self.frames_left = []   # 왼쪽 이동 프레임
        self.frames_right = []  # 오른쪽 이동 프레임
        self.idle_frame = None  # 정지 프레임

        # 스케일된 프레임 캐시
        self._scaled_frames_left = []
        self._scaled_frames_right = []
        self._scaled_idle_frame = None
        self._cached_scale_size = None

        # 스프라이트 시트 로드
        if sprite_sheet_path:
            self.load_sprite_sheet(sprite_sheet_path)
        else:
            default_path = resource_path(os.path.join("assets", "stage2walking.png"))
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

            print(f"🐊 스테이지2 스프라이트 시트 로드: {sheet_width}x{sheet_height}")

            # 스프라이트 시트 구조:
            # - 2행 × 4프레임 구조
            # - 상단 행: 왼쪽 이동 (4프레임)
            # - 하단 행: 오른쪽 이동 (4프레임)

            row_height = sheet_height // 2
            frame_width = sheet_width // self.total_frames

            print(f"🐊 프레임 크기: {frame_width}x{row_height}, 총 프레임: {self.total_frames}")

            # 첫 번째 행 (왼쪽 이동) 프레임 추출
            self.frames_left = []
            for i in range(self.total_frames):
                try:
                    frame_x = i * frame_width
                    frame_rect = pygame.Rect(frame_x, 0, frame_width, row_height)

                    # 경계 체크
                    if frame_rect.right > sheet_width:
                        frame_rect.width = sheet_width - frame_rect.x

                    frame = sprite_sheet.subsurface(frame_rect).copy()
                    self.frames_left.append(frame)
                except Exception as e:
                    print(f"⚠️ 왼쪽 프레임 {i} 추출 실패: {e}")

            # 두 번째 행 (오른쪽 이동) 프레임 추출
            self.frames_right = []
            row2_y = row_height
            for i in range(self.total_frames):
                try:
                    frame_x = i * frame_width
                    frame_rect = pygame.Rect(frame_x, row2_y, frame_width, row_height)

                    # 경계 체크
                    if frame_rect.right > sheet_width:
                        frame_rect.width = sheet_width - frame_rect.x
                    if frame_rect.bottom > sheet_height:
                        frame_rect.height = sheet_height - frame_rect.y

                    frame = sprite_sheet.subsurface(frame_rect).copy()
                    self.frames_right.append(frame)
                except Exception as e:
                    print(f"⚠️ 오른쪽 프레임 {i} 추출 실패: {e}")

            # 정지 프레임 - 첫 번째 프레임 사용
            if self.frames_right:
                self.idle_frame = self.frames_right[0]
            elif self.frames_left:
                self.idle_frame = self.frames_left[0]
            else:
                self.idle_frame = None

            print(f"✅ 프레임 로드 완료: 왼쪽 {len(self.frames_left)}개, 오른쪽 {len(self.frames_right)}개")
            return True

        except Exception as e:
            print(f"❌ 스프라이트 시트 로드 실패: {e}")
            import traceback
            traceback.print_exc()
            self._create_fallback_frames()
            return False

    def _create_fallback_frames(self):
        """폴백 프레임 생성 (스프라이트 로드 실패 시)"""
        frame_size = (200, 200)

        base_frame = pygame.Surface(frame_size, pygame.SRCALPHA)
        pygame.draw.rect(base_frame, (34, 139, 34), (10, 10, 180, 180), border_radius=15)

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
        dx = current_x - self.prev_x

        # 방향 전환 쿨다운 업데이트
        if self.direction_change_cooldown > 0:
            self.direction_change_cooldown -= dt

        self.movement_accumulator += dx

        # 이동 감지 (더 민감하게)
        if abs(dx) > 1.5:
            new_direction = 1 if dx > 0 else -1

            if new_direction != self.direction:
                if self.direction_change_cooldown <= 0 and abs(self.movement_accumulator) > 4.0:
                    if (self.movement_accumulator > 0 and new_direction == 1) or \
                       (self.movement_accumulator < 0 and new_direction == -1):
                        self.direction = new_direction
                        self.direction_change_cooldown = self.direction_change_threshold
                        self.movement_accumulator = 0

            # 이동 속도에 따라 애니메이션 속도 조절
            speed_factor = min(abs(dx) / 5.0, 2.0)
            adjusted_speed = self.animation_speed / max(speed_factor, 0.5)

            # 애니메이션 타이머 업데이트
            self.animation_timer += dt
            if self.animation_timer >= adjusted_speed:
                self.animation_timer = 0
                self.current_frame = (self.current_frame + 1) % self.total_frames
        else:
            if self.direction_change_cooldown <= 0:
                if abs(self.movement_accumulator) < 2.0:
                    self.direction = 0
                    self.current_frame = 0
                    self.animation_timer = 0
                self.movement_accumulator *= 0.8

        self.prev_x = current_x

    def _build_scaled_cache(self, scale_size: tuple):
        """스케일된 프레임 캐시 생성"""
        if scale_size == self._cached_scale_size:
            return

        self._cached_scale_size = scale_size

        # 왼쪽 프레임 캐시
        self._scaled_frames_left = []
        for frame in self.frames_left:
            scaled = pygame.transform.smoothscale(frame, scale_size)
            self._scaled_frames_left.append(scaled)

        # 오른쪽 프레임 캐시
        self._scaled_frames_right = []
        for frame in self.frames_right:
            scaled = pygame.transform.smoothscale(frame, scale_size)
            self._scaled_frames_right.append(scaled)

        # 정지 프레임 캐시
        if self.idle_frame:
            self._scaled_idle_frame = pygame.transform.smoothscale(self.idle_frame, scale_size)

    def get_current_frame(self, scale_size: tuple = None) -> pygame.Surface:
        """
        현재 프레임 반환

        Args:
            scale_size: (width, height) 크기로 스케일링

        Returns:
            현재 애니메이션 프레임 서피스
        """
        if scale_size:
            self._build_scaled_cache(scale_size)

            if self.direction == -1 and self._scaled_frames_left:
                return self._scaled_frames_left[self.current_frame % len(self._scaled_frames_left)]
            elif self.direction == 1 and self._scaled_frames_right:
                return self._scaled_frames_right[self.current_frame % len(self._scaled_frames_right)]
            else:
                return self._scaled_idle_frame if self._scaled_idle_frame else self._scaled_frames_right[0]

        # 원본 크기 반환
        if self.direction == -1 and self.frames_left:
            return self.frames_left[self.current_frame % len(self.frames_left)]
        elif self.direction == 1 and self.frames_right:
            return self.frames_right[self.current_frame % len(self.frames_right)]
        else:
            return self.idle_frame if self.idle_frame else self.frames_right[0]

    def draw(self, surface: pygame.Surface, x: float, y: float,
             width: int = None, height: int = None, center: bool = True):
        """
        애니메이션 프레임 그리기

        Args:
            surface: 그릴 대상 서피스
            x: X 좌표
            y: Y 좌표
            width: 출력 너비
            height: 출력 높이
            center: True면 (x, y)가 중심점
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
_stage2_boss_sprite_instance = None


def get_stage2_boss_sprite() -> Stage2BossSprite:
    """
    Stage 2 보스 스프라이트 인스턴스 반환 (싱글톤)
    """
    global _stage2_boss_sprite_instance

    if _stage2_boss_sprite_instance is None:
        _stage2_boss_sprite_instance = Stage2BossSprite()

    return _stage2_boss_sprite_instance


def init_stage2_boss_sprite(sprite_sheet_path: str = None) -> Stage2BossSprite:
    """
    Stage 2 보스 스프라이트 초기화

    Args:
        sprite_sheet_path: 스프라이트 시트 경로 (선택적)

    Returns:
        초기화된 Stage2BossSprite 인스턴스
    """
    global _stage2_boss_sprite_instance

    if sprite_sheet_path:
        _stage2_boss_sprite_instance = Stage2BossSprite(sprite_sheet_path)
    else:
        _stage2_boss_sprite_instance = Stage2BossSprite()

    return _stage2_boss_sprite_instance


def reset_stage2_boss_sprite():
    """Stage 2 보스 스프라이트 리셋"""
    global _stage2_boss_sprite_instance
    _stage2_boss_sprite_instance = None


# 테스트 코드
if __name__ == "__main__":
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("Stage 2 Boss Walking Animation Test")
    clock = pygame.time.Clock()

    # 스프라이트 초기화
    boss_sprite = init_stage2_boss_sprite()

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

        keys = pygame.key.get_pressed()
        if keys[pygame.K_LEFT]:
            boss_vel = -5.0
        elif keys[pygame.K_RIGHT]:
            boss_vel = 5.0
        else:
            boss_vel *= 0.9

        boss_x += boss_vel
        boss_x = max(100, min(700, boss_x))

        boss_sprite.update(boss_x, dt)

        screen.fill((50, 80, 50))
        boss_sprite.draw(screen, boss_x, boss_y, 150, 150)

        font = pygame.font.Font(None, 36)
        info_text = f"Direction: {boss_sprite.direction}, Frame: {boss_sprite.current_frame}"
        text_surface = font.render(info_text, True, (255, 255, 255))
        screen.blit(text_surface, (10, 10))

        pygame.display.flip()

    pygame.quit()
