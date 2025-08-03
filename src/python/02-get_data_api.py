import time
import pandas as pd
from pathlib import Path 
from nba_api.stats.endpoints import commonplayerinfo

ROOT_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT_DIR / "data" / "raw" / "nba_player_stats_by_season.csv"
AUXILIARY_DATA_DIR = ROOT_DIR / "data" / "auxiliar" / "common_player_info_kaggle.csv"

player_stats = pd.read_csv(DATA_DIR)
kaggle_data = pd.read_csv(AUXILIARY_DATA_DIR)

"""
This script extracts player information from the NBA API for players not present in the Kaggle dataset, which works as an
auxiliary dataset for the project. Thus, it is not present in the raw or processed data directories and has its own auxiliar folder.

The use of the Kaggle dataset is to avoid making too many requests to the NBA API in a short period of time which can oversaturate
the API and lead to errors. 

The Kaggle dataset is NOT updated for 3 years (as of 2025), so it is necessary to extract the information
of the players that are not present in the Kaggle dataset to have a complete dataset with all the players in the NBA
combined with the stats dataset extracted in '01-get_data_api.py'.
"""

total_ids = player_stats['PLAYER_ID'].unique().tolist() # List of all player IDs in the stats dataset
available_players = kaggle_data['person_id'].unique().tolist() # List of player IDs already present in the Kaggle dataset

necessary_players = []

for id in total_ids:
    if id not in available_players:
        necessary_players.append(id)

necessary_info = []

for player in necessary_players:
    print(f"Extracting data for player ID: {player}")

    try:
        info = commonplayerinfo.CommonPlayerInfo(player_id = player)
        info = info.get_normalized_dict()
        necessary_info.append(info['CommonPlayerInfo'][0])

    except Exception as e:
        print(f"Error extracting data for player ID {player}: {e}")

    time.sleep(1.5) # To avoid hitting the API rate limit   
        
complementary_data = pd.DataFrame(necessary_info)

kaggle_data.columns = complementary_data.columns # To ensure both DataFrames have the same columns for concatenation
df = pd.concat([kaggle_data, complementary_data], ignore_index=True)

df.to_csv("common_player_info.csv", index= False) 

print("Data extraction completed. The combined dataset is saved as 'common_player_info.csv'.")