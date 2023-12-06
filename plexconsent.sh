#!/bin/bash

# Replace '[REDACTED]' with your actual Plex token
TOKEN='[REDACTED]'

# Fetch consent data
consentlist=$(curl -sX GET 'https://plex.tv/api/v2/user/consent'  -H "X-Plex-Token: $TOKEN"  -H "Accept: application/json")

# For testing, change false to true, language to null
#consentlist=$(sed 's/"language":"en"/"language":null/g; s/"consent":false/"consent":true/g' <<<$consentlist)

# Load vendors giving concent into variable
plexconsent=$(jq  -r '.vendors[] | select(.consent) | "\( .id)"' <<<$consentlist)

# If consent has been given to some sites - check them
if [ -n "$plexconsent" ]
then
  # Download vendor list
  vendorlist=$(curl -s GET "https://plex.tv/api/v2/ads/vendors?region=US")
  # List out the vendors with consent given
  echo "The following vendors have consent to gather your info from Plex:"
  while IFS= read -r line
    do
      echo $vendorlist | jq -r --argjson i $line '.vendors[] | select(.id == $i).name'
  done <<< "$plexconsent"
else
  echo "No changes"
  exit 0
fi

# Updating consent and language
modifiedconsent=$(jq '.language="en"' <<<$consentlist | jq '. | .vendors[].consent = false')

# Update consent data
curl --fail -sX PUT 'https://plex.tv/api/v2/user/consent'  -H "X-Plex-Token: $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" --data "$modifiedconsent"
# Exit cleanly or with an error code
exit_code=$?
if [ $exit_code != 0 ]
then
  echo "Error posting updated consent to Plex"
  exit $exit_code
fi
