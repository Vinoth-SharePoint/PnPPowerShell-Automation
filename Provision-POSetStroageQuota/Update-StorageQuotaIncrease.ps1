function  UpdateSPOStorageQuotaRequest {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)] [string]$siteUrl,
        [Parameter(Mandatory = $false)] [string]$siteCollectionURL,
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

        #Define Storage Quota Increase
        $StorageWarningLevelPercentage = 80
        $QuotaIncreaseforGroupConnected = 2
        $QuotaIncreaseforNonGroupConnected = 5
        $QuotaIncreaseforCommunication = 1

        #Calculate New Storage Quota
        $Site = Get-PnPTenantSite | Where-Object { $_.Url -eq $siteURL }
        $CurrentStorage = $Site.StorageQuota
        $WebTemplateID = $Site.Template
        
        #Define Common Params
        $Params = @{
            ErrorVariable = "createErrorList"
            ErrorAction   = "SilentlyContinue"
        }

    }
    Process {
        Log-Message "Processing Storage Quota Request for -$siteUrl" $logFile Process
        If ($WebTemplateID) {  
            #-Group Connected Team Site
            if ($WebTemplateID -eq "GROUP#0") {
            
                $GroupConnectedSiteStorageMaximumLevel = $CurrentStorage + ( $QuotaIncreaseforGroupConnected * 1024)   
                $GroupConnectedSiteStorageWarningLevel = ($GroupConnectedSiteStorageMaximumLevel / 100) * $StorageWarningLevelPercentage
                Set-PnPTenantSite -Url $siteUrl -StorageWarningLevel $GroupConnectedSiteStorageWarningLevel -StorageMaximumLevel $GroupConnectedSiteStorageMaximumLevel -Wait @Params
                $QuotaIsUpdated = $true
            }
         
            #-Communication Site
            if ($WebTemplateID -eq "SITEPAGEPUBLISHING#0") {
            
                $CommunicationSiteStorageMaximumLevel = $CurrentStorage + (  $QuotaIncreaseforCommunication * 1024)   
                $CommunicationSiteStorageWarningLevel = ( $CommunicationSiteStorageMaximumLevel / 100) * $StorageWarningLevelPercentage
                Set-PnPTenantSite -Url $siteUrl -StorageWarningLevel $CommunicationSiteStorageWarningLevel -StorageMaximumLevel $CommunicationSiteStorageMaximumLevel -Wait @Params
                $QuotaIsUpdated = $true
            }
            #-Non-Group Connected Team Site
            if ($WebTemplateID -eq "STS#3") {
         
                $NonGroupConnectedSiteStorageMaximumLevel = $CurrentStorage + (  $QuotaIncreaseforNonGroupConnected * 1024)   
                $NonGroupConnectedSiteStorageWarningLevel = ($NonGroupConnectedSiteStorageMaximumLevel / 100) * $StorageWarningLevelPercentage
                Set-PnPTenantSite -Url $siteUrl -StorageWarningLevel $NonGroupConnectedSiteStorageWarningLevel -StorageMaximumLevel $NonGroupConnectedSiteStorageMaximumLevel -Wait @Params
                $QuotaIsUpdated = $true
            }
        }

        else {

            Log-Message "Site $($siteUrl) does not exists !" $logFile Warning
            $createErrorList = $true
            $addScriptResponse.Add("Site does not exists")
        }
        
        if ($QuotaIsUpdated) {
            Connect-PnPOnline -Url $siteUrl -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
            $getProperty = Get-PnPSite -Includes Id, Url @Params
            $getSiteCollectionURL = $getProperty.Url
            $getSiteCollectionGUID = $getProperty.Id
            Log-Message "Storage Quota has been updated Successfully for -$siteUrl" $logFile Success
            $addScriptResponse.Add("Storage Quota has been updated Successfully!! SiteCollectionURL:$siteUrl")
        }

        #Update SPO Site Creation List and Error Handling
        if (!$createErrorList) {
    
            Connect-PnPOnline -Url $siteCollectionURL -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
            #Update list item -> When site is created Successfully
            $scriptAttempt++
            Set-PnPListItem -List SiteStorageUpdateRequests -Identity $listItemIdentity -Values @{ 
                "SiteUpdationStatus"    = "Completed";
                "RequestCompletionDate" = $todayDate;
                "SiteURL"               = $getSiteCollectionURL;
                "SiteGUID"              = $getSiteCollectionGUID;
                "ScriptAttempts"        = $scriptAttempt; 
                "ScriptResponse"        = "Storage Quota Request has been updated Successfully"; 
                "ScriptHistory"         = $addScriptResponse
            }
            Log-Message "SPO List Item Updated Successfully" $logFile Success 
            $currentStorageAllocated = "$GroupConnectedSiteStorageMaximumLevel, $CommunicationSiteStorageMaximumLevel, $NonGroupConnectedSiteStorageMaximumLevel" -split ','
            $storageAllocated = [string]$currentStorageAllocated
            UpdateMasterList $listItemIdentity $appID $appSecret $spoMasterListURL $CurrentStorage $storageAllocated
           
        }
    
        else {
            Connect-PnPOnline -Url $siteCollectionURL -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
            #Update list item -> Script Attempt less then or equal 4
            if ($scriptAttempt -le "4") {
                $scriptAttempt++
                $addScriptResponse.Add("There has been an error for updating Storage Quota Request")
                Set-PnPListItem -List SiteStorageUpdateRequests -Identity $listItemIdentity -Values @{
                    "SiteCreationStatus" = "Error";
                    "ScriptAttempts"     = $scriptAttempt;
                    "ScriptResponse"     = "Storage Quota Request has been failed to Update";
                    "ScriptHistory"      = $addScriptResponse  
                }
            }
            #Update list item -> Script Attempt equal 5 OR Site Already exists
            if ( ($scriptAttempt -eq "5") -or ($addScriptResponse -eq 'Site does not exists')) {
                Set-PnPListItem -List SiteStorageUpdateRequests -Identity $listItemIdentity -Values @{ 
                    "SiteCreationStatus" = "Rejected";
                    "ScriptAttempts"     = $scriptAttempt;
                    "ScriptResponse"     = "Storage Quota Request has been Rejected";
                    "ScriptHistory"      = $addScriptResponse 
                }
                      
            }
        }

    }
    end { Log-Message "Storage Quota set to:---$siteUrl Sucuessfully!!" $logFile Success }
} 