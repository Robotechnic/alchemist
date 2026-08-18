VERSION := $(shell sed -n 's/^version\s*=\s*"\(.*\)"/\1/p' typst.toml)
PACKAGE_NAME := $(shell sed -n 's/^name\s*=\s*"\(.*\)"/\1/p' typst.toml)
TARGET_DIR=./$(PACKAGE_NAME)/$(VERSION)

ENGINE_DIR=src/elements/chem

.PHONY: check plugin coordgen plugin-test link clean-link module manual watch bump-cetz

check:
	typst compile ./lib.typ
	rm ./lib.pdf

# Build the Rust/WASM molecule engine and copy it into the package.
plugin:
	cd $(ENGINE_DIR)/engine && cargo build --release --target wasm32-unknown-unknown
	cp $(ENGINE_DIR)/engine/target/wasm32-unknown-unknown/release/alchemist_chem_engine.wasm \
		$(ENGINE_DIR)/chem.wasm

plugin-test:
	cd $(ENGINE_DIR)/engine && cargo test

# Build the CoordgenLibs 2D-coordinate plugin and copy it into the package.
# Needs emscripten + binaryen (provided here via nix). See $(ENGINE_DIR)/coordgen/build.sh.
coordgen:
	bash $(ENGINE_DIR)/coordgen/build.sh

link :
	mkdir -p ~/.cache/typst/packages/preview/${PACKAGE_NAME}
	ln -s "$(CURDIR)" ~/.cache/typst/packages/preview/${PACKAGE_NAME}/$(VERSION)

clean-link:
	rm -rf ~/.cache/typst/packages/preview/${PACKAGE_NAME}

module:
	mkdir -p $(TARGET_DIR)
	mkdir -p $(TARGET_DIR)/src
	cp ./typst.toml $(TARGET_DIR)/typst.toml
	cp ./LICENSE $(TARGET_DIR)/
	cp ./lib.typ $(TARGET_DIR)/
	cp -r ./src/* $(TARGET_DIR)/src/
	sed 's|https://typst.app/universe/package/${PACKAGE_NAME}|https://github.com/Typsium/${PACKAGE_NAME}|g' ./README.md > $(TARGET_DIR)/README.md
	sed -i "s/\/master\//\/$(VERSION)\//g" $(TARGET_DIR)/README.md
	sed -E -i 's/:[0-9]+\.[0-9]+\.[0-9]+/:$(VERSION)/g' $(TARGET_DIR)/README.md
	

manual:
	typst compile ./doc/manual.typ --root .

watch:
	typst watch ./doc/manual.typ --root .

test:
	tt run -F -j15

format:
	typstyle -i $$(find ./src -type f -name "*.typ")

# Target to bump the version in lib.typ and all files in /src
CETZ_VERSION ?= 0.5.2
bump-cetz:
	perl -pi -e 's/cetz:[0-9]+\.[0-9]+\.[0-9]+/cetz:$(CETZ_VERSION)/g' ./lib.typ
	find ./src -type f -exec perl -pi -e 's/cetz:[0-9]+\.[0-9]+\.[0-9]+/cetz:$(CETZ_VERSION)/g' {} +
	find ./tests/* -type f -exec perl -pi -e 's/cetz:[0-9]+\.[0-9]+\.[0-9]+/cetz:$(CETZ_VERSION)/g' {} +