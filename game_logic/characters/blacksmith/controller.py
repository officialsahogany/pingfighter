"""발토르(Blacksmith) 캐릭터 컨트롤러 뼈대."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable, Optional

from .state import BlacksmithState, blacksmith_state


@dataclass
class BlacksmithController:
    """발토르 전용 시스템을 모듈화하기 위한 컨트롤러.

    아직 모든 로직이 마이그레이션되지 않았으므로 pingfighter 전역 상태와의
    양방향 동기화 헬퍼 수준으로 제공한다.
    """

    namespace: Any
    state: BlacksmithState = blacksmith_state

    def sync_from_globals(self, attrs: Optional[Iterable[str]] = None) -> None:
        """pingfighter 전역 상태를 내부 상태로 동기화."""
        self.state.sync_from_globals(self.namespace, attrs=attrs)

    def apply_to_globals(self, attrs: Optional[Iterable[str]] = None) -> None:
        """내부 상태를 pingfighter 전역에 반영."""
        self.state.apply_to_globals(self.namespace, attrs=attrs)

    def reset(self) -> None:
        """발토르 전용 상태를 초기화하고 전역에 반영."""
        self.state.reset()
        self.apply_to_globals()


__all__ = ["BlacksmithController"]
