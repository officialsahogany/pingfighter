import sys
import re

with open('pingfighter.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Block 1
old1 = '''    # ── 프리즈 스냅샷 합성 (pillars + game SCREEN + 좌측 필러 UI) ──
    snapshot = pygame.Surface((real_w, real_h)).convert()
    snapshot.fill((15, 15, 25))
    # 필러 배경 (캐시)
    _pb_cache = globals().get('_pillar_bg_cache')
    if _pb_cache is not None:
        try:
            snapshot.blit(_pb_cache, (0, 0))
        except Exception:
            pass'''
new1 = '''    try:
        _sound = pygame.mixer.Sound(resource_path("sounds/itemget.wav"))
        _sound.play()
    except Exception:
        pass

    # ── 프리즈 스냅샷 합성 (pillars + game SCREEN + 좌측 필러 UI) ──
    snapshot = pygame.Surface((real_w, real_h)).convert()
    snapshot.fill((15, 15, 25))
    # 필러 배경 (캐시)
    _pb_cache = globals().get('_pillar_bg_cache')
    if _pb_cache is not None:
        try:
            if _pb_cache.get_width() > 0 and _pb_cache.get_height() > 0:
                snapshot.blit(_pb_cache, (0, 0))
        except Exception:
            pass'''
content = content.replace(old1, new1)

# Block 2
old2 = '''    if gauge_surf is not None:
        gauge_w = gauge_surf.get_width()
        gauge_h = gauge_surf.get_height()
        try:
            if scale != 1.0:'''
new2 = '''    if gauge_surf is not None:
        gauge_w = gauge_surf.get_width()
        gauge_h = gauge_surf.get_height()
        if gauge_w > 0 and gauge_h > 0:
            try:
                if scale != 1.0:'''
content = content.replace(old2, new2)

# Block 2b
old2b = '''            else:
                snapshot.blit(gauge_surf, (pillar_x_left, pillar_y_left))
        except Exception:
            pass'''
new2b = '''            else:
                    snapshot.blit(gauge_surf, (pillar_x_left, pillar_y_left))
            except Exception:
                pass'''
content = content.replace(old2b, new2b)

# Block 3
old3 = '''    # ── 좌표 변환: SCREEN(내부) → REAL_SCREEN ──
    src_x = float(GAME_OFFSET_X + source_rect.centerx * scale)
    src_y = float(GAME_OFFSET_Y + source_rect.centery * scale)'''
new3 = '''    # ── 좌표 변환: SCREEN(내부) → REAL_SCREEN ──
    src_real_x = float(GAME_OFFSET_X + source_rect.centerx * scale)
    src_real_y = float(GAME_OFFSET_Y + source_rect.centery * scale)
    src_x = src_real_x
    src_y = src_real_y'''
content = content.replace(old3, new3)

# Block 4
old4 = '''    if perk_color and len(perk_color) >= 3:
        try:
            _aurora_palette.insert(0, (
                max(0, min(255, int(perk_color[0]))),
                max(0, min(255, int(perk_color[1]))),
                max(0, min(255, int(perk_color[2]))),
            ))
        except Exception:
            pass'''
new4 = '''    if perk_color and len(perk_color) >= 3:
        try:
            _pc = (
                max(0, min(255, int(perk_color[0]))),
                max(0, min(255, int(perk_color[1]))),
                max(0, min(255, int(perk_color[2]))),
            )
            _aurora_palette.insert(0, _pc)
            _aurora_palette.extend([_pc, _pc])
        except Exception:
            pass'''
content = content.replace(old4, new4)

# Block 5
old5 = '''        # ── 게임 영역 비네트: 버스트 이후 강화해 카드 UI 를 가림 ──
        if frame < PHASE_BURST_START:
            vignette_alpha = min(60, frame * 3)
        else:
            _bf = frame - PHASE_BURST_START
            vignette_alpha = min(210, 60 + _bf * 3)'''
new5 = '''        # ── 게임 영역 비네트: 버스트 이후 강화해 카드 UI 를 가림 ──
        if frame < PHASE_BURST_START:
            vignette_alpha = min(60, frame * 3)
        else:
            _bf = frame - PHASE_BURST_START
            vignette_alpha = min(180, 60 + _bf * 3)'''
content = content.replace(old5, new5)

# Block 6
old6 = '''        # ─────────────── Burst ───────────────
        if frame >= PHASE_BURST_START and not _burst_done:
            _burst_done = True
            num_particles = 100'''
new6 = '''        # ─────────────── Burst ───────────────
        if frame >= PHASE_BURST_START and not _burst_done:
            _burst_done = True
            try:
                num_particles = 40 if _adaptive_performance_enabled() else 100
            except Exception:
                num_particles = 100'''
content = content.replace(old6, new6)

# Block 7
old7 = '''                if size > 2:
                    pygame.draw.circle(_overlay, (255, 255, 255, min(255, alpha + 30)),
                                       (int(bx), int(by)), max(1, size - 1))
                if pt >= 1.0:
                    p["arrived"] = True'''
new7 = '''                if size > 2 and not p.get("arrived"):
                    pygame.draw.circle(_overlay, (255, 255, 255, min(255, alpha + 30)),
                                       (int(bx), int(by)), max(1, size - 1))
                if pt >= 1.0:
                    if not p.get("arrived"):
                        p["arrived"] = True
                        p["arrived_time"] = 0
                if p.get("arrived"):
                    p["arrived_time"] = p.get("arrived_time", 0) + 1
                    fade = max(0, 255 - p["arrived_time"] * 20)
                    if fade > 0:
                        pygame.draw.circle(_overlay, (*p["color"], fade), (int(bx), int(by)), max(1, size))'''
content = content.replace(old7, new7)

# Block 9
old9 = '''        for _evt in pygame.event.get():
            if _evt.type == pygame.QUIT:
                pass'''
new9 = '''        for _evt in pygame.event.get():
            if _evt.type == pygame.QUIT:
                try:
                    pygame.quit()
                    import sys
                    sys.exit(0)
                except Exception:
                    pass'''
content = content.replace(old9, new9)

with open('pingfighter.py', 'w', encoding='utf-8') as f:
    f.write(content)
print('Patch script execution completed')
