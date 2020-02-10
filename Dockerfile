FROM puckel/docker-airflow:1.10.7
RUN export "PATH=${PATH};/usr/local/airflow/.local/bin"
COPY requirements.txt /
