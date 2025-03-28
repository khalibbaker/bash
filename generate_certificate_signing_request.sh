#!/bin/bash

# Init: a <certificate/> directory to be provided as argument 1
certificate_request_directory="$1"

# Init: an array to include list of files in the <certificate/> directory
certificate_request_directory_files_arr=()

# Init: a counter for number of files found in the <certificate/> directory
certificate_request_directory_files_count=0

# Init: a counter for which CSR is being generated
csr_counter=0

# Condition: Check if argument 1 exists
if [ -z "$1" ]
    then
        echo "No <certificate/> directory supplied. Exiting..."
        exit 3
fi

# Conditon: If the directory does not have any files, then exit
if [ -z "$(ls -A "$certificate_request_directory")" ]; then
    echo "The $certificate_request_directory directory is empty. Exiting..."
    exit 3
else
    certificate_request_directory_files_count=$(ls $certificate_request_directory | wc -l)
    echo "There are $certificate_request_directory_files_count files found in directory: $certificate_request_directory/..." ; echo "" ; sleep 2
fi

# Remove any trailing slashes (/) from the directory specified
if [[ "$certificate_request_directory" == */ ]]; then
    certificate_request_directory="${certificate_request_directory%/}"
fi

# Loop: add each file found in the directory to an array
for file in "$certificate_request_directory"/*
do 
    if [ -f "$file" ]; then
        certificate_request_directory_files_arr+=($file)
    fi
done


# Loop: for each file in the certificate directory, generate a private key, private key phrase file, TLS application,
# and certifcate signing request (CSR)
for file in "${certificate_request_directory_files_arr[@]}"
do
    # Begin count of csr process
    let csr_counter++
    echo "Starting CSR generation for CSR:  $csr_counter" ; sleep 2

    # Condition: Check if file is empty
    if ! [ -s "$file" ]; then
        echo "The $file file is empty. Skipping..." ; echo ""
        continue
    fi

    # Init: array to include CN and SANs 
    certificate_list_arr=()

    # Init: a string to include the CN. This should be the first row of servers_list_for_certificates.dat
    certificate_common_name=""

    # Init: a string to include the SAN. This should be remaining rows of servers_list_for_certificates.dat
    certificate_san_arr=()

    # Init: create a file and arrays to build and store the tls_certificate_application_<date>.dat
    tls_certificate_application_file=""
    req_arr=()
    req_distinguished_name_arr=()
    sans_arr=()

    # Init: create a variable to store a passphrase to encrypt the private key
    private_key_credentials=""

    # Store each line of the output of the df -h command as an entry in the array
    IFS=$'\n' certificate_list_arr=( $(cat $file | grep -vE '^#') )

    # Init: counter variable for index of certificate_list_arr
    certificate_list_arr_index_counter=0



    # Loop: interate through the certificate_list_arr. Store the first item as the common name (cn)
    echo "Using the following common name (CN) and [optional] subject alternative name(s)..." ; echo "" ; sleep 3
    for item in "${certificate_list_arr[@]}"
    do
        if [[ $certificate_list_arr_index_counter -eq 0 ]]; then
            certificate_common_name=$(echo $item)
            echo "CN: $certificate_common_name"
            sleep 2
        else
            echo "SAN: $item"
            sans_arr+=($item)
            sleep 2
        fi

        let certificate_list_arr_index_counter++
    done



    # Create a directory to store the certificate TLS application and CSR
    certificate_common_name_dir=$certificate_common_name
    mkdir ./$certificate_common_name_dir

    # Create the TLS Application File
    todays_date=$(date -d "$(date)" +%Y-%m-%d)
    tls_certificate_application_file="$certificate_common_name_dir/TLS_app_$todays_date.dat"
    touch ./$tls_certificate_application_file

    # # Build the TLS Application
    echo "" ; echo "Building the TLS Application from $systems_file..." ; echo "" ; sleep 3
    # Create [ req ] section  of TLS application
    echo "[ req ]" >> $tls_certificate_application_file
    req_arr=(
        "default_bits           = 2048"
        "prompt                 = no"
        "days                   = 365"
        "distinguished_name     = req_distinguished_name"
        "req_extensions         = v3_req"
    )

    for item in "${req_arr[@]}"
    do
        echo $item >> $tls_certificate_application_file
    done
    echo "" >> $tls_certificate_application_file

    # Create the [ req_distinguished_name ] section of TLS application
    echo "[ req_distinguished_name ]" >> $tls_certificate_application_file
    req_distinguished_name_arr=(
        "countryName            = US"
        "stateOrProvinceName    = District of Columbia"
        "localityName           = Washington"
        "organizationName       = Sysad Solutions LLC"
        "organizationalUnitName = Intel"
        "commonName             = $certificate_common_name"
        "emailAddress           = security@sysad.io"
    )
    for item in "${req_distinguished_name_arr[@]}"
    do
        echo $item >> $tls_certificate_application_file
    done
    echo "" >> $tls_certificate_application_file

    # Create the [ v3_req ] section of TLS application
    echo "[ v3_req ]" >> $tls_certificate_application_file
    v3_req_arr=(
        "basicConstraints       = CA:false"
        "extendedKeyUsage       = serverAuth, clientAuth"
        "subjectAltName         = @sans"
    )
    for item in "${v3_req_arr[@]}"
    do
        echo $item >> $tls_certificate_application_file
    done
    echo "" >> $tls_certificate_application_file

    # Create the [ sans ] section of TLS application
    echo "[ sans ]" >> $tls_certificate_application_file
    sans_index=0
    for item in "${sans_arr[@]}"
    do
        echo "DNS.$sans_index = $item" >> $tls_certificate_application_file
        let sans_index++
    done

    # Create the private_key and store the output of private key in a file
    echo "Creating credentials for the private key..." ; echo "" ; sleep 3
    private_key_credentials=$(openssl rand -base64 20) ; echo $private_key_credentials >> $certificate_common_name_dir/private_credentials.help

    # Create the csr
    echo "Generating the CSR..." ; echo "" ; sleep 3
    openssl req -new -passout pass:$private_key_credentials \
    -keyout $certificate_common_name_dir/${certificate_common_name}_private.key \
    -out $certificate_common_name_dir/${certificate_common_name}.csr \
    -config $tls_certificate_application_file 2>/dev/null

    echo "Completed CSR: $csr_counter" ; echo "" ; sleep 2
    # Copy the original file with all the CN and SANs into respective directory
    # cp $file 
    # Send email of CSR attachment

done

# End of script execution
echo "Done." ; echo ""