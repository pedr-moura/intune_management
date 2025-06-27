

# Intune Device Management Script

This PowerShell script automates the collection of active device data from Microsoft Intune using the Microsoft Graph API. It processes details such as device name, user, operating system, compliance status, and storage metrics for devices synced in the last 90 days, generating an interactive HTML report.

## Getting Started

1. **Open PowerShell as Administrator.**

2. Run the following command:

    ```powershell
    iex (irm 'https://intune-management.vercel.app/use.ps1')
    ```

3. The script will:
   - Connect securely to Microsoft Graph with `DeviceManagementManagedDevices.Read.All` scope.
   - Retrieve data for active devices (last 90 days).
   - Identify unique device models and log them.
   - Generate an HTML report with dynamic filters, sorting, and table/grid views.

## Output

- A file named `index.html` will be saved at:

    ```
    C:\IntManager\report\index.html
    ```

- A log file `device_models.log` will be saved at:

    ```
    C:\IntManager\report\device_models.log
    ```

- The report includes:
  - Details for all active devices (e.g., device name, user, OS, compliance, storage).
  - Interactive features: advanced filters, column selection, sorting, and table/grid views.
  - A log of unique device models (e.g., 705 models from 18,054 devices).

## Requirements

- PowerShell 5.1 or higher.
- Microsoft 365 administrative permissions to query Intune device data.
- Internet access.

## Security

The script does not store credentials locally. Authentication is handled securely via Microsoft Graph, using interactive sign-in or existing session tokens.

## Support

For questions, feedback, or issues, please open an issue on the project repository or contact the script maintainer.

