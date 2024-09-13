# DHCP-Scope-Analyzer

## Description

DHCP-Scope-Analyzer is a PowerShell script designed to analyze and optimize DHCP scopes on Windows Server environments. This tool provides network administrators with valuable insights into their DHCP configurations by identifying the best available IP ranges within each scope, taking into account exclusions and reservations.

## Key Features

1. **Scope Analysis**: Examines all DHCP scopes on a specified server.
2. **Exclusion Handling**: Accurately processes and accounts for IP address exclusions within each scope.
3. **Best Range Calculation**: Identifies the largest contiguous block of available IP addresses in each scope.
4. **Reservation Reporting**: Collects and formats DHCP reservations for easy review.
5. **Detailed Debugging**: Provides comprehensive debug output for troubleshooting and verification.
6. **Export Functionality**: Exports DHCP reservation data to a configuration file.

## Use Cases

- Optimizing DHCP scope configurations
- Troubleshooting IP address allocation issues
- Preparing for network expansions or reconfigurations
- Auditing DHCP settings across multiple scopes
- Generating reports on available IP addresses and current reservations

This script is an essential tool for network administrators looking to maintain efficient and well-organized DHCP services in their Windows Server environments.
