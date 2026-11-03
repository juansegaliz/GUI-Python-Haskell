-- | Triqui.hs
--
-- Reglas del triqui y la inteligencia de la máquina (algoritmo minimax).
-- Todo es puro: un tablero entra, un tablero o un número sale.
--
-- El tablero es una lista de 9 casillas, numeradas así:
--
--    0 | 1 | 2
--   ---+---+---
--    3 | 4 | 5
--   ---+---+---
--    6 | 7 | 8
module Triqui
  ( Ficha (..)
  , Tablero
  , tableroVacio
  , libres
  , poner
  , ganador
  , lleno
  , mejorJugada
  , mostrarTablero
  ) where

import Data.Maybe (listToMaybe)

data Ficha = X | O deriving (Eq, Show)

type Tablero = [Maybe Ficha]

tableroVacio :: Tablero
tableroVacio = replicate 9 Nothing

-- | Las ocho formas de hacer triqui: tres filas, tres columnas, dos diagonales.
lineas :: [[Int]]
lineas = [ [0,1,2], [3,4,5], [6,7,8]
         , [0,3,6], [1,4,7], [2,5,8]
         , [0,4,8], [2,4,6] ]

-- | Casillas vacías del tablero.
libres :: Tablero -> [Int]
libres t = [ i | (i, Nothing) <- zip [0 ..] t ]

-- | Devuelve un tablero NUEVO con la ficha puesta; el original no cambia.
poner :: Int -> Ficha -> Tablero -> Tablero
poner i f t = [ if j == i then Just f else casilla | (j, casilla) <- zip [0 ..] t ]

-- | Si alguien hizo triqui, quién fue y en qué línea.
ganador :: Tablero -> Maybe (Ficha, [Int])
ganador t = listToMaybe
  [ (f, l) | l@[a, b, c] <- lineas
           , Just f <- [t !! a]
           , t !! b == Just f
           , t !! c == Just f ]

lleno :: Tablero -> Bool
lleno = null . libres

otra :: Ficha -> Ficha
otra X = O
otra O = X

-- ---------------------------------------------------------------------
-- Minimax
-- ---------------------------------------------------------------------

-- | Puntaje de un tablero desde el punto de vista de 'yo':
--   positivo si 'yo' gana, negativo si pierde, 0 si empata o no se sabe.
--   Ganar pronto vale más que ganar tarde (por eso se suma la profundidad).
--
--   prof  = cuántas jugadas más se permite imaginar la máquina
--   turno = a quién le toca mover en ese tablero imaginado
minimax :: Ficha -> Int -> Ficha -> Tablero -> Int
minimax yo prof turno t
  | Just (f, _) <- ganador t = if f == yo then 10 + prof else -(10 + prof)
  | lleno t || prof == 0     = 0
  | turno == yo              = maximum hijos   -- la máquina escoge lo mejor para ella
  | otherwise                = minimum hijos   -- y supone que el rival escoge lo peor para ella
  where
    hijos = [ minimax yo (prof - 1) (otra turno) (poner i turno t) | i <- libres t ]

-- | Cuántas jugadas imagina la máquina según el nivel.
profundidad :: Int -> Int
profundidad 1 = 1   -- fácil: solo ve si puede ganar ya mismo
profundidad 2 = 3   -- medio: ve venir algunas amenazas
profundidad _ = 9   -- imposible: explora la partida completa

-- | Preferencia cuando dos jugadas valen lo mismo: centro, esquinas, bordes.
preferencia :: [Int]
preferencia = [4, 0, 2, 6, 8, 1, 3, 5, 7]

-- | La mejor casilla para la ficha 'yo' según el nivel (1, 2 o 3).
mejorJugada :: Int -> Ficha -> Tablero -> Maybe Int
mejorJugada nivel yo t
  | null candidatas = Nothing
  | otherwise       = Just (snd (foldr1 mejor candidatas))
  where
    p          = profundidad nivel
    candidatas = [ (minimax yo (p - 1) (otra yo) (poner i yo t), i)
                 | i <- preferencia, i `elem` libres t ]
    -- se queda con el mayor puntaje; ante un empate, con la que va primero en 'preferencia'
    mejor a b  = if fst b > fst a then b else a

-- | Tablero como texto de 9 caracteres: "X.O......" (el punto es casilla vacía).
mostrarTablero :: Tablero -> String
mostrarTablero = map simbolo
  where
    simbolo (Just X) = 'X'
    simbolo (Just O) = 'O'
    simbolo Nothing  = '.'
