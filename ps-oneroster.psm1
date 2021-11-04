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
        [Parameter(Mandatory)]
        [string]
        $Domain,

        # Version of the API to call
        [Parameter()]
        [string]
        $Version = "v1p1",

        # The login username or id 
        [Parameter(Mandatory)]
        [string]
        $ClientID,

        # The login secret or password
        [Parameter(Mandatory)]
        [string]
        $ClientSecret,

        # The login endpoint of your oneroster server
        [Parameter()]
        [string]
        $LoginEndpoint,

        # The oneroster scope access required as a space seperated string
        [Parameter()]
        [string]
        $Scope = "roster-core.readonly",

        # The oneroster login server implementation
        [Parameter()]
        [ValidateSet("go-oneroster","libre-oneroster")]
        $Provider = "go-oneroster"
    )

    process { 
        
        $env:ONEROSTER_URL = "$Domain/ims/oneroster/$version"

        if ($provider -eq "go-oneroster") {
            if ('' -eq $LoginEndpoint) { $LoginEndpoint = "login" }
            $p = @{
                uri = "$env:ONEROSTER_URL/$LoginEndpoint"
                method = "POST"
                body = @{ "clientid" = $ClientId; "clientsecret" = $ClientSecret}
            }
            $token = Invoke-RestMethod @p
        }

        if ($provider -eq "libre-oneroster") {
            if ('' -eq $LoginEndpoint) { $LoginEndpoint = "auth/login" }
            $p = @{
                uri = "$Domain/$LoginEndpoint"
                method = "POST"
                body = @{ "client_id" = $ClientId; "client_secret" = $ClientSecret; "scope" = $scope}
            }
            $token = (Invoke-RestMethod @p).access_token
        }

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
        $Fields

    )
    
    begin {
        if (!$env:ONEROSTER_TOKEN) { throw "No token detected, please use the Connect-Oneroster command" }
    } 

    process {
        
        $url = "$env:ONEROSTER_URL/$Endpoint" + "?"

        if ($Filter) { $url += "&filter=$filter" }
        if ($Fields) { $url += "&fields=$Fields" }
        if ($Sort) { $url += "&sort=$Sort" }

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

<#
.SYNOPSIS
    Uses sql style joins to join classes to enrollments and courses to those classes
.EXAMPLE
    PS C:\> Get-EnrollmentsJoined
.OUTPUTS
    PSCustomObject[]
#>
function Get-EnrollmentsJoined {

    [CmdletBinding()]

    $enrollments = Get-ORData -endpoint 'enrollments' -all 
    $classes = Get-ORData -endpoint 'classes' -all
    $courses = Get-ORData -endpoint 'courses' -all

    $e = $enrollments.enrollments |
    select-object *,
    @{ n = 'userSourcedId'; e = { $_.user.sourcedId } },
    @{ n = 'classSourcedId'; e = { $_.class.sourcedId } }

    $s = $classes.classes |
        Select-Object *,
        @{ n = 'courseSourcedId'; e = { $_.course.sourcedId } }

    $c = $courses.courses 

    $jscP = @{
        left = $s
        right = $c
        leftJoinProperty = "courseSourcedId"
        rightJoinProperty = "sourcedId"
        Prefix = "course_"
    }
    
    $jsc = Join-Object @jscP

    $jejscP = @{
        left = $e
        right = $jsc
        leftJoinProperty = "classSourcedId"
        RightJoinProperty = "sourcedId"
        Prefix = "class_"

    }
    $jejesc = join-object @jejscP

    $output = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($i in $jejesc) { 

        $o = [PSCustomObject]@{
            sourcedId = $i.sourcedId
            class = [PSCustomObject]@{ 
                sourcedId = $i.classSourcedId
                code = $i.class_classCode
                type = $i.class_classType
                course = [PSCustomObject]@{
                    sourcedId = $i.class_courseSourcedId
                    code = $i.class_course_courseCode
                    dateLastModified = $i.class_course_dateLastModified
                    org = $i.class_course_org
                    status = $i.class_course_status
                    subjects = $i.class_course_subjects
                    title = $i.class_course_title
                }
                dateLastModified = $i.class_dateLastModified
                grades = $i.class_grades
                school = $i.class_school
                status = $i.class_status
                subjects = $i.class_subjects
                terms = $i.class_terms
                title = $i.class_title
            }
            dateLastModified = $i.dateLastModified
            role = $i.role
            school = $i.school
            status = $i.status
            user = [PSCustomObject]@{ sourcedId = $i.userSourcedId }
            
        }
        $output.add($o)
            
    }

    return $output
    
}

<#
.SYNOPSIS
    Prints a reference table of Grades/Years across various schooling systems.
.EXAMPLE
    PS C:\> ConvertFrom-K12 -K12 "KG"
    Searches and returns the equivilant schooling system grades of K12's kindergarten
.OUTPUTS
    String
#>
function ConvertFrom-K12 {
    [CmdletBinding(DefaultParameterSetName = 'k12')]
    param (
        # A K12 grade to be converted
        [Parameter(Mandatory = $true,
        Position = 0,
        ParameterSetName = 'k12')]
        [string]
        $K12,

        # A table index to reference
        [Parameter(Mandatory = $true,
        ParameterSetName = 'index')]
        [int]
        $Index,

        # Print all options
        [Parameter(Mandatory = $true,
        ParameterSetName = 'print')]
        [switch]
        $All,

        # Gets the leaving year of the student
        [Parameter(ParameterSetName = 'k12')]
        [Parameter(ParameterSetName ='index')]
        [switch]
        $ClassOf
    )

    begin {
        $table = @(
            [pscustomobject]@{ "INDEX" = 0; "CEDS" = "IT"; "SCO" = ""; "ENG" = ""; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 1; "CEDS" = "PR"; "SCO" = "" ; "ENG" = ""; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 2; "CEDS" = "PK"; "SCO" = "N"; "ENG" = ""; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 3; "CEDS" = "TK"; "SCO" = "KN"; "ENG" = "Reception"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 4; "CEDS" = "KG"; "SCO" = "P1"; "ENG" = "1"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 5; "CEDS" = "01"; "SCO" = "P2"; "ENG" = "2"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 6; "CEDS" = "02"; "SCO" = "P3"; "ENG" = "3"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 7; "CEDS" = "03"; "SCO" = "P4"; "ENG" = "4"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 8; "CEDS" = "04"; "SCO" = "P5"; "ENG" = "5"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 9; "CEDS" = "05"; "SCO" = "P6"; "ENG" = "6"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 10; "CEDS" = "06"; "SCO" = "P7"; "ENG" = "7"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 11; "CEDS" = "07"; "SCO" = "S1"; "ENG" = "8"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 12; "CEDS" = "08"; "SCO" = "S2"; "ENG" = "9"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 13; "CEDS" = "09"; "SCO" = "S3"; "ENG" = "10"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 14; "CEDS" = "10"; "SCO" = "S4"; "ENG" = "11"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 15; "CEDS" = "11"; "SCO" = "S5"; "ENG" = "12"; "ClassOf" = $null; }
            [pscustomobject]@{ "INDEX" = 16; "CEDS" = "12"; "SCO" = "S6"; "ENG" = "13"; "ClassOf" = $null; }
        )
    }

    process {
        if ($K12) {
            $result = $table | where-object CEDS -eq $k12
        }

        if ($index) {
            $result = $table | where-object index -eq $index
        }

        if ($all) {
            $result = $table
        }

        if ($ClassOf) {
            $month = get-date -f MM
            $schoolyear = if ($month -lt "07") { get-date (get-date).AddYears(-1) -f yy }
                else { get-date -f yy }
            $leaving = 18 - ($result.index + 1) + $schoolyear
            $result.ClassOf = $leaving
        }
        return $result
    }
}
