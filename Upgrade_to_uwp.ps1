# Andy Wigley
# andy.wigley@microsoft.com
# 31 July 2015 Updated for 10.0.10240.0 release

# Get the version number of UAP (selects last subfolder)
$FolderPath = "C:\Program Files (x86)\Windows Kits\10\Platforms\UAP"
$UAPVersionNumber = Get-ChildItem -Path $FolderPath | Select-Object -Last 1 -ExpandProperty Name

# Find the csproj file
$FilePath   = Get-ChildItem -Path "." | Where-Object {$_.Extension -eq ".csproj"} | Select-Object -First 1
ECHO "Converting $FilePath..."
# Note Get-Content returns file contents as an array of strings
$FileContents = Get-Content -Path $FilePath
$FileContents = $FileContents | ForEach-Object {$_ -replace '<ProjectTypeGuids>.*</ProjectTypeGuids>', "<ProjectTypeGuids>{A5A43C5B-DE2A-4C0C-9213-0A381AF9435A};{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}</ProjectTypeGuids>"}
$FileContents = $FileContents | ForEach-Object {$_ -replace ';WINDOWS_APP', ';WINDOWS_UWP'}
$FileContents = $FileContents | ForEach-Object {$_ -replace ';WINDOWS_PHONE_APP', ';WINDOWS_UWP'}
$FileContents = $FileContents | ForEach-Object {$_ -replace '12.0', '14.0'}
$FileContents = $FileContents | ForEach-Object {$_ -replace '<Import Project="\$\(MSBuildExtensionsPath.*Microsoft.Windows.UI.Xaml.CSharp.targets" />', '<Import Project="$(MSBuildExtensionsPath)\Microsoft\WindowsXaml\v$(VisualStudioVersion)\Microsoft.Windows.UI.Xaml.CSharp.targets" />'}

# Output this so far
$FileContents | Out-File $FilePath -Encoding ascii -Force

#Now we need to do a multiline match, so read entire file in again, this time as a single string
$FileContents = Get-Content -Path $FilePath -Raw
$FileContents = $FileContents -replace '<TargetPlatformVersion>8.1</TargetPlatformVersion>', "<TargetPlatformIdentifier>UAP</TargetPlatformIdentifier>
    <TargetPlatformVersion>$UAPVersionNumber</TargetPlatformVersion>
    <TargetPlatformMinVersion>$UAPVersionNumber</TargetPlatformMinVersion>"
$FileContents = $FileContents -replace '<MinimumVisualStudioVersion>12</MinimumVisualStudioVersion>', '<MinimumVisualStudioVersion>14</MinimumVisualStudioVersion>
    <EnableDotNetNativeCompatibleProfile>true</EnableDotNetNativeCompatibleProfile>'
$FileContents = $FileContents -replace "(?smi)<PropertyGroup Condition="" '\$\(TargetPlatformIdentifier\)' == ''(.*)</PropertyGroup>", ''

$FileContents = $FileContents -replace "(?smi)<PropertyGroup Condition="" '\$\(Configuration\)\|\$\(Platform\)' == 'Debug\|AnyCPU'(.*?)</PropertyGroup>\n", ''
$FileContents = $FileContents -replace "(?smi)<PropertyGroup Condition="" '\$\(Configuration\)\|\$\(Platform\)' == 'Release\|AnyCPU'(.*?)</PropertyGroup>\n", ''

#Remove NuGet v2 package references
$FileContents = $FileContents -replace "(?smi)<ItemGroup>(\s*)<Reference(.*?)</ItemGroup>", ''

$FileContents = $FileContents -replace "(?smi)<Target Name=""EnsureNuGetPackageBuildImports(.*?)</Target>\r\n", ''
$FileContents = $FileContents -replace "(?smi)<Import Project=""\.\.\\packages(.*?)/>\r\n", ''

$FileContents = $FileContents -replace "  <None Include=""packages.config"" />", "  <None Include=""project.json"" />"

# The above works for those projects that already had a NuGet v2 packages.config, 
# but doesn't handle the case of projects that had no NuGet packages at all - these still need a project.json reference.
if ($FileContents -notmatch "project.json")
{
  # First, extract the ItemGroup with the manifest reference
  $FileContents -match '(?smi)<ItemGroup>\s*<AppxManifest Include="Package.appxmanifest">.*?</ItemGroup>'
  $AppManifestIdentityGroup = $matches[0]
  $NewAppManifestIdentityGroup = $AppManifestIdentityGroup -replace '</ItemGroup>', "  <None Include=""project.json"" />
  </ItemGroup>"
  # Put in the modified element
  $FileContents = $FileContents -replace "$AppManifestIdentityGroup", "$NewAppManifestIdentityGroup"
}

# Write out the finished file
$FileContents | Out-File $FilePath -Encoding ascii -Force
ECHO "Finished updating csproj file"

# Find the package.appxmanifest file
# Find the manifest file
$AppxManifestFilePath   = Get-ChildItem -Path "." | Where-Object {$_.Extension -eq ".appxmanifest"} | Select-Object -First 1
if ($AppxManifestFilePath)
{
    ECHO "Converting $AppxManifestFilePath..."

    # We need to do a multiline match, so read entire file as a single string
    $FileContents = Get-Content -Path $AppxManifestFilePath -Raw
    $FileContents = $FileContents -replace "(?smi)<Package [^>]*>", '<Package
      xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
      xmlns:mp="http://schemas.microsoft.com/appx/2014/phone/manifest"
      xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
      IgnorableNamespaces="uap mp">'
    $dependencies = '<Dependencies>
        <TargetPlatform Name="Windows.Universal" MinVersion="10.0.0.0" MaxVersionTested="10.0.0.0" />
      </Dependencies>'
    $FileContents = $FileContents -replace "(?smi)<Prerequisites>.*</Prerequisites>", $dependencies
    $FileContents = $FileContents -replace "<TargetPlatform", '<TargetDeviceFamily'
    $FileContents = $FileContents -replace "<m3:", '<uap:'
    $FileContents = $FileContents -replace "</m3:", '</uap:'
    $FileContents = $FileContents -replace "<m2:", '<uap:'
    $FileContents = $FileContents -replace "</m2:", '</uap:'
    $FileContents = $FileContents -replace 'ForegroundText="light"', ''
    $FileContents = $FileContents -replace 'Capability Name="appointments"', 'uap:Capability Name="appointments"'
    $FileContents = $FileContents -replace 'Capability Name="contacts"', 'uap:Capability Name="contacts"'
    $FileContents = $FileContents -replace 'Capability Name="enterpriseAuthentication"', 'uap:Capability Name="enterpriseAuthentication"'
    $FileContents = $FileContents -replace 'Capability Name="musicLibrary"', 'uap:Capability Name="musicLibrary"'
    $FileContents = $FileContents -replace 'Capability Name="picturesLibrary"', 'uap:Capability Name="picturesLibrary"'
    $FileContents = $FileContents -replace 'Capability Name="removableStorage"', 'uap:Capability Name="removableStorage"'
    $FileContents = $FileContents -replace 'Capability Name="sharedUserCertificates"', 'uap:Capability Name="sharedUserCertificates"'
    $FileContents = $FileContents -replace 'Capability Name="videosLibrary"', 'uap:Capability Name="videosLibrary"'

    # Check for the <mp:PhoneIdentity> element
    if ($FileContents -notmatch "<mp:PhoneIdentity")
    {
      # Get the value of the Name attribute in the <Identity> element
      # and insert the missing PhoneIdentity
      $FileContents -match '(?smi)<Identity[^N]*Name="(?<nameattribute>[^"]*)[^>]*>'
      $IdentityElement = $matches[0]
      $NameAttribute = $matches['nameattribute']
      $FileContents = $FileContents -replace "$IdentityElement", "$IdentityElement

      <mp:PhoneIdentity PhoneProductId=""$NameAttribute"" PhonePublisherId=""00000000-0000-0000-0000-000000000000""/>"
    }

    # Output the file
    $FileContents | Out-File $AppxManifestFilePath -Encoding ascii -Force
    ECHO "Finished updating package.appxmanifest"
}


# Delete packages.config
$FilePath   = Get-ChildItem -Path "." | Where-Object {$_.Name -eq "packages.config"} | Select-Object -First 1
if ($FilePath)
{
    ECHO "Deleting packages.config..."
    $FilePath | Remove-Item -Force
}

# Create project.json
ECHO "Creating project.json..."
'{' > project.json
'  "dependencies": {' >> project.json
# Output ApplicationInsights dependencies only if this is a foreground app (i.e. has an appxmanifest)
if ($AppxManifestFilePath)
{
'    "Microsoft.ApplicationInsights": "1.0.0",' >> project.json
'    "Microsoft.ApplicationInsights.PersistenceChannel": "1.0.0",' >> project.json
'    "Microsoft.ApplicationInsights.WindowsApps": "1.0.0",' >> project.json
}
'    "Microsoft.NETCore.UniversalWindowsPlatform": "5.0.0"' >> project.json
'  },' >> project.json
'  "frameworks": {' >> project.json
'    "uap10.0": {}' >> project.json
'  },' >> project.json
'  "runtimes": {' >> project.json
'    "win10-arm": {},' >> project.json
'    "win10-arm-aot": {},' >> project.json
'    "win10-x86": {},' >> project.json
'    "win10-x86-aot": {},' >> project.json
'    "win10-x64": {},' >> project.json
'    "win10-x64-aot": {}' >> project.json
'  }' >> project.json
'}' >> project.json

ECHO "Done"
Pause