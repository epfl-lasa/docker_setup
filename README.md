# docker_setup

This repository contains examples and scripts to help build docker images. The content of the [scripts folder](./scripts) can be copied to any repository and adapted to build a supporting Docker image. The files are described below and we define set of rules for building proper images.

The basic principle of Docker is expected to be known beforehand. In this documentation we refer to the computer on which the image is created as host. Docker creates an image from a Dockerfile, and a running instance of this image is called a container.

## Dockerfile

This is the most important file for building a Docker image. See this is as a cook recipe where you inform the image compiler about the steps that have to be performed during the build process. Check the [official documentation](https://docs.docker.com/engine/reference/builder/) for specific commands. Most common ones are:

### FROM

This is usually the first line of the Dockerfile. It specifies on which image the current image will be built upon. See this as specifying wich Operating System you want to install on your machine. Although, remember that on a Linux host computer, you will only be able to build Linux based images (Docker and the host machine share the same Operating System).

For example, if you want to base the image on Ubuntu 20.04 you will specify:

```
FROM ubuntu:20.04
```

This will pull the image from the [ubuntu registry](https://hub.docker.com/_/ubuntu) corresponding to the tag sepcified after the `:` (here 20.04). If no tag is specified, it will download the one corresponding to `latest`.

You can build an image on top of any existing images either on [Dockerhub](https://hub.docker.com/), private registry or locally. By default, Docker first search if an image corresponding to the name & tag specified exists in your local registry. If not, it will pull it from [Dockerhub public registries](https://hub.docker.com/). If none are found it returns an error.

As an example, you can build an image on top of an official ROS image, corresponding to the ROS distribution of your choice:

```dockerfile
FROM ros:kinetic-ros-core
```

will pull the `kinetic-ros-core` image on [ROS registry](https://hub.docker.com/_/ros).

Some images, specified as `alpine` are specifically designed to be light weight versions of specific images. It is interesting to use them when disk usage is an issue (e.g. on embedded systems). 


### RUN

The `RUN` command execut the script command written after. It is similar to executing a command in a terminal. For example `RUN echo 'Hello world'` will output 'Hello world'. Note that comments, prefixed by `#` are not executed. Therefore, 


```dockerfile
RUN echo hello \
# comment
world
```

produces a similar result. Generally, use the `RUN` command to install a specific package clone a repository. Any valid command in a terminal is valid after the `RUN` command.

As Docker executes commands line by line and store each results, it is recommended to group commands in single line as much as possible. This saves size in the ouptut image. For example, prefer installing all packages in one single line at the beginning of the file such as:

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

Please not the last line `rm -rf /var/lib/apt/lists/*`. Again, this is good practice to use after installing a package. It delete the cache made `apt update` to save some space. However, if you want or need to install another package afterwards, you will need to re-run `apt update`. This is one of the reasons why it is recommended to run all installations in one batch, as it saves both time and space.

### ENV

The `ENV` command create an environment variable that can be used later in the Dockerfile, but also in the executed container. Syntax for using `ENV` is

```dockerfile
ENV MYVAR value
```

It is a shortcut for 

```dockerfile
RUN export MYVAR=value
```

It is usually used to specify environment variables such as `PYTHON_PATH` or `LD_LIBRARY_PATH` needed for compilation.

### ARG

The `ARG` command is used to define local variables in the scope of the Dockerfile. As opposed to `ENV` variables they will not be valid in the container at runtime. Syntax is a bit different compared to `ENV`:

```dockerfile
ARG MYVAR=value
```

Any variables defined as `ARG` can also be set at build time. This the way to build template Dockerfile where you can specify specific values when needed during the build process.

### WORKDIR

This is the command to move into a folder and creating it if non existing. For example:

```dockerfile
WORKDIR /home/ros/ros_ws
```

is the equivalent of running

```dockerfile
RUN mkdir -p /home/ros/ros_ws $$ cd /home/ros/ros_ws
```

Note that the folder is always created as `root` user (default user is `root` in Docker). If you specify another user in the container, prefers the usage of `mkdir` command but you can still use `WORKDIR` to move to the folder after it has been created.

### USER

As said above, default user is `root`. It is recommended, for safety reasons, to create another user in the container and run commands as this user. This is done in two steps. First create the group and user:

```dockerfile
ENV USER ros
ARG UID=1000
ARG GID=1000
RUN addgroup --gid ${GID} ${USER}
RUN adduser --gecos "ROS User" --disabled-password --uid ${UID} --gid ${GID} ${USER}
RUN usermod -a -G dialout ${USER}
```

This blocks create an environment variable `USER` with value `ros` and create this user with specific `uid` and `gid`. By default, those values will be 1000 but can be changed at build time by passing the values in the build command (see below). This specific way of creating a user is important if you need the user in the container to match a specific user on the host (defined by its `uid` and `gid`), for example for files shared between the container and the host.

After the user is created it can be invoked with:

```dockerfile
USER ros
```

Shifting back to root user is:

```dockerfile
USER root
```

### COPY

This command is used to copy files either from another image or from the host machine. For example, copying the content of folder from the host is done with:

```dockerfile
COPY --chown=${USER} /path_to_folder /destination_path
```

This will copy the content of the folder at `/path_to_folder` on the host in `/destination_path` in the container. Note that specifying the user ensures that the copy has the correct permissions. Otherwise it is executed as `root`.

### Specific commands or usages

Previous commands cover the basics for building docker images. However, there are sometime some more tricks needed for specific configurations:

#### Non interactive mode

Docker does not handle interaction, for example the need to specify arguments during a building or installation process. Each commands need to be executed without interruption. It might be needed, for package installation to specify that the package control manager has to be run in non interactive mode. This is done with:

```dockerfile
ENV DEBIAN_FRONTEND=noninteractive
```

This is not recommended to use but might be needed and can be a life saver.

#### Graphical mode

By default, Docker runs in headless mode (no graphics). However, if you need to open a graphical application in the container, you will need to share the graphics manager of the host. Simply add the command

```dockerfile
ENV QT_X11_NO_MITSHM 1
```

There are additional steps needed at runtime (see below).