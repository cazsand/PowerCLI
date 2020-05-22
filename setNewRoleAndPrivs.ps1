$cvRole = "VM Tower Users"
$cvRolesFile = "c:\vm_toweruser_role_ids.txt"
$viServer = Read-Host -Prompt 'Entra el nombre del servidor'
Connect-VIServer -server $viServer
$cvRoleIds = @()

     Get-Content $cvRolesFile | Foreach-Object{
        $cvRoleIds += $_P
     }
     
   New-VIRole -name $cvRole -Privilege (Get-VIPrivilege -Server $viserver -id $cvRoleIds) -Server $viserver
   Set-VIRole -Role $cvRole -AddPrivilege (Get-VIPrivilege -Server $viserver -id $cvRoleIds) -Server $viserver
   
   
