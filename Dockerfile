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
    parallel

WORKDIR /usr/local/bin

RUN wget https://github.com/Illumina/ExpansionHunterDenovo/releases/download/v0.9.0/ExpansionHunterDenovo-v0.9.0-linux_x86_64.tar.gz

RUN tar -xvzf ExpansionHunterDenovo-v0.9.0-linux_x86_64.tar.gz
RUN chmod -R u+rwx,g+rwx,o+rwx ExpansionHunterDenovo-v0.9.0-linux_x86_64

# Copy your application code into the container
COPY run_ehdn.sh .
RUN chmod +x run_ehdn.sh

# give me all the permissions
RUN chmod -R 777 /var/lib/ 

# Set the entrypoint command
CMD ["run_ehdn.sh"]
