require "json"
require "date"




## I/O
########################

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




## Billing
#############################

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

##
# Computes the commission for each contributor based on the price
#
# param price the price of a rental
# param nbDays the number of days of the rental
def getCommission(price, nbDays)
  comm = 0.3 * price;
  commInsurance = comm / 2;
  commRoadside = 100 * nbDays;
  commDrivy = comm - commInsurance - commRoadside;
  commission = {"insurance_fee" => commInsurance.to_i, "assistance_fee" => commRoadside.to_i, "drivy_fee" => commDrivy.to_i}
end

##
# Computes the options
#
# param nbDays the number of days of the rental
# param deductibleOption whether the customer opted in for a reduced deductible in case of accident
def getOptions(nbDays, deductibleOption)
  # deductible reduction option
  deductibleReduction = 0;
  if (deductibleOption)
    deductibleReduction = (nbDays * 400);  
  end
  
  # aggregation of options
  options = {"deductible_reduction" => deductibleReduction}
end

##
# Computes the transactions for each actor
#
# param price the price of the rental, without the options
# param comm the multiple commissions: insurance_fee, assistance_fee, drivy_fee
# param options the options: deductible_reduction
# return a list of bank transactions, with information: who, type, amount
def getActions(price, comm, options);
  actions = [];
  # driver
  actions.push({
    "who" => "driver",  
    "type" => "debit",
    "amount" => (price + options["deductible_reduction"]).to_i});
  # owner
  actions.push({
    "who" => "owner",  
    "type" => "credit",
    "amount" => (price - comm["insurance_fee"] - comm["assistance_fee"] - comm["drivy_fee"]).to_i});
  # insurance
  actions.push({
    "who" => "insurance",  
    "type" => "credit",
    "amount" => comm["insurance_fee"]});
  # assistance
  actions.push({
    "who" => "assistance",  
    "type" => "credit",
    "amount" => comm["assistance_fee"]});
  # drivy
  actions.push({
    "who" => "drivy",  
    "type" => "credit",
    "amount" => (comm["drivy_fee"] + options["deductible_reduction"]).to_i});
  actions;  
end




## Script
#############################

data = readJson("data.json");

# making cars accessible as map (car_id > car)
cars = [];
for car in data["cars"] do
  cars[car["id"]] = car;
end

output = {"rentals" => []};
for rental in data["rentals"] do
  ## extracting rental information

  # both first and last days are billed
  nbDays = (Date.parse(rental["end_date"]) - Date.parse(rental["start_date"])).to_i + 1; 
  pricePerDay = cars[rental["car_id"]]["price_per_day"];
  pricePerKm = cars[rental["car_id"]]["price_per_km"];
  nbKms = rental["distance"];
  deductibleOption = rental["deductible_reduction"];
  
  ## generating billing information
  
  price = getPrice(nbDays, pricePerDay, pricePerKm, nbKms);
  comm = getCommission(price, nbDays);
  options = getOptions(nbDays, deductibleOption);
  actions = getActions(price, comm, options);
  
  ## generating the output based on billing computations
  
  output["rentals"].push(
    "id" => rental["id"], 
    "actions" => actions);
end

writeJson(output, "myoutput.json");


