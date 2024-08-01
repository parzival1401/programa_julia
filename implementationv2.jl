using GLMakie, FilePathsBase, MAT, Statistics, JLD2

const microscope_options = ["EPI", "TIRF"]

"""
    NavigatorState(current_path::String)

A mutable struct to keep track of the current path and saved paths for data and model.

# Fields
- `current_path::String`: Current directory path
- `saved_data_path::String`: Path where data is saved
- `saved_model_path::String`: Path where model is saved
"""
mutable struct NavigatorState
    current_path::String
    saved_data_path::String
    saved_model_path::String
    NavigatorState(current_path) = new(current_path, "", "")
end

"""
    get_directory_contents(path::String) -> Tuple{Vector{String}, Vector{String}}

Retrieves the contents (directories and files) of the specified path.

# Arguments
- `path::String`: The directory path to examine

# Returns
- A tuple containing two vectors: (directories, files)
"""
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

"""
    get_available_drives() -> Vector{String}

Returns a list of available drives based on the operating system.

# Returns
- An array of drive paths
"""
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

"""
    filter_files(dir::String, pattern::Regex) -> Vector{String}

Filters files in the given directory based on the specified regex pattern.

# Arguments
- `dir::String`: The directory to search
- `pattern::Regex`: The regex pattern to match file names

# Returns
- An array of filtered file names
"""
function filter_files(dir, pattern)
    filter(name -> occursin(pattern, name), readdir(dir, sort=true))
end

"""
    load_mat_data(folder::String, names::Vector{String}, variable::String) -> Tuple{Vector{String}, Vector{Any}}

Loads MAT file data from the specified folder for the given file names and variable.

# Arguments
- `folder::String`: The folder containing the MAT files
- `names::Vector{String}`: Names of the files to load
- `variable::String`: Name of the variable to extract from each file

# Returns
- A tuple containing: (file paths, loaded data)
"""
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

"""
    load_jld2_data(folder::String, names::Vector{String}, variable::String) -> Tuple{Vector{String}, Vector{Any}}

Loads JLD2 file data from the specified folder for the given file names and variable.

# Arguments
- `folder::String`: The folder containing the JLD2 files
- `names::Vector{String}`: Names of the files to load
- `variable::String`: Name of the variable to extract from each file

# Returns
- A tuple containing: (file paths, loaded data)
"""
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

"""
    create_focus_controls(fig::Figure, row::Int, col::Int, z_slider_index::Int) -> Tuple{GridLayout, Vector{Button}, Menu, Int}

Creates focus control buttons and snap menu for the GUI.

# Arguments
- `fig::Figure`: The main figure
- `row::Int`: Row position in the figure
- `col::Int`: Column position in the figure
- `z_slider_index::Int`: Index of the z-slider

# Returns
- A tuple containing: (grid, buttons, snap_menu, z_slider_index)
"""
function create_focus_controls(fig, row, col, z_slider_index)
    grid = GridLayout(tellwidth=false)
    fig[row, col] = grid
    buttons = grid[3:4,1] = [Button(fig, label="+1 focus", width=150), Button(fig, label="-1 focus", width=150)]
    snap_menu = Menu(grid[5,1], options = ["No snap", "Snap"], default="No snap")
    return grid, buttons, snap_menu, z_slider_index
end

"""
    com(im::Array{Float64, 2}, cnt::Tuple{Int, Int}, sz::Int) -> Tuple{Int, Int}

Calculates the center of mass for a given image region.

# Arguments
- `im::Array{Float64, 2}`: The input image
- `cnt::Tuple{Int, Int}`: The initial center point (y, x)
- `sz::Int`: The size of the region to consider

# Returns
- A tuple containing the (y, x) coordinates of the center of mass
"""
function com(im, cnt, sz)
    y, x = cnt
    y_st = Int(round(clamp(y - sz / 2 - 1, 1, size(im, 1))))
    y_en = Int(round(clamp(y_st + sz, 1, size(im, 1))))
    x_st = Int(round(clamp(x - sz / 2 - 1, 1, size(im, 2))))
    x_en = Int(round(clamp(x_st + sz, 1, size(im, 2))))

    im_min = minimum(view(im, y_st:y_en, x_st:x_en))
    com_x = 0.0
    com_y = 0.0
    total = 0.0
    for i in y_st:y_en
        for j in x_st:x_en
            com_y += (im[i, j] - im_min) * i
            com_x += (im[i, j] - im_min) * j
            total += (im[i, j] - im_min)
        end
    end

    com_y = com_y / total
    com_x = com_x / total

    if total == 0.0
        return cnt
    end

    return round(Int, com_y), round(Int, com_x)
end

"""
    create_main_image_listener(z_slider::SliderGrid, menu::Menu, data_epi::Observable, data_tirf::Observable) -> Observable

Creates a listener for the main image display, updating based on slider values and menu selection.

# Arguments
- `z_slider::SliderGrid`: The slider grid containing focus and polarization sliders
- `menu::Menu`: The menu for selecting between EPI and TIRF modes
- `data_epi::Observable`: Observable containing EPI data
- `data_tirf::Observable`: Observable containing TIRF data

# Returns
- An Observable for the main image data
"""
function create_main_image_listener(z_slider, menu, data_epi, data_tirf)
    return lift(z_slider.sliders[2].value, z_slider.sliders[1].value, menu.selection, data_epi, data_tirf) do focus, angle, mode, epi_data, tirf_data
        data = mode == microscope_options[1] ? epi_data : tirf_data
        
        if isempty(data) || angle > length(data)
            return zeros(256, 256)  # or any default size you prefer
        end
        
        current_data = data[angle]
        size_y, size_x, size_z = size(current_data)
        
        focus = clamp(focus, 1, size_z)
        return current_data[:, :, focus]
    end
end

"""
    get_sub_im(im::Array{Float64, 2}, cnt::Tuple{Int, Int}, sz::Int) -> Array{Float64, 2}

Extracts a sub-image from the given image based on center coordinates and size.

# Arguments
- `im::Array{Float64, 2}`: The input image
- `cnt::Tuple{Int, Int}`: The center point (y, x) of the sub-image
- `sz::Int`: The size of the sub-image

# Returns
- A sub-image array
"""
function get_sub_im(im, cnt, sz)
    y, x = cnt
    y_st = Int(round(clamp(y - sz / 2, 1, size(im, 1))))
    y_en = Int(round(clamp(y_st + sz, 1, size(im, 1))))
    x_st = Int(round(clamp(x - sz / 2, 1, size(im, 2))))
    x_en = Int(round(clamp(x_st + sz, 1, size(im, 2))))
    return im[y_st:y_en, x_st:x_en]
end

"""
    create_img_listener(mouse_pos::Observable, z_slider::SliderGrid, menu::Menu, data_epi::Observable, data_tirf::Observable, dim::Symbol, img_mid_x::Int, img_mid_y::Int) -> Observable

Creates a listener for image updates based on mouse position, slider values, and menu selection.

# Arguments
- `mouse_pos::Observable`: Observable containing the current mouse position
- `z_slider::SliderGrid`: The slider grid containing focus and polarization sliders
- `menu::Menu`: The menu for selecting between EPI and TIRF modes
- `data_epi::Observable`: Observable containing EPI data
- `data_tirf::Observable`: Observable containing TIRF data
- `dim::Symbol`: The dimension to process (:xy, :xz, or :yz)
- `img_mid_x::Int`: Half the width of the image
- `img_mid_y::Int`: Half the height of the image

# Returns
- An Observable for the processed image data
"""
function create_img_listener(mouse_pos, z_slider, menu, data_epi, data_tirf, dim, img_mid_x, img_mid_y)
    return lift(mouse_pos, z_slider.sliders[dim == :xy ? 2 : (dim == :xz ? 3 : 4)].value, z_slider.sliders[1].value, menu.selection, data_epi, data_tirf) do x, focus, angle, mode, epi_data, tirf_data
        mouse_x, mouse_y = trunc.(Int, x[end])
        data = mode == microscope_options[1] ? epi_data : tirf_data
        
        if isempty(data) || angle > length(data)
            return zeros(2*img_mid_y, 2*img_mid_x)
        end
        
        current_data = data[angle]
        size_y, size_x, size_z = size(current_data)
        
        if dim == :xy
            focus = clamp(focus, 1, size_z)
            full_slice = current_data[:, :, focus]
            full_slice .-= minimum(full_slice)
            sz = img_size[1]
            cmy_old, cmx_old = mouse_y, mouse_x
            cmy_new, cmx_new = com(full_slice, [cmy_old, cmx_old], sz)
            println("first com: $cmy_new,  $cmx_new")
            while (cmy_new != cmy_old) || (cmx_new != cmx_old)
                temp_com = [cmy_new, cmx_new]
                cmy_new, cmx_new = com(full_slice, [cmy_new, cmx_new], sz)
                cmy_old, cmx_old = temp_com
                println("updated com: $cmy_new,  $cmx_new")
            end
            cmy, cmx = cmy_new, cmx_new
            println("final: $cmy,  $cmx")
            return get_sub_im(full_slice, [cmy, cmx], sz)
        elseif dim == :xz
            x_focus = clamp(focus+mouse_x, 1, size_y)
            y_i = max(1, mouse_y - img_mid_y)
            y_f = min(size_y, mouse_y + img_mid_y - 1)
            return current_data[y_i:y_f, x_focus, :]
        else  # yz
            y_focus = clamp(focus+mouse_y, 1, size_y)
            x_i = max(1, mouse_x - img_mid_x)
            x_f = min(size_x, mouse_x + img_mid_x - 1)
            return current_data[y_focus, x_i:x_f, :]
        end
    end
end

"""
    create_title_listener(z_slider::SliderGrid, menu::Menu, names_epi::Observable, names_tirf::Observable) -> Observable

Creates a listener for updating the title based on slider values and menu selection.

# Arguments
- `z_slider::SliderGrid`: The slider grid containing focus and polarization sliders
- `menu::Menu`: The menu for selecting between EPI and TIRF modes
- `names_epi::Observable`: Observable containing EPI file names
- `names_tirf::Observable`: Observable containing TIRF file names

# Returns
- An Observable for the title text
"""
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

"""
    create_axis(fig::Figure; title::String="", subtitle::String="", sz_title::Int=22, sz_subtitle::Int=17, yaxisrev::Bool=true) -> Axis

Creates an axis for the figure with specified properties.

# Arguments
- `fig::Figure`: The main figure
- `title::String`: The title for the axis
- `subtitle::String`: The subtitle for the axis
- `sz_title::Int`: Font size for the title
- `sz_subtitle::Int`: Font size for the subtitle
- `yaxisrev::Bool`: Whether to reverse the y-axis

# Returns
- An Axis object
"""
function create_axis(fig; title="", subtitle="", sz_title=22, sz_subtitle=17, yaxisrev=true)
    GLMakie.Axis(fig,
        title = title,
        subtitle = subtitle,
        aspect = DataAspect(), 
        yreversed = yaxisrev,
        titlesize = sz_title,
        subtitlesize = sz_subtitle
    )
end

"""
    get_model_size(model_arr::Array{Float64, 3}, img_size::Vector{Int}) -> Tuple{Int, Int, Int, Int, Int, Int}

Calculates various size parameters for the model array.

# Arguments
- `model_arr::Array{Float64, 3}`: The 3D model array
- `img_size::Vector{Int}`: The size of the image

# Returns
- A tuple containing: (size_y, size_x, size_z, midle_point_y, midle_point_x, midle_point_z)
"""
function get_model_size(model_arr, img_size)
    size_y, size_x, size_z = size(model_arr)
    midle_point_z = round(Int, size_z/2)
    midle_point_y = round(Int, size_y/2)
    midle_point_x = round(Int, size_x/2)
    return size_y, size_x, size_z, midle_point_y, midle_point_x, midle_point_z
end

"""
    create_model_listener(buttons::Vector{Button}, z_slider::SliderGrid, menu::Menu, model_epi::Observable, model_tirf::Observable, dim::Symbol, snap_menu::Menu, z_index::Int, data_offset::Observable) -> Observable

Creates a listener for model updates based on button clicks, slider values, and menu selections.

# Arguments
- `buttons::Vector{Button}`: Focus control buttons
- `z_slider::SliderGrid`: The slider grid containing focus and polarization sliders
- `menu::Menu`: The menu for selecting between EPI and TIRF modes
- `model_epi::Observable`: Observable containing EPI model data
- `model_tirf::Observable`: Observable containing TIRF model data
- `dim::Symbol`: The dimension to process (:xy, :xz, or :yz)
- `snap_menu::Menu`: Menu for selecting snap mode
- `z_index::Int`: Index of the z-slider
- `data_offset::Observable`: Observable containing the offset between data and model

# Returns
- An Observable for the processed model data
"""
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
        
        size_y, size_x, size_z, midle_point_y, midle_point_x, midle_point_z = get_model_size(model[angle], img_size)
        println("midle_point_z: ", midle_point_z)
        max_index = dim == :xy ? size_z : (dim == :xz ? size_y : size_x)
        
        slice = if dim == :xy
            if snap == "Snap"
                effective_point = clamp(slider_value + img_size[1], 1, max_index)
            else
                effective_point = clamp(midle_point_z + offset, 1, max_index)
                println("Effective point: ", effective_point)
            end
            return permutedims(model[angle][max(1, midle_point_y-img_mid_y+1):min(size_y, midle_point_y+img_mid_y), 
                         max(1, midle_point_x-img_mid_x+1):min(size_x, midle_point_x+img_mid_x), 
                         effective_point],[2,1])
        elseif dim == :xz
            if snap == "Snap"
                effective_point = clamp(slider_value + img_size[1], 1, max_index)
            else
                effective_point = clamp(midle_point_z + offset, 1, max_index)
                println("Effective point: ", effective_point)
            end
            return model[angle][max(1, midle_point_y-img_mid_y+1):min(size_y, midle_point_y+img_mid_y), 
                         effective_point, :]
        else  # yz
            if snap == "Snap"
                effective_point = clamp(slider_value + img_size[1], 1, max_index)
            else
                effective_point = clamp(midle_point_z + offset, 1, max_index)
                println("Effective point: ", effective_point)
            end
            return model[angle][effective_point, 
                         max(1, midle_point_x-img_mid_x+1):min(size_x, midle_point_x+img_mid_x), :]
        end
        
        println("Slice size: ", size(slice))
        return slice
    end
end

"""
    load_and_update_data(path::String, names_files_epi_data::Observable, names_files_tirf_data::Observable, data_epi::Observable, data_tirf::Observable, z_slider::SliderGrid, data_model_offset::Observable)

Loads and updates data from the specified path, updating relevant Observables and slider ranges.

# Arguments
- `path::String`: The path to load data from
- `names_files_epi_data::Observable`: Observable for EPI data file names
- `names_files_tirf_data::Observable`: Observable for TIRF data file names
- `data_epi::Observable`: Observable for EPI data
- `data_tirf::Observable`: Observable for TIRF data
- `z_slider::SliderGrid`: The slider grid to update
- `data_model_offset::Observable`: Observable for the offset between data and model
"""
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

"""
    load_and_update_model(path::String, names_files_epi_model::Observable, names_files_tirf_model::Observable, model_epi::Observable, model_tirf::Observable, data_model_offset::Observable)

Loads and updates model data from the specified path, updating relevant Observables.

# Arguments
- `path::String`: The path to load model data from
- `names_files_epi_model::Observable`: Observable for EPI model file names
- `names_files_tirf_model::Observable`: Observable for TIRF model file names
- `model_epi::Observable`: Observable for EPI model data
- `model_tirf::Observable`: Observable for TIRF model data
- `data_model_offset::Observable`: Observable for the offset between data and model
"""
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

"""
    create_file_navigator_and_main_view()

Creates the main GUI for file navigation and image visualization.
"""
function create_file_navigator_and_main_view()
    # Create the main figure for the GUI
    fig = Figure(size = (1725, 1000))
    
    # Initialize the state with the home directory
    state = NavigatorState(homedir())
    
    # Create the layout for the menu and path labels
    menu_layout = fig[1, 1:5] = GridLayout()
    path_label = Label(menu_layout[1, 1:2], "Current path: $(state.current_path)", tellwidth=false, halign=:left)
    data_path_label = Label(menu_layout[1,2:3], "Data path: None", tellwidth=false, halign=:right)
    model_path_label = Label(menu_layout[1,4:5], "Model path: None", tellwidth=false, halign=:center)
    
    # Create menus for drive selection and file/directory navigation
    drive_menu = Menu(menu_layout[2, 1], options = get_available_drives(), tellwidth = false)
    main_menu = Menu(menu_layout[2, 2], options = [""], tellwidth = false)
    
    # Create buttons for saving data and model paths
    save_data_button = Button(menu_layout[2, 3], label = "Save Data Path", tellwidth = false)
    save_model_button = Button(menu_layout[2, 5], label = "Save Model Path", tellwidth = false)

    # Function to handle menu item selection
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

    # Set up the listener for main menu selection
    on(main_menu.selection) do selected_item
        handle_menu_selection(selected_item)
    end

    # Function to update the main menu with current directory contents
    function update_main_menu()
        directories, files = get_directory_contents(state.current_path)
        menu_options = [".."]
        append!(menu_options, isempty(directories) ? files : directories)
        if length(menu_options) == 1
            push!(menu_options, "<Empty directory>")
        end
        main_menu.options[] = menu_options
    end

    # Function to navigate up one directory level
    function go_up()
        parent_dir = dirname(state.current_path)
        if parent_dir != state.current_path
            state.current_path = parent_dir
            path_label.text[] = "Current path: $(state.current_path)"
            update_main_menu()
        end
    end

    # Function to update the drive menu and handle drive selection
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

    # Initialize the drive menu and main menu
    update_drive_menu()
    update_main_menu()

    # Set up mouse position tracking
    mouse_pos = Observable(Point2f[])
    push!(mouse_pos[], [50,50])

    # Create a menu for selecting between EPI and TIRF modes
    menu = Menu(fig, options = microscope_options, default = "EPI")
    fig[4,1:2] = vgrid!(Label(fig, "Microscope Mode", width = nothing, fontsize=20), menu)

    # Define global image size parameters
    global img_size = [16, 16]
    global img_mid_y, img_mid_x = img_size .÷ 2

    # Create sliders for controlling various aspects of the visualization
    z_slider = SliderGrid(
        fig[5, 1:5],
        (label = "polarization", range = 1:1:1, format = "{1} ", startvalue = 1),
        (label = "xy Focus", range = 1:1:1, format = "{1} ", startvalue = 1),
        (label = "xz focus", range = -img_size[1]:1:img_size[1], format = "{1} ", startvalue = 0),
        (label = "zy Focus ", range =-img_size[2]:1:img_size[2], format = "{1} ", startvalue = 0),
    tellheight = false)

    # Create focus controls for XY, XZ, and YZ views
    grid_xy, buttons_xy, snap_menu_xy, z_index_xy = create_focus_controls(fig, 4, 3, 2)
    grid_xz, buttons_xz, snap_menu_xz, z_index_xz = create_focus_controls(fig, 4, 4, 3)
    grid_yz, buttons_yz, snap_menu_yz, z_index_yz = create_focus_controls(fig, 4, 5, 4)

    # Initialize Observables for storing data and model information
    data_epi = Observable(Vector{Array{Float64, 3}}())
    data_tirf = Observable(Vector{Array{Float64, 3}}())
    model_epi = Observable{Vector{Array{Float64, 3}}}(Vector{Array{Float64, 3}}())
    model_tirf = Observable{Vector{Array{Float64, 3}}}(Vector{Array{Float64, 3}}())
    names_files_epi_data = Observable(String[])
    names_files_tirf_data = Observable(String[])
    names_files_epi_model = Observable(String[])
    names_files_tirf_model = Observable(String[])

    # Create listeners for updating the main image and detail views
    img = create_main_image_listener(z_slider, menu, data_epi, data_tirf)
    img_xy = Observable(zeros(16, 16))
    img_xz = Observable(zeros(16, 21))
    img_yz = Observable(zeros(16, 21))
    model_xy = Observable(zeros(16, 16))
    model_xz = Observable(zeros(16, 21))
    model_yz = Observable(zeros(16, 21))

    # Create title listeners for data and model graphs
    tittle_graph_data = create_title_listener(z_slider, menu, names_files_epi_data, names_files_tirf_data)
    tittle_graph_model = create_title_listener(z_slider, menu, names_files_epi_model, names_files_tirf_model)

    # Create axes for all the visualizations
    ax1 = create_axis(fig[2:3, 1:2], title = tittle_graph_data, sz_title = 30)
    ax2 = create_axis(fig[2,3], title = "XY data", subtitle = tittle_graph_data)
    ax3 = create_axis(fig[2,4], title = "XZ data", subtitle = tittle_graph_data)
    ax4 = create_axis(fig[2,5], title = "YZ data", subtitle = tittle_graph_data)
    ax5 = create_axis(fig[3,3], title = "XY model", subtitle = tittle_graph_model)
    ax6 = create_axis(fig[3,4], title = "XZ model", subtitle = tittle_graph_model)
    ax7 = create_axis(fig[3,5], title = "YZ model", subtitle = tittle_graph_model)

    # Create heatmaps for all the visualizations
    heatmap!(ax1, img, colormap=:inferno)
    heatmap!(ax2, img_xy, colormap=:inferno)
    heatmap!(ax3, img_xz, colormap=:inferno)
    heatmap!(ax4, img_yz, colormap=:inferno)
    heatmap!(ax5, model_xy, colormap=:inferno)
    heatmap!(ax6, model_xz, colormap=:inferno)
    heatmap!(ax7, model_yz, colormap=:inferno)

    # Register mouse click interaction for the main image
    register_interaction!(ax1, :my_interaction) do event::MouseEvent, axis
        if event.type === MouseEventTypes.leftclick
            println("$(event.data)")
            push!(mouse_pos[], [event.data[2],event.data[1]] )
            notify(mouse_pos) 
        end
    end

    # Create listeners for updating detail views based on mouse position and slider values
    img_xy_listener = create_img_listener(mouse_pos, z_slider, menu, data_epi, data_tirf, :xy, img_mid_y, img_mid_x)
    img_xz_listener = create_img_listener(mouse_pos, z_slider, menu, data_epi, data_tirf, :xz, img_mid_y, img_mid_x)
    img_yz_listener = create_img_listener(mouse_pos, z_slider, menu, data_epi, data_tirf, :yz, img_mid_y, img_mid_x)

    # Set up listeners to update detail view Observables
    on(img_xy_listener) do val
        img_xy[] = val
    end
    on(img_xz_listener) do val
        img_xz[] = val
    end
    on(img_yz_listener) do val
        img_yz[] = val
    end

    # Initialize variables for managing the offset between data and model
    data_middle_slice = 0
    model_middle_slice = 0

    if !isempty(data_epi[])
        data_middle_slice = size(data_epi[][1], 3) ÷ 2
    end

    if !isempty(model_epi[])
        model_middle_slice = size(model_epi[][1], 3) ÷ 2
    end

    data_model_offset = Observable(model_middle_slice - data_middle_slice)

    # Create listeners for updating model views
    model_xy_listener = create_model_listener(buttons_xy, z_slider, menu, model_epi, model_tirf, :xy, snap_menu_xy, 2, data_model_offset)
    model_xz_listener = create_model_listener(buttons_xz, z_slider, menu, model_epi, model_tirf, :xz, snap_menu_xz, 3, data_model_offset)
    model_yz_listener = create_model_listener(buttons_yz, z_slider, menu, model_epi, model_tirf, :yz, snap_menu_yz, 4, data_model_offset)

    # Set up listeners to update model view Observables
    on(model_xy_listener) do val
        model_xy[] = val
    end
    on(model_xz_listener) do val
        model_xz[] = val
    end
    on(model_yz_listener) do val
        model_yz[] = val
    end

    # Set up listeners for slider changes to update views and respect snap settings
    on(z_slider.sliders[2].value) do val
        notify(img_xy_listener)
        if snap_menu_xy.selection[] == "Snap"
            notify(model_xy_listener)
        end
    end
    
    on(z_slider.sliders[3].value) do val
        notify(img_xz_listener)
        if snap_menu_xz.selection[] == "Snap"
            notify(model_xz_listener)
        end
    end
    
    on(z_slider.sliders[4].value) do val
        notify(img_yz_listener)
        if snap_menu_yz.selection[] == "Snap"
            notify(model_yz_listener)
        end
    end
    for ax in [ax1, ax2, ax3, ax4, ax5, ax6, ax7]
        hidedecorations!(ax)
     end
    # Set up listeners for save buttons to update paths and load data/models
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

    # Display the figure
    display(fig)
end


# Call the function to create and display the file navigator and main view
create_file_navigator_and_main_view()