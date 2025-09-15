#!/usr/bin/env python3
"""
Remove all borders and fill with original map background
"""

from PIL import Image
import numpy as np

def remove_all_borders():
    """Remove all borders and fill with map background color"""
    
    # Load the current image
    img = Image.open("stage1_field.png")
    img_array = np.array(img)
    
    # Get the background color from the center area (avoiding taegeuk)
    # Sample from multiple points to ensure we get the background color
    bg_samples = []
    sample_points = [
        (150, 200),  # Left side
        (450, 200),  # Right side
        (300, 100),  # Top
        (300, 700),  # Bottom
    ]
    
    for x, y in sample_points:
        color = img_array[y, x]
        bg_samples.append(tuple(color[:3]))  # Get RGB only
    
    # Most common color should be the background
    from collections import Counter
    bg_color = Counter(bg_samples).most_common(1)[0][0]
    print(f"Detected background color: RGB{bg_color}")
    
    # Create new image filled with background color
    width, height = img.size
    new_img = Image.new('RGB', (width, height), bg_color)
    new_array = np.array(new_img)
    
    # Copy the taegeuk symbol from the original
    # The taegeuk is in the center area, roughly a circle of radius 100
    center_x, center_y = width // 2, height // 2
    radius = 100
    
    for y in range(max(0, center_y - radius), min(height, center_y + radius)):
        for x in range(max(0, center_x - radius), min(width, center_x + radius)):
            # Check if point is within circle
            dist = ((x - center_x) ** 2 + (y - center_y) ** 2) ** 0.5
            if dist <= radius:
                # Copy pixel from original
                new_array[y, x] = img_array[y, x][:3]  # RGB only
    
    # Convert back to image and save
    result_img = Image.fromarray(new_array, 'RGB')
    result_img.save("stage1_field.png")
    print("All borders removed and filled with background color!")

if __name__ == "__main__":
    remove_all_borders()