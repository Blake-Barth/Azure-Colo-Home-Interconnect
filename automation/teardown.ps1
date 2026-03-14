Write-Host "Checking Azure Authentication..." -ForegroundColor Cyan
$azContext = Get-AzContext
if ($null -eq $azContext) {
    Connect-AzAccount -UseDeviceAuthentication
}

$resourceGroupName = "Azure-Colo-Home-Interconnect"
$containerName = "scus-interconnect-container"
$connectionName = "SCUS-Interconnect-Connection-Home"
$gatewayName = "SCUS-Interconnect-VNetGW"

Write-Host "Stopping Container: $containerName..." -ForegroundColor Magenta
Stop-AzContainerGroup -ResourceGroupName $resourceGroupName -Name $containerName

Write-Host "Removing VPN Connection: $connectionName..." -ForegroundColor Yellow
Remove-AzVirtualNetworkGatewayConnection -Name $connectionName -ResourceGroupName $resourceGroupName -Force

Write-Host "Removing VNet Gateway: $gatewayName..." -ForegroundColor Cyan
Remove-AzVirtualNetworkGateway -Name $gatewayName -ResourceGroupName $resourceGroupName -Force

Write-Host "Teardown Complete!" -ForegroundColor Green