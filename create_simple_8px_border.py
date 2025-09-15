#!/usr/bin/env python3
"""
Create simple 8-pixel danchung border while preserving original content
"""

from PIL import Image, ImageDraw
import numpy as np
import math

def create_simple_8px_border():
    """Create 8-pixel danchung border preserving original content"""
    
    # Load current image
    img = Image.open("stage1_field.png")
    width, height = img.size
    img_array = np.array(img)
    
    # Create a copy to work with
    result = img.copy()
    draw = ImageDraw.Draw(result)
    
    # Border thickness
    border_thickness = 8
    
    # Traditional Danchung colors (오방색 + 단청 색상)
    colors = {
        'red': (220, 50, 47),        # 적색 (Juk-saek)
        'blue': (0, 120, 168),       # 청색 (Cheong-saek) 
        'yellow': (255, 205, 0),     # 황색 (Hwang-saek)
        'white': (255, 255, 255),    # 백색 (Baek-saek)
        'black': (20, 20, 20),       # 흑색 (Heuk-saek)
        'green': (0, 150, 100),      # 녹색 (Nok-saek)
        'turquoise': (64, 224, 208), # 청록
    }
    
    # First, fill the border area with background color
    bg_color = (34, 34, 44)  # Original background color
    
    # Top border
    draw.rectangle([0, 0, width-1, border_thickness-1], fill=bg_color)
    # Bottom border
    draw.rectangle([0, height-border_thickness, width-1, height-1], fill=bg_color)
    # Left border
    draw.rectangle([0, 0, border_thickness-1, height-1], fill=bg_color)
    # Right border
    draw.rectangle([width-border_thickness, 0, width-1, height-1], fill=bg_color)
    
    # Now draw the danchung pattern
    # Base colored lines
    for i in range(border_thickness):
        if i == 0:  # Outermost
            color = colors['red']
        elif i == 1:
            color = colors['turquoise']
        elif i == 2:
            color = colors['yellow']
        elif i == 3:
            color = colors['blue']
        elif i == 4:
            color = colors['green']
        elif i == 5:
            color = colors['white']
        elif i == 6:
            color = colors['red']
        else:  # i == 7, innermost
            color = colors['turquoise']
        
        # Draw rectangle border
        draw.rectangle([i, i, width-1-i, height-1-i], outline=color, width=1)
    
    # Add wave pattern decoration
    # Horizontal waves (top and bottom)
    wave_amplitude = 2
    for y_offset in [3, border_thickness-3]:  # Near outer and inner edge
        for x in range(border_thickness, width-border_thickness):
            wave_y = y_offset + int(wave_amplitude * math.sin(x * 0.1))
            if 0 <= wave_y < border_thickness:
                draw.point((x, wave_y), fill=colors['white'])
                draw.point((x, height-1-wave_y), fill=colors['white'])
    
    # Vertical waves (left and right)
    for x_offset in [3, border_thickness-3]:
        for y in range(border_thickness, height-border_thickness):
            wave_x = x_offset + int(wave_amplitude * math.sin(y * 0.1))
            if 0 <= wave_x < border_thickness:
                draw.point((wave_x, y), fill=colors['white'])
                draw.point((width-1-wave_x, y), fill=colors['white'])
    
    # Add small flower patterns in border
    flower_spacing = 30
    for i in range(border_thickness, width-border_thickness, flower_spacing):
        # Top border flowers
        if i + 4 < width - border_thickness:
            draw.ellipse([i-1, 4, i+1, 6], fill=colors['yellow'], outline=colors['red'])
            # Bottom border flowers  
            draw.ellipse([i-1, height-6, i+1, height-4], fill=colors['yellow'], outline=colors['red'])
    
    for i in range(border_thickness, height-border_thickness, flower_spacing):
        # Left border flowers
        if i + 4 < height - border_thickness:
            draw.ellipse([4, i-1, 6, i+1], fill=colors['yellow'], outline=colors['red'])
            # Right border flowers
            draw.ellipse([width-6, i-1, width-4, i+1], fill=colors['yellow'], outline=colors['red'])
    
    # Corner decorations - traditional Korean pattern
    corner_size = border_thickness
    corners = [
        (0, 0),  # Top-left
        (width-corner_size, 0),  # Top-right
        (0, height-corner_size),  # Bottom-left
        (width-corner_size, height-corner_size)  # Bottom-right
    ]
    
    for cx, cy in corners:
        # Draw corner accent with traditional pattern
        for i in range(corner_size):
            # Diagonal line pattern
            draw.point((cx+i, cy+corner_size-1-i), fill=colors['yellow'])
            if i > 0 and i < corner_size-1:
                draw.point((cx+i, cy+corner_size-2-i), fill=colors['white'])
                draw.point((cx+i, cy+corner_size-i), fill=colors['white'])
    
    # Save the result
    result.save("stage1_field.png")
    print("Created 8-pixel danchung border!")

if __name__ == "__main__":
    create_simple_8px_border()