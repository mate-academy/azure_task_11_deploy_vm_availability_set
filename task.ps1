# task.ps1
$ErrorActionPreference = "Stop"
$ConfirmPreference = "None"
$ProgressPreference = "SilentlyContinue"

# —овет: используй регион, где у теб€ уже реально создавалс€ Standard_B1s.
# ” теб€ успешно был polandcentral. uksouth можно, но если снова будут capacity issues Ч мен€й регион.
$location = "polandcentral"

$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"

$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = (Get-Content -Raw "/root/.ssh/mate_azure_vm.pub").Trim()

$vmBaseName = "matebox"
$vmImage = "Ubuntu2204"         # friendly name (важно дл€ проверки)
$vmSize  = "Standard_B1s"
$availabilitySetName = "mateavalset"

# admin credential (New-AzVM требует Credential, даже если будем входить по ключу)
$adminUsername = "azureuser"
$plainPassword = "P@ss" + (Get-Random -Minimum 10000000 -Maximum 99999999) + "aA!"
$adminPassword = ConvertTo-SecureString $plainPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($adminUsername, $adminPassword)

function Invoke-WithRetry {
  param(
    [Parameter(Mandatory=$true)][ScriptBlock]$Script,
    [int]$Attempts = 4,
    [int]$DelaySeconds = 12
  )
  for ($a=1; $a -le $Attempts; $a++) {
    try { return & $Script }
    catch {
      Write-Host "Attempt $a/$Attempts failed: $($_.Exception.Message)" -ForegroundColor Yellow
      if ($a -eq $Attempts) { throw }
      Start-Sleep -Seconds $DelaySeconds
    }
  }
}

Write-Host "Creating / updating resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force | Out-Null

Write-Host "Creating / updating network security group $networkSecurityGroupName ..."
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $networkSecurityGroupName -ErrorAction SilentlyContinue

$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name "SSH" -Protocol Tcp -Direction Inbound -Priority 1001 `
  -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow

$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name "HTTP-8080" -Protocol Tcp -Direction Inbound -Priority 1002 `
  -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow

if (-not $nsg) {
  New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName `
    -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP | Out-Null
  $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $networkSecurityGroupName
} else {
  $nsg.SecurityRules.Clear()
  $nsg.SecurityRules.Add($nsgRuleSSH)
  $nsg.SecurityRules.Add($nsgRuleHTTP)
  $nsg | Set-AzNetworkSecurityGroup | Out-Null
}

Write-Host "Creating / updating VNet $virtualNetworkName and subnet $subnetName ..."
$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkName -ErrorAction SilentlyContinue

if (-not $vnet) {
  $subnetCfg = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
  New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location `
    -AddressPrefix $vnetAddressPrefix -Subnet $subnetCfg | Out-Null
  $vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkName
} else {
  $sub = $vnet.Subnets | Where-Object { $_.Name -eq $subnetName }
  if (-not $sub) {
    Add-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet -AddressPrefix $subnetAddressPrefix | Out-Null
    $vnet | Set-AzVirtualNetwork | Out-Null
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkName
  }
}

Write-Host "Creating / updating SSH key resource $sshKeyName ..."
$existingKey = Get-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -ErrorAction SilentlyContinue
if (-not $existingKey) {
  New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -PublicKey $sshKeyPublicKey | Out-Null
}

Write-Host "Creating / updating Availability Set $availabilitySetName ..."
$avSet = Get-AzAvailabilitySet -ResourceGroupName $resourceGroupName -Name $availabilitySetName -ErrorAction SilentlyContinue
if (-not $avSet) {
  # Aligned = managed disks (современно и стабильнее)
  $avSet = New-AzAvailabilitySet `
    -Location $location `
    -Name $availabilitySetName `
    -ResourceGroupName $resourceGroupName `
    -Sku Aligned `
    -PlatformFaultDomainCount 2 `
    -PlatformUpdateDomainCount 5
}

Start-Sleep 5

for ($i = 1; $i -le 2; $i++) {
  $vmName = "$vmBaseName-$i"

  Write-Host "Creating VM $vmName in availability set $availabilitySetName using image $vmImage ..."

  Invoke-WithRetry -Attempts 4 -DelaySeconds 15 -Script {
    New-AzVM `
      -ResourceGroupName $resourceGroupName `
      -Name $vmName `
      -Location $location `
      -Image $vmImage `
      -Size $vmSize `
      -VirtualNetworkName $virtualNetworkName `
      -SubnetName $subnetName `
      -SecurityGroupName $networkSecurityGroupName `
      -SshKeyName $sshKeyName `
      -AvailabilitySetName $availabilitySetName `
      -Credential $cred `
      -Verbose | Out-Null
  }
}

Write-Host ""
Write-Host "DONE. Check VMs + Availability Set:"
Get-AzVM -ResourceGroupName $resourceGroupName | Select Name, Location, @{n="AvailabilitySetId";e={$_.AvailabilitySetReference.Id}}
