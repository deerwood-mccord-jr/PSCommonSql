function Register-DbProvider {
  param(
    $DbProviderFactory
  )
  if(-not $Script:DbProviderFactories) {
    $Script:DbProviderFactories = @{}
  }
  
  $Script:DbProviderFactories[$DbProviderFactory.Invariant] = $DbProviderFactory  
}