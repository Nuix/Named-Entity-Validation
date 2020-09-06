# encoding: UTF-8
# Where you currently have the folder where the json and icon subdirectory would be.
# Worker Side Scripts won't know where to find these so you'll need to pass this along.
$stagingFolder=nil # Please update this to be the literal path. This is so workers know where to pick up the definitions.json, return back __dir__ to reset this script. 
$groups=[] # .group , only include these (if empty all included, example "Australia"
$specific=[] # .title , groups as above + these specific items, example "Australia-ABN"
$debug=false # if you want more intense logging on each step of validation.
$useCache=true # store in memory known matches to save time recalculating. COST: More memory consumption.

# Add methods with caution, but most things should be safe.
$savedStates={} # don't put anything in here.
$knownMatches={} # using this as a cache for previously detected ones to save on detection/validation time.. Theoretically known bad values could be placed here in their entity sub group. Careful! Not recommended.
require 'fileutils'

if($stagingFolder.nil?)
	puts "$stagingFolder='" + __dir__ + "'\nPlease update line 4 of the runme.rb script to include the current directory as above"
	$stagingFolder=__dir__ #temporarily using current path to continue running test/import.
	exit
end

# Math adds the param to the current input | Numeric
def add(input,params)
	numeric,unused=params
	return input+numeric
end

# Adds each placement of the weight onto the input | Hash of weighted addition 
def addArray(inputIntArray,params)
	weights,unused=params
	weight=weights[inputIntArray.length().to_s]
	return inputIntArray.map.with_index{|x,i| x + weight[i]}
end

# Adds the saved state to the current input | state name
def addState(input,params)
	key,unused=params
	return input + $savedStates[key]
end

# Multiplies each placement of the weight onto the input | Hash of weighted multiplication (use 0 to ignore field and state if you need to keep said value) 
def applyWeight(inputIntArray,params)
	weights,unused=params
	weight=weights[inputIntArray.length().to_s]
	if(weight == nil)
		raise "Weighting can only happen with equal length of input and weight arrays ( " + inputIntArray.length().to_s + ")"
	end
	if(weight.length() != inputIntArray.length())
		raise "Weighting can only happen with equal length of input and weight arrays ( " + weight.length().to_s + " != " + inputIntArray.length().to_s + ")"
	end
	return inputIntArray.map.with_index{|x,i| x * weight[i]}
end

# Usually used as the last or basic check to confirm the input matches the expected value | expected value
def assertEquals(input,params)
	expectedInput,unused=params
	return input==expectedInput
end

# Used as a check to ensure that the value is within the expected values | array of possible expected values
def assertEqualsAny(input,params)
	params.each do | possibleMatch|
		if(possibleMatch==input)
			return true
		end
	end
	return false
end

# Used as an inversion of assertEquals | banned value
def assertNotEquals(input,params)
	expectedInput,unused=params
	return input!=expectedInput
end

# Compares the current input to a known state | state containing expected value
def assertStateMatches(input,params)
	key,unused=params
	return $savedStates[key]==input
end

# Convert the lettering to a particular case | "up", "down", "capitalize"
def changeCase(inputString,params)
	direction,unused=params
	case(direction)
	when "up"
		return inputString.upcase()
	when "down"
		return inputString.downcase()
	when "capitalize"
		return inputString.capitalize()
	else
		raise "Unknown changeCase paramater"
	end
end

# Output the element from position in the supplied input array | index
def getElementAtPosition(inputArray,params)
	index,unused=params
	return inputArray[index]
end

# Join the input array by a particular char | char or empty string to join with no delimitator
def joinStringArray(inputStringArray,params)
	joinCharacter,unused=params
	return inputStringArray.join(joinCharacter)
end

# Make the input become the saved state | saved state name
def loadState(inputIgnored,params)
	key,unused=params
	return $savedStates[key]
end

# A convenience method for substitueArray for known only int value arrays| an array of strings that can be converted to ints
def mapIntArrayToStringArray(inputIntarray,params)
	unused=params
	return inputIntarray.map{|i|i.to_s}
end

# Apply a modulus against the input and return the remainder | mod value
def modBy(inputInt,params)
	modInt,unused=params
	return inputInt % modInt
end

# Strip out any unwanted values, usually this is aesthetic padding you may find in its natural state | an array of values to be removed
def removeElements(inputArray,params)
	params.each do | removeElement|
		inputArray.delete_if{|thisChar|thisChar==removeElement}
	end
	return inputArray
end

# Save the input against the specific name | specific name to call this state
def saveState(input,params)
	key,unused=params
	$savedStates[key]=input
	return input
end

# Split the input by the param | a single char, or no char to split into chars
def splitIntoChunks(input,params)
	splitChar,unused=params
	return input.split(splitChar)
end

# Caesar cipher. Input is translated based on the provided two exactly the same sized arrays | two arrays of exactly the same size
def substitueArray(inputArray,params)
	originalCharList,outputValueList,unused=params
	if(originalCharList.length() != outputValueList.length())
		raise "Substitution can only happen with equal value input and substitution arrays ( " + originalCharList.length().to_s + " != " + outputValueList.length().to_s + ")"
	end
	return inputArray.map{|place|outputValueList[originalCharList.index(place)]}
end

# Add all the values in the input | an array of numbers
def sumArray(inputINTarray,params)
	return inputINTarray.reduce(0, :+)
end

# Used to translate the entity group and abbreviation into something that Nuix will permit (no spaces!)
def makeSafeEntityName(entityConfiguration)
	return (entityConfiguration["group"] + " " + entityConfiguration["abbreviation"]).gsub(/\s+/, '-')
end

# Where the magic happens... 
# If the entity is not known, return true
# If the entity has no validation steps, return true
# If the entity has already been found in the past... match it with the cache
# Iterate each known step, and save it in the cache.
# Will the cache get too large and kill workers? TBC. Cache can be disabled by $useCache=false
def validateEntity(entityName,stringToCheck)
	if(!($knownMatches.has_key? entityName))
		$knownMatches[entityName]={}
	end
	validationEntity=$standardVerificationSteps.select{|entityConfiguration|makeSafeEntityName(entityConfiguration)==entityName}
	if(validationEntity.length != 1)
		return true # not one of ours?
	else
		validationEntity=validationEntity.first()
	end
	if($debug)
		puts entityName
	end
	if(!(validationEntity.has_key? "validationSteps"))
		if($debug)
			puts "Skipped built-in Entity for validation: " + entityName.to_s
		end
		return true
	end
	begin
		if($knownMatches[entityName].has_key? stringToCheck)
			if($debug)
				puts "Skipped custom Entity for validation (known Result): " + entityName.to_s + " " + stringToCheck + " " + $knownMatches[entityName][stringToCheck].to_s
			end
			return $knownMatches[entityName][stringToCheck]
		end
		$savedStates={} # reset states in case things are hanging around
		validationSteps=validationEntity["validationSteps"]
		result=stringToCheck
		stepResults=[result];
		validationSteps.each_with_index do | step,index |
			if($debug)
				puts "\t" + step["method"] + "(" + result.to_s + "," + step["params"].to_s + ")"
			end
			result=send(step["method"],result,step["params"])
			stepResults.push(result)
			if($debug)
				puts "\t\t" + result.to_s
			end
			if(result==false)
				if($useCache)
					$knownMatches[entityName][stringToCheck]=false
				end
				return false
			end
		end
		if($useCache)
			$knownMatches[entityName][stringToCheck]=true
		end
		return true
	rescue Exception => ex
		puts ex.message
		puts ex.backtrace
		if($useCache)
			$knownMatches[entityName][stringToCheck]=false
		end
		return false
	end
end


$customEntityTypes={}
$standardVerificationSteps={}
def nuix_worker_item_callback_init
	require "json"
	file = File.open($stagingFolder + "/definitions.json", "r:UTF-8", &:read)
	$standardVerificationSteps=JSON.load file
	
	puts "LOADED PACK:\n======================="
	$standardVerificationSteps.each do | entityConfiguration|
		if(($groups.include? entityConfiguration["group"]) || (($groups.size() == 0) && ($specific.size()==0)) || ($specific.include? entityConfiguration["title"]))
			puts "#{entityConfiguration["title"]} (#{entityConfiguration["abbreviation"]}): #{entityConfiguration["description"]}"
			puts "\t" + entityConfiguration["regex"]
			Regexp.new(entityConfiguration["regex"])# Used like this to validate the regex
			safe_nuix_entity_name=makeSafeEntityName(entityConfiguration)
			puts "\t" + safe_nuix_entity_name
			if !($currentCase.nil?)
				if(!$existingEntityLines.include? safe_nuix_entity_name)
					iconFile=$stagingFolder + "/icons/" + entityConfiguration["icon"] + ".png"
					if(File.file?(iconFile))
						FileUtils.cp_r(iconFile, $currentCase.getLocation().to_s + "/Stores/User Data/Named Entities/" + safe_nuix_entity_name + ".png")
					else
						puts "Could not find icon file:" + iconFile
					end
					$existingEntityLines.push("NamedEntities." + safe_nuix_entity_name + ".group = " + entityConfiguration["group"])
					$existingEntityLines.push("NamedEntities." + safe_nuix_entity_name + ".title = " + entityConfiguration["title"].inspect.gsub('"','').encode("UTF-8"))
				end
			end
			$customEntityTypes[safe_nuix_entity_name]=entityConfiguration["regex"]
		end
	end
	if !($currentCase.nil?)
		File.open($entityFile, 'w:UTF-8') { |file| file.write($existingEntityLines.uniq.sort().map{|this|this.encode("utf-8")}.join("\n")) }
	end
	puts "----------------------------------------------\n\n"
end

$pendingLoadingSystemEntities=true
def firstInit(worker_item)
	$pendingLoadingSystemEntities=false
	puts "SYSTEM LOADED PACK:\n======================="
	worker_item.getInstalledNamedEntityTypes().each do | installedEntityName,installedEntityPattern |
		if(!($customEntityTypes.has_key? installedEntityName))
			puts installedEntityName
			puts "\t" + installedEntityPattern.pattern()
			$customEntityTypes[installedEntityName]=installedEntityPattern.pattern()
		end
	end
end

def nuix_worker_item_callback(worker_item)
	$pendingLoadingSystemEntities ? firstInit(worker_item)  : nil
	discoveredEntities=worker_item.scanItemText($customEntityTypes)
	
	if(discoveredEntities.size() > 0)
		worker_item.addNamedEntities(discoveredEntities.select{|entity|validateEntity(entity.getType().to_s,entity.getValue().to_s)})
	end
end


def nuix_worker_item_callback_close
	# Cleanup, finalize, report, etc
end


if !($currentCase.nil?)
	$debug=true
	$entityFile=$currentCase.getLocation().to_s + "/Stores/User Data/Named Entities/regex.properties"
	$existingEntityLines=[]
	puts "importing (generic) entity and images"
	if(File.file?($entityFile))
		$existingEntityLines=File.readlines($entityFile, "r:UTF-8").map{|line|line.strip()}.reject{|line|line.length == 0}.uniq
	end
	nuix_worker_item_callback_init()
end 