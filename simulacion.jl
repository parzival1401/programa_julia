#################################
#########################################
# join all the images 
angles_x = Vector{Any}()
angles_y = Vector{Any}()
sz=40
roi=[(y,x,0) for y=1:sz, x=1:sz] 
pos_emitter = (sz/2,sz/2,0.0)

### angles 
N_angles = 12
angles = Vector{Any}()
θ = Array(range(0, pi, N_angles))
dθ = θ[2] - θ[1]
dΩ = dθ^2
for i in eachindex(θ)
    if θ[i] == 0 
        push!(angles,[θ[i],0])
    end
    dϕ = dΩ/(sin(θ[i])*dθ)
    Number_ϕ = round(Int, 2 * pi / dϕ)
    for k in 0:Number_ϕ
        if k * dϕ <=(2 * pi)
            push!(angles, [θ[i], k * dϕ])
        end
    end
end
|



# loop for sum the images in multiple z posistions 
xe = sz/2
ye = sz/2
pos = [(ye,xe,k) for k=-0.5:0.1:0.5]
out = zeros(sz,sz,length(pos))
z_stack_y= Vector{Any}()
z_stack_x = Vector{Any}()
z_stack = Vector{Any}()
suma_gen = Vector{Any}()
for j=eachindex(pos)
    data_x = zeros(sz,sz)
    data_y = zeros(sz,sz)
    data = Vector{Any}()
    sum_data_gen = zeros(sz,sz)
    for i in eachindex(angles)
        angl=[angles[i][end-1],angles[i][end]]
        p=PSF.Dipole3D(na,λ,n,pixelsize,angl;normf =1.0, ksize=128,excitationfield=[0,1,0],mvtype="stage")
        p.electricfield = 'x'
        imx=PSF.pdf(p,roi,pos[j])
        p.electricfield = 'y'
        imy=PSF.pdf(p,roi,pos[j])
        suma=imx.+imy
        data_x .+=+imx
        data_y .+=imy
        sum_data_gen .+=suma
        push!(data,suma)
        println(angl)
    end
    push!(suma_gen,sum_data_gen)
    push!(z_stack,data)
    push!(z_stack_x,data_x)
    push!(z_stack_y,data_y)
    fig = Figure()
    ax = CM.Axis(fig[1,1],title = " zstack",yreversed = true,aspect=1)
    CM.heatmap!(ax,suma_gen[end]',colormap=:inferno)
    ax = CM.Axis(fig[1,2],title = " zstack_x",yreversed = true,aspect=1)
    CM.heatmap!(ax,z_stack_x[end]',colormap=:inferno)
    ax = CM.Axis(fig[1,3],title = " zstack_y",yreversed = true,aspect=1)
    CM.heatmap!(ax,z_stack_y[end]',colormap=:inferno)
    display(fig)
end


fig = Figure()
ax = CM.Axis(fig[1,1],title = " zstack",aspect=1,yreversed = true)
CM.heatmap!(ax,z_stack_y[1]',colormap=:inferno)
display(fig)
           
##### only at one z position
data_x = Vector{Any}()
data_y = Vector{Any}()
data = Vector{Any}()
    for i in eachindex(angles)
        angl=[angles[i][end-1],angles[i][end]]
        p=PSF.Dipole3D(na,λ,n,pixelsize,angl;normf =1.0, ksize=128,excitationfield=[0,1,0],mvtype="stage")
        p.electricfield = 'x'
        imx=PSF.pdf(p,roi,pos_emitter)
        p.electricfield = 'y'
        imy=PSF.pdf(p,roi,pos_emitter)
        suma=imx.+imy
        push!(data_y,imy)
        push!(data_x,imx)
        push!(data,suma)
        println(angl)
    end
sum_arr = zeros(size(data[1]))
sum_x =zeros(size(data_x[1]))
sum_y=zeros(size(data_y[1]))

for i in 1:size(data,1)  
    sum_arr = sum_arr.+data[i]
    sum_x= sum_x.+data_x[i]
    sum_y= sum_y.+data_y[i]  
end

fig = Figure()#size = (400, 400))
ax = CM.Axis(fig[1, 1],title="total",aspect=1,yreversed= true)
CM.heatmap!(ax,sum_arr,colormap=:inferno)
ax = CM.Axis(fig[1, 2],title="polarixation x",aspect=1,yreversed= true)
CM.heatmap!(ax,sum_x',colormap=:inferno)
ax = CM.Axis(fig[1, 1],title=" polarization y ",aspect=1,yreversed= true)
CM.heatmap!(ax,sum_y',colormap=:inferno)
display(fig)




