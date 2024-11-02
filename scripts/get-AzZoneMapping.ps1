$location = "westeurope"

$subscriptionId = (Get-AzContext).Subscription.ID
$response = Invoke-AzRestMethod -Method GET -Path "/subscriptions/$subscriptionId/locations?api-version=2022-12-01"
$locations = ($response.Content | ConvertFrom-Json).value

$locations | Where-Object { $_.name -eq $location } | Select-Object -ExpandProperty availabilityZoneMappings
