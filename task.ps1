# ==============================
# task.ps1 — розгортання двох VM в одному Availability Set
# ЗА УМОВАМИ: без створення Resource Group, без відкриття портів, правильне використання SSH ключа, без публічного IP
# ==============================

$location = "uksouth"
$resourceGroupName = "mate-resources"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$sshPublicKeyPath = "~/.ssh/id_rsa.pub"  # шлях до відкритого ключа SSH
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$availabilitySetName = "mateavalset"

# Створення Availability Set (припускається, що Resource Group існує)
New-AzAvailabilitySet `
    -ResourceGroupName $resourceGroupName `
    -Name $availabilitySetName `
    -Location $location `
    -Sku aligned `
    -PlatformFaultDomainCount 2 `
    -PlatformUpdateDomainCount 2 -ErrorAction Stop

# Зчитування вмісту SSH ключа з файлу
$sshPublicKey = Get-Content -Path $sshPublicKeyPath -Raw

for ($i = 1; $i -le 2; $i++) {
    $vmName = "ubuntu-vm-$i"

    # Створюємо конфігурацію NIC без публічного IP
    $nic = New-AzNetworkInterface `
        -Name "$vmName-nic" `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -SubnetId (Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName).Subnets | Where-Object { $_.Name -eq $subnetName } | Select-Object -ExpandProperty Id `
        -NetworkSecurityGroupId (Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName).Id `
        -PublicIpAddressId $null

    # Конфігурація віртуальної машини з правильним SSH ключем (SshPublicKey)
    $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize `
        | Set-AzVMOperatingSystem -Linux -ComputerName $vmName -Credential (Get-Credential -Message "Enter dummy credentials (login is disabled, use SSH)") `
        | Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts" -Version "latest" `
        | Add-AzVMNetworkInterface -Id $nic.Id `
        | Set-AzVMBootDiagnostics -Disable

    # Додаємо SSH ключ (у правильному форматі)
    $vmConfig = Add-AzVMSSHKey -VM $vmConfig -KeyData $sshPublicKey -Path "/home/azureuser/.ssh/authorized_keys"

    # Вказуємо Availability Set
    $vmConfig.AvailabilitySetId = (Get-AzAvailabilitySet -ResourceGroupName $resourceGroupName -Name $availabilitySetName).Id

    # Створення VM
    New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig -ErrorAction Stop
}
