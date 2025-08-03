##### Exploratory Data Analysis #####

# Load necessary libraries
library(ggplot2)
library(ggExtra)
library(GGally)
library(tidyverse)
library(scales)
library(tidyr)
library(dplyr)
library(psych)
library(corrplot)
library(RColorBrewer)
library(fmsb)
library(tidygeocoder)
library(maps)
library(ggrepel)

# 1. Distribution and General Questions about the Data

# Define columns to exclude from the summary and correlation matrix
cols_to_exclude <- c("POSITION", "PLAYER_NAME", "PLAYER_ID", "SEASON", "TEAM_ABBREVIATION", 
                     "SCHOOL", "COUNTRY", "ALL_STAR")

# Display a summary of the numerical variables
summary(nba_data[, setdiff(names(nba_data), cols_to_exclude)])

# Calculate the correlation matrix for numerical variables
correlation_matrix <- cor(nba_data[, setdiff(names(nba_data), cols_to_exclude)], use = "complete.obs")

# Plot the correlation matrix
corrplot(correlation_matrix, 
         method = "color",
         type = "lower",
         col = colorRampPalette(brewer.pal(8, "RdBu"))(200),
         addCoef.col = "black", # Correlation values
         tl.col = "black",      # Label text color
         tl.cex = 0.8,          # Label text size
         number.cex = 0.55      # Correlation values size
)


# 2. SALARIES

# Plot the distribution of adjusted salaries
ggplot(nba_data, aes(x = SALARY)) +
  geom_histogram(
    bins = 60, 
    fill = "#408973", 
    color = "black", 
    alpha = 0.8) +
  labs(
    title = "Distribution of Adjusted NBA Salaries",
    x = "Inflation-Adjusted Salary (M$)",
    y = "Number of Players"
  ) +
  scale_x_continuous(labels = scales::dollar_format(prefix = "$", suffix = "M", scale = 1e-6)) +
  theme_minimal(base_size = 14) +
  theme(plot.title = element_text(hjust = 0.5, size = 25, face = "bold"),
        axis.title = element_text(face = "bold", size = 18),
        axis.text = element_text(size = 18))

# Plot the salary distribution by position using a boxplot
nba_data %>%
  filter(!is.na(POSITION), POSITION != "") %>%
  mutate(
    POSITION = recode(
      POSITION,
      "Guard" = "Guards",
      "Forward" = "Forwards",
      "Center" = "Center"
    )
  ) %>%
  ggplot(aes(x = POSITION, y = SALARY)) +
  geom_boxplot(
    fill = "#698bab",
    color = "black",
    outlier.colour = "red"
  ) +
  labs(
    title = "Salary Distribution by Position",
    x = "Position",
    y = "Adjusted Salary (M$)"
  ) +
  scale_y_continuous(
    labels = scales::dollar_format(prefix = "$", suffix = "M", scale = 1e-6)
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 25, face = "bold"),
    axis.title = element_text(face = "bold", size = 18),
    axis.text = element_text(size = 18)
  )

# Plot the relationship between experience and salary
exp_vs_salary <- ggplot(nba_data, aes(x = SEASON_EXP, y = SALARY)) + 
  geom_jitter(width = 0.3, alpha = 0.6, color = "#1f77b4", size = 2) +
  geom_smooth(method = "loess", formula = y ~ x, se = TRUE, color = "#2ca02c", fill = "#2ca02c", alpha = 0.5) +
  labs(
    title = "NBA Experience vs. Salary",
    x = "NBA Experience (Years)",
    y = "Annual Salary (M$)",
  ) +
  scale_y_continuous(labels = scales::dollar_format(prefix = "$", suffix = "M", scale = 1e-6)) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 25),
    axis.title = element_text(face = "bold", size = 18),
    axis.text = element_text(size = 18)
  )

# Add marginal boxplots to the experience vs. salary plot
exp_vs_salary <- ggMarginal(exp_vs_salary, type = "boxplot", fill = "#1f77b4", size = 4, alpha = 0.4)
exp_vs_salary

# Plot the relationship between key stats and salary
nba_long <- nba_data %>%
  select(SALARY, MIN, PTS, AST, REB) %>%
  pivot_longer(cols = -SALARY, names_to = "statistic", values_to = "value")

ggplot(nba_long, aes(x = value, y = SALARY)) + 
  geom_point(color = "#3f6280", alpha = 0.4) +
  geom_smooth(method = lm, se = FALSE, color = "darkorange") + 
  facet_wrap(~ statistic, scales = "free_x") +
  labs(title = "Relationship Between Key Stats and Adjusted Salary", y = "Salary", x = "") +
  scale_y_continuous(labels = scales::dollar_format(prefix = "$", suffix = "M", scale = 1e-6)) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 25),
    axis.title = element_text(face = "bold", size = 18),
    axis.text = element_text(size = 18),
    strip.text = element_text(size = 18, face = "bold")
  )

# Plot the top 25 salaries for the 2018-19 season
top25 <- nba_data %>%
  filter(SEASON == "2018-19") %>%
  arrange(desc(SALARY)) %>%
  slice(1:25)

ggplot(top25, aes(x = reorder(PLAYER_NAME, SALARY), y = SALARY, fill = NBA_FANTASY_PTS)) +
  geom_col() +
  coord_flip() +
  scale_fill_gradient(low = "#B3CDE3", high = "#08306B") +
  labs(
    title = "Top 25 NBA Salaries (2018-19) and NBA Fantasy Points",
    x = "Player", y = "Adjusted Salary ($M)",
    fill = "NBA Fantasy"
  ) +
  scale_y_continuous(labels = scales::dollar_format(prefix = "$", suffix = "M", scale = 1e-6)) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 25),
    axis.title = element_text(face = "bold", size = 18),
    axis.text = element_text(size = 18)
  )

# Plot the evolution of the average NBA salary over time
nba_data %>%
  mutate(SEASON = as.numeric(as.character(sub("-.*", "", SEASON)))) %>%
  group_by(SEASON) %>%
  summarise(avg_salary = mean(SALARY)) %>%
  
  ggplot(aes(x = SEASON, y = avg_salary)) +
  geom_line(color = "#2C3E50", size = 1) +
  geom_point(size = 2, color = "#2980B9", fill = "white", stroke = 1.2) +
  labs(
    title = "Evolution of Adjusted NBA Average Salary",
    x = "Season",
    y = "Average Salary (M$)"
  ) +
  scale_y_continuous(labels = scales::dollar_format(prefix = "$", suffix = "M", scale = 1e-6)) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 25),
    axis.title = element_text(face = "bold", size = 20),
    axis.text = element_text(size = 18)
  )


# ALL - STAR

# Filter out the 1998-99 season as it was shortened
nba_allstar <- subset(nba_data, nba_data$SEASON != "1998-99")

# Calculate True Shooting Percentage
nba_allstar$TS_PCT <- nba_allstar$PTS / (2 * (nba_allstar$FGA + 0.44 * nba_allstar$FTA)) * 100

# Define a vector to store a readable name for each statistic
stat_names <- c(
  PTS = "Points",
  REB = "Rebounds",
  AST = "Assists",
  MIN = "Minutes per Game",
  TOV = "Turnovers",
  TS_PCT = "True Shooting %"
)

# Plot boxplots to compare All-Star vs. Non-All-Star stats
nba_allstar %>%
  select(ALL_STAR, PTS, REB, AST, MIN, TOV, TS_PCT) %>%
  pivot_longer(cols = -ALL_STAR, names_to = "statistic", values_to = "value") %>%
  mutate(
    ALL_STAR = factor(ALL_STAR, levels = c(0, 1), labels = c("Non-All-Star", "All-Star")),
    statistic = factor(stat_names[statistic], levels = stat_names)
  ) %>%
  
  ggplot(aes(x = ALL_STAR, y = value, fill = ALL_STAR)) + 
  geom_boxplot(alpha = 0.7, outlier.shape = NA, color = "black") + 
  facet_wrap(~ statistic, scales = "free", ncol = 3) +
  labs(
    title = "Statistical Comparison: All-Star vs. Non-All-Star",
    x = "",
    y = ""
  ) + 
  scale_fill_manual(values = c("Non-All-Star" = "#bdbdbd", "All-Star" = "#d7191c")) + 
  theme_minimal() + 
  theme(
    legend.position = "none",
    strip.text = element_text(face = "bold", hjust = 0.5, size = 18),
    plot.title = element_text(hjust = 0.5, size = 25, face = "bold"),
    axis.text = element_text(size = 18)
  )

# Clean up temporary variable
rm(stat_names)

# Plot a pie chart of All-Star position distribution
nba_data %>%
  filter(ALL_STAR == 1, !is.na(POSITION), POSITION != "") %>%
  count(POSITION) %>%
  mutate(POSITION = recode(POSITION,
                           "Guard" = "Guards",
                           "Forward" = "Forwards",
                           "Center" = "Centers"
  ), 
  percentage = n / sum(n),
  label = paste0(POSITION, " (", round(percentage * 100), "%)")) %>%
  ggplot(aes(x = "", y = percentage, fill = POSITION)) +
  geom_col(width = 1, color = "white") + 
  coord_polar(theta = "y") + 
  geom_text(aes(label = label), position = position_stack(vjust = 0.5), size = 4) + 
  labs(title = "All-Star Position Distribution") + 
  theme_void() +
  theme(
    legend.position = "none",
    plot.title = element_text(hjust = 0.5, size = 25, face = "bold")  
  )


# PLAYER ARCHETYPES

# Select key stats for the radar chart
stats <- c("PTS", "AST", "REB", "BLK", "STL", "TOV", "FG_PCT", "FG3_PCT", "FT_PCT")

# Prepare data for the radar chart by position
radar_data <- nba_data %>%
  filter(POSITION %in% c("Guard", "Forward", "Center")) %>%
  group_by(POSITION) %>%
  summarise(across(all_of(stats), mean, na.rm = TRUE)) %>%
  mutate(POSITION = recode(POSITION,
                           "Guard" = "Guards",
                           "Forward" = "Forwards",
                           "Center" = "Centers")) %>% 
  as.data.frame()

# Define min and max values for the radar chart axes
min_values <- c(5, 0, 2, 0, 0, 0, 0.30, 0, 0.6)
max_values <- c(9.1, 3, 5.5, 0.88, 1, 1.5, 0.50, 0.35, 0.8)

# Define colors for the radar chart
border_colors <- c("blue", "forestgreen", "darkorange")
fill_colors <- adjustcolor(border_colors, alpha.f = 0.3)

# Combine min/max values with the data
radar_chart_data <- rbind(max_values, min_values, radar_data[, -1])
rownames(radar_chart_data) <- c("Max", "Min", radar_data$POSITION)


# Plot the radar chart
radarchart(
  radar_chart_data,
  axistype = 1,
  pcol = border_colors,
  pfcol = fill_colors,
  plwd = 2,
  plty = 1,
  cglcol = "grey70",
  cglty = 1,
  axislabcol = NA,
  cglwd = 0.8,
  vlcex = 1.5,
)

# Add a legend
legend("topright", legend = radar_data$POSITION,
       bty = "n", pch = 20, col = border_colors,
       text.col = "black", cex = 2, pt.cex = 2.5) 

# Summarize and visualize average stats per position with a bar chart
position_stats <- nba_data %>%
  filter(!is.na(POSITION) & POSITION != "") %>%
  group_by(POSITION) %>%
  summarise(
    points = mean(PTS, na.rm = TRUE),
    assists = mean(AST, na.rm = TRUE),
    rebounds = mean(REB, na.rm = TRUE),
    blocks = mean(BLK, na.rm = TRUE),
    steals = mean(STL, na.rm = TRUE),
    fg_pct = mean(FG_PCT, na.rm = TRUE),
    fg3_pct = mean(FG3_PCT, na.rm = TRUE),
    ft_pct = mean(FT_PCT, na.rm = TRUE)
  )

# Prepare data for plotting by converting to a long format
stats_long <- position_stats %>%
  pivot_longer(cols = c(points, assists, rebounds, blocks, steals, fg_pct, fg3_pct, ft_pct),
               names_to = "statistic",
               values_to = "value") %>%
  # Translate positions
  mutate(POSITION = case_when(
    POSITION == "Guard" ~ "Guards",
    POSITION == "Forward" ~ "Forwards", 
    POSITION == "Center" ~ "Centers",
    TRUE ~ POSITION
  )) %>%
  # Translate and improve statistic names
  mutate(statistic = case_when(
    statistic == "points" ~ "Points per Game",
    statistic == "assists" ~ "Assists per Game",
    statistic == "rebounds" ~ "Rebounds per Game", 
    statistic == "blocks" ~ "Blocks per Game",
    statistic == "steals" ~ "Steals per Game",
    statistic == "fg_pct" ~ "Field Goal %",
    statistic == "fg3_pct" ~ "Three-Point %",
    statistic == "ft_pct" ~ "Free Throw %",
    TRUE ~ statistic
  ))

# Create the bar chart with facets
ggplot(stats_long, aes(x = POSITION, y = value, fill = POSITION)) +
  geom_col(alpha = 0.8, width = 0.7) +
  facet_wrap(~statistic, scales = "free_y", ncol = 4) +
  labs(title = "Average Statistics by Position in the NBA",
       subtitle = "Detailed Comparison Between Guards, Forwards, and Centers",
       x = "",
       y = "",
       fill = "") +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 18),
    axis.text.y = element_text(size = 18),
    strip.text = element_text(size = 18, face = "bold"),
    plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 15, hjust = 0.5),
    legend.position = "bottom",
    axis.text = element_text(size = 15),
    legend.text = element_text(size = 18),
    panel.grid.minor = element_blank()
  ) +
  scale_fill_manual(values = c("Guards" = "#FF6B6B", 
                               "Forwards" = "#4ECDC4", 
                               "Centers" = "#45B7D1"))


# NCAA

# Summarize college data
colleges <- ncaa_exp %>%
  filter(!is.na(Draft.College), Draft.College != "", !is.na(Pick)) %>%
  group_by(Draft.College) %>%
  summarise(
    players = n(),
    avg_pick = round(mean(as.numeric(Pick), na.rm = TRUE))
  ) %>%
  arrange(players)

# The user's code had a manual removal of a row.
# colleges <- colleges[-6,] 

# Geocode college locations
college_coords <- colleges %>%
  mutate(query = paste(Draft.College, "University", "USA")) %>%
  geocode(address = query, method = "osm", lat = lat, long = lon)

# Prepare data for plotting on a map
map_df <- college_coords %>% 
  filter(!is.na(lat), players >= 5)

usa_map_data <- map_data("state")

# Plot the map of the USA with colleges
ggplot() +
  geom_polygon(data = usa_map_data, aes(x = long, y = lat, group = group),
               fill = "#f5f5f5", color = "white") +
  geom_point(data = map_df,
             aes(x = lon, y = lat, size = players, color = avg_pick),
             alpha = 0.8, stroke = 0.2) +
  geom_text_repel(
    data = map_df,
    aes(x = lon, y = lat, label = Draft.College),
    size = 4.5,
    max.overlaps = 10
  ) +
  scale_size_continuous(
    name = "Players Contributed",
    range = c(2, 12),
    guide = guide_legend(title.theme = element_text(size = 18), label.theme = element_text(size = 14))
  ) +
  scale_color_viridis_c(
    name = "Average Pick",
    direction = -1,
    guide = guide_colorbar(title.theme = element_text(size = 18), label.theme = element_text(size = 14))
  ) +
  coord_fixed(1.3) +
  theme_minimal() +
  labs(
    title = "Top NCAA Colleges Contributing Talent to the NBA",
    x = "",
    y = ""
  ) +
  theme(legend.position = "right",
        panel.grid = element_blank(),
        axis.text = element_blank(),
        axis.ticks = element_blank(),
        axis.title = element_blank(),
        plot.title = element_text(face = "bold", size = 25, hjust = 0.5),
        legend.text = element_text(size = 16)
  )

# Prepare data for career length by draft pick plot
draft_data <- ncaa_exp %>%
  filter(Draft.Year >= 2001 & Draft.Year <= 2003) %>%
  mutate(
    Pick = as.numeric(Pick),
    Round = ifelse(Pick <= 30, "First Round", "Second Round")
  )

# Plot career length by draft pick
ggplot(draft_data, aes(x = Pick, y = SEASON_EXP, color = Round)) +
  geom_point(alpha = 0.7, size = 2.5) +
  scale_x_continuous(breaks = seq(1, 60, by = 2)) +
  scale_color_manual(values = c("First Round" = "#1f77b4", "Second Round" = "#ff7f0e")) +
  labs(
    title = "Career Length by Draft Pick (2001-2003)",
    x = "Pick Number",
    y = "NBA Experience (Years)",
    color = "Draft Round"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5, size = 25),
    legend.position = "right",
    panel.grid = element_blank(),
    axis.title = element_text(size = 18),
    axis.text = element_text(size = 15),
    legend.title = element_text(size = 18),
    legend.text = element_text(size = 18)
  )

# Plot a pie chart of academic class distribution
ncaa_exp %>%
  filter(!is.na(Class), Class != "") %>%
  count(Class) %>%
  mutate(
    Class_full = recode(Class,
                        "FR" = "Freshman",
                        "SO" = "Sophomore",
                        "JR" = "Junior",
                        "SR" = "Senior",
                        .default = Class),
    percentage = n / sum(n),
    label = paste0(Class_full, " (", round(percentage * 100), "%)")
  ) %>%
  ggplot(aes(x = "", y = percentage, fill = Class_full)) +
  geom_col(width = 1, color = "white") +
  coord_polar(theta = "y") +
  geom_text(aes(label = label), position = position_stack(vjust = 0.5), size = 4.7) +
  scale_fill_brewer(palette = "Set2") + # Color palette
  labs(title = "Academic Class Distribution in the NBA Draft") +
  theme_void() +
  theme(
    legend.position = "none",
    plot.title = element_text(hjust = 0.5, size = 25, face = "bold")
  )

# Calculate average NBA experience per academic class
by_class <- ncaa_exp %>%
  group_by(Class) %>%
  summarise(avg_exp = mean(SEASON_EXP, na.rm = TRUE)) %>%
  as.data.frame()
