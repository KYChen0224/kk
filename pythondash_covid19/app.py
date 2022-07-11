import dash
from dash import dcc
from dash import html
import pandas as pd
import plotly.express as px
from dash.dependencies import Input, Output
import plotly.graph_objects as go
import numpy as np
import time

external_stylesheets = ['https://codepen.io/chriddyp/pen/bWLwgP.css']

app = dash.Dash(__name__, external_stylesheets=external_stylesheets)

df = pd.read_csv('https://data.cdc.gov/api/views/8xkx-amqh/rows.csv?accessType=DOWNLOAD')
df = df[['Date','Recip_County','Recip_State','Series_Complete_Pop_Pct','Administered_Dose1_Pop_Pct']]
df['Date'] = pd.to_datetime(df['Date'])
df['days'] = df['Date']-df['Date'].min()

def getdays(x):
    return x.days
df['day_c'] = df['days'].map(getdays)

available_indicators_state = df['Recip_State'].unique()


def generate_table(dataframe, max_rows=13):
    return html.Table([
        html.Thead(
            html.Tr([html.Th(col) for col in dataframe.columns])
        ),
        html.Tbody([
            html.Tr([
                html.Td(dataframe.iloc[i][col]) for col in dataframe.columns
            ]) for i in range(min(len(dataframe), max_rows))
        ])
    ])

df_level = pd.read_csv('https://data.cdc.gov/api/views/8396-v7yb/rows.csv?accessType=DOWNLOAD',
                na_values = 'suppressed')
df_level['cases_per_100K_7_day_count_change'] = df_level['cases_per_100K_7_day_count_change'].str.replace(',','').astype(float)
df_level = df_level[['state_name','county_name','report_date','cases_per_100K_7_day_count_change','percent_test_results_reported_positive_last_7_days']]
us_state_to_abbrev = { 
     "Alabama": "AL", 
     "Alaska": "AK", 
     "Arizona": "AZ", 
     "Arkansas": "AR", 
     "California": "CA", 
     "Colorado": "CO", 
     "Connecticut": "CT", 
     "Delaware": "DE", 
     "Florida": "FL", 
     "Georgia": "GA", 
     "Hawaii": "HI", 
     "Idaho": "ID", 
     "Illinois": "IL", 
     "Indiana": "IN", 
     "Iowa": "IA", 
     "Kansas": "KS", 
     "Kentucky": "KY", 
     "Louisiana": "LA", 
     "Maine": "ME", 
     "Maryland": "MD", 
     "Massachusetts": "MA", 
     "Michigan": "MI", 
     "Minnesota": "MN", 
     "Mississippi": "MS", 
     "Missouri": "MO", 
     "Montana": "MT", 
     "Nebraska": "NE", 
     "Nevada": "NV", 
     "New Hampshire": "NH", 
     "New Jersey": "NJ", 
     "New Mexico": "NM", 
     "New York": "NY", 
     "North Carolina": "NC", 
     "North Dakota": "ND", 
     "Ohio": "OH", 
     "Oklahoma": "OK", 
     "Oregon": "OR", 
     "Pennsylvania": "PA", 
     "Rhode Island": "RI", 
     "South Carolina": "SC", 
     "South Dakota": "SD", 
     "Tennessee": "TN", 
     "Texas": "TX", 
     "Utah": "UT", 
     "Vermont": "VT", 
     "Virginia": "VA", 
     "Washington": "WA", 
     "West Virginia": "WV", 
     "Wisconsin": "WI", 
     "Wyoming": "WY", 
     "District of Columbia": "DC", 
     "American Samoa": "AS", 
     "Guam": "GU", 
     "Northern Mariana Islands": "MP", 
     "Puerto Rico": "PR", 
     "United States Minor Outlying Islands": "UM", 
     "U.S. Virgin Islands": "VI", 
}
df_level['state_name'] = df_level['state_name'].replace(us_state_to_abbrev)
df_level['report_date'] = pd.to_datetime(df_level['report_date'])
df_level['days'] = df_level['report_date']-df_level['report_date'].min()
df_level['day_c'] = df_level['days'].map(getdays)



df_vaccination = pd.read_csv('https://data.cdc.gov/api/views/unsk-b7fc/rows.csv?accessType=DOWNLOAD')

df_vaccination = df_vaccination[['Date','Location', 'Series_Complete_Pop_Pct', 'Administered_Dose1_Pop_Pct']]

dic = {'Fully vaccinated':'Series_Complete_Pop_Pct',
      'At least 1 dose':'Administered_Dose1_Pop_Pct'}
text_dic = {'Fully vaccinated' : 'text_fully_vac',
            'At least 1 dose' : 'text_1dose'}

#graph 1
df_vaccination['Date'] = pd.to_datetime(df_vaccination['Date'])
df_vaccination['days'] = df_vaccination['Date']-df_vaccination['Date'].min()
df_vaccination['day_c'] = df_vaccination['days'].map(getdays)
for col in df_vaccination.columns:
    df_vaccination[col] = df_vaccination[col].astype(str)


df_vaccination['day_c'] = df_vaccination['day_c'].astype(int)

df_vaccination['text_1dose'] = df_vaccination['Location'] + '<br>' + \
    'At least one dose ' + ':' + df_vaccination['Administered_Dose1_Pop_Pct'] + '<br>'
df_vaccination['text_fully_vac'] = df_vaccination['Location'] + '<br>' + \
    'Fully vaccinated ' + ':' + df_vaccination['Series_Complete_Pop_Pct'] + '<br>'
#df_vaccination['Date'] = df_vaccination['Date'] + 'T00:00:00'
df_vaccination['Date'] = pd.to_datetime(df_vaccination['Date'])



app.layout = html.Div([
    

    #graph 1
    html.Div([
        html.Div([
            html.Div([
            html.H1(children='COVID-19 vaccine rates by state')
        ], style={'width': '100%', 'text-align': 'center', 'display': 'inline-block'}),
            html.Div([
                dcc.RadioItems(
                    id='y-type',
                    options=[{'label': i, 'value': i} for i in ['Fully vaccinated', 'At least 1 dose']],
                    value='Fully vaccinated',
                    labelStyle={'display': 'center'}
                )
            ], style={'width': '100%', 'text-align': 'center', 'display': 'inline-block'})
        ]),

        dcc.Graph(id='vac-graphic'),
        html.Div([
            dcc.Slider(
                id='Date-slider',
                min=df_vaccination['day_c'].min(),
                max=df_vaccination['day_c'].max(),
                value=df_vaccination['day_c'].max(),
         #       marks={days: days for days in df_vaccination['days'].unique()},
                step=1,
                tooltip={"placement": "bottom", "always_visible": True},
            ),   
            html.Div(id='updatemode-output-container', style={'text-align': 'center','margin-top': 20})
        ])

    ]),    

    html.Hr(),


    html.Div([
        html.Div([

            html.Div([
                dcc.Dropdown(
                    id='left-state-column',
                    options=[{'label': i, 'value': i} for i in available_indicators_state],
                    value='IL'
                ),
                dcc.RadioItems(
                    id='left-selection-type',
                    options=[{'label': i, 'value': i} for i in ['Name', 'Fully vaccinated','At least 1 dose']],
                    value='Name',
                    labelStyle={'display': 'inline-block', 'marginTop': '5px'}
                ),
                dcc.RadioItems(
                    id='left-sort-type',
                    options=[{'label': i, 'value': i} for i in ['Increasing', 'Decreasing']],
                    value='Increasing',
                    labelStyle={'display': 'inline-block', 'marginTop': '5px'}
                )
            ],
            style={'width': '49%', 'display': 'inline-block'}),

            html.Div([
                dcc.Dropdown(
                    id='right-county-column'
                ),
                dcc.RangeSlider(
                    id='right-date-slider',
                    min=df_level['day_c'].min(),
                    max=df_level['day_c'].max(),
                    value=[df_level['day_c'].min(),df_level['day_c'].max()],
                    tooltip={"placement": "bottom", "always_visible": True},
                ),
                
            ], style={'width': '49%', 'float': 'right', 'display': 'inline-block'}),
            
        ], style={
            'padding': '10px 5px'
        }),

        
        html.Div([
            html.Div([
                html.Div(
                    id = 'filter_data',style={'width': '50%', 'display': 'inline-block'},

                ),
                html.Div(
                    dcc.Slider(
                        id='left-date-slider',
                        min=df['day_c'].min(),
                        max=df['day_c'].max(),
                        value=df['day_c'].max(),
                #        marks={str(year): str(year) for year in df['days'].unique()},
                        tooltip={"placement": "bottom", "always_visible": True},
                        step=1
                    )
                ),
                html.Div(id='left-updatemode-output-container', style={'text-align': 'left','margin-top': 20})
            ], style={'width': '49%', 'display': 'inline-block'}),    
            

            html.Div([
                dcc.Graph(id='x-time-series'),
                dcc.Graph(id='y-time-series'),
            ], style={'width': '49%', 'float': 'right', 'display': 'inline-block'}),



        ])        
    ])


])
        


@app.callback(
    Output('updatemode-output-container', 'children'),
    Output('vac-graphic', 'figure'),
    Input('y-type', 'value'),
    Input('Date-slider', 'value')
    )

def update_graph(y_type,Date_value):
    graph_df_vaccination = df_vaccination[df_vaccination['day_c'] == Date_value]
    df_vaccination_z = graph_df_vaccination[dic[y_type]].astype(float)
    fig = go.Figure(data=go.Choropleth(
        locations=graph_df_vaccination['Location'],
        z=df_vaccination_z,
        locationmode='USA-states',
        colorscale='Reds',
        autocolorscale=False,
        text=graph_df_vaccination[text_dic[y_type]], # hover text
        marker_line_color='white', # line markers between states
        colorbar_title="percentage of vaccinated"
    ))

    fig.update_layout(
        geo = dict(
            scope='usa',
            projection=go.layout.geo.Projection(type = 'albers usa'),
            showlakes=True, # lakes
            lakecolor='rgb(255, 255, 255)'),
    )
    children = 'Start from 2020-12-13, pointed date : {}'.format(str(df_vaccination.loc[df_vaccination['day_c'] == Date_value, 'Date'].mean()))

    return children, fig  


@app.callback(
    Output('right-county-column', 'options'),
    Input('left-state-column', 'value'))
def set_county_options(state_name):
    available_indicators_county = df.loc[df['Recip_State'] == state_name,'Recip_County'].unique()
    return [{'label': i, 'value': i} for i in available_indicators_county]

@app.callback(
    Output('right-county-column', 'value'),
    Input('right-county-column', 'options'))
def set_county_value(available_options):
    return available_options[0]['value'] 


@app.callback(
    Output('filter_data', 'children'),
    Output('x-time-series', 'figure'),
    Output('y-time-series', 'figure'),
    Output('left-updatemode-output-container', 'children'),
    [Input('left-state-column', 'value'),
     Input('left-selection-type', 'value'),
     Input('left-sort-type', 'value'),
     Input('right-county-column', 'value'),
     Input('right-date-slider', 'value'),     
     Input('left-date-slider', 'value'),])

def update_graph(state_name, type_name,sort_type,
                couny_name,right_date_value,left_date_value):
    df_state = df[df['Recip_State'] == state_name]
    dic_sort = {
        'Name' : 'Recip_County',
        'Fully vaccinated' : 'Series_Complete_Pop_Pct',
        'At least 1 dose' : 'Administered_Dose1_Pop_Pct',
        'Increasing' : True,
        'Decreasing' : False
    }
    df_state = df_state.sort_values(dic_sort[type_name],ascending=dic_sort[sort_type])
    df_state = df_state[df_state['day_c'] == left_date_value]
    df_state_clean = df_state.drop(columns = ['Date','Recip_State','days','day_c'])
    df_state_clean = df_state_clean.rename(columns = {'Recip_County':'Name',
                    'Series_Complete_Pop_Pct':'Fully (%)',
                    'Administered_Dose1_Pop_Pct':'At least 1 (%)'})
    children = generate_table(df_state_clean)
    
    df_level_fig = df_level[(df_level['state_name'] == state_name)&(df_level['county_name'] == couny_name)]
    df_level_fig = df_level_fig[df_level_fig['day_c'].between(right_date_value[0],right_date_value[1])]
    df_level_fig = df_level_fig.sort_values('day_c')
    fig1 = px.line(df_level_fig, x="day_c", y="percent_test_results_reported_positive_last_7_days", 
                    labels = {'day_c' : 'Date','percent_test_results_reported_positive_last_7_days' : 'percentage'},
                    title='Daily Positivity - 7 day moving average')
    fig2 = px.line(df_level_fig, x="day_c", y="cases_per_100K_7_day_count_change", 
                    labels = {'day_c' : 'Date', 'cases_per_100K_7_day_count_change' : 'case number'},
                    title='Daily new cases - 7 day moving average(per 100K)')


    children1 = 'Start from 2020-12-13, end by : {}'.format(str(df_state.loc[df_state['day_c'] == left_date_value, 'Date'].mean()))


    return [children], fig1, fig2, children1


if __name__ == '__main__':
    app.run_server(debug=True)