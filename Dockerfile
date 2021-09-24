# Build this image:  docker build -t fe4-mpi .
#
# Builds Foam-extend 4.1 nextRelease branch with system MPI
# from Ubuntu 20.04 LTS (focal) in Opt mode

# Base image
FROM ubuntu:20.04

# MAINTAINER of docker.openmpi: Ole Weidner <ole.weidner@ed.ac.uk>
MAINTAINER Mohammed Elwardi Fadeli <elwardifadeli@gmail.com>

# Main user
ENV USER openfoam

# Disable apt prompts and set user home
ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/home/${USER} 

# Install requirements
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends sudo apt-utils vim && \
    apt-get install -y --no-install-recommends openssh-server python-dev \
        gfortran libopenmpi-dev openmpi-bin openmpi-common openmpi-doc binutils && \
    apt-get install -y git-core build-essential binutils-dev cmake flex libfl-dev \
        zlib1g-dev libncurses5-dev curl bison \
        libxt-dev rpm mercurial graphviz gcc-7 g++-7 && \
    apt-get clean && apt-get purge && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# SSH mess
RUN mkdir /var/run/sshd
RUN echo 'root:${USER}' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# ------------------------------------------------------------
# Add an 'openfoam' user with root access
# ------------------------------------------------------------

RUN adduser --disabled-password --gecos "" ${USER} && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ------------------------------------------------------------
# Set-Up SSH with a dummy key
# ------------------------------------------------------------

ENV SSHDIR ${HOME}/.ssh/

RUN mkdir -p ${SSHDIR}

ADD ssh/config ${SSHDIR}/config
ADD ssh/id_rsa.fe4 ${SSHDIR}/id_rsa
ADD ssh/id_rsa.fe4.pub ${SSHDIR}/id_rsa.pub
ADD ssh/id_rsa.fe4.pub ${SSHDIR}/authorized_keys

RUN chmod -R 600 ${SSHDIR}* && \
    chown -R ${USER}:${USER} ${SSHDIR}

#RUN pip install --upgrade pip
#
#USER ${USER}
#RUN  pip install --user -U setuptools \
#    && pip install --user mpi4py

# ------------------------------------------------------------
# Configure OpenMPI and set ownership on /data
# ------------------------------------------------------------

USER root

RUN rm -fr ${HOME}/.openmpi && mkdir -p ${HOME}/.openmpi
ADD default-mca-params.conf ${HOME}/.openmpi/mca-params.conf
RUN chown -R ${USER}:${USER} ${HOME}/.openmpi
RUN mkdir /data
RUN chown -R ${USER}:${USER} /data

# ------------------------------------------------------------
# Let's not Copy MPI4PY example scripts
# ------------------------------------------------------------

ENV TRIGGER 1

#ADD mpi4py_benchmarks ${HOME}/mpi4py_benchmarks
#RUN chown -R ${USER}:${USER} ${HOME}/mpi4py_benchmarks

# ------------------------------------------------------------
# Get and Compile foam-extend-4.1
# ------------------------------------------------------------

USER openfoam

ENV FOAM_REPO_URL git://github.com/Unofficial-Extend-Project-Mirror/foam-extend-foam-extend-4.0
#ENV FOAM_REPO_URL git://git.code.sf.net/p/foam-extend/foam-extend-4.1

RUN mkdir -p ${HOME}/foam
WORKDIR ${HOME}/foam
RUN git clone --depth 1 --single-branch --branch nextRelease ${FOAM_REPO_URL} foam-extend-4.1
RUN git config --global user.email "you@example.com" && \
    git config --global user.name "Your Name"

WORKDIR ${HOME}/foam/foam-extend-4.1
COPY 0001-compile-on-Ubuntu-20.04-with-system-MPI.patch .
RUN git am 0001-compile-on-Ubuntu-20.04-with-system-MPI.patch
SHELL ["/bin/bash", "-c"]
RUN source etc/bashrc; ./Allwmake.firstInstall
RUN echo 'source ~/foam/foam-extend-4.1/etc/bashrc' >> ${HOME}/.bashrc

WORKDIR /data

USER root
EXPOSE 22
# Make sure SSH has the keys
RUN ssh-keygen -A
CMD ["/etc/init.d/ssh", "start"]

USER ${USER}
