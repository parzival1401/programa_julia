using MAT
using GLMakie
using Statistics
using JLD2


if Sys.isapple()
    #model_prediction_dir = joinpath("/Users","fernandodelgado","Documents","university ","summer 2024","intership ","data ","model_data")
    model_prediction_dir = joinpath("/Volumes","lidke-lrs","Projects","TIRF Demo","fernando","model_data") 
    general_directory_data = joinpath("/Volumes","lidke-lrs","Projects","TIRF Demo","fernando","06-21-24") 

elseif Sys.iswindows()
    general_directory_data = "Y:\\Projects\\TIRF Demo\\fernando\\06-21-24"
    model_prediction_dir = "Y:\\Projects\\TIRF Demo\\fernando\\model_data"
    #model_prediction_dir= "/Users/fernandodelgado/Documents/university /summer 2024/intership /data /model_data"
end

#### names of model 
names_files_model_all = filter(name -> occursin(r"epi|TIRF", name), readdir(model_prediction_dir, sort=true))
names_files_epi_model = filter(name -> occursin(r"epi|EPI", name), readdir(model_prediction_dir,sort=true))
names_files_tirf_model = filter(name -> occursin(r"tirf|TIRF", name), readdir(model_prediction_dir,sort=true))
names_files_model = deepcopy(names_files_tirf_model)
##### names of data 
names_files_data_all = filter(name -> occursin(r"epi|TIRF|tirf|EPI", name), readdir(general_directory_data, sort=true))
names_files_epi_data= filter(name -> occursin(r"epi|EPI", name), readdir(general_directory_data,sort=true))
names_files_tirf_data = filter(name -> occursin(r"tirf|TIRF", name), readdir(general_directory_data,sort=true))
names_files_data = deepcopy(names_files_tirf_data)
#fuction to calculate the center of mass 


function center_of_mass(array) 
    x_coords = repeat(1:size(array, 1), outer=(size(array, 1), 1))
    y_coords = reshape(repeat([1:size(array, 1);], inner=(size(array, 2))), size(array))
    total_mass = sum(array)
    center_x = round(Int, sum(x_coords .* array[:]) / total_mass)
    center_y = round(Int, sum(y_coords .* array) / total_mass)
    return center_x, center_y
end

function join_dir_names_data(folder, names,variable)
    paths_general = Vector{String}()
    data = Vector{Any}()  
    for i in names
        path = joinpath(folder, i)  
        push!(paths_general, path)
        open_file = MAT.matopen(path)
        var = read(open_file, variable)
        close(open_file)  
        push!(data, var)
    end
    return paths_general, data
end
function join_dir_names_model(folder, names,variable)
    paths_general = Vector{String}()
    data = Vector{Any}() 
    for i in names
        path = joinpath(folder, i)
        println(path) 
        push!(paths_general, path)
        var = load(path, variable)
        push!(data, var)
    end
    return paths_general,data
end
function size_model(model_arr,angle,img_size)
    size_x =size(model_arr[angle],1)
    size_y =size(model_arr[angle],2)
    size_z =size(model_arr[angle],3)
    midle_point_z = round(Int,size_z/2)
    midle_point_x = round(Int,size_x/2)
    midle_point_y = round(Int,size_y/2)
    return size_x,size_y,size_z,midle_point_x,midle_point_y,midle_point_z
end
#load data
paths_data_all, data_all=join_dir_names_data(general_directory_data,names_files_data_all,"ZStack")
paths_data_epi, data_epi = join_dir_names_data(general_directory_data,names_files_epi_data,"ZStack")
paths_data_tirf, data_tirf = join_dir_names_data(general_directory_data,names_files_tirf_data,"ZStack")
data = deepcopy(data_tirf)
#load model 
paths_model_all, model_all = join_dir_names_model(model_prediction_dir,names_files_model_all,"model")
paths_model_epi, model_epi = join_dir_names_model(model_prediction_dir,names_files_epi_model,"model")
paths_model_tirf, model_tirf= join_dir_names_model(model_prediction_dir,names_files_tirf_model,"model")
model = deepcopy(model_tirf)
fig = Figure(size=(1725,1000))

#click recocnition Initialization fo observables 

mouse_pos = Observable(Point2f[])
push!(mouse_pos[],[50,50])

# menu for microscope mode
microscope_options = ["EPI","TIRF"]
menu = Menu(fig, options = microscope_options,default = "EPI")
fig[3,1:2] = vgrid!(Label(fig,"Microscope Mode",width = nothing,fontsize=20),menu)
#menu options 
on(menu.selection) do mode 
    if mode == microscope_options[1]
        data = data_epi
        names_files_data = names_files_epi_data
        names_model = names_files_epi_model
        println("epi")
    elseif mode == microscope_options[2]
        data = data_epi
        names_files_data = names_files_tirf_data
        names_model = names_files_tirf_model
        println("tirf")
    end
end
#### sample image size
img_size=[16,16]
img_mid_x = round(Int,img_size[1]/2)
img_mid_y = round(Int,img_size[2]/2)


#crete sliders 
z_slider=SliderGrid(
    fig[4, 1:5],
    (label = "xy Focus", range = 1:1:size(data[1],3), format = "{1} F", startvalue = round(Int,size(data[1],3)/2)),
    (label = "polarization", range = 1:1:size(data,1), format = "{1} F", startvalue = size(data,1)),
    (label = "xz focus", range = -img_size[1]:1:img_size[1], format = "{1} F", startvalue = 1),
    (label = "xz Focus ", range = -img_size[2]:1:img_size[2], format = "{1} F", startvalue = 1),
    tellheight = false)

# botoms focus model 

fig[3,3] = grid_xy = GridLayout(tellwidth=false,title="hola")
buttons_xy = grid_xy[3:4,1]= [Button(fig,label="+1 focus",width=150),Button(fig,label="-1 focus",width=150)]
fig[3,4] = grid_xz = GridLayout(tellwidth=false)
buttons_xz = grid_xz[3:4,1]= [Button(fig,label="+1 focus",width=150),Button(fig,label="-1 focus",width=150)]
fig[3,5] = grid_yz = GridLayout(tellwidth=false)
buttons_yz = grid_yz[3:4,1]= [Button(fig,label="+1 focus",width=150),Button(fig,label="-1 focus",width=150)]


#define lisenteners 

img = lift(z_slider.sliders[1].value,z_slider.sliders[2].value,menu.selection) do focus, angle,mode
    if mode == microscope_options[1]
        return data_epi[angle][:,:,focus]
    elseif mode == microscope_options[2]
        return data_tirf[angle][:,:,focus]
    end
end

model_xy=lift(buttons_xy[1].clicks,buttons_xy[2].clicks,z_slider.sliders[2].value,menu.selection) do in,out,angle,mode
    if mode == microscope_options[1]
        size_x,size_y,size_z,midle_point_x,midle_point_y,midle_point_z = size_model(model_epi,angle,img_size)
        if midle_point_z+in-out> size_z
            return model_epi[angle][midle_point_x-img_mid_x:midle_point_x+img_mid_x,midle_point_y-img_mid_y:midle_point_y+img_mid_y,end]'
        elseif midle_point_z+in-out<1
            return model_epi[angle][midle_point_x-img_mid_x:midle_point_x+img_mid_x,midle_point_y-img_mid_y:midle_point_y+img_mid_y,1]'
        else
            return model_epi[angle][midle_point_x-img_mid_x:midle_point_x+img_mid_x,midle_point_y-img_mid_y:midle_point_y+img_mid_y,midle_point_z+in-out]'
        end
     elseif mode == microscope_options[2]
        size_x,size_y,size_z,midle_point_x,midle_point_y,midle_point_z = size_model(model_tirf,angle,img_size)
        if midle_point_z+in-out> size_z
            return model_tirf[angle][midle_point_x-img_mid_x:midle_point_x+img_mid_x,midle_point_y-img_mid_y:midle_point_y+img_mid_y,end]'
        elseif midle_point_z+in-out<1
            return model_tirf[angle][midle_point_x-img_mid_x:midle_point_x+img_mid_x,midle_point_y-img_mid_y:midle_point_y+img_mid_y,1]'
        else
            return model_tirf[angle][midle_point_x-img_mid_x:midle_point_x+img_mid_x,midle_point_y-img_mid_y:midle_point_y+img_mid_y,midle_point_z+in-out]'
        end

    end
    
end
model_xz=lift(buttons_xz[1].clicks,buttons_xz[2].clicks,z_slider.sliders[2].value,menu.selection) do in,out,angle,mode
    if mode == microscope_options[1]
        size_x,size_y,size_z,midle_point_x,midle_point_y,midle_point_z = size_model(model_epi,angle,img_size)
        if midle_point_y+in-out> size_y
            return model_epi[angle][midle_point_x-img_mid_x:midle_point_x+img_mid_x,end,:]'
        elseif midle_point_y+in-out<1
            return model_epi[angle][midle_point_x-img_mid_x:midle_point_x+img_mid_x,1,:]'
        else
            return model_epi[angle][midle_point_x-img_mid_x:midle_point_x+img_mid_x,midle_point_y+in-out,:]'
        end
    elseif mode == microscope_options[2]
        size_x,size_y,size_z,midle_point_x,midle_point_y,midle_point_z = size_model(model_tirf,angle,img_size)
        if midle_point_y+in-out> size_y
            return model_tirf[angle][midle_point_x-img_mid_x:midle_point_x+img_mid_x,end,:]'
        elseif midle_point_y+in-out<1
            return model_tirf[angle][midle_point_x-img_mid_x:midle_point_x+img_mid_x,1,:]'
        else
            return model_tirf[angle][midle_point_x-img_mid_x:midle_point_x+img_mid_x,midle_point_y+in-out,:]'
        end
    end
end
model_yz = lift(buttons_yz[1].clicks,buttons_yz[2].clicks,z_slider.sliders[2].value,menu.selection) do in,out,angle,mode
    if mode == microscope_options[1]
        size_x,size_y,size_z,midle_point_x,midle_point_y,midle_point_z = size_model(model_epi,angle,img_size)
        if midle_point_x+in-out> size_x
            return model_epi[angle][end,midle_point_y-img_mid_y:midle_point_y+img_mid_y,:]' 
        elseif midle_point_x+in-out<1
            return model_epi[angle][1,midle_point_y-img_mid_y:midle_point_y+img_mid_y,:]'
        else
            return model_epi[angle][midle_point_x+in-out,midle_point_y-img_mid_y:midle_point_y+img_mid_y,:]'
        end
    elseif mode == microscope_options[2]
        size_x,size_y,size_z,midle_point_x,midle_point_y,midle_point_z = size_model(model_tirf,angle,img_size)
        if midle_point_x+in-out> size_x
            return model_tirf[angle][end,midle_point_y-img_mid_y:midle_point_y+img_mid_y,:]'
        elseif midle_point_x+in-out<1
            return model_tirf[angle][1,midle_point_y-img_mid_y:midle_point_y+img_mid_y,:]'
        else
            return model_tirf[angle][midle_point_x+in-out,midle_point_y-img_mid_y:midle_point_y+img_mid_y,:]'
        end
    end
end

tittle_graph_data=lift(z_slider.sliders[2].value,menu.selection) do idx,mode
    if mode == microscope_options[1]
        return names_files_epi_data[idx][1:end-4]
    elseif mode == microscope_options[2]
        return names_files_tirf_data[idx][1:end-4]
    end
end
tittle_graph_model=lift(z_slider.sliders[2].value,menu.selection) do idx,mode
    if mode == microscope_options[1]
        return names_files_epi_model[idx][1:end-4]
    elseif mode == microscope_options[2]
        return names_files_tirf_model[idx][1:end-4]
    end
end

sz_title = 22
sz_subtitle = 17
#define axis of theA figure 
ax1 = Axis(fig[1:2, 1:2],
        title = tittle_graph_data,
        aspect = DataAspect(), 
        yreversed = true, xzoomlock=true,yzoomlock=true,titlesize=30
)
ax2 = Axis(fig[1,3],
        title =  "XY data",
        subtitle = tittle_graph_data,
        aspect = DataAspect(), 
        yreversed = true,titlesize=sz_title,subtitlesize=sz_subtitle
)
ax3 = Axis(fig[1, 4],
        title =  "XZ data",
        subtitle = tittle_graph_data,
        aspect = DataAspect(), 
        yreversed = true,titlesize=sz_title,subtitlesize=sz_subtitle
)
ax4 = Axis(fig[1,5],
        title =  "YZ data",
        subtitle = tittle_graph_data,
        aspect = DataAspect(), 
        yreversed = true,titlesize=sz_title,subtitlesize=sz_subtitle
)
ax5 = Axis(fig[2, 3],
        title = "XY model",
        subtitle = tittle_graph_model,
        aspect = DataAspect(), 
        yreversed = true,titlesize=sz_title
)
ax6 = Axis(fig[2, 4],
        title = "XZ model",
        subtitle = tittle_graph_model,
        aspect = DataAspect(), 
        yreversed = true,titlesize=sz_title
)
ax7 = Axis(fig[2, 5],
        title = "YZ model",
        subtitle = tittle_graph_model,
        aspect = DataAspect(), 
        yreversed = true,titlesize=sz_title
)
#mouse recocnition fuction 
register_interaction!(ax1, :my_interaction) do event::MouseEvent, axis
   
    if event.type === MouseEventTypes.leftclick
        println("$(event.data)")
        push!(mouse_pos[],event.data)
        notify(mouse_pos) 
    end
end

##### scroll xz
img_xz=lift(mouse_pos,z_slider.sliders[3].value,z_slider.sliders[2].value,menu.selection) do x,focus,angle,mode
    mouse_x=139
    mouse_y=56
    mouse_x=trunc(Int,x[end][1])
    mouse_y=trunc(Int,x[end][2])
    x_ax=img_size[1]÷2
    y_ax=img_size[2]÷2
    y_i,y_f= mouse_y-y_ax ,mouse_y+y_ax
    x_i,x_f= mouse_x-x_ax , mouse_x+x_ax
    if mode == microscope_options[1]
        return data_epi[angle][mouse_x+focus,y_i:y_f,:]'
    elseif mode == microscope_options[2]
        return data_tirf[angle][mouse_x+focus,y_i:y_f,:]'
    end
    
end
img_yz=lift(mouse_pos,z_slider.sliders[4].value,z_slider.sliders[2].value,menu.selection) do x,focus,angle,mode
    mouse_x=139
    mouse_y=56
    mouse_x=trunc(Int,x[end][1])
    mouse_y=trunc(Int,x[end][2])
    img_size=[16,16]
    x_ax=img_size[1]÷2
    y_ax=img_size[2]÷2
    y_i,y_f= mouse_y-y_ax ,mouse_y+y_ax
    x_i,x_f= mouse_x-x_ax , mouse_x+x_ax
    if mode == microscope_options[1]
        return data_epi[angle][x_i:x_f,mouse_y+focus,:]'
    elseif mode == microscope_options[2]
        return data_tirf[angle][x_i:x_f,mouse_y+focus,:]'
    end
    
end

#lisenteners of the mouse 

img_xy=lift(mouse_pos,z_slider.sliders[1].value,z_slider.sliders[2].value,menu.selection) do x,focus,angle,mode
    mouse_x=139
    mouse_y=56
    mouse_x=trunc(Int,x[end][1])
    mouse_y=trunc(Int,x[end][2])
    img_size=[16,16]
    x_ax=img_size[1]÷2
    y_ax=img_size[2]÷2
    y_i,y_f= mouse_y-y_ax ,mouse_y+y_ax
    x_i,x_f= mouse_x-x_ax , mouse_x+x_ax
    #=img_zomm=@view data[angle][x_i:x_f,y_i:y_f,focus]
    x_center,y_center=center_of_mass(img_zomm)
    x_offset= mouse_x-x_ax-x_center
    y_offset= mouse_y-y_ax-y_center
    println(mouse_x," ",mouse_y)
    println(x_center," ",y_center)
    println(mouse_x-x_center," ",mouse_x+x_center)
    println(mouse_y-y_center," ",mouse_y+y_center)=#
    if mode == microscope_options[1]
        return data_epi[angle][x_i:x_f,y_i:y_f,focus]
    elseif mode == microscope_options[2]
        return data_tirf[angle][x_i:x_f,y_i:y_f,focus]
    end
    
    
end

heatmap!(ax1,img,colormap=:inferno )
heatmap!(ax2,img_xy,colormap=:inferno)
heatmap!(ax3,img_xz,colormap=:inferno)
heatmap!(ax4,img_yz,colormap=:inferno)
heatmap!(ax5,model_xy,colormap=:inferno)
heatmap!(ax6,model_xz,colormap=:inferno)
heatmap!(ax7,model_yz,colormap=:inferno)
hidedecorations!(ax1)
hidedecorations!(ax2)
hidedecorations!(ax3)
hidedecorations!(ax4)
hidedecorations!(ax5)
hidedecorations!(ax6)
hidedecorations!(ax7)
display(fig)








