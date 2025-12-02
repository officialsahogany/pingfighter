"""
포커 게임 모듈 - 1:1 텍사스 홀덤
플레이어 vs 딜러 (골드 베팅)
"""

import pygame
import pygame.freetype
import random
import math
import os
import sys

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
# 카드 클래스
# ============================================
class Card:
    """개별 카드"""
    SUITS = ['hearts', 'diamonds', 'clubs', 'spades']  # 하트, 다이아, 클럽, 스페이드
    RANKS = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']

    SUIT_SYMBOLS = {
        'hearts': '♥',
        'diamonds': '♦',
        'clubs': '♣',
        'spades': '♠'
    }

    SUIT_COLORS = {
        'hearts': (220, 50, 50),
        'diamonds': (220, 50, 50),
        'clubs': (30, 30, 30),
        'spades': (30, 30, 30)
    }

    def __init__(self, suit, rank):
        self.suit = suit
        self.rank = rank
        self.face_up = True

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

    # 패 랭킹 (높을수록 좋음)
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
        """
        7장 카드에서 최고의 5장 패를 평가
        Returns: (랭킹, 타이브레이커 값들, 패 이름)
        """
        if len(cards) < 5:
            return (0, [], "카드 부족")

        best_hand = None
        best_rank = 0
        best_tiebreaker = []

        # 7장에서 5장 조합 모두 검사
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
        """5장 카드 평가"""
        values = sorted([c.get_value() for c in cards], reverse=True)
        suits = [c.suit for c in cards]

        is_flush = len(set(suits)) == 1
        is_straight = HandEvaluator._is_straight(values)

        # 값 카운트
        value_counts = {}
        for v in values:
            value_counts[v] = value_counts.get(v, 0) + 1

        counts = sorted(value_counts.values(), reverse=True)

        # 로얄 플러시
        if is_flush and is_straight and values == [14, 13, 12, 11, 10]:
            return (HandEvaluator.ROYAL_FLUSH, values)

        # 스트레이트 플러시
        if is_flush and is_straight:
            return (HandEvaluator.STRAIGHT_FLUSH, values)

        # 포카드
        if counts == [4, 1]:
            four_val = [v for v, c in value_counts.items() if c == 4][0]
            kicker = [v for v, c in value_counts.items() if c == 1][0]
            return (HandEvaluator.FOUR_OF_KIND, [four_val, kicker])

        # 풀 하우스
        if counts == [3, 2]:
            three_val = [v for v, c in value_counts.items() if c == 3][0]
            two_val = [v for v, c in value_counts.items() if c == 2][0]
            return (HandEvaluator.FULL_HOUSE, [three_val, two_val])

        # 플러시
        if is_flush:
            return (HandEvaluator.FLUSH, values)

        # 스트레이트
        if is_straight:
            return (HandEvaluator.STRAIGHT, values)

        # 트리플
        if counts == [3, 1, 1]:
            three_val = [v for v, c in value_counts.items() if c == 3][0]
            kickers = sorted([v for v, c in value_counts.items() if c == 1], reverse=True)
            return (HandEvaluator.THREE_OF_KIND, [three_val] + kickers)

        # 투 페어
        if counts == [2, 2, 1]:
            pairs = sorted([v for v, c in value_counts.items() if c == 2], reverse=True)
            kicker = [v for v, c in value_counts.items() if c == 1][0]
            return (HandEvaluator.TWO_PAIR, pairs + [kicker])

        # 원 페어
        if counts == [2, 1, 1, 1]:
            pair_val = [v for v, c in value_counts.items() if c == 2][0]
            kickers = sorted([v for v, c in value_counts.items() if c == 1], reverse=True)
            return (HandEvaluator.ONE_PAIR, [pair_val] + kickers)

        # 하이 카드
        return (HandEvaluator.HIGH_CARD, values)

    @staticmethod
    def _is_straight(values):
        """스트레이트 체크"""
        sorted_vals = sorted(set(values), reverse=True)
        if len(sorted_vals) != 5:
            return False

        # 일반 스트레이트
        if sorted_vals[0] - sorted_vals[4] == 4:
            return True

        # A-2-3-4-5 스트레이트 (휠)
        if sorted_vals == [14, 5, 4, 3, 2]:
            return True

        return False


# ============================================
# 포커 게임 클래스
# ============================================
class PokerGame:
    """1:1 텍사스 홀덤 게임"""

    # 게임 상태
    STATE_BETTING = 'betting'        # 베팅 단계
    STATE_PREFLOP = 'preflop'        # 프리플랍 (홀카드 배분)
    STATE_FLOP = 'flop'              # 플랍 (커뮤니티 3장)
    STATE_TURN = 'turn'              # 턴 (커뮤니티 4장)
    STATE_RIVER = 'river'            # 리버 (커뮤니티 5장)
    STATE_SHOWDOWN = 'showdown'      # 쇼다운 (결과)
    STATE_GAME_OVER = 'game_over'    # 게임 종료

    def __init__(self, player_gold=1000):
        self.deck = Deck()
        self.player_hand = []       # 플레이어 홀카드 2장
        self.dealer_hand = []       # 딜러 홀카드 2장
        self.community_cards = []   # 커뮤니티 카드 (최대 5장)

        self.player_gold = player_gold
        self.pot = 0                # 팟 (베팅 총액)
        self.current_bet = 0        # 현재 베팅액
        self.min_bet = 10           # 최소 베팅
        self.max_bet = 500          # 최대 베팅

        self.state = self.STATE_BETTING
        self.winner = None          # 'player', 'dealer', 'tie'
        self.result_message = ""

        self.player_hand_result = None
        self.dealer_hand_result = None

        # 애니메이션
        self.animation_timer = 0
        self.card_deal_timer = 0
        self.cards_to_reveal = 0

    def start_new_round(self):
        """새 라운드 시작"""
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

    def place_bet(self, amount):
        """베팅하기"""
        if self.state != self.STATE_BETTING:
            return False

        amount = max(self.min_bet, min(amount, self.max_bet, self.player_gold))

        if amount > self.player_gold:
            return False

        self.current_bet = amount
        self.player_gold -= amount
        self.pot = amount * 2  # 딜러도 같은 금액 베팅

        # 카드 배분
        self._deal_initial_cards()
        self.state = self.STATE_PREFLOP
        return True

    def _deal_initial_cards(self):
        """초기 카드 배분 (홀카드 2장씩)"""
        # 플레이어 카드 (앞면)
        self.player_hand = [self.deck.deal(True), self.deck.deal(True)]
        # 딜러 카드 (뒷면)
        self.dealer_hand = [self.deck.deal(False), self.deck.deal(False)]

    def proceed_to_next_stage(self):
        """다음 단계로 진행"""
        if self.state == self.STATE_PREFLOP:
            # 플랍: 커뮤니티 카드 3장
            self.community_cards = [self.deck.deal(), self.deck.deal(), self.deck.deal()]
            self.state = self.STATE_FLOP

        elif self.state == self.STATE_FLOP:
            # 턴: 커뮤니티 카드 1장 추가
            self.community_cards.append(self.deck.deal())
            self.state = self.STATE_TURN

        elif self.state == self.STATE_TURN:
            # 리버: 커뮤니티 카드 1장 추가
            self.community_cards.append(self.deck.deal())
            self.state = self.STATE_RIVER

        elif self.state == self.STATE_RIVER:
            # 쇼다운
            self._showdown()

    def fold(self):
        """폴드 (포기)"""
        if self.state in [self.STATE_PREFLOP, self.STATE_FLOP, self.STATE_TURN, self.STATE_RIVER]:
            self.winner = 'dealer'
            self.result_message = "폴드! 딜러 승리"
            self.state = self.STATE_GAME_OVER
            return True
        return False

    def call(self):
        """콜 (계속 진행)"""
        if self.state in [self.STATE_PREFLOP, self.STATE_FLOP, self.STATE_TURN, self.STATE_RIVER]:
            self.proceed_to_next_stage()
            return True
        return False

    def raise_bet(self, additional_amount):
        """레이즈 (추가 베팅)"""
        if self.state in [self.STATE_PREFLOP, self.STATE_FLOP, self.STATE_TURN, self.STATE_RIVER]:
            if additional_amount <= self.player_gold:
                self.player_gold -= additional_amount
                self.pot += additional_amount * 2
                self.current_bet += additional_amount
                return True
        return False

    def _showdown(self):
        """쇼다운: 결과 계산"""
        # 딜러 카드 공개
        for card in self.dealer_hand:
            card.face_up = True

        # 패 평가
        player_cards = self.player_hand + self.community_cards
        dealer_cards = self.dealer_hand + self.community_cards

        self.player_hand_result = HandEvaluator.evaluate(player_cards)
        self.dealer_hand_result = HandEvaluator.evaluate(dealer_cards)

        p_rank, p_tie, p_name = self.player_hand_result
        d_rank, d_tie, d_name = self.dealer_hand_result

        # 승자 결정
        if p_rank > d_rank:
            self.winner = 'player'
            self.player_gold += self.pot
            self.result_message = f"승리! {p_name}"
        elif d_rank > p_rank:
            self.winner = 'dealer'
            self.result_message = f"패배... 딜러 {d_name}"
        else:
            # 같은 랭킹이면 타이브레이커
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
        """게임 업데이트"""
        self.animation_timer += dt


# ============================================
# 포커 게임 UI
# ============================================
class PokerGameUI:
    """포커 게임 UI 렌더링"""

    # 카드 크기
    CARD_WIDTH = 60
    CARD_HEIGHT = 84

    def __init__(self, screen_width, screen_height, fonts=None):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game = None
        self.fonts = fonts  # freetype 폰트 딕셔너리

        # UI 상태
        self.bet_amount = 50
        self.selected_action = 0  # 0: 콜, 1: 레이즈, 2: 폴드
        self.raise_amount = 20

        self.animation_timer = 0
        self.show_result_timer = 0

        # 색상
        self.TABLE_GREEN = (30, 100, 60)
        self.TABLE_BORDER = (80, 60, 40)
        self.GOLD = (255, 215, 0)
        self.WHITE = (255, 255, 255)
        self.BLACK = (20, 20, 20)
        self.RED = (220, 50, 50)
        self.DARK_BG = (25, 20, 35)

        # 폰트 캐시 (freetype이 없을 경우 대비)
        self._font_cache = {}

    def start_game(self, player_gold):
        """게임 시작"""
        self.game = PokerGame(player_gold)
        self.game.start_new_round()
        self.bet_amount = min(50, player_gold)

    def handle_event(self, event):
        """이벤트 처리"""
        if not self.game:
            return None

        if event.type == pygame.KEYDOWN:
            if self.game.state == PokerGame.STATE_BETTING:
                return self._handle_betting_input(event)
            elif self.game.state in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                                      PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
                return self._handle_action_input(event)
            elif self.game.state in [PokerGame.STATE_SHOWDOWN, PokerGame.STATE_GAME_OVER]:
                return self._handle_result_input(event)

        return None

    def _handle_betting_input(self, event):
        """베팅 단계 입력"""
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
                return 'bet_placed'
        elif event.key == pygame.K_ESCAPE:
            return 'exit'

        return None

    def _handle_action_input(self, event):
        """액션 단계 입력"""
        if event.key == pygame.K_LEFT:
            self.selected_action = (self.selected_action - 1) % 3
        elif event.key == pygame.K_RIGHT:
            self.selected_action = (self.selected_action + 1) % 3
        elif event.key == pygame.K_UP:
            if self.selected_action == 1:  # 레이즈 금액 증가
                self.raise_amount = min(100, self.game.player_gold, self.raise_amount + 10)
        elif event.key == pygame.K_DOWN:
            if self.selected_action == 1:  # 레이즈 금액 감소
                self.raise_amount = max(10, self.raise_amount - 10)
        elif event.key in [pygame.K_RETURN, pygame.K_z]:
            if self.selected_action == 0:  # 콜
                self.game.call()
                return 'action_call'
            elif self.selected_action == 1:  # 레이즈
                if self.game.raise_bet(self.raise_amount):
                    self.game.call()
                    return 'action_raise'
            elif self.selected_action == 2:  # 폴드
                self.game.fold()
                return 'action_fold'
        elif event.key == pygame.K_ESCAPE:
            return 'exit'

        return None

    def _handle_result_input(self, event):
        """결과 화면 입력"""
        if event.key in [pygame.K_RETURN, pygame.K_z]:
            if self.game.player_gold >= self.game.min_bet:
                self.game.start_new_round()
                self.bet_amount = min(50, self.game.player_gold)
                return 'new_round'
            else:
                return 'exit'  # 골드 부족
        elif event.key == pygame.K_ESCAPE:
            return 'exit'

        return None

    def update(self, dt):
        """업데이트"""
        self.animation_timer += dt
        if self.game:
            self.game.update(dt)

    def draw(self, screen):
        """게임 화면 그리기"""
        if not self.game:
            return

        # 배경
        screen.fill(self.DARK_BG)

        # 테이블
        self._draw_table(screen)

        # 카드
        self._draw_cards(screen)

        # UI
        self._draw_ui(screen)

        # 상태별 추가 UI
        if self.game.state == PokerGame.STATE_BETTING:
            self._draw_betting_ui(screen)
        elif self.game.state in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                                  PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
            self._draw_action_ui(screen)
        elif self.game.state in [PokerGame.STATE_SHOWDOWN, PokerGame.STATE_GAME_OVER]:
            self._draw_result_ui(screen)

    def _draw_table(self, screen):
        """포커 테이블 그리기"""
        cx, cy = self.screen_width // 2, self.screen_height // 2

        # 테이블 외곽
        table_w, table_h = 500, 300
        pygame.draw.ellipse(screen, self.TABLE_BORDER,
                           (cx - table_w // 2 - 10, cy - table_h // 2 - 10, table_w + 20, table_h + 20))
        pygame.draw.ellipse(screen, self.TABLE_GREEN,
                           (cx - table_w // 2, cy - table_h // 2, table_w, table_h))

        # 테이블 무늬
        pygame.draw.ellipse(screen, (40, 120, 70),
                           (cx - table_w // 2 + 20, cy - table_h // 2 + 20, table_w - 40, table_h - 40), 3)

        # POT 표시
        pot_text = f"POT: {self.game.pot} G"
        self._draw_text(screen, pot_text, cx, cy - 30, self.GOLD, 24, center=True)

    def _draw_cards(self, screen):
        """카드 그리기"""
        cx = self.screen_width // 2

        # 커뮤니티 카드 (중앙)
        comm_y = self.screen_height // 2 + 10
        comm_start_x = cx - (len(self.game.community_cards) * (self.CARD_WIDTH + 8)) // 2

        for i, card in enumerate(self.game.community_cards):
            card_x = comm_start_x + i * (self.CARD_WIDTH + 8)
            self._draw_card(screen, card, card_x, comm_y)

        # 플레이어 카드 (하단)
        player_y = self.screen_height - 150
        player_start_x = cx - (self.CARD_WIDTH + 10)

        for i, card in enumerate(self.game.player_hand):
            card_x = player_start_x + i * (self.CARD_WIDTH + 10)
            self._draw_card(screen, card, card_x, player_y)

        # 딜러 카드 (상단)
        dealer_y = 80
        dealer_start_x = cx - (self.CARD_WIDTH + 10)

        for i, card in enumerate(self.game.dealer_hand):
            card_x = dealer_start_x + i * (self.CARD_WIDTH + 10)
            self._draw_card(screen, card, card_x, dealer_y)

        # 레이블
        self._draw_text(screen, "딜러", cx, dealer_y - 25, self.WHITE, 18, center=True)
        self._draw_text(screen, "플레이어", cx, player_y + self.CARD_HEIGHT + 10, self.WHITE, 18, center=True)

    def _draw_card(self, screen, card, x, y):
        """개별 카드 그리기"""
        w, h = self.CARD_WIDTH, self.CARD_HEIGHT

        # 카드 그림자
        pygame.draw.rect(screen, (0, 0, 0, 100), (x + 3, y + 3, w, h), border_radius=6)

        if card.face_up:
            # 앞면
            pygame.draw.rect(screen, (250, 248, 240), (x, y, w, h), border_radius=6)
            pygame.draw.rect(screen, (180, 180, 180), (x, y, w, h), 2, border_radius=6)

            # 카드 내용
            suit_color = Card.SUIT_COLORS[card.suit]
            symbol = Card.SUIT_SYMBOLS[card.suit]

            # 랭크와 심볼
            self._draw_text(screen, card.rank, x + 8, y + 8, suit_color, 16)
            self._draw_text(screen, symbol, x + 8, y + 24, suit_color, 14)

            # 중앙 큰 심볼
            self._draw_text(screen, symbol, x + w // 2, y + h // 2, suit_color, 32, center=True)

            # 반대쪽 (180도 회전 효과)
            self._draw_text(screen, card.rank, x + w - 16, y + h - 24, suit_color, 16)
        else:
            # 뒷면
            pygame.draw.rect(screen, (70, 50, 120), (x, y, w, h), border_radius=6)
            pygame.draw.rect(screen, (100, 80, 150), (x, y, w, h), 2, border_radius=6)

            # 뒷면 무늬
            pygame.draw.rect(screen, (90, 70, 140), (x + 6, y + 6, w - 12, h - 12), border_radius=4)

            # 다이아몬드 패턴
            for row in range(3):
                for col in range(2):
                    dx = x + 15 + col * 20
                    dy = y + 20 + row * 22
                    points = [(dx, dy - 6), (dx + 6, dy), (dx, dy + 6), (dx - 6, dy)]
                    pygame.draw.polygon(screen, (110, 90, 160), points)

    def _draw_ui(self, screen):
        """기본 UI 그리기"""
        # 골드 표시
        gold_text = f"골드: {self.game.player_gold} G"
        self._draw_text(screen, gold_text, 20, 20, self.GOLD, 20)

        # 현재 베팅
        bet_text = f"베팅: {self.game.current_bet} G"
        self._draw_text(screen, bet_text, 20, 50, self.WHITE, 16)

        # 게임 상태
        state_names = {
            'betting': '베팅 단계',
            'preflop': '프리플랍',
            'flop': '플랍',
            'turn': '턴',
            'river': '리버',
            'showdown': '쇼다운',
            'game_over': '게임 종료'
        }
        state_text = state_names.get(self.game.state, self.game.state)
        self._draw_text(screen, state_text, self.screen_width - 20, 20, (150, 200, 255), 18, right=True)

    def _draw_betting_ui(self, screen):
        """베팅 UI"""
        cx = self.screen_width // 2
        y = self.screen_height - 80

        # 베팅 박스
        box_w, box_h = 300, 60
        pygame.draw.rect(screen, (40, 35, 50), (cx - box_w // 2, y, box_w, box_h), border_radius=10)
        pygame.draw.rect(screen, self.GOLD, (cx - box_w // 2, y, box_w, box_h), 2, border_radius=10)

        # 베팅 금액
        self._draw_text(screen, f"베팅: {self.bet_amount} G", cx, y + 15, self.GOLD, 24, center=True)

        # 조작법
        self._draw_text(screen, "◀▶: 10G  ▲▼: 50G  Enter: 확인  ESC: 나가기",
                       cx, y + 42, (150, 150, 150), 12, center=True)

    def _draw_action_ui(self, screen):
        """액션 UI (콜/레이즈/폴드)"""
        cx = self.screen_width // 2
        y = self.screen_height - 80

        actions = ["콜", f"레이즈 +{self.raise_amount}G", "폴드"]
        action_colors = [(100, 200, 100), (255, 200, 50), (200, 100, 100)]

        btn_w, btn_h = 100, 40
        total_w = len(actions) * btn_w + (len(actions) - 1) * 15
        start_x = cx - total_w // 2

        for i, (action, color) in enumerate(zip(actions, action_colors)):
            btn_x = start_x + i * (btn_w + 15)

            # 선택된 버튼 강조
            if i == self.selected_action:
                pygame.draw.rect(screen, color, (btn_x - 3, y - 3, btn_w + 6, btn_h + 6), border_radius=8)
                pygame.draw.rect(screen, (60, 55, 70), (btn_x, y, btn_w, btn_h), border_radius=6)
                text_color = color
            else:
                pygame.draw.rect(screen, (40, 35, 50), (btn_x, y, btn_w, btn_h), border_radius=6)
                pygame.draw.rect(screen, (80, 75, 90), (btn_x, y, btn_w, btn_h), 2, border_radius=6)
                text_color = (150, 150, 150)

            self._draw_text(screen, action, btn_x + btn_w // 2, y + btn_h // 2 - 8, text_color, 14, center=True)

        # 조작법
        self._draw_text(screen, "◀▶: 선택  Enter: 확인  ESC: 나가기",
                       cx, y + 50, (150, 150, 150), 12, center=True)

    def _draw_result_ui(self, screen):
        """결과 UI - 카드가 보이도록 하단에 결과 표시"""
        cx = self.screen_width // 2

        # 결과 박스 (하단에 배치하여 카드가 보이도록)
        box_w, box_h = 400, 120
        box_y = self.screen_height - 140

        # 반투명 배경
        overlay = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
        overlay.fill((30, 25, 45, 230))
        screen.blit(overlay, (cx - box_w // 2, box_y))

        # 결과 색상
        if self.game.winner == 'player':
            result_color = (100, 255, 100)
            title = "승리!"
        elif self.game.winner == 'dealer':
            result_color = (255, 100, 100)
            title = "패배"
        else:
            result_color = (255, 255, 100)
            title = "무승부"

        # 테두리
        pygame.draw.rect(screen, result_color, (cx - box_w // 2, box_y, box_w, box_h), 3, border_radius=10)

        # 결과 텍스트
        self._draw_text(screen, title, cx, box_y + 10, result_color, 28, center=True)

        # 패 정보 (양쪽에 표시)
        if self.game.player_hand_result:
            p_name = self.game.player_hand_result[2]
            self._draw_text(screen, f"내 패: {p_name}", cx - 90, box_y + 45, (150, 200, 255), 14, center=True)

        if self.game.dealer_hand_result:
            d_name = self.game.dealer_hand_result[2]
            self._draw_text(screen, f"딜러: {d_name}", cx + 90, box_y + 45, (255, 150, 150), 14, center=True)

        # 골드 변화
        gold_text = f"골드: {self.game.player_gold} G"
        self._draw_text(screen, gold_text, cx, box_y + 70, self.GOLD, 16, center=True)

        # 계속하기
        if self.game.player_gold >= self.game.min_bet:
            self._draw_text(screen, "Enter: 계속  ESC: 나가기", cx, box_y + 95, (150, 150, 150), 12, center=True)
        else:
            self._draw_text(screen, "골드 부족! ESC: 나가기", cx, box_y + 95, (255, 100, 100), 12, center=True)

    def _draw_text(self, screen, text, x, y, color, size, center=False, right=False):
        """텍스트 그리기 (freetype 폰트 사용)"""
        # freetype 폰트가 전달된 경우 사용
        if self.fonts:
            # 크기에 맞는 폰트 선택 (manager.py의 키: large, medium, small)
            if size >= 28:
                font_key = 'large'
            elif size <= 14:
                font_key = 'small'
            else:
                font_key = 'medium'

            font = self.fonts.get(font_key) or self.fonts.get('medium') or self.fonts.get('default')
            if font:
                try:
                    # freetype 렌더링
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
                except Exception as e:
                    pass  # 폰트 렌더링 실패 시 대체 방법 사용

        # 대체 방법: 시스템 폰트 사용
        if size not in self._font_cache:
            try:
                # 한글 지원 폰트 시도
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
        """현재 플레이어 골드 반환"""
        return self.game.player_gold if self.game else 0


# ============================================
# 테스트용 메인
# ============================================
if __name__ == "__main__":
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("텍사스 홀덤 포커")
    clock = pygame.time.Clock()

    # 게임 시작
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
