$location = "canadacentral"
$resourceGroupName = "mate-azure-task-11"

$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"

$sshKeyName = "linuxboxsshkey"
$sshKeyPath = "$HOME\.ssh\linuxboxsshkey.pub"

$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_D2s_v3"

$availabilitySetName = "mate-avset"

Write-Host "=== CHECK RESOURCE GROUP ==="
$rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

if (-not $rg) {
    Write-Host "Creating resource group..."
    New-AzResourceGroup -Name $resourceGroupName -Location $location | Out-Null
}

Write-Host "=== CREATE AVAILABILITY SET ==="
$availabilitySet = New-AzAvailabilitySet `
    -ResourceGroupName $resourceGroupName `
    -Name $availabilitySetName `
    -Location $location `
    -Sku "Aligned" `
    -PlatformFaultDomainCount 2 `
    -PlatformUpdateDomainCount 2

Write-Host "=== CREATE NSG ==="
$nsgRule = New-AzNetworkSecurityRuleConfig `
    -Name "AllowSSH" `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1000 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 22 `
    -Access Allow

$nsg = New-AzNetworkSecurityGroup `
    -Name $networkSecurityGroupName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -SecurityRules $nsgRule

Write-Host "=== CREATE VNET ==="
$subnet = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $subnetAddressPrefix

$vnet = New-AzVirtualNetwork `
    -Name $virtualNetworkName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix $vnetAddressPrefix `
    -Subnet $subnet

Write-Host "=== CREATE SSH KEY ==="
if (Test-Path $sshKeyPath) {
    $pubKey = Get-Content $sshKeyPath -Raw
} else {
    ssh-keygen -t rsa -b 4096 -f "$HOME\.ssh\linuxboxsshkey" -N '""' | Out-Null
    $pubKey = Get-Content $sshKeyPath -Raw
}

New-AzSshKey `
    -Name $sshKeyName `
    -ResourceGroupName $resourceGroupName `
    -PublicKey $pubKey `
    -Location $location | Out-Null

Write-Host "=== DEPLOY VMS ==="

for ($i = 1; $i -le 2; $i++) {

    $vm = "$vmName$i"

    Write-Host "Deploying $vm..."

    New-AzVM `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -Name $vm `
        -VirtualNetworkName $virtualNetworkName `
        -SubnetName $subnetName `
        -SecurityGroupName $networkSecurityGroupName `
        -ImageName $vmImage `
        -Size $vmSize `
        -AvailabilitySetName $availabilitySetName `
        -SshKeyName $sshKeyName
}