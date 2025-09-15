#!/usr/bin/env python3
"""
Remove decorative border from stage1_field_backup.png and fill with floor pattern
"""

from PIL import Image
import numpy as np

def remove_border_properly():
    """Remove border and fill with floor pattern"""
    
    # Load the backup image
    img = Image.open("stage1_field_backup.png")
    width, height = img.size
    img_array = np.array(img)
    
    # The border appears to be around 8-12 pixels based on visual inspection
    # Let's detect it by looking for the distinctive green/red/yellow pattern
    border_size = 0
    
    # Check for green color (part of the border pattern)
    green_color = np.array([0, 255, 0])  # Bright green
    
    # Check top edge
    for y in range(20):  # Check first 20 pixels
        # Check if this row contains bright green
        row = img_array[y, :, :]
        for x in range(width):
            pixel = row[x]
            # Check if pixel is greenish
            if pixel[1] > 200 and pixel[0] < 100 and pixel[2] < 100:  # Green dominant
                border_size = max(border_size, y + 5)  # Add some margin
                break
    
    # If we didn't find green, try detecting by color variety
    if border_size == 0:
        for y in range(20):
            row = img_array[y, :, :]
            unique_colors = len(np.unique(row.reshape(-1, 3), axis=0))
            if unique_colors > 15:  # Decorative border has many colors
                border_size = y + 1
            else:
                break
    
    # Manual override based on visual inspection
    if border_size < 8:
        border_size = 12  # Based on the image, border appears to be about 12 pixels
    
    print(f"Border size set to: {border_size} pixels")
    
    # Sample floor pattern from the center bottom area
    sample_area_size = 100
    center_x = width // 2
    bottom_y = height - 100
    
    # Extract a sample of the floor pattern
    sample_x_start = center_x - sample_area_size // 2
    sample_x_end = center_x + sample_area_size // 2
    sample_y_start = bottom_y - sample_area_size // 2
    sample_y_end = bottom_y + sample_area_size // 2
    
    floor_sample = img_array[sample_y_start:sample_y_end, sample_x_start:sample_x_end].copy()
    
    # Create new image starting with the original
    result = img_array.copy()
    
    # Remove border and fill with floor pattern
    sample_h, sample_w = floor_sample.shape[:2]
    
    # Fill all border areas
    for y in range(height):
        for x in range(width):
            # Check if this pixel is in the border area
            if y < border_size or y >= height - border_size or x < border_size or x >= width - border_size:
                # Calculate position in the floor sample
                sample_y = y % sample_h
                sample_x = x % sample_w
                result[y, x] = floor_sample[sample_y, sample_x]
    
    # Make sure to preserve the taegeuk symbol in the center
    center_x, center_y = width // 2, height // 2
    taegeuk_radius = 100
    
    for y in range(max(0, center_y - taegeuk_radius), min(height, center_y + taegeuk_radius)):
        for x in range(max(0, center_x - taegeuk_radius), min(width, center_x + taegeuk_radius)):
            # Check if this pixel is within the taegeuk area
            if (x - center_x)**2 + (y - center_y)**2 <= taegeuk_radius**2:
                result[y, x] = img_array[y, x]
    
    # Save the result
    result_img = Image.fromarray(result, 'RGB')
    result_img.save("stage1_field_no_border.png")
    print("Border removed and filled with floor pattern! Saved as stage1_field_no_border.png")

if __name__ == "__main__":
    remove_border_properly()