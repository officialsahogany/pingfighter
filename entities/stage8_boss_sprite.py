"""
🥷 Stage 8 Boss Sprite Animation - 아카무 리고 걷기 애니메이션
스프라이트 시트를 활용한 좌우 이동 애니메이션 시스템

스프라이트 시트 구조 (stage8walking.png):
- 1열 (상단): 오른쪽 이동 애니메이션 (4프레임)
- 2열 (하단): 왼쪽 이동 애니메이션 (4프레임)
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


class Stage8BossSprite:
    """
    🥷 아카무 리고 (Stage 8 보스) 걷기 애니메이션 클래스

    스프라이트 시트 구조 (stage8walking.png):
    - 1열 (상단): 오른쪽 이동 애니메이션 (4프레임)
    - 2열 (하단): 왼쪽 이동 애니메이션 (4프레임)
    """

    def __init__(self, sprite_sheet_path: str = None,
                 total_frames: int = 4, animation_speed: float = 0.06):
        """
        애니메이션 초기화

        Args:
            sprite_sheet_path: 스프라이트 시트 이미지 경로
            total_frames: 한 방향당 총 프레임 수 (4프레임)
            animation_speed: 애니메이션 속도 (초 단위, 낮을수록 빠름)
        """
        self.total_frames = total_frames
        self.animation_speed = animation_speed

        # 프레임 크기 (로드 시 계산됨)
        self.frame_width = 0
        self.frame_height = 0

        # 기준 프레임 크기 (승리/패배 스프라이트 시트 기준 - 모든 애니메이션 통일)
        # stage8win.png, stage8defeat.png: 1086x1037, 2행x4열 → 271x518
        self.standard_frame_width = 271
        self.standard_frame_height = 518

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
        self.frames_left = []   # 왼쪽 이동 프레임 (2열)
        self.frames_right = []  # 오른쪽 이동 프레임 (1열)
        self.idle_frame = None  # 정지 프레임

        # 스케일된 프레임 캐시 (떨림 방지)
        self._scaled_frames_left = []
        self._scaled_frames_right = []
        self._scaled_idle_frame = None
        self._cached_scale_size = None

        # 히트 애니메이션 상태
        self.is_hit = False
        self.hit_frame = 0
        self.hit_timer = 0.0
        self.hit_animation_speed = 0.05
        self.hit_total_frames = 4
        self.hit_direction = 1

        # 히트 프레임 저장 (별도 히트 시트가 없으면 일반 프레임 사용)
        self.frames_hit_left = []
        self.frames_hit_right = []
        self._scaled_frames_hit_left = []
        self._scaled_frames_hit_right = []

        # 대쉬 애니메이션 상태
        self.is_dashing = False
        self.dash_frame = 0
        self.dash_timer = 0.0
        self.dash_animation_speed = 0.08
        self.dash_total_frames = 2  # 각 방향 2프레임
        self.dash_direction = 1

        # 대쉬 프레임 저장
        self.frames_dash_left = []
        self.frames_dash_right = []
        self._scaled_frames_dash_left = []
        self._scaled_frames_dash_right = []

        # 방향 전환 애니메이션 상태
        self.is_turning = False
        self.turn_frame = 0
        self.turn_timer = 0.0
        self.turn_animation_speed = 0.04  # 빠른 전환
        self.turn_total_frames = 5  # 5프레임 (왼쪽 → 정면 → 오른쪽)
        self.turn_from_direction = 0  # 전환 시작 방향
        self.turn_to_direction = 0    # 전환 목표 방향

        # 방향 전환 프레임 저장 (5프레임: 왼쪽, 왼쪽-중간, 정면, 오른쪽-중간, 오른쪽)
        self.frames_turn = []  # 인덱스 0=왼쪽, 2=정면, 4=오른쪽
        self._scaled_frames_turn = []

        # 패배 애니메이션 상태
        self.is_defeated = False
        self.defeat_frame = 0
        self.defeat_timer = 0.0
        self.defeat_animation_speed = 0.15  # 느린 애니메이션 (털썩 주저앉는 느낌)
        self.defeat_total_frames = 4  # 4프레임
        self.defeat_loop = False  # 루프 여부 (마지막 프레임에서 멈춤)
        self.defeat_finished = False  # 애니메이션 완료 여부

        # 패배 프레임 저장
        self.frames_defeat = []
        self._scaled_frames_defeat = []

        # 승리 애니메이션 상태
        self.is_victorious = False
        self.victory_frame = 0
        self.victory_timer = 0.0
        self.victory_animation_speed = 0.12  # 빠른 애니메이션 (기뻐하는 느낌)
        self.victory_total_frames = 4  # 4프레임
        self.victory_loop = True  # 루프 여부 (승리 후 반복)
        self.victory_finished = False  # 애니메이션 완료 여부

        # 승리 프레임 저장
        self.frames_victory = []
        self._scaled_frames_victory = []

        # 스프라이트 시트 로드
        if sprite_sheet_path:
            self.load_sprite_sheet(sprite_sheet_path)
        else:
            default_path = resource_path(os.path.join("assets", "stage8walking.png"))
            self.load_sprite_sheet(default_path)

        # 히트 스프라이트 시트 로드 시도 (없으면 일반 프레임 사용)
        hit_path = resource_path(os.path.join("assets", "stage9hit2.png"))
        if os.path.exists(hit_path):
            self.load_hit_sprite_sheet(hit_path)
        else:
            # 히트 시트가 없으면 일반 프레임을 히트 프레임으로 사용
            self.frames_hit_left = self.frames_left.copy()
            self.frames_hit_right = self.frames_right.copy()

        # 대쉬 스프라이트 시트 로드 시도
        dash_path = resource_path(os.path.join("assets", "stage8dash.png"))
        if os.path.exists(dash_path):
            self.load_dash_sprite_sheet(dash_path)
        else:
            # 대쉬 시트가 없으면 일반 프레임 사용
            self.frames_dash_left = self.frames_left[:2] if len(self.frames_left) >= 2 else self.frames_left.copy()
            self.frames_dash_right = self.frames_right[:2] if len(self.frames_right) >= 2 else self.frames_right.copy()

        # 방향 전환 스프라이트 시트 로드 시도
        turn_path = resource_path(os.path.join("assets", "stage8movechange3.png"))
        if os.path.exists(turn_path):
            self.load_turn_sprite_sheet(turn_path)

        # 패배 스프라이트 시트 로드 시도
        defeat_path = resource_path(os.path.join("assets", "stage8defeat.png"))
        if os.path.exists(defeat_path):
            self.load_defeat_sprite_sheet(defeat_path)

        # 승리 스프라이트 시트 로드 시도
        victory_path = resource_path(os.path.join("assets", "stage8win.png"))
        if os.path.exists(victory_path):
            self.load_victory_sprite_sheet(victory_path)

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

            print(f"🥷 스테이지 8 스프라이트 시트 로드: {sheet_width}x{sheet_height}")

            # 스프라이트 시트 구조 분석:
            # - 2행 × 4프레임 구조
            # - 1열 (상단): 오른쪽 이동 애니메이션 (4프레임)
            # - 2열 (하단): 왼쪽 이동 애니메이션 (4프레임)

            # 행 높이 계산 (2행으로 균등 분할)
            row_height = sheet_height // 2

            # 프레임 너비 계산 (4프레임으로 균등 분할)
            frame_width_float = sheet_width / self.total_frames

            # 프레임 크기 저장
            self.frame_width = int(frame_width_float)
            self.frame_height = row_height

            # 옆 프레임이 보이지 않도록 양쪽 여백 추가
            margin = 2
            actual_frame_width = int(frame_width_float) - (margin * 2)

            print(f"🥷 프레임 크기: {actual_frame_width}x{row_height}, 총 프레임: {self.total_frames}")

            # 첫 번째 행 (오른쪽 이동) 프레임 추출
            self.frames_right = []
            for i in range(self.total_frames):
                try:
                    frame_center_x = int(frame_width_float * (i + 0.5))
                    frame_x = frame_center_x - (actual_frame_width // 2)
                    frame_rect = pygame.Rect(frame_x, 0, actual_frame_width, row_height)

                    # 경계 체크
                    if frame_rect.x < 0:
                        frame_rect.x = 0
                    if frame_rect.right > sheet_width:
                        frame_rect.width = sheet_width - frame_rect.x
                    if frame_rect.bottom > sheet_height:
                        frame_rect.height = sheet_height - frame_rect.y

                    frame = sprite_sheet.subsurface(frame_rect).copy()
                    # 기준 크기로 스케일링 (승리/패배와 크기 통일)
                    frame = pygame.transform.smoothscale(frame, (self.standard_frame_width, self.standard_frame_height))
                    self.frames_right.append(frame)
                except Exception as e:
                    print(f"⚠️ 오른쪽 프레임 {i} 추출 실패: {e}")

            # 두 번째 행 (왼쪽 이동) 프레임 추출
            self.frames_left = []
            row2_y = row_height
            for i in range(self.total_frames):
                try:
                    frame_center_x = int(frame_width_float * (i + 0.5))
                    frame_x = frame_center_x - (actual_frame_width // 2)
                    frame_rect = pygame.Rect(frame_x, row2_y, actual_frame_width, row_height)

                    # 경계 체크
                    if frame_rect.x < 0:
                        frame_rect.x = 0
                    if frame_rect.right > sheet_width:
                        frame_rect.width = sheet_width - frame_rect.x
                    if frame_rect.bottom > sheet_height:
                        frame_rect.height = sheet_height - frame_rect.y

                    frame = sprite_sheet.subsurface(frame_rect).copy()
                    # 기준 크기로 스케일링 (승리/패배와 크기 통일)
                    frame = pygame.transform.smoothscale(frame, (self.standard_frame_width, self.standard_frame_height))
                    self.frames_left.append(frame)
                except Exception as e:
                    print(f"⚠️ 왼쪽 프레임 {i} 추출 실패: {e}")

            # 프레임 크기를 기준 크기로 업데이트
            self.frame_width = self.standard_frame_width
            self.frame_height = self.standard_frame_height

            # 정지 프레임 - 오른쪽 첫 번째 프레임 사용
            if self.frames_right:
                self.idle_frame = self.frames_right[0]
            elif self.frames_left:
                self.idle_frame = self.frames_left[0]
            else:
                self.idle_frame = None

            print(f"✅ 아카무 리고 프레임 로드 완료: 오른쪽 {len(self.frames_right)}개, 왼쪽 {len(self.frames_left)}개 (크기: {self.frame_width}x{self.frame_height})")
            return True

        except Exception as e:
            print(f"❌ 스테이지 8 스프라이트 시트 로드 실패: {e}")
            import traceback
            traceback.print_exc()
            self._create_fallback_frames()
            return False

    def _create_fallback_frames(self):
        """폴백 프레임 생성 (스프라이트 로드 실패 시)"""
        # 기준 크기 사용 (모든 애니메이션 크기 통일)
        self.frame_width = self.standard_frame_width
        self.frame_height = self.standard_frame_height

        frame_size = (self.frame_width, self.frame_height)

        # 기본 닌자 캐릭터 모양 생성
        base_frame = pygame.Surface(frame_size, pygame.SRCALPHA)

        # 몸통 (검은 닌자복)
        pygame.draw.rect(base_frame, (30, 30, 35),
                        (60, 80, 80, 140), border_radius=10)

        # 머리 (빨간 머리카락)
        pygame.draw.circle(base_frame, (180, 40, 40), (100, 60), 40)

        # 얼굴
        pygame.draw.circle(base_frame, (255, 220, 200), (100, 65), 25)

        # 빨간 눈
        pygame.draw.circle(base_frame, (200, 50, 50), (90, 60), 6)
        pygame.draw.circle(base_frame, (200, 50, 50), (110, 60), 6)

        # 다리
        pygame.draw.rect(base_frame, (60, 55, 50),
                        (70, 220, 25, 60), border_radius=5)
        pygame.draw.rect(base_frame, (60, 55, 50),
                        (105, 220, 25, 60), border_radius=5)

        self.frames_left = [base_frame.copy() for _ in range(self.total_frames)]
        self.frames_right = [base_frame.copy() for _ in range(self.total_frames)]
        self.idle_frame = base_frame.copy()

        print("⚠️ 아카무 리고 폴백 프레임 생성됨")

    def load_hit_sprite_sheet(self, path: str) -> bool:
        """
        히트 스프라이트 시트 로드 및 프레임 분할

        스프라이트 시트 구조 (stage9hit2.png):
        - 1열 (상단): 히트 애니메이션 (4프레임) - 좌우 방향 상관없이 사용
        - 2열, 3열: 사용 안함

        Args:
            path: 히트 스프라이트 시트 이미지 경로

        Returns:
            성공 여부
        """
        try:
            sprite_sheet = pygame.image.load(path).convert_alpha()
            sheet_width = sprite_sheet.get_width()
            sheet_height = sprite_sheet.get_height()

            print(f"🥊 아카무 리고 히트 스프라이트 시트 로드: {sheet_width}x{sheet_height}")

            # 2행 구조로 가정 (1086x1037 → 2행x4열)
            row_height = sheet_height // 2  # 약 518px
            frame_width_float = sheet_width / self.hit_total_frames  # 4프레임, 약 271px

            # 마진 설정 (하단 마진을 크게 해서 아래 행이 보이지 않도록)
            margin_x = 10
            margin_y_top = 10
            margin_y_bottom = 80  # 하단 마진 더 크게 (아래 행 머리 완전히 제외)
            actual_frame_width = int(frame_width_float) - (margin_x * 2)
            actual_frame_height = row_height - margin_y_top - margin_y_bottom

            print(f"🥊 히트 프레임 크기: {actual_frame_width}x{actual_frame_height}, 총 프레임: {self.hit_total_frames}")

            # 1열 (상단) - 히트 애니메이션 프레임 추출
            # 좌우 방향 상관없이 동일한 프레임 사용
            frames_hit = []
            row1_y = margin_y_top  # 1열 시작 Y좌표
            for i in range(self.hit_total_frames):
                try:
                    # 각 프레임의 정확한 시작 X 좌표 (마진 적용)
                    frame_x = int(frame_width_float * i) + margin_x
                    frame_rect = pygame.Rect(frame_x, row1_y, actual_frame_width, actual_frame_height)

                    # 경계 체크
                    if frame_rect.x < 0:
                        frame_rect.x = 0
                    if frame_rect.right > sheet_width:
                        frame_rect.width = sheet_width - frame_rect.x
                    if frame_rect.bottom > row_height:
                        frame_rect.height = row_height - frame_rect.y

                    frame = sprite_sheet.subsurface(frame_rect).copy()
                    # 기준 크기로 스케일링 (모든 애니메이션 크기 통일)
                    frame = pygame.transform.smoothscale(frame, (self.standard_frame_width, self.standard_frame_height))
                    frames_hit.append(frame)
                except Exception as e:
                    print(f"⚠️ 히트 프레임 {i} 추출 실패: {e}")

            # 좌우 모두 동일한 프레임 사용
            self.frames_hit_right = frames_hit.copy()
            self.frames_hit_left = frames_hit.copy()

            print(f"✅ 아카무 리고 히트 프레임 로드 완료: {len(frames_hit)}개 (좌우 동일)")
            return True

        except Exception as e:
            print(f"⚠️ 아카무 리고 히트 스프라이트 시트 로드 실패 (폴백 사용): {e}")
            self.frames_hit_left = self.frames_left.copy() if self.frames_left else []
            self.frames_hit_right = self.frames_right.copy() if self.frames_right else []
            return False

    def load_dash_sprite_sheet(self, path: str) -> bool:
        """
        대쉬 스프라이트 시트 로드 및 프레임 분할

        스프라이트 시트 구조 (stage8dash.png):
        - 3열에 4프레임: 왼쪽 2개 (왼쪽 대쉬), 오른쪽 2개 (오른쪽 대쉬)

        Args:
            path: 대쉬 스프라이트 시트 이미지 경로

        Returns:
            성공 여부
        """
        try:
            sprite_sheet = pygame.image.load(path).convert_alpha()
            sheet_width = sprite_sheet.get_width()
            sheet_height = sprite_sheet.get_height()

            print(f"💨 아카무 리고 대쉬 스프라이트 시트 로드: {sheet_width}x{sheet_height}")

            # 3행 구조 - 3열(마지막 행)만 사용
            row_height = sheet_height // 3
            frame_width_float = sheet_width / 4  # float로 정확한 너비 계산

            # 캐릭터가 겹치는 스프라이트 시트 - 큰 마진으로 중심부만 추출
            # 상단 마진을 크게 해서 위쪽 행의 이미지가 보이지 않도록 함
            margin_x = 35  # 좌우 마진 크게 (인접 캐릭터 머리카락 제외)
            margin_y_top = 40  # 상단 마진 크게 (위쪽 행 이미지 제외)
            margin_y_bottom = 10  # 하단 마진
            actual_frame_width = int(frame_width_float) - (margin_x * 2)
            actual_frame_height = row_height - margin_y_top - margin_y_bottom

            print(f"💨 대쉬 프레임 크기: {actual_frame_width}x{actual_frame_height}")

            # 3열 (마지막 행) - 왼쪽 2프레임 (오른쪽 대쉬 - 캐릭터가 오른쪽을 향함)
            self.frames_dash_right = []
            row3_y = row_height * 2 + margin_y_top
            for i in range(2):  # 처음 2프레임
                try:
                    # 각 프레임의 정확한 시작 X 좌표 (마진 적용)
                    frame_x = int(frame_width_float * i) + margin_x
                    frame_rect = pygame.Rect(frame_x, row3_y, actual_frame_width, actual_frame_height)

                    # 경계 체크
                    if frame_rect.x < 0:
                        frame_rect.x = 0
                    if frame_rect.right > sheet_width:
                        frame_rect.width = sheet_width - frame_rect.x
                    if frame_rect.bottom > sheet_height:
                        frame_rect.height = sheet_height - frame_rect.y

                    frame = sprite_sheet.subsurface(frame_rect).copy()
                    # 기준 크기로 스케일링 (모든 애니메이션 크기 통일)
                    frame = pygame.transform.smoothscale(frame, (self.standard_frame_width, self.standard_frame_height))
                    self.frames_dash_right.append(frame)
                except Exception as e:
                    print(f"⚠️ 오른쪽 대쉬 프레임 {i} 추출 실패: {e}")

            # 3열 (마지막 행) - 오른쪽 2프레임 (왼쪽 대쉬 - 캐릭터가 왼쪽을 향함)
            self.frames_dash_left = []
            for i in range(2, 4):  # 마지막 2프레임
                try:
                    # 각 프레임의 정확한 시작 X 좌표 (마진 적용)
                    frame_x = int(frame_width_float * i) + margin_x
                    frame_rect = pygame.Rect(frame_x, row3_y, actual_frame_width, actual_frame_height)

                    # 경계 체크
                    if frame_rect.x < 0:
                        frame_rect.x = 0
                    if frame_rect.right > sheet_width:
                        frame_rect.width = sheet_width - frame_rect.x
                    if frame_rect.bottom > sheet_height:
                        frame_rect.height = sheet_height - frame_rect.y

                    frame = sprite_sheet.subsurface(frame_rect).copy()
                    # 기준 크기로 스케일링 (모든 애니메이션 크기 통일)
                    frame = pygame.transform.smoothscale(frame, (self.standard_frame_width, self.standard_frame_height))
                    self.frames_dash_left.append(frame)
                except Exception as e:
                    print(f"⚠️ 왼쪽 대쉬 프레임 {i} 추출 실패: {e}")

            print(f"✅ 아카무 리고 대쉬 프레임 로드 완료: 왼쪽 {len(self.frames_dash_left)}개, 오른쪽 {len(self.frames_dash_right)}개")
            return True

        except Exception as e:
            print(f"⚠️ 아카무 리고 대쉬 스프라이트 시트 로드 실패 (폴백 사용): {e}")
            self.frames_dash_left = self.frames_left[:2] if len(self.frames_left) >= 2 else self.frames_left.copy()
            self.frames_dash_right = self.frames_right[:2] if len(self.frames_right) >= 2 else self.frames_right.copy()
            return False

    def load_turn_sprite_sheet(self, path: str) -> bool:
        """
        방향 전환 스프라이트 시트 로드 및 프레임 분할

        스프라이트 시트 구조 (stage8movechange3.png):
        - 1열 (상단): 사용 안함
        - 2열 (하단): 4프레임 - 3번째(인덱스 2) 정면 프레임 1개만 사용

        Args:
            path: 방향 전환 스프라이트 시트 이미지 경로

        Returns:
            성공 여부
        """
        try:
            sprite_sheet = pygame.image.load(path).convert_alpha()
            sheet_width = sprite_sheet.get_width()
            sheet_height = sprite_sheet.get_height()

            print(f"🔄 아카무 리고 방향 전환 스프라이트 시트 로드: {sheet_width}x{sheet_height}")

            # 2행 구조 - 2열(하단)의 3번째 프레임 사용 (정면 이미지)
            row_height = sheet_height // 2  # 약 518px
            frame_width_float = sheet_width / 4  # 4프레임, 약 271px

            # 걷기 애니메이션과 동일한 마진 설정
            margin_x = 10
            margin_y = 10
            actual_frame_width = int(frame_width_float) - (margin_x * 2)
            actual_frame_height = row_height - (margin_y * 2)

            print(f"🔄 방향 전환 프레임 크기: {actual_frame_width}x{actual_frame_height} (2열 3번째 프레임)")

            # 2열 (하단) - 3번째 프레임 (인덱스 2, 정면) 1개만 추출
            self.frames_turn = []
            try:
                # 3번째 프레임 (인덱스 2)
                frame_x = int(frame_width_float * 2) + margin_x
                frame_y = row_height + margin_y  # 2열 하단
                frame_rect = pygame.Rect(frame_x, frame_y, actual_frame_width, actual_frame_height)

                # 경계 체크
                if frame_rect.right > sheet_width:
                    frame_rect.width = sheet_width - frame_rect.x
                if frame_rect.bottom > sheet_height:
                    frame_rect.height = sheet_height - frame_rect.y

                frame = sprite_sheet.subsurface(frame_rect).copy()
                # 기준 크기로 스케일링 (걷기 애니메이션과 동일)
                frame = pygame.transform.smoothscale(frame, (self.standard_frame_width, self.standard_frame_height))
                self.frames_turn.append(frame)
            except Exception as e:
                print(f"⚠️ 방향 전환 프레임 추출 실패: {e}")

            print(f"✅ 아카무 리고 방향 전환 프레임 로드 완료: {len(self.frames_turn)}개 (2열 3번째 정면 프레임)")
            return True

        except Exception as e:
            print(f"⚠️ 아카무 리고 방향 전환 스프라이트 시트 로드 실패: {e}")
            return False

    def load_defeat_sprite_sheet(self, path: str) -> bool:
        """
        패배 스프라이트 시트 로드 및 프레임 분할

        스프라이트 시트 구조 (stage8defeat.png):
        - 1열 (상단): 서있는/걷기 포즈 (사용 안함)
        - 2열 (하단): 4프레임 패배 애니메이션 (털썩 주저앉는 모습)

        Args:
            path: 패배 스프라이트 시트 이미지 경로

        Returns:
            성공 여부
        """
        try:
            sprite_sheet = pygame.image.load(path).convert_alpha()
            sheet_width = sprite_sheet.get_width()
            sheet_height = sprite_sheet.get_height()

            print(f"😵 아카무 리고 패배 스프라이트 시트 로드: {sheet_width}x{sheet_height}")

            # 2행 구조 - 2열(하단) 사용 (패배 포즈)
            row_height = sheet_height // 2
            frame_width = sheet_width // 4  # 4프레임

            # 마진 설정 (캐릭터 주변 여백 제거)
            margin_x = 10
            margin_y = 10
            actual_frame_width = frame_width - (margin_x * 2)
            actual_frame_height = row_height - (margin_y * 2)

            print(f"😵 패배 프레임 크기: {actual_frame_width}x{actual_frame_height}")

            # 2열 (하단) - 4프레임 추출
            self.frames_defeat = []
            row2_y = row_height + margin_y  # 2열 시작 Y좌표 + 상단 마진

            for i in range(4):
                try:
                    frame_x = i * frame_width + margin_x
                    frame_rect = pygame.Rect(frame_x, row2_y, actual_frame_width, actual_frame_height)

                    # 경계 체크
                    if frame_rect.right > sheet_width:
                        frame_rect.width = sheet_width - frame_rect.x
                    if frame_rect.bottom > sheet_height:
                        frame_rect.height = sheet_height - frame_rect.y

                    frame = sprite_sheet.subsurface(frame_rect).copy()
                    # 기준 크기로 스케일링 (모든 애니메이션 크기 통일)
                    frame = pygame.transform.smoothscale(frame, (self.standard_frame_width, self.standard_frame_height))
                    self.frames_defeat.append(frame)
                except Exception as e:
                    print(f"⚠️ 패배 프레임 {i} 추출 실패: {e}")

            print(f"✅ 아카무 리고 패배 프레임 로드 완료: {len(self.frames_defeat)}개")
            return True

        except Exception as e:
            print(f"⚠️ 아카무 리고 패배 스프라이트 시트 로드 실패: {e}")
            return False

    def load_victory_sprite_sheet(self, path: str) -> bool:
        """
        승리 스프라이트 시트 로드 및 프레임 분할

        스프라이트 시트 구조 (stage8win.png):
        - 1열 (상단): 서있는/걷기 포즈 (사용 안함)
        - 2열 (하단): 4프레임 승리 애니메이션 (기뻐하는 모습)

        Args:
            path: 승리 스프라이트 시트 이미지 경로

        Returns:
            성공 여부
        """
        try:
            sprite_sheet = pygame.image.load(path).convert_alpha()
            sheet_width = sprite_sheet.get_width()
            sheet_height = sprite_sheet.get_height()

            print(f"🎉 아카무 리고 승리 스프라이트 시트 로드: {sheet_width}x{sheet_height}")

            # 2행 구조 - 2열(하단) 사용 (승리 포즈)
            row_height = sheet_height // 2
            frame_width = sheet_width // 4  # 4프레임

            # 마진 설정 (캐릭터 주변 여백 제거)
            margin_x = 10
            margin_y = 10
            actual_frame_width = frame_width - (margin_x * 2)
            actual_frame_height = row_height - (margin_y * 2)

            print(f"🎉 승리 프레임 크기: {actual_frame_width}x{actual_frame_height}")

            # 2열 (하단) - 4프레임 추출
            self.frames_victory = []
            row2_y = row_height + margin_y  # 2열 시작 Y좌표 + 상단 마진

            for i in range(4):
                try:
                    frame_x = i * frame_width + margin_x
                    frame_rect = pygame.Rect(frame_x, row2_y, actual_frame_width, actual_frame_height)

                    # 경계 체크
                    if frame_rect.right > sheet_width:
                        frame_rect.width = sheet_width - frame_rect.x
                    if frame_rect.bottom > sheet_height:
                        frame_rect.height = sheet_height - frame_rect.y

                    frame = sprite_sheet.subsurface(frame_rect).copy()
                    # 기준 크기로 스케일링 (모든 애니메이션 크기 통일)
                    frame = pygame.transform.smoothscale(frame, (self.standard_frame_width, self.standard_frame_height))
                    self.frames_victory.append(frame)
                except Exception as e:
                    print(f"⚠️ 승리 프레임 {i} 추출 실패: {e}")

            print(f"✅ 아카무 리고 승리 프레임 로드 완료: {len(self.frames_victory)}개")
            return True

        except Exception as e:
            print(f"⚠️ 아카무 리고 승리 스프라이트 시트 로드 실패: {e}")
            return False

    def trigger_victory(self):
        """승리 애니메이션 시작"""
        if not self.frames_victory:
            print("⚠️ 승리 프레임이 없음")
            return

        self.is_victorious = True
        self.victory_frame = 0
        self.victory_timer = 0.0
        self.victory_finished = False
        # 다른 애니메이션 상태 초기화
        self.is_hit = False
        self.is_dashing = False
        self.is_turning = False
        self.is_defeated = False
        print("🎉 아카무 리고 승리 애니메이션 시작")

    def trigger_defeat(self):
        """패배 애니메이션 시작"""
        if not self.frames_defeat:
            print("⚠️ 패배 프레임이 없음")
            return

        self.is_defeated = True
        self.defeat_frame = 0
        self.defeat_timer = 0.0
        self.defeat_finished = False
        # 다른 애니메이션 상태 초기화
        self.is_hit = False
        self.is_dashing = False
        self.is_turning = False
        print("😵 아카무 리고 패배 애니메이션 시작")

    def trigger_turn(self, from_direction: int, to_direction: int):
        """
        방향 전환 애니메이션 시작

        Args:
            from_direction: 전환 시작 방향 (-1: 왼쪽, 0: 정지, 1: 오른쪽)
            to_direction: 전환 목표 방향 (-1: 왼쪽, 0: 정지, 1: 오른쪽)
        """
        if not self.frames_turn or len(self.frames_turn) < 1:
            return  # 방향 전환 프레임이 없으면 무시

        if from_direction == to_direction:
            return  # 같은 방향이면 무시

        self.is_turning = True
        self.turn_timer = 0.0
        self.turn_from_direction = from_direction
        self.turn_to_direction = to_direction

        # 1프레임만 사용 (정면 이미지)
        self.turn_frame = 0

    def trigger_dash(self, direction: int):
        """
        대쉬 애니메이션 시작

        Args:
            direction: 대쉬 방향 (-1: 왼쪽, 1: 오른쪽)
        """
        self.is_dashing = True
        self.dash_frame = 0
        self.dash_timer = 0.0
        self.dash_direction = direction
        print(f"💨 아카무 리고 대쉬 애니메이션 시작 (방향: {'오른쪽' if direction == 1 else '왼쪽'})")

    def stop_dash(self):
        """대쉬 애니메이션 종료"""
        self.is_dashing = False
        self.dash_frame = 0
        self.dash_timer = 0.0

    def trigger_hit(self, ball_x: float, boss_x: float):
        """
        히트 애니메이션 시작

        Args:
            ball_x: 공의 X 좌표
            boss_x: 보스의 X 좌표
        """
        self.is_hit = True
        self.hit_frame = 0
        self.hit_timer = 0.0
        self.hit_direction = 1 if ball_x > boss_x else -1
        print(f"🥊 아카무 리고 히트 애니메이션 시작 (방향: {'오른쪽' if self.hit_direction == 1 else '왼쪽'})")

    def update(self, current_x: float, dt: float = 1/60):
        """
        애니메이션 업데이트

        Args:
            current_x: 현재 보스 X 좌표
            dt: 델타 타임 (초 단위)
        """
        # 패배 애니메이션 업데이트 (최최우선 - 패배 시 다른 모든 애니메이션 무시)
        if self.is_defeated:
            if not self.defeat_finished:
                self.defeat_timer += dt
                if self.defeat_timer >= self.defeat_animation_speed:
                    self.defeat_timer = 0.0
                    self.defeat_frame += 1
                    if self.defeat_frame >= self.defeat_total_frames:
                        if self.defeat_loop:
                            self.defeat_frame = 0  # 루프
                        else:
                            self.defeat_frame = self.defeat_total_frames - 1  # 마지막 프레임에서 멈춤
                            self.defeat_finished = True
            self.prev_x = current_x
            return  # 패배 중에는 다른 애니메이션 무시

        # 승리 애니메이션 업데이트 (최최우선 - 승리 시 다른 모든 애니메이션 무시)
        if self.is_victorious:
            if not self.victory_finished:
                self.victory_timer += dt
                if self.victory_timer >= self.victory_animation_speed:
                    self.victory_timer = 0.0
                    self.victory_frame += 1
                    if self.victory_frame >= self.victory_total_frames:
                        if self.victory_loop:
                            self.victory_frame = 0  # 루프
                        else:
                            self.victory_frame = self.victory_total_frames - 1  # 마지막 프레임에서 멈춤
                            self.victory_finished = True
            self.prev_x = current_x
            return  # 승리 중에는 다른 애니메이션 무시

        # 히트 애니메이션 업데이트 (최우선)
        if self.is_hit:
            self.hit_timer += dt
            if self.hit_timer >= self.hit_animation_speed:
                self.hit_timer = 0.0
                self.hit_frame += 1
                if self.hit_frame >= self.hit_total_frames:
                    self.is_hit = False
                    self.hit_frame = 0
            self.prev_x = current_x
            return

        # 대쉬 애니메이션 업데이트 (높은 우선순위)
        if self.is_dashing:
            self.dash_timer += dt
            if self.dash_timer >= self.dash_animation_speed:
                self.dash_timer = 0.0
                self.dash_frame = (self.dash_frame + 1) % self.dash_total_frames
            self.prev_x = current_x
            return

        # 방향 전환 애니메이션 업데이트
        if self.is_turning:
            self.turn_timer += dt
            # 1프레임만 사용: 0.15초 동안 정면 이미지 보여준 후 방향 전환
            turn_duration = 0.15  # 방향 전환 시 정면 이미지 표시 시간
            if self.turn_timer >= turn_duration:
                self.is_turning = False
                self.direction = self.turn_to_direction
                self.turn_timer = 0.0

            self.prev_x = current_x
            return

        # 이동 방향 감지
        dx = current_x - self.prev_x

        # 방향 전환 쿨다운 업데이트
        if self.direction_change_cooldown > 0:
            self.direction_change_cooldown -= dt

        # 이동량 누적
        self.movement_accumulator += dx

        # 데드존과 누적 이동량 체크로 떨림 방지
        if abs(dx) > 2.0:
            new_direction = 1 if dx > 0 else -1

            if new_direction != self.direction:
                if self.direction_change_cooldown <= 0 and abs(self.movement_accumulator) > 5.0:
                    if (self.movement_accumulator > 0 and new_direction == 1) or \
                       (self.movement_accumulator < 0 and new_direction == -1):
                        # 방향 전환 애니메이션 시작
                        if self.frames_turn and len(self.frames_turn) >= 1:
                            self.trigger_turn(self.direction, new_direction)
                        else:
                            self.direction = new_direction
                        self.direction_change_cooldown = self.direction_change_threshold
                        self.movement_accumulator = 0

            # 이동 속도에 따라 애니메이션 속도 조절
            speed_factor = min(abs(dx) / 5.0, 2.0)
            adjusted_speed = self.animation_speed / max(speed_factor, 0.5)

            self.animation_timer += dt
            if self.animation_timer >= adjusted_speed:
                self.animation_timer = 0
                self.current_frame = (self.current_frame + 1) % self.total_frames
        else:
            if self.direction_change_cooldown <= 0:
                if abs(self.movement_accumulator) < 3.0:
                    # 정지 상태로 전환 (전환 애니메이션 사용)
                    if self.direction != 0 and self.frames_turn and len(self.frames_turn) >= 1:
                        self.trigger_turn(self.direction, 0)
                    else:
                        self.direction = 0
                    self.current_frame = 0
                    self.animation_timer = 0
                self.movement_accumulator *= 0.8

        self.prev_x = current_x

    def _build_scaled_cache(self, scale_size: tuple):
        """스케일된 프레임 캐시 생성"""
        need_full_rebuild = (scale_size != self._cached_scale_size)
        need_hit_rebuild = (self.frames_hit_left and not self._scaled_frames_hit_left) or \
                           (self.frames_hit_right and not self._scaled_frames_hit_right)
        need_dash_rebuild = (self.frames_dash_left and not self._scaled_frames_dash_left) or \
                            (self.frames_dash_right and not self._scaled_frames_dash_right)
        need_turn_rebuild = (self.frames_turn and not self._scaled_frames_turn)
        need_defeat_rebuild = (self.frames_defeat and not self._scaled_frames_defeat)
        need_victory_rebuild = (self.frames_victory and not self._scaled_frames_victory)

        if not need_full_rebuild and not need_hit_rebuild and not need_dash_rebuild and not need_turn_rebuild and not need_defeat_rebuild and not need_victory_rebuild:
            return

        self._cached_scale_size = scale_size

        if need_full_rebuild:
            self._scaled_frames_left = []
            for frame in self.frames_left:
                scaled = pygame.transform.smoothscale(frame, scale_size)
                self._scaled_frames_left.append(scaled)

            self._scaled_frames_right = []
            for frame in self.frames_right:
                scaled = pygame.transform.smoothscale(frame, scale_size)
                self._scaled_frames_right.append(scaled)

            if self.idle_frame:
                self._scaled_idle_frame = pygame.transform.smoothscale(self.idle_frame, scale_size)

        if need_full_rebuild or need_hit_rebuild:
            self._scaled_frames_hit_left = []
            for frame in self.frames_hit_left:
                scaled = pygame.transform.smoothscale(frame, scale_size)
                self._scaled_frames_hit_left.append(scaled)

            self._scaled_frames_hit_right = []
            for frame in self.frames_hit_right:
                scaled = pygame.transform.smoothscale(frame, scale_size)
                self._scaled_frames_hit_right.append(scaled)

        if need_full_rebuild or need_dash_rebuild:
            self._scaled_frames_dash_left = []
            for frame in self.frames_dash_left:
                scaled = pygame.transform.smoothscale(frame, scale_size)
                self._scaled_frames_dash_left.append(scaled)

            self._scaled_frames_dash_right = []
            for frame in self.frames_dash_right:
                scaled = pygame.transform.smoothscale(frame, scale_size)
                self._scaled_frames_dash_right.append(scaled)

        if need_full_rebuild or need_turn_rebuild:
            self._scaled_frames_turn = []
            for frame in self.frames_turn:
                scaled = pygame.transform.smoothscale(frame, scale_size)
                self._scaled_frames_turn.append(scaled)

        if need_full_rebuild or need_defeat_rebuild:
            self._scaled_frames_defeat = []
            for frame in self.frames_defeat:
                scaled = pygame.transform.smoothscale(frame, scale_size)
                self._scaled_frames_defeat.append(scaled)

        if need_full_rebuild or need_victory_rebuild:
            self._scaled_frames_victory = []
            for frame in self.frames_victory:
                scaled = pygame.transform.smoothscale(frame, scale_size)
                self._scaled_frames_victory.append(scaled)

    def get_current_frame(self, scale_size: tuple = None) -> pygame.Surface:
        """
        현재 프레임 반환

        Args:
            scale_size: (width, height) 크기로 스케일링 (None이면 원본 크기)

        Returns:
            현재 애니메이션 프레임 서피스
        """
        if scale_size:
            self._build_scaled_cache(scale_size)

            # 패배 애니메이션 중이면 패배 프레임 반환 (최최우선)
            if self.is_defeated and self._scaled_frames_defeat:
                frame_idx = min(self.defeat_frame, len(self._scaled_frames_defeat) - 1)
                return self._scaled_frames_defeat[frame_idx]

            # 승리 애니메이션 중이면 승리 프레임 반환 (최최우선)
            if self.is_victorious and self._scaled_frames_victory:
                frame_idx = min(self.victory_frame, len(self._scaled_frames_victory) - 1)
                return self._scaled_frames_victory[frame_idx]

            # 히트 애니메이션 중이면 히트 프레임 반환 (최우선)
            if self.is_hit:
                if self.hit_direction == -1 and self._scaled_frames_hit_left:
                    return self._scaled_frames_hit_left[self.hit_frame % len(self._scaled_frames_hit_left)]
                elif self._scaled_frames_hit_right:
                    return self._scaled_frames_hit_right[self.hit_frame % len(self._scaled_frames_hit_right)]

            # 대쉬 애니메이션 중이면 대쉬 프레임 반환
            if self.is_dashing:
                if self.dash_direction == -1 and self._scaled_frames_dash_left:
                    return self._scaled_frames_dash_left[self.dash_frame % len(self._scaled_frames_dash_left)]
                elif self._scaled_frames_dash_right:
                    return self._scaled_frames_dash_right[self.dash_frame % len(self._scaled_frames_dash_right)]

            # 방향 전환 애니메이션 중이면 전환 프레임 반환
            if self.is_turning and self._scaled_frames_turn:
                frame_idx = self.turn_frame % len(self._scaled_frames_turn)
                return self._scaled_frames_turn[frame_idx]

            # 캐시된 프레임에서 가져오기
            if self.direction == -1 and self._scaled_frames_left:
                return self._scaled_frames_left[self.current_frame % len(self._scaled_frames_left)]
            elif self.direction == 1 and self._scaled_frames_right:
                return self._scaled_frames_right[self.current_frame % len(self._scaled_frames_right)]
            else:
                # 정지 상태 - 정면 프레임 사용 (1프레임만 있음)
                if self._scaled_frames_turn and len(self._scaled_frames_turn) >= 1:
                    return self._scaled_frames_turn[0]  # 정면 프레임 (인덱스 0)
                return self._scaled_idle_frame if self._scaled_idle_frame else self._scaled_frames_right[0]

        # 패배 애니메이션 중이면 패배 프레임 반환 (원본 크기, 최최우선)
        if self.is_defeated and self.frames_defeat:
            frame_idx = min(self.defeat_frame, len(self.frames_defeat) - 1)
            return self.frames_defeat[frame_idx]

        # 승리 애니메이션 중이면 승리 프레임 반환 (원본 크기, 최최우선)
        if self.is_victorious and self.frames_victory:
            frame_idx = min(self.victory_frame, len(self.frames_victory) - 1)
            return self.frames_victory[frame_idx]

        # 히트 애니메이션 중이면 히트 프레임 반환 (원본 크기, 최우선)
        if self.is_hit:
            if self.hit_direction == -1 and self.frames_hit_left:
                return self.frames_hit_left[self.hit_frame % len(self.frames_hit_left)]
            elif self.frames_hit_right:
                return self.frames_hit_right[self.hit_frame % len(self.frames_hit_right)]

        # 대쉬 애니메이션 중이면 대쉬 프레임 반환 (원본 크기)
        if self.is_dashing:
            if self.dash_direction == -1 and self.frames_dash_left:
                return self.frames_dash_left[self.dash_frame % len(self.frames_dash_left)]
            elif self.frames_dash_right:
                return self.frames_dash_right[self.dash_frame % len(self.frames_dash_right)]

        # 방향 전환 애니메이션 중이면 전환 프레임 반환 (원본 크기)
        if self.is_turning and self.frames_turn:
            frame_idx = self.turn_frame % len(self.frames_turn)
            return self.frames_turn[frame_idx]

        # 원본 크기 반환
        if self.direction == -1 and self.frames_left:
            return self.frames_left[self.current_frame % len(self.frames_left)]
        elif self.direction == 1 and self.frames_right:
            return self.frames_right[self.current_frame % len(self.frames_right)]
        else:
            # 정지 상태 - 정면 프레임 사용 (1프레임만 있음)
            if self.frames_turn and len(self.frames_turn) >= 1:
                return self.frames_turn[0]  # 정면 프레임 (인덱스 0)
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
_stage8_boss_sprite_instance = None


def get_stage8_boss_sprite() -> Stage8BossSprite:
    """
    Stage 8 보스 스프라이트 인스턴스 반환 (싱글톤)

    Returns:
        Stage8BossSprite 인스턴스
    """
    global _stage8_boss_sprite_instance

    if _stage8_boss_sprite_instance is None:
        _stage8_boss_sprite_instance = Stage8BossSprite()

    return _stage8_boss_sprite_instance


def init_stage8_boss_sprite(sprite_sheet_path: str = None) -> Stage8BossSprite:
    """
    Stage 8 보스 스프라이트 초기화

    Args:
        sprite_sheet_path: 스프라이트 시트 경로 (선택적)

    Returns:
        초기화된 Stage8BossSprite 인스턴스
    """
    global _stage8_boss_sprite_instance

    if sprite_sheet_path:
        _stage8_boss_sprite_instance = Stage8BossSprite(sprite_sheet_path)
    else:
        _stage8_boss_sprite_instance = Stage8BossSprite()

    return _stage8_boss_sprite_instance


def reset_stage8_boss_sprite():
    """Stage 8 보스 스프라이트 리셋"""
    global _stage8_boss_sprite_instance
    _stage8_boss_sprite_instance = None


# 테스트 코드
if __name__ == "__main__":
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("Stage 8 Boss (아카무 리고) Walking Animation Test")
    clock = pygame.time.Clock()

    # 스프라이트 초기화
    boss_sprite = init_stage8_boss_sprite()

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
                elif event.key == pygame.K_SPACE:
                    # 스페이스바로 히트 테스트
                    boss_sprite.trigger_hit(boss_x + 50, boss_x)

        # 키 입력으로 보스 이동
        keys = pygame.key.get_pressed()
        if keys[pygame.K_LEFT]:
            boss_vel = -5.0
        elif keys[pygame.K_RIGHT]:
            boss_vel = 5.0
        else:
            boss_vel *= 0.9

        boss_x += boss_vel
        boss_x = max(100, min(700, boss_x))

        # 애니메이션 업데이트
        boss_sprite.update(boss_x, dt)

        # 화면 그리기 (닌자 저택 배경색)
        screen.fill((30, 25, 22))

        # 보스 그리기
        boss_sprite.draw(screen, boss_x, boss_y, 150, 200)

        # 정보 표시
        font = pygame.font.Font(None, 36)
        info_text = f"Direction: {boss_sprite.direction}, Frame: {boss_sprite.current_frame}"
        text_surface = font.render(info_text, True, (255, 255, 255))
        screen.blit(text_surface, (10, 10))

        help_text = "Arrow keys to move, SPACE for hit, ESC to exit"
        help_surface = font.render(help_text, True, (200, 200, 200))
        screen.blit(help_surface, (10, 50))

        if boss_sprite.is_hit:
            hit_text = f"HIT! Frame: {boss_sprite.hit_frame}"
            hit_surface = font.render(hit_text, True, (255, 100, 100))
            screen.blit(hit_surface, (10, 90))

        pygame.display.flip()

    pygame.quit()
