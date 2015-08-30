{-# LANGUAGE GADTs #-}
{-# LANGUAGE Arrows #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_HADDOCK show-extensions #-}


module Data.Parallel.HsStream where


import qualified Data.Sequence as S
import Data.Foldable (mapM_, foldlM, foldl)
import Data.Maybe (isJust, fromJust)
import Data.Traversable (Traversable, mapM)
import Control.Concurrent (forkIO, ThreadId, killThread, threadDelay)
import Control.Concurrent.MVar (MVar, newEmptyMVar, putMVar, readMVar)
import Control.Exception (evaluate)
import Control.Exception.Base (catch, AsyncException(ThreadKilled))
import Control.Monad (liftM, when)
import Prelude hiding (id, mapM, mapM_, take, foldl)
import Data.UUID (UUID)
import Data.UUID.V4 (nextRandom)

import qualified Prelude
import qualified Control.Concurrent.Chan.Unagi as UQ
import qualified Control.Concurrent.Chan.Unagi.Bounded as BQ 


---------------- QUEUE ----------------

data Queue a = Bounded (BQ.InChan a) (BQ.OutChan a) | Unbounded (UQ.InChan a) (UQ.OutChan a)


readQueue :: Queue a -> IO a
readQueue (Bounded _ outChan) = BQ.readChan outChan
readQueue (Unbounded _ outChan) = UQ.readChan $ outChan

tryReadQueue :: Queue a -> IO (Maybe a)
tryReadQueue (Bounded _ outChan) = do
    (elem, _) <- BQ.tryReadChan outChan
    BQ.tryRead elem
tryReadQueue (Unbounded _ outChan) = do
    (elem, _) <- UQ.tryReadChan outChan
    UQ.tryRead elem

writeQueue :: Queue a -> a -> IO ()
writeQueue (Bounded inChan _) = BQ.writeChan inChan
writeQueue (Unbounded inChan _) = UQ.writeChan inChan


newBQueue :: Int -> IO (Queue a)
newBQueue limit = do
    (inChan, outChan) <- BQ.newChan limit
    return $ Bounded inChan outChan

newUQueue :: IO (Queue a)
newUQueue = do
    (inChan, outChan) <- UQ.newChan
    return $ Unbounded inChan outChan


newQueue = newUQueue
---------------------------------------

-- Tipo de los ids de streams
type StreamId = UUID

data Subscripton b = forall i o. Subscripton StreamId (b -> i) (SQueue i o)

-- El tipo QData puede contener datos, pedidos de datos, subscripciones y desubscripciones
-- El Maybe de Request es en caso que sea infinito
data QData a b = 
    Data StreamId (Maybe a) 
    | Request StreamId (Maybe Int) 
    | Subscrip (Subscripton b)
    | DeSubscrip StreamId

type SQueue a b = Queue (QData a b)

-- Los streams obtienen datos de tipo a y subscripciones para datos de tipo b (o sea, generan datos de tipo b)
data S a b = S StreamId (SQueue a b)



-- En general, al crearse un nuevo stream, lo primero que éste hace es subscribirse a otro (obviamente el unfold no lo hace)
sUnfold :: (i -> (Maybe (o, i))) -> i -> IO (S () o)
sUnfold fun seed = do
    -- Create new S
    sId <- nextRandom
    qi <- newQueue
    let s = S sId qi
    -- Do my work
    forkIO $ work s [] seed
    return s
    where 
        work s @ (S sId qi) subscribers currSeed = do
            msg <- readQueue qi
            case msg of
                --Data ssId (Just d) -> undefined
                --Data ssId Nothing -> undefined
                Request ssId (Just n) -> undefined
                Subscrip subscription -> do
                    work s (subscription : subscribers) currSeed
                DeSubscrip ssId -> undefined


sMap :: (b -> c) -> S a b -> IO (S b c)
sMap fun (S inId inQi) = do
    -- Create new S
    sId <- nextRandom
    qi <- newQueue
    let s = S sId qi
    -- Send subcribe message to inQi
    writeQueue inQi (Subscrip $ Subscripton sId Prelude.id qi)
    -- Do my work
    forkIO $ work s []
    return s
    where 
        work = undefined

sFilter :: (b -> Bool) -> S a b -> IO (S b b)
sFilter = undefined

sUntil :: (c -> b -> c) -> c -> (c -> Bool) -> S a b -> IO (S b b)
sUntil = undefined

sJoin :: S a1 b1 -> S a2 b2 -> IO (S (Either b1 b2) (b1, b2))
sJoin = undefined

