versioninfo()

Threads.nthreads()
Threads.threadid()
Threads.@threads for i in 1:100
    println("i: ",i," id: ",Threads.threadid())
end