dist:
	for dir in $$(find . -mindepth 1 -maxdepth 1 -type d ! -name '.*'); do                    \
	    [ "$$(basename "$$dir")" = common ] || [ "$$(basename "$$dir")" = dist ] || {         \
	        mkdir -p "$@/$$dir";                                                              \
	        cp "$$dir/flake.nix" "$@/$$dir";                                                  \
			cat common/.gitignore "$$dir/.gitignore" > "$@/$$dir/.gitignore" 2>/dev/null ||:; \
			cat common/.envrc "$$dir/.envrc" > "$@/$$dir/.envrc" 2>/dev/null ||:;             \
	    };                                                                                    \
	done

.PHONY: dist
