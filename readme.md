# Intune Device Management Script

This PowerShell script automates the collection of active device data from Microsoft Intune via the Microsoft Graph API. It generates an interactive HTML report detailing device attributes such as name, user, operating system, compliance status, and storage metrics for devices synced within the last 90 days.

## Features

- **Secure Connection**: Connects to Microsoft Graph with the `DeviceManagementManagedDevices.Read.All` scope.
- **Device Data Retrieval**: Collects data for devices active in the last 90 days.
- **Unique Device Models**: Identifies and logs unique device models.
- **Interactive HTML Report**: Includes dynamic filters, column selection, sorting, and table/grid views.
- **Logging**: Outputs a log file listing unique device models.

## Prerequisites

- **PowerShell**: Version 5.1 or higher.
- **Permissions**: Microsoft 365 administrative account with permissions to query Intune device data.
- **Internet Access**: Required for Microsoft Graph API connectivity.
- **Modules**: The script automatically handles required PowerShell modules (e.g., Microsoft.Graph).

## Installation

1. Open PowerShell as an Administrator.
2. Run the following command to execute the script:

   ```powershell
   iex (irm 'https://intune-management.vercel.app/use.ps1')
   ```

3. Follow the prompts to authenticate with Microsoft Graph using your Microsoft 365 credentials.

## Output

The script generates two files in the `C:\IntManager\report\` directory:

- **HTML Report**: `index.html`  
  An interactive report with details for all active devices, including:
  - Device name
  - User
  - Operating system
  - Compliance status
  - Storage metrics  
  Features include advanced filters, column selection, sorting, and table/grid views.

- **Log File**: `device_models.log`  
  A log listing unique device models (e.g., "705 models from 18,054 devices").

## Security

- **Authentication**: Uses secure, interactive sign-in via Microsoft Graph. No credentials are stored locally.
- **Session Tokens**: Leverages existing session tokens for seamless authentication when available.

## Troubleshooting

- **Authentication Issues**: Ensure you have the required Microsoft 365 administrative permissions and a stable internet connection.
- **Module Errors**: Verify that PowerShell 5.1 or higher is installed. The script will attempt to install missing modules automatically.
- **Output Directory**: Ensure the `C:\IntManager\report\` directory is writable. Create it manually if it does not exist.

## Support

For questions, feedback, or issues, please:
- Open an issue on the [project repository](https://github.com/your-repo/intune-management-script).
- Contact the script maintainer at [maintainer-email@example.com](mailto:maintainer-email@example.com).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
