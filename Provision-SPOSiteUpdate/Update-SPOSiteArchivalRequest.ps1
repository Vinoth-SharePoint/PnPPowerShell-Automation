function  UpdateSPOSiteArchivalRequest {
  [CmdletBinding()]
  param
  (
   
    [Parameter(Mandatory = $true)] [string]$siteUrl,
    [Parameter(Mandatory = $true)] [string]$siteOwners,
    [Parameter(Mandatory = $true)] [string]$siteCollectionURL,
    [Parameter(Mandatory = $true)] [string]$listItemIdentity,   
    [Parameter(Mandatory = $true)] [string]$appID, 
    [Parameter(Mandatory = $true)] [string]$appSecret,
    [Parameter(Mandatory = $false)] [int]$scriptAttempt,
    [Parameter(Mandatory = $true)] [string]$spoMasterListURL
  )
  begin {
    
    #Define Variable 
    $addScriptResponse = New-Object System.Collections.ArrayList
    if($null -eq $scriptAttempt){$scriptAttempt=0}
    $createErrorList;
    $todayDate = Get-Date -f "dd/MM/yyyy HH:mm:ss"
   
    #Define Common Params
    $Params = @{
      ErrorVariable = "createErrorList"
      ErrorAction   = "SilentlyContinue"
    }

    #Check if sites Exist
    $Site = Get-PnPTenantSite | Where-Object { $_.Url -eq $siteURL }
        
    #Define Site Definition
    $WebTemplateID = $Site.Template
    if ($WebTemplateID -eq "GROUP#0") { $siteDefinition = "Group Connected Team Site" }
    if ($WebTemplateID -eq "SITEPAGEPUBLISHING#0") { $siteDefinition = "Communication Site" }
    if ($WebTemplateID -eq "STS#3") { $siteDefinition = "Non-Group Connected Team Site" }

  }
  process {
    if ($Site) {
    
      Connect-PnPOnline -Url $siteUrl -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
      Log-Message "Processing Site Archival Request -$siteUrl" $logFile Process  
      #--------------------------------------------------------------------------------------------------------------------------
      #Before set to Readonly need to check if the request user is part of SiteAdmin or Site Onwer
      $checkSiteAdmin = Get-PnPSiteCollectionAdmin | Where-Object { $_.Email -eq $siteOwners }
      if ($checkSiteAdmin) {
        #Set SiteCollection to Read-only
        Set-PnPTenantSite -Identity $siteUrl -LockState ReadOnly -Wait @Params 
        $SiteArchivelUpdated = $true
        Write-Host $siteOwners - $User.Email -BackgroundColor Blue
      }
      else {
        #Check if the request user is Site Onwer
        $getSiteOwnerGroup = Get-PnPGroup -AssociatedOwnerGroup 
        foreach ($User in $getSiteOwnerGroup.Users) {
          if ($User.Email -eq $siteOwners ) {
            #Set SiteCollection to Read-only
            Set-PnPTenantSite -Identity $siteUrl -LockState ReadOnly -Wait @Params
            $SiteArchivelUpdated = $true
          }
        }
      }
      #--------------------------------------------------------------------------------------------------------------------------  
    }
    else {
      Log-Message "Unable to perform Site Archival request due to the requested site does not exist" $logfile Error
      $createErrorList = $true
      $addScriptResponse.Add("Requested Site does not exists")
    }
    
    #----------------------------------------------------------------------------------------------------------------------------------
    #Get GUID ,URL to Update MasterList and Update Tracker List as well
    if ($SiteArchivelUpdated) {
      Connect-PnPOnline -Url $siteUrl -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
      $getProperty = Get-PnPSite -Includes Id, Url @Params
      $getSiteCollectionURL = $getProperty.Url
      $getSiteCollectionGUID = $getProperty.Id
      Log-Message "Site Archival change request has been completed successfully!!" $logfile Success
      $addScriptResponse.Add("Site Archival change request has been completed successfully SiteCollection URL : $siteUrl")
         
    }
    else {
      Log-Message "Site Archival change request has been rejected due to the requested User is not part of either Site Owner or Site Admins" $logfile Error
      $addScriptResponse.Add("Site Archival change request has been rejected due to the requested User is not part of either Site Owner or Site Admins")
      $createErrorList = $true
    }
  #----------------------------------------------------------------------------------------------------------------------------------------------
    #Update SPO Site Creation List and Error Handling
    if (!$createErrorList) {
    
      Connect-PnPOnline -Url $siteCollectionURL -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
      #Update list item -> When site is created Successfully
      $scriptAttempt++
      Set-PnPListItem -List SiteUpdateTracker -Identity $listItemIdentity -Values @{ 
        "SiteDefinition"        = $siteDefinition;
        "SiteUpdationStatus"    = "Completed";
        "RequestCompletionDate" = $todayDate;
        "SiteURL"               = $getSiteCollectionURL;
        "SiteGUID"              = $getSiteCollectionGUID;
        "ScriptAttempts"        = $scriptAttempt; 
        "ScriptResponse"        = "SPO Site Archival change request has been completed successfully"; 
        "ScriptHistory"         = $addScriptResponse
      }
      Log-Message "SPO List Item Updated Successfully" $logFile Success  
      UpdateMasterList $listItemIdentity $appID $appSecret $spoMasterListURL
    }

    else {
      Connect-PnPOnline -Url $siteCollectionURL -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
      #Update list item -> Script Attempt less then or equal 4
      if ($scriptAttempt -le "4") {
        $scriptAttempt++
        Set-PnPListItem -List SiteUpdateTracker -Identity $listItemIdentity -Values @{
          "SiteUpdationStatus" = "Error";
          "ScriptAttempts"     = $scriptAttempt;
          "ScriptResponse"     = "SPO Site Archival change request has been failed to Update";
          "ScriptHistory"      = $addScriptResponse  
        }
      }
      #Update list item -> Script Attempt equal 5 OR Site Already exists
      if ( ($scriptAttempt -eq "5") -or ($addScriptResponse -eq 'Requested Site does not exists')) {
        Set-PnPListItem -List SiteUpdateTracker -Identity $listItemIdentity -Values @{ 
          "SiteUpdationStatus" = "Rejected";
          "ScriptAttempts"     = $scriptAttempt;
          "ScriptResponse"     = "SPO Site Archival change request has been Rejected";
          "ScriptHistory"      = $addScriptResponse 
        }
            
      }
    }
    Clear-Item Variable:createErrorList
  }

  end { Log-Message "SPO Site Archival change request has been completed Successfully!!" $logfile Success }
}

#===========================================> ***End*** ========================================================================>


  







