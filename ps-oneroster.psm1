<#
.SYNOPSIS
    Connects to a oneroster api and sets an environment variable with the API token 
.EXAMPLE
    PS C:\> Connect-Oneroster -Domain 'www.myserver.com' -ClientId 'abcedf' -ClientSecret 'superSecret'
    Gets an API token from the oneroster server at www.myserver.com/ims/oneroster/v1p1
.OUTPUTS
    API token [string]
#>
function Connect-Oneroster {

    [CmdletBinding()]
    param (

        # The prefix to your /ims/oneroster url path
        [Parameter(Mandatory = $true)]
        [string]
        $Domain,

        # Version of the API to call
        [Parameter()]
        [string]
        $Version = "v1p1",

        # The login username or id 
        [Parameter(Mandatory = $true)]
        [string]
        $ClientID,

        # The login secret or password
        [Parameter(Mandatory = $true)]
        [string]
        $ClientSecret
    )

    process { 
        
        $p = @{ 
            uri = "$Domain/ims/oneroster/$version/login"
            method = "POST"
            body = @{ "clientid" = $ClientId; "clientsecret" = $ClientSecret }
        }
        $token = Invoke-RestMethod @p

        $env:ONEROSTER_TOKEN = $token 

        return $token

    }

}
