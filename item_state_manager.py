"""런타임 아이템 상태를 다루는 공용 헬퍼."""

from __future__ import annotations

from typing import Callable

from game_state.items import ItemStateAdapter


def reset_runtime_items(
    adapter: ItemStateAdapter,
    *,
    clear_notices: Callable[[], None],
    set_selected_index: Callable[[int], None],
    set_max_slots: Callable[[int], None],
    max_slots: int = 3,
) -> None:
    """액티브/패시브 슬롯과 선택 상태를 기본값으로 초기화."""

    adapter.clear_active_items()
    adapter.clear_passive_items()
    clear_notices()
    set_selected_index(0)
    set_max_slots(max_slots)
