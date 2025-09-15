#!/usr/bin/env python3
"""
Move taegeuk symbol 23 pixels down to align with screen center
"""

from PIL import Image
import numpy as np

def move_taegeuk_to_center():
    """Move taegeuk 23 pixels down to center it at y=400"""
    
    # Load the current image
    img = Image.open("stage1_field.png")
    img_array = np.array(img)
    height, width = img_array.shape[:2]
    
    # Create new image with background color
    bg_color = (34, 34, 44)  # The background color we found earlier
    new_img = Image.new('RGB', (width, height), bg_color)
    new_array = np.array(new_img)
    
    # First, copy the border areas (everything except the center taegeuk area)
    # Copy top border
    new_array[:100] = img_array[:100]
    # Copy bottom border  
    new_array[700:] = img_array[700:]
    # Copy left border
    new_array[:, :100] = img_array[:, :100]
    # Copy right border
    new_array[:, 500:] = img_array[:, 500:]
    
    # Now copy the taegeuk, but shifted down by 23 pixels
    # The taegeuk is roughly in the area (220-380, 300-455)
    # We'll copy a larger area to be safe
    source_top = 250
    source_bottom = 500
    source_left = 200
    source_right = 400
    
    dest_top = source_top + 23  # Move down by 23 pixels
    dest_bottom = source_bottom + 23
    
    # Make sure we don't go out of bounds
    if dest_bottom <= height:
        # Copy the taegeuk area
        new_array[dest_top:dest_bottom, source_left:source_right] = \
            img_array[source_top:source_bottom, source_left:source_right]
    
    # Convert back to image and save
    result_img = Image.fromarray(new_array, 'RGB')
    result_img.save("stage1_field.png")
    print("Taegeuk moved 23 pixels down to center!")
    print(f"Taegeuk now centered at (300, 400)")

if __name__ == "__main__":
    move_taegeuk_to_center()