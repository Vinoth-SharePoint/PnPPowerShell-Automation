function  UpdateSPOBusinessUseChangeRequest {
  [CmdletBinding()]
  param
  (
   
    [Parameter(Mandatory = $true)] [string]$siteUrl,
    [Parameter(Mandatory = $true)] [string]$businessUse,
    [Parameter(Mandatory = $true)] [string]$listItemIdentity,   
    [Parameter(Mandatory = $true)] [string]$appID, 
    [Parameter(Mandatory = $true)] [string]$appSecret,
    [Parameter(Mandatory = $false)] [int]$scriptAttempt,
    [Parameter(Mandatory = $true)] [string]$spoMasterListURL

  )
  begin {
    
    #Define Variable 
    if ($null -eq $scriptAttempt) { $scriptAttempt = 0 }
    $addScriptResponse = New-Object System.Collections.ArrayList
    $createErrorList;
    $todayDate = Get-Date -f "dd/MM/yyyy HH:mm:ss"
   
    #Define Common Params
    $Params = @{
      ErrorVariable = "createErrorList"
      ErrorAction   = "SilentlyContinue"
    }

    #Check if Site is created already or not
    $Site = Get-PnPTenantSite | Where-Object { $_.Url -eq $siteURL }

  }
  #--------------------------------------------------------------------------------------------------------------------------
  process {
    if ($Site) {
      
      Log-Message "Processing Business Use Change-$siteUrl" $logFile Process
      Connect-PnPOnline -Url $siteUrl -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
      $addScriptResponse.Add("Business Use Change has been Updated : $siteUrl")
      $BusinessUse = $true
      #Logic Yet to be write#
    }
    else {
      Log-Message "The requested site does not exist" $logfile Error
      $createErrorList = $true
      $addScriptResponse.Add("Requested Site does not exists")
    }
    
    #Get GUID ,URL to Update MasterList and Update Tracker List as well
    if ($BusinessUse) {
      $getProperty = Get-PnPSite -Includes Id, Url @Params
      $getSiteCollectionURL = $getProperty.Url
      $getSiteCollectionGUID = $getProperty.Id
          
    }
    
    #Update SPO Site Creation List and Error Handling
    if (!$createErrorList) {
    
      Connect-PnPOnline -Url $siteCollectionURL -Credentials $ADUserCredentials
      #Update list item -> When site is created Successfully
      $scriptAttempt++
      Set-PnPListItem -List SiteUpdateTracker -Identity $listItemIdentity -Values @{ 
        "SiteUpdationStatus"    = "Completed";
        "RequestCompletionDate" = $todayDate;
        "SiteURL"               = $getSiteCollectionURL;
        "SiteGUID"              = $getSiteCollectionGUID;
        "ScriptAttempts"        = $scriptAttempt; 
        "ScriptResponse"        = "SPO Business Use Change request has been updated Successfully"; 
        "ScriptHistory"         = $addScriptResponse
      }
      Log-Message "SPO List Item Updated Successfully" $logFile Success  
      UpdateMasterList $listItemIdentity $appID $appSecret $spoMasterListURL
    }

    else {
      Connect-PnPOnline -Url $siteCollectionURL -Credentials $ADUserCredentials
      #Update list item -> Script Attempt less then or equal 4
      if ($scriptAttempt -le "4") {
        $scriptAttempt++
        Set-PnPListItem -List SiteUpdateTracker -Identity $listItemIdentity -Values @{
          "SiteUpdationStatus" = "Error";
          "ScriptAttempts"     = $scriptAttempt;
          "ScriptResponse"     = "SPO Business Use Change request has been failed to Update";
          "ScriptHistory"      = $addScriptResponse  
        }
      }
      #Update list item -> Script Attempt equal 5 OR Site Already exists
      if ( ($scriptAttempt -eq "5") -or ($addScriptResponse -eq 'Requested Site does not exists')) {
        Set-PnPListItem -List SiteUpdateTracker -Identity $listItemIdentity -Values @{ 
          "SiteUpdationStatus" = "Rejected";
          "ScriptAttempts"     = $scriptAttempt;
          "ScriptResponse"     = "SPO Business Use Change request has been Rejected";
          "ScriptHistory"      = $addScriptResponse 
        }
            
      }
    }
    Clear-Item Variable:createErrorList
  }

  end { Log-Message "SPO Business Use Change request has been completed Successfully!!" $logfile Success }
}

#===========================================> ***End*** ========================================================================>


  







