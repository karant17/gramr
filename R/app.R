
#--------------------------------
# Functions for the Shiny app

#' Parse RMarkdown documents
#' @param file a character vector of the file or path
#' @return used in the shiy app
#' @importFrom dplyr data_frame
#' @importFrom stringr str_detect
#' @importFrom purrr map
#' @examples
#' # don't run
#' # parse_rmd()
#' @export
parse_rmd <- function(file){
  text_df <- data_frame(
    text = readLines(file),
    is_code = FALSE
  )
  text_df$line_num <- 1:nrow(text_df)
  text_df$code_mark = str_detect(text_df$text, "^```") |
    str_detect(text_df$text, "---")
  text_df$is_code[text_df$code_mark] <- TRUE

  flip_flop <- TRUE
  for (i in seq_along(text_df$text)) {
    if (flip_flop) {
      text_df$is_code[i] <- TRUE
    }
    if (text_df$code_mark[i] && i > 1) {
      flip_flop <- !flip_flop
    }
  }

  text_df$grammar_check <- map(text_df$text, check_grammar)
  text_df
}




#' Start grammar checker shiny application
#' Start the grammar checker. This allows the user to
#' step through lines of text
#' which may have grammar errors, and then write the resulting file.
#' @param path the intended filepath
#' @return a shiny app is launched
#' @importFrom purrr map_lgl
#' @import shiny
#' @examples
#' # don't run during tests
#' # gramr::run_grammar_checker("example.rmd")
#' @export
run_grammar_checker <- function(path){
  text_df <- parse_rmd(path)
  check_df <- text_df[map_lgl(text_df$grammar_check, ~!is.null(.)), ]
  counter <- 1

  ui <- fluidPage(
    # Application title
    sidebarLayout(
      sidebarPanel(
        checkboxGroupInput(inputId = 'options',
                                  label = "Ignore",
                                  choiceNames = list("Passive Voice",
                                                     "Duplicate words (the the)",
                                                     "'So' at start of sentence",
                                                     "'There is/are; at start of sentence",
                                                     "Avoid weasel words",
                                                     "Wordiness",
                                                     "Problematic Adverbs",
                                                     "Cliches",
                                                     "Avoid 'Being' words"),
                                  choiceValues = list("passive", "illusion", "so", "thereIs","weasle",
                                                      "adverb", "toWordy", "cliches", "eprime")
        ),
        actionButton("do", "Next"),
        actionButton("exit", "Finish")
      ),
      mainPanel(
        textAreaInput(inputId  = 'text',
                             label  = 'Text to Check',
                             value  = check_df$text[1],
                             height = 300,
                             width = 500,
                             resize = "both"),
        verbatimTextOutput(outputId = "text")
      )
    )
  )

  server <- function(input, output, session) {
    output$text <- renderText({
      option_list <- lapply(input$options, function(x)FALSE)
      names(option_list) <- input$options
      out <- check_grammar(input$text, option_list)
      out <- paste(out, collapse = "\n")
      out
    })

    observeEvent(input$do, {
      if( counter < length(check_df)){
        text_df[ text_df$line_num == check_df$line_num[counter], "text"] <- input$text
        counter <<- counter + 1
        updateTextInput(session, "text", value = check_df$text[counter])
      }
    })

    observeEvent(input$exit, {
      text_df[ text_df$line_num == check_df$line_num[counter], "text"] <- input$text
      writeLines(text_df$text, path)
      stopApp()
    })
  }

  # Run the application
  shinyApp(ui = ui, server = server)
}
