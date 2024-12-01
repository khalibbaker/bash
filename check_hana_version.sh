#!/bin/bash

# Init: a <systems>.dat file to be provided as argument 1
systems_file="$1"

# Check if argument 1 exists
if [ -z "$1" ]
    then
        echo "No <system>.dat file supplied. Exiting..."
        exit 3
fi

# Init: a variable to store the hana version
hana_version=""

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


# From command prompt, get username and password. Password will be hidden
read -p "Enter HANA Username: " hana_user
read -s -p "Enter HANA Password: " hana_user_password

# Newline
echo ""

# Connect to HANA with credentials & perform sql query against HANA database to select hana version
sql=$(hdbsql -n $hana_ip_address -i $hana_instance_number -u $hana_user -p $hana_user_password -x -a -d $hana_database_type \
"SELECT version FROM SYS.M_DATABASE";)

# Set hana version to a variable
hana_version=$(echo $sql | tr -d '"')

# Output results
echo The HANA version on $(hostname) is $hana_version













