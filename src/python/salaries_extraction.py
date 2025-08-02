import requests 
import time
import pandas as pd
from bs4 import BeautifulSoup


def salarios_hoops_hype(temporada):
    # Las URL de las temporadas son de la forma https://hoopshype.com/salaries/players/2016-2017/
    url = f"https://hoopshype.com/salaries/players/{temporada}/"

    headers = {
        "User-Agent": "Mozilla/5.0"
    }

    print(f"Extrayendo temporada {temporada}")
    res = requests.get(url, headers = headers)
    soup = BeautifulSoup(res.text, "html.parser")

    tabla = soup.find("table")
    filas = tabla.find_all("tr")[1:]

    datos = []
    for fila in filas:
        columnas = fila.find_all("td")
        jugador = columnas[1].get_text(strip = True)
        salario = columnas[3].get_text(strip = True).replace("$", "").replace(",", "")

        try:
            salario = int(salario)
        except Exception:
            salario = None  # Si no hay salario lo registramos como faltante

        datos.append({
            "PLAYER": jugador,
            "ADJUSTED SALARY ($)": salario,
            "SEASON": temporada
        })

    return pd.DataFrame(datos)

#Temporadas deseadas
temporadas = [f"{y}-{y+1}" for y in range(1996, 2024)]

salarios_por_temporada = []

for temporada in temporadas:
    datos = salarios_hoops_hype(temporada)
    salarios_por_temporada.append(datos)
    time.sleep(10)

salarios_totales = pd.concat(salarios_por_temporada, ignore_index= True)

salarios_totales.to_csv('salarios_nba.csv', index = False)
print("Salarios extraídos correctamente")
