function  UpdateSPOHubSiteDissAssociationRequest {
  [CmdletBinding()]
  param
  (
   
    [Parameter(Mandatory = $true)] [string]$siteUrl,
    [Parameter(Mandatory = $true)] [string]$siteUpdateRequestType,
    [Parameter(Mandatory = $false)] [string]$existingHUBsiteURL,
    [Parameter(Mandatory = $false)] [string]$siteCollectionURL,
    [Parameter(Mandatory = $true)] [string]$listItemIdentity,   
    [Parameter(Mandatory = $true)] [string]$appID, 
    [Parameter(Mandatory = $true)] [string]$appSecret,
    [Parameter(Mandatory = $false)] [int]$scriptAttempt,
    [Parameter(Mandatory = $true)] [string]$spoMasterListURL

  )
  begin {
    
    #Define Variable 
    if($null -eq $scriptAttempt){$scriptAttempt=0}
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

    #Define Site Definition
    $WebTemplateID = $Site.Template
    if ($WebTemplateID -eq "GROUP#0") { $siteDefinition = "Group Connected Team Site" }
    if ($WebTemplateID -eq "SITEPAGEPUBLISHING#0") { $siteDefinition = "Communication Site" }
    if ($WebTemplateID -eq "STS#3") { $siteDefinition = "Non-Group Connected Team Site" }

  }
  #--------------------------------------------------------------------------------------------------------------------------
  process {
    if ($Site) {
      Log-Message "Processing HubSite-$siteUrl" $logFile Process      
      if ($siteUpdateRequestType -eq "Hub Site Disassociation") {

        #Check if Hub site is already Associated
        $chkHUBSite = Get-PnPHubSite -Identity $siteUrl
        if ($chkHUBSite.SiteId) {

          #Proceed with Dissassociation if Hub site is already Associated otherwise it will skip
          Remove-PnPHubSiteAssociation -Site $siteUrl @Params
          Log-Message "Dissassociated HubSite with ExistingHubSiteURL successfully!!" $logfile Success
          $addScriptResponse.Add("Dissassociated HubSite from ExistingHubSiteURL SiteCollection URL : $siteUrl") 
          $RegisterHubsite = $true

        }

        else {
          Log-Message "Unable to Dissassociate HubSite due to the existing HUBSite Url is Invalid or may be its not HUBsite" $logfile Error
          $addScriptResponse.Add("Unable to Dissassociate HubSite due to the existing HUBSite Url is Invalid or may be its not HUBsite")
          $createErrorList = $true
        }

      }
    }
    else {
      Log-Message "Unable to Disassociate HubSite due to the requested site does not exist" $logfile Error
      $createErrorList = $true
      $addScriptResponse.Add("Requested Site does not exists")
    }

    #Get GUID ,URL to Update MasterList and Update Tracker List as well
    if ($RegisterHubsite) {
      Connect-PnPOnline -Url $siteUrl -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
      $getProperty = Get-PnPSite -Includes Id, Url @Params
      $getSiteCollectionURL = $getProperty.Url
      $getSiteCollectionGUID = $getProperty.Id
          
    }
    
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
        "ScriptResponse"        = "SPO HubSite disassociation change request has been updated Successfully"; 
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
          "ScriptResponse"     = "SPO HubSite disassociation Change request has been failed to Update";
          "ScriptHistory"      = $addScriptResponse  
        }
      }
      #Update list item -> Script Attempt equal 5 OR Site Already exists
      if ( ($scriptAttempt -eq "5") -or ($addScriptResponse -eq 'Requested Site does not exists')) {
        Set-PnPListItem -List SiteUpdateTracker -Identity $listItemIdentity -Values @{ 
          "SiteUpdationStatus" = "Rejected";
          "ScriptAttempts"     = $scriptAttempt;
          "ScriptResponse"     = "SPO HubSite disassociation Change request has been Rejected";
          "ScriptHistory"      = $addScriptResponse 
        }
            
      }
    }
    Clear-Item Variable:createErrorList
  }

  end { Log-Message "SPO HubSite disassociation Change request has been completed Successfully!!" $logfile Success }
}

#===========================================> ***End*** ========================================================================>


  







