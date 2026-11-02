$location = "switzerlandnorth"
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B2ats_v2"
$availabilitySetName = "mateavalset"

$localKeyPath = "$HOME\.ssh\matebox_task11_key"
if (-not (Test-Path "$localKeyPath.pub")) {
    ssh-keygen -t rsa -b 2048 -f $localKeyPath -N '""'
}
$sshKeyPublicKey = Get-Content "$localKeyPath.pub" -Raw

New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP -Force

$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet -Force

New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -PublicKey $sshKeyPublicKey

New-AzAvailabilitySet -ResourceGroupName $resourceGroupName -Name $availabilitySetName -Location $location -Sku Aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 5

$cred = New-Object System.Management.Automation.PSCredential ("azureuser", (ConvertTo-SecureString "IgnoreThisPassword123!" -AsPlainText -Force))

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
    -AvailabilitySetName $availabilitySetName `
    -Credential $cred
}