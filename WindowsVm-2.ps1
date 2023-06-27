# Sign in to your Azure account
Connect-AzAccount

$resourceGoupName =  __resourceGoupName__
$azureRegion = "__azureRegion__"
$vmName = __vmName__
$adminUsername = __adminUsername__
$adminPassword = __adminPassword__

$SecurePassword = ConvertTo-SecureString "Creative@3112" -AsPlainText
$Credential = New-Object System.Management.Automation.PSCredential ("svkadmin", $SecurePassword); 
$zone = 1,2,3
$vmcount = 100
$osname


$rg = Get-AzResourceGroup -Name $resourceGoupName

if ($rg -eq $null)
{
New-AzResourceGroup -Name $resourceGoupName -Location $azureRegion 
}
else {  }


$newSubnetParams = @{
    'Name'          = 'testsubnet'
    'AddressPrefix' = '10.0.1.0/24'
}
$subnet = New-AzVirtualNetworkSubnetConfig @newSubnetParams

$newVNetParams = @{
    'Name'              = 'testvnet'
    'ResourceGroupName' = $resourceGoupName
    'Location'          = $azureRegion
    'AddressPrefix'     = '10.0.0.0/16'
}
$vNet = New-AzVirtualNetwork @newVNetParams -Subnet $subnet



$newStorageAcctParams = @{
    'Name'              = 'sgtest2ds' ## Must be globally unique and all lowercase
    'ResourceGroupName' = $resourceGoupName
    'Type'              = 'Standard_LRS'
    'Location'          = $azureRegion
}
$storageAccount = New-AzStorageAccount @newStorageAcctParams

$newPublicIpParams = @{
    'Name'              = 'testnic'
    'ResourceGroupName' = $resourceGoupName
    'AllocationMethod'  = 'Static' ## Dynamic or Static
    #'DomainNameLabel'  = 'test-domain'
    'Location'          = $azureRegion
     'SKU'              = 'Standard'
     'Zone'             = $zone
 }

$publicIp = New-AzPublicIpAddress @newPublicIpParams

# Create a network security group
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGoupName -Location $azureRegion -Name "trainingnsg"

# Create an inbound rule in the NSG to allow RDP
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name "RDP" -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg

$newVNicParams = @{
    'Name'              = 'testnic'
    'ResourceGroupName' = $resourceGoupName
    'Location'          = $azureRegion
}
$vNic = New-AzNetworkInterface @newVNicParams -SubnetId $vNet.Subnets[0].Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id

$newConfigParams = @{
    'VMName' = $vmName
    'VMSize' = 'Standard_DS1_v2'
}
$vmConfig = New-AzVMConfig @newConfigParams 

$newVmOsParams = @{
    'Windows'          = $true
    'ComputerName'     = $vmName
    'Credential'       = $Credential
    'ProvisionVMAgent' = $true
    'EnableAutoUpdate' = $true
}
$vm = Set-AzVMOperatingSystem @newVmOsParams -VM $vmConfig


$newSourceImageParams = @{
    'PublisherName' = 'MicrosoftWindowsServer'
    'Version'       = 'latest'
    'Skus'          = '2019-Datacenter'
}

$vm = Set-AzVMSourceImage @newSourceImageParams -VM $vm -Offer 'WindowsServer'

$vm = Add-AzVMNetworkInterface -VM $vm -Id $vNic.Id


$osDiskName = 'myDisk'
$osDiskUri = $storageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName + $osDiskName + ".vhd"

$newOsDiskParams = @{
    'Name'         = 'OSDisk'
    'CreateOption' = 'fromImage'
}

$vm = Set-AzVMOSDisk @newOsDiskParams -VM $vm -VhdUri $osDiskUri


New-AzVM -VM $vm -ResourceGroupName $resourceGoupName -Location $azureRegion
