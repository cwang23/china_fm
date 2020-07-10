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
library(tmcn)
library(jiebaR)

rm(list = ls())
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
      url == "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/t1687014.shtml" ~
        as.Date("2019-08-07"),
      url == "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/t1686638.shtml" ~
        as.Date("2019-08-07"),
      TRUE ~ date)) %>%
  select(-tempdate)


## CLEAN ENGLISH DATA FOR APP --------------------------------------------------

# initial clean to group together questions and answers
clean_mfen_new <- clean_mfen %>%
  transmute(
    date, spox, type, title,
    "tokenprep" = content,
    "Content" = case_when(
      content_type == "Q" ~ str_glue("<strong>{content}</strong>"),
      TRUE ~ content),
    url,
    "grouping" = case_when(content_type == "Q" ~ content_order,
                           content_type == "A" ~ content_order - 1,
                           TRUE ~ content_order)) %>%
  arrange(date, grouping) %>%
  group_by(date, spox, type, url, title, grouping) %>%
  summarise(tokenprep = paste0(tokenprep, collapse = " "),
            Content = paste0(Content, collapse = "<br>"),
            .groups = "drop") %>%
  mutate(tokenprep = gsub("A:", "", tokenprep),
         tokenprep = gsub("Q:", "", tokenprep),
         tokenprep = gsub("<br>", " ", tokenprep),
         # get rid of weird apostrophes
         tokenprep = gsub("’", "'", tokenprep, perl = TRUE),
         Content = gsub("’", "'", Content, perl = TRUE),
         tokenprep = str_trim(tokenprep)) %>%
  filter(tokenprep != "") %>%
  arrange(date, grouping) %>%
  mutate(response_id = paste0("responseid_", 1:nrow(.)))


# clean the displayed table data
display_en_df <- clean_mfen_new %>%
  transmute(
    "Date" = date,
    "Spokesperson" = spox,
    "Title" = title,
    "Type of Remarks" = type,
    "Source" = str_glue("<a href='{url}'>English Source</a>"),
    Content,
    response_id)


# clean the text data
text_en_df <- clean_mfen_new %>%
  transmute(response_id, date, spox, type, tokenprep, url) %>%
  unnest_tokens(word, tokenprep) %>%
  # remove stop words and numbers
  anti_join(stop_words) %>%
  filter(!grepl("[0-9]", word)) %>%
  # get frequency of tokens
  group_by(date, spox, type, url, response_id, word) %>%
  summarise(freq = n(), .groups = "drop")


## CLEAN CHINESE DATA FOR APP --------------------------------------------------

# initial clean to group together questions and answers
clean_mfch_new <- clean_mfch %>%
  transmute(
    date, spox, type, title,
    "tokenprep" = content,
    "Content" = case_when(
      content_type == "Q" ~ str_glue("<strong>{content}</strong>"),
      TRUE ~ content),
    url,
    "grouping" = case_when(
      content_type == "Q" ~ content_order,
      content_type == "A" ~ content_order - 1,
      TRUE ~ content_order)) %>%
  arrange(date, grouping) %>%
  group_by(date, spox, type, url, title, grouping) %>%
  summarise(tokenprep = paste0(tokenprep, collapse = " "),
            Content = paste0(Content, collapse = "<br>"),
            .groups = "drop") %>%
  mutate(tokenprep = gsub("<br>", "", tokenprep)) %>%
  filter(tokenprep != "") %>%
  arrange(date, grouping) %>%
  mutate(response_id = paste0("responseid_", 1:nrow(.))) %>%
  select(-grouping)

# clean the displayed table data
display_ch_df <- clean_mfch_new %>%
  transmute(
    "Date" = date,
    "Spokesperson" = spox,
    "Title" = title,
    "Type of Remarks" = type,
    "Source" = str_glue("<a href='{url}'>Chinese Source</a>"),
    Content,
    response_id)

# tokenize Chinese text
ch_tokens <- purrr::map(
  clean_mfch_new$tokenprep, function(x) {segment(x, cutter)}) %>%
  setNames(clean_mfch_new$response_id) %>%
  enframe() %>%
  unnest(cols = c(name, value)) %>%
  rename("response_id" = name, "word" = value)

text_ch_df <- clean_mfch_new %>%
  left_join(ch_tokens) %>%
  select(-tokenprep) %>%
  # remove stop words, question and answer text
  filter(!word %in% c(STOPWORDS$word, "问", "答")) %>%
  # remove numbers
  filter(!grepl("[0-9]", word)) %>%
  group_by(date, spox, type, url, response_id, word) %>%
  summarise(freq = n(), .groups = "drop")


## COMBINE CHINESE ENGLISH DATA ------------------------------------------------

display_df <- display_ch_df %>%
  arrange(Date, Spokesperson) %>%
  group_by(Date, Spokesperson, Title, `Type of Remarks`, Source) %>%
  # create order for each Q/A in doc for joining
  mutate(order = 1:n()) %>%
  rename_with(~ paste0(., "_ch"), Title:response_id) %>%
  full_join(display_en_df %>%
              arrange(Date, Spokesperson) %>%
              group_by(Date, Spokesperson, Title, `Type of Remarks`, Source) %>%
              # create order for each Q/A in doc for joining
              mutate(order = 1:n()) %>%
              rename_with(~ paste0(., "_en"), Title:response_id)) %>%
  ungroup()


## WRITE DATA FOR APP ----------------------------------------------------------

save(display_df,
     display_ch_df,
     display_en_df,
     text_ch_df,
     text_en_df,
     file = "chinafm_clean.RData")

