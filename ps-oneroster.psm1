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
        
        $env:ONEROSTER_URL = "$Domain/ims/oneroster/$version"

        $p = @{ 
            uri = "$env:ONEROSTER_URL/login"
            method = "POST"
            body = @{ "clientid" = $ClientId; "clientsecret" = $ClientSecret }
        }
        $token = Invoke-RestMethod @p

        $env:ONEROSTER_TOKEN = $token 

        return $token

    }

}

<#
.SYNOPSIS
    Queries a oneroster endpoint
.EXAMPLE
    PS C:\> Get-Data -Endpoint 'classes' -All

    Gets a list of all classes
.EXAMPLE
    PS C:\> $p = @{
        Endpoint = 'users'
        Sort = 'familyName'
        Filter = "role='student'&dateLastModified>'2015-01-01'"
        Field = 'familyName,givenName'
    }
        Get-Data @p

    Gets users, sorted by familyname where their role is a student and they were last modified after 2014, showning only the familyname and givenname attributes
.OUTPUTS
    Array
#>
function Get-Data {
    
    [CmdletBinding()]
    param (

        # Target endpoint to query
        [Parameter(Mandatory = $true)]
        [string]
        $Endpoint,

        # Return all pages
        [Parameter()]
        [switch]
        $All,

        # Sort by
        [Parameter()]
        [string]
        $Sort,

        # filtering attributes: https://www.imsglobal.org/oneroster-v11-final-specification#_Toc480451997
        [Parameter()]
        [string]
        $Filter,

        # Comma seperated selection of specific fields to return
        [Parameter()]
        [string]
        $Field

    )
    
    begin {
        if (!$env:ONEROSTER_TOKEN) { throw "No token detected, please use the Connect-Oneroster command" }
    } 

    process {
        
        $url = "$env:ONEROSTER_URL/$Endpoint"

        if ($Sort) { $url += "?sort=$Sort" }
        if ($Filter) { $url += "?filter=$filter" }
        if ($Field) { $url += "?field=$Field" }

        $p = @{
            uri = $url 
            method = "GET"
            headers = @{ "authorization" = "bearer $env:ONEROSTER_TOKEN" }
            FollowRelLink = $all
        }
        $data = Invoke-RestMethod @p

        return $data

    }

}
