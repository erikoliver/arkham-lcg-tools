#!/usr/bin/env ruby
#

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

#
# Idea: Parse ArkhamDB JSON data
# (https://github.com/Kamalisk/arkhamdb-json-data/) to enable statistics
# and proxy decks.
#
# Example: For scenario X what is the distribution of treachery tests
# and values, enemy fight/evade, etc.
# 
# Practical issue: Statistics are harder than they seem because the pack
# information does not contain the necessary information about which
# encounter sets are used. 
#
#
# Data dependencies
#   * Need the above 'arkhamdb-json-data'
#   * Need the public API card pull of ArkhamDB for Octagon IDs (https://arkhamdb.com/api/public/cards/)
#   * Need the Cardgame DB file for quantities (http://www.cardgamedb.com/deckbuilders/arkhamhorror/database/AHC##-db.jgz)
# 
#
#
# TODO: Consider if the public API can be used instead of the GitHub download
#   * Contrapoint: The packs.json is needed to figure out the AHC##_#.jpg from a the card data so the GitHub data is needed...
#   * Followup: https://arkhamdb.com/api/public/packs/ might solve that issue
#
## 

require 'json'
require 'CSV'
require 'CGI'

ARKHAMDBGITJSONROOT='./arkhamdb-json-data-master/' # this is where the 'arkhamdb-json-data' is locally
BASEURL='http://lcg-cdn.fantasyflightgames.com/ahlcg/' # this is the base URL for Arkham cards on FFG's site
CARDDB = './carddbdata/AHC29-db.jgz' # download this from http://www.cardgamedb.com/deckbuilders/arkhamhorror/database/AHC##-db.jgz
ARKHAMDBCARDAPI = './cards.json' # this is the download of https://arkhamdb.com/api/public/cards/


OUTFILECARDS = './outcards.csv' # output file

# fields to pull from the JSON
HEADINGS = %w(
	arkhamdbcode
	oct_id
	quantity
	scenario_name
	card_name
	pack_code
	front
	back
	encounter_code
	type_code
	subtype_code
	shroud
	clues
	cluesscale
	enemy_evade
	enemy_fight
	enemy_health
	enemy_health_scale
	enemy_damage
	enemy_horror
	text
	victory
	calcwilltest
	calcagilitytest
	calcombattest
	calcintellecttest
)
			
# recursively process all of the Arkham GitHub JSON data 

def processpack(path)
	# we start at the path
	storage = Array.new() # this will need to get appended to
	Dir.entries(path).each do |filename|
		next if (filename == '.' || filename == '..')
		# if we have a directory recurse into it	
		if(File.ftype(File.join(path,filename)) == 'directory') then
			temparray = processpack(File.join(path,filename))
		elsif (filename =~ /^*.json$/) then
			temparray = JSON.parse(File.read(File.join(path,filename)))
		end
		
		# now we need to merge temphash into storage and return storage
		next if (temparray == nil)
		temparray.each do |row|
			#next if (row == nil)
			storage << row
		end #temparray.each 
		
	end # packpah
	
	return storage
end


#####
# Step 1: Figure out the carddb pack codes, e.g. dwl --> 02
#####

# The Arkham GitHub has a file "packs.json" that maps the abbreviations ot the codes
packids = Array.new()
packids = JSON.parse(File.read(File.join(ARKHAMDBGITJSONROOT,'packs.json')))
# make a hash
packlookup = Hash.new()
packids.each do |row|
	packlookup[row['code']] = Hash.new()
	packlookup[row['code']][:cgdb_id] = row['cgdb_id']
	packlookup[row['code']][:name] = row['name']
end

####
# Step 2: Read the Card DB data
# This is a master JGZ file located at http://www.cardgamedb.com/deckbuilders/arkhamhorror/database/AHC##-db.jgz
# So for example when TCU (#29) came out the file was http://www.cardgamedb.com/deckbuilders/arkhamhorror/database/AHC29-db.jgz
# And that included all of the previous cards through TCU
# 
#
# As a practical matter, the file was plain text and if the leading 'cards = ' and trailing ';' were removed it works as JSON
# 
# We want this file because it has a quantity for each AHC##_#.jpg which we can use to link up
# between the Arkham DB git file and this, in particular to retrieve the quantity of a card in the pack
#
####


carddbstring = File.read(CARDDB)
# remove extraneous data
carddbstring.gsub!(/^cards\s+=\s*/,'')
carddbstring.gsub!(/;$/,'')

temparray = JSON.parse(carddbstring)

# now hash the carddb data based on the imgf
carddbhash = Hash.new()
temparray.each do |row|
	next if (carddbhash.has_key?(row['imgf'])) # cannot duplicate
	carddbhash[row['imgf']] = row # store the entire hash by the image key
end # temparray.each

####
# Step 3: Load the public API data on cards too for Octagon IDs
# This file is at - https://arkhamdb.com/api/public/cards/
# And is the only way I've found to get the Octagon Ids
#
####

octids = JSON.parse(File.read(ARKHAMDBCARDAPI))
# make a hash
octlookup = Hash.new()
octids.each do |row|
	octlookup[row['code']] = row['octgn_id']
end

#### 
# Step 4: Load all of the ArkhamDB github JSON data
####
packpath = File.join(ARKHAMDBGITJSONROOT,'pack') # this folder has all of the individual JSONs in sub dirs
resultarray = processpack(packpath)


####
# Step 5: Combine everything we just did and output a CSV file
####


of = CSV.open(OUTFILECARDS,'w')
of << HEADINGS

# so we have an array of cards now with key-> value we want to permute that into the common items we want
resultarray.each do |row|
	# we want to parse the text for willpower, agility, combat, intellect tests
	willtest = nil
	agilitytest = nil
	combattest = nil
	intellecttest = nil

	if(row.has_key?('text')) then
		# the text will have something like '...Test [willpower] (3)...' we want to find those strings, multiple strings are possible we will take the first of each type thus the
		# Regex  /Test (\[willpower\]) \(([^)])\)/ --> simplified since we aren't going to parse the first capture
		
		# look for will test, etc.
		willtest = $1 if(row['text'] =~ /Test \[willpower\] \(([^)])\)/) 
		agilitytest = $1 if(row['text'] =~ /Test \[agility\] \(([^)])\)/) 
		combattest = $1 if(row['text'] =~ /Test \[combat\] \(([^)])\)/) 
		intellecttest = $1 if(row['text'] =~ /Test \[intellect\] \(([^)])\)/) 
		
	end
	
	front = nil
	back = nil
	frontalt = nil
	if(packlookup.has_key?(row['pack_code']) && packlookup[row['pack_code']] != nil) then
		frontalt = 'AHC' + packlookup[row['pack_code']][:cgdb_id].to_s.rjust(2,'0') + '_' + row['position'].to_s + '.jpg'
		front = BASEURL + frontalt
		back = BASEURL + 'AHC' + packlookup[row['pack_code']][:cgdb_id].to_s.rjust(2,'0') + '_' + row['position'].to_s + 'b.jpg'
	end
	
	## some types don't usually have meaningful backs, so nil the back value for them
	## other known valid types: investigator, scenario, agenda, act, location, story
	back = nil if(row['type_code'] =~ /^(asset|event|skill|treachery|enemy)$/) 

	qty = nil
	qty = carddbhash[frontalt]['quantity'] if(carddbhash.has_key?(frontalt))
	
	# "clues_fixed": true, - present if clues is NOT multiplied by # of players
	cluesscale = true
	cluesscale = false if(row.has_key?('clues_fixed'))
	cluesscale = nil if(! row.has_key?('clues') )

    # enemy health
    #    "health": 5,
    #    "health_per_investigator": true,
	healthscales = false
	healthscales = true if(row.has_key?('health_per_investigator'))
	healthscales = nil if(! row.has_key?('health'))

	# horror/damage
	#         "enemy_damage": 1,
	#         "enemy_horror": 0,

	
	of << [	row['code'], 
			octlookup[row['code']],
			qty,
			packlookup[row['pack_code']][:name],
			CGI.unescapeHTML(row['name']),
			row['pack_code'], 
			front,
			back,
			row['encounter_code'], 
			row['type_code'], 
			row['subtype_code'],
			row['shroud'], 
			row['clues'],
			cluesscale, 
			row['enemy_evade'], 
			row['enemy_fight'],
			row['health'],
			healthscales,
			row['enemy_damage'],
			row['enemy_horror'],
			row['text'],
			row['victory'],
			willtest, agilitytest, combattest, intellecttest
		] 
end # rows

of.close()
