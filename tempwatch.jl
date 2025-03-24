using Bonito
using CSV
using DataFrames
using JSON
using PlotlyJS
import Bonito.TailwindDashboard as D
cities_data = CSV.File("cities.csv") |> DataFrame

map_lat_min = 8.0
map_lat_max = 37.0
map_lng_min = 68.0
map_lng_max = 97.0

original_map_width = 800
original_map_height = 800
scale_factor = 0.7
map_width = original_map_width * scale_factor
map_height = original_map_height * scale_factor

function latlng_to_pixels(lat, lng, lat_min, lat_max, lng_min, lng_max, width, height)
    x = ((lng - (lng_min - 1.2)) / (lng_max - lng_min + 2.8)) * width
    y = ((lat_max + 1.2 - lat) / (lat_max - lat_min + 1.5)) * height
    y = y - 50
    return (x, y)
end

cities_data[!, :x] = [latlng_to_pixels(row.lat, row.lng, map_lat_min, map_lat_max, map_lng_min, map_lng_max, original_map_width, original_map_height)[1] for row in eachrow(cities_data)]
cities_data[!, :y] = [latlng_to_pixels(row.lat, row.lng, map_lat_min, map_lat_max, map_lng_min, map_lng_max, original_map_width, original_map_height)[2] for row in eachrow(cities_data)]

cities_data[!, :x] .= cities_data[!, :x] .* scale_factor
cities_data[!, :y] .= cities_data[!, :y] .* scale_factor

app = App() do session
    map_img = DOM.img(
        src="https://i.postimg.cc/prY8k5XX/india-map.png",  
        style="""
            width: $(map_width)px;
            height: $(map_height)px;
            display: block;
            position: relative;
        """,
        alt="India Map"
    )
    
    data_display = DOM.div(
        id="data-display",
        style="""
            font-size: 18px;
            color: blue;
        """
    )
    
    temp_plot_display = DOM.div(
        id="temp-plot-display",
        style="""
            width: 100%;
            height: 400px;
        """
    )
    
    humidity_plot_display = DOM.div(
        id="humidity-plot-display",
        style="""
            width: 100%;
            height: 400px;
        """
    )
    
    dots = [
        DOM.div(
            style="""
                position: absolute;
                width: 7px;
                height: 7px;
                background-color: red;
                border-radius: 50%;
                left: $(row.x)px;
                top: $(row.y)px;
                cursor: pointer;
            """,
            onclick="handleDotClick($(row.Column1))"
        )
        for row in eachrow(cities_data)
    ]
    
    cities_js_data = [Dict("Column1" => row.Column1, "city" => row.city) for row in eachrow(cities_data)]
    
    js_script = """
        const citiesData = $(json(cities_js_data));
        
        async function handleDotClick(cityIndex) {
            const city = citiesData.find(c => c.Column1 === cityIndex).city;
            const dataDisplay = document.getElementById("data-display");
            if (dataDisplay) {
                dataDisplay.innerText = "Loading temperature and humidity data for " + city + "...";
            } else {
                console.error("Element with id 'data-display' not found!");
            }
            
            try {
                const response = await fetch(`https://raw.githubusercontent.com/Priynsh/indiabonito/main/Dataset2/\${city.toLowerCase()}.csv`);
                if (!response.ok) {
                    throw new Error("Failed to load data for " + city);
                }
                const csvData = await response.text();
                const rows = csvData.split("\\n").slice(1);
                const dates = [];
                const temperatures = [];
                const humidities = [];
                rows.forEach(row => {
                    const columns = row.split(",");
                    if (columns.length >= 4) {
                        dates.push(columns[1]);
                        temperatures.push(parseFloat(columns[2]));
                        humidities.push(parseFloat(columns[3]));
                    }
                });
                
                if (dataDisplay) {
                    dataDisplay.innerText = "Temperature and humidity data for " + city;
                }
                
                const tempPlotData = [{
                    x: dates,
                    y: temperatures,
                    type: 'scatter',
                    mode: 'lines+markers',
                    name: 'Temperature (°C)'
                }];
                const tempLayout = {
                    title: `Hourly Temperature for ` + city,
                    xaxis: { title: 'Time' },
                    yaxis: { title: 'Temperature (°C)' }
                };
                console.log("Plotting temperature data...");
                Plotly.newPlot('temp-plot-display', tempPlotData, tempLayout);
                
                const humidityPlotData = [{
                    x: dates,
                    y: humidities,
                    type: 'scatter',
                    mode: 'lines+markers',
                    name: 'Relative Humidity (%)'
                }];
                const humidityLayout = {
                    title: `Hourly Relative Humidity for ` + city,
                    xaxis: { title: 'Time' },
                    yaxis: { title: 'Relative Humidity (%)' }
                };
                console.log("Plotting humidity data...");
                Plotly.newPlot('humidity-plot-display', humidityPlotData, humidityLayout);
            } catch (error) {
                console.error("Error loading or plotting data:", error);
                if (dataDisplay) {
                    dataDisplay.innerText = "Error loading data for " + city;
                }
            }
        }
    """
    
    return DOM.div(
        D.FlexRow(
            DOM.div(
                map_img,
                dots,
                style="flex: 1; margin-right: 20px;"
            ),
            DOM.div(
                data_display,
                D.FlexCol(
                    temp_plot_display,
                    humidity_plot_display
                ),
                style="flex: 1;"
            )
        ),
        DOM.script(src="https://cdn.plot.ly/plotly-latest.min.js"),
        DOM.script(js_script),
        style="margin: 0; padding: 0; min-height: 100vh;"
    )
end

port = 8080
url = "127.0.0.1"
println("Starting Bonito server on http://$url:$port...")
server = Bonito.Server(app, url, port)

while true
    sleep(1)
end