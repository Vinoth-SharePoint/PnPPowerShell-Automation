
[CmdletBinding()]
param(
       
  [Parameter(Mandatory = $false)][string]$SiteCollectionURLl,
  $tenantURL = "https://vinovijayabalan.sharepoint.com"
)

#Set Proxy creds and TLS Version
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials 
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12   

#Get the parent folder path
$PSScriptFolder = $PSScriptRoot
$Date = Get-Date
$fileDate = $Date.ToString('MM-dd-yyyy_hh-mm-ss')
$logfile = ($PSScriptRoot + "\PSLogs" + "\Provision-DomainSPOSiteupdate-" + $fileDate + ".log")
$env:PNPLEGACYMESSAGE = 'false'

#Frame SiteCollection URL from Tenant URL
$siteCollectionURL = $tenantURL + "/sites/SPORequests"
$spoMasterListURL = $tenantURL + "/sites/SPORequests"

#Import Modules
. "$PSScriptFolder\Common.ps1"
. "$PSScriptFolder\Update-DomainStorageQuotaIncrease.ps1"


try { 
    
  #Connect to SPO
  $appAuthentication = Get-Configuration $tenantURL
  $appID = $appAuthentication.appID
  $appSecret = $appAuthentication.appSecret
  Write-Host "Connecting PnP Online using AppID and AppSecret Method..." -ForegroundColor Green 
  Connect-PnPOnline -Url $siteCollectionURL -ClientId $appID -ClientSecret $appSecret
    
  #Puts list into an array variable to Update
  $spoSitesToUpate = Get-PnPListItem  -List SiteStorageUpdateRequests | Where-Object { ($_.FieldValues.SiteUpdationStatus -eq "New") -or (($_.FieldValues.SiteUpdationStatus -eq "Error") -and ($_.FieldValues.ScriptAttempts -le "5")) }
  foreach ($siteRequest in $spoSitesToUpate) {
    $siteUrl = $siteRequest.FieldValues.SiteURL
    $listItemIdentity = $siteRequest.FieldValues.ID
    $scriptAttempt = $siteRequest.FieldValues.ScriptAttempts 
    
    #Call function based on SiteType and Import respective PowerShell Module
    UpdateSPOStorageQuotaRequest $siteUrl $siteCollectionURL $listItemIdentity $appID $appSecret $scriptAttempt $spoMasterListURL
    
  }

}

catch [Exception] {
  #Logging Error message
  $ErrorMessage = $_.Exception.Message
  Log-Message $ErrorMessage $logfile
  Log-Message "Connection has been falied due to Invalid Parameter !! Please check the configuration!!" $logfile Error
  
}

finally {
  #DisConnecting PnP Online
  Disconnect-PnPOnline
  Log-Message "PnP Connection has been disconnected successfully!!" $logFile Success
    
}
#---- End Function--->




  
    
  
  
  
  
  
  
  
  





