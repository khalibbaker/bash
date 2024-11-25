#!/bin/bash

# Init: a <systems>.dat file to be provided as argument 1
systems_file="$1"

# Check if argument 1 exists
if [ -z "$1" ]
    then
        echo "No <system>.dat file supplied. Exiting..."
        exit 3
fi

# Init: variable for system IP or sap hostname/alias
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

# New line
echo ""

# Connect to HANA with credentials & perform sql query against HANA database to select all users that
# have a valid_until date. Query grabs user_name, days between today's date and the valid_until date, and the valid_untildate 
sql=$(hdbsql -n $hana_ip_address -i $hana_instance_number -u $hana_user -p $hana_user_password -x -a -d $hana_database_type \
"SELECT 
USER_NAME,
DAYS_BETWEEN(CURRENT_DATE, VALID_UNTIL) as DAYS_LEFT,
TO_VARCHAR(VALID_UNTIL, 'YYYY-MM-DD')	
FROM SYS.USERS
WHERE VALID_UNTIL IS NOT NULL;")

# Covert the sql results to an array
days_until_expiration_arr=(`echo ${sql}`)

# Loop will go through each record matched by the SQL query via an array.  If the user expires in less an 7 days, send email. 
for record in "${days_until_expiration_arr[@]}"
do
    username=$(echo $record | awk -F, '{print $1}' | tr -d '"') # Get the user (equiv. to user_name field in the table)
    days_remain=$(echo $record | awk -F, '{print $2}')  # Get the days remaining between today and the expiration date.
    date_of_expiration=$(echo $record | awk -F, '{print $3}' | tr -d '"') # Get the expiration date

    # Print: a statement about when the user expires
    echo User $username expires in $days_remain days on $date_of_expiration.

    # Condition: if user expires in 7 days or less, send alert.
    if [ $days_remain -le 7 ];
        then
            # Send alert email
            continue
    fi

done
