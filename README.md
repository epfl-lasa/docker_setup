# docker_setup

This repository contains examples and scripts to help build docker images. The content of the [scripts folder](./scripts) can be copied to any repository and adapted to build a supporting Docker image. The files are described below and we define set of rules for building proper images.

The basic principle of Docker is expected to be known beforehand (if not, read a short introduction [here](https://docs.docker.com/get-started/overview/)). In this documentation we refer to the computer on which the image is created as host. Docker creates an image from a `Dockerfile`, and a running instance of this image is called a container. A registry, either local or online, is the place where prebuilt images are stored. The most common online registry is [dockerhub](https://hub.docker.com/) and is directly connected with Docker client.

## Dockerfile

This is the most important file for building a Docker image. See this is as a cook recipe where you inform the image compiler about the steps that have to be performed during the build process. Check the [official documentation](https://docs.docker.com/engine/reference/builder/) for specific commands. Most common ones are:

### FROM

This is usually the first line of the `Dockerfile`. It specifies on which image the current image will be built upon. See this as specifying which operating system you want to install on your machine. Although, remember that on a Linux host computer, you will only be able to build Linux based images (Docker and the host machine share the same operating system).

For example, if you want to base the image on Ubuntu 20.04 you will specify:

```
FROM ubuntu:20.04
```

This will pull the image from the [Ubuntu registry](https://hub.docker.com/_/ubuntu) corresponding to the tag sepcified after the `:` (here 20.04). If no tag is specified, it will download the one corresponding to `latest`.

You can build an image on top of any other existing image coming from [dockerhub](https://hub.docker.com/), a private registry or  aved locally. By default, Docker first checks if an image corresponding to the name & tag specified exists in your local registry. If not, it will pull it from [Dockerhub public registries](https://hub.docker.com/). If none are found, it returns an error.

As an example, you can build an image on top of an official ROS image, corresponding to the ROS distribution of your choice:

```dockerfile
FROM ros:kinetic-ros-core
```

will pull the `kinetic-ros-core` image on [ROS registry](https://hub.docker.com/_/ros).

Some images, specified as `alpine`, are specifically designed to be light weight versions of specific images. It is interesting to use them when disk usage is an issue (e.g. on embedded systems). 


### RUN

The `RUN` command executes the script commands written after. It is similar to executing a series of commands in a terminal. For example `RUN echo "Hello world"` will output `"Hello world"`. Note that comments, prefixed by `#` and linebreak (`\`) are not executed. Therefore, 


```dockerfile
RUN echo hello \
# comment
world
```

produces a similar result. Generally, use the `RUN` command to install a specific package or clone a repository. Any valid command in a terminal is valid after the `RUN` command.

As Docker executes commands line by line and stores each results, it is recommended to group commands in single line as much as possible. This saves size in the ouptut image. For example, prefer installing all packages in one single line at the beginning of the file such as:

```dockerfile
RUN apt update && apt install -y \
  sudo \
  autoconf \
  automake \
  libtool \
  curl \
  make \
  g++ \
  && rm -rf /var/lib/apt/lists/*
```

Note the last line `rm -rf /var/lib/apt/lists/*`. Again, this is good practice to use after installing a package. It deletes the cache made by the `apt update` call to save some space. However, if you want or need to install another package afterwards, you will need to re-run `apt update`. This is one of the reasons why it is recommended to run all installations in one batch, as it saves both time and space.

### ENV

The `ENV` command creates an environment variable that can be used later in the `Dockerfile`, but also in the executed container. Syntax for using `ENV` is

```dockerfile
ENV MYVAR value
```

It is a shortcut for 

```dockerfile
RUN export MYVAR=value
```

It is usually used to specify environment variables such as `PYTHON_PATH` or `LD_LIBRARY_PATH` needed for compilation.

### ARG

The `ARG` command is used to define local variables in the scope of the `Dockerfile`. As opposed to `ENV` variables they will not be valid in the container at runtime. Syntax is a bit different compared to `ENV`:

```dockerfile
ARG MYVAR=value
```

Any variable defined as `ARG` can also be set at build time. This the way to build templated `Dockerfile` where you can specify specific values when needed during the build process (see passing arguments in the building step below).

### WORKDIR

This is the command to move into a folder and creating it if non-existing. For example:

```dockerfile
WORKDIR /home/ros/ros_ws
```

is the equivalent of running

```dockerfile
RUN mkdir -p /home/ros/ros_ws $$ cd /home/ros/ros_ws
```

Note that the folder is always created as `root` user (default user is `root` in Docker). If you specify another user in the container, prefer the usage of `mkdir` command to give the correct permissions to the created folder. You can still use `WORKDIR` to move to the folder after it has been created as it is preferable compared to using `RUN cd ...`.

### USER

As said above, default user is `root`. It is recommended, for safety reasons, to create another user in the container and run commands as this user. This is done in two steps. First create the group and user:

```dockerfile
ENV USER myuser
ARG UID=1000
ARG GID=1000
RUN addgroup --gid ${GID} ${USER}
RUN adduser --gecos "My User" --disabled-password --uid ${UID} --gid ${GID} ${USER}
RUN usermod -a -G dialout ${USER}
```

This blocks create an environment variable `USER` with value `myuser` and create this user with specific `uid` and `gid`. By default, those values will be 1000 but can be changed at build time by passing the values in the build command (see below). This specific way of creating a user is important if you need the user in the container to match a specific user on the host (defined by its `uid` and `gid`), for example for files shared between the container and the host.

After the user is created it can be invoked with:

```dockerfile
USER myuser
```

Shifting back to `root` user is:

```dockerfile
USER root
```

### COPY

This command is used to copy files either from another image or from the host machine. For example, copying the content of a folder from the host is done with:

```dockerfile
COPY --chown=${USER} /path_to_folder /destination_path
```

This will copy the content of the folder at `/path_to_folder` on the host in `/destination_path` in the container. Note that `--chown=${USER}` specifies to copy as the user to ensure that the copy has the correct permissions. Otherwise it is executed as `root`.

### Entrypoint

TODO

### CMD

TODO

### Specific commands or usages

Previous commands cover the basics for building docker images. However, there are some more tricks needed for specific configurations:

#### Non-interactive mode

Docker does not handle interactions, for example the need to specify arguments during a building or installation process. Each commands need to be executed without interruption. It might be needed, for package installation to specify that the package control manager has to be run in non-interactive mode. This is done with:

```dockerfile
ENV DEBIAN_FRONTEND=noninteractive
```

This is not recommended to use but might be needed and can be a life saver.

### To conclude

This covers the basics to create a Docker image from a `Dockerfile`. We will now describe the build and run process to build the image and run a container from it.

# Building the image

The simplest command to build the image is to run

```bash
docker build .
```

in the folder where the `Dockerfile` is located. It will execute all the commands in the `Dockerfile` and build the image. However, it might be needed to add specific arguments. This is the reason we prefer using a [build](./scripts/build.sh) that simplifies the building call. Below are some specificities that can be added or removed from the script to fit your needs.

## Naming the image and tag

If not specified, name and tag of the image will be a unique id chosen by Docker as a very long integer. This is not ideal as you might need to build another image on top of the one you have just created. Therefore, naming the created image is very important. This can be done with:

```bash
docker build -t "${NAME}:${TAG}" .
```

where `${NAME}` and `${TAG}` are variables specified before. By default, we consider in the [build](./scripts/build.sh) script that the name of the image corresponds to the current folder. It is automatically extracted with:

```bash
NAME=$(echo "${PWD##*/}" | tr _ -)
```

This also changes `_` to `-` to match docker naming conventions.

## Passing arguments to the Dockerfile

Any `ARG` variable defined in the `Dockerfile` can be set at build time with the command argument `--build-arg MYVAR=value`. For example, passing the `uid` and `gid` of the host user can be done with:

```bash
UID="$(id -u "${USER}")"
GID="$(id -g "${USER}")"
docker build \
        --no-cache \
        --build-arg UID="${UID}" \
        --build-arg GID="${GID}" \
        .
```

## Pulling the base image

As seen in the `Dockerfile`, a Docker image is always based on top of another image. When this image is coming from a public registry, Docker automatically pulls it, if it did not find it locally. However, as soon as the local image exists, it uses this one. Meaning that if your local image is not updated regularly, you might not have the latest version of it.

One way to automate this is to add a line in the [build](./scripts/build.sh) script to force pulling the base image:

```bash
docker pull "${BASE_IMAGE}:${BASE_TAG}"
```

where `${BASE_IMAGE}` and `${BASE_TAG}` are variables specified before.

## Rebuilding the image from scratch

By default, Docker keeps a cache version of each line run in the `Dockerfile`. Imagine you modify line 66 of the `Dockerfile` this allows Docker to use the cache version for the 65 previous lines and start building after the line you have just modified, in order to save time.

However, you might want to rebuild the image without using the cache. As an example, if you have cloned a repository in the `Dockerfile` and this repository has been updated, Docker has no way of knowing this and will always use the cached version of it. Your choice is either to modify the `Dockerfile` at the line specifying the cloning (or before), but this is not desired, or rebuild the complete image without cache. Despite this approach taking longer, it is the best option and can be achieve with:

```bash
docker build --no-cache .
```

A good way to automate this is to pass an argument `-r` to the [build](./scripts/build.sh) with:

```bash
REBUILD=0

while getopts 'r' opt; do
    case $opt in
        r) REBUILD=1 ;;
        *) echo 'Error in command line parsing' >&2
           exit 1
    esac
done
shift "$(( OPTIND - 1 ))"
```

## To conclude

This concludes the basics for building an image. Obviously, those commands can be combined and written directly in the terminal. However, as you might suspect, this become quickly tedious and this is the reason we recommend using a [build](./scripts/build.sh) to simplify this process. To run the script simply do:

```bash
sh build.sh
```

with eventual arguments passed.

# Running the container

Now that the image is built, you will want to execute it, or as Docker language, run a container from it. The simplest command is:

```bash
docker run "${NAME}:${TAG}"
```

where `${NAME}` and `${TAG}` are variables specified before and correspond to an image with a valid name and tag, either locally or on a public (or private) resgistry. Now, let us see how we can extend this run command to specify more desired behaviors. Below we present some of the most useful one. Check the [official documentation](https://docs.docker.com/engine/reference/run/) for complete reference.

## Running an interactive container

By default, the run command will execute the command specified by the `CMD` command at the end of the `Dockerfile`. If this command terminates, the container is stoppped, otherwise it hangs until termination. Sometime you might also want to start an interactive container, that acts as a terminal inside the container envrionment to let you execute commands inside the container. For that you need to add:

```bash
docker run -it "${NAME}:${TAG}"
```

It is recommended to couple this with the `--rm` argument to destroy the container at exit. Otherwise, Docker will keep it alive until it is manually destroyed:

```bash
docker run -it --rm "${NAME}:${TAG}"
```

## Specifying an environment variable

Any `ENV` variables or even new environment variables can be defined at runtime. This is the same process as `ARG` variables that could be defined at build time. Remember that `ARG` variables are not valid at runtime as opposed to `ENV` ones. This is simply done with:

```bash
docker run --env MYVAR=value "${NAME}:${TAG}"
```

## Specifying a network interface

By default, containers run in an isolated network and can be pinged and access via their ids. For simplicity, you might want to specify that they should use the host network interface. You can do that with:

```bash
docker run --net=host "${NAME}:${TAG}"
```

See the [official documentation](https://docs.docker.com/network/) for more details on networking.

## Mounting a shared volume between the host and the container

This is probably the most tricky part and one of the most important. Containers and host are completly isolated and you can't access files from one another directly. The way to specify that a specific folder is shared between the host and a container is to use mounted volumes at runtime. This is a two step process. First we need to create a volume linked to a specified folder on the host:

```bash
docker volume create --driver local \
    --opt type="none" \
    --opt device="/path_to_folder" \
    --opt o="bind" \
    "${VOL_NAME}"
```

You need to specify the path of the folder (`/path_to_folder`) and a unique name for the volume. If the volume is already created it will not recreate it again. If you change the path to the folder later on you might need to first manually delete the existing volume. This volume can then be linked to any container using its unique name:

```bash
docker run --volume="${VOL_NAME}:/destination_path/:rw" "${NAME}:${TAG}"
```

Change the `/destination_path` to the folder inside the container where you want the shared volume to be stored. For sharing a file you don't need to create the volume first. You can use:

```bash
docker run --volume="$/path_to_file:/destination_file/:rw" "${NAME}:${TAG}"
```

The `rw` option provides read and write permissions. This can be changed as well.

## Running in privilege mode

By default, Docker containers are “unprivileged” and cannot, for example, run a Docker daemon inside a Docker container. This is because a container is not allowed to access any devices, but a “privileged” container is given access to all devices. This is useful to access graphics options or specific hardware. This is performed with:

```bash
docker run --privileged "${NAME}:${TAG}"
```

## Allowing graphical capacities

By default Docker containers run headlessly without possibility to use graphical capactities. Using them for opening windowed applications requires some steps at runtime. The following configuration allows this on Linux system (does not work on Mac):

```bash
xhost +
docker run \
    --privileged \
    --env DISPLAY="${DISPLAY}" \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    --env="XAUTHORITY=$XAUTH" \
    --volume="$XAUTH:$XAUTH" \
    "${NAME}:${TAG}"
```

## Sharing the graphic card

Disclaimer, this obviously works only when the computer is equiped with a Nvidia graphic card installed.

Sometimes, only sharing graphical mode is not enough and the container need to have access to the graphic card(s). This requires additional steps, the first one is to install the [Nvidia container toolkit](https://github.com/NVIDIA/nvidia-docker) by following the documentation.

Then, at runtime, the container requires additional configurations:

```bash
docker run \
    --privileged \
    --gpus all \
    --env NVIDIA_VISIBLE_DEVICES="${NVIDIA_VISIBLE_DEVICES:-all}" \
    --env NVIDIA_DRIVER_CAPABILITIES="${NVIDIA_DRIVER_CAPABILITIES:+$NVIDIA_DRIVER_CAPABILITIES,}graphics" \
    "${NAME}:${TAG}"
```

There are other options regarding memory or cpu usage. Check the [official documentation](https://docs.docker.com/config/containers/resource_constraints/) for complete reference.

## To conclude

All the options can be combined again, creating a difficult command to type everytime. This is where the [run](./scripts/run.sh) script comes in handy. As for the [build](./scripts/build.sh) script, modify it for your needs and run it with:

```bash
sh run.sh
```

with eventual arguments passed.

# Examples

As examples are worth a thousand words, you can check our [image repository](https://github.com/epfl-lasa/docker_images) that contains images for packages we work with.
