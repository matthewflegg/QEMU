<#
.SYNOPSIS
    Creates or starts an Arch Linux virtual machine.
    
.DESCRIPTION
    Creates an Arch Linux virtual machine using QEMU, or starts an existing
    instance if this script was already used to initialize one.

    Prerequisites:
    --------------

    - QEMU is installed and working on your Windows 10/11 system (1).
    - Virtualization (Intel VT-d, AMD-V) is enabled in BIOS/UEFI.
    - Minimum 30G disk space on your primary storage device.
    - You have downloaded an Arch Linux ISO.

    Instructions:
    -------------

    - Change the relevant configuration parameters below as appropriate (2).
    - Create the virtual machine with .\ArchVm.ps1 -Action Create.
    - Install Arch Linux on the Virtual Machine (3).
    - Start the virtual machine with .\ArchVm.ps1 -Action Start.

    Not sure what to do?
    --------------------

    Each number corresponds to instructions/help regarding a prerequisite or
    instruction.

    (1) QEMU Windows Installation: https://dev.to/whaleshark271/using-qemu-on-windows-10-home-edition-4062
    (2) QEMU Options:              https://wiki.gentoo.org/wiki/QEMU/Options
    (3) Arch Installation:         https://wiki.archlinux.org/title/installation_guide
    
.NOTES
	Author: Matthew Flegg | License: GPL V3
#>

# Specify parameters for the user to pass to the CmdLet.
[CmdLetBinding()]
param(
    [ValidateSet("Create", "Start")]
    [string] $Action
)

# ===== Configuration =====
# Change these variables below as appropriate.
$memorySizeMb = 4096                                    # Must be fewer than your total memory in MB.
$cpuCoreCount = 4                                       # Must be fewer than your total number of threads.
$diskImageFilePath = ".\Arch Linux.qcow2"
$diskImageSizeGb = 30                                   # Minimum required.
$archIsoFilePath = ".\archlinux-2022.09.03-x86_64.iso"

# ===== Functions =====
# Returns a boolean value indicating whether Windows Hypervisor Platform is is enabled.
function Assert-WhpEnabled {
    $whpEnabled = ((Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform `
        | Select-Object -Property Enabled) `
        | Format-List `
        | Out-String)

    return $whpEnabled.Split(' ')[0].Trim() -eq "Enabled"
}

# Create the virtual disk image.
function Initialize-DiskImage {
    qemu-img.exe create -f qcow2 "Arch Linux.qcow2" "$($diskImageSizeGb)G"
}

# Boot into the live installation environment.
# This starts the VM for the first time and sets relevant parameters.
function Initialize-VirtualMachine {
    qemu-system-x86_64.exe `
        -accel whpx,kernel-irqchip=off `
        -hda $diskImageFilePath `
        -m $memorySizeMb `
        -smp cpus=$cpuCoreCount `
        -net nic,model=virtio `
        -net user `
        -cdrom $archIsoFilePath `
        -vga std `
        -boot strict=on
}

# Run the command to start the virtual machine.
function Start-VirtualMachine {
    qemu-system-x86_64.exe `
        -accel whpx,kernel-irqchip=off `
        -hda $diskImageFilePath `
        -m $memorySizeMb `
        -smp cpus=$cpuCoreCount `
        -net nic,model=virtio `
        -net user `
        -vga std `
        -boot strict=on
}

# ===== Driver Code =====
# Perform either of the actions specified ("Create", "Start").
function Invoke-SpecifiedAction {

    # If WHP is not enabled, QEMU will not be able to create or start the VM.
    if (-Not (Assert-WhpEnabled)) {
        Write-Host @(
            "Windows Hypervisor Platform is not installed. Install WHP: `n"
            "1. Press Win + R, type 'OptionalFeatures.exe' and press ENTER. `n"
            "2. Check 'Windows Hypervisor Platform' box and restart. `n"
        )
    }

    try {

        # Create the disk image and boot the VM for the first time.
        if ($Action -eq "Create") {
            Initialize-DiskImage
            Initialize-VirtualMachine
            Exit 0
        }

        # Start the virtual machine.
        Start-VirtualMachine
        Exit 0
    }

    # Something went wrong. Error details should be given by QEMU.
    catch {
        Write-Host "An error occured."
        Exit -1
    }
}