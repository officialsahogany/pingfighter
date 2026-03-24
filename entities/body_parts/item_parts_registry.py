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


def get_item_part(item_name: str, block: int = 9) -> Optional[BodyPart]:
    """아이템 이름에 해당하는 BodyPart 인스턴스를 반환.

    매핑되지 않은 아이템이면 None 반환.
    매번 새 인스턴스를 생성하므로 캐싱이 필요하면 호출측에서 처리.
    """
    # 지연 임포트 (순환 참조 방지)
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
        from entities.body_parts.item_arm_parts import CommandoArmPart
        return CommandoArmPart(block)

    elif item_name == "gold_digger":
        from entities.body_parts.item_arm_parts import GoldDiggerArmPart
        return GoldDiggerArmPart(block)

    elif item_name == "ragnarok_hammer":
        from entities.body_parts.item_weapon_parts import RagnarokHammerPart
        return RagnarokHammerPart(block)

    elif item_name == "chargebag":
        from entities.body_parts.item_back_parts import ChargeBagPart
        return ChargeBagPart(block)

    return None


def apply_item_to_skin(skin: CharacterSkin, item_name: str, block: int = 9) -> bool:
    """아이템에 해당하는 파츠를 스킨에 적용.

    Returns:
        True if part was applied, False if item has no visual part.
    """
    part = get_item_part(item_name, block)
    if part is not None:
        skin.set_part(part)
        return True
    return False


def remove_item_from_skin(skin: CharacterSkin, item_name: str, block: int = 9) -> bool:
    """아이템 해제 시 기본 파츠로 복원.

    Returns:
        True if slot was restored, False if item has no visual part.
    """
    part = get_item_part(item_name, block)
    if part is None:
        return False

    slot = part.slot

    # 기본 파츠로 복원
    from entities.body_parts.smasher_head import SmasherHeadPart
    from entities.body_parts.smasher_torso import SmasherTorsoPart
    from entities.body_parts.smasher_arms import SmasherLeftArmPart
    from entities.body_parts.smasher_weapon import SmasherWeaponPart

    DEFAULT_PARTS = {
        "head": SmasherHeadPart,
        "torso": SmasherTorsoPart,
        "l_arm": SmasherLeftArmPart,
        "weapon": SmasherWeaponPart,
        "back": None,  # back은 기본이 없음 → 제거
    }

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
    "chargebag",
}

# ── 아이템 → 슬롯 매핑 (UI 표시용) ──
ITEM_SLOT_MAP = {
    "spiked_helmet": "head",
    "bulletproof_hat": "head",
    "technical_vest": "torso",
    "bulkup": "torso",
    "commando_arm": "l_arm",
    "gold_digger": "l_arm",
    "ragnarok_hammer": "weapon",
    "chargebag": "back",
}
