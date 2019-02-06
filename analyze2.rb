#!/usr/bin/env ruby

#
# (C) 2019 Erik Oliver
# MIT License:  
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# Idea: Analyze each encounter pack


require 'rubygems'
require 'CSV'
require 'descriptive_statistics'

INPUTCSV='/Users/erik/Documents/Arkham DB Json/outcards.csv' # this is our file with the parsed Arkham DB data
SCENARIOCSV='/Users/erik/Documents/Arkham DB Json/scenario.csv' # this is our file with the encounter sets in each scenario

## Main Program Flow

outname = './encounteranalysis.csv'
outname2 = './scenarioanalysis.csv'

if(!(ARGV.length()>0)) then
	STDERR.print "Usage: analyze.rb numplayers\n"
	exit -1
end
numplayers = ARGV[0]


##
# Step 1: Review the array of cards input and parse out into per-encounter set statisitcs into a hash
##

# slurp up the data into an array to iterate over
cardarray = CSV.read(INPUTCSV, headers: true)

encounterset = Hash.new()
cardarray.each do |row|
	set = row['encounter_code']
	# are we seeing an encounter set for the first time?
	next if (set == nil) # we do not handle cards that are not assigned an encounter set
	if(! encounterset.has_key?(set)) then
		encounterset[set] = Hash.new() 
		encounterset[set][:cardcount] = 0

		encounterset[set][:locationcount] = 0
		encounterset[set][:shroudarray] = Array.new()
		encounterset[set][:cluearray] = Array.new()

		encounterset[set][:enemycount] = 0
		encounterset[set][:enemyfightarray] = Array.new()
		encounterset[set][:enemyevadearray] = Array.new()
		encounterset[set][:enemyhealtharray] = Array.new()
		encounterset[set][:enemydamagearray] = Array.new()
		encounterset[set][:enemyhorrorarray] = Array.new()
		
		encounterset[set][:treacherycount] = 0
		encounterset[set][:willarray] = Array.new()
		encounterset[set][:agilityarray] = Array.new()
		encounterset[set][:combatarray] = Array.new()
		encounterset[set][:intellectarray] = Array.new()
	end
	
	if (row['quantity'] == nil) then
		qty = 1
	else
		qty = row['quantity'].to_i
	end
		
	encounterset[set][:cardcount] += 1*qty
	
	#locations
	if(row['type_code'] == 'location') then
		# count the # of locations
		encounterset[set][:locationcount] += 1*qty if(row['type_code'] == 'location')
		
		i = qty
		while (i >0) 
			encounterset[set][:shroudarray]  << row['shroud'].to_i 
			i -= 1
		end

		# locations - clue scale
		
		if(row['clues'] != nil)
			cluesscale = 1
			cluesscale = numplayers.to_i if (row['cluesscale'] == 'true')
			i = qty
			while (i>0)
				encounterset[set][:cluearray]  << row['clues'].to_i * cluesscale
				i -= 1
			end
		end

	end # locations
	
		
	# enemies
	if(row['type_code'] == 'enemy') then
		encounterset[set][:enemycount] += 1*qty
		if(row['enemy_fight'] != nil) then
			i = qty
			while (i>0)
				encounterset[set][:enemyfightarray] << row['enemy_fight'].to_i
				i -= 1
			end
		end
		
		if(row['enemy_evade'] != nil) then
			i = qty
			while (i>0)
				encounterset[set][:enemyevadearray] << row['enemy_evade'].to_i
				i -= 1
			end
		end

		if(row['enemy_health'] != nil) then
			healthscale = 1
			healthscale = numplayers.to_i if (row['enemy_health_scale'] == 'true')
			
			i = qty
			while (i>0)
				encounterset[set][:enemyhealtharray] << row['enemy_health'].to_i*healthscale
				i -= 1
			end
		end

		if(row['enemy_damage'] != nil) then
			i = qty
			while (i>0)
				encounterset[set][:enemydamagearray] << row['enemy_damage'].to_i
				i -= 1
			end
		end

		if(row['enemy_horror'] != nil) then
			i = qty
			while (i>0)
				encounterset[set][:enemyhorrorarray] << row['enemy_horror'].to_i
				i -= 1
			end
		end
		
	end # enemies
	
	
	# treachery
	if(row['type_code'] == 'treachery' && (row['subtype'] == nil || row['subtype'] == '') ) then
		encounterset[set][:treacherycount] += 1*qty 
		
		i = qty
		while (i>0)
			encounterset[set][:willarray] << row['calcwilltest'].to_i if(row['calcwilltest'] != nil)
			encounterset[set][:agilityarray] << row['calcagilitytest'].to_i if(row['calcagilitytest'] != nil)
			encounterset[set][:combatarray] << row['calcombattest'].to_i if(row['calcombattest'] != nil)
			encounterset[set][:intellectarray] << row['calcintellecttest'].to_i if(row['calcintellecttest'] != nil)
			
			i -= 1
		end 		
	end # treacheries
end

##
# Step 2: Write out per encounter set information
##

HEADINGS = %w(
	encounter_code
	cardcount
	locationcount
	shroudarray
	cluearray
	enemycount
	enemyfightarray
	enemyevadearray
	enemyhealtharray
	enemydamagearray
	enemyhorrorarray
	treacherycount
	willarray
	agilityarray
	combatarray
	intellectarray
)

of = CSV.open(outname,'w')
of << ['# of players =',numplayers]
of << []
of << HEADINGS

encounterset.each do |k,v|

	averageshroud = v[:totalshroud].to_f/v[:locationcount].to_f
	averageshroud = nil if(averageshroud.nan?())

	averageclues = v[:totalclues].to_f/v[:locationcount].to_f
	averageclues = nil if(averageclues.nan?())


	of << [
		k,
		v[:cardcount],
		v[:locationcount],
		v[:shroudarray].join(','),
		v[:cluearray].join(','),
		v[:enemycount],
		v[:enemyfightarray].join(','),
		v[:enemyevadearray].join(','),
		v[:enemyhealtharray].join(','),
		v[:enemydamagearray].join(','),
		v[:enemyhorrorarray].join(','),
		v[:treacherycount],
		v[:willarray].join(','),
		v[:agilityarray].join(','),
		v[:combatarray].join(','),
		v[:intellectarray].join(',')
	]
end

of.close()

##
# Step 3: Combine on a per scenario basis
##
scenarioarray = CSV.read(SCENARIOCSV, headers: true)
scenariohash = Hash.new()

scenarioarray.each do |row|
	scenario = row['scenario']
	# each row of the scenario file calls out 1 encounter set to use with a given scenario
	if(! scenariohash.has_key?(scenario)) then
		scenariohash[scenario] = Hash.new()
		scenariohash[scenario][:pack] = row['pack_code']
		scenariohash[scenario][:locationcount] = 0
		scenariohash[scenario][:shroudarray] = Array.new()
		scenariohash[scenario][:cluearray] = Array.new()

		scenariohash[scenario][:enemycount] = 0
		scenariohash[scenario][:enemyfightarray] = Array.new()
		scenariohash[scenario][:enemyevadearray] = Array.new()
		scenariohash[scenario][:enemyhealtharray] = Array.new()
		scenariohash[scenario][:enemydamagearray] = Array.new()
		scenariohash[scenario][:enemyhorrorarray] = Array.new()
		
		scenariohash[scenario][:treacherycount] = 0
		scenariohash[scenario][:willarray] = Array.new()
		scenariohash[scenario][:agilityarray] = Array.new()
		scenariohash[scenario][:combatarray] = Array.new()
		scenariohash[scenario][:intellectarray] = Array.new()
	end
	
	# locations

	scenariohash[scenario][:locationcount]  += encounterset[row['encounter_code']][:locationcount]
	scenariohash[scenario][:shroudarray] << encounterset[row['encounter_code']][:shroudarray]
	scenariohash[scenario][:cluearray] << encounterset[row['encounter_code']][:cluearray]
	
	# enemies 
	scenariohash[scenario][:enemycount]  += encounterset[row['encounter_code']][:enemycount]
	scenariohash[scenario][:enemyfightarray] << encounterset[row['encounter_code']][:enemyfightarray]
	scenariohash[scenario][:enemyevadearray] << encounterset[row['encounter_code']][:enemyevadearray]
	scenariohash[scenario][:enemyhealtharray] << encounterset[row['encounter_code']][:enemyhealtharray]
	scenariohash[scenario][:enemydamagearray] << encounterset[row['encounter_code']][:enemydamagearray]
	scenariohash[scenario][:enemyhorrorarray] << encounterset[row['encounter_code']][:enemyhorrorarray]
	
	# treachery tests
	scenariohash[scenario][:treacherycount] += encounterset[row['encounter_code']][:treacherycount]
	scenariohash[scenario][:willarray] << encounterset[row['encounter_code']][:willarray]
	scenariohash[scenario][:intellectarray] << encounterset[row['encounter_code']][:intellectarray]
	scenariohash[scenario][:combatarray] << encounterset[row['encounter_code']][:combatarray]
	scenariohash[scenario][:agilityarray] << encounterset[row['encounter_code']][:agilityarray]
	
end


###
# Step 4: Write out per scenario data
###

HEADINGS2 = %w(
	pack
	scenario
	locationcount
	shroudarray
	shroudmedian
	shroudmean
	shroudstddev
	shroudmode
	shroudmin
	shroudmax
	cluetotal
	cluearray
	cluemedian
	cluemean
	cluestddev
	cluemode
	cluemin
	cluemax
	enemycount
	enemyfightarray
	enemyfightmedian
	enemyfightmean
	enemyfightstddev
	enemyfightmode
	enemyfightmin
	enemyfightmax
	enemyevadearray
	enemyevademedian
	enemyevademean
	enemyevadestddev
	enemyevademode
	enemyevademin
	enemyevademax
	enemyhealtharray
	enemyhealthmedian
	enemyhealthmean
	enemyhealthstddev
	enemyhealthmode
	enemyhealthmin
	enemyhealthmax
	enemydamagearray
	enemydamagemedian
	enemydamagemean
	enemydamagestddev
	enemydamagemode
	enemydamagemin
	enemydamagemax
	enemyhorrorarray
	enemyhorrormedian
	enemyhorrormean
	enemyhorrorstddev
	enemyhorrormode
	enemyhorrormin
	enemyhorrormax
	treacherycount
	willcount
	willtests
	willmedian
	willmean
	willstddev
	willmode
	willmin
	willmax	
	intellectcount
	intellecttests
	intellectmedian
	intellectmean
	intellectstddev
	intellectmode
	intellectmin
	intellectmax	
	combatcount
	combattests
	combatmedian
	combatmean
	combatstddev
	combatmode
	combatmin
	combatmax	
	agilitycount
	agilitytests
	agilitymedian
	agilitymean
	agilitystddev
	agilitymode
	agilitymin
	agilitymax	
	
)


of2 = CSV.open(outname2,'w')

of2 << ['# of players =',numplayers]
of2 << []
of2 << HEADINGS2

scenariohash.each do |k,v|
	scenariohash[k][:shroudarray].flatten!
	scenariohash[k][:cluearray].flatten!
	scenariohash[k][:enemyfightarray].flatten!
	scenariohash[k][:enemyevadearray].flatten!
	scenariohash[k][:enemyhealtharray].flatten!
	scenariohash[k][:enemydamagearray].flatten!
	scenariohash[k][:enemyhorrorarray].flatten!
	scenariohash[k][:willarray].flatten!
	scenariohash[k][:intellectarray].flatten!
	scenariohash[k][:combatarray].flatten!
	scenariohash[k][:agilityarray].flatten!
		
	of2 << [
		v[:pack],
		k,
		scenariohash[k][:locationcount],
		scenariohash[k][:shroudarray],
		scenariohash[k][:shroudarray].median,
		scenariohash[k][:shroudarray].mean.round(2),
		scenariohash[k][:shroudarray].standard_deviation.round(2),
		scenariohash[k][:shroudarray].mode,
		scenariohash[k][:shroudarray].min,
		scenariohash[k][:shroudarray].max,
		scenariohash[k][:cluearray].sum,
		scenariohash[k][:cluearray],
		scenariohash[k][:cluearray].median,
		scenariohash[k][:cluearray].mean.round(2),
		scenariohash[k][:cluearray].standard_deviation.round(2),
		scenariohash[k][:cluearray].mode,
		scenariohash[k][:cluearray].min,
		scenariohash[k][:cluearray].max,
		scenariohash[k][:enemycount],
		scenariohash[k][:enemyfightarray],
		scenariohash[k][:enemyfightarray].median,
		scenariohash[k][:enemyfightarray].mean.round(2),
		scenariohash[k][:enemyfightarray].standard_deviation.round(2),
		scenariohash[k][:enemyfightarray].mode,
		scenariohash[k][:enemyfightarray].min,
		scenariohash[k][:enemyfightarray].max,
		scenariohash[k][:enemyevadearray],
		scenariohash[k][:enemyevadearray].median,
		scenariohash[k][:enemyevadearray].mean.round(2),
		scenariohash[k][:enemyevadearray].standard_deviation.round(2),
		scenariohash[k][:enemyevadearray].mode,
		scenariohash[k][:enemyevadearray].min,
		scenariohash[k][:enemyevadearray].max,
		scenariohash[k][:enemyhealtharray],
		scenariohash[k][:enemyhealtharray].median,
		scenariohash[k][:enemyhealtharray].mean.round(2),
		scenariohash[k][:enemyhealtharray].standard_deviation.round(2),
		scenariohash[k][:enemyhealtharray].mode,
		scenariohash[k][:enemyhealtharray].min,
		scenariohash[k][:enemyhealtharray].max,
		scenariohash[k][:enemydamagearray],
 		scenariohash[k][:enemydamagearray].median,
		scenariohash[k][:enemydamagearray].mean.round(2),
		scenariohash[k][:enemydamagearray].standard_deviation.round(2),
		scenariohash[k][:enemydamagearray].mode,
		scenariohash[k][:enemydamagearray].min,
		scenariohash[k][:enemydamagearray].max,
		scenariohash[k][:enemyhorrorarray],
		scenariohash[k][:enemyhorrorarray].median,
		scenariohash[k][:enemyhorrorarray].mean.round(2),
		scenariohash[k][:enemyhorrorarray].standard_deviation.round(2),
		scenariohash[k][:enemyhorrorarray].mode,
		scenariohash[k][:enemyhorrorarray].min,
		scenariohash[k][:enemyhorrorarray].max,
		scenariohash[k][:treacherycount],
		scenariohash[k][:willarray].length,
		scenariohash[k][:willarray],
		scenariohash[k][:willarray].median,
		scenariohash[k][:willarray].mean,
		scenariohash[k][:willarray].standard_deviation,
		scenariohash[k][:willarray].mode,
		scenariohash[k][:willarray].min,
		scenariohash[k][:willarray].max,		
		scenariohash[k][:intellectarray].length,
		scenariohash[k][:intellectarray],
		scenariohash[k][:intellectarray].median,
		scenariohash[k][:intellectarray].mean,
		scenariohash[k][:intellectarray].standard_deviation,
		scenariohash[k][:intellectarray].mode,
		scenariohash[k][:intellectarray].min,
		scenariohash[k][:intellectarray].max,		
		scenariohash[k][:combatarray].length,
		scenariohash[k][:combatarray],
		scenariohash[k][:combatarray].median,
		scenariohash[k][:combatarray].mean,
		scenariohash[k][:combatarray].standard_deviation,
		scenariohash[k][:combatarray].mode,
		scenariohash[k][:combatarray].min,
		scenariohash[k][:combatarray].max,		
		scenariohash[k][:agilityarray].length,
		scenariohash[k][:agilityarray],
		scenariohash[k][:agilityarray].median,
		scenariohash[k][:agilityarray].mean,
		scenariohash[k][:agilityarray].standard_deviation,
		scenariohash[k][:agilityarray].mode,
		scenariohash[k][:agilityarray].min,
		scenariohash[k][:agilityarray].max,		

	]
end

of2.close()

