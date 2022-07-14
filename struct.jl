
Base.@kwdef struct BC
    prod_center::Float64
    auto_penalty::Float64
    distrib_center::Float64
end

Base.@kwdef struct PC
    prod_center::Float64
    auto_bonus::Float64
    distrib_center::Float64
    
end

Base.@kwdef struct RC
    primary::Float64
    secondary::Float64
end 

Base.@kwdef struct Capacity
    cost::Float64
    prod_center::Float64
    auto_bonus::Float64
end

Base.@kwdef struct Instance 
    routingCosts::RC
    buildingCosts::BC
    productionCosts::PC
    capacity::Capacity
    clientsDemands::Vector{Int64}
    clientsCoordinates::Vector{Tuple{Float64,Float64}}
    sitesCoordinates::Vector{Tuple{Float64,Float64}}
    ssDistances::Matrix{Float64}
    scDistances::Matrix{Float64}
end

Base.@kwdef struct Solution
    isproduction::Vector{Bool}
    isautomated::Vector{Bool}
    isdistribution::Vector{Bool}
    distributionParents::Vector{Int}
    clientsParents::Vector{Bool}
end

nbclients(instance::Instance) = length(clientsCoordinates)
nbsites(instance::Instance)=length(sitesCooordinates)





