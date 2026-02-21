.PHONY: validate lint pack test-scripts test-templates publish-snapshot clean all

ORB_FILE := orb.yml
ORB_NAMESPACE := KofTwentyTwo
ORB_NAME := munitor

all: lint validate test-scripts test-templates

# Generate self-contained packed scripts (embeds helpers + templates)
pack-scripts:
	bash scripts/pack_generate_config.sh
	bash scripts/pack_generate_dockerfile.sh

# Pack the orb source into a single file
pack: pack-scripts
	circleci orb pack src > $(ORB_FILE)

# Validate the packed orb against CircleCI schema
validate: pack
	circleci orb validate $(ORB_FILE)
	@echo "Orb validation passed."

# Lint YAML files and shell scripts
lint:
	yamllint -c .yamllint src/
	shellcheck --severity=warning src/scripts/*.sh
	@echo "Lint passed."

# Run unit tests for shell scripts
test-scripts:
	@echo "Running script tests..."
	@for f in tests/test_*.sh; do \
		if [ -f "$$f" ]; then \
			echo "  Running $$f"; \
			bash "$$f" || exit 1; \
		fi; \
	done
	@echo "All script tests passed."

# Run template rendering tests
test-templates:
	@echo "Running template tests..."
	@if [ -f tests/test_generate_config.sh ]; then \
		bash tests/test_generate_config.sh || exit 1; \
	else \
		echo "  No template tests yet (created in Phase 2)."; \
	fi
	@echo "Template tests passed."

# Publish a dev snapshot for integration testing
publish-snapshot: validate
	circleci orb publish $(ORB_FILE) $(ORB_NAMESPACE)/$(ORB_NAME)@dev:snapshot

clean:
	rm -f $(ORB_FILE)
