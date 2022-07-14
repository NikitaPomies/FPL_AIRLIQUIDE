include("struct.jl")
function readInstance(path::String)
    @assert endswith(path,".json")
    file=JSON.parsefile(path)

    params=file["parameters"]

    params_BC=params["buildingCosts"]
    buildingCosts=BC(;prod_center=params_BC["productionCenter"],
    distrib_center=params_BC["distributionCenter"],
    auto_penalty=params_BC["automationPenalty"])

    params_PC=params["productionCosts"]
    productionCosts=PC(;prod_center=params_PC["productionCenter"],
    distrib_center=params_PC["distributionCenter"],
    auto_bonus=params_PC["automationBonus"])

    params_RC=params["routingCosts"]
    routing_costs=RC(;primary=params_RC["primary"],
    secondary=params_RC["secondary"])

    params_C=params["capacities"]
    capacity=Capacity(;cost=params["capacityCost"],
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


    instance=Instance(;routingCosts=routing_costs,
    buildingCosts=buildingCosts,productionCosts=productionCosts,
    capacity=capacity,clientsDemands=clientsDemands,
    clientsCoordinates=clientsCoordinates,
    sitesCoordinates=sitesCoordinates,
    ssDistances=ssDistances,scDistances=scDistances)

    return instance
end 



