## Foam-Extend-4.1 with Docker

Allows for running multiple (SSH-connected) Docker containers which have Foam-extend-4.1 (nextRelease branch)
compiled with system OpenMPI (Ubuntu 20.04).

Shamelessly based on [docker.openmpi](https://github.com/oweidner/docker.openmpi).
We don't really need their MPI4Py so I'm not keeping it.


### MPI-powered FE4 Container Cluster with `docker-compose`

An example of a [Docker Compose YML file](docker-compose.yml) (Version 2) is provided
to define:

- A **master** container (should instantiate only 1 of those) which 
   can be accessed from the host machine on SSH port 2222 (This binds to 22 inside the container).
- A number of **slave** containers which are all linked to the master.

Both container types will share a Docker volume (called `data`) and mount it at the same location
(`/data`). They all start up at this location, acting as the user `openfoam` which has root
privileges and Foam Extend 4.1 sourced.

> Note: All docker-compose commands are meant to be executed in a directory holding
> the docker-compose.yml file


Strictly speaking, all you have to do to bootstrap your make-believe cluster is:
```
> git clone https://github.com/FoamScience/foam-extend-4.1-openmpi mpi-cluster
> cd mpi-cluster
> docker-compose up -d --scale master=1 --scale slave=3
```

But to be able to run MPI jobs with Foam extend 4.1 solvers, I recommend writing
a simple script (Example: [createCluster.sh](createCluster.sh)) which you execute
to properly setup each master and slave node. This mainly involves:

- Fixing auto-generated `hostnames` as OpenMPI doesn't like underscores in them.
- Compiling your own libraries/solvers on each node
- Copying case files to `/data` (Should be done on only one node)

> Note that the `/data` volume is "shared" between all containers,
> which makes life easier when it's time to run the OpenFOAM case

When you're done, `docker-compose down` will tear down the cluster but the `data`
volume will be preserved (Running `./createCluster.sh` again will link to the same volume).

### How do I run my cases?

Assuming you're on Alpine Linux,


0. Get the files:
   ```
   > apk add jq
   > git clone https://github.com/FoamScience/foam-extend-4.1-openmpi mpi-cluster
   > cd mpi-cluster
   ```
1. In `createCluster.sh` file:
   - Change `LIB_TAR_URL` if you want to compile an external library
   - Change `CASE_URL` (should point to a TAR file) if you want to get the case on cluster creation
   - Change `SLAVES_NUM` to reflect the number of slaves you want to spawn
2. Then (Will take some time, needs to pull a 900MB image and can peacefully omit some bash warnings):
   ```
   > ./createCluster.sh
   ```
3. Run `docker ps -a` to make sure everything is running fine.
4. You can access the cluster through its master node. Once inside the container,
   you can prepare a hosts file (from `/etc/hosts`) and run your case with it:
   ```
   > docker-compose exec master bash
   (openfoam:/data)> cd case
   (openfoam:/data)> mpirun --hostfile hosts solver -parallel
```

### All good, but I don't want to compile libraries on each node each time

If your libraries are getting larger, you can pick the [Dockerfile](Dockerfile),
add commands to get and compile your libraries towards the end, and push a new image.

The sample `docker-compose.yml` file uses a pre-generated `foamscience/foam-extend-4.1-openmpi`
image from Docker Hub. You can replace that with your new image and all containers will have
your library pre-compiled.
