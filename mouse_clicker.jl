using MAT
using GLMakie


img = rand(100, 100)
fig = Figure()
ax1 = Axis(fig[1,1])
image!(ax1,img) 
mouse_pos = Observable(Point2f[])
register_interaction!(ax1, :my_interaction) do event::MouseEvent, axis
   
    if event.type === MouseEventTypes.leftclick
        println("$(event.data)")
        push!(mouse_pos[],event.data)
        notify(mouse_pos)
        return event.data
        
    end
end

display(fig)

#trunc(Int,mouse_pos.val[1][1])

mydir = joinpath("Users","Fernando")                                                               #save the image in the directory
save("heatmaps_examples.png",fig)

img_size=[15,15]
÷