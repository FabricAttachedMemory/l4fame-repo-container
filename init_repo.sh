#!/bin/bash

set -u

function main {
    init_script
    error_check

    create_repo
    sign_repo
    serve_repo

    update_repo
}

# create repo from .deb packages
function create_repo {
    aptly repo create \
        -component="$COMPONENT" \
        -distribution="$DISTRIBUTION" \
        $REPO_NAME
    aptly repo add $REPO_NAME /debs/
    aptly publish repo \
        -architectures="$ARCHITECTURES" \
        -skip-signing=true \
        $REPO_NAME
}

# manually sign Release file for authenticated repo if specified
# Aptly gpg2 signing is not supported so this is done manually
function sign_repo {
    if [ "$GPG_ID" != "" ]
    then
        gpg -u $GPG_ID --batch --pinentry-mode loopback --passphrase "$GPG_PASS" \
        --clearsign -o $RELEASE_PATH/InRelease $RELEASE_PATH/Release
        gpg -u $GPG_ID --batch --pinentry-mode loopback --passphrase "$GPG_PASS" \
        -abs -o $RELEASE_PATH/Release.gpg $RELEASE_PATH/Release
    fi
}

# delete repo in order to re-publish
function drop_repo {
    if [[ $(aptly publish list -raw) ]]
    then 
        aptly publish drop $DISTRIBUTION
    fi
    if [[ $(aptly repo list -raw) ]]
    then 
        aptly repo drop $REPO_NAME
    fi
}

# move repo to whatever location hosting software is using
# additionally, generate and add status file for Repo
function serve_repo {
    rm -r /var/www/html
    mkdir /var/www/html
    cp -r ~/.aptly/public/. /var/www/html/.

    generate_status
}

# check for changes to .deb directory
# update repo when change is detected
function update_repo {
    CHECK_DIR='debs'
    stat -t $CHECK_DIR > deb_check.txt
    INIT_STAT=`cat deb_check.txt`
    while true; do
        sleep 30
        CHECK_STAT=`stat -t $CHECK_DIR`
        if [ "$INIT_STAT" != "$CHECK_STAT" ]
        then
            drop_repo
            create_repo
            sign_repo
            serve_repo
            CHECK_STAT=`stat -t $CHECK_DIR`
            INIT_STAT=`echo $CHECK_STAT`
        fi
    done
}

# initializes script with necessary variables and starts server
# also keeps track of the number of times the container restarts
# drops any pre-existing repos in case the container has restarted
function init_script {
    RELEASE_PATH=~/.aptly/public/dists/$DISTRIBUTION
    touch restarts.txt
    RESTARTS=`cat restarts.txt`
    RESTARTS=$((RESTARTS+1))
    echo $RESTARTS > restarts.txt
    START_TIME=`date`
    init_server
    drop_repo
}

# initializes desired server, currently using NGINX
function init_server {
    sed -i '/server {/ a   autoindex on;' /etc/nginx/sites-available/default
    /etc/init.d/nginx start
}

# looks for issues with keys and packages
# stops container if a problem is detected and alerts the user
function error_check {
    set -e
    if [ ! -d /debs ]
    then
        echo "Mount your Debian package directory to /debs."
        exit 1
    fi
}

# generates repo and container status for debugging purposes
function generate_status {
    cat > /var/www/html/status.txt << EOSTATUS
Started: $START_TIME
Restarted: $((RESTARTS-1)) times

`ls -1 debs | wc -l` packages uploaded:
`ls -1 debs`

Environment @ build time:
`env | sort`

EOSTATUS
}

main "$@"
