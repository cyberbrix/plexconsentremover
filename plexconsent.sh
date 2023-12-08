#!/bin/bash

#requirements
# jq

# check if JQ installed
if ! type jq &> /dev/null
then
  echo "jq is not installed"
  exit 1
fi


# Replace '[REDACTED]' with your actual Plex token
TOKEN='[REDACTED]'
TOKEN='SUzw1tsUm6sCDHE8PZZd'

# Fetch consent data
consentlist=$(curl -sX GET 'https://plex.tv/api/v2/user/consent'  -H "X-Plex-Token: $TOKEN"  -H "Accept: application/json")
if [ $? != 0 ]
then
  echo "Error connecting to Plex.tv"
  exit 1
fi


# Data validation
echo "$consentlist" | grep -q "vendorListVersion"
if [ $? != 0 ]
then
  echo "Vendor List not downloaded"
  echo "$consentlist"
  exit 1
fi 


# For testing, change false to true, language to null
#consentlist=$(sed 's/"language":"en"/"language":null/g; s/"consent":false/"consent":true/g' <<<"$consentlist")

# Load vendors giving concent into variable
plexconsent=$(jq  -r '.vendors[] | select(.consent) | "\( .id)"' <<<"$consentlist")

# If consent has been given to some sites - check them
if [ -n "$plexconsent" ]
then
  # Download vendor list
  vendorlist=$(curl -s GET "https://plex.tv/api/v2/ads/vendors?region=US")
  # List out the vendors with consent given
  echo "The following vendors have consent to gather your info from Plex. Removing concent."
  while IFS= read -r line
    do
      jq -r --argjson i $line '.vendors[] | select(.id == $i).name' <<<"$vendorlist"
  done <<< "$plexconsent"
else
  # echo "No changes" - keep commented for use in a cronjob
  exit 0
fi

# Updating consent and language
modifiedconsent=$(jq '.language="en"' <<<"$consentlist" | jq '. | .vendors[].consent = false')

# Update consent data
curl --fail -sX PUT 'https://plex.tv/api/v2/user/consent'  -H "X-Plex-Token: $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" --data "$modifiedconsent"

# Exit cleanly or with an error code
exit_code=$?
if [ $exit_code != 0 ]
then
  echo "Error updating consent to Plex"
  exit $exit_code
else
  echo "Updated consent status"
  exit 0
fi
