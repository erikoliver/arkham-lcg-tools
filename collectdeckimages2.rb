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


# Idea: you have an exported .o8d file from Arkham DB, find all of the
# octagon IDs and grab the images down
# 
# Data dependencies:
#   * Relies on the data file output from 'parsejson.rb' to read the Arkham card data
#   * Requires an .o8d file for the desired deck to produce a PDF
#
# Usage note: Arkham DB does not have octagon IDs for 100% of cards, you
# can hack the .o8d file to include the ArkhamDB, e.g. 05116, instead
# Aside, using the octagon IDs is suboptimal, but the most consistent
# export from Arkham DB decks...
#
# Also http://ffgapp.com/qr/AHC## has an HTML file with all jpgs linked...


require 'rubygems'
require 'CSV'
require 'CGI'
require 'rmagick'



INPUTCSV='/Users/erik/Documents/Arkham DB Json/outcards.csv' # this is our file with the parsed Arkham DB data
CACHEDIR='/Users/erik/Documents/Arkham DB Json/imagecache/'
COLMAX = 3
ROWMAX = 3

## Url Retriever that uses the cache and command line 'curl'

def cachedretrieve(cardurl, cachedir, cardname)
	# FFG URLs look like http://lcg-cdn.fantasyflightgames.com/ahlcg/AHC00_116.jpg
	# we will use the "AHC##_####.jpg" as the file name
	
	if(cardurl !~ /\/(AHC\d\d_\d+b?.jpg)$/) then
		raise "Invalid arkham URL #{cardurl}"
	end
	
	fullpathfilename = File.join(cachedir,$1)
	
	if(File.exists?(fullpathfilename)) then # we already have this card
		return nil
	end

	print "Getting #{$1} - #{cardname}\n" 
		
	IO.popen(['curl', cardurl]) do |curl_io| 
		res = curl_io.read 
		File.open(fullpathfilename, 'wb') do |file|
			file.write(res)
		end # open	
		print "waiting 0-5sec\n"
		sleep(rand(5)) # sleep seconds

	end	# Need to add error handling
	return nil
end # cacehdretrieve

# fix rotations of files so everything is 300 wide x 419 high
def checkrotation(filepath)
	# rotate if needed - normally these are 300 wide by 419 high
	img = Magick::Image.read(filepath).first

	if(img.columns > img.rows) # too wide so rotate left
		img.rotate!(-90)
		img.write(filepath)
	end	
end

def makepage(pagearray,outfile)
	ilist = Magick::ImageList.new() # create an image list to hold the images
	pagearray.each do |file|
		ilist << Magick::Image.read(file).first
	end
	
	newlist = ilist.montage() {
		self.geometry = Magick::Geometry.new(300,419) # print at ~59% scale
		self.tile = Magick::Geometry.new(COLMAX,ROWMAX)
	}
	newlist.write(outfile)
end

## Main Program Flow

Dir.mkdir(CACHEDIR) if(! Dir.exists?(CACHEDIR))

print "Cache is in: #{CACHEDIR}\n\n"

infile = nil
if(!(ARGV.length()>0)) then
	STDERR.print "Usage: collectdeckimages.rb deck.o8d\n"
	exit -1
end

infile = ARGV[0]
raise "No input file chosen" if (infile == '' || infile == nil)
raise "Input file must be an o8d file, you selected '#{infile}'" if (infile !~ /.o8d$/i)

dirname = File.dirname(infile) 
basename = File.basename(infile)
extension = File.extname(infile)
justfile = File.basename(infile, extension)
outname = File.join(dirname,justfile + '.pdf')

## Step 1: Link Octagon Ids to the images
cardhash = Hash.new()
CSV.foreach(INPUTCSV, headers: true) do |row|
  # we have a bunch of CSV::Row's let's store in desired hash uisng the oct_id
  oct_id = row['oct_id']
  if(oct_id == nil || oct_id == '')
  	# we will treat the arkham db code as the key
  	# this allows a manual .o8d file to be created with the cards not yet assigned octagon ids
  	oct_id = row['arkhamdbcode']
  end
  
  next if(oct_id) == nil # skip if we had neither type of code
  
  myid = oct_id.split(':')
  myid.each do |id|
  	if(cardhash.has_key?(id)) then
  		print "Error duplicate uuid = #{id}\n"
  		exit -1
  	end
  	
  	cardhash[id] = Hash.new()
  	cardhash[id][:name] = row['card_name']
  	cardhash[id][:front] = row['front']
  	cardhash[id][:back] = row['back']
  end
end

## Step 2: Trivially read the .o8d file (XML) as text looking for the IDs
# Sample :     <card qty="1" id="4efb8c8b-170a-43e8-850b-f41180416ede">Charisma</card>
# Trivial Regex: card\sqty="(\d+)"\sid="([^"]+)\">([^<]+)<


cardsneeded = Hash.new()
File.open(infile).each do |line|
	# we need to look for an octagon id
	next unless (line =~ /card\sqty="(\d+)"\sid="([^"]+)\">([^<]+)</)	
	# $1 has the quantity and $2 the id
	cardsneeded[$2] = Hash.new()
	cardsneeded[$2][:qty] = $1.to_i
	cardsneeded[$2][:name] = CGI.unescapeHTML($3)
	
end

## Step 3: Use the cardhash and cardsneeded to retrieve the JPGs
cardsneeded.keys.each do |key|
	# lookup the necessary image URL in cardhash
	if(cardhash.has_key?(key)) then
		
		front = cardhash[key][:front]
		back = cardhash[key][:back]
	
		## use caching and retrieve front/back URLs to cache
		cachedretrieve(front,CACHEDIR, cardsneeded[key][:name]) if(front != nil)
		cachedretrieve(back,CACHEDIR, cardsneeded[key][:name]) if(back != nil)
		
	else
		print "Card '#{cardsneeded[key][:name]}' in your deck does not have image data associated\n"
	end
end 


## Step 4: Make a PDF/something of the deck I believe it can be 2x5 cards on one letter-sized page

pagearray = Array.new()
cardsneeded.each do |key, value|
	# we need to respect the quantity and piece together the images we downloaded in Step 3 into a master image
	# Value is a hash like {:qty => 2, :name => 'Card Name'}
	# we can use the key to get the front/back from the cardhash
	
	front = cardhash[key][:front]
	if(front != nil) then
		front =~ /\/(AHC\d\d_\d+b?.jpg)$/
		frontfile = File.join(CACHEDIR,$1)
		checkrotation(frontfile)
	end
	
	back = cardhash[key][:back]
	if(back != nil) then
		back =~ /\/(AHC\d\d_\d+b?.jpg)$/
		backfile = File.join(CACHEDIR,$1)
		checkrotation(backfile)
	else
		backfile = nil
	end
	
	qty = value[:qty]
	
	while (qty>0)
		qty -= 1 # decrement the number of copies we need to add
		pagearray << frontfile
		next if (backfile == nil)
		pagearray << backfile		
	end
end 

print "making the PDF....\n"
makepage(pagearray,outname)
print "...PDF complete\n"
