#!/usr/bin/env python3
"""
Analyze the exact size of taegeuk symbol including white border
"""

from PIL import Image
import numpy as np

def analyze_taegeuk_size():
    """Find the exact size of taegeuk including any white borders"""
    
    # Load the image
    img = Image.open("stage1_field.png")
    img_array = np.array(img)
    height, width = img_array.shape[:2]
    
    print(f"Image size: {width}x{height}")
    
    # Look for any non-background pixels in the center area
    center_x, center_y = width // 2, height // 2
    search_radius = 150
    
    non_bg_pixels = []
    bg_color = (34, 34, 44)  # Background color
    
    for y in range(max(0, center_y - search_radius), min(height, center_y + search_radius)):
        for x in range(max(0, center_x - search_radius), min(width, center_x + search_radius)):
            pixel = img_array[y, x]
            # Check if pixel is not background color (with some tolerance)
            if abs(int(pixel[0]) - bg_color[0]) > 5 or \
               abs(int(pixel[1]) - bg_color[1]) > 5 or \
               abs(int(pixel[2]) - bg_color[2]) > 5:
                non_bg_pixels.append((x, y, pixel))
    
    if non_bg_pixels:
        # Find bounds
        min_x = min(x for x, y, p in non_bg_pixels)
        max_x = max(x for x, y, p in non_bg_pixels)
        min_y = min(y for x, y, p in non_bg_pixels)
        max_y = max(y for x, y, p in non_bg_pixels)
        
        taegeuk_width = max_x - min_x + 1
        taegeuk_height = max_y - min_y + 1
        taegeuk_center_x = (min_x + max_x) // 2
        taegeuk_center_y = (min_y + max_y) // 2
        taegeuk_radius = max(taegeuk_width, taegeuk_height) // 2
        
        print(f"\nTaegeuk bounds: x({min_x}-{max_x}), y({min_y}-{max_y})")
        print(f"Taegeuk size: {taegeuk_width}x{taegeuk_height}")
        print(f"Taegeuk center: ({taegeuk_center_x}, {taegeuk_center_y})")
        print(f"Taegeuk radius (including borders): ~{taegeuk_radius}")
        
        # Check for white pixels on the border
        white_border_pixels = []
        for x, y, pixel in non_bg_pixels:
            # Check if it's on the edge and whitish
            if (x == min_x or x == max_x or y == min_y or y == max_y):
                r, g, b = pixel[0], pixel[1], pixel[2]
                if r > 200 and g > 200 and b > 200:  # Whitish color
                    white_border_pixels.append((x, y))
        
        if white_border_pixels:
            print(f"\nFound {len(white_border_pixels)} white border pixels")
            print("White border detected around taegeuk!")
            
            # Find the actual colored part without white border
            colored_pixels = [(x, y, p) for x, y, p in non_bg_pixels 
                            if not (p[0] > 200 and p[1] > 200 and p[2] > 200)]
            if colored_pixels:
                colored_min_x = min(x for x, y, p in colored_pixels)
                colored_max_x = max(x for x, y, p in colored_pixels)
                colored_min_y = min(y for x, y, p in colored_pixels)
                colored_max_y = max(y for x, y, p in colored_pixels)
                colored_radius = max(colored_max_x - colored_min_x, colored_max_y - colored_min_y) // 2
                
                print(f"\nColored area (without white border):")
                print(f"Bounds: x({colored_min_x}-{colored_max_x}), y({colored_min_y}-{colored_max_y})")
                print(f"Radius: ~{colored_radius}")
                print(f"White border thickness: ~{taegeuk_radius - colored_radius} pixels")

if __name__ == "__main__":
    analyze_taegeuk_size()