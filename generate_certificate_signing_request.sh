#!/bin/bash

# Init: a <systems>.dat file to be provided as argument 1
systems_file="$1"

# Check if argument 1 exists
if [ -z "$1" ]
    then
        echo "No <system>.dat file supplied. Exiting..."
        exit 3
fi

# Init: array to include CN and SANs 
certificate_list_arr=()

# Init: a string to include the CN. This should be the first row of servers_list_for_certificates.dat
certificate_common_name=""

# Init: a string to include the SAN. This should be remaining rows of servers_list_for_certificates.dat
certificate_san_arr=()


# Init: create a file to store the tls_certificate_application_<date>.dat


# Store each line of the output of the df -h command as an entry in the array
IFS=$'\n' certificate_list_arr=( $(cat $systems_file | grep -vE '^#') )

# Init: counter variable for index of certificate_list_arr
certificate_list_arr_index_counter=0

# Loop: interate through the certificate_list_arr. Store the first
for item in "${certificate_list_arr[@]}"
do
    if [[ $certificate_list_arr_index_counter -eq 0 ]]; then
        certificate_common_name=$(echo $item)

    else
        echo "not one"
    fi

    let certificate_list_arr_index_counter++
done

echo $certificate_common_name