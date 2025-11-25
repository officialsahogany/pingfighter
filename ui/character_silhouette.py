"""
Human silhouette generator for character equipment screen.
Creates a simple human body silhouette for equipment slot positioning.
"""
import pygame


def create_human_silhouette(width=300, height=450):
    """
    Create a human silhouette surface for the equipment screen.
    
    Args:
        width: Width of the surface
        height: Height of the surface
        
    Returns:
        pygame.Surface with human silhouette drawn
    """
    surface = pygame.Surface((width, height), pygame.SRCALPHA)
    
    silhouette_color = (42, 54, 84, 120)  # RGBA with alpha for transparency
    
    cx = width // 2
    top_y = int(height * 0.06)
    
    # Head
    head_radius = int(height * 0.08)
    head_center = (cx, top_y + head_radius)
    pygame.draw.circle(surface, silhouette_color, head_center, head_radius)
    
    # Neck
    neck_width = max(8, int(width * 0.08))
    neck_height = int(height * 0.035)
    neck_rect = pygame.Rect(cx - neck_width // 2, head_center[1] + head_radius // 2, neck_width, neck_height)
    pygame.draw.rect(surface, silhouette_color, neck_rect)
    
    # Torso
    shoulder_y = neck_rect.bottom + int(height * 0.015)
    torso_height = int(height * 0.32)
    torso_top_width = int(width * 0.36)
    torso_bottom_width = int(width * 0.28)
    torso_points = [
        (cx - torso_top_width // 2, shoulder_y),
        (cx + torso_top_width // 2, shoulder_y),
        (cx + torso_bottom_width // 2, shoulder_y + torso_height),
        (cx - torso_bottom_width // 2, shoulder_y + torso_height)
    ]
    pygame.draw.polygon(surface, silhouette_color, torso_points)
    
    # Arms (spread outward)
    arm_length = int(width * 0.46)
    arm_drop = int(height * 0.16)
    arm_thickness = max(12, int(width * 0.08))
    shoulder_span = int(width * 0.46)
    left_shoulder = (cx - shoulder_span // 2, shoulder_y + int(height * 0.02))
    right_shoulder = (cx + shoulder_span // 2, shoulder_y + int(height * 0.02))
    pygame.draw.line(surface, silhouette_color, left_shoulder, (left_shoulder[0] - arm_length, left_shoulder[1] + arm_drop), arm_thickness)
    pygame.draw.line(surface, silhouette_color, right_shoulder, (right_shoulder[0] + arm_length, right_shoulder[1] + arm_drop), arm_thickness)
    
    # Belt / waist
    belt_y = shoulder_y + torso_height
    belt_height = int(height * 0.05)
    belt_width = torso_bottom_width
    belt_rect = pygame.Rect(cx - belt_width // 2, belt_y, belt_width, belt_height)
    pygame.draw.rect(surface, silhouette_color, belt_rect, border_radius=6)
    
    # Legs (open stance)
    hip_y = belt_rect.bottom
    leg_length = int(height * 0.36)
    leg_spread = int(width * 0.32)
    leg_thickness = max(12, int(width * 0.08))
    left_leg_start = (cx - leg_spread // 4, hip_y)
    right_leg_start = (cx + leg_spread // 4, hip_y)
    left_leg_end = (cx - leg_spread // 2, hip_y + leg_length)
    right_leg_end = (cx + leg_spread // 2, hip_y + leg_length)
    pygame.draw.line(surface, silhouette_color, left_leg_start, left_leg_end, leg_thickness)
    pygame.draw.line(surface, silhouette_color, right_leg_start, right_leg_end, leg_thickness)
    
    # Feet
    foot_width = int(width * 0.18)
    foot_height = int(height * 0.05)
    pygame.draw.ellipse(surface, silhouette_color, pygame.Rect(left_leg_end[0] - foot_width // 2, left_leg_end[1] - foot_height // 2, foot_width, foot_height))
    pygame.draw.ellipse(surface, silhouette_color, pygame.Rect(right_leg_end[0] - foot_width // 2, right_leg_end[1] - foot_height // 2, foot_width, foot_height))
    
    return surface


def get_body_part_positions(width=300, height=450):
    """
    Get the positions of body parts for equipment slot placement.
    
    Returns:
        dict: Dictionary mapping body part names to (x, y) positions
    """
    cx = width // 2
    top_y = int(height * 0.06)
    shoulder_span = int(width * 0.46)
    leg_span = int(width * 0.30)
    
    return {
        "head": (cx, top_y + int(height * 0.08)),
        "left_arm": (int(cx - shoulder_span // 2), int(height * 0.26)),
        "top": (cx, int(height * 0.34)),
        "right_arm": (int(cx + shoulder_span // 2), int(height * 0.26)),
        "belt": (cx, int(height * 0.50)),
        "bottom": (cx, int(height * 0.62)),
        "knee": (int(cx - leg_span), int(height * 0.74)),
        "shoes": (int(cx + leg_span), int(height * 0.88)),
    }
