#====================
# Author: Richard Liu
# Last Updated: 7/6/20
# Description: Implementation of Machine Learning as Natural Experiment 2SLS Estimator
# ===================
import pandas as pd
import random
import numpy as np
from numpy.linalg import inv, multi_dot
from linearmodels.iv import IV2SLS
import statsmodels.api as sm

# Description:
#   - Sample from uniform distribution on delta-ball centered on input vector using Method 2 Appendix B4
#   - De-standardize and compute QPS = avg(ML(X_c^s, X_di)), s = 1 to S
# Inputs:
#   - X_ci: continuous vars for individual i (p_c x 1)
#   - X_di: discrete vars for individual i (p_d x 1)
#   - S: # draws
#   - delta: radius of ball
#   - mu: mean of continuous variables (p_c x 1)
#   - sigma: std of continuous variables (p_c x 1)
# Output: p^s(X_i; delta) (scalar within [0,1])
def computeQPS(X_ci, X_di, S, delta, mu, sigma, ML):
    p_c = len(X_ci) # Number of continuous variables
    delta_vec = np.array([delta] * p_c)
    standard_draws = np.random.normal(loc=X_ci, scale=delta_vec, size=(S,p_c)) # S draws of X_c ~ N(X_ci, delta)
    scaled_draws = np.apply_along_axis(lambda row: np.divide(row, np.sqrt(np.sum(row**2))), axis=1, arr=standard_draws) # Scale each draw by its radius
    u = np.random.uniform(low=[0] * S, high = [1] * S)**(1/p_c) # S draws from Unif(0,1), then sent to 1/p_c power
    uniform_draws = scaled_draws * u[:, None] # Scale by sampled u to get the final uniform draws (S x p_c)
    # De-standardize each of the variables
    destandard_draws = np.add(np.multiply(uniform_draws, sigma), mu) # This applies the transformations element-wise to each row of uniform_draws

    # Compute QPS
    qps = np.mean(np.apply_along_axis(lambda row: ML(row, X_di), axis=1, arr=destandard_draws))
    return(qps)

# Description: Run a 2SLS regression using ML treatment recommendation as an instrument for treatment assignment
# Inputs
    # Y: vector of outcomes (n x 1)
    # D: vector of binary treatment (n x 1)
    # Z: vector of binary treatment recommendation (n x 1)
    # ML: function R^p -> [0,1] (maps covariate vector to treatment recommendation)
    # delta: bandwith (>0)
    # S: # simulation draws
    # covariates:
    # ONE OF
    #   - X; C: combined matrix of discrete/continuous covariates (n x p); indices of continuous variables
    #   - X_c; X_d: separate matrices of discrete and continuous covariates respectively (n x p_c; n x p_d)
# Outputs
#   Dictionary of:
#   - beta_hat: 3x1 array of estimated coefficients [b0, b1, b2]
#   - var_cov: heteroskedasticity robust variance-covariance matrix
#   - N: # observations of QPS within (0,1)
def estimate_2sls(Y, D, Z, ML, delta, S, **covariates):
    X_c = covariates.get("X_c")
    if X_c is not None:
        X_d = covariates.get("X_d")
        X = np.concatenate((X_c, X_d), axis=1) # Concat discrete and continuous variables column-wise to back out X (n x p)
        C = range(np.shape(X_c)[1]) # Continuous indices are just the first couple of columns of the X matrix
    else:
        X = covariates.get("X")
        C = covariates.get("C") # Column indices of the continuous covariates

    # === Standardize continuous variables - we assume X is a 2d numpy array ===
    # Formula: (X_ik - u_k)/o_k; k represents a continuous variable
    mu = np.mean(X[:,C], axis=0)
    sigma = np.std(X[:,C], axis=0)
    X[:,C] = np.apply_along_axis(lambda row: np.divide(np.subtract(row, mu), sigma), axis=1, arr=X[:,C])

    # === Compute QPS for each individual i using Method 2 ===
    QPS_vec = []
    discrete_inds = list(set(range(np.shape(X)[1])) - set(C)) # Indices for discrete variables
    for i in range(len(X)):
        QPS_vec.append(computeQPS(X[i,C],X[i, discrete_inds], S, delta, mu, sigma, ML)) # Compute QPS for each individual i
    QPS_vec = np.array(QPS_vec)

    # ==== Compute 2SLS Estimator ====
    # Matrix forms
    #   - W: [[1,...,1], [Z_1, ..., Z_n], [qps_1, ..., qps_n]] (3 x n)
    #   - V: [[1,...,1], [D_1, ..., D_n], [qps_1, ..., qps_n]] (3 x n)
    #   - Y: [Y_1, ..., Y_n] (n x 1)
    #   - e_hat: diag([e_1, ..., e_n]) (n x n) (2nd stage residuals along diagonal)
    # Formulas:
    #   - beta_hat = (W x V')^-1 (W x Y)
    #   - var_cov = (W x V')^-1 (W x e_hat^2 x W')(V x W')^-1

    # Take indices of the inputs for which QPS_i %in% (0,1)
    obs_tokeep = np.nonzero((QPS_vec > 0) & (QPS_vec < 1))
    assert len(obs_tokeep[0]) > 0

    # Adjusted input matrices for 2SLS
    Y_adj = Y[obs_tokeep]
    D_adj = D[obs_tokeep]
    Z_adj = Z[obs_tokeep]
    QPS_adj = QPS_vec[obs_tokeep]
    N_adj = len(Y_adj)

    W = np.stack((np.ones(N_adj), Z_adj, QPS_adj), axis=0)
    V = np.stack((np.ones(N_adj), D_adj, QPS_adj), axis=0)

    beta_hat = multi_dot([inv(np.dot(W, V.T)), W, Y_adj]) # Compute 2SLS estimators [b0, b1, b2]

    # Heteroskedasticity robust variance-covariance matrix
    e_hat = Y_adj - beta_hat[0] - np.multiply(D_adj, beta_hat[1]) - np.multiply(QPS_adj, beta_hat[2])
    e_hat = np.diag(e_hat**2)
    var_cov = multi_dot([inv(np.dot(W, V.T)), W, e_hat, W.T, inv(np.dot(V, W.T))])

    # === Validation: Compare against results from IV2SLS function in linearmodels package ===
    exog = sm.add_constant(QPS_adj)
    validation_2sls = IV2SLS(Y_adj, exog, D_adj, Z_adj).fit(cov_type='robust')
    print(validation_2sls)

    ret_dict = {"beta_hat":beta_hat, "var_cov":var_cov, "N":N_adj}
    return(ret_dict)

# Dummy ML function that returns value between 0 and 1
# *args = arbitrary number of arrays to concatenate
def ML_test_1(*args):
    ret = np.random.uniform()
    return(ret)

# ML function to test error handling
def ML_test_2(*args):
    return(0)

if __name__ == "__main__":
    # ========= TESTING ==========
    # Simulate estimation with 100 observations, 10 discrete vars, 10 continuous vars, and 20 draws
    N = 100
    b0 = 1
    b1 = 2.1
    b2 = 3.7
    delta = 2
    S = 20
    Z = np.array(random.choices([0,1], k=N))
    v = np.random.normal(0,1,N) # First stage error
    D = Z*2 + v # "True" functional form of D
    e = np.random.normal(0,1,N) # 2nd stage error
    Y = b0 + b1 * D + e # Ignore QPS for this test
    X_c = np.random.normal(10, 5, (N, 10))
    X_d = np.random.choice(20, size=(N,10))
    X = np.concatenate((X_c, X_d), axis=1)
    C = range(np.shape(X_c)[1])

    # Run with X_c and X_d as separate inputs
    ret_1 = estimate_2sls(Y, D, Z, ML_test_1, delta, S, X_c = X_c, X_d = X_d)
    print(ret_1)

    # Run with total covariate matrix X and indices C as inputs
    ret_2 = estimate_2sls(Y, D, Z, ML_test_1, delta, S, X = X, C = C)
    print(ret_2)
