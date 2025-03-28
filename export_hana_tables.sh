#!/bin/bash

# Init: a <systems>.dat file to be provided as argument 1
systems_file="$1"

# Init: a <hana tables>.dat
hana_tables_file="$2"

# Check if argument 1 exists
if [ -z "$1" ]
    then
        echo "No <systems>.dat file supplied. Exiting..."
        exit 3
elif [ -z "$2" ]
    then
        echo "No <hana tables>.dat file supplied. Exiting..."
        exit 4
fi

# Init: an array to store the schema.table of from the <hana tables.dat> file
hana_tables_arr=()

# Init: a variable for system IP or sap hostname/alias
hana_ip_address=""
hana_instance_number=""

# Init: variable for HANA user and hana password to connect to the database
hana_user=""
hana_user_password=""

# Init: variable to specify TENANT or SYSTEMDB
hana_database_type=""

# Get IP address, instance number, and database type
hana_ip_address=$(grep $(hostname) $systems_file | awk '{print $1}')
hana_database_type=$(grep $(hostname) $systems_file | awk '{print $5}')
hana_instance_number=$(grep $(hostname) $systems_file | awk '{print $4}' | tail -c 3)

# Init: a variable to store export location
export_location_directory=""

# Init: the number of database threads to use
threads=4 # 4 threads

# Init: number of tables exported
number_of_exported_tables=0

# Init: size of export_location_directory 
export_location_size_before=0
export_location_size_after=0

# Populate the array with the tables from HANA
mapfile -t hana_tables_arr < $hana_tables_file

# From command prompt, get the directory location
read -p "Enter location to store the export: " export_location_directory

# Condition: check if the target directory exists first, if not exit and tell user to create it first
# FIX: prompt user to create the directory or exit
if [ ! -d "$export_location_directory" ]
    then
        echo The directory $export_location_directory does not exist. Please create this directory before running the export...
        exit 5
fi


# From command prompt, get username and password. Password will be hidden
read -p "Enter HANA Username: " hana_user
read -s -p "Enter HANA Password: " hana_user_password

# Newline
echo "" ; echo ""

# Get the size of the directory before
export_location_size_before=$(du -sh $export_location_directory)
echo Size of export location before: $export_location_size_before ; echo ""

# Loop: for each schema.table, perform the export to the target directory
for item in "${hana_tables_arr[@]}"
do

    # Connect to HANA with credentials & perform sql query against HANA database to select hana version
    sql=$(hdbsql -n $hana_ip_address -i $hana_instance_number -u $hana_user -p $hana_user_password -x -a -d $hana_database_type \
    "EXPORT $item AS BINARY INTO '$export_location_directory' WITH REPLACE THREADS $threads";)

    let number_of_exported_tables++ # Increment the number of exported tables counter
    echo "Exporting $item to $export_location_directory" ; echo ""

done

# Summary / Send email
# Get the size of the directory after
export_location_size_after=$(du -sh $export_location_directory)
echo Size of export location after: $export_location_size_after ; echo ""

# Display count of tables exported
echo "Table(s) export complete. $number_of_exported_tables table(s) exported." 
