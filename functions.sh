# List of useful functions that can be called


# get_hana_system_status - this function runs sapcontrol against all instances in a system and 
# prints the status of each sap service (hdbindexserver, etc.)

function get_hana_system_status () {

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


# get_hana_system_status - this function runs sapcontrol against all instances in a system and 
# prints the status of each sap service (hdbindexserver, etc.)

function get_hana_users_expiring_soon (){

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

function check_filesystems(){
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