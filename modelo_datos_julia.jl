using Revise
using MicroscopePSFs
PSF=MicroscopePSFs
using Plots
using CairoMakie
CM = CairoMakie
# Create a scalar PSF

na=1.49
n=[1.33,1.52,1.52] # refractive indices (sample medium, cover glass, immersion)
λ=.69
pixelsize=.05
dipole_ang = [0,0].*pi./180
p=PSF.Dipole3D(na,λ,n,pixelsize,dipole_ang;normf =1.0, ksize=128,excitationfield=1.0,mvtype="stage") # scalar excitation, for fast rotating dipole
#p=PSF.Dipole3D(na,λ,n,pixelsize,dipole_ang;normf =normf, ksize=128,excitationfield=[0,0,1],mvtype="stage") # polarized excitation, for slow rotating dipole

# join all the images 
data_x = Vector{Any}()
data_y = Vector{Any}()
data= Vector{Any}()
angles_x = Vector{Any}()
angles_y = Vector{Any}()
sz=40
roi=[(y,x,0) for y=1:sz, x=1:sz] 
pos_emitter = (sz/2,sz/2,0.0)
id_x,id_y=1,1
for i in 45:3:90
    push!(angles_x,i*pi/180)
end
for i in 45:3:90
push!(angles_y,i*pi/180)
end

for i in 1:round(Int,size(angles_x,1))
    #for k in 1:round(Int,size(angles_y,1))
        angl=[r1[i,1],r1[i,2]]
        #angl=[angles_x[i],angles_y[k]]
        p=PSF.Dipole3D(na,λ,n,pixelsize,angl;normf =1.0, ksize=128,excitationfield=1.0,mvtype="stage")
        hx = p.pupilfunctionx.pupil[:,:,1].*exp.(im*p.pupilfunctionx.pupil[:,:,2])
        hy = p.pupilfunctiony.pupil[:,:,1].*exp.(im*p.pupilfunctiony.pupil[:,:,2])
        p.electricfield = 'x'
        imx=PSF.pdf(p,roi,pos_emitter)
        p.electricfield = 'y'
        imy=PSF.pdf(p,roi,pos_emitter)
        fig = Figure(size = (600, 300))
        ax = CM.Axis(fig[1, 1],title="Ex psf",aspect=1)
        hm = CM.heatmap!(ax, imx,colormap=:inferno)
        hidedecorations!(ax)
        ax = CM.Axis(fig[1, 2],title="Ey psf",aspect=1)
        hm = CM.heatmap!(ax, imy,colormap=:inferno)
        hidedecorations!(ax)
        suma=imx.+imy
        push!(data_y,imy)
        push!(data_x,imx)
        push!(data,suma)
        display(fig)
        println(angl)
   # end

end
sum_arr = zeros(size(data[1]))
idx = 1
for i in 1:size(data,1)    
    #fig = Figure(size = (600, 300))
    #ax = CM.Axis(fig[1, 1],title="Ex",aspect=1,titlesize=20)
    #CM.heatmap!(ax,suma,colormap=:inferno)
    sum_arr = sum_arr.+data[idx]
    #display(fig)
    idx+=1 
end
fig = Figure(size = (400, 400))
ax = CM.Axis(fig[1, 1],title=" 45:3:90 x and 45:3:90 y ",aspect=1,titlesize=20)
CM.heatmap!(ax,data[12],colormap=:inferno)
display(fig)





#look at pupil
hx = p.pupilfunctionx.pupil[:,:,1].*exp.(im*p.pupilfunctionx.pupil[:,:,2])
hy = p.pupilfunctiony.pupil[:,:,1].*exp.(im*p.pupilfunctiony.pupil[:,:,2])
fig = Figure(size = (800, 400))
ax = CM.Axis(fig[1, 1],title="Ex",aspect=1,titlesize=20)
hm = CM.heatmap!(ax, abs.(hx),colormap=:inferno)
hidedecorations!(ax)
ax = CM.Axis(fig[1, 2],title="Ey",aspect=1,titlesize=20)
hm = CM.heatmap!(ax, abs.(hy),colormap=:inferno)
hidedecorations!(ax)
fig

#simulate PSF
sz=40 
roi=[(y,x,0) for y=1:sz, x=1:sz] 

pos_emitter = (sz/2,sz/2,0.0)
p.electricfield = 'x'
imx=PSF.pdf(p,roi,pos_emitter)
p.electricfield = 'y'
imy=PSF.pdf(p,roi,pos_emitter)




#look at psf in x and y polarization
fig = Figure(size = (800, 400))
ax = CM.Axis(fig[1, 1],title="Ex psf",aspect=1)
hm = CM.heatmap!(ax, imx,colormap=:inferno)
hidedecorations!(ax)
ax = CM.Axis(fig[1, 2],title="Ey psf",aspect=1)
hm = CM.heatmap!(ax, imy,colormap=:inferno)
hidedecorations!(ax)
fig



#look at psf with both polarizations at different z positions
xe = sz/2
ye = sz/2
pos = [(ye,xe,k) for k=0.0:0.1:0.5]
out = zeros(sz,sz,length(pos))
for j=eachindex(pos)
    p.electricfield = 'x'
    imx=PSF.pdf(p,roi,pos[j])
    p.electricfield = 'y'
    imy=PSF.pdf(p,roi,pos[j])
    ims = imx.+imy
    zpos = pos[j][3]

    fig = Figure(size = (400, 400))
    ax = CM.Axis(fig[1, 1],title="PSF, z: $zpos μm",aspect=1)
    hm = CM.heatmap!(ax, ims,colormap=:inferno)
    hidedecorations!(ax)
    fig
    display(fig)
    sleep(.1)
    print(sum(ims))
    print("\n")
end

# generate isotropic dipole angles
Nθ = 12
ang = []
append!(ang, [(0.01, 0.0)])
θ = Array(range(0, pi, Nθ))
dθ = θ[2] - θ[1]
for j in eachindex(θ)
    dϕ = dθ / sin(θ[j])
    Nϕ = round(Int, 2 * pi / dϕ)
    for i in 0:Nϕ
        if i * dϕ < (2 * pi - dϕ)
            append!(ang, [(θ[j], i * dϕ)])
        end
    end
end
append!(ang, [(pi+0.01, 0.0)])

# plot dipole angles
ang_array = [tup[j] for tup in ang,j = 1:2]
α = ang_array[:,1]
β = ang_array[:,2]
z = cos.(α)    
x = sin.(α).*cos.(β)
y = sin.(α).*sin.(β)
r = hcat(x,y,z)
r1 = sortslices(r,dims=1,by=x->x[3],rev=true)
fig = Figure(size = (400, 400))
ax = CM.Axis3(fig[1, 1],aspect = :equal,xlabel="x",ylabel="y",zlabel="z")
CM.scatter!(ax,r1[:,1],r1[:,2],r1[:,3],markersize=10,marker=:circle)
CM.lines!(ax,r1[:,1],r1[:,2],r1[:,3])
fig

        