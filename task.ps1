$ErrorActionPreference = "Stop"

# -----------------------------
#   CONFIGURATION
# -----------------------------

$location = "northeurope"
$resourceGroupName = "mate-azure-task-11"

$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"

$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKeyPath = "$HOME/.ssh/id_rsa.pub"   # змінити якщо ключ інший

$availabilitySetName = "mate-availability-set"

$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$vmBaseName = "mate11vm"

# -----------------------------
#   CHECK SSH PUBLIC KEY
# -----------------------------

if (-not (Test-Path $sshKeyPublicKeyPath)) {
    throw "SSH public key not found at $sshKeyPublicKeyPath"
}

$sshKeyPublicKey = Get-Content -Path $sshKeyPublicKeyPath -Raw

# -----------------------------
#   CREATE RESOURCE GROUP
# -----------------------------

Write-Host "Creating resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force | Out-Null

# -----------------------------
#   CREATE NSG
# -----------------------------

Write-Host "Creating NSG $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
    -Name "SSH" `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1000 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 22 `
    -Access Allow

$nsg = New-AzNetworkSecurityGroup `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $networkSecurityGroupName `
    -SecurityRules $nsgRuleSSH

# -----------------------------
#   CREATE VNET + SUBNET
# -----------------------------

Write-Host "Creating virtual network $virtualNetworkName ..."
$subnet = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $subnetAddressPrefix `
    -NetworkSecurityGroup $nsg

$vnet = New-AzVirtualNetwork `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $virtualNetworkName `
    -AddressPrefix $vnetAddressPrefix `
    -Subnet $subnet

# -----------------------------
#   CREATE SSH KEY RESOURCE
# -----------------------------

Write-Host "Creating SSH key resource $sshKeyName ..."
New-AzSshKey `
    -ResourceGroupName $resourceGroupName `
    -Name $sshKeyName `
    -PublicKey $sshKeyPublicKey | Out-Null

# -----------------------------
#   CREATE AVAILABILITY SET
# -----------------------------

Write-Host "Creating Availability Set $availabilitySetName ..."
New-AzAvailabilitySet `
    -ResourceGroupName $resourceGroupName `
    -Name $availabilitySetName `
    -Location $location `
    -Sku Aligned `
    -PlatformFaultDomainCount 2 `
    -PlatformUpdateDomainCount 5 | Out-Null

# -----------------------------
#   CREATE TWO VMS IN AVAILABILITY SET
# -----------------------------

for ($i = 1; $i -le 2; $i++) {

    $vmName = "$vmBaseName$i"

    Write-Host "Creating VM $vmName ..."

    New-AzVM `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -Name $vmName `
        -VirtualNetworkName $virtualNetworkName `
        -AddressPrefix $vnetAddressPrefix `
        -SubnetName $subnetName `
        -SubnetAddressPrefix $subnetAddressPrefix `
        -SecurityGroupName $networkSecurityGroupName `
        -Image $vmImage `
        -Size $vmSize `
        -SshKeyName $sshKeyName `
        -AvailabilitySetName $availabilitySetName
}

Write-Host "`nDeployment completed successfully!"
