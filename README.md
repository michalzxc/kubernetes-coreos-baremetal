FORK of [ xetys/kubernetes-coreos-baremetal](https://github.com/xetys/kubernetes-coreos-baremetal)

# PC
Add ssh keys, generate masters configuration and workers
```
 ./addrootsshkey.sh ~/.ssh/authorized_keys
 ./build-cloud-config.sh controller1 controller1.local dhcp
 ./build-cloud-config.sh controller2 controller2.local dhcp
 ./build-cloud-config.sh controller3 controller3.local dhcp
 ./updatemasters.sh
 ./build-cloud-config.sh worker1 worker1.local controller1.local
 ./build-cloud-config.sh worker2 worker2.local controller1.local
 ./build-cloud-config.sh worker3 worker3.local controller1.local
 ./updatemasters.sh
```

# KVM Server
__virsh:__
```
vol-clone coreos_production_openstack_image.img controller1.img --pool default
vol-resize --pool default --vol controller1.img 15G
vol-clone coreos_production_openstack_image.img controller2.img --pool default
vol-resize --pool default --vol controller2.img 15G
vol-clone coreos_production_openstack_image.img controller3.img --pool default
vol-resize --pool default --vol controller3.img 15G
vol-clone coreos_production_openstack_image.img worker1.img --pool default
vol-resize --pool default --vol worker1.img 50G
vol-clone coreos_production_openstack_image.img worker2.img --pool default
vol-resize --pool default --vol worker2.img 50G
vol-clone coreos_production_openstack_image.img worker3.img --pool default
vol-resize --pool default --vol worker3.img 50G
vol-list default
```
# PC
```
scp inventory/node-controller1/config.iso michal@145.239.253.207:~/node-controller1.iso
scp inventory/node-controller2/config.iso michal@145.239.253.207:~/node-controller2.iso
scp inventory/node-controller3/config.iso michal@145.239.253.207:~/node-controller3.iso
scp inventory/node-worker1/config.iso michal@145.239.253.207:~/node-worker1.iso
scp inventory/node-worker2/config.iso michal@145.239.253.207:~/node-worker2.iso
scp inventory/node-worker3/config.iso michal@145.239.253.207:~/node-worker3.iso
```

# KVM Server
```
mv /home/michal/*.iso /var/lib/libvirt/images/
chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/*.iso
```

# PC
```
virt-install --connect qemu+ssh://michal@145.239.253.207/system -n controller1 --memory 4096 --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/controller1.img --network network=internal --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-controller1.iso
virt-install --connect qemu+ssh://michal@145.239.253.207/system -n controller2 --memory 4096 --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/controller2.img --network network=internal --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-controller2.iso
virt-install --connect qemu+ssh://michal@145.239.253.207/system -n controller3 --memory 4096 --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/controller3.img --network network=internal --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-controller3.iso
virt-install --connect qemu+ssh://michal@145.239.253.207/system -n worker1 --memory 10240 --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/worker1.img --network network=internal --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-worker1.iso
virt-install --connect qemu+ssh://michal@145.239.253.207/system -n worker2 --memory 10240 --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/worker2.img --network network=internal --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-worker2.iso
virt-install --connect qemu+ssh://michal@145.239.253.207/system -n worker3 --memory 10240 --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/worker3.img --network network=internal --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-worker3.iso
```
