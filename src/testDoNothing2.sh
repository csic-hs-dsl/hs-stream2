ghc --make Data/Parallel/HsStream/Examples/DoNothing2.hs -fforce-recomp -threaded -rtsopts -main-is Data.Parallel.HsStream.Examples.DoNothing2
rm Data/Parallel/HsStream/Examples/*.hi
rm Data/Parallel/HsStream/Examples/*.o
time ./Data/Parallel/HsStream/Examples/DoNothing2 +RTS -N$1