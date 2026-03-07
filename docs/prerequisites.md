# Prerequisites — Phase 1

## Host Requirements

| Resource  | Minimum    | Recommended |
|-----------|------------|-------------|
| CPU cores | 8 physical | 12+         |
| RAM       | 16 GB      | 32 GB       |
| Free disk | 150 GB     | 200 GB      |
| OS        | Windows 11 | Windows 11  |

## Required Software

### 1. VMware Workstation Pro 17+

Broadcom provides VMware Workstation Pro free for personal use.
Download from: https://support.broadcom.com/group/ecx/productdownloads?subfamily=VMware+Workstation+Pro

### 2. Vagrant

```powershell
winget install HashiCorp.Vagrant
```

Verify: `vagrant --version` (expect 2.4+)

### 3. Vagrant VMware Utility

This is a separate installer from the plugin — it runs as a Windows service that allows
Vagrant to communicate with VMware Workstation. **Must be installed before the plugin.**

1. Go to: `https://releases.hashicorp.com/vagrant-vmware-utility`
2. Click the highest version number at the top of the list
3. Download the file ending in `_windows_amd64.msi`
4. Run the `.msi` and complete the installer

Verify the service is running:

```powershell
Get-Service -Name "vagrant-vmware-utility"
# Status should be: Running
```

### 4. vagrant-vmware-desktop Plugin

```powershell
vagrant plugin install vagrant-vmware-desktop
```

Verify: `vagrant plugin list` (should show `vagrant-vmware-desktop`)

### 5. kubectl

```powershell
winget install Kubernetes.kubectl
```

Verify: `kubectl version --client`

### 6. Git for Windows

Git provides the `bash` shell that `make` targets use internally. Install using the
default path (`C:\Program Files\Git`) — the Makefile hardcodes this location.

```powershell
winget install Git.Git
```

Verify: `git --version`

### 7. Helm

Used to install Phase 2 platform components (ingress-nginx, cert-manager, MetalLB).

```powershell
winget install Helm.Helm
```

Verify: `helm version`

### 8. make

`make` is not included with Windows. Install via winget:

```powershell
winget install GnuWin32.Make
```

Winget does not add `make` to PATH automatically. Add it permanently:

**System Properties → Advanced → Environment Variables → System Variables → Path → Edit → New**

Add: `C:\Program Files (x86)\GnuWin32\bin`

Then **open a new terminal** for the change to take effect.

> For the current terminal session only (no restart required):
> ```powershell
> $env:Path += ";C:\Program Files (x86)\GnuWin32\bin"
> ```

Verify: `make --version`

---

## VMware Network Configuration

StackLayer uses a **host-only** network on the `192.168.56.0/24` subnet. VMware maps
this to a vmnet adapter.

To verify or create the network:
1. Open VMware Workstation
2. Edit → Virtual Network Editor
3. Confirm a host-only adapter exists with subnet `192.168.56.0`, or add one

If `192.168.56.x` conflicts with your existing networks, change `NODE_IP_PREFIX` at the
top of [phase1-infrastructure/Vagrantfile](../phase1-infrastructure/Vagrantfile).

---

## VM Storage Location (Optional)

By default, Vagrant stores VM files inside the project's `.vagrant/` folder. To store
them on a different drive or path, set `STACKLAYER_VM_DIR` before running `vagrant up`:

```powershell
$env:STACKLAYER_VM_DIR = "C:\VMs\stacklayer"
cd phase1-infrastructure
vagrant up
```

The directory will be created automatically. Each VM gets its own subfolder:
`C:\VMs\stacklayer\k8s-controller-1`, `C:\VMs\stacklayer\k8s-worker-1`, etc.

> **Note:** Once VMs are created, changing `STACKLAYER_VM_DIR` requires `vagrant destroy`
> first — Vagrant tracks VM locations at creation time.

---

## Optional (Quality of Life)

- **Windows Terminal** — `winget install Microsoft.WindowsTerminal`

---

## Verification Checklist

```powershell
vagrant --version          # 2.4+
vagrant plugin list        # vagrant-vmware-desktop
kubectl version --client   # v1.x
helm version               # v3.x
git --version              # any recent version
make --version             # GNU Make 3.x+
```
