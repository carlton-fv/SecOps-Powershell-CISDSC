function Get-RecommendationFromGPOHash {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$GPOHash,

        [Parameter(Mandatory = $true)]
        [ValidateSet('AuditPolicy','PrivilegeRight','Service','SystemAccess','Registry')]
        [string]$Type
    )

    begin {

    }

    process {
        switch($Type){
            'AuditPolicy'{
                [string]$CorrectionKey = $GPOHash['Subcategory']
                [string]$SearchString = $SearchString = "*Ensure '$($GPOHash['Subcategory'])'*'$($GPOHash['InclusionSetting'])'"
                [scriptblock]$FilterScript = {$_.title -like $SearchString}
            }

            'PrivilegeRight'{
                [string]$CorrectionKey = $GPOHash['Policy'].replace('_',' ')
                [string]$SearchString = "*'$($CorrectionKey)'*"
                [scriptblock]$FilterScript = {$_.title -like $SearchString}
            }

            'Service'{
                [string]$CorrectionKey = $GPOHash['Name']
                [string]$SearchString = "*$($GPOHash['Name'])*"
                [scriptblock]$FilterScript = {$_.title -like $SearchString -and $_.TopLevelSection -eq $script:ServiceSection}
            }

            'SystemAccess'{
                #Wildcards are used instead of spaces because CIS puts ':' in these policy names.
                [string]$CorrectionKey = $GPOHash['Name'].replace('_','*')
                [string]$SearchString = "*'$($CorrectionKey)'*"
                [scriptblock]$FilterScript = {$_.title -like $SearchString}
            }

            'Registry'{
                [string]$CorrectionKey = "$($GPOHash['Key'] -replace 'HKLM:','HKEY_LOCAL_MACHINE'):$($GPOHash['ValueName'])"
                [string]$patternString = "(?i)^($($CorrectionKey))$".replace("\","\\")
                [scriptblock]$FilterScript = {($_.AuditProcedure -split "`n") -match $patternString}
            }
        }

        if($script:StaticCorrections[$CorrectionKey]){
            $Recommendation = $script:BenchmarkRecommendations.Values |
                Where-Object -FilterScript {$_.RecommendationNum -eq $script:StaticCorrections[$CorrectionKey]}
        }
        else{
            $Recommendation = $script:BenchmarkRecommendations.Values |
                Where-Object -FilterScript $FilterScript
        }

        [int]$RecommendationCount = ($Recommendation | Measure-Object).Count

        if($RecommendationCount -eq 0){
            Write-Warning -Message "Failed to find a recommendation for $($Type) $($CorrectionKey)."
        }
        elseif($RecommendationCount -gt 1){
            Write-Warning -Message "Found multiple recommendation matches for $($Type) $($CorrectionKey)."
        }
        else{
            return $Recommendation
        }
    }

    end {

    }
}