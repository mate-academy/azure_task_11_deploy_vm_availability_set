# Parameters
$location                  = "uksouth"
$resourceGroupName         = "mate-azure-task-11"
$networkSecurityGroupName  = "defaultnsg"
$virtualNetworkName        = "vnet"
$subnetName                = "default"
$vnetAddressPrefix         = "10.0.0.0/16"
$subnetAddressPrefix       = "10.0.0.0/24"
$sshKeyName                = "linuxboxsshkey"
$sshKeyPublicKey           = Get-Content "~/.ssh/id_rsa.pub"
$vmName                    = "matebox"
$vmImage                   = "Ubuntu2204"
$vmSize                    = "Standard_B1s"
$availabilitySetName       = "mateavalset"

# Create resource group
Write-Host "Creating resource group $resourceGroupName..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create network security group
Write-Host "Creating network security group $networkSecurityGroupName..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 `
    -SourceAddressPrefix * -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 `
    -SourceAddressPrefix * -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow

$nsg = New-AzNetworkSecurityGroup `
    -Name $networkSecurityGroupName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# Create virtual network and subnet
Write-Host "Creating virtual network $virtualNetworkName with subnet $subnetName..."
$subnet = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $subnetAddressPrefix

$vnet = New-AzVirtualNetwork `
    -Name $virtualNetworkName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix $vnetAddressPrefix `
    -Subnet $subnet

# Import SSH key
Write-Host "Importing SSH public key $sshKeyName..."
New-AzSshKey `
    -Name $sshKeyName `
    -ResourceGroupName $resourceGroupName `
    -PublicKey $sshKeyPublicKey

# Create availability set
Write-Host "Creating availability set $availabilitySetName..."
$avSet = New-AzAvailabilitySet `
    -ResourceGroupName $resourceGroupName `
    -Name $availabilitySetName `
    -Location $location `
    -PlatformFaultDomainCount 2 `
    -PlatformUpdateDomainCount 2 `
    -Sku Aligned

# Deploy two VMs in the availability set
for ($i = 1; $i -le 2; $i++) {
    $vmNameWithNumber = "$vmName-$i"
    Write-Host "Creating VM $vmNameWithNumber in availability set..."
    
    # Create network interface with NSG
    $nic = New-AzNetworkInterface `
        -Name "$vmNameWithNumber-nic" `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -SubnetId $vnet.Subnets[0].Id `
        -NetworkSecurityGroupId $nsg.Id
    
    # Create VM configuration with SSH key
    $vmConfig = New-AzVMConfig `
        -VMName $vmNameWithNumber `
        -VMSize $vmSize |
        Set-AzVMOperatingSystem `
            -Linux `
            -ComputerName $vmNameWithNumber `
            -DisablePasswordAuthentication |
        Set-AzVMSourceImage `
            -PublisherName "Canonical" `
            -Offer "0001-com-ubuntu-server-jammy" `
            -Skus "22_04-lts" `
            -Version "latest" |
        Add-AzVMNetworkInterface `
            -Id $nic.Id
    
    # Add SSH key
    $vmConfig = Add-AzVMSshPublicKey `
        -VM $vmConfig `
        -KeyData $sshKeyPublicKey `
        -Path "/home/azureuser/.ssh/authorized_keys"
    
    # Create VM with explicit availability set name
    New-AzVM `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -VM $vmConfig `
        -AvailabilitySetName $availabilitySetName
}

Write-Host "`n✅ Successfully deployed two VMs ($vmName-1, $vmName-2) in availability set '$availabilitySetName'."