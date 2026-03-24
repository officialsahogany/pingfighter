"""
아이템 → 파츠 매핑 레지스트리.

패시브 아이템 획득 시 이 레지스트리를 통해
해당 아이템에 맞는 BodyPart를 가져와 skin.set_part()로 교체한다.

사용 예:
    from entities.body_parts.item_parts_registry import get_item_part, apply_item_to_skin
    part = get_item_part("spiked_helmet")
    if part:
        skin.set_part(part)

    # 또는 한 줄로:
    apply_item_to_skin(skin, "spiked_helmet")
"""

from entities.player_skeleton import CharacterSkin, BodyPart
from typing import Optional


def get_item_part(item_name: str, block: int = 9,
                   side: str = "left") -> Optional[BodyPart]:
    """아이템 이름에 해당하는 BodyPart 인스턴스를 반환.

    Args:
        item_name: 아이템 코드명.
        block: 렌더링 블록 크기.
        side: 팔 아이템의 좌/우 선택. "left" 또는 "right".

    매핑되지 않은 아이템이면 None 반환.
    """
    if item_name == "spiked_helmet":
        from entities.body_parts.item_head_parts import SpikedHelmetPart
        return SpikedHelmetPart(block)

    elif item_name == "bulletproof_hat":
        from entities.body_parts.item_head_parts import BulletproofHatPart
        return BulletproofHatPart(block)

    elif item_name == "technical_vest":
        from entities.body_parts.item_torso_parts import TechnicalVestPart
        return TechnicalVestPart(block)

    elif item_name == "bulkup":
        from entities.body_parts.item_torso_parts import BulkupSuitPart
        return BulkupSuitPart(block)

    elif item_name == "commando_arm":
        if side == "right":
            from entities.body_parts.item_arm_parts import CommandoArmRightPart
            return CommandoArmRightPart(block)
        from entities.body_parts.item_arm_parts import CommandoArmPart
        return CommandoArmPart(block)

    elif item_name == "gold_digger":
        if side == "right":
            from entities.body_parts.item_arm_parts import GoldDiggerArmRightPart
            return GoldDiggerArmRightPart(block)
        from entities.body_parts.item_arm_parts import GoldDiggerArmPart
        return GoldDiggerArmPart(block)

    elif item_name == "ragnarok_hammer":
        from entities.body_parts.item_weapon_parts import RagnarokHammerPart
        return RagnarokHammerPart(block)

    elif item_name == "poseidon_trident":
        from entities.body_parts.item_weapon_parts import PoseidonTridentPart
        return PoseidonTridentPart(block)

    elif item_name == "transcendent_crown":
        from entities.body_parts.item_head_parts import TranscendentCrownPart
        return TranscendentCrownPart(block)

    elif item_name == "odins_eye":
        from entities.body_parts.item_head_parts import OdinsEyePart
        return OdinsEyePart(block)

    elif item_name == "chargebag":
        from entities.body_parts.item_back_parts import ChargeBagPart
        return ChargeBagPart(block)

    return None


# 양팔 착용 가능한 아이템 목록
DUAL_ARM_ITEMS = {"commando_arm", "gold_digger"}


def apply_item_to_skin(skin: CharacterSkin, item_name: str, block: int = 9) -> bool:
    """아이템에 해당하는 파츠를 스킨에 적용.

    양팔 아이템(commando_arm, gold_digger)은 l_arm이 이미 같은 아이템이면
    자동으로 r_arm에 적용한다.

    Returns:
        True if part was applied, False if item has no visual part.
    """
    if item_name in DUAL_ARM_ITEMS:
        # l_arm에 이미 같은 종류의 아이템이 장착되어 있는지 확인
        existing_l = skin.get_part("l_arm")
        if existing_l and _is_same_item_type(existing_l, item_name):
            # 오른팔에 적용
            part = get_item_part(item_name, block, side="right")
            if part:
                skin.set_part(part)
                return True
        else:
            # 왼팔에 적용
            part = get_item_part(item_name, block, side="left")
            if part:
                skin.set_part(part)
                return True
        return False

    part = get_item_part(item_name, block)
    if part is not None:
        skin.set_part(part)
        return True
    return False


def _is_same_item_type(part: BodyPart, item_name: str) -> bool:
    """파츠가 해당 아이템 타입인지 확인."""
    cls_name = type(part).__name__.lower()
    # CommandoArmPart, CommandoArmRightPart → "commando"
    # GoldDiggerArmPart, GoldDiggerArmRightPart → "golddigger"
    if item_name == "commando_arm":
        return "commando" in cls_name
    elif item_name == "gold_digger":
        return "golddigger" in cls_name
    return False


def remove_item_from_skin(skin: CharacterSkin, item_name: str, block: int = 9) -> bool:
    """아이템 해제 시 기본 파츠로 복원.

    Returns:
        True if slot was restored, False if item has no visual part.
    """
    part = get_item_part(item_name, block)
    if part is None:
        return False

    from entities.body_parts.smasher_head import SmasherHeadPart
    from entities.body_parts.smasher_torso import SmasherTorsoPart
    from entities.body_parts.smasher_arms import SmasherLeftArmPart, SmasherRightArmPart
    from entities.body_parts.smasher_weapon import SmasherWeaponPart

    DEFAULT_PARTS = {
        "head": SmasherHeadPart,
        "face": None,           # 오딘의눈 해제 시 제거만 (기본 face 파츠 없음)
        "torso": SmasherTorsoPart,
        "l_arm": SmasherLeftArmPart,
        "r_arm": SmasherRightArmPart,
        "weapon": SmasherWeaponPart,
        "back": None,
    }

    # 양팔 아이템은 l_arm과 r_arm 둘 다 복원
    if item_name in DUAL_ARM_ITEMS:
        for slot in ("l_arm", "r_arm"):
            existing = skin.get_part(slot)
            if existing and _is_same_item_type(existing, item_name):
                default_cls = DEFAULT_PARTS.get(slot)
                if default_cls:
                    skin.set_part(default_cls(block))
        return True

    slot = part.slot
    default_cls = DEFAULT_PARTS.get(slot)
    if default_cls:
        skin.set_part(default_cls(block))
    else:
        skin.remove_part(slot)
    return True


# ── 지원 아이템 목록 (외부 참조용) ──
VISUAL_ITEM_NAMES = {
    "spiked_helmet",
    "bulletproof_hat",
    "technical_vest",
    "bulkup",
    "commando_arm",
    "gold_digger",
    "ragnarok_hammer",
    "poseidon_trident",
    "transcendent_crown",
    "odins_eye",
    "chargebag",
}

# ── 아이템 → 슬롯 매핑 (UI 표시용) ──
ITEM_SLOT_MAP = {
    "spiked_helmet": "head",
    "bulletproof_hat": "head",
    "technical_vest": "torso",
    "bulkup": "torso",
    "commando_arm": "l_arm",    # 첫 번째는 l_arm, 두 번째는 r_arm
    "gold_digger": "l_arm",     # 첫 번째는 l_arm, 두 번째는 r_arm
    "ragnarok_hammer": "weapon",
    "poseidon_trident": "weapon",
    "transcendent_crown": "head",
    "odins_eye": "face",
    "chargebag": "back",
}
