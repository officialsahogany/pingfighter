#!/usr/bin/env python3
"""
Restore only the taegeuk symbol from backup while keeping the current border
"""

from PIL import Image
import numpy as np

def restore_taegeuk_only():
    """Restore taegeuk from backup but keep current border"""
    
    # Load current image (with 8px border)
    current_img = Image.open("stage1_field.png")
    current_array = np.array(current_img)
    
    # Load backup image (with original taegeuk position)
    backup_img = Image.open("/Volumes/T7/윈도우용 백업/윈도우용최신/game/bosspong/stage1_field.png")
    backup_array = np.array(backup_img)
    
    height, width = current_array.shape[:2]
    
    # Create result starting with current image (to keep border)
    result_array = current_array.copy()
    
    # Copy only the center area from backup (where taegeuk is)
    # We'll copy a generous area to make sure we get all of the taegeuk
    center_area_size = 300  # Large enough to include all of taegeuk
    start_x = (width - center_area_size) // 2
    end_x = start_x + center_area_size
    start_y = (height - center_area_size) // 2
    end_y = start_y + center_area_size
    
    # Copy the center area from backup
    result_array[start_y:end_y, start_x:end_x] = backup_array[start_y:end_y, start_x:end_x]
    
    # Convert back to image and save
    result_img = Image.fromarray(result_array, 'RGB')
    result_img.save("stage1_field.png")
    print("Taegeuk restored from backup while keeping current border!")

if __name__ == "__main__":
    restore_taegeuk_only()