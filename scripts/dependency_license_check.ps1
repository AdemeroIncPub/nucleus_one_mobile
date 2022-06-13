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
    return $r.Match($pubDevHtmlContent).Value.Trim()
}

try {
    $pubspecYamlFilePaths = @('pubspec.yaml', '..\nucleus_one_dart_sdk\pubspec.yaml')

    foreach ($pubspecYamlFilePath in $pubspecYamlFilePaths) {
        $invalidPackageFound = $false
        $packageName = ''
        $depDict = GetPubDevPackages -PubspecYamlFilePath $pubspecYamlFilePath -PackageNameOut ([ref]$packageName)
        $errorMessages = "`r`nLibrary: ${packageName}"
        
        foreach ($depKvp in $depDict.GetEnumerator()) {
            $license = GetPubDevPackageLicense -PackageName $depKvp.Name
    
            # GPL and LGPL license are not to be used by our libraries for legal reasons
            if ($license.Contains('GPL')) {
                $invalidPackageFound = $true
                $errorMessages += "`r`n- Package ""$($depKvp.Name)"" uses unacceptable license ""${license}""`r`n"
            }
        }

        if ($invalidPackageFound) {
            Write-Error $errorMessages -Category InvalidResult
            Exit 1
        }
        Write-Output "Library ""${packageName}"": all *direct* dependencies verified to not use a GPL-based license"
    }

    Exit 0
}
 catch
{
    Write-Error $_
    Exit 1
}