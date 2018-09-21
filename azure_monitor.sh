#!/bin/bash

#Active Directory ID
adid=$2
#Subscription ID
subid=$3
#Service Principal-ADApplication ID
clientid=$4
#Servoce Principal-ADApplication Secret
clientsecret=$5
#Resource Group Name
resourcegroup=$6
#Resource Type
resourcetype=$7
#Resource Name
resourcename=$8
#Mettric Aggregation
aggregation=$9
#Mettric Name
metricname=${10}
#granulação de tempo
timegrain=PT"$1"M

#inicio (hora atual menos 1 minuto)
start=`date --utc +%Y-%m-%dT%H:%M:00Z -d "$1 min ago"`

#fim (hora atual)
end=`date --utc +%Y-%m-%dT%H:%M:00Z`
apiversion="2018-01-01"
Bearer=(`wget -qO- "https://login.windows.net/$adid/oauth2/token"  --post-data "resource=https://management.core.windows.net&client_id=$clientid&grant_type=client_credentials&client_secret=$clientsecret" | jq -r '.access_token'`)
URL="https://management.azure.com/subscriptions/$subid/resourceGroups/$resourcegroup/providers/$resourcetype/$resourcename/providers/microsoft.insights/metrics?timespan=$start/$end&interval=$timegrain&aggregation=$aggregation&metricnames=$metricname&api-version=$apiversion"
wget -qO- --header="Authorization: Bearer $Bearer" --header="Content-Type: application/json" "$URL" | jq  -r ".value[0].timeseries[0].data[0]."$aggregation""
