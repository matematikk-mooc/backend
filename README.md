Docker Canvas 
-------------------------------

Docker provisioning for Canvas 

### Prerequisites
* [Docker Desktop](https://www.docker.com/products/docker-desktop)

or

* [Docker Engine](https://docs.docker.com/engine/installation/)
* [Docker Compose](https://docs.docker.com/compose/install/)

and

* Large amount (~4GB) of memory allocated to your docker machine (Canvas uses a lot of memory)

### Clone Repo 

    git clone git@github.com:netguru/UDIR-canvas.git udir-canvas

### Persistant data

During the first run the folder '.user_data' will be created 
this folder will contain all your data.

### Canvas environment configuration

You can leave all settings as they are.
 - Default user is: udir@udir.local
 - Default password is: udir_udir
 - Default organization is: udir
 - Default domain is: localhost

If you want change any of those please do this in config.env file before you start building application.

### SSL configuration

Canvas application is set to be accessible via https.
For this purpose we use self signed certificate, for this reason web browser could display message that this certificate is not trusted and visit this page is not safe.
You can remove this warning by replace certificate signed by trusted the certification center (Verizon, let's encrypt, etc.)
To do this please add your certificate to config folder, and change those lines in config/nginx.conf
    
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/certs/nginx-selfsigned.key;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;

You can do it before first run or any time - just restart canvas application 
   `
    docker-compose stop
    docker-compose up -d
    `
or stop and start form canvas.sh script

### Fix for override themes

Run this command after you add your own themes, this will fix bug in Canvas DB, and allow to read JS files

    docker-compose run -e PGDATABASE=canvas -e PGUSER=canvas -e PGHOST=db -e PGPASSWORD=canvas --rm db psql -c "UPDATE attachments set content_type='application/x-javascript' WHERE content_type='text/javascript';"

Or you can do it from `canvas.sh` script 

### If it is the first time:

To start using docker Canvas environment you can use this script if you have mac or linux:
    `
    canvas.sh
    `
Or you can do the steps manually as described below. This is mandatory if you are running on windows. 


### Manual steps:
Create necessary external volumes for the database and cache:

    docker volume create --name data-postgresql --driver local

    docker volume create --name canvas-redis --driver local

Initialize data by first starting the database:

    docker-compose up -d db

Wait a few moments for the database to start then (command might fail if database hasn't finished first time startup):

    docker-compose run --rm app bundle exec rake db:create db:initial_setup

The branding assets must also be manually generated when canvas is in production mode:

    docker-compose run --rm app bundle exec rake \
        canvas:compile_assets_dev \
        brand_configs:generate_and_upload_all

Finally startup all the services (the build will create a docker image for you):

    docker-compose up -d --build

Canvas is accessible at

    https://localhost/

MailHog (catches all out going mail from canvas) is accessible at

    http://localhost:8901/

### Start Server

    docker-compose up -d

### Check Logs

    # app
    docker logs -f dockercanvas_app_1
    # worker
    docker logs -f dockercanvas_worker_1
    # db
    docker logs -f dockercanvas_db_1
    # redis
    docker logs -f dockercanvas_redis_1
    # mail
    docker logs -f dockercanvas_mail_1

### Stop Server

    docker-compose stop

### Stop Server and Clean Up

This option is available only as manual step
    docker-compose down
    rm -rf .user_data

### Rebuild local image

You can try rebuilding the image if you are experiencing issues importing course content, etc. Before running this command, stop the server (if it's running) using `docker-compose down`

    docker-compose build

### Communicating between projects

 It may be hard to link to the Canvas container in some situations using only `localhost`. This can be mitigated using the IP address of your host machine to access the canvas instance or by using virtual hosts if that is not feasible.


