#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
코만도(Commando) 캐릭터 공략 PDF 생성기
핑파이터 게임 공략 자료
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
    Image, PageBreak, HRFlowable
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT

# 폰트 등록
FONT_PATH = os.path.join(PROJECT_ROOT, "fonts", "NanumSquareB.ttf")
FONT_PATH_BOLD = os.path.join(PROJECT_ROOT, "fonts", "NanumSquareEB.ttf")

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

# 아이콘 경로
ITEMS_PATH = os.path.join(PROJECT_ROOT, "items")
SOLDIER_IMG_PATH = os.path.join(PROJECT_ROOT, "soldier_paddle_new.png")

# 색상 정의
COLOR_PRIMARY = colors.HexColor('#2E4057')
COLOR_SECONDARY = colors.HexColor('#048A81')
COLOR_ACCENT = colors.HexColor('#F18F01')
COLOR_WARNING = colors.HexColor('#C73E1D')
COLOR_BG_LIGHT = colors.HexColor('#F5F5F5')
COLOR_BG_TABLE = colors.HexColor('#E8F4F8')


def get_icon_path(item_name):
    """아이템 아이콘 경로 반환"""
    path = os.path.join(ITEMS_PATH, f"{item_name}.png")
    if os.path.exists(path):
        return path
    return None


def create_styles():
    """스타일 생성"""
    styles = getSampleStyleSheet()

    # 제목 스타일
    styles.add(ParagraphStyle(
        name='KoreanTitle',
        fontName=BOLD_FONT,
        fontSize=24,
        textColor=COLOR_PRIMARY,
        alignment=TA_CENTER,
        spaceAfter=20,
        spaceBefore=10
    ))

    # 부제목 스타일
    styles.add(ParagraphStyle(
        name='KoreanHeading1',
        fontName=BOLD_FONT,
        fontSize=16,
        textColor=COLOR_SECONDARY,
        spaceBefore=15,
        spaceAfter=10,
        borderPadding=5,
        backColor=COLOR_BG_LIGHT
    ))

    # 소제목 스타일
    styles.add(ParagraphStyle(
        name='KoreanHeading2',
        fontName=BOLD_FONT,
        fontSize=13,
        textColor=COLOR_PRIMARY,
        spaceBefore=12,
        spaceAfter=6
    ))

    # 본문 스타일
    styles.add(ParagraphStyle(
        name='KoreanBody',
        fontName=BASE_FONT,
        fontSize=10,
        textColor=colors.black,
        spaceBefore=4,
        spaceAfter=4,
        leading=14
    ))

    # 인용문 스타일
    styles.add(ParagraphStyle(
        name='Quote',
        fontName=BASE_FONT,
        fontSize=11,
        textColor=COLOR_SECONDARY,
        alignment=TA_CENTER,
        spaceBefore=10,
        spaceAfter=10,
        leftIndent=20,
        rightIndent=20,
        borderPadding=10,
        backColor=COLOR_BG_LIGHT
    ))

    # 경고 스타일
    styles.add(ParagraphStyle(
        name='Warning',
        fontName=BOLD_FONT,
        fontSize=10,
        textColor=COLOR_WARNING,
        spaceBefore=8,
        spaceAfter=8,
        leftIndent=10,
        borderPadding=5
    ))

    # 팁 스타일
    styles.add(ParagraphStyle(
        name='Tip',
        fontName=BASE_FONT,
        fontSize=9,
        textColor=COLOR_SECONDARY,
        spaceBefore=4,
        spaceAfter=4,
        leftIndent=15,
        bulletIndent=5
    ))

    return styles


def create_table(data, col_widths=None, header=True):
    """테이블 생성"""
    table = Table(data, colWidths=col_widths)

    style_commands = [
        ('FONTNAME', (0, 0), (-1, -1), BASE_FONT),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]

    if header:
        style_commands.extend([
            ('BACKGROUND', (0, 0), (-1, 0), COLOR_PRIMARY),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), BOLD_FONT),
            ('FONTSIZE', (0, 0), (-1, 0), 10),
        ])
        # 홀수 행 배경색
        for i in range(1, len(data)):
            if i % 2 == 0:
                style_commands.append(('BACKGROUND', (0, i), (-1, i), COLOR_BG_TABLE))

    table.setStyle(TableStyle(style_commands))
    return table


def add_icon_to_table_cell(icon_name, text):
    """아이콘과 텍스트를 포함한 테이블 셀 생성"""
    icon_path = get_icon_path(icon_name)
    if icon_path:
        try:
            return [Image(icon_path, width=16, height=16), f" {text}"]
        except:
            pass
    return text


def build_pdf():
    """PDF 문서 생성"""
    output_path = os.path.join(PROJECT_ROOT, "docs", "코만도_공략가이드.pdf")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        rightMargin=15*mm,
        leftMargin=15*mm,
        topMargin=15*mm,
        bottomMargin=15*mm
    )

    styles = create_styles()
    story = []

    # ===== 표지 =====
    story.append(Spacer(1, 30*mm))
    story.append(Paragraph("핑파이터 (PingFighter)", styles['KoreanTitle']))
    story.append(Spacer(1, 10*mm))
    story.append(Paragraph("코만도 캐릭터 공략 가이드", styles['KoreanTitle']))
    story.append(Spacer(1, 15*mm))

    # 캐릭터 이미지
    if os.path.exists(SOLDIER_IMG_PATH):
        try:
            soldier_img = Image(SOLDIER_IMG_PATH, width=80*mm, height=80*mm)
            soldier_img.hAlign = 'CENTER'
            story.append(soldier_img)
        except Exception as e:
            print(f"이미지 로드 실패: {e}")

    story.append(Spacer(1, 15*mm))
    story.append(Paragraph('"탄약은 곧 정의다."', styles['Quote']))
    story.append(Spacer(1, 20*mm))

    # 기본 정보 테이블
    info_data = [
        ['항목', '내용'],
        ['캐릭터 ID', 'soldier'],
        ['별명', '코만도, 솔져'],
        ['기본 장비', '코만도암 (패시브), 권총 (기본 화기)'],
        ['전용 시스템', '화기 교체, 물자보급, 헤드샷/레그샷'],
        ['플레이 스타일', '원거리 슈터형'],
        ['난이도', '★★★☆☆ (보통)'],
    ]
    story.append(create_table(info_data, col_widths=[50*mm, 100*mm]))

    story.append(PageBreak())

    # ===== 1. 캐릭터 개요 =====
    story.append(Paragraph("1. 캐릭터 개요", styles['KoreanHeading1']))
    story.append(Paragraph(
        "코만도는 핑파이터의 플레이어블 캐릭터 중 하나로, 화력 기반 원거리 딜러입니다. "
        "권총을 기본 무기로 사용하며, 다양한 화기류를 수집하고 교체하며 싸우는 슈터 스타일 플레이가 특징입니다.",
        styles['KoreanBody']
    ))
    story.append(Spacer(1, 5*mm))

    # ===== 2. 기본 패시브 =====
    story.append(Paragraph("2. 기본 패시브: 코만도암 (Commando Arm)", styles['KoreanHeading1']))
    story.append(Paragraph(
        "캐릭터 선택 시 자동으로 장착되는 패시브 아이템입니다. 최대 2개까지 중첩 가능하며, 중첩 시 효과가 강화됩니다.",
        styles['KoreanBody']
    ))

    passive_data = [
        ['효과', '기본 보너스', '설명'],
        ['투척 속도 증가', '+15%', '수류탄 등 투척 속도 상승'],
        ['폭발 범위 증가', '+10%', '폭발 아이템 범위 확대'],
        ['연막 지속시간', '+30%', '연막탄 효과 연장'],
    ]
    story.append(create_table(passive_data, col_widths=[45*mm, 35*mm, 70*mm]))
    story.append(Spacer(1, 5*mm))

    # ===== 3. 화기 시스템 =====
    story.append(Paragraph("3. 화기 시스템", styles['KoreanHeading1']))
    story.append(Paragraph(
        "코만도의 핵심 시스템입니다. 다양한 화기류를 획득하고 전환하며 전투합니다.",
        styles['KoreanBody']
    ))

    story.append(Paragraph("3.1 보유 가능 화기 목록", styles['KoreanHeading2']))

    weapon_data = [
        ['화기', '타입', '특징'],
        ['권총 (Pistol)', '기본', '6발, 헤드샷/레그샷 확률 발동'],
        ['바주카포 (Bazooka)', '획득', '강력한 폭발 데미지, 넉백'],
        ['AK-47', '획득', '빠른 연사력, 높은 DPS'],
        ['그물덫총 (Net Gun)', '획득', '보스 일시 속박'],
        ['화력지원 (Fire Support)', '획득', '폭격기 호출, 광역 폭발'],
        ['자폭드론 (Suicide Drone)', '획득', '유도 드론 3기'],
    ]
    story.append(create_table(weapon_data, col_widths=[50*mm, 30*mm, 70*mm]))
    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("3.2 화기 교체 조작법", styles['KoreanHeading2']))
    control_data = [
        ['조작', '동작'],
        ['마우스 휠 ↑/↓', '다음/이전 화기로 전환'],
        ['마우스 중클릭', '권총으로 즉시 전환'],
        ['숫자키 1~5', '해당 슬롯 화기 직접 선택'],
    ]
    story.append(create_table(control_data, col_widths=[50*mm, 100*mm]))
    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("3.3 화기 노후화 시스템", styles['KoreanHeading2']))
    story.append(Paragraph(
        "⚠️ 주의: 권총을 제외한 모든 화기는 노후화될 수 있습니다!",
        styles['Warning']
    ))

    degradation_data = [
        ['단계', '설명'],
        ['1. 획득', '화기 획득 시 0~2회의 노후화 임계치 랜덤 부여'],
        ['2. 사용', '재장전 횟수가 임계치에 도달하면 노후화 상태 진입'],
        ['3. 파괴', '노후화된 화기는 탄약이 바닥나면 완전 파괴'],
    ]
    story.append(create_table(degradation_data, col_widths=[30*mm, 120*mm]))

    story.append(PageBreak())

    # ===== 4. 스킬 시스템 =====
    story.append(Paragraph("4. 스킬 시스템", styles['KoreanHeading1']))

    story.append(Paragraph("4.1 헤드샷 (Headshot)", styles['KoreanHeading2']))
    story.append(Paragraph(
        "권총 사격 시 확률적으로 발동하는 특수 효과입니다.",
        styles['KoreanBody']
    ))
    headshot_data = [
        ['효과', '수치'],
        ['스턴', '보스 1초간 행동 불가'],
        ['게이지 보너스', '+50 게이지'],
        ['도핑 시', '발동 확률 2배'],
    ]
    story.append(create_table(headshot_data, col_widths=[50*mm, 100*mm]))
    story.append(Spacer(1, 3*mm))

    story.append(Paragraph("4.2 레그샷 (Legshot)", styles['KoreanHeading2']))
    story.append(Paragraph(
        "권총 사격 시 확률적으로 발동하는 특수 효과입니다. (헤드샷 미발동 시)",
        styles['KoreanBody']
    ))
    legshot_data = [
        ['효과', '수치'],
        ['이속 감소', '보스 이동속도 30% 감소'],
        ['게이지 보너스', '+40 게이지'],
        ['도핑 시', '발동 확률 2배'],
    ]
    story.append(create_table(legshot_data, col_widths=[50*mm, 100*mm]))
    story.append(Spacer(1, 3*mm))

    story.append(Paragraph("4.3 물자보급 (Supply Drop)", styles['KoreanHeading2']))
    story.append(Paragraph(
        "코만도 전용 스킬로, 아래 방향키를 길게 눌러 발동합니다. 무전기로 보급품을 요청합니다.",
        styles['KoreanBody']
    ))
    supply_data = [
        ['조작', '설명'],
        ['↓ 길게 유지', '무전기로 물자 요청'],
        ['발동 조건', '게이지 충분 + 홀드 시간 충족'],
    ]
    story.append(create_table(supply_data, col_widths=[50*mm, 100*mm]))
    story.append(Spacer(1, 5*mm))

    # ===== 5. 전용 아이템 =====
    story.append(Paragraph("5. 전용 아이템", styles['KoreanHeading1']))

    story.append(Paragraph("5.1 물자보급 전용 아이템", styles['KoreanHeading2']))
    supply_items_data = [
        ['아이템', '효과'],
        ['탄약상자', '모든 화기 즉시 풀장전'],
        ['화력지원', '폭격기 호출, 광역 폭발 데미지'],
        ['도핑물약', '8초간 헤드샷/레그샷 확률 2배'],
        ['자폭드론', '유도 드론 3기, 보스 추적 폭발'],
    ]
    story.append(create_table(supply_items_data, col_widths=[50*mm, 100*mm]))
    story.append(Spacer(1, 3*mm))

    story.append(Paragraph("5.2 투척 아이템 (코만도암 강화 적용)", styles['KoreanHeading2']))
    throw_items_data = [
        ['아이템', '기본 효과', '코만도 보너스'],
        ['수류탄', '폭발 데미지 + 스턴', '투척 속도↑, 폭발 범위↑'],
        ['연막탄', '보스 시야 차단', '지속시간 +30%'],
    ]
    story.append(create_table(throw_items_data, col_widths=[40*mm, 55*mm, 55*mm]))

    story.append(PageBreak())

    # ===== 6. 조작법 요약 =====
    story.append(Paragraph("6. 조작법 요약", styles['KoreanHeading1']))
    controls_full_data = [
        ['조작', '동작'],
        ['← →', '좌우 이동'],
        ['↓ 짧게', '대시'],
        ['↓ 길게', '물자보급 호출'],
        ['SPACE / 좌클릭', '현재 화기 발사'],
        ['R / 탄약 소진 시', '재장전'],
        ['마우스 휠', '화기 교체'],
        ['마우스 중클릭', '권총으로 전환'],
        ['숫자키 1~5', '슬롯 직접 선택'],
    ]
    story.append(create_table(controls_full_data, col_widths=[50*mm, 100*mm]))
    story.append(Spacer(1, 8*mm))

    # ===== 7. 공략 가이드 =====
    story.append(Paragraph("7. 공략 가이드", styles['KoreanHeading1']))

    story.append(Paragraph("7.1 초보자 필독 팁", styles['KoreanHeading2']))
    tips_beginner = [
        "• 권총은 절대 버려지지 않습니다 - 다른 화기가 모두 파괴되어도 권총은 남습니다.",
        "• 재장전 타이밍을 익히세요 - R키로 수동 재장전 가능 (여유 있을 때 미리!)",
        "• 물자보급을 적극 활용하세요 - 게이지가 차면 ↓ 홀드로 물자 호출",
        "• 헤드샷/레그샷을 노려보세요 - 권총 명중 시 확률 발동"
    ]
    for tip in tips_beginner:
        story.append(Paragraph(tip, styles['Tip']))
    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("7.2 중급자 팁", styles['KoreanHeading2']))
    tips_intermediate = [
        "• 화기 노후화 관리 - 노후화된 화기는 탄약 소진 전에 최대한 활용",
        "• 화기 조합 전략 - 바주카(큰 데미지), AK-47(빠른 연사), 그물덫총(속박)",
        "• 도핑물약 타이밍 - 사용 후 8초간 권총 연사로 헤드샷 확률 극대화",
        "• 화력지원 활용 - 발동 후딜 있으니 안전할 때 사용"
    ]
    for tip in tips_intermediate:
        story.append(Paragraph(tip, styles['Tip']))
    story.append(Spacer(1, 5*mm))

    story.append(Paragraph("7.3 상황별 전략", styles['KoreanHeading2']))
    strategy_data = [
        ['상황', '권장 전략'],
        ['다중 화기 보유 시', '상황에 맞게 빠른 교체'],
        ['탄약 부족 시', '권총으로 버티며 물자보급 대기'],
        ['보스 광폭화 시', '그물덫총으로 속박 후 딜'],
        ['노후화 화기 다수', '탄약상자 우선 확보'],
    ]
    story.append(create_table(strategy_data, col_widths=[50*mm, 100*mm]))

    story.append(PageBreak())

    # ===== 8. 화기별 상세 가이드 =====
    story.append(Paragraph("8. 화기별 상세 가이드", styles['KoreanHeading1']))

    weapons_detail = [
        ("바주카포 (Bazooka)", "필드 드롭, 물자보급", "폭발 범위 데미지, 넉백 효과", "보스가 멀리 있을 때 사용, 반동 주의"),
        ("AK-47", "필드 드롭, 물자보급", "빠른 연사, 높은 DPS", "탄약 소모 빠르니 탄약상자 확보 중요"),
        ("그물덫총 (Net Gun)", "필드 드롭", "보스 일시 속박", "속박 중 다른 화기로 딜 몰아넣기"),
        ("화력지원 (Fire Support)", "물자보급 전용", "폭격기 호출, 광역 폭발", "발동 후딜 있으니 안전할 때 사용"),
        ("자폭드론 (Suicide Drone)", "물자보급 전용", "자동 유도, 보스 추적 폭발 (3기)", "발사 후 자동 추적이라 회피기에 좋음"),
    ]

    for name, obtain, feature, tip in weapons_detail:
        story.append(Paragraph(f"◆ {name}", styles['KoreanHeading2']))
        weapon_detail_data = [
            ['획득 방법', obtain],
            ['특징', feature],
            ['팁', tip],
        ]
        detail_table = Table(weapon_detail_data, colWidths=[35*mm, 115*mm])
        detail_table.setStyle(TableStyle([
            ('FONTNAME', (0, 0), (-1, -1), BASE_FONT),
            ('FONTSIZE', (0, 0), (-1, -1), 9),
            ('FONTNAME', (0, 0), (0, -1), BOLD_FONT),
            ('BACKGROUND', (0, 0), (0, -1), COLOR_BG_LIGHT),
            ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('LEFTPADDING', (0, 0), (-1, -1), 6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ]))
        story.append(detail_table)
        story.append(Spacer(1, 3*mm))

    # ===== 9. 장단점 분석 =====
    story.append(Paragraph("9. 장단점 분석", styles['KoreanHeading1']))

    pros_cons_data = [
        ['장점', '단점'],
        ['안정적인 원거리 딜 가능', '화기 노후화로 무기 관리 필요'],
        ['다양한 화기로 상황 대응력 우수', '탄약 관리 까다로움'],
        ['헤드샷/레그샷의 CC기 보유', '재장전 중 무방비 상태'],
        ['물자보급으로 자원 수급 가능', '근접전 약함'],
        ['권총은 절대 사라지지 않음', ''],
    ]
    story.append(create_table(pros_cons_data, col_widths=[75*mm, 75*mm]))
    story.append(Spacer(1, 8*mm))

    # ===== 10. 추천 플레이어 =====
    story.append(Paragraph("10. 추천 플레이어", styles['KoreanHeading1']))
    recommend_list = [
        "• FPS/TPS 게임을 좋아하는 플레이어",
        "• 원거리 딜러를 선호하는 플레이어",
        "• 다양한 무기 활용을 즐기는 플레이어",
        "• 자원 관리 게임에 익숙한 플레이어"
    ]
    for item in recommend_list:
        story.append(Paragraph(item, styles['KoreanBody']))
    story.append(Spacer(1, 8*mm))

    # ===== 11. 여담 =====
    story.append(Paragraph("11. 여담", styles['KoreanHeading1']))
    trivia_list = [
        "• 코만도의 영어 이름 'Soldier'는 군인이라는 뜻입니다.",
        "• 헤드샷/레그샷 시스템은 FPS 게임에서 영감을 받았습니다.",
        "• 물자보급 시 무전기 애니메이션이 재생됩니다.",
        "• 화기 노후화 시스템은 현실적인 무기 관리를 반영한 것입니다.",
        "• 코만도암 2개 중첩 시 투척 아이템 성능이 크게 상승합니다."
    ]
    for item in trivia_list:
        story.append(Paragraph(item, styles['KoreanBody']))

    # 문서 빌드
    doc.build(story)
    print(f"✅ PDF 생성 완료: {output_path}")
    return output_path


if __name__ == "__main__":
    try:
        output = build_pdf()
        print(f"PDF 파일 위치: {output}")
    except ImportError as e:
        print(f"❌ reportlab 라이브러리가 필요합니다: {e}")
        print("설치 명령어: pip install reportlab")
    except Exception as e:
        print(f"❌ PDF 생성 실패: {e}")
        import traceback
        traceback.print_exc()
