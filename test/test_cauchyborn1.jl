
using Base.Test
using JuLIP, ForwardDiff
using JuLIPMaterials
using StaticArrays

MST = JuLIPMaterials
CB = MST.CauchyBorn
CLE = MST.CLE
FD = ForwardDiff

Id = one(SMatrix{3,3,Float64})

println("------------------------------------------------------------")
println(" Testing Simple Lattice Cauchy--Born Implementation")
println("------------------------------------------------------------")

at = bulk(:Fe)
r0 = rnn(:Fe)
calc = LennardJones(σ = r0) * C2Shift(2.7*r0)
set_calculator!(at, calc)
variablecell!((at))
# minimise!(at)
println("Constructing Wcb . . .")
W = CB.Wcb(at, calc)

println("generate a cauchy Born potential . . . ")
println("check W, grad(W..) evaluate ok . . .")
@test W(Id) == energy(at) / det(defm(at))
@test CB.grad(W, Id) isa AbstractMatrix

println("Finite-difference consistency test")
F = Id + (rand(3,3) - 0.5) * 0.01
W0 = W(F)
dW0 = CB.grad(W, F)[:]
errors = []
for p = 2:10
   h = .1^p
   dWh = zeros(9)
   for i = 1:9
      F[i] += h
      dWh[i] = (W(F) - W0) / h
      F[i] -= h
   end
   push!(errors, norm(dWh-dW0, Inf))
   @printf(" %2d  |  %.3e \n", p, errors[end])
end
passed = minimum(errors) <= 1e-3 * maximum(errors)
if passed
   println("passed")
else
   warn("""It seems the finite-difference test has failed, which indicates
   that there is an inconsistency between the function and gradient
   evaluation. Please double-check this manually / visually. (It is
   also possible that the function being tested is poorly scaled.)""")
end

# ------ some more random tests left-over from debugging -------

# setup a Cauchy-Born model for bulk Fe
atu = bulk(:Fe)
r0 = rnn(:Fe)
calc = LennardJones(σ = r0) * C2Shift(2.7*r0)
set_calculator!(atu, calc)
variablecell!(atu)
println("Constructing Wcb . . .")
W = CB.Wcb(atu, calc, normalise = :atoms)

energy(atu)
W(Id)

@test CB.grad(W, Id) ≈ -virial(atu)
@test stress(atu) == CB.grad(W, Id) / det(cell(atu))

at1 = deepcopy(atu)
F0 = defm(at1)
for n = 1:5
   F = Id + 0.1 * rand(3,3)
   set_defm!(at1, F * F0)
   @test energy(calc, at1) == W(F)
end
