// Typst plugin (wasm-minimal-protocol) wrapping Schrödinger CoordgenLibs.
//
// Input  (one arg, whitespace-separated decimal ints):
//   nAtoms  Z0 Z1 ... Z[nA-1]  nBonds  (a b order) x nBonds
// Output (text):
//   nAtoms lines "x y" in coordgen's native scale (~50 units per bond), then a
//   line "R <nRings>", then one line per ring listing its space-separated atom
//   indices. Rings are perceived by coordgen (SSSR); the caller reuses them
//   instead of re-deriving ring membership.
//
// Built to a self-contained wasm via emscripten; the WASI/env imports it pulls
// in are stubbed out with binaryen wasm-merge (see build.sh) so the only imports
// left are the two `typst_env` protocol functions Typst provides.

#include "sketcherMinimizer.h"
#include "sketcherMinimizerAtom.h"
#include "sketcherMinimizerRing.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unordered_map>
#include <vector>

extern "C" {
__attribute__((import_module("typst_env"),
               import_name("wasm_minimal_protocol_write_args_to_buffer")))
void write_args(uint8_t *ptr);

__attribute__((import_module("typst_env"),
               import_name("wasm_minimal_protocol_send_result_to_host")))
void send_result(const uint8_t *ptr, size_t len);
}

static const char *skip_ws(const char *p, const char *e) {
    while (p < e && (*p == ' ' || *p == '\n' || *p == '\t' || *p == '\r')) ++p;
    return p;
}
static long read_int(const char *&p, const char *e) {
    p = skip_ws(p, e);
    char *end = nullptr;
    long v = std::strtol(p, &end, 10);
    p = end;
    return v;
}

static void fail(const char *msg) {
    send_result(reinterpret_cast<const uint8_t *>(msg), std::strlen(msg));
}

extern "C" __attribute__((export_name("layout"))) int32_t layout(int32_t in_len) {
    std::string in;
    in.resize((size_t)in_len);
    write_args(reinterpret_cast<uint8_t *>(&in[0]));

    const char *p = in.data();
    const char *e = p + in_len;
    long nA = read_int(p, e);
    if (nA <= 0) { fail("no atoms"); return 1; }

    auto *mol = new sketcherMinimizerMolecule();
    std::vector<sketcherMinimizerAtom *> atoms;
    atoms.reserve((size_t)nA);
    for (long i = 0; i < nA; ++i) {
        auto a = mol->addNewAtom();
        a->setAtomicNumber((int)read_int(p, e));
        atoms.push_back(a);
    }
    long nB = read_int(p, e);
    for (long i = 0; i < nB; ++i) {
        long u = read_int(p, e), v = read_int(p, e), o = read_int(p, e);
        if (u < 0 || u >= nA || v < 0 || v >= nA) { fail("bad bond index"); return 1; }
        auto b = mol->addNewBond(atoms[(size_t)u], atoms[(size_t)v]);
        b->setBondOrder((int)o);
    }

    sketcherMinimizer m;
    m.initialize(mol); // takes ownership of mol
    m.runGenerateCoordinates();

    std::string out;
    out.reserve((size_t)nA * 16);
    char buf[64];
    for (long i = 0; i < nA; ++i) {
        const auto &c = atoms[(size_t)i]->getCoordinates();
        int n = std::snprintf(buf, sizeof(buf), "%.4f %.4f\n", (double)c.x(), (double)c.y());
        out.append(buf, (size_t)n);
    }

    // Rings perceived by coordgen (SSSR), so the caller need not re-derive them.
    std::unordered_map<sketcherMinimizerAtom *, long> idx;
    for (long i = 0; i < nA; ++i) idx[atoms[(size_t)i]] = i;
    auto &rings = mol->getRings();
    int n = std::snprintf(buf, sizeof(buf), "R %zu\n", rings.size());
    out.append(buf, (size_t)n);
    for (auto *ring : rings) {
        bool first = true;
        for (auto *a : ring->getAtoms()) {
            n = std::snprintf(buf, sizeof(buf), first ? "%ld" : " %ld", idx[a]);
            out.append(buf, (size_t)n);
            first = false;
        }
        out.push_back('\n');
    }

    send_result(reinterpret_cast<const uint8_t *>(out.data()), out.size());
    return 0;
}
