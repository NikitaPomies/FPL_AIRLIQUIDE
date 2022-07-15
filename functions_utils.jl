include("struct.jl")
function readInstance(path::String)
    @assert endswith(path, ".json")
    file = JSON.parsefile(path)

    params = file["parameters"]

    params_BC = params["buildingCosts"]
    buildingCosts = BC(; prod_center=params_BC["productionCenter"],
        distrib_center=params_BC["distributionCenter"],
        auto_penalty=params_BC["automationPenalty"])

    params_PC = params["productionCosts"]
    productionCosts = PC(; prod_center=params_PC["productionCenter"],
        distrib_center=params_PC["distributionCenter"],
        auto_bonus=params_PC["automationBonus"])

    params_RC = params["routingCosts"]
    routing_costs = RC(; primary=params_RC["primary"],
        secondary=params_RC["secondary"])

    params_C = params["capacities"]
    capacity = Capacity(; cost=params["capacityCost"],
        prod_center=params_C["productionCenter"],
        auto_bonus=params_C["automationBonus"])

    I = length(file["clients"])
    clientsDemands = fill(typemax(Int), I)
    clientsCoordinates = fill((Inf, Inf), I)
    for client in file["clients"]
        i, d, coords = client["id"], client["demand"], client["coordinates"]
        clientsDemands[i] = d
        clientsCoordinates[i] = Tuple(coords)
    end

    S = length(file["sites"])
    sitesCoordinates = fill((Inf, Inf), S)
    for site in file["sites"]
        s, coords = site["id"], site["coordinates"]
        sitesCoordinates[s] = Tuple(coords)
    end

    ssd = file["siteSiteDistances"]
    ssDistances = collect(ssd[s1][s2] for s1 in 1:S, s2 in 1:S)
    scd = file["siteClientDistances"]
    scDistances = collect(scd[s][i] for s in 1:S, i in 1:I)


    instance = Instance(; routingCosts=routing_costs,
        buildingCosts=buildingCosts, productionCosts=productionCosts,
        capacity=capacity, clientsDemands=clientsDemands,
        clientsCoordinates=clientsCoordinates,
        sitesCoordinates=sitesCoordinates,
        ssDistances=ssDistances, scDistances=scDistances)

    return instance
end


function is_feasible(sol::Solution, instance::Instance)::Tuple{Bool,String}
    I, S = nbclients(instance), nbsites(instance)

    isprod = sol.isproduction
    isauto = sol.isautomated
    isdist = sol.isdistribution
    distpar = sol.distributionParents
    clientpar = sol.clientsParents

    for s in 1:S
        if isprod[s]
            if isdist[s]
                return false, "Center with 2 types"
            elseif distpar[s] != 0
                return false, "Production center with a parent"
            end
        elseif isdist[s]
            if isauto[s]
                return false, "Automated distribution center"
            elseif !(1 <= distpar[s] <= S)
                return false, "Distribution center without a valid parent"
            elseif !isprod[distpar[s]]
                return false, "Distribution center whose parent is not a production center"
            end
        else
            if isauto[s]
                return false, "Automated empty site"
            elseif distpar[s] != 0
                return false, "Empty site with a parent"
            end
        end
    end

    for i in 1:I
        if !(1 <= clientpar[i] <= S)
            return false, "Client without a valid parent"
        elseif !isprod[clientpar[i]] && !isdist[clientpar[i]]
            return false, "Client whose parent is an empty site"
        end
    end

    return true, "The solution is feasible"
end

function building_cost(s::Int, sol::Solution, instance::Instance)
    s == 0 && return 0.0
    cᵇ = instance.buildingCosts
    if sol.isproduction[s]
        aₛ = sol.isautomated[s]
        return cᵇ.prod_center + aₛ * cᵇ.auto_penalty
    elseif sol.isdistribution[s]
        return cᵇ.distrib_center
    else
        return 0.0
    end
end

function production_cost(i::Int, sol::Solution, instance::Instance)
    i == 0 && return 0.0
    cᵖ = instance.productionCosts
    dᵢ = instance.clientsDemands[i]
    sᵢ = sol.clientsParents[i]
    if sol.isproduction[sᵢ]
        aₛ = sol.isautomated[sᵢ]
        return dᵢ * (cᵖ.prod_center - aₛ * cᵖ.auto_bonus)
    elseif sol.isdistribution[sᵢ]
        pₛ = sol.distributionParents[sᵢ]
        aₚ = sol.isautomated[pₛ]
        return dᵢ * (cᵖ.prod_center - aₚ * cᵖ.auto_bonus + cᵖ.distrib_center)
    else
        return Inf
    end
end

function routing_cost(i::Int, sol::Solution, instance::Instance)
    i == 0 && return 0.0
    cʳ = instance.routingCosts
    Δₛₛ = instance.ssDistances
    Δₛᵢ = instance.scDistances
    dᵢ = instance.clientsDemands[i]
    sᵢ = sol.clientsParents[i]
    if sol.isproduction[sᵢ]
        return dᵢ * cʳ.secondary * Δₛᵢ[sᵢ, i]
    elseif sol.isdistribution[sᵢ]
        pₛ = sol.distributionParents[sᵢ]
        return dᵢ * (cʳ.primary * Δₛₛ[pₛ, sᵢ] + cʳ.secondary * Δₛᵢ[sᵢ, i])
    else
        return Inf
    end
end

function capacity_cost(s::Int, sol::Solution, instance::Instance)
    s == 0 && return 0.0
    cᵘ = instance.capacity.cost
    u = instance.capacity
    if sol.isproduction[s]
        aₛ = sol.isautomated[s]
        sumD = 0
        for i = 1:nbclients(instance)
            dᵢ = instance.clientsDemands[i]
            if path_exists(s, i, sol)
                sumD += dᵢ
            end
        end
        return cᵘ * max(0, sumD - (u.prod_center + aₛ * u.auto_bonus))
    elseif sol.isdistribution[s]
        return 0.0
    else
        return 0.0
    end
end

function building_cost(sol::Solution, instance::Instance)
    return sum(building_cost(s, sol, instance) for s in 1:nbsites(instance))
end

function production_cost(sol::Solution, instance::Instance)
    return sum(production_cost(i, sol, instance) for i in 1:nbclients(instance))
end

function routing_cost(sol::Solution, instance::Instance)
    return sum(routing_cost(i, sol, instance) for i in 1:nbclients(instance))
end

function capacity_cost(sol::Solution, instance::Instance)
    return sum(capacity_cost(s, sol, instance) for s in 1:nbsites(instance))
end

function cost(sol::Solution, instance::Instance; verbose::Bool=false)
    bc = building_cost(sol, instance)
    cc = capacity_cost(sol, instance)
    pc = production_cost(sol, instance)
    rc = routing_cost(sol, instance)
    total_cost = bc + cc + pc + rc
    if verbose
        println("Building cost: $bc")
        println("Capacity cost: $cc")
        println("Production cost: $pc")
        println("Routing cost: $rc")
        println("Total cost: $total_cost")
    end
    return total_cost
end


function read_solution(path::String, instance::Instance)
    @assert endswith(path, ".json")
    file = JSON.parsefile(path)

    I, S = nbclients(instance), nbsites(instance)
    print(I, S)
    is_production_center = fill(false, S)
    is_automated = fill(false, S)
    is_distribution_center = fill(false, S)
    distribution_parents = fill(0, S)
    client_parents = fill(0, I)

    unique_prod_ids = Set{Int}(
        prod_center["id"] for prod_center in file["productionCenters"]
    )
    @assert length(unique_prod_ids) == length(file["productionCenters"])
    @assert all(1 .<= unique_prod_ids .<= S)
    for prod_center in file["productionCenters"]
        s, a = prod_center["id"], prod_center["automation"]
        is_production_center[s] = true
        is_automated[s] = a
    end

    unique_dist_ids = Set{Int}(
        dist_center["id"] for dist_center in file["distributionCenters"]
    )
    @assert length(unique_dist_ids) == length(file["distributionCenters"])
    @assert all(1 .<= unique_dist_ids .<= S)
    for dist_center in file["distributionCenters"]
        s, p = dist_center["id"], dist_center["parent"]
        is_distribution_center[s] = true
        distribution_parents[s] = p
    end

    unique_client_ids = Set{Int}(client["id"] for client in file["clients"])
    @assert length(unique_client_ids) == length(file["clients"])
    @assert all(1 .<= unique_client_ids .<= I)
    for client in file["clients"]
        i, s = client["id"], client["parent"]
        client_parents[i] = s
    end
    sol = Solution(;
        isproduction=is_production_center,
        isautomated=is_automated,
        isdistribution=is_distribution_center,
        distributionParents=distribution_parents,
        clientsParents=client_parents
    )
    return sol
end




function path_exists(s::Int, i::Int, sol::Solution)
    sᵢ = sol.clientsParents[i]
    return sᵢ == s || sol.distributionParents[sᵢ] == s
end

function write_solution(sol::Solution, path::String)
    @assert endswith(path, ".json")

    I, S = nbclients(sol), nbsites(sol)
    soldict = Dict("productionCenters" => [], "distributionCenters" => [], "clients" => [])

    for s in 1:S
        if sol.isproduction[s]
            push!(
                soldict["productionCenters"],
                Dict("id" => s, "automation" => Int(sol.isautomated[s])),
            )
        elseif sol.isdistribution[s]
            push!(
                soldict["distributionCenters"],
                Dict("id" => s, "parent" => sol.distributionParents[s]),
            )
        end
    end

    for i in 1:I
        push!(soldict["clients"], Dict("id" => i, "parent" => sol.clientsParents[i]))
    end

    open(path, "w") do file
        JSON.print(file, soldict)
    end
end