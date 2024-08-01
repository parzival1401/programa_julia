"""
    scalebar!(img::AbstractArray, pxsize::Float64;      
        position::String,        
        len::Real, 
        width::Real,
        scale::Int,
        color::Symbol = :white)

Add scalebar to the input image.

This is the major interface function for the package

# Arguments
    img::AbstractArray         : A 2-dimensional array of pixels
    pxsize::Real               : pixel size
    position::String           : "br" = bottom right, "ul" = upper left, etc. The default is "br"
    len::Real                  : the scalebar length, in pixels. The default is determined by the "scalebar_length_calc.jl" function len_calc() 
    width::Real                : similar to length
    scale::Int                 : scaling factor, default is 15
    color::Symbol              : either `:black`` or `:white`
   

# Returns
    img array with scalebar
"""
function scalebar!(img::AbstractArray, # updated function sigature with len_calc (-Ian)
    pxsize::Float64; 
    position::Symbol = :br, 
    len::Real = len_calc(img)[1],    # length and width default to results of len_calc()
    width::Real = len_calc(img)[2],
    offsetx::Int=30,
    offsety::Int=30,
    color::Symbol= :white ) # Added width parameter
    
    img_sizex = size(img,2)
    img_sizey = size(img,1)
    len_bar = round(Int,len/pxsize)
    println("len_bar: ",len_bar)
    width_bar = round(Int,width/pxsize) # Use width parameter to set width_bar
    offset_x = round(Int,img_sizex/offsetx)
    offset_y = round(Int,img_sizey/offsety)
    if position== :br
        x_i = img_sizey - width_bar - offset_y + 1
        x_f = img_sizey - offset_y
        y_i = img_sizex - len_bar - offset_x + 1
        y_f = img_sizex - offset_x
        #println("b")
    elseif position == :bl
        x_i = img_sizey - width_bar - offset_y + 1
        x_f = img_sizey - offset_y
        y_i = offset_x
        y_f = offset_x + len_bar - 1
        #println("bl")
    elseif position == :tl
        x_i = offset_y
        x_f = offset_y + width_bar - 1
        y_i = offset_x
        y_f = offset_x + len_bar - 1
        #println("ul")
    elseif position == :tr
        x_i = offset_y
        x_f = offset_y + width_bar - 1
        y_i = img_sizex - len_bar - offset_x + 1
        y_f = img_sizex - offset_x
        #println("ur")
    end
   
    if color == :white
        return img[x_i:x_f, y_i:y_f] .= RGB(1,1,1) # Fill in the rectangle
    elseif color == :black
        return img[x_i:x_f, y_i:y_f] .= RGB(0,0,0) # Fill in the rectangle
    end
    
end   


"""
    scalebar(img::AbstractArray, pxsize::Float64;      
        position::String,        
        len::Real, 
        scale::Int,
        width::Real,
        color::Symbol = :white)

Copy img and pass the copy to scalebar!()

# Arguments
    img::AbstractArray         : A 2-dimensional array of pixels
    pxsize::Real               : pixel size
    position::String           : "br" = bottom right, "ul" = upper left, etc. The default is "br"
    len::Real                  : the scalebar length, in pixels. The default is determined by the "scalebar_length_calc.jl" function len_calc() 
    width::Real                : similar to length
    scale::Int                 : scaling factor, default is 15
    color::Symbol              : either `:black`` or `:white`

# Returns
    A copy of img with scalebar applied

    See Also [`scalebar!`]@ref
"""
function scalebar(img::AbstractArray, # updated function sigature with len_calc (-Ian)
    pxsize::Float64; 
    position::Symbol= :br, 
    len::Real = len_calc(img)[1],    # length and width default to results of len_calc()
    width::Real = len_calc(img)[2],
    offsetx::Int=30,
    offsety::Int=30,
    color::Symbol= :white )  # Added width parameter
    
 img_new = deepcopy(img)
 scalebar!(img_new,pxsize,position=position,len=len,offsetx=offsetx,offsety=offsety,width=width,color=color) # Added width parameter
 return img_new 
end



""" 
    len_calc(img::AbstractArray)

Determine default scalebar length based on the dimensions of the input image. 

# Arguments
    img::AbstractArray : input array containing image data

# Returns
    len : scalebar length dimension in pixels
    width : scalebar width dimension in pixels
""" 
function len_calc(img::Union{AbstractArray, Array{Float64}})
   
    # get the dimensions of the input image
    len_dim = size(img)[2]
    
    # find 20% the length of the image
    len_sb = 0.1 .* len_dim
    
    # find the nearest multiple of 5
    if len_sb > 150
        sb_len = (len_sb +(100-len_sb%100))
    else 
        sb_len = (len_sb-len_sb%5)
    end
    

    # set the width based on the length 
    
    sb_wid = sb_len*.25
    sb_wid = sb_wid - sb_wid %5
    sb_dims = (sb_len, sb_wid)
    
    println("default scalebar dimensions calculated:", sb_dims)
        
    len = convert(Int, sb_len)
    println("len: ",len)
    width = convert(Int, sb_wid)
    println("width: ",width)
    return len, width

end

# # test scale bar 
#img = RGB.(ones(512,512))
#scalebar!(img,0.5,color=:black)
#img

