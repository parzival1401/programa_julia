using MAT
using GLMakie
using Statistics
#getting the adrees of all the files in a folder 

general_directory = "/Users/fernandodelgado/Documents/university /summer 2024/intership /data /06-05-24"

names_files = readdir(general_directory,sort=true)
x,y = 10, 10
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

#sample = @view data[1][x-8:x+8,y-8:y+8,9]
sample=ones(100,100)
for i in 60:74
    for n in 20:34
        sample[n,i]=2
    end
end
fig = Figure()


ax1 = Axis(fig[1, 1], title = "sample")
ax2 = Axis(fig[1,2],title="zoom")

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


mouse_pos = Observable(Point2f[])
push!(mouse_pos[],[51,51])


register_interaction!(ax1, :my_interaction) do event::MouseEvent, axis
   
    if event.type === MouseEventTypes.leftclick
        println("$(event.data)")
        push!(mouse_pos[],event.data)
        notify(mouse_pos)
        
        
    end
end
zoom=lift(mouse_pos) do x
    
    mouse_x=trunc(Int,x[end][1])
    mouse_y=trunc(Int,x[end][2])
    img_size=[15,15]
    x_ax=img_size[1]÷2
    y_ax=img_size[2]÷2
    y_i,y_f= mouse_y-y_ax ,mouse_y+y_ax
    x_i,x_f= mouse_x-x_ax , mouse_x+x_ax
    center_m=@view sample[x_i:x_f,y_i:y_f]
    x_center,y_center=center_of_mass(center_m)
    println(x_center," ",y_center)

    sample[x_i:x_f,y_i:y_f]
    
end
heatmap!(ax1,sample,colormap=:grays)
heatmap!(ax2,zoom,colormap=:grays)
display(fig)