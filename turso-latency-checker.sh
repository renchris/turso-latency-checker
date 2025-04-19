#!/bin/bash

# Turso Latency Checker (Simple Version)
# A simple script to measure latency to all Turso locations

# List of Turso locations
LOCATIONS=("ams" "arn" "atl" "bog" "bom" "bos" "cdg" "den" "dfw" "ewr" "eze" "fra" "gdl" "gig" "gru" "hkg" "iad" "jnb" "lax" "lhr" "mad" "mia" "nrt" "ord" "otp" "phx" "qro" "scl" "sea" "sin" "sjc" "syd" "waw" "yul" "yyz")

# Gateway regions
GATEWAY_REGIONS=("ams" "cdg" "dfw" "fra" "hkg" "iad" "lax" "lhr" "nrt" "ord" "scl" "sea" "sin" "sjc" "syd" "yyz")

# Location names mapping for better readability
get_location_name() {
  case "$1" in
    "ams") echo "Amsterdam, Netherlands" ;;
    "arn") echo "Stockholm, Sweden" ;;
    "atl") echo "Atlanta, Georgia (US)" ;;
    "bog") echo "Bogotá, Colombia" ;;
    "bom") echo "Mumbai, India" ;;
    "bos") echo "Boston, Massachusetts (US)" ;;
    "cdg") echo "Paris, France" ;;
    "den") echo "Denver, Colorado (US)" ;;
    "dfw") echo "Dallas, Texas (US)" ;;
    "ewr") echo "Secaucus, NJ (US)" ;;
    "eze") echo "Buenos Aires, Argentina" ;;
    "fra") echo "Frankfurt, Germany" ;;
    "gdl") echo "Guadalajara, Mexico" ;;
    "gig") echo "Rio de Janeiro, Brazil" ;;
    "gru") echo "São Paulo, Brazil" ;;
    "hkg") echo "Hong Kong, Hong Kong" ;;
    "iad") echo "Ashburn, Virginia (US)" ;;
    "jnb") echo "Johannesburg, South Africa" ;;
    "lax") echo "Los Angeles, California (US)" ;;
    "lhr") echo "London, United Kingdom" ;;
    "mad") echo "Madrid, Spain" ;;
    "mia") echo "Miami, Florida (US)" ;;
    "nrt") echo "Tokyo, Japan" ;;
    "ord") echo "Chicago, Illinois (US)" ;;
    "otp") echo "Bucharest, Romania" ;;
    "phx") echo "Phoenix, Arizona (US)" ;;
    "qro") echo "Querétaro, Mexico" ;;
    "scl") echo "Santiago, Chile" ;;
    "sea") echo "Seattle, Washington (US)" ;;
    "sin") echo "Singapore, Singapore" ;;
    "sjc") echo "San Jose, California (US)" ;;
    "syd") echo "Sydney, Australia" ;;
    "waw") echo "Warsaw, Poland" ;;
    "yul") echo "Montreal, Canada" ;;
    "yyz") echo "Toronto, Canada" ;;
    *) echo "Unknown location" ;;
  esac
}

# Define formatting codes
CYAN='\033[0;36m'
BOLD='\033[1m'
BOLD_CYAN='\033[1;36m'  # Combine bold and cyan
RESET='\033[0m'

# Temporary directory for storing results
TEMP_DIR="/tmp/turso_latency_$$"
mkdir -p "$TEMP_DIR"

# Function to measure latency for a single location
measure_latency() {
  local location="$1"
  local url="http://region.turso.io:8080/"
  local timeout=3
  
  # Run curl and capture its built-in timing
  local result=$(curl -s -o /dev/null -w "%{time_total}" --max-time $timeout -H "fly-prefer-region: $location" "$url")
  local exit_code=$?
  
  if [ "$exit_code" -eq 0 ]; then
    local duration=$(echo "$result * 1000" | bc | cut -d. -f1)
    echo "$duration" > "$TEMP_DIR/$location"
  else
    echo "ERROR" > "$TEMP_DIR/$location"
  fi
}

# Check if a location is a gateway
is_gateway() {
  local location="$1"
  for gateway in "${GATEWAY_REGIONS[@]}"; do
    if [ "$gateway" = "$location" ]; then
      echo "✓"
      return
    fi
  done
  echo " "
}

# Main script
echo "Turso Latency Checker"
echo "====================="
echo "Measuring latency to all Turso locations..."
echo

# Start the latency tests in the background
for location in "${LOCATIONS[@]}"; do
  measure_latency "$location" &
done

# Show a spinner animation as progress indicator
echo -n "Running tests: "
spinner=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
total=${#LOCATIONS[@]}
i=0
while true; do
  completed=$(ls "$TEMP_DIR" | wc -l)
  echo -ne "\rRunning tests: ${spinner[$i]} "
  
  if [ "$completed" -eq "$total" ]; then
    echo -e "\rRunning tests: Complete!          "
    break
  fi
  
  i=$(( (i+1) % ${#spinner[@]} ))
  sleep 0.1
done

echo

# All tests are now complete - collect and sort the results
echo "RESULTS (sorted by latency)"
echo "--------------------------------------------------------------------------------"
printf "%-6s  %-36s  %11s  %s\n" "ID" "LOCATION" "LATENCY" "GATEWAY"
echo "--------------------------------------------------------------------------------"

# Get all locations with their latency (excluding errors)
successful_locations=()
for location in "${LOCATIONS[@]}"; do
  if [ -f "$TEMP_DIR/$location" ] && [ "$(cat "$TEMP_DIR/$location")" != "ERROR" ]; then
    successful_locations+=("$location $(cat "$TEMP_DIR/$location")")
  fi
done

# Sort by latency (second field)
IFS=$'\n' sorted_locations=($(echo "${successful_locations[*]}" | sort -n -k2))
unset IFS

# Get the fastest location
fastest_location=$(echo "${sorted_locations[0]}" | awk '{print $1}')
fastest_latency=$(echo "${sorted_locations[0]}" | awk '{print $2}')

# Print sorted results
for entry in "${sorted_locations[@]}"; do
  location=$(echo "$entry" | awk '{print $1}')
  latency=$(echo "$entry" | awk '{print $2}')
  gateway_mark=$(is_gateway "$location")
  
  # Make sure location name is not too long
  location_name=$(get_location_name "$location")
  if [ ${#location_name} -gt 36 ]; then
    location_name="${location_name:0:33}..."
  fi
  
  # Add special handling for cities with non-ASCII characters and highlight fastest
  if [ "$location" = "$fastest_location" ]; then
    case "$location" in
      "gru"|"bog"|"qro")
        printf "${BOLD}%-6s  %-36s   ${BOLD_CYAN}%11s${RESET}${BOLD}  %s${RESET}\n" "$location" "$location_name" "${latency}ms" "$gateway_mark"
        ;;
      *)
        printf "${BOLD}%-6s  %-36s  ${BOLD_CYAN}%11s${RESET}${BOLD}  %s${RESET}\n" "$location" "$location_name" "${latency}ms" "$gateway_mark"
        ;;
    esac
  else
    case "$location" in
      "gru"|"bog"|"qro")
        printf "%-6s  %-36s   %11s  %s\n" "$location" "$location_name" "${latency}ms" "$gateway_mark"
        ;;
      *)
        printf "%-6s  %-36s  %11s  %s\n" "$location" "$location_name" "${latency}ms" "$gateway_mark"
        ;;
    esac
  fi
done

# List failed locations
failed_locations=()
for location in "${LOCATIONS[@]}"; do
  if [ -f "$TEMP_DIR/$location" ] && [ "$(cat "$TEMP_DIR/$location")" = "ERROR" ]; then
    failed_locations+=("$location")
  fi
done

if [ ${#failed_locations[@]} -gt 0 ]; then
  echo
  echo "Failed to connect to these regions:"
  for location in "${failed_locations[@]}"; do
    echo "- $location ($(get_location_name "$location"))"
  done
fi

# Show fastest region
if [ ${#sorted_locations[@]} -gt 0 ]; then
  fastest_entry="${sorted_locations[0]}"
  fastest_location=$(echo "$fastest_entry" | awk '{print $1}')
  fastest_latency=$(echo "$fastest_entry" | awk '{print $2}')
  
  # Check if it's a gateway
  gateway_info=""
  if [ "$(is_gateway "$fastest_location")" = "✓" ]; then
    gateway_info=" (Gateway Region)"
  fi
  
  echo
  echo -e "Fastest region: ${BOLD}$fastest_location ($(get_location_name "$fastest_location")) - ${BOLD_CYAN}${fastest_latency}ms${RESET}${BOLD}${gateway_info}${RESET}"
else
  echo
  echo "No successful connections to any region."
fi

echo

# Clean up
rm -rf "$TEMP_DIR" 