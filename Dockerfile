FROM ubuntu:16.04
LABEL maintainer="macheleven@protonmail.com"

WORKDIR /directv/
COPY ./directv_http.pl .

RUN apt-get update && apt-get install -y libjson-perl libswitch-perl libwww-perl && \
    chmod +x directv_http.pl

ENTRYPOINT ["./directv_http.pl"]

CMD ["version"]
