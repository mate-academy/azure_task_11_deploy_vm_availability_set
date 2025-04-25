$linuxUser = "azur1"
$linuxPassword = "YourSecurePassword123!" | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($linuxUser, $linuxPassword)
$location = "uksouth"
$resourceGroupName = "mate-azure-task-113"
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

if (-not (Test-Path "$HOME\.ssh\$linuxUser.pub")) {
    Write-Host "SSH-ключ не найден. Генерируем новый..." -ForegroundColor Cyan
    ssh-keygen -t rsa -b 4096 -f "$HOME\.ssh\$linuxUser" -N "" | Out-Null
}

$sshKeyPublicKey = (Get-Content "$HOME\.ssh\$linuxUser.pub" -Raw).Trim()


Write-Host "Creating a resource group $resourceGroupName ..." -ForegroundColor Cyan
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..." -ForegroundColor Cyan
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP | Out-Null

$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet | Out-Null

New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -PublicKey $sshKeyPublicKey | Out-Null

Write-Host "Creating an availability set $availabilitySetName ..." -ForegroundColor Cyan
New-AzAvailabilitySet `
   -Location $location `
   -Name $availabilitySetName `
   -ResourceGroupName $resourceGroupName `
   -Sku aligned `
   -PlatformFaultDomainCount 2 `
   -PlatformUpdateDomainCount 2

for (($zone = 1); ($zone -le 2); ($zone++) ) {
    Write-Host "Creating a virtual machine $vmName-$zone ..." -ForegroundColor Cyan
    New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Name "$vmName-$zone" `
    -Location $location `
    -image $vmImage `
    -size $vmSize `
    -SubnetName $subnetName `
    -VirtualNetworkName $virtualNetworkName `
    -SecurityGroupName $networkSecurityGroupName `
    -Credential $credential `
    -AvailabilitySetName $availabilitySetName `
    -SshKeyName $sshKeyName `
    -SshKeyValues $sshKeyPublicKey
}
