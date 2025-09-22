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
    except AttributeError:
        # 개발 환경에서는 현재 파일 위치를 기준으로 경로 계산
        base_path = os.path.dirname(os.path.abspath(__file__))

    # Windows/맥 모두에서 경로 구분자 통일
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)

    return os.path.join(base_path, relative_path)

# 폰트 파일 경로 헬퍼
def get_font_path(font_name):
    """폰트 파일의 절대 경로 반환"""
    return resource_path(font_name)
