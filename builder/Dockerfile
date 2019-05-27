FROM ruby:2.6.3

ENV GEM_SOURCE=http://192.168.0.108:8809

RUN sed -i "s/deb.debian.org/mirrors.ustc.edu.cn/g" /etc/apt/sources.list
RUN apt-get update && apt-get install -y rsync \
  && gem install therubyracer --source $GEM_SOURCE \
  && gem install uglifier --source $GEM_SOURCE

