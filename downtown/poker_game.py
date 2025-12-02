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
        for combo in combinations(cards, 5):
            rank, tiebreaker = HandEvaluator._evaluate_five(list(combo))
            if rank > best_rank or (rank == best_rank and tiebreaker > best_tiebreaker):
                best_rank = rank
                best_tiebreaker = tiebreaker
                best_hand = combo

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

    def __init__(self, player_gold=1000):
        self.deck = Deck()
        self.player_hand = []
        self.dealer_hand = []
        self.community_cards = []

        self.player_gold = player_gold
        self.pot = 0
        self.current_bet = 0
        self.min_bet = 10
        self.max_bet = 500

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
        player_x1, player_y = 340, 420
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

    def fold(self):
        if self.state in [self.STATE_PREFLOP, self.STATE_FLOP, self.STATE_TURN, self.STATE_RIVER]:
            self.winner = 'dealer'
            self.result_message = "폴드! 딜러 승리"
            self.state = self.STATE_GAME_OVER
            return True
        return False

    def call(self):
        if self.state in [self.STATE_PREFLOP, self.STATE_FLOP, self.STATE_TURN, self.STATE_RIVER]:
            self.proceed_to_next_stage()
            return True
        return False

    def raise_bet(self, additional_amount):
        if self.state in [self.STATE_PREFLOP, self.STATE_FLOP, self.STATE_TURN, self.STATE_RIVER]:
            if additional_amount <= self.player_gold:
                self.player_gold -= additional_amount
                self.pot += additional_amount * 2
                self.current_bet += additional_amount
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

        if p_rank > d_rank:
            self.winner = 'player'
            self.player_gold += self.pot
            self.result_message = f"승리! {p_name}"
        elif d_rank > p_rank:
            self.winner = 'dealer'
            self.result_message = f"패배... 딜러 {d_name}"
        else:
            if p_tie > d_tie:
                self.winner = 'player'
                self.player_gold += self.pot
                self.result_message = f"승리! {p_name} (하이 카드)"
            elif d_tie > p_tie:
                self.winner = 'dealer'
                self.result_message = f"패배... 딜러 {d_name} (하이 카드)"
            else:
                self.winner = 'tie'
                self.player_gold += self.pot // 2
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
            elif self.state == self.STATE_FLOP_DEALING:
                self.state = self.STATE_FLOP
            elif self.state == self.STATE_TURN_DEALING:
                self.state = self.STATE_TURN
            elif self.state == self.STATE_RIVER_DEALING:
                self.state = self.STATE_RIVER


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
        """카드 앞면 (프리미엄)"""
        # 배경 그라데이션
        for i in range(h):
            ratio = i / h
            r = int(255 - ratio * 10)
            g = int(252 - ratio * 10)
            b = int(245 - ratio * 12)
            pygame.draw.line(surf, (r, g, b), (0, i), (w, i))

        # 테두리
        pygame.draw.rect(surf, (200, 195, 185), (0, 0, w, h), 2, border_radius=8)

        # 카드 내부 테두리
        pygame.draw.rect(surf, (230, 225, 215), (3, 3, w-6, h-6), 1, border_radius=6)

        suit_color = Card.SUIT_COLORS[card.suit]
        symbol = Card.SUIT_SYMBOLS[card.suit]

        # 좌상단 랭크와 심볼
        self._draw_rank(surf, card.rank, 6, 4, suit_color, int(w * 0.28))
        self._draw_suit_symbol(surf, symbol, 7, int(h * 0.22), suit_color, int(w * 0.22))

        # 중앙 대형 심볼 또는 페이스 카드 디자인
        if card.rank in ['J', 'Q', 'K']:
            self._draw_face_card(surf, card, w, h, suit_color)
        elif card.rank == 'A':
            self._draw_ace_card(surf, card, w, h, suit_color, symbol)
        else:
            self._draw_pip_card(surf, card, w, h, suit_color, symbol)

        # 우하단 (180도 회전 효과)
        self._draw_rank(surf, card.rank, w - 6 - int(w * 0.2), h - 4 - int(h * 0.22), suit_color, int(w * 0.28), flip=True)

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
        """무늬를 도형으로 직접 그리기 (폰트 의존 없음) - 개선된 버전"""
        s = max(6, size)
        half = s // 2

        if suit_symbol == '♥':  # 하트
            # 두 개의 원 + 삼각형으로 하트 구성
            r = int(s * 0.28)
            # 왼쪽 상단 원
            pygame.draw.circle(surf, color, (int(cx - r * 0.7), int(cy - r * 0.3)), r)
            # 오른쪽 상단 원
            pygame.draw.circle(surf, color, (int(cx + r * 0.7), int(cy - r * 0.3)), r)
            # 하단 삼각형
            points = [
                (cx - r * 1.65, cy - r * 0.1),
                (cx + r * 1.65, cy - r * 0.1),
                (cx, cy + r * 1.8)
            ]
            pygame.draw.polygon(surf, color, points)

        elif suit_symbol == '♦':  # 다이아몬드
            points = [
                (cx, cy - half),
                (cx + half * 0.65, cy),
                (cx, cy + half),
                (cx - half * 0.65, cy)
            ]
            pygame.draw.polygon(surf, color, points)

        elif suit_symbol == '♣':  # 클럽 (클로버)
            r = int(s * 0.22)
            # 위쪽 원
            pygame.draw.circle(surf, color, (int(cx), int(cy - r * 1.1)), r)
            # 왼쪽 원
            pygame.draw.circle(surf, color, (int(cx - r * 1.0), int(cy + r * 0.2)), r)
            # 오른쪽 원
            pygame.draw.circle(surf, color, (int(cx + r * 1.0), int(cy + r * 0.2)), r)
            # 줄기
            stem_w = max(2, int(s * 0.12))
            pygame.draw.polygon(surf, color, [
                (cx - stem_w, cy + r * 0.3),
                (cx + stem_w, cy + r * 0.3),
                (cx + stem_w * 1.5, cy + half),
                (cx - stem_w * 1.5, cy + half)
            ])

        elif suit_symbol == '♠':  # 스페이드
            # 뒤집힌 하트 형태 (원 2개 + 삼각형)
            r = int(s * 0.25)
            # 왼쪽 하단 원
            pygame.draw.circle(surf, color, (int(cx - r * 0.7), int(cy + r * 0.15)), r)
            # 오른쪽 하단 원
            pygame.draw.circle(surf, color, (int(cx + r * 0.7), int(cy + r * 0.15)), r)
            # 상단 삼각형 (뾰족한 부분)
            points = [
                (cx - r * 1.6, cy + r * 0.3),
                (cx + r * 1.6, cy + r * 0.3),
                (cx, cy - r * 1.7)
            ]
            pygame.draw.polygon(surf, color, points)
            # 줄기
            stem_w = max(2, int(s * 0.12))
            pygame.draw.polygon(surf, color, [
                (cx - stem_w, cy + r * 0.5),
                (cx + stem_w, cy + r * 0.5),
                (cx + stem_w * 1.5, cy + half),
                (cx - stem_w * 1.5, cy + half)
            ])

    def _draw_face_card(self, surf, card, w, h, color):
        """페이스 카드 (J, Q, K) 디자인"""
        cx, cy = w // 2, h // 2
        symbol = Card.SUIT_SYMBOLS[card.suit]

        # 중앙 프레임
        frame_w = int(w * 0.7)
        frame_h = int(h * 0.5)
        frame_x = cx - frame_w // 2
        frame_y = cy - frame_h // 2 + 5

        # 프레임 배경
        pygame.draw.rect(surf, (*color, 30), (frame_x, frame_y, frame_w, frame_h), border_radius=4)
        pygame.draw.rect(surf, color, (frame_x, frame_y, frame_w, frame_h), 2, border_radius=4)

        # 페이스 카드 글자
        letter = card.rank
        try:
            font = pygame.font.SysFont('Georgia', int(w * 0.45))
        except:
            font = pygame.font.Font(None, int(w * 0.45) + 4)

        text = font.render(letter, True, color)
        text_rect = text.get_rect(center=(cx, cy - 2))
        surf.blit(text, text_rect)

        # 프레임 내 작은 무늬
        small_suit_size = int(w * 0.18)
        self._draw_suit_shape(surf, symbol, cx, cy + int(h * 0.16), small_suit_size, color)

        # 장식 라인
        pygame.draw.line(surf, (*color, 100), (frame_x + 5, frame_y + 5),
                        (frame_x + frame_w - 5, frame_y + 5), 1)
        pygame.draw.line(surf, (*color, 100), (frame_x + 5, frame_y + frame_h - 5),
                        (frame_x + frame_w - 5, frame_y + frame_h - 5), 1)

    def _draw_ace_card(self, surf, card, w, h, color, symbol):
        """에이스 카드 디자인"""
        cx, cy = w // 2, h // 2

        # 대형 중앙 심볼 - 도형으로 직접 그리기
        large_size = int(w * 0.65)
        self._draw_suit_shape(surf, symbol, cx, cy + 5, large_size, color)

        # 장식 원
        pygame.draw.circle(surf, (*color, 40), (cx, cy + 5), int(w * 0.35), 2)

    def _draw_pip_card(self, surf, card, w, h, color, symbol):
        """숫자 카드 핍 패턴 - 개선된 레이아웃"""
        cx, cy = w // 2, h // 2
        value = card.get_value()

        # 핍 크기 (카드 크기에 비례, 더 작게)
        pip_size = int(w * 0.18)

        # 핍 배치 (카드 값에 따라)
        positions = self._get_pip_positions(value, w, h)

        for px, py, flipped in positions:
            # 도형으로 직접 그리기
            self._draw_suit_shape(surf, symbol, int(px), int(py), pip_size, color)

    def _get_pip_positions(self, value, w, h):
        """핍 위치 계산 - 랭크/심볼 영역 피해서 배치"""
        cx, cy = w // 2, h // 2

        # 핍 영역 (좌상단/우하단 랭크+심볼 영역 피함)
        # 상단 마진 더 크게 (랭크+심볼 영역)
        top_margin = int(h * 0.32)
        bot_margin = int(h * 0.68)

        top = int(h * 0.35)
        bot = int(h * 0.65)
        mid = cy

        # 좌우도 여유있게
        left = int(w * 0.30)
        right = int(w * 0.70)

        patterns = {
            2: [(cx, top, False), (cx, bot, True)],
            3: [(cx, top, False), (cx, mid, False), (cx, bot, True)],
            4: [(left, top, False), (right, top, False), (left, bot, True), (right, bot, True)],
            5: [(left, top, False), (right, top, False), (cx, mid, False), (left, bot, True), (right, bot, True)],
            6: [(left, top, False), (right, top, False), (left, mid, False), (right, mid, False), (left, bot, True), (right, bot, True)],
            7: [(left, top, False), (right, top, False), (cx, int(h*0.42), False), (left, mid, False), (right, mid, False), (left, bot, True), (right, bot, True)],
            8: [(left, top, False), (right, top, False), (cx, int(h*0.40), False), (left, mid, False), (right, mid, False), (cx, int(h*0.60), True), (left, bot, True), (right, bot, True)],
            9: [(left, top, False), (right, top, False), (left, int(h*0.43), False), (right, int(h*0.43), False), (cx, mid, False), (left, int(h*0.57), True), (right, int(h*0.57), True), (left, bot, True), (right, bot, True)],
            10: [(left, top, False), (right, top, False), (cx, int(h*0.38), False), (left, int(h*0.45), False), (right, int(h*0.45), False), (left, int(h*0.55), True), (right, int(h*0.55), True), (cx, int(h*0.62), True), (left, bot, True), (right, bot, True)],
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
        self.selected_action = 0
        self.raise_amount = 20

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

    def start_game(self, player_gold):
        self.game = PokerGame(player_gold)
        self.game.start_new_round()
        self.bet_amount = min(50, player_gold)
        self.result_shown = False

    def handle_event(self, event):
        if not self.game:
            return None

        if event.type == pygame.KEYDOWN:
            # 애니메이션 중에는 입력 무시 (일부 상태)
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
        elif event.key in [pygame.K_RETURN, pygame.K_z]:
            if self.game.place_bet(self.bet_amount):
                # 칩 애니메이션
                self._spawn_chip_animation(self.bet_amount)
                return 'bet_placed'
        elif event.key == pygame.K_ESCAPE:
            return 'exit'
        return None

    def _handle_action_input(self, event):
        if event.key == pygame.K_LEFT:
            self.selected_action = (self.selected_action - 1) % 3
        elif event.key == pygame.K_RIGHT:
            self.selected_action = (self.selected_action + 1) % 3
        elif event.key == pygame.K_UP:
            if self.selected_action == 1:
                self.raise_amount = min(100, self.game.player_gold, self.raise_amount + 10)
        elif event.key == pygame.K_DOWN:
            if self.selected_action == 1:
                self.raise_amount = max(10, self.raise_amount - 10)
        elif event.key in [pygame.K_RETURN, pygame.K_z]:
            if self.selected_action == 0:
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
        elif event.key == pygame.K_ESCAPE:
            return 'exit'
        return None

    def _handle_result_input(self, event):
        if event.key in [pygame.K_RETURN, pygame.K_z]:
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

        if self.game:
            self.game.update(dt)

            # 승리 시 파티클 효과
            if self.game.state == PokerGame.STATE_SHOWDOWN and not self.result_shown:
                self.result_shown = True
                if self.game.winner == 'player':
                    self.particles.emit_win(self.screen_width // 2, self.screen_height // 2)

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
        """프리미엄 포커 테이블"""
        cx, cy = self.screen_width // 2, self.screen_height // 2 + 20

        # 테이블 크기
        table_w, table_h = 520, 320

        # 테이블 그림자
        shadow_surf = pygame.Surface((table_w + 40, table_h + 40), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 80), (0, 0, table_w + 40, table_h + 40))
        screen.blit(shadow_surf, (cx - table_w // 2 - 20, cy - table_h // 2 - 10))

        # 테이블 외곽 (나무 프레임)
        pygame.draw.ellipse(screen, self.TABLE_BORDER,
                           (cx - table_w // 2 - 15, cy - table_h // 2 - 15, table_w + 30, table_h + 30))
        pygame.draw.ellipse(screen, self.TABLE_BORDER_LIGHT,
                           (cx - table_w // 2 - 15, cy - table_h // 2 - 15, table_w + 30, table_h + 30), 3)

        # 펠트 (그라데이션 효과)
        for i in range(5):
            ratio = i / 5
            color = (
                int(self.TABLE_FELT[0] + (self.TABLE_FELT_LIGHT[0] - self.TABLE_FELT[0]) * ratio * 0.3),
                int(self.TABLE_FELT[1] + (self.TABLE_FELT_LIGHT[1] - self.TABLE_FELT[1]) * ratio * 0.3),
                int(self.TABLE_FELT[2] + (self.TABLE_FELT_LIGHT[2] - self.TABLE_FELT[2]) * ratio * 0.3)
            )
            pygame.draw.ellipse(screen, color,
                               (cx - table_w // 2 + i * 2, cy - table_h // 2 + i * 2,
                                table_w - i * 4, table_h - i * 4))

        # 테이블 내부 라인
        pygame.draw.ellipse(screen, (45, 130, 90),
                           (cx - table_w // 2 + 25, cy - table_h // 2 + 25,
                            table_w - 50, table_h - 50), 2)

        # 중앙 로고/장식
        self._draw_table_logo(screen, cx, cy - 20)

        # POT 표시
        self._draw_pot_display(screen, cx, cy + 50)

    def _draw_table_logo(self, screen, x, y):
        """테이블 중앙 로고"""
        # 장식 원
        pygame.draw.circle(screen, (40, 115, 75), (x, y), 35, 2)
        pygame.draw.circle(screen, (50, 140, 90), (x, y), 25, 1)

        # 텍스트
        self._draw_text(screen, "POKER", x, y - 8, (60, 150, 100), 16, center=True)

    def _draw_pot_display(self, screen, x, y):
        """팟 표시 (프리미엄)"""
        pot = self.game.pot

        # 팟 박스
        box_w, box_h = 140, 45

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
        chip_x = x - box_w // 2 + 25
        chip_y = y + box_h // 2
        self._draw_chip(screen, chip_x, chip_y, 15)

        # POT 텍스트
        self._draw_text(screen, "POT", x + 10, y + 5, self.SILVER, 12, center=True)
        self._draw_text(screen, f"{pot:,}G", x + 10, y + 22, self.GOLD_LIGHT, 18, center=True)

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
        # 커뮤니티 카드 (중앙)
        if self.game.community_cards:
            comm_y = self.screen_height // 2 + 25
            total_width = len(self.game.community_cards) * (self.CARD_WIDTH + 10)
            comm_start_x = cx - total_width // 2

            for i, card in enumerate(self.game.community_cards):
                card_x = comm_start_x + i * (self.CARD_WIDTH + 10)
                self.card_renderer.draw_card(screen, card, card_x, comm_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

        # 플레이어 카드 (하단)
        if self.game.player_hand:
            player_y = self.screen_height - 160
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
            comm_y = self.screen_height // 2 + 25
            total_width = len(self.game.community_cards) * (self.CARD_WIDTH + 10)
            comm_start_x = cx - total_width // 2

            for i, card in enumerate(self.game.community_cards):
                card_x = comm_start_x + i * (self.CARD_WIDTH + 10)
                self.card_renderer.draw_card(screen, card, card_x, comm_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

        # 플레이어 카드 (딜링 완료된 것만)
        player_y = self.screen_height - 160
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
            comm_y = self.screen_height // 2 + 25
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

        # 플레이어 카드 (하단) - 2장만
        if self.game.player_hand:
            player_y = self.screen_height - 160
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
        # 골드 표시 (좌상단)
        self._draw_gold_display(screen, 20, 15)

        # 현재 베팅 (좌측)
        if self.game.current_bet > 0:
            self._draw_text(screen, f"BET: {self.game.current_bet}G", 20, 55, self.SILVER, 14)

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
        self._draw_gold_coin(screen, x + 18, y + box_h // 2, coin_size)

        # 골드 텍스트
        self._draw_text(screen, f"{self.game.player_gold:,}", x + 38, y + 8, self.GOLD_LIGHT, 16)

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
        self._draw_text(screen, "BET AMOUNT", cx, y + 8, self.SILVER, 12, center=True)

        # 금액과 화살표
        arrow_y = y + 35

        # 왼쪽 화살표
        pygame.draw.polygon(screen, self.GOLD, [
            (cx - 100, arrow_y),
            (cx - 85, arrow_y - 10),
            (cx - 85, arrow_y + 10)
        ])

        # 금액
        self._draw_text(screen, f"{self.bet_amount:,}G", cx, y + 28, self.GOLD_LIGHT, 24, center=True)

        # 오른쪽 화살표
        pygame.draw.polygon(screen, self.GOLD, [
            (cx + 100, arrow_y),
            (cx + 85, arrow_y - 10),
            (cx + 85, arrow_y + 10)
        ])

        # 조작법
        self._draw_text(screen, "◀▶: ±10G  ▲▼: ±50G  Enter: 확인  ESC: 나가기",
                       cx, y + 55, (120, 120, 130), 11, center=True)

    def _draw_dealing_ui(self, screen):
        """딜링 중 UI"""
        cx = self.screen_width // 2
        y = self.screen_height - 60

        # 로딩 표시
        dots = "." * (int(self.animation_timer * 3) % 4)
        self._draw_text(screen, f"딜링 중{dots}", cx, y, self.SILVER, 16, center=True)

    def _draw_action_ui(self, screen):
        """액션 UI (프리미엄)"""
        cx = self.screen_width // 2
        y = self.screen_height - 85

        actions = [
            ("CALL", (80, 180, 100), (100, 220, 120)),
            (f"RAISE +{self.raise_amount}G", (200, 170, 60), (240, 200, 80)),
            ("FOLD", (180, 80, 80), (220, 100, 100))
        ]

        btn_w, btn_h = 110, 50
        total_w = len(actions) * btn_w + (len(actions) - 1) * 15
        start_x = cx - total_w // 2

        for i, (action, color, color_light) in enumerate(actions):
            btn_x = start_x + i * (btn_w + 15)

            # 선택 여부
            is_selected = (i == self.selected_action)

            # 그림자
            pygame.draw.rect(screen, (0, 0, 0, 80), (btn_x + 3, y + 3, btn_w, btn_h), border_radius=8)

            if is_selected:
                # 선택된 버튼 (글로우 효과)
                pygame.draw.rect(screen, (*color_light, 50), (btn_x - 4, y - 4, btn_w + 8, btn_h + 8), border_radius=10)
                pygame.draw.rect(screen, color_light, (btn_x, y, btn_w, btn_h), border_radius=8)
                pygame.draw.rect(screen, self.WHITE, (btn_x, y, btn_w, btn_h), 2, border_radius=8)
                text_color = self.WHITE
            else:
                pygame.draw.rect(screen, (40, 35, 50), (btn_x, y, btn_w, btn_h), border_radius=8)
                pygame.draw.rect(screen, color, (btn_x, y, btn_w, btn_h), 2, border_radius=8)
                text_color = (150, 150, 160)

            self._draw_text(screen, action, btn_x + btn_w // 2, y + btn_h // 2 - 10, text_color, 14, center=True)

        # 조작법
        self._draw_text(screen, "◀▶: 선택  ▲▼: 레이즈 조절  Enter: 확인  ESC: 나가기",
                       cx, y + 58, (100, 100, 110), 11, center=True)

    def _draw_result_ui(self, screen):
        """결과 UI (프리미엄)"""
        cx = self.screen_width // 2

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
                running = False
            else:
                result = ui.handle_event(event)
                if result == 'exit':
                    running = False

        ui.update(dt)
        ui.draw(screen)
        pygame.display.flip()

    pygame.quit()
