<#  Versioning Methodology: X(X).Y(Y).Z(Z)(a)
    X(X): Major
        - 1 - 2 digits (1-99), Incremented by 1
        - Changes that may impact decommission or modify the return values of APIs used by other addons.
        - No APIs currently are exposed for reliable use by other addons.
    Y(Y): Minor
        - 1 - 2 digits (1-99), Incremented by 1
        - Modifications or Additions to
            - UI Elements
            - Features
    Z(Z): Patch
        - 1 - 2 digits (1-99), Increment amount may vary.
        - Increment amount may very but will normally be 1.
        - Bug Fixes
        - Minor Code Refactoring
    a: Alterate Releases
        - 1 alpha (lowercase), b or p.
        - Optional identifier used for pathes not yet live.
        - Identifiers
            - p: PTR
            - b: BETA
 #>
$addonDir = ".\addon\$Env:addonName"
$tag = $Env:ReleaseTag
if (($Env:GitHubRelease -eq "true")) {
    if ($tag -eq $null) {
        Write-Error -Message "No tag specified in $Env:ReleaseTag" -ErrorId "noEnvTag"
        Throw
    } else {
        $tagCheck = git ls-remote --tags | grep -Pattern $tag
        if ($tagCheck -ne $null) {
            Write-Error -Message "Tag $tag already used" -ErrorId "dupEnvTag"
            Throw
        }
    }
} else {
    $tag = $Env:ReleaseTag
}
mkdir $addonDir -Force | Out-Null
mkdir "$addonDir\locale" -Force | Out-Null
cd "$addonDir\"  | Out-Null
Copy-Item -Path "..\..\*" -Include *.lua, *.xml, *.toc -Destination ".\" | Out-Null
Copy-Item -Path "..\..\locale\*" -Include *.lua -Destination ".\locale\" | Out-Null
Copy-Item -Path "..\..\libs" ".\libs" -Recurse | Out-Null
Compress-Archive ".\" "..\..\release\LFM+_$tag.zip" -Force | Out-Null
$zipInfo = (Get-Item "..\..\release\LFM+_$tag.zip" | Select FullName).FullName
Write-Information -Message "Created: $zipInfo" -InformationAction Continue
if ($Env:GitHubRelease -eq "true" ) {
    gh release create "$tag" --notes-file .\RELEASE.MD .\release\LFM+_"$tag".zip | Out-Null
    Write-Information -Message "Release: $tag created on GitHub" -InformationAction Continue
} else {
    Write-Information -Message "Release: $tag NOT created on GitHub" -InformationAction Continue
}
cd "..\..\" | Out-Null
rm ".\addon\" -r -fo | Out-Null