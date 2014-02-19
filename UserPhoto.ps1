$Loginnames = Get-ADUser -Filter * | select SamAccountName
foreach ($Login in $Loginnames){
	$Filename = './Photos/'+ $login.SamAccountName + '.jpg'
	import-recipientdataproperty -identity $login.SamAccountName -picture -filedata ([Byte[]]$(get-content -path $Filename -encoding byte -readcount 0))