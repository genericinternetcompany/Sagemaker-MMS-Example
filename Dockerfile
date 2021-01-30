FROM amazonlinux:2

# RUN whoami
USER root

RUN amazon-linux-extras install python3
RUN amazon-linux-extras install corretto8

# Install OpenCV dependencies
RUN yum -y install libXrender-0.9.10 --nogpgcheck \
 && yum -y install mesa-libGL-18.3.4 --nogpgcheck \
 && yum clean all

RUN useradd python
RUN mkdir /usr/java

RUN yum groupinstall -y Development Tools
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

COPY get-pip.py ./get-pip.py
RUN python ./get-pip.py

RUN update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

USER python



# MMS required: Label to advertise MMS + use SAGEMAKER_BIND_TO_PORT env var if present
LABEL com.amazonaws.sagemaker.capabilities.multi-models=true
LABEL com.amazonaws.sagemaker.capabilities.accept-bind-to-port=true


ENV LANG C.UTF-8
ENV LD_LIBRARY_PATH /opt/conda/lib/:$LD_LIBRARY_PATH
ENV PATH /opt/conda/bin:$PATH
# ENV SAGEMAKER_SERVING_MODULE sagemaker_pytorch_serving_container.serving:main
ENV DIR_TEMP /home/model-server/
ENV S3_BUCKET $S3_BUCKET
ENV Stage $STAGE
ENV Region $REGION
ENV ServiceName $SERVICE_NAME

# RUN find  /usr/ -name java 
RUN export PATH=/usr/java/jdk11.0.3/bin:$PATH
RUN export PATH=/home/python/.local/bin:$PATH
RUN java -version

# Install dependencies
RUN pip install --no-cache-dir --upgrade pip

# Install MMS, and SageMaker Inference Toolkit to set up MMS
RUN pip install --no-cache-dir multi-model-server==1.1.2 \
                                                      sagemaker-inference==1.5.3 \
                                                      retrying==1.3.3 \
                                                      pyyaml==5.3.1 \
                                                      boto3==1.14.53
# Torch
RUN pip install --no-cache-dir torch==1.4.0 torchvision==0.5.0

# Model shared dependencies
RUN pip install --no-cache-dir                       pandas \
                                                      opencv-python==4.5.1.48 \
                                                      gensim==3.8.3 \
                                                      tqdm==4.55.1

# # Model specific dependencies
RUN pip install --no-cache-dir cython==0.29.21 \
                                                      nltk==3.5 \
                                                      pybind11==2.6.1 \
                                                      lightgbm==2.3.1 \
                                                      shapely==1.7.1
                                        
RUN pip3 install --no-cache-dir fasttext 
                                        
# scikit learn not passing infrasecurity scan
RUN pip uninstall -y scikit-learn

# Test lib
RUN python -c "import torch, cv2, pandas, fasttext"

# MMS required paths
RUN mkdir -p $DIR_TEMP \
 && mkdir -p /opt/ml/model

# Copy entrypoint script to the image
COPY ./docker-entrypoint.py /usr/local/bin/docker_entrypoint.py

# Copy the default custom service file to handle incoming data and inference requests
COPY model_handler.py /home/model-server/model_handler.py

WORKDIR /home/python
# Define entrypoint script and command
ENTRYPOINT ["python3", "/usr/local/bin/docker_entrypoint.py"]
CMD ["serve"]