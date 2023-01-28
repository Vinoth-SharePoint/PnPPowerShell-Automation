<#

.DESCRIPTION
=============
This Script Contains 5 different modules.Each modules will perform the Site update operation based on MyIT request.
1. Site Owner Change       : Change either Primary Admin or Secondary admin
2. Business Use Change     : Update Business Use Change value into MasterList
3. Hub Site Association    : Associate Hub Site with Existing Hub Site
4. Hub Site DissAssociation: DissAssociate Hub Site with Existing Hub Site
5. Site Archival           : Lock the Site or Set the site read only mode

EXAMPLE
========

.\Provision-DomainSPOSiteUpdate.ps1

.NOTES
Created by   : Vinothkumar Vijayabalan
Date Coded   : 07/Jun/2021 

.Prerequisites
====================
PnP.PowerShell Required Version : 1.5.0

#>

[CmdletBinding()]
param(      
  [Parameter(Mandatory = $true)][string]$tenantURL
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

#Frame SPORequest and MasterList SiteCollection URL from Tenant URL
$siteCollectionURL = $tenantURL + "/sites/SPORequests"
$spoMasterListURL = $tenantURL + "/sites/SharePoint"

#Import Modules
. "$PSScriptFolder\Common.ps1"
. "$PSScriptFolder\Update-DomainSPOHubSiteAssociation.ps1"
. "$PSScriptFolder\Update-DomainSPOHubSiteDissassociation.ps1"
. "$PSScriptFolder\Update-DomainSPOSiteOwnerChangeRequest.ps1"
. "$PSScriptFolder\Update-DomainSPOBusinessUseChangeRequest.ps1"
. "$PSScriptFolder\Update-DomainSPOSiteArchivalRequest.ps1"


try { 
    
  #Connect to SPO
  $appAuthentication = Get-Configuration $tenantURL
  $appID = $appAuthentication.appID
  $appSecret = $appAuthentication.appSecret
  Write-Host "Connecting PnP Online using AppID and AppSecret Method..." -ForegroundColor Green 
  Connect-PnPOnline -Url $siteCollectionURL -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
    
  #Puts list into an array variable to Update
  $spoSitesToUpate = Get-PnPListItem  -List SiteUpdateTracker | Where-Object { ($_.FieldValues.SiteUpdationStatus -eq "New") -or (($_.FieldValues.SiteUpdationStatus -eq "Error") -and ($_.FieldValues.ScriptAttempts -le "5")) }
  foreach ($siteRequest in $spoSitesToUpate) {
    $siteUpdateRequestType = $siteRequest.FieldValues.SiteUpdateRequestType
    $siteOwners = $siteRequest.FieldValues.SiteOwners
    $siteUrl = $siteRequest.FieldValues.SiteURL
    $ownerToChange = $siteRequest.FieldValues.OwnerToChange
    $newOwnerNameEmail = $siteRequest.FieldValues.NewOwnerEmail
    $existingHUBsiteURL = $siteRequest.FieldValues.HubSiteURL       
    $businessUse = $siteRequest.FieldValues.BusinessUse
    $listItemIdentity = $siteRequest.FieldValues.ID
    $scriptAttempt = $siteRequest.FieldValues.ScriptAttempts 
    #------------------------------------------------------------------------------------------------------------------------#  
    #Call function based on SiteType and Import respective PowerShell Module
    switch ( $SiteUpdateRequestType ) { 
      'Site Ownership Change' {
        UpdateSPOSiteOwnerChangeRequest $siteUrl $ownerToChange $newOwnerNameEmail $siteCollectionURL $listItemIdentity $appID $appSecret $scriptAttempt $spoMasterListURL
      }
      'Business Use Change' {
        UpdateSPOBusinessUseChangeRequest $siteUrl $businessUse $listItemIdentity $appID $appSecret $scriptAttempt $spoMasterListURL
      }
      'Hub Site Association' {
        UpdateSPOHubSiteAssociationRequest $siteUrl $siteUpdateRequestType $existingHUBsiteURL $siteCollectionURL $listItemIdentity $appID $appSecret $scriptAttempt $spoMasterListURL
      }
      'Hub Site Disassociation' {
        UpdateSPOHubSiteDissAssociationRequest $siteUrl $siteUpdateRequestType $existingHUBsiteURL $siteCollectionURL $listItemIdentity $appID $appSecret $scriptAttempt $spoMasterListURL
      }
      'Site Archival' {
        UpdateSPOSiteArchivalRequest $siteUrl $siteOwners $siteCollectionURL $listItemIdentity $appID $appSecret $scriptAttempt $spoMasterListURL
      }
    }
    #------------------------------------------------------------------------------------------------------------------------#   
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




  
    
  
  
  
  
  
  
  
  





