-- | Notas.hs
--
-- Lógica pura del programa de notas: leer las líneas de un CSV, validar
-- cada una, calcular la definitiva y el estado de cada estudiante, y
-- resumir el curso. Ninguna función de este módulo toca archivos ni la
-- pantalla; Main.hs se encarga de eso.
--
-- Formato del CSV (separado por punto y coma, admite coma decimal):
--
--   nombre;corte1;corte2;corte3
--   Ana Pérez;4,2;3,8;4,0
--   Luis Díaz;2,5;3,0;          <- corte 3 vacío: todavía no se ha presentado
module Notas
  ( Estudiante (..)
  , Estado (..)
  , pesos
  , leerCurso
  , definitiva
  , estado
  , Resumen (..)
  , resumir
  , redondear2
  ) where

import Data.Char (isSpace, toLower)
import Data.List (isPrefixOf)

-- ---------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------

data Estudiante = Estudiante
  { linea  :: Int           -- ^ renglón del archivo, para poder reportar errores
  , nombre :: String
  , corte1 :: Double
  , corte2 :: Double
  , corte3 :: Maybe Double  -- ^ Nothing: el corte 3 todavía no tiene nota
  } deriving Show

data Estado
  = Aprobo
  | Reprobo
  | Pendiente Double        -- ^ nota que necesita en el corte 3 para llegar a 3,0
  deriving (Show, Eq)

-- | Porcentaje de cada corte. Cambiarlos aquí cambia todo el programa.
pesos :: (Double, Double, Double)
pesos = (0.30, 0.30, 0.40)

notaMinima :: Double
notaMinima = 3.0

-- ---------------------------------------------------------------------
-- Lectura y validación
-- ---------------------------------------------------------------------

-- | Recibe el contenido completo del CSV y devuelve, por un lado, los
-- errores (renglón y motivo) y, por otro, los estudiantes válidos.
-- Un renglón malo no detiene el programa: se reporta y se sigue.
leerCurso :: String -> ([(Int, String)], [Estudiante])
leerCurso contenido = separar (map leerRenglon renglonesUtiles)
  where
    sinBom = dropWhile (== '\xFEFF') contenido            -- Excel agrega un BOM al inicio
    renglones = zip [1 ..] (lines (filter (/= '\r') sinBom))
    renglonesUtiles = [ (n, r) | (n, r) <- renglones
                               , not (all isSpace r)
                               , not (esEncabezado r) ]
    esEncabezado r = "nombre" `isPrefixOf` map toLower (recortar r)

    separar resultados = ( [ e | Left e <- resultados ]
                         , [ x | Right x <- resultados ] )

-- | Convierte un renglón en estudiante, o explica por qué no se puede.
-- Either String: Left lleva el error y Right el valor correcto.
leerRenglon :: (Int, String) -> Either (Int, String) Estudiante
leerRenglon (n, renglon) =
  case map recortar (partir ';' renglon) of
    [nom, t1, t2, t3]
      | null nom  -> Left (n, "falta el nombre")
      | otherwise -> conRenglon $ do
          c1 <- leerNota "corte 1" t1
          c2 <- leerNota "corte 2" t2
          c3 <- if null t3 then Right Nothing else Just <$> leerNota "corte 3" t3
          Right (Estudiante n nom c1 c2 c3)
    campos -> Left (n, "tiene " ++ show (length campos) ++ " campos y se esperaban 4")
  where
    conRenglon = either (\motivo -> Left (n, motivo)) Right

-- | Lee una nota con punto o con coma decimal y comprueba que esté entre 0 y 5.
leerNota :: String -> String -> Either String Double
leerNota cual texto =
  case reads (map comaAPunto texto) :: [(Double, String)] of
    [(nota, "")]
      | nota >= 0 && nota <= 5 -> Right nota
      | otherwise              -> Left ("la nota del " ++ cual ++ " (" ++ texto ++ ") está fuera del rango 0 a 5")
    _ -> Left ("la nota del " ++ cual ++ " (\"" ++ texto ++ "\") no es un número")
  where
    comaAPunto c = if c == ',' then '.' else c

-- | Parte un texto por un separador (recursiva): partir ';' "a;b;;c" == ["a","b","","c"]
partir :: Char -> String -> [String]
partir sep texto =
  case break (== sep) texto of
    (campo, [])        -> [campo]
    (campo, _ : resto) -> campo : partir sep resto

recortar :: String -> String
recortar = reverse . dropWhile isSpace . reverse . dropWhile isSpace

-- ---------------------------------------------------------------------
-- Cálculos
-- ---------------------------------------------------------------------

-- | Redondea a dos decimales, con la regla escolar (el 5 sube).
-- Atención: 'round' de Haskell redondea al par (round 2.5 == 2), por eso no se usa.
redondear2 :: Double -> Double
redondear2 x = fromIntegral (floor (x * 100 + 0.5) :: Integer) / 100

-- | Definitiva, solo si ya están las tres notas.
definitiva :: Estudiante -> Maybe Double
definitiva e = do
  c3 <- corte3 e
  let (p1, p2, p3) = pesos
  Just (redondear2 (p1 * corte1 e + p2 * corte2 e + p3 * c3))

estado :: Estudiante -> Estado
estado e =
  case definitiva e of
    Just d
      | d >= notaMinima -> Aprobo
      | otherwise       -> Reprobo
    Nothing -> Pendiente necesita
  where
    (p1, p2, p3) = pesos
    acumulado = p1 * corte1 e + p2 * corte2 e
    -- se redondea hacia arriba para no prometer una nota que se queda corta
    necesita  = fromIntegral (ceiling ((notaMinima - acumulado) / p3 * 100 - 1e-9) :: Integer) / 100

-- ---------------------------------------------------------------------
-- Resumen del curso
-- ---------------------------------------------------------------------

data Resumen = Resumen
  { cantidad   :: Int
  , promedio   :: Maybe Double  -- ^ Nothing si nadie tiene definitiva
  , maxima     :: Maybe Double
  , minima     :: Maybe Double
  , aprobados  :: Int
  , reprobados :: Int
  , pendientes :: Int
  } deriving Show

resumir :: [Estudiante] -> Resumen
resumir es = Resumen
  { cantidad   = length es
  , promedio   = if null defs then Nothing else Just (redondear2 (sum defs / fromIntegral (length defs)))
  , maxima     = if null defs then Nothing else Just (maximum defs)
  , minima     = if null defs then Nothing else Just (minimum defs)
  , aprobados  = length [ () | Aprobo <- estados ]
  , reprobados = length [ () | Reprobo <- estados ]
  , pendientes = length [ () | Pendiente _ <- estados ]
  }
  where
    defs    = [ d | Just d <- map definitiva es ]
    estados = map estado es
