#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
require (shinyFiles)

#setwd("analysis")
##multidimensional analysis:
library (randomForest)
library (ica)
library (e1071) #svm
require(Hmisc)   #binomial confidence 

library(osfr) ##access to osf

#normal libraries:
library (tidyverse)
library (stringr)
#for plotting
library(gridExtra)
library(RGraphics)
source ("Rcode/functions.r")
source= function (file, local = TRUE, echo = verbose, print.eval = echo, 
          exprs, spaced = use_file, verbose = getOption("verbose"), 
          prompt.echo = getOption("prompt"), max.deparse.length = 150, 
          width.cutoff = 60L, deparseCtrl = "showAttributes", chdir = FALSE, 
          encoding = getOption("encoding"), continue.echo = getOption("continue"), 
          skip.echo = 0, keep.source = getOption("keep.source")) 
{
  envir <- if (isTRUE(local)) 
    parent.frame()
  else if (identical(local, FALSE)) 
    .GlobalEnv
  else if (is.environment(local)) 
    local
  else stop("'local' must be TRUE, FALSE or an environment")
  if (!missing(echo)) {
    if (!is.logical(echo)) 
      stop("'echo' must be logical")
    if (!echo && verbose) {
      warning("'verbose' is TRUE, 'echo' not; ... coercing 'echo <- TRUE'")
      echo <- TRUE
    }
  }
  if (verbose) {
    cat("'envir' chosen:")
    print(envir)
  }
  if (use_file <- missing(exprs)) {
    ofile <- file
    from_file <- FALSE
    srcfile <- NULL
    if (is.character(file)) {
      have_encoding <- !missing(encoding) && encoding != 
        "unknown"
      if (identical(encoding, "unknown")) {
        enc <- utils::localeToCharset()
        encoding <- enc[length(enc)]
      }
      else enc <- encoding
      if (length(enc) > 1L) {
        encoding <- NA
        owarn <- options(warn = 2)
        for (e in enc) {
          if (is.na(e)) 
            next
          zz <- file(file, encoding = e)
          res <- tryCatch(readLines(zz, warn = FALSE), 
                          error = identity)
          close(zz)
          if (!inherits(res, "error")) {
            encoding <- e
            break
          }
        }
        options(owarn)
      }
      if (is.na(encoding)) 
        stop("unable to find a plausible encoding")
      if (verbose) 
        cat(gettextf("encoding = \"%s\" chosen", encoding), 
            "\n", sep = "")
      if (file == "") {
        file <- stdin()
        srcfile <- "<stdin>"
      }
      else {
        filename <- file
        file <- file(filename, "r", encoding = encoding)
        on.exit(close(file))
        if (isTRUE(keep.source)) {
          lines <- readLines(file, warn = FALSE)
          on.exit()
          close(file)
          srcfile <- srcfilecopy(filename, lines, file.mtime(filename)[1], 
                                 isFile = TRUE)
        }
        else {
          from_file <- TRUE
          srcfile <- filename
        }
        loc <- utils::localeToCharset()[1L]
        encoding <- if (have_encoding) 
          switch(loc, `UTF-8` = "UTF-8", `ISO8859-1` = "latin1", 
                 "unknown")
        else "unknown"
      }
    }
    else {
      lines <- readLines(file, warn = FALSE)
      srcfile <- if (isTRUE(keep.source)) 
        srcfilecopy(deparse(substitute(file)), lines)
      else deparse(substitute(file))
    }
    exprs <- if (!from_file) {
      if (length(lines)) 
        .Internal(parse(stdin(), n = -1, lines, "?", 
                        srcfile, encoding))
      else expression()
    }
    else .Internal(parse(file, n = -1, NULL, "?", srcfile, 
                         encoding))
    on.exit()
    if (from_file) 
      close(file)
    if (verbose) 
      cat("--> parsed", length(exprs), "expressions; now eval(.)ing them:\n")
    if (chdir) {
      if (is.character(ofile)) {
        if (grepl("^(ftp|http|file)://", ofile)) 
          warning("'chdir = TRUE' makes no sense for a URL")
        else if ((path <- dirname(ofile)) != ".") {
          owd <- getwd()
          if (is.null(owd)) 
            stop("cannot 'chdir' as current directory is unknown")
          on.exit(setwd(owd), add = TRUE)
          setwd(path)
        }
      }
      else {
        warning("'chdir = TRUE' makes no sense for a connection")
      }
    }
  }
  else {
    if (!missing(file)) 
      stop("specify either 'file' or 'exprs' but not both")
    if (!is.expression(exprs)) 
      exprs <- as.expression(exprs)
  }
  Ne <- length(exprs)
  if (echo) {
    sd <- "\""
    nos <- "[^\"]*"
    oddsd <- paste0("^", nos, sd, "(", nos, sd, nos, sd, 
                    ")*", nos, "$")
    trySrcLines <- function(srcfile, showfrom, showto) {
      tryCatch(suppressWarnings(getSrcLines(srcfile, showfrom, 
                                            showto)), error = function(e) character())
    }
  }
  yy <- NULL
  lastshown <- 0
  srcrefs <- attr(exprs, "srcref")
  if (verbose && !is.null(srcrefs)) {
    cat("has srcrefs:\n")
    utils::str(srcrefs)
  }
  for (i in seq_len(Ne + echo)) {
    tail <- i > Ne
    if (!tail) {
      if (verbose) 
        cat("\n>>>> eval(expression_nr.", i, ")\n\t\t =================\n")
      ei <- exprs[i]
    }
    if (echo) {
      nd <- 0
      srcref <- if (tail) 
        attr(exprs, "wholeSrcref")
      else if (i <= length(srcrefs)) 
        srcrefs[[i]]
      if (!is.null(srcref)) {
        if (i == 1) 
          lastshown <- min(skip.echo, srcref[3L] - 1)
        if (lastshown < srcref[3L]) {
          srcfile <- attr(srcref, "srcfile")
          dep <- trySrcLines(srcfile, lastshown + 1, 
                             srcref[3L])
          if (length(dep)) {
            leading <- if (tail) 
              length(dep)
            else srcref[1L] - lastshown
            lastshown <- srcref[3L]
            while (length(dep) && grepl("^[[:blank:]]*$", 
                                        dep[1L])) {
              dep <- dep[-1L]
              leading <- leading - 1L
            }
            dep <- paste0(rep.int(c(prompt.echo, continue.echo), 
                                  c(leading, length(dep) - leading)), dep, 
                          collapse = "\n")
            nd <- nchar(dep, "c")
          }
          else srcref <- NULL
        }
      }
      if (is.null(srcref)) {
        if (!tail) {
          dep <- substr(paste(deparse(ei, width.cutoff = width.cutoff, 
                                      control = deparseCtrl), collapse = "\n"), 
                        12L, 1000000L)
          dep <- paste0(prompt.echo, gsub("\n", paste0("\n", 
                                                       continue.echo), dep))
          nd <- nchar(dep, "c") - 1L
        }
      }
      if (nd) {
        do.trunc <- nd > max.deparse.length
        dep <- substr(dep, 1L, if (do.trunc) 
          max.deparse.length
          else nd)
        cat(if (spaced) 
          "\n", dep, if (do.trunc) 
            paste(if (grepl(sd, dep) && grepl(oddsd, dep)) 
              " ...\" ..."
              else " ....", "[TRUNCATED] "), "\n", sep = "")
      }
    }
    if (!tail) {
      yy <- withVisible(eval(ei, envir))
      i.symbol <- mode(ei[[1L]]) == "name"
      if (!i.symbol) {
        curr.fun <- ei[[1L]][[1L]]
        if (verbose) {
          cat("curr.fun:")
          utils::str(curr.fun)
        }
      }
      if (verbose >= 2) {
        cat(".... mode(ei[[1L]])=", mode(ei[[1L]]), "; paste(curr.fun)=")
        utils::str(paste(curr.fun))
      }
      if (print.eval && yy$visible) {
        if (isS4(yy$value)) 
          methods::show(yy$value)
        else print(yy$value)
      }
      if (verbose) 
        cat(" .. after ", sQuote(deparse(ei, control = unique(c(deparseCtrl, 
                                                                "useSource")))), "\n", sep = "")
    }
  }
  invisible(yy)
}


PMeta = osfr::path_file("myxcv")
Projects_metadata <- read_csv(PMeta)



# Define UI for application that draws a histogram
ui <- fluidPage(
   
   # Application title
   titlePanel("Analyse your home cage monitoring data. https://github.com/jcolomb/HCS_analysis"),
   
   # Sidebar with a slider input for number of bins 
   sidebarLayout(
      sidebarPanel(
         sliderInput("Npermutation",
                     "Number of permutations to perform for the statistics:",
                     min = 1,
                     max = 1000,
                     value = 240)
         , checkboxInput('RECREATEMINFILE', 'recreate the min_file even if one exists', FALSE)
         , radioButtons('groupingby', 'grouping variables following which categories',
                      c('Jhuang 10 categories'='MITsoft',
                        'Berlin 18 categories'='AOCF'),
                      'MITsoft')
         , shinyUI(bootstrapPage(shinyDirButton('STICK', "Data_directory", 
                          "Choose the directory containing all your HCS data (works only while running the app via Rstudio on your computer):")
      ))),
      
      # Show a plot of the generated distribution
      mainPanel(
        selectInput('Name_project', 'choose the project to analyse:',
                        Projects_metadata$Proj_name ,
                        'test_online')
        ,actionButton("goButton", "Go!")
        
        ,htmlOutput("includeHTML")
        , textOutput("test")
        
        
        
      )
   )
)

# Define server logic required to draw a histogram
server <- function(input, output, session) {
  volumes= getVolumes(c("(C:)"))
  values <- reactiveValues()
  values$Outputshtml <- "reports/empty.html"
  values$message = "analyis not started"
  
  shinyDirChoose(input, 'STICK', roots=volumes, session = session,restrictions=system.file(package='base'))
 
   #
  fileInput <- reactive({
    filepath= (parseDirPath(volumes, input$STICK))
    filepath
  })

  GObutton <- observeEvent(input$goButton, {
    # session$sendCustomMessage(type = 'testmessage',
    #                          message = 'this may take some time, plese wait')
   dataoutput()
  includeHTML1()
  })
  
  dataoutput <- reactive({
    RECREATEMINFILE <- input$RECREATEMINFILE
    groupingby<- input$groupingby
    Npermutation<- input$Npermutation
    STICK<- fileInput()
    Name_project <- input$Name_project
    
    values$message <- "analyis started"
    #source <- function (x,...){source (x, local=TRUE,...)}
    source("master_shiny.R")
    values$Outputshtml="reports/multidim_anal_variable.html"
    
  })

  output$outputshtml <- renderUI({
    values$Outputshtml
  })

  includeHTML1<- reactive({

    paste(readLines(values$Outputshtml), collapse="\n") 
  })
  
  output$includeHTML<-renderText(includeHTML1())

   output$test <- renderPrint({
     input$Name_project
  })
   


  
 
}

# Run the application 
shinyApp(ui = ui, server = server)

