-- | Main.hs
--
-- A diferencia de los proyectos anteriores, este programa NO termina después
-- de responder: se queda abierto durante toda la partida, leyendo una orden
-- por renglón y respondiendo un renglón por orden. La ventana de Python lo
-- abre una sola vez y conversa con él.
--
-- Órdenes que entiende (una por renglón):
--   NUEVA HUMANO     partida nueva; empieza la persona (X)
--   NUEVA MAQUINA    partida nueva; empieza la máquina (O)
--   JUGAR n          la persona juega en la casilla n (0 a 8) y la máquina responde
--   NIVEL n          cambia la dificultad: 1 fácil, 2 medio, 3 imposible
--   SALIR            termina el programa
--
-- Respuestas (un renglón, campos separados por espacio):
--   OK <tablero> <estado> <jugada de la máquina> <línea ganadora>
--      tablero: 9 caracteres X, O o .   estado: SIGUE, GANA_X, GANA_O o EMPATE
--      jugada:  0 a 8, o - si la máquina no jugó   línea: p. ej. 0,4,8, o -
--   ERR <motivo>
--   ADIOS
--
-- El estado de la partida no se guarda en ninguna variable que cambie: se
-- le pasa a 'bucle' como argumento, y cada vuelta recibe la partida nueva.
module Main (main) where

import Data.Char (isDigit)
import Data.List (intercalate)
import System.IO

import Triqui

data Partida = Partida
  { tablero   :: Tablero
  , nivel     :: Int
  , terminada :: Bool
  }

persona, maquina :: Ficha
persona = X
maquina = O

partidaInicial :: Partida
partidaInicial = Partida tableroVacio 3 False

main :: IO ()
main = do
  mapM_ (`hSetEncoding` utf8) [stdin, stdout, stderr]
  -- Cada respuesta debe salir apenas se escribe; si no, Python se queda esperando.
  hSetBuffering stdout LineBuffering
  hPutStrLn stderr "Motor de triqui listo."
  bucle partidaInicial

-- | Lee una orden, responde y vuelve a empezar con la partida actualizada.
bucle :: Partida -> IO ()
bucle partida = do
  fin <- isEOF                      -- Python cerró la conexión: se termina sin error
  if fin
    then hPutStrLn stderr "Entrada cerrada; fin del motor."
    else do
      renglon <- getLine
      case words (filter (/= '\r') renglon) of
        ["SALIR"] -> responder "ADIOS"
        orden     -> do
          let (respuesta, siguiente) = atender orden partida
          hPutStrLn stderr ("<- " ++ renglon ++ "   -> " ++ respuesta)
          responder respuesta
          bucle siguiente

responder :: String -> IO ()
responder r = putStrLn r >> hFlush stdout

-- | El corazón del programa, y es una función pura:
--   (orden, partida actual)  ->  (respuesta, partida siguiente)
atender :: [String] -> Partida -> (String, Partida)
atender ["NUEVA", "HUMANO"] p = informar Nothing (p { tablero = tableroVacio, terminada = False })
atender ["NUEVA", "MAQUINA"] p = juegaMaquina (p { tablero = tableroVacio, terminada = False })
atender ["NIVEL", n] p
  | n `elem` ["1", "2", "3"] = informar Nothing (p { nivel = read n })
  | otherwise                = ("ERR el nivel debe ser 1, 2 o 3", p)
atender ["JUGAR", n] p
  | terminada p                = ("ERR la partida ya terminó; pida una NUEVA", p)
  | not (all isDigit n) || null n = ("ERR la casilla debe ser un número de 0 a 8", p)
  | casilla > 8                = ("ERR la casilla debe ser un número de 0 a 8", p)
  | casilla `notElem` libres t = ("ERR la casilla " ++ n ++ " ya está ocupada", p)
  | otherwise                  =
      let p' = p { tablero = poner casilla persona t }
      in if seAcabo (tablero p') then informar Nothing p' else juegaMaquina p'
  where
    t       = tablero p
    casilla = read n :: Int
atender orden p = ("ERR orden desconocida: " ++ unwords orden, p)

-- | La máquina escoge su jugada con minimax y se informa el resultado.
juegaMaquina :: Partida -> (String, Partida)
juegaMaquina p =
  case mejorJugada (nivel p) maquina (tablero p) of
    Nothing -> informar Nothing p
    Just i  -> informar (Just i) (p { tablero = poner i maquina (tablero p) })

seAcabo :: Tablero -> Bool
seAcabo t = ganador t /= Nothing || lleno t

-- | Arma el renglón "OK ..." y marca la partida como terminada si corresponde.
informar :: Maybe Int -> Partida -> (String, Partida)
informar jugada p = (unwords ["OK", mostrarTablero t, estado, maybe "-" show jugada, linea], p')
  where
    t  = tablero p
    p' = p { terminada = seAcabo t }
    (estado, linea) = case ganador t of
      Just (f, l) -> ("GANA_" ++ show f, intercalate "," (map show l))
      Nothing
        | lleno t   -> ("EMPATE", "-")
        | otherwise -> ("SIGUE", "-")
