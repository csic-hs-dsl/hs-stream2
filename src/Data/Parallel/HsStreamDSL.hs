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
{-
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
-}  

data IO2 a = IO2 (IO a)
runIO2 (IO2 io) = io

instance Monad IO2 where
    (IO2 io) >>= f = IO2 $ runIO2 . f =<< io
    return a = IO2 (return a)
    
instance Applicative IO2 where
    pure a = IO2 (pure a)
    (IO2 iof) <*> (IO2 io) = IO2 $ do
        f <- iof
        a <- io
        return $ f a

instance Functor IO2 where
    fmap f (IO2 io) = IO2 $ return . f =<< io
    
sUnfold_ :: (i -> (Maybe (o, i))) -> i -> IO2 (S () o)
sMap_ :: (Show b) => (b -> c) -> S a b -> IO2 (S b c)
sFilter_ :: (Show b) => (b -> Bool) -> S a b -> IO2 (S b b)
sUntil_ :: (Show b, Show c) => (c -> b -> c) -> c -> (c -> Bool) -> S a b -> IO2 (S b b)
sJoin_ :: (Show b1, Show b2) => S a1 b1 -> S a2 b2 -> IO2 (S (Either b1 b2) (b1, b2))
sReduce_ :: Show a => (a -> b -> b) -> b -> IO2 (S x a) -> IO b

sUnfold_ fun seed = IO2 $ sUnfold fun seed
sMap_ fun str = IO2 $ sMap fun str
sFilter_ filFun str = IO2 $ sFilter filFun str
sUntil_ accFun seed test str = IO2 $ sUntil accFun seed test str 
sJoin_ strL strR = IO2 $ sJoin strL strR
sReduce_ f z strIO2 = runIO2 $ (IO2 . (sReduce f z)) =<< strIO2