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
library(wordcloud)
library(DT)
library(shiny)
library(shinythemes)
library(shinyWidgets)
library(data.table)

rm(list = ls())
load("chinafm_clean.RData")

allwords <- data.table(
  "Select one or more words below:" = sort(unique(text_en_df$word)))
allspoxes <- sort(unique(text_en_df$spox))
mindate <- min(display_en_df$Date, na.rm = TRUE)
maxdate <- max(display_en_df$Date, na.rm = TRUE)


## UI --------------------------------------------------------------------------

ui <- fluidPage(
  theme = shinytheme("journal"),

  titlePanel("China Foreign Ministry Spokesperson Remarks (English Translations)"),
  p("The source of these remarks can be found ",
    tags$a(href = "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/",
           "here"), "!"),
  p("Made by Clara Wang in July 2020."),
  p(str_glue("Includes statements from {format(mindate, '%B %d, %Y')} to {format(maxdate, '%B %d, %Y')}.")),

  wellPanel(
    h3("Filter Remarks"),
    p("Use the filters below to filter the remarks show in the table and wordcloud."),
    dateRangeInput("i_daterange",
                   label = "Filter Dates (yyyy-mm-dd)",
                   start = mindate,
                   end = maxdate,
                   min = mindate,
                   max = maxdate),
    selectizeInput("i_spox",
                   "Filter to selected spokespeople:",
                   choices = allspoxes,
                   multiple = TRUE,
                   selected = allspoxes),
    selectizeInput("i_filter",
                   label = "Filter to remarks that include these words:",
                   choices = NULL,
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
          plotOutput("wordcloud", width = "100%", height = "650px")
        )
      )
    )
  )
)


## SERVER ----------------------------------------------------------------------

server <- function(input, output, session) {

  ## --------------------------< reactive data > -------------------------------
  want_responses <- reactive({
    if (!is.null(input$i_filter)) {
      text_en_df %>%
        filter(word %in% input$i_filter) %>%
        pull(response_id) %>%
        unique()
    } else {
      text_en_df %>%
        pull(response_id) %>%
        unique()
    }
  })

  filtered_tab <- reactive({
    out <- display_en_df %>%
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
    out <- text_en_df %>%
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


  ## ---------------------------< reactive UI > --------------------------------
  updateSelectizeInput(
    session,
    "i_filter",
    choices = c(allwords),
    server = TRUE)


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

