#!/usr/bin/env python3
"""
Remove border from stage1_field_backup.png
"""

from PIL import Image
import numpy as np

def remove_border():
    """Remove border from backup image and fill with floor pattern"""
    
    # Load the backup image
    img = Image.open("stage1_field_backup.png")
    width, height = img.size
    img_array = np.array(img)
    
    # First, sample the floor pattern from a safe area (bottom center, avoiding any border)
    # Sample from bottom area but not too close to edges
    sample_y_start = height - 100  # Start sampling 100 pixels from bottom
    sample_y_end = height - 50     # End sampling 50 pixels from bottom
    sample_x_start = width // 3
    sample_x_end = 2 * width // 3
    
    # Extract floor pattern
    floor_sample = img_array[sample_y_start:sample_y_end, sample_x_start:sample_x_end].copy()
    
    # Detect border size by looking for decorative patterns
    border_size = 0
    
    # Check top edge for border
    for y in range(min(50, height//2)):
        row = img_array[y, width//4:3*width//4]
        # Count unique colors in this row
        unique_colors = len(np.unique(row.reshape(-1, 3), axis=0))
        # Decorative borders typically have many colors
        if unique_colors > 20:
            border_size = max(border_size, y + 1)
        else:
            break
    
    # Check left edge for border
    for x in range(min(50, width//2)):
        col = img_array[height//4:3*height//4, x]
        unique_colors = len(np.unique(col.reshape(-1, 3), axis=0))
        if unique_colors > 20:
            border_size = max(border_size, x + 1)
        else:
            break
    
    print(f"Detected border size: {border_size} pixels")
    
    # Create result array starting with original image
    new_array = img_array.copy()
    
    # Fill border areas with floor pattern
    if border_size > 0:
        # Tile the floor sample to fill border areas
        sample_h, sample_w = floor_sample.shape[:2]
        
        # Top border
        for y in range(border_size):
            for x in range(width):
                sample_y = y % sample_h
                sample_x = x % sample_w
                new_array[y, x] = floor_sample[sample_y, sample_x]
        
        # Bottom border
        for y in range(height - border_size, height):
            for x in range(width):
                sample_y = (y - (height - border_size)) % sample_h
                sample_x = x % sample_w
                new_array[y, x] = floor_sample[sample_y, sample_x]
        
        # Left border
        for y in range(border_size, height - border_size):
            for x in range(border_size):
                sample_y = (y - border_size) % sample_h
                sample_x = x % sample_w
                new_array[y, x] = floor_sample[sample_y, sample_x]
        
        # Right border
        for y in range(border_size, height - border_size):
            for x in range(width - border_size, width):
                sample_y = (y - border_size) % sample_h
                sample_x = (x - (width - border_size)) % sample_w
                new_array[y, x] = floor_sample[sample_y, sample_x]
        
        # Fill corners with floor pattern
        # Top-left corner
        for y in range(border_size):
            for x in range(border_size):
                sample_y = y % sample_h
                sample_x = x % sample_w
                new_array[y, x] = floor_sample[sample_y, sample_x]
        
        # Top-right corner
        for y in range(border_size):
            for x in range(width - border_size, width):
                sample_y = y % sample_h
                sample_x = (x - (width - border_size)) % sample_w
                new_array[y, x] = floor_sample[sample_y, sample_x]
        
        # Bottom-left corner
        for y in range(height - border_size, height):
            for x in range(border_size):
                sample_y = (y - (height - border_size)) % sample_h
                sample_x = x % sample_w
                new_array[y, x] = floor_sample[sample_y, sample_x]
        
        # Bottom-right corner
        for y in range(height - border_size, height):
            for x in range(width - border_size, width):
                sample_y = (y - (height - border_size)) % sample_h
                sample_x = (x - (width - border_size)) % sample_w
                new_array[y, x] = floor_sample[sample_y, sample_x]
    
    # Convert back to image and save
    result_img = Image.fromarray(new_array, 'RGB')
    result_img.save("stage1_field_no_border.png")
    print("Border removed! Saved as stage1_field_no_border.png")

if __name__ == "__main__":
    remove_border()