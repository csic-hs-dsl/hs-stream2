{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeOperators #-}

module Data.Parallel.HsStreamDSL3 where

-- Generador
data Gen a = Gen [a]

-- Stream
data Stream a where
    StreamLit :: Gen a -> Stream a
    StreamApp :: (Param a -> (Param a, ParamVal b)) -> Stream a -> Stream b
    StreamJoin :: Stream a -> Stream b -> Stream (a :. b)

-- Valores joineados
infixr 3 :.
data a :. b = a :. b
toPair (a :. b) = (a, b)

-- Valores de parámetros
type ParamVal a = Maybe [a]

-- Parámetros
data Param a where
    Param1 :: ParamVal a -> Param a
    ParamN :: ParamVal a -> Param b -> Param (a :. b)

-- Funciones auxiliares sobre parámetros
paramValue :: Param a -> ParamVal a
paramValue (Param1 l) = l
paramValue (ParamN ml p) = 
    do
        l <- ml
        pl <- paramValue p
        return $ zipWith (:.) l pl

descompParam :: Param (a :. b) -> (ParamVal a, Param b)
descompParam (Param1 ml) = undefined --case (unzip $ map toPair l) of (l1, l2) -> (l1, Param1 l2)
descompParam (ParamN l p) = (l, p)

continueDescomp :: (a, Param (b :. c)) -> (ParamVal b :. a, Param c)
continueDescomp (lc, p) = case (descompParam p) of (lb, p') -> (lb :. lc, p')

finishDescomp :: (a, Param b) -> (ParamVal b) :. a
finishDescomp (b, p) = (paramValue p) :. b

-- Ejemplos

-- Algo que juta streams de distintos tipos
ej2 = 
    let
        g1 = StreamLit $ Gen [1, 2]
        g2 = StreamLit $ Gen ['3', '2']
        g3 = StreamLit $ Gen [3.0, 2.0, 6.0]
        g4 = StreamLit $ Gen [True, False, False]
        join = StreamJoin g4 . StreamJoin g3 $ StreamJoin g2 g1
        fun param = 
            case finishDescomp . continueDescomp . continueDescomp $ descompParam param
            of 
                Nothing :. Nothing :. Nothing :. Nothing -> 
                    (ParamN Nothing . ParamN Nothing . ParamN Nothing $ Param1 Nothing, Nothing)
                Just (d:ds) :. Just (c:cs) :. Just (b:bs) :. Just (a:as) -> 
                    (ParamN (Just as) . ParamN (Just bs) . ParamN (Just cs) $ Param1 (Just ds), Just [(a, b, c, d)])
                ds :. cs :. bs :. as -> 
                    (ParamN as . ParamN bs . ParamN cs $ Param1 ds, Just [])
        app = StreamApp fun join
    in app

-- Mergesort  
ejMergeSort g1 g2 = 
    let
        join = StreamJoin g2 g1
        fun param = 
            case finishDescomp $ descompParam param
            of 
                mbs@Nothing :. mas         -> (ParamN mbs $ Param1 mas, mas)
                mbs         :. mas@Nothing -> (ParamN mbs $ Param1 mas, mbs)
                mbs@(Just (b:bs)) :. mas@(Just (a:as)) -> 
                    if b < a then (ParamN mas $ Param1 (Just bs), Just [b])
                    else          (ParamN (Just as) $ Param1 mbs, Just [a])
                bs          :. as          -> (ParamN as $ Param1 bs, Just [])
    in StreamApp fun join
