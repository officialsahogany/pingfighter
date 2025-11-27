# downtown/shop.py
# 상점 시스템 - 아이템 구매/판매

import pygame
import pygame.freetype
from .constants import SCREEN_WIDTH, SCREEN_HEIGHT, Colors

class ShopItem:
    """상점 아이템 정보"""
    def __init__(self, name, description, price, item_type, icon="📦"):
        self.name = name
        self.description = description
        self.price = price
        self.item_type = item_type  # "consumable", "equipment", "special"
        self.icon = icon

class Shop:
    """
    상점 시스템
    - 5가지 테마 중 선택 가능
    - 아이템 구매/판매
    - 한글 폰트 지원
    """

    # 5가지 상점 테마
    THEMES = {
        "cyberpunk": {
            "name": "네온 마켓",
            "name_en": "Neon Market",
            "description": "사이버펑크 스타일의 첨단 상점",
            "primary_color": (255, 20, 147),    # 네온 핑크
            "secondary_color": (0, 255, 255),   # 사이버 시안
            "bg_color": (20, 20, 40),
            "style": "cyberpunk"
        },
        "fantasy": {
            "name": "마법 상점",
            "name_en": "Magic Emporium",
            "description": "신비로운 마법 아이템 판매점",
            "primary_color": (138, 43, 226),    # 보라색
            "secondary_color": (255, 215, 0),   # 금색
            "bg_color": (25, 15, 45),
            "style": "fantasy"
        },
        "steampunk": {
            "name": "기어 상회",
            "name_en": "Gear Emporium",
            "description": "증기기관 시대의 기계 상점",
            "primary_color": (184, 134, 11),    # 황동색
            "secondary_color": (139, 69, 19),   # 녹슨 철
            "bg_color": (40, 30, 20),
            "style": "steampunk"
        },
        "nature": {
            "name": "숲속 교역소",
            "name_en": "Forest Trading Post",
            "description": "자연과 조화로운 전통 상점",
            "primary_color": (34, 139, 34),     # 숲 녹색
            "secondary_color": (210, 180, 140), # 나무색
            "bg_color": (25, 35, 25),
            "style": "nature"
        },
        "luxury": {
            "name": "황금 갤러리",
            "name_en": "Golden Gallery",
            "description": "최고급 프리미엄 아이템 전문점",
            "primary_color": (255, 215, 0),     # 금색
            "secondary_color": (192, 192, 192), # 은색
            "bg_color": (30, 25, 20),
            "style": "luxury"
        }
    }

    def __init__(self, screen, theme="cyberpunk", freetype_fonts=None):
        self.screen = screen
        self.theme_key = theme
        self.theme = self.THEMES[theme]
        self.freetype_fonts = freetype_fonts or {}

        # 상점 아이템 목록
        self.items = self._init_items()

        # UI 상태
        self.selected_index = 0
        self.scroll_offset = 0
        self.max_visible_items = 5

        # 플레이어 소지금
        self.player_gold = 0

    def _init_items(self):
        """상점 아이템 초기화"""
        return [
            ShopItem("체력 물약", "HP 50 회복", 100, "consumable", "🧪"),
            ShopItem("마나 물약", "MP 30 회복", 80, "consumable", "💙"),
            ShopItem("방어구", "방어력 +10", 500, "equipment", "🛡️"),
            ShopItem("강화석", "무기 강화 재료", 300, "special", "💎"),
            ShopItem("행운의 부적", "크리티컬 확률 +5%", 400, "special", "🍀"),
            ShopItem("순간이동 주문서", "체크포인트로 이동", 200, "consumable", "📜"),
            ShopItem("투명 망토", "3초간 무적", 600, "equipment", "👻"),
            ShopItem("황금 열쇠", "숨겨진 방 개방", 1000, "special", "🗝️"),
        ]

    def set_player_gold(self, gold):
        """플레이어 골드 설정"""
        self.player_gold = gold

    def open(self, player_gold=0):
        """상점 열기"""
        self.player_gold = player_gold
        self.selected_index = 0
        self.scroll_offset = 0
        return self._run_shop_loop()

    def _run_shop_loop(self):
        """상점 메인 루프"""
        clock = pygame.time.Clock()
        running = True
        purchased_items = []

        while running:
            dt = clock.tick(60) / 1000.0

            # 이벤트 처리
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return None, 0

                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        # ESC - 상점 나가기
                        running = False

                    elif event.key == pygame.K_UP or event.key == pygame.K_w:
                        # 위로 이동
                        self.selected_index = max(0, self.selected_index - 1)
                        if self.selected_index < self.scroll_offset:
                            self.scroll_offset = self.selected_index

                    elif event.key == pygame.K_DOWN or event.key == pygame.K_s:
                        # 아래로 이동
                        self.selected_index = min(len(self.items) - 1, self.selected_index + 1)
                        if self.selected_index >= self.scroll_offset + self.max_visible_items:
                            self.scroll_offset = self.selected_index - self.max_visible_items + 1

                    elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                        # 아이템 구매
                        item = self.items[self.selected_index]
                        if self.player_gold >= item.price:
                            self.player_gold -= item.price
                            purchased_items.append(item)
                            # 구매 효과음 (나중에 추가)

            # 렌더링
            self._draw_shop()
            pygame.display.flip()

        return purchased_items, self.player_gold

    def _draw_shop(self):
        """상점 UI 그리기"""
        # 배경 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 220))
        self.screen.blit(overlay, (0, 0))

        # 메인 패널
        panel_width = 500
        panel_height = 600
        panel_x = (SCREEN_WIDTH - panel_width) // 2
        panel_y = (SCREEN_HEIGHT - panel_height) // 2

        # 패널 배경
        panel_rect = pygame.Rect(panel_x, panel_y, panel_width, panel_height)
        pygame.draw.rect(self.screen, self.theme["bg_color"], panel_rect, border_radius=15)
        pygame.draw.rect(self.screen, self.theme["primary_color"], panel_rect, 3, border_radius=15)

        # 테마별 장식
        self._draw_theme_decorations(panel_x, panel_y, panel_width, panel_height)

        # 헤더
        self._draw_header(panel_x, panel_y, panel_width)

        # 골드 표시
        self._draw_gold_display(panel_x, panel_y, panel_width)

        # 아이템 목록
        self._draw_item_list(panel_x, panel_y + 120, panel_width, panel_height - 180)

        # 하단 안내
        self._draw_footer(panel_x, panel_y, panel_width, panel_height)

    def _draw_theme_decorations(self, x, y, width, height):
        """테마별 장식 그리기"""
        style = self.theme["style"]

        if style == "cyberpunk":
            # 네온 라인 효과
            for i in range(3):
                line_y = y + 15 + i * 5
                color = (*self.theme["secondary_color"], 100 - i * 30)
                pygame.draw.line(self.screen, color, (x + 20, line_y), (x + width - 20, line_y), 2)

        elif style == "fantasy":
            # 마법진 무늬
            center_x = x + width // 2
            center_y = y + height // 2
            for radius in [180, 200, 220]:
                pygame.draw.circle(self.screen, (*self.theme["secondary_color"], 30),
                                 (center_x, center_y), radius, 1)

        elif style == "steampunk":
            # 기어 장식
            gear_positions = [(x + 30, y + 30), (x + width - 30, y + 30),
                            (x + 30, y + height - 30), (x + width - 30, y + height - 30)]
            for gx, gy in gear_positions:
                self._draw_gear(gx, gy, 15, self.theme["secondary_color"])

        elif style == "nature":
            # 나뭇잎 장식
            leaf_color = (*self.theme["primary_color"], 80)
            for i in range(5):
                leaf_x = x + 20 + i * 100
                self._draw_leaf(leaf_x, y + 10, leaf_color)

        elif style == "luxury":
            # 황금 테두리 강조
            inner_rect = pygame.Rect(x + 10, y + 10, width - 20, height - 20)
            pygame.draw.rect(self.screen, (*self.theme["secondary_color"], 50), inner_rect, 2, border_radius=12)

    def _draw_gear(self, cx, cy, radius, color):
        """기어 그리기"""
        teeth = 8
        import math
        points = []
        for i in range(teeth * 2):
            angle = i * math.pi / teeth
            r = radius if i % 2 == 0 else radius * 0.7
            px = cx + r * math.cos(angle)
            py = cy + r * math.sin(angle)
            points.append((px, py))
        if len(points) > 2:
            pygame.draw.polygon(self.screen, (*color, 100), points, 2)
        pygame.draw.circle(self.screen, (*color, 150), (cx, cy), radius // 3, 2)

    def _draw_leaf(self, x, y, color):
        """나뭇잎 그리기"""
        points = [(x, y), (x + 10, y + 5), (x + 5, y + 15), (x, y)]
        pygame.draw.polygon(self.screen, color, points)

    def _draw_header(self, x, y, width):
        """헤더 그리기"""
        font_large = self.freetype_fonts.get('large')
        if font_large:
            title = self.theme["name"]
            title_surf, title_rect = font_large.render(title, self.theme["primary_color"])
            title_x = x + (width - title_rect.width) // 2
            self.screen.blit(title_surf, (title_x, y + 25))

            # 부제
            font_small = self.freetype_fonts.get('small')
            if font_small:
                subtitle = self.theme["description"]
                sub_surf, sub_rect = font_small.render(subtitle, Colors.TEXT_GRAY)
                sub_x = x + (width - sub_rect.width) // 2
                self.screen.blit(sub_surf, (sub_x, y + 60))

    def _draw_gold_display(self, x, y, width):
        """골드 표시"""
        font_medium = self.freetype_fonts.get('medium')
        if font_medium:
            gold_text = f"💰 보유 골드: {self.player_gold:,}G"
            gold_surf, gold_rect = font_medium.render(gold_text, Colors.UI_ACCENT)
            gold_x = x + (width - gold_rect.width) // 2
            self.screen.blit(gold_surf, (gold_x, y + 90))

    def _draw_item_list(self, x, y, width, height):
        """아이템 목록 그리기"""
        item_height = 80
        font_medium = self.freetype_fonts.get('medium')
        font_small = self.freetype_fonts.get('small')

        if not (font_medium and font_small):
            return

        # 스크롤 가능한 영역
        visible_items = self.items[self.scroll_offset:self.scroll_offset + self.max_visible_items]

        for i, item in enumerate(visible_items):
            actual_index = self.scroll_offset + i
            item_y = y + i * item_height

            # 선택된 아이템 하이라이트
            is_selected = (actual_index == self.selected_index)

            # 아이템 배경
            item_rect = pygame.Rect(x + 20, item_y, width - 40, item_height - 10)

            if is_selected:
                pygame.draw.rect(self.screen, (*self.theme["primary_color"], 80), item_rect, border_radius=10)
                pygame.draw.rect(self.screen, self.theme["primary_color"], item_rect, 2, border_radius=10)
            else:
                pygame.draw.rect(self.screen, (40, 40, 50), item_rect, border_radius=10)
                pygame.draw.rect(self.screen, (70, 70, 80), item_rect, 1, border_radius=10)

            # 아이콘
            icon_surf, icon_rect = font_medium.render(item.icon, Colors.TEXT_WHITE)
            self.screen.blit(icon_surf, (x + 35, item_y + 10))

            # 아이템 이름
            name_surf, name_rect = font_medium.render(item.name, Colors.TEXT_WHITE)
            self.screen.blit(name_surf, (x + 75, item_y + 10))

            # 아이템 설명
            desc_surf, desc_rect = font_small.render(item.description, Colors.TEXT_GRAY)
            self.screen.blit(desc_surf, (x + 75, item_y + 38))

            # 가격
            can_afford = self.player_gold >= item.price
            price_color = self.theme["secondary_color"] if can_afford else Colors.UI_DANGER
            price_text = f"{item.price}G"
            price_surf, price_rect = font_medium.render(price_text, price_color)
            price_x = x + width - price_rect.width - 35
            self.screen.blit(price_surf, (price_x, item_y + 20))

    def _draw_footer(self, x, y, width, height):
        """하단 안내 그리기"""
        font_small = self.freetype_fonts.get('small')
        if font_small:
            hints = [
                "[↑↓] 이동",
                "[SPACE] 구매",
                "[ESC] 나가기"
            ]
            hint_text = "  |  ".join(hints)
            hint_surf, hint_rect = font_small.render(hint_text, Colors.TEXT_GRAY)
            hint_x = x + (width - hint_rect.width) // 2
            self.screen.blit(hint_surf, (hint_x, y + height - 35))


# =============================================================================
# 5가지 테마 미리보기 함수
# =============================================================================
def preview_shop_themes(screen, freetype_fonts):
    """5가지 상점 테마를 한 화면에 표시"""
    clock = pygame.time.Clock()
    running = True

    themes = list(Shop.THEMES.keys())
    selected = 0

    while running:
        clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return None

            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return None
                elif event.key == pygame.K_LEFT:
                    selected = (selected - 1) % len(themes)
                elif event.key == pygame.K_RIGHT:
                    selected = (selected + 1) % len(themes)
                elif event.key == pygame.K_RETURN:
                    return themes[selected]

        # 배경
        screen.fill((20, 20, 30))

        # 제목
        font_large = freetype_fonts.get('large')
        if font_large:
            title_surf, title_rect = font_large.render("상점 테마 선택", Colors.TEXT_WHITE)
            screen.blit(title_surf, ((SCREEN_WIDTH - title_rect.width) // 2, 30))

        # 테마 카드들
        card_width = 140
        card_height = 180
        spacing = 20
        total_width = len(themes) * card_width + (len(themes) - 1) * spacing
        start_x = (SCREEN_WIDTH - total_width) // 2

        font_medium = freetype_fonts.get('medium')
        font_small = freetype_fonts.get('small')

        for i, theme_key in enumerate(themes):
            theme = Shop.THEMES[theme_key]
            card_x = start_x + i * (card_width + spacing)
            card_y = 120

            # 카드 배경
            card_rect = pygame.Rect(card_x, card_y, card_width, card_height)

            if i == selected:
                # 선택된 카드
                pygame.draw.rect(screen, (*theme["primary_color"], 150), card_rect, border_radius=12)
                pygame.draw.rect(screen, theme["primary_color"], card_rect, 3, border_radius=12)
            else:
                pygame.draw.rect(screen, (40, 40, 50), card_rect, border_radius=12)
                pygame.draw.rect(screen, (70, 70, 80), card_rect, 1, border_radius=12)

            # 테마 이름
            if font_medium:
                name_surf, name_rect = font_medium.render(theme["name"], theme["primary_color"])
                name_x = card_x + (card_width - name_rect.width) // 2
                screen.blit(name_surf, (name_x, card_y + 20))

            # 설명
            if font_small:
                # 설명을 두 줄로 나누기
                desc_words = theme["description"].split()
                line1 = " ".join(desc_words[:2])
                line2 = " ".join(desc_words[2:]) if len(desc_words) > 2 else ""

                desc1_surf, desc1_rect = font_small.render(line1, Colors.TEXT_GRAY)
                desc1_x = card_x + (card_width - desc1_rect.width) // 2
                screen.blit(desc1_surf, (desc1_x, card_y + 55))

                if line2:
                    desc2_surf, desc2_rect = font_small.render(line2, Colors.TEXT_GRAY)
                    desc2_x = card_x + (card_width - desc2_rect.width) // 2
                    screen.blit(desc2_surf, (desc2_x, card_y + 75))

            # 색상 샘플
            color_y = card_y + 110
            pygame.draw.rect(screen, theme["primary_color"],
                           (card_x + 20, color_y, card_width - 40, 20), border_radius=5)
            pygame.draw.rect(screen, theme["secondary_color"],
                           (card_x + 20, color_y + 25, card_width - 40, 20), border_radius=5)

        # 하단 안내
        if font_small:
            hint_text = "[← →] 선택  [ENTER] 확정  [ESC] 취소"
            hint_surf, hint_rect = font_small.render(hint_text, Colors.TEXT_GRAY)
            screen.blit(hint_surf, ((SCREEN_WIDTH - hint_rect.width) // 2, SCREEN_HEIGHT - 80))

        pygame.display.flip()

    return None
