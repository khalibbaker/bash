#!/bin/bash

# Author: Khalib Baker
# Company: Sysad Solutions
# Description: This script checks the OS/Linux users on a server, provided by a os_user.dat file for password
# and account expiration.

# Init: a <systems>.dat file to be provided as argument 1
systems_file="$1"

# Check if argument 1 exists
if [ -z "$1" ]
    then
        echo "No <users>.dat file supplied. Exiting..."
        exit 3
fi

# Init: an array to store each user from the .dat file
os_user_arr=()

# Init: a variable to store the OS user from the .dat file
os_user=""

# Init: a variable to store the expiration date (date or never)
password_expiration_date=""

# Init: a variable to store password inactive date
password_inactive_date=""

# Init: a variable to store account expiration date
account_expiration_date=""

# Init: a variable to store today date and days until expiration
todays_date=$(date '+%Y-%m-%d')
days_until_password_expiration=0
days_until_password_inactive=0
days_until_account_expiration=0


# Init: a variable to store threshold for days until expiration (7 days)
expiration_day_threshold=7

# Init: an array to store counter of users with warning
os_user_warning_counter=0

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