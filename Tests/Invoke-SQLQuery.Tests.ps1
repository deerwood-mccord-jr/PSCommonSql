#handle PS2
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}

$PSVersion = $PSVersionTable.PSVersion.Major

Describe "New-SQLConnection PS$PSVersion" {
    BeforeEach {
        Import-Module $here\..\PSCommonSql -Force -ErrorAction Stop -Scope Global
        Import-Module PSCommonSql.Sqlite -Force -ErrorAction Stop -Scope Global 
    }
    
    AfterEach {
        Remove-Module PSCommonSql -Force -ErrorAction Stop
    }
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should create a connection' {
            $Connection = New-SQLConnection @Verbose -ConnectionString "Data Source=:MEMORY:" -DbProviderName "System.Data.Sqlite"
            $Connection.ConnectionString | Should be "Data Source=:MEMORY:"
            $Connection.State | Should be "Open"
        }
    }
}

Describe "Invoke-SQLQuery PS$PSVersion" {
    BeforeEach {
        $SQLiteFile = "$TestDrive\Working.SQLite"
        Copy-Item $here\Names.SQLite $SQLiteFile -Force

        Import-Module $here\..\PSCommonSql -Force -Scope Global
        Import-Module PSCommonSql.Sqlite -Force -ErrorAction Stop -Scope Global
    }
    
    AfterEach {
        Remove-Module PSCommonSql -Force -ErrorAction Stop
    }
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should take file input' {
            $Out = @( Invoke-SqlQuery @Verbose -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -InputFile $here\Test.SQL )
            $Out.count | Should be 2
            $Out[1].OrderID | Should be 500
        }

        It 'should take query input' {
            $Out = @( Invoke-SQLQuery @Verbose -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -Query "PRAGMA table_info(NAMES)" -ErrorAction Stop )
            $Out.count | Should Be 4
            $Out[0].Name | SHould Be "fullname"
        }

        It 'should support parameterized queries' {
            
            $Out = @( Invoke-SQLQuery @Verbose -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -Query "SELECT * FROM NAMES WHERE BirthDate >= @Date" -SqlParameters @{
                Date = (Get-Date 3/13/2012)
            } -ErrorAction Stop )
            $Out.count | Should Be 1
            $Out[0].fullname | Should Be "Cookie Monster"

            $Out = @( Invoke-SQLQuery @Verbose -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -Query "SELECT * FROM NAMES WHERE BirthDate >= @Date" -SqlParameters @{
                Date = (Get-Date 3/15/2012)
            } -ErrorAction Stop )
            $Out.count | Should Be 0
        }

        It 'should use existing SQLConnections' {
            $Connection = New-SQLConnection @Verbose -ConnectionString "Data Source=:MEMORY:" -DbProviderName "System.Data.Sqlite"
            $Connection.ConnectionString | Should be "Data Source=:MEMORY:"
            $Connection.State | Should be "Open"
            
            Invoke-SqlQuery @Verbose -SQLConnection $Connection -Query "CREATE TABLE OrdersToNames (OrderID INT PRIMARY KEY, fullname TEXT);"
            Invoke-SqlQuery @Verbose -SQLConnection $Connection -Query "INSERT INTO OrdersToNames (OrderID, fullname) VALUES (1,'Cookie Monster');"
            @( Invoke-SqlQuery @Verbose -SQLConnection $Connection -Query "PRAGMA STATS" ) |
                Select -first 1 -ExpandProperty table |
                Should be 'OrdersToNames'

            $COnnection.State | Should Be Open

            $Connection.close()
        }

        It 'should respect PowerShell expectations for null' {
            
            #The SQL folks out there might be annoyed by this, but we want to treat DBNulls as null to allow expected PowerShell operator behavior.

            $Connection = New-SQLConnection -ConnectionString "Data Source=:MEMORY:" -DbProviderName "System.Data.Sqlite"  
            Invoke-SqlQuery @Verbose -SQLConnection $Connection -Query "CREATE TABLE OrdersToNames (OrderID INT PRIMARY KEY, fullname TEXT);"
            Invoke-SqlQuery @Verbose -SQLConnection $Connection -Query "INSERT INTO OrdersToNames (OrderID, fullname) VALUES (1,'Cookie Monster');"
            Invoke-SqlQuery @Verbose -SQLConnection $Connection -Query "INSERT INTO OrdersToNames (OrderID) VALUES (2);"

            @( Invoke-SqlQuery @Verbose -SQLConnection $Connection -Query "SELECT * FROM OrdersToNames" -As DataRow | Where{$_.fullname}).count |
                Should Be 2

            @( Invoke-SqlQuery @Verbose -SQLConnection $Connection -Query "SELECT * FROM OrdersToNames" | Where{$_.fullname} ).count |
                Should Be 1
        }
    }
}

Describe "Out-DataTable PS$PSVersion" {
    BeforeEach {
        $SQLiteFile = "$TestDrive\Working.SQLite"
        Copy-Item $here\Names.SQLite $SQLiteFile -Force

        Import-Module $here\..\PSCommonSql -Force -Scope Global
        Import-Module PSCommonSql.Sqlite -Force -ErrorAction Stop -Scope Global
    }
    
    AfterEach {
        Remove-Module PSCommonSql -Force -ErrorAction Stop
    }

    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should create a DataTable' {
            
            $DataTable = 1..1000 | %{
                New-Object -TypeName PSObject -property @{
                    fullname = "Name $_"
                    surname = "Name"
                    givenname = "$_"
                    BirthDate = (Get-Date).Adddays(-$_)
                } | Select fullname, surname, givenname, birthdate
            } | Out-DataTable @Verbose

            $DataTable.GetType().Fullname | Should Be 'System.Data.DataTable'
            @($DataTable.Rows).Count | Should Be 1000
            $Columns = $DataTable.Columns | Select -ExpandProperty ColumnName
            $Columns[0] | Should Be 'fullname'
            $Columns[3] | Should Be 'BirthDate'
            $DataTable.columns[3].datatype.fullname | Should Be 'System.DateTime'
            
        }
    }
}

Describe "Invoke-SQLBulkCopy PS$PSVersion" {
    BeforeEach {
        $SQLiteFile = "$TestDrive\Working.SQLite"
        Copy-Item $here\Names.SQLite $SQLiteFile -Force

        Import-Module $here\..\PSCommonSql -Force -Scope Global
        Import-Module PSCommonSql.Sqlite -Force -ErrorAction Stop -Scope Global
        
        $DataTable = 1..1000 | %{
            New-Object -TypeName PSObject -property @{
                fullname = "Name $_"
                surname = "Name"
                givenname = "$_"
                BirthDate = (Get-Date).Adddays(-$_)
            } | Select fullname, surname, givenname, birthdate
        } | Out-DataTable @Verbose
        
        Invoke-SQLBulkCopy @Verbose -DataTable $DataTable -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -Table Names -NotifyAfter 100 -force
    }
    
    AfterEach {
        Remove-Module PSCommonSql -Force -ErrorAction Stop
    }

    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should insert data' {
            @( Invoke-SQLQuery @Verbose -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -Query "SELECT fullname FROM NAMES WHERE surname = 'Name'" ).count | Should Be 1000
        }
        
        It "Throws by default on conflict" {
            #Try adding same data
            { Invoke-SQLBulkCopy @Verbose -DataTable $DataTable -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -Table Names -NotifyAfter 100 -force } | Should Throw
        }
        
        It "Does not change data on conflict by default" {
            #Change a known row's prop we can test to ensure it does or does not change
            $DataTable.Rows[0].surname = "Name 1"
            { Invoke-SQLBulkCopy @Verbose -DataTable $DataTable -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -Table Names -NotifyAfter 100 -force } | Should Throw

            $Result = @( Invoke-SQLQuery @Verbose -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -Query "SELECT surname FROM NAMES WHERE fullname = 'Name 1'")
            $Result[0].surname | Should Be 'Name'
        }
        
        It "Does not change data on Rollback" {
            $DataTable.Rows[0].surname = "Name 1"
            { Invoke-SQLBulkCopy @Verbose -DataTable $DataTable -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -Table Names -NotifyAfter 100 -ConflictClause Rollback -Force } | Should Throw
            
            $Result = @( Invoke-SQLQuery @Verbose -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -Query "SELECT surname FROM NAMES WHERE fullname = 'Name 1'")
            $Result[0].surname | Should Be 'Name'
        }
        
        It "Replaces data on Replace" {
            $DataTable.Rows[0].surname = "Name 1"
            Invoke-SQLBulkCopy @Verbose -DataTable $DataTable -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -Table Names -NotifyAfter 100 -ConflictClause Replace -Force

            $Result = @( Invoke-SQLQuery @Verbose -ConnectionString "Data Source=$SQLiteFile" -DbProviderName "System.Data.Sqlite" -Query "SELECT surname FROM NAMES WHERE fullname = 'Name 1'")
            $Result[0].surname | Should Be 'Name 1'
        }
    }
}
