module Data.Parallel.HsStream.Examples.DoNothing2 where

import Data.Parallel.HsStream
import Data.Parallel.HsStream.Utils

import Data.List (foldl')

main = do
    let (gen, seed) = toUnfold . take 100000 $ repeat 10000
    sIn <- sUnfold gen seed
    sOut1 <- sMap doNothing sIn
    sOut2 <- sMap doNothing sOut1
    out <- sReduce (:) [] sOut2
    print $ foldl' (+) 0 out