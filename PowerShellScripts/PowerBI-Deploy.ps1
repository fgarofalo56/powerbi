#If your Build agent requires TLs version uncomment out the below
#[Net.servicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls1.2

#Refrance  for Power BI Managment Module:  https://github.com/Microsoft/powerbi-powershell
#Use of a service principal and an application secret:  https://docs.microsoft.com/en-us/power-bi/developer/embedded/embed-service-principal

#Install Power BI Management Module at runtime of Release Pipeline
Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -Force -Verbose

#Connect to Power BI
$tenantID = "enter tenantID"
$ServicePrincipalId = "enter SP ID"
$AppKey = "enter App Key"
$PWord = ConvertTo-SecureString -String $AppKey -AsPlainText -Force

$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ServicePrincipalId, $PWord
Connect-PowerBIServiceAccount -ServicePrincipal -Credential $Credential -Tenant $tenantID 


#Set Report Settings
$Report = "enter report Path"
$ReportName = 'enter report Name'
$WorkspaceName = 'enter workspace'

New-PowerBIReport -Path $Report -Name $ReportName -Workspace ( Get-PowerBIWorkspace -Name $WorkspaceName ) -ConflictAction "CreateOrOverwrite"