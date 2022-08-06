using JSON

include("functions_utils.jl")
include("linearModel.jl")

instance = readInstance(join((pwd(), "/instances/KIRO-small.json"),""))

sol=optSolution(instance,bigInstance=false)
is_feasible(sol,instance)
cost(sol,instance;verbose=true)


