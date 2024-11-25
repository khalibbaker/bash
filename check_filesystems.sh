#!/bin/bash


# Init: an array named filesystems_arr with the first element removed. The first element is the first row output from df -h 
# mapfile -t filesystems_arr < <( df -h )

# IFS=$'\n' filesystems_arr=( $(df -h) )
# filesystems_arr=( `df -h` )
readarray -t filesystems_arr < <(df -h)

# Init: a variable to store file system 
filesystem_name=""

# Init: a variable to store current usage
filesystem_usage=""

# Init: a variable to store mounted on directory director
mounted_directory=""

# Init: an array to store the disk usages
disk_usage=()

# Init: a variable for filesystem threshold (i.e. filesystem more than X % used)
threshold=90

readarray -t disk_usage < <(df -h | grep -vE "^Filesystem|tmpfs|cdrom")

filesystem_usage=$(echo $disk_usage[1]} | awk '{print $5}')
filesystem_usage=${filesystem_usage::-1}


echo $filesystem_usage

if [ "$filesystem_usage" -gt "$threshold" ]; then
    echo ALERT

fi










# echo ${filesystems_arr[0]} | awk '{print $5}' | cut -c1-2
# echo $threshold

# # Loop: to loop through array of filesystems outputed by df -h
# for item in ${filesystems_arr[@]}
# do
#     # echo $item
#     file_system_usage=$(echo ${filesystems_arr[$item]} | awk '{print $5}' | cut -c1-2)
#     echo $file_system_usage


# done