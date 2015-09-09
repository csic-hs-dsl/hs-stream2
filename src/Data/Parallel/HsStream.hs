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
import Data.Foldable (mapM_, foldlM, foldl, traverse_)
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

import qualified Data.Dequeue as Buffer
import qualified Data.Map.Strict as Map
import qualified Prelude
import qualified Control.Concurrent.Chan.Unagi as UQ
import qualified Control.Concurrent.Chan.Unagi.Bounded as BQ 

import Debug.Trace (traceM)

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

data Subscription b = forall i o. Subscription Int (b -> i) (SQueue i o)


-- El tipo QData puede contener datos, pedidos de datos, subscripciones y desubscripciones
-- El Maybe de Request es en caso que sea infinito
data QData a b = 
    Data StreamId (Maybe a) 
    | Request StreamId (Maybe Int) 
    | forall i o. Subscrip StreamId (b -> i) (SQueue i o)
    | DeSubscrip StreamId

instance Show a => Show (QData a b) where
    show (Data sId d) = "Data " ++ show sId ++ " " ++ show d
    show (Request sId d) = "Request " ++ show sId ++ " " ++ show d
    show (Subscrip sId _ _) = "Subscrip " ++ show sId
    show (DeSubscrip sId) = "DeSubscrip " ++ show sId


type SQueue a b = Queue (QData a b)

-- Los streams obtienen datos de tipo a y subscripciones para datos de tipo b (o sea, generan datos de tipo b)
data S a b = S StreamId (SQueue a b)


emtpyBuffer :: Buffer.BankersDequeue a
emtpyBuffer = Buffer.empty

emptySet :: forall b. Map.Map StreamId (Subscription b)
emptySet = Map.empty

nullSet :: forall b. Map.Map StreamId (Subscription b) -> Bool
nullSet = Map.null

addSub sId sub set = Map.insert sId sub set

removeSub sId set = Map.delete sId set

addReqToSub ssId n subs = Map.adjust (\(Subscription m sf sqI) -> Subscription (n+m) sf sqI) ssId subs

minSubReq subs = minimum $ map (\(Subscription m _ _) -> m) (Map.elems subs)

removeReqToSubs n subs = Map.map (\(Subscription m sf sqI) -> Subscription (m-n) sf sqI) subs

sendData sId d subs = traverse_ (\(Subscription _ f sqI) -> writeQueue sqI (Data sId (Just $ f d))) (Map.elems subs)

sendNothing sId subs = traverse_ (\(Subscription _ _ sqI) -> writeQueue sqI (Data sId (Nothing))) (Map.elems subs)



-- En general, al crearse un nuevo stream, lo primero que éste hace es subscribirse a otro (obviamente el unfold no lo hace)
sUnfold :: (i -> (Maybe (o, i))) -> i -> IO (S () o)
sUnfold fun seed = do
    -- Create new S
    sId <- nextRandom
    qi <- newQueue
    let s = S sId qi
    -- Do my work
    forkIO $ work s Map.empty seed
    return s
    where 
        work s @ (S sId qi) subscribers currSeed = do
            msg <- readQueue qi
            case msg of
                --Data ssId (Just d) -> undefined
                --Data ssId Nothing -> undefined
                Request ssId (Just n) -> do
--                    putStrLn $ "sUnfold Request " ++ (show n)
                    let auxSubs = Map.adjust (\(Subscription m sf sqI) -> Subscription (n+m) sf sqI) ssId subscribers
                        minReq = minimum $ map (\(Subscription m _ _) -> m) (Map.elems auxSubs)
                        newSubscribers = Map.map (\(Subscription m sf sqI) -> Subscription (m-minReq) sf sqI) auxSubs
                    genAndWrite s minReq currSeed newSubscribers
                Subscrip ssId sf sqI -> do
--                    putStrLn $ "sUnfold Subscrip"
                    work s (Map.insert ssId (Subscription 0 sf sqI) subscribers) currSeed
                DeSubscrip ssId -> do
--                    putStrLn $ "sUnfold DeSubscrip"
                    let newSubscribers = Map.delete ssId subscribers
                    when (not $ Map.null newSubscribers) (work s newSubscribers currSeed)
        genAndWrite s @ (S sId _) timesLeft seed subscribers =
            if (timesLeft > 0) then
                case fun seed of
                    Just (d, newSeed) -> do 
                        traverse_ (\(Subscription _ f sqI) -> writeQueue sqI (Data sId (Just $ f d))) (Map.elems subscribers)
                        genAndWrite s (timesLeft-1) newSeed subscribers
                    Nothing -> do
                        traverse_ (\(Subscription _ _ sqI) -> writeQueue sqI (Data sId (Nothing))) (Map.elems subscribers)
            else
                work s subscribers seed


sMap :: Show b => (b -> c) -> S a b -> IO (S b c)
sMap fun (S inId inQi) = do
    -- Create new S
    myId <- nextRandom
    myQi <- newQueue
    -- Send subcribe message to inQi
    writeQueue inQi (Subscrip myId Prelude.id myQi)
    -- Do my work
    forkIO $ work myId myQi emptySet emtpyBuffer
    return $ S myId myQi
    where 
        work myId myQi subscribers buffer = do
            msg <- readQueue myQi
            traceM $ "sMap: received message on work state: (" ++ show msg ++ ")"
            case msg of
                Data _ (Just d) -> do
                    -- Aplico la funcion, lo guardo en un buffer, y si hay subscriptores que pidieron datos enviarselos.
                    let auxBuffer = Buffer.pushFront buffer (fun d)
                        minReq = min (Buffer.length buffer) (minSubReq subscribers)
                    newBuffer <- sendToSubscribers myId subscribers minReq auxBuffer
                    let newSubs = removeReqToSubs minReq subscribers
                    work myId myQi newSubs newBuffer
                Data _ Nothing -> do
                    if (Buffer.null buffer) then
                        -- Si no hay nada en el buffer, se envia Nothing y se termina el hilo.
                        sendNothing myId subscribers
                    else do
                        -- Si hay algo en el buffer hay que esperar que lo pidan.
                        traceM "sMap: pass to AfterNothing"
                        workAfterNothing myId myQi subscribers buffer
                Request ssId (Just n) -> do
                    -- Aumento la cantidad de datos que pidio ese subscriptor. Si hay datos en el buffer y no hay subscriptor con 0 les envio datos.
                    let auxSubs = addReqToSub ssId n subscribers
                        minReq = min (Buffer.length buffer) (minSubReq auxSubs)
                    newBuffer <- sendToSubscribers myId subscribers minReq buffer
                    let newSubs = removeReqToSubs minReq auxSubs
                        toAsk = minSubReq newSubs
                    when (toAsk > 0) (writeQueue inQi (Request myId (Just toAsk)))
                    work myId myQi newSubs newBuffer
                Subscrip ssId sf sqI -> do
                    work myId myQi (addSub ssId (Subscription 0 sf sqI) subscribers) buffer
                DeSubscrip ssId -> do
                    -- Se desubscribe al correspondiente. Si ya no se tienen subscriptores se envia una desubscripcion hacia atras.
                    let newSubscribers = removeSub ssId subscribers
                    if (nullSet newSubscribers) then
                        writeQueue inQi (DeSubscrip myId)
                    else
                        work myId myQi newSubscribers buffer

        workAfterNothing myId myQi subscribers buffer = do
            msg <- readQueue myQi
            traceM $ "sMap: received message on AfterNothing state: (" ++ show msg ++ ")"
            case msg of
                Data _ _ -> error "Unexpected Data message in state AfterNothing on sMap"
                Request ssId (Just n) -> do
                    let auxSubs = addReqToSub ssId n subscribers
                        minReq = min (Buffer.length buffer) (minSubReq auxSubs)
                    newBuffer <- sendToSubscribers myId subscribers minReq buffer
                    if (Buffer.null newBuffer) then do
                        sendNothing myId subscribers
                    else do
                        let newSubs = removeReqToSubs minReq auxSubs
                        workAfterNothing myId myQi newSubs newBuffer
                Subscrip _ _ _ -> error "Unexpected Subscrip message in state AfterNothing on sMap"
                DeSubscrip ssId -> do
                    -- Se desubscribe al correspondiente. Si ya no se tienen subscriptores se envia una desubscripcion hacia atras.
                    let newSubscribers = removeSub ssId subscribers
                    if (nullSet newSubscribers) then
                        writeQueue inQi (DeSubscrip myId)
                    else
                        workAfterNothing myId myQi newSubscribers buffer

        sendToSubscribers myId subscribers n buffer = 
            if (n > 0) then do
                let (Just d, newBuffer) = Buffer.popBack buffer
                sendData myId d subscribers
                sendToSubscribers myId subscribers (n-1) newBuffer
            else
                return buffer

        

sFilter :: (b -> Bool) -> S a b -> IO (S b b)
sFilter = undefined

sUntil :: (c -> b -> c) -> c -> (c -> Bool) -> S a b -> IO (S b b)
sUntil = undefined

sJoin :: S a1 b1 -> S a2 b2 -> IO (S (Either b1 b2) (b1, b2))
sJoin = undefined

-- El reduce no genera un hilo, esto supongo que esta bien si hay un unico reduce.
sReduce :: Show a => (a -> b -> b) -> b -> S x a -> IO b
sReduce f z (S inId inQi) = do
    -- Create new S
    sId <- nextRandom
    qi <- newQueue
    let s = S sId qi
    -- Send subcribe message to inQi
    writeQueue inQi (Subscrip sId Prelude.id qi)
    -- Do my work
    result <- work s z 0
    return result
    where 
        work s @ (S sId qi) acc 0 = do
--            putStrLn "sReduce 0"
            writeQueue inQi (Request sId (Just 10))
            work s acc 10
        work s @ (S sId qi) acc reqData = do
            msg <- readQueue qi
            traceM $ "sReduce: received message: (" ++ show msg ++ ")"
            case msg of
                Data ssId (Just d) -> do
--                    putStrLn "sReduce Just"
                    work s (f d acc) (reqData - 1)
                Data ssId Nothing -> do
--                    putStrLn "sReduce Nothing"
                    return acc
                --Request ssId (Just n) -> undefined
                --Subscrip ssId sf sqI -> undefined
                --DeSubscrip ssId -> undefined
