.PHONY: dist clean scaffold-dev

ROOT := $(CURDIR)
TEMPLATES := $(shell find . -mindepth 1 -maxdepth 1 -type d ! -name '.*' \
	! -name common ! -name dist ! -name scripts -printf '%f\n' | sort)

dist:
	@for t in $(TEMPLATES); do                                                                          \
	    out="dist/$$t";                                                                                 \
	    rm -rf "$$out";                                                                                 \
	    mkdir -p "$$out";                                                                               \
	    cp -a "$$t/." "$$out/";                                                                         \
	    cat common/.gitignore "$$t/.gitignore" 2>/dev/null > "$$out/.gitignore" ||:;                    \
	    cat common/.envrc     "$$t/.envrc"     2>/dev/null > "$$out/.envrc"     ||:;                    \
	    if [ -f "$$out/.init-nix/run.sh" ]; then                                                        \
	        awk -v root="$(ROOT)" '                                                                     \
	            /^#@include / { f=$$2; p=root"/"f;                                                      \
	                while ((getline l < p) > 0) print l; close(p); next }                              \
	            { print }' "$$out/.init-nix/run.sh" > "$$out/.init-nix/run.sh.tmp";                     \
	        mv "$$out/.init-nix/run.sh.tmp" "$$out/.init-nix/run.sh";                                   \
	        chmod +x "$$out/.init-nix/run.sh";                                                          \
	    fi;                                                                                             \
	done

clean:
	rm -rf dist

# Local authoring/test harness:
#   make scaffold-dev TEMPLATE=cpp TARGET=/tmp/foo
# Builds dist for the named template, then scaffolds it via init-nix.sh
# pointed at ./dist instead of the published tarball.
scaffold-dev: dist
	@[ -n "$(TEMPLATE)" ] || { echo "TEMPLATE=<name> required" >&2; exit 2; }
	@[ -n "$(TARGET)"   ] || { echo "TARGET=<dir> required"     >&2; exit 2; }
	bash -c '. ./init-nix.sh && INIT_NIX_TEMPLATES_DIR="$(ROOT)/dist" init-nix "$(TEMPLATE)" "$(TARGET)"'
