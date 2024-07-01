

data = ones(40,40)


for i in 1:3:round(Int,size(data,1)-3)
    for k in 1:3:round(Int,size(data,2)-3)
        valor =sum(data[i:i+3,k:k+3])
        println(valor)
        data[i:i+3,k:k+3].= valor
    end
end
data