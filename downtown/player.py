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

        # 끼임 방지 시스템
        self.stuck_timer = 0
        self.stuck_threshold = 0.5  # 0.5초간 못 움직이면 끼인 것으로 판단
        self.last_position = (self.x, self.y)

        # 한글 키보드 지원을 위한 키 상태 (간소화)
        self.pressed_keys = set()  # 현재 눌린 모든 키코드
        self._scancode_map = {}    # 눌린 키의 scancode → pygame key 매핑

        # 이동키 매핑 (물리 위치 기준)
        self._movement_keys = {pygame.K_a, pygame.K_s, pygame.K_d, pygame.K_w}
        self._unicode_movement_map = {
            'ㅁ': pygame.K_a,  # A 키 위치
            'ㄴ': pygame.K_s,  # S 키 위치
            'ㅇ': pygame.K_d,  # D 키 위치
            'ㅈ': pygame.K_w   # W 키 위치
        }
        self._movement_scancode_map = self._build_movement_scancode_map()

    def handle_input(self, keys, dt):
        """입력 처리 (한글 키보드 지원 - WASD와 동일)"""
        if self.is_interacting:
            return

        # 이동 입력
        self.velocity_x = 0
        self.velocity_y = 0

        # 좌우 이동 (a = 왼쪽, d = 오른쪽)
        # pressed_keys에 저장된 한글 키도 함께 체크
        is_left = keys[pygame.K_LEFT] or keys[pygame.K_a] or (pygame.K_a in self.pressed_keys)
        is_right = keys[pygame.K_RIGHT] or keys[pygame.K_d] or (pygame.K_d in self.pressed_keys)

        if is_left:
            self.velocity_x = -self.speed
            self.direction = 1
        elif is_right:
            self.velocity_x = self.speed
            self.direction = 2

        # 상하 이동 (w = 위, s = 아래)
        is_up = keys[pygame.K_UP] or keys[pygame.K_w] or (pygame.K_w in self.pressed_keys)
        is_down = keys[pygame.K_DOWN] or keys[pygame.K_s] or (pygame.K_s in self.pressed_keys)

        if is_up:
            self.velocity_y = -self.speed
            self.direction = 3
        elif is_down:
            self.velocity_y = self.speed
            self.direction = 0

        # 대각선 이동 속도 정규화
        if self.velocity_x != 0 and self.velocity_y != 0:
            factor = 0.707  # 1/sqrt(2)
            self.velocity_x *= factor
            self.velocity_y *= factor

        self.is_moving = (self.velocity_x != 0 or self.velocity_y != 0)

    def _build_movement_scancode_map(self):
        """키보드 레이아웃과 무관한 물리 스캔코드 → pygame 키 매핑"""
        # SDL 기본 스캔코드 값 (레이아웃 무관)
        fallback_scancodes = {
            'SCANCODE_A': 4,
            'SCANCODE_S': 22,
            'SCANCODE_D': 7,
            'SCANCODE_W': 26,
        }

        scancode_map = {}
        for attr, keycode in [
            ("SCANCODE_A", pygame.K_a),
            ("SCANCODE_S", pygame.K_s),
            ("SCANCODE_D", pygame.K_d),
            ("SCANCODE_W", pygame.K_w),
        ]:
            sc_value = getattr(pygame, attr, None)
            if sc_value is None:
                sc_value = fallback_scancodes[attr]
            scancode_map[sc_value] = keycode
        return scancode_map

    def handle_movement_key_event(self, pressed, scancode=None, keycode=None, unicode_char=None):
        """레이아웃 상관없이 이동키 입력을 처리"""
        target_key = None

        # 1) 물리 스캔코드 우선 (한글/영문 모드와 무관하게 안정적)
        if scancode is not None and scancode in self._movement_scancode_map:
            target_key = self._movement_scancode_map[scancode]

        # 2) 유니코드 문자 매핑 (입력기가 유니코드를 제공하는 경우)
        if target_key is None and unicode_char:
            target_key = self._unicode_movement_map.get(unicode_char)

        # 3) 키코드 매핑 (영문 배열 등 일반 키 입력)
        if target_key is None and keycode in self._movement_keys:
            target_key = keycode

        if target_key is None:
            return  # 이동키가 아니면 무시

        if pressed:
            self.pressed_keys.add(target_key)
            # 스캔코드로 릴리즈 추적 (키보드 레이아웃 변화에도 안전)
            if scancode is not None:
                self._scancode_map[scancode] = target_key
        else:
            self.pressed_keys.discard(target_key)
            if scancode is not None:
                self._scancode_map.pop(scancode, None)

    def set_korean_key(self, key_char, pressed, scancode=None, keycode=None):
        """기존 호환용 래퍼 (한글 자모 / 스캔코드 모두 처리)"""
        self.handle_movement_key_event(pressed, scancode=scancode, keycode=keycode, unicode_char=key_char)

    def release_korean_key_by_scancode(self, scancode, keycode=None):
        """기존 호환용 래퍼 - 스캔코드 기반 릴리즈"""
        self.handle_movement_key_event(False, scancode=scancode, keycode=keycode)

    def update(self, dt, downtown_map):
        """업데이트"""
        if self.is_interacting:
            return

        # 현재 위치가 유효하지 않으면 즉시 탈출 시도
        if not self._is_current_position_valid(downtown_map):
            self._escape_from_stuck(downtown_map)
            return

        # 이동 처리
        moved = False
        if self.is_moving:
            new_x = self.x + self.velocity_x * dt * 60
            new_y = self.y + self.velocity_y * dt * 60

            # 충돌 체크 및 이동
            if self._can_move_to(new_x, self.y, downtown_map):
                self.x = new_x
                moved = True
            if self._can_move_to(self.x, new_y, downtown_map):
                self.y = new_y
                moved = True

            # 충돌 박스 업데이트
            self._update_collision_rect()

            # 발자국 파티클
            if moved:
                self._add_footstep_particle()

        # 끼임 감지: 움직이려 하는데 못 움직이면
        if self.is_moving and not moved:
            self.stuck_timer += dt
            if self.stuck_timer >= self.stuck_threshold:
                self._escape_from_stuck(downtown_map)
                self.stuck_timer = 0
        else:
            self.stuck_timer = 0

        # 애니메이션 업데이트
        self._update_animation(dt)

        # 시각 효과 업데이트
        self.glow_timer += dt
        self._update_particles(dt)

        # 상호작용 대상 확인
        self._check_interaction_targets(downtown_map)

    def _can_move_to(self, new_x, new_y, downtown_map):
        """이동 가능 여부 체크 - 실제 건물 크기에 맞춘 충돌 감지"""
        # 플레이어 충돌 박스 (실제 캐릭터 발 부분 기준 - 좁게)
        # 가로: 캐릭터 폭의 1/5 (약 38px) → half_w = 19px
        # 세로: 캐릭터 높이의 1/6 (약 32px) → half_h = 16px
        half_w = self.width // 5   # 약 38px 폭
        half_h = self.height // 6  # 약 32px 높이

        # 8개 포인트 체크 (4 코너 + 4 변 중점)
        check_points = [
            # 4 코너
            (new_x - half_w, new_y - half_h),  # 좌상
            (new_x + half_w, new_y - half_h),  # 우상
            (new_x - half_w, new_y + half_h),  # 좌하
            (new_x + half_w, new_y + half_h),  # 우하
            # 4 변 중점 (상하좌우 이동 시 건물 통과 방지)
            (new_x, new_y - half_h),           # 상단 중점
            (new_x, new_y + half_h),           # 하단 중점
            (new_x - half_w, new_y),           # 좌측 중점
            (new_x + half_w, new_y),           # 우측 중점
        ]

        for cx, cy in check_points:
            if not downtown_map.is_walkable(cx, cy):
                return False

        # 건물 렉트와 직접 충돌 체크 (마진 없이 실제 크기로)
        player_rect = pygame.Rect(
            new_x - half_w,
            new_y - half_h,
            half_w * 2,
            half_h * 2
        )

        for btype, rect in downtown_map.building_rects:
            # 건물 실제 크기 그대로 사용 (마진 없음)
            if player_rect.colliderect(rect):
                return False

        return True

    def _is_current_position_valid(self, downtown_map):
        """현재 위치가 유효한지 체크 (건물 안에 있는지)"""
        return self._can_move_to(self.x, self.y, downtown_map)

    def _escape_from_stuck(self, downtown_map):
        """끼인 상태에서 탈출"""
        # 스폰 포인트로 먼저 시도
        spawn_pos = downtown_map.get_spawn_pixel_pos()
        if self._can_move_to(spawn_pos[0], spawn_pos[1], downtown_map):
            self.x = float(spawn_pos[0])
            self.y = float(spawn_pos[1])
            self._update_collision_rect()
            return

        # 주변 타일 탐색 (나선형으로)
        for radius in range(1, 10):
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    if abs(dx) != radius and abs(dy) != radius:
                        continue  # 나선형 가장자리만

                    test_x = self.x + dx * TILE_SIZE
                    test_y = self.y + dy * TILE_SIZE

                    if self._can_move_to(test_x, test_y, downtown_map):
                        self.x = test_x
                        self.y = test_y
                        self._update_collision_rect()
                        return

        # 최후의 수단: 맵 하단 중앙으로 강제 이동
        from .constants import MAP_WIDTH, MAP_HEIGHT
        self.x = float(MAP_WIDTH * TILE_SIZE // 2)
        self.y = float((MAP_HEIGHT - 2) * TILE_SIZE)
        self._update_collision_rect()

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
        """상호작용 가능한 대상 확인 - 입구 기반 건물 감지"""
        self.interaction_target = None

        # 좁은 상호작용 범위 (건물에 가까이 가야 함)
        close_range = INTERACTION_RANGE * 0.8  # 32픽셀 (40 * 0.8)

        # 방향에 따른 전방 체크 위치
        check_x = self.x
        check_y = self.y

        if self.direction == 0:  # 아래
            check_y += close_range
        elif self.direction == 1:  # 왼쪽
            check_x -= close_range
        elif self.direction == 2:  # 오른쪽
            check_x += close_range
        elif self.direction == 3:  # 위
            check_y -= close_range

        # 건물 체크 - 전방 위치에서만
        building_type, building_rect = downtown_map.get_building_at(check_x, check_y)

        # 건물을 찾았으면, 입구 방향인지 확인
        if building_type and building_rect:
            # 건물 입구는 아래쪽 (건물 하단 1/3 영역)
            entrance_zone = pygame.Rect(
                building_rect.left,
                building_rect.bottom - building_rect.height // 3,  # 하단 1/3
                building_rect.width,
                building_rect.height // 3
            )

            # 플레이어가 입구 영역 근처에 있고, 건물을 향해 있는지 확인
            player_point = (int(self.x), int(self.y))

            # 입구 영역과의 거리 체크 (좀 더 가까워야 함)
            entrance_dist = 9999
            if entrance_zone.collidepoint(player_point):
                entrance_dist = 0
            else:
                # 입구 영역과 가장 가까운 점까지의 거리
                closest_x = max(entrance_zone.left, min(self.x, entrance_zone.right))
                closest_y = max(entrance_zone.top, min(self.y, entrance_zone.bottom))
                entrance_dist = math.sqrt((self.x - closest_x)**2 + (self.y - closest_y)**2)

            # 입구 근처에 있고 (close_range 이내), 위쪽을 보고 있을 때만 상호작용
            if entrance_dist <= close_range and self.direction == 3:  # 위쪽 방향
                self.interaction_target = {
                    'type': 'building',
                    'building_type': building_type,
                    'rect': building_rect
                }

        # 건물을 못 찾았으면 기존 로직: 가장 가까운 입구 찾기
        if not self.interaction_target:
            closest_entrance_dist = float('inf')
            closest_building = None

            for btype, rect in downtown_map.building_rects:
                # 건물 입구 영역 (하단 1/3)
                entrance_zone = pygame.Rect(
                    rect.left,
                    rect.bottom - rect.height // 3,
                    rect.width,
                    rect.height // 3
                )

                # 입구까지의 거리
                closest_x = max(entrance_zone.left, min(self.x, entrance_zone.right))
                closest_y = max(entrance_zone.top, min(self.y, entrance_zone.bottom))
                dist = math.sqrt((self.x - closest_x)**2 + (self.y - closest_y)**2)

                # 가까운 입구이고, 위쪽을 보고 있을 때
                if dist < closest_entrance_dist and dist <= close_range and self.direction == 3:
                    closest_entrance_dist = dist
                    closest_building = (btype, rect)

            if closest_building:
                self.interaction_target = {
                    'type': 'building',
                    'building_type': closest_building[0],
                    'rect': closest_building[1]
                }

        # 출구 체크 (좁은 범위로 축소)
        exit_pos = downtown_map.get_exit_pixel_pos()
        dist_to_exit = math.sqrt((self.x - exit_pos[0])**2 + (self.y - exit_pos[1])**2)
        if dist_to_exit < close_range:  # 건물과 동일한 좁은 범위
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

        # 상호작용 표시 (하단 UI에서 처리하므로 머리 위 표시 제거)

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
        """상호작용 프롬프트 표시 (스페이스바)"""
        # 프롬프트 배경
        prompt_y = y - self.height - 25

        # 깜빡이는 효과
        alpha = int(150 + 100 * math.sin(self.glow_timer * 5))

        # 스페이스바 모양 키 표시
        prompt_w = 60
        prompt_h = 24
        prompt_surf = pygame.Surface((prompt_w, prompt_h), pygame.SRCALPHA)
        pygame.draw.rect(prompt_surf, (*Colors.UI_PRIMARY, alpha),
                        (0, 0, prompt_w, prompt_h), border_radius=6)
        pygame.draw.rect(prompt_surf, (*Colors.TEXT_WHITE, alpha),
                        (0, 0, prompt_w, prompt_h), 2, border_radius=6)

        screen.blit(prompt_surf, (x - prompt_w // 2, prompt_y))

        # 스페이스바 내부 선 (키캡 느낌)
        line_y = prompt_y + prompt_h // 2
        line_start = x - prompt_w // 2 + 10
        line_end = x + prompt_w // 2 - 10
        pygame.draw.line(screen, (*Colors.TEXT_WHITE, alpha),
                        (line_start, line_y), (line_end, line_y), 2)

    def check_building_click(self, mouse_pos, camera_offset, downtown_map):
        """마우스 클릭으로 건물 상호작용 체크

        Args:
            mouse_pos: (x, y) 화면 좌표
            camera_offset: (offset_x, offset_y) 카메라 오프셋
            downtown_map: DowntownMap 인스턴스

        Returns:
            건물 정보 딕셔너리 또는 None
        """
        # 화면 좌표를 월드 좌표로 변환
        # camera_offset은 카메라의 월드 좌표이므로 더해야 함
        world_x = mouse_pos[0] + camera_offset[0]
        world_y = mouse_pos[1] + camera_offset[1]

        # 클릭한 위치에 건물이 있는지 확인
        building_type, building_rect = downtown_map.get_building_at(world_x, world_y)

        if not building_type or not building_rect:
            return None

        # 플레이어가 건물에 가까운지 확인 (상호작용 범위)
        # 플레이어 중심점
        player_center_x = self.x
        player_center_y = self.y

        # 건물 중심점
        building_center_x = building_rect.centerx
        building_center_y = building_rect.centery

        # 거리 계산
        distance = math.sqrt(
            (player_center_x - building_center_x) ** 2 +
            (player_center_y - building_center_y) ** 2
        )

        # 상호작용 범위 체크 (건물 크기에 따라 조정)
        # 건물의 대각선 길이의 절반 + 여유 공간
        building_radius = math.sqrt(building_rect.width**2 + building_rect.height**2) / 2
        max_interaction_distance = building_radius + INTERACTION_RANGE * 2  # 80픽셀 추가 여유

        if distance > max_interaction_distance:
            return None  # 너무 멀리 있음

        # 건물 정보 반환
        return {
            'type': 'building',
            'building_type': building_type,
            'building_rect': building_rect,
            'distance': distance
        }

    def set_position(self, x, y):
        """위치 설정"""
        self.x = float(x)
        self.y = float(y)
        self._update_collision_rect()
