"""Modelo 3 - Simulación Monte Carlo de la jornada (One More Day).

Sortea los eventos del día según sus pesos (sin reemplazo: un evento no se repite en la
partida) y simula jornadas completas para estimar el resultado esperado de los recursos
y la probabilidad de victoria de dos tipos de jugador. Es la herramienta de balance de
P2-11 / P4-13.

Datos embebidos: OneMoreDay_Diseño.xlsx (Miguel Ávila, P4), pestañas Guía, 2 Flujo,
3 Eventos, 4 Decisiones, 5 Reglas y 8 Balance.
Tipología: simulación Monte Carlo estática por réplicas (cada réplica = una jornada).
PRNG: congruencial lineal del Taller 1, punto 3 (ver prng.py).

Uso:
    python jimenez_poveda_modelo3_montecarlo.py [--seed N] [--days N] [--no-show]
"""
import argparse
import csv
from pathlib import Path
from typing import NamedTuple

import matplotlib.pyplot as plt

from common import confidence_interval, print_header, stamp
from prng import LCG
from punto3_generadores_pseudoaleatorios.pruebas import (
    NIVEL_DE_SIGNIFICANCIA,
    calcular_estadistico_chi_cuadrado,
    valor_critico_chi_cuadrado,
)


class Event(NamedTuple):
    id: str
    money: int
    energy: int
    time: int
    weight: int


class Scenario(NamedTuple):
    name: str
    stage: str
    events: int
    npc: str | None
    consumes: bool  # base consumption and hostiles (Casa has neither, tab 8)


RESOURCES = ("money", "energy", "time")
INITIAL = {"money": 30, "energy": 100, "time": 100}
ENERGY_MAX = 100
MONEY_POINTS = 3          # value of 1 money unit when comparing options (Guía)
HOSTILES_PER_SCENARIO = 2
HIT_DAMAGE = {"money": 0, "energy": -5, "time": -2}

# Tab 3 Eventos: (id, Δ money, Δ energy, Δ time, weight).
EVENTS = {
    "casa": [Event("EV-01", 0, 5, 0, 3), Event("EV-02", -3, 0, 0, 2), Event("EV-03", 5, 0, 0, 2),
             Event("EV-04", 0, 5, -5, 2), Event("EV-05", 0, -5, -5, 2)],
    "ida": [Event("EV-06", 0, 0, -10, 3), Event("EV-07", 0, -10, 0, 3), Event("EV-08", 0, -5, -5, 2),
            Event("EV-09", 5, 0, 0, 2), Event("EV-10", -2, 0, 10, 2), Event("EV-11", 0, 10, 0, 2)],
    "trabajo": [Event("EV-12", 0, -10, -10, 3), Event("EV-13", 0, -5, -10, 3), Event("EV-14", 0, 10, 0, 2),
                Event("EV-15", 0, 10, -5, 2), Event("EV-16", 10, -15, -5, 2), Event("EV-17", -5, 0, 0, 2),
                Event("EV-18", -3, 15, -5, 2)],
    "vuelta": [Event("EV-19", 0, -5, -15, 2), Event("EV-20", -5, 0, 0, 2), Event("EV-21", 0, 10, 0, 3),
               Event("EV-22", -5, 5, 10, 2), Event("EV-23", 10, 0, 0, 2)],
}
# Tab 4 Decisiones: options A, B, C as (Δ money, Δ energy, Δ time).
DECISIONS = {
    "NPC-01": [(-2, 10, -5), (0, -5, 5), (0, 5, -5)],
    "NPC-02": [(-3, 0, 10), (0, -3, -2), (-2, 0, 5)],
    "NPC-03": [(5, -10, -5), (-2, 10, -5), (0, -5, 5)],
    "NPC-04": [(10, -15, -10), (-5, 5, 10), (0, -5, 5)],
    "NPC-05": [(-3, 15, -5), (0, -5, 5), (-1, 5, 0)],
    "NPC-06": [(0, 10, -10), (0, 0, 5), (4, -10, -5)],
}
# Tabs 2 Flujo and 5 Reglas. El Marcador (Trabajo 3) is not modelled here.
FLOW = [
    Scenario("Casa", "casa", 1, None, False),
    Scenario("Ida 1", "ida", 1, "NPC-01", True),
    Scenario("Ida 2", "ida", 1, "NPC-02", True),
    Scenario("Ida 3", "ida", 1, None, True),
    Scenario("Trabajo 1", "trabajo", 2, "NPC-03", True),
    Scenario("Trabajo 2", "trabajo", 1, "NPC-04", True),
    Scenario("Trabajo 3", "trabajo", 1, None, True),
    Scenario("Vuelta 1", "vuelta", 1, "NPC-05", True),
    Scenario("Vuelta 2", "vuelta", 1, None, True),
    Scenario("Vuelta 3", "vuelta", 1, "NPC-06", True),
]
# Three parameter configurations for the validation table (config 1 = current design).
CONFIGS = [
    {"name": "Config 1 - diseño actual", "base_energy": -5, "base_time": -6,
     "hit_prob": {"ida": 0.30, "trabajo": 0.35, "vuelta": 0.40}},
    {"name": "Config 2 - hostiles +10 pp", "base_energy": -5, "base_time": -6,
     "hit_prob": {"ida": 0.40, "trabajo": 0.45, "vuelta": 0.50}},
    {"name": "Config 3 - escenarios más cortos", "base_energy": -5, "base_time": -5,
     "hit_prob": {"ida": 0.30, "trabajo": 0.35, "vuelta": 0.40}},
]
REFERENCE_WIN_RATE = {"random": 0.37, "careful": 0.83}  # tab 8, Miguel's own simulation
PLAYER_NAMES = {"random": "Elige al azar", "careful": "Jugador cuidadoso"}
DEFEAT_NAMES = {"money": "D-01 dinero", "energy": "D-02 energía", "time": "D-03 tiempo"}
SAMPLER_DRAWS = 20000
RESULTS_DIR = Path(__file__).parent / "resultados"


def draws_per_stage() -> dict:
    counts = {}
    for scenario in FLOW:
        counts[scenario.stage] = counts.get(scenario.stage, 0) + scenario.events
    return counts


def draw_without_replacement(pool: list, rng: LCG) -> Event:
    """Weighted draw that removes the chosen event from `pool`."""
    target = rng.next() * sum(event.weight for event in pool)
    accumulated = 0
    for index, event in enumerate(pool):
        accumulated += event.weight
        if target < accumulated:
            return pool.pop(index)
    return pool.pop()  # R == 1.0


def inclusion_probabilities(events: list, draws: int) -> dict:
    """Exact P(event appears in `draws` weighted draws without replacement), by enumeration."""
    result = dict.fromkeys((event.id for event in events), 0.0)

    def walk(pool: list, remaining: int, probability: float) -> None:
        if remaining == 0:
            return
        total = sum(event.weight for event in pool)
        for index, event in enumerate(pool):
            branch = probability * event.weight / total
            result[event.id] += branch
            walk(pool[:index] + pool[index + 1:], remaining - 1, branch)

    walk(list(events), draws, 1.0)
    return result


def theoretical_final(config: dict) -> dict:
    """E[final resources] for the random player without clamping or stopping (linearity of expectation)."""
    final = dict(INITIAL)
    for stage, draws in draws_per_stage().items():
        inclusion = inclusion_probabilities(EVENTS[stage], draws)
        for event in EVENTS[stage]:
            for resource in RESOURCES:
                final[resource] += inclusion[event.id] * getattr(event, resource)
    for scenario in FLOW:
        if scenario.npc:
            options = DECISIONS[scenario.npc]
            for position, resource in enumerate(RESOURCES):
                final[resource] += sum(option[position] for option in options) / len(options)
        if scenario.consumes:
            final["energy"] += config["base_energy"]
            final["time"] += config["base_time"]
            hits = HOSTILES_PER_SCENARIO * config["hit_prob"][scenario.stage]
            for resource in RESOURCES:
                final[resource] += hits * HIT_DAMAGE[resource]
    return final


def choose_option(options: list, player: str, state: dict, rng: LCG) -> tuple:
    if player == "random":
        return options[min(int(rng.next() * len(options)), len(options) - 1)]
    # Careful player (tab 8): protect the lowest resource, money measured in points.
    points = {"money": state["money"] * MONEY_POINTS, "energy": state["energy"], "time": state["time"]}
    lowest = RESOURCES.index(min(points, key=points.get))
    return max(options, key=lambda o: (o[lowest], o[0] * MONEY_POINTS + o[1] + o[2]))


def simulate_day(config: dict, player: str, rng: LCG, game_rules: bool) -> tuple:
    """One full day. Returns (final state, defeat cause or None).

    game_rules=True applies the energy cap of 100 and records the first resource that
    reaches 0 (design rule). game_rules=False is the unbounded day used to check theory.
    """
    state = dict(INITIAL)
    defeat = None
    pools = {stage: list(events) for stage, events in EVENTS.items()}

    def apply(change: tuple) -> None:
        nonlocal defeat
        for position, resource in enumerate(RESOURCES):
            state[resource] += change[position]
        if game_rules:
            state["energy"] = min(state["energy"], ENERGY_MAX)
            if defeat is None:
                defeat = next((r for r in RESOURCES if state[r] <= 0), None)

    hit = tuple(HIT_DAMAGE[resource] for resource in RESOURCES)
    for scenario in FLOW:
        if scenario.consumes:
            apply((0, config["base_energy"], config["base_time"]))
        for _ in range(scenario.events):
            event = draw_without_replacement(pools[scenario.stage], rng)
            apply((event.money, event.energy, event.time))
        if scenario.npc:
            apply(choose_option(DECISIONS[scenario.npc], player, state, rng))
        if scenario.consumes:
            for _ in range(HOSTILES_PER_SCENARIO):
                if rng.next() < config["hit_prob"][scenario.stage]:
                    apply(hit)
    return state, defeat


def chi_square(observed: list, expected: list) -> tuple:
    statistic = calcular_estadistico_chi_cuadrado(observed, expected)
    critical = valor_critico_chi_cuadrado(1 - NIVEL_DE_SIGNIFICANCIA, len(observed) - 1)
    return statistic, critical, statistic < critical


def validate_sampler(rng: LCG) -> dict:
    """Ida stage: first draw against w/W and inclusion in 3 draws against the exact value."""
    events = EVENTS["ida"]
    draws = draws_per_stage()["ida"]
    first_counts = dict.fromkeys((e.id for e in events), 0)
    inclusion_counts = dict.fromkeys((e.id for e in events), 0)
    for _ in range(SAMPLER_DRAWS):
        pool = list(events)
        for position in range(draws):
            event = draw_without_replacement(pool, rng)
            inclusion_counts[event.id] += 1
            if position == 0:
                first_counts[event.id] += 1
    total_weight = sum(e.weight for e in events)
    expected_first = [SAMPLER_DRAWS * e.weight / total_weight for e in events]
    statistic, critical, passes = chi_square([first_counts[e.id] for e in events], expected_first)
    exact = inclusion_probabilities(events, draws)
    simulated = {key: count / SAMPLER_DRAWS for key, count in inclusion_counts.items()}

    print(f"\nValidación del sorteo (etapa Ida, {SAMPLER_DRAWS} jornadas, {draws} eventos sin reemplazo):")
    print(f"  {'Evento':<7}{'Peso':>5}{'p 1.er sorteo':>15}{'Obs.':>8}{'π exacta':>11}{'π simulada':>12}"
          f"{'Con reemplazo k·p':>19}")
    for event, expected in zip(events, expected_first):
        p = event.weight / total_weight
        print(f"  {event.id:<7}{event.weight:>5}{p:>15.4f}{first_counts[event.id] / SAMPLER_DRAWS:>8.4f}"
              f"{exact[event.id]:>11.4f}{simulated[event.id]:>12.4f}{draws * p:>19.4f}")
    print(f"  Chi-cuadrado del primer sorteo: χ² = {statistic:.3f} < {critical:.3f} -> "
          f"{'pasa' if passes else 'NO pasa'}")
    return {"events": events, "exact": exact, "simulated": simulated, "draws": draws}


def compare_replacement() -> None:
    """Expected Δ of the events of each stage: tab 8 (with replacement) against the real rule."""
    print("\nE[Δ eventos] por etapa: con reemplazo (cálculo de la pestaña 8) vs sin reemplazo (regla real)")
    for stage, draws in draws_per_stage().items():
        events = EVENTS[stage]
        total_weight = sum(e.weight for e in events)
        inclusion = inclusion_probabilities(events, draws)
        with_r = [draws * sum(e.weight * getattr(e, r) for e in events) / total_weight for r in RESOURCES]
        without_r = [sum(inclusion[e.id] * getattr(e, r) for e in events) for r in RESOURCES]
        print(f"  {stage:<8} con: ({with_r[0]:+6.2f}, {with_r[1]:+6.2f}, {with_r[2]:+6.2f})"
              f"   sin: ({without_r[0]:+6.2f}, {without_r[1]:+6.2f}, {without_r[2]:+6.2f})")


def run_config(config: dict, days: int, rng: LCG, track_convergence: bool) -> dict:
    theory = theoretical_final(config)
    unbounded = [simulate_day(config, "random", rng, game_rules=False)[0] for _ in range(days)]
    print(f"\n{config['name']}: base E {config['base_energy']}, base T {config['base_time']}, "
          f"P(golpe) {config['hit_prob']}")
    print(f"  Jugador al azar, sin topes ni derrota ({days} jornadas):")
    print(f"  {'Recurso final':<15}{'Teórico':>10}{'Simulado':>10}{'IC 95 %':>22}{'Dif. %':>9}  ¿Teórico en IC?")
    rows = []
    for resource in RESOURCES:
        mean, low, high = confidence_interval([day[resource] for day in unbounded])
        diff = abs(mean - theory[resource]) / abs(theory[resource]) * 100
        inside = low <= theory[resource] <= high
        print(f"  {resource:<15}{theory[resource]:>10.3f}{mean:>10.3f}   [{low:>8.3f}, {high:>8.3f}]"
              f"{diff:>8.2f}%  {'sí' if inside else 'no'}")
        rows.append([config["name"], f"final_{resource}", theory[resource], mean, low, high, diff, inside])

    result = {"config": config, "theory": theory, "unbounded": unbounded, "win": {}, "convergence": {}}
    print("  Con reglas del juego (tope de energía 100, derrota al llegar a 0):")
    for player in ("random", "careful"):
        defeats = [simulate_day(config, player, rng, game_rules=True)[1] for _ in range(days)]
        wins = [1 if cause is None else 0 for cause in defeats]
        mean, low, high = confidence_interval(wins)
        causes = ", ".join(f"{DEFEAT_NAMES[r]} {defeats.count(r) / days:.1%}" for r in RESOURCES)
        reference = REFERENCE_WIN_RATE[player] if config is CONFIGS[0] else None
        reference_text = f" | pestaña 8: {reference:.0%}" if reference is not None else ""
        print(f"    {PLAYER_NAMES[player]:<18} P(victoria) = {mean:.3f} [{low:.3f}, {high:.3f}]"
              f"{reference_text} | derrotas: {causes}")
        rows.append([config["name"], f"p_victoria_{player}", reference, mean, low, high, None, None])
        result["win"][player] = (mean, low, high)
        if track_convergence:
            running, total = [], 0
            for count, win in enumerate(wins, start=1):
                total += win
                running.append(total / count)
            result["convergence"][player] = running
    result["rows"] = rows
    return result


def plot(sampler: dict, results: list, show: bool) -> Path:
    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    ax_incl, ax_conv, ax_hist, ax_win = axes.flat

    ids = [e.id for e in sampler["events"]]
    positions = range(len(ids))
    ax_incl.bar([p - 0.2 for p in positions], [sampler["exact"][i] for i in ids], 0.4, label="π exacta")
    ax_incl.bar([p + 0.2 for p in positions], [sampler["simulated"][i] for i in ids], 0.4, label="π simulada")
    total_weight = sum(e.weight for e in sampler["events"])
    ax_incl.plot(list(positions), [sampler["draws"] * e.weight / total_weight for e in sampler["events"]],
                 "k_", markersize=25, label="k·p (con reemplazo)")
    ax_incl.set_xticks(list(positions), ids)
    ax_incl.set(title=f"Ida: probabilidad de que salga cada evento ({sampler['draws']} sorteos sin reemplazo)",
                ylabel="Probabilidad")
    ax_incl.legend(fontsize=8)

    base = results[0]
    for player, color in (("random", "tab:orange"), ("careful", "tab:green")):
        running = base["convergence"][player]
        n_axis = range(1, len(running) + 1)
        final = running[-1]
        ax_conv.plot(n_axis, running, color=color, linewidth=1, label=PLAYER_NAMES[player])
        band = [1.96 * (final * (1 - final) / n) ** 0.5 for n in n_axis]
        ax_conv.fill_between(n_axis, [final - b for b in band], [final + b for b in band], color=color, alpha=0.15)
    ax_conv.set(title="Convergencia de P(victoria), config 1 (banda ±1.96·√(p(1−p)/N))",
                xlabel="Jornadas simuladas N", ylabel="P(victoria) acumulada", ylim=(0, 1))
    ax_conv.legend(fontsize=8)

    times = [day["time"] for day in base["unbounded"]]
    # Final times are integers: integer-aligned bins avoid empty-bin artefacts.
    ax_hist.hist(times, bins=range(int(min(times)) - 5, int(max(times)) + 10, 5), alpha=0.7, color="tab:blue")
    ax_hist.axvline(0, color="red", linestyle="--", label="Tiempo = 0 (derrota D-03)")
    ax_hist.axvline(base["theory"]["time"], color="black", label=f"E[T final] = {base['theory']['time']:.2f}")
    ax_hist.set(title="Tiempo final, config 1, jugador al azar sin derrota", xlabel="Tiempo final",
                ylabel="Jornadas")
    ax_hist.legend(fontsize=8)

    width = 0.38
    for offset, player, color in ((-width / 2, "random", "tab:orange"), (width / 2, "careful", "tab:green")):
        means = [r["win"][player][0] for r in results]
        errors = [r["win"][player][0] - r["win"][player][1] for r in results]
        ax_win.bar([i + offset for i in range(len(results))], means, width, yerr=errors, capsize=4,
                   color=color, label=PLAYER_NAMES[player])
    ax_win.set_xticks(range(len(results)), [r["config"]["name"].split(" - ")[1] for r in results])
    ax_win.set(title="Sensibilidad: P(victoria) por configuración (IC 95 %)", ylabel="P(victoria)", ylim=(0, 1))
    ax_win.legend(fontsize=8)

    fig.suptitle(f"Modelo 3 - Monte Carlo de la jornada | {stamp()}")
    fig.tight_layout()
    path = RESULTS_DIR / "modelo3_montecarlo.png"
    fig.savefig(path, dpi=130)
    if show:
        plt.show()
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description="Modelo 3: Monte Carlo de la jornada con el LCG del Taller 1.")
    parser.add_argument("--seed", type=int, default=20261101)
    parser.add_argument("--days", type=int, default=10000, help="Jornadas por configuración y jugador.")
    parser.add_argument("--no-show", action="store_true", help="Guarda el gráfico sin abrir la ventana.")
    args = parser.parse_args()
    if args.days < 30:
        parser.error("Se requieren al menos 30 jornadas.")
    for npc, options in DECISIONS.items():
        if len(options) != 3:
            raise ValueError(f"{npc} debe tener 3 opciones.")

    RESULTS_DIR.mkdir(exist_ok=True)
    print_header("MODELO 3 - MONTE CARLO", Path(__file__).name, [
        f"Semilla      : {args.seed} | jornadas por configuración y jugador: {args.days}",
        "Datos        : OneMoreDay_Diseño.xlsx (23 eventos, 6 NPC, 10 escenarios)",
    ])

    rng = LCG(args.seed)
    sampler = validate_sampler(rng)
    compare_replacement()
    results = [run_config(config, args.days, rng, track_convergence=index == 0)
               for index, config in enumerate(CONFIGS)]

    csv_path = RESULTS_DIR / "modelo3_montecarlo_resultados.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["config", "metrica", "teorico_o_referencia", "simulado", "ic_inferior",
                         "ic_superior", "diferencia_pct", "teorico_en_ic"])
        for result in results:
            writer.writerows(result["rows"])

    figure_path = plot(sampler, results, show=not args.no_show)
    print(f"\nResultados: {csv_path}\nGráfico   : {figure_path}")


if __name__ == "__main__":
    main()
