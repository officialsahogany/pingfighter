"""
BossPong Main Entry Point
깔끔한 메인 진입점
"""

import pygame
import sys
from core.game_state import GameState
from core.events import EventManager, EventType, emit_event
from core.profiler import GameProfiler
from core.global_manager import GlobalManager
from ui.menus import MenuSystem
from ui.opening_system import get_opening_system
from ui.academy_ui import AcademyUI
from ui.network_ui import get_network_ui
from ui.settings_ui import get_settings_ui
from game_logic.collision import get_collision_system
from game_logic.physics import get_physics_system
from game_logic.skill_manager import get_skill_manager
from game_logic.item_manager import get_item_manager
from game_logic.scoring import get_scoring_system
from game_logic.round_manager import get_round_manager
from game_logic.stage_features import get_stage_features
from game_logic.balance_manager import get_balance_manager
from modes.academy import get_academy_mode
from modes.gacha import get_gacha_system
from managers.sound_manager import get_sound_manager
from managers.effects_manager import get_effects_manager
from managers.dash_manager import get_dash_manager
from entities.entity import get_entity_manager
from ai.boss_ai import BossAI
from ai.ai_difficulty import DynamicDifficulty
from ui.ui_manager import UIManager
from network.network_manager import get_network_manager, NetworkMode
from replay.replay_system import get_replay_manager
from achievement.achievement_system import get_achievement_manager
from config.settings_system import get_settings_manager
from core.error_handler import get_error_handler, safe_execute
from core.error_boundary import (
    get_boundary_manager, rendering_boundary, 
    gameplay_boundary, network_boundary
)
from game_logic.special_abilities import get_special_ability_manager
from game_logic.special_items import get_special_item_manager
from game_logic.perfect_timing import get_perfect_timing_manager
from game_logic.power_smashing import get_power_smashing_manager
from ai.boss_skills import get_boss_skill_manager, BossType


class BossPongGame:
    """메인 게임 클래스"""
    
    def __init__(self):
        """게임 초기화"""
        # Pygame 초기화
        pygame.init()
        
        # 시스템 초기화
        self.global_manager = GlobalManager.get_instance()
        self.global_manager.init_pygame_objects()
        
        self.game_state = GameState.get_instance()
        self.event_manager = EventManager.get_instance()
        
        # 화면 설정
        self.screen = self.global_manager.get('screen')
        self.clock = self.global_manager.get('clock')
        self.fps = self.global_manager.get('fps', 60)
        
        # 게임 시스템
        self.menu_system = MenuSystem(self.screen, 
                                     self.global_manager.get('WIDTH', 600),
                                     self.global_manager.get('HEIGHT', 750))
        self.opening_system = get_opening_system()
        self.collision_system = get_collision_system()
        self.physics_system = get_physics_system()
        self.skill_manager = get_skill_manager()
        self.item_manager = get_item_manager()
        self.scoring_system = get_scoring_system()
        self.round_manager = get_round_manager()
        self.stage_features = get_stage_features()
        self.balance_manager = get_balance_manager()
        self.sound_manager = get_sound_manager()
        self.effects_manager = get_effects_manager()
        self.dash_manager = get_dash_manager()
        self.entity_manager = get_entity_manager()
        self.academy_mode = get_academy_mode()
        self.gacha_system = get_gacha_system()
        self.academy_ui = AcademyUI(self.screen)
        self.network_ui = get_network_ui(self.screen)
        self.settings_ui = get_settings_ui(self.screen)
        self.network_manager = get_network_manager()
        self.replay_manager = get_replay_manager()
        self.achievement_manager = get_achievement_manager()
        self.settings_manager = get_settings_manager()
        
        # UI 매니저
        self.ui_manager = UIManager(self.screen)
        
        # AI 시스템
        self.boss_ai = None
        self.difficulty_manager = DynamicDifficulty()
        
        # 게임 오브젝트 초기화 (전역 매니저에 등록)
        self._init_game_objects()
        
        # 프로파일러
        self.profiler = GameProfiler(self.screen)
        self.profiler.enabled = False
        
        # 에러 처리 시스템
        self.error_handler = get_error_handler()
        self.boundary_manager = get_boundary_manager()
        
        # 특수 능력 매니저
        self.special_ability_manager = get_special_ability_manager()
        
        # 특수 아이템 매니저
        self.special_item_manager = get_special_item_manager()
        
        # 퍼펙트 타이밍 매니저
        self.perfect_timing_manager = get_perfect_timing_manager()
        
        # 파워 스매싱 매니저  
        self.power_smashing_manager = get_power_smashing_manager()
        
        # 보스 스킬 매니저
        self.boss_skill_manager = get_boss_skill_manager()
        
        # 게임 상태
        self.running = True
        
        # 시작 모드 설정 (개발/테스트 모드)
        import os
        if os.environ.get('BOSSPONG_QUICK_START') or '--quick' in sys.argv:
            # 바로 게임 시작
            self.current_mode = 'playing'
            self.start_stage(1)
        else:
            # 정상적인 시작 (오프닝)
            self.current_mode = 'opening'
            self.opening_system.start_opening()
        
        # 아카데미 스킬 효과 적용
        self._apply_academy_skills()
    
    def _init_game_objects(self):
        """게임 오브젝트 초기화"""
        import pygame
        WIDTH = self.global_manager.get('WIDTH', 600)
        HEIGHT = self.global_manager.get('HEIGHT', 750)
        
        # 공
        ball = pygame.Rect(WIDTH//2 - 5, HEIGHT//2 - 5, 10, 10)
        self.global_manager.set('BALL', ball)
        
        # 플레이어 패들
        player = pygame.Rect(WIDTH//2 - 50, HEIGHT - 60, 100, 10)
        self.global_manager.set('PLAYER', player)
        
        # 보스 패들
        boss = pygame.Rect(WIDTH//2 - 50, 50, 100, 10)
        self.global_manager.set('BOSS', boss)
        
        # 공 속도
        self.global_manager.set('ball_dx', 5)
        self.global_manager.set('ball_dy', 5)
        
        # 이벤트 핸들러 등록
        self.setup_event_handlers()
        
    def setup_event_handlers(self):
        """이벤트 핸들러 설정"""
        self.event_manager.subscribe(EventType.GAME_OVER, self.on_game_over)
        self.event_manager.subscribe(EventType.GAME_START, self.on_game_start)
        self.event_manager.subscribe(EventType.GAME_PAUSE, self.on_game_pause)
        self.event_manager.subscribe(EventType.GAME_RESUME, self.on_game_resume)
        self.event_manager.subscribe(EventType.MENU_OPENED, self.on_menu_opened)
        
        # 에러 이벤트 핸들러
        self.event_manager.subscribe(EventType.ERROR_OCCURRED, self.on_error_occurred)
        self.event_manager.subscribe(EventType.ROUND_RESTART, self.on_round_restart)
        
    def on_game_over(self, event):
        """게임 오버 처리"""
        self.current_mode = 'game_over'
        
    def on_game_start(self, event):
        """게임 시작 처리"""
        self.current_mode = 'playing'
        stage = event.data.get('stage', 1)
        self.start_stage(stage)
        
    def on_game_pause(self, event):
        """일시정지 처리"""
        self.game_state.set('paused', True)
        
    def on_game_resume(self, event):
        """재개 처리"""
        self.game_state.set('paused', False)
        
    def on_menu_opened(self, event):
        """메뉴 열림 처리"""
        menu_type = event.data.get('type')
        if menu_type == 'academy':
            self.academy_ui.open()
        elif menu_type == 'gacha':
            self.gacha_system.start_gacha()
    
    def on_error_occurred(self, event):
        """에러 발생 처리"""
        error = event.data.get('error')
        recovered = event.data.get('recovered')
        if error and not recovered:
            # 심각한 에러: 일시정지
            self.event_manager.emit(EventType.GAME_PAUSE)
    
    def on_round_restart(self, event):
        """라운드 재시작 처리"""
        # 현재 라운드 재시작
        if hasattr(self, 'round_manager'):
            self.round_manager.restart_round()
            self.physics_system.reset()
        
    def start_stage(self, stage: int):
        """스테이지 시작
        
        Args:
            stage: 스테이지 번호
        """
        # AI 초기화 (ML 모델 사용 가능시 ML AI 사용)
        from ai.boss_ai import StageSpecificBossAI
        use_ml = self.global_manager.get_setting('ml_ai_enabled', True)
        self.boss_ai = StageSpecificBossAI.create_boss(stage, use_ml)
        
        # 시스템 리셋
        self.physics_system.reset()
        self.skill_manager.reset()
        self.item_manager.reset()
        self.scoring_system.reset_stage()
        self.round_manager.reset()
        self.dash_manager.reset()
        self.effects_manager.clear()
        self.entity_manager.clear()
        
        # 난이도 설정
        difficulty = self.global_manager.get_setting('difficulty', 'normal')
        self.difficulty_manager.set_preset_difficulty(difficulty)
        
        # 스테이지 인트로 표시 (선택적)
        if stage > 1:  # 스테이지 2부터 인트로 표시
            self.opening_system.start_stage_intro(stage)
        
        # 스테이지 설정
        self.game_state.set('current_stage', stage)
        self.global_manager.set('current_stage', stage)
        self.scoring_system.set_stage_config(stage)
        self.round_manager.set_stage_config(stage)
        self.stage_features.set_stage(stage)
        
        # 라운드 시작
        self.round_manager.start_round()
        
        # 공 초기화
        self.physics_system.reset()
        
    def handle_events(self):
        """이벤트 처리"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
                
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    if self.current_mode == 'playing':
                        self.toggle_pause()
                    else:
                        self.current_mode = 'menu'
                        
                elif event.key == pygame.K_7:
                    # 프로파일러 토글
                    self.profiler.toggle_visibility()
                    
            # 오프닝 시스템에 이벤트 전달
            if self.current_mode == 'opening':
                if self.opening_system.handle_input(event):
                    # 오프닝 종료 후 메뉴로
                    self.current_mode = 'menu'
                # 개발 모드: 스페이스로 바로 게임 시작
                if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
                    self.current_mode = 'playing'
                    self.start_stage(1)
                    
            # 메뉴 시스템에 이벤트 전달
            elif self.current_mode == 'menu':
                # 빠른 시작: 스페이스바로 즉시 게임 시작
                if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
                    self.current_mode = 'playing'
                    self.start_stage(1)
                    return
                # 가챠 시스템이 활성화된 경우 우선 처리
                if self.gacha_system.is_active():
                    self.gacha_system.handle_input(event)
                # 아카데미 UI가 활성화된 경우
                elif self.academy_ui.active:
                    self.academy_ui.handle_event(event)
                # 네트워크 UI가 활성화된 경우
                elif self.network_ui.active:
                    self.network_ui.handle_event(event)
                # 설정 UI가 활성화된 경우
                elif self.settings_ui.active:
                    self.settings_ui.handle_event(event)
                else:
                    # 메뉴 시스템에 이벤트 전달
                    if hasattr(self.menu_system, 'handle_event'):
                        self.menu_system.handle_event(event)
                    
                    # 개발용 단축키
                    if event.type == pygame.KEYDOWN:
                        # G키로 가챠 시스템 직접 열기
                        if event.key == pygame.K_g:
                            self.gacha_system.start_gacha()
                        # A키로 아카데미 UI 열기
                        elif event.key == pygame.K_a:
                            self.academy_ui.open()
                        # N키로 네트워크 UI 열기
                        elif event.key == pygame.K_n:
                            self.network_ui.open()
                        # S키로 설정 UI 열기
                        elif event.key == pygame.K_s:
                            self.settings_ui.open()
                        # R키로 리플레이 토글
                        elif event.key == pygame.K_r:
                            if self.replay_manager.player.playing:
                                self.replay_manager.player.stop_playback()
                            else:
                                # 가장 최근 리플레이 재생
                                replays = self.replay_manager.get_replay_list()
                                if replays:
                                    self.replay_manager.player.load_replay(replays[0]['filename'])
                                    self.replay_manager.player.start_playback()
                
    def toggle_pause(self):
        """일시정지 토글"""
        paused = self.game_state.get('paused', False)
        if paused:
            self.event_manager.emit(EventType.GAME_RESUME)
        else:
            self.event_manager.emit(EventType.GAME_PAUSE)
            
    def update(self, dt: float):
        """게임 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 프로파일러 업데이트
        if hasattr(self.profiler, 'start_frame'):
            self.profiler.start_frame()
        
        # 일시정지 체크
        if self.game_state.get('paused', False):
            return
            
        # 모드별 업데이트
        if self.current_mode == 'opening':
            if self.opening_system.update(dt):
                # 오프닝 종료
                self.current_mode = 'menu'
                
        elif self.current_mode == 'menu':
            if hasattr(self.menu_system, 'update'):
                self.menu_system.update(dt)
            
            # 가챠 시스템 업데이트
            if self.gacha_system.is_active():
                self.gacha_system.update(dt)
            
            # 아카데미 UI 업데이트
            if self.academy_ui.active:
                self.academy_ui.update(dt)
            
            # 네트워크 UI 업데이트
            if self.network_ui.active:
                self.network_ui.update(dt)
            
            # 설정 UI 업데이트
            if self.settings_ui.active:
                self.settings_ui.update(dt)
            
        elif self.current_mode == 'playing':
            # 게임 로직 업데이트
            
            # 공 이동 업데이트 (원본처럼 직접 처리)
            ball_rect = self.global_manager.get('BALL')
            if ball_rect:
                ball_dx = self.global_manager.get('ball_dx', 5)
                ball_dy = self.global_manager.get('ball_dy', 5)
                ball_rect.x += ball_dx
                ball_rect.y += ball_dy
                
                # 벽 충돌
                if ball_rect.left <= 0 or ball_rect.right >= self.global_manager.get('WIDTH', 600):
                    self.global_manager.set('ball_dx', -ball_dx)
                    ball_dx = -ball_dx
                
                # 패들 충돌 체크
                player_rect = self.global_manager.get('PLAYER')
                boss_rect = self.global_manager.get('BOSS')
                
                if player_rect and ball_rect.colliderect(player_rect):
                    self.global_manager.set('ball_dy', -abs(ball_dy))
                    # 히트 위치에 따른 각도 조정
                    hit_pos = (ball_rect.centerx - player_rect.centerx) / (player_rect.width / 2)
                    self.global_manager.set('ball_dx', 8 * hit_pos)
                    self.scoring_system.add_score(10)
                    
                if boss_rect and ball_rect.colliderect(boss_rect):
                    self.global_manager.set('ball_dy', abs(ball_dy))
                    import random
                    self.global_manager.set('ball_dx', random.uniform(-8, 8))
                
                # 화면 밖으로 나간 경우
                if ball_rect.top <= 0:
                    # 플레이어 점수
                    self.scoring_system.add_score(50)
                    self.physics_system.reset()
                elif ball_rect.bottom >= self.global_manager.get('HEIGHT', 750):
                    # 보스 점수
                    self.physics_system.reset()
            
            self.physics_system.update(dt)
            self.check_collisions()
            
            # 스킬 및 아이템 업데이트
            self.skill_manager.update(dt)
            player_rect = self.global_manager.get('PLAYER')
            if player_rect:
                self.item_manager.update(dt, player_rect)
            
            # 대시 및 이펙트 업데이트
            self.dash_manager.update(dt)
            self.effects_manager.update(dt)
            self.entity_manager.update(dt)
            self.stage_features.update(dt)
            
            if self.boss_ai:
                self.update_boss_ai(dt)
                    
            # 플레이어 입력 처리
            self.handle_player_input()
            
            # 아이템 스폰 (임시 - 확률적으로)
            import random
            if random.random() < 0.001:  # 0.1% 확률
                self.item_manager.spawn_item()
            
        # 리플레이 업데이트
        self.replay_manager.update(dt)
        
        # 성취 체크
        self.achievement_manager.check_achievements()
        
        # 이벤트 큐 처리
        self.event_manager.process_queue()
        
        # 프로파일러 종료
        if hasattr(self.profiler, 'end_frame'):
            self.profiler.end_frame()
        
    @rendering_boundary
    def render(self):
        """화면 렌더링"""
        # 렌더링 경계 프레임 저장
        rendering_boundary_obj = self.boundary_manager.get_boundary('rendering')
        if rendering_boundary_obj:
            rendering_boundary_obj.save_frame(self.screen)
        
        # 화면 클리어
        self.screen.fill((0, 0, 0))
        
        # 모드별 렌더링
        if self.current_mode == 'opening':
            self.opening_system.render(self.screen)
            
        elif self.current_mode == 'menu':
            # 메뉴 렌더링
            if hasattr(self.menu_system, 'render'):
                self.menu_system.render(self.screen)
            
            # 가챠 시스템 렌더링
            if self.gacha_system.is_active():
                self.gacha_system.render(self.screen)
            
            # 아카데미 UI 렌더링
            if self.academy_ui.active:
                self.academy_ui.render(self.screen)
            
            # 네트워크 UI 렌더링
            if self.network_ui.active:
                self.network_ui.render(self.screen)
            
            # 설정 UI 렌더링
            if self.settings_ui.active:
                self.settings_ui.render(self.screen)
            
        elif self.current_mode == 'playing':
            # 배경 그리기
            self.draw_background()
            
            # 게임 오브젝트 그리기
            self.draw_game_objects()
            
            # UI 그리기
            self.draw_ui()
            
        # 프로파일러 오버레이
        if self.profiler.visible:
            self.profiler.render(self.screen)
            
        # 화면 업데이트
        pygame.display.flip()
        
    def run(self):
        """메인 게임 루프"""
        print("🎮 BossPong Starting...")
        print("📊 Architecture: Fully Modularized")
        print("✨ All systems ready!")
        
        while self.running:
            try:
                # 델타 타임 계산
                dt = self.clock.tick(self.fps) / 1000.0
                
                # 게임 루프
                self.handle_events()
                self.update(dt)
                self.render()
                
            except Exception as e:
                # 에러 처리
                if not self.error_handler.handle_error(e):
                    # 복구 실패: 게임 종료
                    print(f"❌ 치명적 에러: {e}")
                    self.running = False
            
        self.cleanup()
        
    @gameplay_boundary
    def check_collisions(self):
        """충돌 검사"""
        ball_rect = self.global_manager.get('BALL')
        player_rect = self.global_manager.get('PLAYER')
        boss_rect = self.global_manager.get('BOSS')
        
        if not ball_rect:
            return
            
        # 공 속도 가져오기
        ball_vel = [
            self.global_manager.get('ball_dx', 0),
            self.global_manager.get('ball_dy', 5)
        ]
        
        # 벽 충돌
        self.collision_system.check_ball_wall_collision(
            ball_rect, ball_vel, self.global_manager.get('WIDTH', 600)
        )
        
        # 패들 충돌
        if player_rect:
            hit = self.collision_system.check_ball_paddle_collision(
                ball_rect, player_rect, ball_vel, is_player=True
            )
            if hit:
                # 충돌 이펙트
                emit_event(EventType.COLLISION, {
                    'type': 'ball_paddle',
                    'position': (ball_rect.centerx, ball_rect.centery)
                })
        if boss_rect:
            hit = self.collision_system.check_ball_paddle_collision(
                ball_rect, boss_rect, ball_vel, is_player=False
            )
            if hit:
                # 충돌 이펙트
                emit_event(EventType.COLLISION, {
                    'type': 'ball_paddle',
                    'position': (ball_rect.centerx, ball_rect.centery)
                })
            
        # 득점 체크
        scorer = self.collision_system.check_ball_out_of_bounds(
            ball_rect, self.global_manager.get('HEIGHT', 750)
        )
        if scorer:
            self.handle_score(scorer)
            
    def handle_score(self, scorer: str):
        """득점 처리"""
        # 라운드 매니저를 통해 득점 처리
        round_ended = self.round_manager.check_score_update(scorer)
        
        # 공 리셋
        self.physics_system.reset()
        
        # 라운드가 끝났으면 잠시 대기
        if round_ended:
            # 라운드 종료 UI는 UIManager에서 처리
            self.ui_manager.show_round_end()
            
    @gameplay_boundary
    def update_boss_ai(self, dt: float):
        """보스 AI 업데이트"""
        boss_rect = self.global_manager.get('BOSS')
        player_rect = self.global_manager.get('PLAYER')
        if not boss_rect:
            return
            
        # 멀티플레이어 클라이언트 모드에서는 AI 업데이트 하지 않음
        if self.network_manager.mode == NetworkMode.CLIENT:
            # 원격 입력 처리
            remote_input = self.network_manager.get_remote_input()
            if remote_input:
                if remote_input.get('left'):
                    boss_rect.x -= 5 * dt * 60
                if remote_input.get('right'):
                    boss_rect.x += 5 * dt * 60
                # 화면 경계 체크
                boss_rect.x = max(0, min(self.global_manager.get('WIDTH', 600) - boss_rect.width, boss_rect.x))
            return
            
        # 더 상세한 게임 상태 정보
        game_state_dict = {
            'ball_position': self.physics_system.ball_position,
            'ball_velocity': self.physics_system.ball_velocity,
            'boss_x': boss_rect.centerx,
            'boss_y': boss_rect.centery,
            'player_x': player_rect.centerx if player_rect else 300,
            'player_y': player_rect.centery if player_rect else 650,
            'player_score': self.global_manager.get('player_score', 0),
            'boss_score': self.global_manager.get('boss_score', 0),
            'game_time': pygame.time.get_ticks() / 1000.0,
            'player_dashing': self.dash_manager.dash_active
        }
        
        # AI 전략 업데이트
        if hasattr(self.boss_ai, 'update_strategy'):
            self.boss_ai.update_strategy(game_state_dict)
        
        # 난이도 시스템 업데이트
        self.difficulty_manager.update(dt, game_state_dict)
        
        # 현재 난이도를 AI에 적용
        current_difficulty = self.difficulty_manager.get_current_difficulty()
        if hasattr(self.boss_ai, 'apply_difficulty'):
            self.boss_ai.apply_difficulty(current_difficulty)
        
        decision = self.boss_ai.make_decision(game_state_dict)
        
        # AI 결정 적용
        if decision['move'] != 0:
            boss_rect.x += decision['move'] * dt * 60
            # 화면 경계 체크
            boss_rect.x = max(0, min(self.global_manager.get('WIDTH', 600) - boss_rect.width, boss_rect.x))
            
        # 특수 능력 실행
        if decision.get('special'):
            self._execute_boss_special(decision['special'])
            
        # 액션 실행
        if decision.get('action'):
            self._execute_boss_action(decision['action'])
            
        # 특수 능력 매니저 업데이트
        self.special_ability_manager.update(dt)
        
        # 특수 아이템 매니저 업데이트
        self.special_item_manager.update(dt)
        
        # 퍼펙트 타이밍 매니저 업데이트
        self.perfect_timing_manager.update(dt)
        
        # 파워 스매싱 매니저 업데이트
        self.power_smashing_manager.update(dt)
        
        # 보스 스킬 매니저 업데이트
        self.boss_skill_manager.update(dt)
            
    def _execute_boss_special(self, special: str):
        """보스 특수 능력 실행"""
        if special == 'speed_boost':
            # 일시적 속도 증가
            emit_event(EventType.BOSS_SPECIAL, {'type': 'speed_boost'})
        elif special == 'curve_shot':
            # 커브 샷
            emit_event(EventType.BOSS_SPECIAL, {'type': 'curve_shot'})
        elif special == 'shield':
            # 실드 생성
            emit_event(EventType.BOSS_SPECIAL, {'type': 'shield'})
        elif special == 'power_shot':
            # 파워 샷
            emit_event(EventType.BOSS_SPECIAL, {'type': 'power_shot'})
            
    def _execute_boss_action(self, action: str):
        """보스 액션 실행"""
        if action == 'charge':
            # 차지 샷 준비
            emit_event(EventType.BOSS_ACTION, {'type': 'charge'})
        elif action == 'dash':
            # 대시
            emit_event(EventType.BOSS_ACTION, {'type': 'dash'})
            
    def handle_player_input(self):
        """플레이어 입력 처리"""
        keys = pygame.key.get_pressed()
        player_rect = self.global_manager.get('PLAYER')
        
        # 설정 매니저를 통해 키 바인딩 확인
        sm = self.settings_manager
        
        if not player_rect:
            return
            
        # 멀티플레이어 모드에서 입력 전송
        if self.network_manager.mode in [NetworkMode.HOST, NetworkMode.CLIENT]:
            input_data = {
                'left': keys[pygame.K_LEFT] or keys[pygame.K_a],
                'right': keys[pygame.K_RIGHT] or keys[pygame.K_d],
                'dash': keys[pygame.K_SPACE]
            }
            self.network_manager.send_input(input_data)
            
        # 대시 입력 처리
        self.dash_manager.handle_input(keys)
        
        # 이동 (대시 중이 아닐 때만)
        if not self.dash_manager.dash_active:
            speed = 8  # 고정 속도
            movement_mult = self.dash_manager.get_movement_multiplier()
            
            # 간단한 키 처리 (원본처럼)
            if keys[pygame.K_LEFT] or keys[pygame.K_a]:
                player_rect.x -= speed * movement_mult
            if keys[pygame.K_RIGHT] or keys[pygame.K_d]:
                player_rect.x += speed * movement_mult
            
        # 화면 경계 체크
        player_rect.x = max(0, min(self.global_manager.get('WIDTH', 600) - player_rect.width, player_rect.x))
        
        # 숫자 키로 아이템 사용 (1-6)
        for i in range(1, 7):
            if keys[pygame.K_1 + i - 1]:
                self.item_manager.use_active_item(i - 1)
        
        # Tab으로 슬롯 선택
        if keys[pygame.K_TAB]:
            current = self.item_manager.selected_slot_index
            self.item_manager.select_slot((current + 1) % len(self.item_manager.get_active_slots()))
        
        # Q키로 특수 아이템 테스트 (임시)
        if keys[pygame.K_q]:
            # 랜덤 특수 아이템 발동
            import random
            items = ['fireball', 'tears', 'grenade', 'molotov', 'wall', 'quake']
            item = random.choice(items)
            if item == 'fireball':
                self.special_item_manager.activate_fireball()
            elif item == 'tears':
                self.special_item_manager.activate_tears_of_pain()
            elif item == 'grenade':
                self.special_item_manager.activate_grenade()
            elif item == 'molotov':
                self.special_item_manager.activate_molotov()
            elif item == 'wall':
                self.special_item_manager.activate_wall()
            elif item == 'quake':
                self.special_item_manager.activate_quake()
        
    def draw_background(self):
        """배경 그리기"""
        bg = self.global_manager.get('CURRENT_BG')
        if bg:
            self.screen.blit(bg, (0, 0))
        else:
            # 기본 배경
            self.screen.fill((30, 100, 30))
            
    def draw_game_objects(self):
        """게임 오브젝트 그리기"""
        # 화면 흔들림 오프셋 가져오기
        shake_x, shake_y = self.effects_manager.get_screen_shake_offset()
        
        # 엔티티 렌더링 (벽, 아이템, 투사체 등)
        self.entity_manager.render(self.screen)
        
        # 보스 그리기
        boss_rect = self.global_manager.get('BOSS')
        if boss_rect:
            boss_img = self.global_manager.get('BOSS_IMG')
            if boss_img:
                self.screen.blit(boss_img, (boss_rect.x + shake_x, boss_rect.y + shake_y))
            else:
                pygame.draw.rect(self.screen, (255, 255, 255), 
                               (boss_rect.x + shake_x, boss_rect.y + shake_y, boss_rect.width, boss_rect.height))
                
        # 플레이어 그리기
        player_rect = self.global_manager.get('PLAYER')
        if player_rect:
            player_img = self.global_manager.get('PLAYER_IMG')
            if player_img:
                # 대시 회전 적용
                rotation = self.dash_manager.get_rotation_angle()
                if rotation != 0:
                    player_img = pygame.transform.rotate(player_img, rotation)
                img_rect = player_img.get_rect(center=(player_rect.centerx + shake_x, player_rect.centery + shake_y))
                self.screen.blit(player_img, img_rect)
            else:
                pygame.draw.rect(self.screen, (255, 255, 255), 
                               (player_rect.x + shake_x, player_rect.y + shake_y, player_rect.width, player_rect.height))
                
        # 공 그리기
        ball_rect = self.global_manager.get('BALL')
        if ball_rect:
            ball_img = self.global_manager.get('BALL_IMG')
            if ball_img:
                img_rect = ball_img.get_rect(center=(ball_rect.centerx + shake_x, ball_rect.centery + shake_y))
                self.screen.blit(ball_img, img_rect)
            else:
                pygame.draw.circle(self.screen, (255, 255, 255), 
                                 (ball_rect.centerx + shake_x, ball_rect.centery + shake_y), 
                                 ball_rect.width // 2)
        
        # 이펙트 렌더링
        self.effects_manager.render(self.screen)
        
        # 특수 능력 렌더링
        self.special_ability_manager.render(self.screen)
        
        # 특수 아이템 렌더링
        self.special_item_manager.render(self.screen)
        
        # 스테이지 특수 효과 렌더링
        self.stage_features.render(self.screen)
                
    def draw_ui(self):
        """UI 그리기"""
        font = self.global_manager.get('FONT')
        if not font:
            font = pygame.font.Font(None, 40)
            
        # 점수 표시
        score_text = self.scoring_system.get_score_text()
        rendered_text = font.render(score_text, True, (255, 255, 255))
        score_rect = rendered_text.get_rect(center=(self.global_manager.get('WIDTH', 600) // 2, 50))
        self.screen.blit(rendered_text, score_rect)
        
        # 라운드 상태 표시
        font_small = pygame.font.Font(None, 20)
        round_text = self.round_manager.get_stage_info()['name']
        rendered_round = font_small.render(f"Stage {self.round_manager.current_stage}: {round_text}", True, (200, 200, 200))
        self.screen.blit(rendered_round, (10, 10))
        
        # 메달 표시
        medal_text = font_small.render(f"Medals: {self.scoring_system.medal_score}", True, (255, 215, 0))
        self.screen.blit(medal_text, (self.global_manager.get('WIDTH', 600) - 100, 10))
        
        # 아이템 UI 그리기
        self._draw_item_ui()
        
        # 대시 UI 그리기
        self.dash_manager.render_ui(self.screen)
        
        # 화면 효과 렌더링 (최상위)
        self.effects_manager.render_screen_effects(self.screen)
        
    def _draw_item_ui(self):
        """아이템 UI 그리기"""
        # 액티브 아이템 슬롯
        slots = self.item_manager.get_active_slots()
        slot_size = 50
        slot_y = self.global_manager.get('HEIGHT', 750) - slot_size - 10
        
        for i, slot in enumerate(slots):
            x = 10 + i * (slot_size + 10)
            
            # 슬롯 배경
            pygame.draw.rect(self.screen, (50, 50, 50), (x, slot_y, slot_size, slot_size))
            
            # 아이템 색상으로 원 그리기
            pygame.draw.circle(self.screen, slot['color'], 
                             (x + slot_size // 2, slot_y + slot_size // 2), 
                             slot_size // 3)
            
            # 선택된 슬롯 강조
            if i == self.item_manager.selected_slot_index:
                pygame.draw.rect(self.screen, (255, 100, 100), 
                               (x - 2, slot_y - 2, slot_size + 4, slot_size + 4), 3)
            
            # 숫자 표시
            if i < 6:
                font = pygame.font.Font(None, 16)
                num_text = font.render(str(i + 1), True, (255, 255, 255))
                self.screen.blit(num_text, (x + 2, slot_y + 2))
        
        # 패시브 아이템 표시
        passive_items = self.item_manager.get_passive_items()
        if passive_items:
            y = 100
            for item in passive_items[:5]:  # 최대 5개만 표시
                pygame.draw.circle(self.screen, item['color'], (20, y), 8)
                y += 20
        
    def _apply_academy_skills(self):
        """아카데미 스킬 효과 적용"""
        effects = self.academy_mode.get_all_skill_effects()
        
        # 대시 관련 효과
        if 'dash_cooldown_reduction' in effects:
            self.dash_manager.dash_cooldown_time *= (1 - effects['dash_cooldown_reduction'])
        if 'dash_distance_increase' in effects:
            self.dash_manager.dash_speed *= (1 + effects['dash_distance_increase'])
        if 'extra_dash_tokens' in effects:
            self.dash_manager.dash_charges += int(effects['extra_dash_tokens'])
            
    def cleanup(self):
        """종료 처리"""
        print("\n👋 Thanks for playing BossPong!")
        
        # 에러 통계 출력
        error_stats = self.error_handler.get_error_stats()
        if error_stats['total_errors'] > 0:
            print(f"\n📊 에러 통계:")
            print(f"  총 에러: {error_stats['total_errors']}건")
            for category, count in error_stats['by_category'].items():
                print(f"  {category}: {count}건")
        
        # 아카데미 진행 상황 저장
        self.academy_mode.save_progress()
        
        # 성취 진행 상황 저장
        self.achievement_manager.save_progress()
        
        # 설정 저장
        self.settings_manager.save_settings()
        
        # 통계 저장
        if hasattr(self, 'difficulty_manager'):
            self.difficulty_manager.save_stats()
        
        # 네트워크 연결 종료
        if hasattr(self, 'network_manager'):
            self.network_manager.disconnect()
        
        # 사운드 정리
        if hasattr(self, 'sound_manager'):
            self.sound_manager.cleanup()
        
        # 시스템 정리
        self.global_manager.cleanup()
        
        # Pygame 종료
        pygame.quit()
        sys.exit()


def main():
    """메인 함수"""
    game = BossPongGame()
    game.run()


if __name__ == "__main__":
    main()