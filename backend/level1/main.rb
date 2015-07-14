require "json"
require "date"

# your code

dataFile = File.new("data.json", "r");
data = JSON.load(dataFile);
dataFile.close();

# making cars accessible as map (car_id > car)
cars = [];
for car in data["cars"] do
  cars[car["id"]] = car;
end

# extracting rental information and storing it as a map
output = {"rentals" => []};
for rental in data["rentals"] do
  # both first and last days are billed
  nbDays = (Date.parse(rental["end_date"]) - Date.parse(rental["start_date"])).to_i + 1; 
  pricePerDay = cars[rental["car_id"]]["price_per_day"];
  pricePerKm = cars[rental["car_id"]]["price_per_km"];
  nbKms = rental["distance"];
  
  price = nbDays * pricePerDay + nbKms * pricePerKm;
  output["rentals"].push("id" => rental["id"], "price" => price);
end

# exporting rental info
outFile = File.new("myoutput.json", "w");
JSON.dump(output, outFile);
outFile.close();
