#! /system/bin/sh
#***********************************************************
#** Copyright (C), 2008-2020, OPLUS Mobile Comm Corp., Ltd.
#** OPLUS_FEATURE_BT_HCI_LOG
#**
#** Version: 1.0
#** Date : 2020/06/06
#** Author: Laixin@CONNECTIVITY.BT.BASIC.LOG.70745, 2020/06/06
#** Add for: cached bt hci log and feedback
#**
#** ---------------------Revision History: ---------------------
#**  <author>    <data>       <version >       <desc>
#**  Laixin    2020/06/06     1.0        build this module
#****************************************************************/

config="$1"

function countCachedHciLog() {
    hciLogCachedPath=`getprop persist.sys.oplus.bt.cache_hcilog_path`
    if [ "w$hciLogCachedPath" = "w" ];then
        hciLogCachedPath="/data/misc/bluetooth/cached_hci/"
    fi
    enPath="/data/persist_log/DCS/en/network_logs/bt_hci_log/"
    dePath="/data/persist_log/DCS/de/network_logs/bt_hci_log/"

    cachedHciLogByteCnt=`ls -Al ${hciLogCachedPath} | grep btsnoop | awk 'BEGIN{sum7=0}{sum7+=$5}END{print sum7}'`
    cachedHciLogNumCnt=`ls -l ${hciLogCachedPath}  | grep "btsnoop" | wc -l`
    enHciLogCnt=`ls -Al $enPath | grep bt_hci_log | awk 'BEGIN{sum7=0}{sum7+=$5}END{print sum7}'`
    #`ls -l $enPath | grep "bt_hci_log" | wc -l`

    # keep each folder not more than threadshold
    threadshold=`getprop persist.sys.oplus.bt.cache_hcilog_fsThreshold_bytes`
    if [ enHciLogCnt -gt $threadshold ];then
        deleteCachedHciLog $enPath
    fi
    if [ cachedHciLogByteCnt -gt $threadshold ] || [ cachedHciLogNumCnt -gt 20 ];then
        deleteCachedHciLog $hciLogCachedPath
    fi

    deHciLogCnt=`ls -Al $dePath | grep bt_hci_log | awk 'BEGIN{sum7=0}{sum7+=$5}END{print sum7}'`
    if [ $deHciLogCnt -gt $threadshold ];then
        deleteCachedHciLog $dePath
    fi
    setprop sys.oplus.bt.count_cache_hcilog 0
}

function uploadCachedHciLog() {
    hciLogCachedPath=`getprop persist.sys.oplus.bt.cache_hcilog_path`
    if [ "w$hciLogCachedPath" = "w" ];then
        hciLogCachedPath="/data/misc/bluetooth/cached_hci/"
    fi
    dePath="/data/persist_log/DCS/de/network_logs/bt_hci_log"

    otaVersion=`getprop ro.build.version.ota`

    uuid=`uuidgen | sed 's/-//g'`
    echo "uuid: ${uuid}"
    uploadReason=`getprop sys.oplus.bt.cache_hcilog_upload_reason`
    if [ "w${uploadReason}" = "w" ];then
        uploadReason="rus_trigger_upload"
    fi

    fileName="bt_hci_log@${uuid:0:16}@${otaVersion}@${uploadReason}.tar.gz"
    # filter out posted file
    excludePosted=`ls -A ${hciLogCachedPath} | grep -v posted_`
    #echo ".... ${excludePosted}  ...."
    #excludePosted=($excludePosted)
    #echo "numbers: ${#excludePosted[@]}"
    num=${#excludePosted[@]}
    if [ num -eq 0 ];then
        setprop sys.oplus.bt.cache_hcilog_rus_upload 0
        return
    fi

    tar -czvf ${dePath}/${fileName} -C $hciLogCachedPath --exclude=posted_* $hciLogCachedPath
    chown -R system:system ${dePath}/${fileName}
    chmod -R 777 ${dePath}/${fileName}

    # for file that not in use, mark it as posted
    files=${excludePosted}
    #echo "file all $files"
    for var in ${files};
    do
        if [[ ! ${var} == posted_* ]];then
            status=`lsof ${hciLogCachedPath}/${var}`
            echo "status of  ${var} : $status"
            if [ "w${status}" = "w" ];then
                mv ${hciLogCachedPath}/${var} ${hciLogCachedPath}/posted_${var}
            fi
        fi
    done

    setprop sys.oplus.bt.cache_hcilog_rus_upload 0
}

function deleteCachedHciLog() {
    logPath=$1

    # sort file by time 
    filelist=`ls -Atr $logPath`
    filelist=($filelist)
    totalFile=${#filelist[@]}

    th=`getprop persist.sys.oplus.bt.cache_hcilog_fsThreshold_cnt`
    #echo "filelist: ${filelist},, totalFile: ${totalFile},, th: ${th}"
    loop=`expr ${totalFile} - ${th}`
    while [ ${loop} -gt 0 ];do
        index=`expr $loop - 1`
        if [ "w${logPath}" != "w" ];then
            rm ${logPath}/${filelist[$index]}
        fi
        let loop-=1
    done
}

function uploadBtSSRDump() {
    DCS_BT_LOG_PATH=/data/persist_log/DCS/de/network_logs/bt_fw_dump
    if [ ! -d ${DCS_BT_LOG_PATH} ];then
        mkdir -p ${DCS_BT_LOG_PATH}
    fi

    #this only provide uuid
    uuidssr=`getprop persist.sys.bluetooth.dump.zip.name`
    otassr=`getprop ro.build.version.ota`
    date_time=`date +%Y-%m-%d_%H-%M-%S`
    zip_name="bt_ssr_dump@${uuidssr}@${otassr}@${date_time}"

    chmod 777 ${DCS_BT_LOG_PATH}/*
    debtssrdumpcount=`ls -l /data/persist_log/DCS/de/network_logs/bt_fw_dump  | grep "bt_ssr_dump" | wc -l`
    enbtssrdumpcount=`ls -l /data/persist_log/DCS/en/network_logs/bt_fw_dump  | grep "bt_ssr_dump" | wc -l`
    dump_count_limit=`getprop persist.sys.bt.ssrdump.limit`
    if [ "x$dump_count_limit" == 'x' ];then
        dump_count_limit=10
    fi
    if [ $debtssrdumpcount -ge ${dump_count_limit} ];then
        # remove the oldest compressed file
        filelist=`ls -Atr $DCS_BT_LOG_PATH | grep bt_ssr_dump`
        filelist=($filelist)
        rm ${DCS_BT_LOG_PATH}/${filelist[0]}
    fi
    # remove op would be failed, double check to avoid file increase
    debtssrdumpcount=`ls -l /data/persist_log/DCS/de/network_logs/bt_fw_dump  | grep "bt_ssr_dump" | wc -l`
    enbtssrdumpcount=`ls -l /data/persist_log/DCS/en/network_logs/bt_fw_dump  | grep "bt_ssr_dump" | wc -l`
    if [ $debtssrdumpcount -lt ${dump_count_limit} ] && [ $enbtssrdumpcount -lt ${dump_count_limit} ];then
        dmesg > ${DCS_BT_LOG_PATH}/kernel_${date_time}.txt
        tar -czvf  ${DCS_BT_LOG_PATH}/${zip_name}.tar.gz --exclude=*.tar.gz -C ${DCS_BT_LOG_PATH} ${DCS_BT_LOG_PATH}
    fi
    #sleep 5
    if [ "w${DCS_BT_LOG_PATH}" != "w" ];then
        rm ${DCS_BT_LOG_PATH}/*.log
        rm ${DCS_BT_LOG_PATH}/*.cfa
        rm ${DCS_BT_LOG_PATH}/*.bin
        rm ${DCS_BT_LOG_PATH}/*.txt
        rm ${DCS_BT_LOG_PATH}/combo_t32*
    fi

    chown system:system ${DCS_BT_LOG_PATH}/${zip_name}.tar.gz
    chmod 777 ${DCS_BT_LOG_PATH}/${zip_name}.tar.gz

    setprop sys.oplus.bt.collect_bt_ssrdump 0
}

case "$config" in
        "collectBTCoredumpLog")
        collectBTCoredumpLog
    ;;
        "countCachedHciLog")
        countCachedHciLog
    ;;
        "uploadCachedHciLog")
        uploadCachedHciLog
    ;;
        "uploadBtSSRDump")
        uploadBtSSRDump
    ;;
esac
