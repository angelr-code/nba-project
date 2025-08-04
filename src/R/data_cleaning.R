# Data cleaning and preprocessing for statistical analysis and modeling

# Load raw data from CSV files
common_data <- read.csv("data/raw/common_player_info.csv")
player_stats <- read.csv("data/raw/nba_player_stats_by_season.csv")
salaries <- read.csv("data/raw/salarios_nba_ajustados.csv")
all_star <- read.csv("data/raw/all_stars.csv")
ncaa <- read.csv("data/raw/ncaa.csv")

##### COMMON CLEANING FOR ALL TASKS #####

# Clean Player Statistics
# Define columns to be removed
cols_to_remove <- c("NICKNAME", "TEAM_ID")
rank_cols <- grep("_RANK$", names(player_stats), value = TRUE)
wnba_cols <- grep("^WNBA", names(player_stats), value = TRUE)
columns_to_delete <- c(cols_to_remove, rank_cols, wnba_cols)

# Remove the identified columns
player_stats <- player_stats[, setdiff(names(player_stats), columns_to_delete)]

# Clean up temporary variables
rm(columns_to_delete, rank_cols, wnba_cols, cols_to_remove) 

# Reorder columns to move 'SEASON' to the third position
player_stats <- player_stats[, c(names(player_stats)[1:2], "SEASON", names(player_stats)[3:(ncol(player_stats) - 1)])] 

# Save the cleaned data
save(player_stats, file = "data/processed/player_stats.Rdata")


# Clean Common Player Info
# Keep only players with 'Y' in GAMES_PLAYED_FLAG and NBA_FLAG
common_data <- subset(common_data, common_data$GAMES_PLAYED_FLAG == 'Y' & common_data$NBA_FLAG == 'Y')

# Define columns to be removed
cols_to_remove <- c("FIRST_NAME", "LAST_NAME", "DISPLAY_FI_LAST", "DISPLAY_LAST_COMMA_FIRST",
                    "PLAYER_SLUG", "BIRTHDATE", "LAST_AFFILIATION", "JERSEY", "PLAYERCODE",
                    "ROSTERSTATUS", "FROM_YEAR", "TO_YEAR")

flag_cols <- grep("_FLAG$", names(common_data), value = TRUE)
team_city_cols <- grep("^TEAM", names(common_data), value = TRUE)
draft_cols <- grep("^DRAFT", names(common_data), value = TRUE)

# Remove the identified columns
common_data <- common_data[, setdiff(names(common_data), c(cols_to_remove, team_city_cols, flag_cols, draft_cols))]

# Rename columns for clarity
names(common_data)[1] <- "PLAYER_ID"
names(common_data)[2] <- "PLAYER_NAME"

# Convert player height from feet-inches to meters
height_split <- strsplit(as.character(common_data$HEIGHT), "-")
feet <- as.numeric(sapply(height_split, `[`, 1))
inches <- as.numeric(sapply(height_split, `[`, 2))
common_data$HEIGHT <- round((feet * 0.3048) + (inches * 0.0254), 2) 

# Convert player weight from lbs to kgs
common_data$WEIGHT <- round(common_data$WEIGHT * 0.453592, 1) 

# Keep only the primary position
common_data$POSITION <- sub("-.*", "", common_data$POSITION) 

# Clean up temporary variables
rm(flag_cols, team_city_cols, draft_cols, height_split, feet, inches, cols_to_remove)

# Save the cleaned data
save(common_data, file = "data/processed/common_data.Rdata")


# Clean Salaries
# Rename columns
names(salaries)[1] <- "PLAYER_NAME" 
names(salaries)[2] <- "SALARY"

# Adjust the season format to match other datasets (e.g., "2000-01")
salaries$SEASON <- paste0(substr(salaries$SEASON, 1, 4), "-", substr(salaries$SEASON, 8, 9))

# Save the cleaned data
save(salaries, file = "data/processed/salaries.Rdata")


# Clean All-Star Data
# Add a flag to indicate All-Star status
all_star$ALL_STAR <- 1

# Rename column
names(all_star)[1] <- "PLAYER_NAME"

# Remove the 'CONFERENCE' column as it is not needed
all_star <- all_star[, setdiff(names(all_star), c("CONFERENCE"))]

# Adjust the season format to match other datasets (e.g., "2000-01")
years <- as.numeric(all_star$SEASON)
start_years <- as.character(years - 1)
years <- as.character(years)
all_star$SEASON <- paste0(start_years, "-", substr(years, 3, 4))

# Clean player names by removing extra text
all_star$PLAYER_NAME <- gsub("\\(C\\)|INJ|REP|ST|SPL|COVID|DNP|DND|\\d+$", "", all_star$PLAYER_NAME)

# Clean up temporary variables
rm(start_years, years)

# Save the cleaned data
save(all_star, file = "data/processed/all_star.Rdata")


# Clean NCAA Data
library(dplyr)

# Filter NCAA data based on Draft Year and Season
draft_year <- as.numeric(sub("-.*", "", ncaa$Season)) + 1
ncaa <- subset(ncaa, draft_year == ncaa$Draft.Year)

# Remove unnecessary columns
ncaa <- ncaa[, setdiff(names(ncaa), c("Team", "X.9999"))]

# Get common player info to link with NCAA data
columns_to_select <- c("PLAYER_NAME", "COUNTRY", "HEIGHT", "WEIGHT", "SEASON_EXP")
aux_data <- common_data[, columns_to_select]
names(aux_data)[1] <- "Player"

# Join NCAA data with NBA experience data
ncaa_exp <- left_join(ncaa, aux_data, by = c("Player"))
ncaa_exp <- subset(ncaa_exp, !is.na(ncaa_exp$SEASON_EXP))

# Clean up temporary variables
rm(columns_to_select, draft_year, aux_data)

# Save the cleaned data
save(ncaa_exp, file = "data/processed/ncaa.Rdata")


##### DATA MERGING FOR STATISTICAL MODELS #####

library(dplyr)

# Join player statistics with common data
nba_data <- left_join(player_stats, common_data[, setdiff(names(common_data), c("PLAYER_NAME"))], by = "PLAYER_ID")

# Join with salaries
nba_data <- left_join(nba_data, salaries, by = c("PLAYER_NAME", "SEASON"))

# Remove rows without salary information
nba_data <- nba_data[!is.na(nba_data$SALARY),]

# Join with All-Star data
nba_data <- left_join(nba_data, all_star, by = c("PLAYER_NAME", "SEASON"))

# Fill NA values in ALL_STAR with 0
nba_data$ALL_STAR[is.na(nba_data$ALL_STAR)] <- 0

# Reorder columns for better readability
nba_data <- nba_data[, c(names(nba_data)[1:4], c("SCHOOL", "COUNTRY", "HEIGHT", "WEIGHT", "SEASON_EXP", "POSITION", "SALARY", "ALL_STAR"), names(nba_data)[5:(ncol(nba_data) - 8)])]


# Recalculate experience for each season
# Ensure SEASON_START is correctly formatted
nba_data <- nba_data %>%
  mutate(SEASON_START = as.numeric(substr(SEASON, 1, 4)))

# 1. Players still in the league in 2023-24
players_2023 <- nba_data %>%
  group_by(PLAYER_NAME) %>%
  filter(max(SEASON_START) == 2023) %>%
  arrange(SEASON_START) %>%
  mutate(SEASON_EXP = row_number()) %>%
  ungroup()

# 2. The rest of the players
players_not_2023 <- nba_data %>%
  group_by(PLAYER_NAME) %>%
  filter(max(SEASON_START) != 2023) %>%
  arrange(desc(SEASON_START)) %>%
  mutate(SEASON_EXP = SEASON_EXP - row_number() + 1) %>%
  ungroup()

# 3. Combine the two groups
nba_data <- bind_rows(players_2023, players_not_2023)

# Order by season
nba_data <- nba_data %>%
  arrange(SEASON_START)

# Remove the temporary 'SEASON_START' column
nba_data <- nba_data[, -ncol(nba_data)] 

# Filter out rows with non-positive experience
nba_data <- nba_data %>%
  filter(SEASON_EXP > 0)

# Save the final merged dataset
save(nba_data, file = "data/processed/nba_data.Rdata")

