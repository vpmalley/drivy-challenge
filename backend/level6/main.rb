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




## Extraction
#############################

##
# Extracts the information from the rental and cars data to prepare for billing
# 
# param rental the data about the current rental
# param cars the data about all available cars
# return the rentalInfo that was extracted, with members: 
#   id, nbDays, pricePerDay, pricePerKm, nbKms, deductibleOption
def extractRentalInfo(rental, cars)
  rentalInfo = {};
  rentalInfo["id"] = rental["id"]
  # both first and last days are billed
  rentalInfo["nbDays"] = (Date.parse(rental["end_date"]) - Date.parse(rental["start_date"])).to_i + 1; 
  rentalInfo["pricePerDay"] = cars[rental["car_id"]]["price_per_day"];
  rentalInfo["pricePerKm"] = cars[rental["car_id"]]["price_per_km"];
  rentalInfo["nbKms"] = rental["distance"];
  rentalInfo["deductibleOption"] = rental["deductible_reduction"];
  rentalInfo;
end




## Billing
#############################

##
# Computes the price for the number of days the price is discounted.
# Discounts are defined by a dayThreshold (days after this number are discounted) 
#   and a discount (the discount on the pricePerDay, as a number between 0 and 1)
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
# return the price of a rental as an integer, in cents
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
# Computes the commission for each contributor
#
# param price the price of a rental
# param nbDays the number of days of the rental
# return the commissions, as a Hash containing the following fields:
#   insurance_fee, assistance_fee, drivy_fee
def getCommission(price, nbDays)
  comm = 0.3 * price;
  commInsurance = comm / 2;
  commRoadside = 100 * nbDays;
  commDrivy = comm - commInsurance - commRoadside;
  commission = {
    "insurance_fee" => commInsurance.to_i,
    "assistance_fee" => commRoadside.to_i, 
    "drivy_fee" => commDrivy.to_i
  }
end

##
# Computes the options
#
# param nbDays the number of days of the rental
# param deductibleOption whether the customer opted in for a reduced deductible in case of accident
# return the options and the corresponding billed amount
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
# return a list of bank transactions, with fields: 
#   who, type, amount
def getActions(price, comm, options)
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

##
# Computes the modifications to bill to the different actors for a rental
#
# param initRentalInfo the processed information for the initial rental
# param newRentalInfo the processed information for the rental with modifications
# return the actions to bill to the different actors
def getRentalModActions(initRentalInfo, newRentalInfo)
  actions = [];
    
  # we first extract data and store it in Hashes, mapped by the actor
  initActions = {};
  for initAction in initRentalInfo["actions"]
    initActions[initAction["who"]] = initAction;
  end
  
  # comparing the initial actions and the expected new rental, computing the difference
  for newAction in newRentalInfo["actions"]
    initAction = initActions[newAction["who"]]
    
    balance = (newAction["amount"] - initAction["amount"]).to_i;
    type = newAction["type"];
    if (balance < 0)
      if ("debit" == newAction["type"])
        type = "credit";
      else
        type = "debit";
      end
    end
    
    actions.push({
      "who" => newAction["who"],  
      "type" => type,
      "amount" => balance.abs
    });
  end
  actions;
end


##
# Extracts rental data and computes billing
#
# param rental the data specifically about the current rental
# param cars the data about all available cars
# return the rentalInfo that was extracted and computed, with members: 
#   id, nbDays, pricePerDay, pricePerKm, nbKms, deductibleOption, price, commission, options, actions
def processRental(rental, cars)
  rentalInfo = extractRentalInfo(rental, cars);
  
  # generating billing information
  rentalInfo["price"] = getPrice(rentalInfo["nbDays"], rentalInfo["pricePerDay"], rentalInfo["pricePerKm"], rentalInfo["nbKms"]);
  rentalInfo["commission"] = getCommission(rentalInfo["price"], rentalInfo["nbDays"]);
  rentalInfo["options"] = getOptions(rentalInfo["nbDays"], rentalInfo["deductibleOption"]);
  rentalInfo["actions"] = getActions(rentalInfo["price"], rentalInfo["commission"], rentalInfo["options"]);
  rentalInfo;
end

##
# Computes the modifications in the billing
# 
# param initRental the base data for the initial rental
# param rentalMod the modifications to base data to apply to the specified rental 
# param initRentalInfo initial rental processed information, including all following fields for each rental:
#   nbDays, pricePerDay, pricePerKm, nbKms, price, commission, options, actions
# param cars information about cars
# return the list of actions to bill to the actors, each containing the fields:
#   who, type, amount
def processModifications(initRental, rentalMod, initRentalInfo, cars)
  newRental = initRental.merge(rentalMod);
  newRentalInfo = processRental(newRental, cars);
  getRentalModActions(initRentalInfo, newRentalInfo);
end




## Script
#############################

data = readJson("data.json");

# making cars accessible as Hash (car_id => car)
cars = [];
for car in data["cars"] do
  cars[car["id"]] = car;
end
# making rentals accessible as Hash (rental_id => rental)
rentals = [];
for rental in data["rentals"] do
  rentals[rental["id"]] = rental;
end

# processing rentals
processedRentals = {};
for rental in data["rentals"] do
  rentalInfo = processRental(rental, cars);
  processedRentals[rental["id"]] = rentalInfo;
end

# processing rental modifications
processedModifs = [];
for rentalMod in data["rental_modifications"] do
  rentalId = rentalMod["rental_id"];
  processedModifs.push({
    "id" => rentalMod["id"],
    "rental_id" => rentalId,
    "actions" => processModifications(rentals[rentalId], rentalMod, processedRentals[rentalId], cars)
  });
  
end

# outputting rental modifications
output = {"rental_modifications" => processedModifs};
writeJson(output, "myoutput.json");


