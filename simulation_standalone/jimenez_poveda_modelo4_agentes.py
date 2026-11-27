"""Modelo 4 - Simulación basada en agentes (One More Day).

Un escenario de calle en grilla con un jugador de prueba que lo cruza de izquierda a
derecha, hostiles con reglas locales y un NPC. Tipos de agente (catálogo de hostiles de
OneMoreDay_Diseño.xlsx, pestaña 5):
  - Errante (H-T2 «Pila de papeles»): siempre camina al azar (modelo 2).
  - Perseguidor (H-T1 «Llamada urgente», H-I3/H-V3 «acecha»): máquina de estados
    PATRULLAR -> PERSEGUIR (jugador dentro del radio de visión) -> ENFRIAMIENTO (tras golpear).
  - NPC: quieto; interactúa cuando el jugador pasa a su lado.
Un hostil golpea como máximo una vez por escenario, igual que el balance de la pestaña 8.

Tipología: simulación basada en agentes, de tiempo discreto (ticks).
PRNG: congruencial lineal del Taller 1, punto 3 (ver prng.py).

Uso:
    python jimenez_poveda_modelo4_agentes.py [--seed N] [--crossings N] [--no-show]
"""
import argparse
import csv
from pathlib import Path

import matplotlib.pyplot as plt

from common import confidence_interval, print_header, stamp
from jimenez_poveda_modelo2_caminata import SYMMETRIC, is_free, step
from prng import LCG

PATROL, CHASE, COOLDOWN = "patrullar", "perseguir", "enfriamiento"
# Embedded test data: a 20 x 10 street with a kiosk, benches and posts.
WIDTH, HEIGHT = 20, 10
BLOCKED = {(5, 3), (5, 4), (6, 3), (6, 4), (10, 7), (11, 7), (12, 7), (14, 2), (15, 2), (9, 1), (17, 5)}
GRID = (WIDTH, HEIGHT, BLOCKED)
FREE_CELLS = [(x, y) for y in range(HEIGHT) for x in range(WIDTH) if is_free((x, y), GRID)]
NPC_CELL = (10, 4)
# Test player: crosses towards the exit (right) without dodging; the worst case for the player.
PLAYER_PROBS = {"up": 0.2, "down": 0.2, "left": 0.1, "right": 0.5}
CONTACT_RADIUS = 1
LOSE_MARGIN = 2          # a chaser gives up when the player is farther than vision + margin
MAX_TICKS = 500
DESIGN_HIT_PROB = {"ida": 0.30, "trabajo": 0.35, "vuelta": 0.40}  # tab 8 Balance

CONFIGS = [
    {"name": "Config 1 - 2 errantes", "wanderers": 2, "chasers": 0, "vision": 0, "chase_prob": 0.0, "npc": False},
    {"name": "Config 2 - 4 errantes", "wanderers": 4, "chasers": 0, "vision": 0, "chase_prob": 0.0, "npc": False},
    {"name": "Config 3 - 2 perseguidores + NPC", "wanderers": 0, "chasers": 2, "vision": 3, "chase_prob": 0.6,
     "npc": True},
]
SWEEP_VISIONS = [0, 1, 2, 3, 4, 5, 6]
RESULTS_DIR = Path(__file__).parent / "resultados"


class Agent:
    def __init__(self, kind: str, cell: tuple) -> None:
        self.kind = kind
        self.cell = cell
        self.state = PATROL
        self.hit = False


def manhattan(a: tuple, b: tuple) -> int:
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


# k(cell): free cells within CONTACT_RADIUS of `cell`, including itself (k_t of the contact formula).
FREE_NEIGHBOURS = {cell: sum(1 for other in FREE_CELLS if manhattan(cell, other) <= CONTACT_RADIUS)
                   for cell in FREE_CELLS}


def chase_step(cell: tuple, target: tuple) -> tuple:
    """Greedy move that shortens the distance, trying the longer axis first; stays if both are blocked."""
    dx, dy = target[0] - cell[0], target[1] - cell[1]
    moves = [((dx > 0) - (dx < 0), 0), (0, (dy > 0) - (dy < 0))]
    if abs(dy) > abs(dx):
        moves.reverse()
    for move in moves:
        candidate = (cell[0] + move[0], cell[1] + move[1])
        if move != (0, 0) and is_free(candidate, GRID):
            return candidate
    return cell


def update_hostile(agent: Agent, player: tuple, config: dict, rng: LCG, transitions: dict) -> None:
    if agent.kind == "chaser":
        distance = manhattan(agent.cell, player)
        if agent.state == PATROL and distance <= config["vision"]:
            agent.state = CHASE
            transitions[(PATROL, CHASE)] += 1
        elif agent.state == CHASE and distance > config["vision"] + LOSE_MARGIN:
            agent.state = PATROL
            transitions[(CHASE, PATROL)] += 1
    if agent.state == CHASE:
        if rng.next() < config["chase_prob"]:
            agent.cell = chase_step(agent.cell, player)
    else:
        agent.cell, _ = step(agent.cell, SYMMETRIC, rng, GRID)  # model 2 random walk


def pick(cells: list, rng: LCG) -> tuple:
    return cells[min(int(rng.next() * len(cells)), len(cells) - 1)]


def simulate_crossing(config: dict, rng: LCG, transitions: dict, record: bool = False) -> dict:
    player = pick([c for c in FREE_CELLS if c[0] == 0], rng)
    # Hostiles start in the stationary (uniform) distribution of the random walk.
    hostiles = ([Agent("wanderer", pick(FREE_CELLS, rng)) for _ in range(config["wanderers"])]
                + [Agent("chaser", pick(FREE_CELLS, rng)) for _ in range(config["chasers"])])
    contacts = 0
    expected_contacts = 0.0
    interacted = False
    invalid = 0
    trace = []

    def check() -> None:
        nonlocal contacts, expected_contacts, interacted, invalid
        expected_contacts += len(hostiles) * FREE_NEIGHBOURS[player] / len(FREE_CELLS)
        for agent in hostiles:
            invalid += not is_free(agent.cell, GRID)
            if manhattan(agent.cell, player) <= CONTACT_RADIUS:
                contacts += 1
                if not agent.hit:
                    agent.hit = True
                    transitions[(agent.state, COOLDOWN)] += 1
                    agent.state = COOLDOWN
        if config["npc"] and manhattan(player, NPC_CELL) <= CONTACT_RADIUS:
            interacted = True
        if record:
            trace.append((player, [(a.cell, a.state, a.hit) for a in hostiles]))

    ticks = 0
    check()
    while player[0] < WIDTH - 1 and ticks < MAX_TICKS:
        player, _ = step(player, PLAYER_PROBS, rng, GRID)
        for agent in hostiles:
            update_hostile(agent, player, config, rng, transitions)
        ticks += 1
        check()
    return {"contacts": contacts, "expected_contacts": expected_contacts, "ticks": ticks,
            "hits": [a.hit for a in hostiles], "interacted": interacted, "invalid": invalid, "trace": trace}


def new_transitions() -> dict:
    return {(PATROL, CHASE): 0, (CHASE, PATROL): 0, (PATROL, COOLDOWN): 0, (CHASE, COOLDOWN): 0}


def run_config(config: dict, crossings: int, rng: LCG) -> dict:
    transitions = new_transitions()
    runs = [simulate_crossing(config, rng, transitions) for _ in range(crossings)]
    hits = [1 if hit else 0 for run in runs for hit in run["hits"]]
    print(f"\n{config['name']}: radio de visión {config['vision']}, P(avanzar persiguiendo) "
          f"{config['chase_prob']}, {crossings} cruces")
    rows = []
    mean_ticks = confidence_interval([run["ticks"] for run in runs])
    print(f"  Duración del cruce: {mean_ticks[0]:.2f} ticks [{mean_ticks[1]:.2f}, {mean_ticks[2]:.2f}]")
    if config["chasers"] == 0:
        theory = sum(run["expected_contacts"] for run in runs) / crossings
        mean, low, high = confidence_interval([run["contacts"] for run in runs])
        diff = abs(mean - theory) / theory * 100
        inside = low <= theory <= high
        print(f"  Ticks en contacto por cruce: teórico Σk_t/N = {theory:.4f} | simulado {mean:.4f} "
              f"[{low:.4f}, {high:.4f}] | dif. {diff:.2f} % | ¿teórico en IC? {'sí' if inside else 'no'}")
        rows.append([config["name"], "ticks_contacto", theory, mean, low, high, diff, inside])
    p_hit, low, high = confidence_interval(hits)
    print(f"  P(un hostil golpea en el escenario) = {p_hit:.4f} [{low:.4f}, {high:.4f}]")
    rows.append([config["name"], "p_golpe_por_hostil", None, p_hit, low, high, None, None])
    if config["npc"]:
        p_npc = sum(run["interacted"] for run in runs) / crossings
        print(f"  P(el jugador pasa junto al NPC e interactúa) = {p_npc:.4f}")
        rows.append([config["name"], "p_interaccion_npc", None, p_npc, None, None, None, None])
    if config["chasers"]:
        shown = ", ".join(f"{a}→{b}: {count}" for (a, b), count in transitions.items())
        print(f"  Transiciones de estado observadas: {shown}")
    invalid = sum(run["invalid"] for run in runs)
    print(f"  Agentes en celdas no válidas: {invalid}")
    assert invalid == 0, "Un agente salió de las celdas válidas."
    return {"config": config, "runs": runs, "p_hit": (p_hit, low, high), "rows": rows}


def run_sweep(base: dict, crossings: int, rng: LCG) -> list:
    """Sensitivity: P(hit) of a chaser against its vision radius."""
    points = []
    for vision in SWEEP_VISIONS:
        config = dict(base, vision=vision)
        transitions = new_transitions()
        hits = [1 if hit else 0 for _ in range(crossings)
                for hit in simulate_crossing(config, rng, transitions)["hits"]]
        points.append((vision, *confidence_interval(hits)))
    print("\nSensibilidad (2 perseguidores): P(golpe) según el radio de visión")
    for vision, mean, low, high in points:
        print(f"  r = {vision}: {mean:.4f} [{low:.4f}, {high:.4f}]")
    return points


def find_trace(config: dict, rng: LCG) -> list:
    """First crossing in which a chaser actually chases, for the illustrative plot."""
    for _ in range(200):
        run = simulate_crossing(config, rng, new_transitions(), record=True)
        if any(state == CHASE for _, agents in run["trace"] for _, state, _ in agents):
            return run["trace"]
    return run["trace"]


def plot(results: list, sweep: list, trace: list, show: bool) -> Path:
    fig, (ax_trace, ax_contacts, ax_sweep) = plt.subplots(1, 3, figsize=(18, 5.2))

    blocked = [[1 if (x, y) in BLOCKED else 0 for x in range(WIDTH)] for y in range(HEIGHT)]
    ax_trace.imshow(blocked, cmap="Greys", vmin=0, vmax=1.5)
    path = [tick[0] for tick in trace]
    ax_trace.plot([c[0] for c in path], [c[1] for c in path], "k-", linewidth=1.5, label="Jugador")
    colors = {PATROL: "tab:gray", CHASE: "tab:red", COOLDOWN: "tab:blue"}
    for index in range(len(trace[0][1])):
        cells = [tick[1][index] for tick in trace]
        ax_trace.plot([c[0][0] for c in cells], [c[0][1] for c in cells], "-", color="lightgray", linewidth=0.8)
        for state, color in colors.items():
            points = [c[0] for c in cells if c[1] == state]
            ax_trace.scatter([p[0] for p in points], [p[1] for p in points], s=14, color=color,
                             label=state.capitalize() if index == 0 else None)
    ax_trace.plot(*NPC_CELL, "g^", markersize=10, label="NPC")
    ax_trace.set(title="Traza de un cruce (config 3): estado de cada perseguidor", xlabel="x", ylabel="y")
    ax_trace.legend(fontsize=7, loc="lower right")

    wanderer_results = [r for r in results if r["config"]["chasers"] == 0]
    names = [r["config"]["name"].split(" - ")[1] for r in wanderer_results]
    theory = [r["rows"][0][2] for r in wanderer_results]
    simulated = [r["rows"][0][3] for r in wanderer_results]
    errors = [r["rows"][0][3] - r["rows"][0][4] for r in wanderer_results]
    positions = range(len(names))
    ax_contacts.bar([p - 0.2 for p in positions], theory, 0.4, label="Teórico Σk_t/N")
    ax_contacts.bar([p + 0.2 for p in positions], simulated, 0.4, yerr=errors, capsize=4, label="Simulado (IC 95 %)")
    ax_contacts.set_xticks(list(positions), names)
    ax_contacts.set(title="Errantes: ticks en contacto por cruce", ylabel="Ticks en contacto")
    ax_contacts.legend(fontsize=8)

    visions = [p[0] for p in sweep]
    ax_sweep.errorbar(visions, [p[1] for p in sweep], yerr=[p[1] - p[2] for p in sweep], fmt="o-", capsize=4,
                      label="Simulado")
    for (stage, target), style in zip(DESIGN_HIT_PROB.items(), (":", "--", "-.")):
        ax_sweep.axhline(target, color="tab:red", linestyle=style, linewidth=1, label=f"Meta {stage} ({target:.0%})")
    ax_sweep.set(title="Calibración: P(golpe) de un perseguidor según el radio de visión",
                 xlabel="Radio de visión r (celdas)", ylabel="P(golpe por escenario)")
    ax_sweep.legend(fontsize=8)

    fig.suptitle(f"Modelo 4 - Basado en agentes | {stamp()}")
    fig.tight_layout()
    path = RESULTS_DIR / "modelo4_agentes.png"
    fig.savefig(path, dpi=130)
    if show:
        plt.show()
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description="Modelo 4: agentes con el LCG del Taller 1.")
    parser.add_argument("--seed", type=int, default=20261101)
    parser.add_argument("--crossings", type=int, default=5000, help="Cruces por configuración.")
    parser.add_argument("--sweep-crossings", type=int, default=1500, help="Cruces por radio en la sensibilidad.")
    parser.add_argument("--no-show", action="store_true", help="Guarda el gráfico sin abrir la ventana.")
    args = parser.parse_args()
    if args.crossings < 30 or args.sweep_crossings < 30:
        parser.error("Se requieren al menos 30 cruces.")

    RESULTS_DIR.mkdir(exist_ok=True)
    print_header("MODELO 4 - BASADO EN AGENTES", Path(__file__).name, [
        f"Semilla      : {args.seed} | cruces por configuración: {args.crossings} | "
        f"cruces por radio: {args.sweep_crossings}",
        f"Escenario    : grilla {WIDTH}x{HEIGHT}, {len(BLOCKED)} celdas bloqueadas, {len(FREE_CELLS)} libres",
    ])

    rng = LCG(args.seed)
    results = [run_config(config, args.crossings, rng) for config in CONFIGS]
    sweep = run_sweep(CONFIGS[2], args.sweep_crossings, rng)
    trace = find_trace(CONFIGS[2], rng)

    csv_path = RESULTS_DIR / "modelo4_agentes_resultados.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["config", "metrica", "teorico", "simulado", "ic_inferior", "ic_superior",
                         "diferencia_pct", "teorico_en_ic"])
        for result in results:
            writer.writerows(result["rows"])
        writer.writerows([["Sensibilidad", f"p_golpe_r{v}", None, m, lo, hi, None, None] for v, m, lo, hi in sweep])

    figure_path = plot(results, sweep, trace, show=not args.no_show)
    print(f"\nResultados: {csv_path}\nGráfico   : {figure_path}")


if __name__ == "__main__":
    main()
