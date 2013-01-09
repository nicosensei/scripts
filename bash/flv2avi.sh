#!/bin/bash

OUTFILE=`echo "$2" | sed 's/.flv/.avi/'`

#if [ "$1" = "2pass" ];
#then 
#    mencoder -oac copy -ovc lavc -lavcopts vcodec=mpeg4:vpass=1 -oac copy -o /dev/null "$1"
#    mencoder -oac mp3lame -lameopts vbr=2 -ovc lavc -lavcopts vcodec=mpeg4:mbd=2:trell:vpass=2 -o "$OUTFILE" "$1"
#else
#    mencoder -oac mp3lame -lameopts vbr=2 -ovc lavc -lavcopts vcodec=mpeg4:mbd=2:trell:v4mv:turbo -o "$OUTFILE" "$1"
#fi

V_BITRATE=3000
case "$1" in
    -divx)
      MENC_OPTS="-ovc lavc -lavcopts vcodec=mpeg4:vbitrate=$V_BITRATE:mbd=2:v4mv:autoaspect"
      ;;
    -xvid)
      MENC_OPTS="-ovc xvid -xvidencopts bitrate=$V_BITRATE:autoaspect:pass=2"
      ;;
    -x264)
      MENC_OPTS="-ovc x264 -x264encopts bitrate=$V_BITRATE:pass=2:nr=2000"
      ;;
    *) 
      echo -e "Unrecognized option $1"
      exit -1
      ;;
esac

mencoder $MENC_OPTS -vf pp=lb -oac mp3lame -lameopts fast:preset=standard -o $OUTFILE "$2"
