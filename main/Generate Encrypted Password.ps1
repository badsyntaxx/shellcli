function generateEncryptedPassword {
    param (
        [string]$outputPath = "C:\EncryptionFiles"
    )

    # Create output directory if it doesn't exist
    if (-not (Test-Path -Path $outputPath)) {
        New-Item -ItemType Directory -Path $outputPath | Out-Null
        writeText -type "plain" -text "Created output directory: $outputPath"
    }

    # Prompt the user for a password
    $password = readInput -prompt "Enter the password to encrypt:" -IsSecure

    # Generate a random 32-byte (256-bit) encryption key
    $encryptionKey = New-Object Byte[] 32
    [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($encryptionKey)

    # Convert the encryption key to a comma-separated string for storage
    $encryptionKeyString = $encryptionKey -join ","

    # Encrypt the password using the encryption key
    $encryptedPassword = ConvertFrom-SecureString -SecureString $password -Key $encryptionKey

    # Save the encryption key and encrypted password to files
    $keyFilePath = "$outputPath\KEY.txt"
    $passwordFilePath = "$outputPath\PHRASE.txt"

    Set-Content -Path $keyFilePath -Value $encryptionKeyString
    Set-Content -Path $passwordFilePath -Value $encryptedPassword

    $password = $null

    writeText -type "plain" -text "Decryption key saved to: $keyFilePath"
    writeText -type "plain" -text "Encrypted password saved to: $passwordFilePath"
    writeText -type "success" -text "Success. An encrypted password and decryption key have been generated."
}