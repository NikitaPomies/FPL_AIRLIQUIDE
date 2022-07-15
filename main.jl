using JSON
using Random

file = JSON.parsefile("/home/nikitapms/Bureau/ENPC_2A/KIRO/sujet/sujet_real/Instances/KIRO-medium.json")


include("functions_utils.jl")

instance = readInstance("/home/nikitapms/Bureau/ENPC_2A/KIRO/sujet/sujet_real/Instances/KIRO-large.json")

print(instance.routingCosts)


sol = read_solution("/home/nikitapms/Bureau/ENPC_2A/KIRO/MEILLEURS_RESULTS/large_final.json", instance)



test_sol=local_search(100,instance)

#write_solution(test_sol,"/home/nikitapms/Bureau/ENPC_2A/KIRO/KIRO_JULIA/large1.json")