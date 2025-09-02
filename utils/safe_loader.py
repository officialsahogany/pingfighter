"""
안전한 리소스 로딩 유틸리티
try-except 중복 제거를 위한 헬퍼
"""
import pygame

def safe_load_image(path, default_size=(100, 100), default_color=(128, 128, 128)):
    """이미지를 안전하게 로드하고, 실패시 기본 서페이스 반환"""
    try:
        image = pygame.image.load(path).convert_alpha()
        return image
    except (FileNotFoundError, pygame.error):
        surface = pygame.Surface(default_size, pygame.SRCALPHA)
        surface.fill(default_color)
        return surface

def safe_load_sound(path, default_volume=0.5):
    """사운드를 안전하게 로드하고, 실패시 더미 사운드 반환"""
    try:
        sound = pygame.mixer.Sound(path)
        sound.set_volume(default_volume)
        return sound
    except (FileNotFoundError, pygame.error):
        class DummySound:
            def play(self): pass
            def stop(self): pass
            def set_volume(self, v): pass
            def get_volume(self): return 0
        return DummySound()

def safe_load_font(path, size, fallback="arial"):
    """폰트를 안전하게 로드하고, 실패시 기본 폰트 반환"""
    try:
        return pygame.font.Font(path, size)
    except (FileNotFoundError, pygame.error):
        return pygame.font.SysFont(fallback, size)

def safe_scale_image(image, size):
    """이미지를 안전하게 스케일"""
    try:
        return pygame.transform.scale(image, size)
    except pygame.error:
        return image

def safe_get_rect(surface, **kwargs):
    """Rect를 안전하게 가져오기"""
    try:
        return surface.get_rect(**kwargs)
    except AttributeError:
        return pygame.Rect(0, 0, 100, 100)