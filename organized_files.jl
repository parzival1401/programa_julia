using MAT
using GLMakie
#getting the adrees of all the files in a folder 

general_directory = "/Users/fernandodelgado/Documents/university /summer 2024/intership /data /06-03-24"

names_files = readdir(general_directory,sort=true,join=true)
img_files = filter(endswith(".mat"),names_files)