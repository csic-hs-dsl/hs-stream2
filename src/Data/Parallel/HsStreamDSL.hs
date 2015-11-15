{-# LANGUAGE GADTs #-}

module Data.Parallel.HsStreamDSL where

import Data.Parallel.HsStream
import Control.Applicative

--sUnfold :: (i -> (Maybe (o, i))) -> i -> IO (S () o)
--sMap :: (Show b) => (b -> c) -> S a b -> IO (S b c)
--sFilter :: (Show b) => (b -> Bool) -> S a b -> IO (S b b)
--sUntil :: (Show b, Show c) => (c -> b -> c) -> c -> (c -> Bool) -> S a b -> IO (S b b)
--sJoin :: (Show b1, Show b2) => S a1 b1 -> S a2 b2 -> IO (S (Either b1 b2) (b1, b2))
--sReduce :: Show a => (a -> b -> b) -> b -> S x a -> IO b

data Stream a b where
    StrUnfold :: (i -> (Maybe (o, i))) -> i -> Stream () o
    StrMap :: (Show b) => (b -> c) -> Stream a b -> Stream b c
    StrFilter :: (Show b) => (b -> Bool) -> Stream a b -> Stream b b
    StrUntil :: (Show b, Show c) => (c -> b -> c) -> c -> (c -> Bool) -> Stream a b -> Stream b b
    StrJoin :: (Show b1, Show b2) => Stream a1 b1 -> Stream a2 b2 -> Stream (Either b1 b2) (b1, b2)

strReduce :: Show a => (a -> b -> b) -> b -> Stream x a -> IO b
strReduce f z str = do
    s <- exec str
    sReduce f z s

exec :: Stream i o -> IO (S i o)
exec (StrUnfold fun seed) = sUnfold fun seed
exec (StrMap fun str) = do
    s <- exec str
    sMap fun s
exec (StrFilter filFun str) = do
    s <- exec str
    sFilter filFun s
exec (StrUntil accFun seed test str) = do
    s <- exec str
    sUntil accFun seed test s
exec (StrJoin str1 str2) = do
    s1 <- exec str1
    s2 <- exec str2
    sJoin s1 s2
