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

$domain = Get-ADDomain
$CSV = Import-Csv "$scriptcontainer\userdata.csv"

if($domain.Forest -ne "'LIVEDOMAIN.COM'")
{
    $password = read-host -prompt "Enter Password" -AsSecureString
    $company = read-host -prompt "Enter Company Name"
    #$Connection = ($Domain.Forest.Replace(".",",DC=")).Insert(0,"DC=")  Use $domain.distinguishedname

    #Creating Top Level OUs:
    New-ADOrganizationalUnit -name "User Accounts" -Path $domain.distinguishedname -Description "Holds all user accounts" -ProtectedFromAccidentalDeletion $false
    New-ADOrganizationalUnit -name "User Groups" -Path $domain.distinguishedname -Description "Holds all user groups" -ProtectedFromAccidentalDeletion $false
    New-ADOrganizationalUnit -name "Computer Accounts" -Path $domain.distinguishedname -Description "Holds all computer accounts" -ProtectedFromAccidentalDeletion $false
    New-ADOrganizationalUnit -name "Computer Groups" -Path $domain.distinguishedname -Description "Holds all Computer groups" -ProtectedFromAccidentalDeletion $false

    $OfficeOU = $CSV | Select-Object Office -Unique
    $DepartmentOU = $CSV | Select-Object Department -Unique

    foreach ($office in $officeOU)
    {
        #Setting top level OU path variables.
        $UserOUPath = "OU=User Accounts,"+$domain.DistinguishedName
        $ComputerOUPath = "OU=Computer Accounts,"+$domain.DistinguishedName
        $UserGroupOUPath = "OU=User Groups,"+$domain.DistinguishedName
        $computerGroupOUPath = "OU=Computer Groups,"+$domain.DistinguishedName    

        #Creating Office based OU structure
        New-ADOrganizationalUnit -name $office.office -path $UserOUPath
        New-ADOrganizationalUnit -name $office.office -path $ComputerOUPath
        New-ADOrganizationalUnit -name $office.office -path $userGroupOUPath
        New-ADOrganizationalUnit -name $office.office -path $computergroupOUPath

        #Setting top Office OU path variables.
        $DeptConnection = "OU=" + $Dept.Department + "," + $NewConnection
        $UserOfficeOUPath = "OU="+$office.office+","+$UserOUPath
        $ComputerOfficeOUPath = "OU="+$office.office+","+$ComputerOUPath
        $UserGroupOfficeOUPath = "OU="+$office.office+","+$UserGroupOUPath
        $computerGroupOfficeOUPath = "OU="+$office.office+","+$ComputergroupOUPath

        #Creating Departmental based OU structure.
        foreach ($department in $DepartmentOU)
        {
            New-ADOrganizationalUnit -name $Department.department -path $UserOfficeOUPath
            New-ADOrganizationalUnit -name $department.Department -path $ComputerOfficeOUPath
            New-ADOrganizationalUnit -name $department.Department -path $usergroupOfficeOUPath
            New-ADOrganizationalUnit -name $department.Department -path $computergroupofficeoupath

            #Creating Users
            $Users = $CSV |where-object {$_.Office -eq $office.Office -and $_.Department -eq $department.Department}

            foreach ($User in $Users)
            {
				$counter=0
				$name=$User.GivenName
				$LoginName= $User.GivenName.Substring(0,1)+$User.Surname
				$Fullname = $User.GivenName +' '+ $User.Surname
				$SamName2 = $LoginName + "@" + $domain.DNSRoot
				$find = Get-ADUser -ldapfilter "(SamAccountName=$loginname)"
# Checks for duplicate usernames, if found adds an incremental value.
				while($find -ne $null)
                {
					$counter= $counter+1
					$LoginName= $User.GivenName.Substring(0,1)+$User.Surname+$counter
					$name= $User.GivenName
                    $SamName2 = $LoginName + "@" + $domain.DNSRoot
					$find = Get-ADUser -ldapfilter "(SamAccountName=$loginname)"
				}

                $DeptConnection = "OU="+$department.department+","+$UserOfficeOUPath
				New-ADUser -Name $FullName -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force)-GivenName $name -Surname $User.Surname -displayName $FullName -UserPrincipalName $SamName2 -SamAccountName $LoginName -Path $DeptConnection -Company $Company -Office $User.Office -OfficePhone $User.OfficePhone -Title $User.title -MobilePhone $User.MobilePhone -Enabled $true -PasswordNeverExpires $true -Department $User.Department
            	$Filename = './Photos/'+ $loginname + '.jpg'
                if ((Test-Path $Filename)-eq $true)
                {
                    $photo = [Byte[]]$(get-content -path $Filename -encoding byte)
                    if (($photo.Length) -le 100KB)
                    {
                        set-aduser -identity $loginname -replace @{thumbnailphoto=$photo}
                    }
                    ELSE
                    {
                        Write-Warning "File $filename is too large.  File size must be 100Kb or less"
                    }
                }    
                ELSE
                {
                    write-warning "File $filename does not exist, skipping AD Photo Import"
                }
            }
    }
    }
}
ELSE
{
    write-host Script Terminated due to being ran on Hymans Domain.
}



