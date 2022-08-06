using CPLEX, JuMP

include("struct.jl")


function closestClients(scd,s :: Int,n::Int)

    """
    closestClients(scd,s :: Int,n::Int) 

    Returns the n nearest clients of site s. 
    """

    row=scd[s,:]
    row=partialsortperm(row,1:n)
    return row

end






function closestSites(ssd,s::Int,n::Int)
    """
    closestSites(ssd,s::Int,n::Int) 

    Returns the n nearest sites of site s
    """
    row=ssd[s,:]
    row=partialsortperm(row,1:n)
    
    return row
end

function create_SS_Sets(instance::Instance, S::Array,n::Int)

    ssTab=zeros(Int64,length(S),n)
    for s in S
        ssTab[s,:]=closestSites(instance.ssDistances,s,n)
    end
    SS=[(s1, s2) for s1 in S, s2 in S if s2!= s1 && s2 in ssTab[s1,:]]
    return SS

end

function create_SS_SSI_Sets(instance::Instance, SS:: Array, S :: Array, I :: Array, n ::Int)

    scTab=zeros(Int64,length(S),n)
    for s in S
        scTab[s,:]=closestClients(instance.scDistances,s,n)
    end
    SSI= [(s,s2,i) for (s,s2) in SS, i in I if i in scTab[s,:]]
    SI= [(s,i) for s in S, i in I if i in scTab[s,:]]
    return SI,SSI
end









function optSolution(instance :: Instance; bigInstance = false :: Bool)

    """
        optSolution(instance :: Instance)

        Create a linear model to solve KIRO 2021 facility location problem.
        This model returns the optimal solution for the tiny, small and medium instance.

        For large instance, the model will consider that a site can deliver only 
        its 10 closest sites and its 150 closest clients. You should reduce these values
        if you want to run optSolution on bigger instances.

        
    """
    print("tessssst")
    #Sets definition 
   
    S=[s for s in 1:nbsites(instance)]
    I=[i for i in 1:nbclients(instance)]
    if !bigInstance
        SS= [(s1, s2) for s1 in S, s2 in S if s1!= s2]
        SSI= [(s,s2,i) for (s,s2) in SS, i in I]
        SI=[(s,i) for s in S, i in I]
    end

    if bigInstance
        SS=create_SS_Sets(instance,S,10) #[(s1, s2) for s1 in S, s2 in S if s2!= s1 && s2 in closestSites(instance.ssDistances,s1,20)]
        #SSI= [(s,s2,i) for (s,s2) in SS, i in I if i in closestClients(instance.scDistances,s2,200)]
        #SI=[(s,i) for s in S, i in I if i in closestClients(instance.scDistances,s,200)]
        SI,SSI=create_SS_SSI_Sets(instance,SS,S,I,150)
    end

    println("Sets were created")
    
    m = JuMP.direct_model(CPLEX.Optimizer())
    
    #Variables

    @variable(m, x[S], Bin, base_name = "x")
    @variable(m, y[S], Bin, base_name = "y")
    @variable(m,a[S], Bin, base_name ="a")
    @variable(m,mA[SI],Bin,base_name="mA")
    @variable(m,mNA[SI],Bin,base_name="mNA")
    @variable(m,B[SS],Bin,base_name="B")
    @variable(m,bA[SSI],Bin,base_name="bA")
    @variable(m,bNA[SSI],Bin,base_name="bNA")
    @variable(m,T[S],base_name="T")

    #Constraints

    for s in S
        @constraint(m,x[s]+y[s]<=1 )
        @constraint(m, x[s]>=a[s])
        @constraint(m,sum(B[(so,s)] for so in S if (so,s) in SS)==y[s])
        @constraint(m,T[s]>=0)
        @constraint(m ,T[s]>= sum(instance.clientsDemands[i]*(mA[(s,i)]+mNA[(s,i)]+
        sum(bA[(s,st,i)]+bNA[(s,st,i)] for st in S if (s,st,i) in SSI  )) for i in I if (s,i) in SI) -
        (instance.capacity.prod_center+a[s]*instance.capacity.auto_bonus))
    end

    for i in I
        @constraint(m,sum(mA[(s,i)]+mNA[(s,i)] for s in S if (s,i) in SI)+
        sum(bA[(s,s2,i)]+bNA[(s,s2,i)] for (s,s2) in SS if (s,s2,i) in SSI)==1)
    end
    
    for (s,i) in SI
        @constraint(m,mA[(s,i)]<=a[s])
        @constraint(m, mNA[(s,i)]<=1-a[s])
        @constraint(m,x[s]>= mA[(s,i)]+mNA[(s,i)])  
    end
    
    for (s,s2) in SS
        @constraint(m, (x[s]+y[s2])/2 >= B[(s,s2)])
    end
    
    for (s,s2,i) in SSI
        @constraint(m,B[(s,s2)]>=bA[(s,s2,i)]+bNA[(s,s2,i)] )
        @constraint(m,bA[(s,s2,i)]<=a[s])
        @constraint(m,bNA[(s,s2,i)]<=1-a[s])
    end


    #Objective function 

    cp_P = instance.productionCosts.prod_center
    cp_A = instance.productionCosts.auto_bonus
    cp_D = instance.productionCosts.distrib_center

    @expression(m,bc,sum(instance.buildingCosts.prod_center * x[s] + 
    instance.buildingCosts.distrib_center * y[s] +  instance.buildingCosts.auto_penalty * a[s] for s in S))
    @expression(m,cc, instance.capacity.cost * sum(T[s] for s in S))
    @expression(m,rc ,sum(instance.clientsDemands[i] * instance.routingCosts.secondary * instance.scDistances[s, i] * (mA[(s, i)] + mNA[(s, i)]) for (s, i) in SI) + 
    sum(instance.clientsDemands[i] * (instance.routingCosts.secondary * instance.scDistances[s2, i] 
    + instance.routingCosts.primary * instance.ssDistances[s, s2]) * (bA[(s, s2, i)] + bNA[(s, s2, i)]) for (s, s2, i) in SSI))

    @expression(m,pc,sum(instance.clientsDemands[i] * (sum(mA[(s, i)] * (cp_P - cp_A) + cp_P * mNA[(s, i)] for s in S if (s,i) in SI) + sum(bA[(s, s2, i)] *
     (cp_D - cp_A + cp_P) + bNA[(s, s2, i)] * (cp_D + cp_P) for (s, s2) in SS if (s,s2,i) in SSI))
     for i in I))
    @objective(m, Min, cc + pc + rc + bc)

    println("Model Created. Optimization starts ! ") 

    optimize!(m)
    println(solution_summary(m))
    


    #Solution  
    
    client_parents = fill(0, nbclients(instance))
    is_prod=fill(0,nbsites(instance))
    is_distrib=fill(0,nbsites(instance))
    distrib_parents=fill(0,nbsites(instance))
    is_auto=fill(0, nbsites(instance))
    for (s,i) in SI
        if value(mA[(s,i)])+value(mNA[(s,i)])>0.5
            client_parents[i]=s
        end
    end

    for (s,s2,i) in SSI
        if (value(bA[(s,s2,i)])+value(bNA[(s,s2,i)]))>0.5
            client_parents[i]=s2
        end
    end


    for s in S
        if value(x[s]) > 0.5
            is_prod[s]=1
        end

        if value(y[s]) > 0.5
            is_distrib[s] = 1
            for s2 in S 
                
                if (s2,s) in SS && value(B[(s2,s)])==1
                   
                    distrib_parents[s]=s2

                end
            end

        end

        if value(a[s])>0.5
            is_auto[s]=1
        end
    end

    solution = Solution(;
        isproduction=is_prod,
        isautomated=is_auto,
        isdistribution=is_distrib,
        distributionParents=distrib_parents,
        clientsParents=client_parents,
    )      

    return solution
end







    
    
    
