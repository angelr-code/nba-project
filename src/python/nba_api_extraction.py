import pandas as pd
from nba_api.stats.endpoints import leaguedashplayerstats
import time

# Lista con las temporadas disponibles en nba_api
temporadas = [f"{y}-{str(y+1)[-2:]}" for y in range(1996, 2024)]

# Lista que contendrá los df de las temporadas
datos_por_temporada = []

for temporada in temporadas:
    print(f"Extrayendo temporada {temporada}")

    try:
        stats = leaguedashplayerstats.LeagueDashPlayerStats(
            season=temporada,
            season_type_all_star='Regular Season',
            per_mode_detailed = 'PerGame'
        )

        datos = stats.get_data_frames()[0]
        datos['SEASON'] = temporada
        datos_por_temporada.append(datos)

        time.sleep(10) # Pausa por 10 segundos entre la extracción de temporadas para evitar bloqueos de la NBA
    
    except Exception as e:
        print(f"Error en la extracción de la temporada {temporada}: {e}")
        continue

datos_totales = pd.concat(datos_por_temporada, ignore_index = True)

datos_totales.to_csv('nba_player_stats_by_season.csv', index = False)
print("Datos Extraídos con éxito ")
