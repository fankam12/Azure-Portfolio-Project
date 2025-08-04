# Step 1 – Create Resource Group: `HomeLabRG`

We start by creating a centralized resource group to contain all project resources.

## 💻 Azure PowerShell Command
```powershell
# ---------------------------------------------
# Create a Resource Group named 'HomeLabRG'
# ---------------------------------------------
New-AzResourceGroup -Name "HomeLabRG" -Location "East US"
