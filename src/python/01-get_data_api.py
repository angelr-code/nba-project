import pandas as pd
from nba_api.stats.endpoints import leaguedashplayerstats
import time

# List with the seasons from 1996-97 to 2023-24 (available seasons in the NBA API)
seasons = [f"{y}-{str(y+1)[-2:]}" for y in range(1996, 2024)]

# List to store data for each season
data_per_season = []

for season in seasons:
    print(f"Extracting data for season: {season}")

    try:
        stats = leaguedashplayerstats.LeagueDashPlayerStats(
            season=season,
            season_type_all_star='Regular Season',
            per_mode_detailed = 'PerGame'
        )

        data = stats.get_data_frames()[0] # Get the first DataFrame from the response
        data['SEASON'] = season # Add season column
        data_per_season.append(data)

        time.sleep(10) # 10 seconds delay to avoid hitting API limits
    except Exception as e:
        print(f"Error extracting data for season {season}: {e}")
        continue

df = pd.concat(data_per_season, ignore_index = True) # Concatenate all dataframes into one
df.to_csv('nba_player_stats_by_season.csv', index = False)
print("Data extraction complete. Saved to 'nba_player_stats_by_season.csv'.")
