.PHONY: setup validate quick-validate test test-format test-catalog run editor scene screenshot profile format lint clean reimport export help

help:
	@echo "TOSSA dev commands:"
	@echo "  make setup          one-command environment bootstrap"
	@echo "  make validate       full headless validation (parse, booking, daily, collision, screenshot)"
	@echo "  make quick-validate fast subset (parse + booking + daily, no collision sweep/screenshot)"
	@echo "  make test           alias for validate (see scripts/test.sh for why)"
	@echo "  make test-format    run pure formatting-contract tests"
	@echo "  make test-catalog   run immutable catalog-contract tests"
	@echo "  make run            launch TOSSA normally (windowed, real audio)"
	@echo "  make editor         open the Godot editor"
	@echo "  make scene ARGS='--day work'   launch windowed+muted at a specific dev-flag state"
	@echo "  make screenshot     capture all known TOSSA screens to artifacts/screenshots/"
	@echo "  make profile        capture a performance sample to artifacts/profiling/"
	@echo "  make format         check Game.gd formatting (diff only, see scripts/format.sh)"
	@echo "  make lint           run gdlint (advisory)"
	@echo "  make reimport       force-reimport assets and check for orphaned .import sidecars"
	@echo "  make clean          remove the .godot/ cache"
	@echo "  make export         export release, demo, and debug macOS/Windows/Linux binaries into export/"

setup:
	scripts/bootstrap.sh

validate:
	scripts/validate.sh

quick-validate:
	scripts/validate.sh --quick

test: validate

test-format:
	godot --headless --path . --script tests/test_format.gd

test-catalog:
	godot --headless --path . --script tests/test_catalog.gd

run:
	scripts/run_game.sh

editor:
	scripts/run_editor.sh

scene:
	scripts/run_scene.sh $(ARGS)

screenshot:
	scripts/screenshot.sh

profile:
	scripts/profile.sh

format:
	scripts/format.sh

lint:
	scripts/lint.sh

reimport:
	scripts/reimport.sh

export:
	scripts/export_all.sh

clean:
	scripts/clean_cache.sh
