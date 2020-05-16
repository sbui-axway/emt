#!/bin/sh

# Halt on error
set -e

emtuser_uid=1000
emtuser_gid=1000
emt_dir=/tmp/emt
events_dir=$emt_dir/events
gw_merge_dir=$emt_dir/apigateway
aga_merge_dir=$emt_dir/analytics
reports_dir=$emt_dir/reports
sql_dir=$emt_dir/sql

metrics_env_vars="-e METRICS_DB_URL=jdbc:mysql://metricsdb:3306/metrics?useSSL=false -e METRICS_DB_USERNAME=root -e METRICS_DB_PASS=root01"

cleanup() {
    echo "*** Cleaning up after previous run ***"
    rm -rf "$emt_dir"
    docker rm -f anm analytics apimgr casshost1 metricsdb || true
    docker rmi admin-node-manager apigw-analytics api-gateway-defaultgroup apigw-base || true
    docker network rm api-gateway-domain || true
}

is_substring() {
    case "$2" in
        *$1*) return 0;;
        *) return 1;;
    esac
}

validate_env() {
    echo "*** Validating environment ***"
    local name=`hostname`
    if is_substring "_" "${name}"
    then
        echo "Error: Configured hostname \"$name\" contains underscore symbol in it. Such is unsupported!"
        exit 1
    fi
}

setup() {
    echo
    echo "Building and starting an API Gateway domain that contains an Admin Node Manager,"
    echo "API Manager and API Gateway Analytics."

    cd $(dirname "$0")/..
    mkdir -p "$events_dir" "$gw_merge_dir/ext/lib" "$aga_merge_dir/ext/lib" "$reports_dir" "$sql_dir"
    chown -R $emtuser_uid:$emtuser_gid "$events_dir" "$gw_merge_dir/ext/lib" "$aga_merge_dir/ext/lib" "$reports_dir" "$sql_dir"

    echo
    echo "Downloading MySQL connector JAR ..."
    local mysql_jar_url="https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.47/mysql-connector-java-5.1.47.jar"
    local tmp_jar="/tmp/mysql-connector-java-5.1.47.jar"
    python 2>&1 -c "import urllib2;r=urllib2.urlopen('$mysql_jar_url',timeout=10);s=r.read();f=open('$tmp_jar','w');f.write(s);f.close();print('OK')" \
        | python -c "import sys;s=sys.stdin.readlines()[-1].strip();print(s);s!='OK' and sys.exit(1)"

    cp "$tmp_jar" "$gw_merge_dir/ext/lib"
    mv "$tmp_jar" "$aga_merge_dir/ext/lib"    
    cp quickstart/mysql-analytics.sql $sql_dir

    echo
    echo "*** Creating Docker network to allow containers to communicate with one another ***"
    docker network create api-gateway-domain
    echo
    echo "*** Starting Cassandra container to store API Manager data ***"
    docker run -d --name=casshost1 --network=api-gateway-domain cassandra:2.2.12
    echo
    echo "*** Starting MySQL container to store metrics data ***"
    docker run -d --name metricsdb --network=api-gateway-domain \
               -v $sql_dir:/docker-entrypoint-initdb.d \
               -e MYSQL_ROOT_PASSWORD=root01 -e MYSQL_DATABASE=metrics \
               mysql:5.7
    echo
    echo "*** Generating default domain certificate ***"
    ./gen_domain_cert.py --default-cert || true
}

build_base_image() {
    echo
    echo "******************************************************************"
    echo "*** Building base image for Admin Node Manager and API Gateway ***"
    echo "******************************************************************"
    ./build_base_image.py --installer=$APIGW_INSTALLER --os=centos7 --user-uid=$emtuser_uid --user-gid=$emtuser_gid
}

build_anm_image() {
    echo
    echo "**********************************************************"
    echo "*** Building and starting Admin Node Manager container ***"
    echo "**********************************************************"
    ./build_anm_image.py --default-cert --default-user --metrics --merge-dir="$gw_merge_dir"

    docker run -d --name=anm --network=api-gateway-domain \
               -p 8090:8090 -v $events_dir:/opt/Axway/apigateway/events \
               $metrics_env_vars admin-node-manager
}

build_analytics_image() {
    echo
    echo "*************************************************************"
    echo "*** Building and starting API Gateway Analytics container ***"
    echo "*************************************************************"
    ./build_aga_image.py --license=$LICENSE --installer=$APIGW_INSTALLER --os=centos7 \
                         --merge-dir="$aga_merge_dir" --default-user

    docker run -d --name=analytics --network=api-gateway-domain \
               -p 8040:8040 -v $reports_dir:/tmp/reports \
               $metrics_env_vars apigw-analytics
}

build_gateway_image() {
    echo
    echo "***************************************************"
    echo "*** Building and starting API Manager container ***"
    echo "***************************************************"
    ./build_gw_image.py --license=$LICENSE  --merge-dir="$gw_merge_dir" --default-cert --api-manager

    docker run -d --name=apimgr --network=api-gateway-domain \
               -p 8075:8075 -p 8065:8065 -p 8080:8080 -v $events_dir:/opt/Axway/apigateway/events \
               -e EMT_DEPLOYMENT_ENABLED=true -e EMT_ANM_HOSTS=anm:8090 -e CASS_HOST=casshost1 \
               $metrics_env_vars api-gateway-defaultgroup
}

finish() {
    echo
    echo "************"
    echo "*** Done ***"
    echo "************"
    echo 
    echo "Wait a couple of minutes for startup to complete."
    echo
    echo "Login to API Gateway Manager at https://localhost:8090 (admin/changeme)"
    echo "Login to API Manager at https://localhost:8075 (apiadmin/changeme)"
    echo "Login to API Gateway Analytics at https://localhost:8040 (admin/changeme)"
}

if [ $# -lt 2 ]; then
    echo "Usage: quickstart.sh INSTALLER LICENSE"
    echo
    echo "Builds and starts an API Gateway domain that contains an Admin Node Manager,"
    echo "API Manager and API Gateway Analytics."
    echo
    echo "Options:"
    echo "  INSTALLER         Path to 7.6+ API Gateway installer"
    echo "  LICENSE           Path to license for API Manager and API Gateway Analytics"
    exit 1
elif [ ! -f "$1" ]; then
    echo "Error: API Gateway installer does not exist: \"$1\""
    exit 1
elif [ ! -f "$2" ]; then
    echo "Error: License file does not exist: \"$2\""
    exit 1
fi
APIGW_INSTALLER=$(readlink -f "$1")
LICENSE=$(readlink -f "$2")

validate_env
cleanup
setup
build_base_image
build_anm_image
build_analytics_image
build_gateway_image
finish
