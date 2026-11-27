"""Modelo 1 - Sistema de colas M/M/1 (One More Day).

Fila de atención (paradero del bus o ventanilla de trámite) que el protagonista hace
durante la jornada. La espera se descuenta del tiempo del jugador.

Tipología: simulación de eventos discretos (llegada, inicio de servicio, salida).
PRNG: congruencial lineal del Taller 1, punto 3 (ver prng.py).
Unidades: minutos de juego.

Uso:
    python jimenez_poveda_modelo1_colas.py [--seed N] [--customers N] [--reps N] [--no-show]
"""
import argparse
import csv
import math
from pathlib import Path
from statistics import fmean

import matplotlib.pyplot as plt

from common import confidence_interval, print_header, stamp
from prng import LCG
from punto3_generadores_pseudoaleatorios.pruebas import prueba_chi_cuadrado, prueba_de_medias

# Embedded test data: three configurations for the validation table.
# Config 3 has the same rho as config 1 but a faster scale: same Lq, different Wq.
CONFIGS = [
    {"name": "Config 1 - flujo bajo", "lam": 0.5, "mu": 1.0},
    {"name": "Config 2 - hora pico", "lam": 0.8, "mu": 1.0},
    {"name": "Config 3 - ventanilla rápida", "lam": 0.8, "mu": 1.6},
]
SWEEP_RHOS = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
SWEEP_REPS = 5
METRICS = ["rho", "L", "Lq", "W", "Wq"]
RESULTS_DIR = Path(__file__).parent / "resultados"


def theoretical_mm1(lam: float, mu: float) -> dict:
    rho = lam / mu
    return {
        "rho": rho,
        "L": rho / (1 - rho),
        "Lq": rho**2 / (1 - rho),
        "W": 1 / (mu - lam),
        "Wq": lam / (mu * (mu - lam)),
    }


def simulate_mm1(lam: float, mu: float, customers: int, warmup: int, rng: LCG) -> dict:
    """One FIFO single-server run. The first `warmup` customers are discarded (transient)."""
    arrival = 0.0
    server_free_at = 0.0
    window_start = None
    busy_time = 0.0
    waits_queue = []
    waits_system = []
    for index in range(customers):
        arrival += rng.exponential(lam)           # arrival event
        service = rng.exponential(mu)
        start = max(arrival, server_free_at)      # service-start event
        server_free_at = start + service          # departure event
        if index < warmup:
            continue
        if window_start is None:
            window_start = arrival
        busy_time += service
        waits_queue.append(start - arrival)
        waits_system.append(server_free_at - arrival)
    horizon = server_free_at - window_start
    # L and Lq as time averages via the sample-path Little identity: integral of N(t) = sum of sojourns.
    return {
        "rho": busy_time / horizon,
        "L": sum(waits_system) / horizon,
        "Lq": sum(waits_queue) / horizon,
        "W": fmean(waits_system),
        "Wq": fmean(waits_queue),
        "waits_queue": waits_queue,
        "waits_system": waits_system,
    }


def sample_player_wait(lam: float, mu: float, rng: LCG) -> float:
    """Wait of the player arriving at a queue in steady state (what the game uses).

    With probability 1 - rho the server is free (wait 0); otherwise the wait is Exp(mu - lam).
    Its mean is rho / (mu - lam) = Wq.
    """
    if rng.next() >= lam / mu:
        return 0.0
    return rng.exponential(mu - lam)


def check_generator(seed: int) -> None:
    rng = LCG(seed)
    numbers = [rng.next() for _ in range(10000)]
    means = prueba_de_medias(numbers)
    chi = prueba_chi_cuadrado(numbers, 100)
    print("\nValidación del generador (10 000 números, α = 0.05):")
    print(f"  Prueba de medias : media = {means['estadistico']:.5f} "
          f"en [{means['limite_inferior']:.5f}, {means['limite_superior']:.5f}] -> "
          f"{'pasa' if means['pasa'] else 'NO pasa'}")
    print(f"  Chi-cuadrado     : χ² = {chi['estadistico']:.3f} < {chi['valor_critico']:.3f} -> "
          f"{'pasa' if chi['pasa'] else 'NO pasa'}")
    print(f"  Primeros R (referencia para el port a GDScript): {numbers[:3]}")


def run_config(config: dict, args, rng: LCG) -> dict:
    lam, mu = config["lam"], config["mu"]
    theory = theoretical_mm1(lam, mu)
    runs = [simulate_mm1(lam, mu, args.customers, args.warmup, rng) for _ in range(args.reps)]
    player_waits = [sample_player_wait(lam, mu, rng) for _ in range(args.customers)]

    print(f"\n{config['name']}: λ = {lam}/min, μ = {mu}/min, ρ = {theory['rho']:.3f}")
    print(f"  {'Métrica':<7}{'Teórico':>10}{'Simulado':>10}{'IC 95 %':>22}{'Dif. %':>9}  ¿Teórico en IC?")
    rows = []
    for metric in METRICS:
        mean, low, high = confidence_interval([run[metric] for run in runs])
        diff = abs(mean - theory[metric]) / theory[metric] * 100
        inside = low <= theory[metric] <= high
        print(f"  {metric:<7}{theory[metric]:>10.4f}{mean:>10.4f}   [{low:>8.4f}, {high:>8.4f}]"
              f"{diff:>8.2f}%  {'sí' if inside else 'no'}")
        rows.append([config["name"], lam, mu, metric, theory[metric], mean, low, high, diff, inside])
    player_mean = fmean(player_waits)
    print(f"  Espera del jugador (muestreo usado en el juego): media = {player_mean:.4f} min "
          f"vs Wq = {theory['Wq']:.4f} ({abs(player_mean - theory['Wq']) / theory['Wq'] * 100:.2f} %)")
    return {"config": config, "theory": theory, "runs": runs, "rows": rows}


def run_sweep(args, rng: LCG) -> list:
    """Sensitivity: Wq against rho with mu = 1."""
    points = []
    for rho in SWEEP_RHOS:
        values = [simulate_mm1(rho, 1.0, args.customers, args.warmup, rng)["Wq"] for _ in range(SWEEP_REPS)]
        points.append((rho, fmean(values)))
    return points


def plot(results: list, sweep: list, show: bool) -> Path:
    fig, (ax_conv, ax_hist, ax_sens) = plt.subplots(1, 3, figsize=(17, 5))

    for result in results:
        waits = result["runs"][0]["waits_queue"]
        running, total = [], 0.0
        for count, wait in enumerate(waits, start=1):
            total += wait
            running.append(total / count)
        line, = ax_conv.plot(running, linewidth=1, label=result["config"]["name"])
        ax_conv.axhline(result["theory"]["Wq"], color=line.get_color(), linestyle="--", linewidth=1)
    ax_conv.set(title="Convergencia de Wq (réplica 1; línea discontinua = teoría)",
                xlabel="Cliente atendido", ylabel="Wq acumulado (min)")
    ax_conv.legend(fontsize=8)

    busy = results[1]
    lam, mu = busy["config"]["lam"], busy["config"]["mu"]
    waits = [w for run in busy["runs"] for w in run["waits_system"]]
    ax_hist.hist(waits, bins=60, density=True, alpha=0.6, label="Simulado")
    top = max(waits)
    xs = [top * i / 200 for i in range(201)]
    rate = mu - lam
    ax_hist.plot(xs, [rate * math.exp(-rate * x) for x in xs], "r-",
                 label=f"Teoría: Exp(μ−λ = {rate:.2f})")
    ax_hist.set(title=f"Distribución de W ({busy['config']['name']})",
                xlabel="Tiempo en el sistema (min)", ylabel="Densidad")
    ax_hist.legend(fontsize=8)

    fine = [i / 100 for i in range(5, 93)]
    ax_sens.plot(fine, [theoretical_mm1(r, 1.0)["Wq"] for r in fine], "k-", label="Teoría ρ²/(1−ρ)·(1/λ)")
    ax_sens.plot([p[0] for p in sweep], [p[1] for p in sweep], "o", label=f"Simulado ({SWEEP_REPS} réplicas)")
    ax_sens.set(title="Sensibilidad: Wq frente a ρ (μ = 1)", xlabel="ρ = λ/μ", ylabel="Wq (min)")
    ax_sens.legend(fontsize=8)

    fig.suptitle(f"Modelo 1 - Colas M/M/1 | {stamp()}")
    fig.tight_layout()
    path = RESULTS_DIR / "modelo1_colas.png"
    fig.savefig(path, dpi=130)
    if show:
        plt.show()
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description="Modelo 1: colas M/M/1 con el LCG del Taller 1.")
    parser.add_argument("--seed", type=int, default=20261101)
    parser.add_argument("--customers", type=int, default=20000)
    parser.add_argument("--warmup", type=int, default=2000)
    parser.add_argument("--reps", type=int, default=30)
    parser.add_argument("--no-show", action="store_true", help="Guarda el gráfico sin abrir la ventana.")
    args = parser.parse_args()
    if args.warmup >= args.customers or args.reps < 2:
        parser.error("Se requiere warmup < customers y al menos 2 réplicas.")
    for config in CONFIGS:
        if config["lam"] >= config["mu"]:
            raise ValueError(f"{config['name']}: λ debe ser menor que μ para que la cola sea estable.")

    RESULTS_DIR.mkdir(exist_ok=True)
    print_header("MODELO 1 - COLAS M/M/1", Path(__file__).name, [
        f"Semilla      : {args.seed} | clientes por réplica: {args.customers} "
        f"(calentamiento {args.warmup}) | réplicas: {args.reps}",
    ])
    check_generator(args.seed)

    rng = LCG(args.seed)
    results = [run_config(config, args, rng) for config in CONFIGS]
    sweep = run_sweep(args, rng)

    csv_path = RESULTS_DIR / "modelo1_colas_resultados.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["config", "lambda", "mu", "metrica", "teorico", "simulado",
                         "ic_inferior", "ic_superior", "diferencia_pct", "teorico_en_ic"])
        for result in results:
            writer.writerows(result["rows"])

    figure_path = plot(results, sweep, show=not args.no_show)
    print(f"\nResultados: {csv_path}\nGráfico   : {figure_path}")


if __name__ == "__main__":
    main()
