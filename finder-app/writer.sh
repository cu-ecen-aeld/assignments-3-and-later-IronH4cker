#!/bin/bash

if [ $# -ne 2 ]; then
	echo "<file_path><string_to_write>"
	exit 1
fi

writefile=$1
writestr=$2

#Create new file with name and path writefile and content writestr
mkdir -p "$(dirname "$writefile" )"

#Write the content of the file
echo "$writestr" > "$writefile"

#Confirmation
echo "File has been created in: $writefile"
echo "Contain:"
cat "$writefile"
