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





#########################################
#########################################
# join all the images 
data_x = Vector{Any}()
data_y = Vector{Any}()
data= Vector{Any}()
angles_x = Vector{Any}()
angles_y = Vector{Any}()
sz=40
roi=[(y,x,0) for y=1:sz, x=1:sz] 
pos_emitter = (sz/2,sz/2,0.0)

### angles 
N_angles = 6
angles = Vector{Any}()
θ = Array(range(0, pi, N_angles))
dθ = θ[2] - θ[1]
dΩ = dθ^2
for i in eachindex(θ)
    if θ[i] == 0 
        push!(angles,(θ[i],0))
    end
    dϕ = dΩ/(sin(θ[i])*dθ)
    Number_ϕ = round(Int, 2 * pi / dϕ)
    println(Number_ϕ)
    for k in 0:Number_ϕ
        if k * dϕ <=(2 * pi)
            push!(angles, (θ[i], k * dϕ))
        end
    end
end

# plot dipole angles
θ_plot = Vector{Any}()
ϕ_plot = Vector{Any}()

for i in eachindex(angles)
    push!(θ_plot,angles[i][end-1])
    push!(ϕ_plot,angles[i][end])
end  
x = sin.(θ_plot).*cos.(ϕ_plot)
y = sin.(θ_plot).*sin.(ϕ_plot)
z = cos.(θ_plot)  
fig = Figure(size=(700,650))
ax = CM.Axis3(fig[1, 1],aspect = :equal)            #,yreversed=true,zreversed=true,xreversed=true)
ax1=Axis(fig[1,2],title ="xy",aspect = DataAspect())
ax2=Axis(fig[2,1],title ="xz",aspect = DataAspect())
ax3=Axis(fig[2,2],title="yz",aspect = DataAspect())
CM.scatter!(ax1,x,y)
CM.scatter!(ax2,x,z)
CM.scatter!(ax3,y,z)
CM.scatter!(ax,x',y',z')
CM.lines!(ax,x',y',z')
CM.lines!(ax1,x,y)
CM.lines!(ax2,x,z)
CM.lines!(ax3,y,z)
fig


# loop for sum the images 


for i in eachindex(angles)
    #for k in 1:round(Int,size(angles_y,1))

        angl=[angles[i][end-1],angles[i][end]]
        p=PSF.Dipole3D(na,λ,n,pixelsize,angl;normf =1.0, ksize=128,excitationfield=1.0,mvtype="stage")
        hx = p.pupilfunctionx.pupil[:,:,1].*exp.(im*p.pupilfunctionx.pupil[:,:,2])
        hy = p.pupilfunctiony.pupil[:,:,1].*exp.(im*p.pupilfunctiony.pupil[:,:,2])
        p.electricfield = 'x'
        imx=PSF.pdf(p,roi,pos_emitter)
        p.electricfield = 'y'
        imy=PSF.pdf(p,roi,pos_emitter)
        #=fig = Figure(size = (600, 300))
        ax = CM.Axis(fig[1, 1],title="Ex psf",aspect=1)
        hm = CM.heatmap!(ax, abs.(hx),colormap=:inferno)
        hidedecorations!(ax)
        ax = CM.Axis(fig[2, 1],title="Ex psf",aspect=1)
        hm = CM.heatmap!(ax, imx,colormap=:inferno)
        hidedecorations!(ax)
        ax = CM.Axis(fig[1, 2],title="Ey psf",aspect=1)
        hm = CM.heatmap!(ax, abs.(hy),colormap=:inferno)
        hidedecorations!(ax)
        ax = CM.Axis(fig[2, 2],title="Ey psf",aspect=1)
        hm = CM.heatmap!(ax, imy,colormap=:inferno)
        hidedecorations!(ax)=#
        suma=imx.+imy
        push!(data_y,imy)
        push!(data_x,imx)
        push!(data,suma)
        #display(fig)
        println(angl)
    #end

end
sum_arr = zeros(size(data[1]))
sum_x =zeros(size(data_x[1]))
sum_y=zeros(size(data_y[1]))

for i in 1:size(data,1)  
    sum_arr = sum_arr.+data[i]
    sum_x= sum_x.+data_x[i]
    sum_y= sum_y.+data_y[i]  
    #=fig = Figure(size = (600, 300))
    ax = CM.Axis(fig[1, 1],title="sum_arr",aspect=1)
    CM.heatmap!(ax,sum_arr,colormap=:inferno)
    ax = CM.Axis(fig[1, 2],title="sum x",aspect=1)
    CM.heatmap!(ax,sum_x,colormap=:inferno)
    ax = CM.Axis(fig[1, 3],title="sum y",aspect=1)
    CM.heatmap!(ax,sum_y,colormap=:inferno)
    ax = CM.Axis(fig[2, 1],title="data",aspect=1)
    CM.heatmap!(ax,data[idx],colormap=:inferno)
    ax = CM.Axis(fig[2, 2],title="data x",aspect=1)
    CM.heatmap!(ax,data_x[idx],colormap=:inferno)
    ax = CM.Axis(fig[2, 3],title="data y ",aspect=1)
    CM.heatmap!(ax,sum_y,colormap=:inferno)
    
    display(fig)=#
  
end
fig = Figure(size = (400, 400))
ax = CM.Axis(fig[1, 1],title="total",aspect=1,yreversed= true)
CM.heatmap!(ax,sum_arr,colormap=:inferno)
ax = CM.Axis(fig[1, 2],title="polarixation x",aspect=1,yreversed= true)
CM.heatmap!(ax,sum_x',colormap=:inferno)
ax = CM.Axis(fig[1, 3],title=" polarization y ",aspect=1,yreversed= true)
CM.heatmap!(ax,sum_y',colormap=:inferno)
display(fig)




