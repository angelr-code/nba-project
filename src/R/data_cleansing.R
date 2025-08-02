# Limpieza y preprocesamiento de datos para análisis estadístico y modelado 

datos_comunes <- read.csv("data/raw_data/common_player_info.csv")
  
estadisticas <- read.csv("data/raw_data/nba_player_stats_by_season.csv")

salarios <- read.csv("data/raw_data/salarios_nba_ajustados.csv")

all_star <- read.csv("data/raw_data/all_stars.csv")

ncaa <- read.csv("data/raw_data/ncaa.csv")

##### Limpieza común a todas las tareas #####


# Limpieza de Estadísticas


cols <- c("NICKNAME", "TEAM_ID")

col_rankings <- grep("_RANK$", names(estadisticas), value = TRUE)

col_wnba <- grep("^WNBA", names(estadisticas), value = TRUE)

col_a_borrar <- c(cols, col_rankings, col_wnba)

estadisticas <- estadisticas[, setdiff(names(estadisticas), col_a_borrar)]

rm(col_a_borrar, col_rankings, col_wnba, cols) # limpia variables del entorno

estadisticas <- estadisticas[, c(names(estadisticas)[1:2],  "SEASON", names(estadisticas)[3:(ncol(estadisticas) - 1)])] # mueve la columna temporada

save(estadisticas, file = "data/processed_data/estadisticas.Rdata")


# Limpieza de datos comunes

datos_comunes <- subset(datos_comunes, datos_comunes$GAMES_PLAYED_FLAG == 'Y' & datos_comunes$NBA_FLAG == 'Y')

cols <- c("FIRST_NAME", "LAST_NAME", "DISPLAY_FI_LAST", "DISPLAY_LAST_COMMA_FIRST", 
          "PLAYER_SLUG", "BIRTHDATE", "LAST_AFFILIATION", "JERSEY", "PLAYERCODE",
          "ROSTERSTATUS", "FROM_YEAR", "TO_YEAR")

flags <- grep("_FLAG$", names(datos_comunes), value = TRUE)

col_ciudad <- grep("^TEAM", names(datos_comunes), value = TRUE)

draft <- grep("^DRAFT", names(datos_comunes), value = TRUE)

datos_comunes <- datos_comunes[, setdiff(names(datos_comunes), c(cols, col_ciudad, flags, draft))]

names(datos_comunes)[1] <- "PLAYER_ID"

names(datos_comunes)[2] <- "PLAYER_NAME"


altura_split <- strsplit(as.character(datos_comunes$HEIGHT), "-")
pies <- as.numeric(sapply(altura_split, `[`, 1))
pulgadas <- as.numeric(sapply(altura_split, `[`, 2))

datos_comunes$HEIGHT <- round((pies * 0.3048) + (pulgadas * 0.0254), 2) # Paso altura a metros

datos_comunes$WEIGHT <- round(datos_comunes$WEIGHT * 0.453592, 1) # lbs a kgs

datos_comunes$POSITION <- sub("-.*", "", datos_comunes$POSITION ) # Nos quedamos con la posición principal

rm(flags, col_ciudad, draft, altura_split, pies, pulgadas, cols)

save(datos_comunes, file = "data/processed_data/datos_comunes.Rdata")

# Limpieza salarios 

names(salarios)[1] <- "PLAYER_NAME" 

names(salarios)[2] <- "SALARY"

salarios$SEASON <- paste0(substr(salarios$SEASON, 1, 4), "-", substr(salarios$SEASON, 8, 9))

save(salarios, file = "data/processed_data/salarios.Rdata")

#Limpieza All star

all_star$ALL_STAR <- 1

names(all_star)[1] <- "PLAYER_NAME"

all_star <- all_star[, setdiff(names(all_star), c("CONFERENCE"))]

years <- as.numeric(all_star$SEASON)
start_years <- as.character(years - 1)
years <- as.character(years)

all_star$SEASON <- paste0(start_years, "-", substr(years, 3, 4))

all_star$PLAYER_NAME <- gsub("\\(C\\)|INJ|REP|ST|SPL|COVID|DNP|DND|\\d+$", "", all_star$PLAYER_NAME)

rm(start_years, years)

save(all_star, file = "data/processed_data/all_star.Rdata")


# Limpieza de datos universitarios

library(dplyr)

temporada <- as.numeric(sub("-.*", "", ncaa$Season)) + 1

ncaa <- subset(ncaa, temporada == ncaa$Draft.Year)

ncaa <- ncaa[, setdiff(names(ncaa), c("Team", "X.9999"))]

columnas <- c("PLAYER_NAME", "COUNTRY", "HEIGHT", "WEIGHT", "SEASON_EXP")

datos_aux <- datos_comunes[, columnas]

names(datos_aux)[1] <- "Player"

ncaa_exp <- left_join(ncaa, datos_aux, by = c("Player"))

ncaa_exp <- subset(ncaa_exp, !is.na(ncaa_exp$SEASON_EXP))

rm(columnas, temporada)

save(ncaa_exp, file = "data/processed_data/ncaa.Rdata")

##### Unión de datos para aplicar a modelos estadísticos #######


library(dplyr)

datos_nba <- left_join(estadisticas, datos_comunes[, setdiff(names(datos_comunes), c("PLAYER_NAME"))], by = "PLAYER_ID")

datos_nba <- left_join(datos_nba, salarios, by = c("PLAYER_NAME", "SEASON"))

datos_nba <- datos_nba[!is.na(datos_nba$SALARY),]

datos_nba <- left_join(datos_nba, all_star, by = c("PLAYER_NAME", "SEASON"))

datos_nba$ALL_STAR[is.na(datos_nba$ALL_STAR)] <- 0

datos_nba <- datos_nba[, c(names(datos_nba)[1:4], c("SCHOOL","COUNTRY","HEIGHT","WEIGHT","SEASON_EXP","POSITION","SALARY","ALL_STAR"), names(datos_nba)[5:(ncol(datos_nba) - 8)])]


# Calculamos la experiencia en cada temporada

# Aseguramos SEASON_START está bien
datos_nba <- datos_nba %>%
  mutate(SEASON_START = as.numeric(substr(SEASON, 1, 4)))

# 1. Jugadores que siguen en la liga en la 2023-24
jugadores_2023 <- datos_nba %>%
  group_by(PLAYER_NAME) %>%
  filter(max(SEASON_START) == 2023) %>%
  arrange(SEASON_START) %>%
  mutate(SEASON_EXP = row_number()) %>%
  ungroup()

# 2. Resto de jugadores
jugadores_no_2023 <- datos_nba %>%
  group_by(PLAYER_NAME) %>%
  filter(max(SEASON_START) != 2023) %>%
  arrange(desc(SEASON_START)) %>%
  mutate(SEASON_EXP = SEASON_EXP - row_number() + 1) %>%
  ungroup()

# 3. Unimos los dos grupos
datos_nba <- bind_rows(jugadores_2023, jugadores_no_2023)

datos_nba <- datos_nba %>%
  arrange(SEASON_START) #Ordenamos por temporada

datos_nba <- datos_nba[, -ncol(datos_nba)]# Eliminamos la variable SEASON_START

datos_nba <- datos_nba %>%
  filter(SEASON_EXP > 0)

save(datos_nba, file = "data/processed_data/nba_data.Rdata")
