"""신화 아이템 아이콘 미리보기 (게임 실행 없이 확인용)"""
import pygame
import sys
import os

# 프로젝트 루트를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path.replace('/', os.sep))

pygame.init()

COLS = 5
ICON_SIZE = 64
PAD = 16
BG_COLOR = (20, 20, 40)

# 전설 아이템 매니저 로드
from legendary_items import LegendaryItemManager
manager = LegendaryItemManager()

# 표시할 아이템 목록
items_to_show = [
    ("ragnarok_hammer", "라그나로크 해머"),
    ("poseidon_trident", "포세이돈의 삼지창"),
    ("hermes_shoes", "헤르메스의 신발"),
    ("sacred_laurel", "신성 월계수"),
    ("transcendent_crown", "초월자의 관"),
    ("odins_eye", "오딘의 눈"),
    ("angel_blessing", "천사의 주사위"),
    ("pandora_legacy", "판도라의 유산"),
    ("megingjord", "메긴교르드"),
]

# 엘릭서는 별도 함수
try:
    from item_effects.elixir_of_mastery import draw_elixir_animated_icon
    items_to_show.append(("elixir_of_mastery", "엘릭서 오브 마스터리"))
except Exception:
    draw_elixir_animated_icon = None

ROWS = (len(items_to_show) + COLS - 1) // COLS
WIN_W = COLS * (ICON_SIZE + PAD) + PAD
WIN_H = ROWS * (ICON_SIZE + PAD + 20) + PAD + 30

screen = pygame.display.set_mode((WIN_W, WIN_H))
pygame.display.set_caption("신화 아이템 아이콘 미리보기")

font = None
for fname in ["NanumSquareB.ttf", "NanumGothic.ttf", "malgun.ttf"]:
    for fdir in ["fonts", "."]:
        fpath = resource_path(os.path.join(fdir, fname))
        if os.path.exists(fpath):
            try:
                font = pygame.font.Font(fpath, 11)
                break
            except:
                pass
    if font:
        break
if not font:
    font = pygame.font.SysFont("malgungothic", 11)

clock = pygame.time.Clock()
running = True

while running:
    dt = clock.tick(60) / 1000.0

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
            running = False

    screen.fill(BG_COLOR)

    # 타이틀
    title_surf = font.render("신화 아이템 아이콘 미리보기 (ESC로 종료)", True, (200, 200, 200))
    screen.blit(title_surf, (PAD, 6))

    for idx, (item_key, item_name) in enumerate(items_to_show):
        col = idx % COLS
        row = idx // COLS
        ix = PAD + col * (ICON_SIZE + PAD)
        iy = 28 + PAD + row * (ICON_SIZE + PAD + 20)

        # 슬롯 배경
        slot_rect = pygame.Rect(ix - 2, iy - 2, ICON_SIZE + 4, ICON_SIZE + 4)
        pygame.draw.rect(screen, (40, 40, 60), slot_rect, border_radius=4)

        # 아이콘 그리기
        if item_key == "elixir_of_mastery" and draw_elixir_animated_icon:
            draw_elixir_animated_icon(screen, ix, iy, ICON_SIZE, pygame.time.get_ticks() / 1000.0)
        else:
            item = manager.get_item(item_key)
            if item:
                item.update(dt, ui_mode=True)
                item.draw_icon(screen, ix, iy, ICON_SIZE)

        # 이름 라벨
        name_surf = font.render(item_name, True, (180, 180, 180))
        name_x = ix + (ICON_SIZE - name_surf.get_width()) // 2
        screen.blit(name_surf, (name_x, iy + ICON_SIZE + 4))

    pygame.display.flip()

pygame.quit()
