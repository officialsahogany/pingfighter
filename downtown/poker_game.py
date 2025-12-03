"""
포커 게임 모듈 - 1:1 텍사스 홀덤 (프리미엄 버전)
플레이어 vs 딜러 (골드 베팅)
고퀄리티 카드 애니메이션 & 프리미엄 UI
"""

import pygame
import pygame.freetype
import pygame.gfxdraw
import random
import math
import os
import sys
import time

# 리소스 경로 함수
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)


# ============================================
# BGM 관리
# ============================================
class PokerBGM:
    """포커 게임 BGM 관리자"""
    _instance = None
    _previous_music = None  # 이전 BGM 상태 저장
    _previous_pos = 0  # 이전 BGM 재생 위치

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def __init__(self):
        self.bgm_path = None
        self.is_playing = False
        self._init_bgm_path()

    def _init_bgm_path(self):
        """BGM 경로 초기화"""
        # downtown 폴더 기준으로 상위의 bgm 폴더 참조
        try:
            current_dir = os.path.dirname(os.path.abspath(__file__))
            parent_dir = os.path.dirname(current_dir)
            bgm_path = os.path.join(parent_dir, "bgm", "pokerbgm.wav")

            if os.path.exists(bgm_path):
                self.bgm_path = bgm_path
            else:
                # PyInstaller 환경
                self.bgm_path = resource_path(os.path.join("..", "bgm", "pokerbgm.wav"))
        except Exception as e:
            print(f"[PokerBGM] BGM 경로 초기화 실패: {e}")
            self.bgm_path = None

    def start(self, volume=0.5):
        """포커 BGM 시작 (이전 BGM 상태 저장)"""
        if not self.bgm_path or not os.path.exists(self.bgm_path):
            print(f"[PokerBGM] BGM 파일을 찾을 수 없습니다: {self.bgm_path}")
            return False

        try:
            # 현재 재생 중인 음악 상태 저장
            if pygame.mixer.music.get_busy():
                PokerBGM._previous_music = True
                try:
                    PokerBGM._previous_pos = pygame.mixer.music.get_pos()
                except:
                    PokerBGM._previous_pos = 0
            else:
                PokerBGM._previous_music = False

            # 포커 BGM 재생
            pygame.mixer.music.load(self.bgm_path)
            pygame.mixer.music.set_volume(volume)
            pygame.mixer.music.play(-1)  # 무한 반복
            self.is_playing = True
            print(f"[PokerBGM] BGM 재생 시작: {self.bgm_path}")
            return True
        except Exception as e:
            print(f"[PokerBGM] BGM 재생 실패: {e}")
            return False

    def stop(self):
        """포커 BGM 정지"""
        if self.is_playing:
            try:
                pygame.mixer.music.fadeout(500)  # 0.5초 페이드아웃
                self.is_playing = False
                print("[PokerBGM] BGM 정지")
            except Exception as e:
                print(f"[PokerBGM] BGM 정지 실패: {e}")

    def set_volume(self, volume):
        """볼륨 설정 (0.0 ~ 1.0)"""
        try:
            pygame.mixer.music.set_volume(max(0.0, min(1.0, volume)))
        except:
            pass


# ============================================
# 파티클 시스템
# ============================================
class Particle:
    """개별 파티클"""
    def __init__(self, x, y, color, vx=0, vy=0, life=1.0, size=3, gravity=0):
        self.x = x
        self.y = y
        self.color = color
        self.vx = vx
        self.vy = vy
        self.life = life
        self.max_life = life
        self.size = size
        self.gravity = gravity
        self.alpha = 255

    def update(self, dt):
        self.x += self.vx * dt
        self.y += self.vy * dt
        self.vy += self.gravity * dt
        self.life -= dt
        self.alpha = int(255 * (self.life / self.max_life))
        return self.life > 0

    def draw(self, screen):
        if self.alpha <= 0:
            return
        color = (*self.color[:3], max(0, min(255, self.alpha)))
        surf = pygame.Surface((self.size * 2, self.size * 2), pygame.SRCALPHA)
        pygame.draw.circle(surf, color, (self.size, self.size), self.size)
        screen.blit(surf, (self.x - self.size, self.y - self.size))


class ParticleSystem:
    """파티클 시스템 관리자"""
    def __init__(self):
        self.particles = []

    def emit_sparkle(self, x, y, count=10, color=(255, 215, 0)):
        """반짝이는 파티클"""
        for _ in range(count):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(50, 150)
            vx = math.cos(angle) * speed
            vy = math.sin(angle) * speed
            size = random.uniform(2, 5)
            life = random.uniform(0.5, 1.2)
            self.particles.append(Particle(x, y, color, vx, vy, life, size, gravity=100))

    def emit_win(self, x, y):
        """승리 이펙트"""
        colors = [(255, 215, 0), (255, 255, 100), (255, 200, 50), (255, 255, 200)]
        for _ in range(50):
            color = random.choice(colors)
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(100, 300)
            vx = math.cos(angle) * speed
            vy = math.sin(angle) * speed
            size = random.uniform(3, 8)
            life = random.uniform(1.0, 2.0)
            self.particles.append(Particle(x, y, color, vx, vy, life, size, gravity=200))

    def emit_card_trail(self, x, y, color=(200, 200, 255)):
        """카드 이동 트레일"""
        for _ in range(3):
            ox = random.uniform(-5, 5)
            oy = random.uniform(-5, 5)
            size = random.uniform(2, 4)
            self.particles.append(Particle(x + ox, y + oy, color, 0, 0, 0.3, size))

    def update(self, dt):
        self.particles = [p for p in self.particles if p.update(dt)]

    def draw(self, screen):
        for p in self.particles:
            p.draw(screen)


# ============================================
# 카드 애니메이션 시스템
# ============================================
class CardAnimation:
    """카드 애니메이션"""
    def __init__(self, card, start_x, start_y, end_x, end_y, duration=0.5,
                 delay=0, flip_at=0.5, start_face_up=False):
        self.card = card
        self.start_x = start_x
        self.start_y = start_y
        self.end_x = end_x
        self.end_y = end_y
        self.current_x = start_x
        self.current_y = start_y
        self.duration = duration
        self.delay = delay
        self.elapsed = 0
        self.flip_at = flip_at  # 카드 뒤집는 타이밍 (0~1)
        self.start_face_up = start_face_up
        self.flipped = start_face_up
        self.completed = False
        self.scale = 0.3  # 시작 스케일
        self.rotation = random.uniform(-30, 30)  # 시작 회전
        self.target_rotation = 0

    def update(self, dt):
        if self.completed:
            return True

        if self.delay > 0:
            self.delay -= dt
            return False

        self.elapsed += dt
        progress = min(1.0, self.elapsed / self.duration)

        # 이징 함수 (ease-out cubic)
        eased = 1 - pow(1 - progress, 3)

        # 위치 보간
        self.current_x = self.start_x + (self.end_x - self.start_x) * eased
        self.current_y = self.start_y + (self.end_y - self.start_y) * eased

        # 스케일 보간
        self.scale = 0.3 + 0.7 * eased

        # 회전 보간
        self.rotation = self.rotation + (self.target_rotation - self.rotation) * eased

        # 카드 뒤집기
        if not self.flipped and progress >= self.flip_at:
            self.flipped = True
            self.card.face_up = not self.start_face_up or self.card.face_up

        if progress >= 1.0:
            self.completed = True
            self.current_x = self.end_x
            self.current_y = self.end_y
            self.scale = 1.0
            self.rotation = 0

        return self.completed


# ============================================
# 카드 클래스 (프리미엄)
# ============================================
class Card:
    """개별 카드 - 프리미엄 디자인"""
    SUITS = ['hearts', 'diamonds', 'clubs', 'spades']
    RANKS = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']

    SUIT_SYMBOLS = {
        'hearts': '♥',
        'diamonds': '♦',
        'clubs': '♣',
        'spades': '♠'
    }

    SUIT_COLORS = {
        'hearts': (220, 40, 40),
        'diamonds': (220, 40, 40),
        'clubs': (25, 25, 25),
        'spades': (25, 25, 25)
    }

    # 페이스 카드 이름
    FACE_NAMES = {
        'J': 'JACK',
        'Q': 'QUEEN',
        'K': 'KING',
        'A': 'ACE'
    }

    def __init__(self, suit, rank):
        self.suit = suit
        self.rank = rank
        self.face_up = True
        self.hover = False
        self.selected = False

    def get_value(self):
        """카드 숫자 값 (A=14, K=13, Q=12, J=11)"""
        if self.rank == 'A':
            return 14
        elif self.rank == 'K':
            return 13
        elif self.rank == 'Q':
            return 12
        elif self.rank == 'J':
            return 11
        else:
            return int(self.rank)

    def __str__(self):
        return f"{self.rank}{self.SUIT_SYMBOLS[self.suit]}"

    def __repr__(self):
        return self.__str__()


# ============================================
# 덱 클래스
# ============================================
class Deck:
    """52장 카드 덱"""
    def __init__(self):
        self.cards = []
        self.reset()

    def reset(self):
        """덱 초기화 및 셔플"""
        self.cards = []
        for suit in Card.SUITS:
            for rank in Card.RANKS:
                self.cards.append(Card(suit, rank))
        self.shuffle()

    def shuffle(self):
        """카드 섞기"""
        random.shuffle(self.cards)

    def deal(self, face_up=True):
        """카드 한 장 뽑기"""
        if self.cards:
            card = self.cards.pop()
            card.face_up = face_up
            return card
        return None


# ============================================
# 패 랭킹 평가
# ============================================
class HandEvaluator:
    """포커 패 평가"""

    HIGH_CARD = 1
    ONE_PAIR = 2
    TWO_PAIR = 3
    THREE_OF_KIND = 4
    STRAIGHT = 5
    FLUSH = 6
    FULL_HOUSE = 7
    FOUR_OF_KIND = 8
    STRAIGHT_FLUSH = 9
    ROYAL_FLUSH = 10

    HAND_NAMES = {
        1: "하이 카드",
        2: "원 페어",
        3: "투 페어",
        4: "트리플",
        5: "스트레이트",
        6: "플러시",
        7: "풀 하우스",
        8: "포카드",
        9: "스트레이트 플러시",
        10: "로얄 플러시"
    }

    @staticmethod
    def evaluate(cards):
        if len(cards) < 5:
            return (0, [], "카드 부족")

        best_hand = None
        best_rank = 0
        best_tiebreaker = []

        from itertools import combinations

        # 디버그: 모든 카드 출력
        print(f"[HAND EVAL] 전체 카드 ({len(cards)}장): {[str(c) for c in cards]}")
        print(f"[HAND EVAL] 무늬: {[c.suit for c in cards]}")

        for combo in combinations(cards, 5):
            rank, tiebreaker = HandEvaluator._evaluate_five(list(combo))
            # 디버그: 플러시 이상일 때 출력
            if rank >= 6:
                print(f"[HAND EVAL] 조합: {[str(c) for c in combo]} -> 랭크 {rank}")
            if rank > best_rank or (rank == best_rank and tiebreaker > best_tiebreaker):
                best_rank = rank
                best_tiebreaker = tiebreaker
                best_hand = combo

        print(f"[HAND EVAL] 최종 결과: 랭크 {best_rank} = {HandEvaluator.HAND_NAMES.get(best_rank, '알 수 없음')}")
        return (best_rank, best_tiebreaker, HandEvaluator.HAND_NAMES.get(best_rank, "알 수 없음"))

    @staticmethod
    def _evaluate_five(cards):
        values = sorted([c.get_value() for c in cards], reverse=True)
        suits = [c.suit for c in cards]

        is_flush = len(set(suits)) == 1
        is_straight = HandEvaluator._is_straight(values)

        value_counts = {}
        for v in values:
            value_counts[v] = value_counts.get(v, 0) + 1

        counts = sorted(value_counts.values(), reverse=True)

        if is_flush and is_straight and values == [14, 13, 12, 11, 10]:
            return (HandEvaluator.ROYAL_FLUSH, values)

        if is_flush and is_straight:
            return (HandEvaluator.STRAIGHT_FLUSH, values)

        if counts == [4, 1]:
            four_val = [v for v, c in value_counts.items() if c == 4][0]
            kicker = [v for v, c in value_counts.items() if c == 1][0]
            return (HandEvaluator.FOUR_OF_KIND, [four_val, kicker])

        if counts == [3, 2]:
            three_val = [v for v, c in value_counts.items() if c == 3][0]
            two_val = [v for v, c in value_counts.items() if c == 2][0]
            return (HandEvaluator.FULL_HOUSE, [three_val, two_val])

        if is_flush:
            return (HandEvaluator.FLUSH, values)

        if is_straight:
            return (HandEvaluator.STRAIGHT, values)

        if counts == [3, 1, 1]:
            three_val = [v for v, c in value_counts.items() if c == 3][0]
            kickers = sorted([v for v, c in value_counts.items() if c == 1], reverse=True)
            return (HandEvaluator.THREE_OF_KIND, [three_val] + kickers)

        if counts == [2, 2, 1]:
            pairs = sorted([v for v, c in value_counts.items() if c == 2], reverse=True)
            kicker = [v for v, c in value_counts.items() if c == 1][0]
            return (HandEvaluator.TWO_PAIR, pairs + [kicker])

        if counts == [2, 1, 1, 1]:
            pair_val = [v for v, c in value_counts.items() if c == 2][0]
            kickers = sorted([v for v, c in value_counts.items() if c == 1], reverse=True)
            return (HandEvaluator.ONE_PAIR, [pair_val] + kickers)

        return (HandEvaluator.HIGH_CARD, values)

    @staticmethod
    def _is_straight(values):
        sorted_vals = sorted(set(values), reverse=True)
        if len(sorted_vals) != 5:
            return False

        if sorted_vals[0] - sorted_vals[4] == 4:
            return True

        if sorted_vals == [14, 5, 4, 3, 2]:
            return True

        return False


# ============================================
# 포커 게임 클래스
# ============================================
class PokerGame:
    """1:1 텍사스 홀덤 게임"""

    STATE_BETTING = 'betting'
    STATE_DEALING = 'dealing'      # 카드 딜링 애니메이션
    STATE_PREFLOP = 'preflop'
    STATE_FLOP_DEALING = 'flop_dealing'  # 플랍 딜링 애니메이션
    STATE_FLOP = 'flop'
    STATE_TURN_DEALING = 'turn_dealing'
    STATE_TURN = 'turn'
    STATE_RIVER_DEALING = 'river_dealing'
    STATE_RIVER = 'river'
    STATE_SHOWDOWN = 'showdown'
    STATE_GAME_OVER = 'game_over'

    def __init__(self, player_gold=1000, dealer_gold=None):
        self.deck = Deck()
        self.player_hand = []
        self.dealer_hand = []
        self.community_cards = []

        self.player_gold = player_gold
        self.pot = 0
        self.current_bet = 0
        self.min_bet = 10
        self.max_bet = 100  # 최대 판돈 제한

        # 딜러 베팅 시스템
        self.dealer_bet = 0  # 딜러가 추가로 베팅한 금액
        self.player_to_call = 0  # 플레이어가 콜하기 위해 내야 할 금액

        # 딜러 보유 골드 (랜덤 1000~3000G)
        if dealer_gold is None:
            self.dealer_gold = random.randint(1000, 3000)
        else:
            self.dealer_gold = dealer_gold
        self.initial_dealer_gold = self.dealer_gold  # 초기 딜러 골드 기록

        # 하우스 엣지 (카지노 수수료 5%)
        self.house_edge = 0.05

        # 연승 패널티 시스템
        self.player_win_streak = 0
        self.win_streak_penalty = 0.02  # 연승당 2% 추가 수수료

        # 딜러 파산 플래그
        self.dealer_bankrupt = False

        # 플로팅 텍스트 트리거용 (UI에서 읽어서 애니메이션 생성)
        self.pending_floating_texts = []  # [(text, type), ...] type: 'fee', 'win', 'lose'

        self.state = self.STATE_BETTING
        self.winner = None
        self.result_message = ""

        self.player_hand_result = None
        self.dealer_hand_result = None

        self.animation_timer = 0
        self.card_animations = []
        self.pending_cards = []

    def start_new_round(self):
        self.deck.reset()
        self.player_hand = []
        self.dealer_hand = []
        self.community_cards = []
        self.pot = 0
        self.current_bet = 0
        self.dealer_bet = 0
        self.player_to_call = 0
        self.state = self.STATE_BETTING
        self.winner = None
        self.result_message = ""
        self.player_hand_result = None
        self.dealer_hand_result = None
        self.card_animations = []
        self.pending_cards = []

    def place_bet(self, amount):
        if self.state != self.STATE_BETTING:
            return False

        amount = max(self.min_bet, min(amount, self.max_bet, self.player_gold))

        if amount > self.player_gold:
            return False

        self.current_bet = amount
        self.player_gold -= amount
        self.dealer_gold -= amount  # 딜러도 동일 금액 베팅
        self.pot = amount * 2

        self._start_deal_animation()
        return True

    def _start_deal_animation(self):
        """딜링 애니메이션 시작"""
        self.state = self.STATE_DEALING
        self.card_animations = []

        # 덱 위치 (화면 중앙 상단)
        deck_x = 400  # 화면 중앙
        deck_y = -100  # 화면 밖

        # 플레이어 카드 위치
        player_x1, player_y = 340, 380
        player_x2 = 410

        # 딜러 카드 위치
        dealer_x1, dealer_y = 340, 80
        dealer_x2 = 410

        # 카드 4장 뽑기 (플레이어 2장, 딜러 2장)
        cards = [
            self.deck.deal(True),   # 플레이어 1
            self.deck.deal(False),  # 딜러 1 (뒷면)
            self.deck.deal(True),   # 플레이어 2
            self.deck.deal(False),  # 딜러 2 (뒷면)
        ]

        # 애니메이션 설정
        positions = [
            (player_x1, player_y, True, 0.0),    # 플레이어 1, 딜레이 0
            (dealer_x1, dealer_y, False, 0.15),  # 딜러 1, 딜레이 0.15s
            (player_x2, player_y, True, 0.3),    # 플레이어 2
            (dealer_x2, dealer_y, False, 0.45),  # 딜러 2
        ]

        for i, (card, (end_x, end_y, face_up, delay)) in enumerate(zip(cards, positions)):
            anim = CardAnimation(
                card, deck_x, deck_y, end_x, end_y,
                duration=0.4, delay=delay,
                flip_at=0.7 if face_up else 1.1,  # 딜러 카드는 안 뒤집음
                start_face_up=False
            )
            self.card_animations.append(anim)

            # 카드 저장
            if i in [0, 2]:
                self.player_hand.append(card)
            else:
                self.dealer_hand.append(card)

    def _start_community_deal(self, count):
        """커뮤니티 카드 딜링"""
        deck_x = 400
        deck_y = -100

        # 커뮤니티 카드 위치 계산
        base_x = 200 + len(self.community_cards) * 75
        comm_y = 250

        for i in range(count):
            card = self.deck.deal(True)
            card.face_up = False  # 시작은 뒷면

            end_x = base_x + i * 75

            anim = CardAnimation(
                card, deck_x, deck_y, end_x, comm_y,
                duration=0.35, delay=i * 0.12,
                flip_at=0.6, start_face_up=False
            )
            self.card_animations.append(anim)
            self.pending_cards.append(card)

    def proceed_to_next_stage(self):
        if self.state == self.STATE_PREFLOP:
            self.state = self.STATE_FLOP_DEALING
            self._start_community_deal(3)

        elif self.state == self.STATE_FLOP:
            self.state = self.STATE_TURN_DEALING
            self._start_community_deal(1)

        elif self.state == self.STATE_TURN:
            self.state = self.STATE_RIVER_DEALING
            self._start_community_deal(1)

        elif self.state == self.STATE_RIVER:
            self._showdown()

    def _dealer_ai_decision(self):
        """딜러 AI: 예측 불가능한 혼합 전략"""
        import random

        # 딜러 핸드 + 커뮤니티 카드로 현재 패 평가
        if self.community_cards:
            dealer_cards = self.dealer_hand + self.community_cards
            hand_result = HandEvaluator.evaluate(dealer_cards)
            hand_rank = hand_result[0]
        else:
            # 프리플랍: 홀 카드만으로 평가
            hand_rank = self._evaluate_hole_cards()

        # 초기 베팅 기준으로 레이즈 범위 계산
        base_bet = self.current_bet if self.current_bet > 0 else self.min_bet
        min_raise = max(10, int(base_bet * 0.5))  # 최소: 베팅의 50%
        max_raise = int(base_bet * 2.0)  # 최대: 베팅의 200%

        # ===== 혼합 전략 선택 (매번 랜덤) =====
        strategy = random.choices(
            ['standard', 'slow_play', 'bluff', 'random'],
            weights=[40, 20, 20, 20]  # 40% 표준, 20% 슬로우플레이, 20% 블러핑, 20% 랜덤
        )[0]

        base_raise_chance = 0.0
        raise_multiplier = 0.5

        if strategy == 'standard':
            # === 전략 1: 표준 (패 강도에 비례) ===
            if hand_rank >= 8:
                base_raise_chance = 0.85
                raise_multiplier = random.uniform(1.2, 1.8)
            elif hand_rank >= 6:
                base_raise_chance = 0.7
                raise_multiplier = random.uniform(0.9, 1.4)
            elif hand_rank >= 4:
                base_raise_chance = 0.5
                raise_multiplier = random.uniform(0.6, 1.0)
            elif hand_rank >= 3:
                base_raise_chance = 0.35
                raise_multiplier = random.uniform(0.5, 0.8)
            elif hand_rank >= 2:
                base_raise_chance = 0.25
                raise_multiplier = random.uniform(0.4, 0.6)
            else:
                base_raise_chance = 0.1
                raise_multiplier = random.uniform(0.3, 0.5)

        elif strategy == 'slow_play':
            # === 전략 2: 슬로우 플레이 (강한 패 → 작게 베팅해서 유인) ===
            if hand_rank >= 6:  # 아주 강한 패
                base_raise_chance = 0.6  # 레이즈 확률 낮춤
                raise_multiplier = random.uniform(0.3, 0.5)  # 작게 베팅
            elif hand_rank >= 4:
                base_raise_chance = 0.4
                raise_multiplier = random.uniform(0.4, 0.6)
            elif hand_rank >= 2:
                base_raise_chance = 0.5  # 중간 패는 보통으로
                raise_multiplier = random.uniform(0.5, 0.8)
            else:
                base_raise_chance = 0.15
                raise_multiplier = random.uniform(0.3, 0.5)

        elif strategy == 'bluff':
            # === 전략 3: 블러핑 (약한 패 → 크게 베팅해서 폴드 유도) ===
            if hand_rank <= 2:  # 약한 패
                base_raise_chance = 0.7  # 높은 블러핑 확률
                raise_multiplier = random.uniform(1.0, 1.8)  # 크게 베팅
            elif hand_rank <= 4:
                base_raise_chance = 0.5
                raise_multiplier = random.uniform(0.8, 1.2)
            else:  # 강한 패는 오히려 조용히
                base_raise_chance = 0.4
                raise_multiplier = random.uniform(0.4, 0.7)

        else:  # random
            # === 전략 4: 완전 랜덤 (패와 무관) ===
            base_raise_chance = random.uniform(0.2, 0.7)
            raise_multiplier = random.uniform(0.4, 1.5)

        # 스테이지에 따른 조정 (후반부일수록 더 공격적)
        stage_multiplier = 1.0
        if self.state == self.STATE_TURN:
            stage_multiplier = 1.15
        elif self.state == self.STATE_RIVER:
            stage_multiplier = 1.3

        final_raise_chance = min(0.9, base_raise_chance * stage_multiplier)

        # 랜덤으로 레이즈 여부 결정
        if random.random() < final_raise_chance:
            # 베팅에 비례한 레이즈 금액 계산
            raise_amount = int(base_bet * raise_multiplier)
            raise_amount = max(min_raise, min(raise_amount, max_raise))

            # 플레이어 골드 고려 (플레이어가 콜할 수 있어야 함)
            raise_amount = min(raise_amount, self.player_gold)

            if raise_amount >= min_raise:
                return ('raise', raise_amount)

        return ('check', 0)

    def _evaluate_hole_cards(self):
        """홀 카드만으로 핸드 강도 평가 (프리플랍용)"""
        if len(self.dealer_hand) < 2:
            return 1

        card1, card2 = self.dealer_hand
        # 카드 값을 숫자로 변환 (get_value: 2~14, 여기서 0~12 범위로)
        rank1 = card1.get_value() - 2
        rank2 = card2.get_value() - 2

        # 포켓 페어
        if rank1 == rank2:
            return 3 + (rank1 / 12)  # 페어 + 높은 카드일수록 보너스

        # 높은 카드 (A, K, Q, J: rank >= 9 → value >= 11)
        high_count = sum(1 for r in [rank1, rank2] if r >= 9)

        # 수트 매치
        suited = card1.suit == card2.suit

        score = 1.0
        if high_count == 2:
            score = 2.5
        elif high_count == 1:
            score = 1.8

        if suited:
            score += 0.5

        # 연속 카드 (스트레이트 가능성)
        if abs(rank1 - rank2) == 1:
            score += 0.3

        return min(3, score)

    def dealer_action(self):
        """딜러의 액션 수행 (레이즈 또는 체크)"""
        action, amount = self._dealer_ai_decision()

        if action == 'raise' and amount > 0:
            # 딜러 골드가 부족하면 레이즈 금액 조정
            amount = min(amount, self.dealer_gold)
            if amount > 0:
                self.dealer_bet = amount
                self.player_to_call = amount
                self.dealer_gold -= amount  # 딜러 골드에서 차감
                self.pot += amount  # 딜러가 팟에 추가
                return ('raise', amount)

        self.dealer_bet = 0
        self.player_to_call = 0
        return ('check', 0)

    def fold(self):
        if self.state in [self.STATE_PREFLOP, self.STATE_FLOP, self.STATE_TURN, self.STATE_RIVER]:
            self.winner = 'dealer'
            self.result_message = "폴드! 딜러 승리"
            self.state = self.STATE_GAME_OVER
            return True
        return False

    def call(self):
        """플레이어가 콜 - 딜러 레이즈 금액만큼 지불"""
        if self.state in [self.STATE_PREFLOP, self.STATE_FLOP, self.STATE_TURN, self.STATE_RIVER]:
            # 딜러가 레이즈한 경우, 플레이어가 그 금액을 지불
            if self.player_to_call > 0:
                call_amount = min(self.player_to_call, self.player_gold)
                self.player_gold -= call_amount
                self.pot += call_amount
                self.current_bet += call_amount
                self.player_to_call = 0
                self.dealer_bet = 0

            self.proceed_to_next_stage()
            return True
        return False

    def get_call_amount(self):
        """현재 콜하기 위해 필요한 금액 반환"""
        return self.player_to_call

    def raise_bet(self, additional_amount):
        if self.state in [self.STATE_PREFLOP, self.STATE_FLOP, self.STATE_TURN, self.STATE_RIVER]:
            # 먼저 콜 금액이 있으면 그것도 지불
            total_amount = additional_amount + self.player_to_call

            # 딜러가 콜할 수 있는 금액 확인
            dealer_call = min(additional_amount, self.dealer_gold)

            if total_amount <= self.player_gold and dealer_call > 0:
                self.player_gold -= total_amount
                self.pot += total_amount  # 플레이어가 낸 금액

                # 딜러도 레이즈에 콜
                self.dealer_gold -= dealer_call
                self.pot += dealer_call

                self.current_bet += total_amount
                self.player_to_call = 0
                self.dealer_bet = 0
                return True
        return False

    def _showdown(self):
        for card in self.dealer_hand:
            card.face_up = True

        player_cards = self.player_hand + self.community_cards
        dealer_cards = self.dealer_hand + self.community_cards

        self.player_hand_result = HandEvaluator.evaluate(player_cards)
        self.dealer_hand_result = HandEvaluator.evaluate(dealer_cards)

        p_rank, p_tie, p_name = self.player_hand_result
        d_rank, d_tie, d_name = self.dealer_hand_result

        # 플레이어 승리 체크
        player_wins = False
        if p_rank > d_rank:
            player_wins = True
        elif p_rank == d_rank and p_tie > d_tie:
            player_wins = True

        if player_wins:
            self.winner = 'player'

            # 하우스 엣지 + 연승 패널티 계산
            total_fee_rate = self.house_edge + (self.player_win_streak * self.win_streak_penalty)
            total_fee_rate = min(total_fee_rate, 0.20)  # 최대 20% 제한

            fee = int(self.pot * total_fee_rate)
            win_amount = self.pot - fee

            # 플레이어가 팟에서 수수료 제외한 금액 획득
            # (딜러는 이미 place_bet에서 베팅금을 냈으므로 추가 차감 불필요)
            self.player_gold += win_amount

            # 연승 카운트 증가
            self.player_win_streak += 1

            # 실제 순이익 계산 (베팅금 제외)
            net_profit = win_amount - self.current_bet

            # 수수료 표시 및 플로팅 텍스트 트리거
            if fee > 0:
                self.result_message = f"승리! {p_name} (+{net_profit}G, 수수료 {fee}G)"
                # 수수료 차감 플로팅 텍스트 (플레이어 위치에서 발생)
                self.pending_floating_texts.append((f"-{fee}", 'fee', 'player'))
            else:
                self.result_message = f"승리! {p_name} (+{net_profit}G)"

            # 획득 골드 플로팅 텍스트 (플레이어 위치에서 발생)
            self.pending_floating_texts.append((f"+{net_profit}", 'win', 'player'))

            # 딜러 골드 감소 표시 (딜러 위치에서 발생)
            dealer_loss = self.pot - self.current_bet  # 딜러가 잃은 금액
            if dealer_loss > 0:
                self.pending_floating_texts.append((f"-{dealer_loss}", 'lose', 'dealer'))

            # 딜러 파산 체크
            if self.dealer_gold <= 0:
                self.dealer_gold = 0
                self.dealer_bankrupt = True
                self.result_message = f"🎉 딜러 파산! {p_name} (+{net_profit}G)"

        elif d_rank > p_rank or (d_rank == p_rank and d_tie > p_tie):
            self.winner = 'dealer'
            # 딜러가 팟 전체를 가져감 (딜러는 이미 베팅금을 냈으므로 팟 전체 획득)
            self.dealer_gold += self.pot
            self.player_win_streak = 0  # 연승 리셋
            self.result_message = f"패배... 딜러 {d_name}"

            # 플레이어 골드 감소 표시 (플레이어 위치)
            self.pending_floating_texts.append((f"-{self.current_bet}", 'lose', 'player'))
            # 딜러 골드 증가 표시 (딜러 위치)
            dealer_win = self.pot - self.current_bet  # 딜러 순이익
            if dealer_win > 0:
                self.pending_floating_texts.append((f"+{dealer_win}", 'win', 'dealer'))
        else:
            # 무승부 - 각자 베팅금 돌려받음
            self.winner = 'tie'
            self.player_gold += self.current_bet
            self.dealer_gold += self.current_bet
            self.result_message = f"무승부! {p_name}"

        self.state = self.STATE_SHOWDOWN

    def update(self, dt):
        self.animation_timer += dt

        # 애니메이션 업데이트
        all_completed = True
        for anim in self.card_animations:
            if not anim.update(dt):
                all_completed = False

        # 딜링 애니메이션 완료 체크
        if all_completed and self.card_animations:
            self.card_animations = []

            # 펜딩 카드를 커뮤니티에 추가
            for card in self.pending_cards:
                card.face_up = True
                self.community_cards.append(card)
            self.pending_cards = []

            # 상태 전환
            if self.state == self.STATE_DEALING:
                self.state = self.STATE_PREFLOP
                # 딜러가 먼저 액션 (레이즈 또는 체크)
                self.dealer_action()
            elif self.state == self.STATE_FLOP_DEALING:
                self.state = self.STATE_FLOP
                # 딜러가 먼저 액션
                self.dealer_action()
            elif self.state == self.STATE_TURN_DEALING:
                self.state = self.STATE_TURN
                # 딜러가 먼저 액션
                self.dealer_action()
            elif self.state == self.STATE_RIVER_DEALING:
                self.state = self.STATE_RIVER
                # 딜러가 먼저 액션
                self.dealer_action()


# ============================================
# 프리미엄 카드 렌더러
# ============================================
class PremiumCardRenderer:
    """고퀄리티 카드 렌더링"""

    def __init__(self):
        self.card_cache = {}
        self.back_cache = {}

    def draw_card(self, screen, card, x, y, width=70, height=98,
                  scale=1.0, rotation=0, face_up=None):
        """프리미엄 카드 그리기"""
        w = int(width * scale)
        h = int(height * scale)

        if w < 10 or h < 10:
            return

        # 표시할 면 결정
        show_face = card.face_up if face_up is None else face_up

        # 카드 서피스 생성
        card_surf = pygame.Surface((w, h), pygame.SRCALPHA)

        if show_face:
            self._draw_card_face(card_surf, card, w, h)
        else:
            self._draw_card_back(card_surf, w, h)

        # 회전 적용
        if rotation != 0:
            card_surf = pygame.transform.rotate(card_surf, rotation)

        # 그림자
        shadow_surf = pygame.Surface((w + 6, h + 6), pygame.SRCALPHA)
        pygame.draw.rect(shadow_surf, (0, 0, 0, 60), (4, 6, w, h), border_radius=8)
        screen.blit(shadow_surf, (x - 2, y - 1))

        # 카드 그리기
        screen.blit(card_surf, (x, y))

    def _draw_card_face(self, surf, card, w, h):
        """카드 앞면 - 클래식 솔리테어 스타일 (흰 배경, 중앙 큰 무늬 1개)"""
        # 흰색 배경
        surf.fill((255, 255, 255))

        # 둥근 모서리 테두리
        pygame.draw.rect(surf, (180, 180, 180), (0, 0, w, h), 2, border_radius=6)

        # 하트/다이아 = 빨간색, 클럽/스페이드 = 검은색
        is_red = card.suit in ['hearts', 'diamonds']
        suit_color = (200, 30, 30) if is_red else (30, 30, 30)
        symbol = Card.SUIT_SYMBOLS[card.suit]

        # === 통일된 배치 설정 (모든 문양 동일 적용) ===
        rank_size = int(w * 0.22)           # 랭크 폰트 크기
        small_suit_size = int(w * 0.16)     # 코너 작은 문양 크기

        # 공통 값
        margin_x = int(w * 0.08)            # 좌우 마진
        rank_height = int(h * 0.15)         # 랭크 텍스트 높이
        suit_offset_y = int(h * 0.20)       # 랭크 아래 문양까지의 간격

        # === 좌상단 (숫자 + 작은 문양) - 더 위로 ===
        top_margin_y = int(h * 0.01)        # 상단 마진 (미세하게 더 위로)
        rank_x = margin_x
        rank_y = top_margin_y
        self._draw_rank(surf, card.rank, rank_x, rank_y, suit_color, rank_size)

        # 작은 문양 위치 (랭크 중앙 아래에 정렬) - 미세하게 아래로
        suit_x = margin_x + (rank_size - small_suit_size) // 2
        suit_y = top_margin_y + suit_offset_y + int(h * 0.02)
        self._draw_suit_shape(surf, symbol,
                              suit_x + small_suit_size // 2,
                              suit_y + small_suit_size // 2,
                              small_suit_size, suit_color)

        # === 중앙 대형 문양 (모든 카드 동일) ===
        cx, cy = w // 2, h // 2
        large_size = int(w * 0.55)
        self._draw_suit_shape(surf, symbol, cx, cy, large_size, suit_color)

        # === 우하단 (숫자 + 작은 문양) ===
        bottom_margin_y = int(h * 0.03)     # 하단 마진
        bottom_margin_x = int(w * 0.03)     # 우측 마진 (더 오른쪽으로)

        # 10일 때 왼쪽으로 살짝 이동하여 중앙정렬
        rank_adjust_x = int(w * 0.03) if card.rank == '10' else 0

        rank_bottom_x = w - bottom_margin_x - rank_size - rank_adjust_x
        rank_bottom_y = h - bottom_margin_y - rank_height - int(h * 0.03)
        self._draw_rank(surf, card.rank, rank_bottom_x, rank_bottom_y, suit_color, rank_size, flip=True)

        # 작은 문양 위치 - 숫자 위에 (숫자와 x축 중앙정렬) - 숫자와 간격 좁힘
        bottom_suit_x = rank_bottom_x + (rank_size - small_suit_size) // 2
        bottom_suit_y = rank_bottom_y - small_suit_size - int(h * 0.01)
        self._draw_suit_shape(surf, symbol,
                              bottom_suit_x + small_suit_size // 2,
                              bottom_suit_y + small_suit_size // 2,
                              small_suit_size, suit_color)

    def _draw_rank(self, surf, rank, x, y, color, size, flip=False):
        """랭크 텍스트"""
        font_size = max(10, size)
        try:
            font = pygame.font.SysFont('Arial Black', font_size)
        except:
            font = pygame.font.Font(None, font_size + 4)

        text = font.render(rank, True, color)
        if flip:
            text = pygame.transform.rotate(text, 180)
        surf.blit(text, (x, y))

    def _draw_suit_symbol(self, surf, symbol, x, y, color, size):
        """무늬 심볼 - 도형으로 직접 그리기"""
        self._draw_suit_shape(surf, symbol, x + size // 2, y + size // 2, size, color)

    def _draw_suit_shape(self, surf, suit_symbol, cx, cy, size, color):
        """무늬를 도형으로 직접 그리기 - 실제 포커 카드 무늬 참고"""
        s = max(8, size)
        half = s / 2

        if suit_symbol == '♥':  # 하트 - 위가 둥글고 아래가 뾰족
            # 하트 크기
            w = s * 0.9   # 전체 너비
            h = s * 0.95  # 전체 높이
            r = w * 0.28  # 상단 원 반지름

            # 원 중심 위치
            circle_y = cy - h * 0.22
            circle_left_x = cx - w * 0.23
            circle_right_x = cx + w * 0.23

            # 상단 왼쪽 원
            pygame.draw.circle(surf, color, (int(circle_left_x), int(circle_y)), int(r))
            # 상단 오른쪽 원
            pygame.draw.circle(surf, color, (int(circle_right_x), int(circle_y)), int(r))
            # 하단 뾰족한 삼각형 - 원과 자연스럽게 연결
            pygame.draw.polygon(surf, color, [
                (circle_left_x - r * 0.85, circle_y + r * 0.2),   # 왼쪽
                (circle_right_x + r * 0.85, circle_y + r * 0.2), # 오른쪽
                (cx, cy + h * 0.48)                               # 하단 뾰족점
            ])

        elif suit_symbol == '♦':  # 다이아몬드 - 세로로 긴 마름모
            w = s * 0.666  # 너비 (10% 추가 증가: 0.605 * 1.1)
            h = s * 1.029  # 높이 (10% 추가 증가: 0.935 * 1.1)
            pygame.draw.polygon(surf, color, [
                (cx, cy - h * 0.5),      # 상단
                (cx + w * 0.5, cy),      # 우측
                (cx, cy + h * 0.5),      # 하단
                (cx - w * 0.5, cy)       # 좌측
            ])

        elif suit_symbol == '♣':  # 클로버 - 세 개의 둥근 잎 + 줄기
            r = s * 0.252  # 잎 반지름 (10% 감소: 0.28 * 0.9)

            # 상단 잎 (12시) - 더 위로
            pygame.draw.circle(surf, color, (int(cx), int(cy - r * 1.1)), int(r))
            # 좌하단 잎 (8시) - 더 벌어지게
            pygame.draw.circle(surf, color, (int(cx - r * 1.05), int(cy + r * 0.2)), int(r))
            # 우하단 잎 (4시) - 더 벌어지게
            pygame.draw.circle(surf, color, (int(cx + r * 1.05), int(cy + r * 0.2)), int(r))

            # 중앙 빈틈 채우기 (더 크게)
            pygame.draw.circle(surf, color, (int(cx), int(cy)), int(r * 0.9))

            # 줄기 (밑으로 갈수록 넓어지는 형태)
            stem_top_w = s * 0.10
            stem_bot_w = s * 0.20
            stem_h = s * 0.38
            stem_top = cy + r * 0.5
            pygame.draw.polygon(surf, color, [
                (cx - stem_top_w, stem_top),
                (cx + stem_top_w, stem_top),
                (cx + stem_bot_w, stem_top + stem_h),
                (cx - stem_bot_w, stem_top + stem_h)
            ])

        elif suit_symbol == '♠':  # 스페이드 - 뒤집힌 하트 + 중앙에 밑으로 넓어지는 막대
            # 하트와 동일한 크기 사용
            w = s * 0.9
            h = s * 0.95
            r = w * 0.34  # 하단 원 반지름 (더 크게 - 굴곡 강조)

            # === 1. 뒤집힌 하트 (하트를 180도 회전) ===
            # 하단 원 중심 위치 (더 아래로, 더 벌어지게)
            circle_y = cy + h * 0.18
            circle_left_x = cx - w * 0.26
            circle_right_x = cx + w * 0.26

            # 하단 왼쪽 원 (더 큰 원으로 굴곡 강조)
            pygame.draw.circle(surf, color, (int(circle_left_x), int(circle_y)), int(r))
            # 하단 오른쪽 원
            pygame.draw.circle(surf, color, (int(circle_right_x), int(circle_y)), int(r))

            # 상단 뾰족한 삼각형 (하트의 하단을 위로)
            pygame.draw.polygon(surf, color, [
                (circle_left_x - r * 0.75, circle_y - r * 0.3),   # 왼쪽
                (circle_right_x + r * 0.75, circle_y - r * 0.3),  # 오른쪽
                (cx, cy - h * 0.48)                                # 상단 뾰족점
            ])

            # === 2. 중앙 막대 (밑으로 갈수록 넓어짐) ===
            stem_top_w = s * 0.06   # 상단 너비 (좁음)
            stem_bot_w = s * 0.18   # 하단 너비 (넓음)
            stem_h = s * 0.30       # 막대 높이
            stem_top_y = circle_y + r * 0.3  # 원 아래에서 시작

            pygame.draw.polygon(surf, color, [
                (cx - stem_top_w, stem_top_y),              # 왼쪽 상단 (좁음)
                (cx + stem_top_w, stem_top_y),              # 오른쪽 상단 (좁음)
                (cx + stem_bot_w, stem_top_y + stem_h),     # 오른쪽 하단 (넓음)
                (cx - stem_bot_w, stem_top_y + stem_h)      # 왼쪽 하단 (넓음)
            ])

    def _draw_ornate_suit(self, surf, suit_symbol, cx, cy, size, color):
        """화려한 장식이 있는 에이스 무늬 (스크린샷 스타일)"""
        s = max(20, size)

        if suit_symbol == '♣':  # 클로버 - 화려한 장식
            # 기본 클로버 형태
            r = s * 0.22
            # 상단 잎
            pygame.draw.circle(surf, color, (int(cx), int(cy - r * 1.2)), int(r))
            # 좌하단 잎
            pygame.draw.circle(surf, color, (int(cx - r * 1.0), int(cy + r * 0.1)), int(r))
            # 우하단 잎
            pygame.draw.circle(surf, color, (int(cx + r * 1.0), int(cy + r * 0.1)), int(r))

            # 장식 - 좌우 스크롤 곡선
            scroll_r = s * 0.35
            # 왼쪽 스크롤
            pygame.draw.arc(surf, color, (int(cx - s * 0.7), int(cy - s * 0.1), int(scroll_r), int(scroll_r)), 0.5, 2.5, 2)
            pygame.draw.arc(surf, color, (int(cx - s * 0.75), int(cy + s * 0.15), int(scroll_r * 0.8), int(scroll_r * 0.8)), 3.5, 5.8, 2)
            # 오른쪽 스크롤
            pygame.draw.arc(surf, color, (int(cx + s * 0.35), int(cy - s * 0.1), int(scroll_r), int(scroll_r)), 0.6, 2.6, 2)
            pygame.draw.arc(surf, color, (int(cx + s * 0.4), int(cy + s * 0.15), int(scroll_r * 0.8), int(scroll_r * 0.8)), 3.7, 6.0, 2)

            # 중앙 장식 점들
            dot_r = s * 0.04
            pygame.draw.circle(surf, color, (int(cx), int(cy - r * 0.3)), int(dot_r))
            pygame.draw.circle(surf, color, (int(cx - r * 0.5), int(cy + r * 0.5)), int(dot_r))
            pygame.draw.circle(surf, color, (int(cx + r * 0.5), int(cy + r * 0.5)), int(dot_r))

            # 줄기 (화려한 버전)
            stem_w = s * 0.12
            stem_h = s * 0.45
            pygame.draw.polygon(surf, color, [
                (cx - stem_w, cy + r * 0.3),
                (cx + stem_w, cy + r * 0.3),
                (cx + stem_w * 0.3, cy + stem_h),
                (cx - stem_w * 0.3, cy + stem_h)
            ])
            # 줄기 장식
            pygame.draw.circle(surf, color, (int(cx), int(cy + stem_h * 0.7)), int(s * 0.06))

        elif suit_symbol == '♥':  # 하트 - 화려한 장식
            w_h = s * 0.9
            h_h = s * 0.95
            r = w_h * 0.28

            # 원 중심 위치
            circle_y = cy - h_h * 0.22
            circle_left_x = cx - w_h * 0.23
            circle_right_x = cx + w_h * 0.23

            # 하트 외곽선 (두꺼운 선)
            # 상단 원들
            pygame.draw.circle(surf, color, (int(circle_left_x), int(circle_y)), int(r))
            pygame.draw.circle(surf, color, (int(circle_right_x), int(circle_y)), int(r))
            # 하단 삼각형 - 원과 자연스럽게 연결
            pygame.draw.polygon(surf, color, [
                (circle_left_x - r * 0.85, circle_y + r * 0.2),
                (circle_right_x + r * 0.85, circle_y + r * 0.2),
                (cx, cy + h_h * 0.50)
            ])

            # 내부 장식 (검정으로 하트 안에 패턴)
            inner_color = (15, 15, 15)  # 배경색
            inner_scale = 0.55
            ir = r * inner_scale
            inner_circle_y = cy - h_h * 0.18
            pygame.draw.circle(surf, inner_color, (int(cx - w_h * 0.20), int(inner_circle_y)), int(ir))
            pygame.draw.circle(surf, inner_color, (int(cx + w_h * 0.20), int(inner_circle_y)), int(ir))
            pygame.draw.polygon(surf, inner_color, [
                (cx - w_h * 0.32, inner_circle_y + ir * 0.2),
                (cx + w_h * 0.32, inner_circle_y + ir * 0.2),
                (cx, cy + h_h * 0.30)
            ])

            # 스크롤 장식
            scroll_w = s * 0.25
            # 좌우 곡선 장식
            pygame.draw.arc(surf, color, (int(cx - s * 0.55), int(cy - s * 0.05), int(scroll_w), int(scroll_w * 1.2)), 0.3, 2.8, 2)
            pygame.draw.arc(surf, color, (int(cx + s * 0.30), int(cy - s * 0.05), int(scroll_w), int(scroll_w * 1.2)), 0.3, 2.8, 2)

            # 중앙 장식 점
            pygame.draw.circle(surf, color, (int(cx), int(cy - h_h * 0.05)), int(s * 0.05))

        elif suit_symbol == '♦':  # 다이아몬드 - 화려한 장식
            w_d = s * 0.495  # 10% 증가
            h_d = s * 0.77   # 10% 증가

            # 메인 다이아몬드
            pygame.draw.polygon(surf, color, [
                (cx, cy - h_d * 0.6),
                (cx + w_d * 0.6, cy),
                (cx, cy + h_d * 0.6),
                (cx - w_d * 0.6, cy)
            ])

            # 내부 장식 (검은색 다이아몬드)
            inner_color = (15, 15, 15)
            pygame.draw.polygon(surf, inner_color, [
                (cx, cy - h_d * 0.35),
                (cx + w_d * 0.35, cy),
                (cx, cy + h_d * 0.35),
                (cx - w_d * 0.35, cy)
            ])

            # 화려한 스크롤 장식 (상하좌우)
            scroll_size = s * 0.22
            # 상단 장식
            pygame.draw.arc(surf, color, (int(cx - scroll_size/2), int(cy - h_d * 0.85), int(scroll_size), int(scroll_size * 0.8)), 3.14, 6.28, 2)
            # 하단 장식
            pygame.draw.arc(surf, color, (int(cx - scroll_size/2), int(cy + h_d * 0.55), int(scroll_size), int(scroll_size * 0.8)), 0, 3.14, 2)
            # 좌측 장식
            pygame.draw.arc(surf, color, (int(cx - w_d * 0.9), int(cy - scroll_size/2), int(scroll_size * 0.8), int(scroll_size)), 4.7, 7.85, 2)
            # 우측 장식
            pygame.draw.arc(surf, color, (int(cx + w_d * 0.55), int(cy - scroll_size/2), int(scroll_size * 0.8), int(scroll_size)), 1.57, 4.7, 2)

            # 코너 장식 점들
            dot_r = s * 0.04
            pygame.draw.circle(surf, color, (int(cx), int(cy - h_d * 0.75)), int(dot_r))
            pygame.draw.circle(surf, color, (int(cx), int(cy + h_d * 0.75)), int(dot_r))
            pygame.draw.circle(surf, color, (int(cx - w_d * 0.75), int(cy)), int(dot_r))
            pygame.draw.circle(surf, color, (int(cx + w_d * 0.75), int(cy)), int(dot_r))

        elif suit_symbol == '♠':  # 스페이드 - 뒤집힌 하트 + 중앙에 밑으로 넓어지는 막대 (화려한 버전)
            # 하트와 동일한 크기 사용
            w = s * 0.9
            h = s * 0.95
            r = w * 0.34  # 하단 원 반지름 (더 크게 - 굴곡 강조)

            # === 1. 뒤집힌 하트 (하트를 180도 회전) ===
            # 하단 원 중심 위치 (더 아래로, 더 벌어지게)
            circle_y = cy + h * 0.18
            circle_left_x = cx - w * 0.26
            circle_right_x = cx + w * 0.26

            # 하단 왼쪽 원 (더 큰 원으로 굴곡 강조)
            pygame.draw.circle(surf, color, (int(circle_left_x), int(circle_y)), int(r))
            # 하단 오른쪽 원
            pygame.draw.circle(surf, color, (int(circle_right_x), int(circle_y)), int(r))

            # 상단 뾰족한 삼각형 (하트의 하단을 위로)
            pygame.draw.polygon(surf, color, [
                (circle_left_x - r * 0.75, circle_y - r * 0.3),   # 왼쪽
                (circle_right_x + r * 0.75, circle_y - r * 0.3),  # 오른쪽
                (cx, cy - h * 0.48)                                # 상단 뾰족점
            ])

            # === 2. 중앙 막대 (밑으로 갈수록 넓어짐) ===
            stem_top_w = s * 0.06   # 상단 너비 (좁음)
            stem_bot_w = s * 0.18   # 하단 너비 (넓음)
            stem_h = s * 0.30       # 막대 높이
            stem_top_y = circle_y + r * 0.3  # 원 아래에서 시작

            pygame.draw.polygon(surf, color, [
                (cx - stem_top_w, stem_top_y),              # 왼쪽 상단 (좁음)
                (cx + stem_top_w, stem_top_y),              # 오른쪽 상단 (좁음)
                (cx + stem_bot_w, stem_top_y + stem_h),     # 오른쪽 하단 (넓음)
                (cx - stem_bot_w, stem_top_y + stem_h)      # 왼쪽 하단 (넓음)
            ])

            # 장식 점들
            dot_r = s * 0.03
            pygame.draw.circle(surf, color, (int(cx), int(cy - h * 0.55)), int(dot_r))
            pygame.draw.circle(surf, color, (int(cx), int(stem_top_y + stem_h + s * 0.05)), int(dot_r))

    def _draw_face_card(self, surf, card, w, h, color):
        """페이스 카드 (J, Q, K) 디자인 - 프리미엄 블랙 스타일"""
        cx, cy = w // 2, h // 2
        symbol = Card.SUIT_SYMBOLS[card.suit]
        letter = card.rank

        # 중앙 프레임 영역
        frame_margin = int(w * 0.12)
        frame_x = frame_margin
        frame_y = int(h * 0.30)
        frame_w = w - frame_margin * 2
        frame_h = int(h * 0.40)

        # 프레임 테두리 (무늬 색상)
        pygame.draw.rect(surf, color, (frame_x, frame_y, frame_w, frame_h), 2, border_radius=4)

        # 인물 실루엣
        person_cx = cx
        person_cy = frame_y + frame_h // 2

        # 머리
        head_r = int(w * 0.09)
        pygame.draw.circle(surf, color, (person_cx, person_cy - int(frame_h * 0.20)), head_r, 2)

        # 몸통
        body_top_w = int(w * 0.12)
        body_bot_w = int(w * 0.18)
        body_h = int(frame_h * 0.35)
        body_top_y = person_cy - int(frame_h * 0.02)
        pygame.draw.polygon(surf, color, [
            (person_cx - body_top_w, body_top_y),
            (person_cx + body_top_w, body_top_y),
            (person_cx + body_bot_w, body_top_y + body_h),
            (person_cx - body_bot_w, body_top_y + body_h)
        ], 2)

        # 왕관 (K만)
        if letter == 'K':
            crown_y = person_cy - int(frame_h * 0.38)
            pygame.draw.polygon(surf, color, [
                (person_cx - int(w * 0.10), crown_y + int(h * 0.04)),
                (person_cx - int(w * 0.08), crown_y),
                (person_cx - int(w * 0.03), crown_y + int(h * 0.02)),
                (person_cx, crown_y - int(h * 0.02)),
                (person_cx + int(w * 0.03), crown_y + int(h * 0.02)),
                (person_cx + int(w * 0.08), crown_y),
                (person_cx + int(w * 0.10), crown_y + int(h * 0.04)),
            ], 2)
        # 여왕 티아라 (Q만)
        elif letter == 'Q':
            tiara_y = person_cy - int(frame_h * 0.35)
            pygame.draw.arc(surf, color,
                          (person_cx - int(w * 0.10), tiara_y, int(w * 0.20), int(h * 0.06)),
                          3.14, 0, 2)
        # 잭 모자 (J만)
        elif letter == 'J':
            hat_y = person_cy - int(frame_h * 0.35)
            pygame.draw.ellipse(surf, color,
                              (person_cx - int(w * 0.08), hat_y, int(w * 0.16), int(h * 0.04)), 2)

    def _draw_ace_card(self, surf, card, w, h, color, symbol):
        """에이스 카드 디자인 - 프리미엄 장식 스타일 (스크린샷 참조)"""
        cx, cy = w // 2, h // 2

        # 대형 중앙 심볼 (화려한 장식 버전)
        large_size = int(w * 0.55)
        self._draw_ornate_suit(surf, symbol, cx, cy, large_size, color)

    def _draw_pip_card(self, surf, card, w, h, color, symbol):
        """숫자 카드 핍 패턴 - 넓게 분산된 레이아웃"""
        cx, cy = w // 2, h // 2
        value = card.get_value()

        # 핍 크기 (무늬가 잘 보이도록 적당한 크기)
        pip_size = int(w * 0.20)

        # 핍 배치 (카드 값에 따라)
        positions = self._get_pip_positions(value, w, h)

        for px, py, flipped in positions:
            # 도형으로 직접 그리기
            self._draw_suit_shape(surf, symbol, int(px), int(py), pip_size, color)

    def _get_pip_positions(self, value, w, h):
        """핍 위치 계산 - 실제 포커 카드 레이아웃 (좌상단/우하단 숫자 영역 피함)"""
        cx, cy = w // 2, h // 2

        # 핍 영역 - 좌상단과 우하단 숫자+무늬 영역 피해서 배치
        # 상단/하단 위치 (숫자 영역 피해서)
        top = int(h * 0.32)      # 상단 줄 (숫자 아래)
        top2 = int(h * 0.42)     # 상단 두번째 줄
        mid = cy                  # 중앙
        bot2 = int(h * 0.58)     # 하단 두번째 줄
        bot = int(h * 0.68)      # 하단 줄 (숫자 위)

        # 좌우 위치 (중앙에 더 가깝게)
        left = int(w * 0.30)
        right = int(w * 0.70)

        patterns = {
            2: [(cx, int(h * 0.35), False), (cx, int(h * 0.65), True)],
            3: [(cx, int(h * 0.32), False), (cx, mid, False), (cx, int(h * 0.68), True)],
            4: [(left, top, False), (right, top, False),
                (left, bot, True), (right, bot, True)],
            5: [(left, top, False), (right, top, False),
                (cx, mid, False),
                (left, bot, True), (right, bot, True)],
            6: [(left, top, False), (right, top, False),
                (left, mid, False), (right, mid, False),
                (left, bot, True), (right, bot, True)],
            7: [(left, top, False), (right, top, False),
                (cx, int(h * 0.40), False),
                (left, mid, False), (right, mid, False),
                (left, bot, True), (right, bot, True)],
            8: [(left, top, False), (right, top, False),
                (cx, int(h * 0.40), False),
                (left, mid, False), (right, mid, False),
                (cx, int(h * 0.60), True),
                (left, bot, True), (right, bot, True)],
            9: [(left, top, False), (right, top, False),
                (left, top2, False), (right, top2, False),
                (cx, mid, False),
                (left, bot2, True), (right, bot2, True),
                (left, bot, True), (right, bot, True)],
            10: [(left, top, False), (right, top, False),
                 (cx, int(h * 0.38), False),
                 (left, top2, False), (right, top2, False),
                 (left, bot2, True), (right, bot2, True),
                 (cx, int(h * 0.62), True),
                 (left, bot, True), (right, bot, True)],
        }

        return patterns.get(value, [(cx, mid, False)])

    def _draw_card_back(self, surf, w, h):
        """카드 뒷면 (프리미엄)"""
        # 배경 그라데이션 (진한 보라~파랑)
        for i in range(h):
            ratio = i / h
            r = int(45 + ratio * 15)
            g = int(35 + ratio * 20)
            b = int(80 + ratio * 30)
            pygame.draw.line(surf, (r, g, b), (0, i), (w, i))

        # 외곽 테두리
        pygame.draw.rect(surf, (80, 70, 120), (0, 0, w, h), 2, border_radius=8)

        # 내부 프레임
        margin = 5
        pygame.draw.rect(surf, (70, 60, 100),
                        (margin, margin, w - margin*2, h - margin*2), 1, border_radius=6)

        # 중앙 장식 패턴
        cx, cy = w // 2, h // 2

        # 다이아몬드 패턴
        pattern_size = min(w, h) * 0.15
        for row in range(-1, 3):
            for col in range(-1, 3):
                dx = cx + col * pattern_size * 1.2 - pattern_size * 0.6
                dy = cy + row * pattern_size * 1.4 - pattern_size * 0.7

                if margin + 5 < dx < w - margin - 5 and margin + 5 < dy < h - margin - 5:
                    points = [
                        (dx, dy - pattern_size * 0.4),
                        (dx + pattern_size * 0.3, dy),
                        (dx, dy + pattern_size * 0.4),
                        (dx - pattern_size * 0.3, dy)
                    ]
                    pygame.draw.polygon(surf, (100, 85, 140), points)
                    pygame.draw.polygon(surf, (120, 100, 160), points, 1)

        # 중앙 원 장식
        pygame.draw.circle(surf, (90, 75, 130), (cx, cy), int(min(w, h) * 0.2), 2)
        pygame.draw.circle(surf, (110, 95, 150), (cx, cy), int(min(w, h) * 0.12))


# ============================================
# 포커 게임 UI (프리미엄)
# ============================================
class PokerGameUI:
    """포커 게임 UI - 프리미엄 버전"""

    CARD_WIDTH = 70
    CARD_HEIGHT = 98

    def __init__(self, screen_width, screen_height, fonts=None):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game = None
        self.fonts = fonts

        self.bet_amount = 50
        self.selected_action = -1  # 키보드 선택 (-1: 없음)
        self.raise_amount = 20
        self.hovered_action = -1  # 마우스 호버 중인 버튼 (-1: 없음)
        self.action_buttons = []  # 버튼 영역 저장용

        # 레이즈 범위 (베팅에 비례하여 동적 계산)
        self.min_raise = 10
        self.max_raise = 100
        self.raise_step = 10  # 레이즈 증감 단위

        self.animation_timer = 0
        self.show_result_timer = 0
        self.result_shown = False

        # 색상 팔레트 (프리미엄)
        self.DARK_BG = (18, 15, 25)
        self.TABLE_FELT = (25, 85, 55)
        self.TABLE_FELT_LIGHT = (35, 110, 70)
        self.TABLE_BORDER = (60, 45, 35)
        self.TABLE_BORDER_LIGHT = (100, 80, 60)
        self.GOLD = (255, 200, 50)
        self.GOLD_LIGHT = (255, 230, 120)
        self.WHITE = (255, 255, 255)
        self.SILVER = (200, 200, 210)
        self.BLACK = (15, 15, 15)
        self.RED = (200, 50, 50)
        self.BLUE = (80, 140, 220)

        # 렌더러 & 파티클
        self.card_renderer = PremiumCardRenderer()
        self.particles = ParticleSystem()

        # 칩 애니메이션
        self.chip_animations = []

        self._font_cache = {}

        # 테이블 애니메이션용 변수
        self.table_glow_phase = 0
        self.table_sparkle_timer = 0
        self.table_sparkles = []  # 테이블 테두리 반짝임 효과
        self.table_pulse_phase = 0  # 테이블 펄스 효과

        # BGM 관리자
        self.bgm = PokerBGM.get_instance()

        # 플로팅 텍스트 애니메이션 (수수료, 획득 골드 등)
        self.floating_texts = []  # [(text, x, y, color, timer, max_timer), ...]

        # 골드 증감 효과음 로드
        self.gold_sound = None
        self._load_gold_sound()

    def _load_gold_sound(self):
        """골드 증감 효과음 로드"""
        try:
            # sounds 폴더에서 itemget.wav 로드
            current_dir = os.path.dirname(os.path.abspath(__file__))
            parent_dir = os.path.dirname(current_dir)
            sound_path = os.path.join(parent_dir, "sounds", "itemget.wav")

            if os.path.exists(sound_path):
                self.gold_sound = pygame.mixer.Sound(sound_path)
                self.gold_sound.set_volume(0.5)
            else:
                # PyInstaller 환경
                alt_path = resource_path(os.path.join("..", "sounds", "itemget.wav"))
                if os.path.exists(alt_path):
                    self.gold_sound = pygame.mixer.Sound(alt_path)
                    self.gold_sound.set_volume(0.5)
        except Exception as e:
            print(f"[PokerGameUI] 골드 효과음 로드 실패: {e}")

    def _play_gold_sound(self):
        """골드 증감 효과음 재생"""
        if self.gold_sound:
            try:
                self.gold_sound.play()
            except Exception:
                pass

    def start_game(self, player_gold):
        self.game = PokerGame(player_gold)
        self.game.start_new_round()
        self.bet_amount = min(50, player_gold)
        self.result_shown = False

        # 포커 BGM 시작
        if self.bgm:
            self.bgm.start(volume=0.4)

    def _update_raise_range(self):
        """현재 베팅에 비례하여 레이즈 범위 계산"""
        if not self.game:
            return

        base_bet = self.game.current_bet if self.game.current_bet > 0 else self.game.min_bet
        self.min_raise = max(10, int(base_bet * 0.5))  # 최소: 베팅의 50%
        self.max_raise = min(int(base_bet * 2.0), self.game.player_gold)  # 최대: 베팅의 200% 또는 보유 골드
        self.raise_step = max(5, int(base_bet * 0.1))  # 증감 단위: 베팅의 10%

        # 레이즈 금액이 범위를 벗어나면 조정
        if self.raise_amount < self.min_raise:
            self.raise_amount = self.min_raise
        elif self.raise_amount > self.max_raise:
            self.raise_amount = self.max_raise

    def handle_event(self, event):
        if not self.game:
            return None

        if event.type == pygame.KEYDOWN:
            # ESC는 언제든 나갈 수 있음
            if event.key == pygame.K_ESCAPE:
                # BGM 정지
                if self.bgm:
                    self.bgm.stop()
                return 'exit'

            # 애니메이션 중에는 다른 입력 무시 (일부 상태)
            if self.game.state in [PokerGame.STATE_DEALING, PokerGame.STATE_FLOP_DEALING,
                                   PokerGame.STATE_TURN_DEALING, PokerGame.STATE_RIVER_DEALING]:
                return None

            if self.game.state == PokerGame.STATE_BETTING:
                return self._handle_betting_input(event)
            elif self.game.state in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                                      PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
                return self._handle_action_input(event)
            elif self.game.state in [PokerGame.STATE_SHOWDOWN, PokerGame.STATE_GAME_OVER]:
                return self._handle_result_input(event)

        # 마우스 이동 - 호버 처리
        elif event.type == pygame.MOUSEMOTION:
            return self._handle_mouse_hover(event.pos)

        # 마우스 클릭 - 버튼 클릭 처리
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            return self._handle_mouse_click(event.pos)

        # 마우스 휠 - 금액 조정
        elif event.type == pygame.MOUSEWHEEL:
            return self._handle_mouse_wheel(event.y)

        return None

    def _handle_mouse_wheel(self, wheel_y):
        """마우스 휠로 금액 조정"""
        # 베팅 상태일 때 - 베팅 금액 조정
        if self.game.state == PokerGame.STATE_BETTING:
            if wheel_y > 0:  # 휠 위로 - 금액 증가
                self.bet_amount = min(self.game.max_bet, self.game.player_gold, self.bet_amount + 10)
            elif wheel_y < 0:  # 휠 아래로 - 금액 감소
                self.bet_amount = max(self.game.min_bet, self.bet_amount - 10)
            return None

        # 액션 상태일 때 - 레이즈 금액 조정 (베팅에 비례)
        if self.game.state in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                                PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
            if wheel_y > 0:  # 휠 위로 - 레이즈 금액 증가
                self.raise_amount = min(self.max_raise, self.game.player_gold, self.raise_amount + self.raise_step)
            elif wheel_y < 0:  # 휠 아래로 - 레이즈 금액 감소
                self.raise_amount = max(self.min_raise, self.raise_amount - self.raise_step)
            return None

        return None

    def _handle_mouse_hover(self, pos):
        """마우스 호버 처리"""
        # 액션 상태일 때만 호버 처리
        if self.game.state not in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                                    PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
            self.hovered_action = -1
            return None

        # 버튼 영역 체크
        self.hovered_action = -1
        for i, btn_rect in enumerate(self.action_buttons):
            if btn_rect.collidepoint(pos):
                self.hovered_action = i
                break
        return None

    def _handle_mouse_click(self, pos):
        """마우스 클릭 처리"""
        # 애니메이션 중에는 무시
        if self.game.state in [PokerGame.STATE_DEALING, PokerGame.STATE_FLOP_DEALING,
                               PokerGame.STATE_TURN_DEALING, PokerGame.STATE_RIVER_DEALING]:
            return None

        # 액션 상태일 때 버튼 클릭 처리
        if self.game.state in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                                PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
            for i, btn_rect in enumerate(self.action_buttons):
                if btn_rect.collidepoint(pos):
                    # 마우스 클릭 시 키보드 선택 해제하고 바로 실행
                    self.selected_action = -1
                    # 해당 액션 실행
                    if i == 0:  # CALL/CHECK
                        # 콜 금액이 플레이어 골드보다 크면 무시
                        call_amount = self.game.get_call_amount()
                        if call_amount > self.game.player_gold:
                            return None  # 골드 부족
                        if call_amount > 0:
                            self._spawn_chip_animation(call_amount)
                        self.game.call()
                        return 'action_call'
                    elif i == 1:  # RAISE
                        if self.game.raise_bet(self.raise_amount):
                            total = self.raise_amount + self.game.player_to_call
                            self._spawn_chip_animation(total)
                            self.game.call()
                            return 'action_raise'
                    elif i == 2:  # FOLD
                        self.game.fold()
                        return 'action_fold'
        return None

    def _handle_betting_input(self, event):
        if event.key == pygame.K_LEFT:
            self.bet_amount = max(self.game.min_bet, self.bet_amount - 10)
        elif event.key == pygame.K_RIGHT:
            self.bet_amount = min(self.game.max_bet, self.game.player_gold, self.bet_amount + 10)
        elif event.key == pygame.K_UP:
            self.bet_amount = min(self.game.max_bet, self.game.player_gold, self.bet_amount + 50)
        elif event.key == pygame.K_DOWN:
            self.bet_amount = max(self.game.min_bet, self.bet_amount - 50)
        elif event.key in [pygame.K_RETURN, pygame.K_z, pygame.K_SPACE]:
            if self.game.place_bet(self.bet_amount):
                # 칩 애니메이션
                self._spawn_chip_animation(self.bet_amount)
                # 베팅 완료 후 레이즈 범위 업데이트
                self._update_raise_range()
                return 'bet_placed'
        elif event.key == pygame.K_ESCAPE:
            return 'exit'
        return None

    def _handle_action_input(self, event):
        if event.key == pygame.K_LEFT:
            # 키보드 사용 시 selected_action 활성화
            if self.selected_action == -1:
                self.selected_action = 2  # 왼쪽 누르면 마지막(FOLD)에서 시작
            else:
                self.selected_action = (self.selected_action - 1) % 3
            self.hovered_action = -1  # 키보드 사용 시 호버 해제
        elif event.key == pygame.K_RIGHT:
            # 키보드 사용 시 selected_action 활성화
            if self.selected_action == -1:
                self.selected_action = 0  # 오른쪽 누르면 처음(CALL)에서 시작
            else:
                self.selected_action = (self.selected_action + 1) % 3
            self.hovered_action = -1  # 키보드 사용 시 호버 해제
        elif event.key == pygame.K_UP:
            # 레이즈 금액 증가 (선택 상태와 무관하게) - 베팅에 비례
            self.raise_amount = min(self.max_raise, self.game.player_gold, self.raise_amount + self.raise_step)
        elif event.key == pygame.K_DOWN:
            # 레이즈 금액 감소 (선택 상태와 무관하게) - 베팅에 비례
            self.raise_amount = max(self.min_raise, self.raise_amount - self.raise_step)
        elif event.key in [pygame.K_RETURN, pygame.K_z, pygame.K_SPACE]:
            # 키보드로 확인 시 selected_action 사용
            if self.selected_action == 0:
                # 콜 금액이 플레이어 골드보다 크면 무시
                call_amount = self.game.get_call_amount()
                if call_amount > self.game.player_gold:
                    return None  # 골드 부족
                if call_amount > 0:
                    self._spawn_chip_animation(call_amount)
                self.game.call()
                return 'action_call'
            elif self.selected_action == 1:
                if self.game.raise_bet(self.raise_amount):
                    self._spawn_chip_animation(self.raise_amount)
                    self.game.call()
                    return 'action_raise'
            elif self.selected_action == 2:
                self.game.fold()
                return 'action_fold'
            # selected_action이 -1이면 아무 동작 안함 (마우스로 클릭해야 함)
        elif event.key == pygame.K_ESCAPE:
            return 'exit'
        return None

    def _handle_result_input(self, event):
        if event.key in [pygame.K_RETURN, pygame.K_z, pygame.K_SPACE]:
            # 딜러 파산 시 계속 불가
            if self.game.dealer_bankrupt:
                return 'exit'  # 파산 시 ESC와 동일하게 종료
            if self.game.player_gold >= self.game.min_bet:
                self.game.start_new_round()
                self.bet_amount = min(50, self.game.player_gold)
                self.result_shown = False
                return 'new_round'
            else:
                return 'exit'
        elif event.key == pygame.K_ESCAPE:
            return 'exit'
        return None

    def _spawn_chip_animation(self, amount):
        """칩 애니메이션 생성"""
        self.particles.emit_sparkle(
            self.screen_width // 2,
            self.screen_height - 100,
            count=15, color=self.GOLD
        )

    def update(self, dt):
        self.animation_timer += dt
        self.particles.update(dt)

        # 플로팅 텍스트 업데이트
        updated_floating = []
        for ft in self.floating_texts:
            text, x, y, color, timer, max_timer, text_type = ft
            timer += dt
            if timer < max_timer:
                updated_floating.append((text, x, y, color, timer, max_timer, text_type))
        self.floating_texts = updated_floating

        if self.game:
            self.game.update(dt)

            # 승리 시 파티클 효과 및 플로팅 텍스트 생성
            if self.game.state == PokerGame.STATE_SHOWDOWN and not self.result_shown:
                self.result_shown = True
                if self.game.winner == 'player':
                    self.particles.emit_win(self.screen_width // 2, self.screen_height // 2)

                # 펜딩된 플로팅 텍스트 처리
                if self.game.pending_floating_texts:
                    # 플레이어 골드 위치: 좌하단 (20, screen_height - 50)
                    # 딜러 골드 위치: 좌상단 (20, 15)
                    player_x, player_y = 150, self.screen_height - 50
                    dealer_x, dealer_y = 150, 40

                    player_offset = 0
                    dealer_offset = 0
                    played_sound = False

                    for item in self.game.pending_floating_texts:
                        text, text_type, target = item

                        # 타입별 색상 결정
                        if text_type == 'fee':
                            color = (255, 150, 100)  # 주황색 (수수료)
                        elif text_type == 'win':
                            color = (100, 255, 100)  # 초록색 (획득)
                        elif text_type == 'lose':
                            color = (255, 100, 100)  # 빨간색 (손실)
                        else:
                            color = (255, 255, 255)

                        # 타겟별 위치 결정
                        if target == 'player':
                            x = player_x
                            y = player_y - player_offset
                            player_offset += 25
                        else:  # dealer
                            x = dealer_x
                            y = dealer_y + dealer_offset
                            dealer_offset += 25

                        # 플로팅 텍스트 추가 (text, x, y, color, timer, max_timer, type)
                        self.floating_texts.append((text, x, y, color, 0, 2.0, text_type))

                        # 효과음 재생 (한 번만)
                        if not played_sound:
                            self._play_gold_sound()
                            played_sound = True

                    self.game.pending_floating_texts = []

    def draw(self, screen):
        if not self.game:
            return

        # 배경
        self._draw_background(screen)

        # 테이블
        self._draw_premium_table(screen)

        # 카드
        self._draw_cards(screen)

        # UI
        self._draw_ui(screen)

        # 상태별 UI
        if self.game.state == PokerGame.STATE_BETTING:
            self._draw_betting_ui(screen)
        elif self.game.state in [PokerGame.STATE_DEALING, PokerGame.STATE_FLOP_DEALING,
                                  PokerGame.STATE_TURN_DEALING, PokerGame.STATE_RIVER_DEALING]:
            self._draw_dealing_ui(screen)
        elif self.game.state in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                                  PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
            self._draw_action_ui(screen)
        elif self.game.state in [PokerGame.STATE_SHOWDOWN, PokerGame.STATE_GAME_OVER]:
            self._draw_result_ui(screen)

        # 파티클
        self.particles.draw(screen)

        # 플로팅 텍스트 (수수료, 획득 골드 등)
        self._draw_floating_texts(screen)

    def _draw_floating_texts(self, screen):
        """플로팅 텍스트 렌더링 (위로 올라가며 페이드아웃)"""
        for ft in self.floating_texts:
            text, base_x, base_y, color, timer, max_timer, text_type = ft

            # 진행률 계산 (0.0 ~ 1.0)
            progress = timer / max_timer

            # 위로 이동 (최대 60px)
            y_offset = -progress * 60
            current_y = base_y + y_offset

            # 페이드아웃 (0.5초 후부터 페이드)
            if progress > 0.5:
                alpha = int(255 * (1.0 - (progress - 0.5) * 2))
            else:
                alpha = 255

            alpha = max(0, min(255, alpha))

            if alpha <= 0:
                continue

            # 골드 아이콘 그리기 (16x16)
            icon_size = 16
            icon_x = int(base_x)
            icon_y = int(current_y)

            # 아이콘 서피스 생성
            icon_surf = pygame.Surface((icon_size + 100, icon_size + 8), pygame.SRCALPHA)

            # 골드 코인 아이콘 그리기
            coin_color = (255, 200, 50, alpha)
            coin_border = (200, 150, 30, alpha)
            pygame.draw.circle(icon_surf, coin_color, (icon_size // 2, icon_size // 2 + 2), icon_size // 2 - 1)
            pygame.draw.circle(icon_surf, coin_border, (icon_size // 2, icon_size // 2 + 2), icon_size // 2 - 1, 1)

            # G 텍스트 (코인 내부) - 시스템 폰트 사용
            try:
                small_font = pygame.font.SysFont('Arial', 10)
                g_surf = small_font.render("G", True, (180, 130, 20))
                g_surf.set_alpha(alpha)
                g_rect = g_surf.get_rect()
                icon_surf.blit(g_surf, (icon_size // 2 - g_rect.width // 2, icon_size // 2 - g_rect.height // 2 + 2))
            except:
                pass

            # 숫자 텍스트 - 시스템 폰트 사용
            try:
                text_font = pygame.font.SysFont('Arial', 16, bold=True)
                text_color = (color[0], color[1], color[2])
                text_surf = text_font.render(text, True, text_color)
                text_surf.set_alpha(alpha)
                text_rect = text_surf.get_rect()
                icon_surf.blit(text_surf, (icon_size + 4, (icon_size - text_rect.height) // 2 + 2))
            except:
                pass

            # 화면에 블릿
            screen.blit(icon_surf, (icon_x, icon_y))

    def _draw_background(self, screen):
        """프리미엄 배경"""
        # 그라데이션 배경
        for y in range(self.screen_height):
            ratio = y / self.screen_height
            r = int(18 + ratio * 8)
            g = int(15 + ratio * 10)
            b = int(25 + ratio * 15)
            pygame.draw.line(screen, (r, g, b), (0, y), (self.screen_width, y))

        # 조명 효과 (상단)
        for i in range(100):
            alpha = int(30 * (1 - i / 100))
            pygame.draw.ellipse(screen, (60, 50, 80, alpha),
                              (self.screen_width // 2 - 300 - i, -50 - i, 600 + i * 2, 150 + i))

    def _draw_premium_table(self, screen):
        """프리미엄 포커 테이블 - 화려한 애니메이션 버전"""
        cx, cy = self.screen_width // 2, self.screen_height // 2 + 20

        # 테이블 크기
        table_w, table_h = 520, 320

        # 애니메이션 업데이트
        self.table_glow_phase += 0.03
        self.table_pulse_phase += 0.05
        self.table_sparkle_timer += 1

        # 외부 글로우 효과 (여러 레이어)
        glow_intensity = 0.5 + 0.3 * math.sin(self.table_glow_phase)
        for i in range(4, 0, -1):
            glow_surf = pygame.Surface((table_w + 80 + i * 20, table_h + 80 + i * 20), pygame.SRCALPHA)
            glow_alpha = int(25 * glow_intensity * (5 - i) / 4)
            glow_color = (50, 180, 100, glow_alpha)
            pygame.draw.ellipse(glow_surf, glow_color, (0, 0, table_w + 80 + i * 20, table_h + 80 + i * 20))
            screen.blit(glow_surf, (cx - table_w // 2 - 40 - i * 10, cy - table_h // 2 - 40 - i * 10))

        # 테이블 그림자 (깊이감)
        shadow_surf = pygame.Surface((table_w + 50, table_h + 50), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 100), (0, 0, table_w + 50, table_h + 50))
        screen.blit(shadow_surf, (cx - table_w // 2 - 25, cy - table_h // 2 - 15))

        # 테이블 외곽 프레임 (그라데이션 나무 테두리)
        frame_w, frame_h = table_w + 40, table_h + 40
        for i in range(8):
            ratio = i / 8
            r = int(80 - ratio * 30)
            g = int(60 - ratio * 25)
            b = int(45 - ratio * 20)
            pygame.draw.ellipse(screen, (r, g, b),
                               (cx - frame_w // 2 + i * 2, cy - frame_h // 2 + i * 2,
                                frame_w - i * 4, frame_h - i * 4))

        # 골드 테두리 라인 (애니메이션)
        gold_pulse = 0.7 + 0.3 * math.sin(self.table_pulse_phase * 2)
        gold_color = (int(255 * gold_pulse), int(180 * gold_pulse), int(50 * gold_pulse))
        pygame.draw.ellipse(screen, gold_color,
                           (cx - frame_w // 2, cy - frame_h // 2, frame_w, frame_h), 3)

        # 내부 골드 하이라이트
        pygame.draw.ellipse(screen, (120, 100, 70),
                           (cx - frame_w // 2 + 5, cy - frame_h // 2 + 5, frame_w - 10, frame_h - 10), 2)

        # 펠트 (고급 그라데이션)
        for i in range(12):
            ratio = i / 12
            # 중앙이 밝고 가장자리가 어두운 그라데이션
            brightness = 1.0 - ratio * 0.25
            r = int(self.TABLE_FELT[0] * brightness + 15 * (1 - ratio))
            g = int(self.TABLE_FELT[1] * brightness + 35 * (1 - ratio))
            b = int(self.TABLE_FELT[2] * brightness + 20 * (1 - ratio))
            pygame.draw.ellipse(screen, (r, g, b),
                               (cx - table_w // 2 + i * 3, cy - table_h // 2 + i * 3,
                                table_w - i * 6, table_h - i * 6))

        # 펠트 중앙 하이라이트 (조명 효과)
        highlight_surf = pygame.Surface((200, 120), pygame.SRCALPHA)
        for i in range(60):
            alpha = int(15 * (1 - i / 60))
            pygame.draw.ellipse(highlight_surf, (100, 200, 130, alpha),
                               (i, i // 2, 200 - i * 2, 120 - i))
        screen.blit(highlight_surf, (cx - 100, cy - 80))

        # 테이블 내부 장식 라인 (애니메이션 점선)
        self._draw_animated_table_border(screen, cx, cy, table_w, table_h)

        # 코너 장식
        self._draw_table_corner_decorations(screen, cx, cy, table_w, table_h)

        # 반짝임 효과 생성 및 그리기
        self._update_and_draw_table_sparkles(screen, cx, cy, table_w, table_h)

        # 중앙 로고/장식 (업그레이드)
        self._draw_table_logo(screen, cx, cy - 20)

        # POT 표시
        self._draw_pot_display(screen, cx, cy + 50)

    def _draw_animated_table_border(self, screen, cx, cy, table_w, table_h):
        """애니메이션 테이블 내부 테두리"""
        # 내부 라인 (점선 애니메이션)
        inner_w, inner_h = table_w - 60, table_h - 60
        num_segments = 48
        dash_offset = (self.table_glow_phase * 30) % 15

        for i in range(num_segments):
            angle = (i / num_segments) * 2 * math.pi
            next_angle = ((i + 1) / num_segments) * 2 * math.pi

            # 점선 효과 (교차)
            if (i + int(dash_offset / 3)) % 3 == 0:
                continue

            x1 = cx + math.cos(angle) * (inner_w // 2)
            y1 = cy + math.sin(angle) * (inner_h // 2)
            x2 = cx + math.cos(next_angle) * (inner_w // 2)
            y2 = cy + math.sin(next_angle) * (inner_h // 2)

            # 색상 그라데이션
            color_phase = (i / num_segments + self.table_glow_phase * 0.5) % 1
            r = int(50 + 30 * math.sin(color_phase * math.pi * 2))
            g = int(140 + 40 * math.sin(color_phase * math.pi * 2))
            b = int(90 + 30 * math.sin(color_phase * math.pi * 2))

            pygame.draw.line(screen, (r, g, b), (x1, y1), (x2, y2), 2)

        # 두 번째 내부 라인 (부드러운 글로우)
        glow_alpha = int(60 + 30 * math.sin(self.table_pulse_phase))
        inner_line_surf = pygame.Surface((table_w, table_h), pygame.SRCALPHA)
        pygame.draw.ellipse(inner_line_surf, (70, 180, 120, glow_alpha),
                           (30, 30, inner_w, inner_h), 2)
        screen.blit(inner_line_surf, (cx - table_w // 2, cy - table_h // 2))

    def _draw_table_corner_decorations(self, screen, cx, cy, table_w, table_h):
        """테이블 코너 장식"""
        corners = [
            (cx - table_w // 2 + 50, cy - table_h // 2 + 30),   # 좌상
            (cx + table_w // 2 - 50, cy - table_h // 2 + 30),   # 우상
            (cx - table_w // 2 + 50, cy + table_h // 2 - 30),   # 좌하
            (cx + table_w // 2 - 50, cy + table_h // 2 - 30),   # 우하
        ]

        for i, (corner_x, corner_y) in enumerate(corners):
            # 펄스 효과
            pulse = 0.7 + 0.3 * math.sin(self.table_pulse_phase + i * 0.8)

            # 외부 원
            pygame.draw.circle(screen, (60, 150, 100), (int(corner_x), int(corner_y)), 12, 2)

            # 내부 빛나는 원
            inner_color = (int(80 * pulse), int(200 * pulse), int(130 * pulse))
            pygame.draw.circle(screen, inner_color, (int(corner_x), int(corner_y)), 6)

            # 글로우 효과
            glow_surf = pygame.Surface((30, 30), pygame.SRCALPHA)
            glow_alpha = int(40 * pulse)
            pygame.draw.circle(glow_surf, (100, 220, 150, glow_alpha), (15, 15), 12)
            screen.blit(glow_surf, (corner_x - 15, corner_y - 15))

    def _update_and_draw_table_sparkles(self, screen, cx, cy, table_w, table_h):
        """테이블 테두리 반짝임 효과"""
        # 새 반짝임 생성
        if self.table_sparkle_timer % 8 == 0:
            angle = random.uniform(0, math.pi * 2)
            # 타원 경계에 반짝임 배치
            x = cx + math.cos(angle) * (table_w // 2 + 10)
            y = cy + math.sin(angle) * (table_h // 2 + 10)
            self.table_sparkles.append({
                'x': x, 'y': y,
                'life': 1.0,
                'size': random.uniform(2, 5),
                'color': random.choice([
                    (255, 215, 0),      # 골드
                    (200, 255, 200),    # 연녹색
                    (150, 255, 180),    # 민트
                    (255, 255, 200),    # 크림
                ])
            })

        # 반짝임 업데이트 및 그리기
        new_sparkles = []
        for sparkle in self.table_sparkles:
            sparkle['life'] -= 0.03
            if sparkle['life'] > 0:
                new_sparkles.append(sparkle)

                # 그리기
                alpha = int(255 * sparkle['life'])
                size = sparkle['size'] * (0.5 + sparkle['life'] * 0.5)
                color = (*sparkle['color'][:3], alpha)

                sparkle_surf = pygame.Surface((int(size * 4), int(size * 4)), pygame.SRCALPHA)

                # 별 모양 반짝임
                center = int(size * 2)
                # 중앙 원
                pygame.draw.circle(sparkle_surf, color, (center, center), int(size))
                # 십자 광선
                for angle in [0, math.pi/2, math.pi, math.pi*3/2]:
                    end_x = center + math.cos(angle) * size * 2
                    end_y = center + math.sin(angle) * size * 2
                    pygame.draw.line(sparkle_surf, color, (center, center), (end_x, end_y), max(1, int(size / 2)))

                screen.blit(sparkle_surf, (sparkle['x'] - center, sparkle['y'] - center))

        self.table_sparkles = new_sparkles[:30]  # 최대 30개 유지

    def _draw_table_logo(self, screen, x, y):
        """테이블 중앙 로고 - 업그레이드 버전"""
        # 로고 배경 글로우
        glow_pulse = 0.6 + 0.4 * math.sin(self.table_pulse_phase * 1.5)
        for i in range(4, 0, -1):
            glow_surf = pygame.Surface((90 + i * 10, 90 + i * 10), pygame.SRCALPHA)
            glow_alpha = int(20 * glow_pulse * (5 - i) / 4)
            pygame.draw.circle(glow_surf, (60, 180, 110, glow_alpha),
                              (45 + i * 5, 45 + i * 5), 40 + i * 5)
            screen.blit(glow_surf, (x - 45 - i * 5, y - 45 - i * 5))

        # 외부 장식 원 (회전 애니메이션)
        num_dots = 12
        for i in range(num_dots):
            angle = (i / num_dots) * 2 * math.pi + self.table_glow_phase
            dot_x = x + math.cos(angle) * 42
            dot_y = y + math.sin(angle) * 42
            dot_pulse = 0.5 + 0.5 * math.sin(self.table_pulse_phase + i * 0.5)
            dot_color = (int(80 + 40 * dot_pulse), int(180 + 40 * dot_pulse), int(120 + 40 * dot_pulse))
            pygame.draw.circle(screen, dot_color, (int(dot_x), int(dot_y)), 3)

        # 메인 원
        pygame.draw.circle(screen, (40, 120, 80), (x, y), 38, 3)
        pygame.draw.circle(screen, (50, 150, 95), (x, y), 32, 2)
        pygame.draw.circle(screen, (35, 100, 65), (x, y), 28)

        # 내부 하이라이트
        highlight_surf = pygame.Surface((50, 50), pygame.SRCALPHA)
        pygame.draw.ellipse(highlight_surf, (80, 180, 120, 60), (8, 5, 34, 20))
        screen.blit(highlight_surf, (x - 25, y - 30))

        # 텍스트 (글로우 효과)
        text_glow = int(140 + 40 * math.sin(self.table_glow_phase * 2))
        self._draw_text(screen, "POKER", x, y - 8, (70, text_glow, 110), 16, center=True)

        # 카드 문양 장식 (직접 그리기 - 폰트 깨짐 방지)
        symbol_colors = [(200, 200, 220), (220, 80, 80), (220, 80, 80), (200, 200, 220)]
        for i, col in enumerate(symbol_colors):
            angle = (i / 4) * 2 * math.pi - math.pi / 4 + self.table_glow_phase * 0.3
            sym_x = int(x + math.cos(angle) * 22)
            sym_y = int(y + math.sin(angle) * 22 + 5)
            self._draw_card_symbol_mini(screen, i, sym_x, sym_y, col, 6)

    def _draw_card_symbol_mini(self, screen, symbol_index, x, y, color, size):
        """미니 카드 문양 직접 그리기 (0=스페이드, 1=하트, 2=다이아, 3=클럽)"""
        if symbol_index == 0:  # 스페이드 ♠ - 뒤집힌 하트 + 중앙에 밑으로 넓어지는 막대
            s = size * 1.2

            # === 1. 뒤집힌 하트 (하트를 180도 회전: 아래가 둥글고 위가 뾰족) ===
            r = s * 0.42  # 원 반지름 (더 크게 - 굴곡 강조)
            circle_y = y + s * 0.20  # 원 중심 Y (아래쪽)
            circle_offset = s * 0.32  # 원 사이 간격 (더 벌어지게)

            # 하단 두 원 (더 큰 원으로 굴곡 강조)
            pygame.draw.circle(screen, color, (int(x - circle_offset), int(circle_y)), int(r))
            pygame.draw.circle(screen, color, (int(x + circle_offset), int(circle_y)), int(r))

            # 위로 뾰족한 삼각형 (하트의 하단을 위로)
            tri_bottom = circle_y - r * 0.2
            tri_top = y - s * 0.55  # 상단 뾰족점
            tri_half_width = s * 0.65

            pygame.draw.polygon(screen, color, [
                (x, tri_top),                      # 상단 뾰족점
                (x - tri_half_width, tri_bottom),  # 왼쪽 하단
                (x + tri_half_width, tri_bottom),  # 오른쪽 하단
            ])

            # === 2. 중앙 막대 (밑으로 갈수록 넓어짐) ===
            stem_top_w = s * 0.08   # 상단 너비 (좁음)
            stem_bot_w = s * 0.22   # 하단 너비 (넓음)
            stem_h = s * 0.42
            stem_top_y = circle_y + r * 0.35  # 원 아래에서 시작

            pygame.draw.polygon(screen, color, [
                (x - stem_top_w, stem_top_y),              # 왼쪽 상단 (좁음)
                (x + stem_top_w, stem_top_y),              # 오른쪽 상단 (좁음)
                (x + stem_bot_w, stem_top_y + stem_h),     # 오른쪽 하단 (넓음)
                (x - stem_bot_w, stem_top_y + stem_h)      # 왼쪽 하단 (넓음)
            ])
        elif symbol_index == 1:  # 하트 ♥
            # 두 개의 원 + 삼각형
            pygame.draw.circle(screen, color, (x - size // 2, y - size // 3), size // 2 + 1)
            pygame.draw.circle(screen, color, (x + size // 2, y - size // 3), size // 2 + 1)
            points = [(x, y + size), (x - size, y - size // 4), (x + size, y - size // 4)]
            pygame.draw.polygon(screen, color, points)
        elif symbol_index == 2:  # 다이아몬드 ♦
            # 마름모 형태 (10% 크게)
            sz = size * 1.1
            points = [
                (x, y - sz),      # 상단
                (x + sz, y),      # 우측
                (x, y + sz),      # 하단
                (x - sz, y),      # 좌측
            ]
            pygame.draw.polygon(screen, color, points)
        elif symbol_index == 3:  # 클럽 ♣
            # 세 개의 큰 원 (잎) + 줄기
            s = size * 1.3  # 전체 크기 확대
            leaf_r = int(s * 0.50)  # 잎 반지름 (더 크게)

            # 상단 잎 (더 위로, 더 도드라지게)
            pygame.draw.circle(screen, color, (x, int(y - s * 0.55)), leaf_r)
            # 좌하단 잎 (더 벌어지게)
            pygame.draw.circle(screen, color, (int(x - s * 0.52), int(y + s * 0.1)), leaf_r)
            # 우하단 잎 (더 벌어지게)
            pygame.draw.circle(screen, color, (int(x + s * 0.52), int(y + s * 0.1)), leaf_r)

            # 중앙 빈틈 채우기
            pygame.draw.circle(screen, color, (x, int(y - s * 0.15)), int(leaf_r * 0.6))

            # 줄기 (밑으로 갈수록 넓어지는 형태)
            stem_top_w = s * 0.12
            stem_bot_w = s * 0.24
            stem_top = y + s * 0.35
            pygame.draw.polygon(screen, color, [
                (x - stem_top_w, stem_top),
                (x + stem_top_w, stem_top),
                (x + stem_bot_w, y + s * 0.75),
                (x - stem_bot_w, y + s * 0.75)
            ])

    def _draw_pot_display(self, screen, x, y):
        """팟 표시 (프리미엄)"""
        pot = self.game.pot

        # 팟 박스
        box_w, box_h = 170, 60

        # 그림자
        pygame.draw.rect(screen, (0, 0, 0, 60), (x - box_w // 2 + 3, y + 3, box_w, box_h), border_radius=8)

        # 배경
        for i in range(box_h):
            ratio = i / box_h
            r = int(35 + ratio * 15)
            g = int(30 + ratio * 10)
            b = int(45 + ratio * 15)
            pygame.draw.line(screen, (r, g, b),
                           (x - box_w // 2, y + i), (x + box_w // 2, y + i))

        pygame.draw.rect(screen, (0, 0, 0, 0), (x - box_w // 2, y, box_w, box_h), border_radius=8)
        pygame.draw.rect(screen, self.GOLD, (x - box_w // 2, y, box_w, box_h), 2, border_radius=8)

        # 칩 아이콘
        chip_x = x - box_w // 2 + 28
        chip_y = y + box_h // 2
        self._draw_chip(screen, chip_x, chip_y, 16)

        # 판돈 텍스트
        self._draw_text(screen, "판돈", x + 15, y + 6, self.SILVER, 20, center=True)
        self._draw_text(screen, f"{pot:,}", x + 8, y + 30, self.GOLD_LIGHT, 26, center=True)
        self._draw_gold_coin(screen, x + 60, y + 42, 14)

    def _draw_chip(self, screen, x, y, radius):
        """칩 그리기"""
        # 그림자
        pygame.draw.circle(screen, (0, 0, 0, 80), (x + 2, y + 2), radius)

        # 칩 본체
        pygame.draw.circle(screen, (180, 140, 60), (x, y), radius)
        pygame.draw.circle(screen, self.GOLD, (x, y), radius - 2)
        pygame.draw.circle(screen, (200, 160, 80), (x, y), radius - 4)

        # 칩 테두리 장식
        pygame.draw.circle(screen, (150, 120, 50), (x, y), radius, 2)

        # 내부 선
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            inner_r = radius - 4
            outer_r = radius - 2
            pygame.draw.line(screen, (170, 130, 50),
                           (x + math.cos(rad) * inner_r, y + math.sin(rad) * inner_r),
                           (x + math.cos(rad) * outer_r, y + math.sin(rad) * outer_r), 2)

    def _draw_cards(self, screen):
        """카드 그리기"""
        cx = self.screen_width // 2
        is_showdown = self.game.state in [PokerGame.STATE_SHOWDOWN, PokerGame.STATE_GAME_OVER]
        is_dealing = self.game.state in [PokerGame.STATE_DEALING, PokerGame.STATE_FLOP_DEALING,
                                          PokerGame.STATE_TURN_DEALING, PokerGame.STATE_RIVER_DEALING]

        # 쇼다운 레이아웃
        if is_showdown and self.game.community_cards:
            self._draw_showdown_cards(screen)
            return

        # 딜링 애니메이션 중
        if is_dealing:
            self._draw_animated_cards(screen)
            return

        # 일반 게임 레이아웃
        # 커뮤니티 카드 (중앙) - 위로 올림
        if self.game.community_cards:
            comm_y = self.screen_height // 2 - 30
            total_width = len(self.game.community_cards) * (self.CARD_WIDTH + 10)
            comm_start_x = cx - total_width // 2

            for i, card in enumerate(self.game.community_cards):
                card_x = comm_start_x + i * (self.CARD_WIDTH + 10)
                self.card_renderer.draw_card(screen, card, card_x, comm_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

        # 플레이어 카드 (하단)
        if self.game.player_hand:
            player_y = self.screen_height - 220
            player_start_x = cx - (self.CARD_WIDTH + 15)

            for i, card in enumerate(self.game.player_hand):
                card_x = player_start_x + i * (self.CARD_WIDTH + 15)
                # 살짝 기울이기
                self.card_renderer.draw_card(screen, card, card_x, player_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

            self._draw_text(screen, "YOUR HAND", cx, player_y - 25, self.BLUE, 14, center=True)

        # 딜러 카드 (상단)
        if self.game.dealer_hand:
            dealer_y = 70
            dealer_start_x = cx - (self.CARD_WIDTH + 15)

            for i, card in enumerate(self.game.dealer_hand):
                card_x = dealer_start_x + i * (self.CARD_WIDTH + 15)
                self.card_renderer.draw_card(screen, card, card_x, dealer_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

            self._draw_text(screen, "DEALER", cx, dealer_y - 25, self.RED, 14, center=True)

    def _draw_animated_cards(self, screen):
        """애니메이션 중인 카드 그리기"""
        cx = self.screen_width // 2

        # 이미 배치된 카드들 (애니메이션 완료된 것들)
        # 커뮤니티 카드
        if self.game.community_cards:
            comm_y = self.screen_height // 2 - 30
            total_width = len(self.game.community_cards) * (self.CARD_WIDTH + 10)
            comm_start_x = cx - total_width // 2

            for i, card in enumerate(self.game.community_cards):
                card_x = comm_start_x + i * (self.CARD_WIDTH + 10)
                self.card_renderer.draw_card(screen, card, card_x, comm_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

        # 플레이어 카드 (딜링 완료된 것만)
        player_y = self.screen_height - 220
        player_start_x = cx - (self.CARD_WIDTH + 15)
        for i, card in enumerate(self.game.player_hand):
            # 애니메이션 중인 카드는 제외
            animating = any(a.card == card and not a.completed for a in self.game.card_animations)
            if not animating:
                card_x = player_start_x + i * (self.CARD_WIDTH + 15)
                self.card_renderer.draw_card(screen, card, card_x, player_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

        # 딜러 카드
        dealer_y = 70
        dealer_start_x = cx - (self.CARD_WIDTH + 15)
        for i, card in enumerate(self.game.dealer_hand):
            animating = any(a.card == card and not a.completed for a in self.game.card_animations)
            if not animating:
                card_x = dealer_start_x + i * (self.CARD_WIDTH + 15)
                self.card_renderer.draw_card(screen, card, card_x, dealer_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

        # 펜딩 카드 (커뮤니티 딜링 중)
        if self.game.pending_cards:
            comm_y = self.screen_height // 2 - 30
            base_idx = len(self.game.community_cards)
            base_x = 200 + base_idx * (self.CARD_WIDTH + 10)

            for i, card in enumerate(self.game.pending_cards):
                animating = any(a.card == card and not a.completed for a in self.game.card_animations)
                if not animating:
                    card_x = base_x + i * (self.CARD_WIDTH + 10)
                    self.card_renderer.draw_card(screen, card, card_x, comm_y,
                                                self.CARD_WIDTH, self.CARD_HEIGHT)

        # 애니메이션 중인 카드들
        for anim in self.game.card_animations:
            if not anim.completed:
                # 트레일 효과
                self.particles.emit_card_trail(anim.current_x + self.CARD_WIDTH // 2,
                                              anim.current_y + self.CARD_HEIGHT // 2)

                self.card_renderer.draw_card(
                    screen, anim.card,
                    int(anim.current_x), int(anim.current_y),
                    self.CARD_WIDTH, self.CARD_HEIGHT,
                    scale=anim.scale,
                    rotation=anim.rotation,
                    face_up=anim.flipped
                )

        # 레이블
        if self.game.player_hand:
            self._draw_text(screen, "YOUR HAND", cx, player_y - 25, self.BLUE, 14, center=True)
        if self.game.dealer_hand:
            self._draw_text(screen, "DEALER", cx, 70 - 25, self.RED, 14, center=True)

    def _draw_showdown_cards(self, screen):
        """쇼다운 시 카드 배치 - 오리지널 텍사스 홀덤 방식
        딜러 홀카드 2장만 공개, 커뮤니티 카드는 가운데 유지"""
        cx = self.screen_width // 2

        # 커뮤니티 카드 (중앙) - 그대로 유지
        if self.game.community_cards:
            comm_y = self.screen_height // 2 + 25
            total_width = len(self.game.community_cards) * (self.CARD_WIDTH + 10)
            comm_start_x = cx - total_width // 2

            for i, card in enumerate(self.game.community_cards):
                card_x = comm_start_x + i * (self.CARD_WIDTH + 10)
                self.card_renderer.draw_card(screen, card, card_x, comm_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

            self._draw_text(screen, "COMMUNITY CARDS", cx, comm_y - 30, self.GOLD, 14, center=True)

        # 딜러 카드 (상단) - 2장만, 공개
        if self.game.dealer_hand:
            dealer_y = 70
            dealer_start_x = cx - (self.CARD_WIDTH + 15)

            for i, card in enumerate(self.game.dealer_hand):
                card.face_up = True  # 쇼다운이므로 공개
                card_x = dealer_start_x + i * (self.CARD_WIDTH + 15)

                # 강조 테두리 (공개된 홀카드)
                pygame.draw.rect(screen, (255, 100, 100),
                               (card_x - 3, dealer_y - 3, self.CARD_WIDTH + 6, self.CARD_HEIGHT + 6),
                               2, border_radius=6)

                self.card_renderer.draw_card(screen, card, card_x, dealer_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

            self._draw_text(screen, "DEALER", cx, dealer_y - 25, self.RED, 14, center=True)

        # 플레이어 카드 (하단) - 2장만, 결과 패널 위에 표시
        if self.game.player_hand:
            player_y = self.screen_height - 290  # 결과 패널(높이 130, y=-150)과 겹치지 않게 위로
            player_start_x = cx - (self.CARD_WIDTH + 15)

            for i, card in enumerate(self.game.player_hand):
                card_x = player_start_x + i * (self.CARD_WIDTH + 15)

                # 강조 테두리
                pygame.draw.rect(screen, (100, 150, 255),
                               (card_x - 3, player_y - 3, self.CARD_WIDTH + 6, self.CARD_HEIGHT + 6),
                               2, border_radius=6)

                self.card_renderer.draw_card(screen, card, card_x, player_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

            self._draw_text(screen, "YOUR HAND", cx, player_y - 25, self.BLUE, 14, center=True)

    def _draw_ui(self, screen):
        """기본 UI"""
        # 딜러 골드 표시 (좌상단)
        self._draw_dealer_gold_display(screen, 20, 15)

        # 플레이어 골드 표시 (좌하단)
        self._draw_gold_display(screen, 20, self.screen_height - 50)

        # 현재 베팅 (좌측 중앙)
        if self.game.current_bet > 0:
            self._draw_text(screen, f"BET: {self.game.current_bet}G", 20, self.screen_height - 80, self.SILVER, 14)

        # 연승 표시 (플레이어 골드 옆)
        if self.game.player_win_streak > 0:
            streak_color = (255, 100, 100) if self.game.player_win_streak >= 3 else (255, 200, 100)
            self._draw_text(screen, f"🔥{self.game.player_win_streak}연승", 160, self.screen_height - 42, streak_color, 14)

        # 게임 상태 (우상단)
        state_names = {
            'betting': '베팅',
            'dealing': '딜링...',
            'preflop': '프리플랍',
            'flop_dealing': '플랍...',
            'flop': '플랍',
            'turn_dealing': '턴...',
            'turn': '턴',
            'river_dealing': '리버...',
            'river': '리버',
            'showdown': '쇼다운',
            'game_over': '게임 종료'
        }
        state_text = state_names.get(self.game.state, self.game.state)
        self._draw_status_badge(screen, self.screen_width - 20, 20, state_text)

    def _draw_gold_display(self, screen, x, y):
        """골드 표시 - 인게임 금화 아이콘과 동일"""
        # 배경
        box_w, box_h = 130, 35
        pygame.draw.rect(screen, (30, 25, 40), (x, y, box_w, box_h), border_radius=6)
        pygame.draw.rect(screen, self.GOLD, (x, y, box_w, box_h), 2, border_radius=6)

        # 금화 아이콘 (인게임과 동일)
        coin_size = 22
        self._draw_gold_coin(screen, x + 18, y + box_h // 2 + 1, coin_size)

        # 골드 텍스트 (금화와 수평 맞춤)
        self._draw_text(screen, f"{self.game.player_gold:,}", x + 38, y + 9, self.GOLD_LIGHT, 16)

    def _draw_dealer_gold_display(self, screen, x, y):
        """딜러 골드 표시 - 플레이어와 동일한 스타일 (DEALER 라벨 + 금화 아이콘)"""
        # 배경
        box_w, box_h = 130, 50  # 높이 늘림 (라벨 + 골드)

        # 딜러 골드 비율에 따라 색상 변화 (위험할수록 빨간색)
        gold_ratio = self.game.dealer_gold / max(self.game.initial_dealer_gold, 1)
        if gold_ratio <= 0.3:
            border_color = (255, 80, 80)  # 위험 - 빨간색
            bg_color = (60, 20, 20)
        elif gold_ratio <= 0.5:
            border_color = (255, 180, 80)  # 주의 - 주황색
            bg_color = (50, 30, 20)
        else:
            border_color = (150, 150, 180)  # 안전 - 은색
            bg_color = (30, 25, 40)

        pygame.draw.rect(screen, bg_color, (x, y, box_w, box_h), border_radius=6)
        pygame.draw.rect(screen, border_color, (x, y, box_w, box_h), 2, border_radius=6)

        # "DEALER" 라벨 (상단)
        self._draw_text(screen, "DEALER", x + box_w // 2, y + 5, (180, 180, 200), 12, center=True)

        # 금화 아이콘 + 골드 텍스트 (하단, 플레이어와 동일)
        coin_size = 22
        self._draw_gold_coin(screen, x + 18, y + 35, coin_size)
        self._draw_text(screen, f"{self.game.dealer_gold:,}", x + 38, y + 26, self.GOLD_LIGHT, 16)

    def _draw_gold_coin(self, screen, x, y, size):
        """금화 아이콘 그리기 - 인게임과 동일한 입체감 있는 동전"""
        # 금화 서피스 생성
        coin_surf = pygame.Surface((size + 4, size + 4), pygame.SRCALPHA)

        cx, cy = size // 2 + 2, size // 2 + 2
        radius = size // 2

        # 색상 정의
        gold_dark = (180, 130, 20)      # 어두운 금색 (테두리/그림자)
        gold_main = (255, 200, 50)       # 메인 금색
        gold_light = (255, 235, 120)     # 밝은 금색 (하이라이트)
        gold_shine = (255, 250, 200)     # 반짝임

        # 그림자 (약간 아래 오른쪽)
        pygame.draw.circle(coin_surf, (0, 0, 0, 80), (cx + 2, cy + 2), radius)

        # 외곽 테두리 (어두운 금색)
        pygame.draw.circle(coin_surf, gold_dark, (cx, cy), radius)

        # 메인 금화
        pygame.draw.circle(coin_surf, gold_main, (cx, cy), radius - 2)

        # 내부 테두리 (입체감)
        pygame.draw.circle(coin_surf, gold_dark, (cx, cy), radius - 3, 1)

        # 상단 하이라이트 (반원)
        highlight_rect = (cx - radius + 4, cy - radius + 3, (radius - 4) * 2, radius - 2)
        pygame.draw.arc(coin_surf, gold_light, highlight_rect, 0.5, 2.6, 2)

        # 중앙에 별 무늬
        star_size = radius // 2
        star_points = []
        for i in range(5):
            # 바깥 점
            angle = math.pi / 2 + i * 2 * math.pi / 5
            px = cx + int(star_size * math.cos(angle))
            py = cy - int(star_size * math.sin(angle))
            star_points.append((px, py))
            # 안쪽 점
            angle += math.pi / 5
            px = cx + int(star_size * 0.4 * math.cos(angle))
            py = cy - int(star_size * 0.4 * math.sin(angle))
            star_points.append((px, py))

        if len(star_points) >= 3:
            pygame.draw.polygon(coin_surf, gold_dark, star_points)
            # 별 하이라이트
            inner_star = [(int(cx + (p[0] - cx) * 0.7), int(cy + (p[1] - cy) * 0.7)) for p in star_points]
            if len(inner_star) >= 3:
                pygame.draw.polygon(coin_surf, gold_light, inner_star)

        # 반짝임 효과 (우상단)
        pygame.draw.circle(coin_surf, gold_shine, (cx + radius // 3, cy - radius // 3), 2)

        screen.blit(coin_surf, (x - size // 2, y - size // 2))

    def _draw_status_badge(self, screen, x, y, text):
        """상태 배지"""
        # 텍스트 크기 계산
        padding = 15
        text_w = len(text) * 10 + padding * 2
        box_h = 28

        box_x = x - text_w

        # 배경
        pygame.draw.rect(screen, (40, 35, 55), (box_x, y, text_w, box_h), border_radius=4)
        pygame.draw.rect(screen, self.BLUE, (box_x, y, text_w, box_h), 2, border_radius=4)

        # 텍스트
        self._draw_text(screen, text, box_x + text_w // 2, y + 5, self.WHITE, 14, center=True)

    def _draw_betting_ui(self, screen):
        """베팅 UI (프리미엄)"""
        cx = self.screen_width // 2
        y = self.screen_height - 85

        # 베팅 박스
        box_w, box_h = 340, 70
        box_x = cx - box_w // 2

        # 그림자
        pygame.draw.rect(screen, (0, 0, 0, 80), (box_x + 4, y + 4, box_w, box_h), border_radius=12)

        # 배경 그라데이션
        for i in range(box_h):
            ratio = i / box_h
            r = int(35 + ratio * 15)
            g = int(30 + ratio * 12)
            b = int(50 + ratio * 15)
            pygame.draw.line(screen, (r, g, b), (box_x, y + i), (box_x + box_w, y + i))

        pygame.draw.rect(screen, self.GOLD, (box_x, y, box_w, box_h), 2, border_radius=12)

        # 베팅 금액 표시
        self._draw_text(screen, "베팅 금액", cx, y + 8, self.SILVER, 12, center=True)

        # 금액과 화살표
        arrow_y = y + 35

        # 왼쪽 화살표
        pygame.draw.polygon(screen, self.GOLD, [
            (cx - 100, arrow_y),
            (cx - 85, arrow_y - 10),
            (cx - 85, arrow_y + 10)
        ])

        # 금액 + 골드 코인 아이콘
        self._draw_text(screen, f"{self.bet_amount:,}", cx - 10, y + 28, self.GOLD_LIGHT, 24, center=True)
        self._draw_gold_coin(screen, cx + 45, y + 38, 16)

        # 오른쪽 화살표
        pygame.draw.polygon(screen, self.GOLD, [
            (cx + 100, arrow_y),
            (cx + 85, arrow_y - 10),
            (cx + 85, arrow_y + 10)
        ])

        # 조작법
        self._draw_text(screen, "◀▶/휠: ±10  ▲▼: ±50  Space: 확인  ESC: 나가기",
                       cx, y + 55, (120, 120, 130), 11, center=True)

    def _draw_dealing_ui(self, screen):
        """딜링 중 UI"""
        cx = self.screen_width // 2
        y = self.screen_height - 60

        # 로딩 표시
        dots = "." * (int(self.animation_timer * 3) % 4)
        self._draw_text(screen, f"딜링 중{dots}", cx, y, self.SILVER, 16, center=True)

    def _draw_action_ui(self, screen):
        """액션 UI (프리미엄) - 마우스 호버/클릭 지원"""
        cx = self.screen_width // 2
        y = self.screen_height - 85

        # 딜러 레이즈 정보 표시
        call_amount = self.game.get_call_amount()
        if call_amount > 0:
            # 딜러가 레이즈했음을 알림
            dealer_msg_y = y - 45
            pygame.draw.rect(screen, (60, 40, 40), (cx - 120, dealer_msg_y - 5, 240, 30), border_radius=6)
            pygame.draw.rect(screen, (200, 100, 100), (cx - 120, dealer_msg_y - 5, 240, 30), 2, border_radius=6)
            self._draw_text(screen, f"딜러 레이즈! +{call_amount}G", cx, dealer_msg_y, (255, 150, 150), 14, center=True)

        # 콜 버튼 텍스트 (콜 금액 표시)
        if call_amount > 0:
            call_text = f"콜 {call_amount}G"
            call_show_gold = True
        else:
            call_text = "체크"  # 딜러가 체크했으면 플레이어도 체크
            call_show_gold = False

        actions = [
            (call_text, (80, 180, 100), (100, 220, 120), call_show_gold),
            (f"레이즈 +{self.raise_amount}", (200, 170, 60), (240, 200, 80), True),  # 골드 아이콘 표시
            ("폴드", (180, 80, 80), (220, 100, 100), False)
        ]

        btn_w, btn_h = 110, 50
        total_w = len(actions) * btn_w + (len(actions) - 1) * 15
        start_x = cx - total_w // 2

        # 버튼 영역 저장 (마우스 처리용)
        self.action_buttons = []

        for i, (action, color, color_light, show_gold_icon) in enumerate(actions):
            btn_x = start_x + i * (btn_w + 15)

            # 버튼 영역 저장
            btn_rect = pygame.Rect(btn_x, y, btn_w, btn_h)
            self.action_buttons.append(btn_rect)

            # 선택 또는 호버 여부
            is_selected = (i == self.selected_action)
            is_hovered = (i == self.hovered_action)

            # 콜 금액이 플레이어 골드보다 크면 비활성화
            is_disabled = (i == 0 and call_amount > self.game.player_gold)

            # 그림자
            pygame.draw.rect(screen, (0, 0, 0, 80), (btn_x + 3, y + 3, btn_w, btn_h), border_radius=8)

            if is_disabled:
                # 비활성화 버튼
                pygame.draw.rect(screen, (50, 50, 55), (btn_x, y, btn_w, btn_h), border_radius=8)
                pygame.draw.rect(screen, (80, 80, 90), (btn_x, y, btn_w, btn_h), 2, border_radius=8)
                text_color = (100, 100, 110)
            elif is_selected:
                # 선택된 버튼 (글로우 효과)
                pygame.draw.rect(screen, (*color_light, 50), (btn_x - 4, y - 4, btn_w + 8, btn_h + 8), border_radius=10)
                pygame.draw.rect(screen, color_light, (btn_x, y, btn_w, btn_h), border_radius=8)
                pygame.draw.rect(screen, self.WHITE, (btn_x, y, btn_w, btn_h), 2, border_radius=8)
                text_color = self.WHITE
            elif is_hovered:
                # 호버 효과 (선택보다 약간 연한 효과)
                hover_color = tuple(min(255, c + 30) for c in color)
                pygame.draw.rect(screen, (*color, 30), (btn_x - 2, y - 2, btn_w + 4, btn_h + 4), border_radius=9)
                pygame.draw.rect(screen, hover_color, (btn_x, y, btn_w, btn_h), border_radius=8)
                pygame.draw.rect(screen, color_light, (btn_x, y, btn_w, btn_h), 2, border_radius=8)
                text_color = self.WHITE
            else:
                pygame.draw.rect(screen, (40, 35, 50), (btn_x, y, btn_w, btn_h), border_radius=8)
                pygame.draw.rect(screen, color, (btn_x, y, btn_w, btn_h), 2, border_radius=8)
                text_color = (150, 150, 160)

            # 텍스트와 골드 아이콘 그리기
            if show_gold_icon:
                # 버튼: 텍스트 + 골드 코인 아이콘
                text_x = btn_x + btn_w // 2 - 8  # 텍스트를 왼쪽으로 약간 이동
                text_y = y + btn_h // 2 - 10
                self._draw_text(screen, action, text_x, text_y, text_color, 14, center=True)
                # 골드 코인 아이콘 (텍스트와 수평 맞춤)
                coin_x = btn_x + btn_w - 18
                coin_y = text_y + 7  # 텍스트 중앙과 수평 맞춤
                self._draw_gold_coin(screen, coin_x, coin_y, 14)
            else:
                self._draw_text(screen, action, btn_x + btn_w // 2, y + btn_h // 2 - 10, text_color, 14, center=True)

        # 레이즈 범위 표시
        range_text = f"레이즈: {self.min_raise}~{self.max_raise}G (±{self.raise_step})"
        self._draw_text(screen, range_text, cx, y + 55, (120, 120, 140), 10, center=True)

        # 조작법
        self._draw_text(screen, "◀▶/클릭: 선택  ▲▼/휠: 레이즈 조절  Space: 확인  ESC: 나가기",
                       cx, y + 70, (100, 100, 110), 10, center=True)

    def _draw_result_ui(self, screen):
        """결과 UI (프리미엄)"""
        cx = self.screen_width // 2

        # 딜러 파산 특별 화면
        if self.game.dealer_bankrupt:
            self._draw_dealer_bankrupt_ui(screen)
            return

        # 결과 박스
        box_w, box_h = 420, 130
        box_y = self.screen_height - 150

        # 그림자
        pygame.draw.rect(screen, (0, 0, 0, 100), (cx - box_w // 2 + 5, box_y + 5, box_w, box_h), border_radius=15)

        # 결과 색상
        if self.game.winner == 'player':
            result_color = (80, 220, 100)
            glow_color = (100, 255, 120, 30)
            title = "VICTORY!"
        elif self.game.winner == 'dealer':
            result_color = (220, 80, 80)
            glow_color = (255, 100, 100, 30)
            title = "DEFEAT"
        else:
            result_color = (220, 200, 80)
            glow_color = (255, 240, 100, 30)
            title = "TIE"

        # 글로우 효과
        glow_surf = pygame.Surface((box_w + 20, box_h + 20), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, glow_color, (0, 0, box_w + 20, box_h + 20), border_radius=18)
        screen.blit(glow_surf, (cx - box_w // 2 - 10, box_y - 10))

        # 배경
        for i in range(box_h):
            ratio = i / box_h
            r = int(25 + ratio * 15)
            g = int(20 + ratio * 12)
            b = int(35 + ratio * 18)
            pygame.draw.line(screen, (r, g, b),
                           (cx - box_w // 2, box_y + i), (cx + box_w // 2, box_y + i))

        pygame.draw.rect(screen, result_color, (cx - box_w // 2, box_y, box_w, box_h), 3, border_radius=15)

        # 결과 타이틀
        self._draw_text(screen, title, cx, box_y + 12, result_color, 28, center=True)

        # 패 정보
        info_y = box_y + 50
        if self.game.player_hand_result:
            p_name = self.game.player_hand_result[2]
            self._draw_text(screen, f"나: {p_name}", cx - 90, info_y, (150, 200, 255), 14, center=True)

        if self.game.dealer_hand_result:
            d_name = self.game.dealer_hand_result[2]
            self._draw_text(screen, f"딜러: {d_name}", cx + 90, info_y, (255, 150, 150), 14, center=True)

        # 골드 변화
        gold_text = f"골드: {self.game.player_gold:,}G"
        self._draw_text(screen, gold_text, cx, info_y + 25, self.GOLD_LIGHT, 16, center=True)

        # 계속하기
        if self.game.player_gold >= self.game.min_bet:
            self._draw_text(screen, "Enter: 계속  ESC: 나가기", cx, info_y + 50, (120, 120, 130), 12, center=True)
        else:
            self._draw_text(screen, "골드 부족! ESC: 나가기", cx, info_y + 50, (255, 100, 100), 12, center=True)

    def _draw_dealer_bankrupt_ui(self, screen):
        """딜러 파산 특별 화면"""
        cx = self.screen_width // 2
        cy = self.screen_height // 2

        # 전체 화면 어둡게
        overlay = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        screen.blit(overlay, (0, 0))

        # 결과 박스 (더 크게)
        box_w, box_h = 450, 200
        box_x = cx - box_w // 2
        box_y = cy - box_h // 2

        # 황금색 글로우
        glow_surf = pygame.Surface((box_w + 40, box_h + 40), pygame.SRCALPHA)
        for i in range(20, 0, -2):
            alpha = int(50 * (1 - i / 20))
            pygame.draw.rect(glow_surf, (255, 200, 50, alpha),
                           (20 - i, 20 - i, box_w + i * 2, box_h + i * 2), border_radius=20)
        screen.blit(glow_surf, (box_x - 20, box_y - 20))

        # 배경 (황금 그라데이션)
        for i in range(box_h):
            ratio = i / box_h
            r = int(40 + ratio * 20)
            g = int(35 + ratio * 15)
            b = int(20 + ratio * 10)
            pygame.draw.line(screen, (r, g, b),
                           (box_x, box_y + i), (box_x + box_w, box_y + i))

        pygame.draw.rect(screen, self.GOLD, (box_x, box_y, box_w, box_h), 4, border_radius=15)

        # 타이틀
        self._draw_text(screen, "🎉 딜러 파산! 🎉", cx, box_y + 20, self.GOLD, 32, center=True)

        # 서브 타이틀
        self._draw_text(screen, "축하합니다! 딜러의 자금을 모두 털었습니다!", cx, box_y + 65, (255, 255, 200), 16, center=True)

        # 획득 정보
        total_won = self.game.initial_dealer_gold
        self._draw_text(screen, f"딜러 초기 자금: {self.game.initial_dealer_gold:,}G", cx, box_y + 100, (200, 200, 200), 14, center=True)
        self._draw_text(screen, f"최종 보유 골드: {self.game.player_gold:,}G", cx, box_y + 125, self.GOLD_LIGHT, 18, center=True)

        # 안내
        self._draw_text(screen, "테이블이 닫힙니다. ESC를 눌러 나가세요.", cx, box_y + 160, (150, 150, 160), 14, center=True)

    def _draw_text(self, screen, text, x, y, color, size, center=False, right=False):
        """텍스트 그리기"""
        if self.fonts:
            if size >= 28:
                font_key = 'large'
            elif size <= 14:
                font_key = 'small'
            else:
                font_key = 'medium'

            font = self.fonts.get(font_key) or self.fonts.get('medium') or self.fonts.get('default')
            if font:
                try:
                    text_surface, text_rect = font.render(text, color)

                    if center:
                        text_rect.centerx = x
                        text_rect.y = y
                    elif right:
                        text_rect.right = x
                        text_rect.y = y
                    else:
                        text_rect.x = x
                        text_rect.y = y

                    screen.blit(text_surface, text_rect)
                    return
                except Exception:
                    pass

        if size not in self._font_cache:
            try:
                for font_name in ['NanumGothic', 'AppleGothic', 'malgun gothic', 'Arial']:
                    try:
                        self._font_cache[size] = pygame.font.SysFont(font_name, size)
                        break
                    except:
                        continue
                if size not in self._font_cache:
                    self._font_cache[size] = pygame.font.Font(None, size + 10)
            except:
                self._font_cache[size] = pygame.font.Font(None, size + 10)

        font = self._font_cache[size]
        text_surface = font.render(text, True, color)
        text_rect = text_surface.get_rect()

        if center:
            text_rect.centerx = x
            text_rect.y = y
        elif right:
            text_rect.right = x
            text_rect.y = y
        else:
            text_rect.x = x
            text_rect.y = y

        screen.blit(text_surface, text_rect)

    def get_player_gold(self):
        return self.game.player_gold if self.game else 0


# ============================================
# 테스트용 메인
# ============================================
if __name__ == "__main__":
    pygame.init()
    pygame.mixer.init()  # 믹서 초기화 (BGM용)
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("텍사스 홀덤 포커 - Premium")
    clock = pygame.time.Clock()

    ui = PokerGameUI(800, 600)
    ui.start_game(1000)

    running = True
    while running:
        dt = clock.tick(60) / 1000.0

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                # BGM 정지 후 종료
                if ui.bgm:
                    ui.bgm.stop()
                running = False
            else:
                result = ui.handle_event(event)
                if result == 'exit':
                    running = False

        ui.update(dt)
        ui.draw(screen)
        pygame.display.flip()

    pygame.quit()
