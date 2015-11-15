module Data.Parallel.HsStream.Examples.DoNothingDSL1 where

import Data.Parallel.HsStreamDSL
import Data.Parallel.HsStream.Utils

import Data.List (foldl')

main = do
    let (gen, seed) = toUnfold . take 100000 $ repeat 10000
    let sIn = StrUnfold gen seed
    let sOut1 = StrMap doNothing sIn
    let sOut2 = StrMap doNothing sIn
    let sOut = StrJoin sOut1 sOut2
    out <- strReduce (:) [] sOut
    print $ foldl' (\z (a, b) -> z + a + b) 0 out
