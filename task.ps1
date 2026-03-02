$location = "swedencentral"
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
# Используем твой ed25519 через $HOME
$sshKeyPublicKey = Get-Content "$HOME/.ssh/id_ed25519.pub"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
# Возвращаем размер по условию задачи
$vmSize = "Standard_B1s"
$availabilitySetName = "mateavalset"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access Allow
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet

New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -PublicKey $sshKeyPublicKey

# Создаем Availability Set
New-AzAvailabilitySet -ResourceGroupName $resourceGroupName -Name $availabilitySetName -Location $location -Sku "Aligned" -PlatformFaultDomainCount 2

# Цикл создания 2 ВМ в Availability Set (без зон)
for (($i = 1); ($i -le 2); ($i++) ) {
    New-AzVm `
        -ResourceGroupName $resourceGroupName `
        -Name "$vmName-$i" `
        -Location $location `
        -ImageName $vmImage `
        -Size $vmSize `
        -SubnetName $subnetName `
        -VirtualNetworkName $virtualNetworkName `
        -SecurityGroupName $networkSecurityGroupName `
        -SshKeyName $sshKeyName `
        -AvailabilitySetName $availabilitySetName
}

