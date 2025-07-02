# Variables
RESOURCE_GROUP_NAME="myResourceGroup"
STATIC_WEB_APP_NAME="myStaticWebApp"

# Get the Static Web App's default hostname
DEFAULT_HOSTNAME=$(az staticwebapp show --name $STATIC_WEB_APP_NAME --resource-group $RESOURCE_GROUP_NAME --query "defaultHostname" --output tsv)
echo "Azure Static Web App Hostname: $DEFAULT_HOSTNAME"
