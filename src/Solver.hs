{-|
Module      : Solver
Description : Functions for solving board
Copyright   : (c) Chad Reynolds, 2018
-}
module Solver(
    recBacktracking
    ) where


import qualified    Data.List as List       (sortBy)
import              Data.Ord                (comparing)
import              Data.Sequence as Seq    (Seq(..), (<|))
import qualified    Data.Set as Set         (Set, size, toList)

import              SudokuBoard             (BoardPosition, SudokuBoard(..), 
                                                getAllRelatedPositions, 
                                                legalDigits, solvedBoard, 
                                                updateBoard, validBoard)
import              SudokuDigit             (SudokuDigit(..), sudokuDomain)


-- | Recursively attempts placements of digits in positions, backtracking 
-- when an invalid placement is made.  Uses MRV to direct position choices 
-- and LCV to direct digit choices to minimize the amount of backtracking.
recBacktracking :: SudokuBoard -> SudokuBoard
recBacktracking board = recBacktracking' nextPos posValues board
    where
        nextPos = minRemainingValues board
        posValues = leastConstrainingValue nextPos board

recBacktracking' :: BoardPosition -> [SudokuDigit] -> SudokuBoard -> SudokuBoard
recBacktracking' pos [] board = board
recBacktracking' pos (x:xs) board 
    | solvedBoard board = board
    | validBoard board = 
        case solvedBoard recResult of 
            True -> recResult
            False ->  nextTry
    | otherwise = nextTry
    where 
        updatedBoard = updateBoard pos x board
        nextPos = minRemainingValues updatedBoard
        posValues = leastConstrainingValue nextPos updatedBoard
        recResult = recBacktracking' nextPos posValues updatedBoard
        nextTry = recBacktracking' pos xs board

minRemainingValues :: SudokuBoard -> BoardPosition
minRemainingValues (Board board) = helper (-1) (0,0) (0,0) board
    where 
        helper :: Int -> BoardPosition ->  BoardPosition -> Seq (Seq SudokuDigit) -> BoardPosition
        helper minCnt minPos newPos (Empty) = minPos
        helper minCnt minPos (r,c) ((Empty) :<| xs) = helper minCnt minPos ((r+1),0) xs
        helper minCnt minPos pos@(r,c) ((x :<| xs) :<| xss) 
            | x == Blank = let  newVals = Set.size (legalDigits pos (Board board))
                                nextPos = (r,(c+1))
                                nextSeq = (xs <| xss) in 
                                case (minCnt == (-1)) || (newVals < minCnt) of
                                    True -> helper newVals pos nextPos nextSeq
                                    False -> helper minCnt minPos nextPos nextSeq
            | otherwise = helper minCnt minPos (r,(c+1)) (xs <| xss)

leastConstrainingValue :: BoardPosition -> SudokuBoard -> [SudokuDigit]
leastConstrainingValue pos board = map fst $ List.sortBy (comparing snd) valsCounts
    where 
        vals = Set.toList $ legalDigits pos board
        relatedPositions = getAllRelatedPositions pos
        valsBoards = Prelude.zip vals $ map (\x -> updateBoard pos x board) vals
        valsCounts = Prelude.zip vals $ map ((\b -> sum (map (\p -> Set.size (legalDigits p b)) relatedPositions)) . snd) valsBoards

