
---

## 📄 `Phase1/04_Create_VMs_AzurePortal.md`
```markdown
# Step 4 – Create Virtual Machines (via Azure Portal)

## 🧾 Instructions
1. Navigate to **Virtual Machines** in Azure Portal
2. Click **+ Add > Virtual Machine**
3. Fill in the required fields:
   - **Resource Group:** HomeLabRG
   - **VM Name:** HomeLabVM01 (repeat for 02–04)
   - **Region:** East US
   - **Image:** Ubuntu LTS or Windows Server 2022
   - **Authentication Type:** SSH or Password
   - **VNet:** HomeLabVNet
   - **Subnet:** HomeLabSubnet
   - **Public IP:** Optional (disabled for private VMs)
   - **NSG:** Select existing — `HomeLabNSG`

4. Click **Review + Create > Create**
5. Repeat steps to deploy additional VMs (2–4 total)

## ✅ Result
- VMs are deployed in same subnet and secured with NSG.
- Communication between them is now possible.
