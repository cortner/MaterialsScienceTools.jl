
using Test, JuLIP, JuLIPMaterials
using JuLIPMaterials: ForceConstantMatrix1

datapath = joinpath(dirname(pathof(JuLIP)), "..", "data")
eam_Fe = EAM(datapath * "/pfe.plt",
             datapath * "/ffe.plt",
             datapath * "/F_fe.plt")

# equilibrate a unit cell
fe1 = bulk(:Fe)
set_calculator!(fe1, eam_Fe)
variablecell!(fe1)
minimise!(fe1)

# get the force constants
fcm = ForceConstantMatrix1(eam_Fe, fe1, h = 1e-5)

println("compute exact hessian on a large cell")
at = fe1 * 12
fixedcell!(at)
set_calculator!(at, eam_Fe)
H = JuLIP.hessian_pos(eam_Fe, at)
Hvec = JuLIP.hessian(at)

println("random virtual displacement => compare H * u and fcm * u")
U = rand(JVecF, length(at))
Uvec = mat(U)[:]
V = vecs(Hvec * Uvec)
# sanity check
@test V[1] ≈ sum( H[1,n] * U[n] for n = 1:length(U) )

# now multiply FCM * U
Vfcm = fcm * (at, U)
err_HxU = maximum(norm.(Vfcm - V)) / maximum(norm.(V))
@show err_HxU
println(@test err_HxU < 1e-7)

println("Check that individual blocks match")
X = positions(at)
x̄ = sum(X) / length(X)
r = [norm(x-x̄) for x in X]
n0 = findall( r .== minimum(r) )[1]
all_found = true
all_passed = true
for n = 1:length(at)
   n == n0 && continue
   norm(H[n0,n]) < 1e-12 && continue
   R = X[n] - X[n0]
   found = false
   for m = 1:length(fcm.R)
      if norm(R - fcm.R[m]) < 1e-7
         found = true
         if norm(H[n0, n] - fcm.H[m]) < 1e-5
            print("+")
         else
            global all_passed = false
            print("-")
         end
         break
      end
   end
   if !found
      global all_found = false
      print("x")
   end
end
println(@test all_passed)
println(@test all_found )
