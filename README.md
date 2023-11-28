# Introduction

This PowerShell script takes a list of tags from a CSV file and updates/adds them to the corresponding resources in Azure.

## What the Project Does

This project is designed to automate the process of updating or adding tags to resources in Azure. It reads a CSV file that contains the tags and their corresponding resources, and then applies those tags to the resources in Azure. This script is designed to be used with GitHub Actions.

## How to Run the Project

This project is designed to be run as a GitHub Action. Here are the steps to set it up:

1. Fork or clone the repository to your GitHub account.
2. Set the necessary environment variables in your GitHub repository settings under the "Secrets" section.
3. Create a new GitHub Action workflow that triggers the PowerShell script.

## Required Environment Variables

The following environment variables need to be set in your GitHub repository secrets for the script to work:

- `AZURE_TENANT_ID`: Your Azure Tenant ID.
- `AZURE_CLIENT_ID`: Your Azure Client ID.
- `AZURE_CLIENT_SECRET`: Your Azure Client Secret.
- `CSV_FILE_PATH`: The path to the CSV file that contains the tags and their corresponding resources.

Please ensure these are set correctly before running the script.