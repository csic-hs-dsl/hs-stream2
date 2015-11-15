ghc --make Data/Parallel/HsStream/Examples/DoNothingIO21.hs -fforce-recomp -threaded -rtsopts -main-is Data.Parallel.HsStream.Examples.DoNothingIO21
rm Data/Parallel/HsStream/Examples/*.hi
rm Data/Parallel/HsStream/Examples/*.o
time ./Data/Parallel/HsStream/Examples/DoNothingIO21 +RTS -N$1