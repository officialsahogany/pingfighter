"""간단한 로컬라이제이션 매니저"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, Optional

from config.language_options import DEFAULT_LANGUAGE, LANGUAGE_CODES
from resource_path import resource_path


class LocalizationManager:
    """JSON 기반 다국어 문자열 로더"""

    def __init__(self):
        self._cache: Dict[str, Dict[str, str]] = {}
        self._current_language: str = DEFAULT_LANGUAGE
        self._fallback_language: str = DEFAULT_LANGUAGE

    @property
    def current_language(self) -> str:
        return self._current_language

    def set_language(self, language_code: str):
        """현재 언어 설정 (지원하지 않는 경우 기본값으로 대체)"""
        if language_code not in LANGUAGE_CODES:
            language_code = DEFAULT_LANGUAGE
        self._current_language = language_code
        # 미리 로드 실패 대비
        self._ensure_language_loaded(language_code)

    def get_text(self, key: str, fallback: Optional[str] = None) -> str:
        """현재 언어 기준으로 번역문 반환"""
        for language_code in (self._current_language, self._fallback_language):
            translations = self._ensure_language_loaded(language_code)
            if translations and key in translations:
                return translations[key]
        if fallback is not None:
            return fallback
        return key

    def get_language_label(self, language_code: str) -> str:
        """언어 선택용 표시 문자열 반환"""
        label_key = f"option.language.{language_code}"
        return self.get_text(label_key, fallback=language_code)

    def _ensure_language_loaded(self, language_code: str) -> Dict[str, str]:
        if language_code in self._cache:
            return self._cache[language_code]

        language_file = Path(resource_path(f"localization/{language_code}.json"))
        translations: Dict[str, str] = {}
        if language_file.exists():
            try:
                with language_file.open("r", encoding="utf-8") as fp:
                    translations = json.load(fp)
            except Exception:
                translations = {}
        self._cache[language_code] = translations
        return translations


_localization_manager: Optional[LocalizationManager] = None


def get_localization_manager() -> LocalizationManager:
    global _localization_manager
    if _localization_manager is None:
        _localization_manager = LocalizationManager()
    return _localization_manager
