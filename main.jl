using JSON

file=JSON.parsefile("/home/nikitapms/Bureau/ENPC_2A/KIRO/sujet/sujet_real/Instances/KIRO-medium.json")


include("functions_utils.jl")

instance=readInstance("/home/nikitapms/Bureau/ENPC_2A/KIRO/sujet/sujet_real/Instances/KIRO-medium.json")

print(instance.routingCosts)