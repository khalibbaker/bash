#!/bin/bash


# Init: an array named filesystems_arr with the first element removed. The first element is the first row output from df -h 
filesystems_arr=()

# Init: a variable to store file system 
filesystem_name=""

# Init: a variable to store current usage
filesystem_usage=""

# Init: a variable to count the filesystems triggered by threshold
filesystem_threshold_counter=0

# Init: a variable to store mounted on directory director
mounted_directory=""

# Init: a variable for filesystem threshold (i.e. filesystem more than X % used)
threshold=1


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