class_name Lcg
extends RefCounted
## Linear congruential generator. 
## X(n+1) = (A * X(n) + C) mod M, R = X / (M - 1) truncated to five decimals.
## A * X < 2^53, so the product fits in a GDScript int (64 bits).

const A: int = 1664525
const C: int = 1013904223
const M: int = 4294967296
const _DECIMALS_SCALE: int = 100000

var state: int


func _init(seed_value: int) -> void:
	state = posmod(seed_value, M)


## Next R ~ U[0, 1].
func next() -> float:
	state = (A * state + C) % M
	@warning_ignore("integer_division")
	return float(state * _DECIMALS_SCALE / (M - 1)) / _DECIMALS_SCALE


## Inverse transform: -ln(R) / rate. R = 0 is redrawn because ln(0) does not exist.
func exponential(rate: float) -> float:
	var number: float = next()
	while number == 0.0:
		number = next()
	return -log(number) / rate


## Uniform index in [0, size). R = 1 maps to the last index.
func index(size: int) -> int:
	return mini(int(next() * size), size - 1)
