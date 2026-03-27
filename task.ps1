$location = "swedencentral" 
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$sshKeyName = "linuxboxsshkey"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_D2as_v5" 
$availabilitySetName = "mateavalset"

# 1. Створення групи ресурсів
if (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
  New-AzResourceGroup -Name $resourceGroupName -Location $location
}

# 2. Створення Availability Set (Це наш кошик для відмовостійкості)
if (-not (Get-AzAvailabilitySet -ResourceGroupName $resourceGroupName -Name $availabilitySetName -ErrorAction SilentlyContinue)) {
  New-AzAvailabilitySet `
    -ResourceGroupName $resourceGroupName `
    -Name $availabilitySetName `
    -Location $location `
    -Sku Aligned `
    -PlatformUpdateDomainCount 2 `
    -PlatformFaultDomainCount 2
}

# 3. Мережева інфраструктура
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH

$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.0.0/24" -NetworkSecurityGroup $nsg
$vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $subnetConfig

# 4. Створення SSH ключа в Azure (Cloud-side)
if (-not (Get-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -ErrorAction SilentlyContinue)) {
  Write-Host "Генерація SSH ключа в Azure..." -ForegroundColor Yellow
  New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -Location $location
}

# 5. Цикл розгортання з ПРИВ'ЯЗКОЮ до Availability Set
for ($i = 1; $i -le 2; $i++) {
  Write-Host "--- Розгортання $vmName-$i у $availabilitySetName ---" -ForegroundColor Green
    
  $vmParams = @{
    ResourceGroupName   = $resourceGroupName
    Name                = "$vmName-$i"
    Location            = $location
    Image               = $vmImage
    Size                = $vmSize
    VirtualNetworkName  = $virtualNetworkName
    SubnetName          = $subnetName
    SecurityGroupName   = $networkSecurityGroupName
    AvailabilitySetName = $availabilitySetName
    SshKeyName          = $sshKeyName
  }

  New-AzVm @vmParams -Verbose
}