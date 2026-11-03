-- | Analisis.hs
--
-- Toda la lógica del analizador de texto. Este módulo es puro: no lee
-- archivos, no imprime nada y no sabe que existe una ventana en Python.
-- Recibe un texto (String) y devuelve otro texto (String) con el informe.
module Analisis
  ( extraerPalabras
  , normalizar
  , informeConteo
  , informeFrecuentes
  , informePalindromos
  , informeInvertir
  ) where

import Data.Char (isAlpha, toLower)
import Data.List (group, sort, sortBy)
import Data.Ord (Down (..), comparing)

-- ---------------------------------------------------------------------
-- Herramientas básicas
-- ---------------------------------------------------------------------

-- | Quita la tilde de una vocal. Las demás letras quedan igual
-- (la ñ se conserva, porque en español es una letra distinta de la n).
sinTilde :: Char -> Char
sinTilde c
  | c `elem` "áàä" = 'a'
  | c `elem` "éèë" = 'e'
  | c `elem` "íìï" = 'i'
  | c `elem` "óòö" = 'o'
  | c `elem` "úùü" = 'u'
  | otherwise      = c

-- | Pasa a minúsculas y quita tildes: "Árbol" y "arbol" quedan iguales.
normalizar :: String -> String
normalizar = map (sinTilde . toLower)

-- | Parte el texto en palabras. Una palabra es una secuencia de letras;
-- los espacios, los signos y los números sirven de separadores.
-- Es una función recursiva: toma una palabra y se llama con el resto.
extraerPalabras :: String -> [String]
extraerPalabras texto =
  case dropWhile (not . isAlpha) texto of
    ""    -> []
    resto -> let (palabra, siguiente) = span isAlpha resto
             in palabra : extraerPalabras siguiente

-- | Agrupa y cuenta elementos repetidos: ["b","a","b"] -> [("a",1),("b",2)]
contarRepetidos :: Ord a => [a] -> [(a, Int)]
contarRepetidos xs = [ (x, length g) | g@(x : _) <- group (sort xs) ]

-- ---------------------------------------------------------------------
-- Operación 1: contar
-- ---------------------------------------------------------------------

informeConteo :: String -> String
informeConteo texto = unlines
  [ "Líneas:                  " ++ show (length (lines texto))
  , "Palabras:                " ++ show numPalabras
  , "Letras:                  " ++ show numLetras
  , "Caracteres (sin saltos): " ++ show (length [ c | c <- texto, c /= '\n' ])
  , "Longitud media:          " ++ media
  ]
  where
    palabras    = extraerPalabras texto
    numPalabras = length palabras
    numLetras   = sum (map length palabras)
    media
      | numPalabras == 0 = "no hay palabras"
      | otherwise        = conUnDecimal (fromIntegral numLetras / fromIntegral numPalabras)
                           ++ " letras por palabra"

-- | Muestra un número con un decimal sin usar librerías: 4.666 -> "4,7"
conUnDecimal :: Double -> String
conUnDecimal x = show entero ++ "," ++ show decimal
  where
    decimas          = round (x * 10) :: Int
    (entero, decimal) = decimas `divMod` 10

-- ---------------------------------------------------------------------
-- Operación 2: palabras más frecuentes
-- ---------------------------------------------------------------------

-- | Las diez palabras que más se repiten. Se ignoran las de menos de
-- cuatro letras ("de", "la", "que"...), porque si no, siempre ganarían.
informeFrecuentes :: String -> String
informeFrecuentes texto
  | null ranking = "No hay palabras de cuatro letras o más.\n"
  | otherwise    = unlines (zipWith renglon [1 :: Int ..] ranking)
  where
    candidatas = [ normalizar p | p <- extraerPalabras texto, length p >= 4 ]
    ordenadas  = sortBy (comparing (Down . snd) <> comparing fst)
                        (contarRepetidos candidatas)
    ranking    = take 10 ordenadas
    renglon i (palabra, veces) =
      show i ++ ". " ++ palabra ++ " (" ++ show veces ++ (if veces == 1 then " vez)" else " veces)")

-- ---------------------------------------------------------------------
-- Operación 3: palíndromos
-- ---------------------------------------------------------------------

esPalindromo :: String -> Bool
esPalindromo p = p == reverse p

informePalindromos :: String -> String
informePalindromos texto = unlines $
  [ "¿El texto completo se lee igual al revés? " ++ (if fraseCompleta then "Sí" else "No")
  , ""
  , "Palabras palíndromas (de tres letras o más):"
  ] ++ lista
  where
    letras        = normalizar (filter isAlpha texto)
    fraseCompleta = not (null letras) && esPalindromo letras
    encontradas   = [ p | (p, _) <- contarRepetidos (map normalizar (extraerPalabras texto))
                        , length p >= 3, esPalindromo p ]
    lista
      | null encontradas = ["  (ninguna)"]
      | otherwise        = [ "  - " ++ p | p <- encontradas ]

-- ---------------------------------------------------------------------
-- Operación 4: invertir
-- ---------------------------------------------------------------------

-- | Invierte el orden de las palabras de cada linea y deja cada palabra
-- al derecho: "hola mundo cruel" -> "cruel mundo hola"
informeInvertir :: String -> String
informeInvertir texto = unlines [ unwords (reverse (words linea)) | linea <- lines texto ]
