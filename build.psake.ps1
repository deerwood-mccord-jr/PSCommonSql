properties {
    $currentDir = resolve-path .
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    $baseDir = $psake.build_script_dir
    $version = git.exe describe --abbrev=0 --tags
    $nugetExe = "$baseDir\vendor\tools\nuget"
    $targetBase = "tools"
}

$ModuleName = "PSCommonSql"

Task default -depends Test

Task Test {
    RequireModule "PSCommonSql.Sqlite"
    RequireModule "Pester"
    
    Push-Location $baseDir
    Import-Module Pester
    $PesterResult = Invoke-Pester -PassThru
    if($PesterResult.FailedCount -gt 0) {
      throw "$($PesterResult.FailedCount) tests failed."
    }
    Pop-Location
}

Task CopyLibraries {
  $TargetBin = "$baseDir\$ModuleName\bin"
  $TargetX64 = "$TargetBin\x64"
  $TargetX86 = "$TargetBin\x86"
  $TargetBin,$TargetX64,$TargetX86 | ForEach-Object {
    if(-not (Test-Path $_)) {
      $null = mkdir $_ -Force
    }
  }

  copy "$baseDir\vendor\packages\System.Data.SQLite.Core.*\lib\net40\*.*" "$baseDir\$ModuleName\bin\x64\"
  copy "$baseDir\vendor\packages\System.Data.SQLite.Core.*\lib\net40\*.*" "$baseDir\$ModuleName\bin\x86\"
  copy "$baseDir\vendor\packages\System.Data.SQLite.Core.*\build\net40\*" "$baseDir\$ModuleName\bin" -Force -Recurse
}

function RequireModule {
  param($Name)
  if(-not (Get-Module -List -Name $Name )) {
    Import-Module PowershellGet
    Find-Package -ForceBootstrap -Name zzzzzz -ErrorAction Ignore
    Install-Module $Name -Scope CurrentUser
    
  }  
}