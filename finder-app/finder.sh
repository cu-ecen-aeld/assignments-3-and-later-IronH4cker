#!/bin/bash

#Verify number of arg inputs
if [ $# -ne 2 ]; then
	echo "Error: You need pass 2 inputs arg: <file directory> <search string>"
	exit 1
fi

filesdir=$1
searchstr=$2

if [ ! -d "$1" ]; then
	echo "DEBUG: Argument 1 is '$1'"
	exit 1
fi



#Check the first arg is an valid directory
if [ ! -d "$filesdir" ]; then
	echo "Error: '$filesdir' is not a valid directory."
	exit 1
fi


#Count number of files (X)
X=$(find "$filesdir" -type f | wc -l)

#Count number of lines which contains the string (Y)
Y=$(grep -r "$searchstr" "$filesdir" 2>/dev/null | wc -l)

echo "The number of files are ${X} and the number of matching lines are ${Y}"

exit 0
