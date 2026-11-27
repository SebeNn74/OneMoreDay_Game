"""Shared PRNG for the five standalone models.

Adapter over the linear congruential generator of Taller 1 (punto 3, generadores.py),
the same one already wrapped in Taller 1 punto 4 (random.py). No `random` or
`numpy.random` is used anywhere.

The game (GDScript) must port exactly this recurrence so that a given seed produces
the same sequence in Python and in Godot: X_{n+1} = (A*X_n + C) mod M, R = X / (M - 1)
truncated to five decimals. A*X < 2^53, so it fits in a GDScript int (64 bits).
"""
import math

from punto3_generadores_pseudoaleatorios.generadores import generar_congruencial_lineal

# Numerical Recipes parameters; they satisfy Hull-Dobell, so the period is the full 2^32.
A = 1664525
C = 1013904223
M = 2**32


class LCG:
    def __init__(self, seed: int, batch_size: int = 4096) -> None:
        self.state = seed % M
        self._batch_size = batch_size
        self._buffer = iter(())

    def _refill(self) -> None:
        sequence = generar_congruencial_lineal(self.state, A, C, M, self._batch_size)
        self._buffer = zip(sequence["valores_x"], sequence["numeros_r"])

    def next(self) -> float:
        """Next R ~ U[0, 1]."""
        try:
            self.state, number = next(self._buffer)
        except StopIteration:
            self._refill()
            self.state, number = next(self._buffer)
        return number

    def exponential(self, rate: float) -> float:
        """Inverse transform: -ln(R) / rate. R = 0 is redrawn because ln(0) does not exist."""
        number = self.next()
        while number == 0.0:
            number = self.next()
        return -math.log(number) / rate
