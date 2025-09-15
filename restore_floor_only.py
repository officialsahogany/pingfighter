#!/usr/bin/env python3
"""
Restore only the floor area from backup while keeping the current border and taegeuk
"""

from PIL import Image
import numpy as np

def restore_floor_only():
    """Restore floor from backup but keep current border and taegeuk"""
    
    # Load current image (with 8px border and taegeuk)
    current_img = Image.open("stage1_field.png")
    current_array = np.array(current_img)
    
    # Load backup image (with original floor style)
    backup_img = Image.open("/Volumes/T7/윈도우용 백업/윈도우용최신/game/bosspong/stage1_field.png")
    backup_array = np.array(backup_img)
    
    height, width = current_array.shape[:2]
    
    # Create result starting with current image (to keep border and taegeuk)
    result_array = current_array.copy()
    
    # Copy the floor area from backup (bottom half, but avoid border)
    # Keep the current border (8 pixels) and taegeuk area
    border_size = 8
    taegeuk_bottom = 483  # From previous analysis, taegeuk extends to y=483
    
    # Check if images have same dimensions
    backup_height, backup_width = backup_array.shape[:2]
    print(f"Current image: {width}x{height}, Backup image: {backup_width}x{backup_height}")
    
    # Use the minimum dimensions to avoid index errors
    min_width = min(width, backup_width)
    min_height = min(height, backup_height)
    
    # Copy floor area from below taegeuk to bottom (excluding border)
    floor_start_y = taegeuk_bottom + 20  # Leave some gap after taegeuk
    floor_end_y = min_height - border_size
    
    # Copy the entire width except borders
    floor_start_x = border_size
    floor_end_x = min_width - border_size
    
    # Copy floor area from backup
    if floor_start_y < floor_end_y and floor_start_x < floor_end_x:
        result_array[floor_start_y:floor_end_y, floor_start_x:floor_end_x] = \
            backup_array[floor_start_y:floor_end_y, floor_start_x:floor_end_x]
    
    # Also copy the top area (above taegeuk) to get original background
    top_end_y = min(300, min_height - border_size)  # Above taegeuk
    if border_size < top_end_y:
        result_array[border_size:top_end_y, floor_start_x:floor_end_x] = \
            backup_array[border_size:top_end_y, floor_start_x:floor_end_x]
    
    # Convert back to image and save
    result_img = Image.fromarray(result_array, 'RGB')
    result_img.save("stage1_field.png")
    print("Floor restored from backup while keeping current border and taegeuk!")

if __name__ == "__main__":
    restore_floor_only()