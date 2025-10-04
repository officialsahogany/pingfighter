.PHONY: autocommit-start autocommit-stop autocommit-status autocommit-sound

autocommit-start:
	bash tools/auto-commit.sh start

autocommit-stop:
	bash tools/auto-commit.sh stop

autocommit-status:
	bash tools/auto-commit.sh status

# One-shot sound test (no watcher needed)
autocommit-sound:
	AUTO_SOUND=1 bash tools/auto-commit.sh sound
