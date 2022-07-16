using JSON
using Random

file = JSON.parsefile("/home/nikitapms/Bureau/ENPC_2A/KIRO/sujet/sujet_real/Instances/KIRO-medium.json")


include("functions_utils.jl")

instance = readInstance("/home/nikitapms/Bureau/ENPC_2A/KIRO/sujet/sujet_real/Instances/KIRO-large.json")

print(instance.routingCosts)
include("local_search.jl")

sol = read_solution("/home/nikitapms/Bureau/ENPC_2A/KIRO/MEILLEURS_RESULTS/large_final.json", instance)



test_sol = local_search(100, instance)
print("number of distribution sites :  $(sum(test_sol.isdistribution))")
#write_solution(test_sol,"/home/nikitapms/Bureau/ENPC_2A/KIRO/KIRO_JULIA/large1.json")
is_feasible(test_sol,instance)

using JuMP, CPLEX

SP=[s for s in 1:nbsites(instance) if test_sol.isproduction[s] ]
  
SD=[s for s in 1:nbsites(instance) if test_sol.isdistribution[s] ]

S=vcat(SP,SD)
I=[i for i in 1:nbclients(instance)]
SDWP=[ (test_sol.distributionParents[s],s) for s in SD]


SPI=[(s,i) for s in SP for i in I ]
SDI=[(s,i) for s in SD for i in I]
SI=vcat(SPI,SDI)
SSI= [(s,s2,i) for (s,s2) in SDWP for i in I]

m=JuMP.direct_model(CPLEX.Optimizer())
@variable(m,a[S],Bin,base_name="a")
@variable(m,mA[SPI],Bin,base_name="mA")
@variable(m,mNA[SPI],Bin,base_name="mNA")

@variable(m,bA[SSI],Bin,base_name="bA")
@variable(m,bNA[SSI],Bin,base_name="bNA")
@variable(m,pc,base_name="pc")
@variable(m,rc,base_name="rc")
@variable(m,bc,base_name="bc")
@variable(m,CC,base_name="CC")
@variable(m,T[S],base_name="T")

for s in SP
    @constraint(m,T[s]>=0)
    @constraint(m ,T[s]>= sum(instance.clientsDemands[i]*(mA[(s,i)]+mNA[(s,i)]+sum(bA[(s,st,i)]+bNA[(s,st,i)] for st in S if (s,st) in SDWP)) for i in I) -(instance.capacity.prod_center+a[s]*instance.capacity.auto_bonus))
end
for i in I
    @constraint(m,sum(mA[(s,i)]+mNA[(s,i)] for s in SP)+sum(bA[(s,s2,i)]+bNA[(s,s2,i)] for (s,s2) in SDWP)==1)
end
for (s,i) in SPI
    @constraint(m,mA[(s,i)]<=a[s])
    @constraint(m, mNA[(s,i)]<=1-a[s])
    
end




for (s,s2,i) in SSI
    
    @constraint(m,bA[(s,s2,i)]<=a[s])
    @constraint(m,bNA[(s,s2,i)]<=1-a[s])
end 

@constraint(m,sum(instance.buildingCosts.auto_penalty*a[s] for s in SP)<=bc)
cp_P=instance.productionCosts.prod_center
cp_A=instance.productionCosts.auto_bonus
cp_D=instance.productionCosts.distrib_center
@constraint(m,sum(instance.clientsDemands[i]*(sum(mA[(s,i)]*(cp_P-cp_A)  +cp_P*mNA[(s,i)] for s in SP)+sum(bA[(s,s2,i)]*(cp_D-cp_A+cp_P)  +bNA[(s,s2,i)]*(cp_D+cp_P) for (s,s2) in SDWP) ) for i in I ) <=pc)
@constraint(m,sum(instance.clientsDemands[i]*instance.routingCosts.secondary*instance.scDistances[s,i]*(mA[(s,i)]+mNA[(s,i)]) for (s,i) in SPI)  +sum(instance.clientsDemands[i]*(instance.routingCosts.secondary*instance.scDistances[s2,i]+instance.routingCosts.primary*instance.ssDistances[s,s2])*(bA[(s,s2,i)]+bNA[(s,s2,i)]) for (s,s2,i) in SSI)<=rc)
@constraint(m,CC>=instance.capacity.cost*sum(T[s] for s in SP))

@objective(m,Min,CC+rc+bc+pc)
#set_optimizer_attribute(m, "MIPGap", 0)
#set_optimizer_attribute(m,"OutputFlag",0)
@time optimize!(m)


client_parents = fill(0, nbclients(instance))
    for i in 1:nbclients(instance)
        for s in SP
            if value(mA[(s,i)])+value(mNA[(s,i)])>0.5
                client_parents[i]=s
            end
        end
        for (s,s2) in SDWP
            if (value(bA[(s,s2,i)])+value(bNA[(s,s2,i)]))>0.5
                client_parents[i]=s2
            end
        end
    end
    is_auto=fill(0, nbsites(instance))
    for s in SP
        if value(a[s])>0.5
            is_auto[s]=1
        end
    end

test_sol.isautomated=is_auto
test_sol.clientsParents=client_parents

is_feasible(test_sol,instance)

print(cost(test_sol,instance))