import requests
import time 
import pandas as pd
from bs4 import BeautifulSoup

def all_star_roster_wiki(temporada):
    # Las URL de las temporadas son de la forma https://en.wikipedia.org/wiki/1997_NBA_All-Star_Game#endnote_rep
    url = f"https://en.wikipedia.org/wiki/{temporada}_NBA_All-Star_Game#endnote_rep"

    headers = {
        "User-Agent": "Mozilla/5.0"
    }

    datos = []

    print(f"Extrayendo elegidos del All Star en el año {temporada}")
    res = requests.get(url, headers = headers)
    soup = BeautifulSoup(res.text, "html.parser")

    tablas = soup.find_all('table', {'class': 'wikitable'})
    
    formato_dif = [2006, 2007, 2008, 2009, 2010, 2011]

    # Conferencia Este
    filas_este = tablas[0].find_all('tr')[1:]
    for fila in filas_este:
        columnas = fila.find_all('td')
        if len(columnas) >= 2 and temporada != 1999 and temporada not in formato_dif:
            nombre = columnas[1].get_text(strip = True)
            datos.append({
                'PLAYER': nombre,
                'CONFERENCE': 'EAST',
                'SEASON': temporada,
            })
        
        if len(columnas) >= 2 and temporada != 1999 and temporada in formato_dif:
            nombre = columnas[0].get_text(strip = True)
            datos.append({
                'PLAYER': nombre,
                'CONFERENCE': 'EAST',
                'SEASON': temporada,
            })

    # Conferencia Oeste
    filas_oeste = tablas[1].find_all('tr')[1:]
    for fila in filas_oeste:
        columnas = fila.find_all('td')
        if len(columnas) >= 2 and temporada != 1999 and temporada not in formato_dif:
            nombre = columnas[1].get_text(strip = True)
            datos.append({
                'PLAYER': nombre,
                'CONFERENCE': 'WEST',
                'SEASON': temporada,
            })
        if len(columnas) >= 2 and temporada != 1999 and temporada in formato_dif:
            nombre = columnas[0].get_text(strip = True)
            datos.append({
                'PLAYER': nombre,
                'CONFERENCE': 'WEST',
                'SEASON': temporada,
            })

    return pd.DataFrame(datos)
            

#Temporadas deseadas
temporadas = [y for y in range(1997, 2025)]

all_stars_por_temporada = []

for temporada in temporadas:
    datos = all_star_roster_wiki(temporada)
    all_stars_por_temporada.append(datos)
    time.sleep(10)

all_star_totales = pd.concat(all_stars_por_temporada, ignore_index= True)

all_star_totales.to_csv('all_stars.csv', index = False)
print("Jugadores del All-Star extraídos correctamente")
