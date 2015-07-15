require "json"
require "date"

##
# Reads the file located at dataFilePath and parses its JSON content, returns the matching data structure
def readJson(dataFilePath)
  dataFile = File.new(dataFilePath, "r");
  data = JSON.load(dataFile);
  dataFile.close();
  data;
end

##
# Writes the output object into the file located at outputFilePath as JSON content
def writeJson(output, outputFilePath)
  outFile = File.new(outputFilePath, "w");
  JSON.dump(output, outFile);
  outFile.close();
end


##
# Computes the price for the number of days the price is discounted.
# Discounts are defined by a dayThreshold ( days after this number are discounted) and a discount (the discount on the pricePerDay, as a number between 0 and 1)
#
# param nbDays the number of days of the rental
# param pricePerDay the price per day applied to the rental
# param dayThreshold beyond this number of days, the discount applies
# param discount the discount rate to apply, as a number between 0 and 1
# return the discounted price for the days beyond the threshold

def discountedPrice(nbDays, pricePerDay, dayThreshold, discount)
  (1 - discount) * (nbDays - dayThreshold) * pricePerDay;
end

##
# Computes the price of a rental
#
# param nbDays the number of days of the rental
# param pricePerDay the price per rental (cents)
# param pricePerKm the price per km during the rental (cents)
# param nbKms the distance during the rental
def getPrice(nbDays, pricePerDay, pricePerKm, nbKms)
  price = nbKms * pricePerKm;
  
  if nbDays > 10
    price += discountedPrice(nbDays, pricePerDay, 10, 0.5);
    nbDays = 10;
  end
  if nbDays > 4
    price += discountedPrice(nbDays, pricePerDay, 4, 0.3);
    nbDays = 4;
  end
  if nbDays > 1
    price += discountedPrice(nbDays, pricePerDay, 1, 0.1);
    nbDays = 1;
  end
  price += nbDays * pricePerDay;
end

data = readJson("data.json");

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
  
  price = getPrice(nbDays, pricePerDay, pricePerKm, nbKms);
  
  # generating the output based on computations
  output["rentals"].push("id" => rental["id"], "price" => price.to_i);
end

writeJson(output, "myoutput.json");


