param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
    [bool]$DownloadArtifacts=$true
)


# default script values 
$taskName = "task11"

$artifactsConfigPath = "$PWD/artifacts.json"
$resourcesTemplateName = "exported-template.json"
$tempFolderPath = "$PWD/temp"

if ($DownloadArtifacts) { 
    Write-Output "Reading config" 
    $artifactsConfig = Get-Content -Path $artifactsConfigPath | ConvertFrom-Json 

    Write-Output "Checking if temp folder exists"
    if (-not (Test-Path "$tempFolderPath")) { 
        Write-Output "Temp folder does not exist, creating..."
        New-Item -ItemType Directory -Path $tempFolderPath
    }

    Write-Output "Downloading artifacts"

    if (-not $artifactsConfig.resourcesTemplate) { 
        throw "Artifact config value 'resourcesTemplate' is empty! Please make sure that you executed the script 'scripts/generate-artifacts.ps1', and commited your changes"
    } 
    Invoke-WebRequest -Uri $artifactsConfig.resourcesTemplate -OutFile "$tempFolderPath/$resourcesTemplateName" -UseBasicParsing

}

Write-Output "Validating artifacts"
$TemplateFileText = [System.IO.File]::ReadAllText("$tempFolderPath/$resourcesTemplateName")
$TemplateObject = ConvertFrom-Json $TemplateFileText -AsHashtable

$nsg = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Network/networkSecurityGroups")
if ($nsg) {
    if ($nsg.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if the Network Security Group resource exists - OK"
    }  else { 
        Write-Output `u{1F914}
        throw "More than one Network Security Group resource was found in the task resource group. Please make sure that your script creates only one network security group (check if script attaches the NSG you are creating to the subnet) and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find Network Security Group resouce. Please re-deploy the VM and try again."
}

$virtualNetwork = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Network/virtualNetworks" )
if ($virtualNetwork ) {
    if ($virtualNetwork.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if virtual network exists - OK."
    }  else { 
        Write-Output `u{1F914}
        throw "More than one virtual network resource was found in the task resource group. Please make sure that your script deploys only 1 virtual network, and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find virtual network in the task resource group. Please make sure that your script creates a virtual network and try again."
}

$virtualNetworkName = $virtualNetwork.name.Replace("[parameters('virtualNetworks_", "").Replace("_name')]", "")
if ($virtualNetworkName -eq "vnet") { 
    Write-Output "`u{2705} Checked the virtual network name - OK."
} else { 
    Write-Output `u{1F914}
    throw "Unable to verify the virtual network name. Please make sure that your script creates a virtual network called 'vnet' and try again."
}

$subnet = $virtualNetwork.properties.subnets
if ($subnet) {
    if ($subnet.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if subnet exists - OK."
    }  else { 
        Write-Output `u{1F914}
        throw "More than one subnet was found in the virtual network. Please make sure that your script deploys only 1 subnet, and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find subnet in the virtual network. Please make sure that your script creates a subnet and try again."
}

if ($subnet.name -eq "default") { 
    Write-Output "`u{2705} Checked the subnet name - OK."
} else { 
    Write-Output `u{1F914}
    throw "Unable to verify the subnet name. Please make sure that your script creates a subnet called 'default' and try again."
}

$sshKey = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Compute/sshPublicKeys")
if ($sshKey) {
    if ($sshKey.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if the public SSH key resource exists - OK"
    }  else { 
        Write-Output `u{1F914}
        throw "More than one public SSH key resource was found in the VM resource group. Please make sure that your script creates only one public SSH key resource and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find public SSH key resouce. Please make sure that your script creates a public SSH key resouce and try again."
}

$sshKeyName = $sshKey.name.Replace("[parameters('sshPublicKeys_", "").Replace("_name')]", "")
if ($sshKeyName -eq "linuxboxsshkey") { 
    Write-Output "`u{2705} Checked the public ssh key name - OK"
} else { 
    Write-Output `u{1F914}
    throw "Unable to verify the public ssh key name. Please make sure that your script creates a public ssh key called 'linuxboxsshkey' and try again."
}

$availabilitySet = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Compute/availabilitySets" )
if ($availabilitySet) {
    if ($availabilitySet.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if the availability set resource exists - OK"
    }  else { 
        Write-Output `u{1F914}
        throw "More than one availability set resource  was found in the task resource group. Please make sure that your script creates only one availability set resource and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find availability set resource. Please make sure that your script creates a availability set resource and try again."
}

$virtualMachines = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Compute/virtualMachines" )
if ($virtualMachines) {
    if ($virtualMachines.name.Count -eq 2) { 
        Write-Output "`u{2705} Checked if Virtual Machines exists - OK."
    }  else { 
        Write-Output `u{1F914}
        throw "Wrong number of Virtual Machine resource was found in the task resource group. Please make sure that your script creates 2 VMs and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find Virtual Machines in the task resource group. Please make sure that your script creates 2 VMs and try again."
}

foreach ($virtualMachine in $virtualMachines) { 
    if ($virtualMachine.properties.availabilitySet.id) { 
        Write-Output "`u{2705} Checked if virtual machine has availability set assigned - OK"
    } else  {
        Write-Output `u{1F914}
        throw "Unable to verify that VM is assigned to the availability set. Please make sure that you are assinging the VM to the availability set during the creation with parameter '-AvailabilitySetName' and try again."
    }

    if ($virtualMachine.properties.osProfile.linuxConfiguration.ssh.publicKeys.keyData -eq $sshKey.properties.publicKey) { 
        Write-Output "`u{2705} Checked if virtual machine uses the public ssh key 'linuxboxsshkey' - OK"
    } else { 
        Write-Output `u{1F914}
        throw "Unable to verify that VM uses the public ssh key 'linuxboxsshkey'. Please make sure that in New-AzVm comandled, parameter '-SshKeyName' is set to the name of the public SSH key you created earlier, and that you are not setting the parameter '-GenerateSshKey'."
    }

    if ($virtualMachine.properties.storageProfile.imageReference.publisher -eq "canonical") { 
        Write-Output "`u{2705} Checked Virtual Machine OS image publisher - OK" 
    } else { 
        Write-Output `u{1F914}
        throw "Virtual Machine uses OS image from unknown published. Please make sure that your script creates a VM from image with friendly name 'Ubuntu2204' and try again."
    }
    if ($virtualMachine.properties.storageProfile.imageReference.offer.Contains('ubuntu-server') -and $virtualMachine.properties.storageProfile.imageReference.sku.Contains('22_04')) { 
        Write-Output "`u{2705} Checked Virtual Machine OS image offer - OK"
    } else { 
        Write-Output `u{1F914}
        throw "Virtual Machine uses wrong OS image. Please make sure that your script creates a VM from image with friendly name 'Ubuntu2204' and try again." 
    }

    if ($virtualMachine.properties.hardwareProfile.vmSize -eq "Standard_B1s") { 
        Write-Output "`u{2705} Checked Virtual Machine size - OK"
    } else { 
        Write-Output `u{1F914}
        throw "Virtual Machine size is not set to B1s. Please make sure that your script creates a VM with size B1s and try again."
    }
}

Write-Output ""
Write-Output "`u{1F973} Congratulations! All tests passed!"