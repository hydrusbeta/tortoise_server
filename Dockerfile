# Use Nvidia Cuda container base, sync the timezone to GMT, and install necessary package dependencies.
# Cuda 11.8 is used instead of 12 for backwards compatibility, as it supports compute capability 3.5 through 9.0.
FROM nvidia/cuda:11.8.0-base-ubuntu20.04
ENV TZ=Etc/GMT
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone.
RUN apt update && apt install -y --no-install-recommends \
    git \
    wget \
    python3.9-venv \
    && apt autoremove -y \
    && apt clean -y

# todo: Is there a better way to refer to the home directory (~)?
ARG HOME_DIR=/root

# Create virtual environments for Tortoise TTS and Hay Say's tortoise_server
RUN python3.9 -m venv ~/hay_say/.venvs/tortoise; \
    python3.9 -m venv ~/hay_say/.venvs/tortoise_server

# Python virtual environments do not come with wheel, so we must install it. Upgrade pip while
# we're at it to handle modules that use PEP 517
RUN ~/hay_say/.venvs/tortoise/bin/pip install --no-cache-dir --upgrade pip wheel;

# Install all python dependencies for Tortoise TTS
# Note: This is done *before* cloning the repository because the dependencies are likely to change less often than the
# Tortoise TTS code itself. Cloning the repo after installing the requirements helps the Docker cache optimize build
# time. See https://docs.docker.com/build/cache
RUN ~/hay_say/.venvs/tortoise/bin/pip install \
    --no-cache-dir \
    --extra-index-url https://download.pytorch.org/whl/cu117 \
	torch==2.0.1+cu117 \
	torchvision==0.15.2+cu117 \
	transformers==4.29.2 \
	torchaudio==2.0.2+cu117 \
    rotary_embedding_torch==0.2.7 \
    inflect==7.0.0 \
    progressbar==2.5 \
    einops==0.6.1 \
    unidecode==1.3.6 \
    librosa==0.10.1

# Install the dependencies for the Hay Say interface code
RUN ~/hay_say/.venvs/tortoise_server/bin/pip install \
    --no-cache-dir \
    hay-say-common==0.2.1

# Download pretrained models.
RUN mkdir -p ~/hay_say/temp_downloads && \
    wget https://huggingface.co/jbetker/tortoise-tts-v2/resolve/main/.models/autoregressive.pth --directory-prefix=/root/hay_say/temp_downloads/ && \
    wget https://huggingface.co/jbetker/tortoise-tts-v2/resolve/main/.models/classifier.pth --directory-prefix=/root/hay_say/temp_downloads/ &&\
    wget https://huggingface.co/jbetker/tortoise-tts-v2/resolve/main/.models/clvp2.pth --directory-prefix=/root/hay_say/temp_downloads/ &&\
    wget https://huggingface.co/jbetker/tortoise-tts-v2/resolve/main/.models/cvvp.pth --directory-prefix=/root/hay_say/temp_downloads/ &&\
    wget https://huggingface.co/jbetker/tortoise-tts-v2/resolve/main/.models/diffusion_decoder.pth --directory-prefix=/root/hay_say/temp_downloads/ &&\
    wget https://huggingface.co/jbetker/tortoise-tts-v2/resolve/main/.models/vocoder.pth --directory-prefix=/root/hay_say/temp_downloads/ &&\
    wget https://huggingface.co/jbetker/tortoise-tts-v2/resolve/main/.models/rlg_auto.pth --directory-prefix=/root/hay_say/temp_downloads/ &&\
    wget https://huggingface.co/jbetker/tortoise-tts-v2/resolve/main/.models/rlg_diffuser.pth --directory-prefix=/root/hay_say/temp_downloads/

# Expose port 6579, the port that Hay Say uses for Tortoise TTS
EXPOSE 6579

# Remove the existing MLP voice directories
RUN rm -rf ~/hay_say/tortoise/tortoise/voices/rainbow && \
    rm -rf ~/hay_say/tortoise/tortoise/voices/applejack

# download Tortoise TTS and checkout a specific commit that is known to work with this Docker
# file and with Hay Say
RUN git clone -b main --single-branch -q https://github.com/neonbjb/tortoise-tts/ ~/hay_say/tortoise
WORKDIR $HOME_DIR/hay_say/tortoise
RUN git reset --hard 5415d47a1da05f8f092af9744e85eb46b978604a

# Move the pretrained models into the expected directory
RUN mkdir -p ~/.cache/tortoise/models/ && \
    mv /root/hay_say/temp_downloads/* ~/.cache/tortoise/models/

# Run setup script for Tortoise TTS
RUN ~/hay_say/.venvs/tortoise/bin/python3 setup.py install

# Download the Hay Say Interface code
RUN git clone https://github.com/hydrusbeta/tortoise_server ~/hay_say/tortoise_server/

# Tortoise TTS downloads some models when it is executed for the first time. Let's Load it ahead of time now so the user
# doesn't need to wait for them to download later and so they can run this architecture offline.
WORKDIR $HOME_DIR/hay_say/tortoise
RUN /root/hay_say/.venvs/tortoise/bin/python3 scripts/tortoise_tts.py -v train_grace -o out.wav text "Testing, 1 2 3."

# Run the Hay Say interface on startup
# CMD ["/bin/sh", "-c", "/root/hay_say/.venvs/tortoise_server/bin/python /root/hay_say/tortoise_server/main.py"]


