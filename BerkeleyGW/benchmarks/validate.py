#!/usr/bin/env python3
"""
validate.py: test output correctness for the ESIF-HPC4 BerkeleyGW benchmark.

Usage:
  ./validate.py <size> <output_file>
Allowed sizes: small, medium, large
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Expectations:
    expected_1: float
    expected_2: float
    tolerance: float

# Reference dictionary of expected values of the Epsilon matrix
#     Head and (2,2) elements
EXPECTATIONS = {
    "small": Expectations(1.777506988066533e01, 9.276513200265800e00, 1.0e-10),
    "medium": Expectations(1.524681719435080e01, 1.070898941170535e01, 1.0e-10),
    "large": Expectations(1.416652250097137e01, 1.151002087971401e01, 1.0e-10),
}


def extract_float_after_marker(text: str, marker: str, i_field: int) -> float:
    for line in text.splitlines():
        if marker in line:
            return float(line.split()[i_field])
    raise ValueError(f"Could not find a float for the string: {marker!r}! Make sure the job completed correctly!")

def test_result(name: str, measured: float, expected: float, tol: float) -> bool:
    err = abs(measured - expected)
    ok = err <= tol
    if not ok:
        print()
        print(name)
        print(f"  Measured: {measured:.15e}")
        print(f"  Expected: {expected:.15e}")
        print(f"  AbsError: {err:.15e}")
        print(f"  Tol:      {tol:.15e}")
        print("  Result:   FAILED")
    return ok, err

def parse_args() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="validate.py",
        description="Test output correctness for the ESIF-HPC4 BerkeleyGW benchmark.",
    )
    p.add_argument("size", choices=["small", "medium", "large"], help="Benchmark size")
    p.add_argument("output_file", help="Path to BerkeleyGW output file (e.g., BGW_EPSILON.out)")
    return p

def main() -> int:
    argsout = parse_args()
    args = argsout.parse_args()

    exp = EXPECTATIONS[args.size]
    text = Path(args.output_file).read_text()

    # Next extract floats from file, uses 0-indexing for i_field (last arg)
    # Measurements (epsilon)
    testval_1 = extract_float_after_marker(text, "Head of Epsilon         =", 6)  # 6th field
    testval_2 = extract_float_after_marker(text, "Epsilon(2,2)            =", 4)

    # Timers
    total_time = extract_float_after_marker(text, " - TOTAL ", 5)
    io_time = extract_float_after_marker(text, " - I/O TOTAL ", 6)
    bench_time = total_time - io_time

    ok1, error1 = test_result("Head of Epsilon validation", testval_1, exp.expected_1, exp.tolerance)
    ok2, error2 = test_result("Epsilon(2,2) validation", testval_2, exp.expected_2, exp.tolerance)
    validation_ok = ok1 and ok2

    print()
    print(f"Validating epsilon job for size: {args.size}")
    print(f"    Tolerance: {exp.tolerance}\n")
    print(f"    Reference Head of Epsilon = {exp.expected_1:.15e}")
    print(f"    Test Head of Epsilon =      {testval_1:.15e}")
    print(f"    Absolute Error =            {error1:.15e}\n")
    print(f"    Reference Epsilon(2,2) = {exp.expected_2:.15e}")
    print(f"    Test Epsilon(2,2) =      {testval_2:.15e}")
    print(f"    Absolute Error =         {error2:.15e}\n")
    print(f"  Validation:     {'PASSED' if validation_ok else 'FAILED'}")
    print(f"  Total Time:     {total_time:.2f}")
    print(f"  I/O Time:       {io_time:.2f}")
    print(f"  Benchmark Time: {bench_time:.2f}")
    print()

    return 0 if validation_ok else 2

if __name__ == "__main__":
    raise SystemExit(main())

