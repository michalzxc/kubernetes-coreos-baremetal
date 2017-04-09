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
