#Connection to Services
function Get-Configuration {
  [CmdletBinding()]
  param( [Parameter(Mandatory = $true)] [string]$tenantURL )
 	$SPOnlineFunctionsConfigFile = $($PSScriptFolder + "\SPOConfiguration.xml")
  if ((Test-Path $SPOnlineFunctionsConfigFile)) {
    $returnAuth = @{}
    #Reading XML file content and define the parameter
    [xml]$SPOnlineFunctionsConfig = Get-Content $SPOnlineFunctionsConfigFile
    $appID = $SPOnlineFunctionsConfig.configuration.appSettings.ClientId
    $appSecret = $SPOnlineFunctionsConfig.configuration.appSettings.ClientSecret
    Connect-PnPOnline -Url $tenantURL -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
    $returnAuth.appID = $appID
    $returnAuth.appSecret = $appSecret
    return $returnAuth
    
  }

}

#Log Message
function Log-Message {
  [CmdletBinding()]
  param

  ([Parameter(Mandatory = $true)] [string]$message, 
    [Parameter(Mandatory = $true)] [string]$logFile,
    [Parameter(Mandatory = $false)] [string]$logStatus)

  $DateTimeStamp = Get-Date -f "dd/MM/yyyy HH:mm:ss"
  "$DateTimeStamp,$message,$logStatus" | Out-File -Encoding Default -Append -FilePath $logFile
  Write-Host "===========================================================" -ForegroundColor White
  if ($logStatus -eq "Warning") { Write-Host $message -BackgroundColor Yellow -ForegroundColor Black }
  if ($logStatus -eq "Success") { Write-Host $message -BackgroundColor Green -ForegroundColor Black }
  if ($logStatus -eq "Error") { Write-Host $message -BackgroundColor Red -ForegroundColor Black }
  if ($logStatus -eq "Process") { Write-Host $message -BackgroundColor White -ForegroundColor Black }
}
#=======>Update Site Master List=======>#
function UpdateMasterList {

  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)] [string]$listItemIdentity,
    [Parameter(Mandatory = $true)] [string]$appID, 
    [Parameter(Mandatory = $true)] [string]$appSecret,
    [Parameter(Mandatory = $true)] [string]$spoMasterListURL
  )  
  
  begin {
    #Read Completed record and pass the value to Switch case
    $readListItem = Get-PnPListItem -List SiteUpdateTracker | Where-Object { ($_.FieldValues.ID -eq "$listItemIdentity") -and (($_.FieldValues.SiteUpdationStatus -eq "Completed")) }
    $SiteUpdateRequestType = $readListItem.FieldValues.SiteUpdateRequestType

    #Connect MasterList and Update  
    Connect-PnPOnline -Url $spoMasterListURL -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
    $readMasterListItemIdentity = Get-PnPListItem -List SiteMasterList | Where-Object { ($_.FieldValues.SiteURL -eq $readListItem.FieldValues.SiteURL ) }
  }

  Process {
    if ($SiteUpdateRequestType) {
      #--------------------------------------------------------------------------------------------------------------#
      switch ( $SiteUpdateRequestType ) { 
        'Site Ownership Change' {
           Set-PnPListItem -List SiteMasterList -Identity $readMasterListItemIdentity -Values  @{
            "PrimaryOwnerEmail"   =	$readListItem.FieldValues.PrimaryOwnerEmail;
            "SecondaryOwnerEmail" =	$readListItem.FieldValues.SecondaryOwnerEmail;
            "ScriptHistory"       =	$readListItem.FieldValues.ScriptHistory;
          } 
        }
        #--------------------------------------------------------------------------------------------------------------#
        'Business Use Change' {
          Set-PnPListItem -List SiteMasterList -Identity $readMasterListItemIdentity -Values  @{
            "BusinessUse"   =	$readListItem.FieldValues.BusinessUse;
            "ScriptHistory" =	$readListItem.FieldValues.ScriptHistory;
          } 
        }
        #--------------------------------------------------------------------------------------------------------------#  
        'Hub Site Association' {
          Set-PnPListItem -List SiteMasterList -Identity $readMasterListItemIdentity -Values  @{
            "ScriptHistory" =	$readListItem.FieldValues.ScriptHistory;
          } 
        }
        #--------------------------------------------------------------------------------------------------------------#  
        'Hub Site Disassociation' {
          Set-PnPListItem -List SiteMasterList -Identity $readMasterListItemIdentity -Values  @{
            "ScriptHistory" =	$readListItem.FieldValues.ScriptHistory;
          } 
        }
        #--------------------------------------------------------------------------------------------------------------#  
        'Site Archival' {
          Set-PnPListItem -List SiteMasterList -Identity $readMasterListItemIdentity -Values  @{
            "SiteStatus"    =	$readListItem.FieldValues.SiteStatus; #Locked
            "ScriptHistory" =	$readListItem.FieldValues.ScriptHistory;
          } 
        }
        #--------------------------------------------------------------------------------------------------------------#  
      }
    }

  }
  end { Log-Message "Update MasterList Successfully" $logFile Success }  
}

#===========================================> ***End*** ========================================================================>