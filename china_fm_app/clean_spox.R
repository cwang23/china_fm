###########################################
## DATA CLEANING OF FP SPOX FOR SHINY APP
## Author(s): Clara Wang
## July 2020
###########################################

# jiebaR vignette
# https://cran.jeroenooms.com/web/packages/jiebaR/vignettes/Quick_Start_Guide.html

## SET UP ----------------------------------------------------------------------

setwd("C:/Users/clara/Documents/china_fm/china_fm_app")

library(readr)
library(tidyverse)
library(lubridate)
library(tidytext)
# library(tm)
# library(tmcn)
library(jiebaR)

# load scraped data
clean_mfch <- read_csv("clean_mf_ch.csv")
clean_mfen <- read_csv("clean_mf_en.csv")

# load stop words
data(stop_words)  # English stop words
data(STOPWORDS)   # simplified Chinese stop words

# initialize worker using default settings
cutter = worker()


## INITIAL CLEAN OF DATES ------------------------------------------------------

clean_mfen <- clean_mfen %>%
  mutate(
    tempdate = ifelse(
      # find the September 2018 entries that are missing dates
      !grepl("20\\d\\d$", title) & grepl("September", title),
      paste0(str_extract(title, "September.*$"), ", 2018"),
      NA)) %>%
  mutate(
    date = case_when(
      !is.na(tempdate) ~ as_date(tempdate, format = "%B %d, %Y"),
      # two statement by Hua Chunying missing dates
      url == "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/t1687014.shtml" ~ as.Date("2019-08-07"),
      url == "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/t1686638.shtml" ~ as.Date("2019-08-07"),
      TRUE ~ date)) %>%
  select(-tempdate)



## CLEAN ENGLISH DATA FOR APP --------------------------------------------------

# clean the displayed table data
display_en_df <- clean_mfen %>%
  transmute(
    "Date" = date,
    "Spokesperson" = spox,
    "Type of Remarks" = type,
    "Content" = case_when(content_type == "Q" ~ str_glue("<strong>{content}</strong>"),
                          TRUE ~ content),
    "Source" = str_glue("<a href='{url}'>URL</a>"),
    "grouping" = case_when(content_type == "Q" ~ content_order,
                           content_type == "A" ~ content_order - 1,
                           TRUE ~ content_order)
  ) %>%
  arrange(Date, grouping) %>%
  group_by(Date, Spokesperson, `Type of Remarks`, Source, grouping) %>%
  summarise(Content = paste0(Content, collapse = "<br>"), .groups = "drop") %>%
  #  arrange(Date, grouping) %>%
  mutate(response_id = paste0("responseid_", 1:nrow(.))) %>%
  select(-grouping)


# clean the text data
text_en_df <- clean_mfen %>%
  transmute(
    date, spox, type, content, url,
    "grouping" = case_when(content_type == "Q" ~ content_order,
                           content_type == "A" ~ content_order - 1,
                           TRUE ~ content_order)) %>%
  group_by(date, spox, type, url, grouping) %>%
  summarise(content = paste0(content, collapse = " "), .groups = "drop") %>%
  mutate(content = gsub("A:", "", content),
         content = gsub("Q:", "", content)) %>%
  arrange(date, grouping) %>%
  mutate(response_id = paste0("responseid_", 1:nrow(.))) %>%
  select(-grouping) %>%
  mutate(tokens = list(segment(content, cutter))) #%>%
  #unnest(tokens)

  unnest_tokens(word, content) %>%
  # remove stop words and numbers
  anti_join(stop_words) %>%
  filter(!grepl("[0-9]", word)) %>%
  # get frequency of tokens
  group_by(date, spox, type, url, response_id, word) %>%
  summarise(freq = n(), .groups = "drop")


## CLEAN CHINESE DATA FOR APP --------------------------------------------------

# clean the displayed table data
display_ch_df <- clean_mfch %>%
  transmute(
    "Date" = date,
    "Spokesperson" = spox,
    "Type of Remarks" = type,
    "Content" = case_when(content_type == "Q" ~ str_glue("<strong>{content}</strong>"),
                          TRUE ~ content),
    "Source" = str_glue("<a href='{url}'>URL</a>"),
    "grouping" = case_when(content_type == "Q" ~ content_order,
                           content_type == "A" ~ content_order - 1,
                           TRUE ~ content_order)
  ) %>%
  arrange(Date, grouping) %>%
  group_by(Date, Spokesperson, `Type of Remarks`, Source, grouping) %>%
  summarise(Content = paste0(Content, collapse = "<br>"), .groups = "drop") %>%
  #  arrange(Date, grouping) %>%
  mutate(response_id = paste0("responseid_", 1:nrow(.))) %>%
  select(-grouping)


# clean the text data
text_ch_df <- clean_mfch %>%
  transmute(
    date, spox, type, content, url,
    "grouping" = case_when(content_type == "Q" ~ content_order,
                           content_type == "A" ~ content_order - 1,
                           TRUE ~ content_order)) %>%
  group_by(date, spox, type, url, grouping) %>%
  summarise(content = paste0(content, collapse = " "), .groups = "drop") %>%
  mutate(content = gsub("答：", "", content),
         content = gsub("问：", "", content)) %>%
  arrange(date, grouping) %>%
  mutate(response_id = paste0("responseid_", 1:nrow(.))) %>%
  select(-grouping) %>%

  unnest_tokens(word, content) %>%
  # remove stop words and numbers
  anti_join(STOPWORDS) %>%
  filter(!grepl("[0-9]", word)) %>%
  # get frequency of tokens
  group_by(date, spox, type, url, response_id, word) %>%
  summarise(freq = n(), .groups = "drop")


