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
  container_ids=$(docker ps -q -f label=mycron.enabled=true)

  for id in $container_ids
  do
    echo -e "${YELLOW}Processing container ID: ${id}${NC}"
    labels=$(docker inspect --format '{{json .Config.Labels}}' $id)

    mycron_labels=$(echo $labels | jq -r 'to_entries[] | select(.key | startswith("mycron")) | .key + "=" + .value' )
    echo -e "${GREEN}mycron labels:${NC}"
    echo "$mycron_labels"
  
    declare -A job_data

    while IFS= read -r label; do
      key=$(echo $label | cut -d= -f1)
      value=$(echo $label | cut -d= -f2)
      job_id=$(echo $key | cut -d. -f2)
      attribute=$(echo $key | cut -d. -f3)
      job_data[$job_id.$attribute]=$value
    done <<< "$mycron_labels"

    for job_id_attribute in "${!job_data[@]}"; do
      job_id=$(echo $job_id_attribute | cut -d. -f1)
      if [[ ${job_data[$job_id.schedule]} && ${job_data[$job_id.command]} ]]; then
        schedule=${job_data[$job_id.schedule]}
        command=${job_data[$job_id.command]}
      
        echo -e "${GREEN}Job details:${NC}"
        echo "Job ID: $job_id"
        echo "Container ID: $id"
        echo "Schedule: $schedule"
        echo "Command: $command"
        echo "Monitoring job $job_id for container $id. It will be executed as per schedule: $schedule"
      
        # Execute the command according to the schedule
        # Add your logic here
      fi
    done
    unset job_data
  done

  sleep 60
done
