#!/usr/bin/env python3
"""Static coverage checks for PingFighter item and skill registries.

This tool is intentionally text-based. Importing pingfighter.py has a large
runtime cost and side effects, so the checks below scan the known hardcoded
registry surfaces directly.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


PROJECT_ROOT = Path(__file__).resolve().parents[1]

ARENA_ONLY_ITEM_NAMES = {
    "hero_seal",
    "minor_hero_seal",
    "intermediate_hero_seal",
}

LEGACY_GACHA_PASSIVE_NAMES = {
    "berserker_fist",
    "phantom_cloak",
}

PLACEHOLDER_LEGENDARY_NAMES = {
    "empty",
    "empty1",
    "empty2",
    "empty_legendary",
    "empty_legendary2",
    "empty_legendary3",
    "empty_legendary4",
    "empty_legendary5",
    "empty_legendary6",
}

PANDORA_SELF_EXCLUDED_MYTHICS = {
    "pandora_legacy",
}

BLACKSMITH_BESPOKE_ICON_FAMILY = "blacksmith_bespoke"
ICON_SCHEMA_REGISTRY_NAMES = (
    "BLACKSMITH_SKILL_ICON_REGISTRY",
    "_OPTIMUS_SKILL_ICON_REGISTRY",
    "_SMASHER_ORB_ICON_REGISTRY",
    "_SOLDIER_ORB_ICON_REGISTRY",
    "_VIPER_ORB_ICON_REGISTRY",
)
REQUIRED_ICON_SCHEMA_STRING_FIELDS = ("slot_occupancy", "cleanup_policy")
REQUIRED_ICON_SCHEMA_BOOL_FIELDS = ("cooldown_reduction_eligible",)
VALID_SLOT_OCCUPANCY = {
    "active_orb",
    "base_fixed",
    "passive_orb",
    "shared_slot",
}
VALID_CLEANUP_POLICY = {
    "base_only",
    "perk_id_lookup",
    "shared_swap",
}
SOLDIER_INSTANCE_COOLDOWN_REQUIREMENTS = {
    "bazooka": {
        "module": "item_effects/bazooka.py",
        "attr": "COOLDOWN_TIME",
        "gate": "can_fire",
    },
    "ak47": {
        "module": "item_effects/ak47.py",
        "attr": "fire_interval",
        "gate": "can_fire",
    },
    "net_gun": {
        "module": "item_effects/net_gun.py",
        "attr": "COOLDOWN_FRAMES",
        "gate": "can_fire",
    },
    "bowling_trap": {
        "module": "item_effects/bowling_trap.py",
        "attr": "COOLDOWN_FRAMES",
        "gate": "can_install",
    },
}
ACADEMY_SWAP_PRECHECKED_CALLS = {
    "swap_smasher_skill": "_smasher_equipped_skills",
    "swap_viper_skill": "_viper_equipped_skills",
}


@dataclass(frozen=True)
class SourceBlock:
    name: str
    text: str
    line: int


@dataclass(frozen=True)
class CoverageIssue:
    severity: str
    code: str
    message: str
    names: tuple[str, ...] = ()
    detail: str = ""


@dataclass
class CoverageReport:
    counts: dict[str, int] = field(default_factory=dict)
    issues: list[CoverageIssue] = field(default_factory=list)

    @property
    def errors(self) -> list[CoverageIssue]:
        return [issue for issue in self.issues if issue.severity == "ERROR"]

    @property
    def warnings(self) -> list[CoverageIssue]:
        return [issue for issue in self.issues if issue.severity == "WARN"]

    @property
    def infos(self) -> list[CoverageIssue]:
        return [issue for issue in self.issues if issue.severity == "INFO"]

    def add(
        self,
        severity: str,
        code: str,
        message: str,
        names: Iterable[str] = (),
        detail: str = "",
    ) -> None:
        self.issues.append(
            CoverageIssue(
                severity=severity,
                code=code,
                message=message,
                names=tuple(sorted(set(names))),
                detail=detail,
            )
        )


def _read_sources(root: Path) -> dict[str, str]:
    files = {
        "items.py": root / "items.py",
        "pingfighter.py": root / "pingfighter.py",
        "gacha.py": root / "gacha.py",
        "legendary_items.py": root / "legendary_items.py",
    }
    for requirement in SOLDIER_INSTANCE_COOLDOWN_REQUIREMENTS.values():
        module_name = requirement["module"]
        files[module_name] = root / module_name
    return {name: path.read_text(encoding="utf-8") for name, path in files.items()}


def _line_for(source: str, index: int) -> int:
    return source.count("\n", 0, index) + 1


def _scan_balanced(source: str, open_index: int) -> str:
    pairs = {"{": "}", "[": "]", "(": ")"}
    opener = source[open_index]
    if opener not in pairs:
        raise ValueError(f"Unsupported opener at {open_index}: {opener!r}")

    stack: list[str] = []
    quote: str | None = None
    triple = False
    escaped = False
    i = open_index

    while i < len(source):
        ch = source[i]

        if quote is not None:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif triple and source.startswith(quote * 3, i):
                quote = None
                triple = False
                i += 2
            elif not triple and ch == quote:
                quote = None
            i += 1
            continue

        if source.startswith('"""', i) or source.startswith("'''", i):
            quote = source[i]
            triple = True
            i += 3
            continue
        if ch in ("'", '"'):
            quote = ch
            triple = False
            i += 1
            continue
        if ch in pairs:
            stack.append(pairs[ch])
        elif stack and ch == stack[-1]:
            stack.pop()
            if not stack:
                return source[open_index : i + 1]
        i += 1

    raise ValueError(f"Unclosed balanced block starting at {open_index}")


def _find_assignment_blocks(source: str, name: str) -> list[SourceBlock]:
    pattern = re.compile(rf"\b{re.escape(name)}\s*=\s*([\[{{(])")
    blocks: list[SourceBlock] = []
    for match in pattern.finditer(source):
        open_index = match.start(1)
        blocks.append(
            SourceBlock(
                name=name,
                text=_scan_balanced(source, open_index),
                line=_line_for(source, match.start()),
            )
        )
    return blocks


def _first_assignment_block(source: str, name: str) -> SourceBlock:
    blocks = _find_assignment_blocks(source, name)
    if not blocks:
        raise ValueError(f"Could not find assignment for {name}")
    return blocks[0]


def _function_block(source: str, name: str) -> SourceBlock:
    lines = source.splitlines(True)
    start = None
    for index, line in enumerate(lines):
        if line.startswith(f"def {name}("):
            start = index
            break
    if start is None:
        raise ValueError(f"Could not find function {name}")

    end = len(lines)
    for index in range(start + 1, len(lines)):
        if lines[index].startswith("def ") or lines[index].startswith("class "):
            end = index
            break
    return SourceBlock(name=name, text="".join(lines[start:end]), line=start + 1)


def _function_name_for_line(source: str, line_number: int) -> str:
    current = ""
    for index, line in enumerate(source.splitlines(), start=1):
        match = re.match(r"^(?:def|class)\s+([A-Za-z_][A-Za-z0-9_]*)\b", line)
        if match:
            current = match.group(1)
        if index >= line_number:
            return current
    return current


def _function_call_blocks(source: str, name: str) -> list[SourceBlock]:
    blocks: list[SourceBlock] = []
    pattern = re.compile(rf"\b{re.escape(name)}\s*\(")
    for match in pattern.finditer(source):
        open_index = source.find("(", match.start())
        if open_index < 0:
            continue
        blocks.append(
            SourceBlock(
                name=name,
                text=_scan_balanced(source, open_index),
                line=_line_for(source, match.start()),
            )
        )
    return blocks


def _keyword_value_is(text: str, keyword: str, value: str) -> bool:
    return bool(
        re.search(
            rf"\b{re.escape(keyword)}\s*=\s*{re.escape(value)}\b",
            text,
        )
    )


def _quoted_names(text: str) -> set[str]:
    return set(re.findall(r'"([a-z0-9_]+)"', text))


def _item_names_from_objects(text: str) -> set[str]:
    return set(re.findall(r'"name"\s*:\s*"([a-z0-9_]+)"', text))


def _item_names_by_type(text: str, item_type: str) -> set[str]:
    pattern = re.compile(
        r'\{\s*"name"\s*:\s*"([a-z0-9_]+)"\s*,\s*"type"\s*:\s*"'
        + re.escape(item_type)
        + r'"',
        re.DOTALL,
    )
    return set(pattern.findall(text))


def _top_level_dict_keys(text: str) -> set[str]:
    return set(re.findall(r'^    "([a-z0-9_]+)"\s*:', text, re.MULTILINE))


def _top_level_dict_entry_blocks(text: str) -> dict[str, str]:
    entries: dict[str, str] = {}
    pattern = re.compile(r'^    "([a-z0-9_]+)"\s*:\s*(\{)', re.MULTILINE)
    for match in pattern.finditer(text):
        entries[match.group(1)] = _scan_balanced(text, match.start(2))
    return entries


def _top_level_string_map(text: str) -> dict[str, str]:
    return dict(
        re.findall(
            r'^    "([a-z0-9_]+)"\s*:\s*"([a-z0-9_]+)"',
            text,
            re.MULTILINE,
        )
    )


def _dict_entries_with_string_field(
    text: str,
    field_name: str,
    field_value: str,
) -> set[str]:
    return {
        name
        for name, value in _dict_entry_string_field_map(text, field_name).items()
        if value == field_value
    }


def _dict_entry_string_field_map(text: str, field_name: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for name, entry_block in _top_level_dict_entry_blocks(text).items():
        match = re.search(rf'"{re.escape(field_name)}"\s*:\s*"([a-z0-9_]+)"', entry_block)
        if match:
            values[name] = match.group(1)
    return values


def _dict_entry_bool_field_map(text: str, field_name: str) -> dict[str, bool]:
    values: dict[str, bool] = {}
    for name, entry_block in _top_level_dict_entry_blocks(text).items():
        match = re.search(rf'"{re.escape(field_name)}"\s*:\s*(True|False)\b', entry_block)
        if match:
            values[name] = match.group(1) == "True"
    return values


def _nested_dict_keys(text: str) -> set[str]:
    return set(re.findall(r'^\s{8}"([a-z0-9_]+)"\s*:', text, re.MULTILINE))


def _nested_string_map(text: str, parent_key: str) -> dict[str, str]:
    match = re.search(rf'"{re.escape(parent_key)}"\s*:\s*(\{{)', text)
    if not match:
        return {}
    block = _scan_balanced(text, match.start(1))
    return dict(re.findall(r'"([a-z0-9_]+)"\s*:\s*"([a-z0-9_]+)"', block))


def _id_fields(text: str) -> set[str]:
    return set(re.findall(r'"id"\s*:\s*"([a-z0-9_]+)"', text))


def _name_fields(text: str) -> set[str]:
    return set(re.findall(r'"name"\s*:\s*"([a-z0-9_]+)"', text))


def _string_assignment_value(source: str, name: str) -> str | None:
    match = re.search(rf"^{re.escape(name)}\s*=\s*\"([a-z0-9_]+)\"", source, re.MULTILINE)
    if not match:
        return None
    return match.group(1)


def _literal_matches(variable_name: str, text: str) -> set[str]:
    names = set(
        re.findall(
            rf"\b{re.escape(variable_name)}\s*==\s*\"([a-z0-9_]+)\"",
            text,
        )
    )
    for pattern in (
        rf"\b{re.escape(variable_name)}\s+in\s+\(([^)]*)\)",
        rf"\b{re.escape(variable_name)}\s+in\s+\[([^\]]*)\]",
        rf"\b{re.escape(variable_name)}\s+in\s+\{{([^}}]*)\}}",
    ):
        for block in re.findall(pattern, text, re.DOTALL):
            names.update(_quoted_names(block))
    return names


def _passive_filter_names_from_store_active(pingfighter_src: str) -> set[str]:
    block = _function_block(pingfighter_src, "store_active_item").text
    names: set[str] = set()
    for match in re.findall(
        r'item_data\["name"\]\s+in\s+\[([^\]]*)\]',
        block,
        re.DOTALL,
    ):
        names.update(_quoted_names(match))
    return names


def _registered_legendary_names(legendary_src: str) -> set[str]:
    names = set(re.findall(r'self\.items\["([a-z0-9_]+)"\]\s*=', legendary_src))
    return names - PLACEHOLDER_LEGENDARY_NAMES


def _collect_item_context(sources: dict[str, str]) -> dict[str, object]:
    items_src = sources["items.py"]
    pingfighter_src = sources["pingfighter.py"]
    gacha_src = sources["gacha.py"]
    legendary_src = sources["legendary_items.py"]

    item_types = _item_names_from_objects(
        _first_assignment_block(items_src, "ITEM_TYPES").text
    )
    passive_drop_names = _quoted_names(
        _first_assignment_block(items_src, "PASSIVE_DROP_ITEM_NAMES").text
    )
    legendary_passive_names = _quoted_names(
        _first_assignment_block(items_src, "LEGENDARY_PASSIVE_ITEM_NAMES").text
    )
    passive_inventory_names = passive_drop_names | legendary_passive_names
    mythic_blocks = _find_assignment_blocks(items_src, "mythic_names")
    if mythic_blocks:
        spawn_mythic_names = _quoted_names(mythic_blocks[0].text)
    else:
        spawn_mythic_names = _quoted_names(
            _first_assignment_block(items_src, "_MYTHICAL_ICON_NAMES").text
        )
    primary_all_items = max(
        _find_assignment_blocks(pingfighter_src, "all_items"),
        key=lambda block: len(_item_names_from_objects(block.text)),
    )
    online_client_block = _function_block(pingfighter_src, "_online_client_apply_state")
    online_uses_passive_helper = (
        "items.is_passive_inventory_item(_cp_name)" in online_client_block.text
    )
    if online_uses_passive_helper:
        capture_passive_names = passive_inventory_names
    else:
        capture_passive_names = _quoted_names(
            _first_assignment_block(pingfighter_src, "_passive_names").text
        )

    registered_legendary_names = _registered_legendary_names(legendary_src)
    regular_legendary_names = registered_legendary_names & item_types

    return {
        "item_types": item_types,
        "unlocked_items": _quoted_names(
            _first_assignment_block(items_src, "unlocked_items").text
        ),
        "obtained_flags": set(
            re.findall(r"^([a-z0-9_]+)_obtained\s*=", items_src, re.MULTILINE)
        ),
        "passive_duplicate_allowed": _quoted_names(
            _first_assignment_block(items_src, "PASSIVE_DUPLICATE_ALLOWED").text
        ),
        "spawn_passive_names": passive_drop_names,
        "legendary_passive_names": legendary_passive_names,
        "passive_inventory_names": passive_inventory_names,
        "spawn_mythic_names": spawn_mythic_names,
        "store_active_passive_filter": _passive_filter_names_from_store_active(
            pingfighter_src
        ),
        "passive_slot_order": _quoted_names(
            _first_assignment_block(pingfighter_src, "PASSIVE_SLOT_ORDER").text
        ),
        "capture_passive_names": capture_passive_names,
        "online_uses_passive_helper": online_uses_passive_helper,
        "primary_all_items": _item_names_from_objects(primary_all_items.text),
        "primary_all_items_line": primary_all_items.line,
        "primary_passive_items": _item_names_by_type(primary_all_items.text, "passive"),
        "all_item_blocks": _find_assignment_blocks(pingfighter_src, "all_items"),
        "gacha_passive_names": _quoted_names(
            _first_assignment_block(gacha_src, "PASSIVE_ITEM_NAMES").text
        ),
        "gacha_legendary_blocks": [
            block
            for name in ("legendary_pool", "legendary_names")
            for block in _find_assignment_blocks(gacha_src, name)
        ],
        "registered_legendary_names": registered_legendary_names,
        "regular_legendary_names": regular_legendary_names,
        "legacy_registered_legendary_names": registered_legendary_names - item_types,
        "pandora_passive_names": _quoted_names(
            _first_assignment_block(legendary_src, "PANDORA_PASSIVE_ITEM_NAMES").text
        ),
        "pandora_mythic_names": _quoted_names(
            _first_assignment_block(legendary_src, "PANDORA_MYTHIC_ITEM_NAMES").text
        ),
    }


def _collect_skill_context(sources: dict[str, str]) -> dict[str, object]:
    pingfighter_src = sources["pingfighter.py"]

    runtime_pool_names = [
        "RUNTIME_SKILL_POOL",
        "SMASHER_EXCLUSIVE_SKILLS",
        "VIPER_EXCLUSIVE_SKILLS",
        "OPTIMUS_EXCLUSIVE_SKILLS",
        "INSTANT_RUNTIME_SKILLS",
    ]
    runtime_ids: set[str] = set()
    for pool_name in runtime_pool_names:
        runtime_ids.update(
            _top_level_dict_keys(_first_assignment_block(pingfighter_src, pool_name).text)
        )
    runtime_ids.update(
        _id_fields(_first_assignment_block(pingfighter_src, "OPTIMUS_SKILL_POOL").text)
    )
    soldier_unlock_blocks = _find_assignment_blocks(
        pingfighter_src,
        "SOLDIER_UNLOCK_PERK_TO_SKILL",
    )
    if soldier_unlock_blocks:
        runtime_ids.update(_top_level_dict_keys(soldier_unlock_blocks[0].text))
    runtime_ids.add("soldier_pistol_perk")

    smasher_active = _name_fields(
        _first_assignment_block(pingfighter_src, "SMASHER_SKILL_ICONS_DATA").text
    )
    viper_active = _name_fields(
        _first_assignment_block(pingfighter_src, "VIPER_SKILL_ICONS_DATA").text
    )
    soldier_active = _name_fields(
        _first_assignment_block(pingfighter_src, "SOLDIER_SKILL_ICONS_DATA").text
    )
    soldier_pistol_orb_skill = _string_assignment_value(
        pingfighter_src,
        "SOLDIER_PISTOL_ORB_SKILL",
    )
    if soldier_pistol_orb_skill:
        soldier_active.add(soldier_pistol_orb_skill)
    blacksmith_active = _name_fields(
        _first_assignment_block(pingfighter_src, "BLACKSMITH_SKILL_ICONS_DATA").text
    )
    soldier_base_skills = _quoted_names(
        _first_assignment_block(pingfighter_src, "SOLDIER_BASE_SKILLS").text
    )
    soldier_shared_slot_skills = _quoted_names(
        _first_assignment_block(pingfighter_src, "SOLDIER_PERMANENT_FIREARM_SKILLS").text
    )
    blacksmith_icon_registry_block = _first_assignment_block(
        pingfighter_src,
        "BLACKSMITH_SKILL_ICON_REGISTRY",
    )
    blacksmith_icon_registry_ids = _top_level_dict_keys(blacksmith_icon_registry_block.text)
    blacksmith_bespoke_registry_ids = _dict_entries_with_string_field(
        blacksmith_icon_registry_block.text,
        "family",
        BLACKSMITH_BESPOKE_ICON_FAMILY,
    )
    optimus_ids = _top_level_dict_keys(
        _first_assignment_block(pingfighter_src, "OPTIMUS_EXCLUSIVE_SKILLS").text
    )

    shared_symbol = _literal_matches(
        "skill_name", _function_block(pingfighter_src, "_draw_skill_icon_symbol").text
    )
    smasher_orb_registry_block = _first_assignment_block(
        pingfighter_src,
        "_SMASHER_ORB_ICON_REGISTRY",
    )
    viper_orb_registry_block = _first_assignment_block(
        pingfighter_src,
        "_VIPER_ORB_ICON_REGISTRY",
    )
    soldier_orb_registry_block = _first_assignment_block(
        pingfighter_src,
        "_SOLDIER_ORB_ICON_REGISTRY",
    )
    smasher_orb_registry_ids = _top_level_dict_keys(smasher_orb_registry_block.text)
    viper_orb_registry_ids = _top_level_dict_keys(viper_orb_registry_block.text)
    soldier_orb_registry_ids = _top_level_dict_keys(soldier_orb_registry_block.text)
    shared_symbol.update(smasher_orb_registry_ids)
    shared_symbol.update(viper_orb_registry_ids)
    soldier_symbol = _literal_matches(
        "skill_name",
        _function_block(pingfighter_src, "_draw_soldier_skill_icon_symbol").text,
    )
    soldier_symbol.update(soldier_orb_registry_ids)
    mini_ids = _literal_matches(
        "skill_id", _function_block(pingfighter_src, "draw_skill_icon_mini").text
    )
    mini_registry_ids = _top_level_dict_keys(
        _first_assignment_block(pingfighter_src, "_MINI_SKILL_ICON_REGISTRY").text
    )
    mini_ids.update(mini_registry_ids)
    optimus_icon_ids = _literal_matches(
        "skill_id", _function_block(pingfighter_src, "draw_optimus_skill_icon").text
    )
    optimus_icon_registry_block = _first_assignment_block(
        pingfighter_src,
        "_OPTIMUS_SKILL_ICON_REGISTRY",
    )
    optimus_icon_registry_ids = _top_level_dict_keys(optimus_icon_registry_block.text)
    icon_schema_registry_blocks = {
        "BLACKSMITH_SKILL_ICON_REGISTRY": blacksmith_icon_registry_block.text,
        "_OPTIMUS_SKILL_ICON_REGISTRY": optimus_icon_registry_block.text,
        "_SMASHER_ORB_ICON_REGISTRY": smasher_orb_registry_block.text,
        "_SOLDIER_ORB_ICON_REGISTRY": soldier_orb_registry_block.text,
        "_VIPER_ORB_ICON_REGISTRY": viper_orb_registry_block.text,
    }
    icon_schema_registry_ids = {
        registry_name: _top_level_dict_keys(block)
        for registry_name, block in icon_schema_registry_blocks.items()
    }
    icon_schema_string_fields = {
        field_name: {
            registry_name: _dict_entry_string_field_map(block, field_name)
            for registry_name, block in icon_schema_registry_blocks.items()
        }
        for field_name in REQUIRED_ICON_SCHEMA_STRING_FIELDS
    }
    icon_schema_bool_fields = {
        field_name: {
            registry_name: _dict_entry_bool_field_map(block, field_name)
            for registry_name, block in icon_schema_registry_blocks.items()
        }
        for field_name in REQUIRED_ICON_SCHEMA_BOOL_FIELDS
    }
    character_unlock_keys = _nested_dict_keys(
        _first_assignment_block(pingfighter_src, "_CHARACTER_UNLOCK_PERKS").text
    )
    smasher_unlock_map = _nested_string_map(
        _first_assignment_block(pingfighter_src, "_CHARACTER_UNLOCK_PERKS").text,
        "smasher",
    )
    viper_unlock_map = _nested_string_map(
        _first_assignment_block(pingfighter_src, "_CHARACTER_UNLOCK_PERKS").text,
        "viper",
    )
    soldier_unlock_map = (
        _top_level_string_map(soldier_unlock_blocks[0].text)
        if soldier_unlock_blocks
        else {}
    )
    soldier_unlock_map.update(_nested_string_map(
        _first_assignment_block(pingfighter_src, "_CHARACTER_UNLOCK_PERKS").text,
        "soldier",
    ))

    return {
        "runtime_ids": runtime_ids,
        "mini_ids": mini_ids,
        "smasher_viper_active_ids": smasher_active | viper_active,
        "soldier_active_ids": soldier_active,
        "blacksmith_active_ids": blacksmith_active,
        "blacksmith_icon_registry_ids": blacksmith_icon_registry_ids,
        "blacksmith_bespoke_registry_ids": blacksmith_bespoke_registry_ids,
        "shared_symbol_ids": shared_symbol,
        "soldier_symbol_ids": soldier_symbol,
        "mini_registry_ids": mini_registry_ids,
        "smasher_orb_registry_ids": smasher_orb_registry_ids,
        "viper_orb_registry_ids": viper_orb_registry_ids,
        "soldier_orb_registry_ids": soldier_orb_registry_ids,
        "smasher_unlock_map": smasher_unlock_map,
        "viper_unlock_map": viper_unlock_map,
        "soldier_unlock_map": soldier_unlock_map,
        "optimus_ids": optimus_ids,
        "optimus_icon_ids": optimus_icon_ids,
        "optimus_icon_registry_ids": optimus_icon_registry_ids,
        "character_unlock_keys": character_unlock_keys,
        "icon_schema_registry_ids": icon_schema_registry_ids,
        "icon_schema_string_fields": icon_schema_string_fields,
        "icon_schema_bool_fields": icon_schema_bool_fields,
        "soldier_base_skills": soldier_base_skills,
        "soldier_shared_slot_skills": soldier_shared_slot_skills,
        "soldier_pistol_orb_skill": soldier_pistol_orb_skill,
    }


def _check_items(report: CoverageReport, context: dict[str, object]) -> None:
    item_types = context["item_types"]
    unlocked_items = context["unlocked_items"]
    primary_all_items = context["primary_all_items"]
    regular_legendary_names = context["regular_legendary_names"]
    expected_primary_dev_items = (
        item_types - regular_legendary_names - ARENA_ONLY_ITEM_NAMES
    )

    report.counts["items.ITEM_TYPES"] = len(item_types)
    report.counts["items.PASSIVE_DROP_ITEM_NAMES"] = len(
        context["spawn_passive_names"]
    )
    report.counts["items.PASSIVE_INVENTORY_ITEM_NAMES"] = len(
        context["passive_inventory_names"]
    )
    report.counts["legendary.manager_regular"] = len(regular_legendary_names)
    report.counts["legendary.manager_registered"] = len(
        context["registered_legendary_names"]
    )
    report.counts["pingfighter.primary_all_items"] = len(primary_all_items)

    missing_unlocked = item_types - unlocked_items
    if missing_unlocked:
        report.add(
            "ERROR",
            "ITEM_UNLOCKED_MISSING",
            "ITEM_TYPES names missing from items.py unlocked_items",
            missing_unlocked,
        )

    legacy_registered = context["legacy_registered_legendary_names"]
    if legacy_registered:
        report.add(
            "INFO",
            "LEGENDARY_MANAGER_LEGACY_ONLY",
            "LegendaryItemManager registers names that are not in ITEM_TYPES",
            legacy_registered,
        )

    if not context["online_uses_passive_helper"]:
        report.add(
            "WARN",
            "ONLINE_PASSIVE_HELPER_NOT_USED",
            "Online client pickup path is not using items.is_passive_inventory_item",
        )

    legendary_passive_mismatch = context["legendary_passive_names"] ^ regular_legendary_names
    if legendary_passive_mismatch:
        report.add(
            "ERROR",
            "LEGENDARY_PASSIVE_NAMES_MISMATCH",
            "items.py LEGENDARY_PASSIVE_ITEM_NAMES differs from current ITEM_TYPES-backed legendaries",
            legendary_passive_mismatch,
        )

    missing_primary = expected_primary_dev_items - primary_all_items
    if missing_primary:
        report.add(
            "ERROR",
            "PRIMARY_DEV_ITEMS_MISSING",
            "Primary pingfighter.py all_items block is missing non-legendary items",
            missing_primary,
            detail=f"primary all_items starts at line {context['primary_all_items_line']}",
        )

    for block in context["all_item_blocks"]:
        block_names = _item_names_from_objects(block.text)
        if block_names == primary_all_items:
            continue
        missing = expected_primary_dev_items - block_names
        if missing:
            report.add(
                "WARN",
                "SECONDARY_DEV_ITEMS_PARTIAL",
                "A secondary all_items block does not mirror the primary dev list",
                missing,
                detail=f"pingfighter.py line {block.line}",
            )

    primary_passive_items = context["primary_passive_items"]
    passive_slot_order = context["passive_slot_order"]
    missing_passive_slot = primary_passive_items - passive_slot_order
    if missing_passive_slot:
        report.add(
            "ERROR",
            "PASSIVE_SLOT_ORDER_MISSING",
            "PASSIVE_SLOT_ORDER is missing primary passive dev items",
            missing_passive_slot,
        )

    store_filter = context["store_active_passive_filter"]
    spawn_passive_names = context["spawn_passive_names"]
    spawn_mythic_names = context["spawn_mythic_names"]
    missing_store_filter = spawn_passive_names - store_filter
    if missing_store_filter:
        report.add(
            "ERROR",
            "STORE_ACTIVE_PASSIVE_FILTER_MISSING",
            "store_active_item passive filter is missing items.py passive_names",
            missing_store_filter,
        )

    missing_spawn_group = (
        store_filter - context["passive_inventory_names"] - spawn_mythic_names
    )
    if missing_spawn_group:
        report.add(
            "ERROR",
            "SPAWN_GROUP_MISSING",
            "items.py passive/mythic groups miss store_active_item passive filter names",
            missing_spawn_group,
        )

    gacha_passive_names = context["gacha_passive_names"]
    gacha_extra = gacha_passive_names - item_types - LEGACY_GACHA_PASSIVE_NAMES
    if gacha_extra:
        report.add(
            "WARN",
            "GACHA_PASSIVE_UNKNOWN",
            "gacha.py PASSIVE_ITEM_NAMES contains names that are not in ITEM_TYPES",
            gacha_extra,
        )

    gacha_missing = (
        store_filter
        - gacha_passive_names
        - regular_legendary_names
        - ARENA_ONLY_ITEM_NAMES
    )
    if gacha_missing:
        report.add(
            "ERROR",
            "GACHA_PASSIVE_MISSING",
            "gacha.py PASSIVE_ITEM_NAMES misses passive filter names",
            gacha_missing,
        )

    capture_missing = context["store_active_passive_filter"] - context[
        "capture_passive_names"
    ]
    if capture_missing:
        report.add(
            "WARN",
            "CAPTURE_PASSIVE_NAMES_MISSING",
            "pingfighter.py _passive_names does not mirror store_active_item passive names",
            capture_missing,
        )

    for block in context["gacha_legendary_blocks"]:
        names = _quoted_names(block.text)
        if names != regular_legendary_names:
            report.add(
                "ERROR",
                "GACHA_LEGENDARY_SET_MISMATCH",
                "gacha.py legendary set differs from LegendaryItemManager regular names",
                (names ^ regular_legendary_names),
                detail=f"gacha.py line {block.line}",
            )

    pandora_passive_missing = regular_legendary_names - context["pandora_passive_names"]
    if pandora_passive_missing:
        report.add(
            "ERROR",
            "PANDORA_PASSIVE_NAMES_MISSING",
            "PANDORA_PASSIVE_ITEM_NAMES is missing regular legendary names",
            pandora_passive_missing,
        )

    pandora_mythic_missing = (
        regular_legendary_names
        - context["pandora_mythic_names"]
        - PANDORA_SELF_EXCLUDED_MYTHICS
    )
    if pandora_mythic_missing:
        report.add(
            "WARN",
            "PANDORA_MYTHIC_NAMES_MISSING",
            "PANDORA_MYTHIC_ITEM_NAMES omits regular legendary names",
            pandora_mythic_missing,
        )


def _schema_names(registry_name: str, names: Iterable[str]) -> list[str]:
    return [f"{registry_name}.{name}" for name in names]


def _check_icon_schema(report: CoverageReport, context: dict[str, object]) -> None:
    registry_ids = context["icon_schema_registry_ids"]
    string_fields = context["icon_schema_string_fields"]
    bool_fields = context["icon_schema_bool_fields"]

    total_registry_ids = sum(len(ids) for ids in registry_ids.values())
    report.counts["skills.icon_schema_registry_ids"] = total_registry_ids
    report.counts["skills.icon_schema_slot_occupancy_fields"] = sum(
        len(field_map) for field_map in string_fields["slot_occupancy"].values()
    )
    report.counts["skills.icon_schema_cleanup_policy_fields"] = sum(
        len(field_map) for field_map in string_fields["cleanup_policy"].values()
    )
    report.counts["skills.icon_schema_cooldown_reduction_fields"] = sum(
        len(field_map)
        for field_map in bool_fields["cooldown_reduction_eligible"].values()
    )

    for registry_name, ids in registry_ids.items():
        for field_name in REQUIRED_ICON_SCHEMA_STRING_FIELDS:
            field_map = string_fields[field_name][registry_name]
            missing = ids - set(field_map)
            if missing:
                report.add(
                    "ERROR",
                    "ICON_SCHEMA_FIELD_MISSING",
                    f"{registry_name} entries missing {field_name}",
                    _schema_names(registry_name, missing),
                )
        for field_name in REQUIRED_ICON_SCHEMA_BOOL_FIELDS:
            field_map = bool_fields[field_name][registry_name]
            missing = ids - set(field_map)
            if missing:
                report.add(
                    "ERROR",
                    "ICON_SCHEMA_FIELD_MISSING",
                    f"{registry_name} entries missing {field_name}",
                    _schema_names(registry_name, missing),
                )

    slot_occupancy_maps = string_fields["slot_occupancy"]
    cleanup_policy_maps = string_fields["cleanup_policy"]
    for registry_name, field_map in slot_occupancy_maps.items():
        invalid = {
            name
            for name, value in field_map.items()
            if value not in VALID_SLOT_OCCUPANCY
        }
        if invalid:
            report.add(
                "ERROR",
                "ICON_SCHEMA_SLOT_OCCUPANCY_INVALID",
                f"{registry_name} contains invalid slot_occupancy values",
                _schema_names(registry_name, invalid),
            )
    for registry_name, field_map in cleanup_policy_maps.items():
        invalid = {
            name
            for name, value in field_map.items()
            if value not in VALID_CLEANUP_POLICY
        }
        if invalid:
            report.add(
                "ERROR",
                "ICON_SCHEMA_CLEANUP_POLICY_INVALID",
                f"{registry_name} contains invalid cleanup_policy values",
                _schema_names(registry_name, invalid),
            )

    soldier_slots = slot_occupancy_maps["_SOLDIER_ORB_ICON_REGISTRY"]
    soldier_base_fixed = {
        name for name, value in soldier_slots.items() if value == "base_fixed"
    }
    soldier_shared_slot = {
        name for name, value in soldier_slots.items() if value == "shared_slot"
    }
    soldier_base_skills = context["soldier_base_skills"]
    soldier_shared_slot_skills = context["soldier_shared_slot_skills"]

    base_fixed_extra = soldier_base_fixed - soldier_base_skills
    if base_fixed_extra:
        report.add(
            "ERROR",
            "SOLDIER_BASE_FIXED_SLOT_MISMATCH",
            "Soldier base_fixed registry entries must be in SOLDIER_BASE_SKILLS",
            base_fixed_extra,
        )
    base_fixed_missing = soldier_base_skills - soldier_base_fixed
    if base_fixed_missing:
        report.add(
            "ERROR",
            "SOLDIER_BASE_FIXED_SLOT_MISSING",
            "SOLDIER_BASE_SKILLS entries must be marked slot_occupancy=base_fixed",
            base_fixed_missing,
        )

    shared_slot_extra = soldier_shared_slot - soldier_shared_slot_skills
    if shared_slot_extra:
        report.add(
            "ERROR",
            "SOLDIER_SHARED_SLOT_MISMATCH",
            "Soldier shared_slot registry entries must be in SOLDIER_SHARED_SLOT_SKILLS",
            shared_slot_extra,
        )
    shared_slot_missing = soldier_shared_slot_skills - soldier_shared_slot
    if shared_slot_missing:
        report.add(
            "ERROR",
            "SOLDIER_SHARED_SLOT_MISSING",
            "SOLDIER_SHARED_SLOT_SKILLS entries must be marked slot_occupancy=shared_slot",
            shared_slot_missing,
        )

    soldier_cleanup = cleanup_policy_maps["_SOLDIER_ORB_ICON_REGISTRY"]
    soldier_shared_swap = {
        name for name, value in soldier_cleanup.items() if value == "shared_swap"
    }
    soldier_pistol_orb_skill = context["soldier_pistol_orb_skill"]
    soldier_expected_shared_swap = (
        soldier_shared_slot_skills
        - ({soldier_pistol_orb_skill} if soldier_pistol_orb_skill else set())
    )
    report.counts["skills.soldier_shared_swap_cleanup_policy_ids"] = len(
        soldier_shared_swap
    )

    shared_swap_extra = soldier_shared_swap - soldier_expected_shared_swap
    if shared_swap_extra:
        report.add(
            "ERROR",
            "SOLDIER_SHARED_SWAP_CLEANUP_POLICY_EXTRA",
            "Only removable Soldier shared-slot firearms should use cleanup_policy=shared_swap",
            shared_swap_extra,
        )
    shared_swap_missing = soldier_expected_shared_swap - soldier_shared_swap
    if shared_swap_missing:
        report.add(
            "ERROR",
            "SOLDIER_SHARED_SWAP_CLEANUP_POLICY_MISSING",
            "Removable Soldier shared-slot firearms must use cleanup_policy=shared_swap",
            shared_swap_missing,
        )

    soldier_unlock_targets = set(context["soldier_unlock_map"].values())
    shared_swap_unmapped = soldier_shared_swap - soldier_unlock_targets
    if shared_swap_unmapped:
        report.add(
            "ERROR",
            "SOLDIER_SHARED_SWAP_CLEANUP_UNMAPPED",
            "Soldier shared_swap entries need a perk-id reverse mapping for cleanup",
            shared_swap_unmapped,
        )

    cooldown_maps = bool_fields["cooldown_reduction_eligible"]
    optimus_false = {
        name
        for name, value in cooldown_maps["_OPTIMUS_SKILL_ICON_REGISTRY"].items()
        if value is False
    }
    non_optimus_false = {
        f"{registry_name}.{name}"
        for registry_name, field_map in cooldown_maps.items()
        if registry_name != "_OPTIMUS_SKILL_ICON_REGISTRY"
        for name, value in field_map.items()
        if value is False
    }
    report.counts["skills.optimus_cooldown_reduction_ineligible_ids"] = len(
        optimus_false
    )
    report.counts["skills.non_optimus_cooldown_reduction_ineligible_ids"] = len(
        non_optimus_false
    )
    missing_optimus_false = (
        registry_ids["_OPTIMUS_SKILL_ICON_REGISTRY"] - optimus_false
    )
    if missing_optimus_false:
        report.add(
            "ERROR",
            "OPTIMUS_COOLDOWN_REDUCTION_POLICY",
            "Optimus registry entries should be cooldown_reduction_eligible=False",
            missing_optimus_false,
        )
    if non_optimus_false:
        report.add(
            "ERROR",
            "COOLDOWN_REDUCTION_FALSE_OUTSIDE_OPTIMUS",
            "Only Optimus registry entries should opt out of generic cooldown reduction",
            non_optimus_false,
        )


def _check_soldier_firearm_cooldown_paths(
    report: CoverageReport,
    context: dict[str, object],
    sources: dict[str, str],
) -> None:
    pingfighter_src = sources["pingfighter.py"]
    soldier_cooldown_map = context["icon_schema_bool_fields"][
        "cooldown_reduction_eligible"
    ]["_SOLDIER_ORB_ICON_REGISTRY"]
    eligible_firearms = {
        name
        for name in SOLDIER_INSTANCE_COOLDOWN_REQUIREMENTS
        if soldier_cooldown_map.get(name) is True
    }
    report.counts["skills.soldier_firearm_cooldown_sync_targets"] = len(
        eligible_firearms
    )

    missing_schema = set(SOLDIER_INSTANCE_COOLDOWN_REQUIREMENTS) - eligible_firearms
    if missing_schema:
        report.add(
            "ERROR",
            "SOLDIER_FIREARM_COOLDOWN_SCHEMA_MISSING",
            "Soldier instance-backed firearms must be cooldown_reduction_eligible=True",
            missing_schema,
        )

    helper_block = _function_block(
        pingfighter_src,
        "_apply_soldier_firearm_cooldown_frames",
    )
    if (
        "_get_soldier_firearm_cooldown_frames" not in helper_block.text
        or not _keyword_value_is(helper_block.text, "apply_reduction", "apply_reduction")
    ):
        report.add(
            "ERROR",
            "SOLDIER_FIREARM_COOLDOWN_HELPER_BYPASS",
            "_apply_soldier_firearm_cooldown_frames must delegate to the shared cooldown helper",
        )

    helper_attr_synced = set()
    for skill_name, requirement in SOLDIER_INSTANCE_COOLDOWN_REQUIREMENTS.items():
        attr = requirement["attr"]
        if f'"{skill_name}"' in helper_block.text and f".{attr}" in helper_block.text:
            helper_attr_synced.add(skill_name)
    report.counts["skills.soldier_firearm_cooldown_helper_attr_syncs"] = len(
        helper_attr_synced
    )
    helper_missing = eligible_firearms - helper_attr_synced
    if helper_missing:
        report.add(
            "ERROR",
            "SOLDIER_FIREARM_COOLDOWN_HELPER_ATTR_MISSING",
            "Soldier firearm cooldown helper must update each instance cooldown attribute",
            helper_missing,
        )

    sync_calls = _function_call_blocks(
        pingfighter_src,
        "_apply_soldier_firearm_cooldown_frames",
    )
    fire_path_synced = {
        skill_name
        for skill_name in eligible_firearms
        for call in sync_calls
        if f'"{skill_name}"' in call.text
        and _keyword_value_is(
            call.text,
            "apply_reduction",
            "permanent_firearm_selected",
        )
    }
    report.counts["skills.soldier_firearm_cooldown_fire_path_syncs"] = len(
        fire_path_synced
    )
    fire_path_missing = eligible_firearms - fire_path_synced
    if fire_path_missing:
        report.add(
            "ERROR",
            "SOLDIER_FIREARM_FIRE_PATH_COOLDOWN_SYNC_MISSING",
            "Soldier firearm fire/install paths must sync instance cooldowns with the reduced HUD cooldown",
            fire_path_missing,
        )

    module_gate_missing = set()
    module_attr_missing = set()
    for skill_name, requirement in SOLDIER_INSTANCE_COOLDOWN_REQUIREMENTS.items():
        module_src = sources[requirement["module"]]
        if f"def {requirement['gate']}(" not in module_src:
            module_gate_missing.add(f"{skill_name}.{requirement['gate']}")
        if requirement["attr"] not in module_src:
            module_attr_missing.add(f"{skill_name}.{requirement['attr']}")
    if module_gate_missing:
        report.add(
            "ERROR",
            "SOLDIER_FIREARM_GATE_METHOD_MISSING",
            "Soldier firearm module is missing the expected fire/install gate method",
            module_gate_missing,
        )
    if module_attr_missing:
        report.add(
            "ERROR",
            "SOLDIER_FIREARM_INSTANCE_COOLDOWN_ATTR_MISSING",
            "Soldier firearm module is missing the cooldown attribute synced by pingfighter.py",
            module_attr_missing,
        )


def _check_soldier_equipped_pop_cleanup(
    report: CoverageReport,
    sources: dict[str, str],
) -> None:
    pingfighter_src = sources["pingfighter.py"]
    pop_pattern = re.compile(r"_soldier_equipped_skills\s*\.\s*pop\s*\(")
    pop_sites: list[tuple[str, int]] = []
    guarded_sites: list[tuple[str, int]] = []
    for match in pop_pattern.finditer(pingfighter_src):
        line = _line_for(pingfighter_src, match.start())
        function_name = _function_name_for_line(pingfighter_src, line)
        pop_sites.append((function_name, line))
        if function_name == "_cleanup_heavenly_cape_overflow_skills":
            block = _function_block(pingfighter_src, function_name)
            if (
                '_perform_skill_swap_cleanup("soldier", victim)' in block.text
                or "_perform_skill_swap_cleanup('soldier', victim)" in block.text
            ):
                guarded_sites.append((function_name, line))

    report.counts["skills.soldier_equipped_pop_sites"] = len(pop_sites)
    report.counts["skills.soldier_equipped_pop_cleanup_guarded_sites"] = len(
        guarded_sites
    )

    unguarded = set(pop_sites) - set(guarded_sites)
    if unguarded:
        report.add(
            "ERROR",
            "SOLDIER_EQUIPPED_DIRECT_POP",
            "_soldier_equipped_skills.pop() must route through shared cleanup",
            {f"{function_name}:line {line}" for function_name, line in unguarded},
        )


def _check_academy_swap_return_guards(
    report: CoverageReport,
    sources: dict[str, str],
) -> None:
    block = _function_block(sources["pingfighter.py"], "apply_academy_skill_swap")
    swap_calls = sorted(set(re.findall(r"\b(swap_[a-z0-9_]+_skill)\s*\(", block.text)))
    guarded = {
        call
        for call in swap_calls
        if re.search(rf"if\s+not\s+{re.escape(call)}\s*\(", block.text)
    }
    prechecked = set()
    for call, equipped_name in ACADEMY_SWAP_PRECHECKED_CALLS.items():
        if call not in swap_calls:
            continue
        if (
            f"if old_skill_name not in {equipped_name}" in block.text
            and "return False" in block.text
        ):
            prechecked.add(call)

    report.counts["skills.academy_swap_calls"] = len(swap_calls)
    report.counts["skills.academy_swap_return_guarded_calls"] = len(guarded)
    report.counts["skills.academy_swap_prechecked_calls"] = len(prechecked)

    unchecked = set(swap_calls) - guarded - prechecked
    if unchecked:
        report.add(
            "ERROR",
            "ACADEMY_SWAP_RETURN_UNCHECKED",
            "apply_academy_skill_swap() must either check swap_*_skill() return values or carry an explicit precheck whitelist",
            unchecked,
        )


def _check_soldier_mixed_slot_static_patterns(
    report: CoverageReport,
    context: dict[str, object],
    sources: dict[str, str],
) -> None:
    _check_soldier_firearm_cooldown_paths(report, context, sources)
    _check_soldier_equipped_pop_cleanup(report, sources)
    _check_academy_swap_return_guards(report, sources)


def _check_skills(
    report: CoverageReport,
    context: dict[str, object],
    sources: dict[str, str],
) -> None:
    runtime_ids = context["runtime_ids"]
    mini_ids = context["mini_ids"]
    shared_symbol_ids = context["shared_symbol_ids"]
    soldier_symbol_ids = context["soldier_symbol_ids"]
    optimus_icon_ids = context["optimus_icon_ids"]

    report.counts["skills.runtime_ids"] = len(runtime_ids)
    report.counts["skills.draw_skill_icon_mini_ids"] = len(mini_ids)
    report.counts["skills.mini_registry_ids"] = len(context["mini_registry_ids"])
    report.counts["skills.smasher_orb_registry_ids"] = len(
        context["smasher_orb_registry_ids"]
    )
    report.counts["skills.viper_orb_registry_ids"] = len(
        context["viper_orb_registry_ids"]
    )
    report.counts["skills.soldier_orb_registry_ids"] = len(
        context["soldier_orb_registry_ids"]
    )
    report.counts["skills.optimus_icon_registry_ids"] = len(
        context["optimus_icon_registry_ids"]
    )
    report.counts["skills.blacksmith_icon_registry_ids"] = len(
        context["blacksmith_icon_registry_ids"]
    )
    report.counts["skills.blacksmith_bespoke_registry_ids"] = len(
        context["blacksmith_bespoke_registry_ids"]
    )
    report.counts["skills.shared_symbol_ids"] = len(shared_symbol_ids)
    _check_icon_schema(report, context)
    _check_soldier_mixed_slot_static_patterns(report, context, sources)

    missing_mini = runtime_ids - mini_ids
    if missing_mini:
        report.add(
            "ERROR",
            "RUNTIME_SKILL_MINI_ICON_MISSING",
            "Runtime perk IDs missing from draw_skill_icon_mini",
            missing_mini,
        )

    missing_unlock_mini = context["character_unlock_keys"] - mini_ids
    if missing_unlock_mini:
        report.add(
            "ERROR",
            "UNLOCK_PERK_MINI_ICON_MISSING",
            "_CHARACTER_UNLOCK_PERKS keys missing from draw_skill_icon_mini",
            missing_unlock_mini,
        )

    smasher_unlock_map = context["smasher_unlock_map"]
    smasher_unlocks_missing_registry = (
        set(smasher_unlock_map) - context["mini_registry_ids"]
    )
    if smasher_unlocks_missing_registry:
        report.add(
            "ERROR",
            "SMASHER_UNLOCK_MINI_REGISTRY_MISSING",
            "Smasher unlock perks should route through _MINI_SKILL_ICON_REGISTRY",
            smasher_unlocks_missing_registry,
        )

    smasher_unlock_targets_missing_registry = (
        set(smasher_unlock_map.values()) - context["smasher_orb_registry_ids"]
    )
    if smasher_unlock_targets_missing_registry:
        report.add(
            "ERROR",
            "SMASHER_UNLOCK_ORB_REGISTRY_MISSING",
            "Smasher unlock targets should share _SMASHER_ORB_ICON_REGISTRY entries",
            smasher_unlock_targets_missing_registry,
        )

    smasher_orb_missing_mini = (
        context["smasher_orb_registry_ids"] - context["mini_registry_ids"]
    )
    if smasher_orb_missing_mini:
        report.add(
            "ERROR",
            "SMASHER_ORB_MINI_REGISTRY_MISSING",
            "Smasher orb registry IDs should also be available to draw_skill_icon_mini",
            smasher_orb_missing_mini,
        )

    viper_unlock_map = context["viper_unlock_map"]
    viper_unlocks_missing_registry = (
        set(viper_unlock_map) - context["mini_registry_ids"]
    )
    if viper_unlocks_missing_registry:
        report.add(
            "ERROR",
            "VIPER_UNLOCK_MINI_REGISTRY_MISSING",
            "Viper unlock perks should route through _MINI_SKILL_ICON_REGISTRY",
            viper_unlocks_missing_registry,
        )

    viper_unlock_targets_missing_registry = (
        set(viper_unlock_map.values()) - context["viper_orb_registry_ids"]
    )
    if viper_unlock_targets_missing_registry:
        report.add(
            "ERROR",
            "VIPER_UNLOCK_ORB_REGISTRY_MISSING",
            "Viper unlock targets should share _VIPER_ORB_ICON_REGISTRY entries",
            viper_unlock_targets_missing_registry,
        )

    viper_orb_missing_mini = (
        context["viper_orb_registry_ids"] - context["mini_registry_ids"]
    )
    if viper_orb_missing_mini:
        report.add(
            "ERROR",
            "VIPER_ORB_MINI_REGISTRY_MISSING",
            "Viper orb registry IDs should also be available to draw_skill_icon_mini",
            viper_orb_missing_mini,
        )

    soldier_active_missing_registry = (
        context["soldier_active_ids"] - context["soldier_orb_registry_ids"]
    )
    if soldier_active_missing_registry:
        report.add(
            "ERROR",
            "SOLDIER_ORB_REGISTRY_MISSING",
            "Soldier active skills should route through _SOLDIER_ORB_ICON_REGISTRY",
            soldier_active_missing_registry,
        )

    stale_soldier_registry = (
        context["soldier_orb_registry_ids"] - context["soldier_active_ids"]
    )
    if stale_soldier_registry:
        report.add(
            "ERROR",
            "SOLDIER_ORB_REGISTRY_STALE",
            "_SOLDIER_ORB_ICON_REGISTRY contains IDs not in SOLDIER_SKILL_ICONS_DATA",
            stale_soldier_registry,
        )

    soldier_unlock_map = context["soldier_unlock_map"]
    soldier_unlocks_missing_registry = (
        set(soldier_unlock_map) - context["mini_registry_ids"]
    )
    if soldier_unlocks_missing_registry:
        report.add(
            "ERROR",
            "SOLDIER_UNLOCK_MINI_REGISTRY_MISSING",
            "Soldier unlock perks should route through _MINI_SKILL_ICON_REGISTRY",
            soldier_unlocks_missing_registry,
        )

    soldier_unlock_targets_missing_registry = (
        set(soldier_unlock_map.values()) - context["soldier_orb_registry_ids"]
    )
    if soldier_unlock_targets_missing_registry:
        report.add(
            "ERROR",
            "SOLDIER_UNLOCK_ORB_REGISTRY_MISSING",
            "Soldier unlock targets should share _SOLDIER_ORB_ICON_REGISTRY entries",
            soldier_unlock_targets_missing_registry,
        )

    soldier_orb_missing_mini = (
        context["soldier_orb_registry_ids"] - context["mini_registry_ids"]
    )
    if soldier_orb_missing_mini:
        report.add(
            "ERROR",
            "SOLDIER_ORB_MINI_REGISTRY_MISSING",
            "Soldier orb registry IDs should also be available to draw_skill_icon_mini",
            soldier_orb_missing_mini,
        )

    missing_shared_symbol = context["smasher_viper_active_ids"] - shared_symbol_ids
    if missing_shared_symbol:
        report.add(
            "ERROR",
            "SMASHER_VIPER_SYMBOL_MISSING",
            "Smasher/Viper active skills missing from _draw_skill_icon_symbol",
            missing_shared_symbol,
        )

    missing_soldier_symbol = context["soldier_active_ids"] - soldier_symbol_ids
    if missing_soldier_symbol:
        report.add(
            "ERROR",
            "SOLDIER_SYMBOL_MISSING",
            "Soldier active skills missing from _draw_soldier_skill_icon_symbol",
            missing_soldier_symbol,
        )

    missing_optimus_icon = context["optimus_ids"] - optimus_icon_ids
    if missing_optimus_icon:
        report.add(
            "ERROR",
            "OPTIMUS_ICON_MISSING",
            "Optimus skill IDs missing from draw_optimus_skill_icon",
            missing_optimus_icon,
        )

    missing_optimus_registry = (
        context["optimus_ids"] - context["optimus_icon_registry_ids"]
    )
    if missing_optimus_registry:
        report.add(
            "ERROR",
            "OPTIMUS_ICON_REGISTRY_MISSING",
            "Optimus skill IDs should route through _OPTIMUS_SKILL_ICON_REGISTRY",
            missing_optimus_registry,
        )

    stale_optimus_registry = (
        context["optimus_icon_registry_ids"] - context["optimus_ids"]
    )
    if stale_optimus_registry:
        report.add(
            "ERROR",
            "OPTIMUS_ICON_REGISTRY_STALE",
            "_OPTIMUS_SKILL_ICON_REGISTRY contains IDs not in OPTIMUS_EXCLUSIVE_SKILLS",
            stale_optimus_registry,
        )

    blacksmith_missing = (
        context["blacksmith_active_ids"]
        - mini_ids
        - shared_symbol_ids
        - soldier_symbol_ids
        - optimus_icon_ids
        - context["blacksmith_bespoke_registry_ids"]
    )
    if blacksmith_missing:
        report.add(
            "ERROR",
            "BLACKSMITH_ICON_ROUTE_MISSING",
            "Blacksmith active skills need a shared icon path or blacksmith_bespoke registry family",
            blacksmith_missing,
        )

    missing_blacksmith_registry = (
        context["blacksmith_active_ids"] - context["blacksmith_icon_registry_ids"]
    )
    if missing_blacksmith_registry:
        report.add(
            "ERROR",
            "BLACKSMITH_ICON_REGISTRY_MISSING",
            "BLACKSMITH_SKILL_ICONS_DATA names missing from BLACKSMITH_SKILL_ICON_REGISTRY",
            missing_blacksmith_registry,
        )

    stale_blacksmith_registry = (
        context["blacksmith_icon_registry_ids"] - context["blacksmith_active_ids"]
    )
    if stale_blacksmith_registry:
        report.add(
            "ERROR",
            "BLACKSMITH_ICON_REGISTRY_STALE",
            "BLACKSMITH_SKILL_ICON_REGISTRY contains IDs not in BLACKSMITH_SKILL_ICONS_DATA",
            stale_blacksmith_registry,
        )

    blacksmith_bespoke = (
        context["blacksmith_active_ids"] & context["blacksmith_bespoke_registry_ids"]
    )
    if blacksmith_bespoke:
        report.add(
            "INFO",
            "BLACKSMITH_BESPOKE_ICON_PATH",
            "Blacksmith active skills intentionally use BLACKSMITH_SKILL_ICON_REGISTRY family=blacksmith_bespoke",
            blacksmith_bespoke,
        )

    source_ids = (
        runtime_ids
        | context["smasher_viper_active_ids"]
        | context["soldier_active_ids"]
        | context["blacksmith_active_ids"]
    )
    legacy_mini_ids = mini_ids - source_ids
    if legacy_mini_ids:
        report.add(
            "INFO",
            "MINI_ICON_LEGACY_BRANCHES",
            "draw_skill_icon_mini contains branches not found in current source pools",
            legacy_mini_ids,
        )


def build_report(root: Path = PROJECT_ROOT) -> CoverageReport:
    sources = _read_sources(root)
    report = CoverageReport()
    _check_items(report, _collect_item_context(sources))
    _check_skills(report, _collect_skill_context(sources), sources)
    return report


def _format_names(names: tuple[str, ...], *, limit: int = 24) -> str:
    if not names:
        return ""
    shown = list(names[:limit])
    suffix = "" if len(names) <= limit else f" ... (+{len(names) - limit} more)"
    return ", ".join(shown) + suffix


def format_issues(
    issues: Iterable[CoverageIssue],
    *,
    include_info: bool = False,
) -> str:
    lines: list[str] = []
    for issue in issues:
        if issue.severity == "INFO" and not include_info:
            continue
        line = f"[{issue.severity}] {issue.code}: {issue.message}"
        if issue.detail:
            line += f" ({issue.detail})"
        lines.append(line)
        names = _format_names(issue.names)
        if names:
            lines.append(f"  - {names}")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check PingFighter hardcoded item/skill registry coverage."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=PROJECT_ROOT,
        help="Project root. Defaults to this repository.",
    )
    parser.add_argument(
        "--items-only",
        action="store_true",
        help="Only print item-related counts and issues.",
    )
    parser.add_argument(
        "--skills-only",
        action="store_true",
        help="Only print skill/icon-related counts and issues.",
    )
    parser.add_argument(
        "--include-info",
        action="store_true",
        help="Also print informational legacy-branch notes.",
    )
    parser.add_argument(
        "--strict-warnings",
        action="store_true",
        help="Return a failing exit code for warnings as well as errors.",
    )
    args = parser.parse_args(argv)

    report = build_report(args.root)

    if args.items_only:
        prefixes = (
            "ITEM",
            "PRIMARY",
            "SECONDARY",
            "PASSIVE",
            "STORE",
            "SPAWN",
            "GACHA",
            "PANDORA",
            "CAPTURE",
            "LEGENDARY",
        )
        issues = [issue for issue in report.issues if issue.code.startswith(prefixes)]
        counts = {k: v for k, v in report.counts.items() if k.startswith(("items.", "legendary.", "pingfighter."))}
    elif args.skills_only:
        prefixes = ("RUNTIME", "UNLOCK", "SMASHER", "VIPER", "SOLDIER", "OPTIMUS", "BLACKSMITH", "MINI")
        issues = [issue for issue in report.issues if issue.code.startswith(prefixes)]
        counts = {k: v for k, v in report.counts.items() if k.startswith("skills.")}
    else:
        issues = report.issues
        counts = report.counts

    print("Registry coverage counts:")
    for key in sorted(counts):
        print(f"  {key}: {counts[key]}")

    visible = format_issues(issues, include_info=args.include_info)
    if visible:
        print()
        print(visible)
    else:
        print()
        print("No registry coverage issues found.")

    has_error = any(issue.severity == "ERROR" for issue in issues)
    has_warning = any(issue.severity == "WARN" for issue in issues)
    if has_error or (args.strict_warnings and has_warning):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
