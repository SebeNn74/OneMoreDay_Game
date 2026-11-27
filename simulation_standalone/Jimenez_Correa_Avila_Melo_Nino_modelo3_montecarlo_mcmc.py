"""Modelo 3 - Monte Carlo con cadenas de Markov (MCMC, Metropolis-Hastings).

Selección de eventos del día de One More Day. Módulo standalone: no depende del juego.

Problema
    Cada etapa del día (casa, ida, trabajo, vuelta) tiene un catálogo de eventos con pesos w_i
    (OneMoreDay_Diseño.xlsx, pestaña 3). Se quiere muestrear el evento i con probabilidad
    pi_i = w_i / sum(w), sin repetir eventos en el mismo día (pestaña 5).

Dos muestreadores
    1. Directo (Monte Carlo clásico): transformada inversa sobre los pesos acumulados.
    2. Metropolis-Hastings (MCMC): cadena de Markov sobre los eventos disponibles.
         X0 ~ U{0..n-1}
         propuesta j ~ U{0..n-1} (simétrica, incluye quedarse: la cadena es aperiódica)
         se acepta con alpha(i -> j) = min(1, w_j / w_i)
       Balance detallado: pi_i P_ij = pi_j P_ji, luego pi es la distribución estacionaria.
       Tras k pasos la distribución es mu_k = mu_0 P^k, que converge a pi a la tasa |lambda_2|^k.
       No necesita la constante de normalización sum(w).

Generador: congruencial lineal del Taller 1 (a = 1664525, c = 1013904223, m = 2^32), el mismo
que core/simulation.gd del juego, de modo que una semilla da los mismos eventos en Python y Godot.

Uso
    python Jimenez_Correa_Avila_Melo_Nino_modelo3_montecarlo_mcmc.py              # validación completa + gráficos
    python Jimenez_Correa_Avila_Melo_Nino_modelo3_montecarlo_mcmc.py --seed 777 --out resultados
"""

import argparse
import getpass
import math
import sys
from datetime import datetime
from pathlib import Path

import matplotlib

# The output has Greek letters (π, λ, χ²): Windows writes redirected output (> file, pipes) in cp1252,
# which has none of them and crashes. UTF-8 always.
sys.stdout.reconfigure(encoding="utf-8")

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy import stats


# ----------------------------------------------------------------------------- generador (Taller 1)
class Lcg:
    """X(n+1) = (A X(n) + C) mod M; R = X / (M - 1) truncado a 5 decimales (igual que lcg.gd)."""

    A, C, M = 1664525, 1013904223, 2**32

    def __init__(self, seed):
        self.state = seed % self.M

    def next(self):
        self.state = (self.A * self.state + self.C) % self.M
        return (self.state * 100000 // (self.M - 1)) / 100000

    def index(self, size):
        return min(int(self.next() * size), size - 1)


# ----------------------------------------------------------------------------- datos embebidos
# (id, etapa, peso) en el orden de data/events/event_catalog.tres. 0 casa, 1 ida, 2 trabajo, 3 vuelta.
EVENTS = [
    ("EV-01", 0, 3), ("EV-02", 0, 2), ("EV-03", 0, 2), ("EV-04", 0, 2), ("EV-05", 0, 2),
    ("EV-06", 1, 3), ("EV-07", 1, 3), ("EV-08", 1, 2), ("EV-09", 1, 2), ("EV-10", 1, 2), ("EV-11", 1, 2),
    ("EV-12", 2, 3), ("EV-13", 2, 3), ("EV-14", 2, 2), ("EV-15", 2, 2), ("EV-16", 2, 2), ("EV-17", 2, 2),
    ("EV-18", 2, 2),
    ("EV-19", 3, 2), ("EV-20", 3, 2), ("EV-21", 3, 3), ("EV-22", 3, 2), ("EV-23", 3, 2),
]
STAGES = {0: "Casa", 1: "Ida", 2: "Trabajo", 3: "Vuelta"}
GAME_STEPS = 10  # EventCatalog.mcmc_steps por defecto en el juego


# ----------------------------------------------------------------------------- muestreadores
def direct_index(weights, rng):
    """Monte Carlo clásico: transformada inversa (port de EventPicker._direct_index)."""
    target = rng.next() * sum(weights)
    accumulated = 0.0
    for i, w in enumerate(weights):
        accumulated += w
        if target < accumulated:
            return i
    return len(weights) - 1  # R == 1.0


def metropolis_index(weights, steps, rng, counter=None):
    """MCMC: cadena de Metropolis de `steps` transiciones (port de MetropolisSampler.sample).

    counter, si se pasa, acumula [propuestas, aceptadas] para medir la tasa de aceptación.
    """
    current = rng.index(len(weights))
    for _ in range(steps):
        proposal = rng.index(len(weights))
        ratio = weights[proposal] / weights[current]
        accepted = ratio >= 1.0 or rng.next() < ratio
        if counter is not None:
            counter[0] += 1
            counter[1] += accepted
        if accepted:
            current = proposal
    return current


def draw_without_replacement(pools, stage, rng, steps):
    """Un sorteo del día (port de EventPicker.draw). steps = 0 usa el sorteo directo."""
    pool = pools[stage]
    if not pool:
        return None
    weights = [float(w) for _, w in pool]
    i = metropolis_index(weights, steps, rng) if steps > 0 else direct_index(weights, rng)
    return pool.pop(i)[0]


def new_pools():
    pools = {s: [] for s in STAGES}
    for event_id, stage, weight in EVENTS:
        pools[stage].append((event_id, weight))
    return pools


# ----------------------------------------------------------------------------- teoría
def target(weights):
    w = np.asarray(weights, float)
    return w / w.sum()


def transition_matrix(weights):
    """P_ij = (1/n) min(1, w_j/w_i) para j != i; P_ii = 1 - suma del resto."""
    w = np.asarray(weights, float)
    n = len(w)
    p = np.minimum(1.0, w[None, :] / w[:, None]) / n
    np.fill_diagonal(p, 0.0)
    p[np.diag_indices(n)] = 1.0 - p.sum(axis=1)
    return p


def distribution_after(weights, steps):
    """mu_k = mu_0 P^k con mu_0 uniforme (X0 ~ U)."""
    n = len(weights)
    return np.full(n, 1.0 / n) @ np.linalg.matrix_power(transition_matrix(weights), steps)


def total_variation(p, q):
    return 0.5 * float(np.abs(np.asarray(p) - np.asarray(q)).sum())


def _acceptance_by_state(weights):
    """a_i = sum_j (1/n) min(1, w_j/w_i): probabilidad de aceptar estando en i."""
    w = np.asarray(weights, float)
    return np.minimum(1.0, w[None, :] / w[:, None]).mean(axis=1)


def acceptance_rate(weights):
    """Tasa de aceptación en estado estacionario: sum_i pi_i a_i."""
    return float(target(weights) @ _acceptance_by_state(weights))


def expected_acceptance(weights, steps):
    """Tasa esperada en una cadena de `steps` pasos desde X0 ~ U: (1/k) sum_t mu_t a."""
    if steps == 0:
        return float("nan")
    a = _acceptance_by_state(weights)
    return float(np.mean([distribution_after(weights, t) @ a for t in range(steps)]))


def second_eigenvalue(weights):
    return sorted(np.abs(np.linalg.eigvals(transition_matrix(weights))))[-2]


def steps_for(weights, tolerance):
    """Pasos mínimos para que TV(mu_k, pi) < tolerance."""
    pi = target(weights)
    k = 0
    while total_variation(distribution_after(weights, k), pi) >= tolerance:
        k += 1
    return k


# ----------------------------------------------------------------------------- experimentos
CONFIGS = [
    # (nombre, pesos, pasos k)
    ("1. Ida, k = 10 (juego)", [3, 3, 2, 2, 2, 2], 10),
    ("2. Ida, k = 1 (cadena corta)", [3, 3, 2, 2, 2, 2], 1),
    ("3. Pesos extremos, k = 10", [1, 1, 1, 1, 1, 10], 10),
]


def run_config(weights, steps, samples, seed):
    rng = Lcg(seed)
    counter = [0, 0]
    counts = np.zeros(len(weights))
    for _ in range(samples):
        counts[metropolis_index(weights, steps, rng, counter)] += 1
    empirical = counts / samples
    pi = target(weights)
    mu_k = distribution_after(weights, steps)
    chi_target = stats.chisquare(counts, pi * samples)
    chi_chain = stats.chisquare(counts, mu_k * samples)
    return {
        "pi": pi,
        "mu_k": mu_k,
        "empirical": empirical,
        "max_diff_pct": float(np.max(np.abs(empirical - pi) / pi) * 100),
        "tv_exact": total_variation(mu_k, pi),
        "tv_empirical": total_variation(empirical, pi),
        "chi_target_p": float(chi_target.pvalue),
        "chi_chain_p": float(chi_chain.pvalue),
        "acceptance_theory": expected_acceptance(weights, steps),
        "acceptance_observed": counter[1] / counter[0] if counter[0] else float("nan"),
    }


def ergodic_average(weights, length, seed):
    """Una cadena larga: frecuencia acumulada del estado 0 (promedio ergódico -> pi_0)."""
    rng = Lcg(seed)
    n = len(weights)
    current = rng.index(n)
    hits = np.zeros(length)
    for t in range(length):
        proposal = rng.index(n)
        ratio = weights[proposal] / weights[current]
        if ratio >= 1.0 or rng.next() < ratio:
            current = proposal
        hits[t] = current == 0
    return np.cumsum(hits) / np.arange(1, length + 1)


def plot_all(out, seed, results):
    out.mkdir(parents=True, exist_ok=True)

    # Figura 1: convergencia TV(mu_k, pi) teórica vs empírica.
    fig, ax = plt.subplots(figsize=(7, 4.5))
    ks = list(range(0, 31))
    for name, weights in [("Ida [3,3,2,2,2,2]", [3, 3, 2, 2, 2, 2]),
                          ("Trabajo [3,3,2,2,2,2,2]", [3, 3, 2, 2, 2, 2, 2]),
                          ("Extremos [1,1,1,1,1,10]", [1, 1, 1, 1, 1, 10])]:
        pi = target(weights)
        exact = [total_variation(distribution_after(weights, k), pi) for k in ks]
        line, = ax.semilogy(ks, [tv if tv > 1e-7 else np.nan for tv in exact],
                            label=f"{name} teórica, |λ2| = {second_eigenvalue(weights):.2f}")
        k_points = [0, 1, 2, 3, 5, 8, 12, 20, 30]
        emp = [run_config(weights, k, 5000, seed)["tv_empirical"] for k in k_points]
        ax.semilogy(k_points, emp, "o", color=line.get_color(), ms=4)
    # E[TV] de una muestra multinomial de N con p = π (aprox. normal): 0.5 sum sqrt(2 p(1-p) / (π N)).
    p = target([3, 3, 2, 2, 2, 2])
    noise = 0.5 * float(np.sum(np.sqrt(2 * p * (1 - p) / (math.pi * 5000))))
    ax.axhline(noise, ls=":", color="gray", label=f"ruido de muestreo esperado, N = 5000 ({noise:.3f})")
    ax.set_xlabel("pasos de la cadena k")
    ax.set_ylabel("distancia de variación total TV(μk, π)")
    ax.set_title("Convergencia de Metropolis-Hastings (puntos: empírico)")
    ax.legend(fontsize=7)
    fig.tight_layout()
    fig.savefig(out / "modelo3_mcmc_convergencia.png", dpi=150)
    plt.close(fig)

    # Figura 2: pi teórica vs frecuencia observada en las 3 configuraciones.
    fig, axes = plt.subplots(1, 3, figsize=(12, 3.8), sharey=True)
    for ax, (name, weights, steps) in zip(axes, CONFIGS):
        r = results[name]
        x = np.arange(len(weights))
        ax.bar(x - 0.2, r["pi"], 0.4, label="π teórica")
        ax.bar(x + 0.2, r["empirical"], 0.4, label="observada")
        ax.set_title(name, fontsize=9)
        ax.set_xticks(x, [f"e{i}" for i in x])
    axes[0].set_ylabel("probabilidad")
    axes[0].legend(fontsize=8)
    fig.suptitle("Distribución muestreada vs objetivo π_i = w_i / Σw")
    fig.tight_layout()
    fig.savefig(out / "modelo3_mcmc_distribuciones.png", dpi=150)
    plt.close(fig)

    # Figura 3: promedio ergódico de una cadena larga y error ~ 1/sqrt(N).
    weights = [3, 3, 2, 2, 2, 2]
    pi0 = target(weights)[0]
    running = ergodic_average(weights, 200000, seed)
    n = np.arange(1, len(running) + 1)
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(11, 4))
    a1.semilogx(n, running, label="frecuencia acumulada de EV-06")
    a1.axhline(pi0, color="k", ls="--", label=f"π = {pi0:.4f}")
    a1.set_xlabel("pasos N")
    a1.set_ylabel("frecuencia")
    a1.legend()
    a1.set_title("Promedio ergódico de la cadena")
    a2.loglog(n[99:], np.abs(running[99:] - pi0), lw=0.6, label="|error|")
    a2.loglog(n[99:], 1 / np.sqrt(n[99:]), "k--", label="1/√N")
    a2.set_xlabel("pasos N")
    a2.legend()
    a2.set_title("El error decrece en O(1/√N)")
    fig.tight_layout()
    fig.savefig(out / "modelo3_mcmc_ergodico.png", dpi=150)
    plt.close(fig)


# ----------------------------------------------------------------------------- comprobaciones
LEGACY_DIRECT_IDS = ["EV-06", "EV-07", "EV-10", "EV-16", "EV-18", "EV-12", "EV-14"]  # simulation_self_test.gd


def self_check():
    """Propiedades que deben cumplirse siempre. Falla con AssertionError si algo se rompe."""
    for weights in ([3, 3, 2, 2, 2, 2], [1, 1, 1, 1, 1, 10], [2]):
        p, pi = transition_matrix(weights), target(weights)
        assert np.allclose(p.sum(axis=1), 1.0), "P no es estocástica"
        assert np.allclose(pi @ p, pi), "pi no es estacionaria"
        flow = pi[:, None] * p
        assert np.allclose(flow, flow.T), "no hay balance detallado"
    assert np.allclose(distribution_after([3, 3, 2, 2, 2, 2], 0), 1 / 6), "mu_0 debe ser uniforme"
    # El sorteo directo debe reproducir el modelo anterior (self-test del juego).
    rng, pools = Lcg(12345), new_pools()
    ids = [draw_without_replacement(pools, 1, rng, 0) for _ in range(3)]
    ids += [draw_without_replacement(pools, 2, rng, 0) for _ in range(4)]
    assert ids == LEGACY_DIRECT_IDS, ids


def godot_expectations(seed=12345, steps=GAME_STEPS):
    """Valores de referencia para tools/simulation_self_test.gd."""
    rng, pools = Lcg(seed), new_pools()
    ids = [draw_without_replacement(pools, 1, rng, steps) for _ in range(3)]
    ids += [draw_without_replacement(pools, 2, rng, steps) for _ in range(4)]
    rng = Lcg(seed)
    counts = [0] * 6
    for _ in range(2000):
        counts[metropolis_index([3.0, 3.0, 2.0, 2.0, 2.0, 2.0], steps, rng)] += 1
    return ids, counts


# ----------------------------------------------------------------------------- main
def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--seed", type=int, default=12345)
    parser.add_argument("--samples", type=int, default=20000)
    parser.add_argument("--out", type=Path, default=Path(__file__).with_name("resultados"))
    args = parser.parse_args()

    print("=" * 78)
    print("Modelo 3 - Monte Carlo con cadenas de Markov (Metropolis-Hastings)")
    print(f"Fecha y hora: {datetime.now():%Y-%m-%d %H:%M:%S}   Usuario: {getpass.getuser()}")
    print(f"Generador: LCG Taller 1 (a={Lcg.A}, c={Lcg.C}, m=2^32)   Semilla: {args.seed}   "
          f"Muestras por configuración: {args.samples}")
    print("=" * 78)

    self_check()
    print("Comprobaciones: P estocástica, πP = π, balance detallado, sorteo directo = modelo anterior: OK\n")

    print("Mezcla de los catálogos del juego (pasos para TV < 1e-3):")
    pools = new_pools()
    for stage, name in STAGES.items():
        w = [float(wt) for _, wt in pools[stage]]
        print(f"  {name:8s} pesos {[int(x) for x in w]}  |λ2| = {second_eigenvalue(w):.3f}  "
              f"k = {steps_for(w, 1e-3)}  aceptación teórica = {acceptance_rate(w):.3f}")
    print()

    results = {}
    print(f"{'Configuración':32s} {'TV(μk,π) teo':>12s} {'TV obs':>8s} {'máx dif %':>9s} "
          f"{'p χ² vs π':>10s} {'p χ² vs μk':>10s} {'acept teo':>9s} {'acept obs':>9s}")
    for name, weights, steps in CONFIGS:
        r = run_config(weights, steps, args.samples, args.seed)
        results[name] = r
        print(f"{name:32s} {r['tv_exact']:12.5f} {r['tv_empirical']:8.4f} {r['max_diff_pct']:9.2f} "
              f"{r['chi_target_p']:10.4f} {r['chi_chain_p']:10.4f} "
              f"{r['acceptance_theory']:9.4f} {r['acceptance_observed']:9.4f}")
        print(f"{'':4s}π teórica : {np.round(r['pi'], 4)}")
        print(f"{'':4s}observada : {np.round(r['empirical'], 4)}")
    print("\nLectura: p χ² vs π < 0.05 indica que la cadena todavía no alcanzó π (falta burn-in);")
    print("p χ² vs μk > 0.05 indica que el programa coincide con la distribución exacta tras k pasos.\n")

    ids, counts = godot_expectations(args.seed)
    print(f"Referencia para simulation_self_test.gd (semilla {args.seed}, k = {GAME_STEPS}):")
    print(f"  MCMC_EVENT_IDS = {ids}")
    print(f"  MCMC_COUNTS    = {counts}   (2000 muestras de [3,3,2,2,2,2])")

    plot_all(args.out, args.seed, results)
    print(f"\nGráficos guardados en {args.out.resolve()}")


if __name__ == "__main__":
    main()
