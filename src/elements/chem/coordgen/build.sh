#!/usr/bin/env bash
# Build the CoordgenLibs Typst plugin -> src/elements/molecule/coordgen.wasm
#
# Requirements (provided here via nix; adjust paths for your environment):
#   - emscripten (emcc)         : nix build nixpkgs#emscripten
#   - binaryen (wasm-as/merge)  : pulled in by emscripten
#
# Produces a self-contained wasm whose ONLY imports are the two `typst_env`
# protocol functions, by stubbing the WASI/env imports emscripten pulls in.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# coordgen/ lives next to the package's molecule sources; emit the wasm there.
OUT="$HERE/../coordgen.wasm"
WORK="$HERE/.build"
COORDGEN_REF="${COORDGEN_REF:-master}"

EMSCRIPTEN="${EMSCRIPTEN:-$(nix build nixpkgs#emscripten --no-link --print-out-paths)}"
# binaryen tools (wasm-as / wasm-merge); separate var name so emcc does not pick
# up its legacy `BINARYEN` env var.
WASMTOOLS="${WASMTOOLS:-$(dirname "$(command -v wasm-as 2>/dev/null || true)")}"
if [ -z "$WASMTOOLS" ]; then
  WASMTOOLS="$(dirname "$(nix build nixpkgs#binaryen --no-link --print-out-paths)/bin/x")/bin"
fi
export PATH="$EMSCRIPTEN/bin:$WASMTOOLS:$PATH"
export EM_CACHE="$WORK/emcache"
mkdir -p "$WORK" "$EM_CACHE"

# 1. fetch CoordgenLibs (header-only deps; maeparser optional and unused)
if [ ! -d "$WORK/coordgenlibs" ]; then
  git clone --depth 1 --branch "$COORDGEN_REF" \
    https://github.com/schrodinger/coordgenlibs.git "$WORK/coordgenlibs"
fi
CG="$WORK/coordgenlibs"

# 2. compile coordgen core + the plugin entry to a standalone wasm.
#    Fixed memory (no growth) avoids the emscripten_notify_memory_growth import.
#    -fno-exceptions: coordgen's core has no catch blocks, and Typst's wasm
#    runtime (wasmi) does not implement the wasm exception-handling proposal, so
#    we must not emit EH opcodes (throws degrade to abort, never hit in practice).
emcc -O2 -std=c++17 -fno-exceptions -I "$CG" \
  "$CG"/sketcherMinimizer.cpp "$CG"/sketcherMinimizerMolecule.cpp \
  "$CG"/CoordgenFragmenter.cpp "$CG"/sketcherMinimizerRing.cpp \
  "$CG"/CoordgenFragmentBuilder.cpp "$CG"/CoordgenMinimizer.cpp \
  "$CG"/sketcherMinimizerResidueInteraction.cpp "$CG"/sketcherMinimizerBond.cpp \
  "$CG"/sketcherMinimizerAtom.cpp "$CG"/sketcherMinimizerMarchingSquares.cpp \
  "$CG"/CoordgenMacrocycleBuilder.cpp "$CG"/sketcherMinimizerFragment.cpp \
  "$CG"/sketcherMinimizerResidue.cpp "$CG"/CoordgenTemplates.cpp \
  "$HERE/cg_plugin.cpp" \
  -sSTANDALONE_WASM=1 -sALLOW_MEMORY_GROWTH=0 -sINITIAL_MEMORY=67108864 \
  --no-entry -Wl,--allow-undefined \
  -sEXPORTED_FUNCTIONS=_layout \
  -o "$WORK/cg_raw.wasm"

# 3. stub the WASI imports (fd_*/environ_*) so the only imports left are the two
#    typst_env protocol functions.
cat > "$WORK/stubs.wat" <<'WAT'
(module
  (func (export "fd_close") (param i32) (result i32) i32.const 0)
  (func (export "fd_write") (param i32 i32 i32 i32) (result i32) i32.const 0)
  (func (export "fd_seek") (param i32 i64 i32 i32) (result i32) i32.const 0)
  (func (export "fd_read") (param i32 i32 i32 i32) (result i32) i32.const 0)
  (func (export "environ_sizes_get") (param i32 i32) (result i32) i32.const 0)
  (func (export "environ_get") (param i32 i32) (result i32) i32.const 0)
)
WAT
wasm-as -all "$WORK/stubs.wat" -o "$WORK/stubs.wasm"
wasm-merge -all --skip-export-conflicts \
  "$WORK/cg_raw.wasm" main "$WORK/stubs.wasm" wasi_snapshot_preview1 \
  -o "$OUT"

echo "built $OUT"
node -e 'const fs=require("fs");const m=new WebAssembly.Module(fs.readFileSync(process.argv[1]));console.log("imports:",JSON.stringify(WebAssembly.Module.imports(m).map(i=>i.module+"."+i.name)));' "$OUT"
