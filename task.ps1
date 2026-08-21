# Using denmarkeast instead of the region from README: Standard_B2ats_v2 is
# restricted (NotAvailableForSubscription) in availability zones in the regions
# I have quota for (ukwest, canadacentral). It's available in all 3 zones in
# denmarkeast without restrictions.
$location = "denmarkeast"
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub" 
$vmName = "matebox"
$vmImage = "Ubuntu2404"
$vmSize = "Standard_B2ats_v2"
$availabilitySetName = "mateavalset"
$vmAdminUsernameBase = "ponchik"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet

New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -PublicKey $sshKeyPublicKey

New-AzAvailabilitySet -ResourceGroupName $resourceGroupName -Name $availabilitySetName -Location $location -Sku Aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 5

for (($i = 1); ($i -le 2); ($i++) ) {
    $vmAdminUsername = $vmAdminUsernameBase + $i
    New-AzVm `
        -ResourceGroupName $resourceGroupName `
        -Name "$vmName-$i" `
        -Location $location `
        -image $vmImage `
        -size $vmSize `
        -SubnetName $subnetName `
        -VirtualNetworkName $virtualNetworkName `
        -SecurityGroupName $networkSecurityGroupName `
        -SshKeyName $sshKeyName `
        -AvailabilitySetName $availabilitySetName `
        -Credential (New-Object System.Management.Automation.PSCredential($vmAdminUsername, (New-Object System.Security.SecureString)))
}
