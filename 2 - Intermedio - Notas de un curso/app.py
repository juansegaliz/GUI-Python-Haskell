"""
app.py - Interfaz gráfica del programa de notas.

Python abre el CSV, le pasa la RUTA a Haskell (notas.exe) y recibe renglones
etiquetados (EST, ERR, RES) que convierte en una tabla, un resumen y una
lista de errores. Python no calcula ninguna nota: todo el cálculo es de Haskell.

Ejecutar:  python app.py      (en Windows también sirve:  py app.py)
"""

import os
import subprocess
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

CARPETA = Path(__file__).resolve().parent
EJECUTABLE = CARPETA / ("notas.exe" if os.name == "nt" else "notas")
SIN_CONSOLA = getattr(subprocess, "CREATE_NO_WINDOW", 0)

COLUMNAS = [("nombre", "Estudiante", 220), ("c1", "Corte 1", 70), ("c2", "Corte 2", 70),
            ("c3", "Corte 3", 70), ("def", "Definitiva", 85), ("detalle", "Situación", 290)]


# ---------------------------------------------------------------------------
# Comunicación con Haskell
# ---------------------------------------------------------------------------

def ejecutar_haskell(*argumentos: str) -> str:
    """Ejecuta notas.exe con los argumentos dados y devuelve su salida estándar."""
    resultado = subprocess.run([str(EJECUTABLE), *argumentos], capture_output=True, text=True,
                               encoding="utf-8", timeout=15, creationflags=SIN_CONSOLA)
    if resultado.returncode != 0:
        raise RuntimeError(f"(código {resultado.returncode}) {resultado.stderr.strip()}")
    return resultado.stdout


def interpretar(salida: str) -> dict:
    """Convierte los renglones etiquetados de Haskell en datos de Python.

    EST  renglón nombre c1 c2 c3 definitiva estado detalle
    ERR  renglón motivo
    RES  cantidad promedio máxima mínima aprobados reprobados pendientes
    """
    datos = {"estudiantes": [], "errores": [], "resumen": None}
    for renglon in salida.splitlines():
        campos = renglon.split("\t")
        etiqueta = campos[0]
        if etiqueta == "EST" and len(campos) == 9:
            _, linea, nombre, c1, c2, c3, definitiva, estado, detalle = campos
            datos["estudiantes"].append({"linea": int(linea), "nombre": nombre, "c1": c1, "c2": c2,
                                         "c3": c3, "def": definitiva, "estado": estado,
                                         "detalle": detalle})
        elif etiqueta == "ERR" and len(campos) == 3:
            datos["errores"].append((int(campos[1]), campos[2]))
        elif etiqueta == "RES" and len(campos) == 8:
            claves = ["cantidad", "promedio", "maxima", "minima", "aprobados", "reprobados", "pendientes"]
            datos["resumen"] = dict(zip(claves, campos[1:]))
        else:
            # Un renglón que no cumple el formato indica un error en el programa de Haskell.
            raise ValueError(f"Renglón inesperado de Haskell: {renglon!r}")
    return datos


def con_coma(texto: str) -> str:
    """Haskell envía 4.20; en pantalla se muestra 4,20."""
    return texto.replace(".", ",")


# ---------------------------------------------------------------------------
# Ventana
# ---------------------------------------------------------------------------

class Aplicacion(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Notas de un curso - Python + Haskell")
        self.geometry("900x640")
        self.minsize(760, 520)
        self.archivo = None
        self.orden = {}   # columna -> ¿orden descendente?

        barra = tk.Frame(self)
        barra.pack(fill="x", padx=12, pady=10)
        tk.Button(barra, text="Abrir CSV...", width=14, command=self.abrir).pack(side="left")
        tk.Button(barra, text="Recalcular", width=12, command=self.calcular).pack(side="left", padx=6)
        tk.Button(barra, text="Guardar reporte...", width=16, command=self.guardar_reporte).pack(side="left")
        self.etiqueta_archivo = tk.Label(barra, text="Ningún archivo abierto", fg="#555")
        self.etiqueta_archivo.pack(side="left", padx=12)

        # Tabla de estudiantes
        marco = tk.Frame(self)
        marco.pack(fill="both", expand=True, padx=12)
        self.tabla = ttk.Treeview(marco, columns=[c for c, _, _ in COLUMNAS], show="headings")
        for clave, titulo, ancho in COLUMNAS:
            self.tabla.heading(clave, text=titulo, command=lambda c=clave: self.ordenar(c))
            self.tabla.column(clave, width=ancho, anchor="w" if clave in ("nombre", "detalle") else "center")
        barra_v = ttk.Scrollbar(marco, orient="vertical", command=self.tabla.yview)
        self.tabla.configure(yscrollcommand=barra_v.set)
        self.tabla.pack(side="left", fill="both", expand=True)
        barra_v.pack(side="right", fill="y")
        self.tabla.tag_configure("APROBO", background="#e3f4e6")
        self.tabla.tag_configure("REPROBO", background="#fbe4e4")
        self.tabla.tag_configure("PENDIENTE", background="#fff4d6")

        # Resumen del curso
        self.resumen = tk.Label(self, text="", anchor="w", justify="left", font=("Segoe UI", 10, "bold"))
        self.resumen.pack(fill="x", padx=12, pady=(8, 2))

        # Errores de lectura
        tk.Label(self, text="Renglones del CSV que no se pudieron leer:", anchor="w").pack(fill="x", padx=12)
        self.errores = tk.Listbox(self, height=5, foreground="#a01010")
        self.errores.pack(fill="x", padx=12, pady=(2, 12))

        self.estudiantes = []
        ejemplo = CARPETA / "notas_ejemplo.csv"
        if ejemplo.exists():
            self.archivo = ejemplo
            self.after(100, self.calcular)

    # --- Acciones -----------------------------------------------------------

    def abrir(self):
        ruta = filedialog.askopenfilename(title="Abrir notas", initialdir=CARPETA,
                                          filetypes=[("Archivos CSV", "*.csv"), ("Todos", "*.*")])
        if ruta:
            self.archivo = Path(ruta)
            self.calcular()

    def calcular(self):
        if not self.archivo:
            messagebox.showinfo("Sin archivo", "Abra primero un archivo CSV.")
            return
        try:
            datos = interpretar(ejecutar_haskell("calcular", str(self.archivo)))
        except FileNotFoundError:
            messagebox.showerror("Falta el ejecutable", f"No se encontró {EJECUTABLE.name}.\n\n"
                                 "Compílelo primero con:\nghc -O2 -outputdir build Main.hs -o notas")
            return
        except (RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
            messagebox.showerror("Error en Haskell", str(error))
            return
        self.etiqueta_archivo.config(text=self.archivo.name)
        self.estudiantes = datos["estudiantes"]
        self.llenar_tabla()
        self.mostrar_resumen(datos["resumen"])
        self.errores.delete(0, "end")
        for linea, motivo in datos["errores"]:
            self.errores.insert("end", f"Renglón {linea}: {motivo}")
        if not datos["errores"]:
            self.errores.insert("end", "(ninguno)")

    def guardar_reporte(self):
        if not self.archivo:
            messagebox.showinfo("Sin archivo", "Abra primero un archivo CSV.")
            return
        destino = filedialog.asksaveasfilename(title="Guardar reporte", defaultextension=".txt",
                                               initialfile="reporte_notas.txt",
                                               filetypes=[("Texto", "*.txt")])
        if not destino:
            return
        try:
            # Esta vez es Haskell quien escribe el archivo, con writeFile.
            mensaje = ejecutar_haskell("reporte", str(self.archivo), destino)
        except (RuntimeError, FileNotFoundError, subprocess.TimeoutExpired) as error:
            messagebox.showerror("Error en Haskell", str(error))
            return
        messagebox.showinfo("Reporte", mensaje.strip())

    # --- Presentación -------------------------------------------------------

    def llenar_tabla(self):
        self.tabla.delete(*self.tabla.get_children())
        for e in self.estudiantes:
            valores = [e["nombre"]] + [con_coma(e[c]) for c in ("c1", "c2", "c3", "def")] + [e["detalle"]]
            self.tabla.insert("", "end", values=valores, tags=(e["estado"],))

    def ordenar(self, columna: str):
        """Ordena la tabla al hacer clic en un encabezado; un segundo clic invierte el orden."""
        descendente = not self.orden.get(columna, True)
        self.orden[columna] = descendente

        def clave(e):
            valor = e[columna]
            if columna in ("c1", "c2", "c3", "def"):
                return float(valor) if valor != "-" else -1.0
            return valor.lower()

        self.estudiantes.sort(key=clave, reverse=descendente)
        self.llenar_tabla()

    def mostrar_resumen(self, r):
        if not r:
            self.resumen.config(text="")
            return
        self.resumen.config(text=(
            f"Estudiantes: {r['cantidad']}    Promedio: {con_coma(r['promedio'])}    "
            f"Más alta: {con_coma(r['maxima'])}    Más baja: {con_coma(r['minima'])}\n"
            f"Aprobados: {r['aprobados']}    Reprobados: {r['reprobados']}    "
            f"Pendientes: {r['pendientes']}"))


if __name__ == "__main__":
    Aplicacion().mainloop()
