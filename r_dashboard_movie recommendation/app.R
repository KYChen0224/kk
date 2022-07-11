library(shiny)
library(shinydashboard)
library(recommenderlab)
library(data.table)
library(ShinyRatingInput)
library(shinyjs)
library(dplyr)
library(ggplot2)
library(recommenderlab)
library(DT)
library(data.table)
library(reshape2)


# Loading datasets

# Loading movies
myurl = "https://liangfgithub.github.io/MovieData/"
ratings = read.csv(paste0(myurl, 'ratings.dat?raw=true'),
                   sep = ':',
                   colClasses = c('integer', 'NULL'),
                   header = FALSE)
colnames(ratings) = c('UserID', 'MovieID', 'Rating', 'Timestamp')

movies = readLines(paste0(myurl, 'movies.dat?raw=true'))
movies = strsplit(movies, split = "::", fixed = TRUE, useBytes = TRUE)
movies = matrix(unlist(movies), ncol = 3, byrow = TRUE)
movies = data.frame(movies, stringsAsFactors = FALSE)
colnames(movies) = c('MovieID', 'Title', 'Genres')
movies$MovieID = as.integer(movies$MovieID)

# convert accented characters
movies$Title[73]
movies$Title = iconv(movies$Title, "latin1", "UTF-8")
movies$Title[73]

# extract year
movies$Year = as.numeric(unlist(
  lapply(movies$Title, function(x) substr(x, nchar(x)-4, nchar(x)-1))))

# Loading users
users = read.csv(paste0(myurl, 'users.dat?raw=true'),
                 sep = ':', header = FALSE)
users = users[, -c(2,4,6,8)] # skip columns
colnames(users) = c('UserID', 'Gender', 'Age', 'Occupation', 'Zip-code')

# Filtering data
movies_not_rated = movies %>%
  filter(!(MovieID %in% ratings$MovieID))

# Data preprocessing before creating shiny structure
genre_list = c("Action", "Adventure", "Animation",
               "Children's", "Comedy", "Crime",
               "Documentary", "Drama", "Fantasy",
               "Film-Noir", "Horror", "Musical",
               "Mystery", "Romance", "Sci-Fi",
               "Thriller", "War", "Western")
arrangement = c('Most popular','Most praised')
small_image_url = "https://liangfgithub.github.io/MovieImages/"
movies = movies %>%
  filter(!(MovieID %in% movies_not_rated$MovieID))
rating_sample <- sample(3706, 120)
rating_count = ratings %>%
  group_by(MovieID) %>%
  count()
rating_value = ratings %>%
  group_by(MovieID) %>%
  summarise(rate_value = mean(Rating))
ratings$Timestamp = NULL

# Shindashboard UI part
ui <- dashboardPage(
  dashboardHeader(title = "Movie Recommender"),


  dashboardSidebar(
    hr(),
    sidebarMenu(id = 'Menus',
                menuItem('Recommender by Genre',tabName = 'Genre',icon = icon("chart-line")),
                menuItem('Recommender by Rating',tabName = 'Rating',icon = icon("table"))
                ),
    hr()
  ),


  dashboardBody(includeCSS("movies.css"),
    skin = 'black',
    # Boxes need to be put in a row (or column)
    tabItems(
      tabItem(tabName = 'Genre',
            fluidRow(
              box(
                title = 'Step1 : Select your favorite genre',
                status = "primary", solidHeader = TRUE,
                collapsible = TRUE,

                selectInput(inputId = 'genre',label = 'select a single genre from the dropdown menu',choices = genre_list)
              ),
              box(
                title = 'Step2 : Select arrangement',
                status = "primary", solidHeader = TRUE,
                collapsible = TRUE,

                selectInput(inputId = 'arrangement',label = 'Choose an arrangement method',choices = arrangement)
              )
            ),

            fluidRow(
              box(
                title = 'Step3 : Discover movies you might like',
                status = "primary", solidHeader = TRUE,
                collapsible = TRUE,
                width = 12,

                actionButton("gobutton", "Click here to get your recommendation",class = "btn-success",
                             style="color: #fff; background-color: #337ab7; border-color: #2e6da4"),
                br(),
                tableOutput('result_genre')
              )
            )
      ),


      tabItem(tabName = 'Rating',
              fluidRow(
                box(
                  title = 'Rate as many movies as possible',
                  status = 'info',solidHeader = TRUE,collapsible = TRUE,
                  width = 12,
                  div(class = 'rateitems',
                      uiOutput('ratings')
                      )
                )
              ),

              fluidRow(
                useShinyjs(),
                box(
                  title = 'Step2 : Discover movies you might like',
                  status = 'info',solidHeader = TRUE,collapsible = TRUE,

                  width = 12,
                  actionButton("button", "Click here to get your recommendation",class = "btn-success",
                               style="color: #fff; background-color: #337ab7; border-color: #2e6da4"),
                  br(),
                  tableOutput('result_rating')
                )
              )
      )

    )
  )
)

# Server part
server <- function(input, output) {
  # define functions
  # function: predict ratings(system 2)
  predict_ratings <- function(a){
    c = cbind(rep(6041,length(a$MovieID)),a)
    colnames(c) <- c('UserID', 'MovieID', 'Rating')
    d = rbind(ratings,c)

    i = paste0('u', d$UserID)
    j = paste0('m', d$MovieID)
    x = d$Rating
    tmp = data.frame(i, j, x, stringsAsFactors = T)
    Rmat = sparseMatrix(as.integer(tmp$i), as.integer(tmp$j), x = tmp$x)
    rownames(Rmat) = levels(tmp$i)
    colnames(Rmat) = levels(tmp$j)
    Rmat = new('realRatingMatrix', data = Rmat)

    rec_UBCF = Recommender(Rmat, method = 'UBCF',
                           parameter = list(normalize = 'Z-score',
                                            method = 'Cosine',
                                            nn = 25))

    e = as(predict(rec_UBCF,
                   Rmat[5604], type = 'ratings'), 'list')
    e = e$u6041
    rating = NA

    for (u in 1:length(e)){
      n =  as.numeric(substr(names(e),start = 2,stop = 5))[u]
      rating[n] = e[u]
    }

    for (v in 1:length(rating)) {
      rating[v] = ifelse(is.na(rating[v])|rating[v]==Inf|rating[v]==-Inf, mean(a$Rating), rating[v])
    }

    rating[a$MovieID] = a$Rating

    return(data.frame(1:3952,rating))
  }
  # function: get user's ratings from input
  get_user_ratings <- function(value_list) {
    dat <- data.table(MovieID = sapply(strsplit(names(value_list), "_"), function(x) ifelse(length(x) > 1, x[[2]], NA)),
                      Rating = unlist(as.character(value_list)))
    dat <- dat[!is.null(Rating) & !is.na(MovieID)]
    dat[Rating == " ", Rating := 0]
    dat[, ':=' (MovieID = as.numeric(MovieID), Rating = as.numeric(Rating))]
    dat <- dat[Rating > 0]
  }



  # system 2 input image and values setting
  output$ratings <- renderUI({
    num_rows <- 20
    num_movies <- 6 # movies per row

    lapply(1:num_rows, function(i) {
      list(fluidRow(lapply(1:num_movies, function(j) {
        list(box(width = 2,
                 div(style = "text-align:center", img(src = paste0(
                   small_image_url,
                   movies$MovieID[rating_sample[(i - 1) * num_movies + j]],
                   '.jpg'), style = "max-height:150")),
                 div(style = "text-align:center", strong(movies$Title[rating_sample[(i - 1) * num_movies + j]])),
                 div(style = "text-align:center; font-size: 150%; color: #f0ad4e;",
                     ratingInput(paste0("select_", movies$MovieID[rating_sample[(i - 1) * num_movies + j]]),
                                 label = "", dataStop = 5)))) #00c0ef
      })))
    })
  })

  # system 1 output function after clicking the button
  go <- eventReactive(input$gobutton,{
    if (input$arrangement == 'Most popular'){
      movies_filter = movies %>%
        inner_join(rating_count,by = 'MovieID') %>%
        inner_join(rating_value,by = 'MovieID') %>%
        filter(grepl(input$genre,Genres)) %>%
        top_n(20, n) %>%
        mutate(Image = paste0(
          small_image_url,
          MovieID,
          '.jpg')) %>%
        arrange(desc(n)) %>%
        select('Image','Title')
    } else {
      movies_filter = movies %>%
        inner_join(rating_count,by = 'MovieID') %>%
        inner_join(rating_value,by = 'MovieID') %>%
        filter(grepl(input$genre,Genres)) %>%
        top_n(20, rate_value) %>%
        mutate(Image = paste0(
          small_image_url,
          MovieID,
          '.jpg')) %>%
        arrange(desc(n)) %>%
        select('Image','Title')
    }

    num_rows <- 4
    num_books <- 5
    lapply(1:num_rows, function(i) {
      list(fluidRow(lapply(1:num_books, function(j) {
        box(width = 2, status = "success", solidHeader = TRUE, title = paste0("Rank ", (i - 1) * num_books + j),

            div(style = "text-align:center",
                a(img(src = movies_filter$Image[(i - 1) * num_books + j], height = 150))),

            div(style="text-align:center; font-size: 100%",
                strong(movies_filter$Title[(i - 1) * num_books + j])
            )

        )
      }))) # columns
    }) # rows
  })

  # system 1 output UI
  output$result_genre <- renderUI({
    go()
  })

  #system 2 output function after clicking the button
  rating_getvalues <- eventReactive(input$button,{
    value_list <- reactiveValuesToList(input)
    user_ratings <- get_user_ratings(value_list)
    predict_ratings_values <- predict_ratings(user_ratings)
    colnames(predict_ratings_values) <- c('MovieID', 'Rating')


    movies_filter = movies %>%
      inner_join(predict_ratings_values,by = 'MovieID') %>%
      top_n(20, Rating) %>%
      mutate(Image = paste0(
        small_image_url,
        MovieID,
        '.jpg')) %>%
      arrange(desc(Rating)) %>%
      select('Image','Title')

    num_rows <- 4
    num_books <- 5
    lapply(1:num_rows, function(i) {
      list(fluidRow(lapply(1:num_books, function(j) {
        box(width = 2, status = "success", solidHeader = TRUE, title = paste0("Rank ", (i - 1) * num_books + j),

            div(style = "text-align:center",
                a(img(src = movies_filter$Image[(i - 1) * num_books + j], height = 150))),

            div(style="text-align:center; font-size: 100%",
                strong(movies_filter$Title[(i - 1) * num_books + j])
            )

        )
      }))) # columns
    }) # rows
  })

  # system 2 output UI
  output$result_rating <- renderUI({
    rating_getvalues()
  })

}

shinyApp(ui, server)
