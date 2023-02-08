mutable struct DirectSolution
    T::Vector{<:MyNumber}
    X::Matrix{<:MyNumber}
    U::Matrix{<:MyNumber}
    P::Matrix{<:MyNumber}
    P_ξ::Matrix{<:MyNumber}
    P_ψ::Matrix{<:MyNumber}
    n::Integer
    m::Integer
    N::Integer
    objective::MyNumber
    constraints::MyNumber
    iterations::Integer
    status::Integer
    stats  #stats::SolverCore.GenericExecutionStats
end


# getters
# todo: return all variables on a common time grid
# trapeze scheme case: state and control on all time steps [t0,...,tN], as well as path constraints
# only exception is the costate, associated to the dynamics equality constraints: N values instead of N+1
# we could use the basic extension for the final costate P_N := P_(N-1)  (or linear extrapolation) 
# NB. things will get more complicated with other discretization schemes (time stages on a different grid ...)
        
#function State()
#function Control()
#function Adjoint()
    
    

function DirectSolution(ocp::OptimalControlModel, N::Integer, ipopt_solution)

    # direct_infos
    t0, tf_, n_x, m, f, ξ, ψ, ϕ, dim_ξ, dim_ψ, dim_ϕ, 
    has_ξ, has_ψ, has_ϕ, hasLagrangeCost, hasMayerCost, 
    dim_x, nc, dim_xu, g, f_Mayer, has_free_final_time, criterion = direct_infos(ocp, N)

    function parse_ipopt_sol(stats)
        """
            return
            X : matrix(N+1,n+1)
            U : matrix(N+1,m)
            P : matrix(N,n+1)
        """
        
        # states and controls
        xu = stats.solution
        X = zeros(N+1,dim_x)
        U = zeros(N+1,m)
        for i in 1:N+1
            X[i,:] = get_state_at_time_step(xu, i-1, dim_x, N)
            U[i,:] = get_control_at_time_step(xu, i-1, dim_x, N, m)
        end

        # adjoints
        P = zeros(N, dim_x)
        lambda = stats.multipliers
        P_ξ = zeros(N+1,dim_ξ)
        P_ψ = zeros(N+1,dim_ψ)
        index = 1 # counter for the constraints
        for i ∈ 1:N
            # state equation
            P[i,:] = lambda[index:index+dim_x-1]            # use getter
            index = index + dim_x
            if has_ξ
                P_ξ[i,:] =  lambda[index:index+dim_ξ-1]      # use getter
                index = index + dim_ξ
            end
            if has_ψ
                P_ψ[i,:] =  lambda[index:index+dim_ψ-1]      # use getter
                index = index + dim_ψ
            end
        end
        if has_ξ
            P_ξ[N+1,:] =  lambda[index:index+dim_ξ-1]        # use getter
            index = index + dim_ξ
        end
        if has_ψ
            P_ψ[N+1,:] =  lambda[index:index+dim_ψ-1]         # use getter
            index = index + dim_ψ
        end
        return X, U, P, P_ξ, P_ψ
    end

    # state, control, adjoint
    X, U, P, P_ξ, P_ψ = parse_ipopt_sol(ipopt_solution)
    
    # times
    tf = get_final_time(ipopt_solution.solution, tf_, has_free_final_time)
    T = collect(LinRange(t0, tf, N+1))
    
    # misc info
    objective = ipopt_solution.objective
    constraints = ipopt_solution.primal_feas
    iterations = ipopt_solution.iter
    status = ipopt_solution.status
        
    # DirectSolution
    #sol  = DirectSolution(T, X, U, P, P_ξ, P_ψ, n_x, m, N, ipopt_solution)
    sol  = DirectSolution(T, X, U, P, P_ξ, P_ψ, n_x, m, N, objective, constraints, iterations, status, ipopt_solution)     

    return sol
end
