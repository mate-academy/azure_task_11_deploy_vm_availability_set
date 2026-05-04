$ErrorActionPreference = "Stop"

# README: any region — centralus (mate-azure-task-2 already had a VM here; B1s blocked in UK/NE on this sub).
$location = "centralus"
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
# Mate validate-artifacts.ps1 checks this exact SKU — do not swap for deploy-only testing if you need CI to pass.
$vmSize = "Standard_B1s"
$availabilitySetName = "mateavalset"

$sshPublicKeyPath = Join-Path $HOME ".ssh/id_ed25519.pub"
if (-not (Test-Path $sshPublicKeyPath)) {
    $sshPublicKeyPath = Join-Path $HOME ".ssh/id_rsa.pub"
}
$sshKeyPublicKey = Get-Content -Path $sshPublicKeyPath -Raw
$secPlain = ConvertTo-SecureString "N0tUsedForLogin!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $secPlain)

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 `
    -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 `
    -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName `
    -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

Write-Host "Creating virtual network $virtualNetworkName ..."
$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup $nsg
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location `
    -AddressPrefix $vnetAddressPrefix -Subnet $subnet

Write-Host "Creating SSH key resource $sshKeyName ..."
New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -Location $location -PublicKey $sshKeyPublicKey

Write-Host "Creating availability set $availabilitySetName ..."
New-AzAvailabilitySet -Name $availabilitySetName -ResourceGroupName $resourceGroupName -Location $location `
    -Sku Aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2

for ($i = 1; $i -le 2; $i++) {
    $instanceName = "$vmName-$i"
    Write-Host "Creating VM $instanceName in availability set $availabilitySetName ..."
    # Single-line New-AzVM avoids PS line-continuation misparsing -SshKeyName on some hosts.
    New-AzVM -ResourceGroupName $resourceGroupName -Name $instanceName -Location $location -Image $vmImage -Size $vmSize -SubnetName $subnetName -VirtualNetworkName $virtualNetworkName -SecurityGroupName $networkSecurityGroupName -SshKeyName $sshKeyName -AvailabilitySetName $availabilitySetName -Credential $cred
}
