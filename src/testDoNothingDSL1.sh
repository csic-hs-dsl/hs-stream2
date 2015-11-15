ghc --make Data/Parallel/HsStream/Examples/DoNothingDSL1.hs -fforce-recomp -threaded -rtsopts -main-is Data.Parallel.HsStream.Examples.DoNothingDSL1
rm Data/Parallel/HsStream/Examples/*.hi
rm Data/Parallel/HsStream/Examples/*.o
time ./Data/Parallel/HsStream/Examples/DoNothingDSL1 +RTS -N$1