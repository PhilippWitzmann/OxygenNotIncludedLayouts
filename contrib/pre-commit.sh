#!/bin/sh

echo "Checking for docker container"
if [ ! "$(docker ps -q -f name=dataimporter_php-fpm_1)" ]; then
        docker-compose up -d && cd .git/hooks
fi

PROJECT=`docker exec dataimporter_php-fpm_1 php -r "echo dirname(dirname(dirname(realpath('$0'))));"`
STAGED_FILES_CMD=`git diff --cached --name-only --diff-filter=ACMR HEAD | grep \\\\.php`

# Determine if a file list is passed
if [ "$#" -eq 1 ]
then
	oIFS=$IFS
	IFS='
	'
	SFILES="$1"
	IFS=$oIFS
fi
SFILES=${SFILES:-$STAGED_FILES_CMD}

echo "Checking PHP Lint..."
if [ "$SFILES" != "" ]
then
    for FILE in $SFILES
    do
        docker exec dataimporter_php-fpm_1 php -l -d display_errors=0 $PROJECT/$FILE
        if [ $? != 0 ]
        then
            echo "Fix the error before commit."
            exit 1
        fi
        FILES="$FILES $PROJECT/$FILE"
    done
fi

if [ "$FILES" != "" ]
then
	echo "Running Code Sniffer..."
	docker exec dataimporter_php-fpm_1 ./vendor/bin/phpcs -snp --extensions=php --encoding=utf-8 $FILES
	if [ $? != 0 ]
	then
		echo "Fix the error before commit."
		exit 1
	fi
fi

if [ "$FILES" != "" ]
then
	echo "Running Mess Detector..."
	docker exec dataimporter_php-fpm_1 ./vendor/bin/phpmd app,packages text ruleset.xml --suffixes php
	if [ $? != 0 ]
	then
		echo "Fix the error before commit."
		exit 1
	fi
fi

if [ "$FILES" != "" ]
then
	echo "Running Copy Paste Detector..."
	docker exec dataimporter_php-fpm_1 php vendor/bin/phpcpd app tests packages
	if [ $? != 0 ]
	then
		echo "Fix the error before commit."
		exit 1
	fi
fi

if [ "$FILES" != "" ]
then
	echo "Running PHPUnit..."
	docker exec dataimporter_php-fpm_1 php vendor/bin/phpunit
	if [ $? != 0 ]
	then
		echo "Fix the error before commit."
		exit 1
	fi
fi

exit $?