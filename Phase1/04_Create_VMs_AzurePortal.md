# Step 4 – Create Virtual Machines (via Azure Portal)

In this step, we will manually create four virtual machines inside the `HomeLabRG` resource group using the **Azure Portal**. Each VM will be placed in the same virtual network (`HomeLabVNet`), subnet (`HomeLabSubnet`), and later associated with a shared Network Security Group (`HomeLabNSG`).

## 🧾 Instructions

1. **Log in to the Azure Portal**  
   Go to: [https://portal.azure.com](https://portal.azure.com)

2. **Navigate to Virtual Machines**  
   In the search bar, type and select **Virtual Machines**

3. **Click `+ Create > Azure virtual machine`**

---

### 🔧 **Basics Tab**
- **Subscription**: Select your active subscription  
- **Resource group**: `HomeLabRG`  
- **Virtual machine name**: e.g., `HomeLabVM01`, `HomeLabVM02`, etc.  
- **Region**: `East US` (same as other resources)  
- **Availability options**: Leave as **default**  
- **Image**:  
  - Windows: Choose **Windows Server 2019** or **2022**  
  - Linux: Choose **Ubuntu LTS** or **Red Hat Enterprise Linux**  
- **Size**: Select a small size like **Standard B1s**  
- **Authentication type**:  
  - Windows: **Password**  
  - Linux: **SSH public key** or **Password**  
- **Username**: e.g., `azureuser`  
- **Password**: Use a strong password (save it)  
- **Public inbound ports**: Select **Allow selected ports**  
  - Windows: Select **RDP (3389)**  
  - Linux: Select **SSH (22)**

---

### 💾 **Disks Tab**
- Leave all default options (Standard SSD or Premium SSD)

---

### 🌐 **Networking Tab**
- **Virtual network**: Select or create `HomeLabVNet`  
- **Subnet**: Select `HomeLabSubnet` (ensure all VMs use the same subnet)  
- **Public IP**: Choose **Yes**  
- **NIC network security group**: Select **None** (you will attach `HomeLabNSG` later)  
- **Accelerated networking**: Leave as **default**  
- **Load balancing**: Select **No**

---

### 🛠️ **Management, Advanced, and Tags Tabs**
- Leave all default options  
- Optional: Add a tag `Environment: HomeLab`

---

### ✅ **Review + Create**
- Review configuration summary  
- Click **Create**  
- Repeat steps to create all four VMs (`HomeLabVM01` through `HomeLabVM04`)
