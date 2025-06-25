$location = "uksouth"
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub" 
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$availabilitySetName = "mateavalset"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet

New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -PublicKey $sshKeyPublicKey

New-AzAvailabilitySet `
   -Location $location `
   -Name $availabilitySetName `
   -ResourceGroupName $resourceGroupName `
   -Sku aligned `
   -PlatformFaultDomainCount 2 `
   -PlatformUpdateDomainCount 2

for (($zone = 1); ($zone -le 2); ($zone++) ) {
    New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Name "$vmName-$zone" `
    -Location $location `
    -image $vmImage `
    -size $vmSize `
    -SubnetName $subnetName `
    -VirtualNetworkName $virtualNetworkName `
    -SecurityGroupName $networkSecurityGroupName `
    -SshKeyValue "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5r/k+NpBFDkrG1436gx7+wbEVTaEa/WrN+tsDd6jZdgUMxLNHhjhLcPWBqb7FzX+CWGUnd7O3ev54YlPmmR6N85QgcOfZgEJeqwzLbxTgLbJNXULhKwDrO8FoCgxgPv9ftNudsLeXwv4fh3iIo1ZE6SsSUouaYd3XXeUDkWARka198vKscDG3KRvUA/Jn+pdOxQ+8dJv/1GwtoI7saXW7FeCI6ykqy+n9X+bYoQ0saD0af65szJydKxEoEDje+zCin5M9ckUvlwJ0Khnk0/pI/jZ7AQ0WWYlLb8UD1QgGEIPi7P2t6PjKcE1omcu+K19ICb4K+OU4I8NGojkANX8H4EzLd8vl7rC0sxAwviKgmqjV4rv8EC81oJEMaCmnHhEZVMLdxkKQltoRKh305vXcqfGJW0P/7AtG9DxYD2U7PaOjhP4S2zpxhEGRbZlxFf1/lXJHBLWYBmQWjc4B527sZywNLVyy94RGSTlvEKE/L1zrAD3t7lKKPdHCfM8HsW0= generated-by-azure" `
    -AvailabilitySetName $availabilitySetName
}
