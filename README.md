# Interfaz gráfica en Python para un programa en Haskell

Esta carpeta contiene tres proyectos de ejemplo, de menor a mayor dificultad. Los tres muestran cómo hacer una ventana en Python que usa un programa escrito en Haskell. En todos se sigue la misma regla:

> **Haskell hace los cálculos. Python solo dibuja la ventana y le pasa a Haskell lo que el usuario escribe o pulsa.**

| Nivel | Carpeta | Qué hace | Qué se aprende |
|---|---|---|---|
| 1 · Fácil | `1 - Facil - Analizador de texto` | Cuenta palabras, busca palíndromos, invierte frases. | Llamar a Haskell desde Python una vez por clic. |
| 2 · Intermedio | `2 - Intermedio - Notas de un curso` | Lee un archivo de notas y calcula definitivas. | Leer archivos, validar datos, responder en un formato que otro programa entiende. |
| 3 · Difícil | `3 - Dificil - Triqui contra la maquina` | Triqui contra la computadora. | Mantener Haskell abierto y conversar con él durante todo el juego. |

**Haga los proyectos en orden.** Cada README da por sabido lo que se explicó en el anterior.

Antes de abrir cualquiera de los tres, instale las dos herramientas de esta página. Se hace **una sola vez** en el computador.

---

## Parte 1. Instalar Python

### 1.1. Descargar

1. Entre a <https://www.python.org/downloads/>.
2. Pulse el botón amarillo **Download Python 3.x.x** (el número exacto no importa, basta con que sea 3.10 o mayor).
3. Abra el archivo descargado (`python-3.x.x-amd64.exe`).

### 1.2. Instalar

En la **primera pantalla** del instalador:

1. **Marque la casilla de abajo: "Add python.exe to PATH".** Si no la marca, Windows no encontrará Python después.
2. Pulse **Install Now**. Esta opción ya incluye Tkinter, que es lo que dibuja las ventanas.
3. Espere a que diga **Setup was successful** y pulse **Close**.

### 1.3. Comprobar

1. Pulse la tecla Windows, escriba `cmd` y pulse Enter. Se abre una ventana negra: el **Símbolo del sistema** (cmd).
2. Escriba lo siguiente y pulse Enter:

   ```cmd
   py --version
   ```

   Debe aparecer algo como:

   ```
   Python 3.13.1
   ```

3. Escriba lo siguiente y pulse Enter:

   ```cmd
   py -m tkinter
   ```

   Debe abrirse una ventanita pequeña que dice *"This is Tcl/Tk version..."*. **Si aparece, Tkinter funciona.** Ciérrela.

> **¿`py` o `python`?** En Windows, `py` es el lanzador oficial de Python y casi siempre funciona. En estos README se usa `py`. Si `py` no existe en su computador pero `python` sí, use `python` en todos los comandos.

### 1.4. Si algo sale mal

| Lo que aparece | Qué hacer |
|---|---|
| `'py' is not recognized...` y `'python' is not recognized...` | Python no quedó instalado o no se marcó "Add python.exe to PATH". Vuelva a ejecutar el instalador, elija **Modify**, siga hasta **Advanced Options**, marque **Add Python to environment variables** y pulse **Install**. Luego **cierre cmd y ábralo de nuevo**. |
| Al escribir `python` se abre la **Microsoft Store**, o no pasa nada | Es un acceso directo falso de Windows. Use `py` en lugar de `python`. Si quiere quitarlo: Configuración → Aplicaciones → Configuración avanzada de aplicaciones → **Alias de ejecución de aplicaciones**, y desactive los dos de Python. |
| `py -m tkinter` dice `No module named tkinter` | Ejecute el instalador de nuevo, elija **Modify** y marque **tcl/tk and IDLE**. |

---

## Parte 2. Instalar Haskell (GHC)

GHC es el compilador de Haskell. Se instala con un programa llamado **GHCup**. La instalación tarda entre 10 y 20 minutos, porque descarga más de 300 MB.

### 2.1. Abrir PowerShell normal (no como administrador)

1. Pulse la tecla Windows y escriba `powershell`.
2. Haga clic en **Windows PowerShell** (clic normal, **no** "Ejecutar como administrador").

### 2.2. Pegar el comando de instalación

Copie esta línea completa, péguela en PowerShell (clic derecho pega) y pulse Enter:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force;[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; try { Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Invoke-WebRequest https://www.haskell.org/ghcup/sh/bootstrap-haskell.ps1 -UseBasicParsing))) -ArgumentList $true } catch { Write-Error $_ }
```

Este comando es el oficial, tomado de <https://www.haskell.org/ghcup/>.

### 2.3. Responder las preguntas

El instalador hace varias preguntas. Responda así:

| Pregunta (en inglés) | Qué responder |
|---|---|
| *Where to install to...?* | Pulse **Enter** (acepta `C:\`). |
| *GHCup is already installed, what do you want to do?* (solo aparece si hubo un intento anterior) | Escriba **R** y Enter (reinstalar). |
| *Specify Cabal directory...* | Pulse **Enter**. |
| *Do you want to install the haskell-language-server (HLS)...?* | Escriba **N** y Enter. |
| *Do you want to install stack as well?* | Escriba **N** y Enter. |
| *Do you want to create convenience desktop shortcuts...?* | Pulse **Enter**. |
| *Do you want GHCup to install a default MSys2 toolchain?* | Escriba **Y** y Enter. |

### 2.4. Esperar a la segunda ventana: NO la cierre

Cuando PowerShell diga **`Starting GHCup installer...`**, se abre **otra ventana** llamada **MinGW x64**. **Esa es la que de verdad instala Haskell.**

- Verá renglones como `[ Info ] downloading...` y `[ Info ] Installing ghc`.
- En `Installing ghc` puede quedarse **varios minutos sin mostrar nada nuevo**. Es normal.
- **No la cierre.** Si intenta cerrarla y aparece un aviso que dice *"Processes are running in session... Close anyway?"*, pulse **Cancel**: la instalación todavía no ha terminado.
- Sabrá que terminó cuando la ventana diga que acabó, pida pulsar una tecla o se cierre sola.

### 2.5. Comprobar

1. **Cierre todas las ventanas de cmd y PowerShell** que tenga abiertas. Las ventanas viejas no se enteran de que Haskell se instaló.
2. Abra un cmd nuevo (tecla Windows, `cmd`, Enter).
3. Escriba:

   ```cmd
   ghc --version
   ```

   Debe aparecer algo como:

   ```
   The Glorious Glasgow Haskell Compilation System, version 9.10.3
   ```

**Si aparece, ya puede empezar con el proyecto 1.**

### 2.6. Si algo sale mal

| Lo que aparece | Qué hacer |
|---|---|
| `'ghc' is not recognized...` justo después de instalar | Cierre **todas** las ventanas de cmd y PowerShell y abra una nueva. Si sigue igual, revise el paso de abajo. |
| `'ghc' is not recognized...` y la carpeta `C:\ghcup\bin` está **vacía** | La instalación no terminó: probablemente se cerró la ventana MinGW antes de tiempo. Repita desde el paso 2.2 y responda **R** cuando pregunte si quiere reinstalar. |
| `Access to the path 'C:\ghcup' is denied` | Quedó un intento anterior a medias que tiene la carpeta bloqueada. Siga las instrucciones de la tabla siguiente. |
| La ventana MinGW se cierra sola con un error, o el antivirus muestra un aviso | El antivirus puede bloquear la instalación. Permita el programa o desactive el antivirus mientras instala, y repita desde el paso 2.2. |

**Cómo limpiar un intento anterior** (cuando aparece *Access denied*):

1. Cierre las ventanas MinGW y cualquier Explorador de archivos que esté mostrando `C:\ghcup`.
2. Pulse la tecla Windows, escriba `powershell`, haga **clic derecho** en Windows PowerShell y elija **Ejecutar como administrador**.
3. Pegue estas cuatro líneas y pulse Enter:

   ```powershell
   Get-Process | Where-Object { $_.Path -like "C:\ghcup*" } | Stop-Process -Force
   Remove-Item C:\ghcup -Recurse -Force
   Get-ChildItem C:\ -Filter "ghcup-*" -Directory | Remove-Item -Recurse -Force
   dir C:\ | Select-String ghcup
   ```

   La última línea no debe mostrar nada. Si dice que el archivo está en uso, reinicie el computador y repita este paso.
4. Cierre esa ventana de administrador y repita la instalación desde el paso 2.1, en una ventana **normal**.

---

## Parte 3. Para su proyecto de feria

La lógica de su proyecto va en módulos de Haskell puros, como `Analisis.hs`, `Notas.hs` o `Triqui.hs`. El `Main.hs` solo lee lo que llega, llama a esas funciones e imprime la respuesta.

Primero haga que su programa de Haskell funcione **por consola**, sin ventana. Solo cuando eso funcione, haga la ventana. La interfaz puede hacerse en el lenguaje que el grupo escoja: lo que se muestra aquí con Python funciona igual desde cualquier lenguaje capaz de ejecutar un programa y leer lo que este imprime.
