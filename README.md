# NBA Player Value and Potential Analysis

This project presents a comprehensive data analysis of NBA players, from their collegiate careers to their performance in the professional league. The goal is to provide data-driven insights into player valuation, game archetypes, and career success prediction.

The project was developed as the final and capstone project for the **Data Analysis** subject of the **Bachelor's Degree in Mathematics** from the **University of Almería** and obtained a grade of **9.8** (out of 10).

This repository contains the full code and documentation for the analysis. The latter is divided into two main reports:

* **Client Report:** A high-level overview of the analysis, focusing on business insights and key findings.

* **Technical Report:** A detailed account of the methodology, models used, and technical results. As well as a full explanation of the code used.

However, this reports are in Spanish, as the project was developed for a Spanish-teached subject. This README file, contains the main conclusions and insights from the analysis, as well as a technical breakdown of the methods and technologies used. 

## 1. Project Summary

The NBA, with its rich history of data analytics, serves as an ideal environment for statistical exploration. This project addresses several key questions using a robust dataset compiled from various sources:

* **Salary and Player Value:** What game factors most influence a player's salary? How can we identify overvalued or undervalued players based on their on-court performance?

* **Player Archetypes:** How can we segment players into distinct game archetypes based on their individual statistics?

* **All-Star and Draft Prediction:** Can we predict which players will be selected for the All-Star Game? Can we predict the professional success of a college player in the NBA?

The analysis was performed using **Python** for data extraction and **R** for all data processing, modeling, and visualization.

## 2. Key Findinds & Key Insights

### 💲 NBA Salary Prediction – Key Findings

This section tackles the most challenging task: predicting NBA player salaries and understanding the game and statistical factors that influence them. Salaries are a complex interplay of performance and macroeconomic factors, including team budgets and market dynamics. In this analysis, we focus on the on-court performance metrics that can be quantified and modeled, by doing so, we aim to provide a clearer picture of player value and identify potential undervalued or overvalued players just based on their performance. 

This information can be crucial for teams to make informed decisions about player contracts and for players to understand their market value.

We use **XGBoost**, a powerful decision tree-based algorithm known for its accuracy and flexibility in regression tasks.

#### Data Preparation
- Salaries were adjusted for inflation to ensure comparability across seasons.
- A rigorous feature selection process was followed, excluding variables that introduced noise or multicollinearity (e.g., physical attributes, team performance metrics like plus-minus).
- Fantasy points were excluded due to their dominant influence and negative impact on model interpretability.
- Position, personal fouls, and similar variables were discarded for their low predictive value.
- Experience and All-Star status were included as categorical variables; season was treated as numeric for better performance.
- Outliers and non-active players were filtered out to ensure prediction reliability.

#### Model Performance
- **R²:** 0.754  
- **Adjusted RMSE:** \$4,067,611  
- **Adjusted MAE:** \$2,870,036  

The model explains ~75% of the salary variance—quite effective considering the complexity of salary determinants, which can be considered a success in the context of sports analytics taking into account the many external factors that influence player salaries. 

Although the MAE is around \$2.9 million, which is significant, we can take some predictions from our test set as examples of the model's performance and its ability to identify over- and undervalued players:


- Stephen Curry (2012–13 Season): The model predicts Curry’s salary with an error of just $81,066 against his actual $5.42 M contract—an astonishingly low 0.015 % error. This is one of the best cases of model accuracy.

- Zion Williamson (2022–23 Season): As a young player in his third year earning $14.4 M, the model misses by only $283,000 (0.020 %). This impressive precision holds even in the face of a major contract jump.

- Mike Conley (2017–18 Season): Conley earned $36.5 M, but the model predicts about $22.5 M—undershooting by $14 M. This large gap highlights an overinflated contract at the time; today his salary is $9 M, underscoring how the model can flag overvaluation.

- Jamal Crawford (2003–04 Season): Crawford made $4.4 M, yet the model forecasts around $11 M. Given his four years of experience and a 17 PPG average, he was arguably one of the league’s top point guards then. Indeed, his salary rose to $9 M the next year and matched the $11 M estimate two seasons later—an example of a player initially undervalued.

- Shaquille O’Neal (2008–09 Season): The model errs by $4.3 M on O’Neal’s $30.02 M salary—a seemingly large absolute error that nevertheless remains below a 15 % relative error, especially reasonable for an All-Star at the peak of his career.


**Most important features:** Experience, points per game, season, minutes played, rebounds, assists, and shooting accuracy.

Surprisingly, All-Star status had minimal weight, likely because performance stats indirectly capture that influence.


### 🏀 Player Archetypes – Key Findings

    

## 3. Technical Breakdown

### **Data & Methodology**

Data was scraped with Python `BeautifulSoup4` from various sources like HoopsHype or Wikipedia and using other tools like the NBA API and Stathead. The entire analysis was then performed in R, leveraging the following key techniques:

* **Data Wrangling:** Extensive data cleaning and joining of multiple datasets (player stats, salaries, college data) to create a unified and robust analytical base.

* **Exploratory Data Analysis (EDA):** Visual exploration of salary distributions, player metrics, and the relationship between collegiate performance and professional success in order to identify trends and patterns that can be useful for modeling.

* **Predictive Modeling:**

    * **Salary Prediction:** Used an **XGBoost** regression model to predict player salaries, allowing for the identification of over- and undervalued players.

    * **All-Star Prediction:** Employed a **Random Forest** classification model to predict All-Star selections, addressing the challenge of imbalanced data.

    * **Draft Success Prediction:** A **XGBoost** classification model was used to predict player success (defined as 5+ years in the league) based on their college statistics.

* **Clustering:** Applied PCA and then k-means clustering to segment players into different game archetypes based on their statistical profiles.

### **Reproducibility**

The project environment is managed using the `renv` package to ensure full reproducibility. To run the project locally, simply clone the repository and run `renv::restore()` to install the correct package versions.

For running the Python scripts, ensure you have the necessary libraries installed, located in the `requirements.txt`.

### **Project Structure**

* `src/`: Contains all the source code for the project.

    * `src/Python/`: Contains Python scripts for data extraction and scraping.

    * `src/R/`: Contains R scripts for data processing, analysis, and modeling.

* `reports/`: Contains the Spanish PDF versions of the reports.

    * `client_report.pdf`: A high-level report with key business insights and visualizations.

    * `technical_report.pdf`: A detailed technical report of the methodology, models, and results.

* `data/`: Contains the raw and processed datasets obtained after the extraction process.

* `outputs/`: Contains the output files generated by the analysis, including visualizations and model results.

