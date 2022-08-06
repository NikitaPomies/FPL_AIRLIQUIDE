
function affect_clients_to_nearest_sites!(instance::Instance,
    sol::Solution)
    I, S = nbclients(instance), nbsites(instance)
    scd = instance.scDistances
    for i in 1:I
        arg_min = 0
        val_min = Inf
        for s in 1:S

            if (sol.isproduction[s] || sol.isdistribution[s]) & (scd[s, i] < val_min)
                arg_min = s
                val_min = scd[s, i]
            end
        sol.clientsParents[i] = arg_min
        end
    end

end

function affect_distrib_to_nearest_prod_site!(instance::Instance, sol::Solution)
    I, S = nbclients(instance), nbsites(instance)
    ssd = instance.ssDistances
    for sd in 1:S
        if sol.isdistribution[sd]
            arg_min = 0
            val_min = Inf
            for sp in 1:S

                if sp != sd & sol.isproduction[sp] & (ssd[sp, sd] < val_min)
                    arg_min = sp
                    val_min = ssd[sp, sd]
                end
            sol.distributionParents[sd] = arg_min
            end
        end
    end
end



function dumb_solver(instance::Instance)

    I, S = nbclients(instance), nbsites(instance)
    isproduction = fill(true, S)
    isautomated = fill(true, S)
    isdistribution = fill(false, S)
    clientsParents = fill(0, I)
    distributionParents = fill(0, S)
    sol = Solution(; isproduction=isproduction, isautomated=isautomated,
        isdistribution=isdistribution, clientsParents=clientsParents, distributionParents=distributionParents)
    affect_clients_to_nearest_sites!(instance, sol)
    return sol
end


function destroy_site!(new_sol::Solution, s::Int64)
    new_sol.distributionParents[s]=0
    if sum(new_sol.isproduction) - new_sol.isproduction[s] > 0
        new_sol.isproduction[s] = false
        new_sol.isdistribution[s] = false
        new_sol.isautomated[s] = false
    end
    
      
    
end

function create_prodsite!(new_sol::Solution, s::Int64, automated=true)
    destroy_site!(new_sol, s)
    new_sol.isproduction[s] = true
    if automated
        new_sol.isautomated[s] = true
    else 
        new_sol.isautomated[s]=false
        
    end

end


function create_distribsite!(new_sol::Solution, s::Int64)

    if sum(new_sol.isproduction) - new_sol.isproduction[s] > 0
        destroy_site!(new_sol, s)
        new_sol.isdistribution[s] = true
    end

end

function swap!(new_sol::Solution, s1::Int64, s2::Int64)

    new_sol.distributionParents[s1]=0
    new_sol.distributionParents[s2]=0

    temp_prod = new_sol.isproduction[s2]
    temp_distrib = new_sol.isdistribution[s2]
    temp_automated = new_sol.isautomated[s2]
    

    new_sol.isproduction[s2] = new_sol.isproduction[s1]
    new_sol.isdistribution[s2] = new_sol.isdistribution[s1]
    new_sol.isautomated[s2] = new_sol.isautomated[s1]
    

    new_sol.isproduction[s1] = temp_prod
    new_sol.isdistribution[s1] = temp_distrib
    new_sol.isautomated[s1] = temp_automated

    new_sol.distributionParents[s1]=0


end






function perturbation(instance::Instance, current_sol::Solution)
    I, S = nbclients(instance), nbsites(instance)

    new_sol = deepcopy(current_sol)
    current_cost = cost(current_sol, instance)
    new_cost = current_cost

    temp_sol = deepcopy(current_sol)
    temp_cost = current_cost
    println(current_cost)
    is_stucked = false
    liste = [i for i in 1:S]
    shuffle!(liste)

    for s in liste
        liste_func = [create_prodsite!, create_distribsite!, destroy_site!]
        for func in liste_func
            func(temp_sol, s)
            affect_distrib_to_nearest_prod_site!(instance, temp_sol)
            affect_clients_to_nearest_sites!(instance, temp_sol)
            temp_cost = cost(temp_sol, instance)
            dObj = temp_cost - current_cost
            if dObj < 0
                println(dObj)
                current_cost = temp_cost
                optflow!(temp_sol,S,I)

                println(current_cost)
                return temp_sol, true
            else
                temp_sol = deepcopy(current_sol)
                temp_cost = current_cost
            end
        end
        #shuffle!(liste)
        for s2 in liste
            if s2 != s

                swap!(temp_sol, s, s2)
                affect_distrib_to_nearest_prod_site!(instance, temp_sol)
                affect_clients_to_nearest_sites!(instance, temp_sol)
                
                temp_cost = cost(temp_sol, instance)
                dObj = temp_cost - current_cost
                if dObj < 0
                    current_cost = temp_cost
                    optflow!(temp_sol,S,I)

                    print("swwaaaaap")
                    return temp_sol, true
                else
                    temp_sol = deepcopy(current_sol)
                    temp_cost = current_cost
                end
            end

        end
    end

    return current_sol, false

end

function local_search(nb_iter::Int64, instance::Instance)
    new_sol = dumb_solver(instance)
    new_cost = cost(new_sol, instance)
    stop = !false
    for i in 1:nb_iter
        println("iteration $i")

        if stop
            new_sol, stop = perturbation(instance, new_sol)


        else
            return new_sol
        end
    end

    return new_sol
end





















