"""Helpers shared by the five standalone models: run header and confidence intervals."""
import getpass
import platform
import sys
from datetime import datetime
from statistics import NormalDist, fmean, stdev

from prng import A, C, M

# The output has Greek letters (λ, μ, ρ): Windows writes redirected output (> file, pipes) in cp1252,
# which has none of them and crashes. UTF-8 always.
sys.stdout.reconfigure(encoding="utf-8")

CONFIDENCE = 0.95


def confidence_interval(values: list) -> tuple:
    """Mean and normal-approximation CI; valid for 30 or more independent replicas."""
    z = NormalDist().inv_cdf(0.5 + CONFIDENCE / 2)
    mean = fmean(values)
    half_width = z * stdev(values) / len(values) ** 0.5
    return mean, mean - half_width, mean + half_width


def stamp() -> str:
    """User and timestamp for figure titles (screenshot requirement)."""
    return f"{getpass.getuser()} | {datetime.now():%Y-%m-%d %H:%M:%S}"


def print_header(title: str, script: str, details: list) -> None:
    print("=" * 78)
    print(f"{title} | One More Day | {script}")
    print(f"Fecha y hora : {datetime.now():%Y-%m-%d %H:%M:%S}")
    print(f"Usuario      : {getpass.getuser()} @ {platform.node()}")
    print(f"Python       : {platform.python_version()} ({platform.system()} {platform.release()})")
    print(f"Generador    : congruencial lineal Taller 1 (a={A}, c={C}, m=2^32={M})")
    for line in details:
        print(line)
    print("=" * 78)
