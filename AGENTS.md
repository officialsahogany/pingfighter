# Repository Guidelines

PingFighter는 Python/Pygame 기반 보스‑퐁 아케이드 게임입니다. 본 문서는 기여자가 빠르게 합류하고 안전하게 변경할 수 있도록 최소·구체 지침을 제공합니다.

## Project Structure & Module Organization
- Entry: `pingfighter.py` (게임 실행), 모듈은 `core/`, `entities/`, `ai/`, `managers/`, `ui/`, `items/`, `effects/`에 분산.
- Assets: `images/`, `fonts/`, `bgm/`, `sounds/` (반드시 `resource_path()`로 로드).
- Tests: `tests/` 및 루트의 `test_*.py`.

## Build, Test, and Development Commands
- Run: `python pingfighter.py`
- Tests: `python -m pytest tests/` 또는 `python tests/test_framework.py`
- Format/Lint: `black .` / `pylint .`
- Package (Windows): `pyinstaller -y PingFighter_Windows.spec` (또는 `--add-data "bgm;bgm" --add-data "images;images"` 등 명시).

## Coding Style & Naming Conventions
- Python 3.10+, PEP 8, 들여쓰기 4칸.
- 네이밍: 함수·모듈 `snake_case`, 클래스 `PascalCase`, 상수 `UPPER_SNAKE`.
- 자원 경로는 항상 `resource_path(relative)` 사용; 하드코딩된 `'/'` 경로 금지.

## Testing Guidelines
- 단위/통합 테스트는 `pytest`/`unittest` 혼용. 새 기능엔 `tests/test_<feature>.py` 추가.
- 커버리지(선택): `pytest --cov=. --cov-report=html`.
- 그래픽 의존 테스트는 가능하면 `SDL_VIDEODRIVER=dummy`로 헤드리스 실행을 고려.

## Commit & Pull Request Guidelines
- 커밋 컨벤션: `feat|fix|docs|style|refactor|test|chore: 간결한 설명`.
- PR에는 요약, 변경사항 목록, 스크린샷(시각 변경 시), 관련 이슈 링크 포함.

## Windows Compatibility (Always Consider)
- 경로: `os.path.join`과 `resource_path()` 사용, 대소문자·경로 구분자 의존 금지.
- 인코딩: 파일 I/O는 `encoding="utf-8"` 명시.
- PyInstaller: Windows에서는 `--add-data "src;dest"`(세미콜론) 규칙. 필요 시 `PingFighter_Windows.spec` 사용.
- 오디오: MP3 디코더 이슈 대비 `PINGF_BGM_EXT=ogg` 환경변수 또는 OGG 동시 배포.
- 로컬 검증(Win): `py -3 -m venv .venv && .venv\\Scripts\\activate && pip install -r requirements.txt && python pingfighter.py`.

