#!/usr/bin/env python3
"""
Remove existing border and create new 8-pixel border
"""

from PIL import Image, ImageDraw
import numpy as np

def create_8px_border():
    """Remove existing border and create new 8-pixel border"""
    
    # Load current image
    img = Image.open("stage1_field.png")
    width, height = img.size
    
    # Create new image with same size
    new_img = Image.new('RGB', (width, height), (34, 34, 44))
    
    # Copy the center content (excluding old border)
    # First, find the actual border size by analyzing the image
    img_array = np.array(img)
    
    # Detect border size by checking where the pattern changes
    # Look for the background color (34, 34, 44)
    bg_color = np.array([34, 34, 44])
    
    # Find where the actual content starts (skip the border)
    border_size = 0
    for i in range(50):  # Check up to 50 pixels
        # Check if the top row at this depth is mostly border pattern
        if not np.array_equal(img_array[i, width//2], bg_color):
            border_size = i
            break
    
    print(f"Detected border size: {border_size} pixels")
    
    # Copy center content
    center_size = min(width, height) - (border_size * 2)
    center_x = (width - center_size) // 2
    center_y = (height - center_size) // 2
    
    # Extract center content
    center_content = img.crop((center_x, center_y, center_x + center_size, center_y + center_size))
    
    # Resize to fit with 8px border
    new_center_size = min(width, height) - 16  # 8px border on each side
    center_content = center_content.resize((new_center_size, new_center_size), Image.Resampling.LANCZOS)
    
    # Paste center content
    paste_x = (width - new_center_size) // 2
    paste_y = (height - new_center_size) // 2
    new_img.paste(center_content, (paste_x, paste_y))
    
    # Now create 8-pixel danchung border
    draw = ImageDraw.Draw(new_img)
    border_thickness = 8
    
    # Traditional Danchung colors
    colors = {
        'red': (220, 50, 47),
        'blue': (0, 120, 168),
        'yellow': (255, 205, 0),
        'white': (255, 255, 255),
        'black': (20, 20, 20),
        'green': (0, 150, 100),
        'turquoise': (64, 224, 208),
    }
    
    # Draw base border frame
    for i in range(border_thickness):
        if i < 2:
            color = colors['red']
        elif i < 4:
            color = colors['turquoise']
        elif i < 6:
            color = colors['yellow']
        else:
            color = colors['blue']
        
        # Draw rectangle border
        draw.rectangle([i, i, width-1-i, height-1-i], outline=color, width=1)
    
    # Add wave patterns
    wave_positions = [2, 5]
    for wave_y in wave_positions:
        for x in range(0, width, 20):
            wave_x = x + (wave_y % 2) * 10
            if wave_x < width - 8:
                # Small decorative dot
                draw.ellipse([wave_x, wave_y, wave_x+3, wave_y+3], 
                           fill=colors['white'], outline=colors['red'])
                draw.ellipse([wave_x, height-wave_y-3, wave_x+3, height-wave_y], 
                           fill=colors['white'], outline=colors['red'])
    
    # Add corner decorations
    corner_size = 12
    corners = [
        (0, 0),  # Top-left
        (width-corner_size, 0),  # Top-right
        (0, height-corner_size),  # Bottom-left
        (width-corner_size, height-corner_size)  # Bottom-right
    ]
    
    for cx, cy in corners:
        # Corner flower pattern
        center_x = cx + corner_size//2
        center_y = cy + corner_size//2
        
        # Flower center
        draw.ellipse([center_x-2, center_y-2, center_x+2, center_y+2], 
                    fill=colors['yellow'], outline=colors['red'])
        
        # Petals
        for angle in range(0, 360, 90):
            import math
            rad = math.radians(angle)
            px = center_x + math.cos(rad) * 4
            py = center_y + math.sin(rad) * 4
            draw.ellipse([px-1, py-1, px+1, py+1], fill=colors['white'])
    
    # Save the result
    new_img.save("stage1_field.png")
    print("Created new 8-pixel danchung border!")

if __name__ == "__main__":
    create_8px_border()