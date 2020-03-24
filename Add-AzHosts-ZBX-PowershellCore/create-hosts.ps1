$dataatual = Get-Date -Format "ddMMyyyyHHmm"
write-host -ForegroundColor Yellow "###Instalando modulos necessarios"
Install-module Az.Accounts
Install-Module Az.Resources
write-host  -ForegroundColor Yellow  "###Adquirindo Service Principal do Azure AD - Necessario ter permissoes de leitura"
$Credential = Get-Credential
$SENHA = $Credential.Password
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SENHA)
$PLAIN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
write-host ""
write-host -ForegroundColor Yellow "###Alimentando parametros da Azure"
$ACTIVEDIRECTORYID = Read-Host "Digite o ID do Tenant/AzureAD:"
$SERVICEPRINCIPAL = $Credential.Username
$SERVICEPRINCIPALKEY = $PLAIN
$SUBSCRIPTIONID = Read-Host "Digite a Subscription ID:"
write-host ""
write-host -ForegroundColor Yellow "###Conectando na conta Azure"
$AzureConnection = Connect-AzAccount -Credential $Credential -Tenant $ACTIVEDIRECTORYID -ServicePrincipal -WarningAction SilentlyContinue
$SUB = $AzureConnection.SubscriptionName
write-host -ForegroundColor Yellow "Voce esta conectado na conta $SUB"
write-host -ForegroundColor Yellow ""
write-host -ForegroundColor Yellow "###Alimentando parametros do Zabbix"
write-host -ForegroundColor Yellow "Preencha as credenciais Zabbix"
$ZBXCREDENTIAL = Get-Credential
$USER = $ZBXCREDENTIAL.Username
$SENHAZBX = $ZBXCREDENTIAL.Password
$BSTRZBX = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SENHAZBX)
$PLAINZBX = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRZBX)
$PASS = $PLAINZBX
write-host ""
$ZBXURL = Read-Host "Digite o caminho completo de sua aplicação Zabbix"
$URL="$ZBXURL/api_jsonrpc.php"
$PREFIX0 = Read-Host "Digite o prefixo para o nome dos hosts"
$GROUPID = Read-Host "Digite o GroupID do Zabbix que deseja adicionar os hosts"
#$TEMPLATEID = Read-Host "Digite o template que deseja vincular ao host"
$TIMEGRAIN = "1"
$DNS = "{`$RESOUCENAME}.azurewebsites.net"
write-host ""
write-host -ForegroundColor Yellow "###Adquirindo Recursos"
$Resources = Get-AzResource `
|Where-Object {$_.ResourceType -eq 'Microsoft.Web/sites' -or `
$_.ResourceType -eq 'Microsoft.Cache/redis' -or `
$_.ResourceType -eq 'Microsoft.Web/serverfarms' -or `
$_.ResourceType -eq 'Microsoft.Sql/servers' -or `
$_.ResourceType -eq 'Microsoft.Sql/servers/databases' -or `
$_.ResourceType -eq 'Microsoft.Sql/servers/elasticPools' -or `
#$_.ResourceType -eq 'Microsoft.Storage/storageAccounts' -or `
$_.ResourceType -eq 'Microsoft.Web/sites' -or `
$_.ResourceType -eq 'Microsoft.Web/sites/slots' `
}
write-output $Resources | Format-table
$Resources |ConvertTo-Html >> $env:temp\addedhosts$dataatual.html
#Invoke-Item $env:temp\addedhosts$dataatual.html
write-host ""
write-host -ForegroundColor Yellow "###Criando funcoes"
Function Get-Folder($initialDirectory)

{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = "Selecione o destino dos logs"
    $foldername.rootfolder = "MyComputer"

    if($foldername.ShowDialog() -eq "OK")
    {
        $folder += $foldername.SelectedPath
    }
    return $folder
}
function autenticacao(){
    $JSON= @"
 {
 "jsonrpc": "2.0",
 "method": "user.login",
 "params":
 { "user": "$USER",
 "password": "$PASS" },
 "id": 0 }
"@
$Request = Invoke-Webrequest -Method Post -Headers @{'Content-Type' = 'application/json'} -Body $JSON -Uri $URL
($Request.Content |ConvertFrom-Json).result
}
write-host ""
write-host -ForegroundColor Yellow "Adquirindo Token do Zabbix"
$TOKEN=autenticacao
write-host ""
write-host -ForegroundColor Yellow "Os hosts serão adicionados agora"
pause

Foreach ($i in $resources) {
$RESOURCENAME = $i.Name
$RESOURCEGROUPNAME = $i.ResourceGroupName
$RESOURCETYPE = $i.ResourceType
$HOSTNAME = $RESOURCENAME
$RESOURCENAME = $RESOURCENAME -replace '/','-'
#write-output $RESOURCENAME }
#Tratando o tipo de recurso
if ($RESOURCETYPE -eq "Microsoft.Cache/redis") {$TEMPLATEID="10312"; $PREFIX="$PREFIX0-REDIS" }
if ($RESOURCETYPE -eq "Microsoft.Web/serverfarms") {$TEMPLATEID="10285"; $PREFIX="$PREFIX0-SFARM" }
if ($RESOURCETYPE -eq "Microsoft.Sql/servers") {$TEMPLATEID="10286"; $PREFIX="$PREFIX0-SQLS" }
if ($RESOURCETYPE -eq "Microsoft.Sql/servers/databases") {$TEMPLATEID="10287"; $PREFIX="$PREFIX0-DBASE" }
if ($RESOURCETYPE -eq "Microsoft.Sql/servers/elasticPools") {$TEMPLATEID="10288"; $PREFIX="$PREFIX0-EPOOL" }
#if ($RESOURCETYPE -eq "Microsoft.Storage/storageAccounts") {$TEMPLATEID="10289"; $PREFIX="$PREFIX0-STACC" }
if ($RESOURCETYPE -eq "Microsoft.Web/sites") {$TEMPLATEID="10290"; $PREFIX="$PREFIX0-WAPP" }
if ($RESOURCETYPE -eq "Microsoft.Web/sites/slots") {$TEMPLATEID="10291"; $PREFIX="$PREFIX0-WAPPS" }
$JSONCREATE= @"
{
    "jsonrpc": "2.0",
    "method": "host.create",
    "params": {
        "host": "$RESOURCENAME",
        "name": "$PREFIX-$RESOURCENAME",
        "interfaces": [
            {
                "type": 1,
                "main": 1,
                "useip": 1,
                "ip": "127.0.0.1",
                "dns": "$DNS",
                "port": "10050"
            }
        ],
        "macros": [
                {
                "macro": "{`$ACTIVEDIRECTORYID}",
                "value": "$ACTIVEDIRECTORYID"
                },{
                "macro": "{`$DNS}",
                "value": "$DNS"
                },{    
                "macro": "{`$HOSTNAME}",
                "value": "$HOSTNAME"
                },{
                "macro": "{`$RESOURCEGROUPNAME}",
                "value": "$RESOURCEGROUPNAME"
                },{
                "macro": "{`$RESOURCENAME}",
                "value": "$RESOURCENAME"
                },{
                "macro": "{`$RESOURCETYPE}",
                "value": "$RESOURCETYPE"
                },{
                "macro": "{`$SERVICEPRINCIPAL}",
                "value": "$SERVICEPRINCIPAL"
                },{
                "macro": "{`$SERVICEPRINCIPALKEY}",
                "value": "$SERVICEPRINCIPALKEY"
                },{
                "macro": "{`$SUBSCRIPTIONID}",
                "value": "$SUBSCRIPTIONID"
                },{
                "macro": "{`$TIMEGRAIN}",
                "value": "$TIMEGRAIN"
            }
        ],
        "groups": [
            {
                "groupid": "$GROUPID"
            }
        ],
        "templates": [
            {
                "templateid": "$TEMPLATEID"
            }
        ]
    
    },
    "auth": "$TOKEN",
    "id": 1
}
"@
$createdhost = Invoke-Webrequest -Method Post -Headers @{'Content-Type' = 'application/json'} -Body $JSONCREATE -Uri $URL
write-host $RESOURCENAME - $RESOURCETYPE - $createdhost.Content - $createdhost.StatusCode
write-output $RESOURCENAME - $RESOURCETYPE - $createdhost.Content - $createdhost.StatusCode >> $env:temp\addedhosts$dataatual.log
}
$caminho = Get-Folder
Move-Item -Path $env:temp\addedhosts$dataatual.log -Destination $caminho\addedhosts$dataatual.log
Move-Item -Path $env:temp\addedhosts$dataatual.html -Destination $caminho\addedhosts$dataatual.html
write-host -ForegroundColor Yellow "FIM!"
pause