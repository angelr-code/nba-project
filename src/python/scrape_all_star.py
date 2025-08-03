import requests
import time 
import pandas as pd
from bs4 import BeautifulSoup

def all_star_roster_wiki(season):
    """
    Extracts the All-Star roster for a given season from Wikipedia.
    
    Parameters
    ----------
    season : int
        The season for which to extract the All-Star roster (e.g., 1997, 1998, ..., 2024).
    
    Returns
    -------
    pd.DataFrame
        A DataFrame containing the All-Star players, their conference, and the season.
    """


    # Example URL: https://en.wikipedia.org/wiki/1997_NBA_All-Star_Game#endnote_rep
    url = f"https://en.wikipedia.org/wiki/{season}_NBA_All-Star_Game#endnote_rep"

    # Headers to mimic a browser request
    # This is important to avoid being blocked by the website
    headers = {
        "User-Agent": "Mozilla/5.0"
    }

    # List to store player data
    data = []
    print(f"Extracting All-Star roster for season: {season}")
    res = requests.get(url, headers = headers) # Make the request to the URL
    soup = BeautifulSoup(res.text, "html.parser") # Parse the HTML content

    # Find the tables containing the All-Star rosters. Wikipedia table format is wikitable
    # The All-Star rosters are usually in the first two tables of the page
    # The first table is for the Eastern Conference and the second for the Western Conference

    tables = soup.find_all('table', {'class': 'wikitable'})
    
    special_format = [2006, 2007, 2008, 2009, 2010, 2011] # Special cases where the table format is slightly different. 
    
    # In season 1999, the All-Star Game was not played due to the lockout, so we skip it

    # Eastern Conference
    east_rows = tables[0].find_all('tr')[1:] # Skip the header row
    for row in east_rows:
        columns = row.find_all('td')
        if len(columns) >= 2 and season != 1999 and season not in special_format: 
            name = columns[1].get_text(strip = True)
            data.append({
                'PLAYER': name,
                'CONFERENCE': 'EAST',
                'SEASON': season,
            })
        
        if len(columns) >= 2 and season != 1999 and season in special_format:
            name = columns[0].get_text(strip = True)
            data.append({
                'PLAYER': name,
                'CONFERENCE': 'EAST',
                'SEASON': season,
            })

    # Western Conference
    west_rows = tables[1].find_all('tr')[1:]
    for row in west_rows:
        columns = row.find_all('td')
        if len(columns) >= 2 and season != 1999 and season not in special_format:
            name = columns[1].get_text(strip = True)
            data.append({
                'PLAYER': name,
                'CONFERENCE': 'WEST',
                'SEASON': season,
            })
        if len(columns) >= 2 and season != 1999 and season in special_format:
            name = columns[0].get_text(strip = True)
            data.append({
                'PLAYER': name,
                'CONFERENCE': 'WEST',
                'SEASON': season,
            })

    return pd.DataFrame(data)
            

# Desired seasons 
seasons = [y for y in range(1997, 2025)]

all_star_season = []

for season in seasons:
    datos = all_star_roster_wiki(season)
    all_star_season.append(datos)
    time.sleep(10) # 10 seconds delay to avoid hitting the website too frequently

all_stars = pd.concat(all_star_season, ignore_index= True)

all_stars.to_csv('all_stars.csv', index = False)
print("All-Star rosters extracted successfully and saved to 'all_stars.csv'.")
