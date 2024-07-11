using GLMakie, FilePathsBase, MAT, Statistics, JLD2

const microscope_options = ["EPI", "TIRF"]

mutable struct NavigatorState
    current_path::String
    saved_data_path::String
    saved_model_path::String
    NavigatorState(current_path) = new(current_path, "", "")
end

function get_directory_contents(path)
    directories = String[]
    files = String[]
    for (root, dirs, fs) in walkdir(path)
        append!(directories, dirs)
        append!(files, fs)
        break  # Only process the current directory
    end
    return directories, files
end

function get_available_drives()
    if Sys.iswindows()
        drives = [string(d, ":\\") for d in 'A':'Z' if isdir(string(d, ":\\"))]
    elseif Sys.isapple()
        drives = ["/", "/Volumes"]
    else
        drives = ["/"]
    end
    return drives
end

function filter_files(dir, pattern)
    filter(name -> occursin(pattern, name), readdir(dir, sort=true))
end

function load_mat_data(folder, names, variable)
    paths = String[]
    data = Any[]
    for name in names
        path = joinpath(folder, name)
        push!(paths, path)
        open_file = MAT.matopen(path)
        var = read(open_file, variable)
        close(open_file)
        push!(data, var)
    end
    return paths, data
end

function load_jld2_data(folder, names, variable)
    paths = String[]
    data = Any[]
    for name in names
        path = joinpath(folder, name)
        println("Loading file: ", path)
        push!(paths, path)
        try
            file = jldopen(path, "r")
            if haskey(file, variable)
                var = file[variable]
                println("Original data type: ", typeof(var))
                if var isa Array{Any, 3}
                    converted_var = Array{Float64}(var)
                    push!(data, converted_var)
                    println("Converted data size: ", size(converted_var))
                elseif var isa Array{Float64, 3}
                    push!(data, var)
                    println("Loaded data size: ", size(var))
                else
                    println("Warning: Loaded data is not of type Array{Any, 3} or Array{Float64, 3}. Type: ", typeof(var))
                end
            else
                println("Warning: Variable '$variable' not found in file")
            end
            close(file)
        catch e
            println("Error loading file $path: ", e)
        end
    end
    return paths, data
end

function create_focus_controls(fig, row, col, z_slider_index)
    grid = GridLayout(tellwidth=false)
    fig[row, col] = grid
    buttons = grid[3:4,1] = [Button(fig, label="+1 focus", width=150), Button(fig, label="-1 focus", width=150)]
    snap_menu = Menu(grid[5,1], options = ["No snap", "Snap"], default="No snap")
    return grid, buttons, snap_menu, z_slider_index
end

function calculate_center_of_mass(image)
    total_mass = sum(image)
    if total_mass == 0
        return size(image) .÷ 2
    end
    
    y_indices, x_indices = axes(image)
    com_y = sum(y * image[y, x] for y in y_indices, x in x_indices) / total_mass
    com_x = sum(x * image[y, x] for y in y_indices, x in x_indices) / total_mass
    
    return round(Int, com_y), round(Int, com_x)
end
function create_main_image_listener(z_slider, menu, data_epi, data_tirf)
    return lift(z_slider.sliders[2].value, z_slider.sliders[1].value, menu.selection, data_epi, data_tirf) do focus, angle, mode, epi_data, tirf_data
        data = mode == microscope_options[1] ? epi_data : tirf_data
        
        if isempty(data) || angle > length(data)
            return zeros(256, 256)  # or any default size you prefer
        end
        
        current_data = data[angle]
        size_x, size_y, size_z = size(current_data)
        
        focus = clamp(focus, 1, size_z)
        return current_data[:, :, focus]
    end
end

function create_img_listener(mouse_pos, z_slider, menu, data_epi, data_tirf, dim, img_mid_x, img_mid_y)
    return lift(mouse_pos, z_slider.sliders[dim == :xy ? 2 : (dim == :xz ? 3 : 4)].value, z_slider.sliders[1].value, menu.selection, data_epi, data_tirf) do x, focus, angle, mode, epi_data, tirf_data
        mouse_x, mouse_y = trunc.(Int, x[end])
        data = mode == microscope_options[1] ? epi_data : tirf_data
        
        if isempty(data) || angle > length(data)
            return zeros(2*img_mid_x, 2*img_mid_y)
        end
        
        current_data = data[angle]
        size_x, size_y, size_z = size(current_data)
        
        if dim == :xy
            focus = clamp(focus, 1, size_z)
            full_slice = current_data[:, :, focus]
            
            # Define an initial region of interest around the click
            roi_size = min(size_x, size_y, 4*img_mid_x)  # Adjust this size as needed
            x_i = clamp(mouse_x - roi_size÷2, 1, size_x - roi_size + 1)
            x_f = x_i + roi_size - 1
            y_i = clamp(mouse_y - roi_size÷2, 1, size_y - roi_size + 1)
            y_f = y_i + roi_size - 1
            
            initial_roi = full_slice[x_i:x_f, y_i:y_f]
            
            # Calculate local center of mass
            local_com_y, local_com_x = calculate_center_of_mass(initial_roi)
            
            # Adjust ROI to center on local center of mass
            com_x = x_i + local_com_x - 1
            com_y = y_i + local_com_y - 1
            
            final_x_i = clamp(com_x - img_mid_x, 1, size_x - 2*img_mid_x + 1)
            final_x_f = final_x_i + 2*img_mid_x - 1
            final_y_i = clamp(com_y - img_mid_y, 1, size_y - 2*img_mid_y + 1)
            final_y_f = final_y_i + 2*img_mid_y - 1
            
            return full_slice[final_x_i:final_x_f, final_y_i:final_y_f]
        elseif dim == :xz
            y_focus = clamp(mouse_y, 1, size_y)
            x_i = max(1, mouse_x - img_mid_x)
            x_f = min(size_x, mouse_x + img_mid_x - 1)
            return current_data[x_i:x_f, y_focus, :]
        else  # yz
            x_focus = clamp(mouse_x, 1, size_x)
            y_i = max(1, mouse_y - img_mid_y)
            y_f = min(size_y, mouse_y + img_mid_y - 1)
            return current_data[x_focus, y_i:y_f, :]
        end
    end
end

function create_title_listener(z_slider, menu, names_epi, names_tirf)
    return lift(z_slider.sliders[1].value, menu.selection, names_epi, names_tirf) do idx, mode, epi_names, tirf_names
        names = mode == microscope_options[1] ? epi_names : tirf_names
        if !isempty(names) && idx <= length(names)
            return names[idx][1:end-4]
        else
            return "No data"
        end
    end
end

function create_axis(fig; title="", subtitle="", sz_title=22, sz_subtitle=17, yaxisrev=true)
    Axis(fig,
        title = title,
        subtitle = subtitle,
        aspect = DataAspect(), 
        yreversed = yaxisrev,
        titlesize = sz_title,
        subtitlesize = sz_subtitle
    )
end

function get_model_size(model_arr, img_size)
    size_x, size_y, size_z = size(model_arr)
    midle_point_z = round(Int, size_z/2)
    midle_point_x = round(Int, size_x/2)
    midle_point_y = round(Int, size_y/2)
    return size_x, size_y, size_z, midle_point_x, midle_point_y, midle_point_z
end

function create_model_listener(buttons, z_slider, menu, model_epi, model_tirf, dim, snap_menu, z_index, data_offset)
    button_offset = Observable(0)
    
    on(buttons[1].clicks) do n
        button_offset[] += 1
    end
    
    on(buttons[2].clicks) do n
        button_offset[] -= 1
    end

    return lift(button_offset, z_slider.sliders[1].value, menu.selection, snap_menu.selection, z_slider.sliders[z_index].value, model_epi, model_tirf, data_offset) do offset, angle, mode, snap, slider_value, epi_model, tirf_model, data_offset_value
        model = mode == microscope_options[1] ? epi_model : tirf_model
        println("Model type: ", typeof(model))
        println("Model size: ", size(model))
        if isempty(model) || angle > length(model)
            println("Model is empty or angle out of bounds")
            return zeros(10, 10)  # Return a default empty image if model is not available
        end
        
        size_x, size_y, size_z, midle_point_x, midle_point_y, midle_point_z = get_model_size(model[angle], img_size)
        
        max_index = dim == :xy ? size_z : (dim == :xz ? size_y : size_x)
        
        if snap == "Snap"
            effective_point = clamp(slider_value + data_offset_value, 1, max_index)
        else
            effective_point = clamp(midle_point_z + offset, 1, max_index)
        end
        
        slice = if dim == :xy
            model[angle][max(1, midle_point_x-img_mid_x+1):min(size_x, midle_point_x+img_mid_x), 
                         max(1, midle_point_y-img_mid_y+1):min(size_y, midle_point_y+img_mid_y), 
                         effective_point]
        elseif dim == :xz
            model[angle][max(1, midle_point_x-img_mid_x+1):min(size_x, midle_point_x+img_mid_x), 
                         effective_point, :]
        else  # yz
            model[angle][effective_point, 
                         max(1, midle_point_y-img_mid_y+1):min(size_y, midle_point_y+img_mid_y), :]
        end
        
        println("Slice size: ", size(slice))
        return slice
    end
end

function load_and_update_data(path, names_files_epi_data, names_files_tirf_data, data_epi, data_tirf, z_slider, data_model_offset)
    names_files_data_all = filter_files(path, r"epi|TIRF|tirf|EPI")
    names_files_epi_data[] = filter_files(path, r"epi|EPI")
    names_files_tirf_data[] = filter_files(path, r"tirf|TIRF")

    println("EPI files: ", names_files_epi_data[])
    println("TIRF files: ", names_files_tirf_data[])

    paths_data_all, data_all = load_mat_data(path, names_files_data_all, "ZStack")
    paths_data_epi, data_epi[] = load_mat_data(path, names_files_epi_data[], "ZStack")
    paths_data_tirf, data_tirf[] = load_mat_data(path, names_files_tirf_data[], "ZStack")

    println("EPI data size: ", size(data_epi[]))
    println("TIRF data size: ", size(data_tirf[]))

    data_middle_slice = 0
    if !isempty(data_epi[])
        z_slider.sliders[1].range[] = 1:1:length(data_epi[])
        z_slider.sliders[2].range[] = 1:1:size(data_epi[][1], 3)
        z_slider.sliders[1].value[] = 1
        data_middle_slice = size(data_epi[][1], 3) ÷ 2
        z_slider.sliders[2].value[] = data_middle_slice
    end

    # Update data_model_offset
    model_middle_slice = data_middle_slice + data_model_offset[]
    data_model_offset[] = model_middle_slice - data_middle_slice

    # Notify observables
    notify(data_epi)
    notify(data_tirf)
    notify(names_files_epi_data)
    notify(names_files_tirf_data)
end

function load_and_update_model(path, names_files_epi_model, names_files_tirf_model, model_epi, model_tirf, data_model_offset)
    names_files_model_all = filter_files(path, r"epi|TIRF")
    names_files_epi_model[] = filter_files(path, r"epi|EPI")
    names_files_tirf_model[] = filter_files(path, r"tirf|TIRF")

    println("EPI model files: ", names_files_epi_model[])
    println("TIRF model files: ", names_files_tirf_model[])

    paths_model_all, model_all = load_jld2_data(path, names_files_model_all, "model")
    paths_model_epi, model_epi_data = load_jld2_data(path, names_files_epi_model[], "model")
    paths_model_tirf, model_tirf_data = load_jld2_data(path, names_files_tirf_model[], "model")

    new_model_epi = Vector{Array{Float64, 3}}(filter(x -> x isa Array{Float64, 3}, model_epi_data))
    new_model_tirf = Vector{Array{Float64, 3}}(filter(x -> x isa Array{Float64, 3}, model_tirf_data))

    model_epi[] = new_model_epi
    model_tirf[] = new_model_tirf

    println("EPI model size: ", size.(model_epi[]))
    println("TIRF model size: ", size.(model_tirf[]))

    model_middle_slice = 0
    if !isempty(model_epi[])
        model_middle_slice = size(model_epi[][1], 3) ÷ 2
    end

    # Update data_model_offset
    data_middle_slice = model_middle_slice - data_model_offset[]
    data_model_offset[] = model_middle_slice - data_middle_slice

    # Notify observables
    notify(model_epi)
    notify(model_tirf)
    notify(names_files_epi_model)
    notify(names_files_tirf_model)
end

function create_file_navigator_and_main_view()
    fig = Figure(size = (1725, 1000))
    
    state = NavigatorState(homedir())
    
    menu_layout = fig[1, 1:5] = GridLayout()
    path_label = Label(menu_layout[1, 1:2], "Current path: $(state.current_path)", tellwidth=false, halign=:left)
    data_path_label = Label(menu_layout[1,2:3], "Data path: None", tellwidth=false, halign=:right)
    model_path_label = Label(menu_layout[1,4:5], "Model path: None", tellwidth=false, halign=:center)
    
    drive_menu = Menu(menu_layout[2, 1], options = get_available_drives(), tellwidth = false)
    main_menu = Menu(menu_layout[2, 2], options = [""], tellwidth = false)
    
    save_data_button = Button(menu_layout[2, 3], label = "Save Data Path", tellwidth = false)
    save_model_button = Button(menu_layout[2, 5], label = "Save Model Path", tellwidth = false)

    function handle_menu_selection(selected_item)
        if isnothing(selected_item) || selected_item == "<Empty directory>"
            return
        end
        
        if selected_item == ".."
            go_up()
        else
            new_path = joinpath(state.current_path, selected_item)
            if isdir(new_path)
                state.current_path = new_path
                path_label.text[] = "Current path: $(state.current_path)"
                update_main_menu()
            end
        end
        
        main_menu.selection[] = nothing
    end

    on(main_menu.selection) do selected_item
        handle_menu_selection(selected_item)
    end

    function update_main_menu()
        directories, files = get_directory_contents(state.current_path)
        menu_options = [".."]
        append!(menu_options, isempty(directories) ? files : directories)
        if length(menu_options) == 1
            push!(menu_options, "<Empty directory>")
        end
        main_menu.options[] = menu_options
    end

    function go_up()
        parent_dir = dirname(state.current_path)
        if parent_dir != state.current_path
            state.current_path = parent_dir
            path_label.text[] = "Current path: $(state.current_path)"
            update_main_menu()
        end
    end

    function update_drive_menu()
        drive_menu.options[] = get_available_drives()
        on(drive_menu.selection) do selected_drive
            if !isnothing(selected_drive)
                state.current_path = selected_drive
                path_label.text[] = "Current path: $(state.current_path)"
                update_main_menu()
            end
        end
    end

    update_drive_menu()
    update_main_menu()

    mouse_pos = Observable(Point2f[])
    push!(mouse_pos[], [50,50])

    menu = Menu(fig, options = microscope_options, default = "EPI")
    fig[4,1:2] = vgrid!(Label(fig, "Microscope Mode", width = nothing, fontsize=20), menu)

    global img_size = [16, 16]
    global img_mid_x, img_mid_y = img_size .÷ 2

    z_slider = SliderGrid(
        fig[5, 1:5],
        (label = "polarization", range = 1:1:1, format = "{1} F", startvalue = 1),
        (label = "xy Focus", range = 1:1:1, format = "{1} F", startvalue = 1),
        (label = "xz focus", range = -img_size[1]:1:img_size[1], format = "{1} F", startvalue = 1),
        (label = "zy Focus ", range = -img_size[2]:1:img_size[2], format = "{1} F", startvalue = 1),
        tellheight = false)

    grid_xy, buttons_xy, snap_menu_xy, z_index_xy = create_focus_controls(fig, 4, 3, 2)
    grid_xz, buttons_xz, snap_menu_xz, z_index_xz = create_focus_controls(fig, 4, 4, 3)
    grid_yz, buttons_yz, snap_menu_yz, z_index_yz = create_focus_controls(fig, 4, 5, 4)

    data_epi = Observable(Vector{Array{Float64, 3}}())
    data_tirf = Observable(Vector{Array{Float64, 3}}())
    model_epi = Observable{Vector{Array{Float64, 3}}}(Vector{Array{Float64, 3}}())
    model_tirf = Observable{Vector{Array{Float64, 3}}}(Vector{Array{Float64, 3}}())
    names_files_epi_data = Observable(String[])
    names_files_tirf_data = Observable(String[])
    names_files_epi_model = Observable(String[])
    names_files_tirf_model = Observable(String[])

    img = create_main_image_listener(z_slider, menu, data_epi, data_tirf)
    img_xy = Observable(zeros(16, 16))
    img_xz = Observable(zeros(16, 21))
    img_yz = Observable(zeros(16, 21))
    model_xy = Observable(zeros(16, 16))
    model_xz = Observable(zeros(16, 21))
    model_yz = Observable(zeros(16, 21))

    tittle_graph_data = create_title_listener(z_slider, menu, names_files_epi_data, names_files_tirf_data)
    tittle_graph_model = create_title_listener(z_slider, menu, names_files_epi_model, names_files_tirf_model)

    ax1 = create_axis(fig[2:3, 1:2], title = tittle_graph_data, sz_title = 30)
    ax2 = create_axis(fig[2,3], title = "XY data", subtitle = tittle_graph_data)
    ax3 = create_axis(fig[2,4], title = "XZ data", subtitle = tittle_graph_data)
    ax4 = create_axis(fig[2,5], title = "YZ data", subtitle = tittle_graph_data)
    ax5 = create_axis(fig[3,3], title = "XY model", subtitle = tittle_graph_model)
    ax6 = create_axis(fig[3,4], title = "XZ model", subtitle = tittle_graph_model)
    ax7 = create_axis(fig[3,5], title = "YZ model", subtitle = tittle_graph_model)

    heatmap!(ax1, img, colormap=:inferno)
    heatmap!(ax2, img_xy, colormap=:inferno)
    heatmap!(ax3, img_xz, colormap=:inferno)
    heatmap!(ax4, img_yz, colormap=:inferno)
    heatmap!(ax5, model_xy, colormap=:inferno)
    heatmap!(ax6, model_xz, colormap=:inferno)
    heatmap!(ax7, model_yz, colormap=:inferno)

    register_interaction!(ax1, :my_interaction) do event::MouseEvent, axis
        if event.type === MouseEventTypes.leftclick
            println("$(event.data)")
            push!(mouse_pos[], event.data)
            notify(mouse_pos) 
        end
    end

    img_xy_listener = create_img_listener(mouse_pos, z_slider, menu, data_epi, data_tirf, :xy, img_mid_x, img_mid_y)
    img_xz_listener = create_img_listener(mouse_pos, z_slider, menu, data_epi, data_tirf, :xz, img_mid_x, img_mid_y)
    img_yz_listener = create_img_listener(mouse_pos, z_slider, menu, data_epi, data_tirf, :yz, img_mid_x, img_mid_y)

    on(img_xy_listener) do val
        img_xy[] = val
    end
    on(img_xz_listener) do val
        img_xz[] = val
    end
    on(img_yz_listener) do val
        img_yz[] = val
    end

    data_middle_slice = 0
    model_middle_slice = 0

    if !isempty(data_epi[])
        data_middle_slice = size(data_epi[][1], 3) ÷ 2
    end

    if !isempty(model_epi[])
        model_middle_slice = size(model_epi[][1], 3) ÷ 2
    end

    data_model_offset = Observable(model_middle_slice - data_middle_slice)

    model_xy_listener = create_model_listener(buttons_xy, z_slider, menu, model_epi, model_tirf, :xy, snap_menu_xy, 2, data_model_offset)
    model_xz_listener = create_model_listener(buttons_xz, z_slider, menu, model_epi, model_tirf, :xz, snap_menu_xz, 3, data_model_offset)
    model_yz_listener = create_model_listener(buttons_yz, z_slider, menu, model_epi, model_tirf, :yz, snap_menu_yz, 4, data_model_offset)

    on(model_xy_listener) do val
        model_xy[] = val
    end
    on(model_xz_listener) do val
        model_xz[] = val
    end
    on(model_yz_listener) do val
        model_yz[] = val
    end

    on(z_slider.sliders[2].value) do val
        if snap_menu_xy.selection[] == "Snap"
            notify(model_xy_listener)
        end
    end

    on(z_slider.sliders[3].value) do val
        if snap_menu_xz.selection[] == "Snap"
            notify(model_xz_listener)
        end
    end

    on(z_slider.sliders[4].value) do val
        if snap_menu_yz.selection[] == "Snap"
            notify(model_yz_listener)
        end
    end

    for ax in [ax1, ax2, ax3, ax4, ax5, ax6, ax7]
        hidedecorations!(ax)
    end

    on(save_data_button.clicks) do n
        state.saved_data_path = state.current_path
        data_path_label.text[] = "Data path: $(state.saved_data_path)"
        println("Data path saved: $(state.saved_data_path)")
        load_and_update_data(state.saved_data_path, names_files_epi_data, names_files_tirf_data, data_epi, data_tirf, z_slider, data_model_offset)
    end

    on(save_model_button.clicks) do n
        state.saved_model_path = state.current_path
        model_path_label.text[] = "Model path: $(state.saved_model_path)"
        println("Model path saved: $(state.saved_model_path)")
        load_and_update_model(state.saved_model_path, names_files_epi_model, names_files_tirf_model, model_epi, model_tirf, data_model_offset)
    end

    display(fig)
end

# Call the function to create and display the file navigator and main view
create_file_navigator_and_main_view()