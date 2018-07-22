#FORK of https://github.com/xetys/kubernetes-coreos-baremetal

* gateway 10.10.10.254
* controller, 10.10.10.1
* worker 1, 10.10.10.2
* worker 2, 10.10.10.3
* edge router, 123.234.234.123


with CoreOS installed, the scripts can be used to generate cloud configs like this:

```
$ ./build-cloud-config.sh controller 10.10.10.1/24 10.10.10.254
...
$ ./build-cloud-config.sh worker1 10.10.10.2/24 10.10.10.1
...
$ ./build-cloud-config.sh worker2 10.10.10.3/24 10.10.10.1
...
$ ./build-cloud-config.sh example.com 10.10.10.128/24 10.10.10.1
...
```
$ ./build-image.sh inventory/node-controller
```

It is also possible to use multiple controller machines, which have to be balanced over one DNS hostname.

Read my [blog article about deploying kubernetes](http://stytex.de/blog/2017/01/25/deploy-kubernetes-to-bare-metal-with-nginx/)

--
-- virt / virsh
--
@PC
 ./build-cloud-config.sh controller1 controller1.local dhcp
 ./build-cloud-config.sh controller2 controller2.local dhcp
 ./build-cloud-config.sh controller3 controller3.local dhcp
 ./updatemasters.sh
 ./build-cloud-config.sh worker1 worker1.local controller1.local
 ./build-cloud-config.sh worker2 worker2.local controller1.local
 ./build-cloud-config.sh worker3 worker3.local controller1.local
 ./updatemasters.sh

----
@XEN
virsh:
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

----
@PC
scp inventory/node-controller1/config.iso michal@145.239.253.207:~/node-controller1.iso
scp inventory/node-controller2/config.iso michal@145.239.253.207:~/node-controller2.iso
scp inventory/node-controller3/config.iso michal@145.239.253.207:~/node-controller3.iso
scp inventory/node-worker1/config.iso michal@145.239.253.207:~/node-worker1.iso
scp inventory/node-worker2/config.iso michal@145.239.253.207:~/node-worker2.iso
scp inventory/node-worker3/config.iso michal@145.239.253.207:~/node-worker3.iso

----
@XEN
mv /home/michal/*.iso /var/lib/libvirt/images/
chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/*.iso

@PC
virt-install --connect qemu+ssh://michal@145.239.253.207/system -n controller1 --memory 4096 --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/controller1.img --network network=internal --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-controller1.iso
virt-install --connect qemu+ssh://michal@145.239.253.207/system -n controller2 --memory 4096 --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/controller2.img --network network=internal --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-controller2.iso
virt-install --connect qemu+ssh://michal@145.239.253.207/system -n controller3 --memory 4096 --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/controller3.img --network network=internal --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-controller3.iso
virt-install --connect qemu+ssh://michal@145.239.253.207/system -n worker1 --memory 10240 --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/worker1.img --network network=internal --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-worker1.iso
virt-install --connect qemu+ssh://michal@145.239.253.207/system -n worker2 --memory 10240 --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/worker2.img --network network=internal --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-worker2.iso
virt-install --connect qemu+ssh://michal@145.239.253.207/system -n worker3 --memory 10240 --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/worker3.img --network network=internal --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-worker3.iso


-------------------------------------


ip=192.168.115.2
cluster=testcoreos; vm=1
./build-cloud-config.sh controller$vm $ip/24 192.168.115.1
ip=192.168.115.3
cluster=testcoreos; vm=2
./build-cloud-config.sh controller$vm $ip/24 192.168.115.1
ip=192.168.115.4
cluster=testcoreos; vm=3
./build-cloud-config.sh controller$vm $ip/24 192.168.115.1
./updatemasters.sh
ip=192.168.115.2
cluster=testcoreos; vm=1
sudo cp -a /var/lib/libvirt/images/coreos_production_openstack_image.img /var/lib/libvirt/images/$cluster$vm.img
sudo cp ~/developer/concrete/coreos/kubernetes-coreos-baremetal-cloudconfig/inventory/node-controller$vm/config.iso /var/lib/libvirt/images/${cluster}${vm}config.iso
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/$cluster$vm.img /var/lib/libvirt/images/${cluster}${vm}config.iso
virt-install --connect qemu:///system -n $cluster$vm --memory 2048 --vcpus=2 --disk /var/lib/libvirt/images/$cluster$vm.img --network network=kube --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/${cluster}${vm}config.iso
ssh-keygen -f "/home/michalzxc/.ssh/known_hosts" -R $ip
./configure-kubectl.sh $ip
ip=192.168.115.3
cluster=testcoreos; vm=2
sudo cp -a /var/lib/libvirt/images/coreos_production_openstack_image.img /var/lib/libvirt/images/$cluster$vm.img
sudo cp ~/developer/concrete/coreos/kubernetes-coreos-baremetal-cloudconfig/inventory/node-controller$vm/config.iso /var/lib/libvirt/images/${cluster}${vm}config.iso
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/$cluster$vm.img /var/lib/libvirt/images/${cluster}${vm}config.iso
virt-install --connect qemu:///system -n $cluster$vm --memory 2048 --vcpus=2 --disk /var/lib/libvirt/images/$cluster$vm.img --network network=kube --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/${cluster}${vm}config.iso
ssh-keygen -f "/home/michalzxc/.ssh/known_hosts" -R $ip
ip=192.168.115.4
cluster=testcoreos; vm=3
sudo cp -a /var/lib/libvirt/images/coreos_production_openstack_image.img /var/lib/libvirt/images/$cluster$vm.img
sudo cp ~/developer/concrete/coreos/kubernetes-coreos-baremetal-cloudconfig/inventory/node-controller$vm/config.iso /var/lib/libvirt/images/${cluster}${vm}config.iso
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/$cluster$vm.img /var/lib/libvirt/images/${cluster}${vm}config.iso
virt-install --connect qemu:///system -n $cluster$vm --memory 2048 --vcpus=2 --disk /var/lib/libvirt/images/$cluster$vm.img --network network=kube --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/${cluster}${vm}config.iso
ssh-keygen -f "/home/michalzxc/.ssh/known_hosts" -R $ip

ip=192.168.115.5
cluster=testcoreos; vm=4
./build-cloud-config.sh worker$vm $ip/24 192.168.115.2
sudo cp -a /var/lib/libvirt/images/coreos_production_openstack_image.img /var/lib/libvirt/images/$cluster$vm.img
sudo cp ~/developer/concrete/coreos/kubernetes-coreos-baremetal-cloudconfig/inventory/node-worker$vm/config.iso /var/lib/libvirt/images/${cluster}${vm}config.iso
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/$cluster$vm.img /var/lib/libvirt/images/${cluster}${vm}config.iso
virt-install --connect qemu:///system -n $cluster$vm --memory 2048 --vcpus=2 --disk /var/lib/libvirt/images/$cluster$vm.img --network network=kube --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/${cluster}${vm}config.iso
ssh-keygen -f "/home/michalzxc/.ssh/known_hosts" -R $ip

ip=192.168.115.6
cluster=testcoreos; vm=5
./build-cloud-config.sh worker$vm $ip/24 192.168.115.2
sudo cp -a /var/lib/libvirt/images/coreos_production_openstack_image.img /var/lib/libvirt/images/$cluster$vm.img
sudo cp ~/developer/concrete/coreos/kubernetes-coreos-baremetal-cloudconfig/inventory/node-worker$vm/config.iso /var/lib/libvirt/images/${cluster}${vm}config.iso
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/$cluster$vm.img /var/lib/libvirt/images/${cluster}${vm}config.iso
virt-install --connect qemu:///system -n $cluster$vm --memory 2048 --vcpus=2 --disk /var/lib/libvirt/images/$cluster$vm.img --network network=kube --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/${cluster}${vm}config.iso
ssh-keygen -f "/home/michalzxc/.ssh/known_hosts" -R $ip

ip=192.168.115.7
cluster=testcoreos; vm=6
./build-cloud-config.sh worker$vm $ip/24 192.168.115.2
sudo cp -a /var/lib/libvirt/images/coreos_production_openstack_image.img /var/lib/libvirt/images/$cluster$vm.img
sudo cp ~/developer/concrete/coreos/kubernetes-coreos-baremetal-cloudconfig/inventory/node-worker$vm/config.iso /var/lib/libvirt/images/${cluster}${vm}config.iso
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/$cluster$vm.img /var/lib/libvirt/images/${cluster}${vm}config.iso
virt-install --connect qemu:///system -n $cluster$vm --memory 2048 --vcpus=2 --disk /var/lib/libvirt/images/$cluster$vm.img --network network=kube --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/${cluster}${vm}config.iso
ssh-keygen -f "/home/michalzxc/.ssh/known_hosts" -R $ip

-- delete
ip=192.168.115.2
cluster=testcoreos; vm=1
vid=$(virsh --connect qemu:///system list|egrep "\s$cluster$vm\s"|awk '{print $1}')
virsh --connect qemu:///system destroy $vid
virsh --connect qemu:///system undefine $cluster$vm
ip=192.168.115.3
cluster=testcoreos; vm=2
vid=$(virsh --connect qemu:///system list|egrep "\s$cluster$vm\s"|awk '{print $1}')
virsh --connect qemu:///system destroy $vid
virsh --connect qemu:///system undefine $cluster$vm
ip=192.168.115.4
cluster=testcoreos; vm=3
vid=$(virsh --connect qemu:///system list|egrep "\s$cluster$vm\s"|awk '{print $1}')
virsh --connect qemu:///system destroy $vid
virsh --connect qemu:///system undefine $cluster$vm
ip=192.168.115.5
cluster=testcoreos; vm=4
vid=$(virsh --connect qemu:///system list|egrep "\s$cluster$vm\s"|awk '{print $1}')
virsh --connect qemu:///system destroy $vid
virsh --connect qemu:///system undefine $cluster$vm
cluster=testcoreos; vm=5
vid=$(virsh --connect qemu:///system list|egrep "\s$cluster$vm\s"|awk '{print $1}')
virsh --connect qemu:///system destroy $vid
virsh --connect qemu:///system undefine $cluster$vm
cluster=testcoreos; vm=6
vid=$(virsh --connect qemu:///system list|egrep "\s$cluster$vm\s"|awk '{print $1}')
virsh --connect qemu:///system destroy $vid
virsh --connect qemu:///system undefine $cluster$vm
rm inventory -Rf; mkdir inventory
rm ssl -Rf; mkdir ssl
