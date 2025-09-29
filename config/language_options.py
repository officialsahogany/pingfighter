"""언어 설정 공통 상수"""

from typing import List, Tuple

LANGUAGE_OPTIONS: List[Tuple[str, str]] = [
    ("ko", "한국어"),
    ("en", "English"),
    ("ja", "日本語")
]

DEFAULT_LANGUAGE = LANGUAGE_OPTIONS[0][0]
LANGUAGE_CODES: List[str] = [code for code, _ in LANGUAGE_OPTIONS]


def get_language_label(code: str) -> str:
    """언어 코드에 해당하는 표시 문자열 반환"""
    for language_code, label in LANGUAGE_OPTIONS:
        if language_code == code:
            return label
    return code
