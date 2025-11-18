.PHONY: autocommit-start autocommit-stop autocommit-status autocommit-sound autocommit-start-fg autocommit-once autocommit-restart

autocommit-start:
	bash tools/auto-commit.sh start

autocommit-stop:
	bash tools/auto-commit.sh stop

autocommit-status:
	bash tools/auto-commit.sh status

# One-shot sound test (no watcher needed)
autocommit-sound:
	AUTO_SOUND=1 bash tools/auto-commit.sh sound

# Foreground mode (현재 터미널에서 실행/중지는 Ctrl+C)
autocommit-start-fg:
	AUTO_SOUND?=1 \
	AUTO_SKIP_IDENTITY?=1 \
	bash tools/auto-commit.sh start-fg

# 변경사항이 있을 때만 1회 커밋
autocommit-once:
	AUTO_SKIP_IDENTITY?=1 \
	bash tools/auto-commit.sh once

# 재시작(백그라운드)
autocommit-restart:
	bash tools/auto-commit.sh stop || true
	AUTO_SOUND?=1 AUTO_SKIP_IDENTITY?=1 bash tools/auto-commit.sh start
