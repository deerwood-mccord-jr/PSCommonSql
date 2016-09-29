function Get-DbProviderFactory {
  [CmdletBinding()]
  [OutputType([System.Data.Common.DbProviderFactory])]
  param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $DbProviderName
  )
  if($Script:DbProviderFactories) {
    $FactoryDefinition = $Script:DbProviderFactories[$DbProviderName]
  } else {
    $FactoryDefinition = $null
  }
  if($FactoryDefinition) {
    #Use our own provider registry as DbProviderFactories only reads the configuration the first time it is called
    Write-Debug "Creating instance of $($FactoryDefinition.Type)"
    try {
      New-Object $FactoryDefinition.Type
    } catch {
      try {
        $Type = [Type]$FactoryDefinition.Type
        $Type::Instance
      } catch {
        throw (New-Object System.ArgumentException("Unable to create an instance of the requested type ($($FactoryDefinition.Type))"))
      }
    }
  } else {
    #Try the system registered providers
    try {
      [System.Data.Common.DbProviderFactories]::GetFactory($DbProviderName)
    } catch [System.ArgumentException] {
      throw (New-Object System.ArgumentException("Unable to find the requested .Net Framework Data Provider. Use 'Register-DbProvider' to register one."))
    }
  }
}
