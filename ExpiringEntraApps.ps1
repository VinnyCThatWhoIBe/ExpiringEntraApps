# Enter your information here
$clientid = ""
$tenantid = ""
$certificate = Get-Item -Path "Cert:\CurrentUser\My\..." # Replace the "..." with the thumbprint of the certificate

# Connects to Microsoft Graph
Connect-MgGraph -TenantId $tenantid -ClientId $clientid -CertificateThumbprint $certificate.Thumbprint

# Finds all Enterprise Apps
$EnterpriseApps = Get-MgServicePrincipal -All -Property AppId,createdDateTime,Displayname,id,KeyCredentials,Notes,PreferredSingleSignOnMode,ServicePrincipalType

# Finds all App Registrations
$AppRegistrations = Get-MgApplication -All -Property AppId,AppRoles,CreatedDateTime,DisplayName,Id,Notes,PasswordCredentials,KeyCredentials

# Correlates Enterprise Apps with their partner App Registration and builds the $Results array
$Results = @(
    ForEach($EnterpriseApp in $enterpriseApps){

        # Retrieves owners for Enterprise Apps
        $Owners = @(Get-MgServicePrincipalOwner -ServicePrincipalId $EnterpriseApp.Id)
        $EnterpriseOwners = $null
        $EnterpriseOwners = @(
            ForEach($Owner in $Owners){
                Try{Get-MgUser -UserId $Owner.id -ErrorAction Stop | Select-Object -ExpandProperty DisplayName} Catch {$EnterpriseApps | Where-Object Id -EQ $Owner.Id | Select-Object -ExpandProperty DisplayName}
            }
        )
        $EnterpriseOwnersCombined = $EnterpriseOwners -join ","

        # Finds the matching App Registration
        $MatchingAppRegistration = $AppRegistrations | Where-Object AppId -EQ $EnterpriseApp.AppId

        # Obtains the Owners value for the matching App Registration
        If($MatchingAppRegistration){
            $Owners = @(Get-MgApplicationOwner -ApplicationId $MatchingAppRegistration.Id)
            $AppOwners = $null
            $AppOwners = @(
                ForEach($Owner in $Owners){
                    Try{Get-MgUser -UserId $Owner.Id -ErrorAction Stop | Select-Object -ExpandProperty DisplayName} Catch {$EnterpriseApps | Where-Object Id -EQ $Owner.Id | Select-Object -ExpandProperty DisplayName}
                }
            )
            $AppOwnersCombined = $AppOwners -join ","
        } Else {$AppOwnersCombined = $null}

        # Builds the custom object to output to the $Results array
        [PSCustomObject]@{
            EnterpriseApp = $EnterpriseApp.DisplayName
            EnterpriseObjectId = $EnterpriseApp.Id
            EnterpriseApplicationId = $EnterpriseApp.AppId
            EnterpriseCreated = (Get-Date "$($EnterpriseApp.AdditionalProperties.createdDateTime)").ToString("yyyy-MM-dd")
            EnterpriseCertificateExpiration = (($EnterpriseApp | Select-Object -ExpandProperty KeyCredentials | Select-Object -ExpandProperty EndDateTime | Sort-Object | Get-Unique) | ForEach-Object {[datetime]::Parse($_)} | Sort-Object -Descending | Select-Object -First 1)
            EnterprisePreferredSingleSignOnMode = $EnterpriseApp.PreferredSingleSignOnMode
            EnterpriseServicePrincipalType = $EnterpriseApp.ServicePrincipalType
            EnterpriseOwners = $EnterpriseOwnersCombined
            EnterpriseNotes = $EnterpriseApp.Notes
            AppRegistration = $MatchingAppRegistration.DisplayName
            AppObjectId = $MatchingAppRegistration.Id
            AppApplicationId = $MatchingAppRegistration.AppId
            AppCreated = If($MatchingAppRegistration.CreatedDateTime){(Get-Date "$($MatchingAppRegistration.CreatedDateTime)").ToString("yyyy-MM-dd")}Else{$null}
            AppClientSecretExpiration = (($MatchingAppRegistration | Select-Object -ExpandProperty PasswordCredentials | Select-Object -ExpandProperty EndDateTime | Sort-Object | Get-Unique) | ForEach-Object {[datetime]::Parse($_)} | Sort-Object -Descending | Select-Object -First 1)
            AppCertificateExpiration = (($MatchingAppRegistration | Select-Object -ExpandProperty KeyCredentials | Select-Object -ExpandProperty EndDateTime | Sort-Object | Get-Unique) | ForEach-Object {[datetime]::Parse($_)} | Sort-Object -Descending | Select-Object -First 1)
            AppOwners = $AppOwnersCombined
            AppNotes = $MatchingAppRegistration.Notes
        }
    }
)

# Adds any App Registrations that don't have a corresponding Enterprise Application to the array
$Results += @(
    ForEach($AppRegistration in $AppRegistrations){
        If(($EnterpriseApps | Where-Object AppId -EQ $AppRegistration.appid) -eq $null){

            # Obtains the Owners value for the App Registration
            $Owners = @(Try{Get-MgApplicationOwner -ApplicationId $appRegistration.AppId -ErrorAction Stop}Catch{$null})
            $AppOwners = $null
            $AppOwners = @(
                ForEach($Owner in $Owners){
                    Try{Get-MgUser -UserId $Owner.Id -ErrorAction Stop | Select-Object -ExpandProperty DisplayName}Catch{$null}
                }        
            )
            $AppOwnersCombined = $AppOwners -join ","

            # Builds the custom object to export to CSV                
            [PSCustomObject]@{
                EnterpriseApp = $null
                EnterpriseObjectId = $null
                EnterpriseApplicationId = $null
                EnterpriseCreated = $null
                EnterpriseCertificateExpiration = $null
                EnterprisePreferredSingleSignOnMode = $null
                EnterpriseServicePrincipalType = $null
                EnterpriseOwners = $null
                EnterpriseNotes = $null
                AppRegistration = $AppRegistration.DisplayName
                AppObjectId = $AppRegistration.Id
                AppCreated = (Get-Date "$($AppRegistration.CreatedDateTime)").ToString("yyyy-MM-dd")
                AppApplicationId = $AppRegistration.AppId                
                AppClientSecretExpiration = (($AppRegistration | Select-Object -ExpandProperty PasswordCredentials | Select-Object -ExpandProperty EndDateTime | Sort-Object | Get-Unique) | ForEach-Object {[datetime]::Parse($_)} | Sort-Object -Descending | Select-Object -First 1)
                AppCertificateExpiration = (($AppRegistration | Select-Object -ExpandProperty KeyCredentials | Select-Object -ExpandProperty EndDateTime | Sort-Object | Get-Unique) | ForEach-Object {[datetime]::Parse($_)} | Sort-Object -Descending | Select-Object -First 1)
                AppOwners = $AppOwnersCombined
                AppNotes = $AppRegistration.Notes
            }
        }
    }
)

# Exports a CSV to the desktop 
$Results | Export-Csv -Path "$env:userprofile\desktop\ExpiringEntraApps - $(Get-Date -Format yyyyMMdd).csv" -NoTypeInformation -Force