{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeOperators #-}

module Data.Parallel.HsStreamDSL3 where

-- Generador
data Gen a = Gen [a]

-- Stream
data Stream a where
    StreamLit :: Gen a -> Stream a
    StreamApp :: (Param a -> (Param a, [b])) -> Stream a -> Stream b
    StreamJoin :: Stream a -> Stream b -> Stream (a :. b)

-- Valores joineados
infixr 3 :.
data a :. b = a :. b
toPair (a :. b) = (a, b)

-- Parametros

type ParamVal a = Maybe [a]

data Param a where
    Param1 :: [a] -> Param a
    ParamN :: [a] -> Param b -> Param (a :. b)
  
unParam :: Param (a :. b) -> (Param b, [a])
unParam (Param1 l) = case (unzip $ map toPair l) of (l1, l2) -> (Param1 l2, l1)
unParam (ParamN l p) = (p, l)

paramValue :: Param a -> [a]
paramValue (Param1 l) = l
paramValue (ParamN l p) = zipWith (:.) l (paramValue p)

descomp2 :: (Param (a :. b), c) -> (Param b, [a] :. c)
descomp2 (p, lc) = case (unParam p) of (p', lb) -> (p', lb :. lc)

descomp :: (Param a, b) -> [a] :. b
descomp (p, b) = paramValue p :. b

-- Ejemplos

-- Une 4 streams y procesa alguna cosa
ej1 = 
    let
        g1 = StreamLit $ Gen [1, 2]
        g2 = StreamLit $ Gen ['3', '2']
        g3 = StreamLit $ Gen [3.0, 2.0, 6.0]
        g4 = StreamLit $ Gen [True, False, False]
        join = StreamJoin g4 . StreamJoin g3 $ StreamJoin g2 g1
        fun p =
            let
                (pp, a:as) = unParam p
                (ppp, b:bs) = unParam pp
                (pppp, c:cs) = unParam ppp
                (d:ds) = paramValue pppp
            in (ParamN as . ParamN bs . ParamN cs $ Param1 ds, [(a, b, c, d)])
        app = StreamApp fun join
    in app

-- El ej1 usando descomp de Param        
ej2 = 
    let
        g1 = StreamLit $ Gen [1, 2]
        g2 = StreamLit $ Gen ['3', '2']
        g3 = StreamLit $ Gen [3.0, 2.0, 6.0]
        g4 = StreamLit $ Gen [True, False, False]
        join = StreamJoin g4 . StreamJoin g3 $ StreamJoin g2 g1
        fun p = 
            case descomp . descomp2 . descomp2 $ unParam p 
            of 
                (d:ds) :. (c:cs) :. (b:bs) :. (a:as) -> (ParamN as . ParamN bs . ParamN cs $ Param1 ds, [(a, b, c, d)])
                ds :. cs :. bs :. as                 -> (ParamN as . ParamN bs . ParamN cs $ Param1 ds, [])
        app = StreamApp fun join
    in app
        
