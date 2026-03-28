Write-Host "Checking Azure Authentication..." -ForegroundColor Cyan
$azContext = Get-AzContext
if ($null -eq $azContext) {
    Connect-AzAccount -UseDeviceAuthentication
}

$resourceGroupName = "Azure-Colo-Home-Interconnect"
$containerName = "scus-interconnect-container"
$homeConnectionName = "SCUS-Interconnect-Connection-Home"
$coloConnectionName = "SCUS-Interconnect-Connection-Colo"
$gatewayName = "SCUS-Interconnect-VPNGW"

Write-Host "Stopping Container: $containerName..." -ForegroundColor Magenta
Stop-AzContainerGroup -ResourceGroupName $resourceGroupName -Name $containerName

Write-Host "Removing VPN Connection: $homeConnectionName..." -ForegroundColor Yellow
Remove-AzVirtualNetworkGatewayConnection -Name $homeConnectionName -ResourceGroupName $resourceGroupName -Force

Write-Host "Removing VPN Connection: $coloConnectionName..." -ForegroundColor Yellow
Remove-AzVirtualNetworkGatewayConnection -Name $coloConnectionName -ResourceGroupName $resourceGroupName -Force

Write-Host "Removing VNet Gateway: $gatewayName..." -ForegroundColor Cyan
Remove-AzVirtualNetworkGateway -Name $gatewayName -ResourceGroupName $resourceGroupName -Force

Write-Host "Teardown Complete!" -ForegroundColor Green