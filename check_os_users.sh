#!/bin/bash

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


for user in "${os_user_arr[@]}"
do
    os_user=$user
    password_expiration_date=$(sudo chage -l $os_user | grep "^Password expires" | awk -F':' '{print $2}' | xargs)
    password_inactive_date=$(sudo chage -l $os_user | grep "^Password inactive" | awk -F':' '{print $2}' | xargs)
    account_expiration_date=$(sudo chage -l $os_user | grep "^Account expires" | awk -F':' '{print $2}' | xargs)
    # echo $os_user password exp. on $password_expiration_date and inactive on $password_inactive_date and account expires on $account_expiration_date
   

    # Condition: if the password, password inactive and account expiration dates are equal to never, then continue (user is good)
    if [[ "$password_expiration_date" == "never" && "$password_inactive_date" == "never" && "$account_expiration_date" == "never" ]]; then
        continue
    else
        if [[ ! "$password_expiration_date" == "never" ]]; then
            password_expiration_date=$(date -d "$password_expiration_date" +'%Y-%m-%d')
            days_until_password_expiration=$(( ($(date -d $password_expiration_date +%s) - $(date -d $todays_date +%s)) / 86400 ))
            echo ALERT! The password for $os_user will expire in $days_until_password_expiration days on $password_expiration_date.
        fi

        if [[ ! "$password_inactive_date" == "never" ]]; then
            password_inactive_date=$(date -d $password_inactive_date +'%Y-%m-%d')
            days_until_password_inactive=$(( ($(date -d $password_inactive_date +%s) - $(date -d $todays_date +%s)) / 86400 ))
            echo ALERT! The password for $os_user will become inactive in $days_until_password_inactive days on $password_expiration_date.
        fi

        if [[ ! "$account_expiration_date" == "never" ]]; then
            account_expiration_date=$(date -d "$account_expiration_date" +'%Y-%m-%d')
            days_until_account_expiration=$(( ($(date -d $account_expiration_date +%s) - $(date -d $todays_date +%s)) / 86400 ))
            echo ALERT! The account $os_user will become inactive in $days_until_password_inactive days on $account_expiration_date.

        fi
    fi





    


    # Calculate the difference in date between todays date and the account expiration date which is days until expiration
    # account_expiration_date_formatted=$(date -d "$account_expiration_date" +'%Y-%m-%d')
    # days_until_account_expiration=$(( ($(date -d $temp_exp +%s) - $(date -d $todays_date +%s)) / 86400 ))
    # echo 


done

# temp_exp=$(sudo chage -l john.smith | grep "^Account expires" | awk -F':' '{print $2}' | xargs)

# todays_date=$(date '+%Y-%m-%d') ; echo $todays_date
# temp_exp=$(date -d "$temp_exp" +'%Y-%m-%d') ; echo $temp_exp


# echo $(( ($(date -d $temp_exp +%s) - $(date -d $todays_date +%s)) / 86400 )) days








