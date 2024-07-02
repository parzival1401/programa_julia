using GLMakie
using FilePathsBase

mutable struct NavigatorState
    current_path::String
end

function get_directories(path)
    directories = String[]
    for (root, dirs, files) in walkdir(path)
        append!(directories, dirs)
        break  # Only process the current directory
    end
    return directories
end

function get_available_drives()
    if Sys.iswindows()
        drives = [string(d, ":\\") for d in 'A':'Z' if isdir(string(d, ":\\"))]
    elseif Sys.isapple()
        drives = ["/", "/Volumes"]
    else  # Linux and others
        drives = ["/"]
    end
    return drives
end

function create_directory_navigator()
    fig = Figure(resolution = (800, 600))
    
    state = NavigatorState(homedir())
    
    menu_layout = GridLayout(fig[1,1])
    path_label = Label(menu_layout[1, 1:2], "Current path: $(state.current_path)", tellwidth=false)
    
    drive_menu = Menu(menu_layout[2, 1], options = get_available_drives(), tellwidth = false)
    main_menu = Menu(menu_layout[2, 2], options = [""], tellwidth = false)
    
    up_button = Button(menu_layout[3, :], label = "↑ Up", tellwidth = false)

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

    function update_main_menu()
        directories = get_directories(state.current_path)
        main_menu.options[] = directories
        
        on(main_menu.selection) do selected_item
            if isnothing(selected_item)
                return  # Do nothing if nothing is selected
            end
            
            new_path = joinpath(state.current_path, selected_item)
            if isdir(new_path)
                state.current_path = new_path
                path_label.text[] = "Current path: $(state.current_path)"
                update_main_menu()
            end
        end
    end
    
    on(up_button.clicks) do n
        parent_dir = dirname(state.current_path)
        if parent_dir != state.current_path  # Check if we're not already at the root
            state.current_path = parent_dir
            path_label.text[] = "Current path: $(state.current_path)"
            update_main_menu()
        end
    end
    
    update_drive_menu()
    update_main_menu()
    
    display(fig)
end

create_directory_navigator()


################
################
###############
