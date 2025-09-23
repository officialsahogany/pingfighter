"""LegacyStateAccessor - dict 기반 레거시 전역 상태 접근자."""
from __future__ import annotations

from typing import Any, Iterable, MutableMapping, Tuple


class LegacyStateAccessor:
    """레거시 전역 상태 딕셔너리를 속성 스타일로 다룰 수 있는 어댑터."""

    __slots__ = ("_store",)

    def __init__(self, store: MutableMapping[str, Any]):
        object.__setattr__(self, "_store", store)

    def __getattr__(self, item: str) -> Any:
        return self._store.get(item)

    def __setattr__(self, key: str, value: Any) -> None:
        self._store[key] = value

    def __delattr__(self, item: str) -> None:
        if item in self._store:
            del self._store[item]
        else:
            raise AttributeError(item)

    def __contains__(self, item: object) -> bool:
        return item in self._store

    def keys(self) -> Iterable[str]:
        return self._store.keys()

    def values(self) -> Iterable[Any]:
        return self._store.values()

    def items(self) -> Iterable[Tuple[str, Any]]:
        return self._store.items()

    def get(self, key: str, default: Any = None) -> Any:
        return self._store.get(key, default)

    def setdefault(self, key: str, default: Any = None) -> Any:
        return self._store.setdefault(key, default)

    def update(self, other: MutableMapping[str, Any]) -> None:
        self._store.update(other)

    @property
    def store(self) -> MutableMapping[str, Any]:
        """원본 딕셔너리에 대한 접근자를 반환."""
        return self._store


def bind_legacy_accessor(store: MutableMapping[str, Any]) -> LegacyStateAccessor:
    """주어진 딕셔너리를 감싸는 LegacyStateAccessor 생성."""
    return LegacyStateAccessor(store)
