# arkham-lcg-tools
Collection of scripts and data for working with Arkham LCG Card Data

I've created three simple Ruby scripts for working with the Arkham DB JSON data files [arkhamdb-json-data GitHub](https://github.com/Kamalisk/arkhamdb-json-data).

Also, I've built a list of the encounter sets in each scenario.

## parsejson.rb

The first tool is "parsejson.rb" which expects:
1. A local copy of the above [arkhamdb-json-data](https://github.com/Kamalisk/arkhamdb-json-data)
2. A local copy of the ArkhamDB API card pull (download cards here)[https://arkhamdb.com/api/public/cards/]
3. A local copy of the card game db data (AHC29 was current)[http://www.cardgamedb.com/deckbuilders/arkhamhorror/database/AHC29-db.jgz]. (Modify the URL based on the most recent pack, e.g. AHC30-db.jgz, when later packs come out.) 

The first item serves as the basis for the analysis. I pull the API card list because it was the only way to get Octagon IDs (used later). I pull the card game db file to get quantities for cards (also used later)

## collectdeckimages2.rb

This is my proxy deck builder. It expects the Octagon export from ArkhamDB. Build your deck there and export as Octagon (.o8d) file. This script needs the output from parsejson.rb, above, and an octagon export. It produces a PDF.

You must have ImageMagick installed on your machine.

I used this first to create the cards for the prologue investigators. But also plan to use it to have a couple of tutorial decks with upgrades ready for teaching the game. Other potential uses would be to pre-build the encounter sets for scenarios.

(Note: This cheats and uses regexes to look at the file, so proper XML is optional. Also if no Octagon id is available you can substitute the 5 digit ArkhamDB card id manually, e.g. 05001, etc.) 

## analyze2.rb

This is my first experiment in analyzing the scenarios. It requires a decoder ring of the scenarios as a CSV (you can use the Excel I provide which has the Core, Dunwich, Carcosa, and Forgotten Age saved as CSV and judiciously edited for some of the choices.)

This is still very much a work in progress but the is to enable analysis of average shroud, # of clues, types of tests, enemy difficulty within a scenario.
