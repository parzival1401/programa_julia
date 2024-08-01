####################################################
####################################################
####################################################
####################################################
using Distributions
using LinearAlgebra
using Random
using CairoMakie
using StatsBase

function gaussian_mixture_em_2d(data, K, max_iter=100, tol=1e-6)
    N = size(data, 1)
    D = size(data, 2)  # Dimension of the data
    
    # Initialize parameters
    π = ones(K) / K
    μ = [randn(D) for _ in 1:K]
    Σ = [diagm(rand(D)) for _ in 1:K]
    
    log_likelihood_old = -Inf
    
    for iter in 1:max_iter
        # E-step: Compute responsibilities
        resp = zeros(N, K)
        for k in 1:K
            d = MvNormal(μ[k], Σ[k])
            for i in 1:N
                resp[i, k] = π[k] * pdf(d, data[i, :])
            end
        end
        resp ./= sum(resp, dims=2)
        
        # M-step: Update parameters
        Nk = sum(resp, dims=1)
        π = vec(Nk / N)
        for k in 1:K
            μ[k] = vec(sum(resp[:, k] .* data, dims=1) ./ Nk[k])
            diff = data .- μ[k]'
            Σ[k] = (diff' * (resp[:, k] .* diff)) ./ Nk[k]
            Σ[k] = (Σ[k] + Σ[k]') / 2  # Ensure symmetry
            Σ[k] += 1e-6 * I  # Add small diagonal to ensure positive definiteness
        end
        
        # Compute log-likelihood
        log_likelihood = 0.0
        for i in 1:N
            log_likelihood += log(sum(π[k] * pdf(MvNormal(μ[k], Σ[k]), data[i, :]) for k in 1:K))
        end
        
        # Check convergence
        if abs(log_likelihood - log_likelihood_old) < tol
            break
        end
        log_likelihood_old = log_likelihood
    end
    
    return π, μ, Σ
end

# Generate sample data
Random.seed!(123)
true_μ = [[-2.0, -2.0], [2.0, 2.0], [5.0, -1.0]]
true_Σ = [diagm([0.5, 0.5]), diagm([1.0, 0.8]), diagm([0.7, 1.2])]
true_π = [0.3, 0.4, 0.3]
K = length(true_μ)

data = vcat([rand(MvNormal(true_μ[k], true_Σ[k]), Int(1000 * true_π[k]))' for k in 1:K]...)

# Run EM algorithm
estimated_π, estimated_μ, estimated_Σ = gaussian_mixture_em_2d(data, K)

# Plotting
fig = Figure(size=(800, 600))
ax = Axis(fig[1, 1], xlabel="X", ylabel="Y")

# Plot data points
scatter!(ax, data[:, 1], data[:, 2], color=:black, markersize=5, alpha=0.5, label="Data")

# Plot estimated clusters
for k in 1:K
    μ = estimated_μ[k]
    Σ = estimated_Σ[k]
    
    # Generate points on the ellipse
    θ = range(0, 2π, length=100)
    ellipse = [μ .+ sqrt.(eigvals(Σ)) .* eigvecs(Σ) * [cos(t), sin(t)] for t in θ]
    
    # Extract x and y coordinates
    x = [point[1] for point in ellipse]
    y = [point[2] for point in ellipse]
    
    # Plot the ellipse
    lines!(ax, x, y, color=:red, linewidth=2, label=k == 1 ? "Estimated clusters" : nothing)
end

# Plot true clusters
for k in 1:K
    μ = true_μ[k]
    Σ = true_Σ[k]
    
    # Generate points on the ellipse
    θ = range(0, 2π, length=100)
    ellipse = [μ .+ sqrt.(eigvals(Σ)) .* eigvecs(Σ) * [cos(t), sin(t)] for t in θ]
    
    # Extract x and y coordinates
    x = [point[1] for point in ellipse]
    y = [point[2] for point in ellipse]
    
    # Plot the ellipse
    lines!(ax, x, y, color=:blue, linestyle=:dash, linewidth=2, label=k == 1 ? "True clusters" : nothing)
end

axislegend(ax)
display(fig)





######################################################
######################################################


using Distributions
using LinearAlgebra
using Random
using CairoMakie
using StatsBase

import Distributions: Categorical

function create_gmm_data(n_samples::Int, n_clusters::Int, n_features::Int;
                         mean_range::Tuple{Float64,Float64}=(-5.0, 5.0),
                         cov_range::Tuple{Float64,Float64}=(0.1, 2.0),
                         weight_concentration::Float64=1.0)
    
    # Generate random means
    means = [mean_range[1] .+ (mean_range[2] - mean_range[1]) .* rand(n_features) for _ in 1:n_clusters]
    
    # Generate random covariance matrices
    covs = [diagm(cov_range[1] .+ (cov_range[2] - cov_range[1]) .* rand(n_features)) for _ in 1:n_clusters]
    
    # Generate random weights
    weights = rand(Dirichlet(n_clusters, weight_concentration))
    
    # Create distributions for each component
    distributions = [MvNormal(means[k], covs[k]) for k in 1:n_clusters]
    
    # Create a categorical distribution for component selection
    component_dist = Categorical(weights)
    
    # Generate data
    data = zeros(n_samples, n_features)
    for i in 1:n_samples
        # Select a component
        k = rand(component_dist)
        # Generate a sample from the selected component
        data[i, :] = rand(distributions[k])
    end
    
    return data, means, covs, weights
end

function gaussian_mixture_em_2d(data, K, max_iter=100, tol=1e-6)
    N, D = size(data)
    
    π = ones(K) / K
    μ = [randn(D) for _ in 1:K]
    Σ = [diagm(rand(D)) for _ in 1:K]
    
    log_likelihood_old = -Inf
    log_likelihood = 0.0
    
    for iter in 1:max_iter
        resp = zeros(N, K)
        for k in 1:K
            d = MvNormal(μ[k], Σ[k])
            for i in 1:N
                resp[i, k] = π[k] * pdf(d, data[i, :])
            end
        end
        resp ./= sum(resp, dims=2)
        
        Nk = sum(resp, dims=1)
        π = vec(Nk / N)
        for k in 1:K
            μ[k] = vec(sum(resp[:, k] .* data, dims=1) ./ Nk[k])
            diff = data .- μ[k]'
            Σ[k] = (diff' * (resp[:, k] .* diff)) ./ Nk[k]
            Σ[k] = (Σ[k] + Σ[k]') / 2
            Σ[k] += 1e-6 * I
        end
        
        log_likelihood = 0.0
        for i in 1:N
            log_likelihood += log(sum(π[k] * pdf(MvNormal(μ[k], Σ[k]), data[i, :]) for k in 1:K))
        end
        
        if abs(log_likelihood - log_likelihood_old) < tol
            break
        end
        log_likelihood_old = log_likelihood
    end
    
    return π, μ, Σ, log_likelihood
end

function compute_bic(log_likelihood, n_parameters, n_samples)
    return -2 * log_likelihood + n_parameters * log(n_samples)
end

function find_optimal_clusters(data, max_K=10)
    N, D = size(data)
    bic_values = zeros(max_K)
    
    for K in 1:max_K
        π, μ, Σ, log_likelihood = gaussian_mixture_em_2d(data, K)
        n_parameters = K * (D + D*(D+1)/2 + 1) - 1
        bic_values[K] = compute_bic(log_likelihood, n_parameters, N)
        println("K = $K, BIC = $(bic_values[K])")
    end
    
    optimal_K = argmin(bic_values)
    return optimal_K, bic_values
end

#
Random.seed!(123)
n_samples = 10000
n_clusters = 3      
n_features = 2  

data, true_μ, true_Σ, true_π = create_gmm_data(n_samples, n_clusters, n_features)


optimal_K, bic_values = find_optimal_clusters(data)
println("Optimal number of clusters: $optimal_K")


estimated_π, estimated_μ, estimated_Σ, _ = gaussian_mixture_em_2d(data, optimal_K)


println("\nTrue parameters:")
println("π = $true_π")
println("μ = $true_μ")
println("Σ = $true_Σ")
println("\nEstimated parameters:")
println("π = $estimated_π")
println("μ = $estimated_μ")
println("Σ = $estimated_Σ")


fig = Figure(size=(1600, 600))

ax1 = Axis(fig[1, 1], xlabel="Number of clusters (K)", ylabel="BIC",
           title="BIC vs Number of Clusters")
scatter!(ax1, 1:length(bic_values), bic_values, color=:black, markersize=10)
lines!(ax1, 1:length(bic_values), bic_values, color=:black)


ax2 = Axis(fig[1, 2], xlabel="X", ylabel="Y",
           title="Data and Estimated Clusters (K = $optimal_K)")
scatter!(ax2, data[:, 1], data[:, 2], color=:black, markersize=2, alpha=0.5, label="Data")


for k in 1:optimal_K
    μ = estimated_μ[k]
    Σ = estimated_Σ[k] 
    
    θ = range(0, 2π, length=100)
    ellipse = [μ .+ sqrt.(eigvals(Σ)) .* eigvecs(Σ) * [cos(t), sin(t)] for t in θ]
    
    x = [point[1] for point in ellipse]
    y = [point[2] for point in ellipse]
    
    lines!(ax2, x, y, color=:red, linewidth=2, label=k == 1 ? "Estimated clusters" : nothing)
end


for k in 1:n_clusters
    μ = true_μ[k]
    Σ = true_Σ[k]
    
    θ = range(0, 2π, length=100)
    ellipse = [μ .+ sqrt.(eigvals(Σ)) .* eigvecs(Σ) * [cos(t), sin(t)] for t in θ]
    
    x = [point[1] for point in ellipse]
    y = [point[2] for point in ellipse]
    
    lines!(ax2, x, y, color=:blue, linestyle=:dash, linewidth=2, label=k == 1 ? "True clusters" : nothing)
end

axislegend(ax2)


display(fig)
###########################

