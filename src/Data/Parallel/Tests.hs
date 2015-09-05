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
        
case1 = do
    putStrLn "unfold -> fold"
    let input = [1, 2, 3, 4, 5]
    let expected = input
    let (f, z) = toUnfold input
    s1 <- sUnfold f z
    result <- sReduce (:) [] s1
    assertEquals expected result
    
case2 = do
    putStrLn "unfold -> map -> fold"
    let input = [1, 2, 3, 4, 5]
    let expected = map (+1) input
    let (f, z) = toUnfold input
    s1 <- sUnfold f z
    s2 <- sMap (+1) s1
    result <- sReduce (:) [] s2
    assertEquals expected result

case3 = do
    putStrLn "unfold -> until -> fold"
    let input = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    let expected = input
    let (f, z) = toUnfold input
    s1 <- sUnfold f z
    s2 <- sUntil (+) 0 (>10) s1
    result <- sReduce (:) [] s2
    assertEquals expected result
    
case4 = do
    putStrLn "unfold -> until -> fold, stream infinito"
    let input = [1, 2 ..]
    let expected = takeUntil (+) 0 (>10) input
    let (f, z) = toUnfold input
    s1 <- sUnfold f z
    s2 <- sUntil (+) 0 (>10) s1
    result <- sReduce (:) [] s2
    assertEquals expected result

case5 = do
    putStrLn "unfold -> filter -> fold"
    let input = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    let expected = filter odd input
    let (f, z) = toUnfold input
    s1 <- sUnfold f z
    s2 <- sFilter odd s1
    result <- sReduce (:) [] s2
    assertEquals expected result

case6 = do
    putStrLn "unfold ->"
    putStrLn "          join -> fold"
    putStrLn "unfold ->"
    let input1 = [1, 2, 3, 4, 5]
    let input2 = [6, 7, 8, 9, 10]
    let expected = zip input1 input2
    let (f1, z1) = toUnfold input1
    let (f2, z2) = toUnfold input2
    s1 <- sUnfold f1 z1
    s2 <- sUnfold f2 z2
    s3 <- sJoin s1 s2
    result <- sReduce (:) [] s3
    assertEquals expected result



tests = [case1, case2, case3, case4, case5, case6]
    
testAll = sequence tests