$location = "uksouth"
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$sshKeyName = "linuxboxsshkey"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$availabilitySetName = "mateavalset"

New-AzAvailabilitySet `
-ResourceGroupName $resourceGroupName `
-Location $location `
-Name $availabilitySetName `
-Sku Aligned `
-PlatformFaultDomainCount 2 `
-PlatformUpdateDomainCount 5


for (($vmIndex = 1); ($vmIndex -le 2); ($vmIndex++)) {
    New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Name "$vmName-$vmIndex" `
    -Location $location `
    -image $vmImage `
    -size $vmSize `
    -SubnetName $subnetName `
    -VirtualNetworkName $virtualNetworkName `
    -SecurityGroupName $networkSecurityGroupName `
    -SshKeyName $sshKeyName `
    -AvailabilitySetName $availabilitySetName
}
