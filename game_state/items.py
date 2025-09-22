"""기존 pingfighter 전역 아이템 상태를 느슨하게 참조하는 어댑터."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Iterable, MutableSequence, Optional

__all__ = [
    "ItemStateAdapter",
    "item_state",
    "bind_item_state",
    "unbind_item_state",
]


@dataclass
class _Hooks:
    get_active: Callable[[], MutableSequence]
    get_passive: Callable[[], MutableSequence]
    get_selected_active: Callable[[], int]
    set_selected_active: Callable[[int], None]
    get_selected_passive: Callable[[], int]
    set_selected_passive: Callable[[int], None]
    get_max_slots: Callable[[], int]
    set_max_slots: Callable[[int], None]


class ItemStateAdapter:
    """PingFighter 전역 아이템 상태에 대한 안전한 조회/수정 래퍼."""

    def __init__(self) -> None:
        self._hooks: Optional[_Hooks] = None

    def bind(
        self,
        *,
        get_active: Callable[[], MutableSequence],
        get_passive: Callable[[], MutableSequence],
        get_selected_active: Callable[[], int],
        set_selected_active: Callable[[int], None],
        get_selected_passive: Callable[[], int],
        set_selected_passive: Callable[[int], None],
        get_max_slots: Callable[[], int],
        set_max_slots: Callable[[int], None],
    ) -> None:
        self._hooks = _Hooks(
            get_active,
            get_passive,
            get_selected_active,
            set_selected_active,
            get_selected_passive,
            set_selected_passive,
            get_max_slots,
            set_max_slots,
        )

    def unbind(self) -> None:
        self._hooks = None

    # 조회 계열 ---------------------------------------------------------------
    def active_items(self) -> MutableSequence:
        return self._require().get_active()

    def passive_items(self) -> MutableSequence:
        return self._require().get_passive()

    def selected_active_index(self) -> int:
        return self._require().get_selected_active()

    def selected_passive_index(self) -> int:
        return self._require().get_selected_passive()

    def max_slots(self) -> int:
        return self._require().get_max_slots()

    # 갱신 계열 ---------------------------------------------------------------
    def set_selected_active_index(self, value: int) -> None:
        self._require().set_selected_active(value)

    def set_selected_passive_index(self, value: int) -> None:
        self._require().set_selected_passive(value)

    def set_max_slots(self, value: int) -> None:
        self._require().set_max_slots(value)

    def replace_active_items(self, items: Iterable) -> None:
        target = self.active_items()
        target.clear()
        target.extend(items)

    def replace_passive_items(self, items: Iterable) -> None:
        target = self.passive_items()
        target.clear()
        target.extend(items)

    # 내부 --------------------------------------------------------------------
    def _require(self) -> _Hooks:
        if self._hooks is None:
            raise RuntimeError("ItemStateAdapter is not bound to pingfighter state")
        return self._hooks


item_state = ItemStateAdapter()


def bind_item_state(**hooks) -> None:
    """pingfighter 초기화 시 호출되어 전역 상태 후크를 등록."""

    item_state.bind(**hooks)


def unbind_item_state() -> None:
    item_state.unbind()
