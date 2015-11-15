module Data.Parallel.HsStream.Examples.DoNothingIO21 where

import Data.Parallel.HsStreamIO2
import Data.Parallel.HsStream.Utils

import Data.List (foldl')

main = do
    let aa = do
        let (gen, seed) = toUnfold . take 100000 $ repeat 10000
        sIn <- sUnfold_ gen seed
        sOut1 <- sMap_ doNothing sIn
        sOut2 <- sMap_ doNothing sIn
        sOut <- sJoin_ sOut1 sOut2
        return sOut
    out <- sReduce_ (:) [] aa
    print $ foldl' (\z (a, b) -> z + a + b) 0 out