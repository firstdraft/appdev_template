FROM ubuntu:focal-20200916

RUN apt-get update

RUN apt-get install -y unzip xvfb libxi6 libgconf-2-4 curl wget gnupg2 default-jdk sudo

RUN curl -sS -o - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add
RUN echo "deb [arch=amd64]  http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list
RUN sudo apt-get -y update

RUN sudo apt-get -y install google-chrome-stable git

RUN wget https://chromedriver.storage.googleapis.com/2.41/chromedriver_linux64.zip
RUN unzip chromedriver_linux64.zip

RUN mv chromedriver /usr/bin/chromedriver
RUN chown root:root /usr/bin/chromedriver
RUN chmod +x /usr/bin/chromedriver

RUN wget https://selenium-release.storage.googleapis.com/3.13/selenium-server-standalone-3.13.0.jar
RUN wget http://www.java2s.com/Code/JarDownload/testng/testng-6.8.7.jar.zip
RUN unzip testng-6.8.7.jar.zip

RUN useradd -l -u 33333 -G sudo -md /home/gitpod -s /bin/bash -p gitpod gitpod \
    # passwordless sudo for users in the 'sudo' group
    && sed -i.bkp -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers
ENV HOME=/home/gitpod
WORKDIR $HOME
# custom Bash prompt
RUN { echo && echo "PS1='\[\e]0;\u \w\a\]\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\] \\\$ '" ; } >> .bashrc

### Gitpod user (2) ###
USER gitpod
# use sudo so that user does not get sudo usage info on (the first) login
RUN sudo echo "Running 'sudo' for Gitpod: success" 

WORKDIR /base-rails

RUN  gpg2 --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
RUN curl -L https://get.rvm.io | bash -s stable
ENV PATH /usr/local/rvm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN /bin/bash -l -c "rvm requirements"
RUN /bin/bash -l -c "rvm install 2.6.6"

RUN sudo apt install -y postgresql postgresql-contrib libpq-dev psmisc lsof
RUN sudo wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.focal_amd64.deb && \
    echo y | sudo apt install ./wkhtmltox_0.12.6-1.focal_amd64.deb python3-pip build-essential libssl-dev libffi-dev python3-dev

RUN /bin/bash -l -c "rvm use --default 2.6.6"
RUN /bin/bash -l -c "gem install htmlbeautifier"
RUN /bin/bash -l -c "gem install rufo"

RUN sudo apt-get update && \
    yes Y | sudo apt install dirmngr gnupg apt-transport-https ca-certificates software-properties-common && \
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 && \
    sudo add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/' && \
    yes Y | sudo apt install r-base pkg-config graphviz-dev imagemagick && \
    sudo apt-get install -y graphviz

COPY Gemfile /base-rails/Gemfile
COPY Gemfile.lock /base-rails/Gemfile.lock

RUN /bin/bash -l -c "gem install bundler"
RUN /bin/bash -l -c "bundle install"

RUN /bin/bash -l -c "curl https://cli-assets.heroku.com/install.sh | sh"

