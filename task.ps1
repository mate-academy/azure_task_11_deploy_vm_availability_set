# Параметри розгортання
$location = "eastus" # Змініть на бажаний регіон
$resourceGroupName = "mate-azure-task-11"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub" -ErrorAction Stop
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$availabilitySetName = "mateavalset"
$adminUsername = "azureuser"
$adminPassword = ConvertTo-SecureString "Azure123456!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($adminUsername, $adminPassword)
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

# 1. Створення групи ресурсів
try {
    Write-Host "Перевірка групи ресурсів..."
    $null = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction Stop
    Write-Host "Група ресурсів вже існує."
} catch {
    Write-Host "Створення групи ресурсів '$resourceGroupName'..."
    New-AzResourceGroup -Name $resourceGroupName -Location $location
}

# 2. Створення SSH ключа
try {
    Write-Host "Перевірка SSH ключа..."
    $sshKey = Get-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -ErrorAction Stop
    Write-Host "SSH ключ вже існує."
} catch {
    Write-Host "Створення SSH ключа '$sshKeyName'..."
    $sshKey = New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey
}

# 3. Створення NSG
try {
    Write-Host "Перевірка мережевої групи безпеки..."
    $nsg = Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -ErrorAction Stop
    Write-Host "Мережева група безпеки вже існує."
} catch {
    Write-Host "Створення NSG '$networkSecurityGroupName'..."
    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 `
        -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
    $nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 `
        -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
    $nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName `
        -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP
}

# 4. Створення VNet і підмережі
try {
    Write-Host "Перевірка віртуальної мережі..."
    $vnet = Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -ErrorAction Stop
    Write-Host "Віртуальна мережа вже існує."
} catch {
    Write-Host "Створення VNet '$virtualNetworkName' з підмережею '$subnetName'..."
    $subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup $nsg
    $vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName `
        -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet
}

# 5. Створення Availability Set
try {
    Write-Host "Перевірка Availability Set..."
    $avSet = Get-AzAvailabilitySet -Name $availabilitySetName -ResourceGroupName $resourceGroupName -ErrorAction Stop
    Write-Host "Availability Set вже існує."
} catch {
    Write-Host "Створення Availability Set '$availabilitySetName'..."
    $avSet = New-AzAvailabilitySet -ResourceGroupName $resourceGroupName -Name $availabilitySetName `
        -Location $location -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2 -Sku Aligned
}

# 6. Створення віртуальних машин
Write-Host "Створення віртуальних машин..."
1..2 | ForEach-Object {
    $currentVMName = "$vmName-$_"
    
    try {
        $vm = Get-AzVM -Name $currentVMName -ResourceGroupName $resourceGroupName -ErrorAction Stop
        Write-Host "ВМ '$currentVMName' вже існує."
    } catch {
        Write-Host "Створення ВМ '$currentVMName'..."
        
        # Конфігурація ВМ
        $vmConfig = New-AzVMConfig -VMName $currentVMName -VMSize $vmSize -AvailabilitySetId $avSet.Id
        $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $currentVMName -Credential $cred -DisablePasswordAuthentication
        $vmConfig = Add-AzVMSshPublicKey -VM $vmConfig -KeyData $sshKey.PublicKey -Path "/home/$adminUsername/.ssh/authorized_keys"
        $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts" -Version "latest"
        
        # Мережева конфігурація
        $nic = New-AzNetworkInterface -Name "$currentVMName-nic" -ResourceGroupName $resourceGroupName `
            -Location $location -SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $nsg.Id
        
        $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
        
        # Створення ВМ
        New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig -Verbose
    }
}

Write-Host "Розгортання успішно завершено!" -ForegroundColor Green