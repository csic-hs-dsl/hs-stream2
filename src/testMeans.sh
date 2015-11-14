ghc --make Data/Parallel/HsStream/Examples/KMeans.hs -fforce-recomp -threaded -rtsopts -main-is Data.Parallel.HsStream.Examples.KMeans
rm Data/Parallel/HsStream/Examples/*.hi
rm Data/Parallel/HsStream/Examples/*.o
time ./Data/Parallel/HsStream/Examples/KMeans +RTS -N$1