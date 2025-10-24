# Usefull and automated personal shell commands

## Installation

To make scripts accessible from anywhere in your terminal, follow these steps:

1. Clone the repository to your local machine
2. Move into the cloned directory
3. Add the scripts to the PATH variable:

   - **Linux / MacOS**:

   ```sh
   echo "export PATH=\"\$PATH:$(pwd)/bin\"" >> ~/.bashrc
   source ~/.bashrc
   ```

   - **Windows (PowerShell)**:

   ```powershell
   $currentDir = Get-Location
   [Environment]::SetEnvironmentVariable("Path", "$env:Path;$currentDir\bin", "User")
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
   ```

4. Execute script

   - **Linux / MacOS**:

   ```sh
   ./<script>
   ```

   - **Windows (wsl via PowerShell)**:

   ```Powershell
   wsl <script>
   ```
