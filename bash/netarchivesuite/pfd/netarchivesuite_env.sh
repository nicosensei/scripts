#!/bin/bash

JAVA_HOME=/usr/lib/jvm/java-6-oracle/
NAS_BASE=/home/ngiraud/dev/java/eclipse/workspace/kepler/netarchivesuite_4.2/
DEPLOY_DIR=/home/ngiraud/git/proddlweb/nas-deploy/pfd/menelas1
ENV_NAME=pfdmenelas
REMOTE_HOST=menelas1.bnf.fr
REMOTE_USER=dlweb

IMQ_BIN=/home/dlweb/openmq-4.3/mq/bin
IMQCMD=$IMQ_BIN/imqcmd
PASSFILE_DIR=/home/dlweb
PASSFILE_NAME=mq_admin.passfile
PASSFILE=$PASSFILE_DIR/$PASSFILE_NAME

START_LOG_DIR=/bnf/dlwebdata/netarchivesuite/$ENV_NAME/log

sshCommand() {
  ssh $REMOTE_USER@$REMOTE_HOST "$1"
}

startJmsBroker() {
  sshCommand "$IMQ_BIN/imqbrokerd -reset store > imq.out 2>&1 &"
  echo Waiting for IMQ broker to start, please ignore messages.
  sshCommand "while ! telnet localhost 7676 2>&1 | grep 'portmapper tcp' ; do sleep 1; done"
  return 1
}

stopJmsBroker() {
  sshCommand "ps -wweo pid,command | grep imqbroker |  sed 's/^[ ^t]*//' |  cut -d ' ' -f 1,1  | xargs kill -9"
  echo $"Waiting for IMQ broker to stop..."
  sleep 5
  echo $"... done!"
  sshCommand "ps -wweo pid,command | grep imqbroker"
  return 1
}

emptyJmsBrokerQueues() {
  NOT_FOUND=`sshCommand "if [ -f $PASSFILE ]; then echo 0; else echo 1; fi"`  
  if [ "$NOT_FOUND" -eq 1 ] ; then
      echo "Copying MQ passfile" 
      scp $DEPLOY_DIR/$PASSFILE_NAME $REMOTE_USER@$REMOTE_HOST:$PASSFILE_DIR; 
  fi
  echo -e "Processing queues\n"
  sshCommand "$IMQCMD list dst -t q -u admin -passfile $PASSFILE | grep ^${ENV_NAME}_ | cut -f1 -d\ | xargs -r -n 1 $IMQCMD destroy dst -t q -u admin -passfile $PASSFILE -f -n"
  echo -e "Processing topics\n"
  sshCommand "$IMQCMD list dst -t t -u admin -passfile $PASSFILE | grep ^${ENV_NAME}_ | cut -f1 -d\ | xargs -r -n 1 $IMQCMD destroy dst -t t -u admin -passfile $PASSFILE -f -n"
}

start() {
  if [ "`runningCount;`"  -gt 0 ]; then
    echo Environment is already running.
  else 
      startJmsBroker;
      sshCommand "if [ $(ps aux | grep imqbrokerd | wc -l) == 0 ]; then echo Broker is not started! Will exit now...; fi"
      emptyJmsBrokerQueues;
      . $DEPLOY_DIR/$ENV_NAME/startall_$ENV_NAME.sh
  fi
}

stop() {
  if [ "`runningCount;`" -eq 0 ]; then
    echo Environment is already stopped.
  else
    . $DEPLOY_DIR/$ENV_NAME/killall_$ENV_NAME.sh
    stopJmsBroker;
  fi
}

runningCount() {
   echo `sshCommand "ps aux | grep netarkivet | sed '/^.*grep.*$/d' | wc -l"`
}

status() {
  JVM_COUNT=`sshCommand "ps aux | grep netarkivet | sed '/^.*grep.*$/d' | wc -l"`
  if [ $JVM_COUNT -lt 1 ]; then
    echo -e "NetArchive Suite environment is down."
  else
    echo -e "NetArchive Suite environment is up with $JVM_COUNT applications running."
  fi
}

install() {
  echo "Purging old install files if present..."
  rm -rf $DEPLOY_DIR/$ENV_NAME
  echo "...done"

  CLASSPATH=$NAS_BASE/lib/dk.netarkivet.deploy.jar
  CLASSPATH=$CLASSPATH:$NAS_BASE/lib/dk.netarkivet.archive.jar
  CLASSPATH=$CLASSPATH:$NAS_BASE/lib/dk.netarkivet.common.jar
  CLASSPATH=$CLASSPATH:$NAS_BASE/lib/dk.netarkivet.harvester.jar
  CLASSPATH=$CLASSPATH:$NAS_BASE/lib/dk.netarkivet.monitor.jar
  CLASSPATH=$CLASSPATH:$NAS_BASE/lib/dk.netarkivet.viewerproxy.jar
  CLASSPATH=$CLASSPATH:$NAS_BASE/lib/dom4j-1.5.2.jar
  CLASSPATH=$CLASSPATH:$NAS_BASE/lib/commons-logging-1.0.4.jar
  CLASSPATH=$CLASSPATH:$NAS_BASE/lib/commons-cli-1.0.jar
  CLASSPATH=$CLASSPATH:$NAS_BASE/lib/jaxen-1.1.jar
  export CLASSPATH

  DEPLOY_CMD="$JAVA_HOME/bin/java \
    -cp $CLASSPATH dk.netarkivet.deploy.DeployApplication \
    -E$ENV_NAME.xml -C$ENV_NAME.xml -Z${NAS_BASE}/NetarchiveSuite.zip -Ssecurity.policy -Llog.prop"

  $DEPLOY_CMD $*;
  
  pushd $DEPLOY_DIR/$ENV_NAME

  # Substitute start_XXX.log paths in startup scripts
  for f in `find -name "start_*.sh"`; do
    echo -e "Post-processing script $f"
    sed -i 's@< /dev/null > start_@< /dev/null > '$START_LOG_DIR'/start_@' $f
  done
  # Substitute also in startall script
  STARTALL=startall_$ENV_NAME.sh
  REMOTE_INSTALL_DIR="`cat $STARTALL | grep ssh | sed -n '1p' | cut -d ' ' -f 5 | cut -f1-5 -d/`"
  echo -e "Post-processing script $STARTALL"
  sed -i 's@cat '$REMOTE_INSTALL_DIR'/\*.log@cat '$START_LOG_DIR'/start_\*.log@' $STARTALL

  chmod +x *.sh
  ./install_$ENV_NAME.sh
  popd
}

clean() {
  pushd $DEPLOY_DIR/$ENV_NAME 	
  REMOTE_BASE_DIR="`cat startall_$ENV_NAME.sh | grep ssh | sed -n '1p' | cut -d ' ' -f 5 | cut -f1-5 -d/`"
  for d in `ls -d -- */`; do 
    HOST="`echo "$d" | sed 's#/##'`"
    echo -e "Will delete directory $REMOTE_BASE_DIR on remote host $HOST..."
    ssh $REMOTE_USER@$HOST "rm -rf $REMOTE_BASE_DIR" 
    echo ...done!
  done
  popd
}

case "$1" in
 install)
     install;
     ;;
 clean)
     clean;
     ;;
 start)
     start;
     ;;
 stop)
     stop;
     ;;
 restart)
     stop;
     start;
     ;;
 status)
     status;
     ;;
 *)
     echo $"Usage: $0 {start|stop|restart|status|install}"
     exit 1
     ;;
esac


exit $RETVAL
