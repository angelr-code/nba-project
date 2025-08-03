import requests 
import time
import pandas as pd
from bs4 import BeautifulSoup


def salarios_hoops_hype(season):
    """
    Extracts NBA player salaries from Hoopshype for a given season.

    Parameters
    ----------
        season (str): The season in the format 'YYYY-YYYY'.
    
    Returns
    -------
        pd.DataFrame: A DataFrame containing player names, adjusted salaries, and the season.
    """
    # Example URL: https://hoopshype.com/salaries/players/2016-2017/
    url = f"https://hoopshype.com/salaries/players/{season}/"

    # Headers to mimic a browser request
    # This is important to avoid being blocked by the website
    headers = {
        "User-Agent": "Mozilla/5.0"
    }

    print(f"Extracting salaries for the {season} season.")
    res = requests.get(url, headers = headers) # Make the request to the URL
    soup = BeautifulSoup(res.text, "html.parser") # Parse the HTML content

    # Find the table containing the player salaries
    # The table is usually the first and only one on the page
    # The structure of the table mantains consistent across seasons
    table = soup.find("table")
    rows = table.find_all("tr")[1:]

    data = []
    for row in rows:
        columns = row.find_all("td")
        player = columns[1].get_text(strip = True)
        salary = columns[3].get_text(strip = True).replace("$", "").replace(",", "")

        try:
            salary = int(salary)
        except Exception:
            salary = None  # If the salary is not a valid integer, set it to None (missing data).

        data.append({
            "PLAYER": player,
            "ADJUSTED SALARY ($)": salary,
            "SEASON": season
        })

    return pd.DataFrame(data)

# Desired seasons
seasons = [f"{y}-{y+1}" for y in range(1996, 2024)]

salaries_seasons = []

for season in seasons:
    data = salarios_hoops_hype(season)
    salaries_seasons.append(data)
    time.sleep(10) # 10 seconds delay to avoid hitting the website too frequently

salaries = pd.concat(salaries_seasons, ignore_index= True)

salaries.to_csv('salarios_nba.csv', index = False)
print("Salaries extracted and saved to 'salarios_nba.csv'.")
