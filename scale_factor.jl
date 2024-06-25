using CairoMakie
using Images


##############

function scalebar!(img::AbstractArray; position::String = "br", pxsize::Float64 = 0.5, len::Real = 20, scale::Int=15 )
    img_sizex = size(img,1)
    img_sizey = size(img,2)
    len_bar = round(Int,len/pxsize)
    width_bar = round(Int,len_bar/(scale/2))
    offset_x = round(Int,img_sizex/scale)
    offset_y = round(Int,img_sizey/scale)
    
    if position[1] == 'b'
        x_i = img_sizey-width_bar-offset_y
        x_f = img_sizey-offset_y
        println("b")
    elseif position[1] == 'u'
        x_i = offset_y
        x_f = offset_y+width_bar
        println("u")
    end
    if position[2] == 'r'
        y_i = img_sizex-len_bar-offset_x
        y_f = img_sizex-offset_x
        println("r")
    elseif position[2] == 'l'
        y_i = offset_x
        y_f = offset_x+len_bar 
        println("l")
    end
    
    return x_i, x_f, y_i, y_f
end    
function scalebar_draw(img::AbstractArray,x_i::Int64, x_f::Int64, y_i::Int64, y_f::Int64)
    midle_bar=round(Int,((x_f-x_i)/2)+x_i)
    img[x_i:x_f,y_i-1].= RGB(0,0,0)
    img[x_i:x_f,y_f+1].= RGB(0,0,0)
    img[midle_bar,y_i:y_f].= RGB(0,0,0)
end

img = RGB.(ones(1000,1000))
pxsize = 0.1
len = 10
scale_factor = 15

x_i, x_f, y_i, y_f=scalebar!(img,position="br",len=50)
scalebar_draw(img,x_i, x_f, y_i, y_f)
save("test_bar.png",img)

#######################
using Revise
using Colors
using Images
using CairoMakie
#=
function scalebar!(img::AbstractArray, scale::Real, unit::String, position::Tuple{Real,Real}, color::RGB{N0f8}=RGB{N0f8}(1,1,1))
    # Get the size of the image
    height, width = size(img)
    
    # Get the size of the scalebar
    scalebar_width = 100
    scalebar_height = 10
    
    # Get the position of the scalebar
    x, y = position
    
    # Draw the scalebar
    for i in 1:scalebar_height
        for j in 1:scalebar_width
            img[Int(round(y + i)), Int(round(x + j))] = color
        end
    end
    
    # Draw the text
    #text!(img, "$scale $unit", (x + scalebar_width + 5, y + scalebar_height), color=color, fontsize=10) 

end =#


function scalebar!(img::AbstractArray; position::String = "br", pxsize::Float64 = 0.5, len::Real = 20, scale::Int=15,units::String = "nm" )
    img_sizex = size(img,1)
    img_sizey = size(img,2)
    len_bar = round(Int,len/pxsize)
    width_bar = round(Int,len_bar/(scale/2))
    offset_x = round(Int,img_sizex/scale)
    offset_y = round(Int,img_sizey/scale)
    if position[1] == 'b'
        x_i = img_sizey-width_bar-offset_y
        x_f = img_sizey-offset_y
        println("b")
    elseif position[1] == 'u'
        x_i = offset_y
        x_f = offset_y+width_bar
        println("u")
    end
    if position[2] == 'r'
        y_i = img_sizex-len_bar-offset_x
        y_f = img_sizex-offset_x
        println("r")
    elseif position[2] == 'l'
        y_i = offset_x
        y_f = offset_x+len_bar 
        println("l")
    end
    return x_i, x_f, y_i, y_f
end   

##demostration scale bar


function scalebar(img::AbstractArray; 
    position::String = "br", 
    pxsize::Float64 = 0.5, 
    len::Real = 20, 
    scale::Int=15,
    units::String = "nm" )
 img_new = deepcopy(img)
 scalebar!(img_new, position,pxsize,len,scale)
 return img_new 
end
#draw the scale bar 
function scalebar_draw(img::AbstractArray,x_i::Int64, x_f::Int64, y_i::Int64, y_f::Int64)
    midle_bar=round(Int,((x_f-x_i)/2)+x_i)
    img[x_i:x_f,y_i-1].= RGB(0,0,0)
    img[x_i:x_f,y_f+1].= RGB(0,0,0)
    img[midle_bar,y_i:y_f].= RGB(0,0,0)
end

#test scale bar 
img = RGB.(ones(512,512))
x_i, x_f, y_i, y_f=scalebar!(img,position="br",len=50,)
scalebar_draw(img,x_i, x_f, y_i, y_f)
fig = Figure()
ax = CairoMakie.Axis(fig[1,1],yreversed=true)
heatmap!(img')
display(fig)



