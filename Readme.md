## Foam-Extend-4.1 with Docker

Allows for running multiple (SSH-connected) docker containers which have Foam-extend-4.1 (nextRelease branch)
compiled with system OpenMPI (Ubuntu 18.04).

Shamelessly based on [docker.openmpi](https://github.com/oweidner/docker.openmpi).
We don't really need their MPI4Py but It's nice to have it, so I'm keeping it.


## MPI-powered FE4 Container Cluster with `docker-compose`

Put something like this in a `docker-compose.yml` file:

```
master:
  image: fe4-openmpi
  ports: 
   - "22"
  volumes:
   - data:/data
  links: 
   - slave

slave: 
  image: fe4-openmpi
  volumes:
   - data:/data

volumes:
  data:
    external: true
```
(Note: the above is docker-compose API version 1)

With this, you define a master container (should instantiate only 1 of those) which is
linked to some slave containers (you can get as many as you want),
and can be accessed from the host machine on SSH port 22. Both container types will mount
an external volume (called data) at `/data`.

For the impatient, bootstrap your make-believe cluster with (In case of 4 CPUs for example):
```
> docker volume create data
> docker-compose scale master=1 slave=3
```

Now, you can SSH-copy your libraries/cases from your host to `/data` of the master node, and you're all set!
