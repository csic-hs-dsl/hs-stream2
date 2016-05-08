{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeOperators #-}

module Data.Parallel.HsStreamDSL3 where

data Gen a = Gen [a]

data Stream a where
    StreamLit :: Gen a -> Stream a
    StreamApp :: (Param (a :. Z) -> (Param (a :. Z), [b])) -> Stream a -> Stream b
    StreamJoin :: Stream a -> Stream b -> Stream (a :. b)

data Z = Z

infixr 3 :.
data a :. b = a :. b
toPair (a :. b) = (a, b)

data Param a where
    ZParam :: Param Z 
    NParam :: [a] -> Param b -> Param (a :. b)

g1 = StreamLit $ Gen [1, 2]
g2 = StreamLit $ Gen [3, 2]
g3 = StreamLit $ Gen [3, 2]
g4 = StreamLit $ Gen [3, 2]
join = StreamJoin g2 g1
--fun :: Param (Integer :. (Integer :. (Integer :. Integer))) -> ((Integer :. (Integer :. (Integer :. Integer))), [b])
fun :: Param ([Integer] :. [Integer] :. Z) -> (Param ([Integer] :. [Integer] :. Z), [Integer])
fun p = case p of (NParam (a:as) (NParam (b:bs) ZParam)) -> (NParam as (NParam bs ZParam), [])
--app1 = (\fun -> StreamApp fun join)

{-
ej1 = 
    let
        g1 = StreamLit $ Gen [1, 2]
        g2 = StreamLit $ Gen [3, 2]
        g3 = StreamLit $ Gen [3, 2]
        g4 = StreamLit $ Gen [3, 2]
        join = StreamJoin g2 g1
        fun p = 
            let (NParam (NParam ZParam (a:as)) (b:bs)) = p
            in (NParam (ZParam as) bs, [a, b])
        app1 = StreamApp fun join
        in app1
-}