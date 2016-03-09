{-# LANGUAGE GADTs #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}

module Data.Parallel.HsStreamDSL_2016 where

import Control.Applicative
import Data.Char

data Z = Z deriving (Show, Read, Eq, Ord)
infixl 3 :.
data tail :. head = !tail :. !head deriving (Show, Read, Eq, Ord)


-- Separamos ejecución de definición
-- Ver si se puede poner una construcción que permita fusionar pasos (para que sean secuenciales en vez de paralelos)
-- Tener cuidado en la implementación: Porque antes usábamos Until?
-- Estaría bueno poder hacer merge sort
data Stream a b where
    StrMapState     :: s -> (s -> a -> (Maybe [b], s)) -> Stream a b
    StrLink         :: Stream a b -> Stream b c -> Stream a c
    StrJoin         :: s -> (s -> (ReadFrom, s)) -> (s -> DataFrom b d -> (Maybe [e], s)) -> Stream a b -> Stream c d -> Stream (a, c) e
    StrLoop         :: (a -> b) -> (b -> Bool) -> Stream (a, b) (c, b) -> Stream a c
    StrFilterState  :: s -> (s -> b -> (Bool, s)) -> Stream b b
    StrWhile        :: s -> (s -> b -> s) -> (s -> Bool) -> Stream b b

data ReadFrom = ReadFromLeft | ReadFromRight | ReadFromBoth
data DataFrom a b = DataFromLeft a | DataFromRight b | DataFromBoth a b

strJoin :: Stream a b -> Stream c d -> Stream (a, c) (b, d)
strJoin = StrJoin () (\s -> (ReadFromBoth, s)) (\s (DataFromBoth b d) -> (Just [(b, d)], s))

strMap :: (a -> b) -> Stream a b
strMap f = StrMapState () (\_ a -> (Just $ [f a], ()))

strFilter :: (b -> Bool) -> Stream b b
strFilter f = StrFilterState () (\_ b -> (f b, ()))

{-
a = pop()
b = init(a);
while (cond(b)) {
    (c, b) <- body(a, b)
    push(c)
}
-}


-- Ver si podemos tener generadores que se creen de distinta forma, y que 
-- haya un reduce, de forma que la salida también sea un generador
runStream :: Stream a b -> [a] -> [b]

-- Ejemplos 

-- Fibonacci
ej1 :: Stream () Int
ej1 = StrLoop (const (0, 1)) (const True) $ strMap fib
    where 
        fib (_, (fibM2, fibM1)) = 
            let fibM0 = fibM2 + fibM1 
            in (fibM0, (fibM1, fibM0))

-- Fibonacci Primes
ej2 :: Stream () Int
ej2 = StrLink ej1 $ strFilter isPrime
    where isPrime _ = True

-- Primeros N Fibonacci Primes
ej3 :: Int -> Stream () Int
ej3 n = StrLink ej2 $ StrWhile 0 (\s _ -> s + 1) (<= n)

{-
class Stream s a b | s -> a b

data Ret s a = Ret a

class (Stream s a b) => App s a b | s -> a b where
    app :: Ret s (a -> b)

class (Stream s (a, c) (b, d), Stream s1 a b, Stream s2 c d) => Join s a b c d s1 s2 | s -> a b c d

data GetData1
instance Stream GetData1 Int Char
instance App GetData1 Int Char where
    app = Ret chr

data GetData2
instance Stream GetData2 Char Int
instance App GetData2 Char Int where
    app = Ret ord

data JoinDatas
instance Stream JoinDatas (Int, Char) (Char, Int)
instance Join JoinDatas Int Char Char Int GetData1 GetData2
-}



{-
    a = pop()
    b = init(a);
    while (cond(b)) {
        (c, b) <- body(a, b)
        push(c)
    }

    

ejFib :: Stream Int Int
ejFib = 
    let loop = StrApp rec
        rec (n, r) = if (n == 0) then (1, 0) else (n+r, n)
    in StrFeedback loop

-}        
{-
data Kernel a b where
    KInit :: [a] -> Kernel () a
    KMap :: (a -> b) -> Kernel a b

data Link = forall a b c. Link (Kernel a b) (Kernel b c)

data Stream = Stream [Link]

ej1 = 
    let k1a = KInit [1, 2, 3]
        k2a = KMap id
        k3a = KMap id
        k1b = KInit [1, 3, 2]
        k2b = KMap id
        k3b = KMap id
        k1c = KMap id
    in Stream [
        Link k1a k2a, Link k2a k3a, Link k3a k1c, 
        Link k1b k2b, Link k2b k3b, Link k3b k1c,
        Link k1c k2b]

    -}


{-
-- No se si sirve de algo el a
data Kernel a b where
    KUnfold  :: Int -> (i -> (Maybe (o, i))) -> i -> Kernel () o
    KMap     :: Int -> (b -> c) -> Kernel a b -> Kernel b c
    KFilter  :: Int -> (b -> Bool) -> Kernel a b -> Kernel b b
    KUntil   :: Int -> (c -> b -> c) -> c -> (c -> Bool) -> Kernel a b -> Kernel b b
    KJoin    :: Int -> Kernel a b -> Kernel c d -> Kernel (b, d) (b, d)

data AnyKernel = forall a b. AnyKernel (Kernel a b)
data Link = forall a b c. Link (Kernel a b) (Kernel b c)
data Stream o = forall a. Stream [AnyKernel] [Link] (Kernel a o)

nextId :: Stream a -> Int
nextId (Stream lk _ _) = length lk

addKernel :: Stream a -> Kernel b c -> Stream c
addKernel (Stream lk ll _) k = Stream (AnyKernel k:lk) ll k

addUnfold :: Stream a -> (b -> (Maybe (c, b))) -> b -> Stream c
addUnfold s f z = addKernel s (KUnfold (nextId s) f z)

addMap :: Stream a -> (b -> c) -> Kernel d b -> Stream c
addMap s f k = addKernel s (KMap (nextId s) f k)

addFilter :: Stream a -> (b -> Bool) -> Kernel c b -> Stream b
addFilter s f k = addKernel s (KFilter (nextId s) f k)

addUntil :: Stream i -> (c -> b -> c) -> c -> (c -> Bool) -> Kernel a b -> Stream b
addUntil s f z b k = addKernel s (KUntil (nextId s) f z b k)

addLink :: Stream a -> Link -> Stream a
addLink (Stream lk ll k) l = Stream lk (l:ll) k

addJoin :: Stream a -> Kernel b c -> Kernel d e -> Stream (c, e)
addJoin s k1 k2 = addKernel s (KJoin (nextId s) k1 k2)

instance Functor Stream where
    fmap f s@(Stream _ _ k) = addMap s f k
    
instance Applicative Stream where
    pure = undefined -- Stream infinito de el algo
--    sf <*> sa = undefined -- Map (\(x, y) -> x y) . Join x y 
    sf@(Stream _ _ kf) <*> sa@(Stream _ _ ka) = 
        let asd = addJoin sf kf ka
        in  addMap asd (\(x, y) -> x y) (kernel asd)
-}