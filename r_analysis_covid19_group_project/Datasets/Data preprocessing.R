#library package
library(data.table)
library(curl)
library(dplyr)
library(plyr)

#load the datasets
#raw_case_death_state: raw data of United States COVID-19 Cases and Deaths by State over Time
raw_case_death_state <- data.table::fread('United_States_COVID-19_Cases_and_Deaths_by_State_over_Time.csv')
raw_case_death_state <- as.data.frame(raw_case_death_state)
#raw_vac_state: COVID-19 Vaccinations in the United States,Jurisdiction
raw_vac_state <- data.table::fread('COVID-19_Vaccinations_in_the_United_States_Jurisdiction.csv')
raw_vac_state <- as.data.frame(raw_vac_state)

#data cleaning
#Change the data type: from string to date
raw_case_death_state$submission_date = as.Date(raw_case_death_state$submission_date,format = '%m/%d/%Y')
raw_vac_state$Date = as.Date(raw_vac_state$Date,format = '%m/%d/%Y')

#Delete unnecessary variables in this project
raw_case_death_state = raw_case_death_state[-c(4,5,7,9,10,12,13,14,15)]
del_colnames = c('MMWR_week','Distributed_Per_100k_12Plus','Distributed_Per_100k_18Plus','Distributed_Per_100k_65Plus',
                 'Administered_12Plus','Administered_18Plus','Administered_65Plus','Admin_Per_100k_12Plus',
                 'Admin_Per_100k_18Plus','Admin_Per_100k_65Plus','Administered_Dose1_Recip_12Plus',
                 'Administered_Dose1_Recip_12PlusPop_Pct','Administered_Dose1_Recip_18Plus',
                 'Administered_Dose1_Recip_18PlusPop_Pct','Administered_Dose1_Recip_65Plus',
                 'Administered_Dose1_Recip_65PlusPop_Pct','Series_Complete_12Plus','Series_Complete_12PlusPop_Pct',
                 'Series_Complete_18Plus','Series_Complete_18PlusPop_Pct','Series_Complete_65Plus',
                 'Series_Complete_65PlusPop_Pct','Series_Complete_Janssen_12Plus','Series_Complete_Moderna_12Plus',
                 'Series_Complete_Pfizer_12Plus','Series_Complete_Unk_Manuf_12Plus','Series_Complete_Janssen_18Plus',
                 'Series_Complete_Moderna_18Plus','Series_Complete_Pfizer_18Plus','Series_Complete_Unk_Manuf_18Plus',
                 'Series_Complete_Janssen_65Plus','Series_Complete_Moderna_65Plus','Series_Complete_Pfizer_65Plus',
                 'Series_Complete_Unk_Manuf_65Plus','Additional_Doses_18Plus','Additional_Doses_18Plus_Vax_Pct',
                 'Additional_Doses_50Plus','Additional_Doses_50Plus_Vax_Pct','Additional_Doses_65Plus',
                 'Additional_Doses_65Plus_Vax_Pct','Administered_Dose1_Recip_5Plus','Administered_Dose1_Recip_5PlusPop_Pct',
                 'Series_Complete_5Plus','Series_Complete_5PlusPop_Pct','Administered_5Plus','Admin_Per_100k_5Plus',
                 'Distributed_Per_100k_5Plus','Series_Complete_Moderna_5Plus','Series_Complete_Pfizer_5Plus',
                 'Series_Complete_Janssen_5Plus','Series_Complete_Unk_Manuf_5Plus')
raw_vac_state = raw_vac_state[!names(raw_vac_state) %in% del_colnames]

#Arrange the raw_case_death_state data set according to date
raw_case_death_state = raw_case_death_state[order(raw_case_death_state$submission_date),]
#Reset index
rownames(raw_case_death_state) = NULL

#In this project, our research object dates are from 2020-12-13 to 2021-12-1.
#Data not within the scope of this study will be deleted.
clean_case_death_state = raw_case_death_state %>%
  slice(-c(1:19560))
clean_vac_state = raw_vac_state %>%
  slice(-c(1:64))

#In order to improve the data fitting ability of the SEIR model, all dates are retained.
clean_case_death_state_SEIR = raw_case_death_state

#As required by the SEIR model, add a data set (describe currently active cases).
#Due to certain restrictions, the data set cannot be exported. I copied it from the source code.
#Dataset link:https://www.worldometers.info/coronavirus/usa/illinois/#graph-cases-daily
currently_Active_case_IL = c(30,44,62,91,103,158,286,418,581,749,1044,1279,1527,1856,2526,3009,3464,4558,5014,5930,6879,7583,8746,10174,10999,11977,13197,14652,15937,17341,18559,20198,21303,22457,23730,24750,26540,28007,28624,29722,31161,33124,34836,37467,39519,41599,43541,45628,47803,50239,53291,55652,58605,60877,62833,64979,67497,70270,72499,74108,75327,78311,79526,82647,84760,86670,88366,90617,92007,94260,96335,97937,100227,102683,104116,105262,106216,107647,109193,109751,53524,54481,54437,54223,53717,54142,54258,54630,55042,54667,54332,53976,42456,42719,43123,43342,42938,42243,42105,25814,26418,27073,26817,26833,26513,26764,27026,27379,24626,25131,25505,25866,26135,26622,27334,27873,28387,28358,28738,29422,30483,31278,31915,32698,32988,34042,34882,14876,15792,16657,17710,18205,19343,20567,21807,22993,24514,25385,25861,26934,28690,30021,31500,32687,33805,34896,36095,37628,39339,41169,42451,43750,44899,46244,47598,49392,51120,52322,53855,55075,56890,58182,59997,62013,63786,65238,66338,67755,69002,71036,72696,74468,75996,76728,78316,79196,43505,45736,47014,48195,49412,50049,51302,52826,54397,55509,56757,57773,58839,60270,62014,63918,64970,66272,67078,68376,69883,72055,73871,75150,76534,77321,78719,80285,81561,83228,84256,85759,86601,88181,90440,92685,94840,97342,99759,101885,103547,106237,77164,79477,82501,84310,86238,88641,91531,93027,97960,100756,104189,106558,110613,114368,119072,125532,130983,136056,140481,146053,153689,161768,172684,180812,189784,199763,212267,218828,231356,239484,247316,256101,265778,270590,279968,289090,296453,303110,307564,312435,318629,326544,327738,331226,333435,335383,341601,344556,348168,350633,353177,354294,356280,356433,354503,354941,351858,350520,347117,341742,336490,330877,324172,320452,317307,311700,303824,301263,293470,287534,281426,274736,270169,265187,259556,254925,255415,254713,252369,250650,243209,240331,236976,235222,234565,233663,229720,226660,225083,219842,217161,214987,213079,210131,206215,203590,199619,197278,196682,195834,194482,191273,188242,185066,183557,184450,184044,182049,178831,173818,169146,165345,164284,162834,159841,154743,149365,143504,137060,133010,130366,127251,122093,117642,112885,108208,105080,102822,101002,97953,94858,91931,86847,84141,82656,80977,78452,76301,74280,71857,69970,70085,68874,67779,65981,64380,62436,61154,60784,60543,59255,58455,57284,57047,57353,57684,57691,57585,57660,58519,58500,59606,60685,61672,61781,62176,62902,64006,65461,67060,68357,68890,69729,71782,74058,75500,78075,79841,80760,82271,84102,85919,88112,89820,91700,91656,92612,93045,93822,95211,96675,97476,97778,97546,98085,98458,98963,99503,99590,99221,98858,97740,96267,96733,96001,95630,94123,91897,89968,87878,86066,84617,83418,81189,79156,77215,74881,73277,71706,70696,69053,67111,65092,62611,60682,59441,57900,55854,53540,50647,48144,45985,44656,42917,40959,38934,37586,34636,33327,31862,30734,29346,27790,26242,24654,23268,22335,21403,20375,18933,17665,16335,15544,14913,14283,13651,12838,12216,11700,11262,11075,10888,10701,10512,10315,10305,10416,10703,10910,11051,11220,11608,12067,12476,13465,14609,14603,14999,15713,17607,18792,20171,21587,22033,23445,25287,26678,28779,30953,32690,33602,36024,37920,40607,43329,46350,48599,50260,52746,56054,58503,61364,64863,66969,68909,71792,74741,77238,81126,84463,85604,87740,89774,92202,94727,98279,100273,103150,104143,106918,110397,112253,116028,118061,118803,119130,119595,120451,122154,124394,126407,126625,125699,126431,127524,128361,127885,128538,128256,127530,126710,127076,125672,124751,124577,124044,123397,121354,120275,118683,118637,118073,116293,114284,112191,110884,108291,106874,108289,110988,112752,102944,101115,98266,96035,95604,94103,92377,90281,88373,86929,86313,85779,84668,83623,82302,80823,80120,80259,82988,84749,79820,79237,77649,78574,78244,81193,83513,78699,78040,79705,81751,83493,84660,85795,86023,86126,88646,91861,94949,97914,98340,101411,103587,106508,109864,109989,111883,112918,115452,119154,122652)
currently_Active_case_IL = as.data.table(currently_Active_case_IL)


#Filtering 50 us states
us_states = c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", 
              "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", 
              "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", 
              "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", 
              "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY")

clean_case_death_state = as.data.table(clean_case_death_state)
clean_vac_state = as.data.table(clean_vac_state)
clean_case_death_state = clean_case_death_state[state %in% us_states]
clean_vac_state = clean_vac_state[Location %in% us_states][order(Date)]
clean_case_death_state = clean_case_death_state[submission_date %in% unique(clean_vac_state$Date)]

#Export clean datasets as csv files.
write.csv(currently_Active_case_IL,file = "clean_currently_Active_case_IL.csv",row.names = F)
write.csv(clean_case_death_state,file = "clean_case_death_state.csv",row.names = F)
write.csv(clean_vac_state,file = "clean_vac_state.csv",row.names = F)
write.csv(clean_case_death_state_SEIR,file = "clean_case_death_state_SEIR.csv",row.names = F)
