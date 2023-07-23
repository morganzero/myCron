#!/bin/bash

# Define color codes
GREEN='\e[92m'
YELLOW='\033[1;33m'
NC='\e[0m' # No Color

echo -e "${YELLOW}Starting myCron...${NC}"
crond -b -L /dev/stdout
echo -e "${GREEN}Cron daemon started${NC}"

sleep 1
echo -e "
-------------------------------------------------------------
${GREEN}myCron monitoring schedules${NC}
-------------------------------------------------------------
"

if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

while true; do
  container_names=$(docker ps --format '{{.Names}}' -f label=mycron.enabled=true)

  for name in $container_names
  do
    echo -e "${YELLOW}Processing container name: ${NC}${name}"
    labels=$(docker inspect --format '{{json .Config.Labels}}' $name)
    echo -e "${GREEN}Raw labels from Docker:${NC}"
    echo "$labels"
    echo

    mycron_labels=$(echo $labels | jq -r 'to_entries[] | select(.key | startswith("mycron")) | .key + "=" + .value' )
    echo -e "${GREEN}myCron labels found:${NC}"
    echo "$mycron_labels"
    echo
  
    declare -A job_data

    while IFS= read -r label; do
      key=$(echo $label | cut -d= -f1)
      value=$(echo $label | cut -d= -f2)
      job_id=$(echo $key | cut -d. -f2)
      attribute=$(echo $key | cut -d. -f3)
      unique_key="$name.$job_id.$attribute"
      job_data[$unique_key]=$value
    done <<< "$mycron_labels"

    # Process jobs
    job_ids=$(printf '%s\n' "${!job_data[@]}" | cut -d. -f2 | sort | uniq)
    for job_id in $job_ids; do
      schedule_key="$name.$job_id.schedule"
      command_key="$name.$job_id.command"
      if [[ ${job_data[$schedule_key]} && ${job_data[$command_key]} ]]; then
        schedule=${job_data[$schedule_key]}
        command=${job_data[$command_key]}
      
        echo -e "${YELLOW}Job details:${NC}"
        echo -e "Monitoring job ${GREEN}$job_id${NC} for container ${GREEN}$name${NC}."
        echo -e "It will be executed as per schedule: ${GREEN}$schedule${NC}"
        echo
        echo "Job ID: $job_id"
        echo "Container Name: $name"
        echo "Schedule: $schedule"
        echo "Command: $command"
        echo "-------------------------------------------------------------"
        echo
        # Execute the command according to the schedule
        # Add your logic here
      fi
    done
    unset job_data
  done

  sleep 60
done
