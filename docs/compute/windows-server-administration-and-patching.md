# Windows Server 2022 — Administration, Diagnostics & Patch Compliance

[← Compute Overview](./README.md) · [Private RDP & Terraform](./windows-server-vms.md) · [Portfolio Home](../../README.md)

## Scope and validation date

This record documents hands-on Windows Server administration on `Dev-win01`, successful authenticated RDP to **both** Windows VMs, and Azure Update Manager assessment/configuration for **both** Windows VMs. 
| VM | Resource group | Private IP | OS | Validated |
|---|---|---|---|---|
| `Dev-win01` | `DevLab_RG` | `10.20.1.5` | Windows Server 2022 Datacenter | Authenticated private RDP; guest OS diagnostics; Update Manager |
| `Prod-win01` | `HomeLab_RG` | `10.10.0.5` | Windows Server 2022 Datacenter | Authenticated private RDP; Update Manager |
| `Prod-mgmt01` | `HomeLab_RG` | `10.10.0.4` | Ubuntu 22.04 LTS | SSH jump host; TCP/3389 tests |

## Private RDP validation — both Windows VMs

From `Prod-mgmt01`, TCP/3389 connectivity succeeded to `10.20.1.5` and `10.10.0.5`. From macOS, separate SSH local forwards were established through `Prod-mgmt01`; both local listeners passed `nc` testing. Windows App authenticated successfully to **both** Windows Server desktops.

```bash
# Run in separate macOS terminal windows; substitute the current management VM public IP.
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:13389:10.20.1.5:3389 azureadmin@<MGMT-PUBLIC-IP>
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:13390:10.10.0.5:3389 azureadmin@<MGMT-PUBLIC-IP>

# Test from macOS, not from the Linux jump host.
nc -vz 127.0.0.1 13389
nc -vz 127.0.0.1 13390
```

Windows App endpoints: `127.0.0.1:13389` for `Dev-win01` and `127.0.0.1:13390` for `Prod-win01`. Neither Windows VM has a public IP. Successful private administration does **not** prove that other internal sources are denied by NSGs.

## Dev-win01 — guest operating system inventory

Read-only commands executed in an authenticated PowerShell session:

```powershell
hostname
Get-ComputerInfo | Select-Object CsName,WindowsProductName,WindowsVersion,OsBuildNumber,OsLastBootUpTime
Get-NetIPConfiguration
```

Observed: `Dev-win01`; Windows Server 2022 Datacenter; Windows version `2009`; build `20348`; last boot `2026-10-31 20:20:27` (guest-reported time). Interface `Ethernet` used `10.20.1.5/24`, default gateway `10.20.1.1`, and Azure DNS `168.63.129.16`.

### Network diagnostics

```powershell
Get-NetAdapter | Format-List Name,InterfaceDescription,InterfaceIndex,Status,MacAddress,LinkSpeed
Get-NetIPAddress -AddressFamily IPv4 | Select-Object InterfaceAlias,InterfaceIndex,IPAddress,PrefixLength,AddressState
Get-NetRoute -AddressFamily IPv4 | Where-Object DestinationPrefix -eq '0.0.0.0/0' | Select-Object InterfaceAlias,InterfaceIndex,NextHop,RouteMetric
Test-NetConnection -ComputerName 10.10.0.4 -Port 22
Resolve-DnsName microsoft.com
```

- `Ethernet`: Microsoft Hyper-V Network Adapter, index 5, **Up**, private IPv4 `10.20.1.5/24`.
- `Ethernet 2`: Microsoft Azure Network Adapter, index 4, **Up**, no separate IPv4 reported.
- Both adapters reported the same MAC and a virtual link speed of 200 Gbps. This is consistent with an Azure virtual networking presentation; it is **not** measured application throughput. No adapter was disabled.
- Default IPv4 route: `0.0.0.0/0` via `Ethernet` (index 5) to `10.20.1.1`, route metric `0`.
- `Test-NetConnection 10.10.0.4 -Port 22`: `TcpTestSucceeded : True`, source `10.20.1.5`, confirming a TCP connection from the development Windows VM to the management VM across the peered VNets.
- `Resolve-DnsName microsoft.com` returned A and AAAA answers. This validates name resolution, **not** internet reachability by itself.

**Troubleshooting lesson:** `Get-NetIPAddress` does not return route objects; use `Get-NetRoute` to inspect `DestinationPrefix`.

### Windows service inventory

```powershell
Get-Service -Name TermService,W32Time,EventLog,WinRM,wuauserv |
  Select-Object Name,DisplayName,Status,StartType | Format-Table -AutoSize
```

| Service | Status | Start type |
|---|---|---|
| `EventLog` | Running | Automatic |
| `TermService` | Running | Manual |
| `W32Time` | Running | Automatic |
| `WinRM` | Running | Automatic |
| `wuauserv` | Stopped | Manual |

A stopped on-demand Windows Update service is not, alone, evidence of failure. WinRM service status does not prove remote WinRM accessibility.

### System Event Log and VBS findings

```powershell
Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2,3;StartTime=(Get-Date).AddDays(-1)} -MaxEvents 15 |
  Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message | Format-List

Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
  Select-Object VirtualizationBasedSecurityStatus,SecurityServicesConfigured,SecurityServicesRunning,AvailableSecurityProperties,RequiredSecurityProperties |
  Format-List
```

Four System events were observed: three DistributedCOM **10016** permission warnings, and one Wininit **15** event reporting that Credential Guard and/or VBS Key Isolation were configured but the secure kernel was not running at boot. The Device Guard query returned `VirtualizationBasedSecurityStatus=0`, `SecurityServicesConfigured={0}`, `SecurityServicesRunning={0}`, `AvailableSecurityProperties={1,3,5,7}`, and `RequiredSecurityProperties={0}`.

**Interpretation:** VBS was not enabled at the time of inspection. The startup warning was recorded, but its root cause was not established. No DCOM permission or VBS changes were made. Investigate Azure VM security type, Trusted Launch, Secure Boot and vTPM separately before proposing remediation.

### Windows Defender Firewall / RDP

```powershell
Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction
Get-NetFirewallRule -DisplayGroup 'Remote Desktop' |
  Select-Object DisplayName,Enabled,Direction,Action,Profile
Get-NetFirewallRule -DisplayGroup 'Remote Desktop' |
  Where-Object {$_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound'} |
  Get-NetFirewallAddressFilter | Select-Object LocalAddress,RemoteAddress
```

All three firewall profiles (Domain, Private, Public) were **enabled**; the displayed default action properties were `NotConfigured`, which does not establish an allow-all policy. Three inbound RDP rules were enabled and allowed: Shadow TCP, User Mode TCP, and User Mode UDP. Their profile bitmask `7` covers Domain/Private/Public. All three address filters showed `LocalAddress=Any` and `RemoteAddress=Any`.

**Security finding:** Guest RDP rules do not restrict source IPs. The `AppSubnet_NSG` custom rule permits TCP/3389 from `10.10.0.4/32` to `10.20.1.5`, but the effective default `AllowVnetInBound` rule may allow additional internal sources. Plan to validate effective NSGs and implement defense-in-depth source restrictions with a tested rollback procedure; **no live firewall hardening was performed**.

## Windows update assessment

### Guest patch history — Dev-win01

```powershell
Get-HotFix | Sort-Object InstalledOn -Descending |
  Select-Object -First 10 HotFixID,Description,InstalledOn | Format-Table -AutoSize
```

| HotFixID | Reported description | InstalledOn |
|---|---|---|
| `KB5126654` | Security Update | 2026-10-25 |
| `KB5134140` | Update | 2026-10-25 |
| `KB5127687` | Update | 2026-10-25 |

These are **guest-reported** entries, not an independently verified complete update catalog. `Get-HotFix` does not enumerate all update types.

### Azure Update Manager — both Windows VMs

In **Azure Update Manager → Machines**, an assessment completed for `Dev-win01` and `Prod-win01`. Both displayed **No pending updates** on October 31, 2026. Subsequently, **Update settings → Periodic assessment → Enable** was saved for both. A refreshed Machines view showed `Periodic assessment: Yes` for both and `No pending updates` for both.

- Patch orchestration remained **Windows automatic updates (current)**; no Azure Update Manager maintenance schedule was created.
- No **One-time update** installation was initiated during this exercise.
- `Prod-win01` was already **VM deallocated** in the final Update Manager screenshot; its last assessment remained visible.
- Periodic assessment requires the VM to be running when a scan occurs; deallocated VMs do not receive fresh assessments.
- The other three Linux VMs showed **No updates data** and **Periodic assessment: No** in that screenshot. They were not assessed in this exercise.

**Assessment boundary:** “No pending updates” is a point-in-time Update Manager result, not proof of perpetual patch compliance or absence of vulnerabilities. Existing Windows automatic-update behavior was not changed by enabling periodic assessment.

## Cost management and shutdown

The HomeLab budget is **$200/month**. Azure Update Manager assessments for Azure VMs have no separate per-VM management fee; running VM compute, disks, and applicable networking resources can still incur charges. The operator confirmed **all five VMs were safely deallocated after the exercise**. This final all-VM state was reported by the operator, not re-verified here with a new `az vm list -d` output.

To verify power states before the next session:

```bash
az vm list -d --query "[].{Name:name,ResourceGroup:resourceGroup,PowerState:powerState}" -o table
```

Deallocation stops VM compute charges, but managed disks and certain other resources may continue to be billed.

## Remaining improvements (not yet completed)

1. Inspect effective NSG behavior and plan RDP source restrictions at both Azure and guest firewall layers, with a rollback path.
2. Confirm Windows automatic-update policy and evaluate controlled maintenance windows, reboot behavior, and patch orchestration.
3. Investigate VBS / Trusted Launch configuration before making security changes.
4. Add Azure Monitor, Log Analytics, and Windows Event Log-based troubleshooting scenarios.
5. Test backup/restore and recovery workflows.
6. Consider update assessments for Linux VMs when started.

## Engineering lessons

- Validate each access layer independently: VM running state, private TCP port, Mac-local SSH listener, then authenticated RDP.
- Keep shell context clear: local forwarded ports listen on **macOS**, not on `Prod-mgmt01`.
- Separate **observed** Windows/portal evidence from assumptions about effective security posture.
- Use read-only PowerShell diagnostics before changing firewall, security, or patch settings.
- Treat update assessments as point-in-time evidence and deallocate lab VMs after use.

## Related documentation

- [Compute overview](./README.md)
- [Windows Server private access and Terraform](./windows-server-vms.md)
- [Terraform Dev Windows VM](../../terraform/dev-windows-vm/README.md)
