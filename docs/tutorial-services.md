# Tutorial 6: Services and ports

[User guide](README.md) > Tutorial 6: Services and ports

In about ten minutes you will:
- run a web server in a VM and open it from your Mac;
- see what happens when a service's process ends;
- let a second VM, with no internet, reach one service on your Mac and
  nothing else.

**You'll learn:** `koala create --mode service`, `--publish` and
`--host-service`, and what a VM can reach by default.

Every command and every output on this page comes from a real run. IDs will
differ.

## Before you start

- Koala is installed and running ([Tutorial 1](tutorial-first-vm.md)).
- Ports 8080 and 8765 on your Mac are free. If they aren't, use others
  throughout.
- Make a folder to work in:

<!-- tutorial: skip -->
```console
$ mkdir koala-services-tutorial && cd koala-services-tutorial
```

## Step 1: Run a web server and open it from your Mac

A **service** VM runs one main command: the image's own, or one you give
after `--`. `--publish 8080:80` makes port 80 in the VM answer on port 8080
of your Mac:

```console
$ koala create web --image docker.io/library/busybox:latest --mode service --publish 8080:80 --wait -- sh -c 'mkdir -p /www && echo "hello from the VM" > /www/index.html && exec httpd -f -p 80 -h /www'
publish tcp 127.0.0.1:8080 -> 80 (loopback)
internet on
accepted operation b99714ab-5cb3-4f19-a6f9-817a8270d769 (vm.create)
succeeded b99714ab-5cb3-4f19-a6f9-817a8270d769
$ koala start web --wait
accepted operation a543fbfd-74d1-4feb-a21f-cfa9d9762919 (vm.start)
succeeded a543fbfd-74d1-4feb-a21f-cfa9d9762919
$ curl -s http://127.0.0.1:8080/
hello from the VM
```

`(loopback)`: the port listens on `127.0.0.1`, so only programs on your Mac
can reach it, not other machines on your network. (To open it to your
network, publish on `0.0.0.0:8080:80`; see [Networking](networking.md#publish-a-port).)

```console
$ koala inspect web
web (65dd63ac-06ce-466a-870b-c726ff75c96a)
  state      Running
  mode       service, lean profile
  image      docker.io/library/busybox:latest
             … digest sha256:365a051f12e0…
  resources  1 vCPU, 256 MiB memory, 1 GiB disk
  command    the image's entrypoint, with: sh -c 'mkdir -p /www && echo "hello from the VM" > /www/index.html && exec httpd -f -p 80 -h /www'
  user       the image's
  internet   on
  grants     none
  published  127.0.0.1:8080 -> 80/tcp (loopback)
  volumes    none
  shares     none
  secrets    none
  run        4561072c-3092-4d2c-bdc3-933d5000a199
             primary execution ce4c60b6-60a3-558f-b966-8444c9c5db07
  spec       generation 1; cleanup: retain
```

## Step 2: When the service's process ends

A service VM lives as long as its main command. Stop the web server from
inside, and the VM stops too:

```console
$ koala exec web -- killall httpd
$ sleep 3; koala list
ID                                    NAME                 MODE         STATE              GEN
…
65dd63ac-06ce-466a-870b-c726ff75c96a  web                  service      Stopped            1
```

Koala doesn't restart it on its own. The VM keeps its disk and settings, so
start it again:

```console
$ koala start web --wait
accepted operation 791d1183-a9c6-4141-8f40-074c5bb60b43 (vm.start)
succeeded 791d1183-a9c6-4141-8f40-074c5bb60b43
$ curl -s http://127.0.0.1:8080/
hello from the VM
```

## Step 3: Let a VM reach one service on your Mac

By default a VM can reach the internet, but **not** your Mac, your network
or other VMs. Make a small service on your Mac to try it with:

```console
$ mkdir site && echo "hello from your Mac" > site/hello.txt
```

In a **second Terminal window**, in the same folder, start a web server on
your Mac's loopback address, and leave it running:

<!-- tutorial: skip -->
```console
$ python3 -m http.server 8765 --bind 127.0.0.1 --directory site
```
<!-- tutorial-run: (python3 -m http.server 8765 --bind 127.0.0.1 --directory site >/dev/null 2>&1 & echo $! > .t6-server.pid); sleep 1 -->

Back in the first window, check it answers:

```console
$ curl -s http://127.0.0.1:8765/hello.txt
hello from your Mac
```

Now make a VM with no internet that may reach that one port,
`--host-service 127.0.0.1:8765`:

```console
$ koala create client --image docker.io/library/alpine:3 --no-internet --host-service 127.0.0.1:8765 --wait
internet off
host-service 127.0.0.1:8765/tcp
accepted operation 0a8b4ee0-93af-4918-9ac5-85155c07168d (vm.create)
succeeded 0a8b4ee0-93af-4918-9ac5-85155c07168d
$ koala start client --wait
accepted operation 4c703df3-754c-4702-91fe-ab3176196c12 (vm.start)
succeeded 4c703df3-754c-4702-91fe-ab3176196c12
```

Inside the VM, your Mac's service is `host-1.koala.internal` (the second
`--host-service` address would be `host-2`, and so on):

```console
$ koala exec client -- wget -qO- http://host-1.koala.internal:8765/hello.txt
hello from your Mac
```

Only that port. Another port on your Mac is refused, and so is the
internet:

<!-- tutorial: fails -->
```console
$ koala exec client -- wget -qO- -T 5 http://host-1.koala.internal:8766/
wget: can't connect to remote host (198.19.0.1): Connection refused
koala: execution ed775dce-09d3-42bf-ac16-c2d38b915352 exited (exit 1)
$ koala exec client -- wget -qO- -T 5 http://example.com/
wget: bad address 'example.com'
koala: execution 520b9cc5-c51d-4704-83ea-635d8a77bc5f exited (exit 1)
```

And a VM without the grant can't reach your Mac at all, even though it has
internet:

<!-- tutorial: fails -->
```console
$ koala exec web -- wget -qO- -T 5 http://host-1.koala.internal:8765/hello.txt
wget: bad address 'host-1.koala.internal:8765'
koala: execution 20b44606-ea33-4d40-8189-010959d7b4f4 exited (exit 1)
```

## Clean up

```console
$ koala stop web --wait
accepted operation 4d6e2437-891f-4778-9101-f3dcd0c672a1 (vm.stop)
succeeded 4d6e2437-891f-4778-9101-f3dcd0c672a1
$ koala rm web --wait
accepted operation 44b2d4ee-c6cb-4515-a629-5c7b3edbd250 (vm.remove)
succeeded 44b2d4ee-c6cb-4515-a629-5c7b3edbd250
$ koala stop client --wait
accepted operation ab6773cf-9168-4253-82b1-8e0323934e1b (vm.stop)
succeeded ab6773cf-9168-4253-82b1-8e0323934e1b
$ koala rm client --wait
accepted operation 400b4855-5efd-4bd8-9295-b1444ce9a5b8 (vm.remove)
succeeded 400b4855-5efd-4bd8-9295-b1444ce9a5b8
```

Stop the web server in the second window with Ctrl-C, then:

<!-- tutorial-run: kill $(cat .t6-server.pid) && rm .t6-server.pid -->
```console
$ rm -r site
```

<!-- tutorial: skip -->
```console
$ cd .. && rm -r koala-services-tutorial
```

## What you learned

| What | How |
|---|---|
| Run a service | `koala create NAME --image IMAGE --mode service [-- COMMAND]`; the VM stops when its command ends |
| Open a VM's port on your Mac | `--publish HOST_PORT:VM_PORT` (loopback only); `--publish 0:VM_PORT` picks a free port |
| Let a VM reach a service on your Mac | `--host-service 127.0.0.1:PORT`, then `host-1.koala.internal:PORT` in the VM |
| Switch the internet off | `--no-internet`; grants still work |
| By default | Internet yes; your Mac, your network and other VMs no |

## Next

**Next tutorial:** [Tutorial 7: Look after your VMs](tutorial-look-after.md).

More on this page's topics:

- [Networking](networking.md): LAN grants, UDP, publishing to your network,
  and spec files.
- [Jobs and VMs](vms.md): the three modes, and VMs from a file.
