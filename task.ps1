$location = "denmarkeast" # any region that is available in your Azure subscription
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
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

$sshKeyPath = "$HOME\.ssh\mate_azure_task2.pub"

if (Test-Path $sshKeyPath) {
    $sshKeyPublicKey = (Get-Content $sshKeyPath -Raw).Trim()

    New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -Location $location -PublicKey $sshKeyPublicKey
}
else {
    New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -Location $location
}

New-AzAvailabilitySet -Name $availabilitySetName -ResourceGroupName $resourceGroupName -Location $location -Sku Aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 5 -ErrorAction Stop

$credential = Get-Credential -UserName "azureuser"

for ($number = 1; $number -le 2; $number++) {

    New-AzVM `
        -ResourceGroupName $resourceGroupName `
        -Name "$vmName-$number" `
        -Location $location `
        -Image $vmImage `
        -Size $vmSize `
        -Credential $credential `
        -SubnetName $subnetName `
        -VirtualNetworkName $virtualNetworkName `
        -SecurityGroupName $networkSecurityGroupName `
        -SshKeyName $sshKeyName `
        -AvailabilitySetName $availabilitySetName `
        -PublicIpAddressName "" `
        -ErrorAction Stop
}

$vms = Get-AzVM -ResourceGroupName $resourceGroupName

$results = @(
    foreach ($vm in $vms) {
        @{
            Name = $vm.Name
            Location = $vm.Location
            Size = $vm.HardwareProfile.VmSize
            AvailabilitySetId = $vm.AvailabilitySetReference.Id
        }
    }
)

ConvertTo-Json -InputObject $results -Depth 5 | Set-Content "./result.json"