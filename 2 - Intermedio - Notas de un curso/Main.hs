-- | Main.hs
--
-- Programa de consola que la ventana de Python ejecuta. Tiene dos órdenes:
--
--   notas calcular <archivo.csv>
--       Lee el CSV y responde con renglones etiquetados, uno por dato,
--       con los campos separados por tabulador (\t):
--         EST  renglón  nombre  c1  c2  c3  definitiva  estado  detalle
--         ERR  renglón  motivo
--         RES  cantidad  promedio  máxima  mínima  aprobados  reprobados  pendientes
--       Los números van con punto decimal y "-" cuando no hay dato.
--       Este formato es para que lo lea un programa, no una persona.
--
--   notas reporte <archivo.csv> <salida.txt>
--       Escribe un informe legible para personas en <salida.txt>.
--
-- Códigos de salida: 0 bien, 1 orden mal escrita, 2 no se pudo leer o
-- escribir un archivo.
module Main (main) where

import Control.Exception (IOException, try)
import GHC.IO.Encoding (setLocaleEncoding)
import System.Environment (getArgs)
import System.Exit (ExitCode (..), exitWith)
import System.IO
import Text.Printf (printf)

import Notas

main :: IO ()
main = do
  -- UTF-8 para la consola y también para readFile / writeFile.
  setLocaleEncoding utf8
  mapM_ (`hSetEncoding` utf8) [stdin, stdout, stderr]
  argumentos <- getArgs
  case argumentos of
    ["calcular", entrada]         -> leerArchivo entrada >>= putStr . respuestaCalcular
    ["reporte", entrada, salida]  -> do
      contenido <- leerArchivo entrada
      escrito <- try (writeFile salida (reporte contenido)) :: IO (Either IOException ())
      case escrito of
        Left _   -> fallar 2 ("No se pudo escribir el archivo: " ++ salida)
        Right () -> putStrLn ("Reporte guardado en " ++ salida)
    _ -> fallar 1 "Uso: notas calcular <archivo.csv>  |  notas reporte <archivo.csv> <salida.txt>"

-- | Lee el archivo completo; si no existe o no se puede abrir, termina con código 2.
leerArchivo :: FilePath -> IO String
leerArchivo ruta = do
  resultado <- try (readFile ruta >>= \c -> length c `seq` return c) :: IO (Either IOException String)
  case resultado of
    Right contenido -> return contenido
    Left _          -> fallar 2 ("No se pudo leer el archivo: " ++ ruta) >> return ""

fallar :: Int -> String -> IO ()
fallar codigo mensaje = hPutStrLn stderr mensaje >> exitWith (ExitFailure codigo)

-- ---------------------------------------------------------------------
-- Orden "calcular": formato para máquinas
-- ---------------------------------------------------------------------

respuestaCalcular :: String -> String
respuestaCalcular contenido = unlines (errores ++ estudiantes ++ [resumen])
  where
    (errs, es)  = leerCurso contenido
    errores     = [ campos ["ERR", show n, motivo] | (n, motivo) <- errs ]
    estudiantes = [ campos [ "EST", show (linea e), nombre e
                           , num (corte1 e), num (corte2 e), talVez (corte3 e)
                           , talVez (definitiva e), etiqueta (estado e), detalle (estado e) ]
                  | e <- es ]
    r           = resumir es
    resumen     = campos [ "RES", show (cantidad r), talVez (promedio r), talVez (maxima r)
                         , talVez (minima r), show (aprobados r), show (reprobados r)
                         , show (pendientes r) ]
    campos      = foldr1 (\a b -> a ++ "\t" ++ b)

num :: Double -> String
num = printf "%.2f"

talVez :: Maybe Double -> String
talVez = maybe "-" num

etiqueta :: Estado -> String
etiqueta Aprobo        = "APROBO"
etiqueta Reprobo       = "REPROBO"
etiqueta (Pendiente _) = "PENDIENTE"

-- | Explicación corta del estado, para mostrarla en la tabla.
detalle :: Estado -> String
detalle Aprobo  = "Aprobó la asignatura"
detalle Reprobo = "No alcanzó el 3,0"
detalle (Pendiente nota)
  | nota <= 0 = "Ya tiene asegurado el 3,0"
  | nota > 5  = "Ya no alcanza el 3,0 aunque saque 5,0"
  | otherwise = "Necesita " ++ conComa (num nota) ++ " en el corte 3"

conComa :: String -> String
conComa = map (\c -> if c == '.' then ',' else c)

-- ---------------------------------------------------------------------
-- Orden "reporte": formato para personas
-- ---------------------------------------------------------------------

reporte :: String -> String
reporte contenido = unlines $
  [ "REPORTE DE NOTAS DEL CURSO"
  , "Pesos: corte 1 " ++ pct p1 ++ ", corte 2 " ++ pct p2 ++ ", corte 3 " ++ pct p3
  , ""
  , fila ["Estudiante", "C1", "C2", "C3", "Def.", "Situación"]
  , replicate 96 '-'
  ] ++
  [ fila [ nombre e, nota (corte1 e), nota (corte2 e), maybe "-" nota (corte3 e)
         , maybe "-" nota (definitiva e), detalle (estado e) ]
  | e <- es ] ++
  [ ""
  , "Estudiantes válidos: " ++ show (cantidad r)
  , "Promedio de las definitivas: " ++ maybe "-" nota (promedio r)
  , "Nota más alta: " ++ maybe "-" nota (maxima r) ++ "   Nota más baja: " ++ maybe "-" nota (minima r)
  , "Aprobados: " ++ show (aprobados r) ++ "   Reprobados: " ++ show (reprobados r)
      ++ "   Pendientes: " ++ show (pendientes r)
  ] ++
  (if null errs then [] else "" : "Renglones que no se pudieron leer:" :
     [ "  Renglón " ++ show n ++ ": " ++ m | (n, m) <- errs ])
  where
    (errs, es)   = leerCurso contenido
    r            = resumir es
    (p1, p2, p3) = pesos
    pct p        = show (round (p * 100) :: Int) ++ " %"
    nota         = conComa . num
    fila [a, b, c, d, e, f] = rellenar 30 a ++ rellenar 7 b ++ rellenar 7 c ++ rellenar 7 d
                              ++ rellenar 7 e ++ f
    fila otros   = unwords otros
    rellenar n t = take n (t ++ repeat ' ')
