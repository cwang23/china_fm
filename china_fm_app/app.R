###########################################
## SHINY APP TO ANALYZE CHINA FM REMARKS
## Author(s): Clara Wang
## June 2020
###########################################


## SET UP ----------------------------------------------------------------------

# setwd("C:/Users/clara/Documents/china_fm/china_fm_app")

library(readr)
library(tidyverse)
library(lubridate)
library(tidytext)
library(wordcloud)
library(DT)
library(shiny)
library(shinythemes)
library(shinyWidgets)

# load scraped data
clean_mf <- read_csv("clean_mf.csv")

# load stop words
data(stop_words)

# clean the displayed table data
display_df <- clean_mf %>%
  transmute(
    "Date" = as_date(date, format = "%B %d, %Y"),
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
text_df <- clean_mf %>%
  transmute(
    "date" = as_date(date, format = "%B %d, %Y"),
    `spox`,
    `type`,
    `content`,
    `url`,
    "grouping" = case_when(content_type == "Q" ~ content_order,
                           content_type == "A" ~ content_order - 1,
                           TRUE ~ content_order)
  ) %>%
  group_by(date, spox, type, url, grouping) %>%
  summarise(content = paste0(content, collapse = " "), .groups = "drop") %>%
  mutate(content = gsub("A:", "", content),
         content = gsub("Q:", "", content)) %>%
  arrange(date, grouping) %>%
  mutate(response_id = paste0("responseid_", 1:nrow(.))) %>%
  select(-grouping) %>%
  unnest_tokens(word, content) %>%
  # remove stop words and numbers
  anti_join(stop_words) %>%
  filter(!grepl("[0-9]", word)) %>%
  # get frequency of tokens
  group_by(date, spox, type, url, response_id, word) %>%
  summarise(freq = n(), .groups = "drop")


allwords <- sort(unique(text_df$word))
mindate <- format(min(display_df$Date, na.rm = TRUE), "%B %d, %Y")
maxdate <- format(max(display_df$Date, na.rm = TRUE), "%B %d, %Y")


## UI --------------------------------------------------------------------------

ui <- fluidPage(
  theme = shinytheme("journal"),

  titlePanel("China Foreign Ministry Spokesperson Remarks (English Translations)"),
  p("The source of these remarks can be found ",
    tags$a(href = "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/",
           "here"), "!"),
  p("Made by Clara Wang in July 2020."),
  p(str_glue("Includes statements from {mindate} to {maxdate}.")),

  wellPanel(
    h3("Filter Remarks"),
    p("Use the filters below to filter the remarks show in the table and wordcloud."),
    dateRangeInput("i_daterange",
                   label = "Filter Dates (yyyy-mm-dd)",
                   start = min(display_df$Date, na.rm = TRUE),
                   end = max(display_df$Date, na.rm = TRUE),
                   min = min(display_df$Date, na.rm = TRUE),
                   max = max(display_df$Date, na.rm = TRUE)),
    uiOutput("i_spox"),
    selectizeInput("i_filter",
                   label = "Filter to remarks that include these words:",
                   choices = c("All words selected" = "", allwords),
                   multiple = TRUE,
                   selected = NULL)
  ),
  tabsetPanel(
    type = "tabs",
    tabPanel(
      h4("Database of Remarks"),
      wellPanel(
        h3("Remarks"),
        DTOutput("tbl")
      )
    ),

    tabPanel(
      h4("Text Analysis of Remarks"),
      sidebarLayout(
        sidebarPanel(
          h3("Word Cloud Settings"),
          sliderInput("i_freq",
                      "Only show words that have a frequency of at least:",
                      min = 1,  max = 50, value = 3),
          sliderInput("i_max",
                      "Show maximum this many words in the word cloud:",
                      min = 1,  max = 300,  value = 50),
          selectizeInput("i_remove",
                         label = "Words to remove from the cloud:",
                         choices = allwords,
                         multiple = TRUE),
          # update button
          actionButton("update_cloud", "Plot Wordcloud")

        ),
        mainPanel(
          plotOutput("wordcloud", width = "100%", height = "700px")
        )
      )
    )
  )

)

## SERVER ----------------------------------------------------------------------

server <- function(input, output) {

  ## ---------------------------< reactive UI > --------------------------------
  output$i_spox <- renderUI({
    spoxchoices <- display_df %>%
      filter(Date >= input$i_daterange[1]) %>%
      filter(Date <= input$i_daterange[2]) %>%
      pull(Spokesperson) %>%
      unique() %>%
      sort()

    selectizeInput("i_spox",
                   "Spokesperson",
                   choices = spoxchoices,
                   multiple = TRUE,
                   selected = spoxchoices)
  })


  ## --------------------------< reactive data > -------------------------------
  want_responses <- reactive({
    if (!is.null(input$i_filter)) {
      text_df %>%
        filter(word %in% input$i_filter) %>%
        pull(response_id) %>%
        unique()
    } else {
      text_df %>%
        pull(response_id) %>%
        unique()
    }


  })
  filtered_tab <- reactive({
    out <- display_df %>%
      filter(Date >= input$i_daterange[1]) %>%
      filter(Date <= input$i_daterange[2])

    if (!is.null(input$i_spox)) {
      out <- out %>%
        filter(Spokesperson %in% input$i_spox)
    }
    if (!is.null(input$i_filter)) {
      out <- out %>%
        filter(response_id %in% want_responses())
    }
    return(out %>% select(-response_id))
  })

  word_tab <- eventReactive(input$update_cloud, {
    out <- text_df %>%
      filter(date >= input$i_daterange[1]) %>%
      filter(date <= input$i_daterange[2])

    if (!is.null(input$i_spox)) {
      out <- out %>%
        filter(spox %in% input$i_spox)
    }
    if (!is.null(input$i_remove)) {
      out <- out %>%
        filter(!word %in% input$i_remove)
    }
    if (!is.null(input$i_filter)) {
      out <- out %>%
        filter(response_id %in% want_responses())
    }
    out <- out %>%
      group_by(word) %>%
      summarise(freq = sum(freq, na.rm = TRUE), .groups = "drop")
    return(out)
  })

  wordcloud_maxwords <- eventReactive(input$update_cloud, {
    input$i_max
  })

  wordcloud_minfreq <- eventReactive(input$update_cloud, {
    input$i_freq
  })


  ## -----------------------------< outputs > ----------------------------------

  output$tbl <- renderDT(
    datatable(filtered_tab(), escape = FALSE)
  )

  # make wordcloud repeatable in session
  wordcloud_rep <- repeatable(wordcloud)

  output$wordcloud <- renderPlot({
    wordcloud_rep(word_tab()$word, word_tab()$freq,
                  min.freq = wordcloud_minfreq(),
                  max.words = wordcloud_maxwords(),
                  random.order = FALSE,
                  colors = brewer.pal(8, "Dark2"))
  })
}

## RUN APP ---------------------------------------------------------------------

shinyApp(
  ui = ui,
  server = server
)

# rsconnect::deployApp()
#
# text_df %>%
#   filter(spox == "Geng Shuang") %>%
#   group_by(spox, word) %>%
#   summarise(freq = sum(freq, na.rm = TRUE), .groups = "drop") %>%
#   with(wordcloud(word, freq, max.words = 50, random.order = FALSE,
#                  colors = brewer.pal(8, "Dark2"),
#                  width = 8, height = 8, units = "in"))
