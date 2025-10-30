#include "reproblas/ddot.h"
#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

static unsigned long long as_bits(double d) {
    union { double d; unsigned long long u; } v = { .d = d };
    return v.u;
}

static int test_basic() {
    double x[] = {1.0, 2.0, 3.0};
    double y[] = {4.0, 5.0, 6.0};
    double r = ddot_repro(x, y, 3);
    if (r != 32.0) {
        printf("basic: expected 32, got %.17g\n", r);
        return 0;
    }
    return 1;
}

static int test_order_independence() {
    double x1[] = {1e308, 1e-308, 3.0, 5.0, 1e-308};
    double y1[] = {1e-308, 1e308, -3.0, 2.0, -1e-308};

    double r1 = ddot_repro(x1, y1, 5);

    double x2[] = {3.0, 1e-308, 5.0, 1e308, 1e-308};
    double y2[] = {-3.0, -1e-308, 2.0, 1e-308, 1e308};

    double r2 = ddot_repro(x2, y2, 5);

    if (as_bits(r1) != as_bits(r2)) {
        printf("order: bitwise mismatch r1=%016llx r2=%016llx\n",
               as_bits(r1), as_bits(r2));
        return 0;
    }
    return 1;
}

static int test_exceptions() {
    double x[] = { NAN, 1.0 };
    double y[] = { 2.0, 3.0 };
    double r = ddot_repro(x, y, 2);
    if (!isnan(r)) {
        printf("exceptions: expected NaN, got %.17g\n", r);
        return 0;
    }

    double z = 0.0;
    double inf = INFINITY;
    double r2 = ddot_repro(&z, &inf, 1);
    if (!isnan(r2)) {
        printf("exceptions: expected NaN for 0*Inf, got %.17g\n", r2);
        return 0;
    }

    double x3[] = { inf, -inf };
    double y3[] = { 2.0, 2.0 };
    double r3 = ddot_repro(x3, y3, 2);
    if (!isnan(r3)) {
        printf("exceptions: expected NaN for +Inf + -Inf, got %.17g\n", r3);
        return 0;
    }

    double r4 = ddot_repro(&inf, (double[]){1.0}, 1);
    if (!isinf(r4) || r4 < 0) {
        printf("exceptions: expected +Inf, got %.17g\n", r4);
        return 0;
    }

    double ninf = -INFINITY;
    double r5 = ddot_repro(&ninf, (double[]){1.0}, 1);
    if (!isinf(r5) || r5 > 0) {
        printf("exceptions: expected -Inf, got %.17g\n", r5);
        return 0;
    }

    return 1;
}

static int test_subnormal_path() {
    double a = ldexp(1.0, -1074);
    double x[] = { a, a, a, a };
    double y[] = { 1.0, 1.0, 1.0, 1.0 };
    double r = ddot_repro(x, y, 4);
    if (r == 0.0) {
        printf("subnormal: expected non-zero, got 0\n");
        return 0;
    }
    return 1;
}

int main() {
    int ok = 1;
    ok &= test_basic();
    ok &= test_order_independence();
    ok &= test_exceptions();
    ok &= test_subnormal_path();

    if (ok) {
        printf("All ddot_repro tests passed.\n");
        return 0;
    } else {
        return 1;
    }
}
