
---

## 📄 `Phase1/03_Create_NSG.md`
```markdown
# Step 3 – Create Network Security Group (NSG)

NSG is used to control inbound and outbound traffic for your VMs.

## 💻 PowerShell Command
```powershell
New-AzNetworkSecurityGroup -ResourceGroupName HomeLabRG -Location "East US" -Name HomeLabNSG
