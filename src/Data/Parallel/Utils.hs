module Data.Parallel.Utils where

toUnfold :: [a] -> ([a] -> Maybe (a, [a]), [a])
toUnfold l = (f, z)
    where 
        f []     = Nothing
        f (a:as) = Just (a, as)
        z = l

chunkUnfold ::  Int -> (s -> Maybe (d, s), s) -> (s -> Maybe ([d], s), s)
chunkUnfold chunk (f, s) = (f' chunk, s)
    where 
        f' 0 s = undefined
        f' n s = undefined
        
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

doNothing :: Integer -> Integer
doNothing n = doNothing' 0 n
            
doNothing' :: Integer -> Integer -> Integer
doNothing' i n = if i >= n 
    then n
    else doNothing' (i + 1) n