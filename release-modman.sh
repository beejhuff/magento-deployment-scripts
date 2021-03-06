#!/bin/bash
# Change these variables according to your environment.
SCRIPT_ROOT=/files
HTML_ROOT=/html/shop
HTML_URL=http://page.tld
GIT_URI=git@host.tld:username/repository.git
COMMIT_HASH=HEAD
N98_MAGERUN=${SCRIPT_ROOT}/n98-magerun.phar
MODMAN=${SCRIPT_ROOT}/modman
MODMAN_DIR=/html/.modman

# check the --nodbupdate command line option
dbupdate=true
if [ "$1" = '--nodbupdate' ]
then
    dbupdate=false
fi

# check if all used commands are allowed in this environment (managed servers often block various commands)
commands="git rm mv find ${MODMAN} php ${N98_MAGERUN}"

for command in ${commands}
do
    if type -P "${command}" &>/dev/null
    then
        continue
    else
        echo "${command} command not found."
        exit 1
    fi
done

# check if all given directories exist
directories="${SCRIPT_ROOT} ${HTML_ROOT} ${MODMAN_DIR}"

for directory in ${directories}
do
    if ! test -e "${directory}"
    then
        echo "${directory} command not found."
        exit 1
    fi
done

# get a new, clean version from the repository
echo '... cloning git repository ...'
git clone ${GIT_URI} ${MODMAN_DIR}-new
cd ${MODMAN_DIR}-new

# checkout files from given commit
echo '... checking out given commit ...'
git checkout ${COMMIT_HASH}
rm -rf .git
cd ..

# clear the cache before enabling the maintenance mode to reduce the down time
echo '... clearing the cache ...'
php ${N98_MAGERUN} cache:flush

# enable maintenance mode
echo '... enabling maintenance mode ...'
> ${HTML_ROOT}/maintenance.flag

# point .modman directory to the new revision
rm -rf ${MODMAN_DIR}
mv ${MODMAN_DIR}-new ${MODMAN_DIR}

# recreate all symlinks
find ${HTML_ROOT} -type l -delete
${MODMAN} deploy-all

cd ${HTML_ROOT}

# clear the cache
echo '... clearing the cache ...'
php ${N98_MAGERUN} cache:flush
# clear the APC cache
php ${SCRIPT_ROOT}/apc_clear_call.php --url=${HTML_URL} --htmlroot=${HTML_ROOT} --scriptroot=${SCRIPT_ROOT}

# run install/upgrade scripts, so that they are executed only once
if [ "$dbupdate" = true ]
then
    echo '... running setup scripts ...'
    php ${N98_MAGERUN} sys:setup:run
fi

# disable maintenance mode
echo '... disabling maintenance mode ...'
rm maintenance.flag
