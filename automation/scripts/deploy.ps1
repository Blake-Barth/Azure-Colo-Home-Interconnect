Set-AzConfig -DisplayBreakingChangeWarning $false

Write-Host "Checking Azure Authentication..." -ForegroundColor Cyan
$azContext = Get-AzContext
if ($null -eq $azContext) {
    Connect-AzAccount -UseDeviceAuthentication
}

$resourceGroupName = "Azure-Colo-Home-Interconnect"
$containerName = "scus-interconnect-container"
$vnetGatewayName = "SCUS-Interconnect-VNetGW"
$connectionName = "SCUS-Interconnect-Connection-Home"

if (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Resource Group: $resourceGroupName" -ForegroundColor Yellow
    New-AzResourceGroup -Name $resourceGroupName -Location "southcentralus"
}

Write-Host "Checking VNet Gateway status..." -ForegroundColor Cyan
$vnetGw = Get-AzVirtualNetworkGateway -Name $vnetGatewayName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $vnetGw -or $vnetGw.ProvisioningState -ne "Succeeded") {
    Write-Host "Deploying/Repairing VNet Gateway..." -ForegroundColor Yellow
    New-AzResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile "../templates/vnet_gateway.json" `
        -Mode Incremental
} else {
    Write-Host "VNet Gateway already exists and is healthy." -ForegroundColor Green
}

Write-Host "Checking Connection status..." -ForegroundColor Cyan
$connection = Get-AzVirtualNetworkGatewayConnection -Name $connectionName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $connection) {
    Write-Host "Deploying Home Connection..." -ForegroundColor Yellow
    New-AzResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile "../templates/home_connection.json" `
        -Mode Incremental
    
    Write-Host "Fetching PSK from Key Vault..." -ForegroundColor Cyan
    $pskSecret = (Get-AzKeyVaultSecret -VaultName "SCUS-Interconnect-KVault" -Name "S2S-Home-Secret" -AsPlainText)

    Set-AzVirtualNetworkGatewayConnectionSharedKey `
        -Name $connectionName `
        -ResourceGroupName $resourceGroupName `
        -Value $pskSecret `
        -Force | Out-Null
} else {
    Write-Host "Connection already exists." -ForegroundColor Green
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