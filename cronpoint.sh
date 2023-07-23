#!/bin/bash

# Start the cron daemon
crond -b -L /dev/stdout

# Check if ENV_FILE is set and if yes, source it
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

# Get the IDs of the containers with the mycron labels
container_ids=$(docker ps -q -f label=mycron)

for id in $container_ids
do
  # Get all labels for the container
  labels=$(docker inspect --format '{{json .Config.Labels}}' $id)
  
  # Filter out the labels that are not part of mycron and convert to lines
  mycron_labels=$(echo $labels | jq -r 'to_entries[] | select(.key | startswith("mycron")) | .key + "=" + .value' )

  # If mycron is not enabled for this container, skip it
  if ! echo "$mycron_labels" | grep -q "mycron.enabled=true"; then
    continue
  fi

  # Temporary associative array to hold job data
  declare -A job_data

  # Loop over mycron labels
  while IFS= read -r label; do
    # Extract job id, schedule and command from label
    key=$(echo $label | cut -d= -f1)
    value=$(echo $label | cut -d= -f2)
    job_id=$(echo $key | cut -d. -f2)
    attribute=$(echo $key | cut -d. -f3)

    # Add to job_data array
    job_data[$job_id.$attribute]=$value
  done <<< "$mycron_labels"

  # Now, loop over job_data array and execute if both schedule and command are defined
  for job_id_attribute in "${!job_data[@]}"; do
    job_id=$(echo $job_id_attribute | cut -d. -f1)
    if [[ ${job_data[$job_id.schedule]} && ${job_data[$job_id.command]} ]]; then
      schedule=${job_data[$job_id.schedule]}
      command=${job_data[$job_id.command]}
      
      # Echo job details
      echo "Job ID: $job_id"
      echo "Container ID: $id"
      echo "Schedule: $schedule"
      echo "Command: $command"
      echo "Monitoring job $job_id for container $id, it will be executed as per schedule: $schedule"
      
      # Execute the command according to the schedule
      # Add your logic here

      # If DS_WEBHOOK is defined, send a POST request to the Discord webhook
      if [ -n "$DS_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
          --data '{"content":"Cron job for container '${id}' with job id '${job_id}' has been executed."}' \
          $DS_WEBHOOK
      fi
    fi
  done

  # Unset the temporary job_data array
  unset job_data
done

tail -f /dev/null
