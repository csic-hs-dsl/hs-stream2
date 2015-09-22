module Data.Parallel.KMeans where

import Data.Parallel.HsStream
import Data.Parallel.Utils

import qualified Data.Map.Strict as Map
import Data.List (foldl', sort)

import System.Random (randomRs)
import System.Random.TF.Init (mkTFGen)

type Coord = (Double, Double)
{-
points :: [Coord]
points = [(1, 1), (1, 2), (1, 2), (1, 2), (1, 2), (1, 2), (1, 2), (1, 2), (1, 2), (1, 2), (1, 2), (1, 2), (1, 2), (1, 2), (1, 2)]

means :: [Coord]
means = []-}

(points, means) = genData 1000 10

genData n k = 
    let gen = mkTFGen 1
        (pxs, pxsRest) = splitAt n $ randomRs (1, 100) gen
        (pys, pysRest) = splitAt n pxsRest
        (mxs, mxsRest) = splitAt k pysRest
        (mys, _) = splitAt k mxsRest
        ps = zip pxs pys
        ms = zip mxs mys
    in (ps, ms)

coordDist (x1, y1) (x2, y2) = ((x1 - x2) ** 2) + ((y1 - y2) ** 2)
coordSum (x1, y1) (x2, y2) = (x1 + x2, y1 + y2)
coordDiv (x, y) den = (x / den, y / den)

nearestMean :: Coord -> [Coord] -> Coord
nearestMean p (mean:means) = fst $ foldl' f (mean, coordDist p mean) means
    where f (m, dist) x = 
           let 
               dist' = coordDist p x 
           in 
               if (dist' < dist)
               then (x, dist') 
               else (m, dist)       
--nearestMean _ _ = undefined

main = do
    let (gen, seed) = toUnfold points
    sPoints <- sUnfold gen seed
    sKPoints <- sMap (\p -> (p, nearestMean p means)) sPoints
    let redKPoints (p, m) = Map.insertWith (\(coord, count) (coord', count') -> (coordSum coord coord' , count + count')) m (p, 1)
    res <- sReduce redKPoints Map.empty sKPoints
    let means' = Map.foldrWithKey (\k (coord, count) l -> ((coordDiv coord count):l)) [] res
    putStrLn "result"
    putStrLn . show . sort $ means'
    putStrLn "expected"
    putStrLn . show . sort $ kMeansTestOneStep points means
    
    
    
kMeansTestOneStep :: (Ord t, Floating t) => [(t, t)] -> [(t, t)] -> [(t, t)]
kMeansTestOneStep ps ms = 
    let dist (x, y) (x', y')    = (x - x') ** 2 + (y - y') ** 2
        sumPair (x, y) (x', y') = (x + x', y + y')
        divPair (x, y) d        = (x / d, y / d)
        distToMeans p           = map (\m -> (m, dist m p)) ms
        closestMean p           = foldl1 (\a b -> if (snd a) < (snd b) then a else b) (distToMeans p)
        pointsWithMean          = map (\p -> (p, closestMean p)) ps
        pointsWithMeanOfMean m  = filter (\(_, (m', _)) -> m == m') pointsWithMean
        calcNewMean m           = 
            let pointsWithMeanOfMeanLen = fromIntegral . length . pointsWithMeanOfMean $ m
                sumPointsOfMean = foldl (\p (p', (_, _)) -> sumPair p p') (0, 0) (pointsWithMeanOfMean m)
            in (\p -> divPair p pointsWithMeanOfMeanLen) $ sumPointsOfMean

        calcNewMeans = map calcNewMean ms
    in calcNewMeans