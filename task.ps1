# Параметри розгортання
$location = "eastus" # Змінено на інший регіон
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$availabilitySetName = "mateavalset"
$adminUsername = "azureuser"
$adminPassword = ConvertTo-SecureString "Azure123456!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($adminUsername, $adminPassword)

# Створення групи ресурсів
if (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "Створення групи ресурсів '$resourceGroupName'..."
    New-AzResourceGroup -Name $resourceGroupName -Location $location
}

# Створення NSG
if (-not (Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "Створення групи безпеки мережі '$networkSecurityGroupName'..."
    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 `
        -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
    $nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 `
        -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
    New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $networkSecurityGroupName `
        -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP
}

# Створення VNet і підмережі
if (-not (Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "Створення віртуальної мережі '$virtualNetworkName' та підмережі '$subnetName'..."
    $subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix `
        -NetworkSecurityGroup (Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName)
    New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkName `
        -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet
}

# Створення SSH ключа
if (-not (Get-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "Створення SSH-ключа '$sshKeyName'..."
    New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey
}

# Створення Availability Set
if (-not (Get-AzAvailabilitySet -ResourceGroupName $resourceGroupName -Name $availabilitySetName -ErrorAction SilentlyContinue)) {
    Write-Host "Створення Availability Set '$availabilitySetName'..."
    New-AzAvailabilitySet -ResourceGroupName $resourceGroupName -Name $availabilitySetName `
        -Location $location -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2 -Sku Aligned
}

# Створення віртуальних машин
Write-Host "Створення віртуальних машин у Availability Set..."
1..2 | ForEach-Object {
    $currentVMName = "$vmName-$_"
    if (-not (Get-AzVM -Name $currentVMName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
        Write-Host "Створення ВМ '$currentVMName'..."
        New-AzVm `
            -ResourceGroupName $resourceGroupName `
            -Name $currentVMName `
            -Location $location `
            -Image $vmImage `
            -Size $vmSize `
            -VirtualNetworkName $virtualNetworkName `
            -SubnetName $subnetName `
            -SecurityGroupName $networkSecurityGroupName `
            -SshKeyName $sshKeyName `
            -AvailabilitySetName $availabilitySetName `
            -Credential $cred `
            -Verbose
    }
}

Write-Host "Розгортання успішно завершено!" -ForegroundColor Green