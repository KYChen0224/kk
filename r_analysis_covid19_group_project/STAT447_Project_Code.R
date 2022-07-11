#part1 1.Through the daily mortality rate of different states and the number of new cases each day, we analyze the vaccine effects of different companies.

# Source code for the project
# Read in the cleaned datasets
library(data.table)
case = fread("Datasets/clean_case_death_state.csv")
vac = fread("Datasets/clean_vac_state.csv")

# Merge the two datasets and select only useful columns
case_vac = merge(case, vac, by.x = c("submission_date", "state"),
                 by.y = c("Date", "Location"))
case_vac = case_vac[, c(colnames(case), "Series_Complete_Janssen",
                        "Series_Complete_Moderna", "Series_Complete_Pfizer",
                        "Series_Complete_Unk_Manuf"), with = FALSE]

# Create columns for # of new fully vaccinated people of each company
cv_us = case_vac[submission_date >= as.POSIXct("2021-03-05"),
                 .(new_case = sum(new_case), new_death = sum(new_death),
                   janssen = sum(Series_Complete_Janssen),
                   moderna = sum(Series_Complete_Moderna),
                   pfizer = sum(Series_Complete_Pfizer),
                   unk_manuf = sum(Series_Complete_Unk_Manuf)),
                 by = submission_date]
cv_us = cv_us[, .(submission_date, new_case, new_death,
                  janssen = janssen - lag(janssen, default = 0),
                  moderna = moderna - lag(moderna, default = 0),
                  pfizer = pfizer - lag(pfizer, default = 0),
                  unk_manuf = unk_manuf - lag(unk_manuf, default = 0))]
cv_us = cv_us[submission_date > as.POSIXct("2021-03-05")]

# Graph for daily new case & new death & new fully vaccinated people
library(ggplot2)
cv_melt = melt(cv_us ,  id = 'submission_date', measure = 2:7)
cv_melt$submission_date = as.Date(cv_melt$submission_date)

ggplot(cv_melt, aes(submission_date, value)) +
  geom_line(aes(colour = variable)) +
  ggtitle("Daily Stats for Cases and Vaccination") +
  xlab("Date") +
  ylab("Number of People")

# Break down into states
us_states = c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
              "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
              "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
              "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
              "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY")
domin_case = rep(0, length(us_states))
domin_death = rep(0, length(us_states))

# Build linear regression model for each state
for (i in 1:length(us_states)){
  cv_state = case_vac[submission_date >= as.POSIXct("2021-03-10") &
                        state == us_states[i],
                      .(submission_date, new_case, new_death,
                        janssen = (Series_Complete_Janssen - lag(Series_Complete_Janssen, default = 0)) / lag(Series_Complete_Janssen, default = 0),
                        moderna = (Series_Complete_Moderna - lag(Series_Complete_Moderna, default = 0)) / lag(Series_Complete_Moderna, default = 0),
                        pfizer = (Series_Complete_Pfizer - lag(Series_Complete_Pfizer, default = 0)) / lag(Series_Complete_Pfizer, default = 0),
                        unk_manuf = (Series_Complete_Unk_Manuf - lag(Series_Complete_Unk_Manuf, default = 0)) / lag(Series_Complete_Unk_Manuf, default = 0))]
  cv_state = cv_state[submission_date > as.POSIXct("2021-03-10")]
  model1 = lm(new_case ~ janssen + moderna + pfizer, data = cv_state)
  model2 = lm(new_death ~ janssen + moderna + pfizer, data = cv_state)
  domin_case[i] = names(model1$coefficients[which.min(model1$coefficients)])
  domin_death[i] = names(model2$coefficients[which.min(model2$coefficients)])
}

# Plot the summary table
vac_state = data.frame(us_states, domin_case, domin_death)
td1 = melt(table(domin_case))

ggplot(td1, aes(x = "", y = value, fill = domin_case)) +
  geom_col(color = "black") +
  geom_text(aes(label = value),
            position = position_stack(vjust = 0.5)) +
  ggtitle("Best Vaccine for Decreasing New Case") +
  xlab("") +
  ylab("Number of States") +
  coord_polar(theta = "y")

td2 = melt(table(domin_death))

ggplot(td2, aes(x = "", y = value, fill = domin_death)) +
  geom_col(color = "black") +
  geom_text(aes(label = value),
            position = position_stack(vjust = 0.5)) +
  ggtitle("Best Vaccine for Decreasing New Death") +
  xlab("") +
  ylab("Number of States") +
  coord_polar(theta = "y")


#part 2 The relationship between complete vaccination rate and new daily cases.
library(tidyverse)
library(MASS)

## Load data and data preprocessing
vac_data_raw = read_csv("Datasets/clean_vac_state.csv")
death_data_raw = read_csv("Datasets/clean_case_death_state.csv")

vac_data = vac_data_raw %>%
  rename(State = Location) %>%
  dplyr::select(Date, State,
                Dist_Per_100K,
                Admin_Per_100K, Administered_Dose1_Recip, Administered_Dose1_Pop_Pct,
                Series_Complete_Pop_Pct,
                Additional_Doses_Vax_Pct)

death_data = death_data_raw %>% rename(
  Date = submission_date,
  State = state
)

vac_death_data = vac_data %>%
  left_join(death_data, by = c("Date", "State")) %>%
  group_by(Date) %>%
  summarise(Date = max(Date),
            sum_new_death = sum(new_death),
            sum_Series_Complete_Pop_Pct = sum(Series_Complete_Pop_Pct),
            sum_Administered_Dose1_Pop_Pct = sum(Administered_Dose1_Pop_Pct),
            sum_Additional_Doses_Vax_Pct = sum(Additional_Doses_Vax_Pct),
            sum_tot_cases = sum(tot_cases),
            sum_tot_death = sum(tot_death),
            sum_new_case = sum(new_case)) %>%
  filter(Date >= "2021-03-05")

## EDA
### Plot: Percent of people who are fully vaccinated
vac_data %>%
  group_by(Date) %>%
  summarise(Date = max(Date),
            sum_Series_Complete_Pop_Pct = sum(Series_Complete_Pop_Pct),
            sum_Administered_Dose1_Pop_Pct = sum(Administered_Dose1_Pop_Pct),
            sum_Additional_Doses_Vax_Pct = sum(Additional_Doses_Vax_Pct)) %>%
  ggplot() +
  geom_line(aes(x = Date, y = sum_Series_Complete_Pop_Pct), size = 1L, colour = "#0c4c8a") +
  # geom_line(aes(x = Date, y = sum_Additional_Doses_Vax_Pct), color = "blue") +
  labs(x = "Date", y = "Percent of people who are fully vaccinated", title = "Percent of people who are fully vaccinated from Jan 2021", sice = 12) +
  theme_light()

### Plot: Number of new death daily form 2021 Jan.
death_data %>%
  group_by(Date) %>%
  summarise(Date = max(Date),
            sum_new_death = sum(new_death),
            sum_new_case = sum(new_case)) %>%
  ggplot() +
  geom_vline(xintercept = c(as.Date("2021-03-05"), as.Date("2021-07-05")), linetype = 2, size = 0.5)+
  geom_line(aes(x = Date, y = sum_new_death), size = 1L, colour = "#0c4c8a") +
  # geom_line(aes(x = Date, y = sum_new_case), size = 1L, colour = "blue") +
  labs(x = "Date", y = "Number of new death daily", title = "Number of new death daily form 2021 Jan.") +
  theme_light()

### Plot: Scatterplot of number of daily new deathand percent of  fully vaccinated people from 2021-03-05
ggplot(vac_death_data) +
  aes(x = sum_Series_Complete_Pop_Pct, y = sum_new_case) +
  geom_point(size = 1L, colour = "#0c4c8a") +
  geom_vline(xintercept = c(1250, 2050, 2350, 2550, 2800),linetype = 2, size = 0.2)+
  theme_bw()+
  labs(x = "Percent of people who are fully vaccinated", y = "Number of new death daily", title = "Scatterplot of number of daily new deathand percent of  fully vaccinated people from 2021-03-05")+
  theme(plot.title = element_text(size=10))

## Model: Regression Splines
myknots = c(1250, 2050, 2350, 2550, 2800)
spline_dg1_mykonts <- lm(sum_new_death ~ splines::bs(sum_Series_Complete_Pop_Pct, degree = 1, knots = myknots), data = vac_death_data)

spline_dg2_mykonts <- lm(sum_new_death ~ splines::bs(sum_Series_Complete_Pop_Pct, degree = 2, knots = myknots), data = vac_death_data)

spline_dg3_mykonts <- lm(sum_new_death ~ splines::bs(sum_Series_Complete_Pop_Pct, degree = 3, knots = myknots), data = vac_death_data)

spline_df5 <- lm(sum_new_death ~ splines::bs(sum_Series_Complete_Pop_Pct, df=5), data = vac_death_data)

spline_df7 <- lm(sum_new_death ~ splines::bs(sum_Series_Complete_Pop_Pct, df=7), data = vac_death_data)

spline_df10 <- lm(sum_new_death ~ splines::bs(sum_Series_Complete_Pop_Pct, df=10), data = vac_death_data)

par(mfrow = c(2, 3))
plot(vac_death_data$sum_Series_Complete_Pop_Pct, vac_death_data$sum_new_death, pch = 20, col = "darkorange",
     xlab = "Percent of fully vaccinated people",
     ylab = "Number of new death daily")
lines(vac_death_data$sum_Series_Complete_Pop_Pct, spline_dg1_mykonts$fitted.values, lty = 1, col = "deepskyblue", lwd = 2)
abline(v = myknots, lty = 2)
title("Linear spline with 5 knots")

plot(vac_death_data$sum_Series_Complete_Pop_Pct, vac_death_data$sum_new_death, pch = 20, col = "darkorange",
     xlab = "Percent of fully vaccinated people",
     ylab = "Number of new death daily")
lines(vac_death_data$sum_Series_Complete_Pop_Pct, spline_dg2_mykonts$fitted.values, lty = 1, col = "deepskyblue", lwd = 2)
abline(v = myknots, lty = 2)
title("Quadratic spline with 5 knots")

plot(vac_death_data$sum_Series_Complete_Pop_Pct, vac_death_data$sum_new_death, pch = 20, col = "darkorange",
     xlab = "Percent of fully vaccinated people",
     ylab = "Number of new death daily")
lines(vac_death_data$sum_Series_Complete_Pop_Pct, spline_dg3_mykonts$fitted.values, lty = 1, col = "deepskyblue", lwd = 2)
abline(v = myknots, lty = 2)
title("Cubic spline with 3 knots")

plot(vac_death_data$sum_Series_Complete_Pop_Pct, vac_death_data$sum_new_death, pch = 20, col = "darkorange",
     xlab = "Percent of fully vaccinated people",
     ylab = "Number of new death daily")
lines(vac_death_data$sum_Series_Complete_Pop_Pct, spline_df5$fitted.values, lty = 1, col = "deepskyblue", lwd = 2)
# abline(v = myknots, lty = 2)
title("Spline with 5 degree of pars")

plot(vac_death_data$sum_Series_Complete_Pop_Pct, vac_death_data$sum_new_death, pch = 20, col = "darkorange",
     xlab = "Percent of fully vaccinated people",
     ylab = "Number of new death daily")
lines(vac_death_data$sum_Series_Complete_Pop_Pct, spline_df7$fitted.values, lty = 1, col = "deepskyblue", lwd = 2)
# abline(v = myknots, lty = 2)
title("Spline with 7 degree of pars")

plot(vac_death_data$sum_Series_Complete_Pop_Pct, vac_death_data$sum_new_death, pch = 20, col = "darkorange",
     xlab = "Percent of fully vaccinated people",
     ylab = "Number of new death daily")
lines(vac_death_data$sum_Series_Complete_Pop_Pct, spline_df10$fitted.values, lty = 1, col = "deepskyblue", lwd = 2)
# abline(v = myknots, lty = 2)
title("Spline with 10 degree of pars")

## Model: Linear regression & Stepwise Model Selection
# Fit the full model
full.model.1 <- lm(sum_new_death ~ ., data = vac_death_data[vac_death_data$Date >= "2021-03-05" & vac_death_data$Date <= "2021-07-05",])
# Stepwise regression model
step.model.1 <- step(full.model.1, direction = "both",
                     trace = FALSE)
summary(step.model.1)


#part 3 SEIR Model.
#3.1 Filter Illinois data.
clean_case_death_state_SEIR = fread("Datasets/clean_case_death_state_SEIR.csv")
currently_Active_case_IL = fread('Datasets/clean_currently_Active_case_IL.csv')
case_IL = clean_case_death_state_SEIR |>
  filter(state == 'IL') |>
  slice(-c(1:50)) |>
  mutate(Active_case = currently_Active_case_IL$currently_Active_case)
new_death = case_IL$new_death
#Output graphics, and use loess to do simple smoothing.
ggplot(data = case_IL,aes(x = submission_date, y = Active_case)) +
  geom_line(aes(color = state)) +
  geom_smooth(method = 'loess', se=FALSE, formula=y ~ x) +
  labs(title = 'Currently Active Cases',
       subtitle = 'Number of Infected People',
       x = 'Date', y = 'Number of cases')



#3.2Variable interpretation.

#S:Susceptible.
#Sq:Susceptible patient in quarantine.
#E:Exposed(Potential patients with the virus.)
#Eq:Exposed patient in quarantine.
#I:Infective(Patients who have already exhibited symptoms.)
#H:Patients who were diagnosed and sent to the hospital for treatment.
#N:Population of Illinois.
#R:Recovery(People who are not affected by the virus.)
#new_death:Number of new deaths per day.
E = 10
I = 30
Sq = 1
Eq = 1
R = 0
H = 0
N = 12812508
S = N-H-E-I-Eq-Sq
new_death = case_IL$new_death
#d:Infectivity coefficient of exposed patients relative to patients who have had the disease.
#j:Probability of re-infection in recovered patients.
#j2:Due to the large-scale vaccination of the vaccine, Susceptible patients will be converted to recovery in a certain proportion. j2 represents the proportional coefficient.
#k:Rate of de-quarantine.
#a:Rate from infection to disease.
#c1:Before government control measures, the average number of contacts per person per day.
#c2:After the government has adopted epidemic prevention measures, the average number of contacts per person per day.
#c3:After considering the vaccine factor, the average number of contacts per person per day.
#fI:Proportion of hospitalized patients from Infective.
#fq:Proportion of hospitalized patients from exposed patient in quarantine
#q1:Isolation coefficient before the outbreak.
#q2:Isolation coefficient under epidemic prevention measures.
#yI:Recovery rate of infected people.
#yH:Recovery rate of infected people hospitalized for treatment.
#B:Probability of virus infection.
#T:Total days of analysis.
d = 0.68
j = 0.05
j1 = 0.15
j2 = 0.6
k = 1/14
a = 1/7
c1 = 3.34
c2 = 3.27
c3 = 2.9
fI=0.13
fq=0.13
yI=0.07
yH=0.14
B = 0.045
q1 = 0
q2 = 0.00001
T = 630

#3.3 SEIR MODEL
for (i in 1:80){
  N[i+1] = N[i]-new_death[i]
  S[i+1] = S[i]-(c1*B+c1*q1*(1-B))*S[i]*(I[i]+d*E[i])/N[i]+k*Sq[i]
  E[i+1] = E[i]+c1*B*(1-q1)*S[i]*(I[i]+d*E[i])/N[i]-a*E[i]
  I[i+1] = I[i]+a*E[i]-(fI+yI)*I[i]
  Sq[i+1] = Sq[i]+c1*q1*(1-B)*S[i]*(I[i]+d*E[i])/N[i]-k*Sq[i]
  Eq[i+1] = Eq[i]+c1*B*q1*S[i]*(I[i]+d*E[i])/N[i]-fq*Eq[i]
  H[i+1] = H[i]+fI*I[i]+fq*Eq[i]-yH*H[i]
  R[i+1] = R[i]+yI*I[i]+yH*H[i]
}
for (i in 81:338){
  N[i+1] = N[i]-new_death[i]
  S[i+1]=S[i]-(c2*B+c2*q2*(1-B))*S[i]*(I[i]+d*E[i])/N[i]+k*Sq[i]
  E[i+1]=E[i]+c2*B*(1-q2)*S[i]*(I[i]+d*E[i])/N[i]-a*E[i]
  I[i+1]=I[i]+a*E[i]-(fI+yI)*I[i]
  Sq[i+1]=Sq[i]+c2*q2*(1-B)*S[i]*(I[i]+d*E[i])/N[i]-k*Sq[i]
  Eq[i+1]=Eq[i]+c2*B*q2*S[i]*(I[i]+d*E[i])/N[i]-fq*Eq[i]
  H[i+1]=H[i]+fI*I[i]+fq*Eq[i]-yH*H[i]
  R[i+1]=R[i]+yI*I[i]+yH*H[i]
}
for (i in 339:400){
  N[i+1] = N[i]-new_death[i]
  S[i+1]=S[i]-(c3*B+c2*q2*(1-B))*S[i]*(I[i]+d*E[i])/N[i]+k*Sq[i]+j*R[i]
  E[i+1]=E[i]+c3*B*(1-q2)*S[i]*(I[i]+d*E[i])/N[i]-a*E[i]
  I[i+1]=I[i]+a*E[i]-(fI+yI)*I[i]
  Sq[i+1]=Sq[i]+c3*q2*(1-B)*S[i]*(I[i]+d*E[i])/N[i]-k*Sq[i]
  Eq[i+1]=Eq[i]+c3*B*q2*S[i]*(I[i]+d*E[i])/N[i]-fq*Eq[i]
  H[i+1]=H[i]+fI*I[i]+fq*Eq[i]-yH*H[i]
  R[i+1]=R[i]+yI*I[i]+yH*H[i]-j*R[i]
}
for (i in 401:439){
  N[i+1] = N[i]-new_death[i]
  S[i+1]=S[i]-(c3*B+c2*q2*(1-B))*S[i]*(I[i]+d*E[i])/N[i]+k*Sq[i]+(j-j1)*R[i]
  E[i+1]=E[i]+c3*B*(1-q2)*S[i]*(I[i]+d*E[i])/N[i]-a*E[i]
  I[i+1]=I[i]+a*E[i]-(fI+yI)*I[i]
  Sq[i+1]=Sq[i]+c3*q2*(1-B)*S[i]*(I[i]+d*E[i])/N[i]-k*Sq[i]
  Eq[i+1]=Eq[i]+c3*B*q2*S[i]*(I[i]+d*E[i])/N[i]-fq*Eq[i]
  H[i+1]=H[i]+fI*I[i]+fq*Eq[i]-yH*H[i]
  R[i+1]=R[i]+yI*I[i]+yH*H[i]-(j-j1)*R[i]
}
for (i in 440:(T-1)){
  N[i+1] = N[i]-new_death[i]
  S[i+1]=S[i]-(c3*B+c2*q2*(1-B))*S[i]*(I[i]+d*E[i])/N[i]+k*Sq[i]+(j-j1+j2)*R[i]
  E[i+1]=E[i]+c3*B*(1-q2)*S[i]*(I[i]+d*E[i])/N[i]-a*E[i]
  I[i+1]=I[i]+a*E[i]-(fI+yI)*I[i]
  Sq[i+1]=Sq[i]+c3*q2*(1-B)*S[i]*(I[i]+d*E[i])/N[i]-k*Sq[i]
  Eq[i+1]=Eq[i]+c3*B*q2*S[i]*(I[i]+d*E[i])/N[i]-fq*Eq[i]
  H[i+1]=H[i]+fI*I[i]+fq*Eq[i]-yH*H[i]
  R[i+1]=R[i]+yI*I[i]+yH*H[i]-(j-j1+j2)*R[i]
}
seir_result <- data.frame(S,Sq,E,Eq,I,H,I+H,R,new_death)

#3.4 Data sorting and graph comparison.
case_IL = case_IL |>
  mutate(seir_Active_case = seir_result$I, hosipital = seir_result$H, recovery = seir_result$R)
ggplot(case_IL) +
  geom_line(aes(x = submission_date, y =seir_Active_case, color = 'SEIR')) +
  geom_line(aes(x = submission_date, y =Active_case, color = state))
