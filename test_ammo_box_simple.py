#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pygame
import sys
import os

# 상위 디렉토리를 Python 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import items
from item_effects.ammo_box import get_ammo_box_instance
from item_effects.bazooka import get_bazooka_instance
from item_effects.ak47 import get_ak47_instance

# Test initialization
pygame.init()
pygame.display.set_mode((100, 100))

print('\n=== Ammo Box Quick Test ===')

# Initialize weapons
bazooka = get_bazooka_instance()
bazooka.equip()
bazooka.ammo_count = 1  # Low ammo

ak47 = get_ak47_instance()
ak47.activate(None, None)
ak47.current_ammo = 5  # Low ammo

# Simulate soldier weapons and pistol ammo
soldier_weapons = ['pistol', 'bazooka', 'ak47']
soldier_pistol_ammo = 3
SOLDIER_PISTOL_MAX_AMMO = 10

print(f'\nBefore reload:')
print(f'  Pistol: {soldier_pistol_ammo}/{SOLDIER_PISTOL_MAX_AMMO}')
print(f'  Bazooka: {bazooka.ammo_count}/{bazooka.max_ammo}')
print(f'  AK-47: {ak47.current_ammo}/{ak47.max_ammo}')

# Use ammo box
ammo_box = get_ammo_box_instance()
ammo_box.activate(None, 1)

print(f'\nAfter using ammo box:')
print(f'  Pistol: {soldier_pistol_ammo}/{SOLDIER_PISTOL_MAX_AMMO} (manual reload needed in game)')
print(f'  Bazooka: {bazooka.ammo_count}/{bazooka.max_ammo}')
print(f'  AK-47: {ak47.current_ammo}/{ak47.max_ammo}')

# Check if items.py has ammo_box
print('\n=== Checking items.py ===')
ammo_box_in_items = False
for item in items.ITEM_TYPES:
    if item["name"] == "ammo_box":
        ammo_box_in_items = True
        print(f'✅ ammo_box found in ITEM_TYPES: {item}')
        break

if not ammo_box_in_items:
    print('❌ ammo_box not found in ITEM_TYPES!')

# Check if ammo_box is unlocked
if "ammo_box" in items.unlocked_items:
    print(f'✅ ammo_box is unlocked: {items.unlocked_items["ammo_box"]}')
else:
    print('❌ ammo_box not in unlocked_items!')

pygame.quit()
print('\nTest complete!')