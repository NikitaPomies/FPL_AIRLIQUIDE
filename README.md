# Two Layer Facility Location Problem 

This repository contains code to solve a two layer facility location problem, which was the subject of the 2022 KIRO challenge, a [French OR challenge](
https://kiro.enpc.org).

The subject of the problem can be found [here](/doc/subject.pdf).

The problem was solved using a Mixed Integer Linear Programming formulation which can be found [here](/doc/model.pdf).

We then used JuMP to modelize the problem and CPLEX to solve it to optimum (thanks to [Julia CPLEX interface](https://github.com/jump-dev/CPLEX.jl)).

Here is a visualization of the optimum distribution network for the large instance : 

![](/doc/visu_large.png)

All solutions are provided in [this folder](/sol/)








