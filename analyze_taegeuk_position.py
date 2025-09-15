#!/usr/bin/env python3
"""
Analyze the exact position of taegeuk symbol in stage1_field.png
"""

from PIL import Image
import numpy as np

def analyze_taegeuk_position():
    """Find the exact center of taegeuk symbol"""
    
    # Load the image
    img = Image.open("stage1_field.png")
    img_array = np.array(img)
    height, width = img_array.shape[:2]
    
    print(f"Image size: {width}x{height}")
    print(f"Image center: ({width//2}, {height//2})")
    
    # Look for the taegeuk by finding blue and light blue pixels
    # The taegeuk has distinctive blue colors
    blue_pixels = []
    
    # Sample the center area
    center_x, center_y = width // 2, height // 2
    search_radius = 150
    
    for y in range(max(0, center_y - search_radius), min(height, center_y + search_radius)):
        for x in range(max(0, center_x - search_radius), min(width, center_x + search_radius)):
            pixel = img_array[y, x]
            r, g, b = pixel[0], pixel[1], pixel[2]
            
            # Look for blue pixels (taegeuk blue side)
            if b > 100 and b > r + 30 and b > g + 30:
                blue_pixels.append((x, y))
    
    if blue_pixels:
        # Calculate center of blue pixels
        avg_x = sum(x for x, y in blue_pixels) / len(blue_pixels)
        avg_y = sum(y for x, y in blue_pixels) / len(blue_pixels)
        
        print(f"\nBlue pixels found: {len(blue_pixels)}")
        print(f"Estimated taegeuk center: ({avg_x:.1f}, {avg_y:.1f})")
        print(f"Offset from image center: ({avg_x - width//2:.1f}, {avg_y - height//2:.1f})")
        
        # Find the bounds of the taegeuk
        min_x = min(x for x, y in blue_pixels)
        max_x = max(x for x, y in blue_pixels)
        min_y = min(y for x, y in blue_pixels)
        max_y = max(y for x, y in blue_pixels)
        
        taegeuk_center_x = (min_x + max_x) // 2
        taegeuk_center_y = (min_y + max_y) // 2
        taegeuk_radius = max(max_x - min_x, max_y - min_y) // 2
        
        print(f"\nTaegeuk bounds: x({min_x}-{max_x}), y({min_y}-{max_y})")
        print(f"Taegeuk center from bounds: ({taegeuk_center_x}, {taegeuk_center_y})")
        print(f"Taegeuk radius: ~{taegeuk_radius}")
        print(f"Y offset needed: {taegeuk_center_y - height//2}")
    else:
        print("No blue pixels found in center area")

if __name__ == "__main__":
    analyze_taegeuk_position()