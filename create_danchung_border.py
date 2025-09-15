#!/usr/bin/env python3
"""
Create Korean traditional Danchung (단청) style border
Inspired by Korean palace roof tiles and decorative patterns
"""

from PIL import Image, ImageDraw
import os
import math

def create_danchung_border(width=600, height=800):
    """Create image with traditional Korean Danchung border"""
    
    # Load the current image with taegeuk
    img = Image.open("stage1_field.png")
    draw = ImageDraw.Draw(img)
    
    # Traditional Danchung colors (오방색 + 단청 색상)
    colors = {
        'red': (220, 50, 47),        # 적색 (Juk-saek)
        'blue': (0, 120, 168),       # 청색 (Cheong-saek) 
        'yellow': (255, 205, 0),     # 황색 (Hwang-saek)
        'white': (255, 255, 255),    # 백색 (Baek-saek)
        'black': (20, 20, 20),       # 흑색 (Heuk-saek)
        'green': (0, 150, 100),      # 녹색 (Nok-saek)
        'orange': (255, 127, 0),     # 주황
        'purple': (128, 0, 128),     # 자주
        'turquoise': (64, 224, 208), # 청록
        'dark_red': (139, 0, 0),     # 진한 적색
        'dark_green': (0, 100, 50),  # 진한 녹색
    }
    
    # Border thickness
    border_thickness = 8
    
    # Fill border background with dark color
    bg_color = (30, 25, 20, 255)
    draw.rectangle([0, 0, width, border_thickness], fill=bg_color)
    draw.rectangle([0, height - border_thickness, width, height], fill=bg_color)
    draw.rectangle([0, 0, border_thickness, height], fill=bg_color)
    draw.rectangle([width - border_thickness, 0, width, height], fill=bg_color)
    
    # Draw wave patterns (기와 물결 무늬) on all borders
    def draw_wave_pattern(start_x, start_y, end_x, end_y, is_horizontal=True):
        """Draw traditional Korean wave pattern with multiple colorful layers"""
        if is_horizontal:
            # Top/bottom borders - multiple layered waves like reference
            wave_width = 16
            wave_count = (end_x - start_x) // wave_width
            
            # Define wave layers with colors from reference image
            wave_layers = [
                {'color': colors['turquoise'], 'offset': 0, 'height': 3},
                {'color': colors['green'], 'offset': 2, 'height': 3},
                {'color': colors['red'], 'offset': 4, 'height': 3},
                {'color': colors['blue'], 'offset': 6, 'height': 2},
            ]
            
            for i in range(wave_count):
                x = start_x + i * wave_width
                
                # Draw each wave layer
                for layer in wave_layers:
                    y_offset = start_y + layer['offset']
                    # Draw filled semicircle
                    for h in range(layer['height']):
                        draw.arc([x, y_offset-h, x + wave_width, y_offset-h + layer['height']*2], 
                                0, 180, fill=layer['color'], width=1)
        else:
            # Left/right borders - vertical waves
            wave_height = 16
            wave_count = (end_y - start_y) // wave_height
            
            # Same wave layers for vertical
            wave_layers = [
                {'color': colors['turquoise'], 'offset': 0, 'width': 3},
                {'color': colors['green'], 'offset': 2, 'width': 3},
                {'color': colors['red'], 'offset': 4, 'width': 3},
                {'color': colors['blue'], 'offset': 6, 'width': 2},
            ]
            
            for i in range(wave_count):
                y = start_y + i * wave_height
                
                # Draw each wave layer
                for layer in wave_layers:
                    if start_x < width // 2:  # Left side
                        x_offset = start_x + layer['offset']
                        for w in range(layer['width']):
                            draw.arc([x_offset-w, y, x_offset-w + layer['width']*2, y + wave_height], 
                                    270, 90, fill=layer['color'], width=1)
                    else:  # Right side
                        x_offset = start_x - layer['offset']
                        for w in range(layer['width']):
                            draw.arc([x_offset+w - layer['width']*2, y, x_offset+w, y + wave_height], 
                                    90, 270, fill=layer['color'], width=1)
    
    # Draw the main wave patterns
    draw_wave_pattern(border_thickness, 2, width - border_thickness, border_thickness, True)
    draw_wave_pattern(border_thickness, height - border_thickness + 2, 
                     width - border_thickness, height, True)
    draw_wave_pattern(2, border_thickness, border_thickness, 
                     height - border_thickness, False)
    draw_wave_pattern(width - border_thickness + 2, border_thickness, 
                     width, height - border_thickness, False)
    
    # Draw Danchung flower patterns (단청 꽃무늬) at regular intervals
    def draw_danchung_flower(cx, cy, size=3):
        """Draw traditional Danchung flower pattern like reference"""
        # White center dot
        draw.ellipse([cx-1, cy-1, cx+1, cy+1], 
                    fill=colors['white'])
        
        # Surrounding colorful petals in circular pattern
        petal_count = 4
        for i in range(petal_count):
            angle = i * 90
            rad = math.radians(angle)
            px = cx + int(size * math.cos(rad))
            py = cy + int(size * math.sin(rad))
            
            # Alternate colors for petals
            if i % 2 == 0:
                color = colors['yellow']
            else:
                color = colors['red']
                
            draw.ellipse([px-1, py-1, px+1, py+1], fill=color)
    
    # Add flowers along borders - placed between wave patterns
    # Top and bottom - flowers on the wave crests
    for x in range(16, width - 16, 32):  # Every other wave
        draw_danchung_flower(x + 8, border_thickness // 2, 3)
        draw_danchung_flower(x + 8, height - border_thickness // 2, 3)
    
    # Left and right - flowers on wave crests
    for y in range(16, height - 16, 32):  # Every other wave
        draw_danchung_flower(border_thickness // 2, y + 8, 3)
        draw_danchung_flower(width - border_thickness // 2, y + 8, 3)
    
    # Draw corner decorations (귀면와 - demon face tiles style)
    def draw_corner_pattern(cx, cy):
        """Draw elaborate corner pattern with colorful design"""
        # Outer decorative ring
        draw.ellipse([cx-6, cy-6, cx+6, cy+6], 
                    fill=colors['turquoise'], outline=colors['dark_green'], width=1)
        
        # Inner yellow ring
        draw.ellipse([cx-4, cy-4, cx+4, cy+4], 
                    fill=colors['yellow'], outline=colors['red'], width=1)
        
        # Center pattern with multiple colors
        draw.ellipse([cx-2, cy-2, cx+2, cy+2], 
                    fill=colors['red'])
        
        # Central white dot
        draw.ellipse([cx-1, cy-1, cx+1, cy+1], fill=colors['white'])
        
        # Small decorative dots around in 4 directions
        for angle in [0, 90, 180, 270]:
            rad = math.radians(angle)
            sx = cx + int(7 * math.cos(rad))
            sy = cy + int(7 * math.sin(rad))
            draw.point((sx, sy), fill=colors['yellow'])
    
    # Draw corners
    corner_offset = border_thickness
    draw_corner_pattern(corner_offset, corner_offset)
    draw_corner_pattern(width - corner_offset, corner_offset)
    draw_corner_pattern(corner_offset, height - corner_offset)
    draw_corner_pattern(width - corner_offset, height - corner_offset)
    
    # Add decorative border lines
    # Outer golden frame
    draw.rectangle([0, 0, width-1, height-1], outline=colors['yellow'], width=1)
    draw.rectangle([1, 1, width-2, height-2], outline=colors['red'], width=1)
    
    # Inner frame with decorative lines
    draw.rectangle([border_thickness-1, border_thickness-1, 
                   width-border_thickness, height-border_thickness], 
                   outline=colors['yellow'], width=1)
    
    # Add golden accent lines at edges of wave patterns
    # Top and bottom
    draw.line([(border_thickness, 1), (width - border_thickness, 1)], 
              fill=colors['yellow'], width=1)
    draw.line([(border_thickness, height-2), (width - border_thickness, height-2)], 
              fill=colors['yellow'], width=1)
    # Left and right
    draw.line([(1, border_thickness), (1, height - border_thickness)], 
              fill=colors['yellow'], width=1)
    draw.line([(width-2, border_thickness), (width-2, height - border_thickness)], 
              fill=colors['yellow'], width=1)
    
    # Save the result
    img.save("stage1_field.png")
    print("Danchung style border created!")

if __name__ == "__main__":
    create_danchung_border()