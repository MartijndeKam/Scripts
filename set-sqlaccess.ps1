
#First determine if script needs to run. Check for SQL services if not exit

If ($Services.name -eq $SQLservice) 
{
#Install dependencies first
Add-WindowsFeature RSAT-AD-PowerShell

#region Get the username of the user who is the local administrator (SID ends with -500). 
#$childObject.Name[0] contains the local administrator username
#We could also find the adminuser like this $adminuser = $AzureRMVM.OSProfile.AdminUsername after we have put the AzureRMVM into a variable. 
#Not sure what happens when a user renames the admin account...

$computerName = $env:COMPUTERNAME

$computer = [ADSI] "WinNT://$computerName,Computer" 
    ForEach( $childObject in $computer.Children ) 
    {   
    # Skip objects that are not users.   
    if ( $childObject.Class -ne "User" ) {     continue   }   
    $type = "System.Security.Principal.SecurityIdentifier"   
    # BEGIN CALLOUT A   
    $childObjectSID = new-object $type($childObject.objectSid[0],0)   
    # END CALLOUT A   
    if ( $childObjectSID.Value.EndsWith("-500") ) {     
    "Local Administrator account name: $($childObject.Name[0])"     
    "Local Administrator account SID:  $($childObjectSID.Value)"     
    break   
        } 
    } 

$adminUser = [ADSI] "WinNT://$computerName/$($childObject.Name[0]),User"
#endregion

#region Create a random complex password and set it for the local administrator

$randomObj = New-Object System.Random

$NewPassword=""
    1..12 | ForEach { $NewPassword = $NewPassword + [char]$randomObj.next(33,126) }

$adminUser.SetPassword($NewPassword)

#endregion


#region Get the AD properties of the local computer and format the distinguised name in order to extract the AD group 
#which needs access on the local SQL server
$filter = "(name=$computername)"
$Computerproperties = Get-ADComputer -LDAPFilter $filter
$ADGroupname = $Computerproperties.DistinguishedName.Split(',')[-5].substring(3)


#Formamtting the string old 'crappy' 
# $String1 = $Computerproperties.DistinguishedName
# $string2 = $string1 -replace "............................................$"
# $string3 = $string2 -replace ".*,"
# $ADGroupName = $string3 -replace "OU="
# endregion




#region Logon to SQL with local administrator credentials

$PWord = ConvertTo-SecureString –String $newpassword –AsPlainText -Force
$User = $computername + '\' + $childObject.Name[0]
$Credential = New-Object –TypeName "System.Management.Automation.PSCredential" –ArgumentList $User, $PWord

#endregion

#region Set SQL access
$domaingroup = "sga-res-pub" + "\" + $ADGroupName
$query1 = “CREATE LOGIN [$domaingroup] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]”
$query2 = "sp_addsrvrolemember '$domaingroup', 'sysadmin'"


Invoke-Command -ArgumentList $computername,$query1 -ComputerName $computerName -Credential $Credential -ScriptBlock {Invoke-Sqlcmd -ServerInstance $args[0] -Query $args[1]}
Invoke-Command -Argumentlist $computername,$Query2 -ComputerName $computerName -Credential $Credential -ScriptBlock {Invoke-Sqlcmd -ServerInstance $args[0] -Query $args[1]}


}
else
{"geen SQL server"}



