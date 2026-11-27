"""Modelo 5 - Dinámica de sistemas de los recursos (One More Day).

Stocks: energía E (0-100), tiempo T (0-100 = jornada) y dinero D; variable auxiliar:
progreso P dentro del escenario (px). Flujos continuos, integrados con Euler cada frame:

    dT/dt = -c                                   (el reloj siempre corre)
    dE/dt = -k·m(actividad)                      (caminar m = 1, correr m = RUN_DRAIN_FACTOR)
    dE/dt = r·(E_max - E)                        (sentado: recuperación)
    dP/dt = v(actividad)·g(E),  g(E) = 1 si E >= E_u, si no max(g_min, E/E_u)

Realimentación: poca energía -> caminar más lento -> el escenario dura más -> se gasta más
tiempo y más energía (ciclo reforzador). Descansar es el ciclo compensador: recupera
energía a costa de tiempo. El dinero solo cambia por pulsos (eventos, NPC), que vienen
del modelo 3.

Calibración: con energía normal, cruzar un escenario caminando cuesta exactamente el
consumo base del diseño (OneMoreDay_Diseño.xlsx, Guía): 5 de energía y 6 de tiempo.
Velocidades del repo (data/player/movement_config.tres): caminar 150 px/s, correr 220 px/s.

Tipología: simulación continua (EDO) integrada con Euler explícito.
PRNG: congruencial lineal del Taller 1, punto 3, solo para los eventos de la jornada.

Uso:
    python nino_nino_modelo5_dinamica.py [--seed N] [--dt S] [--no-show]
"""
import argparse
import csv
import math
from pathlib import Path

import matplotlib.pyplot as plt

from common import confidence_interval, print_header, stamp
from jimenez_poveda_modelo3_montecarlo import (
    CONFIGS, DECISIONS, ENERGY_MAX, EVENTS, FLOW, HIT_DAMAGE, HOSTILES_PER_SCENARIO, INITIAL,
    choose_option, draw_without_replacement,
)
from prng import LCG

SCENARIO_LENGTH = 640.0       # px, one screen (README: un escenario por pantalla)
WALK_SPEED = 150.0            # px/s
RUN_SPEED = 220.0             # px/s
BASE_ENERGY_COST = 5.0        # per scenario walking at normal energy (Guía)
BASE_TIME_COST = 4.5        # per scenario walking; Guía says 6, lowered after playtests (day ran out of time)
WALK_CROSSING = SCENARIO_LENGTH / WALK_SPEED          # s
DRAIN = BASE_ENERGY_COST / WALK_CROSSING              # k, energy per second walking
CLOCK = BASE_TIME_COST / WALK_CROSSING                # c, time units per second
RUN_DRAIN_FACTOR = 1.8        # proposal: running drains 1.8 times faster
FATIGUE_THRESHOLD = 30.0      # E_u: below it the character slows down
MIN_SPEED_FACTOR = 0.4        # g_min
REST_RATE = 0.15              # r, 1/s while sitting
REST_UNTIL = 60.0             # the resting policy sits until E >= 60
CRITICAL_ENERGY = math.sqrt(2 * BASE_ENERGY_COST * FATIGUE_THRESHOLD)  # E*, derived below
DT_SWEEP = [1.0, 0.5, 0.25, 0.1, 0.05, 1 / 60]
REST_START, REST_HORIZON = 20.0, 20.0
FATIGUE_START = 25.0
POLICIES = {"walk": "Siempre camina", "run": "Siempre corre", "rest": "Camina y descansa si E < 30"}
RESULTS_DIR = Path(__file__).parent / "resultados"


def speed_factor(energy: float) -> float:
    if energy >= FATIGUE_THRESHOLD:
        return 1.0
    return max(MIN_SPEED_FACTOR, energy / FATIGUE_THRESHOLD)


def derivatives(energy: float, activity: str) -> tuple:
    """(dE/dt, dT/dt, dP/dt) for the current activity: walk, run or rest."""
    if activity == "rest":
        return REST_RATE * (ENERGY_MAX - energy), -CLOCK, 0.0
    running = activity == "run"
    drain = DRAIN * (RUN_DRAIN_FACTOR if running else 1.0)
    speed = (RUN_SPEED if running else WALK_SPEED) * speed_factor(energy)
    return -drain, -CLOCK, speed


def euler_step(state: dict, activity: str, dt: float) -> dict:
    """One explicit Euler step; this is what ResourceDynamics.tick(delta, activity) ports to Godot."""
    d_energy, d_time, d_progress = derivatives(state["energy"], activity)
    return {
        "energy": min(max(state["energy"] + d_energy * dt, 0.0), ENERGY_MAX),
        "time": state["time"] + d_time * dt,
        "progress": state["progress"] + d_progress * dt,
        "money": state["money"],
    }


def integrate(state: dict, activity: str, dt: float, until, max_seconds: float = 120.0) -> tuple:
    """Integrates until until(state) is true, energy runs out or max_seconds. Returns (state, seconds, trace)."""
    elapsed = 0.0
    trace = [(0.0, dict(state))]
    while not until(state) and state["energy"] > 0 and elapsed < max_seconds:
        state = euler_step(state, activity, dt)
        elapsed += dt
        trace.append((elapsed, dict(state)))
    return state, elapsed, trace


def cross(energy: float, activity: str, dt: float) -> tuple:
    start = {"energy": energy, "time": 100.0, "progress": 0.0, "money": 0}
    return integrate(start, activity, dt, lambda s: s["progress"] >= SCENARIO_LENGTH)


# --- Analytic solutions used as theory ---

def rest_exact(energy0: float, seconds: float) -> float:
    return ENERGY_MAX - (ENERGY_MAX - energy0) * math.exp(-REST_RATE * seconds)


def crossing_exact(energy0: float) -> float | None:
    """Walking crossing time. With E0 >= E_u + k·t it is D/v. Below E_u, with g = E/E_u and
    E(t) = E0 - k t, P(t) = v/E_u·(E0 t - k t²/2) = D gives t = (E0 - sqrt(E0² - E*²)) / k,
    where E*² = 2 k D E_u / v = 2 · (base energy cost) · E_u. No real root (E0 < E*) means that,
    without the speed floor, the energy runs out before the exit.
    Returns None outside the two closed-form cases (crossing the threshold mid-scenario, or the
    final energy sqrt(E0² - E*²) falling below the floor g_min·E_u)."""
    if energy0 - BASE_ENERGY_COST >= FATIGUE_THRESHOLD:
        return WALK_CROSSING
    if energy0 > FATIGUE_THRESHOLD or energy0**2 < CRITICAL_ENERGY**2 + (MIN_SPEED_FACTOR * FATIGUE_THRESHOLD) ** 2:
        return None
    return (energy0 - math.sqrt(energy0**2 - CRITICAL_ENERGY**2)) / DRAIN


def report_row(rows: list, config: str, metric: str, theory: float, simulated: float) -> None:
    diff = abs(simulated - theory) / abs(theory) * 100
    print(f"  {metric:<26}{theory:>12.4f}{simulated:>12.4f}{diff:>10.3f} %")
    rows.append([config, metric, theory, simulated, diff])


def validate(dt: float) -> tuple:
    rows = []
    header = f"  {'Variable':<26}{'Teórico':>12}{'Euler':>12}{'Dif.':>12}"

    print(f"\nConfig 1 - descanso sentado: E0 = {REST_START}, r = {REST_RATE}/s, {REST_HORIZON} s, dt = {dt:.4f} s")
    print(header)
    rest_state = {"energy": REST_START, "time": 100.0, "progress": 0.0, "money": 0}
    steps = round(REST_HORIZON / dt)
    for _ in range(steps):
        rest_state = euler_step(rest_state, "rest", dt)
    report_row(rows, "Config 1", f"E({REST_HORIZON:.0f} s)", rest_exact(REST_START, REST_HORIZON), rest_state["energy"])
    report_row(rows, "Config 1", f"T({REST_HORIZON:.0f} s)", 100 - CLOCK * REST_HORIZON, rest_state["time"])
    errors = []
    for step_size in DT_SWEEP:
        state = {"energy": REST_START, "time": 100.0, "progress": 0.0, "money": 0}
        for _ in range(round(REST_HORIZON / step_size)):
            state = euler_step(state, "rest", step_size)
        errors.append((step_size, abs(state["energy"] - rest_exact(REST_START, REST_HORIZON))))
    print("  Error de Euler en E(20 s) según dt (orden 1: el error se reduce en proporción a dt):")
    for step_size, error in errors:
        print(f"    dt = {step_size:<8.4f} error = {error:.6f}   error/dt = {error / step_size:.4f}")

    for name, energy0 in (("Config 2 - cruce con energía normal", 100.0),
                          ("Config 3 - cruce con fatiga", FATIGUE_START)):
        exact_seconds = crossing_exact(energy0)
        state, seconds, _ = cross(energy0, "walk", dt)
        print(f"\n{name}: E0 = {energy0}, caminando, D = {SCENARIO_LENGTH:.0f} px, dt = {dt:.4f} s")
        print(header)
        label = name.split(" - ")[0]
        report_row(rows, label, "Duración del cruce (s)", exact_seconds, seconds)
        report_row(rows, label, "Energía gastada", DRAIN * exact_seconds, energy0 - state["energy"])
        report_row(rows, label, "Tiempo gastado", CLOCK * exact_seconds, 100.0 - state["time"])

    print(f"\nEnergía crítica E* = √(2·{BASE_ENERGY_COST:.0f}·{FATIGUE_THRESHOLD:.0f}) = {CRITICAL_ENERGY:.2f}: "
          "sin el piso de velocidad, por debajo de E* la energía se agota antes de la salida.")
    for energy0 in (18.0, 15.0, 10.0):
        state, seconds, _ = cross(energy0, "walk", dt)
        outcome = "cruza" if state["progress"] >= SCENARIO_LENGTH else "se agota la energía (derrota D-02)"
        print(f"  E0 = {energy0:>4}: {outcome} en {seconds:.2f} s, energía final {state['energy']:.2f}, "
              f"progreso {state['progress']:.0f}/{SCENARIO_LENGTH:.0f} px")
    return rows, errors


def simulate_day(policy: str, rng: LCG, dt: float, record: bool = False) -> dict:
    """Full day: event, NPC and hostile-hit pulses (model 3, careful player, current design hit
    probabilities) plus continuous flows while crossing.

    Every day consumes the same amount of random numbers whatever the policy (the day is not cut
    short on defeat; the first defeat is recorded), so policies run from the same seed see the
    same events and hits day by day (common random numbers)."""
    hit_prob = CONFIGS[0]["hit_prob"]
    hit = (HIT_DAMAGE["money"], HIT_DAMAGE["energy"], HIT_DAMAGE["time"])
    state = {"energy": float(INITIAL["energy"]), "time": float(INITIAL["time"]), "progress": 0.0,
             "money": float(INITIAL["money"])}
    pools = {stage: list(events) for stage, events in EVENTS.items()}
    clock = 0.0
    trace = [(clock, dict(state))]
    defeat = None
    rested = 0.0

    def pulse(change: tuple) -> None:
        state["money"] += change[0]
        state["energy"] = min(state["energy"] + change[1], ENERGY_MAX)
        state["time"] += change[2]
        if record:
            trace.append((clock, dict(state)))

    def run_flow(activity: str, until) -> float:
        nonlocal state, clock
        state, seconds, steps = integrate(state, activity, dt, until)
        if record:
            trace.extend((clock + t, s) for t, s in steps[1:])
        clock += seconds
        return seconds

    for scenario in FLOW:
        for _ in range(scenario.events):
            event = draw_without_replacement(pools[scenario.stage], rng)
            pulse((event.money, event.energy, event.time))
        if scenario.npc:
            pulse(choose_option(DECISIONS[scenario.npc], "careful", state, rng))
        if scenario.consumes:
            if policy == "rest" and 0 < state["energy"] < FATIGUE_THRESHOLD:
                rested += run_flow("rest", lambda s: s["energy"] >= REST_UNTIL)
            state["progress"] = 0.0
            run_flow("run" if policy == "run" else "walk", lambda s: s["progress"] >= SCENARIO_LENGTH)
            for _ in range(HOSTILES_PER_SCENARIO):
                if rng.next() < hit_prob[scenario.stage]:
                    pulse(hit)
        if defeat is None:
            defeat = next((r for r in ("money", "energy", "time") if state[r] <= 0), None)
    return {"trace": trace, "defeat": defeat, "final": state, "seconds": clock, "rested": rested}


def compare_policies(days: int, seed: int, dt: float) -> dict:
    """Policy sensitivity over many days with common random numbers."""
    summary = {}
    print(f"\nPolíticas sobre {days} jornadas (mismos eventos y golpes por jornada; dt = {dt} s):")
    for policy, name in POLICIES.items():
        rng = LCG(seed)
        results = [simulate_day(policy, rng, dt) for _ in range(days)]
        wins = [1 if r["defeat"] is None else 0 for r in results]
        p_win, low, high = confidence_interval(wins)
        causes = ", ".join(f"{resource} {sum(r['defeat'] == resource for r in results) / days:.1%}"
                           for resource in ("money", "energy", "time"))
        mean_time = sum(r["final"]["time"] for r in results) / days
        mean_energy = sum(r["final"]["energy"] for r in results) / days
        resting = sum(r["rested"] > 0 for r in results) / days
        print(f"  {name:<28} P(victoria) = {p_win:.3f} [{low:.3f}, {high:.3f}] | T final {mean_time:6.2f}"
              f" | E final {mean_energy:6.2f} | jornadas con descanso {resting:.1%} | derrotas: {causes}")
        summary[policy] = (p_win, low, high)
    return summary


def plot(errors: list, days: dict, summary: dict, dt: float, show: bool) -> Path:
    fig, axes = plt.subplots(2, 3, figsize=(18, 9.5))
    ax_rest, ax_err, ax_cross, ax_energy, ax_time, ax_policy = axes.flat

    fine = [i / 10 for i in range(int(REST_HORIZON * 10) + 1)]
    ax_rest.plot(fine, [rest_exact(REST_START, t) for t in fine], "k-", label="Analítica")
    for step_size, style in ((2.0, "o--"), (1.0, "s--")):
        times, energy = [0.0], [REST_START]
        state = {"energy": REST_START, "time": 100.0, "progress": 0.0, "money": 0}
        for index in range(round(REST_HORIZON / step_size)):
            state = euler_step(state, "rest", step_size)
            times.append((index + 1) * step_size)
            energy.append(state["energy"])
        ax_rest.plot(times, energy, style, markersize=4, label=f"Euler dt = {step_size} s")
    ax_rest.set(title="Config 1: recuperación sentado E(t)", xlabel="t (s)", ylabel="Energía")
    ax_rest.legend(fontsize=8)

    ax_err.loglog([e[0] for e in errors], [e[1] for e in errors], "o-", label="Error |E_Euler − E_exacta|")
    ax_err.loglog([e[0] for e in errors], [errors[0][1] * e[0] / errors[0][0] for e in errors], "k--",
                  label="Pendiente 1 (orden de Euler)")
    ax_err.set(title="Convergencia de Euler en E(20 s)", xlabel="dt (s)", ylabel="Error absoluto")
    ax_err.legend(fontsize=8)

    for energy0, color in ((100.0, "tab:green"), (FATIGUE_START, "tab:orange"), (15.0, "tab:red")):
        _, _, trace = cross(energy0, "walk", dt)
        ax_cross.plot([t for t, _ in trace], [s["progress"] for _, s in trace], color=color, label=f"E0 = {energy0:.0f}")
        exact = crossing_exact(energy0)
        if exact is not None:
            ax_cross.axvline(exact, color=color, linestyle=":", linewidth=1)
    ax_cross.axhline(SCENARIO_LENGTH, color="black", linestyle="--", linewidth=1, label="Salida (640 px)")
    ax_cross.set(title=f"Configs 2-3: progreso al cruzar (punteado = t analítico; E* = {CRITICAL_ENERGY:.1f})",
                 xlabel="t (s)", ylabel="Progreso P (px)")
    ax_cross.legend(fontsize=8)

    for axis, resource, label in ((ax_energy, "energy", "Energía"), (ax_time, "time", "Tiempo")):
        for policy, day in days.items():
            outcome = "victoria" if day["defeat"] is None else f"derrota por {day['defeat']}"
            axis.plot([t for t, _ in day["trace"]], [s[resource] for _, s in day["trace"]],
                      linestyle="--" if policy == "rest" else "-", label=f"{POLICIES[policy]} ({outcome})")
        axis.axhline(0, color="red", linewidth=0.8)
        axis.set(title=f"Una jornada ilustrativa: {label} (escalones = eventos y golpes)",
                 xlabel="t real (s)", ylabel=label)
        axis.legend(fontsize=7)
    ax_energy.axhline(FATIGUE_THRESHOLD, color="gray", linestyle=":", linewidth=1)

    names = [POLICIES[p] for p in summary]
    ax_policy.bar(range(len(names)), [summary[p][0] for p in summary],
                  yerr=[summary[p][0] - summary[p][1] for p in summary], capsize=5,
                  color=["tab:blue", "tab:orange", "tab:green"])
    ax_policy.set_xticks(range(len(names)), names, fontsize=8)
    ax_policy.set(title="Sensibilidad: P(victoria) por política (IC 95 %)", ylabel="P(victoria)", ylim=(0, 1))

    fig.suptitle(f"Modelo 5 - Dinámica de sistemas | {stamp()}")
    fig.tight_layout()
    path = RESULTS_DIR / "modelo5_dinamica.png"
    fig.savefig(path, dpi=130)
    if show:
        plt.show()
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description="Modelo 5: dinámica de sistemas de los recursos.")
    parser.add_argument("--seed", type=int, default=20261101)
    parser.add_argument("--dt", type=float, default=1 / 60, help="Paso de Euler en segundos (1/60 = un frame).")
    parser.add_argument("--days", type=int, default=2000, help="Jornadas por política en la sensibilidad.")
    parser.add_argument("--batch-dt", type=float, default=0.05, help="Paso de Euler para las jornadas en lote.")
    parser.add_argument("--no-show", action="store_true", help="Guarda el gráfico sin abrir la ventana.")
    args = parser.parse_args()
    if not 0 < args.dt <= 1 or not 0 < args.batch_dt <= 1:
        parser.error("dt y batch-dt deben estar en (0, 1].")
    if args.days < 30:
        parser.error("Se requieren al menos 30 jornadas.")

    RESULTS_DIR.mkdir(exist_ok=True)
    print_header("MODELO 5 - DINÁMICA DE SISTEMAS", Path(__file__).name, [
        f"Semilla      : {args.seed} (solo eventos de la jornada) | dt = {args.dt:.4f} s",
        f"Calibración  : k = {DRAIN:.4f} E/s, c = {CLOCK:.4f} T/s, cruce caminando = {WALK_CROSSING:.3f} s, "
        f"E_u = {FATIGUE_THRESHOLD:.0f}, g_min = {MIN_SPEED_FACTOR}, r = {REST_RATE}/s",
    ])

    rows, errors = validate(args.dt)

    summary = compare_policies(args.days, args.seed, args.batch_dt)
    days = {policy: simulate_day(policy, LCG(args.seed), args.dt, record=True) for policy in POLICIES}

    csv_path = RESULTS_DIR / "modelo5_dinamica_resultados.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["config", "variable", "teorico", "euler", "diferencia_pct"])
        writer.writerows(rows)
        writer.writerows([["Convergencia", f"error_E20_dt_{step:.4f}", 0.0, error, None] for step, error in errors])

        writer.writerows([["Políticas", f"p_victoria_{policy}", None, mean, None] for policy, (mean, _, _) in
                          summary.items()])

    figure_path = plot(errors, days, summary, args.dt, show=not args.no_show)
    print(f"\nResultados: {csv_path}\nGráfico   : {figure_path}")


if __name__ == "__main__":
    main()
