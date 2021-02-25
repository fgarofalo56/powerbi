#If your Build agent requires TLs version uncomment out the below
#[Net.servicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls1.2


#Params passed in from DevOps
#Set Report Settings and datasource params
param (
   $userName, 
   $userPassword,
   $Report,
   $ReportName,
   $WorkspaceName,
   $dataSourceUserName,
   $dataSourcePassword,
   $sqlSrv,
   $dbName,
   $newSqlSrv,
   $newDBName
)

#This script uses an AAD user that has access to the workspace.  The API that is required to update creds does not support running as an app and needs to be run in the context of a user
#Example uses a Power BI web only account with needs to have an active Power BI lic and the coorrect permisons to each group/workspace.  
#Install Azure PowerShell Version 5.4.0
Install-Module -Name Az -RequiredVersion 5.4.0 -Scope CurrentUser -AllowClobber -Force -Verbose

#Import Az Version 5.4.0
Import-Module -Name Az -RequiredVersion 5.4.0


# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
#Connect to Azure with Web-Only Account Requires a Power BI Lic to work
Connect-AzAccount -Credential $credObject
#Get Token with Web-Only Account 
$resource = "https://analysis.windows.net/powerbi/api"
$token = Get-AzAccessToken -Resource $resource 
$bearer = $token.Token


#Set Datasource Settings
#Get Workspace Information
$contentType = "application/x-www-form-urlencoded"
$uri = "https://api.powerbi.com/v1.0/myorg/groups?`$filter=(name eq '$WorkspaceName')"
$parms = @{
    ContentType = $contentType
    Headers     = @{'Content-Type' = $contentType; 'Authorization' = "Bearer $($bearer)" }
    Method      = 'Get'
    URI         = $uri
}
$results = Invoke-WebRequest @parms 
$fr = ($results.Content | ConvertFrom-Json).value
$workspaceID = $fr.id
Write-Host "Workspace ID: $workspacId"


#Get Report
$uri = "https://api.powerbi.com/v1.0/myorg/groups/$workspaceID/reports?`$filter=(name eq '$reportName')"
$parms = @{
    ContentType = $contentType
    Headers     = @{'Content-Type' = $contentType; 'Authorization' = "Bearer $($bearer)" }
    Method      = 'Get'
    URI         = $uri
}
$results = Invoke-WebRequest @parms 
$report = ($results.Content | ConvertFrom-Json).value
$reportId = $report.id
Write-Host "Report Info:  $report"
Write-Host "Report ID to udpate: $reportId"
$datasetId = $report.datasetId
Write-Host "Dataset to update: $datasetId"


#Take Over In Group
Write-Host "Taking over Dataset so that the Data source Settings can be updated"
$contentType = "application/json"     
$uri = "https://api.powerbi.com/v1.0/myorg/groups/$workspaceID/datasets/$datasetId/Default.TakeOver"
$parms = @{
    ContentType = $contentType
    Headers     = @{'Content-Type' = $contentType; 'Authorization' = "Bearer $($bearer)" }
    Method      = 'POST'
    Body        = $body
    URI         = $uri
    Verbose     = $true
}
$results = Invoke-WebRequest @parms 
Write-Host "Dataset take over results: $results"

#Get Datasource and gateway id
Write-Host "Get Datasource gateway id which will be used to update creds for datasource"
$uri = "https://api.powerbi.com/v1.0/myorg/datasets/$datasetId/Default.GetBoundGatewayDataSources"
$parms = @{
    ContentType = $contentType
    Headers     = @{'Content-Type' = $contentType; 'Authorization' = "Bearer $($bearer)" }
    Method      = 'Get'
    URI         = $uri
}
$results = Invoke-WebRequest @parms 

$datasourceId = ($results.Content | ConvertFrom-Json).value.id
$gatewayId = ($results.Content | ConvertFrom-Json).value.gatewayId
Write-Host "Datasource Id to be updated: $datasourceId on GatewayId: $gatewayId"


#Update Datasource connection this example is for Azure SQL DB refrance the API docs to change for a different data source
#Update Data Source:  https://docs.microsoft.com/en-us/rest/api/power-bi/datasets/updatedatasourcesingroup

Write-Host "Update Datasource connection settings"
$contentType = "application/json"     
$uri = "https://api.powerbi.com/v1.0/myorg/groups/$workspaceID/datasets/$datasetId/Default.UpdateDatasources"
$body = @"
{
    "updateDetails": [
        {
            "datasourceSelector": {
                "datasourceType": "Sql",
                "connectionDetails": {
                    "server": "$sqlSrv",
                    "database": "$dbName"
                }
            },
            "connectionDetails": {
                "server": "$newSqlSrv",
                "database": "$newDBName"  
            }
        }
    ]
}
"@
$parms = @{
    ContentType = $contentType
    Headers     = @{'Content-Type' = $contentType; 'Authorization' = "Bearer $($bearer)" }
    Method      = 'POST'
    Body        = $body
    URI         = $uri
    Verbose     = $true
}
$results = Invoke-WebRequest @parms 
Write-Host "Results from updating data source connection: $results)"



#Update DataSet Creds  see: https://docs.microsoft.com/en-us/rest/api/power-bi/gateways/updatedatasource#examples
#Example uses SQL Auth for Creds see the above docs to use differet auth/cred types
Write-Host "Update DataSet creds"
$contentType = "application/json"
$uri = "https://api.powerbi.com/v1.0/myorg/gateways/$gatewayId/datasources/$datasourceId"
$body = @"
{
    "credentialDetails": {
        "credentialType": "Basic",
        "credentials": "{\"credentialData\":[{\"name\":\"username\",\"value\":\"$dataSourceUserName\"},{\"name\":\"password\",\"value\":\"$dataSourcePassword\"}]}",
        "encryptedConnection": "Encrypted",
        "encryptionAlgorithm": "None",
        "privacyLevel": "None"        
    }
}
"@
$parms = @{
    ContentType = $contentType
    Headers     = @{'Content-Type' = $contentType; 'Authorization' = "Bearer $($bearer)" }
    Method      = 'PATCH'
    Body        = $body
    URI         = $uri
    Verbose     = $true
}
$results = Invoke-WebRequest @parms 
Write-Host "Creds updated for datasource: $datasourceId Update Results: $results"


#Refresh Dataset after creds updated
#Refresh DataSet
$contentType = "application/json"     
$uri = "https://api.powerbi.com/v1.0/myorg/groups/$workspaceID/datasets/$datasetId/refreshes"
$parms = @{
    ContentType = $contentType
    Headers     = @{'Content-Type' = $contentType; 'Authorization' = "Bearer $($bearer)" }
    Method      = 'POST'
    Body        = $body
    URI         = $uri
    Verbose     = $true
}
$results = Invoke-WebRequest @parms 
Write-Host "Dataset: $datasetId refresh request $results"
