-- | Main.hs
--
-- Punto de entrada del programa de consola. Es lo único que la ventana de
-- Python ve: la operación llega como argumento y el texto llega por la
-- entrada estándar. El informe sale por la salida estándar.
--
--   Uso:  analizador <contar | frecuentes | palindromos | invertir>
--
-- Si algo sale mal, el mensaje va a la salida de errores (stderr) y el
-- programa termina con código 1. Así Python sabe distinguir un informe
-- de un error.
module Main (main) where

import System.Environment (getArgs)
import System.Exit (ExitCode (..), exitWith)
import System.IO

import Analisis

-- | Tabla de operaciones: nombre que llega desde Python -> función pura.
operaciones :: [(String, String -> String)]
operaciones =
  [ ("contar",      informeConteo)
  , ("frecuentes",  informeFrecuentes)
  , ("palindromos", informePalindromos)
  , ("invertir",    informeInvertir)
  ]

main :: IO ()
main = do
  -- Sin esto, en Windows la ñ y las tildes llegan dañadas.
  mapM_ (`hSetEncoding` utf8) [stdin, stdout, stderr]
  argumentos <- getArgs
  case argumentos of
    [nombre] ->
      case lookup nombre operaciones of
        Just operacion -> do
          texto <- getContents
          -- En Windows las líneas pueden traer '\r' al final: se quita.
          putStr (operacion (filter (/= '\r') texto))
        Nothing -> fallar ("Operación desconocida: " ++ nombre)
    _ -> fallar "Uso: analizador <contar | frecuentes | palindromos | invertir>"

-- | Escribe el mensaje en stderr y termina con código de error 1.
fallar :: String -> IO ()
fallar mensaje = do
  hPutStrLn stderr mensaje
  exitWith (ExitFailure 1)
