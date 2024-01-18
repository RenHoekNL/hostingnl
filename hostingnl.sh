#!/bin/bash

# To run:
#
# ./hostingnl.sh cleanup
# rm -f /var/log/letsencrypt/letsencrypt.log*
# certbot certonly --manual --manual-auth-hook ./hostingnl.sh -d palli.nl -d *.palli.nl --preferred-challenges dns
# ./hostingnl.sh cleanup
#
# The script requires curl, jq and that you set the API_TOKEN
#
# For more info see:
#   https://api.hosting.nl/api/documentation
#   
# After the certicate is renewed, don't forget to restart or reload any services that use the certificate
#


API_TOKEN="f3d79a6917219948f421d1c53b4fd0003745626fb0e0b3848a8cf0c21aa0a7d7"

#
# DO NOT CHANGE ANYTHING BELOW THIS LINE
#


# Set variables
IFS=$'\n'
HEADERS=(
  --header "Content-Type: application/json"
  --header "Accept: application/json"
  --header "API-TOKEN: ${API_TOKEN}"
)

URL="https://api.hosting.nl/domains"
DOMAIN="${CERTBOT_DOMAIN}"
ALL_DOMAINS="$(curl -sSk -X GET ${HEADERS[*]} "${URL}" | jq -r '.data[] | .domain')"

# Clean up
rm -f /tmp/hostingnl.*

# Delete acme-challenge for all domains
function cleanup
{
for D in "$ALL_DOMAINS"; do
  {
  rm -f /tmp/hostingnl.current_dns /tmp/hostingnl.delete

  # Get current list of DNS entries for this domain
  curl -sSk -X GET ${HEADERS[*]} "${URL}/${D}/dns" > /tmp/hostingnl.current_dns
  if [ "$(jq -r '.success' /tmp/hostingnl.current_dns)" \!= "true" ]; then
    {
    echo "Can not retrieve current DNS list"
    exit
    }
  fi

  # Get the IDs of entries with the name _acme-challenge
  ID="$(jq -r '.data[] | select(.name | test("^_acme-challenge.*")) | .id' /tmp/hostingnl.current_dns)"

  # Generate a JSON with the ID's of _acme-challenge entries
  {
  echo -n "["
  for x in ${ID}; do echo -n "{\"id\":$x},"; done
  } | sed 's/,$/]/' > /tmp/hostingnl.ids

  # Delete those entries (if there are any)
  if [ "$(cat /tmp/hostingnl.ids)" \!= "[" ]; then
    cat /tmp/hostingnl.ids | curl -sSk -X DELETE ${HEADERS[*]} --data-binary @- "${URL}/${D}/dns" > /tmp/hostingnl.delete
  fi
  }
done
}

# Insert the new _acme-challenge
# Important to keep in mind that TXT records need their values given in quotes
# Know that you can have multiple TXT fields with the same name
function add
{
cat << EOF | curl -sSk -X POST ${HEADERS[*]} --data-binary @- "${URL}/${DOMAIN}/dns" > /tmp/hostingnl.insert
[
  {
    "name": "_acme-challenge",
    "type": "TXT",
    "content": "\"${CERTBOT_VALIDATION}\"",
    "ttl": "3600",
    "prio": "0"
  }
]
EOF
}

#
# MAIN
#

if [ "$1" == "cleanup" ]; then
  cleanup
  else
  add
fi


# Clean up
rm -f /tmp/hostingnl.*

# EOF
