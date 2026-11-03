"""
app.py - Interfaz gráfica del analizador de texto.

Python solo dibuja la ventana. Cada vez que se pulsa un botón, ejecuta el
programa de Haskell (analizador.exe), le entrega el texto por la entrada
estándar y muestra lo que Haskell responda por la salida estándar.

Ejecutar:  python app.py      (en Windows también sirve:  py app.py)
"""

import os
import subprocess
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, scrolledtext

# El ejecutable de Haskell está en la misma carpeta que este archivo.
CARPETA = Path(__file__).resolve().parent
EJECUTABLE = CARPETA / ("analizador.exe" if os.name == "nt" else "analizador")

# En Windows, evita que se abra una consola negra cada vez que se llama a Haskell.
SIN_CONSOLA = getattr(subprocess, "CREATE_NO_WINDOW", 0)

TEXTO_DE_EJEMPLO = (
    "Anita lava la tina.\n"
    "Ana y Otto reconocen que el oso come arepa con queso.\n"
    "La arepa de queso es la arepa que más se come en la casa de Ana."
)


def llamar_haskell(operacion: str, texto: str) -> str:
    """Ejecuta analizador.exe <operacion>, le pasa el texto y devuelve su respuesta."""
    resultado = subprocess.run(
        [str(EJECUTABLE), operacion],
        input=texto,            # lo que Haskell leerá con getContents
        capture_output=True,    # guarda stdout y stderr en vez de mostrarlos
        text=True,
        encoding="utf-8",       # debe coincidir con hSetEncoding ... utf8 de Haskell
        timeout=10,             # si Haskell se demora más de 10 s, se cancela
        creationflags=SIN_CONSOLA,
    )
    if resultado.returncode != 0:
        # Haskell escribió el motivo en stderr y terminó con código distinto de 0.
        raise RuntimeError(resultado.stderr.strip() or f"Haskell terminó con código {resultado.returncode}")
    return resultado.stdout


class Aplicacion(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Analizador de texto - Python + Haskell")
        self.geometry("760x620")
        self.minsize(560, 480)

        tk.Label(self, text="Escriba o pegue un texto:", anchor="w",
                 font=("Segoe UI", 11, "bold")).pack(fill="x", padx=12, pady=(12, 4))
        self.entrada = scrolledtext.ScrolledText(self, height=9, wrap="word", font=("Consolas", 11))
        self.entrada.pack(fill="both", expand=True, padx=12)
        self.entrada.insert("1.0", TEXTO_DE_EJEMPLO)

        # Un botón por operación. El segundo valor es el nombre que entiende Haskell.
        botones = tk.Frame(self)
        botones.pack(fill="x", padx=12, pady=10)
        for etiqueta, operacion in [("Contar", "contar"),
                                    ("Palabras frecuentes", "frecuentes"),
                                    ("Palíndromos", "palindromos"),
                                    ("Invertir palabras", "invertir")]:
            tk.Button(botones, text=etiqueta, width=18,
                      command=lambda op=operacion: self.analizar(op)).pack(side="left", padx=(0, 6))
        tk.Button(botones, text="Limpiar", command=self.limpiar).pack(side="right")

        tk.Label(self, text="Respuesta de Haskell:", anchor="w",
                 font=("Segoe UI", 11, "bold")).pack(fill="x", padx=12, pady=(0, 4))
        self.salida = scrolledtext.ScrolledText(self, height=11, wrap="word", font=("Consolas", 11),
                                                state="disabled", background="#f4f6f8")
        self.salida.pack(fill="both", expand=True, padx=12)

        self.estado = tk.Label(self, text=f"Ejecutable: {EJECUTABLE.name}", anchor="w", fg="#555")
        self.estado.pack(fill="x", padx=12, pady=6)

    def analizar(self, operacion: str):
        texto = self.entrada.get("1.0", "end-1c")
        if not texto.strip():
            messagebox.showwarning("Sin texto", "Escriba un texto antes de analizarlo.")
            return
        try:
            respuesta = llamar_haskell(operacion, texto)
        except FileNotFoundError:
            messagebox.showerror(
                "Falta el ejecutable",
                f"No se encontró {EJECUTABLE.name}.\n\nCompílelo primero en esta carpeta con:\n"
                "ghc -O2 -outputdir build Main.hs -o analizador")
            return
        except subprocess.TimeoutExpired:
            messagebox.showerror("Sin respuesta", "Haskell tardó demasiado y se canceló la operación.")
            return
        except RuntimeError as error:
            messagebox.showerror("Error en Haskell", str(error))
            return
        self.mostrar(respuesta)
        self.estado.config(text=f"Operación \"{operacion}\" resuelta por {EJECUTABLE.name}")

    def mostrar(self, texto: str):
        self.salida.config(state="normal")
        self.salida.delete("1.0", "end")
        self.salida.insert("1.0", texto)
        self.salida.config(state="disabled")

    def limpiar(self):
        self.entrada.delete("1.0", "end")
        self.mostrar("")


if __name__ == "__main__":
    Aplicacion().mainloop()
