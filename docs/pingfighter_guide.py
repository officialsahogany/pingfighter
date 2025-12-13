#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
핑파이터(PingFighter) 기본 조작법 및 팁 가이드 PDF 생성기
나무위키 스타일 문서
"""

import os
import sys

# 프로젝트 루트 경로 설정
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, PROJECT_ROOT)

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm, cm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    Image, PageBreak, HRFlowable, ListFlowable, ListItem, KeepTogether
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.graphics.shapes import Drawing, Rect, String, Line
from reportlab.graphics import renderPDF

# 폰트 등록
FONT_PATH = os.path.join(PROJECT_ROOT, "fonts", "NanumSquareB.ttf")
FONT_PATH_BOLD = os.path.join(PROJECT_ROOT, "fonts", "NanumSquareEB.ttf")
FONT_PATH_LIGHT = os.path.join(PROJECT_ROOT, "fonts", "NanumSquareL.ttf")

if os.path.exists(FONT_PATH):
    pdfmetrics.registerFont(TTFont('NanumSquare', FONT_PATH))
    BASE_FONT = 'NanumSquare'
else:
    BASE_FONT = 'Helvetica'

if os.path.exists(FONT_PATH_BOLD):
    pdfmetrics.registerFont(TTFont('NanumSquareBold', FONT_PATH_BOLD))
    BOLD_FONT = 'NanumSquareBold'
else:
    BOLD_FONT = 'Helvetica-Bold'

if os.path.exists(FONT_PATH_LIGHT):
    pdfmetrics.registerFont(TTFont('NanumSquareLight', FONT_PATH_LIGHT))
    LIGHT_FONT = 'NanumSquareLight'
else:
    LIGHT_FONT = BASE_FONT

# 아이콘 경로
ITEMS_PATH = os.path.join(PROJECT_ROOT, "items")

# 나무위키 스타일 색상 정의
NAMU_GREEN = colors.HexColor('#00A86B')  # 나무위키 대표 초록색
NAMU_DARK = colors.HexColor('#2D2D2D')   # 나무위키 다크 테마
NAMU_BLUE = colors.HexColor('#0275D8')   # 링크 블루
NAMU_GRAY = colors.HexColor('#F8F9FA')   # 배경 회색
NAMU_BORDER = colors.HexColor('#DEE2E6') # 테이블 보더
NAMU_HEADER = colors.HexColor('#E9ECEF') # 테이블 헤더
NAMU_QUOTE = colors.HexColor('#6C757D')  # 인용문 색상
NAMU_RED = colors.HexColor('#DC3545')    # 경고/주의
NAMU_YELLOW = colors.HexColor('#FFC107') # 팁/힌트
NAMU_CYAN = colors.HexColor('#17A2B8')   # 정보


def get_icon_path(item_name):
    """아이템 아이콘 경로 반환"""
    # 일반 아이템
    path = os.path.join(ITEMS_PATH, f"{item_name}.png")
    if os.path.exists(path):
        return path
    # 전설 아이템
    path = os.path.join(ITEMS_PATH, "legendary", f"{item_name}.png")
    if os.path.exists(path):
        return path
    return None


def create_styles():
    """나무위키 스타일 생성"""
    styles = getSampleStyleSheet()

    # 문서 제목 (나무위키 문서명 스타일)
    styles.add(ParagraphStyle(
        name='NamuTitle',
        fontName=BOLD_FONT,
        fontSize=28,
        textColor=NAMU_DARK,
        alignment=TA_LEFT,
        spaceAfter=5,
        spaceBefore=10
    ))

    # 부제목 (문서 설명)
    styles.add(ParagraphStyle(
        name='NamuSubtitle',
        fontName=BASE_FONT,
        fontSize=12,
        textColor=NAMU_QUOTE,
        alignment=TA_LEFT,
        spaceAfter=20,
        spaceBefore=0
    ))

    # 대분류 헤딩 (1. 개요)
    styles.add(ParagraphStyle(
        name='NamuH1',
        fontName=BOLD_FONT,
        fontSize=18,
        textColor=NAMU_DARK,
        spaceBefore=25,
        spaceAfter=10,
        borderWidth=0,
        borderPadding=0,
        borderColor=NAMU_GREEN,
        leftIndent=0
    ))

    # 중분류 헤딩 (1.1. 세부사항)
    styles.add(ParagraphStyle(
        name='NamuH2',
        fontName=BOLD_FONT,
        fontSize=14,
        textColor=NAMU_DARK,
        spaceBefore=18,
        spaceAfter=8,
        leftIndent=5
    ))

    # 소분류 헤딩 (1.1.1. 상세)
    styles.add(ParagraphStyle(
        name='NamuH3',
        fontName=BOLD_FONT,
        fontSize=12,
        textColor=NAMU_DARK,
        spaceBefore=12,
        spaceAfter=6,
        leftIndent=10
    ))

    # 본문 스타일
    styles.add(ParagraphStyle(
        name='NamuBody',
        fontName=BASE_FONT,
        fontSize=10,
        textColor=NAMU_DARK,
        spaceBefore=3,
        spaceAfter=3,
        leading=16,
        alignment=TA_JUSTIFY
    ))

    # 인용문 스타일 (나무위키 회색 박스)
    styles.add(ParagraphStyle(
        name='NamuQuote',
        fontName=BASE_FONT,
        fontSize=10,
        textColor=NAMU_QUOTE,
        spaceBefore=8,
        spaceAfter=8,
        leftIndent=15,
        rightIndent=15,
        borderPadding=10,
        backColor=NAMU_GRAY,
        leading=14
    ))

    # 주의/경고 스타일
    styles.add(ParagraphStyle(
        name='NamuWarning',
        fontName=BOLD_FONT,
        fontSize=10,
        textColor=NAMU_RED,
        spaceBefore=8,
        spaceAfter=8,
        leftIndent=10,
        borderPadding=8,
        backColor=colors.HexColor('#FFF3CD')
    ))

    # 팁 스타일
    styles.add(ParagraphStyle(
        name='NamuTip',
        fontName=BASE_FONT,
        fontSize=10,
        textColor=NAMU_DARK,
        spaceBefore=5,
        spaceAfter=5,
        leftIndent=15,
        leading=14
    ))

    # 목록 아이템 스타일
    styles.add(ParagraphStyle(
        name='NamuList',
        fontName=BASE_FONT,
        fontSize=10,
        textColor=NAMU_DARK,
        spaceBefore=2,
        spaceAfter=2,
        leftIndent=20,
        bulletIndent=10,
        leading=14
    ))

    # 코드/키 스타일 (키보드 키 표시용)
    styles.add(ParagraphStyle(
        name='NamuCode',
        fontName=BOLD_FONT,
        fontSize=9,
        textColor=NAMU_DARK,
        backColor=NAMU_GRAY,
        borderPadding=2
    ))

    # 각주 스타일
    styles.add(ParagraphStyle(
        name='NamuFootnote',
        fontName=LIGHT_FONT,
        fontSize=8,
        textColor=NAMU_QUOTE,
        spaceBefore=2,
        spaceAfter=2,
        leftIndent=10
    ))

    return styles


def create_namu_table(data, col_widths=None, header=True, title=None):
    """나무위키 스타일 테이블 생성"""
    if title:
        # 제목 행 추가
        data = [[title]] + data

    table = Table(data, colWidths=col_widths)

    style_commands = [
        ('FONTNAME', (0, 0), (-1, -1), BASE_FONT),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.5, NAMU_BORDER),
        ('TOPPADDING', (0, 0), (-1, -1), 8),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
        ('LEFTPADDING', (0, 0), (-1, -1), 10),
        ('RIGHTPADDING', (0, 0), (-1, -1), 10),
    ]

    start_row = 0
    if title:
        # 제목 행 스타일
        style_commands.extend([
            ('SPAN', (0, 0), (-1, 0)),
            ('BACKGROUND', (0, 0), (-1, 0), NAMU_GREEN),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), BOLD_FONT),
            ('FONTSIZE', (0, 0), (-1, 0), 11),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
        ])
        start_row = 1

    if header:
        header_row = start_row
        style_commands.extend([
            ('BACKGROUND', (0, header_row), (-1, header_row), NAMU_HEADER),
            ('FONTNAME', (0, header_row), (-1, header_row), BOLD_FONT),
            ('FONTSIZE', (0, header_row), (-1, header_row), 10),
        ])
        # 홀수 행 배경색
        for i in range(header_row + 1, len(data)):
            if (i - header_row) % 2 == 0:
                style_commands.append(('BACKGROUND', (0, i), (-1, i), NAMU_GRAY))

    table.setStyle(TableStyle(style_commands))
    return table


def create_divider():
    """나무위키 스타일 구분선"""
    return HRFlowable(
        width="100%",
        thickness=1,
        color=NAMU_BORDER,
        spaceBefore=10,
        spaceAfter=10
    )


def create_info_box(text, box_type="info", styles=None):
    """정보 박스 생성 (팁, 주의, 정보 등)"""
    if box_type == "warning":
        prefix = "⚠️ 주의: "
        style = styles['NamuWarning']
    elif box_type == "tip":
        prefix = "💡 팁: "
        style = styles['NamuTip']
    else:
        prefix = "ℹ️ "
        style = styles['NamuQuote']

    return Paragraph(f"{prefix}{text}", style)


def build_pdf():
    """PDF 문서 생성"""
    output_path = os.path.join(PROJECT_ROOT, "docs", "핑파이터_기본가이드.pdf")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        rightMargin=18*mm,
        leftMargin=18*mm,
        topMargin=15*mm,
        bottomMargin=15*mm
    )

    styles = create_styles()
    story = []

    # ===== 표지 / 문서 헤더 =====
    story.append(Paragraph("핑파이터", styles['NamuTitle']))
    story.append(Paragraph("PingFighter - 기본 조작법 및 게임 팁 가이드", styles['NamuSubtitle']))
    story.append(create_divider())

    # 문서 개요 박스
    overview_data = [
        ['핑파이터 (PingFighter)'],
        ['장르', '아케이드 / 액션 / 탁구'],
        ['플랫폼', 'Windows, macOS'],
        ['개발', 'Sahogany Studio'],
        ['엔진', 'Python + Pygame'],
        ['출시', '2024년'],
    ]
    story.append(create_namu_table(overview_data, col_widths=[50*mm, 100*mm], header=True))
    story.append(Spacer(1, 10*mm))

    story.append(Paragraph(
        "핑파이터는 보스전 중심의 아케이드 스타일 탁구 게임입니다. "
        "플레이어는 패들을 조작하여 공을 튕기고, 다양한 아이템과 스킬을 활용해 "
        "8개의 스테이지에 걸쳐 보스들을 물리쳐야 합니다.",
        styles['NamuBody']
    ))

    story.append(Spacer(1, 8*mm))

    # 목차
    story.append(Paragraph("[ 목차 ]", styles['NamuH2']))
    toc_items = [
        "1. 기본 조작법",
        "2. 대시 시스템",
        "3. 아이템 시스템",
        "4. 스테이지 및 보스",
        "5. 아카데미 스킬",
        "6. 전설 아이템",
        "7. 게임 팁 및 전략",
    ]
    for item in toc_items:
        story.append(Paragraph(f"  {item}", styles['NamuList']))

    story.append(PageBreak())

    # ===== 1. 기본 조작법 =====
    story.append(Paragraph("1. 기본 조작법", styles['NamuH1']))
    story.append(create_divider())

    story.append(Paragraph("1.1. 이동 및 기본 조작", styles['NamuH2']))

    basic_controls = [
        ['키', '동작', '설명'],
        ['← / →', '좌우 이동', '패들을 좌우로 이동합니다'],
        ['↓', '대시 / 물자보급', '짧게 누르면 대시, 길게 누르면 물자보급(코만도)'],
        ['SPACE', '대시', '대시를 발동합니다'],
        ['ESC', '일시정지/메뉴', '게임 메뉴를 엽니다'],
        ['TAB', '아이템 관리', '보유 아이템 목록을 확인합니다'],
    ]
    story.append(create_namu_table(basic_controls, col_widths=[35*mm, 40*mm, 75*mm]))
    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("1.2. 마우스 조작 (선택)", styles['NamuH2']))
    story.append(Paragraph(
        "옵션 메뉴에서 마우스 조작을 활성화할 수 있습니다. 마우스 버튼을 방향키에 매핑하여 사용합니다.",
        styles['NamuBody']
    ))

    mouse_controls = [
        ['마우스 입력', '매핑되는 동작'],
        ['마우스 좌클릭', '발사 / 선택'],
        ['마우스 휠 ↑/↓', '화기 교체 (코만도 전용)'],
        ['마우스 중클릭', '권총 즉시 전환 (코만도 전용)'],
    ]
    story.append(create_namu_table(mouse_controls, col_widths=[50*mm, 100*mm]))
    story.append(Spacer(1, 5*mm))

    story.append(create_info_box(
        "IME 호환성 - 모든 키보드 레이아웃과 한글 입력기를 지원합니다.",
        "info", styles
    ))

    story.append(PageBreak())

    # ===== 2. 대시 시스템 =====
    story.append(Paragraph("2. 대시 시스템", styles['NamuH1']))
    story.append(create_divider())

    story.append(Paragraph(
        "대시는 핑파이터의 핵심 회피 및 이동 메커니즘입니다. "
        "적절한 타이밍의 대시는 위기 상황에서 벗어나고, 유리한 위치를 선점하는 데 필수적입니다.",
        styles['NamuBody']
    ))
    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("2.1. 기본 대시", styles['NamuH2']))

    dash_basic = [
        ['항목', '수치'],
        ['발동 키', 'SPACE 또는 ↓ 짧게'],
        ['쿨타임', '8초 (기본)'],
        ['게이지 소모', '있음'],
        ['이동 거리', '스킬에 따라 증가 가능'],
    ]
    story.append(create_namu_table(dash_basic, col_widths=[50*mm, 100*mm]))
    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("2.2. 하프 대시 시스템", styles['NamuH2']))
    story.append(Paragraph(
        "기본 대시의 변형 시스템으로, 짧은 거리를 빠르게 이동할 때 사용합니다. "
        "단거리 대시 시 속도 배율이 1.30배로 증가하여 더 민첩한 움직임이 가능합니다.",
        styles['NamuBody']
    ))

    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("2.3. 대시 관련 스킬", styles['NamuH2']))

    dash_skills = [
        ['스킬명', '최대 레벨', '효과'],
        ['경량화', 'Lv5', '대시 쿨타임 7% 감소'],
        ['모듈제어', 'Lv5', '대시 후딜 시간 10% 감소'],
        ['도약', 'Lv5', '대시 거리 4% 증가 (★4 필요)'],
        ['배터리팩', 'Lv5', '게이지 소모량 8% 감소 (★4 필요)'],
        ['버스트업', 'Lv5', '대시 시 패들 크기 60% 증가 (★8 필요)'],
        ['증폭', 'Lv2', '대시 토큰 1개 추가 (★8 필요)'],
        ['대시 스피릿', 'Lv2', '대시 시 레이저 잔상 생성 (★12 필요)'],
    ]
    story.append(create_namu_table(dash_skills, col_widths=[40*mm, 30*mm, 80*mm]))

    story.append(Spacer(1, 5*mm))
    story.append(create_info_box(
        "★ 표시는 해당 스킬 트리에 누적 투자한 총 스킬 포인트를 의미합니다.",
        "tip", styles
    ))

    story.append(PageBreak())

    # ===== 3. 아이템 시스템 =====
    story.append(Paragraph("3. 아이템 시스템", styles['NamuH1']))
    story.append(create_divider())

    story.append(Paragraph(
        "핑파이터에는 50종 이상의 다양한 아이템이 존재합니다. "
        "아이템은 크게 액티브 아이템과 패시브 아이템으로 구분됩니다.",
        styles['NamuBody']
    ))

    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("3.1. 아이템 분류", styles['NamuH2']))

    item_types = [
        ['분류', '설명', '예시'],
        ['액티브', '사용 시 효과 발동, 쿨타임 존재', '수류탄, 화염병, 스탑워치'],
        ['패시브', '획득 시 상시 효과 적용', '벌크업, 센서, 무중력벨트'],
        ['전설', '매우 희귀, 강력한 효과', '라그나로크 해머, 헤르메스 신발'],
    ]
    story.append(create_namu_table(item_types, col_widths=[30*mm, 70*mm, 50*mm]))

    story.append(Spacer(1, 8*mm))

    story.append(Paragraph("3.2. 주요 액티브 아이템", styles['NamuH2']))

    active_items = [
        ['아이템명', '효과', '드랍률'],
        ['롱부스트', '볼 속도 증가', '2.8%'],
        ['슬롯 추가', '아이템 슬롯 +1', '0.6%'],
        ['게이지 충전', '게이지 즉시 충전', '4.2%'],
        ['벽돌', '필드에 벽돌 설치', '3.5%'],
        ['부활', '사망 시 1회 부활', '0.5%'],
        ['수류탄', '폭발 데미지', '1.8%'],
        ['화염병', '화염 지역 생성', '1.5%'],
        ['스탑워치', '시간 일시 정지', '0.6%'],
        ['조명탄', '시야 확대', '2.0%'],
        ['연막탄', '연막 생성', '1.8%'],
        ['악마의 주사위', '랜덤 효과', '0.2%'],
    ]
    story.append(create_namu_table(active_items, col_widths=[45*mm, 70*mm, 35*mm]))

    story.append(PageBreak())

    story.append(Paragraph("3.3. 주요 패시브 아이템", styles['NamuH2']))

    passive_items = [
        ['아이템명', '효과', '드랍률'],
        ['벌크업', '패들 크기 영구 증가', '0.5%'],
        ['감지센서', '볼 추적 능력 향상', '0.5%'],
        ['무중력벨트', '무중력 상태 (특수 이동)', '0.2%'],
        ['대쉬홀더', '대시 횟수 보너스', '0.8%'],
        ['다우징팬들럼', '아이템 탐지 강화', '0.5%'],
        ['코만도암', '격투 능력 강화', '0.8%'],
        ['테크니컬조끼', '방어력 증가', '0.5%'],
        ['방탄모자', '피해 감소', '0.6%'],
        ['가시투구', '반격 피해 부여', '0.6%'],
    ]
    story.append(create_namu_table(passive_items, col_widths=[45*mm, 70*mm, 35*mm]))

    story.append(Spacer(1, 8*mm))

    story.append(Paragraph("3.4. 아이템 획득 방법", styles['NamuH2']))
    story.append(Paragraph("• 필드 드롭 - 스테이지 진행 중 랜덤 스폰", styles['NamuList']))
    story.append(Paragraph("• 가챠 시스템 - 게이지를 사용하여 뽑기", styles['NamuList']))
    story.append(Paragraph("• 물자보급 - 코만도 캐릭터 전용", styles['NamuList']))
    story.append(Paragraph("• 스테이지 보상 - 특정 조건 달성 시", styles['NamuList']))

    story.append(PageBreak())

    # ===== 4. 스테이지 및 보스 =====
    story.append(Paragraph("4. 스테이지 및 보스", styles['NamuH1']))
    story.append(create_divider())

    story.append(Paragraph(
        "핑파이터는 총 8개의 스테이지로 구성되어 있으며, "
        "각 스테이지마다 고유한 배경과 특수 이벤트, 보스가 등장합니다.",
        styles['NamuBody']
    ))

    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("4.1. 스테이지 목록", styles['NamuH2']))

    stages = [
        ['스테이지', '특징', '특수 이벤트'],
        ['1', '튜토리얼, 기본 조작 학습', '풍선 기계'],
        ['2', '난이도 상승, 빠른 움직임 요구', '지진 이벤트'],
        ['3', '독특한 보스 패턴', '-'],
        ['4', '파워스매싱 시스템 도입', '-'],
        ['5', '화염 관련 메커니즘', '화염 기계'],
        ['6', '높은 난이도', '-'],
        ['7', '전자기파 메커니즘', 'EMP 펄스'],
        ['8', '최종 보스, 초고속 시스템', '초고속 모드'],
    ]
    story.append(create_namu_table(stages, col_widths=[30*mm, 60*mm, 60*mm]))

    story.append(Spacer(1, 8*mm))

    story.append(Paragraph("4.2. 보스 공통 메커니즘", styles['NamuH2']))
    story.append(Paragraph("• 다단계 체력 시스템 - 체력에 따라 패턴 변화", styles['NamuList']))
    story.append(Paragraph("• 넉백 저항 - 라그나로크 해머 등에 대한 저항", styles['NamuList']))
    story.append(Paragraph("• 스턴 시간 - 넉백 시 30프레임(0.5초) 스턴", styles['NamuList']))
    story.append(Paragraph("• 광폭화 - 체력이 낮아지면 패턴이 격렬해짐", styles['NamuList']))

    story.append(Spacer(1, 5*mm))

    story.append(create_info_box(
        "보스의 패턴을 몇 라운드에 걸쳐 학습하는 것이 클리어의 핵심입니다!",
        "tip", styles
    ))

    story.append(PageBreak())

    # ===== 5. 아카데미 스킬 =====
    story.append(Paragraph("5. 아카데미 스킬", styles['NamuH1']))
    story.append(create_divider())

    story.append(Paragraph(
        "아카데미에서는 스킬 포인트(TP)를 사용하여 다양한 능력을 강화할 수 있습니다. "
        "스킬은 세 개의 트리로 구성되어 있습니다.",
        styles['NamuBody']
    ))

    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("5.1. 스킬 트리 구조", styles['NamuH2']))

    skill_trees = [
        ['트리', '색상', '주요 기능'],
        ['대시', '파란색', '대시 속도, 거리, 토큰 강화'],
        ['아이템', '주황색', '드랍률, 쿨타임, 가챠 강화'],
        ['패들', '초록색', '패들 능력 강화 (재구성 중)'],
    ]
    story.append(create_namu_table(skill_trees, col_widths=[35*mm, 35*mm, 80*mm]))

    story.append(Spacer(1, 8*mm))

    story.append(Paragraph("5.2. 아이템 트리 주요 스킬", styles['NamuH2']))

    item_skills = [
        ['스킬명', '최대 레벨', '효과'],
        ['행운', 'Lv5', '아이템 스폰 대기 시간 6% 감소'],
        ['숙련', 'Lv5', '액티브 아이템 쿨타임 8% 감소'],
        ['숙달', 'Lv5', '아이템 사용 시 게이지 +7 (★4)'],
        ['가방 확장', 'Lv3', '액티브 슬롯 +1 (★4)'],
        ['도박', 'Lv3', '가챠 추가 실행 25% 확률 (★8)'],
        ['연금술', 'Lv3', '아이템 유지 20% 확률 (★8)'],
        ['보물지도', 'Lv2', '전설 확률 +350% (★12)'],
    ]
    story.append(create_namu_table(item_skills, col_widths=[40*mm, 30*mm, 80*mm]))

    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("5.3. 스킬 포인트 획득", styles['NamuH2']))
    story.append(Paragraph("• 스테이지 클리어 - 각 스테이지당 1포인트", styles['NamuList']))
    story.append(Paragraph("• 트레이드 포인트 - 스테이지 내 수집 후 전환", styles['NamuList']))
    story.append(Paragraph("• 누적 조건 - 상위 스킬 해금에 총 투자량 필요", styles['NamuList']))

    story.append(PageBreak())

    # ===== 6. 전설 아이템 =====
    story.append(Paragraph("6. 전설 아이템", styles['NamuH1']))
    story.append(create_divider())

    story.append(Paragraph(
        "전설 아이템은 매우 희귀하지만 강력한 효과를 가진 특별한 아이템입니다. "
        "필드 스폰 확률은 0.08%로, 약 1,250번 중 1번 꼴로 등장합니다.",
        styles['NamuBody']
    ))

    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("6.1. 전설 아이템 목록", styles['NamuH2']))

    legendary_items = [
        ['아이템명', '색상', '효과'],
        ['라그나로크 해머', '붉은색', '강력한 넉백 공격'],
        ['헤르메스의 신발', '하늘색', '초고속 이동 및 대시 강화'],
        ['포세이돈의 삼지창', '바다색', '수파 생성, 궤적 영향'],
        ['천사의 가호', '흰색', '다중 버프 옵션 제공'],
        ['신성 월계수', '연두색', '신성한 능력 부여'],
    ]
    story.append(create_namu_table(legendary_items, col_widths=[50*mm, 35*mm, 65*mm]))

    story.append(Spacer(1, 8*mm))

    story.append(Paragraph("6.2. 전설 아이템 특징", styles['NamuH2']))
    story.append(Paragraph("• 붉은색 테두리와 애니메이션 아이콘", styles['NamuList']))
    story.append(Paragraph("• 모든 전설 아이템은 패시브로 분류", styles['NamuList']))
    story.append(Paragraph("• 세션 중 동일 아이템 중복 획득 불가", styles['NamuList']))
    story.append(Paragraph("• 게임 오버 또는 메인 메뉴 복귀 시 효과 리셋", styles['NamuList']))

    story.append(Spacer(1, 5*mm))

    story.append(create_info_box(
        "'보물지도' 스킬(★12 필요)로 전설 아이템 획득 확률을 350% 증가시킬 수 있습니다!",
        "tip", styles
    ))

    story.append(PageBreak())

    # ===== 7. 게임 팁 및 전략 =====
    story.append(Paragraph("7. 게임 팁 및 전략", styles['NamuH1']))
    story.append(create_divider())

    story.append(Paragraph("7.1. 초보자 팁", styles['NamuH2']))

    beginner_tips = [
        "• 튜토리얼 스테이지에서 기본 조작을 충분히 연습하세요",
        "• 대시는 이동뿐 아니라 회피에도 필수적입니다",
        "• 초반에는 롱부스트, 슬롯 추가, 부활 아이템을 우선 확보하세요",
        "• 보스의 공격 패턴을 몇 라운드 동안 관찰하세요",
        "• 게이지 관리가 중요합니다 - 대시용 게이지를 항상 확보하세요",
    ]
    for tip in beginner_tips:
        story.append(Paragraph(tip, styles['NamuList']))

    story.append(Spacer(1, 8*mm))

    story.append(Paragraph("7.2. 중급자 팁", styles['NamuH2']))

    intermediate_tips = [
        "• 스킬 트리 투자 순서: 대시 → 행운 → 버스트업 → 보물지도",
        "• 아이템 조합: 벌크업 + 스파이크부츠 = 공격 중심 빌드",
        "• 아이템 조합: 무중력벨트 + 스마트폰 = 추적 중심 빌드",
        "• 아이템 조합: 부활 + 생명수 = 생존 중심 빌드",
        "• 각 스테이지별 특수 이벤트에 대비하세요",
    ]
    for tip in intermediate_tips:
        story.append(Paragraph(tip, styles['NamuList']))

    story.append(Spacer(1, 8*mm))

    story.append(Paragraph("7.3. 고급자 팁", styles['NamuH2']))

    advanced_tips = [
        "• '연금술' 스킬로 강력한 아이템을 반복 사용하세요",
        "• '도박' 스킬로 가챠 효율을 극대화하세요",
        "• 무한 대시 빌드: 증폭 + 배터리팩 + 대쉬홀더 + 게이지 충전",
        "• 드라이브 보너스(12초)를 활용한 딜 극대화",
        "• 전설 아이템 파밍: 보물지도 스킬 + 반복 플레이",
    ]
    for tip in advanced_tips:
        story.append(Paragraph(tip, styles['NamuList']))

    story.append(Spacer(1, 8*mm))

    story.append(Paragraph("7.4. 스테이지별 전략", styles['NamuH2']))

    stage_strategy = [
        ['스테이지', '전략'],
        ['1', '기본 패턴 학습, 아이템 수집에 집중'],
        ['2', '지진 피하기, 빠른 대시 활용'],
        ['3', '독특한 패턴 대응, 타이밍 학습'],
        ['5', '화염 이벤트 피하기, 연막탄 유용'],
        ['7', 'EMP 펄스 타이밍 파악, 안전 지대 확보'],
        ['8', '초고속 모드 대비, 최대 반응 속도 요구'],
    ]
    story.append(create_namu_table(stage_strategy, col_widths=[30*mm, 120*mm]))

    story.append(Spacer(1, 10*mm))

    # 마무리
    story.append(create_divider())
    story.append(Paragraph(
        "이 가이드는 핑파이터 게임의 핵심 시스템과 팁을 정리한 문서입니다. "
        "실제 플레이를 통해 자신만의 전략을 개발해 보세요!",
        styles['NamuQuote']
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph("ⓒ 2024 Sahogany Studio - PingFighter", styles['NamuFootnote']))

    # 문서 빌드
    doc.build(story)
    print(f"[OK] PDF 생성 완료: {output_path}")
    return output_path


if __name__ == "__main__":
    try:
        output = build_pdf()
        print(f"PDF 파일 위치: {output}")
    except ImportError as e:
        print(f"[ERROR] reportlab 라이브러리가 필요합니다: {e}")
        print("설치 명령어: pip install reportlab")
    except Exception as e:
        print(f"[ERROR] PDF 생성 실패: {e}")
        import traceback
        traceback.print_exc()
