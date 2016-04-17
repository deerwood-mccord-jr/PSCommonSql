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
    if($FactoryDefinition) {
      #Use our own provider registry as DbProviderFactories only reads the configuration the first time it is called
      Write-Debug "Creating instance of $($FactoryDefinition.Type)" 
      New-Object $FactoryDefinition.Type
    } else {
      #Try the system registered providers
      try {
        [System.Data.Common.DbProviderFactories]::GetFactory($DbProviderName)
      } catch [System.ArgumentException] {
        throw (New-Object System.ArgumentException("Unable to find the requested .Net Framework Data Provider. Use 'Register-DbProvider' to register one."))
      }
    }
  } else {
    throw (New-Object System.ArgumentException("Unable to find the requested .Net Framework Data Provider. Use 'Register-DbProvider' to register one."))
  }
}