param (
  [Parameter(Mandatory=$True,Position=1)]
  $apiUrl,
  [Parameter(Mandatory=$False,Position=2)]
  $apiUser,
  [Parameter(Mandatory=$True,Position=3)]
  $apiPassword,
  $apiOrg = 'Tier3',
  $apiSpace = 'Dev',
  [Parameter(Mandatory=$True)]
  $brokerName,
  [Parameter(Mandatory=$True)]
  $brokerUrl
)

cf api $apiUrl
cf login -a $apiUrl -u $apiUser -p $apiPassword -o $apiOrg -s $apiSpace

# Look to see if this is already connected
$jsonServiceBrokers = cf curl -X 'GET' /v2/service_brokers
$serviceBrokers = "$jsonServiceBrokers" | ConvertFrom-Json
foreach ($resource in $serviceBrokers.resources) {
  if ($resource.entity.name -eq $brokerName -and $resource.entity.broker_url -eq $brokerUrl) {
    Write-Host "Service $brokerName already exists for url $brokerUrl not registering"
    exit 0
  }
}

cf delete-service-broker $brokerName -f
cf create-service-broker $brokerName user password $brokerUrl

if ($? -eq $false) {
  Write-Error "Failed to create service broker $brokerName for url $brokerUrl."
  exit 1
}

$jsonresponse = cf curl /v2/service_plans -X 'GET'

if ($? -eq $false) {
  Write-Error "Failed to get service plans."
  exit 1
}

$response = "$jsonresponse" | ConvertFrom-Json

# We assume only one response coming back right now
$guid = $response.resources[0].metadata.guid

cf curl /v2/service_plans/$guid -X 'PUT' -d '{\"public\":true}' | Out-Null

if ($? -eq $false) {
  Write-Error "Failed to set plan $guid to public."
  exit 1
}