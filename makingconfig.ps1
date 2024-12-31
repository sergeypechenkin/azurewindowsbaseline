
# Test Apply the configuration to the machine
Start-DscConfiguration -Path '.\SecurityBaseline\MOF\' -Wait -Verbose

################################ Create a new Guest Configuration Package ZIP
#Rename-Item -Path .\AzureBaselineDscWindows2019\localhost.mof -NewName SecurityBaseline_v1.mof
# Admin
New-GuestConfigurationPackage -Configuration "D:\OneDrive - Microsoft\Github_repo\azurewindowsbaseline\AzureBaselineDscWindows2019\localhost.mof" -Name SecurityBaseline -Path "D:\OneDrive - Microsoft\Github_repo\azurewindowsbaseline\AzureBaselineDscWindows2019\ConfigurationPackageArtificat" -Type AuditAndSet -Force

New-GuestConfigurationPackage -Configuration .\AzureWindowsBaseline.mof -Name AzureWindowsBaseline -Path .\SecurityBaseline\ConfigurationPackageArtificat -Type AuditAndSet

################################ Upload the Guest Configuration Package ZIP to the Azure Storage Account

Connect-AzAccount -Identity 


#for Azure VMs I use User Managed Identity, but for Arc SAS needed


$StorageAccountName = "saazsecbaseline9"
$ContainerName = "machineconfiguration"
$BlobName = "SecurityBaseline.zip"
$LocalFilePath = "C:\AzSecurityBaseline\SecurityBaseline.zip" 

# Check if Privatelink resolves into private endpoint if used
Resolve-DnsName -Name "saazsecbaseline9.blob.core.windows.net"

# Create the Storage Context using Managed Identity
$Context = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

# Upload the file to the blob
Set-AzStorageBlobContent -File $LocalFilePath `
                         -Container $ContainerName `
                         -Blob $BlobName `
                         -Context $Context `
                         -Force

$Blob = Get-AzStorageBlob -Container $ContainerName -Blob $BlobName -Context $Context
$ContentUri = $Blob.ICloudBlob.Uri.AbsoluteUri

#create SAS token and store it to KV

# Retrieve the SAS token from Azure Key Vault
$SecretName = "Policysastoken"
$KeyVaultName = "kv-mwscinav-test-uksouth"
$SasToken = New-AzStorageAccountSASToken -Context $Context -Service Blob -ResourceType Container, Object -Permission rwdl -ExpiryTime (Get-Date).AddDays(6)
Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue $SasToken

# Get the SAS token from Azure Key Vault 
$SecretName = "Policysastoken"
$KeyVaultName = "kv-mwscinav-test-uksouth"
$SasToken = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName

# Construct the URL
$ContentUri = "https://saazsecbaseline9.privatelink.blob.core.windows.net/machineconfiguration/SecurityBaseline.zip"

$ContentUri = "https://oaasguestconfigwcuss1.blob.core.windows.net/builtinconfig/AzureWindowsBaseline/AzureWindowsBaseline_1.3.0.0.zip"
# Use the SAS token with Invoke-WebRequest
Invoke-WebRequest -Uri $ContentUri -Method Get #test


https://oaasguestconfigwcuss1.blob.core.windows.net/builtinconfig/AzureWindowsBaseline/AzureWindowsBaseline_1.2.0.0.zip

$PolicyConfig      = @{
    PolicyId      = (New-Guid)
    ContentUri    = $ContentUri
    DisplayName   = 'SecurityBaseline'
    Description   = 'SecurityBaseline'
    Path          = './SecurityBaseline/policies/deployIfNotExists.json'
    Platform      = 'Windows'
    PolicyVersion = '1.0.0'
    Mode          = 'ApplyAndAutoCorrect'
      # Required parameter for managed identity 
    LocalContentPath = $LocalFilePath
    ManagedIdentityResourceId = "/subscriptions/045bfdf2-9919-49d9-a70b-1543bc91928f/resourceGroups/rg-managementhub-uksouth-001/providers/Microsoft.ManagedIdentity/userAssignedIdentities/vmuseridentity" 
  }
  
  New-GuestConfigurationPolicy @PolicyConfig -excludearcmachines #donotexcludeArcmachines when switch to SAS
  New-AzPolicyDefinition -Name 'SecurityBaselineTest' -Policy SecurityBaseline\policies\deployIfNotExists.json\SecurityBaseline_DeployIfNotExists.json



  #done, policy should be created. Assign it to a scope and trigger policy scan on Azure Portal console

  az policy state trigger-scan

  
 

  






