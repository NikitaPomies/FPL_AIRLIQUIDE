using JSON
using Random
include("Transportation_problem.jl")

file = JSON.parsefile("/home/nikitapms/Bureau/ENPC_2A/KIRO/sujet/sujet_real/Instances/KIRO-medium.json")
include("linearModel.jl")

include("functions_utils.jl")

instance = readInstance("/home/nikitapms/Bureau/ENPC_2A/KIRO/sujet/sujet_real/Instances/KIRO-large.json")

print(instance.routingCosts)
include("local_search.jl")

#sol = read_solution("/home/nikitapms/Bureau/ENPC_2A/KIRO/MEILLEURS_RESULTS/large_final.json", instance)
#cost(sol,instance;verbose=true)

#test_sol=dumb_solver(instance)
#test_sol = local_search(100, instance)
#print("number of distribution sites :  $(sum(test_sol.isdistribution))")
#write_solution(test_sol,"/home/nikitapms/Bureau/ENPC_2A/KIRO/KIRO_JULIA/large1.json")
#is_feasible(test_sol, instance)


#optflow!(test_sol,nbsites(instance),nbclients(instance))

#is_feasible(test_sol,instance)
#cost(sol,instance;verbose=true)
S=30
I=60

#SS= [(s1, s2) for s1 in 1:S, s2 in 1:S if s1!= s2]
#SSI= [(s,s2,i) for (s,s2) in SS, i in 1:I]
#SI=[(s,i) for s in S, i in 1:I]

sol=optSolution(instance,bigInstance=true)



is_feasible(sol,instance)
cost(sol,instance;verbose=true)


