# downtown/player.py
# 번화가 플레이어 캐릭터
# 선택한 캐릭터(스매셔, 코만도, 발토르)의 이미지 연동

import pygame
import math
from .constants import (
    PLAYER_SIZE, PLAYER_SPEED, PLAYER_ANIMATION_SPEED,
    TILE_SIZE, INTERACTION_RANGE, Colors
)
from .character_sprites import (
    load_character_sprite, get_directional_sprite, get_character_display_name
)

class DowntownPlayer:
    """
    번화가에서의 플레이어 캐릭터
    - 상하좌우 이동
    - 건물/NPC와 상호작용
    - 애니메이션
    """

    def __init__(self, x, y, character_type="smasher"):
        # 위치
        self.x = float(x)
        self.y = float(y)
        self.target_x = self.x
        self.target_y = self.y

        # 크기
        self.width = PLAYER_SIZE
        self.height = PLAYER_SIZE

        # 이동
        self.speed = PLAYER_SPEED
        self.velocity_x = 0
        self.velocity_y = 0
        self.is_moving = False

        # 방향 (0: 하, 1: 좌, 2: 우, 3: 상)
        self.direction = 0

        # 애니메이션
        self.animation_frame = 0
        self.animation_timer = 0

        # 캐릭터 스프라이트 시스템
        self.character_type = character_type
        self.sprite = load_character_sprite(character_type)
        self.sprite_flipped = None  # 좌우 반전 캐시
        if self.sprite:
            self.sprite_flipped = pygame.transform.flip(self.sprite, True, False)
            # 스프라이트 크기에 맞춰 캐릭터 크기 조정
            self.width = self.sprite.get_width()
            self.height = self.sprite.get_height()

        # 상호작용
        self.interaction_target = None
        self.is_interacting = False

        # 시각 효과
        self.glow_timer = 0
        self.footstep_particles = []

        # 충돌 박스 (약간 작게)
        self.collision_rect = pygame.Rect(
            self.x - self.width // 4,
            self.y - self.height // 4,
            self.width // 2,
            self.height // 2
        )

    def handle_input(self, keys, dt):
        """입력 처리"""
        if self.is_interacting:
            return

        # 이동 입력
        self.velocity_x = 0
        self.velocity_y = 0

        if keys[pygame.K_LEFT] or keys[pygame.K_a]:
            self.velocity_x = -self.speed
            self.direction = 1
        elif keys[pygame.K_RIGHT] or keys[pygame.K_d]:
            self.velocity_x = self.speed
            self.direction = 2

        if keys[pygame.K_UP] or keys[pygame.K_w]:
            self.velocity_y = -self.speed
            self.direction = 3
        elif keys[pygame.K_DOWN] or keys[pygame.K_s]:
            self.velocity_y = self.speed
            self.direction = 0

        # 대각선 이동 속도 정규화
        if self.velocity_x != 0 and self.velocity_y != 0:
            factor = 0.707  # 1/sqrt(2)
            self.velocity_x *= factor
            self.velocity_y *= factor

        self.is_moving = (self.velocity_x != 0 or self.velocity_y != 0)

    def update(self, dt, downtown_map):
        """업데이트"""
        if self.is_interacting:
            return

        # 이동 처리
        if self.is_moving:
            new_x = self.x + self.velocity_x * dt * 60
            new_y = self.y + self.velocity_y * dt * 60

            # 충돌 체크 및 이동
            if self._can_move_to(new_x, self.y, downtown_map):
                self.x = new_x
            if self._can_move_to(self.x, new_y, downtown_map):
                self.y = new_y

            # 충돌 박스 업데이트
            self._update_collision_rect()

            # 발자국 파티클
            self._add_footstep_particle()

        # 애니메이션 업데이트
        self._update_animation(dt)

        # 시각 효과 업데이트
        self.glow_timer += dt
        self._update_particles(dt)

        # 상호작용 대상 확인
        self._check_interaction_targets(downtown_map)

    def _can_move_to(self, new_x, new_y, downtown_map):
        """이동 가능 여부 체크"""
        # 4개 코너 체크
        half_w = self.width // 4
        half_h = self.height // 4

        corners = [
            (new_x - half_w, new_y - half_h),
            (new_x + half_w, new_y - half_h),
            (new_x - half_w, new_y + half_h),
            (new_x + half_w, new_y + half_h),
        ]

        for cx, cy in corners:
            if not downtown_map.is_walkable(cx, cy):
                return False

        return True

    def _update_collision_rect(self):
        """충돌 박스 업데이트"""
        self.collision_rect.x = self.x - self.width // 4
        self.collision_rect.y = self.y - self.height // 4

    def _update_animation(self, dt):
        """애니메이션 업데이트"""
        if self.is_moving:
            self.animation_timer += dt
            if self.animation_timer >= PLAYER_ANIMATION_SPEED:
                self.animation_timer = 0
                self.animation_frame = (self.animation_frame + 1) % 4
        else:
            self.animation_frame = 0

    def _add_footstep_particle(self):
        """발자국 파티클 추가"""
        if len(self.footstep_particles) < 20 and self.animation_frame % 2 == 0:
            particle = {
                'x': self.x + (random_offset := (hash(str(self.x + self.y)) % 10 - 5)),
                'y': self.y + self.height // 2,
                'life': 0.5,
                'alpha': 100
            }
            self.footstep_particles.append(particle)

    def _update_particles(self, dt):
        """파티클 업데이트"""
        for p in self.footstep_particles[:]:
            p['life'] -= dt
            p['alpha'] = int(p['life'] * 200)
            if p['life'] <= 0:
                self.footstep_particles.remove(p)

    def _check_interaction_targets(self, downtown_map):
        """상호작용 가능한 대상 확인"""
        self.interaction_target = None

        # 방향에 따른 상호작용 위치
        check_x = self.x
        check_y = self.y

        offset = INTERACTION_RANGE
        if self.direction == 0:  # 아래
            check_y += offset
        elif self.direction == 1:  # 왼쪽
            check_x -= offset
        elif self.direction == 2:  # 오른쪽
            check_x += offset
        elif self.direction == 3:  # 위
            check_y -= offset

        # 건물 체크
        building_type, building_rect = downtown_map.get_building_at(check_x, check_y)
        if building_type:
            self.interaction_target = {
                'type': 'building',
                'building_type': building_type,
                'rect': building_rect
            }

        # 출구 체크
        exit_pos = downtown_map.get_exit_pixel_pos()
        dist_to_exit = math.sqrt((self.x - exit_pos[0])**2 + (self.y - exit_pos[1])**2)
        if dist_to_exit < INTERACTION_RANGE * 1.5:
            self.interaction_target = {
                'type': 'exit',
                'position': exit_pos
            }

    def interact(self):
        """상호작용 실행"""
        if self.interaction_target:
            self.is_interacting = True
            return self.interaction_target
        return None

    def end_interaction(self):
        """상호작용 종료"""
        self.is_interacting = False

    def get_rect(self):
        """플레이어 렉트"""
        return pygame.Rect(
            self.x - self.width // 2,
            self.y - self.height // 2,
            self.width,
            self.height
        )

    def draw(self, screen, camera_offset=(0, 0)):
        """플레이어 그리기"""
        draw_x = self.x - camera_offset[0]
        draw_y = self.y - camera_offset[1]

        # 발자국 파티클
        for p in self.footstep_particles:
            px = p['x'] - camera_offset[0]
            py = p['y'] - camera_offset[1]
            surf = pygame.Surface((8, 4), pygame.SRCALPHA)
            pygame.draw.ellipse(surf, (100, 100, 100, p['alpha']), (0, 0, 8, 4))
            screen.blit(surf, (px - 4, py - 2))

        # 그림자 (캐릭터 크기의 40% 너비, 적절한 높이)
        shadow_w = int(self.width * 0.4)
        shadow_h = int(shadow_w * 0.3)  # 납작한 타원형
        shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 60),
                          (0, 0, shadow_w, shadow_h))
        screen.blit(shadow_surf,
                   (draw_x - shadow_w // 2, draw_y + self.height // 4))

        # 플레이어 본체 (임시 - 나중에 스프라이트로 대체)
        self._draw_player_sprite(screen, draw_x, draw_y)

        # 상호작용 표시
        if self.interaction_target:
            self._draw_interaction_prompt(screen, draw_x, draw_y)

    def _draw_player_sprite(self, screen, x, y):
        """플레이어 스프라이트 그리기 - 실제 캐릭터 이미지 사용"""
        # 걷기 애니메이션 (상하 바운스)
        offset_y = 0
        if self.is_moving:
            bounce = math.sin(self.animation_frame * math.pi / 2) * 3
            offset_y = -abs(bounce)

        # 스프라이트가 있으면 실제 캐릭터 이미지 사용
        if self.sprite:
            # 방향에 따른 스프라이트 선택
            if self.direction == 1:  # 왼쪽
                current_sprite = self.sprite_flipped
            else:  # 오른쪽, 위, 아래 - 기본 방향
                current_sprite = self.sprite

            # 스프라이트 그리기
            sprite_x = x - self.width // 2
            sprite_y = y - self.height // 2 + offset_y
            screen.blit(current_sprite, (sprite_x, sprite_y))
        else:
            # 폴백: 기존 도형 렌더링
            self._draw_placeholder_sprite(screen, x, y, offset_y)

    def _draw_placeholder_sprite(self, screen, x, y, offset_y):
        """폴백용 임시 스프라이트 (이미지 로드 실패 시)"""
        # 몸통
        body_color = Colors.NEON_CYAN
        head_color = (255, 220, 180)

        # 몸통 (타원)
        body_rect = pygame.Rect(
            x - self.width // 3,
            y - self.height // 4 + offset_y,
            self.width * 2 // 3,
            self.height // 2
        )
        pygame.draw.ellipse(screen, body_color, body_rect)
        pygame.draw.ellipse(screen, Colors.TEXT_WHITE, body_rect, 2)

        # 머리
        head_rect = pygame.Rect(
            x - self.width // 4,
            y - self.height // 2 + offset_y,
            self.width // 2,
            self.height // 3
        )
        pygame.draw.ellipse(screen, head_color, head_rect)
        pygame.draw.ellipse(screen, (200, 180, 150), head_rect, 1)

        # 눈 (방향에 따라)
        eye_offset_x = 0
        if self.direction == 1:  # 왼쪽
            eye_offset_x = -5
        elif self.direction == 2:  # 오른쪽
            eye_offset_x = 5

        eye_y = y - self.height // 3 + offset_y

        if self.direction != 3:  # 위쪽이 아닐 때만 눈 표시
            # 왼쪽 눈
            pygame.draw.circle(screen, (40, 40, 40),
                             (int(x - 6 + eye_offset_x), int(eye_y)), 3)
            # 오른쪽 눈
            pygame.draw.circle(screen, (40, 40, 40),
                             (int(x + 6 + eye_offset_x), int(eye_y)), 3)

    def _draw_interaction_prompt(self, screen, x, y):
        """상호작용 프롬프트 표시"""
        # 프롬프트 배경
        prompt_y = y - self.height - 20

        # 깜빡이는 효과
        alpha = int(150 + 100 * math.sin(self.glow_timer * 5))

        # 키 표시 (Z키)
        prompt_surf = pygame.Surface((40, 30), pygame.SRCALPHA)
        pygame.draw.rect(prompt_surf, (*Colors.UI_PRIMARY, alpha),
                        (0, 0, 40, 30), border_radius=5)
        pygame.draw.rect(prompt_surf, (*Colors.TEXT_WHITE, alpha),
                        (0, 0, 40, 30), 2, border_radius=5)

        screen.blit(prompt_surf, (x - 20, prompt_y))

        # Z 텍스트
        font = pygame.font.Font(None, 24)
        z_text = font.render("Z", True, Colors.TEXT_WHITE)
        screen.blit(z_text, (x - 5, prompt_y + 5))

    def set_position(self, x, y):
        """위치 설정"""
        self.x = float(x)
        self.y = float(y)
        self._update_collision_rect()
