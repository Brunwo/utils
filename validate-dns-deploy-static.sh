# validate setup azure static webapp with custom domain
RESOURCE_GROUP_NAME="staticwebrg"
STATIC_WEB_APP_NAME="viewportWeb"

# Get the Static Web App's default hostname
DEFAULT_HOSTNAME=$(az staticwebapp show --name $STATIC_WEB_APP_NAME --resource-group $RESOURCE_GROUP_NAME --query "defaultHostname" --output tsv)
echo "Azure Static Web App Hostname: $DEFAULT_HOSTNAME"


#do the setup on namecheap


# Adding the custom domain
CUSTOM_DOMAIN="www.brunowagner.dev"

az staticwebapp hostname set --name $STATIC_WEB_APP_NAME --resource-group $RESOURCE_GROUP_NAME --hostname $CUSTOM_DOMAIN
