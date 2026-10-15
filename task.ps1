$location = "swedencentral" # any region that is available in your Azure subscription
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_ed25519.pub" -Raw
$adminUsername = "azureuser"
$adminPassword = ConvertTo-SecureString "AzureUserMate_VM_task-11" -AsPlainText -Force
$adminCredential = New-Object System.Management.Automation.PSCredential ($adminUsername, $adminPassword)
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B2ts_v2"
$availabilitySetName = "mateavalset"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating an availability set $availabilitySetName ..."
New-AzAvailabilitySet -Location $location -Name $availabilitySetName -ResourceGroupName $resourceGroupName -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet

New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -PublicKey $sshKeyPublicKey

for (($zone = 1); ($zone -le 2); ($zone++) ) {
    New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Name "$vmName-$zone" `
    -Location $location `
    -Image $vmImage `
    -Size $vmSize `
    -SubnetName $subnetName `
    -VirtualNetworkName $virtualNetworkName `
    -SecurityGroupName $networkSecurityGroupName `
    -SshKeyName $sshKeyName `
    -Credential $adminCredential `
    -AvailabilitySetName $availabilitySetName
}
