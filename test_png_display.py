import pygame
import sys
import os

# 리소스 경로 헬퍼
def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

# 초기화
pygame.init()
WIDTH, HEIGHT = 1200, 400
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("전설 아이템 PNG 프레임 확인")

# 색상
BACKGROUND_COLOR = (40, 40, 60)

def load_frames(item_name):
    """아이템의 PNG 프레임들을 로드"""
    frames = []
    for i in range(8):
        frame_path = resource_path(f"items/legendary/{item_name}_frame_{i}.png")
        try:
            frame = pygame.image.load(frame_path).convert_alpha()
            frames.append(frame)
            print(f"✓ {item_name} 프레임 {i} 로드 성공")
        except Exception as e:
            print(f"✗ {item_name} 프레임 {i} 로드 실패: {e}")
            # 빈 프레임 생성
            empty_frame = pygame.Surface((60, 60), pygame.SRCALPHA)
            empty_frame.fill((100, 100, 100, 100))
            frames.append(empty_frame)
    return frames

def main():
    clock = pygame.time.Clock()
    running = True
    
    # 각 아이템의 프레임들 로드
    ragnarok_frames = load_frames("ragnarok_hammer")
    hermes_frames = load_frames("hermes_shoes")
    poseidon_frames = load_frames("poseidon_trident")
    
    current_frame = 0
    frame_counter = 0
    animation_speed = 8
    
    # 폰트
    font = pygame.font.Font(None, 24)
    small_font = pygame.font.Font(None, 18)
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 스페이스바로 프레임 수동 변경
                    current_frame = (current_frame + 1) % 8
        
        # 화면 초기화
        SCREEN.fill(BACKGROUND_COLOR)
        
        # 프레임 카운터 업데이트
        frame_counter += 1
        if frame_counter >= animation_speed:
            frame_counter = 0
            current_frame = (current_frame + 1) % 8
        
        # 제목
        title_text = font.render("전설 아이템 PNG 프레임 (내부 테두리 확인)", True, (255, 255, 255))
        SCREEN.blit(title_text, (WIDTH//2 - title_text.get_width()//2, 20))
        
        # 현재 프레임 번호
        frame_text = font.render(f"현재 프레임: {current_frame}", True, (255, 255, 200))
        SCREEN.blit(frame_text, (WIDTH//2 - frame_text.get_width()//2, 50))
        
        # 아이템들 표시
        y_center = HEIGHT // 2
        x_gap = WIDTH // 4
        
        items = [
            ("라그나로크 해머", ragnarok_frames, x_gap),
            ("헤르메스의 신발", hermes_frames, x_gap * 2),
            ("포세이돈의 삼지창", poseidon_frames, x_gap * 3)
        ]
        
        for name, frames, x in items:
            # 배경 패널
            panel_size = 120
            panel_x = x - panel_size//2
            panel_y = y_center - panel_size//2
            pygame.draw.rect(SCREEN, (30, 30, 40), (panel_x, panel_y, panel_size, panel_size))
            pygame.draw.rect(SCREEN, (60, 60, 80), (panel_x, panel_y, panel_size, panel_size), 2)
            
            # PNG 프레임 표시 (2배 확대)
            if frames and len(frames) > current_frame:
                frame = frames[current_frame]
                # 2배 확대
                scaled_frame = pygame.transform.scale(frame, (120, 120))
                SCREEN.blit(scaled_frame, (panel_x, panel_y))
            
            # 아이템 이름
            name_text = small_font.render(name, True, (200, 200, 255))
            SCREEN.blit(name_text, (x - name_text.get_width()//2, panel_y + panel_size + 10))
            
            # 프레임 색상 정보 (내부 테두리 색상)
            color_info = ""
            if current_frame % 4 == 0:
                color_info = "황금색"
            elif current_frame % 4 == 1:
                color_info = "파란색"
            elif current_frame % 4 == 2:
                color_info = "빨간색"
            else:
                color_info = "보라색"
            
            color_text = small_font.render(f"프레임 {current_frame}: {color_info}", True, (255, 255, 150))
            SCREEN.blit(color_text, (x - color_text.get_width()//2, panel_y + panel_size + 30))
        
        # 안내 텍스트
        info_text = small_font.render("Space: 다음 프레임 | ESC: 종료", True, (150, 150, 150))
        SCREEN.blit(info_text, (WIDTH//2 - info_text.get_width()//2, HEIGHT - 30))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()