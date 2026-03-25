#!/bin/sh

# Remote machine details
REMOTE_HOST="tmpl-nn"
REMOTE_USER="hadoop"
REMOTE_SCRIPT="prefect_process.py"

echo "Connecting to ${REMOTE_HOST} and installing prefect..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "pip install prefect"

echo "Copying ${REMOTE_SCRIPT} to ${REMOTE_USER}@${REMOTE_HOST}:~/"
scp ${REMOTE_SCRIPT} ${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_SCRIPT}

echo "Launching ${REMOTE_SCRIPT} on ${REMOTE_HOST}..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "python3 ~/${REMOTE_SCRIPT}"

echo "Done."

