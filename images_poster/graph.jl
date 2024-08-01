using MAT,JLD2,CairoMakie

path = "/Volumes/lidke-lrs/Projects/TIRF Demo/fernando/06-17-24/bead100nm_1.5X_epi_104deg.mat"
open_file = MAT.matopen(path)
img = read(open_file, "ZStack")
close(open_file)

fig = Figure()
ax = Axis(fig[1, 1],title="xy data")
heatmap!(ax, img[114-8:114+8,122-8:122+8,10], colormap=:inferno)
hidedecorations!(ax)
fig
save("/Users/fernandodelgado/Documents/university /summer 2024/intership /poster/pupil_y.png",fig1)
