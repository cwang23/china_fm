###########################################
## SHINY APP TO ANALYZE CHINA FM REMARKS
## Author(s): Clara Wang
## June 2020
###########################################

## SET UP ----------------------------------------------------------------------

# setwd("C:/Users/clara/Documents/china_fm/china_fm_app")
rm(list = ls())

library(readr)
library(tidyverse)
library(lubridate)
library(wordcloud)
library(DT)
library(shiny)
library(shinythemes)
library(shinyWidgets)
library(data.table)

options(encoding = "UTF-8")
load("chinafm_clean.RData")

allwords_en <- data.table(
  "Select one or more words below:" = sort(unique(text_en_df$word)))
allwords_ch <- data.table(
  "Select one or more characters below:" = sort(unique(text_ch_df$word)))
allspoxes <- sort(unique(text_en_df$spox))
mindate <- list("en" = min(display_en_df$Date, na.rm = TRUE),
                "ch" = min(display_ch_df$Date, na.rm = TRUE),
                "all" = min(display_df$Date, na.rm = TRUE))
maxdate <- list("en" = max(display_en_df$Date, na.rm = TRUE),
                "ch" = max(display_ch_df$Date, na.rm = TRUE),
                "all" = max(display_df$Date, na.rm = TRUE))


## UI --------------------------------------------------------------------------

ui <- fluidPage(
  theme = shinytheme("simplex"),

  titlePanel("China Foreign Ministry Spokesperson Statements"),
  p("The source of these statements can be found ",
    tags$a(href = "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/",
           "here in English"), " and ",
    tags$a(href = "https://www.fmprc.gov.cn/web/wjdt_674879/fyrbt_674889",
           "here in Chinese"), "!"),
  p("Made by Clara Wang in July 2020."),

  wellPanel(
    h3("Filter Statements"),
    p(tags$strong("Use the filters below to filter the statements shown in the table and wordcloud.")),
    p(str_glue("Includes statements from ",
               "{format(mindate$en, '%B %d, %Y')}",
               " to ",
               "{format(maxdate$en, '%B %d, %Y')} in English, and ",
               "from {format(mindate$ch, '%B %d, %Y')}",
               " to ",
               "{format(maxdate$ch, '%B %d, %Y')} in Chinese.")),
    dateRangeInput("i_daterange",
                   label = "Filter Dates (yyyy-mm-dd)",
                   start = maxdate$all,
                   end = maxdate$all,
                   min = mindate$all,
                   max = maxdate$all),
    selectizeInput("i_spox",
                   "Filter to selected spokespeople:",
                   choices = allspoxes,
                   multiple = TRUE,
                   selected = allspoxes),
    checkboxGroupInput("i_language",
                       label = "Show statements in the selected language(s):",
                       choices = c("English", "Chinese"),
                       selected = "English",
                       inline = TRUE),
    conditionalPanel(
      condition = "input.i_language.includes('English')",
      selectizeInput("i_filter_en",
                     label = "Filter to remarks that include these English words:",
                     choices = NULL,
                     multiple = TRUE,
                     selected = NULL)),
    conditionalPanel(
      condition = "input.i_language.includes('Chinese')",
      selectizeInput("i_filter_ch",
                     label = "Filter to remarks that include these Chinese characters:",
                     choices = NULL,
                     multiple = TRUE,
                     selected = NULL))
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
          # language selection
          radioGroupButtons(inputId = "i_language_wc",
                            label = "Select language for wordcloud:",
                            choices = c("English", "Chinese"),
                            status = "primary"),
          conditionalPanel(
            condition = "input.i_language_wc == 'English'",
            selectizeInput("i_remove_en",
                           label = "Remove these words from the cloud:",
                           choices = c(allwords_en),
                           multiple = TRUE,
                           selected = NULL)),
          conditionalPanel(
            condition = "input.i_language_wc == 'Chinese'",
            selectizeInput("i_remove_ch",
                           label = "Remove these characters from the cloud:",
                           choices = c(allwords_ch),
                           multiple = TRUE,
                           selected = NULL)),
          # update button
          actionButton("update_cloud", "Update Wordcloud")

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
  want_responses_en <- reactive({
    if (!is.null(input$i_filter_en)) {
      text_en_df %>%
        filter(word %in% input$i_filter_en) %>%
        pull(response_id_en) %>%
        unique()
    } else {
      text_en_df %>%
        pull(response_id_en) %>%
        unique()
    }
  })

  want_responses_ch <- reactive({
    if (!is.null(input$i_filter_ch)) {
      text_en_df %>%
        filter(word %in% input$i_filter_ch) %>%
        pull(response_id_ch) %>%
        unique()
    } else {
      text_en_df %>%
        pull(response_id_ch) %>%
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
    if (!is.null(input$i_filter_en)) {
      out <- out %>%
        filter(response_id_en %in% want_responses_en())
    }
    if (!is.null(input$i_filter_ch)) {
      out <- out %>%
        filter(response_id_ch %in% want_responses_ch())
    }

    # selected columns to show
    selectcols <- c("Date", "Spokesperson")
    if ("English" %in% input$i_language) {
      selectcols <- c(selectcols, "Title_en", "Source_en", "Content_en")
    }
    if ("Chinese" %in% input$i_language) {
      selectcols <- c(selectcols, "Title_ch", "Source_ch", "Content_ch")
    }
    return(out %>%
             select(all_of(selectcols)) %>%
             rename_with(~ gsub("_en", " (EN)", gsub("_ch", " (CH)", .x)))
    )
  })


  word_tab <- eventReactive(input$update_cloud, {
    if (input$i_language_wc == "English") {
      out <- text_en_df
    } else if (input$i_language_wc == "Chinese") {
      out <- text_ch_df
    }

    if (input$i_language_wc == "English") {
      toremove <- input$i_remove_en
    } else if (input$i_language_wc == "Chinese") {
      toremove <- input$i_remove_ch
    }

    out <- out %>%
      filter(date >= input$i_daterange[1]) %>%
      filter(date <= input$i_daterange[2])

    # filter out words to remove from wordcloud
    if (!is.null(input$i_remove_en) | !is.null(input$i_remove_ch)) {
      out <- out %>%
        filter(!word %in% toremove)
    }
    # filter to selected spox statements
    if (!is.null(input$i_spox)) {
      out <- out %>%
        filter(spox %in% input$i_spox)
    }
    # filter to statements only with selected words
    if (!is.null(input$i_filter_en)) {
      out <- out %>%
        filter(response_id_en %in% want_responses_en())
    }
    if (!is.null(input$i_filter_ch)) {
      out <- out %>%
        filter(response_id_ch %in% want_responses_ch())
    }
    out <- out %>%
      group_by(word) %>%
      summarise(freq = sum(freq, na.rm = TRUE), .groups = "drop") %>%
      mutate(word = enc2utf8(word))
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
    "i_filter_en",
    choices = c(allwords_en),
    server = TRUE)

  updateSelectizeInput(
    session,
    "i_filter_ch",
    choices = c(allwords_ch),
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

# tmp.enc <- options()$encoding
# options(encoding = "UTF-8")
# rsconnect::deployApp()
# options(encoding = tmp.enc)
