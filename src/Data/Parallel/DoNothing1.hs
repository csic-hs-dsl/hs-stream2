module Data.Parallel.DoNothing1 where

import Data.Parallel.HsStream
import Data.Parallel.Utils

import Data.List (foldl')

main = do
    let (gen, seed) = toUnfold . take 100000 $ repeat 10000
    sIn <- sUnfold gen seed
    sOut1 <- sMap doNothing sIn
    sOut2 <- sMap doNothing sIn
    sOut <- sJoin sOut1 sOut2
    out <- sReduce (:) [] sOut
    print $ foldl' (\z (a, b) -> z + a + b) 0 out