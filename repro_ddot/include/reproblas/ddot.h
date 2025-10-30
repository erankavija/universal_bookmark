#ifndef REPROBLAS_DDOT_H
#define REPROBLAS_DDOT_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Reproducible dot product for doubles.
// - Order-independent, bitwise reproducible.
// - Exact accumulation with final IEEE-754 nearest-even rounding.
// - Exceptional behavior:
//   * Any NaN in inputs -> canonical quiet NaN
//   * Any 0 * Inf pair -> NaN
//   * Infinite contributions only -> +Inf / -Inf / NaN if both signs
// Returns: double (IEEE-754) per behavior above.
double ddot_repro(const double* x, const double* y, size_t n);

#ifdef __cplusplus
}
#endif

#endif /* REPROBLAS_DDOT_H */
