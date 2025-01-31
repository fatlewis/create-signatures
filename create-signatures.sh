#!/bin/bash

# Check Dependencies
# imagemagick -> check using 'convert' command?
# pdftk

# Check argument length

# Assign Variables
fileName=$1
numInputPages=20
numLeafsPerPrintPage=2
numLeafsPerSignature=6
numPagesPerLeaf=4 # Must be even as this is the total number, including both sides

# Pad file with extra pages if needed. If odd pages, add more to back
numPagesPerSignature=$(( numLeafsPerSignature * numPagesPerLeaf ))
numSparePages=$(( numPagesPerSignature - ( numInputPages % numPagesPerSignature ) ))
numOutputPages=$(( numInputPages + numSparePages ))
echo "Input Pages: $numInputPages. Pages Per Signature: $numPagesPerSignature. Spare Pages: $numSparePages. Output Pages: $numOutputPages."

numFrontPaddingPages=$(( numSparePages / 2 )) # If odd this will round down
numBackPaddingPages=$(( numSparePages - numFrontPaddingPages ))

# If the final print page has fewer leafs than its capacity, pad the document to ensure the front & back of the final leafs print correctly
numLeafsOnFinalPrintPage=$(( (numOutputPages / numPagesPerLeaf) % numLeafsPerPrintPage ))
if [[ numLeafsOnFinalPrintPage -ne 0 ]]
then
	numBackPaddingPages=$(( numBackPaddingPages + (numLeafsPerPrintPage - numLeafsOnFinalPage) * numPagesPerLeaf ))
fi
finalNumPrintPages=$(( (numInputPages + numFrontPaddingPages + numBackPaddingPages) / numPagesPerLeaf / numLeafsPerPrintPage ))
echo "Pages and pads. Front pad: $numFrontPaddingPages. Back pad: $numBackPaddingPages. Input pages: $numInputPages."
echo "Final Number of print pages (with all pads taken into account): $finalNumPrintPages"

# Create blank page with imagemagick. Use dimensions of first page of input file.
blankPageName=blank-page.temp.pdf
convert xc:none -page $(pdfinfo $fileName | grep "Page size" | awk '{print $3 "x" $5}') $blankPageName
echo "Blank page created with dimensions from '$fileName'"

padFileName=padded-output.temp.pdf
pdftk $(echo $(yes $blankPageName | head -n $numFrontPaddingPages)) $fileName $(echo $(yes $blankPageName | head -n $numBackPaddingPages)) cat output $padFileName
echo "Padded file created at $padFileName."

# Rearrange file into signature leafs
numSignatures=$(( numOutputPages / numPagesPerSignature ))
signatureLeafs=()
for (( i=0; i<$numSignatures; i++ ))
do
	# Find start and ending leaf of each signature
	startingPage=$(( ( i * numPagesPerSignature ) + 1 ))
	endingPage=$(( startingPage + numPagesPerSignature - 1 ))
	while [[ startingPage -lt endingPage ]]
	do
		# Push next set of pages as json array
		signatureLeafs+=("[$endingPage, $startingPage, $(( startingPage + 1 )), $(( endingPage - 1 ))]")

		startingPage=$(( startingPage + 2 ))
		endingPage=$(( endingPage - 2 ))
	done
done

echo "${signatureLeafs[@]}"

# Order leaf pages for print
orderedPageNumbers=()
for (( i=0; i<$finalNumPrintPages; i++ ))
do
	for (( j=0; j<$numLeafsPerPrintPage; j++ ))
	do
		# get leaf from signature leafs array
		currentLeafIndex=$(( (i * numLeafsPerPrintPage) + j ))
		currentLeaf=${signatureLeafs[$currentLeafIndex]}
		# add front pages
		for (( k=0; k<$((numPagesPerLeaf / 2)); k++ ))
		do
			orderedPageNumbers+=($(echo $currentLeaf | jq ".[$k]"))
		done
	done
	for (( j=0; j<$numLeafsPerPrintPage; j++ ))
	do
		# get leaf from signature leafs array
		currentLeafIndex=$(( (i * numLeafsPerPrintPage) + j ))
		currentLeaf=${signatureLeafs[$currentLeafIndex]}
		# add back pages
		for (( k=0; k<$((numPagesPerLeaf / 2)); k++ ))
		do
			orderedPageNumbers+=($(echo $currentLeaf | jq ".[$((k + 2))]"))
		done
	done
done

echo "${orderedPageNumbers[@]}"

outputFileName=rearranged-file.pdf
pdftk $padFileName cat $(echo ${orderedPageNumbers[@]} | sed 's/,//g') output $outputFileName
echo "Done."
# Cleanup
