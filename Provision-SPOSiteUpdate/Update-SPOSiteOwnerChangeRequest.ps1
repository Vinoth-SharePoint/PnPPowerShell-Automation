function  UpdateSPOSiteOwnerChangeRequest {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)] [string]$siteUrl,
        [Parameter(Mandatory = $false)] [string]$ownerToChange,
        [Parameter(Mandatory = $false)] [string]$newOwnerNameEmail,
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

        #Define Common Params
        $Params = @{
            ErrorVariable = "createErrorList"
            ErrorAction   = "SilentlyContinue"
        }

        #Check if sites Exist
        Log-Message "Begin-UpdateSPOSiteOwnerChangeRequest" $logFile Process
        $Site = Get-PnPTenantSite | Where-Object { $_.Url -eq $siteURL }
        
        #Define Site Definition
        $WebTemplateID = $Site.Template
        if ($WebTemplateID -eq "GROUP#0") { $siteDefinition = "Group Connected Team Site" }
        if ($WebTemplateID -eq "SITEPAGEPUBLISHING#0") { $siteDefinition = "Communication Site" }
        if ($WebTemplateID -eq "STS#3") { $siteDefinition = "Non-Group Connected Team Site" }
    }
  
    process {
        Log-Message "Processing UpdateSPOSiteOwnerChangeRequest -$siteUrl " $logFile Process
        if ($Site) {

            #Connect the Site Context
            Connect-PnPOnline -Url $siteUrl -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
            #-----------------------------------------------------------------------------------------------------------
            if ($ownerToChange -eq "Primary Owner") {
                #Add requested user as a Primary Admin 
                Set-PnPTenantSite -Identity $siteUrl -Owners @($newOwnerNameEmail) -Wait @Params
                  
               
                #Get Existing Primary Admin and Remove from the SiteCollection URL [To Promote new usee as a Primary Admin]
                $siteDetails = Get-PnPTenantSite -Identity $siteUrl -Detailed  #Sitedetails
                $getExistingPrimaryAdmin = Get-PnPSiteCollectionAdmin | Where-Object { $_.Email -eq $siteDetails.OwnerEmail } 
                $printEmail = $getExistingPrimaryAdmin.Email

                #If Primary Admin account is Present
                if ($getExistingPrimaryAdmin) {
                    Log-Message "Removed Old PrimaryAdmin ===>  $printEmail || Added New PrimaryAdmin:$newOwnerNameEmail"  $logFile Success
                    Remove-PnPSiteCollectionAdmin -Owners $getExistingPrimaryAdmin @Params  
                    $addScriptResponse.Add(
                        "Existing Primary Admin : Removed Existing Primary Admin:$printEmail.`n  
                         New Primary Admin:  Added New PrimaryAdmin : $newOwnerNameEmail.")
                    $SiteOwnerIsUpdated = $true
                }
                else {
                    Log-Message "Primary Account does not exist"  $logFile Error
                    $createErrorList = $true
                    $addScriptResponse.Add("There has been an error: Primary Account does not exist")
                }   

            }
            #---------------------------------------------------------------------------------------------------------------
            if ($ownerToChange -eq "Secondary Owner") {
                #Add Secondary Admin to the SiteCollection
                Set-PnPTenantSite -Identity $siteUrl -Owners @($newOwnerNameEmail) -Wait @Params
                Log-Message "Secondary Owner added Successfully!!"  $logFile Success  
                $addScriptResponse.Add("Added Secondary Admin : $newOwnerNameEmail")
                $SiteOwnerIsUpdated = $true
            }
            #----------------------------------------------------------------------------------------------------------------
             
        }
        
        else {
            Log-Message "Site $($siteUrl) does not exists !" $logFile Warning
            $createErrorList = $true
            $addScriptResponse.Add("Site does not exists")
            
        }

        #Get Request Site collection GUID and Url to Update MasterList and Site Tracker List
        if ($SiteOwnerIsUpdated) {
            $getProperty = Get-PnPSite -Includes Id, Url @Params
            $getSiteCollectionURL = $getProperty.Url
            $getSiteCollectionGUID = $getProperty.Id
                
              
        }
        #--------------------------------------------------------------------------------------------------------------      
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
                "ScriptResponse"        = "Site Owner change request has been updated Successfully"; 
                "ScriptHistory"         = $addScriptResponse
            }
            Log-Message "SPO List Item Updated Successfully" $logFile Success  
            UpdateMasterList $listItemIdentity $appID $appSecret $spoMasterListURL
        }
        #-------------------------------------------------------------------------------------------------------------- 
        else {
            Connect-PnPOnline -Url $siteCollectionURL -ClientId $appID -ClientSecret $appSecret -WarningAction Ignore
            #$addScriptResponse.add($createErrorList.Message)
            $addScriptResponse.add("There is an error while adding Owner in SPOSitecollection")
            #Update list item -> Script Attempt less then or equal 4
            if ($scriptAttempt -le "4") {
                $scriptAttempt++
                Set-PnPListItem -List SiteUpdateTracker -Identity $listItemIdentity -Values @{
                    "SiteUpdationStatus" = "Error";
                    "ScriptAttempts"     = $scriptAttempt;
                    "ScriptResponse"     = "Site Owner Change request has been failed to Update";
                    "ScriptHistory"      = $addScriptResponse  
                }
            }
            #Update list item -> Script Attempt equal 5 OR Site Already exists
            if ( ($scriptAttempt -eq "5") -or ($addScriptResponse -eq 'Site already exists')) {
                Set-PnPListItem -List SiteUpdateTracker -Identity $listItemIdentity -Values @{ 
                    "SiteUpdationStatus" = "Rejected";
                    "ScriptAttempts"     = $scriptAttempt;
                    "ScriptResponse"     = "Site Owner Change request has been Rejected";
                    "ScriptHistory"      = $addScriptResponse 
                }
                  
            }
        }
        Clear-Item Variable:createErrorList
    }
    #------------------------------------------------------------------------------------------------------------------
    end { Log-Message "SPO Site Owner Change request has been completed Successfully!!" $logfile Success }
       
}


