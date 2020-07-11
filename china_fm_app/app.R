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
library(wordcloud2)
library(DT)
library(shiny)
library(shinythemes)
library(shinyWidgets)
library(data.table)

#options(encoding = "UTF-8")
Sys.setlocale("LC_CTYPE", "chs") # if you use Chinese character
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

  titlePanel("China Foreign Ministry Spokesperson Statements |
              中华人民共和国外交部发言人的表态"),
  p("The source of these statements can be found ",
    tags$a(href = "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/",
           "here in English"), " and ",
    tags$a(href = "https://www.fmprc.gov.cn/web/wjdt_674879/fyrbt_674889",
           "here in Chinese"), "."),
  p("Made by ",
    tags$a(href = "https://www.linkedin.com/in/clarawang/",
           "Clara Wang"), " in July 2020."),

  wellPanel(
    h3("Filter Statements shown in the Table and Wordcloud:"),
    p(tags$strong("Includes statements from:"),
      tags$ul(
        tags$li(str_glue("{format(mindate$en, '%B %d, %Y')} to ",
                         "{format(maxdate$en, '%B %d, %Y')} in English")),
        tags$li(str_glue("{format(mindate$ch, '%B %d, %Y')} to ",
                         "{format(maxdate$ch, '%B %d, %Y')} in Chinese")))),
    dateRangeInput("i_daterange",
                   label = tags$strong("Filter to statements made within this time period (yyyy-mm-dd):"),
                   start = maxdate$all,
                   end = maxdate$all,
                   min = mindate$all,
                   max = maxdate$all),
    selectizeInput("i_spox",
                   tags$strong("Filter to selected spokespeople:"),
                   choices = allspoxes,
                   multiple = TRUE,
                   selected = allspoxes),
    checkboxGroupInput("i_language",
                       tags$strong("Show statements in the selected language(s):"),
                       choices = c("English", "Chinese"),
                       selected = "English",
                       inline = TRUE),
    conditionalPanel(
      condition = "input.i_language.includes('English')",
      selectizeInput("i_filter_en",
                     tags$strong("Filter to statements that include these English words:"),
                     choices = NULL,
                     multiple = TRUE,
                     selected = NULL)),
    conditionalPanel(
      condition = "input.i_language.includes('Chinese')",
      selectizeInput("i_filter_ch",
                     tags$strong("Filter to statements that include these Chinese characters:"),
                     choices = NULL,
                     multiple = TRUE,
                     selected = NULL))
  ),
  tabsetPanel(
    type = "tabs",
    tabPanel(
      h4("Database of Statements"),
      wellPanel(
        h3("Remarks"),
        DTOutput("tbl")
      )
    ),

    tabPanel(
      h4("Wordcloud of Statements"),
      sidebarLayout(
        sidebarPanel(
          h3("Word Cloud Settings"),
          p("Words shown in the wordcloud are limited to the statements ",
            "selected based on the filtering above. Note that if you filter ",
            "the statements based on words/characters, the wordcloud will ",
            "show words from statements filtered based on the corresponding ",
            "language."),
          p("So, if you filter statements based on English words ",
            "and plot the wordcloud in Chinese, the word filters will not apply. ",
            "For this example, the English word filters will only apply if ",
            "you plot the wordcloud in English."),
          sliderInput("i_freq",
                      tags$strong("Only show words that have a frequency of at least:"),
                      min = 1,  max = 50, value = 3),
          sliderInput("i_max",
                      tags$strong("Show maximum this many words in the word cloud:"),
                      min = 1,  max = 300,  value = 50),
          # language selection
          radioGroupButtons(inputId = "i_language_wc",
                            label = tags$strong("Select language for wordcloud:"),
                            choices = c("English", "Chinese"),
                            status = "primary"),
          conditionalPanel(
            condition = "input.i_language_wc == 'English'",
            selectizeInput("i_remove_en",
                           label = tags$strong("Remove these words from the wordcloud:"),
                           choices = c(allwords_en),
                           multiple = TRUE,
                           selected = NULL)),
          conditionalPanel(
            condition = "input.i_language_wc == 'Chinese'",
            selectizeInput("i_remove_ch",
                           label = tags$strong("Remove these characters from the wordcloud:"),
                           choices = c(allwords_ch),
                           multiple = TRUE,
                           selected = NULL)),
          # update button
          actionButton("update_cloud", "Update Wordcloud")

        ),
        mainPanel(
          wordcloud2Output("wordcloud", width = "100%", height = "650px")
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
        pull(response_id) %>%
        unique()
    } else {
      text_en_df %>%
        pull(response_id) %>%
        unique()
    }
  })

  want_responses_ch <- reactive({
    if (!is.null(input$i_filter_ch)) {
      text_ch_df %>%
        filter(word %in% input$i_filter_ch) %>%
        pull(response_id) %>%
        unique()
    } else {
      text_ch_df %>%
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


  wordcloud_maxwords <- eventReactive(input$update_cloud, {
    input$i_max
  })

  wordcloud_minfreq <- eventReactive(input$update_cloud, {
    input$i_freq
  })



  word_tab <- eventReactive(input$update_cloud, {
    # select the correct information based on language selection
    if (input$i_language_wc == "English") {
      out <- text_en_df
      toremove <- input$i_remove_en
      filtercriteria <- input$i_filter_en
      want_responseids <- want_responses_en()
    } else if (input$i_language_wc == "Chinese") {
      out <- text_ch_df
      toremove <- input$i_remove_ch
      filtercriteria <- input$i_filter_ch
      want_responseids <- want_responses_ch()
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
    if (!is.null(filtercriteria)) {
      out <- out %>%
        filter(response_id %in% want_responseids)
    }
    out <- out %>%
      group_by(word) %>%
      summarise(freq = sum(freq, na.rm = TRUE), .groups = "drop") %>%
      mutate(word = enc2utf8(word)) %>%
      filter(freq >= wordcloud_minfreq()) %>%
      arrange(desc(freq))
    return(out[1:wordcloud_maxwords(), ])
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


  output$wordcloud <- renderWordcloud2({
    wordcloud2(select(word_tab(), "word", "freq"))
  })

  # make wordcloud repeatable in session
  # wordcloud_rep <- repeatable(wordcloud)
  #
  # output$wordcloud <- renderPlot({
  #   wordcloud_rep(word_tab()$word, word_tab()$freq,
  #                 min.freq = wordcloud_minfreq(),
  #                 max.words = wordcloud_maxwords(),
  #                 random.order = FALSE,
  #                 colors = brewer.pal(8, "Dark2"))
  # })
}


## RUN APP ---------------------------------------------------------------------

shinyApp(
  ui = ui,
  server = server
)

