import time
import pandas as pd
from nba_api.stats.endpoints import commonplayerinfo

estadisticas_jugadores = pd.read_csv(r"C:\Users\Ángel\Documents\nba-project\data\raw_data\nba_player_stats_by_season.csv")
datos_kaggle = pd.read_csv(r"C:\Users\Ángel\Documents\nba-project\common_player_info_kaggle.csv")

ids_totales = estadisticas_jugadores['PLAYER_ID'].unique().tolist()
jugadores_disponibles = datos_kaggle['person_id'].unique().tolist()

jugadores_necesarios = []

for id in ids_totales:
    if id not in jugadores_disponibles:
        jugadores_necesarios.append(id)

info_necesaria = []

for jugador in jugadores_necesarios:
    print(f"Extrayendo info de {jugador}")

    try:
        info = commonplayerinfo.CommonPlayerInfo(player_id = jugador)
        info = info.get_normalized_dict()
        info_necesaria.append(info['CommonPlayerInfo'][0])

    except Exception as e:
        print(f"Error con el jugador {jugador}: {e}")

    time.sleep(1.5)    
        
datos_restantes = pd.DataFrame(info_necesaria)
datos_kaggle.columns = datos_restantes.columns

df = pd.concat([datos_kaggle, datos_restantes], ignore_index=True)

df.to_csv("common_player_info.csv", index= False)