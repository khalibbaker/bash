#!/bin/bash

# Author: Khalib Baker
# Company: Sysad Solutions
# Description: This is a library containing all functions that can be called from other scripts.

# List of useful functions that can be called


# Function: get_sap_system_status - this function runs sapcontrol against all instances in a system and 
# prints the status of each sap service (hdbindexserver, etc.)

function get_sap_system_status() {

        # Init: a <systems>.dat file to be provided as argument 1
    local systems_file="$1"

    # Check if argument 1 exists
    if [ -z "$1" ]
        then
            echo "No <system>.dat file supplied. Exiting..."
            exit 3
    fi
    # Init: sap_service_name variable to store the name of the sap service (message, enque, icman, etc.)
    local sap_service_name=""

    # Init: sap_service_status variable to store the status of the sap service (GREEN, YELLOW, RED)
    local sap_service_status=""

    # Init: sapcontrol_full_output to store the complete output of the sapcontrol command of GetProcess:List
    local sapcontrol_full_ouput=()


    # Retrieve system information (ip address, hostname, instance(s))
    # Init: instance_number to store the output of the instance number
    # *** Need to account for more instances ***
    instance_number=$(grep $(hostname) $systems_file | awk '{print $4}' | tail -c 3)

    # Output the status of sapcontrol to an array. Each line is an item in the array
    mapfile -t sapcontrol_full_output < <(sapcontrol -nr $instance_number -function GetProcessList)

    # Remove the first three entries from the array (date, ok, etc.)
    sapcontrol_short=("${sapcontrol_full_output[@]:5}")

    # Loop: loop goes thru each service list from sapcontrol
    for item in "${sapcontrol_short[@]}"
    do
    IFS=',' read -r -a field <<< "$item"

    sap_service_name=$(echo ${field[1]} | xargs)
    sap_service_status=$(echo ${field[2]} | xargs)

        # Case: if the status is GREEN, YELLOW, RED, or GRAY, taken action.
    case $sap_service_status in
        "GREEN")
            echo "$sap_service_status for $sap_service_name"
            ;;
        "YELLOW")
            echo "WARNING"
            # Send email 
            ;;
        "RED")
            echo "ALERT / ALERT"
            # Send email
            ;;
        "GRAY")
            echo "$sap_service_name is down."
            ;;
        *)
            echo "goodbye"
            ;;
        esac
    done
}


# Function: get_hana_users_expiring_soon - this function checks all user of a HANA tenants specified in a systems.dat file
# and alerts when a user is near expiration or about to expire.

function get_hana_users_expiring_soon() {

    # Init: a <systems>.dat file to be provided as argument 1
    local systems_file="$1"

    # Check if argument 1 exists
    if [ -z "$1" ]
        then
            echo "No <system>.dat file supplied. Exiting..."
            exit 3
    fi

    # Init: variable for system IP or sap hostname/alias
    local hana_ip_address=""
    local hana_instance_number=""

    # Init: variable for HANA user and hana password to connect to the database
    local hana_user=""
    local hana_user_password=""

    # Init: variable to specify TENANT or SYSTEMDB
    local hana_database_type=""

    # Get IP address, instance number, and database type
    local hana_ip_address=$(grep $(hostname) $systems_file | awk '{print $1}')
    local hana_database_type=$(grep $(hostname) $systems_file | awk '{print $5}')
    local hana_instance_number=$(grep $(hostname) $systems_file | awk '{print $4}' | tail -c 3)

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
    local days_until_expiration_arr=(`echo ${sql}`)

    # Loop will go through each record matched by the SQL query via an array.  If the user expires in less an 7 days, send email. 
    for record in "${days_until_expiration_arr[@]}"
    do
        local username=$(echo $record | awk -F, '{print $1}' | tr -d '"') # Get the user (equiv. to user_name field in the table)
        local days_remain=$(echo $record | awk -F, '{print $2}')  # Get the days remaining between today and the expiration date.
        local date_of_expiration=$(echo $record | awk -F, '{print $3}' | tr -d '"') # Get the expiration date

        # Print: a statement about when the user expires
        echo User $username expires in $days_remain days on $date_of_expiration.

        # Condition: if user expires in 7 days or less, send alert.
        if [ $days_remain -le 7 ];
            then
                # Send alert email
                continue
        fi

    done

}


# Function: check_filesystems checks if any filesystems have reached a certain threshold percentage (%) and alerts

function check_os_users() {
    # Init: a <systems>.dat file to be provided as argument 1
    local systems_file="$1"

    # Check if argument 1 exists
    if [ -z "$1" ]
        then
            echo "No <users>.dat file supplied. Exiting..."
            exit 3
    fi

    # Init: an array to store each user from the .dat file
    local os_user_arr=()

    # Init: a variable to store the OS user from the .dat file
    local os_user=""

    # Init: a variable to store the expiration date (date or never)
    local password_expiration_date=""

    # Init: a variable to store password inactive date
    local password_inactive_date=""

    # Init: a variable to store account expiration date
    local account_expiration_date=""

    # Init: a variable to store today date and days until expiration
    local todays_date=$(date '+%Y-%m-%d')
    local days_until_password_expiration=0
    local days_until_password_inactive=0
    local days_until_account_expiration=0


    # Init: a variable to store threshold for days until expiration (7 days)
    local expiration_day_threshold=7

    # Init: an array to store counter of users with warning
    local os_user_warning_counter=0

    # Store each user in the .dat file to an array
    mapfile -t os_user_arr < $systems_file

    # Loop: for loop to check each user. A warning will be issued for accounts that are not expired. An alert wil be issued for accounts that are
    # each alert should generate an email.
    for user in "${os_user_arr[@]}"
    do
        os_user=$user
        password_expiration_date=$(sudo chage -l $os_user | grep "^Password expires" | awk -F':' '{print $2}' | xargs)
        password_inactive_date=$(sudo chage -l $os_user | grep "^Password inactive" | awk -F':' '{print $2}' | xargs)
        account_expiration_date=$(sudo chage -l $os_user | grep "^Account expires" | awk -F':' '{print $2}' | xargs)
        

        # Condition: if the password, password inactive and account expiration dates are equal to never, then continue (user is good). Else, there is an expiration to consider.
        if [[ "$password_expiration_date" == "never" && "$password_inactive_date" == "never" && "$account_expiration_date" == "never" ]]; then
            continue
        else
            # Check password expiration date
            if [[ ! "$password_expiration_date" == "never" ]]; then
                password_expiration_date=$(date -d "$password_expiration_date" +'%Y-%m-%d') # re-format date
                days_until_password_expiration=$(( ($(date -d $password_expiration_date +%s) - $(date -d $todays_date +%s)) / 86400 )) # calculate difference in days

                # Condition: if days left is 0 (also accounts for negative), then expired.            
                if [[ ! "$days_until_password_expiration" == "0" ]]; then
                    # Send email
                    echo ALERT! The password for $os_user is expired as of $password_expiration_date.
                else
                    # Send email
                    echo WARNING! The password for $os_user will expire in $days_until_password_expiration days on $password_expiration_date.
                fi    

            fi

            # Check password inactive date (similar functionality as above conditions)
            if [[ ! "$password_inactive_date" == "never" ]]; then
                password_inactive_date=$(date -d $password_inactive_date +'%Y-%m-%d')
                days_until_password_inactive=$(( ($(date -d $password_inactive_date +%s) - $(date -d $todays_date +%s)) / 86400 ))

                if [[ ! "$days_until_password_inactive" == "0" ]]; then
                    echo ALERT! The password for $os_user is inactive as of $password_inactive_date. 
                else
                    
                    echo WARNING! The password for $os_user will become inactive in $days_until_password_inactive days on $password_inactive_date.
                fi

            fi

            # Check account expiration date
            if [[ ! "$account_expiration_date" == "never" ]]; then
                account_expiration_date=$(date -d "$account_expiration_date" +'%Y-%m-%d')
                days_until_account_expiration=$(( ($(date -d $account_expiration_date +%s) - $(date -d $todays_date +%s)) / 86400 ))
                # echo ALERT! The account $os_user will become inactive in $days_until_password_inactive days on $account_expiration_date.

                if [[ ! "$days_until_account_expiration" == "0" ]]; then
                    echo ALERT! The account $os_user is inactive as of $account_expiration_date.
                else
                    echo WARNING! The account $os_user will become inactive in $days_until_account_expiration days on $account_expiration_date.
                fi


            fi
        fi

    done    

}


function check_filesystems() {
    # Init: an array named filesystems_arr with the first element removed. The first element is the first row output from df -h 
    local filesystems_arr=()

    # Init: a variable to store file system 
    local filesystem_name=""

    # Init: a variable to store current usage
    local filesystem_usage=""

    # Init: a variable to count the filesystems triggered by threshold
    local filesystem_threshold_counter=0

    # Init: a variable to store mounted on directory director
    local mounted_directory=""

    # Init: a variable for filesystem threshold (i.e. filesystem more than X % used)
    local threshold=1


    # Store each line of the output of the df -h command as an entry in the array
    IFS=$'\n' filesystems_arr=( $(df -h | grep -vE '^Filesystems|tmpfs') )

    # Loop: iterate over each row of df -h and if threshold is met for usage, then alert
    echo "Checking filesystems on $(hostname)..." ; echo ""
    for item in ${filesystems_arr[@]}
    do
        filesystem_usage=$(echo $item | awk '{print $5}' | cut -c1-2)
        filesystem_name=$(echo $item | awk '{print $1}')
        mounted_directory=$(echo $item | awk '{print $6}')
        
        if [[ $filesystem_usage -lt $threshold ]]; then
            continue
            
        elif [[ $filesystem_usage -gt $threshold ]]; then
            # Send email
            echo ALERT!! $filesystem_name on $mounted_directory is above $threshold%.
            let filesystem_threshold_counter++ 
        fi

    done

    echo "" ; echo There are $filesystem_threshold_counter filesystems on $(hostname) alerting.


}