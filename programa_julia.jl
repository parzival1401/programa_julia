

using MAT
using GLMakie
#change the directory for the image your would like to plot 
#img1_dir=" /bead40nm_epi_110deg.mat"
img1_dir="/Volumes/lidke-lrs/Projects/TIRF Demo/fernando/06-03-24/bead40nm_epi_110deg.mat"

img2_dir="/Volumes/lidke-lrs/Projects/TIRF Demo/fernando/06-03-24/bead40nm_epi_200deg.mat"



img1_file=matopen(img1_dir)
vars_img1 = matread(img1_dir)
data_img1= read(img1_file,"ZStack")

img2_file=matopen(img2_dir)
vars_img2 = matread(img2_dir)
data_img2=read(img2_file,"ZStack")

function image_name_num(dir)
  string_size=length(dir)
  for i in 1:string_size
    if dir[string_size-i] == '/' || dir[string_size-i] == "'\'"
      return i-1
      #return[dir[end-i+1:end-4]]
    end  
  end  
end

fig = Figure()
ax1 = Axis(fig[1, 1],
        title = img1_dir[end-image_name_num(img1_dir):end-4],
        xlabel = "The x label",
        ylabel = "The y label",
        aspect = DataAspect(), 
        yreversed = true
)
ax2 = Axis(fig[1, 2],
        title = img2_dir[end-image_name_num(img2_dir):end-4],
        xlabel = "The x label",
        ylabel = "The y label",
        aspect = DataAspect(), 
        yreversed = true
)


z_slider=SliderGrid(
    fig[2, 1:2],
    (label = "Focus", range = 1:1:size(data_img1,3), format = "{1} F", startvalue = 5),
    (label = "E_ax", range = 1:1:size(data_img1,3), format = "{1} F", startvalue = 10.),
    (label = "E_ex", range = 1:1:size(data_img1,3), format = "{1} F", startvalue = 15.9),
    #width =700,
    tellheight = false)




z_display_img1= lift(idx_1 -> permutedims(data_img1[:,:,idx_1],[2,1]), z_slider.sliders[1].value)
z_display_img2= lift(idx_2 -> permutedims(data_img2[:,:,idx_2],[2,1]), z_slider.sliders[1].value)
heatmap!(ax1,z_display_img1,colormap=:grays)
heatmap!(ax2,z_display_img2,colormap=:grays)



display(fig)