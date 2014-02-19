# Written by James Kelly
# This script to populate a blank Active Directory with test accounts
# the script will read configuration settings from a config file and import the accounts that are specified in the userdata.csv file.
# this should NEVER be ran on a production environment.

# Gather the path the script is being run from.
$path = $myInvocation.mycommand.path
$scriptcontainer = Split-Path -Path $path

# Check that pscx module is imported, if not, attempt to import, if not exit script.
if(-not(Get-Module -name ActiveDirectory)) 
{ 
	if (Get-Module -ListAvailable | Where-Object {$_.name -eq "ActiveDirectory"})
		{
		Import-Module -Name ActiveDirectory
		}	
		else 
		{
		"ActiveDirectory module is not installed on this system, Script will now exit" ;exit
		}
}

# Read Configuration File
$config = [xml] ( Get-Content "$scriptcontainer\Config.xml")
$Domain = $config.AD_Populate_Config.Domain_Name
$Password = $config.AD_Populate_Config.User_Password
$Company = $config.AD_Populate_Config.Company_Name
$Connection = ($Domain.Replace(".",",DC=")).Insert(0,"DC=")

# Import CSV file
$CSV = Import-Csv "$scriptcontainer\userdata.csv"

# Gather Lists of Offices and Departments.
$OU = $CSV | Select-Object Office -Unique
$ChildOU = $CSV | Select-Object Department -Unique

# Builds SAMName
$SamName = '@'+$Domain 

# Creates a "All Staff" Group.
New-ADGroup -Path $Connection -Name 'All Staff' -GroupScope Universal -GroupCategory Distribution -Description 'All Staff email Distribution List'

# Creates Office Based OU's and Groups.
foreach($Item in $OU)
{ 
	$OfficeDesc = 'OU to store all '+ $Item.Office + ' ' + 'objects'
	$DeptOU = $CSV |where-Object {$_.Office -eq $Item.office} | select-object Department -unique
	$NewConnection = "OU=" + $item.Office + "," + $connection
	$OfficeDLName = $Item.Office + ' ' + 'All Staff'
	New-ADOrganizationalUnit -name  $Item.office -Path $connection -Description $OfficeDesc -ProtectedFromAccidentalDeletion $false
	New-ADGroup -Path $NewConnection -Name $OfficeDLName -GroupScope Universal -GroupCategory Distribution 
	Add-ADGroupMember -identity 'All Staff' -Members $OfficeDLName
	New-ADOrganizationalUnit -Name Workstations -Path $NewConnection -Description "Local Workstations" -ProtectedFromAccidentalDeletion $false
	New-ADOrganizationalUnit -Name "Local Resource Groups" -Path $NewConnection -description "Holds all localised security groups" -protectedfromaccidentaldeletion $false
# Creates Departmental OU's and Groups.	
	foreach ($Dept in $DeptOU)
	{
		$DeptOUDesc = 'Holds all accounts from the ' + $item.Office + ' ' + $Dept.Department + ' Department'
		$DeptDLName = $Item.Office + ' ' + $Dept.Department + ' ' + 'Staff'
		$DeptConnection = "OU=" + $Dept.Department + "," + $NewConnection
		$Users = $CSV |where-object {$_.Office -eq $Item.Office -and $_.Department -eq $Dept.Department}
		New-ADOrganizationalUnit -name  $Dept.Department -Path $Newconnection -description $deptoudesc -ProtectedFromAccidentalDeletion $false
		New-ADGroup -Path $DeptConnection -Name $DeptDLName -GroupScope Universal -GroupCategory Distribution
		Add-ADGroupMember -identity $OfficeDLName -Members $DeptDLName

# Creates Users and add's them to the relevant Groups.
			foreach ($User in $Users){
				$counter=0
				$name=$User.GivenName
				$LoginName= $User.GivenName.Substring(0,1)+$User.Surname
				$Fullname = $User.GivenName +' '+ $User.Surname
				$SamName2 = $LoginName + $SamName
				$find = Get-ADUser -SearchBase "$connection" -ldapfilter "(SamAccountName=$loginname)"
# Checks for duplicate usernames, if found adds an incremental value.
				while($find -ne $null){
					$counter= $counter+1
					$LoginName= $User.GivenName.Substring(0,1)+$User.Surname+$counter
					$name= $User.GivenName
					$SamName2 = $LoginName + $SamName
					$find = Get-ADUser -SearchBase "$connection" -ldapfilter "(SamAccountName=$loginname)"
					}
				New-ADUser -Name $FullName -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force)-GivenName $name -Surname $User.Surname -displayName $FullName -UserPrincipalName $SamName2 -SamAccountName $LoginName -Path $DeptConnection -Company $Company -Office $User.Office -OfficePhone $User.OfficePhone -Title $User.title -MobilePhone $User.MobilePhone -Enabled $true -PasswordNeverExpires $true -Department $User.Department
				Add-ADGroupMember -Identity $DeptDLNAme -Members $LoginName
				}
	}
}