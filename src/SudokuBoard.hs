{-|
Module      : SudokuBoard
Description : Datatype and functions for representing/manipulating a sudoku 
                board
Copyright   : (c) Chad Reynolds, 2018
-}
module SudokuBoard(
    SudokuBoard(Board),
    strToBoard,
    ) where


import              Data.Sequence as Seq    (Seq(..), adjust', fromList, 
                                                index, replicate, 
                                                update, (><), (<|))
import qualified    Data.Set as Set         (Set, delete, empty, insert, 
                                                member, size)

import              CSP                     (CSP(..), Problem(..))
import              SudokuDigit             (SudokuDigit(Blank), charToDigit,
                                                sudokuDomain)


-- | Contains the state of the board.
data SudokuBoard = Board (Seq (Seq SudokuDigit))
    deriving (Eq)

instance Show SudokuBoard where
    show = boardShow

instance Problem SudokuBoard where
    consistent = validBoard
    complete = solvedBoard

instance CSP SudokuBoard BoardPosition SudokuDigit where
    legalValues = legalDigits
    relatedVariables = \bp b -> getAllRelatedPositions bp
    addAssignment = updateBoard
    valueCount = digitCount

boardShow :: SudokuBoard -> String
boardShow (Board Empty) = ""
boardShow (Board (x :<| Empty)) = rowShow x
boardShow (Board (x :<| xs)) = rowShow x ++ "\n" ++ boardShow (Board xs)

rowShow :: Seq SudokuDigit -> String
rowShow (Empty) = ""
rowShow (x :<| Empty) = show x
rowShow (x :<| xs) = show x ++ " | " ++ rowShow xs

-- | Represents the row, column pairs to index positions in the board.
type BoardPosition = (Int, Int)

emptyBoard :: SudokuBoard
emptyBoard = Board (Seq.replicate 9 $ Seq.replicate 9 Blank)

initializeBoard :: [(BoardPosition, SudokuDigit)] -> SudokuBoard
initializeBoard updates = foldr helper emptyBoard updates
    where 
        helper :: (BoardPosition, SudokuDigit) -> SudokuBoard -> SudokuBoard
        helper (pos,digit) board = updateBoard pos digit board

strToInitList :: String -> [(BoardPosition, SudokuDigit)]
strToInitList s = zipWith helper [0..] s
    where
        helper :: Int -> Char -> (BoardPosition, SudokuDigit)
        helper n ch = (indexToBoardPos n, charToDigit ch)
        indexToBoardPos :: Int -> BoardPosition
        indexToBoardPos n = (div n 9, mod n 9)

-- | Converts a string into a sudoku board.
--
-- Expects a string of 81 characters of digits 1-9.  Any other char is 
-- interpreted as a Blank.
strToBoard :: String -> SudokuBoard
strToBoard s = initializeBoard . strToInitList $ s

-- | Returns a new board with the digit in the given position.
updateBoard :: BoardPosition -> SudokuDigit -> SudokuBoard -> SudokuBoard
updateBoard (r,c) digit (Board board) = Board (adjust' (update c digit) r board)

-- | Returns the digit in the given board at the given position.
getDigit :: BoardPosition -> SudokuBoard -> SudokuDigit
getDigit (r,c) (Board board) = index (index board r) c

getRow :: Int -> SudokuBoard -> Seq SudokuDigit
getRow n (Board board) = index board n

getCol :: Int -> SudokuBoard -> Seq SudokuDigit
getCol n (Board board) = fmap (\x -> index x n) board

cagePosFromBoardPos :: BoardPosition -> Int
cagePosFromBoardPos (r,c) = ((div r 3) * 3) + (mod (div c 3) 3)

getCage :: Int -> SudokuBoard -> Seq SudokuDigit
getCage n board = fromList $ map (\z -> getDigit z board) [(x,y) | x <- [startr..endr], y <- [startc..endc]]
    where
        startr = (div n 3) * 3
        startc = (mod n 3) * 3
        endr = startr + 2
        endc = startc + 2

-- | Returns a sequence of all the digits in the same row/col/cage as the 
-- given position, including the given position.
getAllRelatedDigits :: BoardPosition -> SudokuBoard -> Seq SudokuDigit
getAllRelatedDigits pos@(r,c) board = (getRow r board) >< (getCol c board) >< (getCage (cagePosFromBoardPos pos) board)

getRowPositions :: Int -> [BoardPosition]
getRowPositions n = [(r,c) | r <- [n], c <- [0..8]]

getColPositions :: Int -> [BoardPosition]
getColPositions n = [(r,c) | r <- [0..8], c <- [n]]

getCagePositions :: Int -> [BoardPosition]
getCagePositions n = [(x,y) | x <- [startr..endr], y <- [startc..endc]]
    where
        startr = (div n 3) * 3
        startc = (mod n 3) * 3
        endr = startr + 2
        endc = startc + 2

-- | Returns a list of all the board positions in the same row/col/cage as the 
-- given position, including the given position.
getAllRelatedPositions :: BoardPosition -> [BoardPosition]
getAllRelatedPositions pos@(r,c) = (getRowPositions r) ++ (getColPositions c) ++ (getCagePositions (cagePosFromBoardPos pos))

checkIfSeqGen :: Bool -> Seq SudokuDigit -> Bool
checkIfSeqGen solveCheck digits = helper digits Set.empty
    where
        helper :: Seq SudokuDigit -> Set.Set SudokuDigit -> Bool
        helper (Empty) set = True
        helper (x:<|xs) set 
            | x == Blank = (not solveCheck) && helper xs set
            | not (Set.member x set) = helper xs (Set.insert x set)
            | otherwise = False

checkIfValidSeq :: Seq SudokuDigit -> Bool
checkIfValidSeq digits = checkIfSeqGen False digits

checkIfSolvedSeq :: Seq SudokuDigit -> Bool
checkIfSolvedSeq digits = checkIfSeqGen True digits

checkGen :: (Seq SudokuDigit -> Bool) -> (Int -> SudokuBoard -> Seq SudokuDigit) -> SudokuBoard -> Bool
checkGen f g board = foldr (\x y -> (f x) && y) True (map (\x -> g x board) [0..8])

validRows :: SudokuBoard -> Bool
validRows board = checkGen checkIfValidSeq getRow board

validCols :: SudokuBoard -> Bool
validCols board = checkGen checkIfValidSeq getCol board

validCages :: SudokuBoard -> Bool
validCages board = checkGen checkIfValidSeq getCage board

-- | Returns a boolean indicating if the board is valid(no duplicates in any 
-- row/col/cage, blanks allowed).
validBoard :: SudokuBoard -> Bool
validBoard board = (validRows board) && (validCols board) && (validCages board)

solvedRows :: SudokuBoard -> Bool
solvedRows board = checkGen checkIfSolvedSeq getRow board

solvedCols :: SudokuBoard -> Bool
solvedCols board = checkGen checkIfSolvedSeq getCol board

solvedCages :: SudokuBoard -> Bool
solvedCages board = checkGen checkIfSolvedSeq getCage board

-- | Returns a boolean indicating if the board is solved(no duplicates in any 
-- row/col/cage, blanks not allowed).
solvedBoard :: SudokuBoard -> Bool
solvedBoard board = (solvedRows board) && (solvedCols board) && (solvedCages board)

legalDigits :: BoardPosition -> SudokuBoard -> Set.Set SudokuDigit
legalDigits pos@(r,c) board 
    | getDigit pos board == Blank = foldr helper sudokuDomain (getAllRelatedDigits pos board)
    | otherwise = Set.empty
    where 
        helper :: SudokuDigit -> Set.Set SudokuDigit -> Set.Set SudokuDigit
        helper digit set 
            | digit == Blank = set
            | otherwise = Set.delete digit set

digitCount :: SudokuBoard -> [(BoardPosition, Int)]
digitCount (Board board) = helper [] (0,0) board
    where
        helper :: [(BoardPosition, Int)] -> BoardPosition -> Seq (Seq SudokuDigit) -> [(BoardPosition, Int)]
        helper l pos (Empty) = case l of
                                [] -> [((0,0),0)] -- was default value of previos version
                                _ -> l
        helper l (r,c) ((Empty) :<| xs) = helper l ((r+1),0) xs
        helper l pos@(r,c) ((x :<| xs) :<| xss) 
            | x == Blank = helper ((pos,(Set.size (legalDigits pos (Board board)))):l) (r,(c+1)) (xs <| xss)
            | otherwise = helper l (r,(c+1)) (xs <| xss)
