[CmdletBinding()]
param(
  [string]$Location = "uksouth",
  [string]$Rg       = "mate-azure-task-11",   # заміни на потрібну назву завдання
  [string]$Vnet     = "vnet",
  [string]$Subnet   = "default",
  [string]$Nsg      = "defaultnsg",
  [string]$SshRes   = "linuxboxsshkey",
  [string]$AvSet    = "mate-avset",
  [string]$Vm1      = "matebox-as1",
  [string]$Vm2      = "matebox-as2",
  [string]$Image    = "Ubuntu2204",
  [string]$VmSize   = "Standard_B1s",
  [string]$PubKey   = "$HOME/.ssh/id_rsa.pub"
)

Write-Host "==> Deploying 2 VMs into an Availability Set in $Location"

# 0) RG
if (-not (Get-AzResourceGroup -Name $Rg -ErrorAction SilentlyContinue)) {
  New-AzResourceGroup -Name $Rg -Location $Location | Out-Null
}

# 1) NSG (дозволяємо SSH 22). Без публічних IP це все одно добрий тон + може знадобитись для приватного доступу.
$nsgObj = Get-AzNetworkSecurityGroup -Name $Nsg -ResourceGroupName $Rg -ErrorAction SilentlyContinue
if (-not $nsgObj) {
  $sshRule = New-AzNetworkSecurityRuleConfig `
    -Name "ssh" -Protocol Tcp -Direction Inbound -Priority 1000 `
    -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow

  $nsgObj = New-AzNetworkSecurityGroup `
    -Name $Nsg -ResourceGroupName $Rg -Location $Location -SecurityRules $sshRule
} else {
  if (-not ($nsgObj.SecurityRules | Where-Object Name -eq 'ssh')) {
    $nsgObj.SecurityRules.Add( (New-AzNetworkSecurityRuleConfig `
      -Name "ssh" -Protocol Tcp -Direction Inbound -Priority 1000 `
      -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow) )
    $nsgObj | Set-AzNetworkSecurityGroup | Out-Null
  }
}

# 2) VNet + Subnet (прив'язуємо NSG до Subnet)
$vnetObj = Get-AzVirtualNetwork -Name $Vnet -ResourceGroupName $Rg -ErrorAction SilentlyContinue
if (-not $vnetObj) {
  $subnetCfg = New-AzVirtualNetworkSubnetConfig -Name $Subnet -AddressPrefix "10.10.1.0/24" -NetworkSecurityGroup $nsgObj
  $vnetObj   = New-AzVirtualNetwork -Name $Vnet -ResourceGroupName $Rg -Location $Location -AddressPrefix "10.10.0.0/16" -Subnet $subnetCfg
} else {
  $sn = $vnetObj.Subnets | Where-Object Name -eq $Subnet
  if (-not $sn) {
    Add-AzVirtualNetworkSubnetConfig -Name $Subnet -AddressPrefix "10.10.1.0/24" -VirtualNetwork $vnetObj -NetworkSecurityGroup $nsgObj | Out-Null
    $vnetObj | Set-AzVirtualNetwork | Out-Null
  } elseif (-not $sn.NetworkSecurityGroup) {
    $sn.NetworkSecurityGroup = $nsgObj
    $vnetObj | Set-AzVirtualNetwork | Out-Null
  }
}

# 3) SSH Key resource (якщо є локальний public key — завантажимо; якщо ні — створимо порожній ресурс)
$pubKeyText = $null
if (Test-Path -LiteralPath $PubKey) {
  $pubKeyText = (Get-Content -LiteralPath $PubKey -Raw).Trim()
}
$sshKeyRes = Get-AzSshKey -ResourceGroupName $Rg -Name $SshRes -ErrorAction SilentlyContinue
if (-not $sshKeyRes) {
  if ([string]::IsNullOrWhiteSpace($pubKeyText)) {
    $sshKeyRes = New-AzSshKey -ResourceGroupName $Rg -Name $SshRes          # деякі версії Az не мають -Location
    Write-Host "⚠️  Public key not found at '$PubKey'. SSH Key resource created WITHOUT a key."
  } else {
    $sshKeyRes = New-AzSshKey -ResourceGroupName $Rg -Name $SshRes -PublicKey $pubKeyText
  }
}

# 4) Availability Set
$avsetObj = Get-AzAvailabilitySet -ResourceGroupName $Rg -Name $AvSet -ErrorAction SilentlyContinue
if (-not $avsetObj) {
  $avsetObj = New-AzAvailabilitySet `
    -ResourceGroupName $Rg -Location $Location `
    -Name $AvSet `
    -Sku Aligned `
    -PlatformFaultDomainCount 2 `
    -PlatformUpdateDomainCount 5
}

# Допоміжна функція: створити ВМ у Availability Set (без Public IP, без -OpenPorts!)
function New-AvailSetVm {
  param(
    [string]$Name
  )
  if (-not (Get-AzVM -Name $Name -ResourceGroupName $Rg -ErrorAction SilentlyContinue)) {
    New-AzVM `
      -ResourceGroupName $Rg `
      -Location $Location `
      -Name $Name `
      -Image $Image `
      -Size $VmSize `
      -VirtualNetworkName $Vnet `
      -SubnetName $Subnet `
      -SecurityGroupName $Nsg `
      -SshKeyName $SshRes `
      -AvailabilitySetName $AvSet `
      -Verbose | Out-Null
  } else {
    Write-Host "ℹ️  VM '$Name' already exists — skipping."
  }
}

# 5) Дві ВМ у одному Availability Set
New-AvailSetVm -Name $Vm1
New-AvailSetVm -Name $Vm2

# 6) Коротка перевірка + результат
$vms = Get-AzVM -ResourceGroupName $Rg -Status | Where-Object { $_.Name -in @($Vm1,$Vm2) }
$vms | Select-Object Name, @{n='AvailabilitySet';e={$_.AvailabilitySetReference.Id}}, Location

# 7) (опційно) Згенерувати result.json локально з даними для артефактів
$result = @(
  [pscustomobject]@{ Name = $Vm1; AvailabilitySet = $AvSet; Location = $Location },
  [pscustomobject]@{ Name = $Vm2; AvailabilitySet = $AvSet; Location = $Location }
)
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "result.json" -Encoding UTF8

Write-Host "==> Done. VMs are in the Availability Set '$AvSet'."
