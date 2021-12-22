
#!/bin/bash

DNS_API="https://dns.myhuaweicloud.com/v2/zones"

if [ -z "$HW_USER"]; then
    HW_USER=$(jq -r .user auth.json)
fi
if [ -z "$HW_PASSWORD"]; then
    HW_PASSWORD=$(jq -r .password auth.json)
fi
if [ -z "$ACCOUNT"]; then
    ACCOUNT=$(jq -r .account auth.json)
fi
if [ -z "$REGION"]; then
    REGION=$(jq -r .region auth.json)
fi

if [[ ! $(which jq) || ! $(which curl) || ! $(which dig) ]]; then
    echo "Please install \"jq\", \"dig\" and \"curl\" to run script"
    exit 1
fi

LOGIN=$(curl -X POST https://iam.myhuaweicloud.com/v3/auth/tokens\?nocatalog\=true -d '{"auth": {"identity": {"methods": ["password"], "password": {"user": {"domain": {"name": "'${ACCOUNT}'"}, "name": "'${HW_USER}'", "password": "'${HW_PASSWORD}'"}}}, "scope": {"project": {"name": "'${REGION}'"}}}}' -is)
RESPONSE=$(echo "${LOGIN}" | grep "HTTP/1.1" | awk '{print $2}')
if (("$RESPONSE" < 200 || "$RESPONSE" > 201)); then
    echo "Error during authentication"
    echo "${LOGIN}" | tail -1 | jq
    exit 1
else
    TOKEN=$(echo "${LOGIN}" | grep X-Subject-Token | awk '{print $2}')
    DOMAIN="${CERTBOT_DOMAIN}"
fi

echo "Looking for public zone..."
while [[ "$DOMAIN" == *"."* && -z "$ZONE_ID" ]]; do
    echo "$DOMAIN"
    ZONE_ID=$(curl -H "Content-Type: application/json" -H "X-Auth-Token: ${TOKEN}" -s -X GET "${DNS_API}" | jq '.zones[] | select(.name=="'${DOMAIN}'.")' | jq -r '.id')
    DOMAIN=$(echo "${DOMAIN#*.}")
done

if [ -z "$ZONE_ID" ]; then
    echo "No public zones available for $CERTBOT_DOMAIN"
    exit 1
elif [ -z "$CERTBOT_AUTH_OUTPUT" ]; then
    RESULT_TXT=$(curl -H "Content-Type: application/json" -H "X-Auth-Token: ${TOKEN}" -s -X POST ${DNS_API}/${ZONE_ID}/recordsets -d '{"name": "_acme-challenge.'${CERTBOT_DOMAIN}'.", "type": "TXT", "ttl": 300, "records": ["\"'$CERTBOT_VALIDATION'\""]}')
    RESULT_CAA=$(curl -H "Content-Type: application/json" -H "X-Auth-Token: ${TOKEN}" -s -X POST ${DNS_API}/${ZONE_ID}/recordsets -d '{"name": "'${CERTBOT_DOMAIN}'.", "type": "CAA", "ttl": 300, "records": ["0 issue \"letsencrypt.org\""]}')
    if [[ ($(echo "$RESULT_TXT" | jq .id) == "null") || ($(echo "$RESULT_CAA" | jq .id) == "null") ]]; then
        echo "$RESULT_TXT" | jq
        echo "$RESULT_CAA" | jq
        exit 1
    else
        echo "$RESULT_TXT" | jq -r .id > /tmp/"${ZONE_ID}"."${CERTBOT_DOMAIN}_txt"
        echo "$RESULT_CAA" | jq -r .id > /tmp/"${ZONE_ID}"."${CERTBOT_DOMAIN}_caa"
        while [[ ! $(dig _acme-challenge.${CERTBOT_DOMAIN} TXT | grep "${CERTBOT_VALIDATION}") || ! $(dig "${CERTBOT_DOMAIN}" CAA | grep letsencrypt) ]]; do
            sleep 10
        done
    fi
elif [ ! -z "$CERTBOT_VALIDATION" ]; then
    RESULT_TXT=$(curl -H "Content-Type: application/json" -H "X-Auth-Token: ${TOKEN}" -s -X DELETE ${DNS_API}/${ZONE_ID}/recordsets/$(cat /tmp/"${ZONE_ID}"."${CERTBOT_DOMAIN}_txt") )
    RESULT_CAA=$(curl -H "Content-Type: application/json" -H "X-Auth-Token: ${TOKEN}" -s -X DELETE ${DNS_API}/${ZONE_ID}/recordsets/$(cat /tmp/"${ZONE_ID}"."${CERTBOT_DOMAIN}_caa") )
    if [[ ($(echo "$RESULT_TXT" | jq .id) == "null") || ($(echo "$RESULT_CAA" | jq .id) == "null") ]]; then
        echo "$RESULT_TXT" | jq
        echo "$RESULT_CAA" | jq
        exit 1
    fi
else
    echo "Something went wrong"
    exit 1
fi

