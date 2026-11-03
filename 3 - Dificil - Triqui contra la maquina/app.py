"""
app.py - Interfaz gráfica del triqui contra la máquina.

Esta vez el programa de Haskell (triqui.exe) se abre UNA sola vez al iniciar
la ventana y queda corriendo. Python le escribe una orden por renglón en su
entrada estándar y lee la respuesta en su salida estándar.

Para que la ventana nunca se congele mientras espera a Haskell:
  - un hilo aparte (lector) lee las respuestas y las pone en una cola;
  - la ventana revisa esa cola cada 30 ms con after().

Ejecutar:  python app.py      (en Windows también sirve:  py app.py)
"""

import os
import queue
import subprocess
import threading
import time
import tkinter as tk
from pathlib import Path
from tkinter import messagebox

CARPETA = Path(__file__).resolve().parent
EJECUTABLE = CARPETA / ("triqui.exe" if os.name == "nt" else "triqui")
REGISTRO = CARPETA / "registro_haskell.txt"   # aquí queda lo que Haskell escribe en stderr
SIN_CONSOLA = getattr(subprocess, "CREATE_NO_WINDOW", 0)

TAM = 360                 # lado del tablero en píxeles
CELDA = TAM // 3
ESPERA_MAXIMA = 5.0       # segundos que se espera una respuesta antes de declarar un error


# ---------------------------------------------------------------------------
# Conexión con el proceso de Haskell
# ---------------------------------------------------------------------------

class Motor:
    """Mantiene abierto triqui.exe y conversa con él renglón por renglón."""

    def __init__(self):
        self.registro = open(REGISTRO, "w", encoding="utf-8")
        self.proceso = subprocess.Popen(
            [str(EJECUTABLE)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            # stderr va a un archivo: si fuera a un PIPE que nadie lee, al llenarse
            # Haskell se bloquearía esperando y la ventana también.
            stderr=self.registro,
            text=True, encoding="utf-8", bufsize=1,
            creationflags=SIN_CONSOLA,
        )
        self.respuestas = queue.Queue()
        threading.Thread(target=self._leer, daemon=True).start()

    def _leer(self):
        """Corre en un hilo aparte: cada renglón que llega de Haskell va a la cola."""
        for renglon in self.proceso.stdout:
            self.respuestas.put(renglon.strip())
        self.respuestas.put(None)   # None avisa que Haskell cerró su salida

    def enviar(self, orden: str):
        if self.proceso.poll() is not None:
            raise BrokenPipeError("el proceso de Haskell ya terminó")
        self.proceso.stdin.write(orden + "\n")
        self.proceso.stdin.flush()   # sin flush la orden se queda en el búfer de Python

    def cerrar(self):
        try:
            self.enviar("SALIR")
            self.proceso.wait(timeout=1)
        except Exception:
            self.proceso.kill()
        self.registro.close()


# ---------------------------------------------------------------------------
# Ventana
# ---------------------------------------------------------------------------

class Aplicacion(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Triqui contra la máquina - Python + Haskell")
        self.resizable(False, False)
        self.protocol("WM_DELETE_WINDOW", self.al_cerrar)

        self.tablero = "." * 9
        self.esperando = None     # (orden enviada, hora de envío) mientras no llega la respuesta
        self.pendientes = []      # órdenes que esperan turno para salir
        self.partida_contada = False
        self.marcador = {"GANA_X": 0, "GANA_O": 0, "EMPATE": 0}
        self.construir()

        try:
            self.motor = Motor()
        except FileNotFoundError:
            messagebox.showerror("Falta el ejecutable", f"No se encontró {EJECUTABLE.name}.\n\n"
                                 "Compílelo primero con:\nghc -O2 -outputdir build Main.hs -o triqui")
            self.destroy()
            return
        self.after(30, self.revisar_respuestas)
        self.pedir("NIVEL 3")
        self.pedir_nueva("HUMANO")

    # --- Construcción de la ventana ----------------------------------------

    def construir(self):
        izquierda = tk.Frame(self)
        izquierda.pack(side="left", padx=14, pady=14)

        self.estado = tk.Label(izquierda, text="", font=("Segoe UI", 13, "bold"))
        self.estado.pack(pady=(0, 8))
        self.lienzo = tk.Canvas(izquierda, width=TAM, height=TAM, background="white",
                                highlightthickness=0)
        self.lienzo.pack()
        self.lienzo.bind("<Button-1>", self.clic)

        self.etiqueta_marcador = tk.Label(izquierda, text="", font=("Segoe UI", 11))
        self.etiqueta_marcador.pack(pady=8)

        derecha = tk.Frame(self)
        derecha.pack(side="left", fill="y", padx=(0, 14), pady=14)

        tk.Label(derecha, text="Nivel de la máquina", font=("Segoe UI", 10, "bold")).pack(anchor="w")
        self.nivel = tk.IntVar(value=3)
        for valor, texto in [(1, "Fácil"), (2, "Medio"), (3, "Imposible")]:
            tk.Radiobutton(derecha, text=texto, value=valor, variable=self.nivel,
                           command=lambda: self.pedir(f"NIVEL {self.nivel.get()}")).pack(anchor="w")

        tk.Button(derecha, text="Nueva: empiezo yo", width=24,
                  command=lambda: self.pedir_nueva("HUMANO")).pack(pady=(14, 4))
        tk.Button(derecha, text="Nueva: empieza la máquina", width=24,
                  command=lambda: self.pedir_nueva("MAQUINA")).pack()

        tk.Label(derecha, text="Conversación con Haskell", font=("Segoe UI", 10, "bold")).pack(
            anchor="w", pady=(18, 2))
        self.conversacion = tk.Text(derecha, width=38, height=14, font=("Consolas", 9),
                                    state="disabled", background="#f4f6f8")
        self.conversacion.pack(fill="y", expand=True)
        self.conversacion.tag_configure("enviado", foreground="#1f4e8c")
        self.conversacion.tag_configure("recibido", foreground="#1d6b2f")
        self.conversacion.tag_configure("error", foreground="#a01010")

    # --- Envío de órdenes ----------------------------------------------------

    def pedir(self, orden: str):
        """Envía una orden a Haskell. La respuesta llegará después por la cola."""
        if self.esperando:
            # Una orden a la vez: el protocolo es pregunta-respuesta.
            # Si ya hay una en camino, esta queda en fila hasta que llegue la respuesta.
            self.pendientes.append(orden)
            return
        try:
            self.motor.enviar(orden)
        except (BrokenPipeError, OSError) as error:
            self.motor_caido(str(error))
            return
        self.esperando = (orden, time.monotonic())
        self.anotar("-> " + orden, "enviado")
        if orden.startswith("JUGAR") or orden == "NUEVA MAQUINA":
            self.estado.config(text="La máquina está pensando...")

    def pedir_nueva(self, quien: str):
        self.partida_contada = False
        self.pedir(f"NUEVA {quien}")

    def clic(self, evento):
        if self.esperando or "." not in self.tablero or self.terminada():
            return
        casilla = (evento.y // CELDA) * 3 + (evento.x // CELDA)
        if 0 <= casilla <= 8:
            self.pedir(f"JUGAR {casilla}")

    # --- Recepción de respuestas ------------------------------------------

    def revisar_respuestas(self):
        """Se ejecuta cada 30 ms en el hilo de la ventana; nunca se bloquea."""
        try:
            while True:
                respuesta = self.motor.respuestas.get_nowait()
                if respuesta is None:
                    self.motor_caido("Haskell cerró la conexión.")
                    return
                self.atender(respuesta)
        except queue.Empty:
            pass
        if self.esperando and time.monotonic() - self.esperando[1] > ESPERA_MAXIMA:
            self.anotar("(sin respuesta a tiempo)", "error")
            self.esperando = None
            messagebox.showwarning("Sin respuesta", "Haskell no respondió a tiempo.")
        self.after(30, self.revisar_respuestas)

    def atender(self, respuesta: str):
        self.esperando = None
        self.procesar(respuesta)
        if self.pendientes and not self.esperando:
            self.pedir(self.pendientes.pop(0))

    def procesar(self, respuesta: str):
        partes = respuesta.split(" ")
        if partes[0] == "ERR":
            self.anotar("<- " + respuesta, "error")
            self.estado.config(text=respuesta[4:].capitalize())
            return
        if partes[0] != "OK" or len(partes) != 5:
            self.anotar("<- " + respuesta, "error")
            return
        self.anotar("<- " + respuesta, "recibido")
        _, self.tablero, self.resultado, jugada, linea = partes
        self.dibujar(None if linea == "-" else [int(i) for i in linea.split(",")])
        mensajes = {"SIGUE": "Su turno (usted es X)", "GANA_X": "¡Usted ganó!",
                    "GANA_O": "Ganó la máquina", "EMPATE": "Empate"}
        self.estado.config(text=mensajes.get(self.resultado, self.resultado))
        if self.resultado != "SIGUE" and not self.partida_contada:
            self.marcador[self.resultado] += 1
            self.partida_contada = True
        self.etiqueta_marcador.config(text=(f"Usted {self.marcador['GANA_X']}   ·   "
                                            f"Máquina {self.marcador['GANA_O']}   ·   "
                                            f"Empates {self.marcador['EMPATE']}"))

    def terminada(self) -> bool:
        return getattr(self, "resultado", "SIGUE") != "SIGUE"

    # --- Dibujo --------------------------------------------------------------

    def dibujar(self, linea_ganadora):
        c = self.lienzo
        c.delete("all")
        for k in (1, 2):
            c.create_line(k * CELDA, 8, k * CELDA, TAM - 8, width=4, fill="#333")
            c.create_line(8, k * CELDA, TAM - 8, k * CELDA, width=4, fill="#333")
        m = 28   # margen de cada ficha dentro de su celda
        for i, ficha in enumerate(self.tablero):
            x, y = (i % 3) * CELDA, (i // 3) * CELDA
            if ficha == "X":
                c.create_line(x + m, y + m, x + CELDA - m, y + CELDA - m, width=8, fill="#1f4e8c")
                c.create_line(x + CELDA - m, y + m, x + m, y + CELDA - m, width=8, fill="#1f4e8c")
            elif ficha == "O":
                c.create_oval(x + m, y + m, x + CELDA - m, y + CELDA - m, width=8, outline="#c0392b")
        if linea_ganadora:
            centro = lambda i: ((i % 3) * CELDA + CELDA // 2, (i // 3) * CELDA + CELDA // 2)
            (x1, y1), (x2, y2) = centro(linea_ganadora[0]), centro(linea_ganadora[-1])
            c.create_line(x1, y1, x2, y2, width=10, fill="#f1c40f", capstyle="round")

    def anotar(self, texto: str, estilo: str):
        self.conversacion.config(state="normal")
        self.conversacion.insert("end", texto + "\n", estilo)
        self.conversacion.see("end")
        self.conversacion.config(state="disabled")

    # --- Fallos y cierre ---------------------------------------------------

    def motor_caido(self, motivo: str):
        self.anotar("(Haskell se detuvo)", "error")
        messagebox.showerror("Haskell se detuvo",
                             f"{motivo}\n\nRevise {REGISTRO.name} para ver qué escribió Haskell en stderr.")
        self.destroy()

    def al_cerrar(self):
        if hasattr(self, "motor"):
            self.motor.cerrar()
        self.destroy()


if __name__ == "__main__":
    Aplicacion().mainloop()
