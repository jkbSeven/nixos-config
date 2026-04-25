{...}:

{
    services.qemuGuest.enable = true;

    boot.initrd.availableKernelModules = [
        "virtio_pci"
        "virtio_scsi"
        "virtio_blk"
    ];
}
