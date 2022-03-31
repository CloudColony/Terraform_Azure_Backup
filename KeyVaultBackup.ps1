$StorageAccountKey = "oszdP+l1SPA0SJgzakeR6rWMX/K9VWPl7+l7GbmaT6b1Xkk67yamw6ZfhKT89E68iaCQbwdpkrA++ASt8H4KAw=="
$keyvaultName = "kv-backup-veritas"
$keyVaultResourceGroup = "veritas-rg"
$storageAccountName = "dolayokunsa"
$storageResourceGroup = "veritas-rg"   
$container = "kvbackupcontainer"
$fileshareFolder="KeyVaultBackup" 


$localZipFolder = "C:\Users\caleb.adepoju\Desktop\KeyVaultBackUp\$fileshareFolder\$sub\$keyvaultName" #"$env:Temp\$fileshareFolder\$sub\$keyvaultName"

# Subscription
Get-AzSubscription -SubscriptionId "" | ForEach-Object {
  $sub = $_.Name
}

# Setup backup directory
$tmpFolder = "$localZipFolder"
If ((test-path $tmpFolder)) {
  Remove-Item $tmpFolder -Recurse -Force
}

# Backup items
New-Item -ItemType Directory -Force -Path $tmpFolder | Out-Null
Write-Output "Starting backup of KeyVault to local directory"

# Certificates
$certificates   = Get-AzKeyVaultCertificate -VaultName $keyvaultName -IncludePending
foreach ($cert in $certificates) {
  Backup-AzKeyVaultCertificate `
    -Name $cert.name `
    -VaultName $keyvaultName `
    -OutputFile "$tmpFolder/certificate-$($cert.name)" | Out-Null
}
# Secrets
$secrets = Get-AzKeyVaultSecret -VaultName $keyvaultName 
foreach ($secret in $secrets) {
  #Exclude any secerets automatically generated when creating a cert, as these cannot be backed up   
  if (!($certificates.Name -contains $secret.name)) {
    Backup-AzKeyVaultSecret `
      -Name $secret.name `
      -VaultName $keyvaultName `
      -OutputFile "$tmpFolder/secret-$($secret.name)" | Out-Null
  }
}
# keys
$keys = Get-AzKeyVaultKey -VaultName $keyvaultName
foreach ($key in $keys) {
  #Exclude any keys automatically generated when creating a cert, as these cannot be backed up   
  if (! ($certificates.Name -contains $key.name)) {
    Backup-AzKeyVaultKey `
      -Name $key.name `
      -VaultName $keyvaultName `
      -OutputFile "$tmpFolder/key-$($key.name)" | Out-Null
  }
}

Write-Output "Local file backup complete"  

$storageAccount = 
  Get-AzStorageAccount `
    -ResourceGroupName $storageResourceGroup `
    -Name $storageAccountName 

$timeStamp = Get-Date -format "yyyy-MM-dd"
$zipFile = "$tmpFolder/$($keyvaultName)-$($timeStamp).zip"
$compress = @{
  Path = "$tmpFolder/*"
  CompressionLevel = "Optimal"
  DestinationPath = $zipFile
}
Compress-Archive @compress

$ctx = New-AzStorageContext -StorageAccountname $storageAccountName -StorageAccountKey $StorageAccountKey
Set-AzCurrentStorageAccountAccount -ResourceGroupName "veritas-rg" -AccountName "dolayokunsa"
$blobPath = "$sub/$keyvaultName/$($keyvaultName)-$($timeStamp).zip"

# upload files, overwriting existing
Write-Output "Starting upload of backup to zip Files"
Set-AzStorageBlobContent `
  -Container $container `
  -File $zipFile `
  -Blob $blobPath `
  -Context $storageAccount.Context 

Remove-Item $tmpFolder -Recurse -Force
Write-Output "Backup Complete"
