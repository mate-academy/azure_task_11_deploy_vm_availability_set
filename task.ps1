$ErrorActionPreference = "Stop"

# Main configuration
$location = "indiasouthcentral"
$resourceGroupName = "mate-azure-task-11"

# Network configuration
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"

$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"

# SSH configuration
$sshKeyName = "linuxboxsshkey"
$sshPublicKeyPath = Join-Path $HOME ".ssh/vm-demo-key.pub"
$sshKeyPublicKey = (Get-Content $sshPublicKeyPath -Raw).Trim()

# VM configuration
$adminUsername = "azureuser"

$vmNames = @(
    "matebox1",
    "matebox2"
)

$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"

# Availability Set configuration
$availabilitySetName = "mateavalset"

# Check local public SSH key
if (-not (Test-Path $sshPublicKeyPath)) {
    throw "SSH public key was not found: $sshPublicKeyPath"
}

# Create resource group
Write-Host "Creating resource group $resourceGroupName ..."

New-AzResourceGroup `
    -Name $resourceGroupName `
    -Location $location

# Create NSG rules
Write-Host "Creating network security group $networkSecurityGroupName ..."

$nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
    -Name "SSH" `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1001 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 22 `
    -Access Allow

$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig `
    -Name "HTTP" `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1002 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 8080 `
    -Access Allow

$nsg = New-AzNetworkSecurityGroup `
    -Name $networkSecurityGroupName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# Create subnet and VNet
Write-Host "Creating virtual network $virtualNetworkName ..."

$subnet = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $subnetAddressPrefix

New-AzVirtualNetwork `
    -Name $virtualNetworkName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix $vnetAddressPrefix `
    -Subnet $subnet

# Create Azure SSH key resource
Write-Host "Creating Azure SSH key resource $sshKeyName ..."

New-AzSshKey `
    -Name $sshKeyName `
    -ResourceGroupName $resourceGroupName `
    -PublicKey $sshKeyPublicKey

# Create Availability Set
Write-Host "Creating availability set $availabilitySetName ..."

New-AzAvailabilitySet `
    -ResourceGroupName $resourceGroupName `
    -Name $availabilitySetName `
    -Location $location `
    -Sku "Aligned" `
    -PlatformFaultDomainCount 2 `
    -PlatformUpdateDomainCount 5

# New-AzVM requires a Credential object.
# The password is randomly generated, while VM access uses our SSH key.
$securePassword = ConvertTo-SecureString `
    ("Azure!" + [guid]::NewGuid().ToString("N")) `
    -AsPlainText `
    -Force

$credential = [PSCredential]::new(
    $adminUsername,
    $securePassword
)

# Create two VMs in the same Availability Set
foreach ($vmName in $vmNames) {
    Write-Host ""
    Write-Host "Creating VM $vmName in availability set $availabilitySetName ..."

    New-AzVM `
        -ResourceGroupName $resourceGroupName `
        -Name $vmName `
        -Location $location `
        -Image $vmImage `
        -Size $vmSize `
        -Credential $credential `
        -VirtualNetworkName $virtualNetworkName `
        -SubnetName $subnetName `
        -SecurityGroupName $networkSecurityGroupName `
        -PublicIpAddressName "" `
        -SshKeyName $sshKeyName `
        -AvailabilitySetName $availabilitySetName `
        -SecurityType "Standard"
}

Write-Host ""
Write-Host "Deployment completed."

# Display the created VMs and their Availability Set
Get-AzVM `
    -ResourceGroupName $resourceGroupName |
    Select-Object `
        Name,
        Location,
        ProvisioningState,
        @{
            Name = "AvailabilitySet"
            Expression = {
                ($_.AvailabilitySetReference.Id -split "/")[-1]
            }
        }