#!/usr/bin/env bash

### LICENSE - (BSD 2-Clause) // ###
#
# Copyright (c) 2018, Daniel Plominski (ASS-Einrichtungssysteme GmbH)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or
# other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
### // LICENSE - (BSD 2-Clause) ###

### ### ### ASS // ### ### ###

#// global
export TZ=Europe/Berlin
GETZONETYPE=$(uname)
GETDAY=$(date +'%Y%m%d')

#// runner
if [ -e settings.conf ]; then GET_ZONE_SRV_NAME=$(grep "TARGETZONE" settings.conf | sed 's/TARGETZONE=//' | sed 's/\"//g'); fi
if [ -e settings.conf ]; then GET_WEB_SRV_NAME=$(grep "TARGETWEBSRV" settings.conf | sed 's/TARGETWEBSRV=//' | sed 's/\"//g'); fi
if [ -e settings.conf ]; then GET_WEB_SRC_NAME=$(grep "TARGETWEBSRC" settings.conf | sed 's/TARGETWEBSRC=//' | sed 's/\"//g'); fi

#// FUNCTION: spinner (Version 1.0)
spinner() {
   local pid=$1
   local delay=0.01
   local spinstr='|/-\'
   while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
         local temp=${spinstr#?}
         printf " [%c]  " "$spinstr"
         local spinstr=$temp${spinstr%"$temp"}
         sleep $delay
         printf "\b\b\b\b\b\b"
   done
   printf "    \b\b\b\b"
}

#// FUNCTION: run script as root (Version 1.0)
check_root_user() {
if [ "$(id -u)" != "0" ]; then
   echo "[ERROR] This script must be run as root" 1>&2
   exit 1
fi
}

#// FUNCTION: check state (Version 1.0)
check_hard() {
if [ $? -eq 0 ]
then
   echo "[$(printf "\033[1;32m  OK  \033[0m\n")] '"$@"'"
else
   echo "[$(printf "\033[1;31mFAILED\033[0m\n")] '"$@"'"
   sleep 1
   exit 1
fi
}

#// FUNCTION: check state without exit (Version 1.0)
check_soft() {
if [ $? -eq 0 ]
then
   echo "[$(printf "\033[1;32m  OK  \033[0m\n")] '"$@"'"
else
   echo "[$(printf "\033[1;33mWARNING\033[0m\n")] '"$@"'"
   sleep 1
fi
}

#// FUNCTION: check state hidden (Version 1.0)
check_hidden_hard() {
if [ $? -eq 0 ]
then
   return 0
else
   #/return 1
   checkhard "$@"
   return 1
fi
}

#// FUNCTION: check state hidden without exit (Version 1.0)
check_hidden_soft() {
if [ $? -eq 0 ]
then
   return 0
else
   #/return 1
   checksoft "$@"
   return 1
fi
}

#// FUNCTION: get linux runner variables
prepare_runner_get_env() {
   : # dummy
}

#// FUNCTION: transfer the runner script
transfer_runner_to_target() {
   #// copy the script to the remote host
   scp -q -i /id_ed25519 run-ci-build-smartos.sh root@"$GET_ZONE_SRV_NAME":/run-ci-build-smartos.sh
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] scp file transfer (run-ci-build-smartos.sh) passed. (stage: 1)"
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] scp file transfer (run-ci-build-smartos.sh) goes wrong! (stage: 1)"
      exit 1
   fi
   #// copy settings.conf to the remote host
   scp -q -i /id_ed25519 settings.conf root@"$GET_ZONE_SRV_NAME":/settings.conf
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] scp file transfer (settings.conf) passed. (stage: 2)"
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] scp file transfer (settings.conf) goes wrong! (stage: 2)"
      exit 1
   fi
   #// set the right permission on the remote host script
   ssh -q -i /id_ed25519 root@"$GET_ZONE_SRV_NAME" 'chmod 0750 /run-ci-build-smartos.sh'
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] set the right permission on the remote host script passed. (stage: 3)"
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] set the right permission on the remote host script goes wrong! (stage: 3)"
      exit 1
   fi
}

#// FUNCTION: start the remote build
build_runner_start() {
   ssh -q -i /id_ed25519 root@"$GET_ZONE_SRV_NAME" '/run-ci-build-smartos.sh build'
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] smartos build passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] smartos build goes wrong!"
      exit 1
   fi
}

#// FUNCTION: build smartos on smartos zone
build_zone_smartos() {
   echo "starting ..."
   #// step 1
   mkdir -pv /github
   mkdir -pv /github/"$GETDAY"
   check_hard step 1-8
   #// step 2
   pfexec pkgin -y in scmgit
   check_hard step 2-8
   #/pfexec pkgin -y in pv
   #/check_hard step 2.1-8
   #// step 3
   cd /github/"$GETDAY"
   git clone https://github.com/ass-a2s/smartos-live
### BRANCH ### git clone https://github.com/joyent/smartos-live --branch release-20180104
   check_soft step 3-8
   #// step 4
   cd smartos-live
   cp -v sample.configure.smartos configure.smartos
   check_hard step 4-8
### BRANCH ### sed -i 's/illumos-joyent: master/illumos-joyent: release-20180104/g' configure.smartos
### BRANCH ### sed -i 's/illumos-joyent.git illumos"/illumos-joyent.git illumos --branch release-20180104"/g' configure.smartos
   #// step 5
   #// require bash for Building SmartOS on SmartOS
   /usr/bin/bash -c "cd /github/$GETDAY/smartos-live; ./configure"
   if [ $? -eq 0 ]
   then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] configure passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] configure goes wrong!"
      exit 1
   fi
   echo "step 5-8"
   #// step 6
   if [ -e "/github/$GETDAY/smartos-live/BUILD-LIVE.succeeded" ]
   then
      tail -n 37 BUILD-LIVE.log
      echo "[$(printf "\033[1;33mWARNING\033[0m\n")] skipping ... gmake live, daily build already exists!"
   else
      #// require bash for Building SmartOS on SmartOS
      /usr/bin/bash -c "cd /github/$GETDAY/smartos-live; gmake live" > /github/"$GETDAY"/smartos-live/BUILD-LIVE.log 2>&1
      if [ $? -eq 0 ]
      then
         tail -n 37 BUILD-LIVE.log
         echo "[$(printf "\033[1;32m  OK  \033[0m\n")] gmake live passed."
         touch /github/"$GETDAY"/smartos-live/BUILD-LIVE.succeeded
      else
         tail -n 400 /github/"$GETDAY"/smartos-live/projects/illumos/log/latest/mail_msg
         echo "[$(printf "\033[1;31mFAILED\033[0m\n")] gmake live goes wrong!"
         exit 1
      fi
   fi
   echo "step 6-8"
   #// step 7
   if [ -e "/github/$GETDAY/smartos-live/BUILD-ISO.succeeded" ]
   then
      tail -n 47 BUILD-ISO.log
      echo "[$(printf "\033[1;33mWARNING\033[0m\n")] skipping ... gmake iso, daily build already exists!"
   else
      #// require bash for Building SmartOS on SmartOS
      /usr/bin/bash -c "cd /github/$GETDAY/smartos-live; gmake iso" > /github/"$GETDAY"/smartos-live/BUILD-ISO.log 2>&1
      if [ $? -eq 0 ]
      then
         tail -n 47 BUILD-ISO.log
         echo "[$(printf "\033[1;32m  OK  \033[0m\n")] gmake iso passed."
         touch /github/"$GETDAY"/smartos-live/BUILD-ISO.succeeded
      else
         tail -n 200 BUILD-ISO.log
         echo "[$(printf "\033[1;31mFAILED\033[0m\n")] gmake iso goes wrong!"
         exit 1
      fi
   fi
   echo "step 7-8"
   #// step 8
   if [ -e "/github/$GETDAY/smartos-live/BUILD-USB.succeeded" ]
   then
      tail -n 77 BUILD-USB.log
      echo "[$(printf "\033[1;33mWARNING\033[0m\n")] skipping ... gmake usb, daily build already exists!"
   else
      #// require bash for Building SmartOS on SmartOS
      /usr/bin/bash -c "cd /github/$GETDAY/smartos-live; gmake usb" > /github/"$GETDAY"/smartos-live/BUILD-USB.log 2>&1
      if [ $? -eq 0 ]
      then
         tail -n 77 BUILD-USB.log
         echo "[$(printf "\033[1;32m  OK  \033[0m\n")] gmake usb passed."
         touch /github/"$GETDAY"/smartos-live/BUILD-USB.succeeded
      else
         tail -n 200 BUILD-USB.log
         echo "[$(printf "\033[1;31mFAILED\033[0m\n")] gmake usb goes wrong!"
         exit 1
      fi
   fi
   echo "step 8-8"
   echo "ending ..."
}

#// FUNCTION: start the remote validation
validate_runner_start() {
   ssh -q -i /id_ed25519 root@"$GET_ZONE_SRV_NAME" '/run-ci-build-smartos.sh validate'
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] smartos validate passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] smartos validate goes wrong!"
      exit 1
   fi
}

#// FUNCTION: validate smartos
validate_zone_smartos() {
   #// step 1
   mkdir -pv /github/"$GETDAY"/BUILD
   check_hard step 1-9: prepare work directory
   #// step 2
   GETBUILD=$(find /github/$GETDAY/smartos-live/output -name "platform-20*Z.tgz" | sed "s/\/github\/$GETDAY\/smartos-live\/output\///" | sed 's/platform-//' | sed 's/.tgz//')
   check_hard step 2-9: get build variable
   #// step 3
   cp -rfv /github/"$GETDAY"/smartos-live/output/platform-"$GETBUILD".tgz /github/"$GETDAY"/BUILD/platform-"$GETBUILD".tgz
   check_hard step 3-9: copy platform image version "$GETBUILD"
   #// step 4
   cp -rfv /github/"$GETDAY"/smartos-live/output-iso/platform-"$GETBUILD".iso /github/"$GETDAY"/BUILD/platform-"$GETBUILD".iso
   check_hard step 4-9: copy platform iso version "$GETBUILD"
   #// step 5
   cp -rfv /github/"$GETDAY"/smartos-live/output-usb/platform-"$GETBUILD".usb.bz2 /github/"$GETDAY"/BUILD/smartos-"$GETBUILD"-USB.img.bz2
   check_hard step 5-9: copy platform usb version "$GETBUILD"
   #// step 6
   md5sum /github/"$GETDAY"/BUILD/platform-"$GETBUILD".tgz > /github/"$GETDAY"/BUILD/md5sums.txt
   check_hard step 6-9: generate md5 sum from platform-"$GETBUILD".tgz
   #// step 7
   md5sum /github/"$GETDAY"/BUILD/platform-"$GETBUILD".iso >> /github/"$GETDAY"/BUILD/md5sums.txt
   check_hard step 7-9: generate md5 sum from platform-"$GETBUILD".iso
   #// step 8
   md5sum /github/"$GETDAY"/BUILD/smartos-"$GETBUILD"-USB.img.bz2 >> /github/"$GETDAY"/BUILD/md5sums.txt
   check_hard step 8-9: generate md5 sum from smartos-"$GETBUILD"-USB.img.bz2
   #// step 9
   sed -i "s/\/github\/$GETDAY\/BUILD\///g" /github/"$GETDAY"/BUILD/md5sums.txt
   check_hard step 9-9: normalize md5sums.txt
}

#// FUNCTION: start the remote publishing
publish_runner_start() {
   ssh -q -i /id_ed25519 root@"$GET_ZONE_SRV_NAME" '/run-ci-build-smartos.sh publish'
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] smartos publish passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] smartos publish goes wrong!"
      exit 1
   fi
}

#// FUNCTION: publishing smartos
publish_zone_smartos() {
#// DEBUG
#/set -x
   #// step 1
   GET_WEB_SRV_NAME=$(grep "TARGETWEBSRV" /settings.conf | sed 's/TARGETWEBSRV=//' | sed 's/\"//g')
   check_hard step 1.1-7: get transfer variable 1
   GET_WEB_SRC_NAME=$(grep "TARGETWEBSRC" /settings.conf | sed 's/TARGETWEBSRC=//' | sed 's/\"//g')
   check_hard step 1.2-7: get transfer variable 2
   GETBUILD=$(find /github/$GETDAY/smartos-live/output -name "platform-20*Z.tgz" | sed "s/\/github\/$GETDAY\/smartos-live\/output\///" | sed 's/platform-//' | sed 's/.tgz//')
   check_hard step 1.3-7: get build variable 1
   #// step 2
   ssh -q -i /id_ed25519 root@"$GET_WEB_SRV_NAME" "mkdir -p $GET_WEB_SRC_NAME/$GETBUILD"
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] step 2-7: create remote $GETBUILD directory passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] step 2-7: create remote $GETBUILD directory goes wrong!"
      exit 1
   fi
   #// step 3
   scp -q -i /id_ed25519 /github/"$GETDAY"/BUILD/md5sums.txt root@"$GET_WEB_SRV_NAME":"$GET_WEB_SRC_NAME"/"$GETBUILD"
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] step 3-7: scp file transfer (md5sums.txt) passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] step 3-7: scp file transfer (md5sums.txt) goes wrong!"
      exit 1
   fi
   #// step 4
   scp -q -i /id_ed25519 /github/"$GETDAY"/BUILD/platform-"$GETBUILD".iso root@"$GET_WEB_SRV_NAME":"$GET_WEB_SRC_NAME"/"$GETBUILD"
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] step 4-7: scp file transfer (platform-$GETBUILD.iso) passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] step 4-7: scp file transfer (platform-$GETBUILD.iso) goes wrong!"
      exit 1
   fi
   #// step 5
   scp -q -i /id_ed25519 /github/"$GETDAY"/BUILD/platform-"$GETBUILD".tgz root@"$GET_WEB_SRV_NAME":"$GET_WEB_SRC_NAME"/"$GETBUILD"
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] step 5-7: scp file transfer (platform-$GETBUILD.tgz) passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] step 5-7: scp file transfer (platform-$GETBUILD.tgz) goes wrong!"
      exit 1
   fi
   #// step 6
   scp -q -i /id_ed25519 /github/"$GETDAY"/BUILD/smartos-"$GETBUILD"-USB.img.bz2 root@"$GET_WEB_SRV_NAME":"$GET_WEB_SRC_NAME"/"$GETBUILD"
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] step 6-7: scp file transfer (smartos-$GETBUILD-USB.img.bz2) passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] step 6-7: scp file transfer (smartos-$GETBUILD-USB.img.bz2) goes wrong!"
      exit 1
   fi
   #// step 7
   ssh -q -i /id_ed25519 root@"$GET_WEB_SRV_NAME" "echo '/public/SmartOS/$GETBUILD' > $GET_WEB_SRC_NAME/latest"
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] step 7-7: create latest file passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] step 7-7: create latest file goes wrong!"
      exit 1
   fi
}

### RUN ###

### // stage0 ###

case "$1" in
### ### ### ### ### ### ### ### ###
'prepare')
### stage1 // ###

#// Linux Runner Part:
if [ "$GETZONETYPE" = "Linux" ]
then
   prepare_runner_get_env
fi

### // stage1 ###
   ;;
'transfer')
### stage1 // ###

#// Linux Runner Part:
if [ "$GETZONETYPE" = "Linux" ]
then
   transfer_runner_to_target
fi

### // stage1 ###
   ;;
'build')
### stage1 // ###

#// Linux Runner Part:
if [ "$GETZONETYPE" = "Linux" ]
then
   build_runner_start
fi

#// SmartOS Zone Build Part:
if [ "$GETZONETYPE" = "SunOS" ]
then
   build_zone_smartos
fi

### // stage1 ###
   ;;
'validate')
### stage1 // ###

#// Linux Runner Part:
if [ "$GETZONETYPE" = "Linux" ]
then
   validate_runner_start
fi

#// SmartOS Zone Build Part:
if [ "$GETZONETYPE" = "SunOS" ]
then
   validate_zone_smartos
fi

### // stage1 ###
   ;;
'publish')
### stage1 // ###

#// Linux Runner Part:
if [ "$GETZONETYPE" = "Linux" ]
then
   publish_runner_start
fi

#// SmartOS Zone Build Part:
if [ "$GETZONETYPE" = "SunOS" ]
then
   publish_zone_smartos
fi

### // stage1 ###
   ;;
### ### ### ### ### ### ### ### ###
*)
printf "\033[1;31mWARNING: run-ci-build-smartos is experimental and its not ready for production. Do it at your own risk.\033[0m\n"
echo "" # usage
echo "usage: $0 { prepare | transfer | build | validate | publish }"
;;
esac

### ### ### // ASS ### ### ###
exit 0
# EOF
