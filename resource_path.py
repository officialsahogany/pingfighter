#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""PyInstaller 환경에서 리소스 파일 경로를 올바르게 찾기 위한 헬퍼"""

import os
import sys

def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    
    return os.path.join(base_path, relative_path)

# 폰트 파일 경로 헬퍼
def get_font_path(font_name):
    """폰트 파일의 절대 경로 반환"""
    return resource_path(font_name)