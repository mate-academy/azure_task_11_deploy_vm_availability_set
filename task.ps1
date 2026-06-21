$location = "ukwest"
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDIfVhFZjYAhjVr+8an2+m98NzofTYHwe0M9rtezqgEAZ1qVHhJisVJXaS3u3Yq0O9/PK4fm/rA7qsL3A3OXOwE4Cihwvt340wbXC96NbcitJfykYDF8qrcYxzklXG/dvbZgPPyO0mwMHnlMKae8TqswEdmQ8l4cMFH1OQDkhwGI5PtCAFTDohqQoNZ3I4OLarD78O6lhX97DEBnQchPqp3IJwionPCIhM0kPsTj0dT43uJ4zAa6kMuTztDGknJlkREqtf11+g0UMiwsN1xS6Cp3u7jTid6Wn2RUNOgRfXhPDaTvlw3YVVQPTfgslD0CbSlxPTqfM/KVMtx6Vr1IJljXCsnUlrhPETkfQ/9IHGFzG+S7tdI7j482ANHltvH7+y0xMxR3zjm30SLAi03VVvMkvq8Gqqrlr4mfkRccx0vAamsMxlnjBtQDp/n42ihpJG6LlzeQg2kEMKVGA8kgdpfgaxdrY3KE91YzGRBPbl51Jp22EziL4q1BO3z5oqWdw0= generated-by-azure"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_D2s_v3"
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

for (($i = 1); ($i -le 2); ($i++) ) {
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
    -AvailabilitySetName $availabilitySetName
}
