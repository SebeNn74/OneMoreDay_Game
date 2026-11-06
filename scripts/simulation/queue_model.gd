class_name QueueModel
extends RefCounted
## M/M/1 queue. Port of simulation_standalone/jimenez_poveda_modelo1_colas.py
## (theoretical metrics and sample_player_wait).


static func utilization(config: QueueConfig) -> float:
	return config.arrival_rate / config.service_rate


## Lq: mean number of people waiting. Shown to the player as the visible queue.
static func mean_queue_length(config: QueueConfig) -> float:
	var rho: float = utilization(config)
	return rho * rho / (1.0 - rho)


## Wq = λ / (μ(μ - λ)): mean wait before being served. Shown as the estimated wait.
static func mean_wait(config: QueueConfig) -> float:
	return config.arrival_rate / (config.service_rate * (config.service_rate - config.arrival_rate))


## Wait of the player arriving at a queue in steady state: 0 with probability 1 - ρ,
## otherwise Exp(μ - λ). Its mean is Wq.
static func sample_player_wait(config: QueueConfig, rng: Lcg) -> float:
	assert(config.arrival_rate < config.service_rate, "QueueModel: λ must be lower than μ.")
	if rng.next() >= utilization(config):
		return 0.0
	return rng.exponential(config.service_rate - config.arrival_rate)
