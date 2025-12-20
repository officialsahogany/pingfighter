# -*- coding: utf-8 -*-
"""
옵티머스 전용 스킬을 런타임 스킬 시스템 형식으로 추가하는 스크립트
"""
import os

# 삽입할 코드
NEW_CODE = '''# 옵티머스 전용 스킬 풀 (런타임 스킬 시스템용 딕셔너리 형식)
OPTIMUS_EXCLUSIVE_SKILLS = {
    "mecha_chain": {
        "name": "메카체인",
        "max_level": 4,
        "descriptions": {
            1: "게이지 감소율 10% 감소",
            2: "게이지 감소율 20% 감소",
            3: "게이지 감소율 30% 감소",
            4: "게이지 감소율 40% 감소",
        },
        "detail": "옵티머스의 에너지 효율을 높여 게이지 감소율이 줄어듭니다.",
        "icon_color": (100, 200, 255),
        "tree": "optimus",
        "character_restriction": "optimus"
    },
    "mecha_charge": {
        "name": "메카차지",
        "max_level": 4,
        "descriptions": {
            1: "충전량 +10%",
            2: "충전량 +20%",
            3: "충전량 +30%",
            4: "충전량 +40%",
        },
        "detail": "옵티머스의 핵심 시스템을 업그레이드하여 ㄴ키 홀드 시 게이지 충전 속도가 증가합니다.",
        "icon_color": (255, 220, 50),
        "tree": "optimus",
        "character_restriction": "optimus"
    },
    "mecha_bulk": {
        "name": "메카벌크",
        "max_level": 4,
        "descriptions": {
            1: "패들 +5%",
            2: "패들 +10%",
            3: "패들 +15%",
            4: "패들 +20%",
        },
        "detail": "옵티머스의 프레임을 강화하여 패들 크기가 증가합니다.",
        "icon_color": (180, 100, 255),
        "tree": "optimus",
        "character_restriction": "optimus"
    },
    "emergency_charge": {
        "name": "비상충전",
        "max_level": 3,
        "descriptions": {
            1: "ㄴ더블탭 50%",
            2: "ㄴ더블탭 70%",
            3: "ㄴ더블탭 100%",
        },
        "detail": "위기 상황에서 ㄴ키를 빠르게 두 번 누르면 즉시 게이지를 충전합니다. 스테이지당 1회만 사용 가능합니다.",
        "icon_color": (255, 100, 100),
        "tree": "optimus",
        "character_restriction": "optimus"
    },
    "reboot_enhance": {
        "name": "재부팅강화",
        "max_level": 3,
        "descriptions": {
            1: "스턴 -30%",
            2: "스턴 -60%",
            3: "스턴 -90%",
        },
        "detail": "충전 완료 후 발생하는 시스템 재부팅 시간을 단축합니다.",
        "icon_color": (100, 255, 150),
        "tree": "optimus",
        "character_restriction": "optimus"
    },
    "star_change": {
        "name": "스타체인지",
        "max_level": -1,
        "descriptions": {
            1: "스타포인트 +3",
        },
        "detail": "여분의 에너지를 스타포인트로 변환합니다. 즉시 스타포인트 3개를 획득합니다.",
        "icon_color": (255, 255, 100),
        "tree": "optimus",
        "character_restriction": "optimus"
    },
    "bug_update": {
        "name": "버그업데이트",
        "max_level": 3,
        "descriptions": {
            1: "25% 재선택",
            2: "35% 재선택",
            3: "45% 재선택",
        },
        "detail": "시스템의 예기치 않은 버그로 인해 스킬 선택 후 확률적으로 한 번 더 선택창이 나타납니다.",
        "icon_color": (150, 255, 50),
        "tree": "optimus",
        "character_restriction": "optimus"
    },
    "elec_pad": {
        "name": "일렉패드",
        "max_level": 4,
        "descriptions": {
            1: "5% 게이지+40",
            2: "7% 게이지+50",
            3: "9% 게이지+60",
            4: "11% 게이지+70",
        },
        "detail": "패들에 전기 충격 패드를 장착합니다. 공을 타격할 때마다 확률적으로 게이지가 즉시 충전됩니다.",
        "icon_color": (50, 200, 255),
        "tree": "optimus",
        "character_restriction": "optimus"
    },
    "optimus_arm": {
        "name": "옵티머스암",
        "max_level": 1,
        "descriptions": {
            1: "기계팔 해금",
        },
        "detail": "강력한 기계팔을 장착합니다. 스페셜 게이지가 가득 차면 보스를 직접 잡아 던지는 강력한 기술을 사용할 수 있습니다.",
        "icon_color": (255, 180, 50),
        "tree": "optimus",
        "character_restriction": "optimus"
    },
}

'''

def main():
    filepath = os.path.join(os.path.dirname(__file__), 'pingfighter.py')

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 찾을 패턴
    old_pattern = "# 옵티머스 스킬 풀 정의\nOPTIMUS_SKILL_POOL = ["

    if old_pattern in content:
        # 새 코드 삽입
        new_content = content.replace(
            old_pattern,
            NEW_CODE + "# 레거시 호환: 옵티머스 스킬 풀 정의\nOPTIMUS_SKILL_POOL = ["
        )

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)

        print("SUCCESS: OPTIMUS_EXCLUSIVE_SKILLS 추가 완료!")
    else:
        print("ERROR: 패턴을 찾을 수 없습니다.")
        # 디버깅
        idx = content.find("OPTIMUS_SKILL_POOL")
        if idx != -1:
            print(f"OPTIMUS_SKILL_POOL 위치: {idx}")
            print(f"주변 내용: {repr(content[idx-50:idx+50])}")

if __name__ == "__main__":
    main()