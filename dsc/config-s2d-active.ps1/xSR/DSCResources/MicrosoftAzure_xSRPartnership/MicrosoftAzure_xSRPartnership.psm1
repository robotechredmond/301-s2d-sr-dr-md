#
# xSRPartnership: DSC resource to configure a Storage Replica partnership. 
#

function Get-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [string] $ClusterName,

        [parameter(Mandatory)]
        [string] $RemoteClusterName,

        [parameter(Mandatory)]
        [string] $ReplicationMode,

        [parameter(Mandatory)]
        [uint32] $AsyncRPO,

        [parameter(Mandatory)]
        [PSCredential] $DomainAdministratorCredential
    )
  
    try
    {
        ($oldToken, $context, $newToken) = ImpersonateAs -cred $DomainAdministratorCredential
        $retvalue = @{Ensure = if (((Get-SRGroup -ErrorAction SilentlyContinue).Replicas).DataVolume -eq ((Get-ClusterSharedVolume)[0].SharedVolumeInfo).FriendlyVolumeName) {'Present'} Else {'Absent'}}
    }
    finally
    {
        if ($context)
        {
            $context.Undo()
            $context.Dispose()
            CloseUserToken($newToken)
        }
    }

    $retvalue
}

function Set-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [string] $ClusterName,

        [parameter(Mandatory)]
        [string] $RemoteClusterName,

        [parameter(Mandatory)]
        [string] $ReplicationMode,

        [parameter(Mandatory)]
        [int] $AsyncRPO,

        [parameter(Mandatory)]
        [PSCredential] $DomainAdministratorCredential
    )
 
    try
    {
        ($oldToken, $context, $newToken) = ImpersonateAs -cred $DomainAdministratorCredential
        New-SRPartnership -SourceComputerName $ClusterName -SourceRGName $ClusterName -SourceVolumeName C:\ClusterStorage\Volume1 -SourceLogVolumeName F: -DestinationComputerName $RemoteClusterName -DestinationRGName $RemoteClusterName -DestinationVolumeName C:\ClusterStorage\Volume1 -DestinationLogVolumeName F: -LogSizeInBytes ( (Get-Volume -DriveLetter F).SizeRemaining - 1GB ) -ReplicationMode $ReplicationMode -Seeded -AsyncRPO $AsyncRPO
    }
    finally
    {
        if ($context)
        {
            $context.Undo()
            $context.Dispose()
            CloseUserToken($newToken)
        }
    }

}

function Test-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [string] $ClusterName,

        [parameter(Mandatory)]
        [string] $RemoteClusterName,

        [parameter(Mandatory)]
        [string] $ReplicationMode,

        [parameter(Mandatory)]
        [int] $AsyncRPO,

        [parameter(Mandatory)]
        [PSCredential] $DomainAdministratorCredential
    )

    try
    {
        ($oldToken, $context, $newToken) = ImpersonateAs -cred $DomainAdministratorCredential
        $retvalue = (((Get-SRGroup -ErrorAction SilentlyContinue).Replicas).DataVolume -eq ((Get-ClusterSharedVolume)[0].SharedVolumeInfo).FriendlyVolumeName)
    }
    finally
    {
        if ($context)
        {
            $context.Undo()
            $context.Dispose()
            CloseUserToken($newToken)
        }
    }

    $retvalue
    
}

function Get-ImpersonateLib
{
    if ($script:ImpersonateLib)
    {
        return $script:ImpersonateLib
    }

    $sig = @'
[DllImport("advapi32.dll", SetLastError = true)]
public static extern bool LogonUser(string lpszUsername, string lpszDomain, string lpszPassword, int dwLogonType, int dwLogonProvider, ref IntPtr phToken);

[DllImport("kernel32.dll")]
public static extern Boolean CloseHandle(IntPtr hObject);
'@
   $script:ImpersonateLib = Add-Type -PassThru -Namespace 'Lib.Impersonation' -Name ImpersonationLib -MemberDefinition $sig

   return $script:ImpersonateLib
}

function ImpersonateAs([PSCredential] $cred)
{
    [IntPtr] $userToken = [Security.Principal.WindowsIdentity]::GetCurrent().Token
    $userToken
    $ImpersonateLib = Get-ImpersonateLib

    $bLogin = $ImpersonateLib::LogonUser($cred.GetNetworkCredential().UserName, $cred.GetNetworkCredential().Domain, $cred.GetNetworkCredential().Password, 
    9, 0, [ref]$userToken)

    if ($bLogin)
    {
        $Identity = New-Object Security.Principal.WindowsIdentity $userToken
        $context = $Identity.Impersonate()
    }
    else
    {
        throw "Can't log on as user '$($cred.GetNetworkCredential().UserName)'."
    }
    $context, $userToken
}

function CloseUserToken([IntPtr] $token)
{
    $ImpersonateLib = Get-ImpersonateLib

    $bLogin = $ImpersonateLib::CloseHandle($token)
    if (!$bLogin)
    {
        throw "Can't close token."
    }
}

Export-ModuleMember -Function *-TargetResource
