# Script to validate uniform sampling algorithm in 2 dimensions

import pandas as pd
import random
import numpy as np
from numpy.linalg import inv, multi_dot
import matplotlib.pyplot as plt
from scipy import stats

def testDraws(p_c, delta):
    S = int(1e4)
    X_ci = np.random.uniform(low=-5, high=5, size=p_c)
    delta_vec = np.array([delta] * p_c)
    standard_draws = np.random.normal(size=(S,p_c)) # S draws ~ N(0, 1)
    scaled_draws = np.apply_along_axis(lambda row: np.divide(row, np.sqrt(np.sum(row**2))), axis=1, arr=standard_draws) # Scale each draw by its distance from center
    u = np.random.uniform(low=[0] * S, high = [1] * S)**(1/p_c) # S draws from Unif(0,1), then sent to 1/p_c power
    uniform_draws = scaled_draws * u[:, None] * delta_vec + X_ci # Scale by sampled u, radius and add ball center to get the final uniform draws (S x p_c)

    # Plot if 2d
    # if p_c == 2:
    #     print("Center:", X_ci)
    #     plt.plot(uniform_draws[:,0], uniform_draws[:,1], ".b")
    #     plt.show()

    # Apply distance to boundary test: https://www.jstor.org/stable/pdf/20445229.pdf?refreqid=excelsior%3A9dd0d53fce1e3154e10e1a0b514d21b2
    R = delta # Radius of ball
    dist_to_bound = np.array([R]*S) - np.apply_along_axis(lambda row: np.sqrt(np.sum((row-X_ci)**2)), axis=1, arr = uniform_draws) # Distance to boundary is radius - distance to center
    Y = dist_to_bound/R

    # Under null hypothesis of X is uniformly distributed over ball, Y ~ Beta(1, p_c)
    return(stats.kstest(Y, 'beta',(1,p_c)))

# Generate random dimensions and ball radius and simulate 1000 tests
n_test = 1000
p = []
for _ in range(n_test):
    dim = np.random.choice(range(1,20))
    delta = np.random.uniform(low=1, high=10)
    ks_res = testDraws(dim, delta)
    p.append(ks_res[1])

n_sig = len([val for val in p if val <= 0.05])
print(f"Out of {n_test} tests, {n_sig} rejected uniformity hypothesis.")
