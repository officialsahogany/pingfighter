"""아이템 슬롯 및 선택 상태를 관리하는 런타임 스토리지."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List

__all__ = [
    "ItemState",
    "item_state",
    "reset_item_state",
    "append_active_item",
    "remove_active_item",
    "append_passive_item",
    "remove_passive_item",
]


@dataclass(slots=True)
class ItemState:
    """게임 전역에서 참조하는 아이템 상태."""

    active_item_slot: List[Dict[str, Any]] = field(default_factory=list)
    passive_item_list: List[Dict[str, Any]] = field(default_factory=list)
    selected_item_index: int = 0
    selected_passive_item: int = -1
    max_item_slots: int = 3

    def clear_active(self) -> None:
        self.active_item_slot.clear()

    def clear_passive(self) -> None:
        self.passive_item_list.clear()

    def reset_selection(self) -> None:
        self.selected_item_index = 0
        self.selected_passive_item = -1


item_state = ItemState()


def reset_item_state() -> ItemState:
    """아이템 목록과 선택 상태를 초기화."""

    item_state.clear_active()
    item_state.clear_passive()
    item_state.reset_selection()
    item_state.max_item_slots = 3
    return item_state


def append_active_item(item: Dict[str, Any]) -> None:
    item_state.active_item_slot.append(item)


def remove_active_item(predicate) -> None:
    item_state.active_item_slot[:] = [
        itm for itm in item_state.active_item_slot if not predicate(itm)
    ]


def append_passive_item(item: Dict[str, Any]) -> None:
    item_state.passive_item_list.append(item)


def remove_passive_item(predicate) -> None:
    item_state.passive_item_list[:] = [
        itm for itm in item_state.passive_item_list if not predicate(itm)
    ]
