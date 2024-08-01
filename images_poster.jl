using JLD2,CairoMakie



dir =joinpath("/Volumes", "lidke-lrs", "Projects", "TIRF Demo", "fernando", "model_data","model_general_tirf.jld2")
data = load(dir,"model")

fig= Figure()
ax = Axis(fig[1, 1],aspect = DataAspect())
heatmap!(ax,data[10:30,10:30,10],colormap=:inferno)
hidedecorations!(ax)
display(fig)
save("/Users/fernandodelgado/Documents/university /summer 2024/intership /poster/bead_sim.png",fig)