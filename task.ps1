$location = "westeurope"
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "$HOME/.ssh/id_ed25519.pub" -Raw
$vmImage = "Ubuntu2204"
$vmSize = "Standard_D2als_v7"
$availabilitySetName = "mateavalset"
$platformFaultDomainCount = 2
$platformUpdateDomainCount = 2
$adminUserName = "azureuser"
$adminPassword = ConvertTo-SecureString "MateTask11Password!1" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($adminUserName, $adminPassword)

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

Write-Host "Creating a virtual network $virtualNetworkName ..."
$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet

Write-Host "Creating an SSH key resource $sshKeyName ..."
New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -Location $location -PublicKey $sshKeyPublicKey

Write-Host "Creating an availability set $availabilitySetName ..."
New-AzAvailabilitySet `
    -ResourceGroupName $resourceGroupName `
    -Name $availabilitySetName `
    -Location $location `
    -PlatformFaultDomainCount $platformFaultDomainCount `
    -PlatformUpdateDomainCount $platformUpdateDomainCount `
    -Sku Aligned

Write-Host "Creating virtual machine matebox-1 ..."
New-AzVM `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name "matebox-1" `
    -Credential $credential `
    -Image $vmImage `
    -Size $vmSize `
    -SubnetName $subnetName `
    -VirtualNetworkName $virtualNetworkName `
    -SecurityGroupName $networkSecurityGroupName `
    -SshKeyName $sshKeyName `
    -AvailabilitySetName $availabilitySetName

Write-Host "Creating virtual machine matebox-2 ..."
New-AzVM `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name "matebox-2" `
    -Credential $credential `
    -Image $vmImage `
    -Size $vmSize `
    -SubnetName $subnetName `
    -VirtualNetworkName $virtualNetworkName `
    -SecurityGroupName $networkSecurityGroupName `
    -SshKeyName $sshKeyName `
    -AvailabilitySetName $availabilitySetName
