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

    elif item_name == "dowsing_goggles":
        from entities.body_parts.item_head_parts import DowsingGogglesPart
        return DowsingGogglesPart(block)

    elif item_name == "yachaman_soul":
        from entities.body_parts.item_head_parts import YachamanSoulPart
        return YachamanSoulPart(block)

    elif item_name == "technical_vest":
        from entities.body_parts.item_torso_parts import TechnicalVestPart
        return TechnicalVestPart(block)

    elif item_name == "bulkup":
        from entities.body_parts.item_torso_parts import BulkupSuitPart
        return BulkupSuitPart(block)

    elif item_name == "adversity_armor":
        from entities.body_parts.item_torso_parts import AdversityArmorPart
        return AdversityArmorPart(block)

    elif item_name == "shrapnel_armor":
        from entities.body_parts.item_torso_parts import ShrapnelArmorPart
        return ShrapnelArmorPart(block)

    elif item_name == "valhalla_warplate":
        from entities.body_parts.item_torso_parts import ValhallaWarplatePart
        return ValhallaWarplatePart(block)

    elif item_name == "horn_strawberry_mask":
        from entities.body_parts.item_head_parts import HornStrawberryMaskPart
        return HornStrawberryMaskPart(block)

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

    elif item_name == "soul_burst":
        from entities.body_parts.item_leg_parts import SoulBurstKneePart
        return SoulBurstKneePart(block)

    elif item_name == "pandora_legacy":
        from entities.body_parts.item_back_parts import PandoraLegacyPart
        return PandoraLegacyPart(block)

    elif item_name == "venom_mist_gauntlet":
        if side == "right":
            from entities.body_parts.item_arm_parts import VenomMistGauntletRightPart
            return VenomMistGauntletRightPart(block)
        from entities.body_parts.item_arm_parts import VenomMistGauntletPart
        return VenomMistGauntletPart(block)

    elif item_name == "megingjord":
        from entities.body_parts.item_belt_parts import MegingjordBeltPart
        return MegingjordBeltPart(block)

    elif item_name == "sage_ring":
        # 현자의 반지는 장신구 - 시각적 파츠 없음 (아이콘만 표시)
        return None

    return None


# 양팔 착용 가능한 아이템 목록
DUAL_ARM_ITEMS = {"commando_arm", "gold_digger", "venom_mist_gauntlet"}

# 전설 양손 무기 (weapon + shield 슬롯 동시 사용)
LEGENDARY_WEAPON_ITEMS = {"ragnarok_hammer", "poseidon_trident"}


def apply_item_to_skin(skin: CharacterSkin, item_name: str, block: int = 9) -> bool:
    """아이템에 해당하는 파츠를 스킨에 적용.

    팔 아이템(commando_arm, gold_digger)은 l_arm에 이미 다른 팔 아이템이 있으면
    자동으로 r_arm에 적용한다. (같은/다른 아이템 무관)

    전설 무기(ragnarok_hammer, poseidon_trident)는 weapon 슬롯에 다른 전설 무기가
    이미 있으면 shield 슬롯(오른손)에 자동 적용한다.

    Returns:
        True if part was applied, False if item has no visual part.
    """
    if item_name in DUAL_ARM_ITEMS:
        # l_arm에 이미 아이템 파츠가 장착되어 있는지 확인 (같은/다른 아이템 무관)
        existing_l = skin.get_part("l_arm")
        l_arm_has_item = existing_l and _is_any_arm_item(existing_l)

        if l_arm_has_item:
            # 왼팔에 이미 아이템이 있음 → 오른팔에 적용
            part = get_item_part(item_name, block, side="right")
            if part:
                skin.set_part(part)
                return True
        else:
            # 왼팔이 비어있음(기본 파츠) → 왼팔에 적용
            part = get_item_part(item_name, block, side="left")
            if part:
                skin.set_part(part)
                return True
        return False

    if item_name in LEGENDARY_WEAPON_ITEMS:
        # weapon 슬롯에 다른 전설 무기가 이미 있는지 확인
        existing_weapon = skin.get_part("weapon")
        if existing_weapon and _is_legendary_weapon(existing_weapon) and \
                not _is_same_legendary_weapon(existing_weapon, item_name):
            # 다른 전설 무기가 이미 왼손에 있음 → 오른손(shield 슬롯)에 적용
            right_part = _get_legendary_weapon_right(item_name, block)
            if right_part:
                skin.set_part(right_part)
                return True
        # weapon 슬롯이 비어있거나 기본 무기 → 왼손에 적용
        part = get_item_part(item_name, block)
        if part is not None:
            skin.set_part(part)
            return True
        return False

    part = get_item_part(item_name, block)
    if part is not None:
        skin.set_part(part)
        return True
    return False


def _is_legendary_weapon(part: BodyPart) -> bool:
    """파츠가 전설 무기인지 확인."""
    cls_name = type(part).__name__.lower()
    return "ragnarokhammer" in cls_name or "poseidontrident" in cls_name


def _is_same_legendary_weapon(part: BodyPart, item_name: str) -> bool:
    """파츠가 해당 전설 무기 타입인지 확인."""
    cls_name = type(part).__name__.lower()
    if item_name == "ragnarok_hammer":
        return "ragnarokhammer" in cls_name
    elif item_name == "poseidon_trident":
        return "poseidontrident" in cls_name
    return False


def _get_legendary_weapon_right(item_name: str, block: int = 9) -> Optional[BodyPart]:
    """전설 무기의 오른손(shield 슬롯) 버전을 반환."""
    if item_name == "ragnarok_hammer":
        from entities.body_parts.item_weapon_parts import RagnarokHammerRightPart
        return RagnarokHammerRightPart(block)
    elif item_name == "poseidon_trident":
        from entities.body_parts.item_weapon_parts import PoseidonTridentRightPart
        return PoseidonTridentRightPart(block)
    return None


def _is_any_arm_item(part: BodyPart) -> bool:
    """파츠가 기본 팔이 아닌 아이템 팔 파츠인지 확인."""
    cls_name = type(part).__name__.lower()
    # 기본 팔: SmasherLeftArmPart, SmasherRightArmPart
    if "smasher" in cls_name:
        return False
    # 아이템 팔: CommandoArmPart, GoldDiggerArmPart 등
    return True


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
    from entities.body_parts.smasher_shield import SmasherShieldPart

    DEFAULT_PARTS = {
        "head": SmasherHeadPart,
        "face": None,           # 오딘의눈 해제 시 제거만 (기본 face 파츠 없음)
        "torso": SmasherTorsoPart,
        "l_arm": SmasherLeftArmPart,
        "r_arm": SmasherRightArmPart,
        "weapon": SmasherWeaponPart,
        "shield": SmasherShieldPart,
        "back": None,
    }

    # 팔 아이템은 l_arm, r_arm 양쪽에서 해당 아이템 타입만 복원
    if item_name in DUAL_ARM_ITEMS:
        for slot in ("l_arm", "r_arm"):
            existing = skin.get_part(slot)
            if existing and _is_same_item_type(existing, item_name):
                default_cls = DEFAULT_PARTS.get(slot)
                if default_cls:
                    skin.set_part(default_cls(block))
        return True

    # 전설 무기는 weapon + shield 양쪽 슬롯 모두 복원
    if item_name in LEGENDARY_WEAPON_ITEMS:
        for slot in ("weapon", "shield"):
            existing = skin.get_part(slot)
            if existing and _is_same_legendary_weapon(existing, item_name):
                default_cls = DEFAULT_PARTS.get(slot)
                if default_cls:
                    skin.set_part(default_cls(block))
                else:
                    skin.remove_part(slot)
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
    "dowsing_goggles",
    "technical_vest",
    "bulkup",
    "adversity_armor",
    "shrapnel_armor",
    "commando_arm",
    "gold_digger",
    "ragnarok_hammer",
    "poseidon_trident",
    "transcendent_crown",
    "odins_eye",
    "megingjord",
    "chargebag",
    "soul_burst",
}

# ── 아이템 → 슬롯 매핑 (UI 표시용) ──
ITEM_SLOT_MAP = {
    "spiked_helmet": "head",
    "bulletproof_hat": "head",
    "dowsing_goggles": "head",
    "technical_vest": "torso",
    "bulkup": "torso",
    "adversity_armor": "torso",
    "shrapnel_armor": "torso",
    "commando_arm": "l_arm",    # 첫 번째는 l_arm, 두 번째는 r_arm
    "gold_digger": "l_arm",     # 첫 번째는 l_arm, 두 번째는 r_arm
    "venom_mist_gauntlet": "l_arm",  # 독안개장갑: 첫 번째 l_arm, 두 번째 r_arm
    "ragnarok_hammer": "weapon",
    "poseidon_trident": "weapon",
    "transcendent_crown": "head",
    "odins_eye": "face",
    "megingjord": "torso",
    "valhalla_warplate": "torso",
    "horn_strawberry_mask": "head",
    "chargebag": "back",
    "soul_burst": "legs",
}
