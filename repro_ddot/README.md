# Reproducible ddot (double) prototype + Coq proof starter

This folder contains:
- A C implementation of a strictly reproducible `ddot` using a long accumulator (exact integer big-int across the full double range).
- A Coq "proof starter" that states the mathematical specification and the key proof obligations to refine with Flocq and VST.

What this gives you
- Bitwise reproducible results across platforms/compilers (no floating-point accumulation; only final rounding packs a double).
- IEEE-754 nearest-even rounding.
- Basic exceptional behavior:
  - If any input is NaN, result is a canonical quiet NaN (payload/sign canonicalized).
  - If any term involves 0×∞ (in either order), result is NaN.
  - If all exceptional-free but infinite contributions are present:
    - Only +∞ → +∞
    - Only −∞ → −∞
    - Both +∞ → NaN
- Finite sums: exact accumulation and correct final rounding, including subnormals.

Caveats
- The accumulation width is fixed (66×64 bits). If the exact sum exceeds the max finite double, the result saturates to ±∞ (detected by span overflow).
- The core accumulation is scalar for clarity. AVX2-specific acceleration can be added around it without changing semantics.

Build (C)
```bash
cmake -S repro_ddot -B build/repro_ddot -DCMAKE_BUILD_TYPE=Release
cmake --build build/repro_ddot -j
ctest --test-dir build/repro_ddot --output-on-failure
```

Recommended compiler flags for strictness
- Ensure no fast-math or contraction:
  - GCC/Clang: `-fno-fast-math -ffp-contract=off`
- We do not change the host rounding mode and do not rely on FP arithmetic during accumulation.

Run the demo
```bash
./build/repro_ddot/bin/test_ddot
```

Coq proof starter
- Requires Coq (8.16+ recommended). Flocq is recommended for rounding-proof parts, but the starter avoids it initially to focus on structure.
- Edit `_CoqProject` if your local paths differ.

```bash
cd repro_ddot/coq
coq_makefile -f _CoqProject -o CoqMakefile
make -f CoqMakefile
```

Roadmap to full verification
1) Replace Real with Flocq formal floats and round-to-nearest-even proofs.
2) Prove the accumulator update preserves the exact integer sum scaled by `2^EMIN`.
3) Prove order independence (commutativity/associativity of big-int updates).
4) Prove finalization/rounding produces the correct IEEE-754 result (including subnormals).
5) VST proof that the C implementation refines the Coq spec, and compile with CompCert.

Files
- `include/reproblas/ddot.h`: Public API
- `src/reproblas/ddot.c`: Implementation
- `src/tests/test_ddot.c`: Sanity tests
- `coq/ReproDotSpec.v`: Specification and proof skeleton
- `coq/_CoqProject`: Coq project definition

License
- Provided as-is for learning and research. Add your preferred license if you intend to distribute.
