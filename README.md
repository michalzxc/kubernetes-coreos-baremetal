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
ip=192.168.115.2
cluster=testcoreos; vm=1
./build-cloud-config.sh controller $ip/24 192.168.115.1
sudo cp -a /var/lib/libvirt/images/coreos_production_openstack_image.img /var/lib/libvirt/images/$cluster$vm.img
sudo cp ~/developer/concrete/coreos/kubernetes-coreos-baremetal-cloudconfig/inventory/node-controller/config.iso /var/lib/libvirt/images/${cluster}${vm}config.iso
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/$cluster$vm.img /var/lib/libvirt/images/${cluster}${vm}config.iso
virt-install --connect qemu:///system -n $cluster$vm --memory 2048 --vcpus=2 --disk /var/lib/libvirt/images/$cluster$vm.img --network network=kube --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/${cluster}${vm}config.iso
ssh-keygen -f "/home/michalzxc/.ssh/known_hosts" -R $ip
./configure-kubectl.sh $ip
ip=192.168.115.3
cluster=testcoreos; vm=2
./build-cloud-config.sh worker$vm $ip/24 192.168.115.2
sudo cp -a /var/lib/libvirt/images/coreos_production_openstack_image.img /var/lib/libvirt/images/$cluster$vm.img
sudo cp ~/developer/concrete/coreos/kubernetes-coreos-baremetal-cloudconfig/inventory/node-worker$vm/config.iso /var/lib/libvirt/images/${cluster}${vm}config.iso
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/$cluster$vm.img /var/lib/libvirt/images/${cluster}${vm}config.iso
virt-install --connect qemu:///system -n $cluster$vm --memory 2048 --vcpus=2 --disk /var/lib/libvirt/images/$cluster$vm.img --network network=kube --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/${cluster}${vm}config.iso
ssh-keygen -f "/home/michalzxc/.ssh/known_hosts" -R $ip
ip=192.168.115.4
cluster=testcoreos; vm=3
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
rm inventory -Rf; mkdir inventory
rm ssl -Rf; mkdir ssl
