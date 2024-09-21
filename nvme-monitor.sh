#!/bin/bash

# Configuration
DEVICE="/dev/nvme0n1"
LOG_FILE="/var/log/nvme_monitor.log"
TEMP_FILE="/tmp/nvme_monitor_temp.txt"

# Function to get SMART data
get_smart_data() {
    smartctl -a $DEVICE > $TEMP_FILE
}

# Function to extract value for a given attribute
get_value() {
    local attr=$1
    grep "$attr" $TEMP_FILE | awk -F':' '{print $2}' | awk '{print $1}' | sed 's/\[.*\]//g'
}

# Function to get previous value from log file
get_previous_value() {
    local attr=$1
    grep "$attr:" $LOG_FILE | tail -1 | awk -F': ' '{print $2}'
}

# Function to compare current and previous values
compare_values() {
    local attr=$1
    local current=$2
    local previous=$3
    local threshold=$4

    if [ ! -z "$previous" ] && [ "$current" != "$previous" ]; then
        # Check if both values are numeric (including floating-point)
        if [[ "$current" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$previous" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            local diff=$(awk "BEGIN {print $current - $previous}")
            local abs_diff=$(awk "BEGIN {print ($diff < 0) ? -$diff : $diff}")
            if (( $(echo "$abs_diff >= $threshold" | bc -l) )); then
                echo "$attr changed from $previous to $current"
            fi
        elif [ "$current" != "$previous" ]; then
            # If values are not numeric but different, report the change
            echo "$attr changed from $previous to $current"
        fi
    fi
}

# Get current SMART data
get_smart_data

# Extract current values
TEMP=$(get_value "Temperature:")
SPARE=$(get_value "Available Spare:")
USED=$(get_value "Percentage Used:")
POWER_ON=$(get_value "Power On Hours:")
UNSAFE_SHUTDOWNS=$(get_value "Unsafe Shutdowns:")
ERRORS=$(get_value "Media and Data Integrity Errors:")
DATA_UNITS_READ=$(get_value "Data Units Read:")
DATA_UNITS_WRITTEN=$(get_value "Data Units Written:")

# Compare with previous values if log file exists
CHANGES=""
if [ -f $LOG_FILE ]; then
    PREV_TEMP=$(get_previous_value "Temperature")
    PREV_SPARE=$(get_previous_value "Available Spare")
    PREV_USED=$(get_previous_value "Percentage Used")
    PREV_POWER_ON=$(get_previous_value "Power On Hours")
    PREV_UNSAFE_SHUTDOWNS=$(get_previous_value "Unsafe Shutdowns")
    PREV_ERRORS=$(get_previous_value "Media and Data Integrity Errors")
    PREV_DATA_UNITS_READ=$(get_previous_value "Data Units Read")
    PREV_DATA_UNITS_WRITTEN=$(get_previous_value "Data Units Written")

    CHANGES+=$(compare_values "Temperature" $TEMP "$PREV_TEMP" 5)
    CHANGES+=$(compare_values "Available Spare" $SPARE "$PREV_SPARE" 1)
    CHANGES+=$(compare_values "Percentage Used" $USED "$PREV_USED" 1)
    CHANGES+=$(compare_values "Power On Hours" $POWER_ON "$PREV_POWER_ON" 24)
    CHANGES+=$(compare_values "Unsafe Shutdowns" $UNSAFE_SHUTDOWNS "$PREV_UNSAFE_SHUTDOWNS" 1)
    CHANGES+=$(compare_values "Media and Data Integrity Errors" $ERRORS "$PREV_ERRORS" 1)
    CHANGES+=$(compare_values "Data Units Read" $DATA_UNITS_READ "$PREV_DATA_UNITS_READ" 1000)
    CHANGES+=$(compare_values "Data Units Written" $DATA_UNITS_WRITTEN "$PREV_DATA_UNITS_WRITTEN" 10)
fi

# Log current values
echo "$(date) Temperature: $TEMP" >> $LOG_FILE
echo "$(date) Available Spare: $SPARE" >> $LOG_FILE
echo "$(date) Percentage Used: $USED" >> $LOG_FILE
echo "$(date) Power On Hours: $POWER_ON" >> $LOG_FILE
echo "$(date) Unsafe Shutdowns: $UNSAFE_SHUTDOWNS" >> $LOG_FILE
echo "$(date) Media and Data Integrity Errors: $ERRORS" >> $LOG_FILE
echo "$(date) Data Units Read: $DATA_UNITS_READ" >> $LOG_FILE
echo "$(date) Data Units Written: $DATA_UNITS_WRITTEN" >> $LOG_FILE

# Send email if changes detected
if [ ! -z "$CHANGES" ]; then
    echo -e "NVMe Drive Monitor Report\n\nChanges detected:\n$CHANGES" | mail -s "NVMe Drive Status Change" root
fi

# Clean up
rm $TEMP_FILE
