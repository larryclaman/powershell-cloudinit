# Build a linux VM and apply cloud-init file to it via powershell

<#
Login-AzureRmAccount
$subscriptionId = (Get-AzureRmSubscription |Out-GridView -Title “Select an Azure Subscription …” -PassThru)
Select-AzureRmSubscription -SubscriptionId $subscriptionId.Id
#>


$Location="EastUS"

$SourceRg="ServiceNetEastRG" # pre-existing RG containing a pre-existing vnet
$SourceVnet="ServiceNetworkEastVnet"  # name of pre-existing vnet
$SubnetName="AppSubnetA" # pre-existing subnet in the above vnet

$Groupname="DevRG"  # Name of resource group for new vm

$VMLocalAdminUser = "adminuser"
$password="CHANGEME1234!"  # CHANGE THIS!!!!!!

# three options for provisioning cloud init
# uncomment one of these per your preference

# Option 1: inline
<#
$EncodedText="#cloud-config `
write_files: `
  - path: `"/tmp/my_file.txt`" `
    permissions: `"0644`" `
    owner: `"root`" `
    content: | `
      Here is some sample content."
#>
# Option 2  encode a file
$CloudinitFile="cloud-basic.txt"
$Bytes = [System.Text.Encoding]::Unicode.GetBytes((Get-Content -raw $CloudinitFile))
$EncodedText=(Get-Content -raw $CloudinitFile)


<# Option 3 use a cloud init file hosted elsewhere
$url = "https://containername.blob.core.windows.net/info/cloud-basic.txt"
$EncodedText="#include `
$url"
#>


## Create VMS ############################################################################################
$ubuIMAGEURG="UbuntuLTS"
$vmsize = "Standard_D2s_v3"
$VMLocalAdminSecurePassword = ConvertTo-SecureString $password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

$vmnameprefix = "lin"
$nicprefix =  "nic1"
$vmobj =  @{ `
    'name'= 'ubu1';
    'subnet' = $Subnetname;
    'os' = "ubuntu"
    }

$sourceVnetPS= Get-AzureRmVirtualNetwork -ResourceGroupName $SourceRg -Name $SourceVnet -ErrorAction Stop
$subnetid = (Get-AzureRmVirtualNetworkSubnetConfig -name $vmobj.subnet -VirtualNetwork $sourceVnetPS).Id
$NIC = New-AzureRmNetworkInterface -Name $nicprefix -ResourceGroupName $Groupname -Location $Location -Subnetid $Subnetid

$VirtualMachine = New-AzureRmVMConfig -VMName $vmobj.name -VMSize $vmsize 
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id

$VirtualMachine = Set-AzureRmVMSourceImage -PublisherName Canonical -Offer UbuntuServer -Skus 16.04-LTS -Version latest -VM  $VirtualMachine
$VirtualMachine = Set-AzureRmVMOperatingSystem -Linux -ComputerName $vmobj.name -Credential $Credential  -VM $VirtualMachine -CustomData $EncodedText

New-AzureRMVM -ResourceGroupName $groupname -Location $location -VM $VirtualMachine