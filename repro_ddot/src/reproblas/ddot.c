#include "reproblas/ddot.h"

#include <string.h>   // memset
#include <stdbool.h>
#include <limits.h>

#define WORD_BITS 64
#define ACC_EMIN (-2148)
#define ACC_EPROD_MIN (-2148)
#define ACC_EPROD_MAX (1942)
#define PROD_BITS 106

// Total bit-span required for the accumulator:
//   span = (ACC_EPROD_MAX - ACC_EPROD_MIN + 1) + PROD_BITS
//        = (1942 - (-2148) + 1) + 106 = 4091 + 106 = 4197 bits
#define ACC_BITS 4197
#define ACC_LIMBS ((ACC_BITS + WORD_BITS - 1) / WORD_BITS) // 66 limbs

typedef struct {
    // Non-negative big integer, little-endian limbs
    uint64_t limb[ACC_LIMBS];
} bigu_t;

typedef union {
    double d;
    uint64_t u;
} dblbits_t;

static inline bool is_nan_u64(uint64_t u) {
    uint64_t exp = (u >> 52) & 0x7FFu;
    uint64_t frac = u & ((1ULL << 52) - 1ULL);
    return exp == 0x7FFu && frac != 0;
}

static inline bool is_inf_u64(uint64_t u) {
    uint64_t exp = (u >> 52) & 0x7FFu;
    uint64_t frac = u & ((1ULL << 52) - 1ULL);
    return exp == 0x7FFu && frac == 0;
}

static inline bool is_zero_u64(uint64_t u) {
    return (u & ~(1ULL << 63)) == 0; // ignore sign of zero
}

// Decode double (finite, not NaN/Inf) as sign, integer significand S, exponent E
// such that |value| = S * 2^E and S,E are integers, S>=0.
// Returns false for NaN/Inf; true for finite (including zeros and subnormals).
static inline bool decode_double_SE(uint64_t u, int* sign, uint64_t* S, int* E) {
    *sign = (u >> 63) ? -1 : +1;
    uint64_t exp = (u >> 52) & 0x7FFu;
    uint64_t frac = u & ((1ULL << 52) - 1ULL);
    if (exp == 0x7FFu) {
        return false; // NaN or Inf
    } else if (exp == 0) {
        if (frac == 0) {
            *S = 0;
            *E = 0; // Zero; exponent arbitrary (will be skipped)
        } else {
            // Subnormal: value = frac * 2^(-1074)
            *S = frac;
            *E = -1074;
        }
    } else {
        // Normal: value = (1<<52 + frac) * 2^(exp-1023-52)
        *S = (1ULL << 52) | frac;
        *E = (int)exp - 1023 - 52;
    }
    return true;
}

static inline void bigu_clear(bigu_t* a) {
    memset(a->limb, 0, sizeof(a->limb));
}

static inline void add_word_at(bigu_t* a, size_t idx, uint64_t w, uint64_t* carry, bool* overflow) {
    if (w == 0 && *carry == 0) return;
    if (idx >= ACC_LIMBS) { *overflow = true; return; }
    unsigned __int128 sum = (unsigned __int128)a->limb[idx] + w + *carry;
    a->limb[idx] = (uint64_t)sum;
    *carry = (uint64_t)(sum >> 64);
}

// Add a 128-bit unsigned value shifted left by 'bit_shift' into accumulator 'a'.
static void bigu_add_shifted_u128(bigu_t* a, unsigned __int128 val, size_t bit_shift, bool* overflow) {
    if (val == 0) return;

    size_t word_off = bit_shift / WORD_BITS;
    unsigned r = (unsigned)(bit_shift % WORD_BITS);

    uint64_t lo = (uint64_t)val;
    uint64_t hi = (uint64_t)(val >> 64);

    uint64_t v0, v1, v2;
    if (r == 0) {
        v0 = lo;
        v1 = hi;
        v2 = 0;
    } else {
        v0 = lo << r;
        uint64_t carry0 = lo >> (64 - r);
        v1 = (hi << r) | carry0;
        uint64_t carry1 = hi >> (64 - r);
        v2 = carry1;
    }

    uint64_t carry = 0;
    size_t i = word_off;

    add_word_at(a, i++, v0, &carry, overflow);
    add_word_at(a, i++, v1, &carry, overflow);
    add_word_at(a, i++, v2, &carry, overflow);

    while (carry != 0) {
        if (i >= ACC_LIMBS) { *overflow = true; return; }
        unsigned __int128 sum = (unsigned __int128)a->limb[i] + carry;
        a->limb[i] = (uint64_t)sum;
        carry = (uint64_t)(sum >> 64);
        i++;
    }
}

static int bigu_cmp(const bigu_t* a, const bigu_t* b) {
    for (int i = (int)ACC_LIMBS - 1; i >= 0; --i) {
        if (a->limb[i] < b->limb[i]) return -1;
        if (a->limb[i] > b->limb[i]) return +1;
    }
    return 0;
}

static void bigu_sub(const bigu_t* a, const bigu_t* b, bigu_t* c) {
    uint64_t borrow = 0;
    for (size_t i = 0; i < ACC_LIMBS; ++i) {
        unsigned __int128 ai = a->limb[i];
        unsigned __int128 bi = b->limb[i] + borrow;
        unsigned __int128 diff = ai - bi;
        c->limb[i] = (uint64_t)diff;
        borrow = (uint64_t)((diff >> 64) & 1ULL); // 1 if underflow
    }
}

static int bigu_msb_index(const bigu_t* a) {
    for (int i = (int)ACC_LIMBS - 1; i >= 0; --i) {
        uint64_t w = a->limb[i];
        if (w != 0) {
#if defined(__GNUC__) || defined(__clang__)
            int lz = __builtin_clzll(w);
            int bit = 63 - lz;
#else
            int bit = 63;
            while (bit >= 0 && ((w >> bit) & 1ULL) == 0) --bit;
#endif
            return i * 64 + bit;
        }
    }
    return -1;
}

static uint64_t bigu_extract_bits64(const bigu_t* a, int start, int count) {
    if (count <= 0) return 0;
    if (start >= (int)(ACC_LIMBS * 64)) return 0;

    int end = start + count - 1;
    if (end < 0) return 0;

    int widx0 = start / 64;
    int off0 = start % 64;

    uint64_t w0 = (widx0 >= 0 && widx0 < (int)ACC_LIMBS) ? a->limb[widx0] : 0;
    uint64_t w1 = (widx0 + 1 >= 0 && widx0 + 1 < (int)ACC_LIMBS) ? a->limb[widx0 + 1] : 0;

    unsigned __int128 concat = ((unsigned __int128)w1 << 64) | w0;
    unsigned __int128 shifted = concat >> off0;

    uint64_t mask = (count == 64) ? (uint64_t)(~0ULL) : ((1ULL << count) - 1ULL);
    return (uint64_t)shifted & mask;
}

static bool bigu_has_any_below(const bigu_t* a, int idx) {
    if (idx <= 0) return false;
    int full_limbs = idx / 64;
    int rem = idx % 64;

    for (int i = 0; i < full_limbs; ++i) {
        if (a->limb[i] != 0) return true;
    }
    if (rem > 0 && full_limbs < (int)ACC_LIMBS) {
        uint64_t mask = (1ULL << rem) - 1ULL;
        if ((a->limb[full_limbs] & mask) != 0) return true;
    }
    return false;
}

static double pack_double(int sign, int unbiased_exp, uint64_t frac52) {
    uint64_t signbit = (sign < 0) ? (1ULL << 63) : 0ULL;
    uint64_t expbits, fracbits;
    if (unbiased_exp == INT_MIN) {
        expbits = 0;
        fracbits = frac52 & ((1ULL << 52) - 1ULL);
    } else if (unbiased_exp == INT_MAX) {
        expbits = 0x7FFULL;
        fracbits = 0ULL;
    } else {
        int efield = unbiased_exp + 1023;
        if (efield <= 0) efield = 0;
        expbits = (uint64_t)efield & 0x7FFULL;
        fracbits = frac52 & ((1ULL << 52) - 1ULL);
    }
    uint64_t u = signbit | (expbits << 52) | fracbits;
    dblbits_t db; db.u = u; return db.d;
}

static double finalize_to_double(const bigu_t* Pos, const bigu_t* Neg) {
    bigu_t mag; memset(&mag, 0, sizeof(mag));
    int sgn = +1;

    int cmp = bigu_cmp(Pos, Neg);
    if (cmp == 0) {
        return 0.0;
    } else if (cmp > 0) {
        bigu_sub(Pos, Neg, &mag);
        sgn = +1;
    } else {
        bigu_sub(Neg, Pos, &mag);
        sgn = -1;
    }

    int msb = bigu_msb_index(&mag);
    if (msb < 0) return 0.0;

    int E_star = ACC_EMIN + msb;

    if (E_star > 1023) {
        return pack_double(sgn, INT_MAX, 0);
    }

    if (E_star < -1022) {
        int top = -1023 - ACC_EMIN;
        int bot = -1074 - ACC_EMIN;
        uint64_t mant52 = bigu_extract_bits64(&mag, bot, 52);
        int g_idx = bot - 1;
        bool guard = (g_idx >= 0) ? ((bigu_extract_bits64(&mag, g_idx, 1) & 1ULL) != 0) : false;
        bool sticky = bigu_has_any_below(&mag, g_idx);
        if (guard && (sticky || (mant52 & 1ULL))) {
            mant52 += 1ULL;
            if (mant52 == (1ULL << 52)) {
                return pack_double(sgn, -1022, 0);
            }
        }
        return pack_double(sgn, INT_MIN, mant52);
    }

    int cut = msb - 52;
    uint64_t sig53 = bigu_extract_bits64(&mag, cut, 53);
    int g_idx = cut - 1;
    bool guard = (g_idx >= 0) ? ((bigu_extract_bits64(&mag, g_idx, 1) & 1ULL) != 0) : false;
    bool sticky = bigu_has_any_below(&mag, g_idx);

    if (guard && (sticky || (sig53 & 1ULL))) {
        sig53 += 1ULL;
        if (sig53 == (1ULL << 53)) {
            int E_rounded = E_star + 1;
            if (E_rounded > 1023) {
                return pack_double(sgn, INT_MAX, 0);
            }
            return pack_double(sgn, E_rounded, 0);
        }
    }

    uint64_t frac52 = sig53 & ((1ULL << 52) - 1ULL);
    return pack_double(sgn, E_star, frac52);
}

// Public API

double ddot_repro(const double* x, const double* y, size_t n) {
    bigu_t pos, neg;
    bigu_clear(&pos);
    bigu_clear(&neg);

    bool overflow = false;
    bool saw_nan = false;
    bool saw_invalid_zero_inf = false;
    bool saw_pos_inf = false;
    bool saw_neg_inf = false;

    for (size_t i = 0; i < n; ++i) {
        dblbits_t xb = {.d = x[i]};
        dblbits_t yb = {.d = y[i]};

        if (is_nan_u64(xb.u) || is_nan_u64(yb.u)) {
            saw_nan = true;
            continue;
        }

        bool x_is_inf = is_inf_u64(xb.u);
        bool y_is_inf = is_inf_u64(yb.u);
        bool x_is_zero = is_zero_u64(xb.u);
        bool y_is_zero = is_zero_u64(yb.u);

        if ((x_is_inf && y_is_zero) || (y_is_inf && x_is_zero)) {
            saw_invalid_zero_inf = true;
            continue;
        }

        if (x_is_inf || y_is_inf) {
            int sx = (xb.u >> 63) ? -1 : +1;
            int sy = (yb.u >> 63) ? -1 : +1;
            int s = sx * sy;
            if (s > 0) saw_pos_inf = true; else saw_neg_inf = true;
            continue;
        }

        int sx, sy, Ex, Ey;
        uint64_t Sx, Sy;
        if (!decode_double_SE(xb.u, &sx, &Sx, &Ex)) { saw_nan = true; continue; }
        if (!decode_double_SE(yb.u, &sy, &Sy, &Ey)) { saw_nan = true; continue; }

        if (Sx == 0 || Sy == 0) {
            continue;
        }

        unsigned __int128 Sprod = (unsigned __int128)Sx * (unsigned __int128)Sy;
        int Eprod = Ex + Ey;

        if (Eprod < ACC_EMIN) {
            continue;
        }

        size_t shift = (size_t)(Eprod - ACC_EMIN);
        if (sx * sy > 0) {
            bigu_add_shifted_u128(&pos, Sprod, shift, &overflow);
        } else {
            bigu_add_shifted_u128(&neg, Sprod, shift, &overflow);
        }
    }

    if (saw_nan || saw_invalid_zero_inf) {
        dblbits_t out; out.u = 0x7FF8000000000001ULL; return out.d;
    }
    if (saw_pos_inf && saw_neg_inf) {
        dblbits_t out; out.u = 0x7FF8000000000001ULL; return out.d;
    }
    if (saw_pos_inf && !saw_neg_inf) {
        return pack_double(+1, INT_MAX, 0);
    }
    if (!saw_pos_inf && saw_neg_inf) {
        return pack_double(-1, INT_MAX, 0);
    }

    if (overflow) {
        int cmp = bigu_cmp(&pos, &neg);
        if (cmp == 0) return 0.0;
        return pack_double((cmp > 0) ? +1 : -1, INT_MAX, 0);
    }

    return finalize_to_double(&pos, &neg);
}
