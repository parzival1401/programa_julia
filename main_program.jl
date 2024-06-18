using MAT
using GLMakie
using Statistics
using JLD2


#model_prediction=load("/Volumes/lidke-internal/Personal Folders/Sheng/results/dipole_simulation/slow_dipole_ex001_emx.jld2","model")
model_prediction=load(joinpath("/Volumes","lidke-internal","Personal Folders","Sheng","results","dipole_simulation","slow_dipole_ex001_emx.jld2"),"model")


#getting the adrees of all the files in a folder 
#general_directory_data = "/Users/fernandodelgado/Documents/university /summer 2024/intership /data /06-05-24"
general_directory_data = joinpath("/Users","fernandodelgado","Documents","university ","summer 2024","intership ","data ","06-05-24")
names_files = readdir(general_directory_data)

#fuction to calculate the center of mass 


function center_of_mass(array) 
    
    x_coords = repeat(1:size(array, 1), outer=(size(array, 1), 1))
    y_coords = reshape(repeat([1:size(array, 1);], inner=(size(array, 2))), size(array))
    
    total_mass = sum(array)
    
    center_x = round(Int, sum(x_coords .* array[:]) / total_mass)
    center_y = round(Int, sum(y_coords .* array) / total_mass)
    
    return center_x, center_y
end


function join_dir_names(folder, names)
    paths_general = Vector{String}()
    data = Vector{Any}()  # Initialize an empty vector
    for i in names
        path = joinpath(folder, i)  # Join folder and file name
        push!(paths_general, path)
        open_file = matopen(path)
        var = read(open_file, "ZStack")
        close(open_file)  # Close the file
        push!(data, var)
    end
    return paths_general, data
end
paths_data, data=join_dir_names(general_directory_data,names_files)

fig = Figure()

#click recocnition Initialization fo observables 

mouse_pos = Observable(Point2f[])
push!(mouse_pos[],[50,50])


#crete sliders 
z_slider=SliderGrid(
    fig[2, 1:3],
    (label = "Focus", range = 1:1:size(data[1],3), format = "{1} F", startvalue = 9),
    (label = "E_ax", range = 1:1:size(data,1), format = "{1} F", startvalue = 1),
    (label = "E_ex", range = 1:1:size(data[1],3), format = "{1} F", startvalue = 1),
    tellheight = false)

#define lisenteners 
img=lift(z_slider.sliders[1].value,z_slider.sliders[2].value) do focus, angle
    data[angle][:,:,focus]
end
model=lift(z_slider.sliders[1].value) do focus 
    model_prediction[:,:,focus]'
end
tittle_graph=lift(z_slider.sliders[2].value) do idx
    names_files[idx]
end

#define axis of theA figure 
ax1 = Axis(fig[1, 1],
        title = tittle_graph,
        xlabel = "The x label",
        ylabel = "The y label",
        aspect = DataAspect(), 
        yreversed = true, xzoomlock=true,yzoomlock=true
)
ax2 = Axis(fig[1,2],
        title = "zoom",
        xlabel = "The x label",
        ylabel = "The y label",
        aspect = DataAspect(), 
        yreversed = false
)
ax3 = Axis(fig[1, 3],
        title = tittle_graph,
        xlabel = "The x label",
        ylabel = "The y label",
        aspect = DataAspect(), 
        yreversed = true
)

#mouse recocnition fuction 
register_interaction!(ax1, :my_interaction) do event::MouseEvent, axis
   
    if event.type === MouseEventTypes.leftclick
        println("$(event.data)")
        push!(mouse_pos[],event.data)
        notify(mouse_pos) 
    end
end

#lisenteners of the mouse 

zoom=lift(mouse_pos,z_slider.sliders[1].value,z_slider.sliders[2].value) do x,focus,angle
    mouse_x=50
    mouse_y=-50
    mouse_x=trunc(Int,x[end][1])
    mouse_y=trunc(Int,x[end][2])
    img_size=[15,15]
   
    x_ax=img_size[1]÷2
    y_ax=img_size[2]÷2
    y_i,y_f= mouse_y-y_ax ,mouse_y+y_ax
    x_i,x_f= mouse_x-x_ax , mouse_x+x_ax


   img_zomm=@view data[angle][x_i:x_f,y_i:y_f,focus]
   x_center,y_center=center_of_mass(img_zomm)
   println(x_center," ",y_center)
   #println(x_offset," ",y_offset)Í
   data[angle][x_i:x_f,y_i:y_f,focus]
end

heatmap!(ax1,img,colormap=:grays)
heatmap!(ax2,zoom,colormap=:grays)
heatmap!(ax3,model,colormap=:grays)

display(fig)

#save("heatmaps_examples.png",fig)




