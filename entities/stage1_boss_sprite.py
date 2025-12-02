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

    스프라이트 시트 구조 (stage1walking3.png):
    - 상단 행: 왼쪽 이동 애니메이션 (6프레임)
    - 하단 행: 오른쪽 이동 애니메이션 (6프레임)
    - 이미지 크기: 1024x1024
    """

    def __init__(self, sprite_sheet_path: str = None,
                 frame_width: int = 170, frame_height: int = 512,
                 total_frames: int = 6, animation_speed: float = 0.1):
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

        # 방향 전환 안정화 (떨림 방지)
        self.direction_change_cooldown = 0.0  # 방향 전환 쿨다운 타이머
        self.direction_change_threshold = 0.15  # 방향 전환 최소 대기 시간 (초)
        self.movement_accumulator = 0.0  # 이동량 누적 (방향 결정용)

        # 프레임 저장 리스트
        self.frames_left = []   # 왼쪽 이동 프레임
        self.frames_right = []  # 오른쪽 이동 프레임
        self.idle_frame = None  # 정지 프레임

        # 스케일된 프레임 캐시 (떨림 방지)
        self._scaled_frames_left = []
        self._scaled_frames_right = []
        self._scaled_idle_frame = None
        self._cached_scale_size = None

        # 기본 이미지 (폴백용)
        self.fallback_surface = None
        self.large_idle_frame = None  # 큰 정지 프레임

        # 스프라이트 시트 로드
        if sprite_sheet_path:
            self.load_sprite_sheet(sprite_sheet_path)
        else:
            # 기본 경로 시도 - stage1walking3.png 사용 (6프레임 버전)
            default_path = resource_path(os.path.join("assets", "stage1walking3.png"))
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
            # 알파 채널이 있는 이미지로 로드 (투명 배경 지원)
            sprite_sheet = pygame.image.load(path).convert_alpha()
            sheet_width = sprite_sheet.get_width()
            sheet_height = sprite_sheet.get_height()

            print(f"🎭 스프라이트 시트 로드: {sheet_width}x{sheet_height}")

            # 스프라이트 시트 구조 분석 (stage1walking3.png):
            # - 2행 × 6프레임 구조
            # - 상단 행: 왼쪽 이동 애니메이션 (6프레임)
            # - 하단 행: 오른쪽 이동 애니메이션 (6프레임)
            # - 전체 이미지: 1024 x 1024 픽셀

            # 행 높이 계산 (2행으로 균등 분할)
            row_height = sheet_height // 2  # 512px

            # 프레임 너비 계산 (6프레임으로 균등 분할)
            frame_width = sheet_width // self.total_frames  # 약 170px

            print(f"🎭 프레임 크기: {frame_width}x{row_height}, 총 프레임: {self.total_frames}")

            # 첫 번째 행 (왼쪽 이동) 프레임 추출
            self.frames_left = []
            for i in range(self.total_frames):
                try:
                    frame_x = i * frame_width
                    frame_rect = pygame.Rect(
                        frame_x,
                        0,
                        frame_width,
                        row_height
                    )
                    # 경계 체크
                    if frame_rect.right > sheet_width:
                        frame_rect.width = sheet_width - frame_rect.x
                    if frame_rect.bottom > sheet_height:
                        frame_rect.height = sheet_height - frame_rect.y

                    frame = sprite_sheet.subsurface(frame_rect).copy()
                    # 투명 배경 이미지이므로 그대로 사용
                    self.frames_left.append(frame)
                except Exception as e:
                    print(f"⚠️ 왼쪽 프레임 {i} 추출 실패: {e}")

            # 두 번째 행 (오른쪽 이동) 프레임 추출
            self.frames_right = []
            row2_y = row_height  # 512px 부터 시작
            for i in range(self.total_frames):
                try:
                    frame_x = i * frame_width
                    frame_rect = pygame.Rect(
                        frame_x,
                        row2_y,
                        frame_width,
                        row_height
                    )
                    # 경계 체크
                    if frame_rect.right > sheet_width:
                        frame_rect.width = sheet_width - frame_rect.x
                    if frame_rect.bottom > sheet_height:
                        frame_rect.height = sheet_height - frame_rect.y

                    frame = sprite_sheet.subsurface(frame_rect).copy()
                    # 투명 배경 이미지이므로 그대로 사용
                    self.frames_right.append(frame)
                except Exception as e:
                    print(f"⚠️ 오른쪽 프레임 {i} 추출 실패: {e}")

            # 정지 프레임 - 첫 번째 프레임 사용 (가장 자연스러운 자세)
            if self.frames_right:
                self.idle_frame = self.frames_right[0]
            elif self.frames_left:
                self.idle_frame = self.frames_left[0]
            else:
                self.idle_frame = None

            # 큰 정지 프레임은 이 스프라이트 시트에는 없음
            self.large_idle_frame = None

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

        # 방향 전환 쿨다운 업데이트
        if self.direction_change_cooldown > 0:
            self.direction_change_cooldown -= dt

        # 이동량 누적 (방향 결정에 사용)
        self.movement_accumulator += dx

        # 더 큰 데드존 (2.0) 과 누적 이동량 체크로 떨림 방지
        if abs(dx) > 2.0:  # 기존 0.5에서 2.0으로 증가
            new_direction = 1 if dx > 0 else -1

            # 방향 전환 시 쿨다운 체크 및 누적 이동량 확인
            if new_direction != self.direction:
                # 같은 방향으로 충분히 누적된 이동이 있고, 쿨다운이 끝났을 때만 방향 전환
                if self.direction_change_cooldown <= 0 and abs(self.movement_accumulator) > 5.0:
                    if (self.movement_accumulator > 0 and new_direction == 1) or \
                       (self.movement_accumulator < 0 and new_direction == -1):
                        self.direction = new_direction
                        self.direction_change_cooldown = self.direction_change_threshold
                        self.movement_accumulator = 0  # 방향 전환 후 누적량 리셋
            else:
                # 같은 방향 유지 - 누적량 리셋하지 않음
                pass

            # 이동 속도에 따라 애니메이션 속도 조절
            speed_factor = min(abs(dx) / 5.0, 2.0)  # 최대 2배속
            adjusted_speed = self.animation_speed / max(speed_factor, 0.5)

            # 애니메이션 타이머 업데이트
            self.animation_timer += dt
            if self.animation_timer >= adjusted_speed:
                self.animation_timer = 0
                self.current_frame = (self.current_frame + 1) % self.total_frames
        else:
            # 정지 상태 - 하지만 바로 방향을 0으로 바꾸지 않고 일정 시간 유지
            if self.direction_change_cooldown <= 0:
                # 누적 이동량이 거의 없을 때만 정지 상태로 전환
                if abs(self.movement_accumulator) < 3.0:
                    self.direction = 0
                    self.current_frame = 0
                    self.animation_timer = 0
                self.movement_accumulator *= 0.8  # 점진적으로 누적량 감소

        self.prev_x = current_x

    def _build_scaled_cache(self, scale_size: tuple):
        """스케일된 프레임 캐시 생성 (떨림 방지)"""
        if scale_size == self._cached_scale_size:
            return  # 이미 캐시됨

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
        현재 프레임 반환 (캐시된 스케일 프레임 사용으로 떨림 방지)

        Args:
            scale_size: (width, height) 크기로 스케일링 (None이면 원본 크기)

        Returns:
            현재 애니메이션 프레임 서피스
        """
        # 스케일 사이즈가 있으면 캐시 빌드
        if scale_size:
            self._build_scaled_cache(scale_size)

            # 캐시된 프레임에서 가져오기
            if self.direction == -1 and self._scaled_frames_left:
                return self._scaled_frames_left[self.current_frame % len(self._scaled_frames_left)]
            elif self.direction == 1 and self._scaled_frames_right:
                return self._scaled_frames_right[self.current_frame % len(self._scaled_frames_right)]
            else:
                # 정지 상태
                return self._scaled_idle_frame if self._scaled_idle_frame else self._scaled_frames_right[0]

        # 원본 크기 반환
        if self.direction == -1 and self.frames_left:
            return self.frames_left[self.current_frame % len(self.frames_left)]
        elif self.direction == 1 and self.frames_right:
            return self.frames_right[self.current_frame % len(self.frames_right)]
        else:
            # 정지 상태
            return self.idle_frame if self.idle_frame else self.frames_right[0]

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
