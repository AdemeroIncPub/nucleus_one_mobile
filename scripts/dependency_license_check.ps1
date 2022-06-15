<#
.SYNOPSIS

Interogates Nucleus One Mobile projects for the license information of all dependencies.

.DESCRIPTION

Interogates Nucleus One Mobile projects for the license information of all dependencies.

By default, with no parameters, all projects are verified to not use any GPL-based open source license.


.PARAMETER List
Specifies that dependency information should be output for all projects.

.INPUTS

None. You cannot pipe objects to this script.

.OUTPUTS

If no parameters are specified, outputs whether each project is compliant.
If -List is specified, outputs dependency information for each project.

.EXAMPLE

PS> .\dependency_license_check.ps1
Library "nucleus_one_mobile": all *direct* dependencies verified to not use a GPL-based license
Library "nucleus_one_dart_sdk": all *direct* dependencies verified to not use a GPL-based license

.EXAMPLE

PS> .\dependency_license_check.ps1 -List
Library "nucleus_one_mobile":
permission_handler	MIT
get_it	MIT
...
google_sign_in	BSD-3-Clause
uuid	MIT

Library "nucleus_one_dart_sdk":
remove_from_coverage	BSD-3-Clause
http	BSD-3-Clause
...
pedantic	unknown
file	BSD-3-Clause
#>

[CmdletBinding(DefaultParameterSetName = "Default")]
Param (
    [Parameter(ParameterSetName = "List")]
    [switch]
    $List
)


Function GetPubDevPackages {
    Param(
        [string] $PubspecYamlFilePath,
        [ref]    $PackageNameOut
    )

    $pubspecYamlText = Get-Content $PubspecYamlFilePath -Raw
    
    # Match just the contents of the "dependencies:" section
    [regex]$r = '(?<=[\r\n]dependencies:[\r\n]+\s+flutter:[\r\n]+\s+sdk: flutter[\r\n]+)(.|[\r\n])+?(?=[\r\n]\w+:)'
    $dependenciesMatch = $r.Match($pubspecYamlText)
    # Only select uncommented rows with version numbers
    [regex]$r = '(?<=^|[\r\n]  )(\w+)(?:: +?)([\d.^+]+)'

    # Put the package entries into a hash table
    $depDict = @{}
    foreach ($dep in $r.Matches($pubspecYamlText)) {
        $depDict.Add($dep.Groups[1].Value, $dep.Groups[2].Value)
    }

    [regex]$r = '(?<=(^|[\r\n])name: *)\w+(?=$|[\r\n])'
    $PackageNameOut.Value = $r.Match($pubspecYamlText).Value

    return $depDict
}

Function GetPubDevPackageLicense {
    Param($PackageName)

    # Since the pub.dev API doesn't include license info, it has to be obtained from the raw HTML

    $webClient = New-Object Net.WebClient
    $pubDevHtmlContent = $webClient.DownloadString('https://pub.dev/packages/' + $PackageName)
    
    # PowerShell doesn't provide an on-the-rails way to parse HTML, so use regex to "parse" it
    [regex]$r = '(?<=<h3 class="title">License</h3><p\b(.|[\r\n])+?/>)(.+?)(?=\(.+?LICENSE\b)'
    $license = $r.Match($pubDevHtmlContent).Value.Trim()

    # Sometimes, pub.dev doesn't have license info.  In that case, get it from GitHub
    if ($license -eq 'unknown') {
        $licenseFromGitHub = GetGitHubRepoLicenseViaPubDev -PackageName $PackageName
        if ($licenseFromGitHub -ne $null) {
            $license = $licenseFromGitHub
        }
    }
    return $license
}

Function GetGitHubRepoLicenseViaPubDev {
    Param($PackageName)

    # Since the pub.dev API doesn't include license info, it has to be obtained from the raw HTML

    $webClient = New-Object Net.WebClient
    $pubDevHtmlContent = $webClient.DownloadString('https://pub.dev/packages/' + $PackageName)
    
    # PowerShell doesn't provide an on-the-rails way to parse HTML, so use regex to "parse" it
    [regex]$r = '(?:<h3 [^>]+>Metadata.+?<a\b.+?href=")([^"]+)(?:.+?Repository \(GitHub\))'
    $match = $r.Match($pubDevHtmlContent)
    
    if ($match.Success) {
        return GetGitHubRepoLicense $match.Groups[1].Value.Trim()
    } else {
        return $null
    }
}

Function GetGitHubRepoLicense {
    Param($RepoUrl)

    $repoUrlParts = $RepoUrl.Split('/')
    $repoOwner = $repoUrlParts[3]
    $repoName = $repoUrlParts[4]
    
    # Use the GitHub API to get the license info for this package
    $jsonDataRaw = Invoke-WebRequest -Uri "https://api.github.com/repos/${repoOwner}/${repoName}"
    $jsonData = ConvertFrom-Json $jsonDataRaw.content

    if ($jsonData.license -eq $null) {
        return $null;
    }
    return $jsonData.license.name
}

Function List {
    Default -OutputList $true
}

Function Default {
    Param (
        [bool]$OutputList = $false
    )

    try {
        $pubspecYamlFilePaths = @('pubspec.yaml', '..\nucleus_one_dart_sdk\pubspec.yaml')

        foreach ($pubspecYamlFilePath in $pubspecYamlFilePaths) {
            $invalidPackageFound = $false
            $packageName = ''
            $depDict = GetPubDevPackages -PubspecYamlFilePath $pubspecYamlFilePath -PackageNameOut ([ref]$packageName)
            $errorMessages = "`r`nLibrary: ${packageName}"
            
            if ($OutputList -eq $true) {
                Write-Output "Library ""${packageName}"":"
            }
            
            foreach ($depKvp in $depDict.GetEnumerator()) {
                $license = GetPubDevPackageLicense -PackageName $depKvp.Name
    
                # GPL and LGPL license are not to be used by our libraries for legal reasons
                if ($license.Contains('GPL')) {
                    $invalidPackageFound = $true
                    $errorMessages += "`r`n- Package ""$($depKvp.Name)"" uses unacceptable license ""${license}""`r`n"
                }
                
                if ($OutputList -eq $true) {
                    Write-Output "$($depKvp.Name)	${license}"
                }
            }

            if ($invalidPackageFound) {
                Write-Error $errorMessages -Category InvalidResult
                Exit 1
            }

            if ($OutputList -eq $false) {
                Write-Output "Library ""${packageName}"": all *direct* dependencies verified to not use a GPL-based license"
            }
        }

        Exit 0
    }
     catch
    {
        Write-Error $_
        Exit 1
    }
}

if ($PSCmdlet.ParameterSetName) {
    & (Get-ChildItem "Function:$($PSCmdlet.ParameterSetName)")
    exit
}