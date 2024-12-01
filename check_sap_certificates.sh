#!/bin/bash

# Init: variable to store the location of the certificate directory 
sap_certificate_pse_directory=""

# Init: an array to store certificates in that directory
sap_certificates_pse_arr=()

# Init: a variable to store the number of pse on the sap system and number of expired certificates
sap_certificate_counter=0
sap_expired_certificate_counter=0

# Init: variables to store information about the certificates stored
sap_certificate_cn=""
sap_certificate_expiration_date=""
days_until_certificate_expiration=0

# Init: variable for todays date
todays_date=$(date -d "$(date)" +%Y-%m-%d)

# Init: variable to store threshold to use for less than number of x days
threshold=100 # 10000 days

# Store all .pse files into an array 
shopt -s nullglob
mapfile -t sap_certificates_pse_arr < <(find -L /usr/sap/HX1 -name '*.pse' -print)

# Loop: each item is a *.pse file , for each file grab the CN and calcuate the number of days until expiration. If expiration is less than
# 60 days, alert
echo Checking certificates on $(hostname) ... ; echo ""
for item in "${sap_certificates_pse_arr[@]}"
do
    # Condition: if pse contains system_pki in the file name, then skip. We don't care about the system_pki
    if [[ $item =~ "system_pki" ]]; then
        continue
    fi
    # Store output of sapgense into a variable
    sapgenpse_output=`sapgenpse get_my_name -p $item 2>&1`

    # Get the CN of the certificate stored in .pse file
    sap_certificate_cn=$(echo "${sapgenpse_output[@]}" | grep Subject | grep -v ^SubjectAltName | awk -F':' '{print $2}' | awk -F',' '{print $1}' | xargs)
    
    # Get the certificate expiration date
    sap_certificate_expiration_date=$(echo "${sapgenpse_output[@]}" | grep NotAfter | awk -F'After :' '{print $2}' | awk '{$NF="";sub(/[ \t]+$/,"")}1' | awk '{print $2, $3, $5}')
    sap_certificate_expiration_date=$(date -d "$sap_certificate_expiration_date" +%Y-%m-%d)

    # Calculate the difference in certificate expiration date and today's date
    let days_until_certificate_expiration=($(date +%s -d $sap_certificate_expiration_date)-$(date +%s -d $todays_date))/86400

    if [[ $days_until_certificate_expiration -lt $threshold ]]; then
        let sap_expired_certificate_counter++ # Count expired certificate
        # Send email alert
        echo Check the following certificate on $(hostname) at $item
        echo $sap_certificate_cn expires in $days_until_certificate_expiration days on $sap_certificate_expiration_date
        echo ""
    else
        # (optional) store certificate information into an array
        echo The following certificate on $(hostname) at $item
        echo $sap_certificate_cn expires in $days_until_certificate_expiration days on $sap_certificate_expiration_date
        echo ""
    fi

    let sap_certificate_counter++ # Count certificate found

done

# Summary statement of certificates
echo $(hostname) has $sap_certificate_counter certificates with $sap_expired_certificate_counter needing attention.
