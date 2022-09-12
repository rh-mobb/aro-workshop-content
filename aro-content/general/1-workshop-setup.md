## Workshop Setup and Access Instructions

### Access Azure Portal and CLI

Access the Azure Portal through <https://portal.azure.com>

#### Azure Credentials

Azure credentials will be provided to you by the organizing staff on the day of the event.

#### Access CloudShell and Attach Persistent Storage

Azure Cloud Shell is an interactive, authenticated, browser-accessible shell for managing Azure resources.

To start Cloud Shell, launch it from the top navigation of the Azure Portal.

![Azure Portal Cloud Shell](../assets/images/overview-cloudshell-icon.png){ align=center }

Select the option to use Bash.

![Cloud Shell Choice](../assets/images/overview-choices.png){ align=center }

By using the advanced option, you can associate existing resources. When selecting a Cloud Shell region you must select a backing storage account co-located in the same region.

When the storage setup prompt appears, select Show advanced settings to view additional options. The populated storage options filter for locally redundant storage (LRS), geo-redundant storage (GRS), and zone-redundant storage (ZRS) accounts.

Mount your storage using the advanced option with the following settings:

- Subscription: `Cloud Services Black Belts`
- Cloud Shell Region: `East US`
- Resource Group: `cs-shared-storage`
- Storage Account: `cs-shared-storage`
- File Share: `cs-shared-file-store`

![Advanced Storage Settings](../assets/images/advanced-storage.png){ align=center }

When your shell is ready and you are at the bash prompt, run the following commands:

```
wget https://rh-mobb.github.io/aro-hackathon-content/assets/cloudshell-setup.sh

chmod +x cloudshell-setup.sh

./cloudshell-setup.sh
```

Your shell should now be ready to use for the workshop.

### Operations Content Workstream

Additional setup instructions for the Operations Workstream can be found here: <https://rh-mobb.github.io/aro-hackathon-content/ops/1-account-setup/>

### Development Content Workstream

Additional setup instructions for the Development Workstream can be found here: <https://rh-mobb.github.io/aro-hackathon-content/app/1-account-setup/>