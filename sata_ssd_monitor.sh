  1 #!/bin/bash
  2 
  3 # Configuration
  4 DEVICE="/dev/sda"
  5 LOG_FILE="/var/log/sata_ssd_monitor.log"
  6 TEMP_FILE="/tmp/sata_ssd_monitor_temp.txt"
  7 
  8 # Function to get SMART data
  9 get_smart_data() {
 10     smartctl -a $DEVICE > $TEMP_FILE
 11 }
 12 
 13 # Function to extract value for a given attribute
 14 get_value() {
 15     local attr=$1
 16     local column=$2
 17     grep "$attr" $TEMP_FILE | awk -v col="$column" '{print $col}' | tr -d ' '
 18 }
 19 
 20 # Function to get previous value from log file
 21 get_previous_value() {
 22     local attr=$1
 23     grep "$attr:" $LOG_FILE | tail -1 | awk -F': ' '{print $2}'
 24 }
 25 
 26 # Function to compare current and previous values
 27 compare_values() {
 28     local attr=$1
 29     local current=$2
 30     local previous=$3
 31     local threshold=$4
 32 
 33     if [ ! -z "$previous" ] && [ "$current" != "$previous" ]; then
 34         # Check if both values are numeric
 35         if [[ "$current" =~ ^[0-9]+$ ]] && [[ "$previous" =~ ^[0-9]+$ ]]; then
 36             local diff=$((current - previous))
 37             if [ $diff -lt 0 ]; then
 38                 diff=$((diff * -1))
 39             fi
 40             if [ $diff -ge $threshold ]; then
 41                 echo "$attr changed from $previous to $current"
 42             fi
 43         elif [ "$current" != "$previous" ]; then
 44             # If values are not numeric but different, report the change
 45             echo "$attr changed from $previous to $current"
 46         fi
 47     fi
 48 }
 49 
 50 # Get current SMART data
 51 get_smart_data
 52 
 53 # Extract current values
 54 TEMP=$(get_value "Temperature_Celsius" 10)
 55 READ_ERROR_RATE=$(get_value "Raw_Read_Error_Rate" 10)
 56 REALLOCATED_SECTOR_CT=$(get_value "Reallocated_Sector_Ct" 10)
 57 POWER_ON_HOURS=$(get_value "Power_On_Hours" 10)
 58 POWER_CYCLE_COUNT=$(get_value "Power_Cycle_Count" 10)
 59 PROGRAM_FAIL_COUNT=$(get_value "Program_Fail_Count_Chip" 10)
 60 UNCORRECTABLE_ERRORS=$(get_value "Reported_Uncorrect" 10)
 61 LBAs_WRITTEN=$(get_value "Total_LBAs_Written" 10)
 62 LBAs_READ=$(get_value "Total_LBAs_Read" 10)
 63 
 64 # Compare with previous values if log file exists
 65 CHANGES=""
 66 if [ -f $LOG_FILE ]; then
 67     PREV_TEMP=$(get_previous_value "Temperature")
 68     PREV_READ_ERROR_RATE=$(get_previous_value "Raw Read Error Rate")
 69     PREV_REALLOCATED_SECTOR_CT=$(get_previous_value "Reallocated Sector Count")
 70     PREV_POWER_ON_HOURS=$(get_previous_value "Power On Hours")
 71     PREV_POWER_CYCLE_COUNT=$(get_previous_value "Power Cycle Count")
 72     PREV_PROGRAM_FAIL_COUNT=$(get_previous_value "Program Fail Count")
 73     PREV_UNCORRECTABLE_ERRORS=$(get_previous_value "Uncorrectable Errors")
 74     PREV_LBAs_WRITTEN=$(get_previous_value "Total LBAs Written")
 75     PREV_LBAs_READ=$(get_previous_value "Total LBAs Read")
 76 
 77     CHANGES+=$(compare_values "Temperature" $TEMP "$PREV_TEMP" 5)
 78     CHANGES+=$(compare_values "Raw Read Error Rate" $READ_ERROR_RATE "$PREV_READ_ERROR_RATE" 10)
 79     CHANGES+=$(compare_values "Reallocated Sector Count" $REALLOCATED_SECTOR_CT "$PREV_REALLOCATED_SECTOR_CT" 1)
 80     CHANGES+=$(compare_values "Power On Hours" $POWER_ON_HOURS "$PREV_POWER_ON_HOURS" 24)
 81     CHANGES+=$(compare_values "Power Cycle Count" $POWER_CYCLE_COUNT "$PREV_POWER_CYCLE_COUNT" 5)
 82     CHANGES+=$(compare_values "Program Fail Count" $PROGRAM_FAIL_COUNT "$PREV_PROGRAM_FAIL_COUNT" 1)
 83     CHANGES+=$(compare_values "Uncorrectable Errors" $UNCORRECTABLE_ERRORS "$PREV_UNCORRECTABLE_ERRORS" 1)
 84     CHANGES+=$(compare_values "Total LBAs Written" $LBAs_WRITTEN "$PREV_LBAs_WRITTEN" 1000000)
 85     CHANGES+=$(compare_values "Total LBAs Read" $LBAs_READ "$PREV_LBAs_READ" 1000000)
 86 fi
