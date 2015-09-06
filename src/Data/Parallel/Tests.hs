module Tests where

import Data.Parallel.HsStream

assertEquals :: (Eq a, Show a) => a -> a -> IO ()
assertEquals expected result = if (expected == result) 
    then putStrLn " - OK"
    else error $ " - ERROR: '" ++ show expected ++ "' not equals to '" ++ show result ++ "'"

-- Esta sería la idea del sUntil? Creo que no es como lo veníamos haciendo, pero no recuerdo porque
takeUntil :: (c -> b -> c) -> c -> (c -> Bool) -> [b] -> [b]
takeUntil f z cond []     = []
takeUntil f z cond (a:as) = 
    if cond z 
        then
            []
        else
            let z' = f z a
            in (a : takeUntil f z' cond as)

toUnfold :: [a] -> ([a] -> Maybe (a, [a]), [a])
toUnfold l = (f, z)
    where 
        f []     = Nothing
        f (a:as) = Just (a, as)
        z = l
        
case1 input = do
    putStrLn "unfold -> fold"
    let expected = input
    let (f, z) = toUnfold input
    s1 <- sUnfold f z
    result <- sReduce (:) [] s1
    assertEquals expected (reverse result)
    
case2 input = do
    putStrLn "unfold -> map -> fold"
    let expected = map (+1) input
    let (f, z) = toUnfold input
    s1 <- sUnfold f z
    s2 <- sMap (+1) s1
    result <- sReduce (:) [] s2
    assertEquals expected (reverse result)

case3 input = do
    putStrLn "unfold -> until -> fold"
    let expected = input
    let (f, z) = toUnfold input
    s1 <- sUnfold f z
    s2 <- sUntil (+) 0 (>10) s1
    result <- sReduce (:) [] s2
    assertEquals expected (reverse result)
    
case4 input = do
    putStrLn "unfold -> filter -> fold"
    let expected = filter odd input
    let (f, z) = toUnfold input
    s1 <- sUnfold f z
    s2 <- sFilter odd s1
    result <- sReduce (:) [] s2
    assertEquals expected (reverse result)

case5 input1 input2 = do
    putStrLn "unfold ->"
    putStrLn "          join -> fold"
    putStrLn "unfold ->"
    let expected = zip input1 input2
    let (f1, z1) = toUnfold input1
    let (f2, z2) = toUnfold input2
    s1 <- sUnfold f1 z1
    s2 <- sUnfold f2 z2
    s3 <- sJoin s1 s2
    result <- sReduce (:) [] s3
    assertEquals expected (reverse result)

case6 input = do
    putStrLn "unfold -> map -> until -> fold"
    let expected = takeUntil (+) 0 (>10) . map (+1) $ input
    let (f, z) = toUnfold input
    s1 <- sUnfold f z
    s2 <- sMap (+1) s1
    s3 <- sUntil (+) 0 (>10) s2
    result <- sReduce (:) [] s3
    assertEquals expected (reverse result)

case7 input = do
    putStrLn "unfold -> filter -> until -> fold"
    let expected = takeUntil (+) 0 (>10) . filter odd $ input
    let (f, z) = toUnfold input
    s1 <- sUnfold f z
    s2 <- sFilter odd s1
    s3 <- sUntil (+) 0 (>10) s2
    result <- sReduce (:) [] s3
    assertEquals expected (reverse result)

case8 input1 input2 cond = do
    putStrLn "unfold ->"
    putStrLn "          join -> until -> fold"
    putStrLn "unfold ->"
    let expected = takeUntil (\z (a1, a2) -> z + a1 + a2) 0 cond $ zip input1 input2
    let (f1, z1) = toUnfold input1
    let (f2, z2) = toUnfold input2
    s1 <- sUnfold f1 z1
    s2 <- sUnfold f2 z2
    s3 <- sJoin s1 s2
    s4 <- sUntil (\z (a1, a2) -> z + a1 + a2) 0 cond s3
    result <- sReduce (:) [] s4
    assertEquals expected (reverse result)

tests = [
    case1 [1, 2, 3, 4, 5], 
    case2 [1, 2, 3, 4, 5], 
    case3 [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 
    case3 [1, 2 ..], 
    case4 [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 
    case5 [1, 2, 3, 4, 5] [6, 7, 8, 9, 10], 
    case6 [1, 2 ..], 
    case7 [1, 2 ..], 
    case8 [1, 3 ..] [2, 4 ..] (> 10), 
    case8 [1, 3, 5, 7, 9, 11] [2, 4 ..] (> 10), 
    case8 [1, 3 ..] [2, 4, 6, 8, 10, 12] (> 10), 
    case8 [1, 3 ..] [2, 4 ..] (> 1000), 
    case8 [1, 3, 5, 7, 9, 11] [2, 4 ..] (> 1000), 
    case8 [1, 3 ..] [2, 4, 6, 8, 10, 12] (> 1000)]
    
testAll = sequence tests