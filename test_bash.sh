#1!/bin/bash

todays_date=$(date -d "$(date)" +%Y-%m-%d)
echo ${todays_date}_${SAPSYSTEMNAME}