class_name MetropolisSampler
extends RefCounted
## Metropolis-Hastings over a finite set of states (model 3, Markov chain Monte Carlo).
## Port of metropolis_index() in simulation_standalone/Jimenez_Correa_Avila_Melo_Nino_modelo3_montecarlo_mcmc.py.
##   Target:     π_i ∝ w_i (the normalizing constant Σw is never needed).
##   Proposal:   j ~ U{0..n-1}, symmetric and with self-proposals, so the chain is aperiodic.
##   Acceptance: α(i -> j) = min(1, w_j / w_i).
## Detailed balance π_i P_ij = π_j P_ji holds, so π is the stationary distribution of the chain.


## Runs a chain of [param steps] transitions from X0 ~ uniform and returns the last state.
## With steps = 0 the result is uniform; as steps grows its distribution converges to π.
static func sample(weights: Array[float], steps: int, rng: Lcg) -> int:
	assert(not weights.is_empty(), "MetropolisSampler: there are no states.")
	var current: int = rng.index(weights.size())
	for _step: int in steps:
		var proposal: int = rng.index(weights.size())
		var ratio: float = weights[proposal] / weights[current]
		# ratio >= 1 is always accepted without drawing, as in the Python model.
		if ratio >= 1.0 or rng.next() < ratio:
			current = proposal
	return current
