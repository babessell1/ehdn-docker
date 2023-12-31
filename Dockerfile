# Use Ubuntu 22.04 as the base image
# add
FROM ubuntu:22.04

# Install required dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    samtools \
    parallel \
    python3-pip

RUN apt-get update && apt-get install -y software-properties-common gcc && \
    add-apt-repository -y ppa:deadsnakes/ppa

ENV DEBIAN_FRONTEND noninteractive 

RUN apt-get update && apt-get install -y python3.8 python3-distutils python3-pip python3-apt

WORKDIR /usr/local/bin

RUN wget https://github.com/Illumina/ExpansionHunterDenovo/releases/download/v0.9.0/ExpansionHunterDenovo-v0.9.0-linux_x86_64.tar.gz

RUN tar -xvzf ExpansionHunterDenovo-v0.9.0-linux_x86_64.tar.gz
RUN chmod -R u+rwx,g+rwx,o+rwx ExpansionHunterDenovo-v0.9.0-linux_x86_64
RUN git clone https://github.com/babessell1/ExpansionHunterDenovo-LRDN.git

ENV PATH="$PATH:/usr/local/bin/ExpansionHunterDenovo-LRDN"

# Remove hash lines and trailing slashes from requirements.txt
RUN sed -i '/--hash=.*$/d; s/\\$//' ExpansionHunterDenovo-LRDN/requirements.txt

RUN pip install -r ExpansionHunterDenovo-LRDN/requirements.txt
RUN chmod -R u+rwx,g+rwx,o+rwx ExpansionHunterDenovo-LRDN

# Copy your application code into the container
COPY run_ehdn.sh .
RUN chmod +x run_ehdn.sh

# give me all the permissions
RUN chmod -R 777 /var/lib/ 

# Set the entrypoint command
CMD ["run_ehdn.sh"]
