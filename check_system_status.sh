#!/bin/bash

# Init: a <systems>.dat file to be provided as argument 1
systems_file="$1"

# Check if argument 1 exists
if [ -z "$1" ]
    then
        echo "No <system>.dat file supplied. Exiting..."
        exit 3
fi

# Init: sap_service_name variable to store the name of the sap service (message, enque, icman, etc.)
sap_service_name=""

# Init: sap_service_status variable to store the status of the sap service (GREEN, YELLOW, RED)
sap_service_status=""

# Init: sapcontrol_full_output to store the complete output of the sapcontrol command of GetProcess:List
sapcontrol_full_ouput=()

# Retrieve system information (ip address, hostname, instance(s))
# Init: instance_number to store the output of the instance number
# *** Need to account for more instances ***
instance_number=$(grep $(hostname) $systems_file | awk '{print $4}' | tail -c 3)

# Output the status of sapcontrol to an array. Each line is an item in the array
mapfile -t sapcontrol_full_output < <(sapcontrol -nr $instance_number -function GetProcessList)

# Remove the first three entries from the array (date, ok, etc.)
sapcontrol_short=("${sapcontrol_full_output[@]:5}")


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
