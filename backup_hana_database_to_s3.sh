#!/bin/bash

# Init: a <systems>.dat file to be provided as argument 1
systems_file="$1"

# Check if argument 1 exists
if [ -z "$1" ]; then
        echo "No <system>.dat file supplied. Exiting..."
        exit 3
fi

# Get IP address, instance number, and database type
hana_ip_address=""
hana_database_type=""
hana_instance_number=""

# Init: a variable to store today's date in yyyy-mm-dd format
todays_date=$(date -d "$(date)" +%Y-%m-%d)

#Init: a variable to store the backup directory
backup_directory="/hana/shared/backups"

# Init: variable to store directory of today's location
backup_directory_for_today="$backup_directory/$todays_date"

# Init: a variable for credentials. This user should only have backup privileges
hana_user="BACKUP_ADMINISTRATOR"
hana_user_password="sbxDB111234"

#Check if a backup directory already exist, if not create one
if [ -d "$backup_directory_for_today" ]; then
    echo "The backup directory already exists. Exiting..."
    exit 4
else
    echo "" ; echo "Creating the backup directory $backup_directory_for_today" ; echo ""
    mkdir $backup_directory_for_today
    sleep 1
fi

# Run the HANA backup via SQL query against the HANA database using the hana_user credentials
echo $(date) ; echo "Starting HANA Backup(s)..." ; echo ""

# Loop: Go through each line of the systems.dat file and peform a HANA backup
while IFS= read -r line || [ -n "$line" ]
do
    # Condition: if the line begins with a comment (#), skip it. Else, take the backup
    if [[ "$line" =~ ^# ]]; then # ignore any lines that start with a comment (#)
        continue
    else
        # Get the IP address, HANA database type, and instance number from the systems.dat file
        hana_ip_address=$(echo $line | awk '{print $1}')
        hana_database_type=$(echo $line | awk '{print $5}')
        hana_instance_number=$(echo $line | awk '{print $4}' | tail -c 3)

        # Perform the HANA database backup
        echo "Starting $hana_database_type backup..." ; echo ""
        sql=$(hdbsql -n $hana_ip_address -i $hana_instance_number -u $hana_user -p $hana_user_password -x -a -d $hana_database_type \
        "BACKUP DATA USING FILE ('$backup_directory_for_today/' , '${todays_date}_${SAPSYSTEMNAME}_${hana_database_type}'); ")
        if [ $? -eq 0 ]; then
            echo "HANA Backup $hana_database_type completed successfully..." ; echo ""
        else
            echo "Error: There was an issue with the HANA backups!" ; echo ""
            exit 5
        fi
    fi
done < $systems_file

# Encrypt each file

# Copy the backup directory to AWS S3
echo "" ; echo "Uploading HANA Backups to AWS S3..." ; echo ""
sudo aws s3 sync $backup_directory_for_today  s3://sysad-solutions/hana_backups/$todays_date > /dev/null

# Condition: If the previous aws command executed successfully, remove backups. Else, send alert
if [ $? -eq 0 ]; then
    echo $(date)
    echo "HANA Backup(s) uploaded to AWS S3 successfully..."
else
    echo "Error: There was an issue with uploading the HANA backups to AWS S3!"
    exit 5
fi

