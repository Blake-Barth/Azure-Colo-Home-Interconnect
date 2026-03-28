Set-AzConfig -DisplayBreakingChangeWarning $false

Write-Host "Checking Azure Authentication..." -ForegroundColor Cyan
$azContext = Get-AzContext
if ($null -eq $azContext) {
    Connect-AzAccount -UseDeviceAuthentication
}

$resourceGroupName = "Azure-Colo-Home-Interconnect"
$containerName = "scus-interconnect-container"
$vpnGatewayName = "SCUS-Interconnect-VPNGW"
$homeConnectionName = "SCUS-Interconnect-Connection-Home"
$coloConnectionName = "SCUS-Interconnect-Connection-Colo"

Write-Host "Checking VPN Gateway status..." -ForegroundColor Cyan
$vpnGW = Get-AzVirtualNetworkGateway -Name $vpnGatewayName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $vpnGW -or $vpnGW.ProvisioningState -ne "Succeeded") {
    Write-Host "Deploying/Repairing VPN Gateway..." -ForegroundColor Yellow
    New-AzResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile "../templates/vpn_gateway.json" `
        -Mode Incremental
} else {
    Write-Host "VPNGW Gateway already exists and is healthy." -ForegroundColor Green
}

Write-Host "Checking Colo Connection status..." -ForegroundColor Cyan
$coloConnection = Get-AzVirtualNetworkGatewayConnection -Name $coloConnectionName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $coloConnection) {
    Write-Host "Deploying Home Connection..." -ForegroundColor Yellow
    New-AzResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile "../templates/colo_connection.json" `
        -Mode Incremental
    
    Write-Host "Fetching PSK from Key Vault..." -ForegroundColor Cyan
    $pskSecret = (Get-AzKeyVaultSecret -VaultName "SCUS-Interconnect-KVault" -Name "S2S-Colo-Secret" -AsPlainText)

    Set-AzVirtualNetworkGatewayConnectionSharedKey `
        -Name $coloConnectionName `
        -ResourceGroupName $resourceGroupName `
        -Value $pskSecret `
        -Force | Out-Null
} else {
    Write-Host "Colo connection already exists." -ForegroundColor Green
}

Write-Host "Checking Home Connection status..." -ForegroundColor Cyan
$homeConnection = Get-AzVirtualNetworkGatewayConnection -Name $homeConnectionName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $homeConnection) {
    Write-Host "Deploying Home Connection..." -ForegroundColor Yellow
    New-AzResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile "../templates/home_connection.json" `
        -Mode Incremental
    
    Write-Host "Fetching PSK from Key Vault..." -ForegroundColor Cyan
    $pskSecret = (Get-AzKeyVaultSecret -VaultName "SCUS-Interconnect-KVault" -Name "S2S-Home-Secret" -AsPlainText)

    Set-AzVirtualNetworkGatewayConnectionSharedKey `
        -Name $homeConnectionName `
        -ResourceGroupName $resourceGroupName `
        -Value $pskSecret `
        -Force | Out-Null
} else {
    Write-Host "Home connection already exists." -ForegroundColor Green
}

 
Write-Host "Checking Container State..." -ForegroundColor Cyan
$container = Get-AzContainerGroup -ResourceGroupName $resourceGroupName -Name $containerName -ErrorAction SilentlyContinue

if ($container) {
    if ($container.InstanceView.State -ne "Running") {
        Write-Host "Starting Container..." -ForegroundColor Yellow
        Start-AzContainerGroup -ResourceGroupName $resourceGroupName -Name $containerName
    } else {
        Write-Host "Container is already running." -ForegroundColor Green
    }
} else {
    Write-Warning "Container '$containerName' not found."
}

$container = Get-AzContainerGroup -ResourceGroupName $resourceGroupName -Name $containerName -ErrorAction SilentlyContinue
$appIp = $container.IPAddress.Ip

Write-Host "All operations completed!" -ForegroundColor Green
Write-Host "The Azure Container App IP is: $appIp" -ForegroundColor Cyan