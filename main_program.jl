using MAT
using GLMakie
using Statistics
#getting the adrees of all the files in a folder 

general_directory = "/Users/fernandodelgado/Documents/university /summer 2024/intership /data /06-05-24"

names_files = readdir(general_directory,sort=true)

#fuction to calculate the center of mass 

function center_of_mass(array) 
    # Create meshgrid for x and y coordinates
    x_coords = repeat(1:size(array, 2), outer=(size(array, 1), 1))
    y_coords = repeat(1:size(array, 1), inner=(1, size(array, 2)))
    
    # Calculate total mass
    total_mass = sum(array)
    
    # Calculate center of mass coordinates
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
paths_data, data=join_dir_names(general_directory,names_files)

fig = Figure()

#click recocnition Initialization fo observables 

mouse_pos = Observable(Point2f[])
push!(mouse_pos[],[50,50])




#crete sliders 
z_slider=SliderGrid(
    fig[2, 1:3],
    (label = "Focus", range = 1:1:size(data[1],3), format = "{1} F", startvalue = 1),
    (label = "E_ax", range = 1:1:size(data,1), format = "{1} F", startvalue = 1),
    (label = "E_ex", range = 1:1:size(data[1],3), format = "{1} F", startvalue = 1),
    tellheight = false)



#define lisenteners 
img=lift(z_slider.sliders[1].value,z_slider.sliders[2].value) do focus, angle
    data[angle][:,:,focus]
end
tittle_graph=lift(z_slider.sliders[2].value) do idx
    names_files[idx]
end

#define axis of the figure 
ax1 = Axis(fig[1, 1],
        title = tittle_graph,
        xlabel = "The x label",
        ylabel = "The y label",
        aspect = DataAspect(), 
        yreversed = true
)
ax2 = Axis(fig[1,2],
        title = "zoom",
        xlabel = "The x label",
        ylabel = "The y label",
        aspect = DataAspect(), 
        yreversed = true
)
ax3 = Axis(fig[1, 3],
        title = names_files[4],
        xlabel = "The x label",
        ylabel = "The y label",
        aspect = DataAspect(), 
        yreversed = false
)

#mouse recocnition fuction 
register_interaction!(ax1, :my_interaction) do event::MouseEvent, axis
   
    if event.type === MouseEventTypes.leftclick
        #println("$(event.data)")
        push!(mouse_pos[],event.data)
        notify(mouse_pos)
        
        
    end
end

#lisenteners of the mouse 

zoom=lift(mouse_pos,z_slider.sliders[1].value,z_slider.sliders[2].value) do x,focus,angle
    mouse_x=50
    mouse_y=50
    mouse_x=trunc(Int,x[end][1])
    mouse_y=trunc(Int,x[end][2])
    img_size=[15,15]
    x_ax=img_size[1]÷2
    y_ax=img_size[2]÷2
    y_i,y_f= mouse_y-y_ax ,mouse_y+y_ax
    x_i,x_f= mouse_x-x_ax,mouse_x+x_ax
    #println(x_i," -",x_f)
    println(mouse_x+size(data[angle],1))
    println(typeof(mouse_x)," ",typeof(mouse_x))
    #=if x_i <= x_ax
        x_i = 1
        x_f = img_size[1]
        
    elseif x_f>= size(data[angle],1)
        x_f = size(data[angle],1)
        x_i = x_f - x_ax
    end
    if -y_i <= y_ax
        y_i = 1
        y_f = img_size[2]
        println("y<axis")
    elseif -y_f <= size(data[angle],2)
        y_f = size(data[angle],2)
        y_i = y_f-y_ax=#
    #end
    println(x_i," -",x_f)
    data[angle][x_i:x_f,y_i:y_f,focus]

    
end


heatmap!(ax1,img,colormap=:grays)
heatmap!(ax2,zoom,colormap=:grays)



display(fig)

#save("heatmaps_examples.png",fig)




