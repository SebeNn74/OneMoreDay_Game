"""Modelo 2 - Caminata aleatoria en grilla (One More Day).

Movimiento de peatones y patrulla de hostiles en los escenarios de trayecto. Cada paso
elige una dirección según probabilidades configurables; si la celda destino está fuera
del mapa o bloqueada (banca, poste), el personaje se queda en su celda. step() es la
función que se porta al juego.

Tipología: simulación discreta (cadena de Markov sobre las celdas de la grilla).
PRNG: congruencial lineal del Taller 1, punto 3 (ver prng.py). La elección de dirección
generaliza la de Taller 1 punto 2 (int(r * 4)) a probabilidades distintas por dirección.
Unidades: celdas (en el juego, 1 celda = 1 tile).

Uso:
    python Jimenez_Correa_Avila_Melo_Nino_modelo2_caminata.py [--seed N] [--walkers N] [--steps N] [--no-show]
"""
import argparse
import csv
import math
from pathlib import Path

import matplotlib.pyplot as plt

from common import confidence_interval, print_header, stamp
from prng import LCG
from punto3_generadores_pseudoaleatorios.pruebas import (
    NIVEL_DE_SIGNIFICANCIA,
    calcular_estadistico_chi_cuadrado,
    valor_critico_chi_cuadrado,
)

# Godot convention: y grows downwards.
DIRECTIONS = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}
SYMMETRIC = {"up": 0.25, "down": 0.25, "left": 0.25, "right": 0.25}
# Crowd drifting towards the exit of the platform (right).
BIASED = {"up": 0.25, "down": 0.25, "left": 0.10, "right": 0.40}

# Embedded test data for config 3: a 12 x 6 bus platform with benches and posts.
PLATFORM_WIDTH = 12
PLATFORM_HEIGHT = 6
PLATFORM_BLOCKED = {(3, 2), (3, 3), (4, 2), (4, 3), (8, 1), (8, 4), (10, 2)}
PLATFORM_START = (0, 0)
MIXING_STEPS = 400
TRACKED_PATHS = 3
RESULTS_DIR = Path(__file__).parent / "resultados"


def is_free(cell: tuple, grid: tuple) -> bool:
    width, height, blocked = grid
    return 0 <= cell[0] < width and 0 <= cell[1] < height and cell not in blocked


def choose_direction(probs: dict, rng: LCG) -> str:
    number = rng.next()
    accumulated = 0.0
    for name, probability in probs.items():
        accumulated += probability
        if number < accumulated:
            return name
    return name  # number == 1.0 (R can reach 1 after normalisation)


def step(cell: tuple, probs: dict, rng: LCG, grid: tuple = None) -> tuple:
    """Next cell and chosen direction. With a grid, blocked or outside moves keep the cell."""
    name = choose_direction(probs, rng)
    dx, dy = DIRECTIONS[name]
    target = (cell[0] + dx, cell[1] + dy)
    if grid is not None and not is_free(target, grid):
        return cell, name
    return target, name


def theoretical_free(probs: dict, steps: int) -> dict:
    drift_x = probs["right"] - probs["left"]
    drift_y = probs["down"] - probs["up"]
    var_x = steps * ((probs["right"] + probs["left"]) - drift_x**2)
    var_y = steps * ((probs["up"] + probs["down"]) - drift_y**2)
    return {
        "E[X]": steps * drift_x,
        "E[Y]": steps * drift_y,
        "E[R2]": var_x + var_y + (steps * drift_x) ** 2 + (steps * drift_y) ** 2,
    }


def simulate_free(probs: dict, walkers: int, steps: int, rng: LCG) -> dict:
    finals = {"E[X]": [], "E[Y]": [], "E[R2]": []}
    mean_r2_by_step = [0.0] * steps
    direction_counts = dict.fromkeys(DIRECTIONS, 0)
    paths = []
    for walker in range(walkers):
        cell = (0, 0)
        path = [cell]
        for index in range(steps):
            cell, name = step(cell, probs, rng)
            direction_counts[name] += 1
            mean_r2_by_step[index] += (cell[0] ** 2 + cell[1] ** 2) / walkers
            if walker < TRACKED_PATHS:
                path.append(cell)
        if walker < TRACKED_PATHS:
            paths.append(path)
        finals["E[X]"].append(cell[0])
        finals["E[Y]"].append(cell[1])
        finals["E[R2]"].append(cell[0] ** 2 + cell[1] ** 2)
    return {"finals": finals, "mean_r2_by_step": mean_r2_by_step,
            "direction_counts": direction_counts, "paths": paths}


def simulate_platform(walkers: int, rng: LCG) -> dict:
    """Independent walkers from the entrance; the final cell of each is one occupancy sample."""
    grid = (PLATFORM_WIDTH, PLATFORM_HEIGHT, PLATFORM_BLOCKED)
    counts = {}
    invalid_cells = 0
    for _ in range(walkers):
        cell = PLATFORM_START
        for _ in range(MIXING_STEPS):
            cell, _ = step(cell, SYMMETRIC, rng, grid)
            invalid_cells += not is_free(cell, grid)
        counts[cell] = counts.get(cell, 0) + 1
    free_cells = [(x, y) for y in range(PLATFORM_HEIGHT) for x in range(PLATFORM_WIDTH)
                  if is_free((x, y), grid)]
    return {"counts": counts, "free_cells": free_cells, "invalid_cells": invalid_cells}


def chi_square(observed: list, expected: list) -> tuple:
    statistic = calcular_estadistico_chi_cuadrado(observed, expected)
    critical = valor_critico_chi_cuadrado(1 - NIVEL_DE_SIGNIFICANCIA, len(observed) - 1)
    return statistic, critical, statistic < critical


def report_free(name: str, probs: dict, result: dict, args) -> list:
    theory = theoretical_free(probs, args.steps)
    print(f"\n{name}: p = {probs}, n = {args.steps} pasos, {args.walkers} caminantes")
    print(f"  {'Métrica':<8}{'Teórico':>12}{'Simulado':>12}{'IC 95 %':>26}{'Dif.':>12}  ¿Teórico en IC?")
    rows = []
    for metric, theoretical in theory.items():
        mean, low, high = confidence_interval(result["finals"][metric])
        if theoretical == 0:
            diff_text, diff = f"{abs(mean):.3f} abs", None
        else:
            diff = abs(mean - theoretical) / abs(theoretical) * 100
            diff_text = f"{diff:.2f} %"
        inside = low <= theoretical <= high
        print(f"  {metric:<8}{theoretical:>12.3f}{mean:>12.3f}   [{low:>10.3f}, {high:>10.3f}]"
              f"{diff_text:>12}  {'sí' if inside else 'no'}")
        rows.append([name, metric, theoretical, mean, low, high, diff, inside])

    counts = result["direction_counts"]
    total = sum(counts.values())
    observed = [counts[d] for d in DIRECTIONS]
    expected = [probs[d] * total for d in DIRECTIONS]
    statistic, critical, passes = chi_square(observed, expected)
    shares = ", ".join(f"{d} {counts[d] / total:.4f}" for d in DIRECTIONS)
    print(f"  Frecuencia de direcciones: {shares}")
    print(f"  Chi-cuadrado direcciones: χ² = {statistic:.3f} < {critical:.3f} -> "
          f"{'pasa' if passes else 'NO pasa'}")
    return rows


def report_platform(result: dict, walkers: int) -> list:
    free_cells = result["free_cells"]
    expected_each = walkers / len(free_cells)
    observed = [result["counts"].get(cell, 0) for cell in free_cells]
    statistic, critical, passes = chi_square(observed, [expected_each] * len(free_cells))
    worst = max(abs(count - expected_each) / expected_each * 100 for count in observed)
    print(f"\nConfig 3 - andén con obstáculos: grilla {PLATFORM_WIDTH}x{PLATFORM_HEIGHT}, "
          f"{len(PLATFORM_BLOCKED)} celdas bloqueadas, {walkers} caminantes x {MIXING_STEPS} pasos")
    print(f"  Ocupación teórica por celda libre: 1/{len(free_cells)} = {1 / len(free_cells):.5f} "
          f"({expected_each:.1f} caminantes por celda)")
    print(f"  Chi-cuadrado ocupación uniforme: χ² = {statistic:.3f} < {critical:.3f} -> "
          f"{'pasa' if passes else 'NO pasa'}")
    print(f"  Mayor desviación de una celda respecto a lo esperado: {worst:.2f} %")
    print(f"  Pasos que terminaron fuera del mapa o en una celda bloqueada: {result['invalid_cells']}")
    return [["Config 3 - andén", "chi2_ocupacion", critical, statistic, None, None, worst, passes]]


def plot(symmetric: dict, biased: dict, platform: dict, args, show: bool) -> Path:
    fig, (ax_paths, ax_r2, ax_heat) = plt.subplots(1, 3, figsize=(17, 5))

    for result, label, color in ((symmetric, "Simétrica", "tab:blue"), (biased, "Sesgada (p→ = 0.40)", "tab:red")):
        for index, path in enumerate(result["paths"]):
            ax_paths.plot([c[0] for c in path], [c[1] for c in path], color=color, linewidth=0.8,
                          alpha=0.8, label=label if index == 0 else None)
    ax_paths.plot(0, 0, "ko", label="Origen")
    ax_paths.invert_yaxis()
    ax_paths.set(title=f"Trayectorias ({TRACKED_PATHS} por configuración)", xlabel="x (celdas)",
                 ylabel="y (celdas)")
    ax_paths.legend(fontsize=8)

    steps_axis = list(range(1, args.steps + 1))
    for result, probs, label in ((symmetric, SYMMETRIC, "Simétrica"), (biased, BIASED, "Sesgada")):
        line, = ax_r2.loglog(steps_axis, result["mean_r2_by_step"], linewidth=1.5, label=f"{label} simulada")
        ax_r2.loglog(steps_axis, [theoretical_free(probs, n)["E[R2]"] for n in steps_axis], "--",
                     color=line.get_color(), linewidth=1, label=f"{label} teoría")
    ax_r2.set(title="E[R²] frente a n (pendiente 1: difusión; 2: deriva)", xlabel="Pasos n",
              ylabel="E[R²] (celdas²)")
    ax_r2.legend(fontsize=8)

    expected_each = args.walkers_platform / len(platform["free_cells"])
    ratio = [[platform["counts"].get((x, y), 0) / expected_each
              if (x, y) not in PLATFORM_BLOCKED else math.nan
              for x in range(PLATFORM_WIDTH)] for y in range(PLATFORM_HEIGHT)]
    cmap = plt.get_cmap("coolwarm").copy()
    cmap.set_bad("dimgray")
    image = ax_heat.imshow(ratio, cmap=cmap, vmin=0.6, vmax=1.4)
    fig.colorbar(image, ax=ax_heat, label="Ocupación observada / esperada")
    ax_heat.set(title="Andén: ocupación estacionaria (gris = bloqueado)", xlabel="x", ylabel="y")

    fig.suptitle(f"Modelo 2 - Caminata aleatoria | {stamp()}")
    fig.tight_layout()
    path = RESULTS_DIR / "modelo2_caminata.png"
    fig.savefig(path, dpi=130)
    if show:
        plt.show()
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description="Modelo 2: caminata aleatoria con el LCG del Taller 1.")
    parser.add_argument("--seed", type=int, default=20261101)
    parser.add_argument("--walkers", type=int, default=1000, help="Caminantes de las configs 1 y 2.")
    parser.add_argument("--steps", type=int, default=1000, help="Pasos de las configs 1 y 2.")
    parser.add_argument("--walkers-platform", type=int, default=3000, help="Caminantes de la config 3.")
    parser.add_argument("--no-show", action="store_true", help="Guarda el gráfico sin abrir la ventana.")
    args = parser.parse_args()
    if args.walkers < 30 or args.steps < 1 or args.walkers_platform < 30:
        parser.error("Se requieren al menos 30 caminantes y 1 paso.")
    for probs in (SYMMETRIC, BIASED):
        if not math.isclose(sum(probs.values()), 1.0):
            raise ValueError(f"Las probabilidades deben sumar 1: {probs}")

    RESULTS_DIR.mkdir(exist_ok=True)
    print_header("MODELO 2 - CAMINATA ALEATORIA", Path(__file__).name, [
        f"Semilla      : {args.seed} | configs 1-2: {args.walkers} caminantes x {args.steps} pasos"
        f" | config 3: {args.walkers_platform} caminantes x {MIXING_STEPS} pasos",
    ])

    rng = LCG(args.seed)
    symmetric = simulate_free(SYMMETRIC, args.walkers, args.steps, rng)
    biased = simulate_free(BIASED, args.walkers, args.steps, rng)
    platform = simulate_platform(args.walkers_platform, rng)

    rows = report_free("Config 1 - simétrica libre", SYMMETRIC, symmetric, args)
    rows += report_free("Config 2 - sesgada libre", BIASED, biased, args)
    rows += report_platform(platform, args.walkers_platform)
    # P2-03 acceptance criterion: movement always stays inside valid cells.
    assert platform["invalid_cells"] == 0, "Un caminante salió de las celdas válidas."

    csv_path = RESULTS_DIR / "modelo2_caminata_resultados.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["config", "metrica", "teorico", "simulado", "ic_inferior", "ic_superior",
                         "diferencia_pct", "teorico_en_ic_o_pasa"])
        writer.writerows(rows)

    figure_path = plot(symmetric, biased, platform, args, show=not args.no_show)
    print(f"\nResultados: {csv_path}\nGráfico   : {figure_path}")


if __name__ == "__main__":
    main()
