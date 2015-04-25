# Andy Wigley
# andy.wigley@microsoft.com

# Get the version number of UAP (selects last subfolder)
$FolderPath = "C:\Program Files (x86)\Windows Kits\10\Platforms\UAP"
$UAPVersionNumber = Get-ChildItem -Path $FolderPath | Select-Object -Last 1 -ExpandProperty Name

# Find the csproj file
$FilePath   = Get-ChildItem -Path "." | Where-Object {$_.Extension -eq ".csproj"} | Select-Object -First 1
ECHO "Converting $FilePath..."
# Note Get-Content returns file contents as an array of strings
$FileContents = Get-Content -Path $FilePath
$FileContents = $FileContents | ForEach-Object {$_ -replace '<ProjectTypeGuids>.*</ProjectTypeGuids>', "<ProjectTypeGuids>{A5A43C5B-DE2A-4C0C-9213-0A381AF9435A};{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}</ProjectTypeGuids>"}
$FileContents = $FileContents | ForEach-Object {$_ -replace ';WINDOWS_APP', ';WINDOWS_UAP'}
$FileContents = $FileContents | ForEach-Object {$_ -replace ';WINDOWS_PHONE_APP', ';WINDOWS_UAP'}
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

# Write out the finished file
$FileContents | Out-File $FilePath -Encoding ascii -Force
ECHO "Finished updating csproj file"

# Find the package.appxmanifest file
$FilePath   = Get-ChildItem -Path "." | Where-Object {$_.Extension -eq ".appxmanifest"} | Select-Object -First 1
ECHO "Converting $FilePath..."
# We need to do a multiline match, so read entire file as a single string
$FileContents = Get-Content -Path $FilePath -Raw
$FileContents = $FileContents -replace "(?smi)<Package [^>]*>", '<Package
  xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
  xmlns:mp="http://schemas.microsoft.com/appx/2014/phone/manifest"
  xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
  IgnorableNamespaces="uap mp">'
$dependencies = '<Dependencies>
    <TargetPlatform Name="Windows.Universal" MinVersion="' + $UAPVersionNumber + '" MaxVersionTested="' + $UAPVersionNumber + '" />
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
$FileContents | Out-File $FilePath -Encoding ascii -Force
ECHO "Finished updating package.appxmanifest"
ECHO "Done"
Pause